# Content TODO

The saints library lives in `Sources/RosaryCore/Resources/saints_meditations.json`. The app shows a quotation only when its slot has `verified: true`, a `text`, and a `source`. Every other slot is a placeholder: it has `text: null`, the app never displays it, and the mystery falls back to its reflection prompt (original app text, always labelled "not a quotation").

`swift test` fails if a placeholder id in the JSON is missing from this file, so this list cannot silently drift out of date.

## Current state

- 20 of 20 mysteries have at least one verified quotation.
- 56 verified quotations: 41 from public-domain texts and 15 short attributed excerpts from a copyrighted work (St. John Paul II).
- 7 placeholders, listed below. All seven are for authors whose English texts are still under copyright, so they need both an exact citation and permission.

## Placeholders

| Slot id | Saint | Mystery | Blocker |
| --- | --- | --- | --- |
| `eucharist.padre-pio` | St. Pio of Pietrelcina | The Institution of the Eucharist | No letter with recipient and date checked; translation copyrighted |
| `agonyInGarden.faustina` | St. Faustina Kowalska | The Agony in the Garden | No Diary paragraph number checked; translation copyrighted |
| `agonyInGarden.padre-pio` | St. Pio of Pietrelcina | The Agony in the Garden | No letter with recipient and date checked; translation copyrighted |
| `scourging.faustina` | St. Faustina Kowalska | The Scourging at the Pillar | No Diary paragraph number checked; translation copyrighted |
| `carryingCross.padre-pio` | St. Pio of Pietrelcina | The Carrying of the Cross | No letter with recipient and date checked; translation copyrighted |
| `crucifixion.faustina` | St. Faustina Kowalska | The Crucifixion and Death of Our Lord | No Diary paragraph number checked; translation copyrighted |
| `crucifixion.padre-pio` | St. Pio of Pietrelcina | The Crucifixion and Death of Our Lord | No letter with recipient and date checked; translation copyrighted |

Where to look:

- **St. Faustina:** *Diary of Saint Maria Faustina Kowalska: Divine Mercy in My Soul* (Marian Press, Stockbridge, MA; © Congregation of Marians of the Immaculate Conception). Cite the Diary paragraph number from the printed edition. The translation is copyrighted, so get Marian Press's permission before shipping any excerpt.
- **St. Pio:** *Letters* (*Epistolario*), English edition from Edizioni "Padre Pio da Pietrelcina", San Giovanni Rotondo. Cite the recipient, the exact date of the letter, and the volume and page. The translation is copyrighted, so permission is needed. Do not take text from "Padre Pio quotes" websites: many of the popular lines circulating online cannot be traced to a letter.

## How to fill a slot

1. Work from the printed edition, or a scan of it, not from a quotation website.
2. Copy the excerpt exactly. Do not modernize spelling, fix punctuation, or join sentences from different places. If the excerpt starts or ends mid-paragraph, say so in `excerptNote`.
3. Fill in `text`, `source` (work, part/chapter/paragraph or letter date, translator and edition), `sourceURL` if there is a stable scan, and `license` (`"public domain"` or `"short attributed excerpt"`).
4. Write in `verificationNote` how the words were checked, and record any permission obtained in `copyrightNote`.
5. Set `verified` to `true`, remove the slot from the table above, and run `swift test`. The tests check that verified slots have text, source, and a known license, and that short attributed excerpts stay at 75 words or fewer (90 for public domain).

If a slot can't be verified, leave it as a placeholder. The reflection prompt covers that mystery in the meantime.

## Licensing notes on verified content

These quotations are verified, but the owner should still review the licensing before any public release.

- **St. John Paul II, *Rosarium Virginis Mariae* (15 excerpts, © Libreria Editrice Vaticana).** Each excerpt is one or two sentences with full attribution. Together, though, they quote a sizeable share of sections 20 to 23 of the letter. For personal use this is a modest, attributed use; for a distributed app, either keep a smaller subset or ask LEV for permission. Removing all 15 still leaves at least one public-domain quotation for every mystery. Slot ids: `annunciation.john-paul-ii`, `visitation.john-paul-ii`, `nativity.john-paul-ii`, `presentation.john-paul-ii`, `findingInTemple.john-paul-ii`, `baptism.john-paul-ii`, `weddingAtCana.john-paul-ii`, `transfiguration.john-paul-ii`, `eucharist.john-paul-ii`, `agonyInGarden.john-paul-ii`, `crucifixion.john-paul-ii`, `resurrection.john-paul-ii`, `descentOfHolySpirit.john-paul-ii`, `assumption.john-paul-ii`, `coronation.john-paul-ii`.
- **St. Thérèse of Lisieux (7 excerpts, T. N. Taylor translation, 1912; 8th ed. 1922).** Public domain in the United States. In countries that use life plus 70 years, the status depends on the translator's death date, which has not been checked. Slot ids: `nativity.therese`, `findingInTemple.therese`, `weddingAtCana.therese`, `eucharist.therese`, `agonyInGarden.therese`, `carryingCross.therese`, `crucifixion.therese`.
- **Web editions of public-domain texts.** New Advent (Summa, 1920 Dominican translation), the Newman Reader (Newman's 1893 *Meditations and Devotions*), CCEL (Nicene and Post-Nicene Fathers, 1886 to 1895), and Project Gutenberg (*The Glories of Mary*, 1852; *Story of a Soul*, 1912) each claim copyright on their digital editions or branding. Only the underlying public-domain wording is used, and the `source` field credits the original translation and edition. Don't copy the sites' own notes, headings, or formatting.
- **St. Louis de Montfort, *True Devotion* (3 excerpts, F. W. Faber translation, 1904 printing).** Public domain. Checked against the page scans on archive.org rather than the OCR text.

## How the verified quotations were checked

Each source was downloaded from the `sourceURL` in its slot. The excerpt was cut from that text using start and end anchors rather than typed from memory, then compared word for word with a script. The only differences allowed were whitespace, straight versus curly quotes, and dash style. The three Montfort excerpts were also read against the scanned page images, because the archive.org OCR text breaks "Eliz-abeth" across a line. Each excerpt was then read in its surrounding context to confirm that the words belong to the named saint: none comes from an objection in the Summa that Aquinas goes on to answer, and none is a passage the author was quoting from someone else.
