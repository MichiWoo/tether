import { Body, Controller, Get, Post, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiResponse, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard.js';
import { CurrentUser } from '../auth/decorators/current-user.decorator.js';
import type { JwtUser } from '../auth/auth.types.js';
import { ClipboardService } from './clipboard.service.js';
import { PushClipboardDto } from './dto/push-clipboard.dto.js';
import { ListClipboardQueryDto } from './dto/list-clipboard.query.dto.js';
import { ClipboardItemResponse } from './clipboard.types.js';

@ApiTags('clipboard')
@ApiBearerAuth('access-token')
@Controller('clipboard')
@UseGuards(JwtAuthGuard)
export class ClipboardController {
  constructor(private readonly clipboardService: ClipboardService) {}

  @Post()
  @ApiOperation({
    summary: 'Subir texto al portapapeles',
    description:
      'Guarda el texto y notifica por WebSocket (evento clipboard.updated). Deduplica si el mismo device envía el mismo contenido.',
  })
  @ApiResponse({ status: 201, description: 'Item guardado', type: ClipboardItemResponse })
  @ApiResponse({ status: 404, description: 'sourceDeviceId no existe o no es del usuario' })
  push(
    @CurrentUser() user: JwtUser,
    @Body() dto: PushClipboardDto,
  ): Promise<ClipboardItemResponse> {
    return this.clipboardService.push(user.id, dto);
  }

  @Get('latest')
  @ApiOperation({ summary: 'Último texto del portapapeles' })
  @ApiResponse({
    status: 200,
    description: 'Último item o null si no hay',
    type: ClipboardItemResponse,
  })
  getLatest(@CurrentUser() user: JwtUser): Promise<ClipboardItemResponse | null> {
    return this.clipboardService.getLatest(user.id);
  }

  @Get('history')
  @ApiOperation({
    summary: 'Historial de texto',
    description: 'Últimos N items (default 20, máx 100)',
  })
  @ApiResponse({
    status: 200,
    description: 'Lista de items, más reciente primero',
    type: [ClipboardItemResponse],
  })
  getHistory(
    @CurrentUser() user: JwtUser,
    @Query() query: ListClipboardQueryDto,
  ): Promise<ClipboardItemResponse[]> {
    return this.clipboardService.getHistory(user.id, query.limit);
  }
}
