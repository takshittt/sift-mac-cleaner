# Sift

Sift is a native Mac app that finds the junk that piles up on a Mac over time, explains each item in plain language, and lets you clear it out safely to free up storage space.

It needs macOS 14 (Sonoma) or newer on an Apple Silicon Mac. It works offline, needs no account, and never runs in the background.

## What it does

1. **Asks what you use your Mac for.** Everyday use, software development, or AI and machine learning. Sift suggests these from what is installed. Only the areas you switch on are scanned.
2. **Scans** the known places where caches, logs, leftovers from deleted apps, old installers, large files, build data and AI models pile up, and adds up their sizes.
3. **Labels everything by how safe it is to remove:**
   - 🟢 **Safe:** rebuilt automatically. Nothing of yours is lost. Ticked for you.
   - 🟡 **Caution:** safe, but you may need to re-download, rebuild or sign in again.
   - 🔴 **Review:** may contain your own data. Never ticked for you.
4. **Cleans what you choose,** then shows a short report of what was removed and how much space you got back.

Some places are never touched, whatever you select: Documents, Photos, iCloud Drive, Keychain, Mail, Messages, Contacts, Calendars and Safari data. Nothing outside your home folder is removed, and files of apps that are open are left alone. See **How Sift keeps you safe** in the sidebar or in Settings.

## Grant Full Disk Access (optional)

macOS hides some folders (Safari data, Mail downloads, iPhone and iPad backups, some app containers) unless an app has Full Disk Access. Sift works without it and tells you what it can't see.

To give Sift a complete view:

1. Click **Open Settings** on the banner in Sift, or open **System Settings › Privacy & Security › Full Disk Access**.
2. Switch on **Sift**. If it isn't listed, click **+** and choose Sift from Applications.
3. Back in Sift, click **Scan Again**.

## How to undo

What happens to removed files depends on **Settings › General › Deletion mode**:

- **Smart (recommended):** caches and logs that rebuild themselves are deleted right away, because moving them to the Trash would free no space. Everything else goes to the **Trash**.
- **Always move to Trash:** everything goes to the Trash. Space is freed when you empty it.
- **Always delete permanently:** everything is deleted at once and can't be recovered.

To get something back, open the **Trash** in the Dock, select the item and choose **File › Put Back**. Emptying the Trash in Sift is always permanent.

## Building from source

Requires the Xcode Command Line Tools (Swift 6). Full Xcode isn't needed.

```sh
swift test                  # unit and wiring tests (never touch your real home folder)
scripts/build-app.sh        # build/Sift.app, ad-hoc signed for this Mac
scripts/smoke-test.sh       # launches the app on fake data: scan → clean → report
swift run sift-cli -v       # read-only: prints what a scan of your Mac would find
open build/Sift.app --args --fake   # the app on sample data, nothing on disk is touched
```

With only the Command Line Tools, `swift test` sometimes fails to compile with "plugin for module 'TestingMacros' not found". That's a toolchain hiccup; run it again (`swift test -j 1` fails less often).

### Releasing

`scripts/release.sh` signs the app with a Developer ID (hardened runtime, no sandbox), packages `build/Sift-<version>.dmg`, notarizes and staples it:

```sh
xcrun notarytool store-credentials sift-notary --apple-id you@example.com --team-id TEAMID   # once
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" NOTARY_PROFILE=sift-notary scripts/release.sh
```

Without those variables it still builds the DMG, but with an ad-hoc signed app that Gatekeeper warns about on other Macs.

To change the app icon, edit and rerun `swift scripts/make-icon.swift`.

## Website

`frontend/` is the download website (Vite + React + TypeScript + Tailwind v4, static, for GitHub Pages). Its planning docs are in [frontend/docs/](frontend/docs/). Run `npm install`, then `npm run dev` or `npm run build` from inside `frontend/`. Its copy mirrors this README and [docs/intent.md](docs/intent.md), so update both when areas, safety rules or install steps change.

## Documentation

- [docs/intent.md](docs/intent.md): what Sift is for and the safety rules
- [docs/spec.md](docs/spec.md): architecture, rules, algorithms
- [docs/plan.md](docs/plan.md): build milestones and their status
