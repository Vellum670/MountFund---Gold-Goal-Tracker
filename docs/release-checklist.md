# Gold Envelope final-release checklist

Prepared for version **0.4.17**, October 14, 2026.

Preparation reviewed again on October 15, 2026. Publication remains pending
the in-game checks below.

## Completed preparation

- [x] Remove unused bookkeeping and obsolete UI state without deleting saved goals.
- [x] Preserve unfinished edits when switching goals or preview contexts.
- [x] Preserve plan scrolling and use consistent priority for mixed goal types.
- [x] Keep protected testing utilities in the addon; omit their commands and password from documentation.
- [x] Run all 209 automated regression checks under Lua 5.1.
- [x] Verify that every addon Lua file compiles and the patch has no whitespace errors.
- [x] Match the addon version to dated release notes and keep the README player-facing.
- [x] Build and verify the addon-only ZIP, excluding scratch files and caches.

## In-game checks still needed

Automated checks use mocked game APIs. Complete these checks in the Forever
client before declaring the build final.

- [ ] Install from the packaged ZIP on both a fresh character and one with existing goals.
- [ ] Check level, calendar, and play-time goals; all offered curves; mount/riding separation; and class-training selections and prices.
- [ ] Check silent saving, unfinished fields, goal deletion, Back navigation, Escape, reload, logout, and switching characters.
- [ ] Check supported vendor, buyback, repair, trainer, and auction purchases: cancel, confirm, changing prices/funds, and the two-minute warning cooldown.
- [ ] Check toast login/level-up behavior, hover timing, combat deferral, positioning, and different UI scales/resolutions.
- [ ] Confirm temporary preview state never changes real funds, purchases, or persistent goal data.
- [ ] Check interactions with the other addons normally used on the client.

## Final publication

- [ ] Resolve any in-game failures and repeat the checks affected by those changes.
- [ ] Confirm the final version and release notes; rebuild if either changes.
- [ ] Review the final diff and verify the ZIP matches the exact source revision being released.
- [ ] Commit, tag, and push the approved release; upload the addon ZIP and publish its notes.
- [ ] Download through the public README link and verify that it delivers the intended version and installs correctly.
