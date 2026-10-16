# Changelog

Newest releases appear first. Release notes begin after version **0.3.1**.

## Unreleased

## 1.3.2 - 2026-10-15

- Replace Income-based weights with an authored level-scaled planning curve that
  lowers early savings targets and assigns more saving to later levels. Existing
  saved progress and final goal amounts are preserved.
- Clarify that Income-based targets are estimates rather than measured earnings.
- Use MIT-licensed What's Training? Vanilla tables for class-training estimates,
  with spell names and ranks supplied by the game client. Keep shared ability
  exclusions and let observed trainer costs, levels, and ranks override estimates.
- Exclude pet-only Hunter training from the player class-training reserve.
- Include the training data's attribution and MIT license notice in downloads.

- Configure CurseForge GitHub packaging to install the addon directly under
  Mountfund and exclude duplicate downloads, artwork, and repository-only files.

- Add the selected horse-on-a-gold-coin project icon for the CurseForge listing.

## 1.2.9 - 2026-10-15

- Keep missing savings visible for unfinished goals at or past their level,
  calendar, or play-time deadline instead of reporting a zero interval target.
- Keep overdue interval targets stable as new savings advance progress.

## 1.2.8 - 2026-10-15

- Restore completion notifications when a goal is funded again after spending,
  or when its target changes, including spending while a prompt is open.
- Keep unfinished goal and expense drafts attached to the correct goals when
  funding priorities are reordered.
- Keep the completion confirmation on screen at edge notification positions.

## 1.2.7 - 2026-10-15

- Warn before purchasing excluded class spells and abilities even when no
  protected gold is used, including when training protection is disabled.
- Rename the warning labels consistently to excluded-ability warnings and
  explain the excluded ability in the purchase confirmation.

## 1.2.6 - 2026-10-15

- Add a class-training protection setting; disabling it releases the reserve
  and hides training costs while preserving ability choices.
- Show protection warnings only when purchasing an excluded, greyed-out class
  ability would use protected gold. Other purchases no longer show the warning.
- Explain on the warning popup that Settings can change or disable warnings.

- Simplify README installation steps by removing the extra folder-path check.

## 1.2.5 - 2026-10-15

- Automatically redistribute remaining savings across levels, calendar days, or
  play-time hours using actual interval progress and the selected savings curve.
  Keep original ahead/behind comparisons and the final goal target.
- Collapse completed goals into an expandable history by default.
- Drag goals on the Goals page to set funding priority; top goals receive new
  savings first after class-training protection.

## 1.2.4 - 2026-10-15

- Celebrate fully funded goals with a gentle chime and a confirmation prompt.
  Mark complete records completion and releases savings without spending gold;
  Later keeps the goal tracked, with a Complete button to return to confirmation.
- Recheck funding before completion and keep completed goals labeled after
  spending or reloading. Enable tracking to start saving for the goal again.

## 1.2.3 - 2026-10-15

- Add separate Settings toggles for login/reload and goal-milestone chat summaries;
  keep manual status available and enable automatic summaries by default.
- Add a gold-making tips toggle that hides the section and reclaims its space
  without changing the saved collapse preference.

## 1.2.2 - 2026-10-15

- Configure protected-gold warning silence after Spend anyway from 30 seconds
  to 60 minutes in Settings; keep the two-minute default and save silently.
- Use consistent protected-gold warning labels in Settings and purchase warnings.

- Remove private pre-release rename migration instructions from the README.

- List /mf as the command to open Mountfund under Useful controls.

## 1.2.1 - 2026-10-15

- Condense the README into installation, quick-start controls, and collapsible
  upgrade instructions for keeping existing goals.

## 1.2.0 - 2026-10-15

- Rebrand to Mountfund - Gold Goal Tracker in the addon list, main window,
  chat summaries, reporting page, player guide, and download.
- Add /mountfund and /mf commands while retaining /envelope and /ge aliases.
- Rename the installed folder, manifest, saved-data namespace, and internal
  identifiers to Mountfund. Provide a one-time import for copied legacy saved
  data, with upgrade instructions for retaining existing goals.

