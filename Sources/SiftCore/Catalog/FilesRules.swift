import Foundation

// Spec §7.3: the user's own forgotten files, profile `.general`.
// None is ever preselected. Passes keep one file from being listed under two rules:
// installers first, then large files, then whatever old downloads remain.

extension RuleCatalog {
    static let installerExtensions: Set<String> = ["dmg", "pkg", "mpkg", "iso", "xip"]
    static let largeFileBytes: Int64 = 500_000_000
    static let oldDownloadDays = 90

    public static let files: [Rule] = [
        Rule(id: "installers", title: "Old Installers",
             subtitle: "Disk images and installer packages (.dmg, .pkg, .iso, .xip) in Downloads and Desktop.",
             symbol: "archivebox", section: .files, profile: .general, risk: .caution,
             finder: FileSearchFinder(roots: ["Downloads", "Desktop"], maxDepth: 3) { url, _, _ in
                 installerExtensions.contains(url.pathExtension.lowercased())
                     ? Candidate(url: url, detail: url.pathExtension.lowercased() == "dmg" ? "Disk image" : "Installer")
                     : nil
             }),

        Rule(id: "deviceBackups", title: "iOS Device Backups",
             subtitle: "Local device backups made by Finder. Delete only if the device is backed up elsewhere (e.g. iCloud).",
             symbol: "iphone", section: .files, profile: .general, risk: .review, needsFDA: true,
             safetyExceptions: [DeviceBackupFinder.folder],
             finder: DeviceBackupFinder()),

        Rule(id: "largeFiles", title: "Large Files",
             subtitle: "Files over 500 MB in Downloads, Desktop, Documents and Movies, so you can spot forgotten videos, disk images and archives.",
             symbol: "doc.zipper", section: .files, profile: .general, risk: .review,
             safetyExceptions: ["Documents"], pass: 1,
             finder: FileSearchFinder(roots: ["Downloads", "Desktop", "Documents", "Movies"], maxDepth: 6) { url, values, _ in
                 values.isRegularFile == true && Int64(values.fileSize ?? 0) >= largeFileBytes
                     ? Candidate(url: url, detail: url.deletingLastPathComponent().lastPathComponent)
                     : nil
             }),

        Rule(id: "oldDownloads", title: "Old Downloads",
             subtitle: "Items in Downloads you haven't modified or opened for 90 days.",
             symbol: "clock.arrow.circlepath", section: .files, profile: .general, risk: .review, pass: 2,
             finder: UnusedItemsFinder(folder: "Downloads", days: oldDownloadDays)),
    ]
}
