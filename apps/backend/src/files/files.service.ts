import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service.js';
import { StorageService } from '../storage/storage.service.js';
import { RealtimeService } from '../realtime/realtime.service.js';
import { PlansService } from '../plans/plans.service.js';
import { EVENTS } from '../realtime/realtime-events.js';
import { FileStatus } from '../generated/prisma/client.js';
import type { FileRecord } from '../generated/prisma/client.js';
import { CreateFileDto } from './dto/create-file.dto.js';
import type { CreateFileResponse, FileDownloadResponse, FileResponse } from './file.types.js';
import { objectKey, toFileResponse } from './file.mapper.js';

const MAX_LIST = 100;
const DOWNLOAD_URL_TTL = 3600;

@Injectable()
export class FilesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly storage: StorageService,
    private readonly realtime: RealtimeService,
    private readonly plans: PlansService,
  ) {}

  async create(userId: string, dto: CreateFileDto): Promise<CreateFileResponse> {
    await this.plans.assertFileUpload(userId, dto.size);
    const file = await this.prisma.fileRecord.create({
      data: {
        userId,
        name: dto.name,
        size: dto.size,
        mimeType: dto.mimeType ?? null,
        checksum: dto.checksum ?? null,
      },
    });

    const uploadUrl = await this.storage.getPresignedUploadUrl(
      objectKey(userId, file.id, file.name),
      file.mimeType ?? 'application/octet-stream',
    );

    return {
      file: toFileResponse(file),
      upload: {
        url: uploadUrl,
        method: 'PUT',
        headers: { 'Content-Type': file.mimeType ?? 'application/octet-stream' },
      },
    };
  }

  async findAll(userId: string, limit = 50): Promise<FileResponse[]> {
    const safeLimit = Math.min(Math.max(limit, 1), MAX_LIST);
    const files = await this.prisma.fileRecord.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      take: safeLimit,
    });
    return files.map((file) => toFileResponse(file));
  }

  async getDownload(userId: string, fileId: string): Promise<FileDownloadResponse> {
    return this.getFileUrl(userId, fileId, 'attachment');
  }

  async getPreview(userId: string, fileId: string): Promise<FileDownloadResponse> {
    return this.getFileUrl(userId, fileId, 'inline');
  }

  private async getFileUrl(
    userId: string,
    fileId: string,
    disposition: 'attachment' | 'inline',
  ): Promise<FileDownloadResponse> {
    const file = await this.findOwnedFile(userId, fileId);
    if (file.status !== FileStatus.UPLOADED) {
      throw new BadRequestException('File is not uploaded yet');
    }
    const downloadUrl = await this.storage.getPresignedDownloadUrl(
      objectKey(userId, file.id, file.name),
      file.name,
      DOWNLOAD_URL_TTL,
      disposition,
    );
    return {
      file: toFileResponse(file),
      downloadUrl,
      expiresIn: DOWNLOAD_URL_TTL,
    };
  }

  async complete(userId: string, fileId: string): Promise<FileResponse> {
    const file = await this.findOwnedFile(userId, fileId);
    if (file.status === FileStatus.UPLOADED) {
      return toFileResponse(file);
    }

    const exists = await this.storage.objectExists(objectKey(userId, fileId, file.name));
    if (!exists) {
      throw new BadRequestException('Upload no encontrado en el storage');
    }

    const updated = await this.prisma.fileRecord.update({
      where: { id: fileId },
      data: { status: FileStatus.UPLOADED, uploadedAt: new Date() },
    });
    const response = toFileResponse(updated);
    this.realtime.emitToUser(userId, EVENTS.fileReady, { file: response });
    return response;
  }

  async remove(userId: string, fileId: string): Promise<{ success: true }> {
    const file = await this.findOwnedFile(userId, fileId);
    await this.storage.deleteObject(objectKey(userId, fileId, file.name)).catch(() => undefined);
    await this.prisma.fileRecord.delete({ where: { id: fileId } });
    return { success: true };
  }

  async purgeStalePendingFiles(): Promise<number> {
    const cutoff = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
    const stale = await this.prisma.fileRecord.findMany({
      where: { status: FileStatus.PENDING, createdAt: { lt: cutoff } },
    });
    for (const file of stale) {
      await this.storage.deleteObject(objectKey(file.userId, file.id, file.name)).catch(() => undefined);
    }
    const result = await this.prisma.fileRecord.deleteMany({
      where: { id: { in: stale.map((f) => f.id) } },
    });
    return result.count;
  }

  private async findOwnedFile(userId: string, fileId: string): Promise<FileRecord> {
    const file = await this.prisma.fileRecord.findFirst({
      where: { id: fileId, userId },
    });
    if (!file) {
      throw new NotFoundException('File not found');
    }
    return file;
  }
}
