import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Redis } from 'ioredis';
import { PrismaService } from '../prisma/prisma.service.js';
import { StorageService } from '../storage/storage.service.js';

export type DependencyStatus = 'up' | 'down';

export interface HealthChecks {
  database: DependencyStatus;
  redis: DependencyStatus;
  storage: DependencyStatus;
}

export interface HealthStatus {
  status: 'ok' | 'error';
  name: string;
  version: string;
  uptime: number;
  timestamp: string;
  checks: HealthChecks;
}

@Injectable()
export class HealthService {
  private readonly redis: Redis;

  constructor(
    configService: ConfigService,
    private readonly prisma: PrismaService,
    private readonly storage: StorageService,
  ) {
    this.redis = new Redis({
      host: configService.get<string>('REDIS_HOST', 'localhost'),
      port: Number(configService.get<string>('REDIS_PORT', '6379')),
      lazyConnect: true,
      maxRetriesPerRequest: 1,
      retryStrategy: () => null,
    });
  }

  async getStatus(): Promise<HealthStatus> {
    const [database, redis, storage] = await Promise.allSettled([
      this.prisma.$queryRaw`SELECT 1`,
      this.redis.ping(),
      this.storage.checkConnection(),
    ]);

    const checks: HealthChecks = {
      database: database.status === 'fulfilled' ? 'up' : 'down',
      redis: redis.status === 'fulfilled' ? 'up' : 'down',
      storage: storage.status === 'fulfilled' ? 'up' : 'down',
    };

    return {
      status: Object.values(checks).includes('down') ? 'error' : 'ok',
      name: 'tether-api',
      version: process.env.npm_package_version ?? '0.1.0',
      uptime: process.uptime(),
      timestamp: new Date().toISOString(),
      checks,
    };
  }
}
