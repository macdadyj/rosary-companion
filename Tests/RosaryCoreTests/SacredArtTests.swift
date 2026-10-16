import Foundation
import Testing
@testable import RosaryCore

struct SacredArtTests {
    @Test func everyMysteryHasACuratedWesternSourceAndEasternIconsAreIncluded() {
        for mystery in MysteryID.allCases {
            let rows = SacredArtCatalog.categories(for: mystery)
            #expect(rows.contains { $0.tradition == .western })
            #expect(!SacredArtCatalog.keywords(for: mystery).isEmpty)
            for row in rows {
                #expect(row.title.hasPrefix("Category:"))
            }
        }
        let eastern = SacredArtCatalog.categories.filter { $0.tradition == .byzantine }
        #expect(eastern.count >= 19)
        #expect(eastern.contains { $0.title.contains("Icons") || $0.title.contains("Orthodox") })
    }

    @Test func openLicensesPassAndRestrictedOnesDoNot() {
        #expect(SacredArtFilter.licenseIsOpen("Public domain"))
        #expect(SacredArtFilter.licenseIsOpen("PDM-owner"))
        #expect(SacredArtFilter.licenseIsOpen("CC0"))
        #expect(SacredArtFilter.licenseIsOpen("CC BY-SA 4.0"))
        #expect(SacredArtFilter.licenseIsOpen("CC BY 2.0"))
        #expect(!SacredArtFilter.licenseIsOpen("CC BY-NC-SA 4.0"))
        #expect(!SacredArtFilter.licenseIsOpen("CC BY-ND 4.0"))
        #expect(!SacredArtFilter.licenseIsOpen("Fair use"))
        #expect(!SacredArtFilter.licenseIsOpen(""))
    }

    @Test func onlyReverentRelevantImagesAreAccepted() {
        let agony = candidate(
            title: "Agony in the Garden",
            license: "Public domain",
            mime: "image/jpeg",
            width: 800,
            height: 1000,
            summary: "Christ in Gethsemane"
        )
        #expect(SacredArtFilter.accepts(agony))

        var meme = agony
        meme.title = "Agony in the Garden meme"
        #expect(!SacredArtFilter.accepts(meme))

        var restricted = agony
        restricted.license = "CC BY-NC 4.0"
        #expect(!SacredArtFilter.accepts(restricted))

        var drawing = agony
        drawing.mime = "image/svg+xml"
        #expect(!SacredArtFilter.accepts(drawing))

        var stamp = agony
        stamp.width = 80
        stamp.height = 80
        #expect(!SacredArtFilter.accepts(stamp))

        var unrelated = agony
        unrelated.title = "Floor plan of the convent"
        unrelated.summary = "Measured drawing"
        #expect(!SacredArtFilter.accepts(unrelated))
    }

    @Test func parserReadsCommonsImageInfoAndStripsArtistHTML() throws {
        let data = Data(commonsFixture.utf8)
        let parsed = CommonsCatalogParser.candidates(in: data, mystery: .agonyInGarden, tradition: .western)
        #expect(parsed.count == 1)
        let image = try #require(parsed.first)
        #expect(image.artist == "Fra Angelico")
        #expect(image.license == "Public domain")
        #expect(image.title == "Agony in the Garden")
        #expect(image.thumbURL.hasPrefix("https://"))
        #expect(SacredArtFilter.accepts(image))
    }

    @Test func rotationAlternatesTraditionsAndAHandAdvanceChangesTheChoice() {
        let day = CivilDate(year: 2026, month: 10, day: 16)
        let western = record(tradition: .western, sha1: "aaaaaaaaaaaaaaaa")
        let eastern = record(tradition: .byzantine, sha1: "bbbbbbbbbbbbbbbb")
        let index = SacredArtIndex(records: [eastern, western])
        let first = index.choice(for: .agonyInGarden, on: day)
        let second = index.advanced(mystery: .agonyInGarden).choice(for: .agonyInGarden, on: day)
        #expect(first?.sha1 != second?.sha1)
        #expect(index.choice(for: .agonyInGarden, on: day)?.sha1 == first?.sha1)
        let ordered = SacredArtRotation.order([eastern, western])
        #expect(ordered.map(\.tradition) == [.western, .byzantine])
    }

