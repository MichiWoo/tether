import { Module } from '@nestjs/common';
import { PrismaModule } from '../prisma/prisma.module.js';
import { PlansController } from './plans.controller.js';
import { AdminController } from './admin.controller.js';
import { PlansService } from './plans.service.js';

@Module({
  imports: [PrismaModule],
  controllers: [PlansController, AdminController],
  providers: [PlansService],
  exports: [PlansService],
})
export class PlansModule {}
