-- Character events, persistent goal state, summaries, and purchase confirmations.
-- Real money events and affordability always use player APIs, never previews.
local addonName, ns = ...
ns.name = addonName
ns.WARNING_COOLDOWN_SECONDS = 120
ns.warningCooldownUntil = 0
ns.TEST_COMMAND_PASSWORD = "Quantum123"

function ns.Now() return GetServerTime and GetServerTime() or time() end

function ns.GetPlayedSeconds()
    return (ns.db and ns.db.playedSeconds or 0)+(ns.playStartedAt and math.max(0,GetTime()-ns.playStartedAt) or 0)
end

function ns.GetLevel60PlayedSeconds()
    return (ns.db and ns.db.level60PlayedSeconds or 0)
        + (ns.level60StartedAt and math.max(0, GetTime() - ns.level60StartedAt) or 0)
end

function ns.ClassTrainingRetired(level)
    level = level or ns.GetPlayerLevel()
    return level >= 60 and UnitLevel("player") >= 60 and ns.GetLevel60PlayedSeconds() > 10800
end

function ns.FlushPlayClock()
    if ns.db and ns.level60StartedAt then ns.db.level60PlayedSeconds = ns.GetLevel60PlayedSeconds() end
    ns.level60StartedAt = nil
    if ns.db and ns.playStartedAt then ns.db.playedSeconds=ns.GetPlayedSeconds() end
    ns.playStartedAt=nil
end

function ns.ParseGoalDate(text)
    local y,m,d=text:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
    y,m,d=tonumber(y),tonumber(m),tonumber(d)
    if not y or m<1 or m>12 or d<1 or d>31 or y<1970 or y>2100 then return nil,"Use YYYY-MM-DD." end
    local epoch=time({year=y,month=m,day=d,hour=23,min=59,sec=59})
    local check=date("*t",epoch)
    if check.year~=y or check.month~=m or check.day~=d then return nil,"Choose a valid calendar date." end
    return epoch
end

-- Test overrides live only in this Lua session. Real purchases always use the
-- character's actual money and level.
function ns.GetPlayerLevel()
    return ns.testPlayerLevel or UnitLevel("player")
end

function ns.GetPlayerMoney()
    if ns.testMoneyCopper ~= nil then return ns.testMoneyCopper end
    return GetMoney()
end

function ns.GetGoals()
    return ns.testGoals or ns.db.goals
end

function ns.SetGoals(goals)
    if ns.testGoals then ns.testGoals = goals else ns.db.goals = goals end
end

function ns.WarningCooldownRemaining()
    return math.max(0, ns.warningCooldownUntil - GetTime())
end

function ns.Print(text)
    DEFAULT_CHAT_FRAME:AddMessage("|cffffd36eMountfund:|r " .. text)
end

function ns.GetBudget()
    local goals = ns.GetGoals()
    local training, complete = ns.TrainingRunway(nil, nil, goals)
    local budget = ns.Model.Budget(goals, ns.GetPlayerLevel(), ns.GetPlayerMoney(), training)
    budget.trainingComplete = complete
    return budget
end

