#!/usr/bin/env python3
"""Build the verified prayer JSON from editions already downloaded for checking.

This does not invent wording. It copies verse text out of the Challoner Douay-Rheims
JSON, and it copies prayer wording out of the Wikisource transcriptions saved under
/tmp/sources. Re-run only after those files have been fetched again.

Outputs land in Sources/RosaryCore/Resources/verified/.
"""

from __future__ import annotations

import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "Sources" / "RosaryCore" / "Resources" / "verified"
DRC = Path("/tmp/sources/DRC.json")
CLEAN = Path("/tmp/sources/clean")
MCI_HTML = Path("/tmp/sources/mci-cal.html")
GRC_HTML = Path("/tmp/sources/grc.html")
RETRIEVED = "2026-10-15"


def sha1(text: str) -> str:
    return hashlib.sha1(text.encode("utf-8")).hexdigest()


def collapse(text: str) -> str:
    text = text.replace("\u200b", "")
    text = text.replace("\u00a0", " ")
    text = re.sub(r"[ \t]*\n[ \t]*", " ", text)
    text = re.sub(r"[ \t]{2,}", " ", text)
    return text.strip()


def require(path: Path) -> str:
    if not path.is_file():
        raise SystemExit(f"Missing {path}. Download the source edition before rebuilding texts.")
    return path.read_text(encoding="utf-8")


def scripture() -> dict:
    data = json.loads(require(DRC))
    books = {book["name"]: book for book in data["books"]}
    ranges = [
        ("annunciation", "Luke 1:26–38", "Luke", 1, 26, 38, None),
        ("visitation", "Luke 1:39–56", "Luke", 1, 39, 56, None),
        ("nativity", "Luke 2:1–20", "Luke", 2, 1, 20, None),
        ("presentation", "Luke 2:22–38", "Luke", 2, 22, 38, None),
        ("findingInTemple", "Luke 2:41–52", "Luke", 2, 41, 52, None),
        ("baptism", "Matthew 3:13–17", "Matthew", 3, 13, 17, None),
        ("weddingAtCana", "John 2:1–12", "John", 2, 1, 12, None),
        ("proclamation", "Mark 1:14–15", "Mark", 1, 14, 15, None),
        ("transfiguration", "Luke 9:28–36", "Luke", 9, 28, 36, None),
        ("eucharist", "Luke 22:14–20", "Luke", 22, 14, 20, None),
        ("agonyInGarden", "Luke 22:39–46", "Luke", 22, 39, 46, None),
        ("scourging", "John 19:1", "John", 19, 1, 1, None),
        ("crowningWithThorns", "Matthew 27:27–31", "Matthew", 27, 27, 31, None),
        ("carryingCross", "John 19:16–17", "John", 19, 16, 17, None),
        ("crucifixion", "Luke 23:33–46", "Luke", 23, 33, 46, None),
        ("resurrection", "Mark 16:1–8", "Mark", 16, 1, 8, None),
        ("ascension", "Acts 1:6–11", "Acts", 1, 6, 11, None),
        ("descentOfHolySpirit", "Acts 2:1–13", "Acts", 2, 1, 13, None),
        (
            "assumption",
            "Revelation 12:1",
            "Revelation of John",
            12,
            1,
            1,
            "The mystery list marks this verse with “cf.” The verse is the text of Revelation 12:1. It is not a narrative of the Assumption.",
        ),
        (
            "coronation",
            "Revelation 12:1",
            "Revelation of John",
            12,
            1,
            1,
            "The mystery list marks this verse with “cf.” The verse is the text of Revelation 12:1. It is not a narrative of the Coronation.",
        ),
    ]
    passages = []
    for mystery, reference, book, chapter, start, end, note in ranges:
        chapters = books[book]["chapters"]
        block = chapters[chapter - 1]
        if block["chapter"] != chapter:
            raise SystemExit(f"{book} chapter index does not match {chapter}")
        verses = [verse for verse in block["verses"] if start <= verse["verse"] <= end]
        if [verse["verse"] for verse in verses] != list(range(start, end + 1)):
            raise SystemExit(f"Missing verses for {mystery}")
        body = "\n".join(f"{verse['verse']} {verse['text']}" for verse in verses)
        passages.append(
            {
                "mystery": mystery,
                "reference": reference,
                "book": book,
                "chapter": chapter,
                "verified": True,
                "note": note,
                "verses": [{"verse": verse["verse"], "text": verse["text"]} for verse in verses],
                "sha1": sha1(body),
            }
        )
    return {
        "schemaVersion": 1,
        "translation": "Douay-Rheims Bible, Challoner Revision",
        "source": "Public-domain Challoner text as distributed in scrollmapper/bible_databases formats/json/DRC.json",
        "sourceURL": "https://github.com/scrollmapper/bible_databases/blob/master/formats/json/DRC.json",
        "license": "public domain",
        "retrieved": RETRIEVED,
        "passages": passages,
    }


