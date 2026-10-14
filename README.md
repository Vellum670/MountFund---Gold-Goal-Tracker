# Gold Envelope for WoW: Forever

Save toward level-based goals, track actual savings against your plan, and
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

New goals start at your character's **current level**. A level-25 character sees
levels 25 onward. Choose a goal from **Goals**, then edit its name, target level,
and amount. Fields save when you leave them; buttons and ability selections
save immediately. Invalid input shows an error and keeps the last valid settings.
The main window is 400 × 450 UI units; the goal list and expense chooser open
separately. Coin amounts use native gold, silver, and copper icons.

Presets include First Mount & Riding (100g by level 40), Epic Mount & Riding
(1,000g by level 60), Class Training, and Profession Training. Mount amounts are
editable starter budgets; trainer prices and discounts can differ. A preset
saves automatically when selected. Selecting an existing preset opens that goal.

The addon allocates an initial share of your wallet automatically in the
background, protecting existing goal allocations and upcoming class training.
Your goal shows saved progress and how far ahead or behind you are; there are no
initial-investment fields or confirmation steps.

The default **Income-based** curve puts less saving at low levels and more at
higher levels. It uses relative quest reward/XP estimates, rather than claiming
you should own a fixed amount of gold at each level. Curves 1–4 are optional
custom curves; 1 is linear, and higher values defer more saving. Existing custom
checkpoints are retained when valid. The Plan table shows cumulative goal
targets, additions, and class-training costs at their actual required levels.
See [research, data sources, and limitations](docs/economy-research.md).

## Actual savings and progress

**Saved** is real money allocated from your wallet. The level target is shown
separately, with how far ahead or behind you are. `/ge status` reports your exact
wallet, each goal's saved amount and progress, and any shared training budget.
There is no Available figure. Total protected money never exceeds your wallet.

After the initial investment, actual incoming money funds active goals in
order of earliest deadline, after leaving room for enabled class training.
This includes any positive wallet change, such as loot, a sale, or received
mail; it does not claim to distinguish their sources. Spending uses unallocated
cash first, then reduces savings if necessary. Goals do not move coins out of
your wallet. Uncheck **Track this goal** to release its allocation immediately.

Old goals migrate to your current level with a safe initial allocation; old
planned reserves are not treated as money you actually saved. Income received
while logged out is not retrospectively assigned to goals.

## Level-up progress

Leveling shows a small toast above the bottom-right action area with your saved
progress and whether you are ahead, behind, or fully funded. A coin glows and
the progress bars fill, then the toast fades away after six seconds. It shows
up to two active goals by nearest deadline and notes any others.

The toast is silent, lets mouse clicks pass through, and waits until combat
ends. Rapid level gains share one notification with the latest level. It does
not add money to your goals. Use `/ge toasts` to toggle these notifications.

**Temporary preview command:** `/ge testtoast` shows the toast without leveling
or changing savings. It uses your current goals, or a clearly labeled example
if none are active. Preview also works while normal toasts are turned off and
waits until combat ends. This command will be removed after in-game review.

## Expenses and Class Training

New goals include eligible, unlearned **class training** by default. The bundled
level 1–60 catalog contains 1,374 spell/rank entries across the nine classes and
works before visiting a trainer. Existing goals retain their saved choices.

Use the **Class training** button in the goal editor to open its ability window.
The goal appears first. An eight-column grid uses one clickable icon per ability;
clicking it includes or excludes every rank, including future ranks beyond the
goal's deadline. Excluded, learned, and currently ineligible abilities appear
grey. Small level labels show the next relevant training level. Hover an icon
for the native full spell tooltip, costs, and selection status. Icons do not use
checkboxes or separate rank choices.

Each toggle saves immediately. **Close** or Escape leaves the saved choices in
place. Training prices remain assigned to their actual required levels in the
Plan table. The other **Customize expenses** option asks before opening custom
itemized planning; class training has its own separate button and window.

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
save on leaving the field; **New cost** starts another entry. Exclude manual costs
once paid. These windows save changes automatically and do not require Apply or
Save buttons.

## Before-purchase warnings

When a supported purchase would use actual goal savings or protected training
money, a warning appears **before** spending. It shows the price, remaining
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
migration, initial-investment protection, frame dimensions, and purchase guards.
Run `python3 scripts/package_addon.py` to rebuild and verify
[the addon-only ZIP](downloads/GoldEnvelope.zip), including its bundled data.
For new releases, update the TOC version and add a matching dated entry to
`CHANGELOG.md` before packaging. The build includes these notes in the ZIP and
requires them for versions after 0.3.1.

Live-client validation remains necessary. Enable `/console scriptErrors 1`,
create a test goal, and check the compact layout, coin textures, trainer quotes,
known-spell detection, expense exclusions, level-up costs, and `/ge status`.
Check autosave on field blur, all-rank icon selection, full spell tooltips,
and that closing the training window preserves changes. Exercise purchase
cancel/confirm, quantity purchases, buyback, repairs, training, and
auctions. Confirm that repeat warnings stay quiet for two minutes after
**Spend anyway**, then return when the cooldown expires. Check controller
behavior and interactions with other addons too.
Try `/ge testtoast` to check the toast's placement, coin glow, progress bars,
click-through behavior, and fade. Check a real level-up and its combat deferral
too, then verify `/ge toasts` disables notifications.

API references: [Forever merchant UI](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_UIPanels_Game/Mainline/MerchantFrame.lua),
[trainer UI](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_TrainerUI/Mainline/Blizzard_TrainerUI.lua),
and [auction UI](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_AuctionHouseUI/Shared/Blizzard_AuctionHouseFrame.lua).
