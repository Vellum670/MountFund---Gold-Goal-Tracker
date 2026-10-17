local _, ns = ...
ns.ADDON_ICON = "Interface\\AddOns\\Mountfund\\Media\\Mountfund.tga"

-- Starting budgets, not guaranteed trainer quotes. Keep them editable and opt-in.
-- Mount amounts cover both riding and a mount; they are editable allowances.
ns.Presets = {
    { id = "mount-first", name = "Lvl 40 Mount", targetLevel = 40,
        targetCopper = 100 * 10000, icon = "Interface\\Icons\\Ability_Mount_RidingHorse",
        note = "Mount budget: edit to match your trainer's price." },
    { id = "mount-epic", name = "Epic Mount", targetLevel = 60,
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
        includeClassTraining = true }
end

function ns.GoalIcon(goal)
    local preset=goal and ns.FindPreset(goal.presetID)
    return ns.Model.NormalizeIcon(goal and goal.icon) or (preset and preset.icon) or ns.ADDON_ICON
end
