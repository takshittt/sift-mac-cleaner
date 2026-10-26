import Foundation

/// An app Sift knows by name: used to detect profiles and to protect folders
/// that hold the user's own files (synced folders, models, games).
public struct KnownApp: Sendable {
    public let name: String
    public let bundleIDs: [String]
    /// App names without `.app`, lowercased.
    public let appFileNames: [String]
    /// Absolute paths of command-line tools that show the app is used.
    public let bins: [String]
    /// Home-relative paths whose presence shows the app is used.
    public let evidence: [String]
    public let profile: Profile?
    /// Home-relative folders that may hold the user's own files.
    /// Anything inside is raised to Review and never preselected.
    public let userData: [String]

    public init(_ name: String, ids: [String] = [], files: [String] = [], bins: [String] = [],
                evidence: [String] = [], profile: Profile? = nil, userData: [String] = []) {
        self.name = name
        self.bundleIDs = ids.map { $0.lowercased() }
        self.appFileNames = files.map { $0.lowercased() }
        self.bins = bins
        self.evidence = evidence
        self.profile = profile
        self.userData = userData
    }

    func isInstalled(in apps: AppSnapshot, home: URL, exists: (String) -> Bool) -> Bool {
        bundleIDs.contains { apps.installedIDs.contains($0) }
            || appFileNames.contains { apps.installedNames.contains($0) }
            || bins.contains(where: exists)
            || evidence.contains { exists(home.appending(path: $0).path(percentEncoded: false)) }
    }
}

public enum KnownApps {
    public static let all: [KnownApp] = [
        // Developer
        KnownApp("Xcode", ids: ["com.apple.dt.Xcode"], evidence: ["Library/Developer/Xcode"], profile: .developer),
        KnownApp("Visual Studio Code", ids: ["com.microsoft.VSCode"], files: ["visual studio code"],
                 bins: ["/opt/homebrew/bin/code", "/usr/local/bin/code"], evidence: [".vscode"], profile: .developer),
        KnownApp("Cursor", ids: ["com.todesktop.230313mzl4w4u92"], files: ["cursor"], evidence: [".cursor"], profile: .developer),
        KnownApp("Android Studio", ids: ["com.google.android.studio"], files: ["android studio"],
                 evidence: [".android", "Library/Android"], profile: .developer),
        KnownApp("Docker", ids: ["com.docker.docker"], files: ["docker"], evidence: [".docker"], profile: .developer,
                 userData: ["Library/Containers/com.docker.docker", "Library/Group Containers/group.com.docker"]),
        KnownApp("Postman", ids: ["com.postmanlabs.mac"], files: ["postman"], profile: .developer),
        KnownApp("Homebrew", bins: ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"], profile: .developer),
        KnownApp("Node.js", evidence: [".npm", ".nvm", ".bun"], profile: .developer),
        KnownApp("Rust", evidence: [".cargo"], profile: .developer),
        KnownApp("Gradle / Maven", evidence: [".gradle", ".m2"], profile: .developer),

        // Local AI
        KnownApp("Ollama", ids: ["com.electron.ollama"], files: ["ollama"],
                 bins: ["/opt/homebrew/bin/ollama", "/usr/local/bin/ollama"], evidence: [".ollama"], profile: .localAI,
                 userData: [".ollama"]),
        KnownApp("LM Studio", ids: ["ai.elementlabs.lmstudio"], files: ["lm studio"],
                 evidence: [".lmstudio", ".cache/lm-studio"], profile: .localAI,
                 userData: [".lmstudio", "Library/Application Support/LM Studio"]),
        KnownApp("Jan", ids: ["jan.ai.app"], files: ["jan"], evidence: ["Library/Application Support/Jan"],
                 profile: .localAI, userData: ["Library/Application Support/Jan"]),
        KnownApp("GPT4All", files: ["gpt4all"], evidence: ["Library/Application Support/nomic.ai"],
                 profile: .localAI, userData: ["Library/Application Support/nomic.ai"]),
        KnownApp("Hugging Face", evidence: [".cache/huggingface"], profile: .localAI),

        // Everyday apps whose folders hold the user's own files
        KnownApp("Dropbox", ids: ["com.getdropbox.dropbox"], files: ["dropbox"],
                 userData: ["Dropbox", ".dropbox", "Library/Dropbox", "Library/Application Support/Dropbox"]),
        KnownApp("OneDrive", ids: ["com.microsoft.OneDrive", "com.microsoft.OneDrive-mac"], files: ["onedrive"],
                 userData: ["Library/Containers/com.microsoft.OneDrive-mac", "Library/Application Support/OneDrive"]),
        KnownApp("Google Drive", ids: ["com.google.drivefs"], files: ["google drive"],
                 userData: ["Library/Application Support/Google/DriveFS"]),
        KnownApp("Steam", ids: ["com.valvesoftware.steam"], files: ["steam"],
                 userData: ["Library/Application Support/Steam"]),
        KnownApp("Slack", ids: ["com.tinyspeck.slackmacgap"], files: ["slack"]),
        KnownApp("Discord", ids: ["com.hnc.Discord"], files: ["discord"]),
        KnownApp("Microsoft Teams", ids: ["com.microsoft.teams2", "com.microsoft.teams"], files: ["microsoft teams"]),
        KnownApp("Zoom", ids: ["us.zoom.xos"], files: ["zoom.us"]),
        KnownApp("Notion", ids: ["notion.id"], files: ["notion"]),
        KnownApp("Spotify", ids: ["com.spotify.client"], files: ["spotify"]),
        KnownApp("ChatGPT", ids: ["com.openai.chat"], files: ["chatgpt"]),
        KnownApp("Google Chrome", ids: ["com.google.Chrome"], files: ["google chrome"]),
        KnownApp("Firefox", ids: ["org.mozilla.firefox"], files: ["firefox"]),
    ]

    /// Home-relative folders of every known app that may hold the user's own files.
    public static var userDataPaths: [String] { all.flatMap(\.userData) }
}

/// Suggests profiles from what's installed. Everyday use is always on.
public enum ProfileDetector {
    public static func detect(apps: AppSnapshot, home: URL,
                              exists: (String) -> Bool = { FileManager.default.fileExists(atPath: $0) }) -> Set<Profile> {
        var profiles: Set<Profile> = [.general]
        for app in KnownApps.all {
            if let profile = app.profile, !profiles.contains(profile),
               app.isInstalled(in: apps, home: home, exists: exists) {
                profiles.insert(profile)
            }
        }
        return profiles
    }
}
