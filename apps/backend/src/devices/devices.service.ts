import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service.js';
import type { Device } from '../generated/prisma/client.js';
import { CreateDeviceDto } from './dto/create-device.dto.js';
import { UpdateDeviceDto } from './dto/update-device.dto.js';
import type { DeviceResponse } from './device.types.js';

const ONLINE_THRESHOLD_MS = 2 * 60 * 1000;

@Injectable()
export class DevicesService {
  constructor(private readonly prisma: PrismaService) {}

  async create(userId: string, dto: CreateDeviceDto): Promise<DeviceResponse> {
    const device = await this.prisma.device.create({
      data: {
        userId,
        name: dto.name,
        platform: dto.platform,
        pushToken: dto.pushToken ?? null,
      },
    });
    return this.toResponse(device);
  }

  async findAll(userId: string): Promise<DeviceResponse[]> {
    const devices = await this.prisma.device.findMany({
      where: { userId },
      orderBy: { createdAt: 'asc' },
    });
    return devices.map((device) => this.toResponse(device));
  }

  async findOne(userId: string, deviceId: string): Promise<DeviceResponse> {
    const device = await this.findOwnedDevice(userId, deviceId);
    return this.toResponse(device);
  }

  async update(userId: string, deviceId: string, dto: UpdateDeviceDto): Promise<DeviceResponse> {
    await this.findOwnedDevice(userId, deviceId);
    const device = await this.prisma.device.update({
      where: { id: deviceId },
      data: {
        ...(dto.name !== undefined && { name: dto.name }),
        ...(dto.pushToken !== undefined && { pushToken: dto.pushToken ?? null }),
      },
    });
    return this.toResponse(device);
  }

  async remove(userId: string, deviceId: string): Promise<{ success: true }> {
    await this.findOwnedDevice(userId, deviceId);
    await this.prisma.device.delete({ where: { id: deviceId } });
    return { success: true };
  }

  async heartbeat(userId: string, deviceId: string): Promise<DeviceResponse> {
    await this.findOwnedDevice(userId, deviceId);
    const device = await this.prisma.device.update({
      where: { id: deviceId },
      data: { lastSeenAt: new Date() },
    });
    return this.toResponse(device);
  }

  private async findOwnedDevice(userId: string, deviceId: string): Promise<Device> {
    const device = await this.prisma.device.findFirst({
      where: { id: deviceId, userId },
    });
    if (!device) {
      throw new NotFoundException('Device not found');
    }
    return device;
  }

  private toResponse(device: Device): DeviceResponse {
    const isOnline =
      device.lastSeenAt !== null && Date.now() - device.lastSeenAt.getTime() < ONLINE_THRESHOLD_MS;
    return {
      id: device.id,
      name: device.name,
      platform: device.platform,
      isOnline,
      lastSeenAt: device.lastSeenAt?.toISOString() ?? null,
      createdAt: device.createdAt.toISOString(),
      updatedAt: device.updatedAt.toISOString(),
    };
  }
}
