from collections import Counter
from pathlib import Path

import yaml


def collect_nav_paths(node, paths):
  if isinstance(node, str):
    if node.endswith(".md"):
      paths.append(Path(node).as_posix())
    return

  if isinstance(node, dict):
    for value in node.values():
      collect_nav_paths(value, paths)
    return

  if isinstance(node, list):
    for value in node:
      collect_nav_paths(value, paths)


def main():
  repository = Path(__file__).resolve().parent.parent
  config_path = repository / ".config" / "mkdocs.yml"
  config = yaml.load(config_path.read_text(encoding="utf-8"), Loader=yaml.BaseLoader)
  docs_dir = (config_path.parent / config["docs_dir"]).resolve()

  nav_paths = []
  collect_nav_paths(config["nav"], nav_paths)
  nav_set = set(nav_paths)
  doc_paths = {
    path.relative_to(docs_dir).as_posix()
    for path in docs_dir.rglob("*.md")
    if path.is_file()
  }
  missing = sorted(nav_set - doc_paths)
  orphaned = sorted(doc_paths - nav_set)
  duplicated = sorted(path for path, count in Counter(nav_paths).items() if count > 1)

  if missing:
    print("nav references Markdown files that do not exist:")
    print("\n".join(f"  {path}" for path in missing))
  if orphaned:
    print("Markdown files are not included in nav:")
    print("\n".join(f"  {path}" for path in orphaned))
  if duplicated:
    print("nav includes Markdown files more than once:")
    print("\n".join(f"  {path}" for path in duplicated))

  return 1 if missing or orphaned or duplicated else 0


raise SystemExit(main())
