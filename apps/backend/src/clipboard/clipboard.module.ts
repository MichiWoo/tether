import { Module } from '@nestjs/common';
import { ClipboardController } from './clipboard.controller.js';
import { ClipboardService } from './clipboard.service.js';

@Module({
  controllers: [ClipboardController],
  providers: [ClipboardService],
  exports: [ClipboardService],
})
export class ClipboardModule {}
