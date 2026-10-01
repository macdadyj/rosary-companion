import Foundation

public enum ListenerAvailability: Hashable, Sendable {
    case ready
    case listening
    /// Voice tracking can't run (permission denied, no on-device model, ...). Taps still work.
    case unavailable(String)

    public var isUsable: Bool {
        if case .unavailable = self { return false }
        return true
    }
}

/// Speech recognition, kept behind a protocol so the session can be driven by scripted transcripts.
@MainActor
public protocol SpeechListening: AnyObject {
    var availability: ListenerAvailability { get }
    var onTranscript: (@MainActor (TranscriptUpdate) -> Void)? { get set }
    var onAvailabilityChange: (@MainActor (ListenerAvailability) -> Void)? { get set }
    /// Start listening, or restart recognition, tagging every result with `epoch`.
    func listen(epoch: Int)
    func stop()
}

/// Says the leader parts, announcements, and names aloud. `NarrationSequencer` is the app's
/// implementation: synthesized speech, with recordings standing in where they exist.
@MainActor
public protocol SpeechNarrating: AnyObject {
    /// `completion` runs once, when the narration finishes or is stopped.
    func speak(_ narration: Narration, preDelay: TimeInterval, completion: @escaping @MainActor () -> Void)
    func stop()
}

@MainActor
public protocol HapticsPlaying: AnyObject {
    func play(_ event: HapticEvent)
}
