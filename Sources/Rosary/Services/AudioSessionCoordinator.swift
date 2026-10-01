#if os(iOS)
import AVFoundation
import UIKit

/// Owns the shared audio session during prayer: category, interruptions, and media resets.
@MainActor
final class AudioSessionCoordinator {
    var onInterruptionBegan: (() -> Void)?
    var onMediaServicesReset: (() -> Void)?

    private var observers: [NSObjectProtocol] = []
    private let session = AVAudioSession.sharedInstance()

    init() {
        let center = NotificationCenter.default
        observers.append(center.addObserver(
            forName: AVAudioSession.interruptionNotification, object: session, queue: .main
        ) { [weak self] note in
            let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            let began = raw.flatMap(AVAudioSession.InterruptionType.init(rawValue:)) == .began
            MainActor.assumeIsolated {
                if began { self?.onInterruptionBegan?() }
            }
        })
        observers.append(center.addObserver(
            forName: AVAudioSession.mediaServicesWereResetNotification, object: session, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.onMediaServicesReset?() }
        })
    }

    deinit {
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
    }

    /// Speaker output (so the family can hear) plus the microphone when voice tracking is on.
    func activate(listening: Bool) {
        do {
            if listening {
                try session.setCategory(
                    .playAndRecord, mode: .default,
                    options: [.defaultToSpeaker, .allowBluetoothA2DP, .duckOthers]
                )
            } else {
                try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            }
            try session.setActive(true)
        } catch {
            // Narration and listening degrade to silent tap-to-advance; the session still works.
        }
    }

    func deactivate() {
        try? session.setActive(false, options: .notifyOthersOnDeactivation)
    }

    func keepScreenAwake(_ awake: Bool) {
        UIApplication.shared.isIdleTimerDisabled = awake
    }
}
#endif
