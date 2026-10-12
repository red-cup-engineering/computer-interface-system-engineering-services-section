#!/usr/bin/env node
import { existsSync, readFileSync } from "node:fs";
import { spawnSync } from "node:child_process";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const packageRoot = dirname(dirname(fileURLToPath(import.meta.url)));
const requireTools = process.argv.includes("--require-tools");
const json = process.argv.includes("--json");

function read(relative) {
  return readFileSync(join(packageRoot, relative), "utf8");
}

function parsePackageManifest() {
  const core = read("lisp/gnopon-core.el");
  const match = core.match(/\(defvar gnopon-package-manifest\s+'\(([\s\S]*?)\)\s+"Third-party packages expected/);
  if (!match) {
    throw new Error("could not parse gnopon-package-manifest");
  }
  return [...match[1].matchAll(/\b([a-zA-Z0-9][a-zA-Z0-9-]*)\b/g)].map((item) => item[1]);
}

function commandExists(command) {
  return spawnSync("sh", ["-c", "command -v \"$1\" >/dev/null 2>&1", "sh", command], {
    stdio: "ignore",
  }).status === 0;
}

function runCheck(tool, args) {
  const result = spawnSync(tool, args, {
    cwd: packageRoot,
    encoding: "utf8",
  });
  return {
    command: [tool, ...args].join(" "),
    status: result.status === 0 ? "ok" : "failed",
    exitCode: result.status,
    stdout: result.stdout.trim(),
    stderr: result.stderr.trim(),
  };
}

function staticManifestChecks() {
  const packages = parsePackageManifest();
  const flake = read("flake.nix");
  const guix = read("guix/manifest.scm");
  const missingFromNix = packages.filter((name) => !flake.includes(`"${name}"`));
  const missingFromGuix = packages.filter((name) => !guix.includes(`"emacs-${name}"`));
  return {
    status: missingFromNix.length === 0 && missingFromGuix.length === 0 ? "ok" : "failed",
    emacsPackageCount: packages.length,
    missingFromNix,
    missingFromGuix,
  };
}

function checkNix() {
  if (!existsSync(join(packageRoot, "flake.nix"))) {
    return { status: "failed", reason: "flake.nix missing" };
  }
  if (!commandExists("nix")) {
    return { status: requireTools ? "failed" : "skipped", reason: "nix executable not found" };
  }
  return runCheck("nix", [
    "--extra-experimental-features",
    "nix-command flakes",
    "flake",
    "check",
    "--no-build",
  ]);
}

function checkGuix() {
  if (!existsSync(join(packageRoot, "guix/manifest.scm"))) {
    return { status: "failed", reason: "guix/manifest.scm missing" };
  }
  if (!existsSync(join(packageRoot, "guix/channels.scm"))) {
    return { status: "failed", reason: "guix/channels.scm missing" };
  }
  if (!commandExists("guix")) {
    return { status: requireTools ? "failed" : "skipped", reason: "guix executable not found" };
  }
  return runCheck("guix", [
    "time-machine",
    "-C",
    "guix/channels.scm",
    "--",
    "shell",
    "-m",
    "guix/manifest.scm",
    "--dry-run",
  ]);
}

const report = {
  packageRoot,
  requireTools,
  static: staticManifestChecks(),
  nix: checkNix(),
  guix: checkGuix(),
};

const failed = [report.static, report.nix, report.guix].some((item) => item.status === "failed");

if (json) {
  console.log(JSON.stringify(report, null, 2));
} else {
  console.log(`# GnoponEmacs Reproducibility Check

packageRoot: ${packageRoot}
static manifest alignment: ${report.static.status}
nix: ${report.nix.status}${report.nix.reason ? ` (${report.nix.reason})` : ""}
guix: ${report.guix.status}${report.guix.reason ? ` (${report.guix.reason})` : ""}
`);
}

if (failed) {
  process.exitCode = 1;
}
