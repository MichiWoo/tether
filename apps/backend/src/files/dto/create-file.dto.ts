import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
  Matches,
  Max,
  MaxLength,
  Min,
} from 'class-validator';

const MAX_FILE_SIZE = 5 * 1024 * 1024 * 1024;

export class CreateFileDto {
  @ApiProperty({ example: 'informe.pdf' })
  @IsString()
  @IsNotEmpty()
  @MaxLength(255)
  name: string;

  @ApiProperty({ example: 1024, description: 'Tamaño en bytes (máx 5GB)' })
  @IsInt()
  @Min(1)
  @Max(MAX_FILE_SIZE)
  size: number;

  @ApiPropertyOptional({ example: 'application/pdf' })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  mimeType?: string;

  @ApiPropertyOptional({
    example: 'a3f5... (sha256 hex de 64 chars)',
    description: 'Checksum sha256 del contenido',
  })
  @IsOptional()
  @IsString()
  @Matches(/^[a-f0-9]{64}$/i)
  checksum?: string;
}
