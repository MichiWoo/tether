-- AlterTable
ALTER TABLE "clipboard_items" ADD COLUMN "contentHash" TEXT;

-- Backfill del hash del contenido existente
UPDATE "clipboard_items" SET "contentHash" = encode(sha256(convert_to("content", 'UTF8')), 'hex');

-- AlterTable
ALTER TABLE "clipboard_items" ALTER COLUMN "contentHash" SET NOT NULL;

-- CreateIndex
CREATE UNIQUE INDEX "clipboard_items_userId_sourceDeviceId_contentHash_key" ON "clipboard_items"("userId", "sourceDeviceId", "contentHash");
