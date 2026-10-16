# VERIFY

Nothing in the app is presented as a quotation unless it was copied from the edition named with it. A slot below is a place where the screen says the words are not included yet. Do not fill a slot from memory or from a quotation site.

Checked on 15 October 2026.

## Included, and checked

| Text | Source |
| --- | --- |
| Mystery scripture | Douay-Rheims, Challoner revision, from `scrollmapper/bible_databases` `formats/json/DRC.json`. SHA-1 of each passage is in `scripture.json`. |
| Fruit prayers for the 15 Joyful, Sorrowful, and Glorious mysteries | Michael Davitt Forrest, *The Rosary: Its History and How to Say It* (1926), chapter VI, Wikisource transcription. |
| Litany of Loreto | *The Raccolta* (1857), Ambrose St. John. The table is copied row for row. This edition does not print a repeated response after every title. |
| Angelus and Regina Caeli | *The Raccolta* (1857), Ambrose St. John. |
| Seven Dolors chaplet, including its Act of Consecration | Patrick Francis Moran, *The Catholic Prayer Book and Manual of Meditations* (1883), Wikisource transcription. |
| Byzantine Ruthenian feast names and dates | Metropolitan Cantor Institute, Calendar of Saints, from *The Divine Liturgy of our Holy Father John Chrysostom* (2006). Maternity of Holy Anna is 8 December on that calendar. |
| Western feast names and ranks | The list entries in the English Wikipedia article “General Roman Calendar,” retrieved 15 October 2026. The article’s prose was not copied. |
| Mystery paintings | One public-domain JPEG per mystery from Wikimedia Commons. `art.json` stores the Commons SHA-1 (checked on the original before resizing) and the SHA-1 of the JPEG in the app. |
| Saint meditations already in the app | Unchanged. See `docs/CONTENT_TODO.md`. |

`swift test` recomputes every SHA-1 and fails if a text or painting byte changes.

## Slots

These are in `Sources/RosaryCore/Resources/verified/slots.json`. The screen shows the title and the reason. It does not show invented words.

| Id | What is missing |
| --- | --- |
| `divine-mercy.opening` | English opening prayer of the Divine Mercy chaplet. The published text is copyrighted by the Marians of the Immaculate Conception. |
| `divine-mercy.decade` | The decade invocation. Same copyright. The Our Father, Hail Mary, and Creed on the other beads are the public-domain Rosary texts. The decade beads are counted and marked. |
| `divine-mercy.closing` | The closing prayer. Same copyright. |
| `chant.recording` | No public-domain chant recording was bundled. Settings has a Chant switch. It does not play anything. |
| `fruit.short-labels` | The one-word names already in the app (Humility, Love of neighbor, and the rest, including the Luminous mysteries) were not a list in the 1926 Forrest chapter. They stay on screen as labels, with a line that they have not been checked against one edition. |
| `fruit.luminous-prayers` | Forrest 1926 has no Luminous mysteries. No public-domain luminous fruit prayer was copied. |
| `litany.post-1857` | Titles added after 1857, including Queen of the most holy Rosary, Queen of peace, Queen assumed into heaven, Mother of the Church, and Queen of families, are not in the 1857 text. |
| `consecration.montfort-formula` | St. Louis de Montfort’s consecration formula was not copied into this build. |
| `consecration.daily-readings` | No day-by-day public-domain lectionary was copied. The tracker counts 33 days. Day 33 can show the 1883 Act of Consecration, labeled as that prayer and not as Montfort’s. |

## Notes that are easy to miss

- Assumption and Coronation show Revelation 12:1 and say the mystery list’s “cf.” is a comparison, not a claim that the verse narrates the mystery.
- The Regina Caeli season follows the 1857 rubric (Holy Saturday through the Saturday before Trinity). The app treats the whole civil date of Holy Saturday as already in that season. The rubric starts at midday.
- Easter dates used for that season and for the movable Western feasts come from the Gregorian computus already in `LiturgicalCalendar`. 2024-03-31, 2025-04-20, and 2026-04-05 match the table in Wikipedia’s “List of dates for Easter.”
- John Paul II excerpts already in the saints library are still copyrighted. See `docs/CONTENT_TODO.md` before a public release.