    @Test func cacheKeepsImagesOfflineAndRejectsUnsafeNames() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("sacred-art-\(UUID().uuidString)", isDirectory: true)
        let store = SacredArtStore(directory: directory)
        let jpeg = Data([0xFF, 0xD8, 0xFF, 0xD9])
        let fileName = try #require(try store.writeImage(jpeg, sha1: "abc123def4567890", mime: "image/jpeg"))
        #expect(fileName == "abc123def4567890.jpg")
        #expect(store.imageData(fileName: fileName) == jpeg)
        #expect(store.imageData(fileName: "../index.json") == nil)
        #expect(SacredArtStore.fileName(sha1: "../etc", mime: "image/jpeg") == nil)
        #expect(!SacredArtImageKind.isRasterImage(Data("nope".utf8)))

        let saved = record(tradition: .western, sha1: "abc123def4567890", fileName: fileName)
        try store.save(SacredArtIndex(records: [saved]))
        let loaded = store.load()
        #expect(loaded.records.count == 1)
        #expect(loaded.choice(for: .agonyInGarden, on: CivilDate(year: 2026, month: 10, day: 16))?.fileName == fileName)
        #expect(SacredArtIndex.shouldRefresh(refreshedAt: nil, now: Date()))
        #expect(!SacredArtIndex.shouldRefresh(refreshedAt: Date(), now: Date()))
        try? FileManager.default.removeItem(at: directory)
    }

    @Test func everyMysteryPrintsAFullPassageRatherThanOnlyItsReference() throws {
        let content = try PrayerContent.bundled()
        for mystery in MysteryID.allCases {
            let passage = try #require(content.passage(for: mystery))
            #expect(!passage.verses.isEmpty)
            #expect(passage.body.count > passage.reference.count)
            #expect(passage.body.contains(passage.verses[0].text))
        }
    }

    @Test func tallAndWidePicturesFitInsideTheFrame() {
        let square = ImageFraming.fittedSize(imageWidth: 400, imageHeight: 400, containerWidth: 200, containerHeight: 180)
        #expect(square == FittedSize(width: 180, height: 180))

        let wide = ImageFraming.fittedSize(imageWidth: 640, imageHeight: 160, containerWidth: 200, containerHeight: 180)
        #expect(wide.width == 200)
        #expect(abs(wide.height - 50) < 0.001)
        #expect(wide.width <= 200)
        #expect(wide.height <= 180)

        let tall = ImageFraming.fittedSize(imageWidth: 160, imageHeight: 640, containerWidth: 200, containerHeight: 180)
        #expect(abs(tall.width - 45) < 0.001)
        #expect(tall.height == 180)
        #expect(tall.width <= 200)
        #expect(tall.height <= 180)

        let empty = ImageFraming.fittedSize(imageWidth: 0, imageHeight: 10, containerWidth: 20, containerHeight: 20)
        #expect(empty == FittedSize(width: 0, height: 0))
    }

    private func candidate(
        title: String,
        license: String,
        mime: String,
        width: Int,
        height: Int,
        summary: String
    ) -> SacredArtCandidate {
        SacredArtCandidate(
            mystery: .agonyInGarden,
            tradition: .western,
            title: title,
            artist: "A painter",
            license: license,
            sourceURL: "https://commons.wikimedia.org/wiki/File:Example",
            thumbURL: "https://upload.wikimedia.org/example.jpg",
            mime: mime,
            width: width,
            height: height,
            sha1: "abc123def4567890",
            summary: summary
        )
    }

    private func record(tradition: SacredArtTradition, sha1: String, fileName: String = "aaaaaaaaaaaaaaaa.jpg") -> SacredArtRecord {
        SacredArtRecord(
            mystery: .agonyInGarden,
            tradition: tradition,
            title: "Agony in the Garden",
            artist: "A painter",
            license: "Public domain",
            sourceURL: "https://commons.wikimedia.org/wiki/File:Example",
            sha1: sha1,
            fileName: fileName,
            savedAt: Date(timeIntervalSince1970: 0)
        )
    }
}

private let commonsFixture = """
{"query":{"pages":{"1":{"title":"File:Agony in the Garden.jpg","imageinfo":[{"thumburl":"https://upload.wikimedia.org/thumb/agony.jpg","descriptionurl":"https://commons.wikimedia.org/wiki/File:Agony_in_the_Garden.jpg","mime":"image/jpeg","width":800,"height":1000,"sha1":"abc123def4567890","extmetadata":{"LicenseShortName":{"value":"Public domain"},"Artist":{"value":"<div class=\\"fn\\">Fra Angelico</div>"},"ImageDescription":{"value":"The Agony in the Garden"}}}]}}}}
"""
