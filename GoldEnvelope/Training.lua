local _, ns = ...
local Model = ns.Model

local function sourceFor(name)
    if C_Spell and C_Spell.GetSpellName then
        if name == C_Spell.GetSpellName(33388) then return "mount-first" end
        if name == C_Spell.GetSpellName(33391) then return "mount-epic" end
    end
    if IsTradeskillTrainer and IsTradeskillTrainer() then return "profession" end
    return "class"
end

function ns.SyncExpenses(goal)
    if goal.planMode ~= "items" then return end
    local source = goal.presetID == "class-training" and "class"
        or goal.presetID == "profession-training" and "profession" or goal.presetID
    local existing = {}
    local provisionalSelection
    goal.expenses = goal.expenses or {}
    for _, expense in ipairs(goal.expenses) do
        existing[expense.key] = expense
        if expense.estimated then provisionalSelection = expense.selected end
    end
    for key, quote in pairs(ns.db.trainerCatalog or {}) do
        if quote.source == source then
            local expense = existing[key]
            if not expense then
                expense = { key = key, selected = provisionalSelection ~= false }
                goal.expenses[#goal.expenses + 1] = expense
                existing[key] = expense
            end
            for field, value in pairs(quote) do expense[field] = value end
            expense.copper = quote.copper
        end
    end
    -- A provisional mount budget becomes a real quote once observed.
    if source == "mount-first" or source == "mount-epic" then
        local hasQuote = false
        for _, expense in ipairs(goal.expenses) do
            if expense.source == source and not expense.estimated then hasQuote = true end
        end
        if hasQuote then
            for index = #goal.expenses, 1, -1 do
                if goal.expenses[index].estimated then table.remove(goal.expenses, index) end
            end
        end
    end
    table.sort(goal.expenses, function(a, b)
        if a.level ~= b.level then return a.level < b.level end
        if a.name ~= b.name then return a.name < b.name end
        return a.key < b.key
    end)
    goal.targetCopper = Model.ExpenseTotal(goal)
end

function ns.EnableItemPlanning(goal)
    goal.planMode, goal.planDecision = "items", "items"
    goal.expenses = goal.expenses or {}
    if #goal.expenses == 0 and goal.targetCopper > 0 and goal.presetID ~= "class-training" then
        goal.expenses[1] = { key = "manual:initial", name = goal.name ~= "" and goal.name or "Goal expense",
            level = goal.targetLevel, copper = goal.targetCopper, selected = true,
            estimated = goal.presetID == "mount-first" or goal.presetID == "mount-epic", source = "manual" }
    end
    ns.SyncExpenses(goal)
end

-- Quote every rank exposed by the current trainer, including unavailable future
-- ranks. Do not change the player's trainer filters or treat omissions as learned.
function ns.CaptureTrainerPrices()
    if not ns.db or not GetNumTrainerServices or not GetTrainerServiceInfo or not GetTrainerServiceCost then return end
    if C_Trainer and Enum and Enum.TrainerType and C_Trainer.GetTrainerType
        and C_Trainer.GetTrainerType() == Enum.TrainerType.Pet then return end
    ns.db.trainerCatalog = ns.db.trainerCatalog or {}
    local _, class = UnitClass("player")
    for index = 1, GetNumTrainerServices() do
        local name, serviceType, icon, requiredLevel, rank = GetTrainerServiceInfo(index)
        local cost = GetTrainerServiceCost(index)
        if name and (serviceType == "available" or serviceType == "unavailable" or serviceType == "used") then
            local source = sourceFor(name)
            local level = GetTrainerServiceLevelReq and GetTrainerServiceLevelReq(index) or requiredLevel
            level = math.max(1, level or 1)
            if level <= Model.MAX_LEVEL then
                local key = table.concat({ source, class or "UNKNOWN", name, rank or "", tostring(level) }, ":")
                local previous = ns.db.trainerCatalog[key]
                if type(cost) ~= "number" or cost < 0 or cost > Model.MAX_COPPER or cost ~= math.floor(cost) then cost = nil end
                if serviceType == "used" and previous then cost = previous.copper end
                ns.db.trainerCatalog[key] = { key = key, source = source, class = class, name = name,
                    rank = rank, level = level, copper = cost, paid = serviceType == "used", icon = icon,
                    trainer = UnitName and UnitName("npc") or "Trainer", observedAt = time and time() or 0 }
            end
        end
    end
    for _, goal in ipairs(ns.db.goals) do ns.SyncExpenses(goal) end
    ns.Changed()
    if ns.CatalogChanged then ns.CatalogChanged() end
end
