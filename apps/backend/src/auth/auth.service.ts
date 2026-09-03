import { ConflictException, Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';
import { randomUUID, createHash } from 'node:crypto';
import { Prisma, PrismaClient } from '../generated/prisma/client.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { RegisterDto } from './dto/register.dto.js';
import { LoginDto } from './dto/login.dto.js';
import { UpdateProfileDto } from './dto/update-profile.dto.js';
import { UpdatePasswordDto } from './dto/update-password.dto.js';
import type { AuthResponse, AuthTokens, JwtPayload, JwtUser } from './auth.types.js';

const BCRYPT_ROUNDS = 12;

type DbClient = PrismaClient | Prisma.TransactionClient;

@Injectable()
export class AuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly jwtService: JwtService,
    private readonly configService: ConfigService,
  ) {}

  async register(dto: RegisterDto): Promise<AuthResponse> {
    const existing = await this.prisma.user.findUnique({
      where: { email: dto.email.toLowerCase() },
    });
    if (existing) {
      throw new ConflictException('Email already registered');
    }

    const passwordHash = await bcrypt.hash(dto.password, BCRYPT_ROUNDS);
    const user = await this.prisma.user.create({
      data: {
        email: dto.email.toLowerCase(),
        password: passwordHash,
        name: dto.name ?? null,
      },
    });

    const tokens = await this.issueTokens(user.id, user.email);
    return { ...tokens, user: this.toPublicUser(user) };
  }

  async login(dto: LoginDto): Promise<AuthResponse> {
    const user = await this.prisma.user.findUnique({
      where: { email: dto.email.toLowerCase() },
    });
    if (!user) {
      throw new UnauthorizedException('Invalid credentials');
    }

    const valid = await bcrypt.compare(dto.password, user.password);
    if (!valid) {
      throw new UnauthorizedException('Invalid credentials');
    }

    const tokens = await this.issueTokens(user.id, user.email);
    return { ...tokens, user: this.toPublicUser(user) };
  }

  async refresh(refreshToken: string): Promise<AuthTokens> {
    let payload: JwtPayload;
    try {
      payload = await this.jwtService.verifyAsync<JwtPayload>(refreshToken, {
        secret: this.configService.get<string>('REFRESH_TOKEN_SECRET'),
      });
    } catch {
      throw new UnauthorizedException('Invalid refresh token');
    }

    const tokenHash = this.hashToken(refreshToken);
    const stored = await this.prisma.refreshToken.findUnique({
      where: { tokenHash },
    });

    if (!stored || stored.expiresAt < new Date()) {
      throw new UnauthorizedException('Invalid refresh token');
    }

    if (stored.revokedAt !== null) {
      // Token reutilizado: posible sesión comprometida → se revocan todos los del usuario
      await this.prisma.refreshToken.updateMany({
        where: { userId: stored.userId },
        data: { revokedAt: new Date() },
      });
      throw new UnauthorizedException('Invalid refresh token');
    }

    const user = await this.prisma.user.findUnique({
      where: { id: payload.sub },
    });
    if (!user) {
      throw new UnauthorizedException('Invalid refresh token');
    }

    // Revocar el token actual y emitir el par nuevo de forma atómica
    return this.prisma.$transaction(async (tx) => {
      await tx.refreshToken.update({
        where: { id: stored.id },
        data: { revokedAt: new Date() },
      });
      return this.issueTokens(user.id, user.email, tx);
    });
  }

  async logout(refreshToken: string): Promise<void> {
    const tokenHash = this.hashToken(refreshToken);
    const stored = await this.prisma.refreshToken.findUnique({
      where: { tokenHash },
    });
    if (stored && stored.revokedAt === null) {
      await this.prisma.refreshToken.update({
        where: { id: stored.id },
        data: { revokedAt: new Date() },
      });
    }
  }

  async getMe(userId: string): Promise<JwtUser> {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) {
      throw new UnauthorizedException('User not found');
    }
    return this.toPublicUser(user);
  }

  async updateProfile(userId: string, dto: UpdateProfileDto): Promise<JwtUser> {
    const data: { name?: string | null; avatarUrl?: string | null } = {};
    if (dto.name !== undefined) {
      data.name = dto.name.trim().length > 0 ? dto.name.trim() : null;
    }
    if (dto.avatarUrl !== undefined) {
      const trimmed = dto.avatarUrl.trim();
      data.avatarUrl = trimmed.length > 0 ? trimmed : null;
    }

    const user = await this.prisma.user.update({
      where: { id: userId },
      data,
    });
    return this.toPublicUser(user);
  }

  async updatePassword(userId: string, dto: UpdatePasswordDto): Promise<{ success: true }> {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) {
      throw new UnauthorizedException('User not found');
    }

    const valid = await bcrypt.compare(dto.currentPassword, user.password);
    if (!valid) {
      throw new UnauthorizedException('Current password is incorrect');
    }

    const passwordHash = await bcrypt.hash(dto.newPassword, BCRYPT_ROUNDS);
    await this.prisma.user.update({
      where: { id: userId },
      data: { password: passwordHash },
    });
    return { success: true };
  }

  private async issueTokens(
    userId: string,
    email: string,
    client: DbClient = this.prisma,
  ): Promise<AuthTokens> {
    const accessExpiresIn = this.durationToSeconds(
      this.configService.get<string>('JWT_EXPIRES_IN', '15m'),
    );
    const accessToken = await this.jwtService.signAsync(
      { sub: userId, email } satisfies JwtPayload,
      { expiresIn: accessExpiresIn },
    );

    const refreshExpiresIn = this.durationToSeconds(
      this.configService.get<string>('REFRESH_TOKEN_EXPIRES_IN', '30d'),
    );
    const jti = randomUUID();
    const refreshToken = await this.jwtService.signAsync(
      { sub: userId, jti },
      {
        secret: this.configService.get<string>('REFRESH_TOKEN_SECRET'),
        expiresIn: refreshExpiresIn,
      },
    );

    const expiresAt = new Date(Date.now() + refreshExpiresIn * 1000);

    await client.refreshToken.create({
      data: {
        tokenHash: this.hashToken(refreshToken),
        userId,
        expiresAt,
      },
    });

    return { accessToken, refreshToken };
  }

  private hashToken(token: string): string {
    return createHash('sha256').update(token).digest('hex');
  }

  private parseDuration(value: string): number {
    const match = /^(\d+)([smhd])$/.exec(value);
    if (!match) return 30 * 24 * 60 * 60 * 1000;
    const amount = Number(match[1]);
    const unit = match[2];
    const multipliers: Record<string, number> = {
      s: 1000,
      m: 60 * 1000,
      h: 60 * 60 * 1000,
      d: 24 * 60 * 60 * 1000,
    };
    return amount * multipliers[unit];
  }

  private durationToSeconds(value: string): number {
    return Math.floor(this.parseDuration(value) / 1000);
  }

  private toPublicUser(user: {
    id: string;
    email: string;
    name: string | null;
    avatarUrl: string | null;
  }): JwtUser {
    return {
      id: user.id,
      email: user.email,
      name: user.name ?? undefined,
      avatarUrl: user.avatarUrl,
      gravatarUrl: this.gravatarUrl(user.email),
    };
  }

  private gravatarUrl(email: string): string {
    const hash = createHash('md5').update(email.trim().toLowerCase()).digest('hex');
    return `https://www.gravatar.com/avatar/${hash}?d=retro&s=256`;
  }
}
