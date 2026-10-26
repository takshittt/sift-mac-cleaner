# What We Are Building: Sift

Status: final (v1, closed 2026-10-26)

## The short version

We are building **Sift**, a native Mac app that finds the junk that piles up on a Mac over time, shows it to you in plain language, and lets you clear it out safely to free up storage space.

---

## The problem it solves

Every Mac slowly fills up with files you never asked for and rarely see:

- **Leftovers from websites and apps.** Browsers and apps save copies of images and pages so they load faster next time. Over months, these copies can grow into gigabytes.
- **Files from apps you already deleted.** When you drag an app to the Trash, its settings and data folders often stay behind.
- **Forgotten downloads.** Old installers, disk images and big files you downloaded once and never opened again.
- **Leftovers from programming tools.** People who write software collect huge folders of temporary build files and downloaded tools.
- **AI models.** People who run AI on their own Mac often have very large model files (sometimes tens of gigabytes each) sitting around.

Most people don't know where these files live, and deleting the wrong thing can break an app or lose personal data. So people either live with a full disk or take risks by deleting things blindly.

**Sift makes this safe and simple.** It knows where the junk lives, explains each item in everyday words, and protects anything that matters.

---

## How it works, from the user's point of view

### 1. It asks what you use your Mac for

When Sift first looks at your Mac, it checks which apps you have installed and suggests what kind of user you are:

| Type of use | What it looks at |
|---|---|
| **Everyday use** | Caches, logs, browser leftovers, files from deleted apps |
| **Software development** | Xcode, npm, Homebrew, old project folders |
| **AI and machine learning** | Ollama, LM Studio, Hugging Face models |

You can switch any of these on or off. Only the areas you turn on get checked.

### 2. It scans your Mac

The app looks through the known locations for each kind of junk and adds up how much space each one uses. It shows a storage gauge and a list of categories with their sizes.

### 3. It sorts everything by how safe it is to remove

Each item gets a colored label so you know what you're dealing with:

- 🟢 **Safe.** macOS or the app will rebuild it automatically. Nothing of yours is lost. These are ticked for you.
- 🟡 **Caution.** Safe to remove, but you might need to re-download something, rebuild a project, or sign in again.
- 🔴 **Review.** This might contain your own data. Look through it yourself before removing. These are never ticked for you.

Only the green items are selected by default. Everything else is your decision.

### 4. You choose, then it cleans

You review the list, tick or untick what you want, and press clean. If your choice includes any red "Review" items, the app warns you before going ahead. Afterward it shows a short report of what was removed and how much space you got back. It also keeps a running total of all the space Sift has freed over time.

---

## What it cleans

**Everyday junk**
- App caches: temporary files apps keep so they run faster
- Browser caches for Safari, Chrome, Firefox, Edge, Brave, Arc and Opera (bookmarks, passwords and history are left alone)
- Log files and crash reports
- Mail attachments you opened (the originals stay on the mail server)
- Saved window positions
- Items already in the Trash

**Your own forgotten files** (shown for review, never removed automatically)
- Old installers and disk images (.dmg, .pkg, .iso) in Downloads and Desktop
- Files over 500 MB in Downloads, Desktop, Documents and Movies
- Downloads you haven't opened in 90 days
- Old iPhone/iPad backups saved on the Mac

**Leftovers from deleted apps**
- Settings and data folders whose app can no longer be found anywhere on the Mac
- Startup entries that try to launch programs that no longer exist

**Programming tools**
- Xcode build files, archives, simulator caches and device support files
- Downloaded packages from npm, Yarn, pnpm, pip, Homebrew, Cargo, Go, Gradle, Maven, CocoaPods and others
- `node_modules` folders in projects untouched for two months

**AI models**
- Models downloaded by Ollama and LM Studio
- Hugging Face, PyTorch, Whisper, Keras and similar model caches

---

## Safety rules (the most important part)

Safety matters more than anything else in this app. Freeing space is only useful if nothing important is lost.

1. **Some places are never touched.** Documents, Photos, iCloud Drive, passwords (Keychain), Mail, Messages, Contacts, Calendars and Safari data are blocked. This is built into the app's logic, so it can't be undone by a mistake in a list.
2. **Anything that might be yours goes to the Trash first.** You can still get it back. Only true throwaway files (caches and logs that rebuild themselves) are deleted right away, because moving them to the Trash wouldn't actually free any space.
3. **Open apps are left alone.** If an app is running, its files are not selected, because it is probably using them.
4. **Cloud and sync folders are flagged.** Folders for Dropbox, OneDrive, Google Drive, Docker, games and AI models can hold your own files. They are clearly marked and never pre-selected.
5. **Nothing outside your own user folder is removed,** and the app won't follow shortcuts that point to somewhere else.
6. **It is upfront about what it can't see.** macOS hides some folders unless you give the app "Full Disk Access." The app tells you this and offers a button to open the right setting.

---

## Settings

The user can choose how files are removed:

- **Smart (recommended):** throwaway files are deleted right away, and anything that might matter goes to the Trash.
- **Always move to Trash:** everything goes to the Trash. Space is only freed once you empty it.
- **Always delete permanently:** everything is deleted right away and can't be recovered.

The user can also turn whole areas on or off, and reset everything back to the recommended setup.

---

## What success looks like

Our version is done when:

- It finds the common kinds of junk in the places they usually pile up.
- It labels each item with a clear safety level and explanation.
- It follows every safety rule above, without exception.
- A non-technical person can open it, understand what they're looking at, and free up space without worrying that they'll break something.

## What we are not building

- It doesn't speed up your Mac, scan for viruses, or run in the background.
- It doesn't delete your personal files on its own.
- It doesn't need an internet connection or an account.

