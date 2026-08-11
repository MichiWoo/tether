import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsEmail, IsOptional, IsString, MaxLength, MinLength } from 'class-validator';

export class RegisterDto {
  @ApiProperty({ example: 'user@tether.dev' })
  @IsEmail()
  email: string;

  @ApiProperty({ example: 'supersecret1', minLength: 8, maxLength: 72 })
  @IsString()
  @MinLength(8)
  @MaxLength(72)
  password: string;

  @ApiPropertyOptional({ example: 'Michel' })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  name?: string;
}
