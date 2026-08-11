import { Body, Controller, Delete, Get, Param, Patch, Post, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiResponse, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard.js';
import { CurrentUser } from '../auth/decorators/current-user.decorator.js';
import type { JwtUser } from '../auth/auth.types.js';
import { DevicesService } from './devices.service.js';
import { CreateDeviceDto } from './dto/create-device.dto.js';
import { UpdateDeviceDto } from './dto/update-device.dto.js';
import type { DeviceResponse } from './device.types.js';

@ApiTags('devices')
@ApiBearerAuth('access-token')
@Controller('devices')
@UseGuards(JwtAuthGuard)
export class DevicesController {
  constructor(private readonly devicesService: DevicesService) {}

  @Post()
  @ApiOperation({ summary: 'Registrar dispositivo' })
  @ApiResponse({ status: 201, description: 'Dispositivo creado' })
  @ApiResponse({ status: 401, description: 'No autenticado' })
  create(@CurrentUser() user: JwtUser, @Body() dto: CreateDeviceDto): Promise<DeviceResponse> {
    return this.devicesService.create(user.id, dto);
  }

  @Get()
  @ApiOperation({ summary: 'Listar dispositivos propios' })
  @ApiResponse({ status: 200, description: 'Lista de dispositivos con estado online' })
  findAll(@CurrentUser() user: JwtUser): Promise<DeviceResponse[]> {
    return this.devicesService.findAll(user.id);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Ver un dispositivo propio' })
  @ApiResponse({ status: 200, description: 'Detalle del dispositivo' })
  @ApiResponse({ status: 404, description: 'Dispositivo no encontrado' })
  findOne(@CurrentUser() user: JwtUser, @Param('id') id: string): Promise<DeviceResponse> {
    return this.devicesService.findOne(user.id, id);
  }

  @Patch(':id')
  @ApiOperation({
    summary: 'Actualizar dispositivo',
    description: 'Renombrar o actualizar el pushToken',
  })
  @ApiResponse({ status: 200, description: 'Dispositivo actualizado' })
  @ApiResponse({ status: 404, description: 'Dispositivo no encontrado' })
  update(
    @CurrentUser() user: JwtUser,
    @Param('id') id: string,
    @Body() dto: UpdateDeviceDto,
  ): Promise<DeviceResponse> {
    return this.devicesService.update(user.id, id, dto);
  }

  @Delete(':id')
  @ApiOperation({ summary: 'Eliminar/desvincular dispositivo' })
  @ApiResponse({ status: 200, description: 'Dispositivo eliminado' })
  @ApiResponse({ status: 404, description: 'Dispositivo no encontrado' })
  remove(@CurrentUser() user: JwtUser, @Param('id') id: string): Promise<{ success: true }> {
    return this.devicesService.remove(user.id, id);
  }

  @Post(':id/heartbeat')
  @ApiOperation({
    summary: 'Heartbeat',
    description: 'Marca el dispositivo online (ventana de 2 min)',
  })
  @ApiResponse({ status: 201, description: 'lastSeenAt actualizado' })
  @ApiResponse({ status: 404, description: 'Dispositivo no encontrado' })
  heartbeat(@CurrentUser() user: JwtUser, @Param('id') id: string): Promise<DeviceResponse> {
    return this.devicesService.heartbeat(user.id, id);
  }
}