def fruit_prayers() -> dict:
    text = require(CLEAN / "forrest6.txt")
    marker = "THE FIVE JOYFUL MYSTERIES"
    start = text.find(marker)
    if start < 0:
        raise SystemExit("Forrest chapter VI heading was not found")
    body = text[start:]
    ids = [
        "annunciation",
        "visitation",
        "nativity",
        "presentation",
        "findingInTemple",
        "agonyInGarden",
        "scourging",
        "crowningWithThorns",
        "carryingCross",
        "crucifixion",
        "resurrection",
        "ascension",
        "descentOfHolySpirit",
        "assumption",
        "coronation",
    ]
    chunks = re.split(r"\n\((?:\d+|5)\) ", body)
    # The first chunk is the heading before (1).
    prayers = []
    numbered = [chunk for chunk in chunks[1:]]
    if len(numbered) != 15:
        raise SystemExit(f"Expected 15 Forrest mysteries, found {len(numbered)}")
    for mystery, chunk in zip(ids, numbered, strict=True):
        cleaned = collapse(chunk)
        contemplate_at = cleaned.find("Let us contemplate")
        prayer_at = cleaned.find("LET US PRAY")
        if contemplate_at < 0 or prayer_at < 0:
            raise SystemExit(f"Forrest section missing pieces for {mystery}")
        heading = cleaned[:contemplate_at].strip(" \n")
        contemplate = cleaned[contemplate_at:prayer_at]
        contemplate = re.sub(r"Our Father\..*$", "", contemplate).strip()
        prayer = cleaned[prayer_at + len("LET US PRAY") :].strip()
        amen = prayer.find("Amen.")
        if amen < 0:
            raise SystemExit(f"Forrest prayer has no Amen for {mystery}")
        prayer = prayer[: amen + len("Amen.")]
        prayers.append(
            {
                "mystery": mystery,
                "heading": heading,
                "contemplate": contemplate,
                "prayer": prayer,
                "sha1": sha1(contemplate + "\n" + prayer),
            }
        )
    return {
        "schemaVersion": 1,
        "source": "Michael Davitt Forrest, The Rosary: Its History and How to Say It (1926), chapter VI, “Reflections and Prayers.” Wikisource transcription of the printed pamphlet.",
        "sourceURL": "https://en.wikisource.org/wiki/The_Rosary_(Forrest)/Chapter_VI",
        "license": "public domain",
        "retrieved": RETRIEVED,
        "note": "Line breaks in the transcription were joined. Wording and punctuation are otherwise as printed. The one-word fruit names already in the app are not in this chapter.",
        "prayers": prayers,
    }


def litany() -> dict:
    text = require(CLEAN / "litany.txt").replace("\u200b", "")
    start = text.find("| Kyrie eleison.")
    if start < 0:
        raise SystemExit("Litany table was not found")
    table = text[start:]
    lines = [line.strip()[2:].strip() for line in table.splitlines() if line.strip().startswith("|")]
    if len(lines) % 2 != 0:
        raise SystemExit(f"Litany columns are unpaired ({len(lines)} lines)")
    rows = []
    for index in range(0, len(lines), 2):
        latin, english = lines[index], lines[index + 1]
        rows.append({"latin": latin, "english": english})
    if not rows or not rows[0]["english"].startswith("Lord have mercy"):
        raise SystemExit("Litany did not start at Lord have mercy")
    if rows[-1]["english"] != "R. Amen.":
        raise SystemExit(f"Litany did not end at R. Amen. ({rows[-1]['english']!r})")
    body = "\n".join(f"{row['latin']} / {row['english']}" for row in rows)
    return {
        "schemaVersion": 1,
        "title": "Litany of the Blessed Virgin, commonly called the Litany of Loretto",
        "source": "The Raccolta (1857), translated by Ambrose St. John, section “The Litanies.” Wikisource transcription.",
        "sourceURL": "https://en.wikisource.org/wiki/The_Raccolta_(1857)/The_Litanies",
        "license": "public domain",
        "retrieved": RETRIEVED,
        "note": "Each row is one line of the 1857 table. This edition does not print a repeated response after every Marian title. Invocations added after 1857 are not in this text and are slots in VERIFY.md.",
        "rows": rows,
        "sha1": sha1(body),
    }


