import { BadRequestException, Controller, ForbiddenException, Get, Body, Headers, Put, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiProperty, ApiTags } from '@nestjs/swagger';
import { IsIn } from 'class-validator';
import type { PlanName } from '@tether/protocol';
import { PLAN_CODES } from '@tether/protocol';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard.js';
import { CurrentUser } from '../auth/decorators/current-user.decorator.js';
import type { JwtUser } from '../auth/auth.types.js';
import { ConfigService } from '@nestjs/config';
import type { PlanUsageResponse } from '@tether/protocol';
import { PlansService } from './plans.service.js';

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
  constructor(
    private readonly plansService: PlansService,
    private readonly config: ConfigService,
  ) {}

  @Get('usage')
  @ApiOperation({ summary: 'Uso actual del plan (storage, traspaso del mes, dispositivos, clipboards)' })
  usage(@CurrentUser() user: JwtUser): Promise<PlanUsageResponse> {
    return this.plansService.usage(user.id);
  }

  @Put('plan')
  @ApiOperation({
    summary: 'Cambiar plan del usuario (requiere X-Plan-Admin-Key)',
    description: 'Activación manual hasta integrar pasarela de pagos.',
  })
  async setPlan(
    @CurrentUser() user: JwtUser,
    @Body() dto: SetPlanDto,
    @Headers('x-plan-admin-key') adminKey?: string,
  ): Promise<{ plan: PlanName }> {
    const expected = this.config.get<string>('PLAN_ADMIN_KEY');
    if (expected && adminKey !== expected) {
      throw new ForbiddenException('X-Plan-Admin-Key inválida');
    }
    if (!PLAN_CODES.includes(dto.plan)) {
      throw new BadRequestException(`Plan inválido; use: ${PLAN_CODES.join(', ')}`);
    }
    const plan = await this.plansService.setPlan(user.id, dto.plan);
    return { plan };
  }
}
