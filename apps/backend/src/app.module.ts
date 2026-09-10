import { Module } from '@nestjs/common';
import { APP_GUARD } from '@nestjs/core';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { BullModule } from '@nestjs/bullmq';
import { ThrottlerModule, ThrottlerGuard } from '@nestjs/throttler';
import { LoggerModule } from 'nestjs-pino';
import { AppController } from './app.controller.js';
import { AppService } from './app.service.js';
import { envValidationOptions, envValidationSchema } from './config/env.validation.js';
import { PrismaModule } from './prisma/prisma.module.js';
import { StorageModule } from './storage/storage.module.js';
import { HealthModule } from './health/health.module.js';
import { AuthModule } from './auth/auth.module.js';
import { DevicesModule } from './devices/devices.module.js';
import { ClipboardModule } from './clipboard/clipboard.module.js';
import { FilesModule } from './files/files.module.js';
import { RealtimeModule } from './realtime/realtime.module.js';
import { TransfersModule } from './transfers/transfers.module.js';
import { StatsModule } from './stats/stats.module.js';
import { ReleasesModule } from './releases/releases.module.js';
import { PlansModule } from './plans/plans.module.js';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      envFilePath: ['.env', '.env.local'],
      validationSchema: envValidationSchema,
      validationOptions: envValidationOptions,
    }),
    ThrottlerModule.forRoot([
      {
        ttl: 60_000,
        limit: 100,
      },
    ]),
    LoggerModule.forRootAsync({
      inject: [ConfigService],
      useFactory: (configService: ConfigService) => ({
        pinoHttp: {
          level: configService.get<string>('LOG_LEVEL', 'info'),
          transport:
            configService.get<string>('NODE_ENV', 'development') === 'development'
              ? {
                  target: 'pino-pretty',
                  options: { singleLine: true },
                }
              : undefined,
          autoLogging: {
            ignore: (req) => req.url === '/health',
          },
        },
      }),
    }),
    BullModule.forRootAsync({
      inject: [ConfigService],
      useFactory: (configService: ConfigService) => ({
        connection: {
          host: configService.get<string>('REDIS_HOST', 'localhost'),
          port: Number(configService.get<string>('REDIS_PORT', '6379')),
        },
      }),
    }),
    PrismaModule,
    StorageModule,
    HealthModule,
    AuthModule,
    DevicesModule,
    ClipboardModule,
    FilesModule,
    RealtimeModule,
    TransfersModule,
    StatsModule,
    ReleasesModule,
    PlansModule,
  ],
  controllers: [AppController],
  providers: [
    AppService,
    {
      provide: APP_GUARD,
      useClass: ThrottlerGuard,
    },
  ],
})
export class AppModule {}
