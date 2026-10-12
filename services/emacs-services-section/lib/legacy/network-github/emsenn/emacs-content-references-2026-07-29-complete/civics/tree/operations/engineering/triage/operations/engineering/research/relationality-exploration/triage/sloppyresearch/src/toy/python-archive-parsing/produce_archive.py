#!/usr/bin/env python3
"""
produce_archive.py
Merge three edge sources into a single directed graph:

  • Org-roam links      – from org-roam.db
  • spaCy predicates    – from note text
  • NODE-RELATIONS prop – from note metadata

Ranks nodes by a composite of degree centrality and text coherence.
Outputs ~/archive.txt in descending order.
"""

import os, re, sqlite3
from pathlib import Path
from collections import defaultdict, Counter
from tqdm import tqdm
import spacy
from sexpdata import loads, Symbol

# --------------------------------------------------------------------
# Configuration
# --------------------------------------------------------------------

DB_PATH      = Path.home() / ".emacs.d/org-roam.db"     # path to your org-roam.db
ORG_ROAM_DIR = Path.home() / "ems/org"              # your org-roam directory
ARCHIVE_PATH = Path.home() / "archive.txt"

# --------------------------------------------------------------------
# NLP setup
# --------------------------------------------------------------------

print("Loading spaCy model...")
nlp = spacy.load("en_core_web_sm", disable=["ner", "textcat"])

def extract_predicates(text):
    """Return list of (subj, verb, obj) triples."""
    triples = []
    doc = nlp(text)
    for sent in doc.sents:
        for token in sent:
            if token.pos_ == "VERB":
                subs = [w.text for w in token.lefts if w.dep_.startswith("nsubj")]
                objs = [w.text for w in token.rights if w.dep_.startswith("dobj")]
                for s in subs:
                    for o in objs:
                        triples.append((s, token.lemma_, o))
    return triples

# --------------------------------------------------------------------
# Parse NODE-RELATIONS
# --------------------------------------------------------------------

def parse_node_relations(raw):
    """Extract (src_id, relation, dst_id) from NODE-RELATIONS property text."""
    edges = []
    if not raw:
        return edges
    try:
        # raw is literal lisp list as text
        sexp = loads(raw)
    except Exception:
        # Fallback regex
        for m in re.finditer(
            r"\[\[id:([^\]]+)\]\]\[([^\]]+)\].*?\[\[id:([^\]]+)\]\]\[([^\]]+)\]",
            raw,
        ):
            src, rel, dst, _ = m.groups()
            edges.append((src, rel, dst))
        return edges

    # sexp parse path (very forgiving)
    def extract(node):
        if isinstance(node, list) and len(node) == 2:
            left, right = node
            if isinstance(left, list) and isinstance(right, list):
                try:
                    src_id = str(left[0].value()).split(":")[1]
                    dst_id = str(right[0].value()).split(":")[1]
                    rel = str(left[1].value()) if isinstance(left[1], Symbol) else str(left[1])
                    edges.append((src_id, rel, dst_id))
                except Exception:
                    pass
        elif isinstance(node, list):
            for n in node:
                extract(n)
    extract(sexp)
    return edges

# --------------------------------------------------------------------
# Text metrics
# --------------------------------------------------------------------

def text_coherence(path):
    """Simple definition density."""
    try:
        txt = Path(path).read_text(encoding="utf-8", errors="ignore")
    except Exception:
        return 0.0, ""
    defs = len(re.findall(r"\b(is|are|means|refers to)\b", txt))
    sents = max(1, len(re.findall(r"[.?!]", txt)))
    return min(1.0, defs / sents), txt

# --------------------------------------------------------------------
# Path normalization
# --------------------------------------------------------------------

def normalize_path(raw):
    """Strip quotes and join relative paths."""
    if not raw:
        return None
    s = str(raw).strip()
    if (s.startswith('"') and s.endswith('"')) or (s.startswith("'") and s.endswith("'")):
        s = s[1:-1]
    p = Path(s)
    if not p.is_absolute():
        p = ORG_ROAM_DIR / p
    return p.expanduser().resolve()

# --------------------------------------------------------------------
# Build merged graph
# --------------------------------------------------------------------

def build_graph(cur, nodes):
    """Return merged graph as dict: node -> list of (rel, target, type)."""
    graph = defaultdict(list)

    # --- Org-roam links
    for src, dst in cur.execute("SELECT source, dest FROM links WHERE dest != ''"):
        graph[src].append(("link", dst, "org"))

    # --- NODE-RELATIONS
    for node_id, file, title in tqdm(nodes, desc="Parsing NODE-RELATIONS"):
        path = normalize_path(file)
        if not path or not path.is_file():
            continue
        raw = ""
        try:
            with open(path, encoding="utf-8", errors="ignore") as f:
                for line in f:
                    if line.startswith(":NODE-RELATIONS:"):
                        raw = line.split(":", 2)[-1]
                        break
        except Exception:
            continue
        for src, rel, dst in parse_node_relations(raw):
            graph[src].append((rel, dst, "relations"))

    # --- spaCy predicates
    for node_id, file, title in tqdm(nodes, desc="Extracting predicates"):
        path = normalize_path(file)
        if not path or not path.is_file():
            continue
        try:
            text = Path(path).read_text(encoding="utf-8", errors="ignore")
        except Exception:
            continue
        triples = extract_predicates(text)
        for s, v, o in triples:
            graph[str(node_id)].append((v, o, "spacy"))

    return graph

# --------------------------------------------------------------------
# Scoring
# --------------------------------------------------------------------

def compute_scores(graph, nodes):
    """Return dict node_id -> score based on degree and coherence."""
    degree = Counter()
    for src, edges in graph.items():
        degree[src] += len(edges)
        for _, dst, _ in edges:
            degree[dst] += 1

    maxdeg = max(degree.values()) if degree else 1
    scores = {}
    for node_id, file, title in nodes:
        path = normalize_path(file)
        coh, text = text_coherence(path) if path and path.is_file() else (0.0, "")
        central = degree[node_id] / maxdeg
        score = 0.6 * central + 0.4 * coh
        scores[node_id] = (score, path, title or path.name, text)
    return scores

# --------------------------------------------------------------------
# Write archive
# --------------------------------------------------------------------

def write_archive(scores):
    ranked = sorted(scores.items(), key=lambda x: x[1][0], reverse=True)
    with open(ARCHIVE_PATH, "w", encoding="utf-8") as out:
        for node_id, (score, path, title, text) in ranked:
            if not path or not path.is_file():
                continue
            out.write(f"--------\n{path.name}\nScore: {score:.2f}\n--------\n")
            out.write(text)
            out.write("\n\n")
    print(f"\nArchive written to {ARCHIVE_PATH}")

# --------------------------------------------------------------------
# Main
# --------------------------------------------------------------------

def main():
    if not DB_PATH.exists():
        print(f"Database not found: {DB_PATH}")
        return
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    nodes = list(cur.execute("SELECT id, file, title FROM nodes"))
    if not nodes:
        print("No nodes found.")
        return
    graph = build_graph(cur, nodes)
    scores = compute_scores(graph, nodes)
    write_archive(scores)

# --------------------------------------------------------------------

if __name__ == "__main__":
    main()
