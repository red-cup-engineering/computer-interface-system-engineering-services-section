// The dependency-free voxel-grid boundary shared by the renderer and collision system. A grid is only
// a finite map of explicit readings plus an implicit reading supplied by its caller; federation is one
// possible producer of that map, not a dependency of consumers walking it.

export const FOUR = Object.freeze({ T: "t", F: "f", BOT: "bot", TOP: "top" });

export function readingOf(value) {
  const pos = value?.pos, neg = value?.neg;
  if (pos && neg) return FOUR.TOP;
  if (pos) return FOUR.T;
  if (neg) return FOUR.F;
  return FOUR.BOT;
}

function normalizedCell(cell, key) {
  if (Array.isArray(cell)) return { x: cell[0] | 0, z: cell[1] | 0, reading: cell[2] };
  if (cell && typeof cell === "object") return { ...cell, x: cell.x | 0, z: cell.z | 0 };
  const [x, z] = String(key).split(",").map(Number);
  return { x: x | 0, z: z | 0, reading: cell };
}

// gridFromCells(cells, defaultReading) accepts the JSON-safe triples emitted by voxel views, a Map,
// or cell records. Missing coordinates retain the caller's chosen semantics (fog by default).
export function gridFromCells(cells, defaultReading = FOUR.BOT) {
  const byKey = new Map();
  const source = cells instanceof Map ? cells.entries() : (cells ?? []).map((cell) => [undefined, cell]);
  let minX = Infinity, maxX = -Infinity, minZ = Infinity, maxZ = -Infinity;
  for (const [key, value] of source) {
    const cell = normalizedCell(value, key);
    byKey.set(`${cell.x},${cell.z}`, cell);
    minX = Math.min(minX, cell.x); maxX = Math.max(maxX, cell.x);
    minZ = Math.min(minZ, cell.z); maxZ = Math.max(maxZ, cell.z);
  }
  const bounds = byKey.size
    ? { minX, maxX, minZ, maxZ }
    : { minX: 0, maxX: 0, minZ: 0, maxZ: 0 };
  return {
    cells: byKey,
    bounds,
    at(x, z) {
      const ix = x | 0, iz = z | 0;
      return byKey.get(`${ix},${iz}`) ?? { x: ix, z: iz, reading: defaultReading };
    },
  };
}

// The optional adapter preserves render(rawFederatedWorld) for consumers that also load world.mjs,
// while keeping this module and the browser renderer independent of the federation packages.
let worldGridReader;
export function registerWorldGridReader(reader) { worldGridReader = reader; }
export function gridReader(value, options) {
  if (value && typeof value.at === "function" && value.cells) return value;
  if (worldGridReader) return worldGridReader(value, options);
  throw new TypeError("render requires a grid; load world.mjs to adapt a federated world");
}
