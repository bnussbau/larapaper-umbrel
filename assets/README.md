# App Store assets (handed to Umbrel, NOT part of the app package)

Umbrel hosts the official icon and gallery assets itself, and its linter rejects image
files committed inside the `larapaper/` app folder. So they live here instead.

- **`icon.svg`** — the LaraPaper icon. The manifest omits the `icon:` field on purpose;
  supply this SVG to Umbrel with the submission.
- **Gallery screenshots (TODO)** — add 3–5 `.webp` screenshots of the LaraPaper UI here
  and include them in the umbrel-apps PR body. The manifest ships `gallery: []`; Umbrel
  produces the final gallery from what you provide.
