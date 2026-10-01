import Testing
@testable import RosaryCore

@Suite("Full Rosary")
struct FullRosaryTests {
    @Test("Guided: opening, five decades, and closing, answered by voice")
    func guidedFullRosary() {
        let h = EngineHarness(scope: .fullRosary, set: .glorious, mode: .guided,
                              leaders: [1: "Dad", 2: "Mom", 3: "Ann", 4: "Dad", 5: "Mom"],
                              nextSessionLeader: "Ann")
        h.start()
        var guard_ = 0
        while h.phase != .finished && guard_ < 200 {
            h.runUntilListening()
            if h.phase == .finished { break }
            h.say(h.responseOfCurrentStep)
            guard_ += 1
        }
        #expect(h.phase == .finished)
        #expect(h.decadesCompleted == [1, 2, 3, 4, 5])
        #expect(h.engine.advances.allSatisfy { $0.cause != .tap })

        let said = h.spoken.joined(separator: "\n")
        #expect(h.spoken.first == h.book.text(for: .signOfTheCross).leader)
        #expect(said.contains("I believe in God, the Father almighty"))
        #expect(said.contains("For an increase of faith. Hail Mary"))
        #expect(said.contains("For an increase of hope. Hail Mary"))
        #expect(said.contains("For an increase of charity. Hail Mary"))
        #expect(said.contains("The Third Glorious Mystery: The Descent of the Holy Spirit."))
        #expect(said.contains("Mom leads the next decade."))
        #expect(said.contains("Hail, holy Queen, Mother of mercy"))
        #expect(said.contains("Pray for us, O holy Mother of God."))
        #expect(said.contains("O God, whose only-begotten Son"))
        #expect(h.spoken.suffix(2).first == h.book.text(for: .signOfTheCross).leader)
        #expect(h.spoken.last == "Next time, Ann begins.")
        #expect(h.spoken.filter { $0.contains("Hail Mary, full of grace") }.count == 53)
    }

    @Test("Tracking: the whole Rosary prayed aloud is followed to the final Sign of the Cross")
    func trackingFullRosary() {
        let h = EngineHarness(scope: .fullRosary, set: .luminous, mode: .tracking)
        h.start()
        var beadsSeen: [Int] = []
        for step in h.engine.plan.steps {
            let text: String = switch step.content {
            case .mysteryAnnouncement(let m): m.announcement
            case .prayer(let id): h.book.text(for: id).full
            }
            h.say(text)
            if step.prayerID == .hailMary, h.step.prayerID == .hailMary, let bead = h.step.bead {
                beadsSeen.append(bead)
            }
        }
        #expect(h.phase == .finished)
        #expect(h.decadesCompleted == [1, 2, 3, 4, 5])
        #expect(beadsSeen == [1, 2, 3] + Array(repeating: Array(1...10), count: 5).flatMap { $0 })
        #expect(h.engine.estimatedSteps.isEmpty)
    }

    @Test("Tracking: following along when the family prays 'Holy Ghost'")
    func holyGhost() {
        let h = EngineHarness(scope: .fullRosary, set: .joyful, mode: .tracking)
        h.start()
        h.say("In the name of the Father, and of the Son, and of the Holy Ghost. Amen.")
        h.say("I believe in God, the Father almighty, Creator of heaven and earth")
        #expect(h.step.prayerID == .apostlesCreed)
        h.say(PrayerBook(usesHolyGhost: true).text(for: .apostlesCreed).full)
        h.say(h.book.text(for: .ourFather).full)
        for _ in 0..<3 { h.say(h.book.text(for: .hailMary).full) }
        h.say("Glory be to the Father, and to the Son, and to the Holy Ghost.")
        #expect(h.step.prayerID == .gloryBe)
    }
}
