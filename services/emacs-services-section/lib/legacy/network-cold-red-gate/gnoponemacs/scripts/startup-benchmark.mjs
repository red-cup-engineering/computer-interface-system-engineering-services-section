#!/usr/bin/env node
import { spawnSync } from "node:child_process";
import { existsSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const packageRoot = dirname(dirname(fileURLToPath(import.meta.url)));
const json = process.argv.includes("--json");

function optionValue(name, fallback) {
  const index = process.argv.indexOf(name);
  return index === -1 ? fallback : process.argv[index + 1];
}

const iterations = Number.parseInt(optionValue("--iterations", "5"), 10);
const maxMs = optionValue("--max-ms", null);
const maxMilliseconds = maxMs === null ? null : Number.parseFloat(maxMs);

function commandExists(command) {
  return spawnSync("sh", ["-c", "command -v \"$1\" >/dev/null 2>&1", "sh", command], {
    stdio: "ignore",
  }).status === 0;
}

function percentile(values, pct) {
  const sorted = [...values].sort((left, right) => left - right);
  const index = Math.min(sorted.length - 1, Math.ceil((pct / 100) * sorted.length) - 1);
  return sorted[index] ?? 0;
}

if (!Number.isInteger(iterations) || iterations < 1 || iterations > 50) {
  throw new Error("--iterations must be an integer between 1 and 50");
}

if (maxMilliseconds !== null && (!Number.isFinite(maxMilliseconds) || maxMilliseconds <= 0)) {
  throw new Error("--max-ms must be a positive number");
}

const smokePath = join(packageRoot, "tests/gnopon-load-smoke.el");
if (!existsSync(smokePath)) {
  throw new Error("tests/gnopon-load-smoke.el is missing");
}

if (!commandExists("emacs")) {
  const report = {
    packageRoot,
    status: "skipped",
    reason: "emacs executable not found",
    iterations,
  };
  console.log(json ? JSON.stringify(report, null, 2) : "Emacs not found; startup benchmark skipped.");
  process.exit(0);
}

const runs = [];
for (let index = 0; index < iterations; index += 1) {
  const started = process.hrtime.bigint();
  const result = spawnSync("emacs", ["--batch", "-Q", "-l", smokePath], {
    cwd: packageRoot,
    encoding: "utf8",
  });
  const elapsedMs = Number(process.hrtime.bigint() - started) / 1_000_000;
  runs.push({
    index: index + 1,
    status: result.status === 0 ? "ok" : "failed",
    elapsedMs,
    stderr: result.stderr.trim(),
    stdout: result.stdout.trim(),
  });
  if (result.status !== 0) {
    break;
  }
}

const elapsed = runs.map((run) => run.elapsedMs);
const failedRun = runs.find((run) => run.status === "failed");
const report = {
  packageRoot,
  status: failedRun ? "failed" : "ok",
  iterations: runs.length,
  averageMs: elapsed.reduce((sum, value) => sum + value, 0) / elapsed.length,
  minMs: Math.min(...elapsed),
  maxMs: Math.max(...elapsed),
  p95Ms: percentile(elapsed, 95),
  thresholdMs: maxMilliseconds,
  runs,
};

if (!failedRun && maxMilliseconds !== null && report.p95Ms > maxMilliseconds) {
  report.status = "failed";
  report.reason = `p95 ${report.p95Ms.toFixed(1)}ms exceeded threshold ${maxMilliseconds}ms`;
}

if (json) {
  console.log(JSON.stringify(report, null, 2));
} else {
  console.log(`# GnoponEmacs Startup Benchmark

status: ${report.status}${report.reason ? ` (${report.reason})` : ""}
iterations: ${report.iterations}
averageMs: ${report.averageMs.toFixed(1)}
minMs: ${report.minMs.toFixed(1)}
maxMs: ${report.maxMs.toFixed(1)}
p95Ms: ${report.p95Ms.toFixed(1)}
`);
}

if (report.status === "failed") {
  process.exitCode = 1;
}
