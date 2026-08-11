import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Transform } from 'class-transformer';
import { IsEnum, IsNotEmpty, IsOptional, IsString, MaxLength } from 'class-validator';
import { DevicePlatform } from '../../generated/prisma/client.js';

export class CreateDeviceDto {
  @ApiProperty({ example: 'iPhone de Michel' })
  @IsString()
  @IsNotEmpty()
  @MaxLength(100)
  name: string;

  @ApiProperty({ enum: DevicePlatform, example: 'ios', description: 'Se normaliza a mayúsculas' })
  @Transform(({ value }) => (typeof value === 'string' ? value.toUpperCase() : value))
  @IsEnum(DevicePlatform)
  platform: DevicePlatform;

  @ApiPropertyOptional({ description: 'Token para notificaciones push' })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  pushToken?: string;
}
