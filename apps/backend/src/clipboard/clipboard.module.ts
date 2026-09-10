import { Module } from '@nestjs/common';
import { PrismaModule } from '../prisma/prisma.module.js';
import { RealtimeModule } from '../realtime/realtime.module.js';
import { PlansModule } from '../plans/plans.module.js';
import { ClipboardController } from './clipboard.controller.js';
import { ClipboardService } from './clipboard.service.js';

@Module({
  imports: [PrismaModule, RealtimeModule, PlansModule],
  controllers: [ClipboardController],
  providers: [ClipboardService],
  exports: [ClipboardService],
})
export class ClipboardModule {}