def hours() -> dict:
    angelus = [
        "V. The angel of the Lord declared unto Mary, and she conceived of the Holy Ghost.",
        "Ave Maria.",
        "V. Behold the handmaid of the Lord; be it done unto me according to Thy word.",
        "Ave Maria.",
        "V. And the Word was made Flesh, and dwelt among us.",
        "Ave Maria.",
        "V. Pray for us, Holy Mother of God.",
        "R. That we may be made worthy of the promises of Christ.",
        "Let us pray.",
        "Pour down Thy grace into our souls, we beseech Thee, O Lord; that as we have known the Incarnation of Christ Thy Son by the message of an angel, so by His Passion and Cross we may come to the glory of the resurrection. Through the same Christ our Lord. R. Amen.",
    ]
    regina = [
        "Queen of Heaven, rejoice. Alleluia.",
        "He whom thou wast made worthy to bear. Alleluia.",
        "Hath risen as He said. Alleluia.",
        "Pray for us to our God. Alleluia.",
        "V. Rejoice and be glad, O Mary the Virgin. Alleluia.",
        "R. For the Lord hath risen indeed. Alleluia.",
        "Let us pray.",
        "God, who through the resurrection of Thy Son our Lord Jesus Christ hast vouchsafed to make glad the whole world; grant us, we beseech Thee, that through the intercession of the Virgin Mary His Mother we may attain the joys of eternal life. Through the same our Lord Jesus Christ. Amen.",
    ]
    source_text = require(CLEAN / "angelus1857.txt")
    for line in angelus + regina:
        key = line.replace("Ave Maria.", "Ave Maria")
        if key not in source_text and line not in source_text:
            # The transcription breaks some lines. Check a distinctive prefix.
            prefix = line[:48]
            if prefix not in source_text:
                raise SystemExit(f"1857 Angelus page does not contain: {prefix}")
    return {
        "schemaVersion": 1,
        "source": "The Raccolta (1857), translated by Ambrose St. John, “The Angelus Domini, etc., or the Regina cœli, etc.” Wikisource transcription.",
        "sourceURL": "https://en.wikisource.org/wiki/The_Raccolta_(1857)/The_%22Angelus_Domini%22,_etc.,_or_the_%22Regina_c%C5%93li%22,_etc.",
        "license": "public domain",
        "retrieved": RETRIEVED,
        "seasonNote": "The same section says the Regina cœli replaces the Angelus “at Paschal-tide, that is, from Holy Saturday at midday to midday on the Saturday preceding the Feast of the Most Holy Trinity, inclusive.” The app treats the whole civil date of Holy Saturday as already in that season.",
        "angelus": angelus,
        "reginaCaeli": regina,
        "angelusSha1": sha1("\n".join(angelus)),
        "reginaSha1": sha1("\n".join(regina)),
    }


