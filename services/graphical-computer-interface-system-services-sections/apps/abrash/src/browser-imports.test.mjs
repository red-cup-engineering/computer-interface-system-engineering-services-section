import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

const MODULES = ["raycaster.mjs", "collision.mjs", "framebuffer.mjs", "math.mjs", "grid.mjs"];

test("browser renderer modules have no bare package imports", () => {
  const here = new URL("./", import.meta.url);
  for (const name of MODULES) {
    const source = readFileSync(fileURLToPath(new URL(name, here)), "utf8");
    const specifiers = [...source.matchAll(/^\s*import(?:[\s\S]*?from\s*)?["']([^"']+)["'];?/gm)]
      .map((match) => match[1]);
    assert.ok(specifiers.every((specifier) => specifier.startsWith(".")), `${name}: ${specifiers}`);
  }
});

