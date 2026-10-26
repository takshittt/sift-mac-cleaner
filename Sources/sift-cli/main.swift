import Foundation
import SiftCore

// Prints what a scan of the current user's home folder finds. Read-only:
// this tool has no code path to the clean engine.
//
//   swift run sift-cli                 # summary per rule
//   swift run sift-cli -v              # also the 5 largest items per rule
//   swift run sift-cli --all          # every item, with its group
//   swift run sift-cli developer,localAI

let args = CommandLine.arguments.dropFirst()
let verbose = args.contains("-v") || args.contains("--all")
let limit = args.contains("--all") ? Int.max : 5
let profiles: Set<Profile> = args.first { !$0.hasPrefix("-") }
    .map { Set($0.split(separator: ",").compactMap { Profile(rawValue: String($0)) }) }
    ?? [.general]

func size(_ bytes: Int64) -> String { ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file) }
func pad(_ s: String, _ n: Int) -> String { s + String(repeating: " ", count: max(1, n - s.count)) }

let detected = await Engine.live().apps.detectProfiles()
print("Detected profiles: \(detected.map(\.title).sorted().joined(separator: ", "))\n")

let started = Date()
var grandTotal: Int64 = 0
var fda = true
print(pad("Rule", 28) + pad("Risk", 9) + pad("Items", 7) + "Size")
for try await event in Engine.live().scanner.scan(profiles: profiles) {
    switch event {
    case .category(let c):
        grandTotal += c.total
        let flag = c.needsFDA ? "  (some items hidden without Full Disk Access)" : ""
        print(pad(c.rule.title, 28) + pad(c.rule.risk.title, 9) + pad("\(c.items.count)", 7) + size(c.total) + flag)
        if verbose {
            for item in c.items.prefix(limit) {
                let note = [item.group, item.detail].compactMap { $0 }.map { "  [\($0)]" }.joined()
                print("    " + pad(size(item.size), 11) + item.url.path(percentEncoded: false) + note)
            }
        }
    case .finished(let access):
        fda = access
    case .progress:
        break
    }
}
print("\nTotal \(size(grandTotal)) in \(String(format: "%.1f", Date().timeIntervalSince(started)))s"
      + (fda ? "" : "  ·  Full Disk Access not granted"))