function ns.StatusCoins(amount)
    local gold,silver,copper=ns.Model.SplitCoins(amount)
    local parts={}
    if gold>0 then
        local digits=tostring(gold):reverse():gsub("(%d%d%d)","%1,"):reverse():gsub("^,","")
        parts[#parts+1]=digits.."g"
    end
    if silver>0 then parts[#parts+1]=silver.."s" end
    if copper>0 or #parts==0 then parts[#parts+1]=copper.."c" end
    return table.concat(parts," ")
end

-- Interval baselines persist across reloads. Store scalars so preview goal copies
-- cannot share or mutate real progress bookkeeping.
function ns.StatusInterval(goal, level)
    local kind=goal.goalType or "level"
    local now,played=ns.Now(),ns.GetPlayedSeconds()
    if kind=="date" then
        local parts=date("*t",now)
        local first=time({year=parts.year,month=parts.month,day=parts.day,hour=0,min=0,sec=0})
        local last=time({year=parts.year,month=parts.month,day=parts.day+1,hour=0,min=0,sec=0})
        return "date:"..date("%Y-%m-%d",now),
            math.max(0,ns.Model.TargetAtLevel(goal,level,last,played)-ns.Model.TargetAtLevel(goal,level,first,played))
    elseif kind=="played" then
        local start=goal.startPlayed or 0
        local hour=math.floor(math.max(0,played-start)/3600)
        local first=start+hour*3600
        return "played:"..start..":"..hour,
            math.max(0,ns.Model.TargetAtLevel(goal,level,now,first+3600)-ns.Model.TargetAtLevel(goal,level,now,first))
    end
    return "level:"..level,ns.Model.LevelPlanStep(goal,level).addition
end

function ns.SyncStatusIntervals(goals, level)
    for _,goal in ipairs(goals) do
        local key=ns.StatusInterval(goal,level)
        if goal.statusIntervalKey~=key or goal.statusIntervalActive~=goal.active then
            goal.statusIntervalKey=key
            goal.statusIntervalBase=goal.savedCopper or 0
            goal.statusIntervalActive=goal.active
        end
    end
end

-- Chat and the main-page overview share one read-only display snapshot.
-- Automatic reports use real data; manual reports may describe a session preview.
function ns.BuildGoalStatus(real, levelOverride)
    local level = real and (levelOverride or UnitLevel("player")) or ns.GetPlayerLevel()
    local balance = real and GetMoney() or ns.GetPlayerMoney()
    local source = real and ns.db.goals or ns.GetGoals()
    local goals = {}
    for index, goal in ipairs(source) do goals[index] = ns.Model.CopyGoal(goal) end
    ns.SyncStatusIntervals(goals, level)
    ns.Model.Reconcile(goals, balance)
    local training, complete, nextLevel, costs = ns.TrainingRunway(nil, nil, goals, level, real)
    costs = costs or {current = 0, upcoming = 0, currentComplete = true, upcomingComplete = true}
    local budget = ns.Model.Budget(goals, level, balance, training)
    local sections = {
        {kind = "level", title = "LEVEL GOALS • Level " .. level, label = "Goal for this level", rows = {}, saved = 0, target = 0},
        {kind = "date", title = "CALENDAR GOALS • Today", label = "Goal for Today", rows = {}, saved = 0, target = 0},
        {kind = "played", title = "PLAYTIME GOALS • Current hour", label = "Goal for this hour", rows = {}, saved = 0, target = 0},
    }
    local byKind = {}
    for _, section in ipairs(sections) do byKind[section.kind] = section end
    local status = {level = level, balance = balance, sections = sections, untracked = {},
        training = training, trainingComplete = complete, trainingLevel = nextLevel,
        trainingCosts = costs,
        trainingFunded = budget.trainingFunded, budget = budget, count = #goals, activeCount = 0}
    for index, goal in ipairs(goals) do
        local progress = ns.Model.GoalProgress(goal, level)
        local row = {index = index, name = goal.name, saved = progress.saved, target = progress.target,
            active = goal.active, ahead = progress.ahead, behind = progress.behind,
            goalType = goal.goalType or "level", targetLevel = goal.targetLevel,
            deadlineTime = goal.deadlineTime, durationSeconds = goal.durationSeconds}
        if goal.active then
            local section = byKind[row.goalType]
            local _, addition = ns.StatusInterval(goal, level)
            section.saved = section.saved + math.max(0, progress.saved - (goal.statusIntervalBase or progress.saved))
            section.target = section.target + addition
            section.rows[#section.rows + 1] = row
            status.activeCount = status.activeCount + 1
        else
            status.untracked[#status.untracked + 1] = row
        end
    end
    return status
end

function ns.TrainingCaption(status)
    local first, last = status.trainingLevel, status.trainingCosts.lastLevel
    local levels = first and (last and last > first and first .. "–" .. last or tostring(first))
    return levels and "Lvl " .. levels .. " Class Training" or "Class Training"
end

function ns.PrintStatus(real, levelOverride)
    if real then ns.SyncStatusIntervals(ns.db.goals, levelOverride or UnitLevel("player")) end
    local status = ns.BuildGoalStatus(real, levelOverride)
    local function line(text) DEFAULT_CHAT_FRAME:AddMessage(text) end
    line("|cffffd36eMountfund • Goal summary|r")
    line("  " .. (not real and ns.testMoneyCopper ~= nil and "Test wallet: " or "Wallet: ") .. ns.StatusCoins(status.balance))
    local costs = status.trainingCosts
    if costs.current > 0 or not costs.currentComplete then
        line("  Training due now: " .. ns.StatusCoins(costs.current)
            .. (costs.currentComplete and "" or " (some prices unknown)"))
    end
    if status.trainingLevel then
        line("  " .. ns.TrainingCaption(status) .. ": " .. ns.StatusCoins(costs.upcoming)
            .. (costs.upcomingComplete and "" or " (some prices unknown)"))
    end
    for _, section in ipairs(status.sections) do
        if #section.rows > 0 then
            line("|cffffd36e" .. section.title .. "|r")
            for _, row in ipairs(section.rows) do
                line("  " .. row.name .. ": " .. ns.StatusCoins(row.saved) .. " / " .. ns.StatusCoins(row.target))
            end
            line("  " .. section.label .. ": " .. ns.StatusCoins(section.saved) .. " / " .. ns.StatusCoins(section.target))
        end
    end
    if status.activeCount == 0 then line("  No tracked goals.") end
end

local function hasStatusGoal(kind)
    for _,goal in ipairs(ns.db.goals) do
        if goal.active and (goal.goalType or "level")==kind then return true end
    end
    return false
end

local function resetStatusClock()
    ns.SyncStatusIntervals(ns.db.goals,UnitLevel("player"))
    ns.statusDay=date("%Y-%m-%d",ns.Now())
    ns.statusPlayed=ns.GetPlayedSeconds()
end

function ns.CheckStatusMilestones()
    if not ns.db or ns.outOfWorld then return end
    local today=date("%Y-%m-%d",ns.Now())
    local played=ns.GetPlayedSeconds()
    local previous=ns.statusPlayed or played
    local due=ns.statusDay~=nil and today>ns.statusDay and hasStatusGoal("date")
    for _,goal in ipairs(ns.db.goals) do
        if goal.active and goal.goalType=="played" then
            local start=goal.startPlayed or 0
            if math.floor(math.max(0,played-start)/3600)>math.floor(math.max(0,previous-start)/3600) then due=true end
        end
    end
    ns.statusDay,ns.statusPlayed=today,played
    if due then ns.PrintStatus(true) end
end

-- Copy just the display values so an open toast never changes its goal data.
function ns.BuildLevelUpSummary(level)
    if not ns.db then return nil end
    if type(level) ~= "number" or level ~= math.floor(level) or level < 1
        or level > ns.Model.MAX_LEVEL then return nil end
    local balance = ns.GetPlayerMoney()
    local goals={}
    for index,goal in ipairs(ns.GetGoals()) do goals[index]=ns.Model.CopyGoal(goal) end
    ns.Model.Reconcile(goals, balance)
    local ordered = {}
    for index, goal in ipairs(goals) do
        if goal.active then ordered[#ordered + 1] = { goal = goal, index = index } end
    end
    if #ordered == 0 then return nil end
    local timed=false
    for _,entry in ipairs(ordered) do if ns.Model.IsTimeGoal(entry.goal) then timed=true; break end end
    table.sort(ordered, function(a, b)
        if timed then
            local pa,pb=ns.Model.Priority(a.goal,level),ns.Model.Priority(b.goal,level)
            if pa~=pb then return pa<pb end
        end
        if a.goal.targetLevel ~= b.goal.targetLevel then return a.goal.targetLevel < b.goal.targetLevel end
        return a.index < b.index
    end)
    local training, trainingComplete = ns.TrainingRunway(nil, nil, goals, level)
    local budget = ns.Model.Budget(goals, level, balance, training)
    local summary = { level = level, balance = balance, goals = {}, activeCount = #ordered,
        remainingCount = math.max(0, #ordered - 2) }
    for index = 1, math.min(2, #ordered) do
        local goal = ordered[index].goal
        local progress = ns.Model.GoalProgress(goal, level)
        local preset = ns.FindPreset and ns.FindPreset(goal.presetID)
        local row = { name = goal.name, targetLevel = goal.targetLevel, goalType=goal.goalType,
            icon = goal.icon or (preset and preset.icon) or "Interface\\Icons\\INV_Misc_Coin_01",
            saved = progress.saved, target = progress.target, expected = progress.expected,
            percent = progress.percent, ahead = progress.ahead, behind = progress.behind }
        if goal.targetCopper == 0 and goal.includeClassTraining then
            row.training, row.trainingComplete = true, trainingComplete
            row.saved, row.target, row.expected = budget.trainingFunded, budget.trainingDue, budget.trainingDue
            row.percent = row.target > 0 and row.saved / row.target * 100 or 100
            row.ahead, row.behind = 0, budget.trainingShortfall
        end
        if row.target > 0 and row.saved >= row.target and not row.training then row.status = "complete"
        elseif row.behind > 0 then row.status = "behind"
        elseif row.ahead > 0 then row.status = "ahead"
        else row.status = "ontrack" end
        summary.goals[#summary.goals + 1] = row
    end
    return summary
end

function ns.PrepareGoal(goal, replacing)
    ns.Model.MigrateCurve(goal)
    if goal.goalType=="date" and not goal.startTime then goal.startTime=ns.Now() end
    if goal.goalType=="played" and not goal.startPlayed then goal.startPlayed=math.floor(ns.GetPlayedSeconds()) end
    if not goal.startLevel then goal.startLevel = math.max(1, ns.GetPlayerLevel()) end
    ns.SyncExpenses(goal)
    if goal.savedCopper == nil then
        local allocated, trainingGoals = 0, {}
        for _, existing in ipairs(ns.GetGoals()) do
            if existing ~= replacing and existing.active then
                allocated = allocated + (existing.savedCopper or 0)
                trainingGoals[#trainingGoals + 1] = existing
            end
        end
        local training, complete = ns.TrainingRunway(goal, true, trainingGoals)
        goal.initialCopper = complete and ns.Model.InitialInvestment(ns.GetPlayerMoney(), training, allocated,
            goal.initialPercent, goal.initialOverrideCopper, goal.targetCopper) or 0
        goal.savedCopper = goal.initialCopper
    end
    return goal
end

function ns.ObserveMoney()
    local balance = GetMoney()
    local previous = ns.lastMoney or balance
    local difference = balance - previous
    ns.lastMoney = balance
    local level = UnitLevel("player")
    ns.db.earnings = ns.db.earnings or {}
    ns.SyncStatusIntervals(ns.db.goals,level)
    local record = ns.db.earnings[level]
    if type(record) ~= "table" then record = {} end
    if not ns.Model.IsInteger(record.income, 0, ns.Model.MAX_COPPER) then record.income = 0 end
    if not ns.Model.IsInteger(record.spending, 0, ns.Model.MAX_COPPER) then record.spending = 0 end
    ns.db.earnings[level] = record
    if difference > 0 then
        record.income = record.income + difference
        -- Actual income still uses the character's real training needs while
        -- a test level is active; previewing levels must not change funding.
        ns.Model.FundGoals(ns.db.goals, difference, balance, ns.TrainingRunway(nil, nil, ns.db.goals, level), level)
    else
        record.spending = record.spending - difference
        ns.Model.Reconcile(ns.db.goals, balance)
    end
    ns.Changed()
end

function ns.Changed()
    if ns.RefreshUI then ns.RefreshUI() end
end

function ns.CancelPurchase()
    ns.pending = nil
    if ns.warningFrame then ns.warningFrame:Hide() end
end

-- Read the transaction again at confirmation time: UI selections and quotes can change.
function ns.RequestPurchase(read, execute)
    if ns.pending then
        ns.Print("Finish or cancel the current savings warning first.")
        return
    end
    local action = read()
    if not action then
        ns.Print("The purchase is no longer available. Select it again.")
        return
    end
    if type(action.cost) ~= "number" or action.cost ~= action.cost
        or action.cost < 0 or action.cost > ns.Model.MAX_COPPER
        or action.cost ~= math.floor(action.cost) then
        ns.Print("Cannot read this purchase's price. Select it again.")
        return
    end
    local level = UnitLevel("player")
    local budget = ns.Model.Purchase(ns.db.goals, level, GetMoney(), action.cost,
        ns.TrainingRunway(nil, nil, ns.db.goals, level), action.classTraining)
    if not budget.affordable then ns.Print("You do not have enough money for this purchase."); return end
    if ns.db.warnings and budget.warning and ns.WarningCooldownRemaining() == 0 then
        ns.pending = { read = read, execute = execute, action = action, budget = budget }
        ns.ShowWarning(ns.pending)
        return
    end
    execute()
end

function ns.ConfirmPurchase()
    local pending = ns.pending
    if not pending then return end
    ns.CancelPurchase()
    local action = pending.read()
    if not action or action.key ~= pending.action.key or action.cost ~= pending.action.cost then
        ns.Print("The selection or price changed. Select the purchase again.")
        return
    end
    local level = UnitLevel("player")
    local budget = ns.Model.Purchase(ns.db.goals, level, GetMoney(), action.cost,
        ns.TrainingRunway(nil, nil, ns.db.goals, level), action.classTraining)
    if not budget.affordable then ns.Print("You no longer have enough money for this purchase."); return end
    -- Display refreshes do not change what the player is approving. Reconfirm
    -- only when the actual wallet or protected spending impact has changed.
    if budget.warning and (budget.balance ~= pending.budget.balance
        or budget.reserved ~= pending.budget.reserved or budget.afterShortfall ~= pending.budget.afterShortfall) then
        ns.RequestPurchase(pending.read, pending.execute)
        return
    end
    -- A confirmed warning allows follow-up purchases for this session only.
    -- Price, selection and affordability checks still run during the grace period.
    ns.warningCooldownUntil = GetTime() + ns.WARNING_COOLDOWN_SECONDS
    pending.execute()
end

local function StartSession()
    ns.testPlayerLevel, ns.testMoneyCopper, ns.testGoals, ns.testTrainingSelections = nil, nil, nil, nil
    if ns.RefreshTestContext then ns.RefreshTestContext() end
    ns.CancelPurchase()
    if ns.HideLevelUpToast then ns.HideLevelUpToast() end
    if ns.sessionStarted then return end
    ns.sessionStarted = true
    ns.lastMoney = GetMoney()
    ns.lastLevelUpEvent = UnitLevel("player")
    if not ns.playStartedAt then ns.playStartedAt=GetTime() end
    if UnitLevel("player") == 60 then
        ns.level60StartedAt = GetTime()
        if ns.db.level60PlayedSeconds == nil and RequestTimePlayed then RequestTimePlayed() end
    end
    for _, goal in ipairs(ns.db.goals) do
        if not goal.startLevel then
            if goal.curve == 2 then goal.curve = 0 end
            goal.startLevel = math.max(1, UnitLevel("player"))
            for level in pairs(goal.milestones) do if level <= goal.startLevel then goal.milestones[level] = nil end end
            if goal.presetID == "class-training" then goal.includeClassTraining = true end
            ns.PrepareGoal(goal, goal)
        else ns.SyncExpenses(goal, true) end
    end
    ns.Model.Reconcile(ns.db.goals, GetMoney())
    ns.db.version = 2
    resetStatusClock()
    ns.Changed()
end

local function Initialize()
    ns.testPlayerLevel, ns.testMoneyCopper, ns.testGoals, ns.testTrainingSelections = nil, nil, nil, nil
    ns.loginToastHandled = nil
    ns.statusLoginHandled=nil
    ns.level60StartedAt = nil
    ns.CancelPurchase()
    if ns.HideLevelUpToast then ns.HideLevelUpToast() end
    -- WoW reads saved data by addon folder name. A copied legacy saved-data
    -- file can be imported once without changing its contents or losing goals.
    if type(MountfundDB) ~= "table" and type(GoldEnvelopeDB) == "table" then
        MountfundDB = GoldEnvelopeDB
    end
    GoldEnvelopeDB = nil
    MountfundDB = type(MountfundDB) == "table" and MountfundDB or {}
    ns.db = MountfundDB
    if type(ns.db.playedSeconds)~="number" or ns.db.playedSeconds~=ns.db.playedSeconds or ns.db.playedSeconds<0 or ns.db.playedSeconds==math.huge then ns.db.playedSeconds=0 end
    if ns.db.warnings == nil then ns.db.warnings = true end
    if ns.db.levelUpToasts == nil then ns.db.levelUpToasts = true end
    ns.db.goals = type(ns.db.goals) == "table" and ns.db.goals or {}
    local valid = {}
    for _, goal in ipairs(ns.db.goals) do
        if type(goal)=="table" then ns.Model.MigrateCurve(goal) end
        if ns.Model.ValidateGoal(goal) then valid[#valid + 1] = goal end
    end
    if #valid ~= #ns.db.goals then ns.Print("Some saved goals were invalid and were skipped.") end
    ns.db.goals = valid
    for _, goal in ipairs(valid) do goal.milestones = goal.milestones or {} end
    local quotes = {}
    if type(ns.db.trainerCatalog) == "table" then
        for key, quote in pairs(ns.db.trainerCatalog) do
            if type(key) == "string" and ns.Model.ValidateExpense(quote, false) then
                quote.key = key
                quotes[key] = quote
            end
        end
    end
    ns.db.trainerCatalog = quotes
    ns.db.earnings = type(ns.db.earnings) == "table" and ns.db.earnings or {}
    local at60 = ns.db.level60PlayedSeconds
    if type(at60) ~= "number" or at60 ~= at60 or at60 < 0 or at60 > ns.Model.MAX_COPPER then
        ns.db.level60PlayedSeconds = nil
    end
    if type(ns.db.classTrainingSelections) ~= "table" then
        ns.db.classTrainingSelections = ns.InitializeTrainingSelections(nil, true)
    else
        for key, value in pairs(ns.db.classTrainingSelections) do
            if type(key) ~= "string" or type(value) ~= "boolean" then ns.db.classTrainingSelections[key] = nil end
        end
    end
    resetStatusClock()
    if ns.RefreshTestContext then ns.RefreshTestContext() end
end

local frame = CreateFrame("Frame")
for _, event in ipairs({ "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_LOGOUT", "PLAYER_ENTERING_WORLD", "PLAYER_LEAVING_WORLD",
    "DISPLAY_SIZE_CHANGED", "UI_SCALE_CHANGED", "PLAYER_MONEY", "PLAYER_LEVEL_UP",
    "MERCHANT_SHOW", "MERCHANT_CLOSED", "TRAINER_SHOW", "TRAINER_CLOSED",
    "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED", "PLAYER_REGEN_ENABLED", "TIME_PLAYED_MSG",
    "TRAINER_UPDATE", "TRAINER_SERVICE_INFO_NAME_UPDATE" }) do
    frame:RegisterEvent(event)
end
frame:SetScript("OnEvent", function(_, event, arg, isReloadingUi)
    if event == "ADDON_LOADED" and arg == addonName then Initialize() end
    if not ns.db then return end
    if event == "PLAYER_LOGIN" then StartSession() end
    if event == "TIME_PLAYED_MSG" and UnitLevel("player") == 60 and ns.Model.IsInteger(isReloadingUi, 0, ns.Model.MAX_COPPER) then
        ns.db.level60PlayedSeconds = isReloadingUi
        ns.level60StartedAt = not ns.outOfWorld and GetTime() or nil
        ns.Changed()
    end
    if event=="PLAYER_ENTERING_WORLD" then
        ns.outOfWorld=false; if not ns.playStartedAt then ns.playStartedAt=GetTime() end
        if UnitLevel("player") == 60 and not ns.level60StartedAt then ns.level60StartedAt = GetTime() end
        if not ns.statusLoginHandled and (arg==true or isReloadingUi==true) then
            ns.statusLoginHandled=true
            C_Timer.After(0,function() resetStatusClock(); ns.PrintStatus(true) end)
        end
        -- The initial-login flag excludes zoning, instances, and UI reloads.
        if not ns.loginToastHandled then
            ns.loginToastHandled=true
            if arg==true and not isReloadingUi and ns.QueueLoginToast then ns.QueueLoginToast() end
        end
    end
    if event=="PLAYER_LEAVING_WORLD" then ns.outOfWorld=true; ns.FlushPlayClock() end
    if (event=="DISPLAY_SIZE_CHANGED" or event=="UI_SCALE_CHANGED") and ns.ApplyToastPosition then ns.ApplyToastPosition() end
    if event == "PLAYER_LOGOUT" then
        -- /reload does not reliably blur the focused edit box before saving
        -- SavedVariables. Flush while the editor still has its original goal
        -- context, including the session-only wallet when testing.
        if ns.ui and ns.ui:IsShown() and ns.SaveAllFields then ns.SaveAllFields(true) end
        if ns.FinishToastMove then ns.FinishToastMove() end
        ns.FlushPlayClock()
        ns.outOfWorld=true
        ns.testPlayerLevel, ns.testMoneyCopper, ns.testGoals, ns.testTrainingSelections = nil, nil, nil, nil
        if ns.RefreshTestContext then ns.RefreshTestContext() end
        ns.CancelPurchase()
        if ns.HideLevelUpToast then ns.HideLevelUpToast() end
        return
    end
    if event == "TRAINER_SHOW" or event == "TRAINER_UPDATE" or event == "TRAINER_SERVICE_INFO_NAME_UPDATE" then
        C_Timer.After(0, function()
            if ClassTrainerFrame and ClassTrainerFrame:IsShown() and ns.CaptureTrainerPrices then ns.CaptureTrainerPrices() end
        end)
    end
    if event == "MERCHANT_CLOSED" or event == "TRAINER_CLOSED" or event == "AUCTION_HOUSE_CLOSED" then
        ns.CancelPurchase()
    end
    if event == "PLAYER_LEVEL_UP" then
        -- The event can precede UnitLevel updating.
        local level = tonumber(arg)
        if level and level == math.floor(level) and level >= 1 and level <= ns.Model.MAX_LEVEL
            and level > (ns.lastLevelUpEvent or 0) then
            ns.lastLevelUpEvent = level
            if level == 60 then ns.db.level60PlayedSeconds = 0; ns.level60StartedAt = GetTime() end
            C_Timer.After(0, function()
                ns.SyncStatusIntervals(ns.db.goals,level)
                if ns.RefreshUI then ns.RefreshUI() end
                if hasStatusGoal("level") then ns.PrintStatus(true,level) end
                if ns.db.levelUpToasts and ns.QueueLevelUpToast then ns.QueueLevelUpToast(ns.testPlayerLevel or level) end
            end)
        end
    elseif event == "PLAYER_MONEY" then
        C_Timer.After(0, function() ns.ObserveMoney() end)
    else
        if ns.InstallGuards then ns.InstallGuards() end
        if event == "PLAYER_REGEN_ENABLED" and ns.FlushLevelUpToast then ns.FlushLevelUpToast() end
    end
end)

local refreshElapsed=0
frame:SetScript("OnUpdate",function(_,elapsed)
    if not ns.db or not ns.sessionStarted then return end
    refreshElapsed=refreshElapsed+elapsed
    if refreshElapsed>=10 then
        refreshElapsed=0
        ns.FlushPlayClock()
        if not ns.outOfWorld then
            ns.playStartedAt=GetTime()
            if UnitLevel("player") == 60 then ns.level60StartedAt = GetTime() end
        end
        ns.Changed()
        ns.CheckStatusMilestones()
    end
end)

SLASH_MOUNTFUND1 = "/mountfund"
SLASH_MOUNTFUND2 = "/mf"
SLASH_MOUNTFUND3 = "/envelope"
SLASH_MOUNTFUND4 = "/ge"

local function RefreshTestPreview(showToast, refreshGoalContext)
    ns.CancelPurchase()
    if ns.HideLevelUpToast then ns.HideLevelUpToast() end
    if refreshGoalContext and ns.RefreshTestContext then ns.RefreshTestContext() end
    ns.Changed()
    if ns.RefreshExpensePlanner then ns.RefreshExpensePlanner() end
    if showToast and ns.TestLevelUpToast then ns.TestLevelUpToast() end
end

local function TestGoldUsage()
    ns.Print("Usage: /ge testgold gold [silver [copper]] <password>, /ge testgold reset <password>, or /ge testgold <password>.")
end

SlashCmdList.MOUNTFUND = function(message)
    if not ns.db then return end
    local command, argument = message:match("^%s*(%S+)%s*(.-)%s*$")
    if command == "testlevel" or command == "testgold" or command == "testtoast" then
        local values, password = (argument or ""):match("^(.-)%s*(%S+)$")
        if password ~= ns.TEST_COMMAND_PASSWORD then
            ns.Print("Test commands require the password as their last argument.")
            return
        end
        argument = values:match("^%s*(.-)%s*$")
    end
    if command == "testlevel" then
        if argument == "" then
            ns.Print(ns.testPlayerLevel and ("Test level: " .. ns.testPlayerLevel
                .. "; actual level: " .. UnitLevel("player") .. ".")
                or ("Test level inactive; actual level: " .. UnitLevel("player") .. "."))
            ns.Print("Usage: /ge testlevel 1-60 <password> or /ge testlevel reset <password>. Clears on reload, logout, or character change.")
        elseif argument == "reset" then
            ns.testPlayerLevel = nil
            ns.testTrainingSelections = nil
            RefreshTestPreview(false)
            ns.Print("Test level reset; using actual level " .. UnitLevel("player") .. ".")
        else
            local level = argument:match("^%d+$") and tonumber(argument)
            if not level or level ~= math.floor(level) or level < 1 or level > ns.Model.MAX_LEVEL then
                ns.Print("Usage: /ge testlevel 1-60 <password> or /ge testlevel reset <password>.")
                return
            end
            ns.testPlayerLevel = level
            RefreshTestPreview(true)
            ns.Print("Test level set to " .. level .. " (actual level " .. UnitLevel("player")
                .. "). Clears on reload or logout.")
        end
    elseif command == "testgold" then
        if argument == "" then
            ns.Print(ns.testMoneyCopper ~= nil and ("Test gold: " .. ns.Model.FormatCoins(ns.testMoneyCopper)
                .. "; actual wallet: " .. ns.Model.FormatCoins(GetMoney()) .. ".")
                or ("Test gold inactive; actual wallet: " .. ns.Model.FormatCoins(GetMoney()) .. "."))
            TestGoldUsage()
        elseif argument == "reset" then
            ns.testMoneyCopper, ns.testGoals, ns.testTrainingSelections = nil, nil, nil
            RefreshTestPreview(false, true)
            ns.Print("Test gold reset; using actual wallet " .. ns.Model.FormatCoins(GetMoney()) .. ".")
        else
            local coins = {}
            for value in argument:gmatch("%S+") do coins[#coins + 1] = value end
            if #coins < 1 or #coins > 3 then TestGoldUsage(); return end
            local balance, problem = ns.Model.ParseCoins(coins[1], coins[2], coins[3])
            if not balance then ns.Print(problem); TestGoldUsage(); return end
            if ns.ui and ns.ui:IsShown() and ns.SaveAllFields then ns.SaveAllFields(true) end
            local previous = ns.GetPlayerMoney()
            if not ns.testGoals then
                ns.testGoals = {}
                for index, goal in ipairs(ns.db.goals) do ns.testGoals[index] = ns.Model.CopyGoal(goal) end
            end
            ns.testMoneyCopper = balance
            local difference = balance - previous
            if difference > 0 then
                ns.Model.FundGoals(ns.testGoals, difference, balance,
                    ns.TrainingRunway(nil, nil, ns.testGoals, ns.GetPlayerLevel()))
            else ns.Model.Reconcile(ns.testGoals, balance) end
            RefreshTestPreview(true, true)
            ns.Print("Test gold set to " .. ns.Model.FormatCoins(balance) .. "; actual wallet "
                .. ns.Model.FormatCoins(GetMoney()) .. ". Test goal progress clears on reload or logout.")
        end
    elseif command == "testtoast" then
        if argument ~= "" then
            ns.Print("Usage: /ge testtoast <password>.")
            return
        end
        if ns.TestLevelUpToast then ns.TestLevelUpToast() end
        ns.Print("Preview only; your goals and money are unchanged.")
    elseif message:match("^%s*status%s*$") then
        ns.PrintStatus()
    elseif message:match("^%s*toasts%s*$") then
        ns.db.levelUpToasts = not ns.db.levelUpToasts
        if not ns.db.levelUpToasts and ns.HideLevelUpToast then ns.HideLevelUpToast() end
        ns.Changed()
        ns.Print("Goal progress notifications " .. (ns.db.levelUpToasts and "enabled." or "disabled."))
    else
        ns.ToggleUI()
    end
end
