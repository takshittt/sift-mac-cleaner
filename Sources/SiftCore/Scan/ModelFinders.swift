import Foundation

/// One item per Ollama model: its manifest plus the blobs only it uses (spec §8.5).
///
/// Blobs shared with another model are never offered, so removing one model
/// can't break another. Unreadable manifests are skipped, never guessed at.
public struct OllamaModelFinder: ItemFinder {
    static let root = ".ollama/models"
    static let defaultRegistry = "registry.ollama.ai"

    public init() {}

    public func candidates(in context: ScanContext) async throws -> FinderResult {
        let models = context.home.appending(path: Self.root)
        let manifestsRoot = models.appending(path: "manifests")
        let blobs = models.appending(path: "blobs")

        var manifests: [(url: URL, name: String, digests: Set<String>)] = []
        let walker = FileManager.default.enumerator(at: manifestsRoot, includingPropertiesForKeys: [.isRegularFileKey],
                                                    options: [.skipsHiddenFiles])
        while let url = walker?.nextObject() as? URL {
            guard (try? url.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true,
                  let digests = Self.digests(in: url)
            else { continue }
            manifests.append((url, Self.modelName(manifest: url, root: manifestsRoot), digests))
        }

        var uses: [String: Int] = [:]
        for manifest in manifests { for digest in manifest.digests { uses[digest, default: 0] += 1 } }

        return FinderResult(manifests.map { manifest in
            let own = manifest.digests.filter { uses[$0] == 1 }.sorted()
            let shared = manifest.digests.count - own.count
            return Candidate(
                url: manifest.url, name: manifest.name,
                detail: shared > 0 ? "Keeps \(shared) file\(shared == 1 ? "" : "s") another model still uses" : "Pull it again with `ollama pull \(manifest.name)`",
                additionalURLs: own.map { blobs.appending(path: $0.replacingOccurrences(of: ":", with: "-")) })
        })
    }

    /// Every `sha256:…` digest a manifest refers to, or nil if it isn't a readable manifest.
    static func digests(in manifest: URL) -> Set<String>? {
        guard let data = try? Data(contentsOf: manifest),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        var digests = Set<String>()
        if let config = json["config"] as? [String: Any], let d = config["digest"] as? String { digests.insert(d) }
        for layer in json["layers"] as? [[String: Any]] ?? [] {
            if let d = layer["digest"] as? String { digests.insert(d) }
        }
        let valid = digests.filter { $0.hasPrefix("sha256:") && $0.count == 71 && !$0.contains("/") }
        return valid.isEmpty || valid.count != digests.count ? nil : valid
    }

    /// `manifests/registry.ollama.ai/library/llama3.1/8b` → `llama3.1:8b`;
    /// other namespaces and registries keep their prefix (`user/model:tag`).
    static func modelName(manifest: URL, root: URL) -> String {
        let rootParts = root.standardizedFileURL.pathComponents
        var parts = Array(manifest.standardizedFileURL.pathComponents.dropFirst(rootParts.count))
        guard parts.count >= 2 else { return manifest.lastPathComponent }
        let tag = parts.removeLast()
        if parts.first == defaultRegistry { parts.removeFirst() }
        if parts.first == "library", parts.count == 2 { parts.removeFirst() }
        return parts.joined(separator: "/") + ":" + tag
    }
}

/// Hugging Face hub cache: one item per downloaded model, dataset or space.
public struct HuggingFaceFinder: ItemFinder {
    static let hub = ".cache/huggingface/hub"
    static let legacy = ".cache/huggingface/transformers"

    public init() {}

    public func candidates(in context: ScanContext) async throws -> FinderResult {
        var result = FinderResult()
        let hub = context.home.appending(path: Self.hub)
        let entries = (try? FileManager.default.contentsOfDirectory(at: hub, includingPropertiesForKeys: nil)) ?? []
        for entry in entries {
            let parts = entry.lastPathComponent.components(separatedBy: "--")
            let groups = ["models": "Models", "datasets": "Datasets", "spaces": "Spaces"]
            guard parts.count >= 2, let group = groups[parts[0]] else { continue }
            result.candidates.append(Candidate(url: entry, name: parts.dropFirst().joined(separator: "/"), group: group))
        }
        let legacy = context.home.appending(path: Self.legacy)
        if PathFinder.exists(legacy) {
            result.candidates.append(Candidate(url: legacy, name: "Transformers (legacy)"))
        }
        return result
    }
}
