import {
  Body,
  Controller,
  Get,
  NotFoundException,
  Param,
  Put,
  Query,
  UseGuards,
} from '@nestjs/common';
import { ApiOperation, ApiProperty, ApiPropertyOptional, ApiTags } from '@nestjs/swagger';
import { BadRequestException } from '@nestjs/common';
import { Type } from 'class-transformer';
import { IsInt, IsOptional, IsPositive, IsString, Max, MaxLength, Min } from 'class-validator';
import { PLAN_LIMITS } from '@tether/protocol';
import { PLAN_CODES, type AdminPlansResponse, type AdminUser, type AdminUsersResponse, type PlanLimits, type PlanName } from '@tether/protocol';
import { AdminKeyGuard } from './admin-key.guard.js';
import { PlansService } from './plans.service.js';
import { PrismaService } from '../prisma/prisma.service.js';

const GB = 1024 ** 3;
const MS_PER_MIN = 60 * 1000;

export class PlanLimitsDto {
  @ApiProperty({ description: 'Espacio total en bytes (≤ 1 PB)' })
  @IsInt()
  @IsPositive()
  @Min(1)
  @Max(1024 ** 5)
  maxStorageBytes!: number;

  @ApiProperty({ description: ' Máximo por archivo individual (≤ 10 GB)' })
  @IsInt()
  @IsPositive()
  @Max(10 * GB)
  maxFileSizeBytes!: number;

  @ApiProperty({ description: 'Cuota mensual de transferencia (bytes)' })
  @IsInt()
  @IsPositive()
  @Max(1024 ** 5)
  monthlyTransferBytes!: number;

  @ApiProperty({ example: 10 })
  @IsInt()
  @Min(1)
  @Max(1000)
  maxDevices!: number;

  @ApiProperty({ example: 30 })
  @IsInt()
  @Min(1)
  @Max(365)
  shareTtlDays!: number;

  @ApiProperty({ example: 500 })
  @IsInt()
  @Min(1)
  @Max(100_000)
  clipboardHistoryItems!: number;

  @ApiProperty({ example: 365 })
  @IsInt()
  @Min(1)
  @Max(3650)
  clipboardRetentionDays!: number;
}

export class ListAdminUsersQueryDto {
  @ApiPropertyOptional({ description: 'Filtra por email o nombre (ILIKE)' })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  q?: string;

