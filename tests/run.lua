-- Run from the repository root with Lua 5.1+. No WoW client is needed.
unpack = unpack or table.unpack
local ns, tests = {}, 0
local function loadAddon(file)
    assert(loadfile("GoldEnvelope/" .. file))("GoldEnvelope", ns)
end
local function equal(actual, expected, label)
    assert(actual == expected, (label or "value") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function test(name, fn)
    fn()
    tests = tests + 1
    print("PASS " .. name)
end
local function goal(overrides)
    local result = { name = "Test", targetLevel = 21, targetCopper = 100000, curve = 2, active = true, milestones = {} }
    for key, value in pairs(overrides or {}) do result[key] = value end
    return result
end
loadAddon("Model.lua")
local Model = ns.Model

test("copper precision and input validation", function()
    equal(Model.ParseCoins("1", "2", "3"), 10203)
    equal(Model.ParseCoins("", "0", "1"), 1)
    equal(Model.ParseCoins("-1", "0", "0"), nil)
    equal(Model.ParseCoins("1.5", "0", "0"), nil)
    equal(Model.ParseCoins("0", "100", "0"), nil)
    equal(Model.ParseCoins("0", "0", "100"), nil)
    equal(Model.ParseCoins("100000000", "0", "1"), nil)
    equal(Model.FormatCoins(10203), "1g 2s 3c")
end)
test("curved saving starts small and reaches the full goal", function()
    local g = goal()
    equal(Model.TargetAtLevel(g, 1), 0)
    equal(Model.TargetAtLevel(g, 2), 250)
    equal(Model.TargetAtLevel(g, 11), 25000)
    equal(Model.TargetAtLevel(g, 21), 100000)
    equal(Model.TargetAtLevel(g, 60), 100000)
    assert(Model.TargetAtLevel(g, 20) - Model.TargetAtLevel(g, 19) > Model.TargetAtLevel(g, 3) - Model.TargetAtLevel(g, 2))
end)
test("linear saving and milestone interpolation", function()
    local g = goal({ curve = 1, milestones = { [11] = 20000 } })
    equal(Model.TargetAtLevel(g, 6), 10000)
    equal(Model.TargetAtLevel(g, 11), 20000)
    equal(Model.TargetAtLevel(g, 16), 60000)
end)
test("all curves and checkpoints stay monotonic and exact", function()
    for curve = 1, 4 do
        local g = goal({ curve = curve, milestones = { [5] = 123, [10] = 12000, [15] = 12000 } })
        assert(Model.ValidateGoal(g))
        local prior = 0
        for level = 1, 60 do
            local amount = Model.TargetAtLevel(g, level)
            assert(amount >= prior and amount <= g.targetCopper and amount == math.floor(amount))
            prior = amount
        end
        equal(Model.TargetAtLevel(g, 5), 123)
        equal(Model.TargetAtLevel(g, 10), 12000)
        equal(Model.TargetAtLevel(g, 15), 12000)
    end
end)
test("reject impossible savings plans", function()
    equal(Model.ValidateGoal(goal({ targetLevel = 1 })), nil)
    equal(Model.ValidateGoal(goal({ targetLevel = 61 })), nil)
    equal(Model.ValidateGoal(goal({ targetCopper = 0 })), nil)
    equal(Model.ValidateGoal(goal({ milestones = { [10] = 50000, [15] = 10000 } })), nil)
    equal(Model.ValidateGoal(goal({ milestones = { [21] = 10000 } })), nil)
    equal(Model.ValidateGoal(goal({ milestones = { [5] = 100001 } })), nil)
    equal(Model.ValidateGoal(goal({ milestones = { [5.5] = 1 } })), nil)
end)
test("separate goals add and inactive goals release their reserve", function()
    local goals = { goal(), goal({ targetCopper = 200000 }), goal({ active = false }) }
    equal(Model.Reserved(goals, 11), 75000)
    equal(Model.Budget(goals, 11, 100000).spendable, 25000)
    equal(Model.Budget(goals, 11, 50000).shortfall, 25000)
end)
test("exact limit, one copper over, free actions and existing shortfall", function()
    local goals = { goal() }
    equal(Model.Purchase(goals, 11, 30000, 5000).warning, false)
    equal(Model.Purchase(goals, 11, 30000, 5001).warning, true)
    equal(Model.Purchase(goals, 11, 20000, 0).warning, false)
    equal(Model.Purchase(goals, 11, 20000, 1).warning, true)
    equal(Model.Purchase(goals, 11, 20000, 20001).affordable, false)
end)

local money, level, executions, warnings = 30000, 11, 0, 0
local frames = {}
CreateFrame = function()
    local frame = { scripts = {} }
    function frame:RegisterEvent() end
    function frame:SetScript(name, callback) self.scripts[name] = callback end
    frames[#frames + 1] = frame
    return frame
end
DEFAULT_CHAT_FRAME = { AddMessage = function() end }
UnitLevel = function() return level end
GetMoney = function() return money end
C_Timer = { After = function(_, callback) callback() end }
SlashCmdList = {}
loadAddon("Core.lua")
ns.db = { goals = { goal() }, warnings = true }
ns.ShowWarning = function() warnings = warnings + 1 end
local currentAction
local function read() return currentAction end
local function execute() executions = executions + 1 end
local function reset(cost)
    ns.CancelPurchase()
    ns.db = { goals = { goal() }, warnings = true }
    ns.revision = 0
    money, level, executions, warnings = 30000, 11, 0, 0
    currentAction = { key = "item:1", label = "Item", cost = cost or 6000 }
end

test("cancel cannot spend and confirmation authorizes exactly once", function()
    reset()
    ns.RequestPurchase(read, execute)
    equal(executions, 0); equal(warnings, 1)
    ns.CancelPurchase(); ns.ConfirmPurchase(); equal(executions, 0)
    ns.RequestPurchase(read, execute); ns.ConfirmPurchase(); ns.ConfirmPurchase()
    equal(executions, 1)
end)
test("safe purchases proceed without a warning", function()
    reset(5000)
    ns.RequestPurchase(read, execute)
    equal(executions, 1); equal(warnings, 0)
end)
test("changed price or selection never uses a stale confirmation", function()
    reset(); ns.RequestPurchase(read, execute)
    currentAction = { key = "item:2", cost = 6000 }
    ns.ConfirmPurchase(); equal(executions, 0); equal(ns.pending, nil)
    reset(); ns.RequestPurchase(read, execute)
    currentAction = { key = "item:1", cost = 7000 }
    ns.ConfirmPurchase(); equal(executions, 0); equal(ns.pending, nil)
end)
test("closed windows and expired quotes cannot proceed", function()
    reset(); ns.RequestPurchase(read, execute); currentAction = nil
    ns.ConfirmPurchase(); equal(executions, 0)
    reset(); ns.RequestPurchase(read, execute)
    frames[1].scripts.OnEvent(nil, "MERCHANT_CLOSED")
    equal(ns.pending, nil); ns.ConfirmPurchase(); equal(executions, 0)
end)
test("balance, level and goal changes refresh risky confirmation", function()
    reset(); ns.RequestPurchase(read, execute); money = 29000
    ns.ConfirmPurchase(); equal(executions, 0); equal(warnings, 2)
    ns.ConfirmPurchase(); equal(executions, 1)
    reset(); ns.RequestPurchase(read, execute); level = 12
    ns.ConfirmPurchase(); equal(executions, 0); equal(warnings, 2)
    reset(); ns.RequestPurchase(read, execute); ns.db.goals[1].targetCopper = 110000; ns.Changed()
    ns.ConfirmPurchase(); equal(executions, 0); equal(warnings, 2)
end)
test("insufficient funds cannot proceed", function()
    reset(); ns.RequestPurchase(read, execute); money = 5999
    ns.ConfirmPurchase(); equal(executions, 0); equal(ns.pending, nil)
end)
test("invalid or non-finite transaction prices cannot proceed", function()
    for _, cost in ipairs({ -1, 0.5, math.huge, 0 / 0, Model.MAX_COPPER + 1 }) do
        reset(cost); ns.RequestPurchase(read, execute)
        equal(executions, 0); equal(ns.pending, nil)
    end
end)
test("a pending purchase cannot be replaced by another click", function()
    reset(); ns.RequestPurchase(read, execute)
    ns.RequestPurchase(function() return { key = "other", cost = 7000 } end, function() error("Wrong action") end)
    equal(warnings, 1); ns.ConfirmPurchase(); equal(executions, 1)
end)
test("new income can make an earlier risky purchase safe", function()
    reset(); ns.RequestPurchase(read, execute); money = 40000
    ns.ConfirmPurchase(); equal(executions, 1)
end)

-- Exercise actual UI wrappers, including late-loaded/reused Blizzard popups.
local function control(id, parent, callback)
    return { id = id, parent = parent, scripts = { OnClick = callback },
        GetID = function(self) return self.id end,
        GetParent = function(self) return self.parent end,
        GetScript = function(self, name) return self.scripts[name] end,
        SetScript = function(self, name, callback) self.scripts[name] = callback end,
        IsShown = function(self) return not self.hidden end,
        IsEnabled = function(self) return not self.disabled end,
        IsProtected = function() return false end }
end
InCombatLockdown = function() return false end
IsModifiedClick = function() return false end
hooksecurefunc = function() end
StaticPopup_Show = function() end
MerchantFrame = control(); MerchantFrame.selectedTab = 1
local merchantItem = { name = "Supply", price = 6000, stackCount = 5 }
C_MerchantFrame = { GetItemInfo = function() return merchantItem end }
GetMerchantItemLink = function() return "item:supply" end
MerchantItem1ItemButton = control(1, MerchantFrame, execute)
MerchantItem1ItemButton.SplitStack = execute
GetBuybackItemInfo = function() return "Sold item", nil, 6000, 1 end
GetBuybackItemLink = function() return "item:buyback" end
GetNumBuybackItems = function() return 1 end
GetRepairAllCost = function() return 6000, true end
MerchantRepairAllButton = control(0, MerchantFrame, execute)
MerchantBuyBackItemItemButton = control(0, MerchantFrame, execute)
AuctionHouseFrame = control()
local dialog = control(0, AuctionHouseFrame)
dialog.itemID, dialog.quantity = 123, 2
dialog.PriceFrame = { GetAmount = function() return 6000 end }
dialog.BuyNowButton = control(0, dialog, execute)
AuctionHouseFrame.BuyDialog = dialog
local quoteTime = 10
C_AuctionHouse = { GetQuoteDurationRemaining = function() return quoteTime end }
StaticPopup1 = control()
StaticPopup1.which = "BUYOUT_AUCTION"
StaticPopup1.data = { auctionID = 42, buyout = 6000 }
StaticPopup1.Button1 = control(0, StaticPopup1, execute)
ClassTrainerFrame = control()
ClassTrainerFrame.selectedService = 1
ClassTrainerTrainButton = control(0, ClassTrainerFrame, execute)
ClassTrainer_GetSkillIndexForDisplayIndex = function(index) return index end
GetTrainerServiceInfo = function() return "Learn spell", "available" end
GetTrainerServiceCost = function() return 6000 end
Enum = { TrainerType = { Pet = 2 } }
local trainerType = 1
C_Trainer = { GetTrainerType = function() return trainerType end }
loadAddon("Guards.lua")
ns.InstallGuards()

test("vendor bundle and stack quantity use total cost", function()
    reset(); MerchantFrame.selectedTab = 1
    MerchantItem1ItemButton.scripts.OnClick(MerchantItem1ItemButton, "RightButton")
    equal(warnings, 1); equal(ns.pending.action.cost, 6000); equal(executions, 0)
    ns.CancelPurchase()
    MerchantItem1ItemButton.SplitStack(MerchantItem1ItemButton, 10)
    equal(ns.pending.action.cost, 12000); equal(executions, 0)
    ns.ConfirmPurchase(); equal(executions, 1)
end)
test("vendor changes cancel pending stack purchase", function()
    reset(); MerchantItem1ItemButton.SplitStack(MerchantItem1ItemButton, 10)
    MerchantItem1ItemButton.id = 2
    ns.ConfirmPurchase(); equal(executions, 0)
    MerchantItem1ItemButton.id = 1
end)
test("buyback and repair-all wait for confirmation", function()
    reset(); MerchantFrame.selectedTab = 2
    MerchantItem1ItemButton.scripts.OnClick(MerchantItem1ItemButton, "LeftButton")
    equal(executions, 0); equal(warnings, 1); ns.ConfirmPurchase(); equal(executions, 1)
    reset(); MerchantFrame.selectedTab = 1
    MerchantRepairAllButton.scripts.OnClick(MerchantRepairAllButton, "LeftButton")
    equal(executions, 0); ns.CancelPurchase(); equal(executions, 0)
end)
test("commodity confirmation rejects expired quotes", function()
    reset(); quoteTime = 10
    dialog.BuyNowButton.scripts.OnClick(dialog.BuyNowButton, "LeftButton")
    equal(executions, 0); equal(warnings, 1)
    quoteTime = 0; ns.ConfirmPurchase(); equal(executions, 0)
    quoteTime = 10
end)
test("auction buyout and bid use exact native popup amounts", function()
    reset()
    StaticPopup1.Button1.scripts.OnClick(StaticPopup1.Button1, "LeftButton")
    equal(executions, 0); equal(ns.pending.action.cost, 6000)
    ns.ConfirmPurchase(); equal(executions, 1)
    reset(); StaticPopup1.which = "BID_AUCTION"; StaticPopup1.data = { auctionID = 43, bid = 5001 }
    StaticPopup1.Button1.scripts.OnClick(StaticPopup1.Button1, "LeftButton")
    equal(executions, 0); equal(ns.pending.action.cost, 5001)
    ns.CancelPurchase()
end)
test("training warns, changed services cancel, pet points are not coins", function()
    reset()
    ClassTrainerTrainButton.scripts.OnClick(ClassTrainerTrainButton, "LeftButton")
    equal(executions, 0); equal(warnings, 1)
    ClassTrainerFrame.selectedService = 2
    ns.ConfirmPurchase(); equal(executions, 0)
    ClassTrainerFrame.selectedService = 1
    reset(); trainerType = 2
    ClassTrainerTrainButton.scripts.OnClick(ClassTrainerTrainButton, "LeftButton")
    equal(executions, 1); equal(warnings, 0)
    trainerType = 1
end)
test("unrelated reused popups and modified clicks retain native behavior", function()
    reset(); StaticPopup1.which = "CONFIRM_LOGOUT"
    StaticPopup1.Button1.scripts.OnClick(StaticPopup1.Button1, "LeftButton")
    equal(executions, 1); equal(warnings, 0)
    reset(); IsModifiedClick = function() return true end
    MerchantItem1ItemButton.scripts.OnClick(MerchantItem1ItemButton, "RightButton")
    equal(executions, 1); equal(warnings, 0)
    IsModifiedClick = function() return false end
end)
test("reinstalling guards never duplicates confirmations", function()
    reset(); ns.InstallGuards(); ns.InstallGuards()
    MerchantItem1ItemButton.scripts.OnClick(MerchantItem1ItemButton, "RightButton")
    equal(warnings, 1); ns.ConfirmPurchase(); equal(executions, 1)
end)

-- Smoke-test the real editor and warning with frame stubs, not duplicated UI logic.
local uiControls = {}
local function uiControl(parent)
    local result = { parent = parent, scripts = {}, hidden = true }
    local methods = {}
    function methods:SetText(text) self.text = tostring(text) end
    function methods:GetText() return self.text or "" end
    function methods:SetChecked(value) self.checked = value end
    function methods:GetChecked() return self.checked end
    function methods:SetScript(name, callback) self.scripts[name] = callback end
    function methods:SetEnabled(value) self.disabled = not value end
    function methods:IsShown() return not self.hidden end
    function methods:Show() self.hidden = false end
    function methods:Hide()
        local wasShown = not self.hidden
        self.hidden = true
        if wasShown and self.scripts.OnHide then self.scripts.OnHide(self) end
    end
    function methods:CreateFontString() return uiControl(self) end
    setmetatable(result, { __index = function(_, key) return methods[key] or function() end end })
    uiControls[#uiControls + 1] = result
    return result
end
CreateFrame = function(_, _, parent) return uiControl(parent) end
UIParent, UISpecialFrames, tinsert = {}, {}, table.insert
local function click(parent, text)
    for _, candidate in ipairs(uiControls) do
        if candidate.parent == parent and candidate.text == text and candidate.scripts.OnClick then
            candidate.scripts.OnClick(candidate, "LeftButton")
            return
        end
    end
    error("Missing button " .. text)
end
loadAddon("UI.lua")
test("editor saves a custom goal and checkpoint into the actual budget", function()
    reset(); ns.db.goals = {}
    ns.ToggleUI()
    assert(ns.ui:IsShown())
    ns.ui.name:SetText("My savings")
    ns.ui.level:SetText("21")
    ns.ui.amount[1]:SetText("10")
    ns.ui.amount[2]:SetText("0")
    ns.ui.amount[3]:SetText("0")
    ns.ui.milestoneLevel:SetText("11")
    ns.ui.milestoneAmount[1]:SetText("2")
    ns.ui.milestoneAmount[2]:SetText("50")
    ns.ui.milestoneAmount[3]:SetText("0")
    click(ns.ui, "Set"); click(ns.ui, "Save goal")
    equal(#ns.db.goals, 1); equal(ns.db.goals[1].name, "My savings")
    equal(ns.db.goals[1].milestones[11], 25000)
    equal(ns.GetBudget().reserved, 25000)
    ns.ui.active:SetChecked(false); click(ns.ui, "Save goal")
    equal(ns.GetBudget().reserved, 0)
end)
test("actual warning buttons cancel or authorize a single purchase", function()
    reset(); ns.RequestPurchase(read, execute)
    assert(ns.warningFrame:IsShown()); equal(executions, 0)
    click(ns.warningFrame, "Cancel"); equal(executions, 0); equal(ns.pending, nil)
    ns.RequestPurchase(read, execute); click(ns.warningFrame, "Spend anyway")
    equal(executions, 1); equal(ns.pending, nil)
end)
print(string.format("%d tests passed", tests))
