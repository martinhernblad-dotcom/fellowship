import Foundation
import LinkPresentation
import UIKit
import CryptoKit

@MainActor
final class LinkPreviewService: ObservableObject {
    static let shared = LinkPreviewService()

    struct Metadata: Codable, Equatable {
        var title: String
        var sourceName: String?
        var thumbnailFilename: String?
    }

    @Published private(set) var cache: [String: Metadata] = [:]
    private var inFlight: Set<String> = []

    private init() {
        loadDiskIndex()
    }

    func metadata(for urlString: String) -> Metadata? {
        cache[key(for: urlString)]
    }

    func thumbnail(for urlString: String) -> UIImage? {
        guard let meta = metadata(for: urlString),
              let name = meta.thumbnailFilename else { return nil }
        let path = cacheDir.appendingPathComponent(name)
        guard let data = try? Data(contentsOf: path) else { return nil }
        return UIImage(data: data)
    }

    func fetchIfNeeded(_ urlString: String) {
        let k = key(for: urlString)
        if cache[k] != nil { return }
        if inFlight.contains(k) { return }
        guard let url = URL(string: urlString) else { return }
        inFlight.insert(k)

        let provider = LPMetadataProvider()
        provider.timeout = 8
        provider.startFetchingMetadata(for: url) { [weak self] lp, _ in
            let title  = lp?.title ?? url.host ?? urlString
            let source = LinkPreviewService.sourceLabel(for: url)

            if let imgProvider = lp?.imageProvider {
                imgProvider.loadObject(ofClass: UIImage.self) { obj, _ in
                    let data = (obj as? UIImage)?.jpegData(compressionQuality: 0.75)
                    Task { @MainActor in
                        self?.finalize(k: k, title: title, source: source, imageData: data)
                    }
                }
            } else {
                Task { @MainActor in
                    self?.finalize(k: k, title: title, source: source, imageData: nil)
                }
            }
        }
    }

    private func finalize(k: String, title: String, source: String?, imageData: Data?) {
        inFlight.remove(k)
        var thumbName: String? = nil
        if let imageData {
            let name = "\(k).jpg"
            let path = cacheDir.appendingPathComponent(name)
            if (try? imageData.write(to: path)) != nil {
                thumbName = name
            }
        }
        cache[k] = Metadata(title: title, sourceName: source, thumbnailFilename: thumbName)
        persistDiskIndex()
    }

    nonisolated static func sourceLabel(for url: URL) -> String? {
        let host = url.host?.lowercased() ?? ""
        if host.contains("youtube.com") || host.contains("youtu.be") { return "YouTube" }
        if host.contains("instagram.com") { return "Instagram" }
        if host.contains("tiktok.com")    { return "TikTok" }
        if host.contains("twitter.com") || host.contains("x.com") { return "X" }
        if host.contains("vimeo.com")     { return "Vimeo" }
        let clean = host.replacingOccurrences(of: "www.", with: "")
        return clean.isEmpty ? nil : clean
    }

    private func key(for urlString: String) -> String {
        let digest = SHA256.hash(data: Data(urlString.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private var cacheDir: URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LinkPreviews", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    private var indexURL: URL { cacheDir.appendingPathComponent("index.json") }

    private func loadDiskIndex() {
        guard let data = try? Data(contentsOf: indexURL),
              let decoded = try? JSONDecoder().decode([String: Metadata].self, from: data)
        else { return }
        cache = decoded
    }

    private func persistDiskIndex() {
        guard let data = try? JSONEncoder().encode(cache) else { return }
        try? data.write(to: indexURL)
    }
}

// MARK: - URL detection helper

enum LinkDetector {
    static func extractURL(from text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        guard let detector = try? NSDataDetector(
            types: NSTextCheckingResult.CheckingType.link.rawValue) else { return nil }
        let range = NSRange(trimmed.startIndex..., in: trimmed)
        guard let match = detector.firstMatch(in: trimmed, options: [], range: range),
              match.range.length == (trimmed as NSString).length,
              let url = match.url else { return nil }
        return url
    }
}
