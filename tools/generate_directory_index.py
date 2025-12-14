import json
import os
from pathlib import Path
from typing import Dict, List, Any


ROOT = Path(__file__).resolve().parent
OUTPUT_FILE = ROOT / "directory-index.json"

IGNORED_DIRS = {
    ".git",
    ".github",
    "__pycache__",
    ".venv",
    "node_modules",
    "tools",
}

IGNORED_FILES = {
    OUTPUT_FILE.name,
}


def build_tree(root: Path, rel: Path = Path(".")) -> Dict[str, Any]:
    """Build a nested directory tree starting at rel (relative to root)."""
    abs_path = root / rel

    if rel == Path("."):
        path_str = "/"
        name = ""
    else:
        # Always use POSIX-style paths in JSON
        rel_posix = rel.as_posix().lstrip("./")
        path_str = f"/{rel_posix}" if rel_posix else "/"
        name = rel.name

    children: List[Dict[str, Any]] = []

    # Sort: directories first, then files; both alphabetically
    entries = sorted(
        abs_path.iterdir(),
        key=lambda p: (p.is_file(), p.name.lower()),
    )

    for entry in entries:
        entry_name = entry.name

        if entry.is_dir():
            if entry_name in IGNORED_DIRS:
                continue
            child_rel = rel / entry_name
            child_tree = build_tree(root, child_rel)
            children.append(child_tree)
        else:
            if entry_name in IGNORED_FILES:
                continue
            rel_file = rel / entry_name
            rel_file_posix = rel_file.as_posix().lstrip("./")
            children.append(
                {
                    "name": entry_name,
                    "path": f"/{rel_file_posix}" if rel_file_posix else f"/{entry_name}",
                    "type": "file",
                }
            )

    return {
        "name": name,
        "path": path_str,
        "type": "directory",
        "children": children,
    }


def main() -> None:
    tree = build_tree(ROOT)

    # Ensure deterministic output
    json_str = json.dumps(tree, indent=2, sort_keys=False) + "\n"

    # Only rewrite if content changed
    if OUTPUT_FILE.exists():
        existing = OUTPUT_FILE.read_text(encoding="utf-8")
        if existing == json_str:
            print("directory-index.json is up to date")
            return

    OUTPUT_FILE.write_text(json_str, encoding="utf-8")
    print(f"Wrote {OUTPUT_FILE.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
