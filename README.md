# Rosary

A voice-first Rosary companion for iPhone, written in SwiftUI. Pray aloud and the app follows along: it counts Hail Marys, recognises the Glory Be, the Fatima prayer, and the mystery announcements, and moves on when you do. Tapping anywhere on the screen always works as a fallback. Everything runs on the phone: speech recognition is on-device only, and the app makes no network calls and has no accounts, ads, analytics, or paywall.

It is built with SwiftPM and [xtool](https://xtool.sh) so that it can be developed on Linux and installed on an iPhone over USB with a **free** Apple account.

## Status

| Area | State |
| --- | --- |
| MVP: one decade by voice, end to end, in both modes | Done; covered by scripted-transcript tests |
| Full Rosary (opening prayers, five decades, closing prayers), all four mystery sets, weekday schedule with optional seasonal Sundays | Done |
| Family mode: editable members, a leader per decade, next leader shown and announced, rotation remembered across sessions | Done |
| Saints library: 20 mysteries, 56 verified quotations, 7 placeholders | Done; see [docs/CONTENT_TODO.md](docs/CONTENT_TODO.md) |
| Tracking mode shows the mystery's meditation for the whole decade | Done |
| Narration: best installed voice picked automatically, calm pacing with pauses, voice picker with previews | Done |
| Recorded prayers can replace the synthesized voice, part by part | Ready; no recordings yet, see [docs/RECORDINGS.md](docs/RECORDINGS.md) |
| Habits: streak, one-line journal, intentions, plain-text export | Done |
| Large Dynamic Type, dark (default) and light, high contrast, VoiceOver actions | Done |
| `swift test` on Linux | Rosary core, including the checked texts and paintings |
| iOS app target compiled for arm64 against the iPhoneOS 26.5 SDK on Linux | Passing (`scripts/ios-compile-check.sh`) |
| Signed build installed on a real iPhone | Done by the owner, on an iPhone 11 |

The meditation panel and the new narration were built after that first try on the iPhone, so like the rest of the iOS layer they are compiled and type-checked on Linux but haven't been run on a device yet. Thresholds such as the silence windows in `SessionTiming`, and the pauses between spoken phrases in `SpeechPacing`, may need tuning in use.

TestFlight is prepared in [docs/TESTFLIGHT.md](docs/TESTFLIGHT.md). The App Store bundle id is `com.lojo.Rosary`. Words that were not copied from a named edition are slots in [VERIFY.md](VERIFY.md), not guesses.

## Features

- **Two ways to pray.** *Guided*: the app leads each prayer aloud and listens for your response; a Hail Mary is counted when you finish "Holy Mary, Mother of God…". *Tracking*: you pray everything and the app follows, showing which bead you're on. You can switch modes mid-prayer.
- **Voice tracking that tolerates real recognition.** Anchor phrases are matched approximately (word-level edit distance), so "full of grace the lord is with the" still counts. A match must hold across two partial results before it fires, the same phrase can't fire twice within 1.5 seconds, and text that already produced a match is never searched again, so one spoken prayer can't advance the count twice.
- **Tap anywhere** to advance, with haptics. A tap right after a voice advance confirms it instead of skipping. Back and End are always on screen, and VoiceOver users get a Magic Tap and named actions.
- **Interruptions are handled.** A phone call, Siri, or leaving the app pauses the prayer, and a tap picks it up at the same place. The screen stays awake while you pray.
- **Family mode.** Add, rename, remove, and reorder members. Each decade has a leader. When a decade ends, the next leader's name fills the screen, with "leads the next decade" underneath, and is announced aloud. The app remembers who should start next time.
- **Mysteries for every day.** Monday and Saturday Joyful, Tuesday and Friday Sorrowful, Wednesday and Sunday Glorious, Thursday Luminous. Optionally, Sundays of Advent and Christmastide are Joyful and Sundays of Lent Sorrowful. You can always pick a different set or a single decade.
- **Saints for each mystery.** A short verified quotation (rotating by day) or, where none is verified, a reflection prompt clearly marked as written for the app and not a quotation.
- **Meditation while you pray.** In Tracking mode, a panel above the prayer keeps the current mystery's scripture, fruit, and meditation on screen through the decade. "Another meditation" steps through every verified quotation for that mystery, then the reflection prompt. The panel never takes more than half the space between the header and the controls: a long meditation scrolls inside it, so the bead counter and listening status stay visible. Hide or show it from the panel or in Settings; the choice is remembered.
- **A natural, unhurried narrator.** The app reads with the best English voice installed on the phone: Premium first, then Enhanced, then Standard, preferring your region's accent and skipping the robotic legacy and novelty voices. Prayers are spoken phrase by phrase at a calm pace, with short pauses at semicolons and between sentences. Settings › Narrator voice lists every installed voice with a preview, and explains how to download Premium and Enhanced voices; pace and pitch have their own sliders.
- **Habits.** Daily streak, a one-line journal note after each session, intentions you can offer and mark answered, and a plain-text export via the share sheet.
- **Scripture and fruit.** Each mystery shows its Douay-Rheims passage. The fifteen older mysteries also show the 1926 fruit prayer. The one-word fruit names are labeled as unchecked.
- **Other devotions.** Seven Dolors chaplet (1883), a Divine Mercy bead counter whose Mercy prayers are withheld until licensed, the 1857 Litany of Loreto, the Angelus and Regina Caeli, a 33-day counter, and the Ruthenian and Western Marian calendars.
- **Art and the bead ring.** A public-domain painting for each mystery, with the credit under it, and a glowing ring that moves with the bead. Dark mode is candlelit. Settings shows the build number.

## Build and install on an iPhone (free Apple account)

These steps are for a Linux machine (x86_64 or arm64) with the iPhone connected by USB.

### 1. Install the tools (once)

1. **Swift toolchain.** Install Swift 6.x with [swiftly](https://www.swift.org/install/linux/). This repo is developed with Swift 6.4:

   ```bash
   swiftly install latest
   swift --version
   ```

2. **usbmuxd**, which lets Linux talk to the iPhone over USB:

   ```bash
   sudo apt install usbmuxd        # Debian/Ubuntu; use your distro's package otherwise
   ```

3. **xtool.** Download the AppImage for your architecture from the [xtool releases](https://github.com/xtool-org/xtool/releases) and put it on your PATH (adjust the file name to the one you downloaded):

   ```bash
   chmod +x xtool-x86_64.AppImage
   mv xtool-x86_64.AppImage ~/.local/bin/xtool
   xtool --version                  # this repo was last checked with xtool 1.20.1
   ```

4. **Xcode.xip.** xtool builds its iOS SDK from Xcode's files. Sign in to <https://developer.apple.com/download/all/?q=Xcode> with your Apple ID (a free account works) and download a recent Xcode `.xip`. You only need the file; Xcode never runs. Use a Swift toolchain at least as new as the Swift that ships in that Xcode.

5. **Set up xtool.** Run this from a normal interactive terminal:

   ```bash
   xtool setup
   ```

   This signs in to Apple Developer Services, then asks for the path to `Xcode.xip` and builds the Darwin SDK (it takes a while and needs several GB of disk space). When asked how to log in, choose **password** (Apple ID and password, then the two-factor code). The API-key option needs a paid membership. You can run the two halves separately with `xtool auth login --mode password` and `xtool sdk install ~/Downloads/Xcode_26.xip`, and check them with `xtool auth status` and `xtool sdk status`.

### 2. Prepare the iPhone (once)

1. Connect the iPhone by USB, unlock it, and tap **Trust** on the "Trust This Computer?" prompt.
2. Check that xtool can see it: `xtool devices`.
3. Developer Mode (iOS 16 and later): after the first install attempt, go to **Settings › Privacy & Security › Developer Mode**, turn it on, and let the phone restart.

### 3. Build, sign, and install

From the repository root:

```bash
xtool dev run --usb
```

This builds the app, registers your iPhone and an App ID with your free account, signs the app with a 7-day development profile, and installs it over USB. (`xtool dev` on its own does the same thing; `xtool dev build` only builds the `.app`.)

The first time, iOS refuses to open an app from an untrusted developer. Go to **Settings › General › VPN & Device Management**, tap your Apple ID under *Developer App*, and tap **Trust**.

### 4. First launch

- Allow the microphone and speech recognition when asked. Both prompts say that audio stays on the phone.
- Voice tracking needs Apple's **on-device** English speech model. If the app says it isn't installed, turn on **Settings › General › Keyboard › Enable Dictation** (with English as a keyboard language) and wait for the download. Rosary never falls back to server-based recognition; until the model is there, tap to move through the prayers.
- For the most natural narration, download a Premium or Enhanced English voice in **Settings › Accessibility › Spoken Content › Voices › English** (free, and it works offline). Rosary picks it up automatically; to choose a different one, use **Settings › Narrator voice** in Rosary.

### Free account limits

Apple applies these limits to free accounts, not xtool:

- **Apps stop opening after 7 days.** Plug in and run `xtool dev run --usb` again to re-sign and reinstall. Your streak, journal, intentions, and family list are kept, because reinstalling over the existing app preserves its data.
- **Up to 3 sideloaded apps per device at once**, and a limited number of new App IDs per week. If you hit the App ID limit, wait or reuse the existing bundle ID rather than changing it.
- **No paid-only capabilities.** That's why the app uses none: no iCloud, push notifications, App Groups, or background modes. It needs only the microphone and speech recognition usage strings in `Config/Info.plist`.
- xtool may register the app under a team-specific variant of `com.lojo.Rosary`; it prints the bundle ID it used. To change the base ID, edit `bundleID` in `xtool.yml`.

### Troubleshooting

- **`epoll_ctl ... Operation not permitted` crash** as soon as xtool starts: xtool's networking layer can't handle standard input that isn't a terminal (for example when run from a CI job, or with input redirected from `/dev/null`). Run it from an interactive terminal, or wrap it: `script -qec "xtool dev run --usb" /dev/null`.
- **No devices found:** check that `usbmuxd` is running (`systemctl status usbmuxd`), try another cable or port, and unlock the phone.
- **"Untrusted Developer" or the app won't open:** see the Trust step above, or the 7-day limit.

## Developing on Linux

All of the app's logic lives in `RosaryCore`, a pure-Swift target with no UIKit, SwiftUI, Speech, or AVFoundation imports, so it builds and tests anywhere Swift runs:

```bash
swift build
swift test              # 137 tests
```

The iOS layer (`Sources/Rosary`) is wrapped in `#if os(iOS)`, so on Linux it compiles to an empty module. To check it properly without a Mac, compile both targets for arm64 iOS against an iPhoneOS SDK:

```bash
IOS_SDK=/path/to/iPhoneOS.sdk scripts/ios-compile-check.sh
```

After `xtool setup`, an SDK is inside xtool's Swift SDK bundle: `find ~/.swiftpm/swift-sdks -maxdepth 6 -name 'iPhoneOS*.sdk'`. This produces arm64 Mach-O object files, which runs the full compiler front end and SIL diagnostics, but it doesn't link or sign; `xtool dev` does that.

To redraw the app icon (`Config/AppIcon.png`, 1024×1024), run `scripts/generate-icon.py` with Pillow installed.

## How it's built

```
Package.swift, xtool.yml          SwiftPM package; xtool bundles the "Rosary" library product as the app
Config/Info.plist, AppIcon.png    usage strings, display name, version, icon
Sources/RosaryCore/               pure Swift, tested on Linux
  Prayers/                        traditional prayer texts (public domain), leader/response split
  Mysteries/                      the 20 mysteries, weekday and seasonal-Sunday schedule
  Plan/                           the ordered steps of a session (single decade, five decades, full Rosary)
  Matching/                       text normalisation, approximate phrase matching, AnchorDetector
  Session/                        SessionEngine (deterministic state machine) and SessionController
  Narration/                      what is said aloud, phrase pacing, recordings, voice ranking, playback order
  Family/, Habits/                rotation policies, streaks, journal export, intentions
  Persistence/                    AppModel, settings, JSON files in Application Support
  Saints/, Resources/             saints library, saints_meditations.json, Recordings/
Sources/Rosary/                   SwiftUI app, iOS only
  Services/                       on-device SFSpeechRecognizer, speech and recording playback, voices, haptics, audio session
  Session/                        the prayer screen and the end-of-session summary
  Screens/, Components/           Home, Intentions, Journal, Saints, Settings, Narrator voice; shared views and theme
Tests/RosaryCoreTests/            Swift Testing suites, including scripted-transcript runs
docs/CONTENT_TODO.md              unverified saint slots and licensing notes
docs/RECORDINGS.md                every recording slot, its file name, and the exact words
scripts/                          iOS compile check, icon generator
```

`SessionEngine` turns events (a transcript update, a tap, narration finished, a clock tick) into effects (speak this, listen with this epoch, play a haptic, advance). It takes timestamps as input and never reads the clock, so the tests drive whole sessions from scripted transcripts. Those scripts include partial results, recogniser restarts, misheard words, and people talking over the narrator, and the tests check exactly when and why each step advanced. The iOS services implement small protocols declared in `RosaryCore` (`Session/Services.swift`), so the same engine runs with the real speech recogniser on the phone.

Narration goes through the same kind of seam. The engine emits a `Narration`: a list of parts, where fixed wording (a prayer's leader part, an intention, a mystery announcement) is tagged with a `NarrationClip` and names are plain text. `NarrationPlanner` turns each part into either a recording, if one is bundled for that clip, or paced phrases for the voice (`SpeechPacing`). `NarrationSequencer` plays the items in order through a `NarrationOutput`, which on the phone is `SpeechOutput` (AVSpeechSynthesizer and AVAudioPlayer), and reports back to the engine once. If a recording can't be played, the voice reads that part instead. `VoiceCatalog` ranks the installed voices. All of this except `SpeechOutput` is in `RosaryCore` and tested on Linux.

## Recorded prayers

Any fixed wording can be replaced by a real recording without code changes. Name the file after its slot (for example `prayer.hailMary.m4a`, `prayer.gloryBe.holyGhost.m4a`, `intention.faith.m4a`, `mystery.scourging.m4a`; `m4a`, `caf`, `wav`, `aiff`, and `mp3` all work), put it in `Sources/RosaryCore/Resources/Recordings/`, and rebuild. Parts without a recording keep using the voice, so a set can be recorded a few files at a time. [docs/RECORDINGS.md](docs/RECORDINGS.md) lists all 34 slots with the exact words to record; a test keeps that list in step with the prayer texts. Nothing is downloaded and no cloud voice is used.

Data is stored as JSON in the app's Application Support folder: `settings.json`, `sessions.json`, and `intentions.json`. A missing or corrupt file falls back to defaults instead of crashing.

## Privacy

- Speech recognition is on-device only (`requiresOnDeviceRecognition = true`). If the phone can't recognise speech on-device, voice tracking is turned off rather than sending audio to a server.
- No network code, no third-party SDKs, no analytics, no accounts. The only dependency is the Swift standard library and Apple's frameworks.
- Nothing leaves the phone except a journal export you share yourself.

## Saints content

Quotations are held to strict rules: every one is the saint's own words, copied from a downloaded copy of the cited edition and compared word for word, with the work, section, translation, and license recorded. Slots that couldn't be verified that way are placeholders that the app never shows, and the mystery falls back to a reflection prompt that is labelled as not a quotation. [docs/CONTENT_TODO.md](docs/CONTENT_TODO.md) lists the placeholders, how to fill them, and the licensing review that's still needed.

## Build verification so far

The development environment for this repo is a Linux VM without an Apple ID, so signed builds are made on the owner's machine (the first one has been installed on an iPhone 11). This is what was run in the VM:

1. `swift test`: 137 tests pass on Linux (Swift 6.4).
2. `scripts/ios-compile-check.sh` against an iPhoneOS 26.5 SDK: both `RosaryCore` (Swift 6 language mode) and the SwiftUI app (Swift 5 mode) compile to arm64 iOS 17 object files with no warnings from the project's sources, and the `@main` entry point is present.
3. `xtool dev build` (xtool 1.20.1):
   - Run non-interactively, it crashed immediately with `epoll_ctl(...): Operation not permitted` (see Troubleshooting).
   - Run in a terminal, it got as far as:

     ```
     Now generating the Darwin SDK.

     Please download Xcode from http://developer.apple.com/download/all/?q=Xcode
     and enter the path to the downloaded Xcode.xip.

     Path to Xcode.xip:
     ```

     It stopped there, because downloading Xcode needs an Apple ID sign-in. On a machine where `xtool setup` has been done, `xtool dev build` continues to a full `.app`.
4. Linking was also tried with the `ld64.lld` that ships with the Swift toolchain, but that build of lld refuses to link for the iOS platform, so linking and signing are left to xtool.

To try the latest changes, pull and run `xtool dev run --usb` again on the owner's build machine.

## Decisions for the owner

1. **John Paul II excerpts.** 15 short attributed excerpts from *Rosarium Virginis Mariae* (© Libreria Editrice Vaticana). Individually brief, but together they cover much of sections 20–23. That's fine for personal use; before any public distribution, keep a subset or ask LEV for permission. Every mystery still has a public-domain quotation without them.
2. **Thérèse translation.** The 1912 T. N. Taylor translation is public domain in the US; elsewhere it depends on the translator's death date, which hasn't been checked.
3. **Padre Pio and St. Faustina.** Their English texts are copyrighted (Edizioni Padre Pio; Marian Press). Seven placeholder slots are waiting: ask for permission, or delete the slots.
4. **Bundle ID.** `com.lojo.Rosary` in `xtool.yml`. Change it now if you want something else; changing it later creates a new app on the phone without the old data.
5. **Defaults.** Guided mode, one decade, dark appearance, "Holy Spirit" (with a "Holy Ghost" option), seasonal Sundays off, the opening faith/hope/charity intentions on, a medium (8-second) pause after each mystery announcement, the meditation panel open in tracking mode, and narration with the best installed voice at a calm pace: rate 0.46 on iOS's 0-to-1 scale, where 0.5 is normal speed, and pitch 0.95, a touch below the voice's natural pitch. Settings saved at the old default pace (0.42) move to the new one; a pace someone chose is kept. Family mode starts off, with placeholder members "Dad" and "Mom".
6. **What counts toward the streak.** A session is saved to history (and counts for the streak) only if at least one full decade was prayed; ending earlier saves nothing.
7. **Optional prayers not included.** The closing has the Hail Holy Queen, the versicle, the Rosary prayer ("O God, whose only-begotten Son…"), and the Sign of the Cross. Some families add the St. Michael prayer or prayers for the Holy Father's intentions; neither is in the app yet.
