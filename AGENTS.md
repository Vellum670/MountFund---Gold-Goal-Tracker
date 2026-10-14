# Release workflow

The user requires a changelog starting with the next build after version 0.3.1.

- Record player-facing changes in `CHANGELOG.md` while working.
- Before packaging a new release, update `GoldEnvelope/GoldEnvelope.toc` with
  its version and move the pending notes into `## VERSION - YYYY-MM-DD`.
  Use the release date in the user's timezone (America/Denver).
- Describe what was added, changed, or fixed in concise bullets. Do not invent
  changes or backfill older releases with unverified notes.
- Keep the newest release first. Leave an `Unreleased` section for future work.
- Build with `python3 scripts/package_addon.py`; it validates the release entry
  and includes the changelog in the addon-only download.
- Keep `/ge testgold`, `/ge testlevel`, and `/ge testtoast` in all builds,
  including the final build. Each requires the configured trailing password.
  Overrides and simulated goal changes must remain session-only and must never
  change real money, saved goal progress, or actual purchase affordability.
