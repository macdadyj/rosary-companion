#if os(iOS)
import Foundation
import Observation
import RosaryCore
import UIKit

/// Bundled paintings first. A Commons refresh replaces them when a reverent image is cached.
@MainActor
@Observable
final class SacredArtLibrary {
    private let store: SacredArtStore
    private var index: SacredArtIndex
    private(set) var revision = 0
    private(set) var isRefreshing = false
    private(set) var status = "The paintings in the app are showing."
    private var refreshTask: Task<Void, Never>?
    private var refreshGeneration = 0
    /// Mysteries whose next painting has not arrived yet. The well shows a shimmer instead of the previous picture.
    private(set) var loadingMysteries: Set<MysteryID> = []
    private var fixtures: [MysteryID: FixturePicture] = [:]
    private var fixtureSteps: [MysteryID: Int] = [:]

    private struct FixturePicture {
        var token: String
        var data: Data
        var credit: String
    }

    init(directory: URL) {
        store = SacredArtStore(directory: directory)
        index = store.load()
    }

    static func live() -> SacredArtLibrary {
        let base = (try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        )) ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return SacredArtLibrary(directory: base.appendingPathComponent("Rosary/SacredArt", isDirectory: true))
    }

    func gallery(focus: MysteryID, content: PrayerContent?) -> ArtGallery {
        _ = revision
        return ArtGallery.assemble(works: content?.art.works ?? [], records: index.records, focus: focus)
    }

    func imageData(for plate: ArtPlate, content: PrayerContent?) -> Data? {
        _ = revision
        if let fixture = fixtures[plate.mystery] { return fixture.data }
        switch plate.kind {
        case .bundled:
            return content?.imageData(for: plate.mystery)
        case .cached(let fileName):
            return store.imageData(fileName: fileName) ?? content?.imageData(for: plate.mystery)
        }
    }

    func imageData(for mystery: MysteryID, content: PrayerContent?, on day: CivilDate) -> Data? {
        _ = revision
        if let fixture = fixtures[mystery] { return fixture.data }
        if loadingMysteries.contains(mystery) { return nil }
        if let record = index.choice(for: mystery, on: day),
           let data = store.imageData(fileName: record.fileName) {
            return data
        }
        return content?.imageData(for: mystery)
    }

    func creditLine(for mystery: MysteryID, content: PrayerContent?, on day: CivilDate) -> String {
        _ = revision
        if let fixture = fixtures[mystery] { return fixture.credit }
        if let record = index.choice(for: mystery, on: day),
           store.imageData(fileName: record.fileName) != nil {
            return record.creditLine
        }
        return content?.work(for: mystery)?.creditLine ?? "Mystery artwork"
    }

    /// Changes when the pixels change, so the frame can crossfade to the new painting.
    func imageToken(for mystery: MysteryID, content: PrayerContent?, on day: CivilDate) -> String {
        _ = revision
        if let fixture = fixtures[mystery] { return fixture.token }
        if loadingMysteries.contains(mystery) { return "loading-\(mystery.rawValue)" }
        if let record = index.choice(for: mystery, on: day),
           store.imageData(fileName: record.fileName) != nil {
            return record.sha1
        }
        return "bundled-\(mystery.rawValue)"
    }

    func isLoading(_ mystery: MysteryID) -> Bool {
        loadingMysteries.contains(mystery)
    }

    /// Hand refresh: show the next cached painting, and ask Commons for more.
    /// UI tests swap in a wide picture, then a tall one, and never touch the network.
    func showAnother(mystery: MysteryID, on day: CivilDate) {
        if UITestLaunch.isEnabled {
            let step = (fixtureSteps[mystery] ?? 0) + 1
            fixtureSteps[mystery] = step
            let wide = step % 2 == 1
            fixtures[mystery] = FixturePicture(
                token: wide ? "wide-\(step)" : "tall-\(step)",
                data: Self.fixturePNG(wide: wide),
                credit: wide ? "Wide test image. UI test." : "Tall test image. UI test."
            )
            loadingMysteries.remove(mystery)
            revision += 1
            return
        }
        index = index.advanced(mystery: mystery)
        try? store.save(index)
        let ready = index.choice(for: mystery, on: day)
            .flatMap { store.imageData(fileName: $0.fileName) } != nil
        if ready {
            loadingMysteries.remove(mystery)
        } else {
            loadingMysteries.insert(mystery)
        }
        revision += 1
        refresh(prioritizing: mystery)
    }

    private static func fixturePNG(wide: Bool) -> Data {
        let size = wide ? CGSize(width: 640, height: 160) : CGSize(width: 160, height: 640)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let image = renderer.image { context in
            UIColor(red: 0.16, green: 0.09, blue: 0.05, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            UIColor(red: 0.95, green: 0.78, blue: 0.42, alpha: 1).setFill()
            let bar = wide
                ? CGRect(x: 16, y: size.height / 2 - 18, width: size.width - 32, height: 36)
                : CGRect(x: size.width / 2 - 18, y: 16, width: 36, height: size.height - 32)
            context.fill(bar)
        }
        return image.pngData() ?? Data()
    }

    func refreshIfDue() {
        guard SacredArtIndex.shouldRefresh(refreshedAt: index.refreshedAt, now: Date()) else { return }
        refresh(prioritizing: nil)
    }

    func refresh(prioritizing mystery: MysteryID?) {
        guard !UITestLaunch.isEnabled else { return }
        refreshGeneration += 1
        let generation = refreshGeneration
        refreshTask?.cancel()
        refreshTask = Task { await self.performRefresh(prioritizing: mystery, generation: generation) }
    }

    private func performRefresh(prioritizing mystery: MysteryID?, generation: Int) async {
        isRefreshing = true
        status = "Looking for sacred art…"
        defer {
            if generation == refreshGeneration { isRefreshing = false }
        }
        var incoming: [SacredArtRecord] = []
        var added: [String: Int] = [:]
        var sawCatalog = false
        let categories = SacredArtCatalog.categories.sorted { lhs, rhs in
            (lhs.mystery == mystery) && rhs.mystery != mystery
        }
        for category in categories {
            if Task.isCancelled { break }
            guard let url = CommonsArtRequest.categoryURL(category.title),
                  let data = await fetch(url) else { continue }
            sawCatalog = true
            let accepted = CommonsCatalogParser.candidates(
                in: data, mystery: category.mystery, tradition: category.tradition
            )
            .filter(SacredArtFilter.accepts)
            .sorted { $0.sha1 < $1.sha1 }
            for candidate in accepted {
                if Task.isCancelled { break }
                let slot = "\(candidate.mystery.rawValue)|\(candidate.tradition.rawValue)"
                if (added[slot] ?? 0) >= 1 { continue }
                if index.records.contains(where: { $0.sha1 == candidate.sha1 }) { continue }
                if incoming.contains(where: { $0.sha1 == candidate.sha1 }) { continue }
                guard let thumb = URL(string: candidate.thumbURL), let bytes = await fetch(thumb) else { continue }
                let fileName: String?
                do {
                    fileName = try store.writeImage(bytes, sha1: candidate.sha1, mime: candidate.mime)
                } catch {
                    fileName = nil
                }
                guard let fileName else { continue }
                incoming.append(SacredArtRecord(
                    mystery: candidate.mystery,
                    tradition: candidate.tradition,
                    title: candidate.title,
                    artist: candidate.artist,
                    license: candidate.license,
                    sourceURL: candidate.sourceURL,
                    sha1: candidate.sha1,
                    fileName: fileName,
                    savedAt: Date()
                ))
                added[slot, default: 0] += 1
            }
            if Task.isCancelled { break }
            if category.mystery == mystery, !incoming.isEmpty, generation == refreshGeneration {
                publish(incoming)
                if let mystery, incoming.contains(where: { $0.mystery == mystery }) {
                    loadingMysteries.remove(mystery)
                }
            }
        }
        guard generation == refreshGeneration else { return }
        if sawCatalog {
            publish(incoming)
            status = incoming.isEmpty
                ? "The paintings in the app are showing."
                : "Sacred art refreshed from Wikimedia Commons."
        } else if !Task.isCancelled {
            status = "Couldn't reach Wikimedia Commons. The paintings in the app are still here."
        }
        loadingMysteries.removeAll()
        revision += 1
    }

    private func publish(_ incoming: [SacredArtRecord]) {
        index = index.merging(incoming, now: Date())
        try? store.save(index)
        revision += 1
    }

    private func fetch(_ url: URL) async -> Data? {
        var request = URLRequest(url: url, timeoutInterval: 25)
        request.setValue(CommonsArtRequest.userAgent, forHTTPHeaderField: "User-Agent")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return nil }
            return data
        } catch {
            return nil
        }
    }
}
#endif
