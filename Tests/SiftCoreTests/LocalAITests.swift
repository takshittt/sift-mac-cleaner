import Foundation
import Testing
@testable import SiftCore

@Suite struct OllamaTests {
    let home: FakeHome
    init() throws { home = try FakeHome() }

    static func digest(_ c: Character) -> String { "sha256:" + String(repeating: c, count: 64) }
    static func blobName(_ c: Character) -> String { "sha256-" + String(repeating: c, count: 64) }

    /// Writes a manifest and any of its blobs that don't exist yet.
    private func model(_ path: String, config: Character, layers: [Character], blobBytes: Int = 50_000) throws {
        let manifest: [String: Any] = [
            "schemaVersion": 2,
            "config": ["digest": Self.digest(config)],
            "layers": layers.map { ["digest": Self.digest($0), "size": blobBytes] },
        ]
        let data = try JSONSerialization.data(withJSONObject: manifest)
        let url = home.path(".ollama/models/manifests/\(path)")
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url)
        for c in [config] + layers where !home.exists(".ollama/models/blobs/\(Self.blobName(c))") {
            try home.file(".ollama/models/blobs/\(Self.blobName(c))", bytes: blobBytes)
        }
    }

    private func items() async throws -> [String: CleanItem] {
        let category = try #require(try await scan(home, rules: RuleCatalog.localAI, profiles: [.localAI])["ollamaModels"])
        return Dictionary(uniqueKeysWithValues: category.items.map { ($0.name, $0) })
    }

    @Test func namesFollowOllama() throws {
        let root = home.path(".ollama/models/manifests")
        #expect(OllamaModelFinder.modelName(manifest: root.appending(path: "registry.ollama.ai/library/llama3.1/8b"), root: root) == "llama3.1:8b")
        #expect(OllamaModelFinder.modelName(manifest: root.appending(path: "registry.ollama.ai/someone/tuned/latest"), root: root) == "someone/tuned:latest")
        #expect(OllamaModelFinder.modelName(manifest: root.appending(path: "hf.co/org/repo/Q4"), root: root) == "hf.co/org/repo:Q4")
    }

    @Test func sharedBlobsAreNeverOffered() async throws {
        // Two tags of one family share the big weights blob "w".
        try model("registry.ollama.ai/library/llama3.1/8b", config: "a", layers: ["w", "b"])
        try model("registry.ollama.ai/library/llama3.1/8b-instruct", config: "c", layers: ["w", "d"])
        try model("registry.ollama.ai/library/phi3/mini", config: "e", layers: ["f"])

        let found = try await items()
        #expect(Set(found.keys) == ["llama3.1:8b", "llama3.1:8b-instruct", "phi3:mini"])

        let shared = Self.blobName("w")
        for item in found.values {
            #expect(!item.additionalURLs.contains { $0.lastPathComponent == shared })
        }
        #expect(Set(found["llama3.1:8b"]!.additionalURLs.map(\.lastPathComponent)) == [Self.blobName("a"), Self.blobName("b")])
        #expect(found["llama3.1:8b"]?.detail == "Keeps 1 file another model still uses")
        #expect(found["phi3:mini"]?.detail == "Pull it again with `ollama pull phi3:mini`")
        // Size counts the manifest plus its own blobs only.
        #expect(found["phi3:mini"]!.size >= 100_000)
        #expect(found["llama3.1:8b"]!.size < found["phi3:mini"]!.size + 60_000)
    }

    @Test func deletingOneModelLeavesTheOthersWhole() async throws {
        try model("registry.ollama.ai/library/llama3.1/8b", config: "a", layers: ["w", "b"])
        try model("registry.ollama.ai/library/llama3.1/8b-instruct", config: "c", layers: ["w", "d"])
        let target = try #require(try await items()["llama3.1:8b"])

        let report = await CleanEngine(home: home.url).clean([target], mode: .permanent) { _ in }
        #expect(report.deletedCount == 1 && report.failures.isEmpty)

        let blobs = ".ollama/models/blobs/"
        #expect(!home.exists(".ollama/models/manifests/registry.ollama.ai/library/llama3.1/8b"))
        #expect(!home.exists(blobs + Self.blobName("a")) && !home.exists(blobs + Self.blobName("b")))
        // The other model: manifest and every blob it needs, including the shared one.
        #expect(home.exists(".ollama/models/manifests/registry.ollama.ai/library/llama3.1/8b-instruct"))
        for c: Character in ["c", "w", "d"] { #expect(home.exists(blobs + Self.blobName(c))) }
        #expect(try await items().keys.sorted() == ["llama3.1:8b-instruct"])
    }

    @Test func unreadableOrStrangeManifestsAreSkipped() async throws {
        try model("registry.ollama.ai/library/good/latest", config: "a", layers: ["b"])
        try home.file(".ollama/models/manifests/registry.ollama.ai/library/garbage/latest")   // zeros, not JSON
        let evil: [String: Any] = ["config": ["digest": "sha256:../../../../Documents"], "layers": []]
        let url = home.path(".ollama/models/manifests/registry.ollama.ai/library/evil/latest")
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONSerialization.data(withJSONObject: evil).write(to: url)

        #expect(try await items().keys.sorted() == ["good:latest"])
    }

    @Test func runningOllamaUnticksModels() async throws {
        try model("registry.ollama.ai/library/phi3/mini", config: "a", layers: ["b"])
        let category = try #require(try await scan(home, rules: RuleCatalog.localAI, profiles: [.localAI],
                                                   running: ["com.electron.ollama"])["ollamaModels"])
        #expect(category.items.allSatisfy { $0.isRunningApp && $0.detail == "Ollama is running" })
    }
}

