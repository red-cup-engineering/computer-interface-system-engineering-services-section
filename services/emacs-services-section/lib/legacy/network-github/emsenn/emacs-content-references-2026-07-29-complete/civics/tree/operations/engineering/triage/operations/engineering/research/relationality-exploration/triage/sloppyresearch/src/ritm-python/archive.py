#!/usr/bin/env python3
"""
archive_verbose.py
Unifies Org-roam links, spaCy predicates, and NODE-RELATIONS into one graph,
stabilizes it via RITM C-closure, compresses via transitive reduction,
and serializes the stable structure to RDF/Turtle.

Verbose logging included.
"""

import os, re, sqlite3, json
from pathlib import Path
from collections import defaultdict, Counter
from tqdm import tqdm
import spacy

# --- Import your local RITM modules ------------------------------------------
from cell import RelationalCell
from cell_rules import nodeset
from analysis import coherence_index, summary

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
DB_PATH       = Path.home() / ".emacs.d/org-roam.db"   # adjust if needed
ORG_ROAM_DIR  = Path.home() / "ems/org"            # your org-roam-directory
OUTPUT_TTL    = Path.home() / "archive-stable.ttl"

# ---------------------------------------------------------------------------
# NLP setup
# ---------------------------------------------------------------------------
print("[INIT] Loading spaCy model 'en_core_web_sm'...")
nlp = spacy.load("en_core_web_sm", disable=["ner", "textcat"])
print("[INIT] spaCy model loaded.\n")

# ---------------------------------------------------------------------------
# Utility: normalize paths
# ---------------------------------------------------------------------------
def normalize_path(raw: str) -> Path | None:
    if not raw:
        return None
    s = str(raw).strip()
    if (s.startswith('"') and s.endswith('"')) or (s.startswith("'") and s.endswith("'")):
        s = s[1:-1]
    p = Path(s)
    if not p.is_absolute():
        p = ORG_ROAM_DIR / p
    return p.expanduser().resolve()

# ---------------------------------------------------------------------------
# Load nodes and Org-roam edges
# ---------------------------------------------------------------------------
def load_nodes_and_org_edges(db_path: Path):
    print(f"[DB] Connecting to {db_path}...")
    conn = sqlite3.connect(str(db_path))
    cur = conn.cursor()
    nodes = list(cur.execute("SELECT id, file, title FROM nodes"))
    org_edges = list(cur.execute("SELECT source, dest FROM links WHERE dest != ''"))
    conn.close()
    print(f"[DB] Loaded {len(nodes)} nodes, {len(org_edges)} org-link edges.")
    node_meta = {
        nid: {"file": normalize_path(f), "title": title or ""}
        for nid, f, title in nodes
        if normalize_path(f) and normalize_path(f).is_file()
    }
    readable = set(node_meta.keys())
    org_edges = [(s, t) for (s, t) in org_edges if s in readable and t in readable]
    print(f"[DB] {len(node_meta)} readable node files, {len(org_edges)} valid org edges.\n")
    return node_meta, org_edges

# ---------------------------------------------------------------------------
# NODE-RELATIONS parser
# ---------------------------------------------------------------------------
NODE_RELATIONS_RE = re.compile(r":NODE-RELATIONS:\s*(\(.+\))", re.DOTALL)
ID_PAIR_RE = re.compile(
    r"\[\[id:([^\]]+)\]\]\[([^\]]+)\]\s*\.\s*\[\[id:([^\]]+)\]\]\[([^\]]+)\]"
)

def extract_node_relations(text: str):
    """Return list of (src_id, relation, dst_id) from :NODE-RELATIONS: property."""
    out = []
    if not text:
        return out
    m = NODE_RELATIONS_RE.search(text)
    if not m:
        return out
    blob = m.group(1)
    for s, rel, t, _lbl in ID_PAIR_RE.findall(blob):
        out.append((s, rel, t))
    return out

# ---------------------------------------------------------------------------
# Predicate extraction (simple regex)
# ---------------------------------------------------------------------------
PRED_RE = re.compile(
    r"\b([A-Z][A-Za-z0-9_-]+)\s+"
    r"(uses|defines|influences|criticizes|extends|relates to)\s+"
    r"([A-Z][A-Za-z0-9_-]+)"
)

def extract_spacyish_predicates(text: str):
    return [(a, v, b) for a, v, b in PRED_RE.findall(text or "")]

# ---------------------------------------------------------------------------
# Build three edge sets
# ---------------------------------------------------------------------------
def build_three_edge_sets(node_meta, org_edges):
    print("[GRAPH] Building edge sets (org, relations, spacy)...")
    edges = {"org": set(org_edges), "relations": set(), "spacy": set()}
    title_index = defaultdict(set)
    for nid, meta in node_meta.items():
        title = (meta["title"] or "").strip()
        if title:
            title_index[title].add(nid)
    for nid, meta in tqdm(node_meta.items(), desc="Scanning node files"):
        path = meta["file"]
        if not path or not path.is_file():
            continue
        try:
            txt = path.read_text(encoding="utf-8", errors="ignore")
        except Exception:
            continue
        for s, rel, t in extract_node_relations(txt):
            if s in node_meta and t in node_meta:
                edges["relations"].add((s, t, rel))
        for a, v, b in extract_spacyish_predicates(txt):
            s_ids = title_index.get(a, set())
            t_ids = title_index.get(b, set())
            if len(s_ids) == 1 and len(t_ids) == 1:
                s = next(iter(s_ids))
                t = next(iter(t_ids))
                edges["spacy"].add((s, t, v))
    print(f"[GRAPH] org:{len(edges['org'])}  relations:{len(edges['relations'])}  spacy:{len(edges['spacy'])}\n")
    return edges

