#!/usr/bin/env python3
"""Download one public-domain painting for each mystery and pin its SHA-1.

The Commons API sha1 is checked against the original file before Pillow resizes
it. The JPEG that ships in the app has its own sha1 in art.json. Re-running
replaces the images only when a download still matches a public-domain license.
"""

from __future__ import annotations

import hashlib
import re
import io
import json
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "Sources" / "RosaryCore" / "Resources" / "Art"
MANIFEST = ROOT / "Sources" / "RosaryCore" / "Resources" / "verified" / "art.json"
API = "https://commons.wikimedia.org/w/api.php"
UA = "RosaryCompanion/1.0 (sacred-art verification; github.com/macdadyj)"

# Titles confirmed against Commons imageinfo on 15 October 2026: JPEG, public domain,
# and the file name names the subject. Baptism is a detail of Piero's panel. The Last
# Supper file is a restoration of a copy, which the credit line says.
TITLES = {
    "annunciation": "File:Fra Angelico - The Annunciation - WGA0455.jpg",
    "visitation": "File:Raphael - The visitation.jpg",
    "nativity": "File:Giotto, Lower Church Assisi, Nativity 01.jpg",
    "presentation": "File:Fra Angelico - Presentation of Jesus in the Temple (Cell 10) - WGA00544.jpg",
    "findingInTemple": "File:Paolo Veronese - Jesus among the Doctors - WGA24816.jpg",
    "baptism": "File:Piero della Francesca - Baptism of Christ (detail) - WGA17597.jpg",
    "weddingAtCana": "File:Giotto - Scrovegni - -24- - Marriage at Cana.jpg",
    "proclamation": "File:Bloch-SermonOnTheMount.jpg",
    "transfiguration": "File:The Transfiguration of Christ.16th c.jpg",
    "eucharist": "File:Restoration of copy of Leonardo da Vinci's Last Supper at Tongerlo Abbey.jpg",
    "agonyInGarden": "File:Workshop of Santi Buglioni - The Agony in the Garden of Gethsemane - Walters 27223.jpg",
    "scourging": "File:Albrecht Altdorfer - The Flagellation of Christ - WGA00225.jpg",
    "crowningWithThorns": "File:Perugino (c.1450-1523) (attributed to) - Christ Crowned with Thorns - NG691 - National Gallery.jpg",
    "carryingCross": "File:Juan Sánchez Cotán - Christ Carrying the Cross.jpg",
    "crucifixion": "File:Matthias Grünewald - The Crucifixion - WGA10723.jpg",
    "resurrection": "File:Piero della Francesca - Resurrection - WGA17609.jpg",
    "ascension": "File:Giotto di Bondone - No. 38 Scenes from the Life of Christ - 22. Ascension - WGA09226.jpg",
    "descentOfHolySpirit": "File:Giotto di Bondone - No. 39 Scenes from the Life of Christ - 23. Pentecost - WGA09227.jpg",
    "assumption": "File:Baroque Rubens Assumption-of-Virgin-3.jpg",
    "coronation": "File:Coronation of Mary by Fra Angelico (San Marco Cell 9).jpg",
}


def get(url: str) -> bytes:
    request = urllib.request.Request(url, headers={"User-Agent": UA})
    delay = 2.0
    last_error: Exception | None = None
    for _ in range(6):
        try:
            with urllib.request.urlopen(request, timeout=90) as response:
                return response.read()
        except urllib.error.HTTPError as error:
            last_error = error
            if error.code != 429:
                raise
            time.sleep(delay)
            delay *= 2
    raise SystemExit(f"Commons kept refusing {url}: {last_error}")


def lookup(title: str) -> dict:
    params = {
        "action": "query",
        "format": "json",
        "titles": title,
        "prop": "imageinfo",
        "iiprop": "url|size|mime|sha1|extmetadata",
    }
    payload = json.loads(get(API + "?" + urllib.parse.urlencode(params)))
    pages = payload.get("query", {}).get("pages", {})
    page = next(iter(pages.values()))
    if page.get("missing") is not None:
        raise SystemExit(f"Commons has no {title}")
    info = (page.get("imageinfo") or [None])[0]
    if not info:
        raise SystemExit(f"No image info for {title}")
    info = dict(info)
    info["title"] = page.get("title", title)
    return info


def license_name(info: dict) -> str:
    meta = info.get("extmetadata") or {}
    short = (meta.get("LicenseShortName") or {}).get("value") or ""
    return re_space(short)


def re_space(value: str) -> str:
    return " ".join(value.replace("\n", " ").split())


def acceptable(info: dict) -> bool:
    name = license_name(info).lower()
    if any(word in name for word in ("cc by", "cc-by", "gfdl", "copyright", "non-free")):
        return False
    return any(word in name for word in ("public domain", "cc0", "pd", "no restrictions"))


def meta_value(info: dict, key: str) -> str:
    meta = info.get("extmetadata") or {}
    raw = (meta.get(key) or {}).get("value") or ""
    raw = re.sub(r"<[^>]+>", " ", raw)
    raw = raw.replace("&nbsp;", " ").replace("&amp;", "&").replace("&#039;", "'")
    return re_space(raw)


def choose(mystery: str) -> tuple[dict, bytes]:
    info = lookup(TITLES[mystery])
    if not acceptable(info):
        raise SystemExit(f"{info['title']} is not public domain ({license_name(info)})")
    url = info.get("url")
    if not url:
        raise SystemExit(f"{info['title']} has no download URL")
    data = get(url)
    digest = hashlib.sha1(data).hexdigest()
    if digest != info.get("sha1"):
        raise SystemExit(f"SHA-1 mismatch for {info['title']}")
    info["verifiedSha1"] = digest
    return info, data


def ship(original: bytes) -> bytes:
    image = Image.open(io.BytesIO(original)).convert("RGB")
    image.thumbnail((960, 960))
    buffer = io.BytesIO()
    image.save(buffer, format="JPEG", quality=82, optimize=True)
    return buffer.getvalue()


def main() -> None:
    ART.mkdir(parents=True, exist_ok=True)
    works = []
    for mystery in TITLES:
        info, original = choose(mystery)
        jpeg = ship(original)
        filename = f"{mystery}.jpg"
        (ART / filename).write_bytes(jpeg)
        works.append(
            {
                "mystery": mystery,
                "file": filename,
                "title": info["title"].removeprefix("File:"),
                "artist": meta_value(info, "Artist"),
                "credit": meta_value(info, "Credit"),
                "license": license_name(info),
                "sourceURL": "https://commons.wikimedia.org/wiki/" + urllib.parse.quote(info["title"].replace(" ", "_")),
                "commonsSha1": info["verifiedSha1"],
                "sha1": hashlib.sha1(jpeg).hexdigest(),
            }
        )
        print(f"{mystery}: {works[-1]['title']} ({works[-1]['license']})", flush=True)
        time.sleep(1.5)
    document = {
        "schemaVersion": 1,
        "retrieved": "2026-10-15",
        "note": "commonsSha1 is the Wikimedia original, checked before resizing. sha1 is the JPEG shipped in the app.",
        "works": works,
    }
    MANIFEST.write_text(json.dumps(document, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"wrote {MANIFEST}")


if __name__ == "__main__":
    main()
