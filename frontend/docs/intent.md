# What We're Building: the Sift Website

## The short version

A simple, one-page website for **Sift** where anyone can learn what the app does, see that it's safe, and **download it for their Mac in one click**.

## Who it's for

People who found Sift (from a link, a post or a search) because their Mac is running out of space, and want to know:
1. What is this?
2. Will it delete something I need?
3. Will it work on my Mac?
4. How do I get it, and how do I open it?

Most of them are **not developers**. They have never visited a GitHub releases page and shouldn't have to. Many have been burned by "cleaner" apps before, so the site has to earn trust, not hype.

## The problem it solves

Today the only way to get Sift is the GitHub releases page. That page is confusing for normal people: they have to find the **Assets** list, pick the right file, and then work out on their own why macOS blocks the app the first time it opens.

The website replaces that with a clean page, a big **Download for Mac** button, a plain explanation of how Sift keeps your files safe, and plain-language install steps.

## What the website will do

### 1. Explain Sift at a glance
- A headline that says what Sift is: *free up space on your Mac, safely*.
- A picture of the app's Overview screen, so people get it without reading.
- What it cleans: everyday junk, forgotten files, leftovers from deleted apps, programming tools, AI models, and only the areas you use.

### 2. Show that it's safe
- The three labels (Safe, Caution, Review) and which ones are ticked for you.
- The places that are never touched (Documents, Photos, iCloud Drive, Keychain, Mail, Messages, Contacts, Calendars, Safari data).
- The other guardrails: Trash first, open apps left alone, cloud folders flagged, nothing outside your home folder.

### 3. Download in one click
- A big **Download for Mac** button near the top, and again at the bottom.
- The button always downloads **the newest version**, without us editing the website each time we release.
- Next to it: the version number, the file size, and "macOS 14 or newer · Apple silicon · Free".
- If the newest version can't be looked up for some reason, the button still works: it opens the GitHub releases page instead.

### 4. Walk people through installing
The same steps as the README, written for non-technical people:
1. Open the DMG and drag Sift into Applications.
2. Open it the first time (macOS blocks it because it isn't registered with Apple; here's how to click **Open Anyway**).
3. Optionally give it Full Disk Access for a complete scan.

### 5. Answer the usual questions
- Is it free? Could it delete something I need? How do I get something back?
- Why does macOS warn me? Does it need Full Disk Access? Does it send my data anywhere?
- Which Macs? How to update and uninstall. Where to report a bug.

## What it will look like

- **Clean and white**, with lots of space, like a modern Mac app's website. Lavender, chartreuse and tomato, the same palette as the app.
- Works well on phones too (people often find it on their phone first, then download on their Mac).
- Fast. No pop-ups, no cookie banners, no tracking.

## What it won't do (for now)

- No accounts, sign-ups, payments or newsletter.
- No blog or changelog pages. The "What's new" details stay on GitHub.
- No analytics or tracking of any kind.
- No other languages besides English.

## Where it lives

The website is part of the Sift project itself, in the `frontend/` folder, so the app and its website are kept in one place. It's published for free on GitHub Pages.
