#!/usr/bin/env node
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import {
  existsSync,
  lstatSync,
  mkdirSync,
  readdirSync,
  readFileSync,
  readlinkSync,
  symlinkSync,
} from "node:fs";
import { spawnSync } from "node:child_process";

const packageRoot = dirname(dirname(fileURLToPath(import.meta.url)));
const metadataCommands = new Set(["path", "manifest", "catalog", "doctor", "install", "launch", "run", "help"]);
const requestedCommand = process.argv[2];
const command = requestedCommand && metadataCommands.has(requestedCommand) ? requestedCommand : "launch";

function usage() {
  console.log(`gnoponemacs

Commands:
  run [-- EMACS_ARGS...]     Launch Emacs and open the agent cockpit chooser.
  launch [-- EMACS_ARGS...]  Launch Emacs with this package as its init directory.
  path                  Print this package directory.
  manifest [--json]     Print expected Emacs packages and external tools.
  catalog [--json]      Print indexed GnoponEmacs modules, commands, and keys.
  doctor [--json]       Check local runtime, tools, and install links.
  install --target DIR  Create early-init.el and init.el symlinks in DIR.
  help                  Show this message.

Example:
  gnoponemacs
  gnoponemacs run
  gnoponemacs -- --debug-init
  gnoponemacs install --target ~/.config/emacs
`);
}

function argsAfterCommand() {
  if (command === "launch" && requestedCommand !== "launch") {
    return process.argv.slice(2);
  }
  return process.argv.slice(3);
}

function targetFromArgs() {
  const index = process.argv.indexOf("--target");
  if (index === -1 || !process.argv[index + 1]) {
    throw new Error("install requires --target DIR");
  }
  return resolve(process.argv[index + 1].replace(/^~(?=$|\/)/, process.env.HOME ?? "~"));
}

function ensureSymlink(source, target) {
  if (existsSync(target)) {
    const stat = lstatSync(target);
    if (!stat.isSymbolicLink()) {
      throw new Error(`${target} exists and is not a symlink`);
    }
    const current = resolve(dirname(target), readlinkSync(target));
    if (current !== source) {
      throw new Error(`${target} points to ${current}, expected ${source}`);
    }
    return;
  }
  symlinkSync(source, target);
}

function elispFile(name) {
  return readFileSync(join(packageRoot, "lisp", name), "utf8");
}

function elispModules() {
  return readdirSync(join(packageRoot, "lisp"))
    .filter((name) => name.endsWith(".el"))
    .sort()
    .map((name) => ({
      name,
      path: join(packageRoot, "lisp", name),
      text: elispFile(name),
    }));
}

