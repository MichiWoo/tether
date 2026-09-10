import { beforeEach, describe, expect, it, vi } from 'vitest';
import { PlansService } from './plans.service.js';
import { QuotaExceededException } from './plans.errors.js';
import type { PrismaService } from '../prisma/prisma.service.js';

const GB = 1024 ** 3;
const MB = 1024 ** 2;

function createMocks() {
  return {
    user: {
      findUnique: vi.fn().mockResolvedValue({ plan: 'FREE' }),
      update: vi.fn().mockResolvedValue({ plan: 'PRO' }),
    },
    fileRecord: {
      aggregate: vi.fn().mockResolvedValue({ _sum: { size: 100 * MB } }),
    },
    share: {
      findMany: vi.fn().mockResolvedValue([]),
    },
    device: {
      count: vi.fn().mockResolvedValue(2),
    },
    clipboardItem: {
      count: vi.fn().mockResolvedValue(10),
    },
  };
}

describe('PlansService', () => {
  let prisma: ReturnType<typeof createMocks>;
  let service: PlansService;

  beforeEach(() => {
    vi.clearAllMocks();
    prisma = createMocks();
    service = new PlansService(prisma as unknown as PrismaService);
  });

  describe('getUserPlan', () => {
    it('devuelve el plan del usuario', async () => {
      expect(await service.getUserPlan('u1')).toBe('FREE');
      expect(prisma.user.findUnique).toHaveBeenCalledWith({
        where: { id: 'u1' },
        select: { plan: true },
      });
    });

    it('lanza 404 si el usuario no existe', async () => {
      prisma.user.findUnique.mockResolvedValue(null);
      await expect(service.getUserPlan('u0')).rejects.toThrow('User not found');
    });
  });

  describe('limitsFor', () => {
    it('devuelve límites por plan', () => {
      expect(service.limitsFor('FREE').maxStorageBytes).toBe(2 * GB);
      expect(service.limitsFor('PRO').maxStorageBytes).toBe(50 * GB);
      expect(service.limitsFor('UNLIMITS').maxStorageBytes).toBe(500 * GB);
      expect(service.limitsFor('FREE').maxDevices).toBe(3);
      expect(service.limitsFor('UNLIMITS').shareTtlDays).toBe(90);
    });
  });

  describe('usage', () => {
    it('agrega storage, traspaso, dispositivos e clipboards', async () => {
      prisma.share.findMany.mockResolvedValue([
        { file: { size: 300 * MB } },
        { file: { size: 200 * MB } },
      ]);
      const usage = await service.usage('u1');
      expect(usage.plan).toBe('FREE');
      expect(usage.storageUsedBytes).toBe(100 * MB);
      expect(usage.transferUsedThisMonthBytes).toBe(500 * MB);
      expect(usage.devicesUsed).toBe(2);
      expect(usage.clipboardItemsUsed).toBe(10);
      expect(usage.limits.maxStorageBytes).toBe(2 * GB);
      expect(new Date(usage.monthlyTransferWindow.start).getUTCDate()).toBe(1);
    });
  });

  describe('assertFileUpload', () => {
    it('deja pasar un archivo dentro de los límites', async () => {
      prisma.fileRecord.aggregate.mockResolvedValue({ _sum: { size: 100 * MB } });
      await expect(service.assertFileUpload('u1', 100 * MB)).resolves.toBeUndefined();
    });

    it('lanza QUOTA_FILE_TOO_LARGE (413) si el archivo excede el máximo del plan', async () => {
      const err = service.assertFileUpload('u1', 200 * MB);
      await expect(err).rejects.toMatchObject({
        code: 'QUOTA_FILE_TOO_LARGE',
        response: expect.objectContaining({ maxFileSizeBytes: 100 * MB }),
      });
    });

    it('lanza QUOTA_STORAGE_EXCEEDED (413) si no hay espacio', async () => {
      // archivo de 90 MB (cabe como archivo) sobre 1990 MB usados → pasa el techo de 2 GB
      prisma.fileRecord.aggregate.mockResolvedValue({ _sum: { size: 1990 * MB } });
      await expect(service.assertFileUpload('u1', 90 * MB)).rejects.toMatchObject({
        code: 'QUOTA_STORAGE_EXCEEDED',
        response: expect.objectContaining({ maxStorageBytes: 2 * GB, storageUsedBytes: 1990 * MB }),
      });
    });

    it('excepciones de cuota son QuotaExceededException', async () => {
      await expect(service.assertFileUpload('u1', 900 * GB)).rejects.toBeInstanceOf(QuotaExceededException);
    });
  });

  describe('assertDeviceRegister', () => {
    it('deja registrar debajo del límite', async () => {
      await expect(service.assertDeviceRegister('u1')).resolves.toBeUndefined();
    });

    it('lanza QUOTA_DEVICE_LIMIT (409) al alcanzar el límite', async () => {
      prisma.device.count.mockResolvedValue(3);
      await expect(service.assertDeviceRegister('u1')).rejects.toMatchObject({
        code: 'QUOTA_DEVICE_LIMIT',
        response: expect.objectContaining({ maxDevices: 3 }),
      });
    });
  });

  describe('assertTransfer', () => {
    it('deja pasar dentro de la cuota mensual', async () => {
      await expect(service.assertTransfer('u1', 100 * MB)).resolves.toBeUndefined();
    });

    it('lanza QUOTA_TRANSFER_EXCEEDED (409) al superar la cuota', async () => {
      prisma.share.findMany.mockResolvedValue([
        { file: { size: 4 * GB + 900 * MB } },
      ]);
      await expect(service.assertTransfer('u1', 200 * MB)).rejects.toMatchObject({
        code: 'QUOTA_TRANSFER_EXCEEDED',
      });
    });
  });

  describe('setPlan', () => {
    it('actualiza el plan del usuario y lo devuelve', async () => {
      expect(await service.setPlan('u1', 'PRO')).toBe('PRO');
      expect(prisma.user.update).toHaveBeenCalledWith({
        where: { id: 'u1' },
        data: { plan: 'PRO', planChangedAt: expect.any(Date) },
      });
    });
  });
});
