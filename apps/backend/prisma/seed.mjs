import 'dotenv/config';
import bcrypt from 'bcrypt';
import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from '../dist/src/generated/prisma/client.js';

const BCRYPT_ROUNDS = 12;

const email = (process.env.SEED_ADMIN_EMAIL ?? 'michiwoo.web@gmail.com').trim().toLowerCase();
const name = (process.env.SEED_ADMIN_NAME ?? 'Admin').trim();
const password = process.env.SEED_ADMIN_PASSWORD;

if (!process.env.DATABASE_URL) {
  console.error('DATABASE_URL no está definido. Abortando seed.');
  process.exit(1);
}

if (!password) {
  console.error('SEED_ADMIN_PASSWORD no está definido. Abortando seed.');
  process.exit(1);
}

const prisma = new PrismaClient({
  adapter: new PrismaPg({ connectionString: process.env.DATABASE_URL }),
});

async function main() {
  const existing = await prisma.user.findUnique({ where: { email } });
  if (existing) {
    console.log(`Seed: el usuario admin "${email}" ya existe, se omite.`);
    return;
  }

  const passwordHash = await bcrypt.hash(password, BCRYPT_ROUNDS);
  await prisma.user.create({
    data: { email, name, password: passwordHash },
  });
  console.log(`Seed: usuario admin "${email}" creado.`);
}

main()
  .catch((err) => {
    console.error('Seed falló:', err);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
