import { Injectable, Logger } from '@nestjs/common';
import type { OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import {
  CreateBucketCommand,
  DeleteObjectCommand,
  GetObjectCommand,
  HeadBucketCommand,
  HeadObjectCommand,
  PutObjectCommand,
  S3Client,
} from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';

const DEFAULT_EXPIRES_UPLOAD = 900;
const DEFAULT_EXPIRES_DOWNLOAD = 3600;

@Injectable()
export class StorageService implements OnModuleInit {
  private readonly logger = new Logger(StorageService.name);
  private readonly s3: S3Client;
  private readonly publicS3: S3Client | null;
  private readonly bucket: string;
  private readonly releasesBucket: string;

  constructor(configService: ConfigService) {
    const endpoint = configService.get<string>('MINIO_ENDPOINT', 'localhost');
    const port = configService.get<string>('MINIO_PORT', '9002');
    const useSsl = configService.get<boolean>('MINIO_USE_SSL', false) === true;
    this.bucket = configService.get<string>('MINIO_BUCKET', 'tether');
    this.releasesBucket = configService.get<string>('MINIO_RELEASES_BUCKET', 'releases');

    const credentials = {
      accessKeyId: configService.get<string>('MINIO_ACCESS_KEY', 'minioadmin'),
      secretAccessKey: configService.get<string>('MINIO_SECRET_KEY', 'minioadmin'),
    };

    this.s3 = new S3Client({
      endpoint: `${useSsl ? 'https' : 'http'}://${endpoint}:${port}`,
      region: 'us-east-1',
      forcePathStyle: true,
      credentials,
    });

    // Endpoint público opcional para generar URLs presignadas accesibles desde
    // fuera (TLS). Si no se define, se usa el endpoint interno del SDK.
    const publicEndpoint = configService.get<string>('MINIO_PUBLIC_ENDPOINT');
    this.publicS3 = publicEndpoint
      ? new S3Client({
          endpoint: publicEndpoint,
          region: 'us-east-1',
          forcePathStyle: true,
          credentials,
        })
      : null;
  }

  async onModuleInit(): Promise<void> {
    await this.ensureBucket(this.bucket);
    await this.ensureBucket(this.releasesBucket);
  }

  async getPresignedUploadUrl(
    key: string,
    contentType: string,
    expiresIn = DEFAULT_EXPIRES_UPLOAD,
  ): Promise<string> {
    return getSignedUrl(
      this.s3,
      new PutObjectCommand({
        Bucket: this.bucket,
        Key: key,
        ContentType: contentType,
      }),
      { expiresIn },
    );
  }

  async getPresignedDownloadUrl(
    key: string,
    filename: string,
    expiresIn = DEFAULT_EXPIRES_DOWNLOAD,
    disposition: 'attachment' | 'inline' = 'attachment',
    bucket = this.bucket,
  ): Promise<string> {
    const safeName = filename.replace(/"/g, '');
    return getSignedUrl(
      this.publicS3 ?? this.s3,
      new GetObjectCommand({
        Bucket: bucket,
        Key: key,
        ResponseContentDisposition: `${disposition}; filename="${safeName}"`,
      }),
      { expiresIn },
    );
  }

  async objectExists(key: string): Promise<boolean> {
    try {
      await this.s3.send(new HeadObjectCommand({ Bucket: this.bucket, Key: key }));
      return true;
    } catch {
      return false;
    }
  }

  async checkConnection(): Promise<void> {
    await this.s3.send(new HeadBucketCommand({ Bucket: this.bucket }));
  }

  async deleteObject(key: string): Promise<void> {
    await this.s3.send(new DeleteObjectCommand({ Bucket: this.bucket, Key: key }));
  }

  private async ensureBucket(bucket = this.bucket): Promise<void> {
    try {
      await this.s3.send(new HeadBucketCommand({ Bucket: bucket }));
      return;
    } catch {
      // bucket no existe, se intenta crear
    }
    try {
      await this.s3.send(new CreateBucketCommand({ Bucket: bucket }));
      this.logger.log(`Bucket "${bucket}" creado`);
    } catch (err) {
      this.logger.warn(`No se pudo crear el bucket "${bucket}": ${(err as Error).message}`);
    }
  }
}
