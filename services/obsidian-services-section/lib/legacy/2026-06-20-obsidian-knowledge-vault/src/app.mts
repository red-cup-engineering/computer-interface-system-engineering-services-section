import { createServer, type Server } from "node:http";
import path from "node:path";
import { actions } from "@emsenn/organizing-a-knowledge-vault/actions";
import { induceBins, routeRequest, type ServedResponse } from "@emsenn/relating";
import {
  knowledgeVaultCockpitManifest,
  renderCockpitManifestMarkdown,
  type KnowledgeVaultCockpitManifest,
} from "./cockpit.mjs";

export type KnowledgeVaultApplicationOptions = Readonly<{
  path?: string;
  dataRoot?: string;
}>;

const induced = induceBins(actions, { packageName: "@emsenn/app-obsidian-knowledge-vault" });

export type KnowledgeVaultApplicationRequest = Readonly<{
  method: string;
  path: string;
  query: Readonly<Record<string, string>>;
  body: string;
}>;

export class KnowledgeVaultApplication {
  readonly kind = "obsidian-knowledge-vault.application";
  readonly corpusPath: string;
  readonly manifest: KnowledgeVaultCockpitManifest;
  readonly options: KnowledgeVaultApplicationOptions;

  constructor(options: KnowledgeVaultApplicationOptions = {}) {
    this.options = options;
    this.corpusPath = resolveCorpusPath(options.path);
    process.env["ORGANIZING_KNOWLEDGE_VAULT_PATH"] = this.corpusPath;
    this.manifest = knowledgeVaultCockpitManifest();
  }

  route(request: KnowledgeVaultApplicationRequest): ServedResponse {
    return routeKnowledgeVaultApplicationRequest(this.manifest, this.corpusPath, request, this.options);
  }

  server(): Server {
    return createServer((req, res) => {
      void (async () => {
        const url = new URL(req.url ?? "/", "http://localhost");
        const query: Record<string, string> = {};
        for (const [key, value] of url.searchParams) query[key] = value;
        const body = req.method === "POST" ? await readBody(req) : "";
        const response = this.route({
          method: req.method ?? "GET",
          path: url.pathname,
          query,
          body,
        });
        res.writeHead(response.status, { "content-type": response.type });
        res.end(response.body);
      })();
    });
  }
}

export function createKnowledgeVaultApplication(options: KnowledgeVaultApplicationOptions = {}): KnowledgeVaultApplication {
  return new KnowledgeVaultApplication(options);
}

export function createKnowledgeVaultApplicationServer(options: KnowledgeVaultApplicationOptions = {}): Server {
  return createKnowledgeVaultApplication(options).server();
}

export function routeKnowledgeVaultApplicationRequest(
  manifest: KnowledgeVaultCockpitManifest,
  corpusPath: string,
  request: KnowledgeVaultApplicationRequest,
  options: KnowledgeVaultApplicationOptions = {},
): ServedResponse {
  if (request.method === "GET" && request.path === "/cockpit") return json(manifest);
  if (request.method === "GET" && request.path === "/connectors") return json(manifest.connectors);
  if (request.method === "GET" && request.path === "/cockpit.md") {
    return { status: 200, type: "text/markdown; charset=utf-8", body: `${renderCockpitManifestMarkdown(manifest)}\n` };
  }
  if (request.method === "GET" && request.path === "/benchmark") return json(manifest.benchmark);
  if (request.method === "GET" && request.path === "/health") {
    return json({
      status: "ok",
      package: manifest.appPackage,
      corpusPath,
      actions: induced.actions.length,
      cockpitCommands: manifest.obsidianCommands.length,
      benchmark: manifest.benchmark.length,
    });
  }
  return routeRequest(induced, request, {
    title: manifest.appPackage,
    caller: { transport: "http", surface: "obsidian-knowledge-vault-serve" },
    ...(options.dataRoot === undefined ? {} : { dataRoot: options.dataRoot }),
  });
}

export function resolveCorpusPath(explicit?: string): string {
  if (explicit === undefined || explicit.trim() === "") return path.resolve(process.cwd(), "content");
  return path.isAbsolute(explicit) ? explicit : path.resolve(process.cwd(), explicit);
}

function json(value: unknown, status = 200): ServedResponse {
  return {
    status,
    type: "application/json; charset=utf-8",
    body: `${JSON.stringify(value, null, 2)}\n`,
  };
}

function readBody(req: NodeJS.ReadableStream): Promise<string> {
  return new Promise((resolve) => {
    let body = "";
    req.setEncoding("utf8");
    req.on("data", (chunk: string) => {
      body += chunk;
    });
    req.on("end", () => resolve(body));
  });
}
