local _, ns = ...

-- Player-supplied Classic farming ideas. Prices and demand vary by realm.
ns.GoldTipBrackets = {
    {min=1,max=10,label="Levels 1–10",tips={
        {title="Small Eggs from starter-zone birds",text="Farm Mulgore swoops or Teldrassil strigid owls. Sell eggs to cooks; demand can spike during Winter Veil."},
        {title="Copper on starter-zone mountain edges",text="Try Durotar, Elwynn, or Dun Morogh; avoid dangerous caves. Compare Copper Ore and Copper Bar prices before smelting."},
        {title="Limited-stock vendor recipes",text="Check recipe vendors while passing through towns. Buy for resale only when the Auction House margin covers purchase costs and fees."},
    }},
    {min=11,max=20,label="Levels 11–20",tips={
        {title="Magic Dust from Westfall Dust Devils",text="Its long sleep effect gives it PvP demand. Drops are uncommon, so treat dust as a bonus while grinding."},
        {title="Light Feathers from birds and harpies",text="Farm Westfall fleshrippers or Barrens harpies. Mages and priests use feathers for Slow Fall and Levitate; fleshrippers also drop Small Eggs."},
        {title="Deviate Fish from Barrens oases",text="Fish the oasis waters. Compare selling raw fish with cooking Savory Deviate Delight if you have the recipe."},
    }},
    {min=21,max=30,label="Levels 21–30",tips={
        {title="Thelgen Rock spiders in Wetlands",text="Farm Spider's Silk and Large Venom Sacs: two saleable materials from the same enemies."},
        {title="Swiftthistle from Briarthorn and Mageroyal",text="Gather in Hillsbrad or the Barrens. Swiftthistle supplies Thistle Tea and Swiftness Potions."},
        {title="Oily Blackmouth from coastal schools",text="Try Ratchet or Wetlands. The fish supply Blackmouth Oil for consumables, including Free Action Potions."},
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

function ns.GetGoldTipBracket(level)
    for _,bracket in ipairs(ns.GoldTipBrackets) do
        if level>=bracket.min and level<=bracket.max then return bracket end
    end
end
