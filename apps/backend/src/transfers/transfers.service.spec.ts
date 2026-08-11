import { beforeEach, describe, expect, it, vi } from 'vitest';
import { BadRequestException, NotFoundException } from '@nestjs/common';
import { TransfersService, JOB_EXPIRE_SHARES, JOB_SHARE_CREATED } from './transfers.service.js';
import type { PrismaService } from '../prisma/prisma.service.js';
import type { StorageService } from '../storage/storage.service.js';
import type { RealtimeService } from '../realtime/realtime.service.js';
import type { ConfigService } from '@nestjs/config';
import type { Queue } from 'bullmq';

const uploadedFile = {
  id: 'f1',
  userId: 'u1',
  name: 'a.bin',
  size: 4,
  mimeType: 'application/octet-stream',
  checksum: null,
  status: 'UPLOADED',
  uploadedAt: new Date(),
  createdAt: new Date(),
  updatedAt: new Date(),
};

function createMocks() {
  const prisma = {
    fileRecord: { findFirst: vi.fn(), delete: vi.fn() },
    device: { findFirst: vi.fn() },
    share: {
      create: vi.fn(),
      findMany: vi.fn(),
      findFirst: vi.fn(),
      update: vi.fn(),
      updateMany: vi.fn(),
    },
  };
  const storage = { getPresignedDownloadUrl: vi.fn(), deleteObject: vi.fn() };
  const realtime = { emitToUser: vi.fn(), emitToDevice: vi.fn() };
  const config = { get: vi.fn((_k: string, d?: unknown) => d) };
  const queue = { add: vi.fn() } as unknown as Queue;
  return { prisma, storage, realtime, config, queue };
}

describe('TransfersService', () => {
  let mocks: ReturnType<typeof createMocks>;
  let service: TransfersService;

  beforeEach(() => {
    vi.clearAllMocks();
    mocks = createMocks();
    service = new TransfersService(
      mocks.prisma as unknown as PrismaService,
      mocks.storage as unknown as StorageService,
      mocks.realtime as unknown as RealtimeService,
      mocks.config as unknown as ConfigService,
      mocks.queue,
    );
  });

  describe('createShare', () => {
    it('lanza 404 si el archivo no es del usuario', async () => {
      mocks.prisma.fileRecord.findFirst.mockResolvedValue(null);
      await expect(service.createShare('u1', { fileId: 'f1' })).rejects.toBeInstanceOf(
        NotFoundException,
      );
    });

    it('lanza 400 si el archivo no está subido', async () => {
      mocks.prisma.fileRecord.findFirst.mockResolvedValue({ ...uploadedFile, status: 'PENDING' });
      await expect(service.createShare('u1', { fileId: 'f1' })).rejects.toBeInstanceOf(
        BadRequestException,
      );
    });

    it('crea el share y encola el job share:created', async () => {
      mocks.prisma.fileRecord.findFirst.mockResolvedValue(uploadedFile);
      mocks.prisma.share.create.mockResolvedValue({
        id: 's1',
        userId: 'u1',
        fileId: 'f1',
        targetDeviceId: null,
        status: 'CREATED',
        acceptedAt: null,
        downloadedAt: null,
        expiresAt: new Date(),
        createdAt: new Date(),
        updatedAt: new Date(),
        file: uploadedFile,
      });

      const result = await service.createShare('u1', { fileId: 'f1' });

      expect(mocks.queue.add).toHaveBeenCalledWith(JOB_SHARE_CREATED, { shareId: 's1' });
      expect(result.status).toBe('CREATED');
    });
  });

  describe('expireOverdue', () => {
    it('marca EXPIRED en batch y limpia storage + file', async () => {
      mocks.prisma.share.findMany.mockResolvedValue([
        {
          id: 's1',
          userId: 'u1',
          fileId: 'f1',
          status: 'CREATED',
          file: uploadedFile,
        },
      ]);
      await service.expireOverdue();

      expect(mocks.prisma.share.updateMany).toHaveBeenCalledWith({
        where: { id: { in: ['s1'] } },
        data: { status: 'EXPIRED' },
      });
      expect(mocks.storage.deleteObject).toHaveBeenCalledWith('users/u1/f1');
      expect(mocks.prisma.fileRecord.delete).toHaveBeenCalledWith({ where: { id: 'f1' } });
      expect(mocks.realtime.emitToUser).toHaveBeenCalledWith('u1', 'share.expired', {
        shareId: 's1',
      });
    });

    it('no hace nada si no hay shares vencidos', async () => {
      mocks.prisma.share.findMany.mockResolvedValue([]);
      await service.expireOverdue();
      expect(mocks.prisma.share.updateMany).not.toHaveBeenCalled();
      expect(JOB_EXPIRE_SHARES).toBe('expire-shares');
    });
  });
});
