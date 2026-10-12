#!/usr/bin/env node
import { mkdir, readFile, rm, stat, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const pluginSource = path.join(root, "plugin");
const localInstall = path.join(root, "vault", ".obsidian", "plugins", "knowledge-vault");
const releaseRoot = path.join(root, "dist", "obsidian-plugin");
const releaseDir = path.join(releaseRoot, "knowledge-vault");

const ASSETS = Object.freeze(["manifest.json", "styles.css"]);
const RELEASE_FILES = Object.freeze(["manifest.json", "main.js", "styles.css"]);

const argv = process.argv.slice(2);
const args = new Set(argv);

async function copyFile(source, target) {
  await mkdir(path.dirname(target), { recursive: true });
  await writeFile(target, await readFile(source));
}

async function syncAssets() {
  for (const name of ASSETS) {
    await copyFile(path.join(pluginSource, name), path.join(localInstall, name));
  }
}

async function packagePlugin() {
  await syncAssets();
  await rm(releaseRoot, { recursive: true, force: true });
  await mkdir(releaseDir, { recursive: true });
  await copyReleaseFiles(releaseDir);
  await copyFile(path.join(root, "versions.json"), path.join(releaseRoot, "versions.json"));
  const manifest = JSON.parse(await readFile(path.join(releaseDir, "manifest.json"), "utf8"));
  const zipPath = path.join(releaseRoot, `${manifest.id}-${manifest.version}.zip`);
  await writeZip(zipPath, RELEASE_FILES.map((name) => ({
    source: path.join(releaseDir, name),
    name,
  })));
  process.stdout.write([
    `packaged ${manifest.name} ${manifest.version}`,
    path.relative(root, releaseDir),
    path.relative(root, zipPath),
    path.relative(root, path.join(releaseRoot, "versions.json")),
    "",
  ].join("\n"));
}

async function installPlugin(vaultRoot) {
  if (vaultRoot === undefined || vaultRoot.trim() === "") {
    throw new Error("--install requires a vault root path");
  }
  await syncAssets();
  const target = path.resolve(vaultRoot, ".obsidian", "plugins", "knowledge-vault");
  await copyReleaseFiles(target);
  process.stdout.write([
    "installed Knowledge Vault plugin",
    path.relative(process.cwd(), target) || target,
    ...RELEASE_FILES.map((name) => path.relative(process.cwd(), path.join(target, name)) || path.join(target, name)),
    "",
  ].join("\n"));
}

async function copyReleaseFiles(targetDir) {
  for (const name of RELEASE_FILES) {
    await copyFile(path.join(localInstall, name), path.join(targetDir, name));
  }
}

async function writeZip(zipPath, entries) {
  const localParts = [];
  const centralParts = [];
  let offset = 0;
  for (const entry of entries) {
    const data = await readFile(entry.source);
    const fileStat = await stat(entry.source);
    const name = Buffer.from(entry.name.replaceAll("\\", "/"), "utf8");
    const crc = crc32(data);
    const timeDate = dosDateTime(fileStat.mtime);
    const local = Buffer.alloc(30);
    local.writeUInt32LE(0x04034b50, 0);
    local.writeUInt16LE(20, 4);
    local.writeUInt16LE(0, 6);
    local.writeUInt16LE(0, 8);
    local.writeUInt16LE(timeDate.time, 10);
    local.writeUInt16LE(timeDate.date, 12);
    local.writeUInt32LE(crc, 14);
    local.writeUInt32LE(data.length, 18);
    local.writeUInt32LE(data.length, 22);
    local.writeUInt16LE(name.length, 26);
    local.writeUInt16LE(0, 28);
    localParts.push(local, name, data);

    const central = Buffer.alloc(46);
    central.writeUInt32LE(0x02014b50, 0);
    central.writeUInt16LE(20, 4);
    central.writeUInt16LE(20, 6);
    central.writeUInt16LE(0, 8);
    central.writeUInt16LE(0, 10);
    central.writeUInt16LE(timeDate.time, 12);
    central.writeUInt16LE(timeDate.date, 14);
    central.writeUInt32LE(crc, 16);
    central.writeUInt32LE(data.length, 20);
    central.writeUInt32LE(data.length, 24);
    central.writeUInt16LE(name.length, 28);
    central.writeUInt16LE(0, 30);
    central.writeUInt16LE(0, 32);
    central.writeUInt16LE(0, 34);
    central.writeUInt16LE(0, 36);
    central.writeUInt32LE(0, 38);
    central.writeUInt32LE(offset, 42);
    centralParts.push(central, name);
    offset += local.length + name.length + data.length;
  }
  const centralStart = offset;
  const centralSize = centralParts.reduce((sum, part) => sum + part.length, 0);
  const end = Buffer.alloc(22);
  end.writeUInt32LE(0x06054b50, 0);
  end.writeUInt16LE(0, 4);
  end.writeUInt16LE(0, 6);
  end.writeUInt16LE(entries.length, 8);
  end.writeUInt16LE(entries.length, 10);
  end.writeUInt32LE(centralSize, 12);
  end.writeUInt32LE(centralStart, 16);
  end.writeUInt16LE(0, 20);
  await writeFile(zipPath, Buffer.concat([...localParts, ...centralParts, end]));
}

function dosDateTime(date) {
  const year = Math.max(1980, date.getFullYear());
  return {
    time: (date.getHours() << 11) | (date.getMinutes() << 5) | Math.floor(date.getSeconds() / 2),
    date: ((year - 1980) << 9) | ((date.getMonth() + 1) << 5) | date.getDate(),
  };
}

const CRC_TABLE = new Uint32Array(256);
for (let i = 0; i < CRC_TABLE.length; i += 1) {
  let value = i;
  for (let j = 0; j < 8; j += 1) {
    value = (value & 1) === 1 ? 0xedb88320 ^ (value >>> 1) : value >>> 1;
  }
  CRC_TABLE[i] = value >>> 0;
}

function crc32(data) {
  let crc = 0xffffffff;
  for (const byte of data) {
    crc = CRC_TABLE[(crc ^ byte) & 0xff] ^ (crc >>> 8);
  }
  return (crc ^ 0xffffffff) >>> 0;
}

try {
  if (args.has("--sync")) await syncAssets();
  else if (args.has("--install")) await installPlugin(argAfter("--install"));
  else await packagePlugin();
} catch (error) {
  process.stderr.write(`package-plugin: ${error instanceof Error ? error.message : String(error)}\n`);
  process.exit(1);
}

function argAfter(flag) {
  const index = argv.indexOf(flag);
  return index === -1 ? undefined : argv[index + 1];
}
