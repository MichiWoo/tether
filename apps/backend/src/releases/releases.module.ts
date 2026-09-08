import { Module } from '@nestjs/common';
import { ReleasesController } from './releases.controller.js';
import { ReleasesService } from './releases.service.js';
import { ApiKeyGuard } from './api-key.guard.js';

@Module({
  controllers: [ReleasesController],
  providers: [ReleasesService, ApiKeyGuard],
  exports: [ReleasesService],
})
export class ReleasesModule {}
