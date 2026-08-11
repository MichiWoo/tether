import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsOptional, IsString, MaxLength } from 'class-validator';

export class UpdateDeviceDto {
  @ApiPropertyOptional({ example: 'MacBook Pro 16' })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  name?: string;

  @ApiPropertyOptional({ description: 'Token para notificaciones push' })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  pushToken?: string;
}
