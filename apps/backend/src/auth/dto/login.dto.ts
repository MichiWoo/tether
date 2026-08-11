import { ApiProperty } from '@nestjs/swagger';
import { IsEmail, IsString, MaxLength, MinLength } from 'class-validator';

export class LoginDto {
  @ApiProperty({ example: 'user@tether.dev' })
  @IsEmail()
  email: string;

  @ApiProperty({ example: 'supersecret1' })
  @IsString()
  @MinLength(8)
  @MaxLength(72)
  password: string;
}
