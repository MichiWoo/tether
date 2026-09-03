import { Controller, Get, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiResponse, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard.js';
import { CurrentUser } from '../auth/decorators/current-user.decorator.js';
import type { JwtUser } from '../auth/auth.types.js';
import { StatsService } from './stats.service.js';
import { StatsResponse } from './stats.types.js';

@ApiTags('stats')
@ApiBearerAuth('access-token')
@Controller('stats')
@UseGuards(JwtAuthGuard)
export class StatsController {
  constructor(private readonly statsService: StatsService) {}

  @Get()
  @ApiOperation({
    summary: 'Estadísticas de uso del usuario',
    description:
      'Agrega archivos subidos, tamaño total, shares, dispositivos y ítems de portapapeles del usuario autenticado.',
  })
  @ApiResponse({ status: 200, description: 'Métricas agregadas', type: StatsResponse })
  getStats(@CurrentUser() user: JwtUser): Promise<StatsResponse> {
    return this.statsService.getStats(user.id);
  }
}
