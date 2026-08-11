import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsNotEmpty, IsOptional, IsString } from 'class-validator';

export class CreateShareDto {
  @ApiProperty({ description: 'ID de un archivo propio con status UPLOADED' })
  @IsString()
  @IsNotEmpty()
  fileId: string;

  @ApiPropertyOptional({
    description: 'Device destino. Si se omite, se notifica a todos los devices del usuario',
  })
  @IsOptional()
  @IsString()
  @IsNotEmpty()
  targetDeviceId?: string;
}
