import { IsNotEmpty, IsOptional, IsString } from 'class-validator';

export class CreateShareDto {
  @IsString()
  @IsNotEmpty()
  fileId: string;

  @IsOptional()
  @IsString()
  @IsNotEmpty()
  targetDeviceId?: string;
}
