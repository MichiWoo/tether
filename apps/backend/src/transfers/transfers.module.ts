import { Injectable, Module } from '@nestjs/common';
import type { OnModuleInit } from '@nestjs/common';
import { InjectQueue, BullModule } from '@nestjs/bullmq';
import { Queue } from 'bullmq';
import { PrismaModule } from '../prisma/prisma.module.js';
import { RealtimeModule } from '../realtime/realtime.module.js';
import { PlansModule } from '../plans/plans.module.js';
import { TransfersController } from './transfers.controller.js';
import { TransfersProcessor } from './transfers.processor.js';
import { JOB_EXPIRE_SHARES, JOB_PURGE_PENDING, QUEUE_TRANSFERS, TransfersService } from './transfers.service.js';
import { FilesModule } from '../files/files.module.js';

@Injectable()
class ExpireScheduler implements OnModuleInit {
  constructor(@InjectQueue(QUEUE_TRANSFERS) private readonly queue: Queue) {}

  async onModuleInit(): Promise<void> {
    await this.queue.upsertJobScheduler(
      'expire-shares-scheduler',
      { every: 30 * 60 * 1000 },
      { name: JOB_EXPIRE_SHARES, data: {} },
    );
    await this.queue.upsertJobScheduler(
      'purge-pending-scheduler',
      { every: 6 * 60 * 60 * 1000 },
      { name: JOB_PURGE_PENDING, data: {} },
    );
  }
}

@Module({
  imports: [PrismaModule, RealtimeModule, PlansModule, FilesModule, BullModule.registerQueue({ name: QUEUE_TRANSFERS })],
  controllers: [TransfersController],
  providers: [TransfersService, TransfersProcessor, ExpireScheduler],
  exports: [TransfersService],
})
export class TransfersModule {}
