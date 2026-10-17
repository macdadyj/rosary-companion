#if os(iOS)
import RosaryCore
import SwiftUI

struct ReadingsView: View {
    let model: AppModel

    @State private var date: CivilDate
    @State private var library: LectionaryLibrary?
    @State private var unavailable = false

    init(model: AppModel) {
        self.model = model
        _date = State(initialValue: model.today)
    }

    var body: some View {
        let liturgical = LiturgicalCalendar.day(date)
        let link = LiturgicalCalendar.usccbReadingsURL(for: date)
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Button {
                        date = date.adding(days: -1)
                    } label: {
                        Image(systemName: "chevron.left")
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Previous day")
                    Spacer()
                    Button {
                        date = date.adding(days: 1)
                    } label: {
                        Image(systemName: "chevron.right")
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Next day")
                }
                .font(.headline)
                .foregroundStyle(Theme.gold)

                Text(heading(for: liturgical))
                    .font(.prayer(.largeTitle, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .uiTag(UITag.readingsDay)
                Text(liturgical.color.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.background)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Theme.gold, in: Capsule())
                    .uiTag(UITag.readingsColor)
                Text(liturgical.season.title)
                    .font(.prayer(.title3))
                    .foregroundStyle(Theme.secondaryInk)
                if let celebration = library?.day(on: date)?.celebration, !celebration.isEmpty {
                    Text(celebration)
                        .font(.prayer(.title2, weight: .semibold))
                        .foregroundStyle(Theme.gold)
                }

                if let day = library?.day(on: date), !day.readings.isEmpty {
                    VStack(alignment: .leading, spacing: 18) {
                        ForEach(Array(day.readings.enumerated()), id: \.offset) { _, reading in
                            readingBlock(reading.label, reading.citation)
                        }
                    }
                    .uiTag(UITag.readingsBody)
                } else {
                    Text(unavailable
                        ? "The citations for this day are not in the offline calendar."
                        : "Loading the readings.")
                        .font(.body)
                        .foregroundStyle(Theme.secondaryInk)
                        .uiTag(UITag.readingsBody)
                }

                Link(destination: link) {
                    Text("Read at USCCB")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(PrimaryButtonStyle())
                .uiTag(UITag.readingsLink)
                .accessibilityLabel("Read at USCCB. \(link.absoluteString)")
                .accessibilityValue(link.absoluteString)

                Text("Citations from the Catholic Readings API. The words are the Challoner Douay-Rheims. Where the lectionary’s verse numbers differ, the citation stays and the USCCB page has the reading.")
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryInk)
                if let notice = library?.notice {
                    Text(notice)
                        .font(.caption2)
                        .foregroundStyle(Theme.secondaryInk)
                }
            }
            .padding(20)
        }
        .background(CandleBackground())
        .navigationTitle("Today")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .task(id: date.description) { await refresh(date) }
    }

    private func heading(for day: LiturgicalDay) -> String {
        "\(weekdayName(day.date)), \(monthName(day.date.month)) \(day.date.day)"
    }

    private func readingBlock(_ label: String, _ citation: String) -> some View {
        let text = library?.text(for: citation) ?? ""
        return VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.gold)
            Text(citation)
                .font(.prayer(.title3, weight: .semibold))
                .foregroundStyle(Theme.ink)
            if text.isEmpty {
                Text("These verse numbers are not in the bundled Douay-Rheims.")
                    .font(.callout)
                    .foregroundStyle(Theme.secondaryInk)
            } else {
                Text(text)
                    .font(.prayer(.body))
                    .foregroundStyle(Theme.ink)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .chapelPanel()
    }

    private func load() async {
        guard library == nil else { return }
        let overlay = overlayDays()
        if let bundled = try? LectionaryLibrary.bundled(overlay: overlay) {
            library = bundled
        } else {
            unavailable = true
        }
    }

    private func refresh(_ date: CivilDate) async {
        let month = String(format: "%02d", date.month)
        let day = String(format: "%02d", date.day)
        guard let readingsURL = URL(string: "https://cpbjr.github.io/catholic-readings-api/readings/\(date.year)/\(month)-\(day).json") else { return }
        do {
            let (data, response) = try await URLSession.shared.data(from: readingsURL)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return }
            let payload = try JSONDecoder().decode(ReadingsPayload.self, from: data)
            var celebration = library?.day(on: date)?.celebration
            if let calendarURL = URL(string: "https://cpbjr.github.io/catholic-readings-api/liturgical-calendar/\(date.year)/\(month)-\(day).json"),
               let (calendarData, calendarResponse) = try? await URLSession.shared.data(from: calendarURL),
               let calendarHTTP = calendarResponse as? HTTPURLResponse, calendarHTTP.statusCode == 200,
               let calendar = try? JSONDecoder().decode(CalendarPayload.self, from: calendarData) {
                celebration = calendar.celebration?.name ?? celebration
            }
            let stored = LectionaryDay(
                season: payload.season ?? LiturgicalCalendar.day(date).season.title,
                celebration: celebration,
                firstReading: payload.readings?.firstReading,
                psalm: payload.readings?.psalm,
                secondReading: payload.readings?.secondReading,
                gospel: payload.readings?.gospel
            )
            var days = overlayDays()
            days[date.description] = stored
            if let store = try? JSONFileStore.applicationSupport() {
                try? store.save(LectionaryOverlay(days: days), to: "lectionary-overlay.json")
            }
            if let bundled = try? LectionaryLibrary.bundled(overlay: days) {
                library = bundled
                unavailable = false
            }
        } catch {
            if library?.day(on: date) == nil {
                unavailable = true
            }
        }
    }

    private func overlayDays() -> [String: LectionaryDay] {
        guard let store = try? JSONFileStore.applicationSupport(),
              let overlay = try? store.load(LectionaryOverlay.self, from: "lectionary-overlay.json") else {
            return [:]
        }
        return overlay.days
    }

    private func weekdayName(_ date: CivilDate) -> String {
        switch date.weekday {
        case 1: "Sunday"
        case 2: "Monday"
        case 3: "Tuesday"
        case 4: "Wednesday"
        case 5: "Thursday"
        case 6: "Friday"
        case 7: "Saturday"
        default: "Day"
        }
    }

    private func monthName(_ month: Int) -> String {
        switch month {
        case 1: "January"
        case 2: "February"
        case 3: "March"
        case 4: "April"
        case 5: "May"
        case 6: "June"
        case 7: "July"
        case 8: "August"
        case 9: "September"
        case 10: "October"
        case 11: "November"
        case 12: "December"
        default: ""
        }
    }
}

private struct ReadingsPayload: Decodable {
    var season: String?
    var readings: Readings?

    struct Readings: Decodable {
        var firstReading: String?
        var psalm: String?
        var secondReading: String?
        var gospel: String?
    }
}

private struct CalendarPayload: Decodable {
    var celebration: Celebration?

    struct Celebration: Decodable {
        var name: String?
    }
}
#endif
