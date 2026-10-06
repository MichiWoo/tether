import { Controller, Get, Body, Put, UseGuards } from '@nestjs/common';
import { HttpCode } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiProperty, ApiTags } from '@nestjs/swagger';
import { IsIn } from 'class-validator';
import type { PlanName } from '@tether/protocol';
import { PLAN_CODES } from '@tether/protocol';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard.js';
import { CurrentUser } from '../auth/decorators/current-user.decorator.js';
import type { JwtUser } from '../auth/auth.types.js';
import type { PlanUsageResponse } from '@tether/protocol';
import { PlansService } from './plans.service.js';
import { AdminKeyGuard } from './admin-key.guard.js';

export class SetPlanDto {
  @ApiProperty({ enum: PLAN_CODES, example: 'PRO' })
  @IsIn(PLAN_CODES)
  plan: PlanName;
}

@ApiTags('me')
@ApiBearerAuth('access-token')
@Controller('me')
@UseGuards(JwtAuthGuard)
export class PlansController {
  constructor(private readonly plansService: PlansService) {}

  @Get('usage')
  @ApiOperation({ summary: 'Uso actual del plan (storage, traspaso del mes, dispositivos, clipboards)' })
  usage(@CurrentUser() user: JwtUser): Promise<PlanUsageResponse> {
    return this.plansService.usage(user.id);
  }

  @Put('plan')
  @ApiOperation({
    summary: 'Cambiar el propio plan (requiere X-Plan-Admin-Key)',
    description: 'Activación manual hasta integrar pasarela de pagos.',
  })
  @UseGuards(AdminKeyGuard)
  @HttpCode(200)
  setPlan(
    @CurrentUser() user: JwtUser,
    @Body() dto: SetPlanDto,
  ): Promise<{ plan: PlanName }> {
    // La key la valida AdminKeyGuard; no hace falta seguir consultándola aquí.
    return this.plansService.setPlan(user.id, dto.plan).then((plan) => ({ plan }));
  }
}
