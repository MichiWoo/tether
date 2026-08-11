import { Module } from '@nestjs/common';
import { RealtimeModule } from '../realtime/realtime.module.js';
import { ClipboardController } from './clipboard.controller.js';
import { ClipboardService } from './clipboard.service.js';

@Module({
  imports: [RealtimeModule],
  controllers: [ClipboardController],
  providers: [ClipboardService],
  exports: [ClipboardService],
})
export class ClipboardModule {}