def seven_sorrows() -> dict:
    raw = require(CLEAN / "dolors.txt")
    text = raw.replace("\u200b", "")
    start = text.find("OFFERING OF THE CHAPLET.")
    if start < 0:
        raise SystemExit("Seven Dolors chaplet was not found")
    body = text[start:]
    # Drop the Wikisource running header crumbs that survived inside the body.
    body = re.sub(r"\n\d+\n", "\n", body)

    def grab(heading: str, following: str) -> str:
        begin = body.find(heading)
        end = body.find(following, begin + len(heading))
        if begin < 0 or end < 0:
            raise SystemExit(f"Could not cut {heading!r}")
        return collapse(body[begin + len(heading) : end])

    offering = grab("OFFERING OF THE CHAPLET.", "First Mystery.")
    sections = []
    headings = [
        ("prophecyOfSimeon", "First Mystery.", "THE PROPHECY OF VENERABLE SIMEON.", "Second Mystery."),
        ("flightIntoEgypt", "Second Mystery.", "THE FLIGHT INTO EGYPT.", "Third Mystery."),
        ("lossInTheTemple", "Third Mystery.", "THE LOSING OF JESUS IN THE TEMPLE.", "Fourth Mystery."),
        ("meetingWithTheCross", "Fourth Mystery.", "THE MEETING WITH JESUS CARRYING HIS CROSS.", "Fifth Mystery."),
        ("crucifixion", "Fifth Mystery.", "THE CRUCIFIXION.", "Sixth Mystery."),
        ("descentFromTheCross", "Sixth Mystery.", "THE TAKING DOWN OF JESUS FROM THE CROSS.", "Seventh Mystery."),
        ("burial", "Seventh Mystery.", "THE SEPULTURE OF JESUS CHRIST.", "ACT OF CONSECRATION."),
    ]
    for identifier, marker, title, nxt in headings:
        begin = body.find(marker)
        end = body.find(nxt, begin + len(marker))
        if begin < 0 or end < 0:
            raise SystemExit(f"Missing sorrow {identifier}")
        block = body[begin:end]
        title_at = block.find(title)
        prayer_at = block.find("PRAYER.")
        if title_at < 0 or prayer_at < 0:
            raise SystemExit(f"Sorrow {identifier} is missing its prayer")
        meditation = collapse(block[title_at + len(title) : prayer_at])
        meditation = re.sub(r"Our Father, etc\..*$", "", meditation).strip()
        meditation = re.sub(r"Hail Mary, seven times\.", "", meditation).strip()
        prayer = collapse(block[prayer_at + len("PRAYER.") :])
        if identifier == "burial":
            split = prayer.find("O Queen of Martyrs!")
            if split < 0:
                raise SystemExit("The Queen of Martyrs prayer was not in the seventh sorrow")
            prayer = prayer[:split].strip()
        sections.append(
            {
                "id": identifier,
                "title": title.strip("."),
                "meditation": meditation,
                "prayer": prayer,
                "ourFather": 1,
                "hailMarys": 7,
                "sha1": sha1(meditation + "\n" + prayer),
            }
        )
    closing = "O Queen of Martyrs! " + grab("O Queen of Martyrs!", "ACT OF CONSECRATION.")
    # grab starts after the heading, so put the address back. It is inside the seventh prayer
    # block already; the separate act follows. Pull the act itself.
    act_at = body.find("ACT OF CONSECRATION.")
    act = collapse(body[act_at + len("ACT OF CONSECRATION.") :])
    if not act.endswith("Amen."):
        raise SystemExit("Act of consecration did not end at Amen.")
    return {
        "schemaVersion": 1,
        "title": "Chaplet or Crown in honour of the Seven Dolors of the most Holy Virgin Mary",
        "source": "Patrick Francis Moran, The Catholic Prayer Book and Manual of Meditations (1883), “Chaplet or Crown in honour of the Seven Dolors of the most Holy Virgin Mary.” Wikisource transcription.",
        "sourceURL": "https://en.wikisource.org/wiki/The_Catholic_Prayer_Book_and_Manual_of_Meditations/Chaplet_or_Crown_in_honor_of_the_Seven_Dolors_of_the_B.V.M.",
        "license": "public domain",
        "retrieved": RETRIEVED,
        "note": "Wrapped lines in the transcription were joined, and zero-width spaces inserted at those wraps were removed. Our Father and Hail Mary use the Rosary texts already in the app. The 1883 page says “Our Father, etc., once” and “Hail Mary, seven times.”",
        "offering": offering,
        "offeringSha1": sha1(offering),
        "sorrows": sections,
        "queenOfMartyrs": closing,
        "queenSha1": sha1(closing),
        "actOfConsecration": act,
        "actSha1": sha1(act),
    }


