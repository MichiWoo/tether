import { Processor, WorkerHost } from '@nestjs/bullmq';
import { Job } from 'bullmq';
import {
  TransfersService,
  JOB_EXPIRE_SHARES,
  JOB_SHARE_CREATED,
  QUEUE_TRANSFERS,
} from './transfers.service.js';

@Processor(QUEUE_TRANSFERS)
export class TransfersProcessor extends WorkerHost {
  constructor(private readonly transfersService: TransfersService) {
    super();
  }

  async process(job: Job): Promise<void> {
    switch (job.name) {
      case JOB_SHARE_CREATED:
        await this.transfersService.notifyShareCreated(job.data.shareId as string);
        break;
      case JOB_EXPIRE_SHARES:
        await this.transfersService.expireOverdue();
        break;
      default:
        break;
    }
  }
}
