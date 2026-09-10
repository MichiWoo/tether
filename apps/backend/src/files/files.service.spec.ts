import { beforeEach, describe, expect, it, vi } from 'vitest';
import { BadRequestException, NotFoundException } from '@nestjs/common';
import { FilesService } from './files.service.js';
import type { PrismaService } from '../prisma/prisma.service.js';
import type { StorageService } from '../storage/storage.service.js';
import type { RealtimeService } from '../realtime/realtime.service.js';
import type { PlansService } from '../plans/plans.service.js';

const file = {
  id: 'f1',
  userId: 'u1',
  name: 'foto.jpg',
  size: 12,
  mimeType: 'image/jpeg',
  checksum: null,
  status: 'PENDING',
  uploadedAt: null,
  createdAt: new Date(),
  updatedAt: new Date(),
};

function createMocks() {
  const prisma = {
    fileRecord: {
      create: vi.fn(),
      findMany: vi.fn(),
      findFirst: vi.fn(),
      update: vi.fn(),
      delete: vi.fn(),
    },
  };
  const storage = {
    getPresignedUploadUrl: vi.fn(),
    getPresignedDownloadUrl: vi.fn(),
    objectExists: vi.fn(),
    deleteObject: vi.fn(),
  };
  const realtime = { emitToUser: vi.fn() };
  const plans = {
    assertFileUpload: vi.fn().mockResolvedValue(undefined),
  };
  return { prisma, storage, realtime, plans };
}

describe('FilesService', () => {
  let prisma: ReturnType<typeof createMocks>['prisma'];
  let storage: ReturnType<typeof createMocks>['storage'];
  let realtime: ReturnType<typeof createMocks>['realtime'];
  let plans: ReturnType<typeof createMocks>['plans'];
  let service: FilesService;

  beforeEach(() => {
    vi.clearAllMocks();
    const mocks = createMocks();
    prisma = mocks.prisma;
    storage = mocks.storage;
    realtime = mocks.realtime;
    plans = mocks.plans;
    service = new FilesService(
      prisma as unknown as PrismaService,
      storage as unknown as StorageService,
      realtime as unknown as RealtimeService,
      plans as unknown as PlansService,
    );
  });

  describe('create', () => {
    it('crea el registro y devuelve presigned PUT URL + headers', async () => {
      prisma.fileRecord.create.mockResolvedValue(file);
      storage.getPresignedUploadUrl.mockResolvedValue('http://upload');

      const result = await service.create('u1', {
        name: 'foto.jpg',
        size: 12,
        mimeType: 'image/jpeg',
      });

      expect(prisma.fileRecord.create).toHaveBeenCalledWith(
        expect.objectContaining({ data: expect.objectContaining({ userId: 'u1' }) }),
      );
      expect(result).toMatchObject({
        upload: { method: 'PUT', headers: { 'Content-Type': 'image/jpeg' } },
      });
      expect(result.upload.url).toBe('http://upload');
    });
  });

  describe('getDownload', () => {
    it('lanza 404 si el archivo no es del usuario', async () => {
      prisma.fileRecord.findFirst.mockResolvedValue(null);
      await expect(service.getDownload('u1', 'f1')).rejects.toBeInstanceOf(NotFoundException);
    });

    it('lanza 400 si el archivo no está UPLOADED', async () => {
      prisma.fileRecord.findFirst.mockResolvedValue(file);
      await expect(service.getDownload('u1', 'f1')).rejects.toBeInstanceOf(BadRequestException);
    });

    it('devuelve presigned GET URL si está UPLOADED', async () => {
      prisma.fileRecord.findFirst.mockResolvedValue({
        ...file,
        status: 'UPLOADED',
        uploadedAt: new Date(),
      });
      storage.getPresignedDownloadUrl.mockResolvedValue('http://download');

      const result = await service.getDownload('u1', 'f1');

      expect(result.downloadUrl).toBe('http://download');
      expect(result.file.status).toBe('UPLOADED');
    });
  });

  describe('getPreview', () => {
    it('pide la URL con disposición inline', async () => {
      prisma.fileRecord.findFirst.mockResolvedValue({
        ...file,
        status: 'UPLOADED',
        uploadedAt: new Date(),
      });
      storage.getPresignedDownloadUrl.mockResolvedValue('http://preview');

      const result = await service.getPreview('u1', 'f1');

      expect(result.downloadUrl).toBe('http://preview');
      expect(storage.getPresignedDownloadUrl).toHaveBeenCalledWith(
        'users/u1/f1/foto.jpg',
        'foto.jpg',
        expect.any(Number),
        'inline',
      );
    });

    it('lanza 400 si el archivo no está UPLOADED', async () => {
      prisma.fileRecord.findFirst.mockResolvedValue(file);
      await expect(service.getPreview('u1', 'f1')).rejects.toBeInstanceOf(BadRequestException);
    });
  });

  describe('complete', () => {
    it('lanza 400 si el objeto no existe en storage', async () => {
      prisma.fileRecord.findFirst.mockResolvedValue(file);
      storage.objectExists.mockResolvedValue(false);
      await expect(service.complete('u1', 'f1')).rejects.toBeInstanceOf(BadRequestException);
    });

    it('marca UPLOADED y emite file.ready', async () => {
      prisma.fileRecord.findFirst.mockResolvedValue(file);
      storage.objectExists.mockResolvedValue(true);
      prisma.fileRecord.update.mockResolvedValue({
        ...file,
        status: 'UPLOADED',
        uploadedAt: new Date(),
      });

      const result = await service.complete('u1', 'f1');

      expect(result.status).toBe('UPLOADED');
      expect(realtime.emitToUser).toHaveBeenCalledWith(
        'u1',
        'file.ready',
        expect.objectContaining({ file: expect.objectContaining({ id: 'f1' }) }),
      );
    });
  });

  describe('remove', () => {
    it('borra objeto de storage y el registro', async () => {
      storage.deleteObject.mockResolvedValue(undefined);
      prisma.fileRecord.findFirst.mockResolvedValue(file);
      await service.remove('u1', 'f1');
      expect(storage.deleteObject).toHaveBeenCalledWith('users/u1/f1/foto.jpg');
      expect(prisma.fileRecord.delete).toHaveBeenCalledWith({
        where: { id: 'f1' },
      });
    });
  });
});
