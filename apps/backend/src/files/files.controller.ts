import { Body, Controller, Delete, Get, Param, Post, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiQuery, ApiResponse, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard.js';
import { CurrentUser } from '../auth/decorators/current-user.decorator.js';
import { JwtUser } from '../auth/auth.types.js';
import { FilesService } from './files.service.js';
import { CreateFileDto } from './dto/create-file.dto.js';
import { CreateFileResponse, FileDownloadResponse, FileResponse } from './file.types.js';

@ApiTags('files')
@ApiBearerAuth('access-token')
@Controller('files')
@UseGuards(JwtAuthGuard)
export class FilesController {
  constructor(private readonly filesService: FilesService) {}

  @Post()
  @ApiOperation({
    summary: 'Registrar archivo',
    description:
      'Crea el registro y devuelve una presigned URL PUT para subir el archivo directo a S3/MinIO (TTL 15 min). El servidor no actúa de buffer.',
  })
  @ApiResponse({ status: 201, description: 'Registro creado con upload.url y headers' })
  @ApiResponse({ status: 400, description: 'Datos inválidos (tamaño máx 5GB, checksum hex de 64)' })
  create(@CurrentUser() user: JwtUser, @Body() dto: CreateFileDto): Promise<CreateFileResponse> {
    return this.filesService.create(user.id, dto);
  }

  @Get()
  @ApiOperation({ summary: 'Listar archivos propios' })
  @ApiQuery({ name: 'limit', required: false, type: Number, example: 50 })
  @ApiResponse({ status: 200, description: 'Lista de archivos' })
  findAll(@CurrentUser() user: JwtUser, @Query('limit') limit?: string): Promise<FileResponse[]> {
    return this.filesService.findAll(user.id, limit ? Number(limit) : 50);
  }

  @Get(':id')
  @ApiOperation({
    summary: 'Descargar archivo',
    description:
      'Devuelve el registro + presigned URL GET (TTL 1h). Solo si el archivo está UPLOADED.',
  })
  @ApiResponse({ status: 200, description: 'downloadUrl lista para descargar' })
  @ApiResponse({ status: 400, description: 'Archivo aún no subido' })
  @ApiResponse({ status: 404, description: 'Archivo no encontrado' })
  getDownload(
    @CurrentUser() user: JwtUser,
    @Param('id') id: string,
  ): Promise<FileDownloadResponse> {
    return this.filesService.getDownload(user.id, id);
  }

  @Post(':id/complete')
  @ApiOperation({
    summary: 'Confirmar subida',
    description:
      'Verifica el objeto en S3 con HeadObject, marca UPLOADED y emite file.ready por WebSocket.',
  })
  @ApiResponse({ status: 201, description: 'Archivo marcado como UPLOADED' })
  @ApiResponse({ status: 400, description: 'Objeto no encontrado en el storage' })
  @ApiResponse({ status: 404, description: 'Archivo no encontrado' })
  complete(@CurrentUser() user: JwtUser, @Param('id') id: string): Promise<FileResponse> {
    return this.filesService.complete(user.id, id);
  }

  @Delete(':id')
  @ApiOperation({
    summary: 'Eliminar archivo',
    description: 'Borra el registro y el objeto de S3/MinIO',
  })
  @ApiResponse({ status: 200, description: 'Archivo eliminado' })
  @ApiResponse({ status: 404, description: 'Archivo no encontrado' })
  remove(@CurrentUser() user: JwtUser, @Param('id') id: string): Promise<{ success: true }> {
    return this.filesService.remove(user.id, id);
  }
}
