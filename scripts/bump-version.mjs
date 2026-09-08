#!/usr/bin/env node
// Sincroniza la versión de la app Tauri en los tres archivos que la declaran:
//   - apps/tether_tauri/package.json
//   - apps/tether_tauri/src-tauri/tauri.conf.json
//   - apps/tether_tauri/src-tauri/Cargo.toml
// Uso: node scripts/bump-version.mjs <version> [--no-commit]
//   node scripts/bump-version.mjs 0.2.0
//   node scripts/bump-version.mjs 0.2.0 --no-commit

import { readFile, writeFile } from "node:fs/promises";
import { execSync } from "node:child_process";
import { resolve } from "node:path";

const root = resolve(import.meta.dirname, "..");
const targets = {
  packageJson: resolve(root, "apps/tether_tauri/package.json"),
  tauriConf: resolve(root, "apps/tether_tauri/src-tauri/tauri.conf.json"),
  cargoToml: resolve(root, "apps/tether_tauri/src-tauri/Cargo.toml"),
};

const SEMVER = /^\d+\.\d+\.\d+$/;
const args = process.argv.slice(2);
const version = args.find((a) => !a.startsWith("--"));
const noCommit = args.includes("--no-commit");

if (!version) {
  console.error("Uso: node scripts/bump-version.mjs <version> [--no-commit]");
  process.exit(1);
}

if (!SEMVER.test(version)) {
  console.error(`Versión inválida "${version}". Usá semver estricto (ej. 0.2.0).`);
  process.exit(1);
}

async function readJson(path) {
  return JSON.parse(await readFile(path, "utf8"));
}

const pkg = await readJson(targets.packageJson);
const tauri = await readJson(targets.tauriConf);
const cargo = await readFile(targets.cargoToml, "utf8");

const oldVersion = pkg.version;

pkg.version = version;
tauri.version = version;
const newCargo = cargo.replace(
  /^version\s*=\s*".*"$/m,
  `version = "${version}"`,
);

await writeFile(targets.packageJson, JSON.stringify(pkg, null, 2) + "\n");
await writeFile(targets.tauriConf, JSON.stringify(tauri, null, 2) + "\n");
await writeFile(targets.cargoToml, newCargo);

console.log(`Versión actualizada ${oldVersion} -> ${version}`);

if (noCommit) {
  process.exit(0);
}

const tag = `v${version}`;
execSync(`git add ${targets.packageJson} ${targets.tauriConf} ${targets.cargoToml}`, {
  cwd: root,
  stdio: "inherit",
});
execSync(`git commit -m "chore: bump version to ${version}"`, {
  cwd: root,
  stdio: "inherit",
});
execSync(`git tag ${tag}`, { cwd: root, stdio: "inherit" });

console.log(`Commit y tag creados. Publicá con: git push --follow-tags`);
