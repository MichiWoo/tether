import {
  Body,
  Controller,
  Get,
  NotFoundException,
  Param,
  Post,
  Query,
  Redirect,
  UseGuards,
} from '@nestjs/common';
import { ApiOperation, ApiResponse, ApiTags } from '@nestjs/swagger';
import { ReleasesService } from './releases.service.js';
import { ApiKeyGuard } from './api-key.guard.js';
import { RegisterReleaseDto } from './dto/register-release.dto.js';
import type { ReleaseResponse } from './releases.types.js';

@ApiTags('releases')
@Controller('releases')
export class ReleasesController {
  constructor(private readonly releasesService: ReleasesService) {}

  @Get('latest')
  @ApiOperation({
    summary: 'Última versión publicada',
    description:
      'Devuelve la versión más reciente (por fecha de publicación) con URL de descarga presignada. Filtrable por plataforma y arquitectura.',
  })
  @ApiResponse({ status: 200, description: 'Lista de artefactos de la última versión' })
  latest(
    @Query('channel') channel = 'stable',
    @Query('platform') platform?: string,
    @Query('arch') arch?: string,
  ): Promise<ReleaseResponse[]> {
    return this.releasesService.findLatest(channel, platform, arch);
  }

  @Get('latest.json')
  @ApiOperation({
    summary: 'Manifest de auto-actualización (tauri-plugin-updater)',
    description:
      'Devuelve el manifest `latest.json` con las URLs y firmas por plataforma. Compatible con tauri-plugin-updater v2.',
  })
  async latestManifest(@Query('channel') channel = 'stable') {
    const manifest = await this.releasesService.latestManifest(channel);
    if (!manifest) {
      throw new NotFoundException('No hay releases publicados');
    }
    return manifest;
  }

  @Get()
  @ApiOperation({ summary: 'Listar versiones publicadas' })
  @ApiResponse({ status: 200, description: 'Lista plana de releases' })
  list(@Query('channel') channel = 'stable'): Promise<ReleaseResponse[]> {
    return this.releasesService.listVersions(channel);
  }

  @Get(':id/download')
  @Redirect('', 302)
  @ApiOperation({
    summary: 'Descargar artefacto',
    description: 'Redirige (302) a una URL presignada fresca de descarga.',
  })
  async download(@Param('id') id: string): Promise<{ url: string }> {
    const { url } = await this.releasesService.getDownloadUrl(id);
    return { url };
  }

  @Post()
  @UseGuards(ApiKeyGuard)
  @ApiOperation({
    summary: 'Registrar artefacto (interno, API key)',
    description:
      'Crea o actualiza el registro de un artefacto publicado. Protegido con header x-api-key.',
  })
  @ApiResponse({ status: 201, description: 'Release registrado' })
  register(@Body() dto: RegisterReleaseDto): Promise<ReleaseResponse> {
    return this.releasesService.register(dto);
  }
}
