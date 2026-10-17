# MountFund — Gold Goal Tracker for WoW: Forever

Save for mounts and other goals, budget class training, and track progress by level, date, or play time.

**[Download MountFund](https://github.com/Vellum670/WoW-Forever-Addon/raw/refs/heads/main/downloads/Mountfund.zip)** · [Changelog](CHANGELOG.md)

## Install

1. Extract the ZIP into your Forever client's `Interface/AddOns/` folder.
2. Restart WoW, enable MountFund, and type **`/mf`**.

## Get started

- Open the **MountFund character-sheet tab** or **`/mf`**.
- Choose **New goal** or **Presets**, set an amount and deadline, then **Create goal**. Existing goals save edits automatically.
- Click a goal’s icon to search and choose its image.
- Drag the dotted goal handles to set funding priority. Targets adjust to shortfalls or surplus; completed history starts collapsed.
- Opening Goals selects your first active priority. Gold tips follow your level and faction.
- **Savings plan** shows your schedule. **Additional Expenses** adds individual purchases.
- In **Class training**, left-click an ability for details; right-click to include/exclude it across all goals. Grey means excluded. Trainer visits update estimates.
- Funded goals offer **Mark complete** or **Later**. Confirming completion releases the allocation and keeps the goal in history.

**Gold stays in your wallet; spending can reduce progress.** Unchecking **Track this goal** releases its allocation. Escape saves and closes.

**New income goes 75% toward active goals and 25% into a shared spending pool.**
Class training comes from that spending pool alongside food, water, and other
purchases. Unused spending money carries across levels and reloads. Using the
pool does not pause goal contributions from future income. Small loot amounts
carry fractional copper forward so they receive the same split over time.

Existing goal savings stay allocated when upgrading. Spending beyond the pool,
including training that the pool cannot cover, can reduce goal savings. Purchase
confirmations check your actual wallet again. With class-training protection on,
included training asks for confirmation before using goal savings. The header
shows spending remaining after training or the amount training is short. If all active
goals are full, any excess stays available to spend.

## Useful controls

- **`/mf`** — open MountFund; **`/mf status`** — chat summary.
- **Cogwheel** — warnings, training protection, summaries, tips, and toast options. Hover a toast to keep it visible.
- **Bug icon** — copy the GitHub issue link into your browser.

Excluded-ability warnings appear before buying a greyed-out class spell or ability, regardless of protected gold. Disable training protection in Settings to release its reserve and hide training costs. **Spend anyway** silences excluded-ability warnings for two minutes by default; change this in Settings (30 seconds–60 minutes).

Income-based targets estimate rising earnings. Training uses Classic base costs; visiting a trainer captures Forever-specific quotes.
