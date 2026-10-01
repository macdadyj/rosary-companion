import Foundation
import Testing
@testable import RosaryCore

@Suite("Saints library")
struct SaintsLibraryTests {
    let library: SaintsLibrary

    init() throws {
        library = try SaintsLibrary.bundled()
    }

    @Test func everyMysteryHasAnEntryAndAPrompt() {
        for id in MysteryID.allCases {
            let entry = library.entry(for: id)
            #expect(entry != nil, "missing \(id)")
            #expect(entry?.reflectionPrompt.hasPrefix("Reflection prompt (not a quotation):") == true)
            #expect(library.card(for: id, on: CivilDate(year: 2026, month: 10, day: 1)) != nil)
        }
        #expect(library.file.mysteries.count == 20)
    }

    @Test func verifiedEntriesHaveTextSourceAndKnownLicense() {
        for entry in library.file.mysteries {
            for meditation in entry.meditations {
                if meditation.verified {
                    #expect(meditation.text?.isEmpty == false, "\(meditation.id) verified without text")
                    #expect(meditation.source?.isEmpty == false, "\(meditation.id) verified without source")
                    #expect(
                        ["public domain", "short attributed excerpt"].contains(meditation.license),
                        "\(meditation.id) has license \(meditation.license)"
                    )
                } else {
                    #expect(meditation.text == nil, "\(meditation.id) is unverified but has text")
                    #expect(!meditation.isDisplayable)
                }
            }
        }
    }

    @Test func excerptsStayShort() {
        for entry in library.file.mysteries {
            for meditation in entry.meditations where meditation.isDisplayable {
                let words = meditation.text!.split(whereSeparator: \.isWhitespace).count
                let limit = meditation.license == "short attributed excerpt" ? 75 : 90
                #expect(words <= limit, "\(meditation.id) is \(words) words")
            }
        }
    }

    @Test func bundledLibraryHasAVerifiedQuoteForEveryMystery() {
        for id in MysteryID.allCases {
            #expect(!library.verifiedQuotes(for: id).isEmpty, "\(id) has no verified quote")
        }
    }

    @Test func placeholdersSayWhereToLook() {
        for (_, placeholder) in library.allUnverified {
            #expect(placeholder.suggestedSource?.isEmpty == false, "\(placeholder.id) has no suggested source")
            #expect(placeholder.verificationNote?.hasPrefix("Placeholder") == true)
        }
    }

    @Test func idsAreUnique() {
        let ids = library.file.mysteries.flatMap(\.meditations).map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test func everyPlaceholderIsListedInContentTodo() throws {
        let todo = try String(contentsOf: Self.repositoryRoot.appendingPathComponent("docs/CONTENT_TODO.md"), encoding: .utf8)
        for (_, placeholder) in library.allUnverified {
            #expect(todo.contains(placeholder.id), "\(placeholder.id) is not listed in docs/CONTENT_TODO.md")
        }
    }

    @Test func fallsBackToPromptWithoutVerifiedQuote() throws {
        let file = SaintsLibrary.File(
            schemaVersion: 1, contentPolicy: "",
            mysteries: [
                MysteryMeditations(
                    mystery: .nativity,
                    reflectionPrompt: "Reflection prompt (not a quotation): test",
                    meditations: [
                        SaintMeditation(
                            id: "nativity.placeholder", saint: "St. Example", text: nil, source: nil,
                            license: "unknown", verified: false
                        ),
                    ]
                ),
            ]
        )
        let library = SaintsLibrary(file: file)
        #expect(library.card(for: .nativity, on: CivilDate(year: 2026, month: 12, day: 25))
            == .reflection("Reflection prompt (not a quotation): test"))
        #expect(library.card(for: .annunciation, on: CivilDate(year: 2026, month: 12, day: 25)) == nil)
    }

    @Test func verifiedQuotesTakeTurnsByDay() {
        let quotes = (1...3).map { n in
            SaintMeditation(
                id: "q\(n)", saint: "St. \(n)", text: "Text \(n).", source: "Work \(n)",
                license: "public domain", verified: true
            )
        }
        let library = SaintsLibrary(file: SaintsLibrary.File(
            schemaVersion: 1, contentPolicy: "",
            mysteries: [MysteryMeditations(mystery: .resurrection, reflectionPrompt: "p", meditations: quotes)]
        ))
        let day = CivilDate(year: 2026, month: 4, day: 5)
        var seen = Set<String>()
        for offset in 0..<3 {
            if case let .quote(q) = library.card(for: .resurrection, on: day.adding(days: offset)) { seen.insert(q.id) }
        }
        #expect(seen.count == 3)
    }

    static var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
