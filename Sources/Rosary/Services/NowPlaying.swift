#if os(iOS)
import Foundation
import MediaPlayer
import RosaryCore

/// Lock-screen title and play/pause for the prayer that is being read aloud.
@MainActor
final class NowPlaying {
    private var playToken: Any?
    private var pauseToken: Any?

    func install(onToggle: @escaping @MainActor () -> Void) {
        guard playToken == nil else { return }
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.isEnabled = true
        center.pauseCommand.isEnabled = true
        playToken = center.playCommand.addTarget { _ in
            Task { @MainActor in onToggle() }
            return .success
        }
        pauseToken = center.pauseCommand.addTarget { _ in
            Task { @MainActor in onToggle() }
            return .success
        }
    }

    func publish(title: String, playing: Bool) {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyArtist: "Rosary",
            MPNowPlayingInfoPropertyPlaybackRate: playing ? 1.0 : 0.0,
        ]
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = 0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    func clear() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        let center = MPRemoteCommandCenter.shared()
        if let playToken { center.playCommand.removeTarget(playToken) }
        if let pauseToken { center.pauseCommand.removeTarget(pauseToken) }
        playToken = nil
        pauseToken = nil
    }
}
#endif