  @ApiPropertyOptional({ default: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  page?: number = 1;

  @ApiPropertyOptional({ default: 25 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  take?: number = 25;
}

interface AdminUserRow {
  id: string;
  email: string;
  name: string | null;
  plan: string;
  "createdAt": Date;
  devices: bigint;
  storage: string | bigint;
  transfer: string | bigint;
}

interface TotalRow {
  total: string | bigint;
}

interface PlanPlanRow {
  plan: string;
  bytes: string | bigint;
}

@ApiTags('admin')
@Controller('admin')
@UseGuards(AdminKeyGuard)
export class AdminController {
  constructor(
    private readonly plansService: PlansService,
    private readonly prisma: PrismaService,
  ) {}

  @Get('plans')
  @ApiOperation({ summary: 'Lista los 3 planes con sus límites (X-Plan-Admin-Key)' })
  async plans(): Promise<AdminPlansResponse> {
    const rows = await this.prisma.planLimits.findMany({ orderBy: { plan: 'asc' } });
    return rows.map((row) => ({
      plan: row.plan as PlanName,
      title: row.title,
      limits: {
        maxStorageBytes: Number(row.maxStorageBytes),
        maxFileSizeBytes: Number(row.maxFileSizeBytes),
        monthlyTransferBytes: Number(row.monthlyTransferBytes),
        maxDevices: row.maxDevices,
        shareTtlDays: row.shareTtlDays,
        clipboardHistoryItems: row.clipboardHistoryItems,
        clipboardRetentionDays: row.clipboardRetentionDays,
      },
      updatedAt: row.updatedAt.toISOString(),
    }));
  }

  @Put('plans/:plan')
  @ApiOperation({ summary: 'Actualiza los límites de un plan (X-Plan-Admin-Key)' })
  async updatePlan(@Param('plan') planParam: string, @Body() dto: PlanLimitsDto) {
    const plan = planParam.toUpperCase() as PlanName;
    if (!PLAN_CODES.includes(plan)) {
      throw new NotFoundException(`Plan "${planParam}" no existe; use: ${PLAN_CODES.join(', ')}`);
    }
    const limits: PlanLimits = {
      maxStorageBytes: dto.maxStorageBytes,
      maxFileSizeBytes: dto.maxFileSizeBytes,
      monthlyTransferBytes: dto.monthlyTransferBytes,
      maxDevices: dto.maxDevices,
      shareTtlDays: dto.shareTtlDays,
      clipboardHistoryItems: dto.clipboardHistoryItems,
      clipboardRetentionDays: dto.clipboardRetentionDays,
    };
    await this.enforceHierarchy(plan, limits);
    await this.plansService.updateLimits(plan, limits);
    return { plan, limits, ok: true };
  }

  @Get('users')
  @ApiOperation({ summary: 'Lista paginada de usuarios con uso por usuario (X-Plan-Admin-Key)' })
  async users(@Query() query: ListAdminUsersQueryDto): Promise<AdminUsersResponse> {
    const page = query.page ?? 1;
    const take = query.take ?? 25;
    const q = (query.q ?? '').trim();
    const monthStart = new Date(Date.UTC(new Date().getUTCFullYear(), new Date().getUTCMonth(), 1));
    const offset = (page - 1) * take;
    const like = `%${q}%`;
    const rows = await this.prisma.$queryRaw<AdminUserRow[]>`
      SELECT u.id, u.email, u.name, u.plan::text AS plan, u."createdAt",
             (SELECT COUNT(*) FROM devices d WHERE d."userId" = u.id) AS devices,
             (SELECT COALESCE(SUM(f.size), 0) FROM files f WHERE f."userId" = u.id AND f."status" = 'UPLOADED') AS storage,
             (SELECT COALESCE(SUM(f.size), 0) FROM shares s JOIN files f ON f.id = s."fileId"
              WHERE s."userId" = u.id AND s."status" = 'DOWNLOADED' AND s."downloadedAt" >= ${monthStart}) AS transfer
      FROM users u
      WHERE (${q} = '' OR u.email ILIKE ${like} OR u.name ILIKE ${like})
      ORDER BY u."createdAt" DESC
      LIMIT ${take} OFFSET ${offset}`;

    const totalRow = await this.prisma.$queryRaw<TotalRow[]>`
      SELECT COUNT(*) AS total FROM users u
      WHERE (${q} = '' OR u.email ILIKE ${like} OR u.name ILIKE ${like})`;
    const total = Number(totalRow[0]?.total ?? 0);

    const items: AdminUser[] = rows.map((r) => ({
      id: r.id,
      email: r.email,
      name: r.name,
      plan: r.plan as PlanName,
      devices: Number(r.devices),
      storageBytes: Number(r.storage),
      transferBytesThisMonth: Number(r.transfer),
      createdAt: (r["createdAt"] as unknown as Date).toISOString(),
    }));
    return { items, total, page, take };
  }

  @Put('users/:id/plan')
  @ApiOperation({ summary: 'Cambia el plan de un usuario (X-Plan-Admin-Key)' })
  async setUserPlan(@Param('id') id: string, @Body() dto: { plan: string }) {
    const plan = (dto.plan ?? '').toUpperCase() as PlanName;
    if (!PLAN_CODES.includes(plan)) {
      throw new NotFoundException(`Plan "${dto.plan}" no existe; use: ${PLAN_CODES.join(', ')}`);
    }
    const user = await this.prisma.user.findUnique({ where: { id }, select: { id: true } });
    if (!user) {
      throw new NotFoundException('User not found');
    }
    await this.plansService.setPlan(id, plan);
    return { id, plan: plan, ok: true };
  }

  @Get('metrics')
  @ApiOperation({ summary: 'Métricas globales por plan (X-Plan-Admin-Key)' })
  async metrics() {
    const windowStart = new Date(Date.UTC(new Date().getUTCFullYear(), new Date().getUTCMonth(), 1));
    const activeSince = new Date(Date.now() - 2 * MS_PER_MIN);

    const usersByPlan = await this.prisma.user.groupBy({ by: ['plan'], _count: { _all: true } });
    const storageByPlan = await this.prisma.$queryRaw<PlanPlanRow[]>`
      SELECT u.plan::text AS plan, COALESCE(SUM(f.size), 0) AS bytes
      FROM users u
      LEFT JOIN files f ON f."userId" = u.id AND f."status" = 'UPLOADED'
      GROUP BY u.plan::text, u.plan ORDER BY u.plan::text`;
    const transferByPlan = await this.prisma.$queryRaw<PlanPlanRow[]>`
      SELECT u.plan::text AS plan, COALESCE(SUM(f.size), 0) AS bytes
      FROM users u
      LEFT JOIN shares s ON s."userId" = u.id AND s."status" = 'DOWNLOADED' AND s."downloadedAt" >= ${windowStart}
      LEFT JOIN files f ON f.id = s."fileId"
      GROUP BY u.plan::text, u.plan ORDER BY u.plan::text`;
    const activeDevices = await this.prisma.device.count({ where: { lastSeenAt: { gte: activeSince } } });
    const sharesByStatus = await this.prisma.share.groupBy({ by: ['status'], _count: { _all: true } });

    return {
      usersByPlan: usersByPlan.map((r) => ({ plan: r.plan as PlanName, count: r._count._all })),
      storageByPlan: storageByPlan.map((r) => ({ plan: r.plan as PlanName, bytes: Number(r.bytes) })),
      transferByPlan: transferByPlan.map((r) => ({ plan: r.plan as PlanName, bytes: Number(r.bytes) })),
      activeDevices,
      sharesActive: sharesByStatus.filter((r) => r.status !== 'EXPIRED').reduce((acc, r) => acc + r._count._all, 0),
      sharesExpired: sharesByStatus.filter((r) => r.status === 'EXPIRED').reduce((acc, r) => acc + r._count._all, 0),
      monthStart: windowStart.toISOString(),
    };
  }

  // Jerarquía guardada: el tope superior de un plan no puede superar al del siguiente.
  private async enforceHierarchy(plan: PlanName, limits: PlanLimits): Promise<void> {
    const order: PlanName[] = ['FREE', 'PRO', 'UNLIMITS'];
    const idx = order.indexOf(plan);
    const next = order[idx + 1];
    if (!next) return;
    const nextRow = await this.prisma.planLimits.findUnique({ where: { plan: next } });
    const nextLimits = nextRow
      ? {
          maxStorageBytes: Number(nextRow.maxStorageBytes),
          maxFileSizeBytes: Number(nextRow.maxFileSizeBytes),
          monthlyTransferBytes: Number(nextRow.monthlyTransferBytes),
          maxDevices: nextRow.maxDevices,
          shareTtlDays: nextRow.shareTtlDays,
        }
      : { maxStorageBytes: PLAN_LIMITS[next].maxStorageBytes, maxFileSizeBytes: PLAN_LIMITS[next].maxFileSizeBytes, monthlyTransferBytes: PLAN_LIMITS[next].monthlyTransferBytes, maxDevices: PLAN_LIMITS[next].maxDevices, shareTtlDays: PLAN_LIMITS[next].shareTtlDays };
    if (
      limits.maxStorageBytes > nextLimits.maxStorageBytes ||
      limits.maxFileSizeBytes > nextLimits.maxFileSizeBytes ||
      limits.monthlyTransferBytes > nextLimits.monthlyTransferBytes ||
      limits.maxDevices > nextLimits.maxDevices ||
      limits.shareTtlDays > nextLimits.shareTtlDays
    ) {
      throw new BadRequestException(`Límites de ${plan} deben ser ≤ a los de ${next}`);
    }
  }
}
