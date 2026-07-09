# App Store assets (handed to Umbrel, NOT part of the app package)

Umbrel hosts the official icon and gallery assets itself, and its linter rejects image
files committed inside the `larapaper/` app folder. So they live here instead.

- **`icon.svg`** — the LaraPaper icon. The manifest omits the `icon:` field on purpose;
  supply this SVG to Umbrel with the submission.

## Gallery screenshots — for the PR body, not committed

Umbrel's linter says: leave `gallery: []` (we do), **do not commit screenshots**, and
**include them in the PR body** — Umbrel builds the final gallery assets from what you
provide. So there's no strict size to hit; Umbrel's finished galleries are 16:10 (~1600×1000
`.webp`), but that's their step, not ours.

Best to screenshot **your own running LaraPaper** when you open the PR (it'll show your real
setup). Suggested shots, all clean of personal data:

1. **Plugins & Recipes** (`/plugins`) — the recipe/plugin grid. Shows the headline "build
   any screen" feature. (Rename any personal recipe tiles first if you like.)
2. **Devices → Device Models / Device Palettes** — shows the broad e-ink device + palette
   support (BW, grayscale, color). Very clean, no personal data.
3. **Playlists** (`/playlists`) — shows the rotation feature.
4. *(optional, most compelling)* **Dashboard** (`/dashboard`) — a live device preview showing
   a rendered screen. **If you use this one, crop out the device row: it prints the device's
   MAC address.**

### Privacy checklist before any screenshot goes on a public PR
- Crop out the browser toolbar (profile avatar, other tabs, bookmarks).
- No device **MAC addresses** (the Dashboard device card shows one).
- No personal dashboard content you'd rather not publish (finances, private calendar/agenda,
  home addresses, photos).
- No LAN hostnames/IPs you'd rather keep private (the URL bar — cropping the toolbar handles this).
