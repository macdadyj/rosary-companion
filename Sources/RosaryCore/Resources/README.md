Bundled data for RosaryCore. `saints_meditations.json` holds the saints library; see
`docs/CONTENT_TODO.md` at the repository root for the slots that still need a verified text.

`Recordings/` holds optional recorded prayers that replace the synthesized voice part by part;
see `docs/RECORDINGS.md`. SwiftPM copies every resource to the top of the bundle, so file names
must be unique across this folder and its subfolders.
