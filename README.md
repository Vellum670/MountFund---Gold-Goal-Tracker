# Gold Envelope for WoW: Forever

Save toward goals by level, calendar date, or play time, track actual savings against your plan, and
confirm before supported purchases use protected money. Open with `/envelope`
or `/ge`; `/ge status` prints your wallet and goal progress.

See the [changelog](CHANGELOG.md) for release notes.

## Install

[Download Gold Envelope Here](https://github.com/Vellum670/WoW-Forever-Addon/raw/refs/heads/main/downloads/GoldEnvelope.zip) — Direct Download Link


If the download does not start, [open the ZIP on GitHub](https://github.com/Vellum670/WoW-Forever-Addon/blob/main/downloads/GoldEnvelope.zip)
and click **Download raw file**.

Extract it into the Forever client's `Interface/AddOns/` folder.
The path should end in `AddOns/GoldEnvelope/GoldEnvelope.toc`. Restart
the client after first installation, enable the addon, and enter `/envelope`.
The interface version is `16001` (Forever 1.60.1).

## Savings goals

Choose a goal from **Goals**, then edit its name, deadline, and amount. The
deadline button cycles between **By level**, **By calendar date**, and **By play
time**:

- Level goals start at your character's **current level**. A level-25 character
  sees levels 25 onward.
- Calendar goals use a `YYYY-MM-DD` deadline at the end of that day in your
  computer's local time. Their expected progress advances while you are offline.
- Play-time goals use a number of hours logged into this character after the
  goal starts. This includes AFK time, pauses offline and during loading screens,
  and continues across sessions. Time before installing the addon does not count.

Fields save silently when you leave them; buttons and ability selections save
immediately. **Escape** saves and closes the window, including a field you are
still typing in. Incomplete input is kept for reopening without replacing valid
goal settings. The main window is 400 × 560 UI units. Menus open as pages in this
same window, with **Back** on other pages; short pages shrink to fit their content.
Savings plans and expense grids also resize when they contain only a few rows.
Coin amounts use native gold, silver, and copper icons.

Gold-making tips appear at the bottom of the main page for your current level
bracket. Each reopening advances to the next tip, wrapping after the last one.
Use the arrows to browse three leveling tips or fifteen level-60 ideas;
each includes its farming location and selling context. Hover for the full text.
Tips switch brackets as you level and also follow `/ge testlevel` previews.

Delete a saved goal using **Goals → Delete** beside its entry, or **Delete goal**
on the main page. This removes its plan and releases its savings allocation;
your actual gold and trainer data are kept.

Presets include First Mount & Riding (100g by level 40), Epic Mount & Riding
(1,000g by level 60), Class Training, and Profession Training. Mount amounts are
editable starter budgets; trainer prices and discounts can differ. A preset
saves automatically when selected. Selecting an existing preset opens that goal.

The addon allocates an initial share of your wallet automatically in the
background, protecting existing goal allocations and upcoming class training.
Your goal shows saved progress and how far ahead or behind you are; there are no
initial-investment fields or confirmation steps.

The default **Income-based** level curve puts less saving at low levels and more
at higher levels. It uses relative quest reward/XP estimates, rather than claiming
you should own a fixed amount of gold at each level. Other choices are **Steady
saving**, **Save more later**, **Light start**, and **Late push**, with descriptions
on hover. Time goals start with **Steady saving** and offer those same custom
curves. Existing level checkpoints are retained when valid. The **Savings plan**
table shows each cumulative goal in the right column. In level plans, **This
level** shows a `+` scheduled addition and a `-` expense total, including selected,
unpaid training and other purchases at their due levels. Hover the expense line
to see the individual purchases and prices; unknown prices are flagged. Expenses
are shown for planning and are not deducted again from the goal target or saved
balance. Time plans show additions and targets by date or play-time hours.
See [research, data sources, and limitations](docs/economy-research.md).

The main page's **Goal for this level** section shows the selected goal's
cumulative savings target and **Add this level**, its scheduled increase.
It updates with your current or test level. Time goals show **Goal for now**
using their calendar or play-time schedule. Training-only goals show the shared
current-plus-two-level budget. Actual saved progress remains displayed above.

## Actual savings and progress

**Saved** is real money allocated from your wallet. The expected target is shown
separately, with how far ahead or behind you are. `/ge status` reports your exact
wallet, each goal's saved amount and progress, and any shared training budget.
There is no Available figure. Total protected money never exceeds your wallet.

After the initial investment, actual incoming money funds active goals after
leaving room for enabled class training. Level goals fund in order of earliest
target level. When time goals are included, priority follows the smallest
remaining share of each goal's timeline; the addon does not predict how quickly
you will level.
This includes any positive wallet change, such as loot, a sale, or received
mail; it does not claim to distinguish their sources. Spending uses unallocated
cash first, then reduces savings if necessary. Goals do not move coins out of
your wallet. Uncheck **Track this goal** to release its allocation immediately.

Old goals migrate to your current level with a safe initial allocation; old
planned reserves are not treated as money you actually saved. Income received
while logged out is not retrospectively assigned to goals.

## Goal progress notifications

Leveling shows a small toast centered near the top of the screen with your saved
progress and whether you are ahead, behind, or fully funded. A coin glows and
the progress bars fill, then the toast fades away after six seconds. It shows
up to two active goals by nearest deadline and notes any others.

Hovering resets the six-second timer and holds the toast open at full visibility.
Move the cursor away to resume the countdown. The progress-bar animation
continues normally, and mouse clicks still pass through the toast.

The same toast appears once on character login with **Welcome back!** and your
current progress. It requires an active goal. Zoning, entering instances, and
`/reload` do not trigger another login notification.

The toast is silent, lets mouse clicks pass through, and waits until combat
ends. Rapid level gains share one notification with the latest level. It does
not add money to your goals. Use `/ge toasts` or **Settings → Show goal progress
notifications** to toggle both login and level-up notifications.

Open **Settings** from the main page and press **Move toast** to drag a preview.
Press the button again or **Escape** to save its position. Escape also closes the
menu. The position is saved for this character and adapts to screen resolution;
**Reset position** returns it to the centered default.

## Protected test commands

These commands stay in final builds and require `Quantum123` as the last
argument. The password is a guard against accidental use and is visible in the
addon source. Normal commands such as `/ge status` and `/ge toasts` do not need it.

| Command | Result |
| --- | --- |
| `/ge testgold 100 Quantum123` | Set a simulated wallet of 100g. |
| `/ge testgold 4 87 5 Quantum123` | Set 4g 87s 5c; silver and copper must be 0–99. |
| `/ge testgold reset Quantum123` | Restore the actual wallet and saved goals. |
| `/ge testlevel 40 Quantum123` | Simulate any whole level from 1 to 60. |
| `/ge testlevel reset Quantum123` | Restore the actual level. |
| `/ge testtoast Quantum123` | Preview the toast without leveling. |

Use `/ge testgold Quantum123` or `/ge testlevel Quantum123` to report the current
values. Missing or incorrect passwords leave the current state unchanged.

Gold testing creates a session-only copy of your goals. Raising or lowering the
simulated balance acts like income or spending on that copy, allowing you to try
ahead, behind, and fully funded states. Repeating the same balance does not add
savings again. Goal edits, new goals, and ability choices made while gold testing
is active stay in this copy. Resetting gold restores your original goals and
editor fields; real income and spending received during testing remain recorded.
To create a goal that survives reload, run `/ge testgold reset Quantum123`
first. New goals created with a test wallet disappear when the test session ends.

The window labels the **Test wallet** and **Test level**. Both overrides reset
on `/reload`, logout, exiting the game, or changing characters and never change
your actual character level or gold. Real purchases still use the actual wallet
and saved goals. Using only a test level keeps normal goal edits enabled.

Toast previews use the active test values or current goals, with a clearly
labeled example if no goals exist. They work while normal notifications are
disabled and wait until combat ends.

## Expenses and Class Training

New goals include eligible, unlearned **class training** by default. The bundled
level 1–60 catalog contains 1,374 spell/rank entries across the nine classes and
works before visiting a trainer. Existing goals retain their saved choices.

Use the **Class training** button in the goal editor to open its ability page.
The goal appears first. An eight-column grid uses one clickable icon per ability;
clicking it includes or excludes every rank, including future ranks beyond the
goal's deadline. Icons adapt to your current class and level, ordered by the next
unlearned upgrade after your current level. Small labels show that upgrade's
level, even beyond the goal's deadline. Abilities with no later upgrades stay
visible as **Max** at the end of the grid. Every icon remains clickable, including
Max abilities and those with unmet prerequisites; only excluded icons turn grey.
Prerequisites still determine which training costs count, and the tooltip
explains when they are missing. Observed unpaid older ranks remain in the budget
without replacing the next-upgrade label. Hover an icon
for the native full spell tooltip, costs, and selection status. Icons do not use
checkboxes or separate rank choices.

Each toggle saves immediately. **Back** returns to the goal; **Close** or Escape
closes the window. Training prices remain assigned to their actual required levels
in level plans. **Additional Expenses** asks before opening itemized planning;
class training has its own button and page in the same window.

Class training remains a **shared expense budget**, separate from your mount
or other goal's final amount. It protects current training plus the next two
levels, while the Plan table shows future costs at their required levels. Two
goals including the same training do not count its cost twice. If either active
goal selects a rank, the shared budget includes it. Intended trainer purchases
may use this training money; spending goal savings still requires confirmation.

Bundled prices are **base estimates**, not guaranteed current server quotes.
Visiting a trainer replaces matching estimates with your observed prices and
adds new observed ranks. Show all trainer filters to capture future and known
services. Excluded abilities stay excluded when prices refresh or new ranks
appear. Unknown prices are flagged; the known-cost total cannot guarantee enough
money for unknown costs.
See the research document for catalog provenance and eligibility limitations.

Profession Training uses observed profession ranks and recipes. A riding quote
replaces an itemized mount's starter estimate. You can also add manual expenses
with individual amounts and due levels. Included, unpaid non-class expenses
set an itemized goal's amount and follow its savings curve. Manual cost fields
save on leaving the field; **New cost** starts another entry. Use the small **x**
on a manually added expense to delete it, or click its icon to include/exclude
it. Deletion saves immediately. Class, profession, riding, and the original goal
budget cannot be deleted; training retains its include/exclude controls.
Expense fields also save on Escape.

## Before-purchase warnings

When a supported purchase would use actual goal savings or protected training
money, a warning appears **before** spending. Toggle this in **Settings** using
**Confirm before spending protected gold**. It shows the price, remaining
wallet, and protected money used. **Cancel** or Escape spends nothing;
**Spend anyway** authorizes that action and silences further savings warnings
for **two minutes**. The timer starts after a valid confirmation; Cancel or Escape
does not start it. Purchases during the cooldown still require a valid price and
enough money. The cooldown resets when the UI reloads or you log out.
Spending unallocated cash, reaching the protected limit exactly, or a free
action does not trigger a warning merely
because you are behind a future savings target.

The addon checks the selection, price, funds, and savings again on confirmation.
Changed selections or prices cancel the pending action; changes to funds or
goals refresh the warning. Closing the merchant, trainer, or auction house
cancels pending actions. Expired commodity quotes cannot be accepted.

Native UI coverage:

- Vendor right-click and stack-selector quantity purchases.
- Vendor buyback and repair-all using your own money.
- The trainer's Train button, including profession confirmations.
- Modern auction item buyout/bid and commodity Buy Now confirmations.

This is an advisory guard for these UI actions. Cursor/drag vendor buying,
single-item repair, mail, trades, flights, auction fees, gossip purchases,
macros, and other addons' direct purchases are not intercepted. Their money
changes still reconcile savings. Blizzard purchase APIs are not replaced.

## Validation and packaging

Run `lua tests/run.lua` from the repository with Lua 5.1 or later. Tests cover
real-money accounting, training prices and exclusions, forward-only plans,
migration, initial-investment protection, page navigation, time goals, dynamic
training icons, toast positioning, Escape saving, and purchase guards.
Run `python3 scripts/package_addon.py` to rebuild and verify
[the addon-only ZIP](downloads/GoldEnvelope.zip), including its bundled data.
For new releases, update the TOC version and add a matching dated entry to
`CHANGELOG.md` before packaging. The build includes these notes in the ZIP and
requires them for versions after 0.3.1.

Live-client validation remains necessary. Enable `/console scriptErrors 1`,
create a test goal, and check the compact layout, coin textures, trainer quotes,
known-spell detection, expense exclusions, level-up costs, and `/ge status`.
Check field blur and Escape saving, Back navigation, all-rank icon selection,
full spell tooltips, and training ordering after changing the test level.
Try both calendar and play-time goals. Exercise purchase
cancel/confirm, quantity purchases, buyback, repairs, training, and
auctions. Confirm that repeat warnings stay quiet for two minutes after
**Spend anyway**, then return when the cooldown expires. Check controller
behavior and interactions with other addons too.
Try `/ge testtoast Quantum123` to check the toast's placement, coin glow, progress bars,
click-through behavior, and fade. Hover during fade-out to check that it becomes
fully visible and stays open; move away to check the fresh countdown. Check a
real level-up and its combat deferral too, then verify `/ge toasts` disables
notifications.
Log out and back in to check the welcome toast; zoning and `/reload` should not
show it again.
Use **Settings → Move toast** to check dragging, saving with a second button
press or Escape, and restoration after reload or a resolution change.

API references: [Forever merchant UI](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_UIPanels_Game/Mainline/MerchantFrame.lua),
[trainer UI](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_TrainerUI/Mainline/Blizzard_TrainerUI.lua),
and [auction UI](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_AuctionHouseUI/Shared/Blizzard_AuctionHouseFrame.lua).
