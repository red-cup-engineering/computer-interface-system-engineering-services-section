// _harness — a zero-dependency assert harness for the wheatstone proofs (same shape as arnold's).
// Each proof imports modules by relative/package path, runs assertions, exits non-zero on failure.

let passed = 0;

export function ok(cond, label) {
  if (!cond) { console.error(`  ✗ ${label}`); process.exit(1); }
  passed++; console.log(`  ✓ ${label}`);
}

export function eq(actual, expected, label) {
  const a = JSON.stringify(actual), e = JSON.stringify(expected);
  if (a !== e) { console.error(`  ✗ ${label}\n      expected ${e}\n      got      ${a}`); process.exit(1); }
  passed++; console.log(`  ✓ ${label}`);
}

export function includes(haystack, needle, label) {
  if (!String(haystack).includes(needle)) {
    console.error(`  ✗ ${label}\n      "${needle}" not found in:\n      ${haystack}`); process.exit(1);
  }
  passed++; console.log(`  ✓ ${label}`);
}

export function done(name) { console.log(`${name}: ${passed} assertion(s) passed`); }
