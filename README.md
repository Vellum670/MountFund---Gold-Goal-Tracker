# Mountfund — Gold Goal Tracker for WoW: Forever

Save for mounts and other goals, budget class training, and track progress by level, date, or play time.

**[Download Mountfund](https://github.com/Vellum670/WoW-Forever-Addon/raw/refs/heads/main/downloads/Mountfund.zip)** · [Changelog](CHANGELOG.md)

## Install

1. Extract the ZIP into your Forever client's `Interface/AddOns/` folder.
2. Check the path: `AddOns/Mountfund/Mountfund.toc`.
3. Restart WoW, enable Mountfund, and type **`/mf`**.

## Get started

- Choose **New** or **Presets**, set an amount, and click the deadline button to cycle between level, date, and play time.
- **All goals** shows savings and grouped targets. Click a goal to edit it; hover for details.
- **Class training** protects upcoming costs. Click ability icons to include/exclude them across all goals; grey means excluded. Trainer visits update price estimates.
- Use **Additional Expenses** for other purchases and **Savings plan** for your schedule.

**Edits save automatically. Escape saves and closes.** Savings stay in your wallet; spending can reduce progress. Unchecking **Track this goal** releases its saved allocation.

## Useful controls

- **`/mf status`** — chat summary; also appears on login, reload, and goal milestones.
- **Settings** — spending confirmations and toast options. Hover a toast to keep it visible.
- **Report bug** beside Close — copy the GitHub link into your browser.

Spending confirmations cover supported vendor, trainer, repair-all, and auction actions. **Spend anyway** silences them for two minutes.

<details>
<summary><strong>Upgrading from Gold Envelope? Keep your saved goals.</strong></summary>

Exit WoW and back up `WTF/Account/<account>/<realm>/<character>/SavedVariables/`.
Copy `GoldEnvelope.lua` there to `Mountfund.lua`; back up any existing destination first.
No file-content edits are needed.

Remove `Interface/AddOns/GoldEnvelope/`, then install the new `Mountfund/` folder.
Your old data imports on login. `/ge` and `/envelope` still work.

</details>
