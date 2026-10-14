local addonName, ns = ...
ns.name = addonName
ns.revision = 0

function ns.Print(text)
    DEFAULT_CHAT_FRAME:AddMessage("|cffffd36eGold Envelope:|r " .. text)
end

function ns.GetBudget()
    return ns.Model.Budget(ns.db.goals, UnitLevel("player"), GetMoney())
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
    local budget = ns.Model.Purchase(ns.db.goals, UnitLevel("player"), GetMoney(), action.cost)
    if not budget.affordable then ns.Print("You do not have enough money for this purchase."); return end
    if ns.db.warnings and budget.warning then
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
    local budget = ns.Model.Purchase(ns.db.goals, UnitLevel("player"), GetMoney(), action.cost)
    if not budget.affordable then ns.Print("You no longer have enough money for this purchase."); return end
    if budget.warning and (budget.balance ~= pending.budget.balance
        or budget.reserved ~= pending.budget.reserved or pending.revision ~= ns.revision) then
        ns.RequestPurchase(pending.read, pending.execute)
        return
    end
    pending.execute()
end

local function Initialize()
    GoldEnvelopeDB = type(GoldEnvelopeDB) == "table" and GoldEnvelopeDB or {}
    ns.db = GoldEnvelopeDB
    ns.db.version = 1
    if ns.db.warnings == nil then ns.db.warnings = true end
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
        C_Timer.After(0, function() ns.Changed() end)
    elseif event == "PLAYER_MONEY" then
        if ns.RefreshUI then ns.RefreshUI() end
    else
        if ns.InstallGuards then ns.InstallGuards() end
    end
end)

SLASH_GOLDENVELOPE1 = "/envelope"
SLASH_GOLDENVELOPE2 = "/ge"
SlashCmdList.GOLDENVELOPE = function(message)
    if not ns.db then return end
    if message:match("^%s*status%s*$") then
        local budget = ns.GetBudget()
        ns.Print("Balance: " .. ns.Model.FormatCoins(budget.balance) .. "; reserved: "
            .. ns.Model.FormatCoins(budget.reserved) .. "; available: " .. ns.Model.FormatCoins(budget.spendable))
    else
        ns.ToggleUI()
    end
end
