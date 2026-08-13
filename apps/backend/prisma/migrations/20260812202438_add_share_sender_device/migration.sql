-- AlterTable
ALTER TABLE "shares" ADD COLUMN     "senderDeviceId" TEXT;

-- CreateIndex
CREATE INDEX "shares_senderDeviceId_idx" ON "shares"("senderDeviceId");

-- AddForeignKey
ALTER TABLE "shares" ADD CONSTRAINT "shares_senderDeviceId_fkey" FOREIGN KEY ("senderDeviceId") REFERENCES "devices"("id") ON DELETE SET NULL ON UPDATE CASCADE;
