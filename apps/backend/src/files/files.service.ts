import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service.js';
import { StorageService } from '../storage/storage.service.js';
import { RealtimeService } from '../realtime/realtime.service.js';
import { FileRecord, FileStatus } from '../generated/prisma/client.js';
import { CreateFileDto } from './dto/create-file.dto.js';
import { CreateFileResponse, FileDownloadResponse, FileResponse } from './file.types.js';

const MAX_LIST = 100;
const DOWNLOAD_URL_TTL = 3600;

@Injectable()
export class FilesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly storage: StorageService,
    private readonly realtime: RealtimeService,
  ) {}

  async create(userId: string, dto: CreateFileDto): Promise<CreateFileResponse> {
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
      this.objectKey(userId, file.id),
      file.mimeType ?? 'application/octet-stream',
    );

    return {
      file: this.toResponse(file),
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
    return files.map((file) => this.toResponse(file));
  }

  async getDownload(userId: string, fileId: string): Promise<FileDownloadResponse> {
    const file = await this.findOwnedFile(userId, fileId);
    if (file.status !== FileStatus.UPLOADED) {
      throw new BadRequestException('File is not uploaded yet');
    }
    const downloadUrl = await this.storage.getPresignedDownloadUrl(
      this.objectKey(userId, file.id),
      file.name,
      DOWNLOAD_URL_TTL,
    );
    return {
      file: this.toResponse(file),
      downloadUrl,
      expiresIn: DOWNLOAD_URL_TTL,
    };
  }

  async complete(userId: string, fileId: string): Promise<FileResponse> {
    const file = await this.findOwnedFile(userId, fileId);
    if (file.status === FileStatus.UPLOADED) {
      return this.toResponse(file);
    }

    const exists = await this.storage.objectExists(this.objectKey(userId, fileId));
    if (!exists) {
      throw new BadRequestException('Upload no encontrado en el storage');
    }

    const updated = await this.prisma.fileRecord.update({
      where: { id: fileId },
      data: { status: FileStatus.UPLOADED, uploadedAt: new Date() },
    });
    const response = this.toResponse(updated);
    this.realtime.emitToUser(userId, 'file.ready', { file: response });
    return response;
  }

  async remove(userId: string, fileId: string): Promise<{ success: true }> {
    await this.findOwnedFile(userId, fileId);
    await this.storage.deleteObject(this.objectKey(userId, fileId)).catch(() => undefined);
    await this.prisma.fileRecord.delete({ where: { id: fileId } });
    return { success: true };
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

  private objectKey(userId: string, fileId: string): string {
    return `users/${userId}/${fileId}`;
  }

  private toResponse(file: FileRecord): FileResponse {
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
