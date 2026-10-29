# Technical Spec: the Sift Website

Companion to [intent.md](intent.md), which covers the *what* and *why*. This document covers the *how*. The build order is in [plan.md](plan.md). The stack, layout and design mirror the Strata website, so the two projects' sites stay alike.

---

## 1. Overview

A static, single-page site built with **Vite + React + TypeScript**, styled with **Tailwind CSS v4**. `npm run build` outputs plain HTML/CSS/JS to `frontend/dist/`, which is hosted on **GitHub Pages**. There is no server and no backend.

---

## 2. Tech stack

| Layer | Choice | Why |
|---|---|---|
| Build tool | **Vite 8** | Fast dev server, simple static output, first-class React and Tailwind plugins. |
| UI | **React 19** + **TypeScript** | Components for repeated pieces (feature cards, steps, FAQ items) and one small piece of runtime state (the latest release). |
| Styling | **Tailwind CSS v4** via `@tailwindcss/vite` | No config file; theme tokens live in `src/index.css` under `@theme`. |
| Lint | **oxlint** (from the Vite template) | Fast, zero config. |
| Hosting | **GitHub Pages**, deployed by a GitHub Actions workflow | Free, same repo as the app, no extra accounts. |
| Node | 22 LTS (what's installed locally and pinned in CI) | |

No router, no state library, no UI kit, no icon library (icons are small inline SVGs in `components/icons.tsx`). Only runtime dependencies: `react`, `react-dom`.

---

## 3. Layout

```
frontend/
├─ docs/              # intent.md, spec.md, plan.md
├─ index.html          # <title>, meta description, Open Graph tags, favicon
├─ vite.config.ts      # react() + tailwindcss(), base: './'
├─ public/
│  ├─ icon.png         # 512 px app icon, exported from Support/AppIcon.icns
│  └─ favicon.png      # 64 px
└─ src/
   ├─ main.tsx
   ├─ index.css        # @import "tailwindcss"; @theme tokens
   ├─ App.tsx          # composes the sections in page order
   ├─ release.ts       # useLatestRelease() hook + constants
   └─ components/      # one file per section, plus shared bits
```

The icons are exported with `sips` (see §7). They aren't generated at build time, so CI doesn't need macOS.

---

## 4. Page sections (top to bottom)

| Section | id | Content |
|---|---|---|
| Header | | Icon + "Sift", anchor links (What it cleans, Safety, Install, FAQ), GitHub link, small Download button |
| Hero | `top` | Headline, one-line pitch, **DownloadButton**, release meta line, mock Overview screen |
| Features | `features` | 6 cards: everyday junk, forgotten files, leftovers from deleted apps, programming tools, AI models, profiles |
| Safety | `safety` | The Safe / Caution / Review labels, the never-touched places, the other guardrails |
| Install | `install` | 3 numbered steps; step 2 spells out Privacy & Security → **Open Anyway**; step 3 is optional Full Disk Access |
| FAQ | `faq` | Native `<details>` items: free? could it delete my files? undo, the warning, Full Disk Access, privacy, speed, which Macs, update/uninstall, bugs |
| Final CTA | | Repeat of DownloadButton |
| Footer | | MIT license, GitHub, releases, Issues |

**Source of truth for copy:** the root `README.md` and `docs/intent.md`. The safety labels' wording comes from `SafetyLevel` in `Sources/SiftCore/Model/Kinds.swift`. When areas, safety rules or install steps change in the app, update the site too.

### 4.1 The mock Overview screen
The hero's "screenshot" is HTML + Tailwind, not an image: a window with the sidebar, the lavender "Ready to clean" card with its disk ring (an SVG with a chartreuse arc for what can be freed), the profile chips, the area cards with each area's gradient (the same as `Theme.gradient(for:)` in the app) and the floating Clean bar. The numbers are made up. It stays sharp at any size, never shows anyone's real files, and never goes stale as an image would. It's decorative, so it's marked `aria-hidden`. On phones the sidebar and the fifth card are hidden.

---

## 5. The download button

### 5.1 Where the file comes from
Each GitHub release has one asset named `Sift-<version>.dmg` (built by `scripts/release.sh`). The site finds the newest one at runtime:

```
GET https://api.github.com/repos/takshittt/sift-mac-cleaner/releases/latest
→ tag_name, published_at, assets[] { name, size, browser_download_url }
```

`useLatestRelease()` picks the first asset matching `/^Sift-.+\.dmg$/` and returns `{ version, url, sizeBytes, publishedAt }` or `null`.

### 5.2 Fallback
- The button's `href` **starts as** `https://github.com/takshittt/sift-mac-cleaner/releases/latest` and is swapped for the direct asset URL once the API answers. So the button works before JS loads, if the API is down, and when the unauthenticated rate limit (60 requests/hour per IP) is hit.
- The result is cached in `sessionStorage` (wrapped in try/catch) so moving around the page doesn't refetch.
- While loading, the meta line reads "macOS 14 or newer · Apple silicon · Free". Once loaded it adds "Version 1.0 · 1.9 MB".

### 5.3 Why not a fixed URL
`releases/latest/download/<name>` only works if the asset name is the same every release, and ours includes the version. If we ever ship an unversioned `Sift.dmg` too, the button can use that URL directly and the API call becomes optional.

---

## 6. Design

- **White background**, near-black text (`zinc-900`), muted text `zinc-500`, hairline borders `zinc-200`.
- **Palette** (tokens in `src/index.css` under `@theme`), the same as the app's `Theme`:
  - **Lavender** is the primary colour: buttons (`lavender-600`), links (`lavender-700`), step numbers, tinted section backgrounds (`lavender-50`), the hero and final call-to-action gradients, the "never touched" card.
  - **Chartreuse** is an accent: section labels, the highlight under "safely" in the headline, one in three feature icons, the freeable arc of the disk ring. Only ever a fill under dark text, never text on white.
  - **Tomato** is an accent: FAQ "+" icons, one in three feature icons, the Review dot. Use `tomato-ink` when it has to be text on white.
  - The Safe and Caution dots use Tailwind's `emerald-500` and `amber-400`, matching the app's green and yellow labels.
- System font stack (`-apple-system, BlinkMacSystemFont, "SF Pro", …`), so it looks native on a Mac and loads nothing.
- Max content width ~1100 px, generous vertical spacing; single column on phones, 16 px side gutters, no horizontal scroll.
- Light theme only: the site is intentionally white, like the app, which always runs in light appearance.
- Accessibility: semantic landmarks (`header`, `main`, `section`, `footer`), visible focus rings, colour contrast ≥ 4.5:1, `prefers-reduced-motion` respected. The safety dots are decorative; the label text says the level.

---

## 7. Commands

```bash
cd frontend
npm install
npm run dev        # http://localhost:5173
npm run build      # type-check + build to dist/
npm run preview    # serve dist/ locally
npm run lint

# re-export icons after the app icon changes (macOS only)
sips -s format png -Z 512 ../Support/AppIcon.icns --out public/icon.png
sips -s format png -Z 64  ../Support/AppIcon.icns --out public/favicon.png
```

---

## 8. Hosting and deploy

- **GitHub Pages** from a workflow at `.github/workflows/pages.yml` (repo root, since Actions only reads workflows there).
- Triggers: push to `main` touching `frontend/**`, plus manual `workflow_dispatch`.
- Steps: checkout → setup-node 22 with npm cache → `npm ci` and `npm run build` in `frontend/` → `actions/upload-pages-artifact` (path `frontend/dist`) → `actions/deploy-pages`.
- One-time repo setting: **Settings → Pages → Source: GitHub Actions**.
- URL: `https://takshittt.github.io/sift-mac-cleaner/`. `base: './'` in Vite keeps asset paths relative, so the same build works at that sub-path or at a custom domain later.
- New app releases need **no** website deploy: the button picks them up through the API.

---

## 9. Testing

No unit tests: the only logic is choosing the asset from the API response. Check by hand before each deploy:
- [ ] `npm run build` and `npm run lint` pass
- [ ] Download button downloads the latest `Sift-<ver>.dmg` directly
- [ ] With the network request blocked (DevTools → block `api.github.com`), the button opens the releases page
- [ ] Looks right at 375 px, 768 px and 1440 px wide; no horizontal scroll
- [ ] Safari and Chrome on macOS; Safari on iPhone
- [ ] Tab through the page: every link and button gets a visible focus ring
