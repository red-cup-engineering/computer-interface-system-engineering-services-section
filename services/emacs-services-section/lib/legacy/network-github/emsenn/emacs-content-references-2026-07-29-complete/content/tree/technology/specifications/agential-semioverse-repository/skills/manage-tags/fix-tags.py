#!/usr/bin/env python3
"""Fix and normalize tags in vault frontmatter.

Handles:
1. Tags that are file paths (contain "/" or ".md") — removed
2. Tags that are YAML field names (start with "name:") — removed
3. Tags containing markdown links or LaTeX — removed
4. type/ tags remaining in tags array — removed (should be type: field)
5. Discipline-echo tags that duplicate directory position — removed
6. Structural/workflow tags — removed
7. CamelCase normalization (capitalize every word)
8. Deduplication

Tags follow the vault's CamelCase convention: every word capitalized,
including articles and prepositions (per WCAG screen reader guidance).
"""

import os
import re
import sys
import io

# Fix Windows console encoding
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

CONTENT_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "content")

# Directories to skip entirely
SKIP_DIRS = {"private", ".obsidian"}

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


def is_already_camel(tag):
    """Return True if tag is already in CamelCase."""
    if len(tag) < 2:
        return False
    return any(c.isupper() for c in tag[1:])


def to_camel_case(tag):
    """Convert a lowercase-hyphenated tag to CamelCase."""
    if tag in CAMEL_OVERRIDES:
        return CAMEL_OVERRIDES[tag]
    if is_already_camel(tag):
        return tag
    parts = tag.split("-")
    return "".join(p.capitalize() for p in parts)


def get_discipline_root(filepath):
    """Return the top-level discipline directory for a file path."""
    rel = os.path.relpath(filepath, CONTENT_DIR).replace(os.sep, "/")
    parts = rel.split("/")
    if len(parts) < 2:
        return None
    return parts[0]


def is_bad_tag(tag):
    """Return a reason string if the tag should be removed, else None."""
    # File paths
    if ".md" in tag:
        return "contains .md (file path)"
    # type/ tags (should be type: field now)
    if tag.startswith("type/"):
        return "type/ tag (should be type: field)"
    # Slash in tag
    if "/" in tag:
        return f"contains / (looks like path: {tag})"
    # YAML field name leaked into tags
    if tag.startswith("name:"):
        return "starts with name: (YAML field)"
    # Markdown links
    if "[" in tag or "]" in tag:
        return "contains markdown link syntax"
    # LaTeX
    if "$" in tag or "\\" in tag:
        return "contains LaTeX"
    return None


def normalize_tag(tag, discipline_root=None):
    """Return (normalized_tag, reason) or (None, reason) to remove."""
    # Check if it's outright bad
    reason = is_bad_tag(tag)
    if reason:
        return None, reason

    # Check discipline echo
    lower = tag.lower()
    if discipline_root and discipline_root in DISCIPLINE_ECHO:
        if lower in DISCIPLINE_ECHO[discipline_root]:
            return None, f"discipline echo: {tag} in {discipline_root}/"

    # Check structural tags
    if lower in REMOVE_TAGS:
        return None, f"structural tag: {tag}"

    # CamelCase normalization
    camel = to_camel_case(tag)
    if camel != tag:
        return camel, f"CamelCase: {tag} -> {camel}"

    return tag, None


def parse_frontmatter(content):
    """Parse frontmatter from markdown content."""
    if not content.startswith("---"):
        return None, content, False
    end = content.find("\n---", 3)
    if end < 0:
        return None, content, False
    fm = content[4:end]
    body = content[end + 4:]
    return fm, body, True


