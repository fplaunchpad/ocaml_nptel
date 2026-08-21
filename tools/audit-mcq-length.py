#!/usr/bin/env python3
"""Reject a course-wide "longest MCQ option is correct" giveaway.

The audit treats an option as longest after removing lightweight
Markdown punctuation and collapsing whitespace. A question is biased
when at least one correct option is strictly longer than every
distractor. The course-wide ceiling leaves room for naturally longer
answers while keeping the observed rate near the 25% chance baseline
for four-choice questions.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path


LECTURES_DIR = Path(__file__).resolve().parent.parent / "lectures"
MAX_BIASED_RATE = 0.35
MAX_LENGTH_RATIO = 2.0

QUIZ_RE = re.compile(r"^:::quiz mcq(?:\s+id=([^\s]+))?")
OPTION_RE = re.compile(r"^- \[([ xX])\] (.*)")
MARKUP_RE = re.compile(r"[`*_]")


def option_length(text: str) -> int:
    plain = MARKUP_RE.sub("", text)
    return len(" ".join(plain.split()))


def audit(path: Path) -> list[tuple[str, list[int], float]]:
    """Return biased questions as (id, option lengths, ratio)."""

    lines = path.read_text().splitlines()
    findings: list[tuple[str, list[int], float]] = []
    i = 0
    while i < len(lines):
        quiz = QUIZ_RE.match(lines[i])
        if not quiz:
            i += 1
            continue

        quiz_id = quiz.group(1) or f"{path.stem}:{i + 1}"
        options: list[tuple[bool, str]] = []
        current: list[object] | None = None
        i += 1
        while i < len(lines) and lines[i].strip() != ":::":
            option = OPTION_RE.match(lines[i])
            if option:
                if current:
                    options.append((bool(current[0]), str(current[1])))
                current = [option.group(1).lower() == "x", option.group(2)]
            elif current and lines[i].startswith("  "):
                current[1] = f"{current[1]} {lines[i].strip()}"
            i += 1
        if current:
            options.append((bool(current[0]), str(current[1])))

        if len(options) < 2:
            continue
        lengths = [option_length(text) for _, text in options]
        correct = [index for index, (is_correct, _) in enumerate(options) if is_correct]
        distractors = [lengths[index] for index in range(len(options)) if index not in correct]
        if not correct or not distractors:
            continue
        longest_distractor = max(distractors)
        longest_correct = max(lengths[index] for index in correct)
        if longest_correct > longest_distractor:
            findings.append(
                (quiz_id, lengths, longest_correct / max(longest_distractor, 1))
            )
    return findings


def main() -> int:
    question_count = 0
    findings: list[tuple[Path, str, list[int], float]] = []
    for path in sorted(LECTURES_DIR.glob("M*-L*.md")):
        text = path.read_text()
        question_count += sum(1 for line in text.splitlines() if QUIZ_RE.match(line))
        findings.extend((path, quiz_id, lengths, ratio) for quiz_id, lengths, ratio in audit(path))

    biased_count = len(findings)
    biased_rate = biased_count / question_count if question_count else 0.0
    severe = [finding for finding in findings if finding[3] > MAX_LENGTH_RATIO]

    print(
        f"mcq-length: {biased_count}/{question_count} "
        f"({biased_rate:.1%}) have a uniquely longest correct option"
    )
    if biased_rate > MAX_BIASED_RATE or severe:
        for path, quiz_id, lengths, ratio in sorted(
            findings, key=lambda finding: finding[3], reverse=True
        ):
            print(f"  {path.name} {quiz_id}: lengths={lengths}, ratio={ratio:.2f}")
        if biased_rate > MAX_BIASED_RATE:
            print(f"rate exceeds the {MAX_BIASED_RATE:.0%} course-wide ceiling")
        if severe:
            print(f"{len(severe)} question(s) exceed the {MAX_LENGTH_RATIO:.1f}x ratio ceiling")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
