import { Module } from '@nestjs/common';
import { RealtimeModule } from '../realtime/realtime.module.js';
import { FilesController } from './files.controller.js';
import { FilesService } from './files.service.js';

@Module({
  imports: [RealtimeModule],
  controllers: [FilesController],
  providers: [FilesService],
  exports: [FilesService],
})
export class FilesModule {}
