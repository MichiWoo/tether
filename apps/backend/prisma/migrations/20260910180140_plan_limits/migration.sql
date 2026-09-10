-- CreateEnum
CREATE TYPE "Plan" AS ENUM ('FREE', 'PRO', 'UNLIMITS');

-- AlterTable
ALTER TABLE "users" ADD COLUMN     "plan" "Plan" NOT NULL DEFAULT 'FREE',
ADD COLUMN     "planChangedAt" TIMESTAMP(3);
