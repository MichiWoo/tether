-- CreateTable
CREATE TABLE "clipboard_items" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "content" TEXT NOT NULL,
    "sourceDeviceId" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "clipboard_items_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "clipboard_items_userId_createdAt_idx" ON "clipboard_items"("userId", "createdAt");

-- AddForeignKey
ALTER TABLE "clipboard_items" ADD CONSTRAINT "clipboard_items_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "clipboard_items" ADD CONSTRAINT "clipboard_items_sourceDeviceId_fkey" FOREIGN KEY ("sourceDeviceId") REFERENCES "devices"("id") ON DELETE SET NULL ON UPDATE CASCADE;
