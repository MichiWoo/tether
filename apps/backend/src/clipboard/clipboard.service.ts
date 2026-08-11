import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service.js';
import { RealtimeService } from '../realtime/realtime.service.js';
import { PushClipboardDto } from './dto/push-clipboard.dto.js';
import { ClipboardItemResponse } from './clipboard.types.js';

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

    const latest = await this.prisma.clipboardItem.findFirst({
      where: { userId, sourceDeviceId: dto.sourceDeviceId ?? null },
      orderBy: { createdAt: 'desc' },
      include: { sourceDevice: true },
    });

    if (latest && latest.content === dto.content) {
      return this.toResponse(latest);
    }

    const item = await this.prisma.clipboardItem.create({
      data: {
        userId,
        content: dto.content,
        sourceDeviceId: dto.sourceDeviceId ?? null,
      },
      include: { sourceDevice: true },
    });
    const response = this.toResponse(item);
    this.realtime.emitToUser(userId, 'clipboard.updated', {
      item: response,
      sourceDeviceId: response.sourceDeviceId,
    });
    return response;
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
