import { ApiProperty } from '@nestjs/swagger';
import { IsString, MinLength } from 'class-validator';

export class RefreshTokenDto {
  @ApiProperty({ description: 'Refresh token emitido en register/login/refresh' })
  @IsString()
  @MinLength(10)
  refreshToken: string;
}
