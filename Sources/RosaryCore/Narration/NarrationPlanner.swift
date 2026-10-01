import Foundation

/// Pre-recorded audio for fixed wording. Returning nil means "synthesize this part".
public protocol NarrationRecordings: Sendable {
    func recording(for clip: NarrationClip) -> URL?
}

/// Every part is synthesized.
public struct NoRecordings: NarrationRecordings {
    public init() {}
    public func recording(for clip: NarrationClip) -> URL? { nil }
}

/// Audio files in one folder, named after `NarrationClip.fileName`, e.g. `prayer.hailMary.m4a`.
public struct RecordingFolder: NarrationRecordings {
    public static let fileExtensions = ["m4a", "caf", "wav", "aiff", "mp3"]

    public let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    /// Recordings shipped in RosaryCore's resources (`Sources/RosaryCore/Resources/Recordings`).
    /// SwiftPM copies them to the top of the resource bundle.
    public static var bundled: RecordingFolder? {
        Bundle.module.resourceURL.map(RecordingFolder.init(directory:))
    }

    public func recording(for clip: NarrationClip) -> URL? {
        for fileExtension in Self.fileExtensions {
            let url = directory.appendingPathComponent(clip.fileName).appendingPathExtension(fileExtension)
            if FileManager.default.fileExists(atPath: url.path) { return url }
        }
        return nil
    }
}

/// One thing for the audio output to play.
public enum NarrationItem: Hashable, Sendable {
    /// A recorded clip, plus the synthesized phrases to fall back on if it can't be played.
    case recording(URL, fallback: [SpokenPhrase], pauseAfter: TimeInterval)
    case synthesized(SpokenPhrase)
}

/// Turns a narration into playable items: a recording for each part that has one, and paced,
/// synthesized phrases for everything else.
public struct NarrationPlanner: Sendable {
    public var recordings: any NarrationRecordings
    public var pacing: SpeechPacing

    public init(recordings: any NarrationRecordings = NoRecordings(), pacing: SpeechPacing = SpeechPacing()) {
        self.recordings = recordings
        self.pacing = pacing
    }

    public func items(for narration: Narration) -> [NarrationItem] {
        let parts = narration.parts.filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        var items: [NarrationItem] = []
        for (position, part) in parts.enumerated() {
            let pause = position == parts.count - 1 ? 0 : pacing.partPause
            let speech = pacing.phrases(in: part.text, finalPause: pause)
            if let clip = part.clip, let url = recordings.recording(for: clip) {
                items.append(.recording(url, fallback: speech, pauseAfter: pause))
            } else {
                items += speech.map(NarrationItem.synthesized)
            }
        }
        return items
    }
}
