import { Body, Controller, Get, Param, Post, Query, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard.js';
import { CurrentUser } from '../auth/decorators/current-user.decorator.js';
import { JwtUser } from '../auth/auth.types.js';
import { TransfersService } from './transfers.service.js';
import { CreateShareDto } from './dto/create-share.dto.js';
import { ShareDetailResponse, ShareResponse } from './transfer.types.js';

@Controller('shares')
@UseGuards(JwtAuthGuard)
export class TransfersController {
  constructor(private readonly transfersService: TransfersService) {}

  @Post()
  create(@CurrentUser() user: JwtUser, @Body() dto: CreateShareDto): Promise<ShareResponse> {
    return this.transfersService.createShare(user.id, dto);
  }

  @Get()
  findAll(
    @CurrentUser() user: JwtUser,
    @Query('status') status?: string,
  ): Promise<ShareResponse[]> {
    return this.transfersService.findAll(user.id, status);
  }

  @Get(':id')
  getDetail(@CurrentUser() user: JwtUser, @Param('id') id: string): Promise<ShareDetailResponse> {
    return this.transfersService.getDetail(user.id, id);
  }

  @Post(':id/accept')
  accept(@CurrentUser() user: JwtUser, @Param('id') id: string): Promise<ShareResponse> {
    return this.transfersService.acceptShare(user.id, id);
  }

  @Post(':id/downloaded')
  downloaded(@CurrentUser() user: JwtUser, @Param('id') id: string): Promise<ShareResponse> {
    return this.transfersService.markDownloaded(user.id, id);
  }

  @Post(':id/cancel')
  cancel(@CurrentUser() user: JwtUser, @Param('id') id: string): Promise<ShareResponse> {
    return this.transfersService.cancelShare(user.id, id);
  }
}
