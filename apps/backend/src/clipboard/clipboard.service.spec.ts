import { beforeEach, describe, expect, it, vi } from 'vitest';
import { NotFoundException } from '@nestjs/common';
import { Prisma } from '../generated/prisma/client.js';
import { ClipboardService } from './clipboard.service.js';
import type { PrismaService } from '../prisma/prisma.service.js';
import type { RealtimeService } from '../realtime/realtime.service.js';
import type { PlansService } from '../plans/plans.service.js';

const existingItem = {
  id: 'c1',
  content: 'hola',
  sourceDeviceId: 'd1',
  createdAt: new Date(),
  sourceDevice: { name: 'iPhone' },
};

function createMocks() {
  const prisma = {
    device: { findFirst: vi.fn() },
    clipboardItem: {
      deleteMany: vi.fn().mockResolvedValue({ count: 0 }),
      findFirst: vi.fn(),
      create: vi.fn(),
      findMany: vi.fn().mockResolvedValue([]),
    },
  };
  const realtime = { emitToUser: vi.fn() };
  const plans = {
    getUserPlan: vi.fn().mockResolvedValue('FREE'),
    limitsFor: vi.fn().mockReturnValue({
      clipboardHistoryItems: 50,
      clipboardRetentionDays: 30,
    }),
  };
  return { prisma, realtime, plans };
}

describe('ClipboardService', () => {
  let prisma: ReturnType<typeof createMocks>['prisma'];
  let realtime: ReturnType<typeof createMocks>['realtime'];
  let plans: ReturnType<typeof createMocks>['plans'];
  let service: ClipboardService;

  beforeEach(() => {
    vi.clearAllMocks();
    const mocks = createMocks();
    prisma = mocks.prisma;
    realtime = mocks.realtime;
    plans = mocks.plans;
    service = new ClipboardService(
      prisma as unknown as PrismaService,
      plans as unknown as PlansService,
      realtime as unknown as RealtimeService,
    );
  });

  describe('push', () => {
    it('lanza NotFoundException si el sourceDevice no es del usuario', async () => {
      prisma.device.findFirst.mockResolvedValue(null);
      await expect(
        service.push('u1', { content: 'x', sourceDeviceId: 'd1' }),
      ).rejects.toBeInstanceOf(NotFoundException);
    });

    it('deduplica por fast path y no crea ni emite', async () => {
      prisma.device.findFirst.mockResolvedValue({ id: 'd1' });
      prisma.clipboardItem.findFirst.mockResolvedValue(existingItem);
      const result = await service.push('u1', {
        content: 'hola',
        sourceDeviceId: 'd1',
      });
      expect(result.id).toBe('c1');
      expect(prisma.clipboardItem.create).not.toHaveBeenCalled();
      expect(realtime.emitToUser).not.toHaveBeenCalled();
    });

    it('crea el item, emite clipboard.updated y devuelve la respuesta', async () => {
      prisma.device.findFirst.mockResolvedValue({ id: 'd1' });
      prisma.clipboardItem.findFirst.mockResolvedValue(null);
      prisma.clipboardItem.create.mockResolvedValue(existingItem);

      const result = await service.push('u1', {
        content: 'hola',
        sourceDeviceId: 'd1',
      });

      expect(prisma.clipboardItem.create).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({
            userId: 'u1',
            sourceDeviceId: 'd1',
            contentHash: expect.stringMatching(/^[a-f0-9]{64}$/),
          }),
        }),
      );
      expect(realtime.emitToUser).toHaveBeenCalledWith(
        'u1',
        'clipboard.updated',
        expect.objectContaining({ sourceDeviceId: 'd1' }),
      );
      expect(result.id).toBe('c1');
    });

    it('si el create falla por P2002 (race), devuelve el item existente', async () => {
      prisma.device.findFirst.mockResolvedValue({ id: 'd1' });
      prisma.clipboardItem.findFirst
        .mockResolvedValueOnce(null)
        .mockResolvedValueOnce(existingItem);
      const err = new Prisma.PrismaClientKnownRequestError('dup', {
        code: 'P2002',
        clientVersion: 'test',
      });
      prisma.clipboardItem.create.mockRejectedValue(err);

      const result = await service.push('u1', {
        content: 'hola',
        sourceDeviceId: 'd1',
      });

      expect(result.id).toBe('c1');
      expect(realtime.emitToUser).not.toHaveBeenCalled();
    });
  });

  describe('getHistory', () => {
    it('respeta el límite máximo y ordena descendente', async () => {
      prisma.clipboardItem.findMany.mockResolvedValue([existingItem]);
      await service.getHistory('u1', 999);
      expect(prisma.clipboardItem.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { userId: 'u1' },
          take: 100,
        }),
      );
    });
  });
});
