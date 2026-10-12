// math — the rederived vector kernel the software raycaster needs, pure and self-contained. This
// package derives ALL knowledge from the ground up; nothing here imports a math library and nothing is
// assumed about "how a raycaster works" from outside. abrash renders a VOXEL world with a grid
// DDA raycaster (the Wolfenstein/Quake-lineage software technique Abrash documented): the camera lives
// on a 2D floor plane (x,y) at a height, faces a direction, and casts one ray per screen column. So the
// kernel it needs is 2D vectors, a rotation, and the algebra the cast and the projection rest on —
// each proven by an identity in math.test.mts (rotation preserves length, a perpendicular dots to
// zero). Deterministic — no Date.now, no Math.random — so a frame is replay-identical. Zero deps.

// ── vec2 — the camera plane lives here (x,y on the floor; the vertical is a separate scalar) ──
export const v2 = {
  create: (x = 0, y = 0) => [x, y],
  add: (a, b) => [a[0] + b[0], a[1] + b[1]],
  sub: (a, b) => [a[0] - b[0], a[1] - b[1]],
  scale: (a, s) => [a[0] * s, a[1] * s],
  dot: (a, b) => a[0] * b[0] + a[1] * b[1],
  length: (a) => Math.hypot(a[0], a[1]),
  normalize: (a) => {
    const len = Math.hypot(a[0], a[1]);
    return len === 0 ? [0, 0] : [a[0] / len, a[1] / len];
  },
  // perp(a) — the left-hand perpendicular (90° CCW). dot(a, perp(a)) === 0 (proven in math.test).
  perp: (a) => [-a[1], a[0]],
  // rotate(a, ang) — rotate a vector by `ang` radians (CCW). Length-preserving (proven in math.test).
  rotate: (a, ang) => {
    const c = Math.cos(ang), s = Math.sin(ang);
    return [a[0] * c - a[1] * s, a[0] * s + a[1] * c];
  },
};

// dir(angle) — the unit facing vector for a heading angle (radians, 0 = +x). The camera carries an
// angle; this is its forward. The camera PLANE (the screen's horizontal extent) is perp(dir) scaled by
// the half-FOV tangent — derived once in the raycaster, not here.
export const dir = (angle) => [Math.cos(angle), Math.sin(angle)];

// clampInt(n, lo, hi) — integer clamp (used to bound a screen column / a grid cell index).
export const clampInt = (n, lo, hi) => {
  const i = n | 0;
  return i < lo ? lo : i > hi ? hi : i;
};

// mix(a, b, t) — linear interpolation, used to shade a wall column by distance and to band a sky/floor.
export const mix = (a, b, t) => a + (b - a) * t;
