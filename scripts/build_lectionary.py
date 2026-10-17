#!/usr/bin/env python3
"""Build the offline lectionary and the Douay-Rheims verses it cites.

Citations and season names come from cpbjr/catholic-readings-api (MIT).
Verse text is the Challoner Douay-Rheims in scrollmapper/bible_databases (MIT
packaging; the translation is public domain). This script does not download
USCCB pages.

Usage:
  python3 scripts/build_lectionary.py \\
    --readings /tmp/srcdata/catholic-readings-api/readings \\
    --calendar /tmp/srcdata/catholic-readings-api/liturgical-calendar \\
    --drc /tmp/srcdata/DRC.json \\
    --out Sources/RosaryCore/Resources
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

ALIASES = [
    ("phiippians", "Philippians"),
    ("philippians", "Philippians"),
    ("song of songs", "Song of Solomon"),
    ("song of solomon", "Song of Solomon"),
    ("revelation of john", "Revelation of John"),
    ("revelation", "Revelation of John"),
    ("apocalypse", "Revelation of John"),
    ("sirarch", "Sirach"),
    ("ecclesiasticus", "Sirach"),
    ("sirach", "Sirach"),
    ("1 chronicles", "I Chronicles"),
    ("2 chronicles", "II Chronicles"),
    ("1 corinthians", "I Corinthians"),
    ("2 corinthians", "II Corinthians"),
    ("1 thessalonians", "I Thessalonians"),
    ("2 thessalonians", "II Thessalonians"),
    ("1 timothy", "I Timothy"),
    ("2 timothy", "II Timothy"),
    ("1 samuel", "I Samuel"),
    ("2 samuel", "II Samuel"),
    ("1 kings", "I Kings"),
    ("2 kings", "II Kings"),
    ("1 maccabees", "I Maccabees"),
    ("2 maccabees", "II Maccabees"),
    ("1 peter", "I Peter"),
    ("2 peter", "II Peter"),
    ("1 john", "I John"),
    ("2 john", "II John"),
    ("3 john", "III John"),
    ("psalms", "Psalms"),
    ("psalm", "Psalms"),
    ("genesis", "Genesis"),
    ("exodus", "Exodus"),
    ("leviticus", "Leviticus"),
    ("numbers", "Numbers"),
    ("deuteronomy", "Deuteronomy"),
    ("joshua", "Joshua"),
    ("judges", "Judges"),
    ("ruth", "Ruth"),
    ("ezra", "Ezra"),
    ("nehemiah", "Nehemiah"),
    ("tobit", "Tobit"),
    ("judith", "Judith"),
    ("esther", "Esther"),
    ("job", "Job"),
    ("proverbs", "Proverbs"),
    ("ecclesiastes", "Ecclesiastes"),
    ("wisdom", "Wisdom"),
    ("isaiah", "Isaiah"),
    ("jeremiah", "Jeremiah"),
    ("lamentations", "Lamentations"),
    ("baruch", "Baruch"),
    ("ezekiel", "Ezekiel"),
    ("daniel", "Daniel"),
    ("hosea", "Hosea"),
    ("joel", "Joel"),
    ("amos", "Amos"),
    ("obadiah", "Obadiah"),
    ("jonah", "Jonah"),
    ("micah", "Micah"),
    ("nahum", "Nahum"),
    ("habakkuk", "Habakkuk"),
    ("zephaniah", "Zephaniah"),
    ("haggai", "Haggai"),
    ("zechariah", "Zechariah"),
    ("malachi", "Malachi"),
    ("matthew", "Matthew"),
    ("mark", "Mark"),
    ("luke", "Luke"),
    ("john", "John"),
    ("acts", "Acts"),
    ("romans", "Romans"),
    ("galatians", "Galatians"),
    ("ephesians", "Ephesians"),
    ("colossians", "Colossians"),
    ("titus", "Titus"),
    ("philemon", "Philemon"),
    ("hebrews", "Hebrews"),
    ("james", "James"),
    ("jude", "Jude"),
]
ALIASES.sort(key=lambda item: len(item[0]), reverse=True)


def normalize(citation: str) -> str:
    text = citation.replace("\u00a0", " ").replace("\u2013", "-").replace("\u2014", "-")
    text = re.sub(r"\s+", " ", text).strip().strip(".")
    return text


def split_book(clause: str, carry: str | None) -> tuple[str | None, str]:
    lowered = clause.lower().strip()
    for alias, name in ALIASES:
        if lowered.startswith(alias) and (len(lowered) == len(alias) or not lowered[len(alias)].isalpha()):
            rest = clause[len(alias):].strip(" .")
            return name, rest
    return carry, clause.strip()


def parse_piece(part: str, book: str, chapter: int | None) -> tuple[tuple[str, int, int, int, int] | None, int | None]:
    # "19A", "6A", "10AB", "26b", and "12 cd" all keep the verse number.
    part = re.sub(r"(\d+)\s*[A-Za-z]+\b", r"\1", part.strip())
    part = re.sub(r"\s+", " ", part)
    match = re.fullmatch(r"(\d+)\s*:\s*(\d+)\s*-\s*(\d+)\s*:\s*(\d+)", part)
    if match:
        start_chapter, start_verse, end_chapter, end_verse = (int(match.group(i)) for i in range(1, 5))
        return (book, start_chapter, start_verse, end_chapter, end_verse), end_chapter
    match = re.fullmatch(r"(\d+)\s*:\s*(\d+(?:\s*-\s*\d+)+)", part)
    if match:
        start_chapter = int(match.group(1))
        numbers = [int(piece) for piece in re.split(r"\s*-\s*", match.group(2))]
        return (book, start_chapter, numbers[0], start_chapter, numbers[-1]), start_chapter
    match = re.fullmatch(r"(\d+)\s*:\s*(\d+)", part)
    if match:
        start_chapter, start_verse = int(match.group(1)), int(match.group(2))
        return (book, start_chapter, start_verse, start_chapter, start_verse), start_chapter
    match = re.fullmatch(r"(\d+(?:\s*-\s*\d+)+)", part)
    if match:
        current = chapter or 1
        numbers = [int(piece) for piece in re.split(r"\s*-\s*", match.group(1))]
        return (book, current, numbers[0], current, numbers[-1]), current
    match = re.fullmatch(r"(\d+)", part)
    if match:
        current = chapter or 1
        verse = int(match.group(1))
        return (book, current, verse, current, verse), current
    return None, chapter


def ranges(citation: str) -> list[list[tuple[str, int, int, int, int]]]:
    """Alternatives (split on 'or'), each a list of inclusive ranges."""
    text = normalize(citation)
    if re.fullmatch(r"\d.*", text) and not re.search(r"[A-Za-z]", text):
        text = "Psalm " + text
    alternatives = re.split(r"\s+or\s+", text, flags=re.IGNORECASE)
    parsed: list[list[tuple[str, int, int, int, int]]] = []
    carry_book: str | None = None
    for alternative in alternatives:
        group: list[tuple[str, int, int, int, int]] = []
        for raw_clause in alternative.split(";"):
            clause = raw_clause.strip()
            if not clause:
                continue
            book, rest = split_book(clause, carry_book)
            if book:
                carry_book = book
            if not book or not rest:
                continue
            body = re.sub(r"\band\b", ",", rest, flags=re.IGNORECASE)
            chapter: int | None = None
            for piece in body.split(","):
                piece = piece.strip()
                if not piece:
                    continue
                span, chapter = parse_piece(piece, book, chapter)
                if span:
                    group.append(span)
        parsed.append(group)
    return parsed


def load_drc(path: Path) -> dict[str, dict[int, dict[int, str]]]:
    data = json.loads(path.read_text())
    books: dict[str, dict[int, dict[int, str]]] = {}
    for book in data["books"]:
        chapters: dict[int, dict[int, str]] = {}
        for chapter in book["chapters"]:
            chapters[chapter["chapter"]] = {verse["verse"]: verse["text"] for verse in chapter["verses"]}
        books[book["name"]] = chapters
    return books


def expand(span: tuple[str, int, int, int, int], bible: dict[str, dict[int, dict[int, str]]]) -> list[tuple[str, int, int]]:
    book, start_chapter, start_verse, end_chapter, end_verse = span
    chapters = bible.get(book)
    if not chapters or end_chapter < start_chapter:
        return []
    found: list[tuple[str, int, int]] = []
    for chapter_number in range(start_chapter, end_chapter + 1):
        verses = chapters.get(chapter_number)
        if not verses:
            continue
        first = start_verse if chapter_number == start_chapter else 1
        last = end_verse if chapter_number == end_chapter else max(verses)
        for number in range(first, last + 1):
            if number in verses:
                found.append((book, chapter_number, number))
    return found


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--readings", type=Path, required=True)
    parser.add_argument("--calendar", type=Path, required=True)
    parser.add_argument("--drc", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()

    bible = load_drc(args.drc)
    days: dict[str, dict[str, str]] = {}
    needed: set[tuple[str, int, int]] = set()
    empty: list[str] = []

    for year_dir in sorted(p for p in args.readings.iterdir() if p.name in {"2026", "2027"}):
        for path in sorted(year_dir.glob("*.json")):
            payload = json.loads(path.read_text())
            date = payload["date"]
            readings = payload.get("readings") or {}
            calendar_path = args.calendar / year_dir.name / path.name
            celebration = None
            if calendar_path.exists():
                calendar = json.loads(calendar_path.read_text())
                celebration = (calendar.get("celebration") or {}).get("name") or None
            day = {
                "season": payload.get("season") or "",
            }
            if celebration:
                day["celebration"] = celebration
            for key in ("firstReading", "psalm", "secondReading", "gospel"):
                citation = readings.get(key)
                if not citation:
                    continue
                day[key] = citation
                groups = ranges(citation)
                verses = [verse for group in groups for span in group for verse in expand(span, bible)]
                if not verses:
                    empty.append(f"{date} {key} {citation}")
                needed.update(verses)
            days[date] = day

    for number in range(46, 56):
        needed.add(("Luke", 1, number))

    verses_out: dict[str, dict[str, dict[str, str]]] = {}
    for book, chapter, verse in sorted(needed):
        text = bible[book][chapter][verse]
        verses_out.setdefault(book, {}).setdefault(str(chapter), {})[str(verse)] = text

    notice = (
        "Citations, season names, and feast titles: cpbjr/catholic-readings-api, "
        "MIT License, Copyright (c) 2025 cpbjr. "
        "Verse text: Challoner Douay-Rheims from scrollmapper/bible_databases, "
        "MIT License, Copyright (c) 2024 Scrollmapper; the translation is public domain. "
        "USCCB links are computed in the app and are not copies of USCCB text."
    )
    args.out.mkdir(parents=True, exist_ok=True)
    (args.out / "lectionary.json").write_text(json.dumps({"notice": notice, "days": days}, ensure_ascii=False, separators=(",", ":")))
    (args.out / "douay.json").write_text(json.dumps({"notice": notice, "books": verses_out}, ensure_ascii=False, separators=(",", ":")))
    print(f"days {len(days)} verses {len(needed)} empty {len(empty)}")
    for line in empty:
        print(" empty", line)


if __name__ == "__main__":
    main()
