-- Permite N artefactos por version+platform+arch (deb/rpm/AppImage, msi/exe)
-- y marca el instalador principal mostrado en la landing.
ALTER TABLE "releases" ADD COLUMN "isPrimary" BOOLEAN NOT NULL DEFAULT false;

DROP INDEX IF EXISTS "releases_version_platform_arch_key";

CREATE UNIQUE INDEX "releases_version_platform_arch_filename_key" ON "releases"("version", "platform", "arch", "filename");
