import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsNotEmpty, IsOptional, IsString, MaxLength } from 'class-validator';

export class PushClipboardDto {
  @ApiProperty({ example: 'Texto a copiar en el otro dispositivo', maxLength: 1_000_000 })
  @IsString()
  @IsNotEmpty()
  @MaxLength(1_000_000)
  content: string;

  @ApiPropertyOptional({
    description: 'Device desde el que se envía (para dedupe y mostrar origen)',
  })
  @IsOptional()
  @IsString()
  sourceDeviceId?: string;
}