# ---------------------------------------------------------------------------
# Build RelationalCell and stabilize via C-closure
# ---------------------------------------------------------------------------
def id_mapping(ids):
    idx = {sid: i for i, sid in enumerate(sorted(ids))}
    fwd = {sid: (i, 0) for sid, i in idx.items()}
    rev = {pair: sid for sid, pair in fwd.items()}
    return fwd, rev

def build_cell_from_edges(all_ids, org_edges, rel_edges, spacy_edges):
    print("[CELL] Constructing initial relational cell...")
    cell = RelationalCell()
    fwd, _ = id_mapping(all_ids)
    for sid in all_ids:
        n = fwd[sid]
        cell.Y.setdefault(n, set())

    def add_edge(sid, tid):
        i = fwd[sid]
        j = fwd[tid]
        cell.Y.setdefault(i, set()).add(j)

    for s, t in org_edges:
        add_edge(s, t)
    for s, t, _ in rel_edges:
        add_edge(s, t)
    for s, t, _ in spacy_edges:
        add_edge(s, t)

    print(f"[CELL] Added {sum(len(v) for v in cell.Y.values())} total edges across {len(cell.Y)} nodes.\n")
    return cell

def stabilize_by_C(cell, max_steps=10000):
    print("[STABILIZE] Starting C-closure iterations...")
    steps = 0
    while steps < max_steps:
        evt = cell.step(prefer="C")
        if evt is None:
            break
        steps += 1
        if steps % 1000 == 0:
            print(f"  ...{steps} closure steps")
    print(f"[STABILIZE] Converged after {steps} steps.\n")
    return steps

# ---------------------------------------------------------------------------
# Transitive reduction
# ---------------------------------------------------------------------------
def transitive_reduction(Y):
    print("[COMPRESS] Performing transitive reduction...")
    nodes = list(nodeset(Y))
    reach = {u: set() for u in nodes}
    for u in nodes:
        stack = list(Y.get(u, ()))
        seen = set()
        while stack:
            x = stack.pop()
            if x in seen:
                continue
            seen.add(x)
            reach[u].add(x)
            stack.extend(Y.get(x, ()))
    Yred = {u: set(vs) for u, vs in Y.items()}
    removed = 0
    for u in nodes:
        for v in list(Y.get(u, ())):
            Yred[u].discard(v)
            stack = list(Yred.get(u, ()))
            seen = set()
            found = False
            while stack:
                x = stack.pop()
                if x in seen:
                    continue
                if x == v:
                    found = True
                    break
                seen.add(x)
                stack.extend(Yred.get(x, ()))
            if not found:
                Yred[u].add(v)
            else:
                removed += 1
    print(f"[COMPRESS] Removed {removed} redundant edges.\n")
    return Yred

# ---------------------------------------------------------------------------
# RDF writer
# ---------------------------------------------------------------------------
def write_rdf_turtle(output_path, node_meta, kept_edges):
    print(f"[RDF] Writing {len(kept_edges)} edges to {output_path} ...")
    def iri_node(sid): return f":node/{sid}"
    with open(output_path, "w", encoding="utf-8") as f:
        f.write('@prefix : <http://example.org/roam#> .\n')
        f.write('@prefix prov: <http://www.w3.org/ns/prov#> .\n\n')
        for sid, meta in node_meta.items():
            f.write(f'{iri_node(sid)} a :Node ; :title {json.dumps(meta["title"])} .\n')
        f.write("\n")
        for (s, p, t) in sorted(kept_edges):
            f.write(f'{iri_node(s)} {p} {iri_node(t)} .\n')
    print("[RDF] Finished writing Turtle file.\n")

# ---------------------------------------------------------------------------
# Pipeline
# ---------------------------------------------------------------------------
def main():
    print("[PIPELINE] Starting full stabilization + export pipeline.\n")
    node_meta, org_edges = load_nodes_and_org_edges(DB_PATH)
    edges = build_three_edge_sets(node_meta, org_edges)

    all_ids = set(node_meta.keys())
    cell = build_cell_from_edges(all_ids,
                                 list(edges["org"]),
                                 list(edges["relations"]),
                                 list(edges["spacy"]))
    stabilize_by_C(cell)
    Yred = transitive_reduction(cell.Y)

    print("[ANALYSIS] Computing coherence and summary stats...")
    print(f"  Coherence index: {coherence_index(cell):.3f}")
    print("  Summary:")
    print(summary(cell))
    print()

    kept = set()
    for s, tidset in Yred.items():
        for t in tidset:
            if (s, t) in edges["org"]:
                pred = ":orgLink"
            elif any((s == a and t == b) for (a, b, _) in edges["relations"]):
                pred = ":declaredRelation"
            elif any((s == a and t == b) for (a, b, _) in edges["spacy"]):
                pred = ":spacyPredicate"
            else:
                pred = ":inferred"
            kept.add((s, pred, t))

    write_rdf_turtle(OUTPUT_TTL, node_meta, kept)
    print("[PIPELINE] Done.\n")

# ---------------------------------------------------------------------------
if __name__ == "__main__":
    main()
