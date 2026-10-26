import Foundation

// Spec §7.5: local AI models and caches, profile `.localAI`.

extension RuleCatalog {
    public static let localAI: [Rule] = [
        Rule(id: "ollamaModels", title: "Ollama Models",
             subtitle: "Each downloaded model with the files only it uses. Pull it again with `ollama pull`.",
             symbol: "cube", section: .localAI, profile: .localAI, risk: .review,
             owner: OwnerApp("Ollama", "com.electron.ollama"),
             finder: OllamaModelFinder()),

        Rule(id: "lmStudioModels", title: "LM Studio Models",
             subtitle: "Models downloaded through LM Studio.",
             symbol: "cpu", section: .localAI, profile: .localAI, risk: .review,
             owner: OwnerApp("LM Studio", "ai.elementlabs.lmstudio"),
             finder: PathFinder([
                .init(".lmstudio/models/*", .children, groupByFolder: true),
                .init(".cache/lm-studio/models/*", .children, groupByFolder: true),
             ])),

        Rule(id: "huggingFace", title: "Hugging Face Cache",
             subtitle: "Models and datasets cached by transformers, diffusers and friends. They re-download when a program needs them.",
             symbol: "face.smiling", section: .localAI, profile: .localAI, risk: .caution,
             finder: HuggingFaceFinder()),

        Rule(id: "otherML", title: "Other ML Caches",
             subtitle: "PyTorch hub, Whisper, Keras and similar download caches.",
             symbol: "brain", section: .localAI, profile: .localAI, risk: .caution,
             finder: PathFinder([
                .init(".cache/torch", .itself, name: "PyTorch cache"),
                .init(".cache/whisper", .itself, name: "Whisper models"),
                .init(".cache/clip", .itself, name: "CLIP models"),
                .init(".keras/datasets", .itself, name: "Keras datasets"),
                .init(".keras/models", .itself, name: "Keras models"),
             ])),
    ]
}
