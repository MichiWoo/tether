import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsBoolean,
  IsIn,
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
  Matches,
  MaxLength,
  Min,
} from 'class-validator';

export const RELEASE_PLATFORMS = ['macos', 'windows', 'linux'] as const;
export const RELEASE_ARCHS = ['x86_64', 'aarch64', 'universal', 'i686'] as const;
export const RELEASE_CHANNELS = ['stable', 'beta'] as const;

export class RegisterReleaseDto {
  @ApiProperty({ example: '0.2.0' })
  @IsString()
  @IsNotEmpty()
  @Matches(/^\d+\.\d+\.\d+$/)
  version: string;

  @ApiPropertyOptional({ enum: RELEASE_CHANNELS, default: 'stable' })
  @IsOptional()
  @IsIn(RELEASE_CHANNELS)
  channel?: string;

  @ApiProperty({ enum: RELEASE_PLATFORMS, example: 'macos' })
  @IsIn(RELEASE_PLATFORMS)
  platform: (typeof RELEASE_PLATFORMS)[number];

  @ApiProperty({ enum: RELEASE_ARCHS, example: 'aarch64' })
  @IsIn(RELEASE_ARCHS)
  arch: (typeof RELEASE_ARCHS)[number];

  @ApiProperty({ example: 'Tether_0.2.0_aarch64.dmg' })
  @IsString()
  @IsNotEmpty()
  @MaxLength(255)
  filename: string;

  @ApiProperty({ example: 'releases/0.2.0/macos/aarch64/Tether_0.2.0_aarch64.dmg' })
  @IsString()
  @IsNotEmpty()
  @MaxLength(1024)
  s3Key: string;

  @ApiProperty({ example: 58431232, description: 'Tamaño en bytes' })
  @IsInt()
  @Min(1)
  size: number;

  @ApiProperty({ example: 'a3f5... (sha256 hex de 64 chars)' })
  @IsString()
  @Matches(/^[a-f0-9]{64}$/i)
  checksum: string;

  @ApiPropertyOptional({ description: 'Firma minisign (.sig) del artefacto' })
  @IsOptional()
  @IsString()
  signature?: string;

  @ApiPropertyOptional({ example: 'Corrige bug de subida en Windows' })
  @IsOptional()
  @IsString()
  @MaxLength(2000)
  notes?: string;

  @ApiPropertyOptional({
    description:
      'Marca el instalador principal de la plataforma (un botón por OS en la landing). Solo uno por version+platform debería ser true.',
    example: true,
    default: false,
  })
  @IsOptional()
  @IsBoolean()
  isPrimary?: boolean;
}
