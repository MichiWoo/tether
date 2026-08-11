import { Body, Controller, Get, Param, Post, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiResponse, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard.js';
import { CurrentUser } from '../auth/decorators/current-user.decorator.js';
import type { JwtUser } from '../auth/auth.types.js';
import { TransfersService } from './transfers.service.js';
import { CreateShareDto } from './dto/create-share.dto.js';
import { ListSharesQueryDto } from './dto/list-shares.query.dto.js';
import type { ShareDetailResponse, ShareResponse } from './transfer.types.js';

@ApiTags('transfers')
@ApiBearerAuth('access-token')
@Controller('shares')
@UseGuards(JwtAuthGuard)
export class TransfersController {
  constructor(private readonly transfersService: TransfersService) {}

  @Post()
  @ApiOperation({
    summary: 'Crear share',
    description:
      'Comparte un archivo UPLOADED con un device destino (o todos los del usuario). Encola job en BullMQ que emite share.created por WebSocket. TTL de expiración = SHARE_TTL_DAYS.',
  })
  @ApiResponse({ status: 201, description: 'Share creado' })
  @ApiResponse({ status: 400, description: 'Archivo no subido todavía' })
  @ApiResponse({ status: 404, description: 'Archivo o device destino no encontrado' })
  create(@CurrentUser() user: JwtUser, @Body() dto: CreateShareDto): Promise<ShareResponse> {
    return this.transfersService.createShare(user.id, dto);
  }

  @Get()
  @ApiOperation({ summary: 'Listar shares propios' })
  @ApiResponse({ status: 200, description: 'Lista de shares' })
  @ApiResponse({ status: 400, description: 'status inválido' })
  findAll(
    @CurrentUser() user: JwtUser,
    @Query() query: ListSharesQueryDto,
  ): Promise<ShareResponse[]> {
    return this.transfersService.findAll(user.id, query.status);
  }

  @Get(':id')
  @ApiOperation({
    summary: 'Detalle de share',
    description: 'Incluye presigned URL de descarga (TTL 1h) si el share no está EXPIRED',
  })
  @ApiResponse({ status: 200, description: 'Detalle con downloadUrl' })
  @ApiResponse({ status: 404, description: 'Share no encontrado' })
  getDetail(@CurrentUser() user: JwtUser, @Param('id') id: string): Promise<ShareDetailResponse> {
    return this.transfersService.getDetail(user.id, id);
  }

  @Post(':id/accept')
  @ApiOperation({ summary: 'Aceptar share', description: 'Marca ACCEPTED y emite share.accepted' })
  @ApiResponse({ status: 201, description: 'Share aceptado' })
  @ApiResponse({ status: 400, description: 'Share expirado' })
  @ApiResponse({ status: 404, description: 'Share no encontrado' })
  accept(@CurrentUser() user: JwtUser, @Param('id') id: string): Promise<ShareResponse> {
    return this.transfersService.acceptShare(user.id, id);
  }

  @Post(':id/downloaded')
  @ApiOperation({
    summary: 'Marcar descargado',
    description: 'Marca DOWNLOADED y emite share.downloaded',
  })
  @ApiResponse({ status: 201, description: 'Share marcado como descargado' })
  @ApiResponse({ status: 400, description: 'Share expirado' })
  @ApiResponse({ status: 404, description: 'Share no encontrado' })
  downloaded(@CurrentUser() user: JwtUser, @Param('id') id: string): Promise<ShareResponse> {
    return this.transfersService.markDownloaded(user.id, id);
  }

  @Post(':id/cancel')
  @ApiOperation({ summary: 'Cancelar share', description: 'Marca el share como EXPIRED' })
  @ApiResponse({ status: 201, description: 'Share cancelado' })
  @ApiResponse({ status: 404, description: 'Share no encontrado' })
  cancel(@CurrentUser() user: JwtUser, @Param('id') id: string): Promise<ShareResponse> {
    return this.transfersService.cancelShare(user.id, id);
  }
}
