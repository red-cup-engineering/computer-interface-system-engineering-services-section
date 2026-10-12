import { induceBins } from "@emsenn/relating";
import { actions } from "@emsenn/organizing-a-knowledge-vault/actions";
import { decodeFrontMatterDocument, encodeFrontMatterDocument } from "@emsenn/producing-content/codecs/frontmatter";

export type KnowledgeVaultActionRunOptions = Readonly<{
  argv: readonly string[];
  stdin?: string;
  program?: string;
  dataRoot?: string;
}>;

export type KnowledgeVaultActionRunResult = Readonly<{
  code: number;
  stdout: string;
  stderr: string;
}>;

const dispatcher = induceBins(actions, { packageName: "@emsenn/organizing-a-knowledge-vault" });

export function knowledgeVaultActionHelp(): KnowledgeVaultActionRunResult {
  return dispatcher.dispatch(["--help"], "", {
    program: "obsidian-knowledge-vault",
    caller: { transport: "obsidian-vault-app" },
  });
}

export function runKnowledgeVaultAction(options: KnowledgeVaultActionRunOptions): KnowledgeVaultActionRunResult {
  return dispatcher.dispatch([...options.argv], options.stdin ?? "", {
    program: options.program ?? "obsidian-knowledge-vault",
    caller: { transport: "obsidian-vault-app" },
    ...(options.dataRoot === undefined ? {} : { dataRoot: options.dataRoot }),
  });
}

export function normalizeFrontMatterText(text: string): string {
  return encodeFrontMatterDocument(decodeFrontMatterDocument(text));
}