## 1.1.3 - 2026-10-15

- Share class-training ability choices across all goals. Greyed-out abilities
  now update every goal's training budget and the main-page preview together.
- Preserve existing exclusions when migrating choices and apply them to new
  goals and newly observed ranks. Keep testing choices session-only.
- Hide Class training and stop class-training budgeting after more than three
  hours played at level 60. Persist the timer and seed existing capped
  characters from server played-time data when available.

## 1.1.2 - 2026-10-15

- Show upcoming included spells and abilities with their ranks and costs when
  hovering Class Training in the main-page preview. Group them by required
  level within the character's next two levels.

## 1.1.1 - 2026-10-15

- Keep overview text visible on hover with a subtle tint beneath the text.
- Label upcoming class training using actual upgrades after the character's
  level through the next two levels. Show current and overdue training costs
  separately while retaining their protected funding.

## 1.1.0 - 2026-10-15

- Update the addon version to 1.1.0.

## 0.4.23 - 2026-10-15

- Add Report bug beside Close on the main page. Open a selectable GitHub issue
  link in the same window for players to copy into their browser.
- Preserve goal edits when opening the reporting page and support Back and
  Escape navigation. Reports are written and submitted on GitHub.

## 0.4.22 - 2026-10-15

- Add a collapsible All goals overview to the main page with aligned Saved and
  Target columns, coin icons, and shared class-training funding shown once.
- Group goals by level, calendar date, and play time with combined interval
  progress matching chat summaries. Show untracked goals separately.
- Click overview rows to edit goals below; retain unfinished input and remember
  collapse state. Scroll long lists within a bounded area and show full details
  on hover.

## 0.4.21 - 2026-10-15

- Count duplicate trainer observations once and prefer the latest exact spell
  quote over older name-based matches, keeping shared training totals stable.
- Validate expense rows on simple and itemized goals. Ignore invalid saved
  trainer quotes and recover malformed earnings counters without interrupting
  normal character money updates.
- Preserve invalid expense input when pressing New cost so it can be corrected.
- Verify release downloads before replacing the previous ZIP.

## 0.4.20 - 2026-10-15

- Fix toast hover detection for its click-through window at different UI scales.
  Hovering restores full visibility and holds the dismissal timer until the
  cursor leaves, then resumes the six-second countdown.

## 0.4.19 - 2026-10-15

- Group chat summaries by level, calendar date, and play time, showing each
  goal's savings and combined interval progress against scheduled additions.
- Show shared class training once with its next included training level from
  the class database. Shorten chat coin amounts and separate goal groups.
- Report goal status on matching level, daily, and played-hour milestones,
  plus login and reload. Zoning does not trigger reports.
- Preserve interval savings across reloads; spending reduces reported progress.
  Existing goals start interval tracking when this update first sees them.

## 0.4.18 - 2026-10-15

- Simplify the public repository to the addon, player guide, release notes,
  and addon-only download. Retain the existing direct download links.

## 0.4.17 - 2026-10-14

- Preserve unfinished goal input when editing another goal, and preserve the
  savings-plan scroll position during background updates.
- Use consistent goal priority when level and time goals share a progress toast.
- Remove unused internal bookkeeping and outdated UI flags. Restrict the download
  to the addon manifest, its declared modules, and release notes.

## 0.4.16 - 2026-10-14

- Show the savings target to reach before the next level under Goal for this
  level, including its scheduled addition and By level checkpoint. Curve
  changes now show their effect immediately at the goal's starting level.
- Place the current target amount directly beside its label. Clarify that
  curve choices change planned targets, while actual saved money stays intact.
- Keep the README focused on player installation and usage, removing developer
  commands, testing and packaging instructions, and implementation details.

## 0.4.15 - 2026-10-14

- Keep an itemized mount's allowance separate from its observed riding fee.
  The first known quote preserves the entered combined budget; later fee
  updates no longer erase or change the mount allowance.
- Allow unchanged spending warnings to be confirmed once after background
  refreshes, while rechecking price, affordability, and protected spending.
