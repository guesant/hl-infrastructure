#!/usr/bin/env python3
import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

LT_HOST = os.environ.get("LT_HOST", "localhost")
LT_URL = f"http://{LT_HOST}:8010/v2/check"
LANGUAGES_URL = f"http://{LT_HOST}:8010/v2/languages"

CODE_FENCE = re.compile(r"```.*?```", re.DOTALL)
CODE_SPAN = re.compile(r"`[^`\n]+`")
MARKDOWN_LINK = re.compile(r"\[([^\]]*)\]\([^)]*\)")
HEADING_LINE = re.compile(r"^#{1,6}\s*(.+)$", re.MULTILINE)
LIST_MARK = re.compile(r"^\s*[-*+]\s+", re.MULTILINE)
TABLE_ROW = re.compile(r"^\|.*\|\s*$", re.MULTILINE)
HTML_COMMENT = re.compile(r"<!--.*?-->", re.DOTALL)
EXTRA_SPACE = re.compile(r"[ \t]{2,}")


def wait_for_languagetool(timeout=60):
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            urllib.request.urlopen(LANGUAGES_URL, timeout=3)
            return True
        except (urllib.error.URLError, ConnectionError, OSError):
            time.sleep(2)
    return False


def strip_markup(text: str) -> str:
    text = HTML_COMMENT.sub("", text)
    text = CODE_FENCE.sub("", text)
    text = TABLE_ROW.sub("", text)
    text = CODE_SPAN.sub("", text)
    text = MARKDOWN_LINK.sub(r"\1", text)
    text = HEADING_LINE.sub(r"\1.", text)
    text = LIST_MARK.sub("", text)
    text = EXTRA_SPACE.sub(" ", text)
    return text


def check_text(text: str) -> list[dict]:
    payload = urllib.parse.urlencode(
        {"text": text, "language": "pt-BR", "level": "default"}
    ).encode()
    request = urllib.request.Request(LT_URL, data=payload, method="POST")
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.loads(response.read()).get("matches", [])


def line_for_offset(text: str, offset: int) -> int:
    return text.count("\n", 0, offset) + 1


def main() -> int:
    if not wait_for_languagetool():
        print("LanguageTool não respondeu a tempo; abortando o relatório.", file=sys.stderr)
        return 0

    docs_dir = Path("docs")
    total = 0
    for path in sorted(docs_dir.rglob("*.md")):
        raw = path.read_text(encoding="utf-8")
        text = strip_markup(raw)
        try:
            matches = check_text(text)
        except (urllib.error.URLError, TimeoutError) as error:
            print(f"{path}: falha ao consultar o LanguageTool ({error})", file=sys.stderr)
            continue
        for match in matches:
            rule_id = match.get("rule", {}).get("id", "?")
            line = line_for_offset(text, match["offset"])
            context = match.get("context", {}).get("text", "").strip()
            print(f"{path}:{line}: {match['message']} [{rule_id}]")
            if context:
                print(f"    {context}")
            total += 1

    print(f"\n{total} sugestão(ões) do LanguageTool em {len(list(docs_dir.rglob('*.md')))} páginas.")
    print("Isto é um relatório, não um gate; nada aqui falha o just check.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
