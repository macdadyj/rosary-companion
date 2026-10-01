import Testing
@testable import RosaryCore

@Suite("Text normalisation")
struct NormalizerTests {
    @Test("Lowercases, strips punctuation and accents, canonicalises spoken variants")
    func words() {
        #expect(TextNormalizer.words("Hail Mary, full of grace!") == ["hail", "mary", "full", "of", "grace"])
        #expect(TextNormalizer.words("O my Jesús") == ["o", "my", "jesus"])
        #expect(TextNormalizer.words("Oh my Jesus") == ["o", "my", "jesus"])
        #expect(TextNormalizer.words("The 1st Joyful Mystery") == ["the", "first", "joyful", "mystery"])
        #expect(TextNormalizer.words("the Holy Ghost") == ["the", "holy", "spirit"])
        #expect(TextNormalizer.words("the fire’s heat") == ["the", "fires", "heat"])
        #expect(TextNormalizer.words("only-begotten") == ["only", "begotten"])
    }

    @Test("Folding makes homophones identical or one edit apart")
    func folding() {
        #expect(TextNormalizer.folded("Mary") == TextNormalizer.folded("Marry"))
        #expect(TextNormalizer.folded("thy mercy") == Array("thimerci".utf8))
        let holy = TextNormalizer.folded("holy")
        let wholly = ApproximateMatcher.firstMatch(of: holy, in: TextNormalizer.folded("wholly"), maxErrors: 1)
        #expect(wholly?.distance == 1)
    }
}

@Suite("Approximate matching")
struct ApproximateMatcherTests {
    private func match(_ phrase: String, in text: String, errors: Int? = nil) -> ApproximateMatch? {
        let pattern = TextNormalizer.folded(phrase)
        let k = errors ?? Int(Double(pattern.count) * AnchorLibrary.defaultErrorRate)
        return ApproximateMatcher.firstMatch(of: pattern, in: TextNormalizer.folded(text), maxErrors: k)
    }

    @Test("Exact phrase inside longer speech")
    func exact() throws {
        let found = try #require(match("holy mary mother of god", in: "jesus holy mary mother of god pray"))
        #expect(found.distance == 0)
    }

    @Test("Misheard words still match", arguments: [
        ("hail mary full of grace", "hale marry full of grays the lord is with the"),
        ("o my jesus forgive us our sins", "oh my jesus forgive us are sins"),
        ("glory be to the father", "glory bee to the farther and to the son"),
        ("now and at the hour of our death", "now and at the our of our deaf amen"),
        ("especially those in most need of thy mercy", "especially those and most need of their mercy"),
        ("lead us not into temptation", "lead us not in to temptations"),
    ])
    func noisy(phrase: String, heard: String) {
        #expect(match(phrase, in: heard) != nil, "\"\(heard)\" should match \"\(phrase)\"")
    }

    @Test("Different prayers don't match", arguments: [
        ("o my jesus forgive us our sins", "hail mary full of grace the lord is with thee"),
        ("glory be to the father", "give us this day our daily bread"),
        ("holy mary mother of god", "our father who art in heaven hallowed be thy name"),
        ("world without end", "blessed is the fruit of thy womb jesus"),
    ])
    func unrelated(phrase: String, heard: String) {
        #expect(match(phrase, in: heard) == nil, "\"\(heard)\" should not match \"\(phrase)\"")
    }
}

@Suite("Anchor detector")
struct AnchorDetectorTests {
    let fatima = AnchorLibrary.fragments(for: .fatimaPrayer)
    let gloryBe = AnchorLibrary.fragments(for: .gloryBe)

    private func run(
        _ detector: AnchorDetector,
        _ updates: [TranscriptUpdate],
        fragments: [AnchorFragment],
        start: Double = 0,
        spacing: Double = 0.3
    ) -> [AnchorHit] {
        var hits: [AnchorHit] = []
        for (i, update) in updates.enumerated() {
            hits += detector.process(update, fragments: fragments, now: start + Double(i) * spacing)
        }
        return hits
    }

    @Test("Streaming partials yield each fragment exactly once, in order")
    func streaming() {
        var script = TranscriptScript(epoch: 1)
        let detector = AnchorDetector()
        let updates = script.say(
            "O my Jesus forgive us our sins save us from the fires of hell lead all souls to heaven " +
            "especially those in most need of thy mercy"
        )
        let hits = run(detector, updates + Array(repeating: updates.last!, count: 5), fragments: fatima)
        #expect(hits.map(\.fragment.order) == [0, 1, 2, 3])
        #expect(hits.last?.fragment.isClosing == true)
    }

    @Test("Noisy recognition of the whole Fatima Prayer still reaches the closing phrase")
    func noisyFatima() {
        var script = TranscriptScript(epoch: 1)
        let detector = AnchorDetector()
        let updates = script.say(
            "oh my jesus forgive us are sins save us from the fire of hell lead all soles to heaven " +
            "especially those and most need of their mercy"
        )
        let hits = run(detector, updates + [updates.last!], fragments: fatima)
        #expect(hits.contains { $0.fragment.isClosing })
    }

