local _, ns = ...

-- Player-supplied Classic farming ideas. Prices and demand vary by realm.
ns.GoldTipBrackets = {
    {min=1,max=10,label="Levels 1–10",tips={
        {title="Small Eggs from starter-zone birds",text="Check birds while questing in your own starting area. Sell Small Eggs to cooks when their prices justify farming.",factions={
            Alliance={title="Small Eggs while questing in Teldrassil",text="Strigid owls can supply Small Eggs for cooks. Use this option if you are already in Teldrassil; avoid a long trip just for eggs."},
            Horde={title="Small Eggs while questing in Mulgore",text="Swoops can supply Small Eggs for cooks. Use this option if you are already in Mulgore; avoid a long trip just for eggs."},
        }},
        {title="Copper on starter-zone mountain edges",text="Gather near your own starting quests and avoid dangerous caves. Compare Copper Ore and Copper Bar prices before smelting.",factions={
            Alliance={title="Copper near Alliance starting quests",text="Gather along mountain edges in Elwynn or Dun Morogh if you are questing there. Avoid dangerous caves; compare Copper Ore and Copper Bar prices."},
            Horde={title="Copper near Horde starting quests",text="Gather along mountain edges in Durotar or Mulgore if you are questing there. Avoid dangerous caves; compare Copper Ore and Copper Bar prices."},
        }},
        {title="Limited-stock vendor recipes",text="Check recipe vendors while passing through towns. Buy for resale only when the Auction House margin covers purchase costs and fees."},
    }},
    {min=11,max=20,label="Levels 11–20",tips={
        {title="Sell materials from local quests",text="Keep useful meat, cloth, and leather from the enemies you already fight. Check Auction House demand before traveling to farm.",factions={
            Alliance={title="Magic Dust from Westfall Dust Devils",text="Try this while questing in Westfall. Drops are uncommon, so treat dust as a bonus rather than a reason to travel far."},
            Horde={title="Skin beasts while questing in the Barrens",text="With Skinning, sell leather from the beasts you already kill. Compare material prices against vendor value before listing."},
        }},
        {title="Light Feathers from local birds",text="Mages and priests use Light Feathers for Slow Fall and Levitate. Check birds near your own quest routes.",factions={
            Alliance={title="Light Feathers from Westfall fleshrippers",text="Farm these birds while questing in Westfall. Mages and priests use feathers for Slow Fall and Levitate; keep Small Eggs for cooks too."},
            Horde={title="Light Feathers from Barrens harpies",text="Farm harpies while questing in the Barrens. Mages and priests use feathers for Slow Fall and Levitate."},
        }},
        {title="Fish around your quest hubs",text="Fish nearby waters while questing and compare raw fish prices with cooking costs before spending materials.",factions={
            Alliance={title="Fish around Alliance quest hubs",text="Try nearby waters in Loch Modan or Westfall while questing. Compare raw fish prices with cooking costs before spending materials."},
            Horde={title="Deviate Fish from Barrens oases",text="Fish the oasis waters while questing nearby. Compare selling raw fish with cooking Savory Deviate Delight if you have the recipe."},
        }},
    }},
    {min=21,max=30,label="Levels 21–30",tips={
        {title="Sell useful drops while questing",text="Gather useful materials from enemies near your own quest hubs. Compare Auction House demand with vendor value.",factions={
            Alliance={title="Thelgen Rock spiders in Wetlands",text="Farm Spider's Silk and Large Venom Sacs: two sellable materials from the same enemies."},
            Horde={title="Skin beasts near your Hillsbrad quests",text="With Skinning, gather leather from beasts around your Tarren Mill quest routes. Sell useful meat too; compare Auction House prices with vendor value."},
        }},
        {title="Swiftthistle from Briarthorn and Mageroyal",text="Gather along your own quest routes. Swiftthistle supplies Thistle Tea and Swiftness Potions.",factions={
            Alliance={title="Swiftthistle from Briarthorn and Mageroyal",text="Gather along your Redridge or Wetlands quest routes. Swiftthistle supplies Thistle Tea and Swiftness Potions."},
            Horde={title="Swiftthistle from Briarthorn and Mageroyal",text="Gather in the Barrens or near Tarren Mill in Hillsbrad. Swiftthistle supplies Thistle Tea and Swiftness Potions."},
        }},
        {title="Oily Blackmouth from coastal schools",text="Fish nearby coastal schools rather than traveling into enemy territory. The fish supply Blackmouth Oil for consumables, including Free Action Potions.",factions={
            Alliance={title="Oily Blackmouth along the Wetlands coast",text="Try coastal schools near your Wetlands routes. The fish supply Blackmouth Oil for consumables, including Free Action Potions."},
            Horde={title="Oily Blackmouth near Ratchet",text="Try coastal schools near the neutral port of Ratchet. The fish supply Blackmouth Oil for consumables, including Free Action Potions."},
        }},
    }},
    {min=31,max=40,label="Levels 31–40",tips={
        {title="Arathi earth elementals",text="Best toward the upper end of this bracket. Elemental Earth supplies Greater Nature Protection Potions and Elemental Sharpening Stones."},
        {title="Badlands Lesser Rock Elementals",text="An alternative to Arathi when crowded: sell Elemental Earth, stone, and vendor loot. Pick either elemental location; you do not need both."},
        {title="Badlands Scalding Whelps near level 40",text="Sell Small Flame Sacs for Fire Protection Potions. A Dark Whelpling is a rare bonus rather than reliable income."},
    }},
    {min=41,max=50,label="Levels 41–50",tips={
        {title="Lost Rigger Cove pirates in Tanaris",text="A steady Mageweave, coin, and vendor-loot grind rather than a rare-drop gamble."},
        {title="Feral Scar yetis in Feralas",text="With Skinning, combine leather sales with ordinary loot. Start with the lower-level yetis."},
        {title="Wildvine from Purple Lotus",text="Try Hinterlands ruin areas. Wildvine supplies crafted gear; check its market price before committing to a gathering route."},
    }},
    {min=51,max=59,label="Levels 51–59",tips={
        {title="Jadefire satyrs in Felwood",text="Sell Felcloth and Runecloth. Demonic Runes are soulbound: their benefit is saving on your own consumables."},
        {title="Eastern Plaguelands carrion grubs",text="Farm carrion grubs and devourers for Larval Acid, used in crafts such as Hide of the Wild."},
        {title="Winterfall furbolgs in Winterspring",text="Best toward the upper end of this bracket. Sell Winterfall Firewater, with Runecloth providing additional income."},
    }},
    {min=60,max=60,label="Level 60",tips={
        {title="Essence of Air in northwestern Silithus",text="Kill Dust Stormers. Mobs are limited, so choose quieter hours to reduce competition."},
        {title="Essence of Water in Irontree Woods",text="Kill Felwood's Toxic Horrors when essence prices justify the competition."},
        {title="Rich Thorium in eastern Silithus hives",text="Mine the hive tunnels for a chance at Arcane Crystals. Stealth classes can bypass enemies more easily."},
        {title="Devilsaur Leather in Un'Goro",text="Requires Skinning and the ability to kill elite devilsaurs. Check demand for Devilsaur gear before farming."},
        {title="Twilight cultists in Silithus",text="Sell Encrypted Twilight Texts and cultist outfit pieces used for summon activities."},
        {title="Stonescale Eels on the Tanaris coast",text="Stonescale Oil supplies raid Alchemy recipes. Check fishing time-of-day effects before planning a session."},
        {title="Winter Squid during its season",text="Used for Grilled Squid. Seasonal availability can create a stockpiling opportunity."},
        {title="Dire Maul East jump runs with a partner",text="A warrior/healer pair can combine boss loot with herbs and the mining opportunity near the final boss."},
        {title="Scholomance with Dark Rune reservations",text="Dark Runes are tradable mana consumables. Agree on and state the loot reservation before anyone joins."},
        {title="Rogue: pickpocket Blackrock Depths",text="Earn coins and vendor loot inside an instance. Efficient routes and safe resets matter."},
        {title="Hunter: Dire Maul North tribute runs",text="Sell loot and potentially tribute buffs. Requires practice, equipment, and the correct Classic dungeon behavior."},
        {title="Warrior: offer dungeon tanking",text="When groups need a tank, advertise a clear fee or an agreed unwanted-loot arrangement for specific runs."},
        {title="Alchemy: Heart of Fire to Elemental Fire",text="One Heart of Fire becomes three Elemental Fire. Buy only when the price spread pays; account for the transmute cooldown."},
        {title="Tailoring: Felcloth into Mooncloth",text="Each craft uses two Felcloth and a four-day cooldown. Compare the Mooncloth sale price against material costs."},
        {title="Sell profession leveling kits",text="Bundle exact materials for a defined skill range, such as Engineering 1–150. Charge for sourcing convenience rather than guessing which crafts will sell."},
    }},
}

local factionViews = {}

function ns.GetGoldTipBracket(level, faction)
    faction = faction or (UnitFactionGroup and UnitFactionGroup("player"))
    if faction ~= "Alliance" and faction ~= "Horde" then faction = "Neutral" end
    for _,bracket in ipairs(ns.GoldTipBrackets) do
        if level>=bracket.min and level<=bracket.max then
            local views = factionViews[bracket]
            if not views then views = {}; factionViews[bracket] = views end
            if not views[faction] then
                local view = {min=bracket.min,max=bracket.max,label=bracket.label,tips={}}
                for _,tip in ipairs(bracket.tips) do
                    view.tips[#view.tips+1] = tip.factions and tip.factions[faction] or tip
                end
                views[faction] = view
            end
            return views[faction]
        end
    end
end
