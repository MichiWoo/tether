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
  } else {
    const passwordHash = await bcrypt.hash(password, BCRYPT_ROUNDS);
    await prisma.user.create({
      data: { email, name, password: passwordHash },
    });
    console.log(`Seed: usuario admin "${email}" creado.`);
  }

  const GB = (n) => BigInt(n) * 1024n * 1024n * 1024n;
  const plans = [
    { plan: 'FREE', title: 'Freemium', maxStorageBytes: GB(2), maxFileSizeBytes: 100 * 1024 * 1024, monthlyTransferBytes: GB(5), maxDevices: 3, shareTtlDays: 7, clipboardHistoryItems: 50, clipboardRetentionDays: 30 },
    { plan: 'PRO', title: 'Pro', maxStorageBytes: GB(50), maxFileSizeBytes: 2 * 1024 * 1024 * 1024, monthlyTransferBytes: GB(50), maxDevices: 10, shareTtlDays: 30, clipboardHistoryItems: 500, clipboardRetentionDays: 365 },
    { plan: 'UNLIMITS', title: 'Unlimits', maxStorageBytes: GB(500), maxFileSizeBytes: 5 * 1024 * 1024 * 1024, monthlyTransferBytes: GB(250), maxDevices: 20, shareTtlDays: 90, clipboardHistoryItems: 1000, clipboardRetentionDays: 730 },
  ];
  for (const p of plans) {
    await prisma.planLimits.upsert({ where: { plan: p.plan }, update: {}, create: p });
  }
  console.log('Seed: límites de planes listos (FREE/PRO/UNLIMITS).');
}

main()
  .catch((err) => {
    console.error('Seed falló:', err);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
