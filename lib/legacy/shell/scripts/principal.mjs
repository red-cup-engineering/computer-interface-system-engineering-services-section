// principal — the shell's single import seam to computer's PRINCIPAL tool.
//
// The principal tool just landed in computer/ but its package exports are NOT yet registered
// (`import "@561-group/computer/principal"` does not resolve as of this writing — ERR_MODULE_NOT_FOUND).
// computer/package.json is the OWNER's to edit, not ours; the shell may not touch it. So we reach the
// tool by RELATIVE PATH through this one file, and the rest of the shell imports it by name from here.
// When computer registers the export, this file's body becomes:
//     export * from "@561-group/computer/principal";
//     export { default } from "@561-group/computer/principal";
// and nothing else in the shell changes. (The intended subpaths to register, from the tool's surface:
//   { "./principal": "./principal/src/principal-barrel.mjs",
//     "./principal/tool": "./principal/src/principal.mjs" })
//
// We import the tool MODULE directly (principal.mjs, the named surface) rather than the barrel, because
// the named exports — recognize/dispute/present/whois/authenticated/may/grant/revoke — are what the
// shell verbs map onto.
export * from "../../../../computer/principal/src/principal.mjs";
export { default } from "../../../../computer/principal/src/principal.mjs";
