Bundled data for RosaryCore. `saints_meditations.json` holds the saints library; see
`docs/CONTENT_TODO.md` at the repository root for the slots that still need a verified text.

`lectionary.json` holds Mass citations, season names, and feast titles for 2026 and 2027 from
[cpbjr/catholic-readings-api](https://github.com/cpbjr/catholic-readings-api) (MIT). `douay.json`
holds the Challoner Douay-Rheims verses those citations ask for, taken from the DRC translation in
[scrollmapper/bible_databases](https://github.com/scrollmapper/bible_databases) (MIT packaging; the
translation is public domain). The USCCB link is computed in the app. The lectionary’s verse
numbers sometimes differ from the Douay-Rheims, and those passages keep the citation without
invented wording. Regenerate both files with `scripts/build_lectionary.py`.

`Recordings/` holds optional recorded prayers that replace the synthesized voice part by part;
see `docs/RECORDINGS.md`. SwiftPM copies every resource to the top of the bundle, so file names
must be unique across this folder and its subfolders.
