-- CreateTable
CREATE TABLE "plans" (
    "plan" "Plan" NOT NULL,
    "title" TEXT NOT NULL,
    "maxStorageBytes" BIGINT NOT NULL,
    "maxFileSizeBytes" INTEGER NOT NULL,
    "monthlyTransferBytes" BIGINT NOT NULL,
    "maxDevices" INTEGER NOT NULL,
    "shareTtlDays" INTEGER NOT NULL,
    "clipboardHistoryItems" INTEGER NOT NULL,
    "clipboardRetentionDays" INTEGER NOT NULL,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "plans_pkey" PRIMARY KEY ("plan")
);
