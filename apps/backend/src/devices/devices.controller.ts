import { Body, Controller, Delete, Get, Param, Patch, Post, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard.js';
import { CurrentUser } from '../auth/decorators/current-user.decorator.js';
import { JwtUser } from '../auth/auth.types.js';
import { DevicesService } from './devices.service.js';
import { CreateDeviceDto } from './dto/create-device.dto.js';
import { UpdateDeviceDto } from './dto/update-device.dto.js';
import { DeviceResponse } from './device.types.js';

@Controller('devices')
@UseGuards(JwtAuthGuard)
export class DevicesController {
  constructor(private readonly devicesService: DevicesService) {}

  @Post()
  create(@CurrentUser() user: JwtUser, @Body() dto: CreateDeviceDto): Promise<DeviceResponse> {
    return this.devicesService.create(user.id, dto);
  }

  @Get()
  findAll(@CurrentUser() user: JwtUser): Promise<DeviceResponse[]> {
    return this.devicesService.findAll(user.id);
  }

  @Get(':id')
  findOne(@CurrentUser() user: JwtUser, @Param('id') id: string): Promise<DeviceResponse> {
    return this.devicesService.findOne(user.id, id);
  }

  @Patch(':id')
  update(
    @CurrentUser() user: JwtUser,
    @Param('id') id: string,
    @Body() dto: UpdateDeviceDto,
  ): Promise<DeviceResponse> {
    return this.devicesService.update(user.id, id, dto);
  }

  @Delete(':id')
  remove(@CurrentUser() user: JwtUser, @Param('id') id: string): Promise<{ success: true }> {
    return this.devicesService.remove(user.id, id);
  }

  @Post(':id/heartbeat')
  heartbeat(@CurrentUser() user: JwtUser, @Param('id') id: string): Promise<DeviceResponse> {
    return this.devicesService.heartbeat(user.id, id);
  }
}
