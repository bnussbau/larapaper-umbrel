# LaraPaper Umbrel package — design notes

Rationale behind the packaging choices in `larapaper/`. These were validated against the
pinned image on a real Umbrel install (fresh install + update path + device polling +
SQLite persistence).

## What this packages

`ghcr.io/usetrmnl/larapaper` — a self-hosted TRMNL BYOS e-ink dashboard server (single
Laravel/PHP container, SQLite-backed, renders screens to PNG via headless Chromium). MIT,
by `usetrmnl/larapaper`.

## Image pinning

- Pin the **OCI image-index** digest (multi-arch: `linux/amd64` + `linux/arm64`). Docker
  resolves the correct per-arch layer from the index at pull time, so the index digest is
  reproducible on both architectures Umbrel supports.
- Re-pin on a bump: `docker buildx imagetools inspect ghcr.io/usetrmnl/larapaper:<tag>`.
  The `submit-to-umbrel` workflow does this automatically.
- Stable tags are strict `X.Y.Z`; the workflow refuses beta/nightly tags.

## Decision 1 — per-install `APP_KEY` (the important one)

**Derive a unique, per-install `APP_KEY` from Umbrel's per-app seed, in `exports.sh`.**

The upstream `Dockerfile` does `COPY .env.example .env`, and `.env.example` ships a valid
`APP_KEY=base64:...`. That boots zero-touch, but it means **every install would share one
publicly-known key** baked into the image. In Laravel, `APP_KEY` signs session cookies and
encrypts data at rest — a shared secret across installs is a security smell reviewers flag.

Umbrel's app runtime defines a shell function `derive_entropy(id) = HMAC-SHA256(key =
<install seed>, msg = id)` → 64 hex chars, **deterministic per install**, and sources each
app's `exports.sh` before rendering compose. Laravel needs `APP_KEY = "base64:" +
base64(exactly 32 raw bytes)`, so we hash the 64-hex seed material once more to 32 raw
bytes and base64 them:

```sh
export APP_LARAPAPER_APP_KEY="base64:$(derive_entropy "env-${app_entropy_identifier}-APP_KEY" \
  | openssl dgst -sha256 -binary | base64 | tr -d '\n')"
```

Compose consumes it: `- APP_KEY=${APP_LARAPAPER_APP_KEY}`.

- **Stable** (data survives): the seed never changes and the derivation is a pure function,
  so the same key comes back every boot and after every app update. SQLite encrypted
  columns and signed cookies keep decrypting.
- **Unique**: different installs have different seeds → no two share a signing key.
- **Valid**: the `base64:`-stripped value decodes to exactly 32 bytes; verified on the
  pinned image that Laravel reports `cipher = AES-256-CBC` and an `encrypt()`/`decrypt()`
  round-trip succeeds.

This is the same seed primitive the official Firefly III, BookStack, Plausible and Tandoor
store apps use for their secrets.

## Decision 2 — do NOT set `APP_URL`

LaraPaper emits asset URLs (CSS/JS) as absolute URLs built from the **incoming request's
Host header**, not from a static `.env` `APP_URL`. The Umbrel app_proxy forwards the
browser's Host header, so assets resolve to the exact host:port the browser used and CSS/JS
load correctly. Pinning a fixed absolute `APP_URL` would instead break access via any other
host:port. Leaving it unset is the robust default.

If a feature ever needs fully-qualified absolute URLs (e.g. a device image URL), set
`APP_URL` to how the app is actually reached on the LAN.

## Other choices

- **A narrow `PROXY_AUTH_WHITELIST`** on `app_proxy`: only the exact routes devices and webhook
  publishers reach without a browser session bypass Umbrel's auth — the firmware protocol
  (`/api/setup`, `/api/display`, `/api/log`, `/api/current_screen`), webhooks (`/api/custom_plugins/*`),
  the token REST API (`/api/devices`), the rendered PNGs (`/storage/images/*`), and the
  uuid-gated alias preview (`/api/display/{uuid}/alias`, used by BYOS tooling to fetch a
  plugin's rendered screen without a browser session). Whitelisted paths are public, so
  management routes (`/api/user`, `/api/me`, `/api/plugin_settings/*`, `/api/display/status`,
  `/api/display/update`) are deliberately kept behind Umbrel auth. The proxy matches bare
  paths exactly and `"/path/*"` as child-only, with no mid-path wildcard, so admitting the
  alias route takes the `/api/display/*` child glob; the two Sanctum management children
  that glob would also admit (`/api/display/status`, `/api/display/update`) are excluded
  again via `PROXY_AUTH_BLACKLIST`, which app_proxy evaluates with priority over the
  whitelist. Without `/storage/images/*` the device screen goes blank.
- **`hooks/pre-start`**: pre-creates and `chown`s the data dirs to `82:82` (www-data on the
  Alpine base). Without it the app can't create its SQLite DB on first boot. Idempotent, so
  it is also a safe update-time migration.
- **Volumes**: the two persistent paths — `data/database` → SQLite dir, `data/generated` →
  generated screen PNGs.
- **`firmwares` volume**: omitted. Add
  `data/firmwares → /var/www/html/storage/app/public/firmwares` only if serving OTA
  firmware to real TRMNL hardware devices.
- **`port: 4567`**: LaraPaper's own default host port.
- **`category: automation`**.

## Official-store manifest specifics

Per the getumbrel/umbrel-apps linter for **new** submissions:

- `gallery: []` — leave empty; Umbrel creates the final gallery assets.
- No `icon:` field — Umbrel hosts the official icon (the SVG lives in `assets/`).
- No image/icon/screenshot files inside the `larapaper/` folder — they belong in the PR
  body / Umbrel's asset pipeline.
