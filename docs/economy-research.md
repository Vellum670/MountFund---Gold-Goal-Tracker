# Economy research and budgeting assumptions

Research date: October 14, 2026. Economy model introduced in version 0.3.0;
UI, selection, and scheduling notes updated for version 0.4.0.

## What can be supported by the evidence

There is no verified universal table of how much gold a Forever character
should own at each level. Quest route, loot sales, training choices, professions,
auction trading, gifts, and spending produce different balances. Gold Envelope
therefore uses researched **relative earning weights** to schedule a user's goal,
then measures progress using actual wallet changes. These weights do not predict
absolute income or certify that every goal is affordable.

The old default squared curve put 37.87% of a level-40 goal's amount at level 25
when starting at level 1. The new quest-based curve puts approximately 24.88%
there. For a 100g goal with no initial investment, that is roughly 24.88g instead
of 37.87g. A newly created level-25 goal starts at level 25, with only its safe
initial investment due immediately; it does not impose historical targets.

## Relative earning weights

Source: [CMaNGOS Classic quest and XP database](https://github.com/cmangos/classic-db/blob/22b51464f1625f6ef6275771de1f5466c6f5d19e/Full_DB/ClassicDB_1_12_1_z2815.sql.gz),
pinned to commit `22b51464f1625f6ef6275771de1f5466c6f5d19e`.
This is a **Classic fallback**, not an authoritative Forever economy export.

The analysis used 3,571 quests with levels 1–60, nonnegative cash rewards,
no repeatable flag, and suggested party size at most five. For each level:

1. Pool quest levels within two levels of it to reduce sparse-level noise.
2. Trim the largest 10% of cash rewards and take the mean remaining reward.
3. Estimate quest XP using the database's max-level cash conversion, and take
   the median positive quest XP. [CMaNGOS quest XP code](https://github.com/cmangos/mangos-classic/blob/master/src/game/Quests/QuestDef.cpp)
   uses `RewMoneyMaxLevel / 0.6` for quest levels through 60.
4. Multiply the mean cash reward by XP needed for the level divided by the
   estimated quest XP. This is a relative quest-cash opportunity proxy.
5. Smooth descending artifacts with isotonic regression to obtain nondecreasing
   earning weights. Floor extremely small weights to one.

The resulting weights are committed in
[IncomeWeights.lua](../GoldEnvelope/Data/IncomeWeights.lua). A destination-level
weight corresponds to earning while advancing from the preceding level.
Only weights between a goal's starting level and its deadline are normalized.
The remaining amount after its initial investment is distributed using those
normalized weights. Checkpoints normalize their own intervals.

The sample includes different routes and factions; it is not a playable itinerary.
Quest cash alone excludes loot, auction income, profession earnings and expenses,
and Forever changes. Early quest cash is particularly sparse. Using the weights
relatively avoids presenting this incomplete proxy as guaranteed copper income.
Recorded per-character income and spending are observational totals and do not
automatically retrain this default curve.

## Class training facts and prices

The bundled table was independently generated from factual spell IDs, names,
ranks, required levels, base prices, and race restrictions in
[NaowhForever's cached Wowhead training facts](https://github.com/naowh-gaming/NaowhForever/blob/main/Tools/data/training_cache.json).
Snapshot repository commit: `4b6241cf98299be96d029906b605873b103b1f87`;
cache blob: `7b1e5105b82899528917ee29c561121faf8b1cc9`.
No source addon implementation was copied. Its
[training documentation](https://github.com/naowh-gaming/NaowhForever/blob/main/NaowhForever_Training/README.md)
also describes base prices and trainer-price updates.

The filter selects trainer-sourced entries (source 6) at levels 1–60:

| Class | Spell/rank entries |
| --- | ---: |
| Warrior | 98 |
| Paladin | 150 |
| Hunter | 166 |
| Rogue | 85 |
| Priest | 210 |
| Shaman | 165 |
| Mage | 169 |
| Warlock | 147 |
| Druid | 184 |
| **Total** | **1,374** |

This is the full selected class catalog from that snapshot, not a guarantee of
complete current server coverage. Direct Wowhead queries and the Forever DB2
export were inaccessible during research, so those did not independently verify
the current values. Trainer observations override matching base estimates and
can add server-specific entries. Discounts can change the actual quote; Blizzard's
[Forever Legacy system documentation](https://worldofwarcraft.blizzard.com/en-us/news/24307383/get-to-know-the-world-of-warcraft-forever-legacy-system)
describes changes affecting vendor discounts.

Known spells and race-ineligible entries are excluded. Later ranks whose first
rank comes from a talent or quest require that first rank to be known. This is
an eligibility approximation, not a complete recreation of all server-specific
trainer prerequisites. An ability icon controls all its ranks; exclusions persist when new ranks are observed. Observed unpaid overdue
training remains in the current training budget; unobserved historical ranks are
not automatically charged to a newly created goal.

The icon grid uses the current character's class and level. Each ability shows
its next unlearned rank, sorted by the required level, including upgrades beyond
the current goal's deadline. Fully learned abilities are hidden. Quest or talent
prerequisites apply to later trainer ranks as well as the first cataloged rank.

## Initial investment and training coexistence

The automatic background investment defaults to 20% of the current wallet. It cannot exceed
the goal, unallocated cash, or cash remaining after current training and the next
two levels. The editor no longer exposes percentage or override fields. Insufficient training cash
or an unknown relevant price forces the investment to zero.

For a level-25 warrior, the snapshot lists three level-26 purchases at 1g each:
Challenging Shout, Charge rank 2, and Mocking Blow rank 2. Assuming these remain
unlearned and selected, that is 3g of base-price training. With a wallet of
4g 87s 5c, a 20% initial investment is 97s 41c. The safety cap is
1g 87s 5c, less any existing goal allocations. With only 2g, the investment is
zero. Observed discounted prices change this calculation.

Class Training is shared across active goals and counted once. The level table
shows selected training at its required levels; protection keeps a rolling
current-plus-two-level budget. It is not added as the entire lifetime training
cost to a mount goal. Newly received cash funds goals only after this training
budget has room. Training may use its own budget without consuming goal savings.

## Wallet truth and window size

Actual saved allocations plus funded training can never exceed the wallet.
Expected savings are a separate comparison target. When spending consumes goal
money, recorded savings decrease. A deficit does not invent additional coins.
Paused allocations are released. Old planned reserves migrate without being
credited as historical income.

The native [Forever TradeFrame XML](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_UIPanels_Game/Mainline/TradeFrame.xml)
specifies 344 × 446 UI units. Gold Envelope's main frame now uses 400 × 450,
with menus as pages of that same frame. Short lists, presets, settings, training,
expense grids, and savings plans use smaller heights. Automated tests check
dimensions and interactions; visual fit and real game API behavior still need
client validation.

## Calendar and play-time goals

Time goals schedule the remaining goal amount across elapsed calendar time or
hours logged into the character. They default to steady saving; the other named
custom curves can defer more of the target toward the deadline. The quest-income
weights apply only to level goals, since the addon has no evidence for how fast
a particular player will earn gold per hour.

Calendar deadlines use the end of the selected day in the computer's local time
and advance offline. Play-time goals count time in the world, including AFK time,
with a per-character clock saved across sessions; offline and loading-screen time
do not advance that clock. Both compare actual allocations against their expected
target. Passing time never creates savings. Class training retains its rolling
level-based budget independently of a time goal's deadline.
