-- Build class rank snapshots and merge trainer observations into expense plans.
local _, ns = ...
local Model = ns.Model

-- Character-wide choices are keyed by class and ability, never by spell rank.
local abilityNames, localizedAbilities = {}, {}
for class, ranks in pairs(ns.ClassTrainingData) do
    abilityNames[class], localizedAbilities[class] = {}, {}
    for _, rank in ipairs(ranks) do abilityNames[class][rank.spellID] = rank.name end
end

function ns.TrainingAbilityKey(expense)
    local class = expense.class
    if not class then local _, playerClass = UnitClass("player"); class = playerClass end
    local name = abilityNames[class] and abilityNames[class][expense.spellID]
        or localizedAbilities[class] and localizedAbilities[class][expense.name] or expense.name
    return class .. ":" .. name
end

function ns.GetTrainingSelections(real)
    if not real and (ns.testMoneyCopper ~= nil or ns.testPlayerLevel ~= nil) and ns.testTrainingSelections then
        return ns.testTrainingSelections
    end
    return ns.db.classTrainingSelections
end

function ns.InitializeTrainingSelections(extra, real)
    local choices = {}
    local function inherit(goal)
        for _, expense in ipairs(goal.expenses or {}) do
            if expense.source == "class" then
                local key = ns.TrainingAbilityKey(expense)
                if expense.selected == false then choices[key] = false
                elseif choices[key] == nil then choices[key] = true end
            end
        end
    end
    for _, goal in ipairs(real and ns.db.goals or ns.GetGoals()) do inherit(goal) end
    if extra then inherit(extra) end
    return choices
end

function ns.SetTrainingAbility(expense, selected, staged)
    local preview = ns.testMoneyCopper ~= nil or ns.testPlayerLevel ~= nil
    local choices = ns.GetTrainingSelections()
    local updated = {}
    for key, value in pairs(choices or ns.InitializeTrainingSelections(staged)) do updated[key] = value end
    updated[ns.TrainingAbilityKey(expense)] = selected
    if preview then ns.testTrainingSelections = updated else ns.db.classTrainingSelections = updated end
    if not preview or ns.testGoals then
        for _, goal in ipairs(ns.GetGoals()) do ns.SyncExpenses(goal) end
    end
    ns.Changed()
end

local function classSelected(expense, fallback, real)
    local choices = ns.GetTrainingSelections(real)
    if choices then return choices[ns.TrainingAbilityKey(expense)] ~= false end
    return fallback ~= false
end

local function validSpellID(value)
    return type(value) == "number" and value > 0 and value < math.huge and value == math.floor(value)
end

function ns.ExpenseIcon(expense)
    local icon
    if validSpellID(expense.spellID) and C_Spell and C_Spell.GetSpellTexture then
        icon = C_Spell.GetSpellTexture(expense.spellID)
    end
    return icon or expense.icon or "Interface\\Icons\\INV_Misc_QuestionMark"
end

-- Only a service's own link or typed tooltip can identify its exact spell rank.
-- A name lookup can return a different rank, especially for profession training.
local function trainerSpellID(index)
    local link
    if GetTrainerServiceItemLink then
        link = GetTrainerServiceItemLink(index)
        if type(link) == "string" and link ~= "" then
            local id = tonumber(link:match("|Hspell:(%d+)") or link:match("^spell:(%d+)"))
            if validSpellID(id) then return id, link end
        else link = nil end
    end
    if C_TooltipInfo and C_TooltipInfo.GetTrainerService and Enum and Enum.TooltipDataType
        and Enum.TooltipDataType.Spell ~= nil then
        local data = C_TooltipInfo.GetTrainerService(index)
        if data and data.type == Enum.TooltipDataType.Spell and validSpellID(data.id) then return data.id, link end
    end
    return nil, link
