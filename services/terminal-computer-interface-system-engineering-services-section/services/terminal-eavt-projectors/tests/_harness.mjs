// Minimal zero-dependency assertion harness for the domain projector proofs.

let passed = 0;

export function ok(condition, label) {
  if (!condition) throw new Error(label);
  passed += 1;
}

export function eq(actual, expected, label) {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) throw new Error(label);
  passed += 1;
}

export function includes(haystack, needle, label) {
  if (!String(haystack).includes(needle)) throw new Error(label);
  passed += 1;
}

export function done(name) {
  console.log(`${name}: ${passed} assertion(s) passed`);
}