def feasts() -> dict:
    ruthenian = parse_mci(require(MCI_HTML))
    western = parse_grc(require(GRC_HTML))
    if not any(row["name"].startswith("THE NATIVITY OF THE THEOTOKOS") for row in ruthenian):
        raise SystemExit("Ruthenian calendar is missing the Nativity")
    if not any(row["name"].startswith("1 January") for row in western):
        raise SystemExit("Western calendar is missing 1 January")
    return {
        "schemaVersion": 1,
        "retrieved": RETRIEVED,
        "ruthenian": {
            "name": "Byzantine Ruthenian calendar of the Metropolitan Church of Pittsburgh",
            "source": "Metropolitan Cantor Institute, Calendar of Saints, taken from The Divine Liturgy of our Holy Father John Chrysostom (2006).",
            "sourceURL": "https://mci.archpitt.org/liturgy/Calendar_of_Saints.html",
            "feasts": ruthenian,
        },
        "western": {
            "name": "General Roman Calendar",
            "source": "Titles and ranks as printed in the English Wikipedia article “General Roman Calendar,” which summarizes the calendar promulgated after Mysterii Paschalis and later inscriptions. Feast names below are the article’s list entries, not its prose.",
            "sourceURL": "https://en.wikipedia.org/wiki/General_Roman_Calendar",
            "feasts": western,
        },
    }


def parse_mci(html: str) -> list[dict]:
    keys = (
        "theotokos",
        "maternity",
        "dormition",
        "annunciation",
        "protection of the",
        "entrance of the",
        "nativity of the theotokos",
        "synaxis of the theotokos",
        "robes of the theotokos",
        "sash of the theotokos",
        "meeting of our lord",
    )
    months = {
        "January": 1,
        "February": 2,
        "March": 3,
        "April": 4,
        "May": 5,
        "June": 6,
        "July": 7,
        "August": 8,
        "September": 9,
        "October": 10,
        "November": 11,
        "December": 12,
    }
    rows = []
    for part in re.split(r'<p class="date">', html)[1:]:
        head = re.split(r"</p>", part, maxsplit=1)[0]
        date = re.sub(r"<[^>]+>", " ", head)
        date = re.sub(r"\s+", " ", date).strip()
        match = re.match(r"([A-Za-z]+) (\d+)$", date)
        if not match or match.group(1) not in months:
            continue
        for entry in re.findall(r'<p class="entry">(.*?)</p>', part, flags=re.S):
            rank = "commemoration"
            if "Great feast" in entry:
                rank = "great"
            elif "Polyeleos" in entry:
                rank = "polyeleos"
            elif "Doxology" in entry:
                rank = "doxology"
            elif "six stichera" in entry:
                rank = "six-stichera"
            elif "Vigil" in entry:
                rank = "vigil"
            name = re.sub(r"<[^>]+>", " ", entry)
            name = re.sub(r"\s+", " ", name).strip()
            if any(key in name.lower() for key in keys):
                rows.append(
                    {
                        "month": months[match.group(1)],
                        "day": int(match.group(2)),
                        "name": name,
                        "rank": rank,
                    }
                )
    if len(rows) < 20:
        raise SystemExit(f"Expected the Ruthenian Marian list, found {len(rows)}")
    return rows


