import RosaryCore
import SwiftUI

@main
struct RosaryWatchApp: App {
    var body: some Scene {
        WindowGroup {
            WatchCounterView()
        }
    }
}

struct WatchCounterView: View {
    @State private var counter = WatchCounter()

    var body: some View {
        VStack(spacing: 8) {
            Text("†")
                .font(.title3)
                .foregroundStyle(Color(red: 0.95, green: 0.78, blue: 0.42))
            Text(counter.label)
                .font(.title2.monospacedDigit())
                .accessibilityIdentifier(UITag.watchCount)
            Button("Bead") { counter.advance() }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity, minHeight: 36)
                .accessibilityIdentifier(UITag.watchAdvance)
            HStack {
                Button("Back") { counter.back() }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity, minHeight: 32)
                    .accessibilityIdentifier(UITag.watchBack)
                Button("Reset") { counter.reset() }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity, minHeight: 32)
                    .accessibilityIdentifier(UITag.watchReset)
            }
        }
        .sensoryFeedback(.impact, trigger: counter.bead)
    }
}
