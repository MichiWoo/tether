import { BadRequestException, Injectable, Logger, NotFoundException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { InjectQueue } from '@nestjs/bullmq';
import { Queue } from 'bullmq';
import { PrismaService } from '../prisma/prisma.service.js';
import { StorageService } from '../storage/storage.service.js';
import { RealtimeService } from '../realtime/realtime.service.js';
import { EVENTS } from '../realtime/realtime-events.js';
import { FileStatus, ShareStatus } from '../generated/prisma/client.js';
import { toFileResponse, objectKey } from '../files/file.mapper.js';
import { CreateShareDto } from './dto/create-share.dto.js';
import type { ShareDetailResponse, ShareResponse, ShareWithFile } from './transfer.types.js';

export const QUEUE_TRANSFERS = 'transfers';
export const JOB_SHARE_CREATED = 'share:created';
export const JOB_EXPIRE_SHARES = 'expire-shares';

const DOWNLOAD_URL_TTL = 3600;

@Injectable()
export class TransfersService {
  private readonly logger = new Logger(TransfersService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly storage: StorageService,
    private readonly realtime: RealtimeService,
    private readonly configService: ConfigService,
    @InjectQueue(QUEUE_TRANSFERS) private readonly queue: Queue,
  ) {}

  async createShare(userId: string, dto: CreateShareDto): Promise<ShareResponse> {
    const file = await this.prisma.fileRecord.findFirst({
      where: { id: dto.fileId, userId },
    });
    if (!file) {
      throw new NotFoundException('File not found');
    }
    if (file.status !== FileStatus.UPLOADED) {
      throw new BadRequestException('File is not uploaded yet');
    }

    const targetDeviceId: string | null = dto.targetDeviceId ?? null;
    if (targetDeviceId) {
      const device = await this.prisma.device.findFirst({
        where: { id: targetDeviceId, userId },
        select: { id: true },
      });
      if (!device) {
        throw new NotFoundException('Target device not found');
      }
    }

    const ttlDays = Number(this.configService.get<string>('SHARE_TTL_DAYS', '7'));
    const expiresAt = new Date(Date.now() + ttlDays * 24 * 60 * 60 * 1000);

    const share = await this.prisma.share.create({
      data: {
        userId,
        fileId: file.id,
        targetDeviceId,
        expiresAt,
      },
      include: { file: true },
    });

    await this.queue.add(JOB_SHARE_CREATED, { shareId: share.id });
    return this.toResponse(share);
  }

  async findAll(userId: string, status?: ShareStatus): Promise<ShareResponse[]> {
    const shares = await this.prisma.share.findMany({
      where: { userId, ...(status ? { status } : {}) },
      orderBy: { createdAt: 'desc' },
      include: { file: true },
    });
    return shares.map((share) => this.toResponse(share));
  }

  async getDetail(userId: string, shareId: string): Promise<ShareDetailResponse> {
    const share = await this.findOwnedShare(userId, shareId);
    const downloadUrl =
      share.status !== ShareStatus.EXPIRED && share.file
        ? await this.storage.getPresignedDownloadUrl(
            objectKey(userId, share.fileId),
            share.file.name,
            DOWNLOAD_URL_TTL,
          )
        : null;
    return { ...this.toResponse(share), downloadUrl };
  }

  async acceptShare(userId: string, shareId: string): Promise<ShareResponse> {
    const share = await this.findOwnedShare(userId, shareId);
    if (share.status === ShareStatus.EXPIRED) {
      throw new BadRequestException('Share is expired');
    }
    const updated = await this.prisma.share.update({
      where: { id: share.id },
      data: { status: ShareStatus.ACCEPTED, acceptedAt: new Date() },
      include: { file: true },
    });
    this.realtime.emitToUser(userId, EVENTS.shareAccepted, {
      share: this.toResponse(updated),
    });
    return this.toResponse(updated);
  }

  async markDownloaded(userId: string, shareId: string): Promise<ShareResponse> {
    const share = await this.findOwnedShare(userId, shareId);
    if (share.status === ShareStatus.EXPIRED) {
      throw new BadRequestException('Share is expired');
    }
    const updated = await this.prisma.share.update({
      where: { id: share.id },
      data: { status: ShareStatus.DOWNLOADED, downloadedAt: new Date() },
      include: { file: true },
    });
    this.realtime.emitToUser(userId, EVENTS.shareDownloaded, {
      share: this.toResponse(updated),
    });
    return this.toResponse(updated);
  }

  async cancelShare(userId: string, shareId: string): Promise<ShareResponse> {
    const share = await this.findOwnedShare(userId, shareId);
    const updated = await this.prisma.share.update({
      where: { id: share.id },
      data: { status: ShareStatus.EXPIRED },
      include: { file: true },
    });
    return this.toResponse(updated);
  }

  async notifyShareCreated(shareId: string): Promise<void> {
    const share = await this.prisma.share.findUnique({
      where: { id: shareId },
      include: { file: true },
    });
    if (!share) {
      return;
    }
    const payload = { share: this.toResponse(share) };
    if (share.targetDeviceId) {
      this.realtime.emitToDevice(share.targetDeviceId, EVENTS.shareCreated, payload);
    } else {
      this.realtime.emitToUser(share.userId, EVENTS.shareCreated, payload);
    }
  }

  async expireOverdue(): Promise<void> {
    const now = new Date();
    const overdue = await this.prisma.share.findMany({
      where: {
        status: { in: [ShareStatus.CREATED, ShareStatus.ACCEPTED] },
        expiresAt: { lt: now },
      },
      include: { file: true },
    });

    if (overdue.length === 0) {
      return;
    }

    await this.prisma.share.updateMany({
      where: { id: { in: overdue.map((share) => share.id) } },
      data: { status: ShareStatus.EXPIRED },
    });

    for (const share of overdue) {
      this.realtime.emitToUser(share.userId, EVENTS.shareExpired, {
        shareId: share.id,
      });
      if (!share.file) {
        continue;
      }
      try {
        await this.storage.deleteObject(objectKey(share.userId, share.fileId));
        await this.prisma.fileRecord.delete({ where: { id: share.fileId } });
      } catch (err) {
        this.logger.error(
          `No se pudo limpiar el share expirado ${share.id} (file ${share.fileId})`,
          err as Error,
        );
      }
    }
  }

  private async findOwnedShare(userId: string, shareId: string): Promise<ShareWithFile> {
    const share = await this.prisma.share.findFirst({
      where: { id: shareId, userId },
      include: { file: true },
    });
    if (!share) {
      throw new NotFoundException('Share not found');
    }
    return share;
  }

  private toResponse(share: ShareWithFile): ShareResponse {
    return {
      id: share.id,
      status: share.status,
      file: share.file ? toFileResponse(share.file) : null,
      targetDeviceId: share.targetDeviceId,
      acceptedAt: share.acceptedAt?.toISOString() ?? null,
      downloadedAt: share.downloadedAt?.toISOString() ?? null,
      expiresAt: share.expiresAt.toISOString(),
      createdAt: share.createdAt.toISOString(),
    };
  }
}