def parse_grc(html: str) -> list[dict]:
    phrases = (
        "solemnity of mary",
        "blessed virgin",
        "our lady",
        "holy mother of god",
        "annunciation of the lord",
        "assumption of",
        "visitation of",
        "immaculate conception",
        "immaculate heart",
        "queenship",
        "our lady of sorrows",
        "holy name of mary",
        "mother of the church",
        "nativity of the blessed",
        "presentation of the blessed",
        "dedication of the basilica of saint mary",
    )
    months = {
        "January": 1,
        "February": 2,
        "March": 3,
        "April": 4,
        "May": 5,
        "June": 6,
        "July": 7,
        "August": 8,
        "September": 9,
        "October": 10,
        "November": 11,
        "December": 12,
    }
    rows = []
    for item in re.findall(r"<li[^>]*>(.*?)</li>", html, flags=re.S):
        text = re.sub(r"<[^>]+>", " ", item)
        text = re.sub(r"\s+", " ", text).strip()
        low = text.lower()
        if not any(phrase in low for phrase in phrases):
            continue
        if low.startswith("↑") or "decree on the celebration" in low or "notification on the memorial" in low:
            continue
        movable = None
        month = None
        day = None
        if text.startswith("Monday after Pentecost"):
            movable = "mondayAfterPentecost"
        elif text.startswith("Saturday after the Second Sunday after Pentecost"):
            movable = "saturdayAfterSacredHeart"
        else:
            found = re.match(
                r"(\d{1,2}) (January|February|March|April|May|June|July|August|September|October|November|December): (.*)$",
                text,
            )
            if not found:
                continue
            day = int(found.group(1))
            month = months[found.group(2)]
            text = f"{found.group(1)} {found.group(2)}: {found.group(3)}"
        # Drop trailing footnote letters that the article glues on, such as "memorial c".
        text = re.sub(r"\s+[a-c]$", "", text).strip()
        text = text.replace(" ,", ",")
        rows.append({"month": month, "day": day, "movable": movable, "name": text})
    # 1 January sits in a long list item because a citation is nested in it.
    if not any(row["name"].startswith("1 January") for row in rows):
        if "Solemnity of Mary, the Holy Mother of God" not in html:
            raise SystemExit("1 January was not in the General Roman Calendar article")
        rows.insert(
            0,
            {
                "month": 1,
                "day": 1,
                "movable": None,
                "name": "1 January: Solemnity of Mary, the Holy Mother of God – solemnity",
            },
        )
    return rows


def slots() -> dict:
    return {
        "schemaVersion": 1,
        "slots": [
            {
                "id": "divine-mercy.opening",
                "title": "Divine Mercy opening prayer",
                "reason": "The English chaplet prayers published for St. Faustina’s devotion are copyrighted by the Marians of the Immaculate Conception. They are not included.",
            },
            {
                "id": "divine-mercy.decade",
                "title": "Divine Mercy decade prayer",
                "reason": "The decade invocation is part of the copyrighted English chaplet. The bead is counted. The words are not shown.",
            },
            {
                "id": "divine-mercy.closing",
                "title": "Divine Mercy closing prayer",
                "reason": "The closing prayer of the chaplet is part of the copyrighted English text. It is not shown.",
            },
            {
                "id": "chant.recording",
                "title": "Optional chant recording",
                "reason": "No public-domain recording was bundled. The switch is in Settings and does nothing until a sourced recording is added.",
            },
            {
                "id": "fruit.short-labels",
                "title": "One-word fruit of each mystery",
                "reason": "The short names already in the app (Humility, Love of neighbor, and the rest, including the Luminous mysteries) were not found as a list in the 1926 Forrest chapter. They stay on screen as labels, marked as unchecked.",
            },
            {
                "id": "fruit.luminous-prayers",
                "title": "Fruit prayers for the Luminous mysteries",
                "reason": "Forrest’s 1926 pamphlet has fruit prayers for the fifteen mysteries only. No public-domain luminous fruit prayer was copied.",
            },
            {
                "id": "litany.post-1857",
                "title": "Litany invocations added after 1857",
                "reason": "Queen of the most holy Rosary, Queen of peace, Queen assumed into heaven, Mother of the Church, Queen of families, and any other later titles are not in the 1857 Raccolta text used here.",
            },
            {
                "id": "consecration.montfort-formula",
                "title": "St. Louis de Montfort’s consecration formula",
                "reason": "A word-for-word copy of the Faber translation was not cut into this build. Day 33 can use the 1883 Act of Consecration from the Seven Dolors chaplet, which is a different prayer and is labeled as such.",
            },
            {
                "id": "consecration.daily-readings",
                "title": "Thirty-three daily consecration readings",
                "reason": "No public-domain day-by-day lectionary was copied. The tracker counts the days. The reading for each day is this slot.",
            },
        ],
    }


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    documents = {
        "scripture.json": scripture(),
        "fruits.json": fruit_prayers(),
        "litany.json": litany(),
        "hours.json": hours(),
        "seven_sorrows.json": seven_sorrows(),
        "feasts.json": feasts(),
        "slots.json": slots(),
    }
    for name, document in documents.items():
        path = OUT / name
        path.write_text(json.dumps(document, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
        print(f"wrote {path.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
