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

local function known(spellID)
    if not spellID then return false end
    if IsPlayerSpell then return IsPlayerSpell(spellID) end
    if C_SpellBook and C_SpellBook.IsSpellKnown then return C_SpellBook.IsSpellKnown(spellID) end
    return false
end

function ns.ClassCatalog()
    local _, class = UnitClass("player")
    local raceID
    if UnitRace then local _, _, id = UnitRace("player"); raceID = id end
    local rows, matched = {}, {}
    for _, base in ipairs(ns.ClassTrainingData[class] or {}) do
        local entry = {}
        for key, value in pairs(base) do entry[key] = value end
        entry.key, entry.source, entry.class = "class:" .. base.spellID, "class", class
        entry.name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(base.spellID) or base.name
        entry.paid, entry.priceSource = known(base.spellID), "base price"
        entry.eligible = not base.requiresSpell or known(base.requiresSpell)
        if base.races and raceID then
            local eligibleRace = false
            for _, id in ipairs(base.races) do if id == raceID then eligibleRace = true end end
            entry.eligible = entry.eligible and eligibleRace
        end
        for key, quote in pairs(ns.db.trainerCatalog or {}) do
            if quote.source == "class" and quote.class == class
                and (quote.spellID == base.spellID or (quote.name == entry.name and quote.level == base.level
                    and (quote.rank == base.rank or not quote.rank or quote.rank == ""))) then
                entry.copper, entry.paid, entry.priceSource = quote.copper, quote.paid or entry.paid, "trainer quote"
                entry.observedAt, entry.trainer = quote.observedAt, quote.trainer
                matched[key] = true
                break
            end
        end
        rows[#rows + 1] = entry
    end
    for key, quote in pairs(ns.db.trainerCatalog or {}) do
        if quote.source == "class" and quote.class == class and not matched[key] then
            local entry = {}
            for field, value in pairs(quote) do entry[field] = value end
            entry.key, entry.eligible, entry.priceSource = key, true, "trainer quote"
            rows[#rows + 1] = entry
        end
    end
    table.sort(rows, function(a,b) if a.level ~= b.level then return a.level < b.level end return a.key < b.key end)
    return rows
end

function ns.TrainingByLevel(goal)
    local totals, unknown = {}, 0
    local selections = {}
    for _, expense in ipairs(goal and goal.expenses or {}) do
        if expense.source == "class" then selections[expense.key] = expense.selected end
    end
    for _, entry in ipairs(ns.ClassCatalog()) do
        if selections[entry.key] ~= false and not entry.paid and entry.eligible then
            if entry.copper then totals[entry.level] = (totals[entry.level] or 0) + entry.copper else unknown = unknown + 1 end
        end
    end
    return totals, unknown
end

function ns.TrainingRunway(goal, force)
    local level = UnitLevel("player")
    local enabled, selected = force or (goal and goal.includeClassTraining), {}
    if not goal then
        for _, g in ipairs(ns.db.goals) do
            if g.active and g.includeClassTraining then enabled = true
                for _, e in ipairs(g.expenses or {}) do
                    if e.source == "class" then selected[e.key] = selected[e.key] or e.selected or false end
                end
            end
        end
    else
        for _, e in ipairs(goal.expenses or {}) do if e.source == "class" then selected[e.key] = e.selected end end
    end
    if not enabled then return 0, true end
    local amount, complete = 0, true
    for _, entry in ipairs(ns.ClassCatalog()) do
        local pastDue = entry.priceSource == "trainer quote" and entry.level < level
        if not entry.paid and entry.eligible and (entry.level >= level or pastDue) and entry.level <= math.min(60,level+2)
            and (selected[entry.key] ~= false) then
            if entry.copper then amount = amount + entry.copper else complete = false end
        end
    end
    return amount, complete
end

function ns.SyncExpenses(goal)
    if goal.planMode ~= "items" and not goal.includeClassTraining then return end
    local source = goal.presetID == "class-training" and "class"
        or goal.presetID == "profession-training" and "profession" or goal.presetID
    local existing = {}
    local provisionalSelection
    goal.expenses = goal.expenses or {}
    for _, expense in ipairs(goal.expenses) do
        existing[expense.key] = expense
        if expense.estimated then provisionalSelection = expense.selected end
    end
    local quotes = {}
    for key, quote in pairs(ns.db.trainerCatalog or {}) do if quote.source == source and source ~= "class" then quotes[key] = quote end end
    if goal.includeClassTraining then for _, quote in ipairs(ns.ClassCatalog()) do quotes[quote.key] = quote end end
    -- Preserve old exclusions when migrating name-based captured rows to spell IDs.
    for index = #goal.expenses, 1, -1 do
        local old = goal.expenses[index]
        if old.source == "class" and not quotes[old.key] then
            for key, quote in pairs(quotes) do
                if quote.source == "class" and quote.name == old.name and quote.level == old.level and quote.rank == old.rank then
                    old.key = key; existing[key] = old; break
                end
            end
        end
    end
    for key, quote in pairs(quotes) do
        if quote.source == source or (goal.includeClassTraining and quote.source == "class") then
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
    if goal.planMode == "items" then goal.targetCopper = Model.ExpenseTotal(goal) end
end

function ns.EnableItemPlanning(goal)
    goal.planMode, goal.planDecision = "items", "items"
    if goal.presetID == "class-training" then goal.includeClassTraining = true end
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
