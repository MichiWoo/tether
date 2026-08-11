import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { InjectQueue } from '@nestjs/bullmq';
import { Queue } from 'bullmq';
import { PrismaService } from '../prisma/prisma.service.js';
import { StorageService } from '../storage/storage.service.js';
import { RealtimeService } from '../realtime/realtime.service.js';
import { FileStatus, ShareStatus } from '../generated/prisma/client.js';
import { FileResponse } from '../files/file.types.js';
import { CreateShareDto } from './dto/create-share.dto.js';
import { ShareDetailResponse, ShareResponse, ShareWithFile } from './transfer.types.js';

export const QUEUE_TRANSFERS = 'transfers';
export const JOB_SHARE_CREATED = 'share:created';
export const JOB_EXPIRE_SHARES = 'expire-shares';

const DOWNLOAD_URL_TTL = 3600;

@Injectable()
export class TransfersService {
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

  async findAll(userId: string, status?: string): Promise<ShareResponse[]> {
    let statusFilter: ShareStatus | undefined;
    if (status) {
      if (!Object.values(ShareStatus).includes(status as ShareStatus)) {
        throw new BadRequestException('Invalid status');
      }
      statusFilter = status as ShareStatus;
    }
    const shares = await this.prisma.share.findMany({
      where: { userId, ...(statusFilter ? { status: statusFilter } : {}) },
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
            this.objectKey(userId, share.fileId),
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
    this.realtime.emitToUser(userId, 'share.accepted', {
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
    this.realtime.emitToUser(userId, 'share.downloaded', {
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
      this.realtime.emitToDevice(share.targetDeviceId, 'share.created', payload);
    } else {
      this.realtime.emitToUser(share.userId, 'share.created', payload);
    }
  }

  async expireOverdue(): Promise<void> {
    const overdue = await this.prisma.share.findMany({
      where: {
        status: { in: [ShareStatus.CREATED, ShareStatus.ACCEPTED] },
        expiresAt: { lt: new Date() },
      },
      include: { file: true },
    });

    for (const share of overdue) {
      await this.prisma.share.update({
        where: { id: share.id },
        data: { status: ShareStatus.EXPIRED },
      });
      this.realtime.emitToUser(share.userId, 'share.expired', {
        shareId: share.id,
      });
      if (share.file) {
        await this.storage
          .deleteObject(this.objectKey(share.userId, share.fileId))
          .catch(() => undefined);
        await this.prisma.fileRecord.delete({ where: { id: share.fileId } }).catch(() => undefined);
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

  private objectKey(userId: string, fileId: string): string {
    return `users/${userId}/${fileId}`;
  }

  private toResponse(share: ShareWithFile): ShareResponse {
    return {
      id: share.id,
      status: share.status,
      file: share.file ? this.toFileResponse(share.file) : null,
      targetDeviceId: share.targetDeviceId,
      acceptedAt: share.acceptedAt?.toISOString() ?? null,
      downloadedAt: share.downloadedAt?.toISOString() ?? null,
      expiresAt: share.expiresAt.toISOString(),
      createdAt: share.createdAt.toISOString(),
    };
  }

  private toFileResponse(file: {
    id: string;
    name: string;
    size: number;
    mimeType: string | null;
    checksum: string | null;
    status: FileStatus;
    uploadedAt: Date | null;
    createdAt: Date;
    updatedAt: Date;
  }): FileResponse {
    return {
      id: file.id,
      name: file.name,
      size: file.size,
      mimeType: file.mimeType,
      checksum: file.checksum,
      status: file.status,
      uploadedAt: file.uploadedAt?.toISOString() ?? null,
      createdAt: file.createdAt.toISOString(),
      updatedAt: file.updatedAt.toISOString(),
    };
  }
}
