-- CreateEnum
CREATE TYPE "ShareStatus" AS ENUM ('CREATED', 'ACCEPTED', 'DOWNLOADED', 'EXPIRED');

-- CreateTable
CREATE TABLE "shares" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "fileId" TEXT NOT NULL,
    "targetDeviceId" TEXT,
    "status" "ShareStatus" NOT NULL DEFAULT 'CREATED',
    "acceptedAt" TIMESTAMP(3),
    "downloadedAt" TIMESTAMP(3),
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "shares_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "shares_userId_createdAt_idx" ON "shares"("userId", "createdAt");

-- CreateIndex
CREATE INDEX "shares_targetDeviceId_idx" ON "shares"("targetDeviceId");

-- AddForeignKey
ALTER TABLE "shares" ADD CONSTRAINT "shares_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "shares" ADD CONSTRAINT "shares_fileId_fkey" FOREIGN KEY ("fileId") REFERENCES "files"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "shares" ADD CONSTRAINT "shares_targetDeviceId_fkey" FOREIGN KEY ("targetDeviceId") REFERENCES "devices"("id") ON DELETE SET NULL ON UPDATE CASCADE;
