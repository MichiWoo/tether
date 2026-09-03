import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsOptional, IsString, MaxLength } from 'class-validator';

export class UpdateProfileDto {
  @ApiPropertyOptional({ example: 'Michel' })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  name?: string;

  @ApiPropertyOptional({
    example: 'https://example.com/avatar.png',
    description: 'Vacío para usar Gravatar',
  })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  avatarUrl?: string;
}
