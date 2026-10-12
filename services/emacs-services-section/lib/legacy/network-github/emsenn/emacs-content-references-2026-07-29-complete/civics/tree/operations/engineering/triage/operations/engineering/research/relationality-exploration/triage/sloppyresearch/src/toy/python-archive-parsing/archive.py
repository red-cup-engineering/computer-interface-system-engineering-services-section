#!/usr/bin/env python3
"""
produce_archive.py
Rank Org-roam notes by a composite of graph centrality,
textual coherence, stability, and predicate density.
Writes ~/archive.txt ordered from most to least coherent.
"""

import os, re, sqlite3, math, json
from pathlib import Path
from tqdm import tqdm
import spacy

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

DB_PATH       = Path.home() / ".emacs.d/org-roam.db"   # change if your DB lives elsewhere
ORG_ROAM_DIR  = Path.home() / "ems/org"            # adjust to your org-roam-directory
ARCHIVE_PATH  = Path.home() / "archive.txt"

# ---------------------------------------------------------------------------
# NLP setup
# ---------------------------------------------------------------------------

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

def predicate_density(text):
    triples = extract_predicates(text)
    sents = max(1, len(list(nlp(text).sents)))
    return min(1.0, len(triples)/sents)

# ---------------------------------------------------------------------------
# Basic text features
# ---------------------------------------------------------------------------

def text_coherence(path):
    """Definition density: ratio of 'is/are/means/refers to' to sentences."""
    try:
        txt = Path(path).read_text(encoding="utf-8", errors="ignore")
    except Exception:
        return 0.0
    defs = len(re.findall(r"\b(is|are|means|refers to)\b", txt))
    sents = max(1, len(re.findall(r"[.?!]", txt)))
    return min(1.0, defs / sents)

def suggest_predicates(text):
    pat = re.compile(
        r"\b([A-Z][A-Za-z0-9_-]+)\s+"
        r"(uses|defines|influences|criticizes|extends|relates to)\s+"
        r"([A-Z][A-Za-z0-9_-]+)"
    )
    return [f"{a} {v} {b}" for a, v, b in pat.findall(text)]

# ---------------------------------------------------------------------------
# Graph features from org-roam.db
# ---------------------------------------------------------------------------

def degree_and_reciprocity(cur, node_id):
    """Return (degree, reciprocity) for node_id."""
    outs = [r[0] for r in cur.execute(
        "SELECT dest FROM links WHERE source=?", (node_id,))]
    ins = [r[0] for r in cur.execute(
        "SELECT source FROM links WHERE dest=?", (node_id,))]
    degree = len(set(outs + ins))
    reciprocity = len(set(outs) & set(ins)) / len(outs) if outs else 0.0
    return degree, reciprocity

# ---------------------------------------------------------------------------
# Path normalization
# ---------------------------------------------------------------------------

def normalize_path(raw):
    """Clean quotes and join relative paths to ORG_ROAM_DIR."""
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
# Main
# ---------------------------------------------------------------------------

def produce_archive():
    if not DB_PATH.exists():
        print(f"Database not found: {DB_PATH}")
        return

    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute("SELECT id, file, title FROM nodes")
    nodes = cur.fetchall()
    if not nodes:
        print("No nodes found in DB.")
        return

    print(f"Loaded {len(nodes)} nodes from DB")

    # compute max degree for normalization
    maxdeg = 1
    degrees = []
    for nid, f, t in nodes:
        d, _ = degree_and_reciprocity(cur, nid)
        degrees.append(d)
    if degrees:
        maxdeg = max(degrees)

    scored = []
    for node_id, file, title in tqdm(nodes, desc="Scoring"):
        path = normalize_path(file)
        if not path or not path.is_file():
            continue
        deg, recip = degree_and_reciprocity(cur, node_id)
        central = deg / maxdeg if maxdeg else 0
        coherence = text_coherence(path)
        stability = (recip + coherence) / 2
        try:
            text = path.read_text(encoding="utf-8", errors="ignore")
        except Exception:
            text = ""
        pred_density = predicate_density(text)
        predicate_score = pred_density
        # composite score
        score = (
            0.35 * central +
            0.35 * coherence +
            0.15 * stability +
            0.15 * predicate_score
        )
        scored.append((score, path, title or path.name, text))

    if not scored:
        print("No readable files.")
        return

    scored.sort(reverse=True, key=lambda x: x[0])

    with open(ARCHIVE_PATH, "w", encoding="utf-8") as out:
        for score, path, title, text in scored:
            out.write(f"--------\n{path.name}\nScore: {score:.2f}\n--------\n")
            out.write(text)
            if score < 0.4:
                preds = suggest_predicates(text)
                if preds:
                    out.write("\n;; Possible relations:\n")
                    for p in preds:
                        out.write(f";; {p}\n")
            out.write("\n\n")

    print(f"\nArchive written to {ARCHIVE_PATH}")

# ---------------------------------------------------------------------------

if __name__ == "__main__":
    produce_archive()
