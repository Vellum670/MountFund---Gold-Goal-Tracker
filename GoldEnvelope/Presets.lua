local _, ns = ...

-- Starting budgets, not guaranteed trainer quotes. Keep them editable and opt-in.
-- Source context: https://www.wowhead.com/forever/spell=33388/apprentice-riding
-- https://www.warcrafttavern.com/forever/guides/riding/
ns.Presets = {
    { id = "mount-first", name = "First mount & riding", targetLevel = 40,
        targetCopper = 100 * 10000, icon = "Interface\\Icons\\Ability_Mount_RidingHorse",
        note = "Mount budget: edit to match your trainer's price." },
    { id = "mount-epic", name = "Epic mount & riding", targetLevel = 60,
        targetCopper = 1000 * 10000, icon = "Interface\\Icons\\Ability_Mount_ArmoredBrownWolf",
        note = "Mount budget: edit to match your trainer's price." },
    { id = "class-training", name = "Class training", targetLevel = 60,
        targetCopper = 0, icon = "Interface\\Icons\\INV_Misc_Book_09",
        note = "Class-wide base prices included; trainer quotes override them." },
    { id = "profession-training", name = "Profession training", targetLevel = 60,
        targetCopper = 0, icon = "Interface\\Icons\\Trade_BlackSmithing",
        note = "Visit profession trainers to capture ranks, recipes and prices." },
}

function ns.FindPreset(id)
    for _, preset in ipairs(ns.Presets) do
        if preset.id == id then return preset end
    end
end

function ns.NewPresetGoal(id)
    local preset = ns.FindPreset(id)
    if not preset then return nil end
    return { name = preset.name, presetID = preset.id, targetLevel = preset.targetLevel,
        targetCopper = preset.targetCopper, curve = 0, active = true, milestones = {}, expenses = {},
        includeClassTraining = id == "class-training", initialPercent = 20 }
end
