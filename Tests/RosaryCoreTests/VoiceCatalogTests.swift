import Testing
@testable import RosaryCore

@Suite("Voice catalog")
struct VoiceCatalogTests {
    static let zoePremium = VoiceInfo(
        id: "com.apple.voice.premium.en-US.Zoe", name: "Zoe", language: "en-US", quality: .premium
    )
    static let danielEnhanced = VoiceInfo(
        id: "com.apple.voice.enhanced.en-GB.Daniel", name: "Daniel", language: "en-GB", quality: .enhanced
    )
    static let samantha = VoiceInfo(
        id: "com.apple.voice.compact.en-US.Samantha", name: "Samantha", language: "en-US", quality: .standard
    )
    static let aaron = VoiceInfo(
        id: "com.apple.ttsbundle.siri_Aaron_en-US_compact", name: "Aaron", language: "en-US", quality: .standard
    )
    static let danielCompact = VoiceInfo(
        id: "com.apple.voice.compact.en-GB.Daniel", name: "Daniel", language: "en-GB", quality: .standard
    )
    static let karen = VoiceInfo(
        id: "com.apple.voice.compact.en-AU.Karen", name: "Karen", language: "en_AU", quality: .standard
    )
    static let eddy = VoiceInfo(
        id: "com.apple.eloquence.en-US.Eddy", name: "Eddy", language: "en-US", quality: .standard
    )
    static let fred = VoiceInfo(
        id: "com.apple.speech.synthesis.voice.Fred", name: "Fred", language: "en-US", quality: .standard
    )
    static let bells = VoiceInfo(
        id: "com.apple.speech.synthesis.voice.Bells", name: "Bells", language: "en-US", quality: .standard,
        isNovelty: true
    )
    static let personal = VoiceInfo(
        id: "personal.voice.1", name: "My Voice", language: "en-US", quality: .premium, isPersonal: true
    )
    static let amelie = VoiceInfo(
        id: "com.apple.voice.premium.fr-FR.Amelie", name: "Amélie", language: "fr-FR", quality: .premium
    )

    static let installed = [
        aaron, samantha, danielCompact, karen, eddy, fred, bells, personal, amelie, danielEnhanced, zoePremium,
    ]

    @Test func premiumBeatsEnhancedBeatsStandard() {
        let catalog = VoiceCatalog(installed: Self.installed)
        #expect(catalog.best == Self.zoePremium)
        #expect(catalog.voices.map(\.quality) == [.premium, .enhanced, .standard, .standard, .standard, .standard])

        let withoutPremium = VoiceCatalog(installed: Self.installed.filter { $0 != Self.zoePremium })
        #expect(withoutPremium.best == Self.danielEnhanced)
    }

    @Test func roboticNoveltyPersonalAndOtherLanguageVoicesAreLeftOut() {
        let ids = Set(VoiceCatalog(installed: Self.installed).voices.map(\.id))
        for excluded in [Self.eddy, Self.fred, Self.bells, Self.personal, Self.amelie] {
            #expect(!ids.contains(excluded.id), "\(excluded.name) should not be offered")
        }
        #expect(ids.count == 6)
    }

    @Test func amongEqualQualityTheirOwnRegionThenAmericanEnglishComeFirst() {
        let standard = [Self.karen, Self.danielCompact, Self.samantha, Self.aaron]
        #expect(VoiceCatalog(installed: standard).voices.map(\.name) == ["Aaron", "Samantha", "Karen", "Daniel"])
        #expect(VoiceCatalog(installed: standard, preferredRegion: "gb").best == Self.danielCompact)
        #expect(VoiceCatalog(installed: standard, preferredRegion: "AU").best == Self.karen)
    }

    @Test func qualityStillOutranksRegion() {
        let catalog = VoiceCatalog(installed: [Self.danielCompact, Self.zoePremium], preferredRegion: "GB")
        #expect(catalog.best == Self.zoePremium)
    }

    @Test func theSystemDefaultWinsATie() {
        let catalog = VoiceCatalog(installed: [Self.aaron, Self.samantha], systemDefaultID: Self.samantha.id)
        #expect(catalog.best == Self.samantha)
    }

    @Test func aChosenVoiceIsUsedWhileItIsInstalledAndSuitable() {
        let catalog = VoiceCatalog(installed: Self.installed)
        #expect(catalog.voice(selectedID: Self.samantha.id) == Self.samantha)
        #expect(catalog.voice(selectedID: "com.apple.voice.enhanced.en-US.Ava") == Self.zoePremium)
        #expect(catalog.voice(selectedID: Self.eddy.id) == Self.zoePremium)
        #expect(catalog.voice(selectedID: nil) == Self.zoePremium)
    }

    @Test func suggestsADownloadOnlyWhenEveryVoiceIsStandard() {
        #expect(VoiceCatalog(installed: Self.installed).hasNaturalVoice)
        #expect(VoiceCatalog(installed: [Self.danielEnhanced]).hasNaturalVoice)
        #expect(!VoiceCatalog(installed: [Self.samantha, Self.eddy, Self.personal]).hasNaturalVoice)
        #expect(!VoiceCatalog(installed: []).hasNaturalVoice)
    }

    @Test func voicesAreGroupedByQuality() {
        let catalog = VoiceCatalog(installed: Self.installed)
        #expect(catalog.voices(of: .premium) == [Self.zoePremium])
        #expect(catalog.voices(of: .enhanced) == [Self.danielEnhanced])
        #expect(catalog.voices(of: .standard).count == 4)
    }

    @Test func nothingInstalledMeansTheSystemDefaultIsUsed() {
        let catalog = VoiceCatalog(installed: [Self.amelie, Self.eddy])
        #expect(catalog.voices.isEmpty)
        #expect(catalog.best == nil)
        #expect(catalog.voice(selectedID: Self.eddy.id) == nil)
    }

    @Test func duplicateIdentifiersAppearOnce() {
        #expect(VoiceCatalog(installed: [Self.samantha, Self.samantha]).voices == [Self.samantha])
    }

    @Test func languageTagsAreParsedEitherWay() {
        #expect(Self.danielEnhanced.languageCode == "en")
        #expect(Self.danielEnhanced.regionCode == "GB")
        #expect(Self.karen.languageCode == "en")
        #expect(Self.karen.regionCode == "AU")
        #expect(VoiceInfo(id: "x", name: "X", language: "en", quality: .standard).regionCode == nil)
        #expect(VoiceQuality.premium > .enhanced && VoiceQuality.enhanced > .standard)
    }
}