function parsePackageManifest() {
  const core = elispFile("gnopon-core.el");
  const match = core.match(/\(defvar gnopon-package-manifest\s+'\(([\s\S]*?)\)\s+"Third-party packages expected/);
  if (!match) {
    throw new Error("could not parse gnopon-package-manifest");
  }
  return [...match[1].matchAll(/\b([a-zA-Z0-9][a-zA-Z0-9-]*)\b/g)].map((item) => item[1]);
}

function parseDoctorTools() {
  const doctor = elispFile("gnopon-doctor.el");
  const match = doctor.match(/\(defvar gnopon-doctor-tools\s+'\(([\s\S]*?)\)\s+"External tools/);
  if (!match) {
    throw new Error("could not parse gnopon-doctor-tools");
  }
  return [...match[1].matchAll(/\("([^"]+)"\s+\.\s+"([^"]+)"\)/g)].map((item) => ({
    name: item[1],
    description: item[2],
  }));
}

function manifest() {
  return {
    packageRoot,
    emacsPackages: parsePackageManifest(),
    externalTools: parseDoctorTools(),
  };
}

function parseInteractiveCommands(module) {
  const commands = [];
  const chunks = module.text.split(/\n\(defun\s+/).slice(1);
  for (const chunk of chunks) {
    const name = chunk.match(/^(gnopon\/[a-zA-Z0-9-]+)/)?.[1];
    if (!name || !chunk.includes("(interactive")) {
      continue;
    }
    const doc = chunk.match(/^[\s\S]*?\n\s+"([^"]+)"/)?.[1] ?? "";
    commands.push({
      name,
      module: module.name,
      type: "command",
      doc,
    });
  }
  for (const match of module.text.matchAll(
    /\(transient-define-prefix\s+(gnopon\/[a-zA-Z0-9-]+)\s+\([^)]*\)\s+"([^"]+)"/g,
  )) {
    commands.push({
      name: match[1],
      module: module.name,
      type: "transient",
      doc: match[2],
    });
  }
  return commands;
}

function parseKeybindings(modules) {
  const bindings = [];
  for (const module of modules) {
    for (const match of module.text.matchAll(/\(define-key\s+gnopon-map\s+\(kbd\s+"([^"]+)"\)\s+#'([^)]+)\)/g)) {
      bindings.push({
        key: `C-c g ${match[1]}`,
        command: match[2],
        module: module.name,
      });
    }
    for (const match of module.text.matchAll(/\(define-key\s+global-map\s+\(kbd\s+"([^"]+)"\)\s+#'([^)]+)\)/g)) {
      bindings.push({
        key: match[1],
        command: match[2],
        module: module.name,
      });
    }
  }
  return bindings.sort((left, right) => left.key.localeCompare(right.key));
}

function commandCatalog() {
  const modules = elispModules();
  const commands = modules.flatMap(parseInteractiveCommands).sort((left, right) =>
    left.name.localeCompare(right.name),
  );
  const keybindings = parseKeybindings(modules);
  return {
    packageRoot,
    modules: modules.map((module) => module.name),
    commands,
    keybindings,
  };
}

function commandExists(name) {
  const result = spawnSync("sh", ["-c", `command -v "$1" >/dev/null 2>&1`, "sh", name], {
    stdio: "ignore",
  });
  return result.status === 0;
}

function linkStatus(target, source) {
  if (!existsSync(target)) {
    return "missing";
  }
  const stat = lstatSync(target);
  if (!stat.isSymbolicLink()) {
    return "not-symlink";
  }
  return resolve(dirname(target), readlinkSync(target)) === source ? "ok" : "wrong-target";
}

function doctorReport() {
  const target = process.env.GNOPONEMACS_TARGET
    ? resolve(process.env.GNOPONEMACS_TARGET.replace(/^~(?=$|\/)/, process.env.HOME ?? "~"))
    : resolve(process.env.HOME ?? ".", ".config/emacs");
  const data = manifest();
  return {
    packageRoot,
    node: process.version,
    emacs: commandExists("emacs"),
    target,
    links: {
      "early-init.el": linkStatus(join(target, "early-init.el"), join(packageRoot, "early-init.el")),
      "init.el": linkStatus(join(target, "init.el"), join(packageRoot, "init.el")),
    },
    externalTools: data.externalTools.map((tool) => ({
      ...tool,
      status: commandExists(tool.name) ? "ok" : "missing",
    })),
    emacsPackages: data.emacsPackages,
  };
}

function launchPlan(rawArgs = argsAfterCommand()) {
  let args = rawArgs.filter((arg) => arg !== "--dry-run" && arg !== "--json");
  if (args[0] === "--") {
    args = args.slice(1);
  }
  const hasChdir = args.includes("--chdir");
  return {
    command: "emacs",
    args: [
      "--init-directory",
      packageRoot,
      ...(hasChdir ? [] : ["--chdir", process.cwd()]),
      ...args,
    ],
    cwd: process.cwd(),
  };
}

function shellQuote(value) {
  return `'${String(value).replaceAll("'", "'\\''")}'`;
}

function launchEmacs() {
  const plan = launchPlan();
  if (process.argv.includes("--dry-run")) {
    if (process.argv.includes("--json")) {
      console.log(JSON.stringify(plan, null, 2));
    } else {
      console.log([plan.command, ...plan.args].map(shellQuote).join(" "));
    }
    return;
  }
  const result = spawnSync(plan.command, plan.args, {
    cwd: plan.cwd,
    stdio: "inherit",
  });
  if (result.error) {
    throw result.error;
  }
  process.exit(result.status ?? 1);
}

function runCockpit() {
  const plan = launchPlan();
  plan.args = [...plan.args, "--eval", "(gnopon/cockpit-launch)"];
  if (process.argv.includes("--dry-run")) {
    if (process.argv.includes("--json")) {
      console.log(JSON.stringify(plan, null, 2));
    } else {
      console.log([plan.command, ...plan.args].map(shellQuote).join(" "));
    }
    return;
  }
  const result = spawnSync(plan.command, plan.args, {
    cwd: plan.cwd,
    stdio: "inherit",
  });
  if (result.error) {
    throw result.error;
  }
  process.exit(result.status ?? 1);
}

function printCatalog(json) {
  const catalog = commandCatalog();
  if (json) {
    console.log(JSON.stringify(catalog, null, 2));
    return;
  }
  const bindingsByCommand = new Map();
  for (const binding of catalog.keybindings) {
    const keys = bindingsByCommand.get(binding.command) ?? [];
    keys.push(binding.key);
    bindingsByCommand.set(binding.command, keys);
  }
  console.log(`# GnoponEmacs Command Catalog

packageRoot: ${catalog.packageRoot}
modules: ${catalog.modules.length}
commands: ${catalog.commands.length}
keybindings: ${catalog.keybindings.length}

## Commands

${catalog.commands
  .map((command) => {
    const keys = bindingsByCommand.get(command.name) ?? [];
    return `- ${command.name} (${command.module}${command.type === "transient" ? ", transient" : ""})${
      keys.length ? ` - ${keys.join(", ")}` : ""
    }${command.doc ? `\n  ${command.doc}` : ""}`;
  })
  .join("\n")}

## Keybindings

${catalog.keybindings.map((binding) => `- ${binding.key}: ${binding.command} (${binding.module})`).join("\n")}
`);
}

function printManifest(json) {
  const data = manifest();
  if (json) {
    console.log(JSON.stringify(data, null, 2));
    return;
  }
  console.log(`# GnoponEmacs Manifest

packageRoot: ${data.packageRoot}

## Emacs Packages

${data.emacsPackages.map((name) => `- ${name}`).join("\n")}

## External Tools

${data.externalTools.map((tool) => `- ${tool.name}: ${tool.description}`).join("\n")}
`);
}

function printDoctor(json) {
  const report = doctorReport();
  if (json) {
    console.log(JSON.stringify(report, null, 2));
    return;
  }
  console.log(`# GnoponEmacs CLI Doctor

packageRoot: ${report.packageRoot}
node: ${report.node}
emacs: ${report.emacs ? "ok" : "missing"}
target: ${report.target}
early-init.el: ${report.links["early-init.el"]}
init.el: ${report.links["init.el"]}

## External Tools

${report.externalTools.map((tool) => `- ${tool.name}: ${tool.status} (${tool.description})`).join("\n")}
`);
}

switch (command) {
  case "launch":
    launchEmacs();
    break;
  case "run":
    runCockpit();
    break;
  case "path":
    console.log(packageRoot);
    break;
  case "manifest":
    printManifest(process.argv.includes("--json"));
    break;
  case "catalog":
    printCatalog(process.argv.includes("--json"));
    break;
  case "doctor":
    printDoctor(process.argv.includes("--json"));
    break;
  case "install": {
    const target = targetFromArgs();
    mkdirSync(target, { recursive: true });
    ensureSymlink(join(packageRoot, "early-init.el"), join(target, "early-init.el"));
    ensureSymlink(join(packageRoot, "init.el"), join(target, "init.el"));
    console.log(`Installed GnoponEmacs links in ${target}`);
    break;
  }
  case "help":
  case "--help":
  case "-h":
    usage();
    break;
  default:
    throw new Error(`unknown command: ${command}`);
}
