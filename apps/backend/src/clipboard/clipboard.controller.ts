import { Body, Controller, Get, Post, Query, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard.js';
import { CurrentUser } from '../auth/decorators/current-user.decorator.js';
import { JwtUser } from '../auth/auth.types.js';
import { ClipboardService } from './clipboard.service.js';
import { PushClipboardDto } from './dto/push-clipboard.dto.js';
import { ClipboardItemResponse } from './clipboard.types.js';

@Controller('clipboard')
@UseGuards(JwtAuthGuard)
export class ClipboardController {
  constructor(private readonly clipboardService: ClipboardService) {}

  @Post()
  push(
    @CurrentUser() user: JwtUser,
    @Body() dto: PushClipboardDto,
  ): Promise<ClipboardItemResponse> {
    return this.clipboardService.push(user.id, dto);
  }

  @Get('latest')
  getLatest(@CurrentUser() user: JwtUser): Promise<ClipboardItemResponse | null> {
    return this.clipboardService.getLatest(user.id);
  }

  @Get('history')
  getHistory(
    @CurrentUser() user: JwtUser,
    @Query('limit') limit?: string,
  ): Promise<ClipboardItemResponse[]> {
    return this.clipboardService.getHistory(user.id, limit ? Number(limit) : 20);
  }
}
