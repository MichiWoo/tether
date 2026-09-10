import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service.js';
import { QuotaExceededException } from './plans.errors.js';
import { PLAN_LIMITS, type PlanLimits, type PlanUsageResponse, type PlanName } from '@tether/protocol';

@Injectable()
export class PlansService {
  constructor(private readonly prisma: PrismaService) {}

  limitsFor(plan: PlanName): PlanLimits {
    return PLAN_LIMITS[plan];
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
    const limits = PLAN_LIMITS[plan];

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
    const limits = PLAN_LIMITS[plan];
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
    const limits = PLAN_LIMITS[plan];
    const devices = await this.prisma.device.count({ where: { userId } });
    if (devices >= limits.maxDevices) {
      throw new QuotaExceededException('QUOTA_DEVICE_LIMIT', `Límite de dispositivos de tu plan (${plan}) alcanzado`, {
        maxDevices: limits.maxDevices,
      });
    }
  }

  async assertTransfer(userId: string, incomingBytes: number): Promise<void> {
    const plan = await this.getUserPlan(userId);
    const limits = PLAN_LIMITS[plan];
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
