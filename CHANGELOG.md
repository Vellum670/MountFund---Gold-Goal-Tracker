# Changelog

Newest releases appear first. Release notes begin after version **0.3.1**.

## Unreleased

No changes queued yet.

## 0.3.3 - 2026-10-14

- Added a quiet level-up toast with actual goal savings, an animated progress
  bar, and how far ahead or behind you are. Fully funded goals get a celebration.
- Show up to two goals by nearest deadline and fade away after six seconds.
  The toast is silent, lets clicks pass through, and waits until combat ends.
- Added `/ge toasts` to turn level-up notifications on or off.
- Added temporary `/ge testtoast` for in-game preview without leveling or
  changing goal progress. An example appears if you have no active goal.

## 0.3.2 - 2026-10-14

- Replaced training checklists with an eight-column grid of clickable ability
  icons. Excluded abilities appear grey, and hovering shows the full spell tooltip.
- Use one icon per ability; choosing it includes or excludes all its ranks.
- Added a Class training button to the goal editor with a separate ability
  window. New goals include eligible, unlearned training by default.
- Save fields automatically when focus leaves them and save icon selections
  immediately. Removed the Save goal and Apply choices steps.
- Handle the initial savings allocation automatically in the background; goal
  progress shows how far ahead or behind you are.
- Keep the goal first in the expense window and condense the main window.
- Protect the shared training budget across goals and retain ability exclusions
  when new trainer ranks appear.
- Include this changelog in the addon download.
