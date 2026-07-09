# LaraPaper (Laravel) — per-install APP_KEY.
#
# Umbrel sources this file in its app context (where `derive_entropy` and
# `app_entropy_identifier` are defined by umbreld's legacy-compat app-script)
# and exports the result into the app's compose environment.
#
# derive_entropy(identifier) = HMAC-SHA256(key = the install's umbrel-seed,
# msg = identifier), emitted as 64 hex chars (= 32 bytes). It is DETERMINISTIC
# per install: the same physical Umbrel always yields the same value for the
# same identifier, and umbreld deliberately reads the real seed even across OTA
# updates. `app-${app}-seed` is the exact identifier umbreld uses to compute the
# ${APP_SEED} it injects, so this derives from the same per-app secret.
#
# Laravel requires APP_KEY = "base64:" + base64(exactly 32 raw bytes) for its
# AES-256-CBC cipher. We SHA-256 the 64-hex-char seed material down to 32 raw
# bytes and base64-encode them, producing a valid Laravel key. Because the seed
# is stable, the key is stable: the SQLite DB's encrypted columns and signed
# session cookies keep decrypting across restarts and updates. It is also unique
# per install (different Umbrels have different seeds), which is the whole point
# of replacing the image's shared baked-in key.
export APP_LARAPAPER_APP_KEY="base64:$(derive_entropy "env-${app_entropy_identifier}-APP_KEY" | openssl dgst -sha256 -binary | base64 | tr -d '\n')"
