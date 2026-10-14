# Gold Envelope for WoW: Forever

Save toward level-based goals, track actual savings against your plan, and
confirm before supported purchases use protected money. Open with `/envelope`
or `/ge`; `/ge status` prints your wallet and goal progress.

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
and amount. The main window is 400 × 500 UI units; the goal list and expense
chooser open separately. Coin amounts use native gold, silver, and copper icons.

Presets include First Mount & Riding (100g by level 40), Epic Mount & Riding
(1,000g by level 60), Class Training, and Profession Training. Mount amounts are
editable starter budgets; trainer prices and discounts can differ. A preset
only becomes active when saved. Selecting an existing preset opens that goal.

The default initial investment is **20% of your current wallet**, capped by the
goal amount and money left after existing allocations and the next two levels
of class training. Change the percentage or enter a coin override before saving.
If you cannot afford that training, or a relevant price is unknown, the initial
investment is zero. Training protection applies to the initial investment even
when you have not enabled ongoing Class Training expenses.

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
your wallet. Uncheck **Track this goal** and save to release its allocation.

Old goals migrate to your current level with a safe initial allocation; old
planned reserves are not treated as money you actually saved. Income received
while logged out is not retrospectively assigned to goals.

## Expenses and Class Training

Below level 60, saving a new goal first asks whether you want to choose expenses.
The same prompt applies to custom goals and presets. **Customize expenses**
opens this choice again; level-60 characters can opt in manually.

Check **Class training** to use the bundled level 1–60 catalog for your class:
1,374 spell/rank entries across the nine classes. It works before visiting a
trainer. The chooser displays costs relevant to your goal's start and target
levels; uncheck abilities or ranks you do not plan to learn. Known spells and
ineligible race/talent ranks do not require funds.

Class training remains a **shared expense budget**, separate from your mount
or other goal's final amount. It protects current training plus the next two
levels, while the Plan table shows future costs at their required levels. Two
goals including the same training do not count its cost twice. If either active
goal selects a rank, the shared budget includes it. Intended trainer purchases
may use this training money; spending goal savings still requires confirmation.

Bundled prices are **base estimates**, not guaranteed current server quotes.
Visiting a trainer replaces matching estimates with your observed prices and
adds new observed ranks. Show all trainer filters to capture future and known
services. Unchecked ranks stay excluded when prices refresh. Unknown prices are
flagged; the known-cost total cannot guarantee enough money for unknown costs.
See the research document for catalog provenance and eligibility limitations.

Profession Training uses observed profession ranks and recipes. A riding quote
replaces an itemized mount's starter estimate. You can also add manual expenses
with individual amounts and due levels. Checked, unpaid non-class expenses
set an itemized goal's amount and follow its savings curve. Mark manual costs
excluded once paid. **Apply choices** updates the editor; **Save goal** persists
it. Cancel or Escape discards checklist changes.

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

Live-client validation remains necessary. Enable `/console scriptErrors 1`,
create a test goal, and check the compact layout, coin textures, trainer quotes,
known-spell detection, expense exclusions, level-up costs, and `/ge status`.
Exercise cancel/confirm, quantity purchases, buyback, repairs, training, and
auctions. Confirm that repeat warnings stay quiet for two minutes after
**Spend anyway**, then return when the cooldown expires. Check controller
behavior and interactions with other addons too.

API references: [Forever merchant UI](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_UIPanels_Game/Mainline/MerchantFrame.lua),
[trainer UI](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_TrainerUI/Mainline/Blizzard_TrainerUI.lua),
and [auction UI](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_AuctionHouseUI/Shared/Blizzard_AuctionHouseFrame.lua).
