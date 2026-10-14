local addonName, ns = ...
ns.name = addonName
ns.revision = 0
ns.WARNING_COOLDOWN_SECONDS = 120
ns.warningCooldownUntil = 0

function ns.WarningCooldownRemaining()
    return math.max(0, ns.warningCooldownUntil - GetTime())
end

function ns.Print(text)
    DEFAULT_CHAT_FRAME:AddMessage("|cffffd36eGold Envelope:|r " .. text)
end

function ns.GetBudget()
    local training, complete = ns.TrainingRunway()
    local budget = ns.Model.Budget(ns.db.goals, UnitLevel("player"), GetMoney(), training)
    budget.trainingComplete = complete
    return budget
end

-- Copy just the display values so an open toast never changes its goal data.
function ns.BuildLevelUpSummary(level)
    if not ns.db then return nil end
    if type(level) ~= "number" or level ~= math.floor(level) or level < 1
        or level > ns.Model.MAX_LEVEL then return nil end
    local balance = GetMoney()
    local goals={}
    for index,goal in ipairs(ns.db.goals) do goals[index]=ns.Model.CopyGoal(goal) end
    ns.Model.Reconcile(goals, balance)
    local ordered = {}
    for index, goal in ipairs(goals) do
        if goal.active then ordered[#ordered + 1] = { goal = goal, index = index } end
    end
    if #ordered == 0 then return nil end
    table.sort(ordered, function(a, b)
        if a.goal.targetLevel ~= b.goal.targetLevel then return a.goal.targetLevel < b.goal.targetLevel end
        return a.index < b.index
    end)
    local training, trainingComplete = ns.TrainingRunway(nil, nil, nil, level)
    local budget = ns.Model.Budget(goals, level, balance, training)
    local summary = { level = level, balance = balance, goals = {}, activeCount = #ordered,
        remainingCount = math.max(0, #ordered - 2) }
    for index = 1, math.min(2, #ordered) do
        local goal = ordered[index].goal
        local progress = ns.Model.GoalProgress(goal, level)
        local preset = ns.FindPreset and ns.FindPreset(goal.presetID)
        local row = { name = goal.name, targetLevel = goal.targetLevel,
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
    if not goal.startLevel then goal.startLevel = math.max(1, UnitLevel("player")) end
    ns.SyncExpenses(goal)
    if goal.savedCopper == nil then
        local allocated, trainingGoals = 0, {}
        for _, existing in ipairs(ns.db.goals) do
            if existing ~= replacing and existing.active then
                allocated = allocated + (existing.savedCopper or 0)
                trainingGoals[#trainingGoals + 1] = existing
            end
        end
        local training, complete = ns.TrainingRunway(goal, true, trainingGoals)
        goal.initialCopper = complete and ns.Model.InitialInvestment(GetMoney(), training, allocated,
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
    local record = ns.db.earnings[level] or { income = 0, spending = 0 }
    ns.db.earnings[level] = record
    if difference > 0 then
        record.income = record.income + difference
        ns.Model.FundGoals(ns.db.goals, difference, balance, ns.TrainingRunway())
    else
        record.spending = record.spending - difference
        ns.Model.Reconcile(ns.db.goals, balance)
    end
    ns.Changed()
end

function ns.Changed()
    ns.revision = ns.revision + 1
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
    local budget = ns.Model.Purchase(ns.db.goals, UnitLevel("player"), GetMoney(), action.cost,
        ns.TrainingRunway(), action.classTraining)
    if not budget.affordable then ns.Print("You do not have enough money for this purchase."); return end
    if ns.db.warnings and budget.warning and ns.WarningCooldownRemaining() == 0 then
        ns.pending = { read = read, execute = execute, action = action, budget = budget, revision = ns.revision }
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
    local budget = ns.Model.Purchase(ns.db.goals, UnitLevel("player"), GetMoney(), action.cost,
        ns.TrainingRunway(), action.classTraining)
    if not budget.affordable then ns.Print("You no longer have enough money for this purchase."); return end
    if budget.warning and (budget.balance ~= pending.budget.balance
        or budget.reserved ~= pending.budget.reserved or pending.revision ~= ns.revision) then
        ns.RequestPurchase(pending.read, pending.execute)
        return
    end
    -- A confirmed warning allows follow-up purchases for this session only.
    -- Price, selection and affordability checks still run during the grace period.
    ns.warningCooldownUntil = GetTime() + ns.WARNING_COOLDOWN_SECONDS
    pending.execute()
end

local function StartSession()
    if ns.sessionStarted then return end
    ns.sessionStarted = true
    ns.lastMoney = GetMoney()
    ns.lastLevelUpEvent = UnitLevel("player")
    for _, goal in ipairs(ns.db.goals) do
        if not goal.startLevel then
            if goal.curve == 2 then goal.curve = 0 end
            goal.startLevel = math.max(1, UnitLevel("player"))
            for level in pairs(goal.milestones) do if level <= goal.startLevel then goal.milestones[level] = nil end end
            if goal.presetID == "class-training" then goal.includeClassTraining = true end
            ns.PrepareGoal(goal, goal)
        else ns.SyncExpenses(goal) end
    end
    ns.Model.Reconcile(ns.db.goals, GetMoney())
    ns.db.version = 2
    ns.Changed()
end

local function Initialize()
    GoldEnvelopeDB = type(GoldEnvelopeDB) == "table" and GoldEnvelopeDB or {}
    ns.db = GoldEnvelopeDB
    if ns.db.warnings == nil then ns.db.warnings = true end
    if ns.db.levelUpToasts == nil then ns.db.levelUpToasts = true end
    ns.db.goals = type(ns.db.goals) == "table" and ns.db.goals or {}
    local valid = {}
    for _, goal in ipairs(ns.db.goals) do
        if ns.Model.ValidateGoal(goal) then valid[#valid + 1] = goal end
    end
    if #valid ~= #ns.db.goals then ns.Print("Some saved goals were invalid and were skipped.") end
    ns.db.goals = valid
end

local frame = CreateFrame("Frame")
for _, event in ipairs({ "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_MONEY", "PLAYER_LEVEL_UP",
    "MERCHANT_SHOW", "MERCHANT_CLOSED", "TRAINER_SHOW", "TRAINER_CLOSED",
    "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED", "PLAYER_REGEN_ENABLED",
    "TRAINER_UPDATE", "TRAINER_SERVICE_INFO_NAME_UPDATE" }) do
    frame:RegisterEvent(event)
end
frame:SetScript("OnEvent", function(_, event, arg)
    if event == "ADDON_LOADED" and arg == addonName then Initialize() end
    if not ns.db then return end
    if event == "PLAYER_LOGIN" then StartSession() end
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
            C_Timer.After(0, function()
                ns.Changed()
                if ns.db.levelUpToasts and ns.QueueLevelUpToast then ns.QueueLevelUpToast(level) end
            end)
        end
    elseif event == "PLAYER_MONEY" then
        C_Timer.After(0, function() ns.ObserveMoney() end)
    else
        if ns.InstallGuards then ns.InstallGuards() end
        if event == "PLAYER_REGEN_ENABLED" and ns.FlushLevelUpToast then ns.FlushLevelUpToast() end
    end
end)

SLASH_GOLDENVELOPE1 = "/envelope"
SLASH_GOLDENVELOPE2 = "/ge"
SlashCmdList.GOLDENVELOPE = function(message)
    if not ns.db then return end
    if message:match("^%s*status%s*$") then
        local budget = ns.GetBudget()
        ns.Model.Reconcile(ns.db.goals, GetMoney())
        budget = ns.GetBudget()
        ns.Print("Wallet: " .. ns.Model.FormatCoins(budget.balance) .. "; saved toward goals: "
            .. ns.Model.FormatCoins(budget.saved) .. "; " .. (budget.behind > 0 and "behind: " or "ahead: ")
            .. ns.Model.FormatCoins(budget.behind > 0 and budget.behind or budget.ahead))
        for _, goal in ipairs(ns.db.goals) do
            if goal.active then
                local progress = ns.Model.GoalProgress(goal, UnitLevel("player"))
                if goal.targetCopper == 0 and goal.includeClassTraining then
                    ns.Print(goal.name .. ": funded " .. ns.Model.FormatCoins(budget.trainingFunded) .. " / " .. ns.Model.FormatCoins(budget.trainingDue))
                else ns.Print(goal.name .. ": " .. ns.Model.FormatCoins(progress.saved) .. " / "
                    .. ns.Model.FormatCoins(progress.target) .. string.format(" (%.1f%%)", progress.percent)
                    .. "; " .. (progress.behind > 0 and "behind " or "ahead ")
                    .. ns.Model.FormatCoins(progress.behind > 0 and progress.behind or progress.ahead))
                end
            end
        end
        if budget.trainingDue > 0 then ns.Print("Next two levels' training: " .. ns.Model.FormatCoins(budget.trainingDue)
            .. "; funded: " .. ns.Model.FormatCoins(budget.trainingFunded)) end
    elseif message:match("^%s*testtoast%s*$") then
        -- Temporary preview command while checking the toast in-game.
        if ns.TestLevelUpToast then ns.TestLevelUpToast() end
        ns.Print("Preview only; your goals and money are unchanged.")
    elseif message:match("^%s*toasts%s*$") then
        ns.db.levelUpToasts = not ns.db.levelUpToasts
        if not ns.db.levelUpToasts and ns.HideLevelUpToast then ns.HideLevelUpToast() end
        ns.Print("Level-up goal updates " .. (ns.db.levelUpToasts and "enabled." or "disabled."))
    else
        ns.ToggleUI()
    end
end
