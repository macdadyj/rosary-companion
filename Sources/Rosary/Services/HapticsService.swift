#if os(iOS)
import RosaryCore
import UIKit

@MainActor
final class HapticsService: HapticsPlaying {
    private let soft = UIImpactFeedbackGenerator(style: .soft)
    private let light = UIImpactFeedbackGenerator(style: .light)
    private let notification = UINotificationFeedbackGenerator()

    init() {
        soft.prepare()
        light.prepare()
    }

    func play(_ event: HapticEvent) {
        switch event {
        case .tapAdvance:
            soft.impactOccurred(intensity: 1)
        case .voiceAdvance:
            light.impactOccurred(intensity: 0.5)
        case .stepBack:
            light.impactOccurred(intensity: 0.7)
        case .decadeComplete, .sessionComplete:
            notification.notificationOccurred(.success)
        }
        soft.prepare()
    }
}
#endif
