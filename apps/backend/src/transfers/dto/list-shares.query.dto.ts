import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsEnum, IsOptional } from 'class-validator';
import { ShareStatus } from '../../generated/prisma/client.js';

export class ListSharesQueryDto {
  @ApiPropertyOptional({ enum: ShareStatus })
  @IsOptional()
  @IsEnum(ShareStatus)
  status?: ShareStatus;
}
