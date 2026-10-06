import { Injectable, Logger, NotFoundException, type OnModuleInit } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service.js';
import { QuotaExceededException } from './plans.errors.js';
import { PLAN_LIMITS, type PlanLimits, type PlanUsageResponse, type PlanName } from '@tether/protocol';

@Injectable()
export class PlansService implements OnModuleInit {
  private readonly logger = new Logger(PlansService.name);
  // Los límites viven en la tabla `plans` (editables por panel admin).
  // Código PLAN_LIMITS queda como fallback si la fila falta.
  private readonly limitsCache = new Map<PlanName, PlanLimits>();

  constructor(private readonly prisma: PrismaService) {}

  async onModuleInit(): Promise<void> {
    try {
      const rows = await this.prisma.planLimits.findMany();
      for (const row of rows) {
        this.limitsCache.set(row.plan as PlanName, toLimits(row));
      }
      this.logger.log(`Límites de planes cargados desde DB (${rows.length} planes).`);
    } catch (err) {
      this.logger.warn('No se pudo cargar límites de planes desde DB; usando valores del código.', err as Error);
    }
  }

  limitsFor(plan: PlanName): PlanLimits {
    return this.limitsCache.get(plan) ?? PLAN_LIMITS[plan];
  }

  async updateLimits(plan: PlanName, limits: PlanLimits): Promise<PlanLimits> {
    const row = await this.prisma.planLimits.upsert({
      where: { plan },
      update: {
        maxStorageBytes: BigInt(limits.maxStorageBytes),
        maxFileSizeBytes: BigInt(limits.maxFileSizeBytes),
        monthlyTransferBytes: BigInt(limits.monthlyTransferBytes),
        maxDevices: limits.maxDevices,
        shareTtlDays: limits.shareTtlDays,
        clipboardHistoryItems: limits.clipboardHistoryItems,
        clipboardRetentionDays: limits.clipboardRetentionDays,
      },
      create: { ...toCreate(plan, limits) },
    });
    const mapped = toLimits(row);
    this.limitsCache.set(plan, mapped);
    return mapped;
  }

  async listPlanRows(): Promise<PlanLimits[]> {
    const rows = await this.prisma.planLimits.findMany({ orderBy: { plan: 'asc' } });
    return rows.map(toLimits);
  }

