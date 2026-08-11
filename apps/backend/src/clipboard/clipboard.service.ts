import { Injectable, NotFoundException } from '@nestjs/common';
import { createHash } from 'node:crypto';
import { Prisma } from '../generated/prisma/client.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { RealtimeService } from '../realtime/realtime.service.js';
import { EVENTS } from '../realtime/realtime-events.js';
import { PushClipboardDto } from './dto/push-clipboard.dto.js';
import type { ClipboardItemResponse } from './clipboard.types.js';

const MAX_HISTORY = 100;

@Injectable()
export class ClipboardService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly realtime: RealtimeService,
  ) {}

  async push(userId: string, dto: PushClipboardDto): Promise<ClipboardItemResponse> {
    if (dto.sourceDeviceId) {
      const ownsDevice = await this.prisma.device.findFirst({
        where: { id: dto.sourceDeviceId, userId },
        select: { id: true },
      });
      if (!ownsDevice) {
        throw new NotFoundException('Device not found');
      }
    }

    const sourceDeviceId = dto.sourceDeviceId ?? null;
    const contentHash = this.hashContent(dto.content);

    // Fast path: dedupe por contenido + device
    const latest = await this.prisma.clipboardItem.findFirst({
      where: { userId, sourceDeviceId, contentHash },
      orderBy: { createdAt: 'desc' },
      include: { sourceDevice: true },
    });
    if (latest) {
      return this.toResponse(latest);
    }

    // Red de seguridad ante peticiones concurrentes: el unique index
    // [userId, sourceDeviceId, contentHash] evita duplicados
    try {
      const item = await this.prisma.clipboardItem.create({
        data: {
          userId,
          content: dto.content,
          contentHash,
          sourceDeviceId,
        },
        include: { sourceDevice: true },
      });
      const response = this.toResponse(item);
      this.realtime.emitToUser(userId, EVENTS.clipboardUpdated, {
        item: response,
        sourceDeviceId: response.sourceDeviceId,
      });
      return response;
    } catch (err) {
      if (err instanceof Prisma.PrismaClientKnownRequestError && err.code === 'P2002') {
        const existing = await this.prisma.clipboardItem.findFirst({
          where: { userId, sourceDeviceId, contentHash },
          include: { sourceDevice: true },
        });
        if (existing) {
          return this.toResponse(existing);
        }
      }
      throw err;
    }
  }

  async getLatest(userId: string): Promise<ClipboardItemResponse | null> {
    const item = await this.prisma.clipboardItem.findFirst({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      include: { sourceDevice: true },
    });
    return item ? this.toResponse(item) : null;
  }

  async getHistory(userId: string, limit = 20): Promise<ClipboardItemResponse[]> {
    const safeLimit = Math.min(Math.max(limit, 1), MAX_HISTORY);
    const items = await this.prisma.clipboardItem.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      take: safeLimit,
      include: { sourceDevice: true },
    });
    return items.map((item) => this.toResponse(item));
  }

  private hashContent(content: string): string {
    return createHash('sha256').update(content).digest('hex');
  }

  private toResponse(item: {
    id: string;
    content: string;
    sourceDeviceId: string | null;
    createdAt: Date;
    sourceDevice: { name: string } | null;
  }): ClipboardItemResponse {
    return {
      id: item.id,
      content: item.content,
      sourceDeviceId: item.sourceDeviceId,
      sourceDeviceName: item.sourceDevice?.name ?? null,
      createdAt: item.createdAt.toISOString(),
    };
  }
}
