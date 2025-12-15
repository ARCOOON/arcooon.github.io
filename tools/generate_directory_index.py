import json
from pathlib import Path
from typing import Any, Dict, List, Iterable

ROOT = Path(__file__).resolve().parent.parent

OUTPUT_JSON = ROOT / "directory-index.json"
OUTPUT_TREE_TXT = ROOT / "directory-tree.txt"
OUTPUT_INDEX_ASCII = ROOT / "index"  # lets you curl https://arcooon.github.io/index
OUTPUT_SCRIPTS_LIST = ROOT / "scripts-list.txt"  # pure-bash friendly list

IGNORED_DIRS = {
    ".git",
    "__pycache__",
    ".venv",
    "node_modules",
}

IGNORED_FILES = {
    OUTPUT_JSON.name,
    OUTPUT_TREE_TXT.name,
    OUTPUT_INDEX_ASCII.name,
    OUTPUT_SCRIPTS_LIST.name,
}


def build_tree(root: Path, rel: Path = Path(".")) -> Dict[str, Any]:
    abs_path = root / rel

    # Virtual root node is "/"
    if rel == Path("."):
        name = ""
        path_str = "/"
    else:
        name = rel.name
        rel_posix = rel.as_posix().lstrip("./")
        path_str = f"/{rel_posix}" if rel_posix else "/"

    children: List[Dict[str, Any]] = []
    entries = sorted(abs_path.iterdir(), key=lambda p: (p.is_file(), p.name.lower()))

    for entry in entries:
        entry_name = entry.name

        if entry.is_dir():
            if entry_name in IGNORED_DIRS:
                continue
            children.append(build_tree(root, rel / entry_name))
            continue

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


def _tree_lines(node: Dict[str, Any]) -> Iterable[str]:
    """Render deterministic ASCII tree (dirs first)."""

    def walk(n: Dict[str, Any], prefix: str, is_last: bool) -> List[str]:
        lines: List[str] = []

        name = n.get("name") or "/"
        path = n.get("path") or "/"
        ntype = n.get("type")

        # Skip printing the virtual root label; print its children at top-level.
        if path == "/" and not n.get("name"):
            out: List[str] = []
            kids = n.get("children", []) or []
            for i, ch in enumerate(kids):
                out.extend(walk(ch, "", i == len(kids) - 1))
            return out

        connector = "`-- " if is_last else "|-- "
        label = f"{name}" if ntype == "file" else f"{name}/"
        lines.append(f"{prefix}{connector}{label}")

        kids = n.get("children", []) or []
        if not kids:
            return lines

        new_prefix = prefix + ("    " if is_last else "|   ")
        for i, ch in enumerate(kids):
            lines.extend(walk(ch, new_prefix, i == len(kids) - 1))
        return lines

    return ["/", *walk(node, "", True)]


def _collect_script_paths(tree: Dict[str, Any]) -> List[str]:
    """Collect /scripts/*.sh paths from the JSON tree."""
    out: List[str] = []

    def walk(n: Dict[str, Any]) -> None:
        if n.get("type") == "file":
            p = n.get("path", "")
            if p.startswith("/scripts/") and p.endswith(".sh"):
                out.append(p)
            return
        for ch in n.get("children", []) or []:
            walk(ch)

    walk(tree)
    return sorted(out, key=lambda s: s.lower())


def write_if_changed(path: Path, content: str) -> bool:
    if path.exists():
        old = path.read_text(encoding="utf-8")
        if old == content:
            return False
    path.write_text(content, encoding="utf-8")
    return True


def main() -> None:
    tree = build_tree(ROOT)

    json_content = json.dumps(tree, indent=2) + "\n"
    txt_content = "\n".join(_tree_lines(tree)) + "\n"

    scripts = _collect_script_paths(tree)
    scripts_content = "\n".join(scripts) + ("\n" if scripts else "")

    changed = False
    changed |= write_if_changed(OUTPUT_JSON, json_content)
    changed |= write_if_changed(OUTPUT_TREE_TXT, txt_content)
    changed |= write_if_changed(OUTPUT_INDEX_ASCII, txt_content)
    changed |= write_if_changed(OUTPUT_SCRIPTS_LIST, scripts_content)

    if not changed:
        print("directory index outputs are up to date")
        return

    print(f"Wrote {OUTPUT_JSON.name}")
    print(f"Wrote {OUTPUT_TREE_TXT.name}")
    print(f"Wrote {OUTPUT_INDEX_ASCII.name}")
    print(f"Wrote {OUTPUT_SCRIPTS_LIST.name}")


if __name__ == "__main__":
    main()
