import json
from pathlib import Path
from typing import Any, Dict, List

ROOT = Path(__file__).resolve().parent.parent
OUTPUT_FILE = ROOT / "directory-index.json"

# Keep this list tight: you probably don't want infra internals in the catalog.
IGNORED_DIRS = {
    ".git",
    "__pycache__",
    ".venv",
    "node_modules",
    "tools",
}

# Ignore the output so it doesn't show up in its own listing.
IGNORED_FILES = {
    OUTPUT_FILE.name,
}


def build_tree(root: Path, rel: Path = Path(".")) -> Dict[str, Any]:
    abs_path = root / rel

    # Root node is a virtual directory "/"
    if rel == Path("."):
        name = ""
        path_str = "/"
    else:
        name = rel.name
        rel_posix = rel.as_posix().lstrip("./")
        path_str = f"/{rel_posix}" if rel_posix else "/"

    children: List[Dict[str, Any]] = []

    # Sort: directories first, then files, both alpha.
    entries = sorted(abs_path.iterdir(), key=lambda p: (p.is_file(), p.name.lower()))

    for entry in entries:
        entry_name = entry.name

        if entry.is_dir():
            if entry_name in IGNORED_DIRS:
                continue
            children.append(build_tree(root, rel / entry_name))
            continue

        # Files
        if entry_name in IGNORED_FILES:
            continue

        rel_file = (rel / entry_name)
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

    # Deterministic output
    content = json.dumps(tree, indent=2) + "\n"

    if OUTPUT_FILE.exists():
        old = OUTPUT_FILE.read_text(encoding="utf-8")
        if old == content:
            print("directory-index.json is up to date")
            return

    OUTPUT_FILE.write_text(content, encoding="utf-8")
    print(f"Wrote {OUTPUT_FILE.name}")


if __name__ == "__main__":
    main()
