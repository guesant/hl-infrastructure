#!/usr/bin/env python3
import argparse
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

CODE_FENCE = re.compile(r"```([\w-]*)\n.*?```", re.DOTALL)
HTML_COMMENT = re.compile(r"<!--.*?-->", re.DOTALL)
CODE_SPAN = re.compile(r"`[^`\n]+`")
SENTENCE_SPLIT = re.compile(r"(?<=[.!?])\s+")
STRUCTURAL_LINE = re.compile(
    r"^\s*(#{1,6}\s|\||>|-{3,}$|[-*+]\s|\d+\.\s|!!!\s|```)"
)


@dataclass
class Sentence:
    text: str
    words: int
    code_spans: int


@dataclass
class Paragraph:
    line: int
    sentences: list[Sentence] = field(default_factory=list)

    @property
    def sentence_count(self) -> int:
        return len(self.sentences)

    @property
    def code_spans(self) -> int:
        return sum(s.code_spans for s in self.sentences)


def is_structural(block: str) -> bool:
    lines = [line for line in block.splitlines() if line.strip()]
    return not lines or all(STRUCTURAL_LINE.match(line) for line in lines)


def split_sentences(block: str) -> list[Sentence]:
    spans = CODE_SPAN.findall(block)
    placeholder = block
    for index, span in enumerate(spans):
        placeholder = placeholder.replace(span, f"\x00{index}\x00", 1)
    placeholder = " ".join(placeholder.split())
    raw_sentences = [s for s in SENTENCE_SPLIT.split(placeholder) if s.strip()]

    sentences = []
    for raw in raw_sentences:
        restored = raw
        for index, span in enumerate(spans):
            restored = restored.replace(f"\x00{index}\x00", span)
        sentences.append(
            Sentence(
                text=restored,
                words=len(restored.split()),
                code_spans=restored.count("`") // 2,
            )
        )
    return sentences


def parse(path: Path) -> tuple[list[Paragraph], int]:
    text = path.read_text(encoding="utf-8")
    text = HTML_COMMENT.sub("", text)
    diagrams = sum(
        1 for match in CODE_FENCE.finditer(text) if match.group(1).lower() == "mermaid"
    )
    text = CODE_FENCE.sub("", text)

    paragraphs = []
    line_number = 1
    for block in re.split(r"\n\s*\n", text):
        block_start = line_number
        line_number += block.count("\n") + 1
        if is_structural(block):
            continue
        sentences = split_sentences(block)
        if sentences:
            paragraphs.append(Paragraph(line=block_start, sentences=sentences))
    return paragraphs, diagrams


def format_row(*columns: object, widths: tuple[int, ...]) -> str:
    return "  ".join(str(c).ljust(w) for c, w in zip(columns, widths))


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Measure paragraph, sentence, inline-code and diagram density in the docs prose."
    )
    parser.add_argument("paths", nargs="*", default=["docs"])
    parser.add_argument(
        "--min-sentences",
        type=int,
        default=3,
        help="paragraphs at or below this sentence count are listed as short",
    )
    parser.add_argument(
        "--max-sentences",
        type=int,
        default=5,
        help="paragraphs at or above this sentence count are listed as long",
    )
    parser.add_argument(
        "--max-spans-per-sentence",
        type=float,
        default=1.5,
        help="sentences at or above this code-span density are listed as saturated",
    )
    parser.add_argument("--top", type=int, default=15, help="rows per offender list")
    args = parser.parse_args()

    files = sorted(
        p
        for root in args.paths
        for p in (
            [Path(root)] if Path(root).is_file() else Path(root).rglob("*.md")
        )
    )
    if not files:
        print("no Markdown file found", file=sys.stderr)
        return 1

    widths = (46, 6, 6, 6, 6, 8, 8, 8, 5)
    print(
        format_row(
            "file",
            "paras",
            "sent",
            "s/p",
            "maxSP",
            "spans",
            "sp/p",
            "sp/sen",
            "diag",
            widths=widths,
        )
    )

    short_paragraphs: list[tuple[Path, Paragraph]] = []
    long_paragraphs: list[tuple[Path, Paragraph]] = []
    saturated_sentences: list[tuple[Path, int, Sentence]] = []
    total_diagrams = 0

    for path in files:
        paragraphs, diagrams = parse(path)
        total_diagrams += diagrams
        if not paragraphs and not diagrams:
            continue
        rel = path.relative_to(path.cwd()) if path.is_absolute() else path
        sentence_counts = [p.sentence_count for p in paragraphs] or [0]
        span_counts = [p.code_spans for p in paragraphs]
        total_sentences = sum(sentence_counts) if paragraphs else 0
        total_spans = sum(span_counts)
        avg_sentences = total_sentences / len(paragraphs) if paragraphs else 0
        avg_spans_per_paragraph = total_spans / len(paragraphs) if paragraphs else 0
        avg_spans_per_sentence = total_spans / total_sentences if total_sentences else 0

        print(
            format_row(
                str(rel),
                len(paragraphs),
                total_sentences,
                f"{avg_sentences:.1f}",
                max(sentence_counts),
                total_spans,
                f"{avg_spans_per_paragraph:.1f}",
                f"{avg_spans_per_sentence:.2f}",
                diagrams,
                widths=widths,
            )
        )

        for paragraph in paragraphs:
            if paragraph.sentence_count <= args.min_sentences:
                short_paragraphs.append((rel, paragraph))
            if paragraph.sentence_count >= args.max_sentences:
                long_paragraphs.append((rel, paragraph))
            for sentence in paragraph.sentences:
                if (
                    sentence.words >= 6
                    and sentence.code_spans / sentence.words * 10
                    >= args.max_spans_per_sentence
                ):
                    saturated_sentences.append((rel, paragraph.line, sentence))

    def offenders(title: str, rows: list, render) -> None:
        print(f"\n-- {title} ({len(rows)} total, showing up to {args.top}) --")
        for row in rows[: args.top]:
            print(render(row))

    offenders(
        f"paragraphs with <= {args.min_sentences} sentence(s)",
        sorted(short_paragraphs, key=lambda r: r[1].sentence_count),
        lambda r: f"{r[0]}:{r[1].line} ({r[1].sentence_count} sentence(s))",
    )
    offenders(
        f"paragraphs with >= {args.max_sentences} sentences",
        sorted(long_paragraphs, key=lambda r: -r[1].sentence_count),
        lambda r: f"{r[0]}:{r[1].line} ({r[1].sentence_count} sentences)",
    )
    offenders(
        f"sentences with >= {args.max_spans_per_sentence} code spans per 10 words",
        sorted(
            saturated_sentences,
            key=lambda r: -(r[2].code_spans / r[2].words),
        ),
        lambda r: f"{r[0]}:{r[1]} ({r[2].code_spans} span(s) in {r[2].words} words): {r[2].text[:110]}",
    )
    print(f"\ntotal mermaid diagrams: {total_diagrams}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
