import { describe, beforeAll, afterAll, it, expect } from 'vitest';
import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { AppModule } from '../src/app.module.js';

describe('Auth (e2e)', () => {
  let app: INestApplication;

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleRef.createNestApplication();
    app.useGlobalPipes(
      new ValidationPipe({
        whitelist: true,
        transform: true,
        forbidNonWhitelisted: true,
      }),
    );
    await app.init();
  });

  afterAll(async () => {
    await app.close();
  });

  it('registra, accede a /me con token y devuelve 401 sin token', async () => {
    const email = `e2e-${Date.now()}@tether.dev`;

    const register = await request(app.getHttpServer())
      .post('/auth/register')
      .send({ email, password: 'supersecret1', name: 'E2E' })
      .expect(201);

    expect(register.body.accessToken).toBeTruthy();
    expect(register.body.refreshToken).toBeTruthy();
    expect(register.body.user).toMatchObject({ email, name: 'E2E' });

    const me = await request(app.getHttpServer())
      .get('/auth/me')
      .set('Authorization', `Bearer ${register.body.accessToken}`)
      .expect(200);

    expect(me.body.email).toBe(email);

    await request(app.getHttpServer()).get('/auth/me').expect(401);
  });

  it('rechaza un registro duplicado con 409', async () => {
    const email = `e2e-dup-${Date.now()}@tether.dev`;
    const payload = { email, password: 'supersecret1' };

    await request(app.getHttpServer()).post('/auth/register').send(payload).expect(201);
    await request(app.getHttpServer()).post('/auth/register').send(payload).expect(409);
  });

  it('valida el body (email inválido) con 400', async () => {
    await request(app.getHttpServer())
      .post('/auth/register')
      .send({ email: 'no-es-email', password: 'supersecret1' })
      .expect(400);
  });
});
