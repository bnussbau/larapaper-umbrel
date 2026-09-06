# LaraPaper — Umbrel App Store package

This repository packages **[LaraPaper](https://github.com/usetrmnl/larapaper)** for the
official [Umbrel App Store](https://github.com/getumbrel/umbrel-apps), and **auto-submits
every new upstream release** as a pull request to `getumbrel/umbrel-apps`.

LaraPaper is a self-hosted TRMNL BYOS ("Bring Your Own Server") for e-ink dashboards:
your TRMNL / TRMNL-compatible screens poll this server for images instead of the TRMNL
cloud.

- **Developer:** [usetrmnl/larapaper](https://github.com/usetrmnl/larapaper) (MIT)
- **Umbrel packaging:** [arquiguru](https://github.com/arquiguru)

---

## Repository layout

```
larapaper-umbrel/
├── usetrmnl-larapaper/                     ← the umbrel-apps package (this folder IS the PR content)
│   ├── umbrel-app.yml             ← manifest (gallery: [] and no `icon:` per official-store rules)
│   ├── docker-compose.yml         ← app_proxy + server, image digest-pinned
│   ├── exports.sh                 ← derives a unique, stable per-install Laravel APP_KEY
│   └── hooks/pre-start            ← chowns the SQLite/PNG data dirs to www-data (82:82)
├── .github/workflows/
│   ├── submit-to-umbrel.yml       ← the release watcher → opens the version-bump PR
│   └── lint.yml                   ← fast pre-flight validation on push/PR
├── assets/
│   └── icon.svg                   ← icon to hand to Umbrel (NOT committed into usetrmnl-larapaper/)
├── docs/NOTES.md                  ← packaging design decisions (APP_KEY, APP_URL, volumes)
├── LICENSE                        ← MIT (matches LaraPaper)
└── README.md
```

The `usetrmnl-larapaper/` folder is exactly what lands in `getumbrel/umbrel-apps/larapaper/`.

---

## How the auto-submit works

`.github/workflows/submit-to-umbrel.yml` runs **daily** (and on demand via
**"Run workflow"**). Each run:

1. **Resolves the target version** — the latest *stable* GitHub release of
   `usetrmnl/larapaper`, hard-guarded to a strict `X.Y.Z` so betas/nightlies never ship.
2. **Resolves the image digest** — the multi-arch OCI index digest for
   `ghcr.io/usetrmnl/larapaper:<version>` (via `docker buildx imagetools inspect`), and
   asserts both `linux/amd64` and `linux/arm64` exist (Umbrel requires both).
3. **Compares** against the version currently published on `umbrel-apps:master`.
4. If the target is **strictly newer**, it bumps `version`, pins
   `image: …:<version>@sha256:<digest>`, refreshes `releaseNotes`, and **opens a PR** to
   `getumbrel/umbrel-apps` (base `master`).

The PR is opened **fork → upstream**: it pushes the branch to *your fork* of umbrel-apps
and opens the PR against `getumbrel/umbrel-apps`. If you already have an open PR there
touching this package, re-runs **push the bump to that PR's branch** instead of opening a
second one (so the first-submission PR simply tracks the latest stable release while it is
under review); otherwise the branch is named `usetrmnl-larapaper-<version>`. Once merged, the
"already published" check stops it from re-opening.

### One-time setup the repo owner must do

1. **Fork `getumbrel/umbrel-apps`** under your account (`FORK_OWNER/umbrel-apps`). One click
   at https://github.com/getumbrel/umbrel-apps. The workflow pushes its PR branches there.
   (If your token is a **classic PAT** with the `repo` scope, the workflow will also try to
   create this fork for you automatically. A **fine-grained PAT cannot fork a repo you don't
   own**, so with one of those you must fork by hand, which is why it's listed as step 1.)
2. **Create a Personal Access Token** that can push to your fork *and* open PRs on
   `getumbrel/umbrel-apps`:
   - **Classic PAT** with the `public_repo` scope (`repo` also works). Create it at
     https://github.com/settings/tokens → *Tokens (classic)* → *Generate new token*.

   > **Why not a fine-grained PAT?** A fine-grained token can push to *your* fork, but it
   > cannot open a pull request on `getumbrel/umbrel-apps` because that is not a repo you
   > can grant it access to. The run then dies at the last step with
   > `Resource not accessible by personal access token`. Classic tokens with `public_repo`
   > are allowed to open PRs on any public repo, which is exactly what the fork → upstream
   > flow needs.

   Add it as a repository **Actions secret** named `UMBREL_APPS_TOKEN`
   (*Settings → Secrets and variables → Actions → New repository secret*).
3. **Add an Actions variable** `FORK_OWNER` = your GitHub login (e.g. `bnussbau`)
   (*Settings → Secrets and variables → Actions → Variables → New repository variable*).

That is the entire setup. No secrets live in this repo.

Until those two are set, the scheduled run **skips the PR steps and finishes green**
with a notice (it still checks upstream for a new release), so you won't get a daily
failure email before you've configured it.

### Manual submit

Actions → **"Submit LaraPaper update to Umbrel App Store"** → **Run workflow**. Leave
*version* blank to take the latest stable, or type a specific `X.Y.Z` to force it.

### Alternative considered: Renovate

Renovate can bump the pinned digest/tag *within this repo*, but it does **not** open
cross-repo PRs into `getumbrel/umbrel-apps`. A release-triggered Action that pushes to
your fork and opens the upstream PR is the correct tool for the "auto-submit to the store"
job, so that is the default here. Renovate remains a fine optional add-on if you also want
this repo's own pin kept fresh.

---

## Packaging details worth knowing

- **Per-install `APP_KEY`** — `exports.sh` derives a Laravel `APP_KEY` from Umbrel's
  per-app seed (`derive_entropy`), so every install gets a **unique but stable** key
  instead of the image's shared baked-in one. Stable = SQLite encrypted columns and signed
  cookies keep working across restarts/updates; unique = no two installs share a signing
  key. Zero first-run CLI. Full rationale in [`docs/NOTES.md`](docs/NOTES.md).
- **A narrow `PROXY_AUTH_WHITELIST`** on `app_proxy` — devices and webhook publishers reach
  LaraPaper without a browser session, so only those exact routes bypass Umbrel's auth proxy:
  the device firmware protocol (`/api/setup`, `/api/display`, `/api/log`, `/api/current_screen`),
  the uuid-gated alias preview render (`/api/display/*`, used by BYOS tooling), webhook
  plugins (`/api/custom_plugins/*`), the token-authenticated REST API (`/api/devices`),
  and the rendered screen PNGs (`/storage/images/*`). Management routes such as `/api/user`,
  `/api/me`, `/api/plugin_settings/*`, `/api/display/status` and `/api/display/update` stay
  behind Umbrel auth (the latter two via `PROXY_AUTH_BLACKLIST`, which overrides the
  `/api/display/*` glob). Omitting `/storage/images/*` leaves the device screen blank.
- **No `APP_URL`** — LaraPaper builds asset URLs from the request Host header, which the
  Umbrel proxy forwards, so CSS/JS resolve correctly without pinning an absolute URL.
- **Volumes** — SQLite DB (`data/database`) and generated screen PNGs (`data/generated`).
- **`hooks/pre-start`** — pre-creates and `chown`s those dirs to `82:82` (www-data on the
  Alpine base) so LaraPaper can write on first boot.

### Version suffixes

The watcher ships the plain upstream version (e.g. `0.38.0`). If you ever need a
*packaging-only* fix without an upstream bump, use a suffix so Umbrel still offers the
update (e.g. `0.38.0+1`) and edit `usetrmnl-larapaper/` by hand.

---

## Open TODOs for the maintainer / Umbrel

- **Gallery screenshots** — the manifest ships `gallery: []` on purpose; Umbrel's linter
  asks new official submissions to leave it empty and Umbrel produces the final gallery
  assets. Supply 3–5 `.webp` screenshots in the PR body (or to Umbrel) when ready. Do
  **not** commit them into `usetrmnl-larapaper/` — Umbrel's linter rejects image assets in the app
  folder.
- **Icon** — `assets/icon.svg` is included for convenience; the manifest omits `icon:`
  because Umbrel hosts the official icon. Hand the SVG to Umbrel with the submission.
- **`submission:`** — left as `""`; fill it with the PR URL if you follow that convention.

---

## License

MIT — see [`LICENSE`](LICENSE). LaraPaper itself is MIT (© the TRMNL / usetrmnl authors);
this repository covers the Umbrel packaging only.
