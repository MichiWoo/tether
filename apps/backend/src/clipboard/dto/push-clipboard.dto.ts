import { IsNotEmpty, IsOptional, IsString, MaxLength } from 'class-validator';

export class PushClipboardDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(1_000_000)
  content: string;

  @IsOptional()
  @IsString()
  sourceDeviceId?: string;
}
