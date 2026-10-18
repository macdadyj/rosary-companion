import ActivityKit
import RosaryCore
import SwiftUI
import WidgetKit

struct RosaryEntry: TimelineEntry {
    let date: Date
    let title: String
    let detail: String
}

struct RosaryProvider: TimelineProvider {
    func placeholder(in context: Context) -> RosaryEntry {
        RosaryEntry(date: .now, title: "The Joyful Mysteries", detail: "Pray the Rosary")
    }

    func getSnapshot(in context: Context, completion: @escaping (RosaryEntry) -> Void) {
        completion(entry(for: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RosaryEntry>) -> Void) {
        let now = Date()
        let next = Calendar.current.startOfDay(for: now.addingTimeInterval(36 * 60 * 60))
        completion(Timeline(entries: [entry(for: now)], policy: .after(next)))
    }

    private func entry(for date: Date) -> RosaryEntry {
        let content = try? PrayerContent.bundled()
        let lectionary = try? LectionaryLibrary.bundled()
        let card = TodayCard.make(date: date, calendar: .current, content: content, lectionary: lectionary)
        return RosaryEntry(date: date, title: card.title, detail: card.detail)
    }
}

struct RosaryWidgetView: View {
    let entry: RosaryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("†")
                .font(.title2)
                .foregroundStyle(Color(red: 0.95, green: 0.78, blue: 0.42))
            Text(entry.title)
                .font(.headline)
            Text(entry.detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(Color(red: 0.07, green: 0.035, blue: 0.025), for: .widget)
    }
}

struct RosaryHomeWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "RosaryToday", provider: RosaryProvider()) { entry in
            RosaryWidgetView(entry: entry)
        }
        .configurationDisplayName("Today’s Rosary")
        .description("Today’s mysteries, the Ruthenian and Roman calendars, and the gospel citation.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct RosaryLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PrayerActivityAttributes.self) { context in
            VStack(alignment: .leading, spacing: 4) {
                Text(context.state.title)
                    .font(.headline)
                Text(context.state.detail)
                    .font(.caption)
                Text("\(context.state.completed) of \(context.state.total)")
                    .font(.caption.monospacedDigit())
            }
            .padding()
            .activityBackgroundTint(Color(red: 0.07, green: 0.035, blue: 0.025))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.title)
                }
            } compactLeading: {
                Text("†")
            } compactTrailing: {
                Text("\(context.state.completed)")
            } minimal: {
                Text("†")
            }
        }
    }
}

@main
struct RosaryWidgetBundle: WidgetBundle {
    var body: some Widget {
        RosaryHomeWidget()
        RosaryLiveActivityWidget()
    }
}