@Suite struct ModelCacheTests {
    let home: FakeHome
    init() throws { home = try FakeHome() }

    private func scanAI() async throws -> [String: CleanCategory] {
        try await scan(home, rules: RuleCatalog.localAI, profiles: [.localAI])
    }

    @Test func lmStudioModelsGroupedByPublisher() async throws {
        try home.file(".lmstudio/models/lmstudio-community/Qwen2.5-7B-GGUF/model.gguf", bytes: 20_000)
        try home.file(".lmstudio/models/bartowski/Llama-3.2-3B-GGUF/model.gguf", bytes: 20_000)
        try home.file(".cache/lm-studio/models/TheBloke/old-model/model.gguf", bytes: 20_000)
        let items = try #require(try await scanAI()["lmStudioModels"]).items
        #expect(Set(items.map { "\($0.group ?? "")/\($0.name)" }) ==
                ["lmstudio-community/Qwen2.5-7B-GGUF", "bartowski/Llama-3.2-3B-GGUF", "TheBloke/old-model"])
        #expect(items.allSatisfy { $0.risk == .review })
    }

    @Test func huggingFaceItemsAreNamedLikeTheHub() async throws {
        try home.file(".cache/huggingface/hub/models--meta-llama--Llama-3.2-1B/blobs/x", bytes: 20_000)
        try home.file(".cache/huggingface/hub/datasets--squad/blobs/x", bytes: 20_000)
        try home.file(".cache/huggingface/hub/version.txt", bytes: 20_000)
        try home.file(".cache/huggingface/hub/.locks/x", bytes: 20_000)
        try home.file(".cache/huggingface/transformers/x", bytes: 20_000)
        try home.file(".cache/huggingface/token", bytes: 20_000)   // login token: never offered
        let items = try #require(try await scanAI()["huggingFace"]).items
        #expect(Set(items.map(\.name)) == ["meta-llama/Llama-3.2-1B", "squad", "Transformers (legacy)"])
        #expect(items.first { $0.name == "squad" }?.group == "Datasets")
    }

    @Test func otherMLCachesKeepKerasSettings() async throws {
        try home.file(".cache/torch/hub/x", bytes: 20_000)
        try home.file(".cache/whisper/base.pt", bytes: 20_000)
        try home.file(".keras/models/resnet.h5", bytes: 20_000)
        try home.file(".keras/keras.json", bytes: 20_000)
        let category = try #require(try await scanAI()["otherML"])
        #expect(category.names == ["PyTorch cache", "Whisper models", "Keras models"])
    }
}

@Suite struct MultiFileItemTests {
    let home: FakeHome
    init() throws { home = try FakeHome() }

    @Test func oneUnsafeFileBlocksTheWholeItem() async throws {
        try home.file(".ollama/models/manifests/m")
        try home.file(".ollama/models/blobs/b")
        try home.file("Library/Keychains/login.keychain-db")
        let item = CleanItem(ruleID: "t", url: home.path(".ollama/models/manifests/m"), size: 1, risk: .review,
                             disposal: .trash, additionalURLs: [home.path(".ollama/models/blobs/b"),
                                                                 home.path("Library/Keychains/login.keychain-db")])
        let report = await CleanEngine(home: home.url).clean([item], mode: .permanent) { _ in }
        #expect(report.failures.first?.message == Violation.protected.message)
        #expect(home.exists(".ollama/models/manifests/m") && home.exists(".ollama/models/blobs/b"))
        #expect(home.exists("Library/Keychains/login.keychain-db"))
    }
}