end

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
    local bySpell, byName = {}, {}
    local function newest(a, b)
        local at = Model.IsInteger(a.observedAt, 0, Model.MAX_COPPER) and a.observedAt or 0
        local bt = Model.IsInteger(b.observedAt, 0, Model.MAX_COPPER) and b.observedAt or 0
        if at ~= bt then return at > bt end
        return a.key < b.key
    end
    -- Index once per snapshot. Exact spell IDs win over legacy name matches;
    -- duplicate observations identify one rank, never another expense.
    for key, quote in pairs(ns.db.trainerCatalog or {}) do
        if type(key) == "string" and Model.ValidateExpense(quote, false)
            and quote.source == "class" and quote.class == class then
            local entry = {}
            for field, value in pairs(quote) do entry[field] = value end
            entry.key = key
            local index = entry.spellID and bySpell or byName
            local identity = entry.spellID or (entry.name .. ":" .. entry.level)
            index[identity] = index[identity] or {}
            index[identity][#index[identity] + 1] = entry
        end
    end
    for _, index in ipairs({bySpell, byName}) do
        for _, candidates in pairs(index) do table.sort(candidates, newest) end
    end
    local prerequisites,knownAbilities={},{}
    for _,base in ipairs(ns.ClassTrainingData[class] or {}) do
        if base.requiresSpell then prerequisites[base.name]=base.requiresSpell end
        if known(base.spellID) then knownAbilities[base.name]=true end
    end
    for _, base in ipairs(ns.ClassTrainingData[class] or {}) do
        local entry = {}
        for key, value in pairs(base) do entry[key] = value end
        entry.key, entry.source, entry.class = "class:" .. base.spellID, "class", class
        entry.name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(base.spellID) or base.name
        localizedAbilities[class][entry.name] = base.name
        entry.paid, entry.priceSource = known(base.spellID), "base price"
        entry.requiresSpell=prerequisites[base.name] or base.requiresSpell
        entry.eligible = not entry.requiresSpell or known(entry.requiresSpell) or knownAbilities[base.name]==true
        if base.races and raceID then
            local eligibleRace = false
            for _, id in ipairs(base.races) do if id == raceID then eligibleRace = true end end
            entry.eligible = entry.eligible and eligibleRace
        end
        local quote
        for _, candidate in ipairs(bySpell[base.spellID] or {}) do
            matched[candidate.key] = true
            quote = quote or candidate
        end
        for _, candidate in ipairs(byName[entry.name .. ":" .. base.level] or {}) do
            if candidate.rank == base.rank or not candidate.rank or candidate.rank == "" then
                matched[candidate.key] = true
                quote = quote or candidate
            end
        end
        if quote then
            entry.copper, entry.paid, entry.priceSource = quote.copper, quote.paid or entry.paid, "trainer quote"
            entry.observedAt, entry.trainer = quote.observedAt, quote.trainer
            entry.icon, entry.link = quote.icon, quote.link
        end
        entry.icon = ns.ExpenseIcon(entry)
        rows[#rows + 1] = entry
    end
    local observedNames = {}
    local function identity(quote)
        return quote.name .. ":" .. quote.level .. ":" .. (quote.rank or "")
    end
    local function addObserved(quote)
        local entry = {}
        for field, value in pairs(quote) do entry[field] = value end
        entry.eligible, entry.priceSource = true, "trainer quote"
        entry.paid = entry.paid or known(entry.spellID)
        entry.icon = ns.ExpenseIcon(entry)
        rows[#rows + 1] = entry
    end
    for _, candidates in pairs(bySpell) do
        local quote
        for _, candidate in ipairs(candidates) do
            observedNames[identity(candidate)] = true
            if not matched[candidate.key] then quote = quote or candidate end
        end
        if quote then addObserved(quote) end
    end
    for _, candidates in pairs(byName) do
        for _, quote in ipairs(candidates) do
            local name = identity(quote)
            if not matched[quote.key] and not observedNames[name] then
                addObserved(quote)
                observedNames[name] = true
            end
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
        if classSelected(entry, selections[entry.key]) and not ns.ClassTrainingRetired() and not entry.paid and entry.eligible then
            if entry.copper then totals[entry.level] = (totals[entry.level] or 0) + entry.copper else unknown = unknown + 1 end
        end
    end
    return totals, unknown
end

-- Display purchases at their due levels without moving or spending saved gold.
function ns.ExpensesByLevel(goal)
    local levels,selections,seen={},{},{}
    for _,expense in ipairs(goal.expenses or {}) do
        if expense.source=="class" then selections[expense.key]=expense.selected end
    end
    local function add(expense)
        if not expense.level or expense.level>goal.targetLevel then return end
        local identity=expense.source=="class" and (expense.spellID or expense.key) or expense.key
        local key=(expense.source or "manual") .. ":" .. tostring(identity)
        if seen[key] then return end
        seen[key]=true
        local entry=levels[expense.level]
        if not entry then entry={total=0,complete=true,items={}}; levels[expense.level]=entry end
        entry.items[#entry.items+1]={name=expense.name,rank=expense.rank,source=expense.source,
            copper=expense.copper,key=expense.key}
        if expense.copper~=nil then entry.total=entry.total+expense.copper else entry.complete=false end
    end
    if ns.db.trainingProtection~=false and (ns.GetTrainingSelections() or goal.includeClassTraining) and not ns.ClassTrainingRetired() then
        local classRanks={}
        for _,expense in ipairs(ns.ClassCatalog()) do
            local key=expense.spellID or expense.key; local previous=classRanks[key]
            if not previous or expense.key=="class:" .. tostring(expense.spellID) then classRanks[key]=expense end
        end
        for _,expense in pairs(classRanks) do
            if classSelected(expense, selections[expense.key]) and not expense.paid and expense.eligible~=false then add(expense) end
        end
    end
    for _,expense in ipairs(goal.expenses or {}) do
        if expense.source~="class" and expense.selected and not expense.paid and expense.eligible~=false then add(expense) end
    end
    for _,entry in pairs(levels) do
        table.sort(entry.items,function(a,b)
            if a.name~=b.name then return a.name<b.name end
            return tostring(a.key)<tostring(b.key)
        end)
    end
    return levels
end

-- An optional roster merges its active training choices with a staged goal.
-- This keeps an initial allocation from taking another goal's training money.
function ns.IsExcludedTraining(name)
    local choices=ns.GetTrainingSelections(true)
    if not choices then return false end
    for _,expense in ipairs(ns.ClassCatalog()) do
        if expense.name==name and choices[ns.TrainingAbilityKey(expense)]==false then return true end
    end
    return false
end

function ns.TrainingRunway(goal, force, goals, levelOverride, real)
    local level = levelOverride or ns.GetPlayerLevel()
    real = real or goals == ns.db.goals
    if ns.db.trainingProtection==false or ns.ClassTrainingRetired(level) then return 0, true end
    local shared = ns.GetTrainingSelections(real)
    local enabled, selected = force or (goal and (shared or goal.includeClassTraining)), {}
    local function addSelections(g)
        for _, e in ipairs(g.expenses or {}) do
            if e.source == "class" then
                selected[e.key] = selected[e.key] or e.selected ~= false
            end
        end
    end
    if goal then addSelections(goal) end
    for _, g in ipairs(goals or (not goal and ns.GetGoals()) or {}) do
        if g.active and (shared or g.includeClassTraining) then enabled = true; addSelections(g) end
    end
    if not enabled then return 0, true end
    local amount, complete, nextLevel = 0, true, nil
    local costs = {current = 0, upcoming = 0, currentComplete = true, upcomingComplete = true, upcomingSpells = {}}
    for _, entry in ipairs(ns.ClassCatalog()) do
        local pastDue = entry.priceSource == "trainer quote" and entry.level < level
        if not entry.paid and entry.eligible and (entry.level >= level or pastDue) and entry.level <= math.min(60,level+2)
            and classSelected(entry, selected[entry.key], real) then
            local upcoming = entry.level > level
            if upcoming then
                nextLevel = math.min(nextLevel or entry.level, entry.level)
                costs.lastLevel = math.max(costs.lastLevel or entry.level, entry.level)
                costs.upcomingSpells[#costs.upcomingSpells + 1] = {
                    name = entry.name, rank = entry.rank, level = entry.level,
                    copper = entry.copper, key = entry.key,
                }
            end
            local bucket = upcoming and "upcoming" or "current"
            if entry.copper then
                amount = amount + entry.copper
                costs[bucket] = costs[bucket] + entry.copper
            else
                complete = false
                costs[bucket .. "Complete"] = false
            end
        end
    end
    table.sort(costs.upcomingSpells, function(a, b)
        if a.level ~= b.level then return a.level < b.level end
        if a.name ~= b.name then return a.name < b.name end
        return a.key < b.key
    end)
    return amount, complete, nextLevel, costs
end

function ns.SyncExpenses(goal, real)
    if ns.GetTrainingSelections(real) then goal.includeClassTraining = true end
    if goal.planMode ~= "items" and not goal.includeClassTraining then return end
    local source = goal.presetID == "class-training" and "class"
        or goal.presetID == "profession-training" and "profession" or goal.presetID
    local existing = {}
    local abilitySelections = {}
    local provisionalSelection
    goal.expenses = goal.expenses or {}
    for _, expense in ipairs(goal.expenses) do
        existing[expense.key] = expense
        if expense.source=="class" or expense.source=="profession" then
            local ability=expense.source .. ":" .. expense.name
            abilitySelections[ability]=abilitySelections[ability] or expense.selected~=false
        end
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
                local selected=provisionalSelection~=false
                if quote.source=="class" or quote.source=="profession" then
                    selected=abilitySelections[quote.source .. ":" .. quote.name]~=false
                end
                expense = { key = key, selected = selected }
                goal.expenses[#goal.expenses + 1] = expense
                existing[key] = expense
            end
            for field, value in pairs(quote) do expense[field] = value end
            expense.copper = quote.copper
            if expense.source == "class" then expense.selected = classSelected(expense, expense.selected, real) end
        end
    end
    -- Separate the entered combined budget when a riding price becomes known.
    -- The first quote must not erase the mount allowance. Later quote changes
    -- affect only riding, leaving the allowance at the player's budgeted value.
    if source == "mount-first" or source == "mount-epic" then
        local ridingCost
        for _, expense in ipairs(goal.expenses) do
            if expense.source == source and not expense.estimated and expense.copper~=nil then
                ridingCost=math.max(ridingCost or 0,expense.copper)
            end
        end
        if ridingCost then
            for _,expense in ipairs(goal.expenses) do
                if expense.key=="manual:initial" and expense.estimated then
                    expense.name="Mount allowance"
                    expense.copper=math.max(0,(expense.copper or 0)-ridingCost)
                    expense.estimated=false
                    expense.priceSource="mount allowance from your budget"
                end
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
    local wasItemized=goal.planMode=="items"
    goal.planMode = "items"
    if goal.presetID == "class-training" then goal.includeClassTraining = true end
    goal.expenses = goal.expenses or {}
    local hasGoalExpense,hasInitial = false,false
    for _, expense in ipairs(goal.expenses) do
        if expense.source ~= "class" then hasGoalExpense = true end
        if expense.key=="manual:initial" then hasInitial=true end
    end
    local mount=goal.presetID=="mount-first" or goal.presetID=="mount-epic"
    -- Riding quotes may already be present before itemizing a mount goal.
    -- Carry the entered total across instead of replacing it with those quotes.
    if not hasInitial and (not hasGoalExpense or (mount and not wasItemized)) and goal.targetCopper > 0 and goal.presetID ~= "class-training" then
        goal.expenses[#goal.expenses + 1] = { key = "manual:initial", name = goal.name ~= "" and goal.name or "Goal expense",
            level = goal.targetLevel, copper = goal.targetCopper, selected = true,
            estimated = mount, source = "manual" }
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
                local spellID, link = trainerSpellID(index)
                spellID = spellID or (previous and previous.spellID)
                link = link or (previous and previous.link)
                if type(cost) ~= "number" or cost < 0 or cost > Model.MAX_COPPER or cost ~= math.floor(cost) then cost = nil end
                if serviceType == "used" and previous then cost = previous.copper end
                ns.db.trainerCatalog[key] = { key = key, source = source, class = class, name = name,
                    rank = rank, level = level, copper = cost, paid = serviceType == "used", icon = icon, spellID = spellID, link = link,
                    trainer = UnitName and UnitName("npc") or "Trainer", observedAt = time and time() or 0 }
            end
        end
    end
    for _, goal in ipairs(ns.db.goals) do ns.SyncExpenses(goal, true) end
    if ns.testGoals then for _, goal in ipairs(ns.testGoals) do ns.SyncExpenses(goal) end end
    ns.Changed()
    if ns.CatalogChanged then ns.CatalogChanged() end
end
