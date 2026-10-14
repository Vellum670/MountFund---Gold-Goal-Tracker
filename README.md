# Gold Envelope for WoW: Forever

Save toward level-based goals and confirm before a supported purchase would use
reserved savings. Open the addon with `/envelope` or `/ge`; `/ge status` prints
your current balance, reserve, and spending allowance.

## Install

Copy the `GoldEnvelope` folder into the Forever client's `Interface/AddOns/`
folder. The path should end in `AddOns/GoldEnvelope/GoldEnvelope.toc`. Restart
the client after first installation, enable the addon, and enter `/envelope`.
The interface version is `16001` (Forever 1.60.1).

## Savings goals

Enter a goal name, target level, and final amount in gold, silver, and copper.
Goals and settings are saved separately for each character. The preset picker
includes First Mount & Riding (100g by level 40), Epic Mount & Riding (1,000g by
level 60), Class Training, and Profession Training. Mount amounts are editable
starter budgets, not guaranteed quotes or automatic reputation-discount
calculations. No preset reserves money until you save it. Selecting an existing
preset opens its saved goal rather than creating a duplicate.

Reserve money for multiple goals by adding them; their current targets add
together. Choose a goal from the left-hand list to edit it. The UI uses the game's
gold/silver/copper artwork, dark panels, metallic borders, and gold headings.

Targets mean **money to have saved by a level**, rather than money to earn at
that level. Money remains in your wallet; the addon maintains a planned reserve.
The spending allowance is `max(0, current balance - total reserve today)`.

Each simple budget starts at 0 copper at level 1. The default curve (2) grows slowly early
and more quickly later. Curves 3 and 4 put even more saving at later levels; 1
uses equal additions between levels. For example, an illustrative 10g goal at
level 21 with curve 2 reserves 2g 50s at level 11 and the full 10g at level 21.
These are user-defined budgeting targets, **not estimates of Forever earnings**.

Optional checkpoints let you set exact cumulative amounts at intermediate
levels. The same curve interpolates between adjacent checkpoints. Checkpoints
must stay within the final goal and never decrease. The scrollable table lists
every level's cumulative reserve and the addition since the prior level in
aligned columns, marks checkpoints, and highlights your current level.
Click **Save goal** to persist editor changes.

The full goal stays reserved after its target level. Uncheck **Reserve money
for this goal** and save when ready to spend it on its intended purpose. Gold
earned above the reserve is available to spend. If you are already behind the
plan, any further positive-cost supported purchase requires confirmation.

## Optional itemized planning

When a character below level 60 first saves a new goal, the addon asks whether
they want to choose individual expenses or keep a simple budget. The same prompt
applies to all custom and preset goals. It does not display spell or expense
checkboxes until the player opts in. Existing goals can use **Customize planning**
to request the same choice; level-60 characters can opt in manually.

For Class Training, visit your character's class trainer with all service filters
shown, including unavailable and known abilities. The addon records the trainer's
spell names, ranks, required levels, and quoted coin prices. This works for each
class through its own trainer; it does not ship a presumed complete spell-price
database. Uncheck ranks you do not intend to train. Profession Training works
the same way for profession ranks and recipes.

Trainer prices are captured when the trainer opens or updates, and refresh
itemized saved goals and open checklists. Missing entries remain unobserved;
missing prices are shown as unknown and excluded from the known-cost total.
Filters and different trainers can limit the available list. Previously captured
entries are retained when absent from a later filtered list. Exclusions persist
across price updates, and observed learned ranks stop reserving money. Prices
may change with discounts or game updates, so revisiting a trainer refreshes
the quote. An observed riding quote replaces an itemized mount's starter estimate.

Any goal can have a checklist of manually entered purchases with individual
amounts and due levels. Each checked, unpaid cost saves along the selected curve
until its own due level; costs beyond the goal's target level are excluded. Its
known selected costs determine the final amount, so amount inputs in the main
editor are read-only for itemized plans. Custom checkpoints belong to simple
budgets; itemized plans use their individual expense levels instead. Mark a
manual expense as excluded once paid. **Apply choices** updates the editor;
**Save goal** persists it. Cancel or Escape discards checklist edits.

## Before-purchase warnings

When a supported action would leave you below your current reserve, a warning
shows its cost, remaining balance, reserve at your level, and resulting shortfall.
**Cancel** or Escape spends nothing. **Spend anyway** authorizes only that action.
Reaching the reserve exactly does not trigger a warning. Free actions do not
trigger warnings.

The addon checks the selection, price, funds, and reserve again on confirmation.
Changed selections or prices cancel the pending action; changes to funds or
goals refresh the warning. Closing the merchant, trainer, or auction house
cancels pending actions. Expired commodity quotes cannot be accepted.

Initial native UI coverage:

- Vendor right-click purchases and quantity purchases through the stack selector.
- Vendor buyback and the repair-all button using your own money.
- The trainer's Train button, including profession confirmations.
- Modern auction item buyout/bid confirmations and commodity Buy Now confirmations.

This is an advisory guard for these UI actions, not a lock on your wallet.
Cursor/drag vendor buying, single-item repair, mail, trades, flight payments,
auction deposits/cancellation fees, gossip purchases, controller actions that
call Blizzard functions directly, macros, and other addons' automatic purchases
are not intercepted. Those actions still update the displayed balance. Blizzard's
purchase APIs are not replaced. Disable competing auto-buy/auto-repair features
when trying the warning flow.

## Validation

The Lua model and purchase confirmation flow have automated tests with mocked
WoW APIs. Run `lua tests/run.lua` from this repository, using Lua 5.1 or later
(`unpack` compatibility is provided by the test harness).

Live-client validation is still required: `/console scriptErrors 1`, create a
small test goal, and try vendor purchases below/at/above the reserve, quantity
buying, cancel/confirm, buyback, repair-all, training, and auctions. Check both
mouse and controller behavior, interactions with your other addons, and that
closing a window or letting a quote expire cancels a pending purchase.
Also check the new frame layout and coin textures, the optional-planning prompt,
trainer price capture (including future ranks), retained exclusions, learned
spell detection, and your profession trainers' recipe lists.

API references: [Forever merchant UI](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_UIPanels_Game/Mainline/MerchantFrame.lua),
[trainer UI](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_TrainerUI/Mainline/Blizzard_TrainerUI.lua),
and [auction UI](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_AuctionHouseUI/Shared/Blizzard_AuctionHouseFrame.lua).
