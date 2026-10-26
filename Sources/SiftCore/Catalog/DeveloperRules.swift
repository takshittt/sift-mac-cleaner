import Foundation

// Spec §7.4: developer tools, profile `.developer`.

extension RuleCatalog {
    static let xcode = OwnerApp("Xcode", "com.apple.dt.Xcode")
    static let projectRoots = ["Projects", "Developer", "Code", "Coding", "GitHub", "repos", "workspace",
                               "Documents", "Desktop"]
    static let staleProjectDays = 60

    public static let developer: [Rule] = [
        Rule(id: "xcodeDerivedData", title: "Xcode Build Data",
             subtitle: "DerivedData and Xcode caches. Rebuilt on the next build.",
             symbol: "hammer", section: .developer, profile: .developer, risk: .safe, owner: xcode,
             finder: PathFinder([
                .init("Library/Developer/Xcode/DerivedData", .children, group: "DerivedData"),
                .init("Library/Caches/com.apple.dt.Xcode", .itself, name: "Xcode cache"),
             ])),

        Rule(id: "simulatorCache", title: "Simulator Caches",
             subtitle: "Caches the iOS Simulator rebuilds when it next starts.",
             symbol: "iphone.gen3", section: .developer, profile: .developer, risk: .safe,
             owner: OwnerApp("Simulator", "com.apple.iphonesimulator", "com.apple.dt.Xcode"),
             finder: PathFinder(children: "Library/Developer/CoreSimulator/Caches")),

        Rule(id: "deviceSupport", title: "iOS / watchOS Device Support",
             subtitle: "Debug symbols copied from devices you connected. Re-created the next time you plug the device in.",
             symbol: "cable.connector", section: .developer, profile: .developer, risk: .caution, owner: xcode,
             finder: PathFinder([
                .init("Library/Developer/Xcode/iOS DeviceSupport", .children, group: "iOS"),
                .init("Library/Developer/Xcode/watchOS DeviceSupport", .children, group: "watchOS"),
                .init("Library/Developer/Xcode/tvOS DeviceSupport", .children, group: "tvOS"),
                .init("Library/Developer/Xcode/visionOS DeviceSupport", .children, group: "visionOS"),
             ])),

        Rule(id: "xcodeArchives", title: "Xcode Archives",
             subtitle: "Archived app builds. Keep any you may still need to symbolicate or re-submit.",
             symbol: "archivebox", section: .developer, profile: .developer, risk: .review, owner: xcode,
             finder: PathFinder([.init("Library/Developer/Xcode/Archives/*", .children)])),

        Rule(id: "pkgCaches", title: "Package Manager Caches",
             subtitle: "Downloads cached by npm, Yarn, pip, Homebrew, Cargo, Go and others. They re-download when needed.",
             symbol: "shippingbox", section: .developer, profile: .developer, risk: .safe,
             finder: PathFinder([
                .init(".npm/_cacache", .itself, name: "npm cache"),
                .init("Library/Caches/Yarn", .itself, name: "Yarn cache"),
                .init("Library/Caches/pnpm", .itself, name: "pnpm cache"),
                .init("Library/pnpm/store", .itself, name: "pnpm store",
                      detail: "Projects re-link on next install", risk: .caution),
                .init(".bun/install/cache", .itself, name: "Bun cache"),
                .init("Library/Caches/pip", .itself, name: "pip cache"),
                .init(".cache/uv", .itself, name: "uv cache"),
                .init("Library/Caches/Homebrew", .itself, name: "Homebrew downloads"),
                .init(".cargo/registry/cache", .itself, name: "Cargo downloads"),
                .init("Library/Caches/go-build", .itself, name: "Go build cache"),
                .init("Library/Caches/CocoaPods", .itself, name: "CocoaPods cache"),
                .init(".composer/cache", .itself, name: "Composer cache"),
                .init("Library/Caches/composer", .itself, name: "Composer cache"),
                .init("Library/Caches/org.swift.swiftpm", .itself, name: "SwiftPM cache"),
                .init(".gradle/caches", .itself, name: "Gradle caches",
                      detail: "Offline builds need a re-download", risk: .caution),
                .init(".m2/repository", .itself, name: "Maven repository",
                      detail: "Offline builds need a re-download", risk: .caution),
             ])),

        Rule(id: "staleNodeModules", title: "Stale node_modules",
             subtitle: "node_modules folders in projects you haven't touched for two months. `npm install` brings them back.",
             symbol: "cube.transparent", section: .developer, profile: .developer, risk: .caution,
             safetyExceptions: ["Documents"],
             finder: StaleNodeModulesFinder(roots: projectRoots, days: staleProjectDays)),
    ]
}
