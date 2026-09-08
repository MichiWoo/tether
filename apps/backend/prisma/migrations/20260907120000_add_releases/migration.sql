-- CreateTable
CREATE TABLE "releases" (
    "id" TEXT NOT NULL,
    "version" TEXT NOT NULL,
    "channel" TEXT NOT NULL DEFAULT 'stable',
    "platform" TEXT NOT NULL,
    "arch" TEXT NOT NULL,
    "filename" TEXT NOT NULL,
    "s3Key" TEXT NOT NULL,
    "size" INTEGER NOT NULL,
    "checksum" TEXT NOT NULL,
    "signature" TEXT,
    "notes" TEXT,
    "publishedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "releases_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "releases_version_platform_arch_key" ON "releases"("version", "platform", "arch");

-- CreateIndex
CREATE INDEX "releases_channel_publishedAt_idx" ON "releases"("channel", "publishedAt");
