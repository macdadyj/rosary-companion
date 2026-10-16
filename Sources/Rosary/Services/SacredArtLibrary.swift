#if os(iOS)
import Foundation
import Observation
import RosaryCore

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

    func imageData(for mystery: MysteryID, content: PrayerContent?, on day: CivilDate) -> Data? {
        _ = revision
        if let record = index.choice(for: mystery, on: day),
           let data = store.imageData(fileName: record.fileName) {
            return data
        }
        return content?.imageData(for: mystery)
    }

    func creditLine(for mystery: MysteryID, content: PrayerContent?, on day: CivilDate) -> String {
        _ = revision
        if let record = index.choice(for: mystery, on: day),
           store.imageData(fileName: record.fileName) != nil {
            return record.creditLine
        }
        return content?.work(for: mystery)?.creditLine ?? "Mystery artwork"
    }

    /// Hand refresh: show the next cached painting, and ask Commons for more.
    func showAnother(mystery: MysteryID) {
        index = index.advanced(mystery: mystery)
        try? store.save(index)
        revision += 1
        refresh(prioritizing: mystery)
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
