import { NestFactory } from '@nestjs/core';
import { ConfigService } from '@nestjs/config';
import { ValidationPipe } from '@nestjs/common';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import helmet from 'helmet';
import express from 'express';
import { AppModule } from './app.module.js';
import { allowedOrigins } from './config/cors.js';

async function bootstrap() {
  const app = await NestFactory.create(AppModule, { bodyParser: false });
  const configService = app.get(ConfigService);

  app.use(helmet());
  app.use(express.json({ limit: '5mb' }));
  app.use(express.urlencoded({ extended: true, limit: '5mb' }));

  app.enableShutdownHooks();

  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      transform: true,
      forbidNonWhitelisted: true,
    }),
  );

  const origins = allowedOrigins();
  const isWildcard = origins.length === 1 && origins[0] === '*';
  app.enableCors({
    origin: isWildcard ? true : origins,
    credentials: true,
  });

  const config = new DocumentBuilder()
    .setTitle('Tether API')
    .setDescription(
      'Portapapeles y transferencia de archivos entre dispositivos. API del backend NestJS.',
    )
    .setVersion('0.1.0')
    .addBearerAuth({ type: 'http', scheme: 'bearer', bearerFormat: 'JWT' }, 'access-token')
    .addTag('auth', 'Registro, login y tokens')
    .addTag('devices', 'Dispositivos propios y estado online')
    .addTag('clipboard', 'Texto del portapapeles')
    .addTag('files', 'Archivos y presigned URLs S3/MinIO')
    .addTag('transfers', 'Shares de archivos entre dispositivos')
    .build();

  const document = SwaggerModule.createDocument(app, config);
  SwaggerModule.setup('docs', app, document, {
    swaggerOptions: {
      persistAuthorization: true,
    },
  });

  const port = configService.get<number>('PORT', 3000);
  await app.listen(port);
  console.log(`Tether API running on http://localhost:${port}`);
  console.log(`Swagger UI on http://localhost:${port}/docs`);
}

bootstrap();