  async getUserPlan(userId: string): Promise<PlanName> {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { plan: true },
    });
    if (!user) {
      throw new NotFoundException('User not found');
    }
    return user.plan as PlanName;
  }

  async setPlan(userId: string, plan: PlanName): Promise<PlanName> {
    await this.prisma.user.update({
      where: { id: userId },
      data: { plan, planChangedAt: new Date() },
    });
    return plan;
  }

  async usage(userId: string): Promise<PlanUsageResponse> {
    const plan = await this.getUserPlan(userId);
    const limits = this.limitsFor(plan);

    const window = this.monthlyTransferWindow(new Date());
    const [storage, transfer, devices, clipboardItems] = await Promise.all([
      this.prisma.fileRecord.aggregate({
        where: { userId, status: { in: ['PENDING', 'UPLOADED'] } },
        _sum: { size: true },
      }),
      this.prisma.share
        .findMany({
          where: {
            userId,
            status: 'DOWNLOADED',
            downloadedAt: { gte: window.start, lte: window.end },
          },
          select: { file: { select: { size: true } } },
        })
        .then((shares) => shares.reduce((acc, share) => acc + (share.file?.size ?? 0), 0)),
      this.prisma.device.count({ where: { userId } }),
      this.prisma.clipboardItem.count({ where: { userId } }),
    ]);

    return {
      plan,
      limits,
      storageUsedBytes: storage._sum.size ?? 0,
      transferUsedThisMonthBytes: transfer,
      devicesUsed: devices,
      clipboardItemsUsed: clipboardItems,
      monthlyTransferWindow: {
        start: window.start.toISOString(),
        end: window.end.toISOString(),
      },
    };
  }

  async assertFileUpload(userId: string, incomingBytes: number): Promise<void> {
    const plan = await this.getUserPlan(userId);
    const limits = this.limitsFor(plan);
    if (incomingBytes > limits.maxFileSizeBytes) {
      throw new QuotaExceededException('QUOTA_FILE_TOO_LARGE', `Archivo excede el máximo de tu plan (${plan})`, {
        maxFileSizeBytes: limits.maxFileSizeBytes,
      });
    }
    const storage = await this.prisma.fileRecord.aggregate({
      where: { userId, status: { in: ['PENDING', 'UPLOADED'] } },
      _sum: { size: true },
    });
    const used = storage._sum.size ?? 0;
    if (used + incomingBytes > limits.maxStorageBytes) {
      throw new QuotaExceededException('QUOTA_STORAGE_EXCEEDED', 'Sin espacio suficiente en tu plan', {
        storageUsedBytes: used,
        maxStorageBytes: limits.maxStorageBytes,
      });
    }
  }

  async assertDeviceRegister(userId: string): Promise<void> {
    const plan = await this.getUserPlan(userId);
    const limits = this.limitsFor(plan);
    const devices = await this.prisma.device.count({ where: { userId } });
    if (devices >= limits.maxDevices) {
      throw new QuotaExceededException('QUOTA_DEVICE_LIMIT', `Límite de dispositivos de tu plan (${plan}) alcanzado`, {
        maxDevices: limits.maxDevices,
      });
    }
  }

  async assertTransfer(userId: string, incomingBytes: number): Promise<void> {
    const plan = await this.getUserPlan(userId);
    const limits = this.limitsFor(plan);
    const window = this.monthlyTransferWindow(new Date());
    const shares = await this.prisma.share.findMany({
      where: {
        userId,
        status: 'DOWNLOADED',
        downloadedAt: { gte: window.start, lte: window.end },
      },
      select: { file: { select: { size: true } } },
    });
    const used = shares.reduce((acc, share) => acc + (share.file?.size ?? 0), 0);
    if (used + incomingBytes > limits.monthlyTransferBytes) {
      throw new QuotaExceededException('QUOTA_TRANSFER_EXCEEDED', `Cuota de transferencia mensual del plan (${plan}) alcanzada`, {
        transferUsedBytes: used,
        monthlyTransferBytes: limits.monthlyTransferBytes,
      });
    }
  }

  private monthlyTransferWindow(now: Date): { start: Date; end: Date } {
    const start = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), 1));
    const end = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth() + 1, 1));
    return { start, end };
  }
}

function toLimits(row: {
  plan: string;
  maxStorageBytes: bigint;
  maxFileSizeBytes: bigint;
  monthlyTransferBytes: bigint;
  maxDevices: number;
  shareTtlDays: number;
  clipboardHistoryItems: number;
  clipboardRetentionDays: number;
}): PlanLimits {
  return {
    maxStorageBytes: Number(row.maxStorageBytes),
    maxFileSizeBytes: Number(row.maxFileSizeBytes),
    monthlyTransferBytes: Number(row.monthlyTransferBytes),
    maxDevices: row.maxDevices,
    shareTtlDays: row.shareTtlDays,
    clipboardHistoryItems: row.clipboardHistoryItems,
    clipboardRetentionDays: row.clipboardRetentionDays,
  };
}

function toCreate(plan: PlanName, limits: PlanLimits) {
  return {
    plan,
    title: plan.charAt(0) + plan.slice(1).toLowerCase(),
    maxStorageBytes: BigInt(limits.maxStorageBytes),
    maxFileSizeBytes: BigInt(limits.maxFileSizeBytes),
    monthlyTransferBytes: BigInt(limits.monthlyTransferBytes),
    maxDevices: limits.maxDevices,
    shareTtlDays: limits.shareTtlDays,
    clipboardHistoryItems: limits.clipboardHistoryItems,
    clipboardRetentionDays: limits.clipboardRetentionDays,
  };
}
