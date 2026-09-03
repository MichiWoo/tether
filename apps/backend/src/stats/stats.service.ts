import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service.js';
import { FileStatus } from '../generated/prisma/client.js';
import type { StatsResponse } from './stats.types.js';

@Injectable()
export class StatsService {
  constructor(private readonly prisma: PrismaService) {}

  async getStats(userId: string): Promise<StatsResponse> {
    const [filesUploaded, sizeAgg, shares, devices, clipboardItems] = await Promise.all([
      this.prisma.fileRecord.count({ where: { userId, status: FileStatus.UPLOADED } }),
      this.prisma.fileRecord.aggregate({
        where: { userId, status: FileStatus.UPLOADED },
        _sum: { size: true },
      }),
      this.prisma.share.count({ where: { userId } }),
      this.prisma.device.count({ where: { userId } }),
      this.prisma.clipboardItem.count({ where: { userId } }),
    ]);

    return {
      filesUploaded,
      filesTotalSize: sizeAgg._sum.size ?? 0,
      shares,
      devices,
      clipboardItems,
    };
  }
}