    @Test("A hypothesis that flickers once and is revised away never fires")
    func flicker() {
        let detector = AnchorDetector()
        let flickering = TranscriptUpdate(epoch: 1, text: "glory be to the father")
        let revised = TranscriptUpdate(epoch: 1, text: "gory details of the farmer")
        var hits = detector.process(flickering, fragments: gloryBe, now: 0)
        hits += detector.process(revised, fragments: gloryBe, now: 0.2)
        hits += detector.tick(now: 1.0)
        #expect(hits.isEmpty)
    }

    @Test("A stable single partial fires after the debounce interval")
    func debounceByTime() {
        let detector = AnchorDetector()
        let update = TranscriptUpdate(epoch: 1, text: "glory be to the father")
        #expect(detector.process(update, fragments: gloryBe, now: 0).isEmpty)
        #expect(detector.tick(now: 0.2).isEmpty)
        #expect(detector.tick(now: 0.4).map(\.fragment.order) == [0])
        #expect(detector.tick(now: 0.8).isEmpty)
    }

    @Test("A final result fires immediately")
    func finalResult() {
        let detector = AnchorDetector()
        let update = TranscriptUpdate(epoch: 1, text: "world without end amen", isFinal: true)
        #expect(detector.process(update, fragments: gloryBe, now: 0).map(\.fragment.order) == [4])
    }

    @Test("The recogniser re-sending the same text never fires twice")
    func noDoubleFire() {
        let detector = AnchorDetector()
        let update = TranscriptUpdate(epoch: 1, text: "as it was in the beginning is now")
        var hits: [AnchorHit] = []
        for i in 0..<20 {
            hits += detector.process(update, fragments: gloryBe, now: Double(i) * 0.25)
            hits += detector.tick(now: Double(i) * 0.25 + 0.1)
        }
        #expect(hits.map(\.fragment.order) == [2])
    }

    @Test("Revisions of earlier words don't re-trigger consumed phrases")
    func revisionsAfterHit() {
        let detector = AnchorDetector()
        let updates = [
            "holy mary mother of god",
            "holy mary mother of god",
            "wholly mary mother of god pray",
            "holy marry mother of god pray for us",
            "holy mary mother of god pray for us sinners",
        ].map { TranscriptUpdate(epoch: 1, text: $0) }
        let fragments = AnchorLibrary.fragments(for: .hailMary)
        var hits: [AnchorHit] = []
        for (i, update) in updates.enumerated() {
            hits += detector.process(update, fragments: fragments, now: Double(i) * 0.3)
        }
        hits += detector.tick(now: 3)
        #expect(hits.map(\.fragment.order) == [4, 5])
    }

    @Test("Ordinals are disambiguated: 'fifth' is not taken for 'first'")
    func ordinals() {
        let detector = AnchorDetector()
        let fragments = MysterySet.sorrowful.mysteries.flatMap(AnchorLibrary.fragments(forAnnouncementOf:))
        let update = TranscriptUpdate(epoch: 1, text: "the fifth sorrowful mystery", isFinal: true)
        let hits = detector.process(update, fragments: fragments, now: 0)
        #expect(hits.map(\.fragment.kind) == [.announcement(decade: 5)])

        let detector2 = AnchorDetector()
        let titled = TranscriptUpdate(epoch: 1, text: "the scourging at the pillar", isFinal: true)
        #expect(detector2.process(titled, fragments: fragments, now: 0).map(\.fragment.kind)
                == [.announcement(decade: 2)])
    }

    @Test("A recogniser restart starts a fresh transcript, with cool-down against echoes")
    func segments() {
        let detector = AnchorDetector()
        let first = TranscriptUpdate(epoch: 1, segment: 0, text: "glory be to the father", isFinal: true)
        let echo = TranscriptUpdate(epoch: 1, segment: 1, text: "glory be to the father", isFinal: true)
        let later = TranscriptUpdate(epoch: 1, segment: 2, text: "glory be to the father", isFinal: true)
        #expect(detector.process(first, fragments: gloryBe, now: 0).count == 1)
        #expect(detector.process(echo, fragments: gloryBe, now: 0.5).isEmpty, "inside the cool-down")
        #expect(detector.process(later, fragments: gloryBe, now: 10).count == 1)
    }

    @Test("Two Hail Marys in one burst are both seen")
    func twoInOneUpdate() {
        let detector = AnchorDetector()
        let text = "holy mary mother of god pray for us sinners now and at the hour of our death amen " +
            "hail mary full of grace the lord is with thee blessed art thou among women " +
            "and blessed is the fruit of thy womb jesus holy mary mother of god"
        let update = TranscriptUpdate(epoch: 1, text: text, isFinal: true)
        let hits = detector.process(update, fragments: AnchorLibrary.fragments(for: .hailMary), now: 0)
        #expect(hits.map(\.fragment.order) == [4, 5, 6, 0, 1, 2, 3, 4])
    }
}
