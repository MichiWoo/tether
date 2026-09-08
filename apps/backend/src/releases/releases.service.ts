import { Injectable, NotFoundException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from '../prisma/prisma.service.js';
import { StorageService } from '../storage/storage.service.js';
import type { Release } from '../generated/prisma/client.js';
import type { RegisterReleaseDto } from './dto/register-release.dto.js';
import type { ReleaseRecordLike, ReleaseResponse } from './releases.types.js';

const RELEASE_DOWNLOAD_TTL = 604800; // 7 días

// Clave de plataforma usada por tauri-plugin-updater (macOS se llama "darwin").
const UPDATER_PLATFORM: Record<string, string> = {
  macos: 'darwin',
  windows: 'windows',
  linux: 'linux',
};

export interface UpdaterManifest {
  version: string;
  notes: string;
  pub_date: string;
  platforms: Record<string, { signature: string; url: string }>;
}

@Injectable()
export class ReleasesService {
  private readonly releasesBucket: string;

  constructor(
    private readonly prisma: PrismaService,
    private readonly storage: StorageService,
    configService: ConfigService,
  ) {
    this.releasesBucket = configService.get<string>('MINIO_RELEASES_BUCKET', 'releases');
  }

  async register(dto: RegisterReleaseDto): Promise<ReleaseResponse> {
    const data = {
      version: dto.version,
      channel: dto.channel ?? 'stable',
      platform: dto.platform,
      arch: dto.arch,
      filename: dto.filename,
      s3Key: dto.s3Key,
      size: dto.size,
      checksum: dto.checksum,
      signature: dto.signature ?? null,
      notes: dto.notes ?? null,
    };

    const release = await this.prisma.release.upsert({
      where: {
        version_platform_arch: {
          version: dto.version,
          platform: dto.platform,
          arch: dto.arch,
        },
      },
      create: data,
      update: data,
    });

    return this.toResponse(release);
  }

  async findLatest(
    channel = 'stable',
    platform?: string,
    arch?: string,
  ): Promise<ReleaseResponse[]> {
    const latest = await this.prisma.release.findFirst({
      where: { channel },
      orderBy: { publishedAt: 'desc' },
    });
    if (!latest) return [];

    const releases = await this.prisma.release.findMany({
      where: {
        version: latest.version,
        channel,
        ...(platform ? { platform } : {}),
        ...(arch ? { arch } : {}),
      },
      orderBy: [{ platform: 'asc' }, { arch: 'asc' }],
    });

    return Promise.all(releases.map((r) => this.toResponse(r)));
  }

  async listVersions(channel = 'stable'): Promise<ReleaseResponse[]> {
    const releases = await this.prisma.release.findMany({
      where: { channel },
      orderBy: [{ publishedAt: 'desc' }, { platform: 'asc' }, { arch: 'asc' }],
    });
    return Promise.all(releases.map((r) => this.toResponse(r)));
  }

  async getDownloadUrl(id: string): Promise<{ filename: string; url: string; expiresIn: number }> {
    const release = await this.findRelease(id);
    const url = await this.storage.getPresignedDownloadUrl(
      release.s3Key,
      release.filename,
      RELEASE_DOWNLOAD_TTL,
      'attachment',
      this.releasesBucket,
    );
    return { filename: release.filename, url, expiresIn: RELEASE_DOWNLOAD_TTL };
  }

  async latestManifest(channel = 'stable'): Promise<UpdaterManifest | null> {
    const latest = await this.prisma.release.findFirst({
      where: { channel },
      orderBy: { publishedAt: 'desc' },
    });
    if (!latest) return null;

    const releases = await this.prisma.release.findMany({
      where: { version: latest.version, channel },
    });

    const platforms: UpdaterManifest['platforms'] = {};
    for (const release of releases) {
      if (!release.signature) continue;
      const os = UPDATER_PLATFORM[release.platform] ?? release.platform;
      const url = await this.storage.getPresignedDownloadUrl(
        release.s3Key,
        release.filename,
        RELEASE_DOWNLOAD_TTL,
        'attachment',
        this.releasesBucket,
      );
      const entry = { signature: release.signature, url };
      // Un binario universal de macOS es descargado por el updater con la
      // arquitectura concreta del host (aarch64 o x86_64), no "universal".
      // Por eso un solo artefacto universal se expone bajo ambas claves.
      if (release.platform === 'macos' && release.arch === 'universal') {
        platforms[`${os}-aarch64`] = entry;
        platforms[`${os}-x86_64`] = entry;
      } else {
        platforms[`${os}-${release.arch}`] = entry;
      }
    }

    return {
      version: latest.version,
      notes: latest.notes ?? '',
      pub_date: latest.publishedAt.toISOString(),
      platforms,
    };
  }

  private async findRelease(id: string): Promise<Release> {
    const release = await this.prisma.release.findUnique({ where: { id } });
    if (!release) {
      throw new NotFoundException('Release not found');
    }
    return release;
  }

  private async toResponse(release: ReleaseRecordLike): Promise<ReleaseResponse> {
    const downloadUrl = await this.storage.getPresignedDownloadUrl(
      release.s3Key,
      release.filename,
      RELEASE_DOWNLOAD_TTL,
      'attachment',
      this.releasesBucket,
    );
    return {
      id: release.id,
      version: release.version,
      channel: release.channel,
      platform: release.platform,
      arch: release.arch,
      filename: release.filename,
      size: release.size,
      checksum: release.checksum,
      signature: release.signature,
      notes: release.notes,
      publishedAt: release.publishedAt.toISOString(),
      downloadUrl,
      expiresIn: RELEASE_DOWNLOAD_TTL,
    };
  }
}
