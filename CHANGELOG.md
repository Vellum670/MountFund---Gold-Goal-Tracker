# Changelog

Newest releases appear first. Release notes begin after version **0.3.1**.

## Unreleased

No changes queued yet.

## 0.4.1 - 2026-10-14

- Make every training ability icon selectable, including abilities with unmet
  prerequisites and those with no later upgrades. Only excluded icons turn grey.
- Show the next rank's level after your current level instead of "Now". Keep
  abilities without later upgrades visible as "Max", sorted after future ranks.
- Recognize learned higher ranks when checking an ability's quest or talent
  prerequisite, fixing Sunder Armor eligibility and its training budget.
- Keep observed unpaid older ranks in expense calculations while showing the
  upcoming upgrade in the icon and tooltip.

## 0.4.0 - 2026-10-14

- Added calendar-date and character-play-time goals alongside level goals.
  Calendar deadlines advance offline; play-time goals count logged-in time.
- Moved goal lists, presets, training, expenses, plans, and settings into pages
  of the same window, with Back navigation and smaller layouts for short pages.
- Shrink short savings plans and expense grids to fit their rows, and tighten
  preset and settings pages. Time plans omit the empty training column heading.
- Added descriptive savings-curve names and silent editing. Removed save
  confirmations and clarified the protected-spending setting.
- Update training icons for the current class and level, showing and sorting
  by each ability's next unlearned rank. Fully learned abilities disappear.
- Show observed unpaid training as the next upgrade before a later rank, then
  advance its icon and level when it is learned.
- Clear stale unknown-price tooltip notices when a reused icon has known costs.
- Apply quest and talent prerequisites to every trainer rank of an ability.
- Center the level-up toast near the top of the screen by default. Settings
  lets you drag its preview; Escape or the move button saves the position.
  Saved positions adapt to resolution changes.
- Escape saves fields and settings before closing any page. Incomplete input
  is retained separately so it can be resumed without replacing valid goals.

## 0.3.6 - 2026-10-14

- Added `/ge testgold` to simulate a wallet and experiment with goal funding,
  spending, training budgets, and toast progress using session-only copies.
- Require a password at the end of all gold, level, and toast test commands.
- Retain the test commands in final builds. Overrides reset on reload, logout,
  or character change; simulated goal edits never overwrite real saved goals.
- Keep real purchases and actual earnings independent of simulated values.

## 0.3.5 - 2026-10-14

- Added temporary `/ge testlevel 1-60` to simulate a character level inside
  Gold Envelope and preview its goal progress, training costs, and level-up toast.
- Use `/ge testlevel reset` to return to your real level. The override also
  resets on reload, logout, or character change and is never saved.
- Show the active test level in the goal window. The command does not change
  your character's actual level, money, or existing saved progress.

## 0.3.4 - 2026-10-14

- Fixed overlapping borders on training ability icons. Each icon now has a
  consistent, thin gold or grey frame, with hover highlighting inside it.

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