- Give manual expenses due-level and expense-selection tooltips. Explain that
  disabling goal tracking releases its allocation and restarting funds from zero.
- Add a saved collapse/expand control for gold tips and shrink the main window
  when collapsed. Show aggregate progress only when multiple goals exist.
- Offer Income-based, Steady saving, and Save more later curves. Migrate Light
  start and Late push goals to Save more later while retaining their saved
  allocations, amounts, deadlines, and valid checkpoints.

## 0.4.14 - 2026-10-14

- Use "sellable" in the Wetlands gold-making tip for clearer wording.

## 0.4.13 - 2026-10-14

- Advance to the next gold-making tip in your level bracket each time the
  Gold Envelope window reopens. Page changes and progress updates keep the
  current tip, and the arrows still allow manual browsing.

## 0.4.12 - 2026-10-14

- Add gold-making tips at the bottom of the main page, matched to your current
  level bracket, with a separate set of fifteen ideas at level 60.
- Browse tips using compact arrows, keeping farming locations, requirements,
  and selling context.

## 0.4.11 - 2026-10-14

- Save pending goal and expense fields before reload or logout, even when the
  cursor is still in a field. Preserve unfinished input as a draft.
- Save an active toast-position adjustment before logout.

## 0.4.10 - 2026-10-14

- Even out gold, silver, and copper input spacing, including the native field
  borders, and center each coin icon beside its field.

## 0.4.9 - 2026-10-14

- Add a Delete button beside each goal in the Goals list, and keep the main
  page's Delete goal button inside its visible bounds.
- Remove a deleted goal's pending drafts so autosave cannot restore it, while
  preserving unfinished fields for remaining goals.
- Keep actual gold and trainer data intact when deleting goals.

## 0.4.8 - 2026-10-14

- Rename the expense button and page to **Additional Expenses**.
- Add a small delete button to manually added expenses. Deletion saves
  immediately and clears the expense's editor so it does not reappear on close.
- Keep class, profession, riding, and the original goal budget protected from
  deletion. Training retains its include/exclude controls.

## 0.4.7 - 2026-10-14

- Hovering a toast resets its six-second dismissal timer and holds it open;
  moving the cursor away resumes the countdown. Hover restores a fading toast
  to full visibility without restarting its progress-bar animation.
- Keep normal toasts click-through and retain combat deferral while hovering.

## 0.4.6 - 2026-10-14

- Show the goal-progress toast once on character login with a "Welcome back!"
  message. Zoning, instance loading, and UI reloads do not trigger it.
- Use the existing notification setting for login and level-up toasts. Login
  progress requires an active goal and waits until combat ends when necessary.

## 0.4.5 - 2026-10-14

- Add a gold arrow and hover hint to the goal-type button so players can see
  that clicking cycles between level, calendar date, and play time.

## 0.4.4 - 2026-10-14

- Match the Class training button's width and left edge to the expense button
  below it.

## 0.4.3 - 2026-10-14

- Move each level's cumulative savings goal to the right column of the plan.
  The middle column shows the planned addition and a minus-expenses line.
- Include selected, unpaid class training, profession, riding, and manual
  expenses at their due levels. Hover the expense line for individual costs;
  unknown prices are flagged. Viewing the plan does not deduct any money.

## 0.4.2 - 2026-10-14

- Added **Goal for this level** to the main page with the selected goal's
  planned total and scheduled addition for the current level.
- Use **Goal for now** for calendar and play-time goals, and show the upcoming
  training budget for training-only goals. Keep the main window at 400 × 450.

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

## 0.3.4 - 2026-10-14

- Fixed overlapping borders on training ability icons. Each icon now has a
  consistent, thin gold or grey frame, with hover highlighting inside it.

## 0.3.3 - 2026-10-14

- Added a quiet level-up toast with actual goal savings, an animated progress
  bar, and how far ahead or behind you are. Fully funded goals get a celebration.
- Show up to two goals by nearest deadline and fade away after six seconds.
  The toast is silent, lets clicks pass through, and waits until combat ends.
- Added `/ge toasts` to turn level-up notifications on or off.

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
