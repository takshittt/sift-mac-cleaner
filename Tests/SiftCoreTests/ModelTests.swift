import Foundation
import Testing
@testable import SiftCore

@Suite struct ModelTests {
    let rule = Rule(id: "r", title: "R", subtitle: "", symbol: "trash", section: .junk,
                    profile: .general, risk: .caution, finder: StaticFinder())

    @Test func riskOrdering() {
        #expect(Risk.safe < .caution)
        #expect(Risk.caution < .review)
    }

    @Test func candidateCanRaiseButNotLowerRisk() {
        let url = URL(filePath: "/Users/x/Library/Caches/a")
        #expect(CleanItem(rule: rule, candidate: Candidate(url: url, risk: .review), size: 1).risk == .review)
        #expect(CleanItem(rule: rule, candidate: Candidate(url: url, risk: .safe), size: 1).risk == .caution)
    }

    @Test func ruleDefaults() {
        let safe = Rule(id: "s", title: "", subtitle: "", symbol: "", section: .junk,
                        profile: .general, risk: .safe, finder: StaticFinder())
        #expect(safe.defaultOn && safe.disposal == .permanent)
        #expect(!rule.defaultOn && rule.disposal == .trash)
    }

    @Test @MainActor func settingsPersistAndReset() throws {
        let suite = testDefaultsSuite + ".model"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)

        let store = SettingsStore(defaults: defaults)
        #expect(store.mode == .smart)
        store.mode = .trash
        store.enabledProfiles = [.developer]
        store.lifetimeFreed = 5_000_000_000
        store.ruleOverrides = ["logs": false]

        let reloaded = SettingsStore(defaults: defaults)
        #expect(reloaded.mode == .trash)
        #expect(reloaded.enabledProfiles == [.developer])
        #expect(reloaded.lifetimeFreed == 5_000_000_000)
        #expect(reloaded.ruleOverrides == ["logs": false])

        reloaded.detectedProfiles = [.localAI]
        reloaded.resetToRecommended()
        #expect(reloaded.mode == .smart)
        #expect(reloaded.enabledProfiles == [.general, .localAI])
        #expect(reloaded.ruleOverrides.isEmpty)
    }

    @Test func fakeScannerFiltersByProfile() async throws {
        var rules: [String] = []
        for try await event in FakeScanner().scan(profiles: [.developer]) {
            if case .category(let c) = event { rules.append(c.rule.id) }
        }
        #expect(rules == ["xcodeDerivedData"])
    }
}