def extract_tags_from_frontmatter(fm_lines):
    """Find the tags section in frontmatter lines.

    Returns (tag_start_idx, tag_end_idx, tags_list, indent).
    """
    tags_start = None
    tags = []
    indent = "  "

    for i, line in enumerate(fm_lines):
        stripped = line.strip()
        if stripped.startswith("tags:"):
            tags_start = i
            rest = stripped[5:].strip()
            if rest.startswith("["):
                inner = rest.strip("[]")
                if inner:
                    tags = [t.strip().strip('"').strip("'") for t in inner.split(",")]
                return tags_start, i + 1, tags, indent
            continue

        if tags_start is not None and i > tags_start:
            if stripped.startswith("- "):
                leading = len(line) - len(line.lstrip())
                if leading > 0:
                    indent = line[:leading]
                tag_val = stripped[2:].strip().strip('"').strip("'")
                tags.append(tag_val)
            elif stripped == "" or stripped.startswith("#"):
                continue
            else:
                return tags_start, i, tags, indent

    if tags_start is not None:
        return tags_start, len(fm_lines), tags, indent

    return None, None, [], indent


def rebuild_tags_section(tags, indent="  "):
    """Build the YAML lines for a tags section."""
    if not tags:
        return ["tags: []"]
    lines = ["tags:"]
    for tag in tags:
        if any(c in tag for c in ":#{}[]&*?|>!%@`"):
            lines.append(f'{indent}- "{tag}"')
        else:
            lines.append(f"{indent}- {tag}")
    return lines


def process_file(filepath):
    """Process a single file. Returns list of changes made, or empty list."""
    with open(filepath, "r", encoding="utf-8", errors="replace") as f:
        content = f.read()

    fm_str, body, has_fm = parse_frontmatter(content)
    if not has_fm:
        return []

    fm_lines = fm_str.split("\n")
    tags_start, tags_end, tags, indent = extract_tags_from_frontmatter(fm_lines)

    if tags_start is None or not tags:
        return []

    discipline_root = get_discipline_root(filepath)

    changes = []
    new_tags = []
    seen = set()

    for tag in tags:
        normalized, reason = normalize_tag(tag, discipline_root)
        if normalized is None:
            changes.append(f"  REMOVED: \"{tag}\" ({reason})")
            continue
        if reason:
            changes.append(f"  CHANGED: \"{tag}\" -> \"{normalized}\" ({reason})")

        # Deduplicate
        if normalized.lower() in seen:
            changes.append(f"  DEDUPED: \"{normalized}\" (duplicate after normalization)")
            continue
        seen.add(normalized.lower())
        new_tags.append(normalized)

    if not changes:
        return []

    # Rebuild the frontmatter
    new_tag_lines = rebuild_tags_section(new_tags, indent)
    new_fm_lines = fm_lines[:tags_start] + new_tag_lines + fm_lines[tags_end:]
    new_fm_str = "\n".join(new_fm_lines)
    new_content = "---\n" + new_fm_str + "\n---" + body

    with open(filepath, "w", encoding="utf-8", newline="\n") as f:
        f.write(new_content)

    return changes


def main():
    total_files = 0
    total_changes = 0
    changes_by_type = {
        "removed": 0,
        "changed": 0,
        "deduped": 0,
    }

    for root, dirs, files in os.walk(CONTENT_DIR):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]

        for f in files:
            if not f.endswith(".md"):
                continue
            filepath = os.path.join(root, f)
            changes = process_file(filepath)
            if changes:
                total_files += 1
                rel = os.path.relpath(filepath, CONTENT_DIR)
                print(f"\n{rel}:")
                for change in changes:
                    print(change)
                    total_changes += 1
                    if "REMOVED" in change:
                        changes_by_type["removed"] += 1
                    elif "CHANGED" in change:
                        changes_by_type["changed"] += 1
                    elif "DEDUPED" in change:
                        changes_by_type["deduped"] += 1

    print(f"\n{'=' * 60}")
    print(f"Summary:")
    print(f"  Files modified: {total_files}")
    print(f"  Total tag changes: {total_changes}")
    print(f"    Removed (bad/echo/structural): {changes_by_type['removed']}")
    print(f"    Changed (CamelCase): {changes_by_type['changed']}")
    print(f"    Deduped: {changes_by_type['deduped']}")


if __name__ == "__main__":
    main()
