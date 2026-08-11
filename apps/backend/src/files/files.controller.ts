import { Body, Controller, Delete, Get, Param, Post, Query, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard.js';
import { CurrentUser } from '../auth/decorators/current-user.decorator.js';
import { JwtUser } from '../auth/auth.types.js';
import { FilesService } from './files.service.js';
import { CreateFileDto } from './dto/create-file.dto.js';
import { CreateFileResponse, FileDownloadResponse, FileResponse } from './file.types.js';

@Controller('files')
@UseGuards(JwtAuthGuard)
export class FilesController {
  constructor(private readonly filesService: FilesService) {}

  @Post()
  create(@CurrentUser() user: JwtUser, @Body() dto: CreateFileDto): Promise<CreateFileResponse> {
    return this.filesService.create(user.id, dto);
  }

  @Get()
  findAll(@CurrentUser() user: JwtUser, @Query('limit') limit?: string): Promise<FileResponse[]> {
    return this.filesService.findAll(user.id, limit ? Number(limit) : 50);
  }

  @Get(':id')
  getDownload(
    @CurrentUser() user: JwtUser,
    @Param('id') id: string,
  ): Promise<FileDownloadResponse> {
    return this.filesService.getDownload(user.id, id);
  }

  @Post(':id/complete')
  complete(@CurrentUser() user: JwtUser, @Param('id') id: string): Promise<FileResponse> {
    return this.filesService.complete(user.id, id);
  }

  @Delete(':id')
  remove(@CurrentUser() user: JwtUser, @Param('id') id: string): Promise<{ success: true }> {
    return this.filesService.remove(user.id, id);
  }
}
