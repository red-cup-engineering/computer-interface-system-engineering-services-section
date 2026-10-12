"""tag_normalize.py — Shared tag normalization logic.

Pure functions for normalizing, validating, and deduplicating tags
per the vault's CamelCase convention. No I/O, no side effects.

Used by:
    - fix-tags.py (vault-wide tag cleanup)
    - infer-triage-frontmatter.py (post-processing LLM-generated tags)
"""

import re


# ── CamelCase conversion ─────────────────────────────────────────────

CAMEL_OVERRIDES = {
    "3d-printing": "3DPrinting",
    "ai": "AI",
    "covid-19": "COVID19",
    "gnoponemacs": "GnoponEmacs",
    "inaturalist": "INaturalist",
    "mkdocs": "MkDocs",
    "org-mode": "OrgMode",
    "ritm": "RITM",
}


# ── Discipline-echo removal ──────────────────────────────────────────

DISCIPLINE_ECHO = {
    "biology": {"biology"},
    "business": {"business"},
    "cosmology": {"cosmology"},
    "design": {"design"},
    "domestic": {"domestics", "domestic"},
    "ecology": {"ecology"},
    "education": {"education"},
    "fabrication": {"fabrication"},
    "games": {"games"},
    "information": {"information-theory"},
    "linguistics": {"linguistics"},
    "material-science": {"material-science"},
    "mathematics": {"mathematics"},
    "medicine": {"medicine"},
    "neurology": {"neurology"},
    "philosophy": {"philosophy"},
    "relationality": {"relationality"},
    "sociology": {"sociology"},
    "technology": {"technology"},
    "writing": {"writing"},
}

# ── Structural/workflow tags to remove ────────────────────────────────

REMOVE_TAGS = {
    "curricula", "curriculum", "curriculum-design",
    "stub", "triage", "misc", "terms", "texts",
    "lesson", "lesson-design", "references", "vault",
    "tab", "workflow", "workflows", "seo",
    "study", "personal", "explainer",
}


# ── CamelCase regex (canonical, used across all validators) ───────────

CAMELCASE_RE = re.compile(r"^[A-Z][a-zA-Z0-9]+$")


def is_already_camel(tag: str) -> bool:
    """Return True if tag is already in CamelCase."""
    if len(tag) < 2:
        return False
    return any(c.isupper() for c in tag[1:])


def to_camel_case(tag: str) -> str:
    """Convert a lowercase-hyphenated tag to CamelCase."""
    if tag in CAMEL_OVERRIDES:
        return CAMEL_OVERRIDES[tag]
    if is_already_camel(tag):
        return tag
    parts = tag.split("-")
    return "".join(p.capitalize() for p in parts)


def is_bad_tag(tag: str) -> str | None:
    """Return a reason string if the tag should be removed, else None."""
    if ".md" in tag:
        return "contains .md (file path)"
    if tag.startswith("type/"):
        return "type/ tag (should be type: field)"
    if "/" in tag:
        return f"contains / (looks like path: {tag})"
    if tag.startswith("name:"):
        return "starts with name: (YAML field)"
    if "[" in tag or "]" in tag:
        return "contains markdown link syntax"
    if "$" in tag or "\\" in tag:
        return "contains LaTeX"
    return None


def get_discipline_root(filepath: str, content_dir: str) -> str | None:
    """Return the top-level discipline directory for a file path.

    Args:
        filepath: Absolute or relative path to the file.
        content_dir: Absolute path to the content root directory.
    """
    import os
    rel = os.path.relpath(filepath, content_dir).replace(os.sep, "/")
    parts = rel.split("/")
    if len(parts) < 2:
        return None
    return parts[0]


def normalize_tag(tag: str, discipline_root: str | None = None) -> tuple[str | None, str | None]:
    """Normalize a single tag. Returns (normalized_tag, reason).

    Returns (None, reason) if the tag should be removed.
    Returns (tag, None) if no change was needed.
    Returns (new_tag, reason) if the tag was changed.
    """
    reason = is_bad_tag(tag)
    if reason:
        return None, reason

    lower = tag.lower()
    if discipline_root and discipline_root in DISCIPLINE_ECHO:
        if lower in DISCIPLINE_ECHO[discipline_root]:
            return None, f"discipline echo: {tag} in {discipline_root}/"

    if lower in REMOVE_TAGS:
        return None, f"structural tag: {tag}"

    camel = to_camel_case(tag)
    if camel != tag:
        return camel, f"CamelCase: {tag} -> {camel}"

    return tag, None


def deduplicate_tags(tags: list[str]) -> tuple[list[str], list[str]]:
    """Case-insensitive deduplication. Returns (unique_tags, removed_duplicates)."""
    seen: set[str] = set()
    unique = []
    removed = []
    for tag in tags:
        key = tag.lower()
        if key in seen:
            removed.append(tag)
        else:
            seen.add(key)
            unique.append(tag)
    return unique, removed
