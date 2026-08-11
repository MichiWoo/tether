import { beforeEach, describe, expect, it, vi } from 'vitest';
import { ConflictException, UnauthorizedException } from '@nestjs/common';
import { AuthService } from './auth.service.js';
import type { PrismaService } from '../prisma/prisma.service.js';
import type { JwtService } from '@nestjs/jwt';
import type { ConfigService } from '@nestjs/config';

vi.mock('bcrypt', () => ({
  hash: vi.fn(),
  compare: vi.fn(),
}));

import * as bcrypt from 'bcrypt';

function createMocks() {
  const prisma = {
    user: { findUnique: vi.fn(), create: vi.fn() },
    refreshToken: {
      findUnique: vi.fn(),
      create: vi.fn(),
      update: vi.fn(),
      updateMany: vi.fn(),
    },
    $transaction: vi.fn(async (cb: (tx: unknown) => unknown) => cb(prisma)),
  };
  const jwt = { signAsync: vi.fn(), verifyAsync: vi.fn() };
  const config = { get: vi.fn() };
  config.get.mockImplementation(
    (key: string, def?: unknown) =>
      (
        ({
          JWT_EXPIRES_IN: '15m',
          REFRESH_TOKEN_EXPIRES_IN: '30d',
          REFRESH_TOKEN_SECRET: 'refresh-secret',
          JWT_SECRET: 'jwt-secret',
        }) as Record<string, unknown>
      )[key] ?? def,
  );
  return { prisma, jwt, config };
}

const storedToken = (overrides: Record<string, unknown> = {}) => ({
  id: 'rt1',
  tokenHash: 'hash',
  userId: 'u1',
  expiresAt: new Date(Date.now() + 1000),
  revokedAt: null,
  createdAt: new Date(),
  ...overrides,
});

const user = {
  id: 'u1',
  email: 'a@tether.dev',
  password: 'hash',
  name: 'A',
  createdAt: new Date(),
  updatedAt: new Date(),
};

describe('AuthService', () => {
  let prisma: ReturnType<typeof createMocks>['prisma'];
  let jwt: ReturnType<typeof createMocks>['jwt'];
  let config: ReturnType<typeof createMocks>['config'];
  let service: AuthService;

  beforeEach(() => {
    vi.clearAllMocks();
    const mocks = createMocks();
    prisma = mocks.prisma;
    jwt = mocks.jwt;
    config = mocks.config;
    service = new AuthService(
      prisma as unknown as PrismaService,
      jwt as unknown as JwtService,
      config as unknown as ConfigService,
    );
    vi.mocked(bcrypt.hash).mockResolvedValue('hash' as never);
  });

  describe('register', () => {
    it('lanza ConflictException si el email ya existe', async () => {
      prisma.user.findUnique.mockResolvedValue(user);
      await expect(
        service.register({ email: 'A@Tether.Dev', password: 'supersecret1' }),
      ).rejects.toBeInstanceOf(ConflictException);
    });

    it('crea el usuario con email normalizado y devuelve tokens', async () => {
      prisma.user.findUnique.mockResolvedValue(null);
      prisma.user.create.mockResolvedValue(user);
      jwt.signAsync.mockResolvedValue('access');
      jwt.signAsync.mockResolvedValueOnce('access').mockResolvedValueOnce('refresh');
      prisma.refreshToken.create.mockResolvedValue({});

      const result = await service.register({
        email: 'A@Tether.Dev',
        password: 'supersecret1',
        name: 'A',
      });

      expect(prisma.user.create).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({ email: 'a@tether.dev' }),
        }),
      );
      expect(result).toEqual({
        accessToken: 'access',
        refreshToken: 'refresh',
        user: { id: 'u1', email: 'a@tether.dev', name: 'A' },
      });
    });
  });

  describe('login', () => {
    it('lanza UnauthorizedException si el usuario no existe', async () => {
      prisma.user.findUnique.mockResolvedValue(null);
      await expect(
        service.login({ email: 'a@tether.dev', password: 'supersecret1' }),
      ).rejects.toBeInstanceOf(UnauthorizedException);
    });

    it('lanza UnauthorizedException si la contraseña no coincide', async () => {
      prisma.user.findUnique.mockResolvedValue(user);
      vi.mocked(bcrypt.compare).mockResolvedValue(false as never);
      await expect(
        service.login({ email: 'a@tether.dev', password: 'supersecret1' }),
      ).rejects.toBeInstanceOf(UnauthorizedException);
    });
  });

  describe('refresh', () => {
    it('lanza 401 si el token no es válido', async () => {
      jwt.verifyAsync.mockRejectedValue(new Error('bad'));
      await expect(service.refresh('token')).rejects.toBeInstanceOf(UnauthorizedException);
    });

    it('revoca TODOS los tokens del usuario si detecta reuso (token ya revocado)', async () => {
      jwt.verifyAsync.mockResolvedValue({ sub: 'u1', jti: 'j' });
      prisma.refreshToken.findUnique.mockResolvedValue(storedToken({ revokedAt: new Date() }));
      await expect(service.refresh('token')).rejects.toBeInstanceOf(UnauthorizedException);
      expect(prisma.refreshToken.updateMany).toHaveBeenCalledWith({
        where: { userId: 'u1' },
        data: { revokedAt: expect.any(Date) },
      });
    });

    it('rota el token de forma atómica (revoca + emite par nuevo en transacción)', async () => {
      jwt.verifyAsync.mockResolvedValue({ sub: 'u1', jti: 'j' });
      prisma.refreshToken.findUnique.mockResolvedValue(storedToken());
      prisma.user.findUnique.mockResolvedValue(user);
      jwt.signAsync.mockResolvedValueOnce('access').mockResolvedValueOnce('refresh');
      prisma.refreshToken.create.mockResolvedValue({});

      const result = await service.refresh('token');

      expect(prisma.$transaction).toHaveBeenCalled();
      expect(prisma.refreshToken.update).toHaveBeenCalledWith({
        where: { id: 'rt1' },
        data: { revokedAt: expect.any(Date) },
      });
      expect(result).toEqual({ accessToken: 'access', refreshToken: 'refresh' });
    });
  });
});
