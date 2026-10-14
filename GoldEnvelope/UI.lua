local _, ns = ...
local Model = ns.Model
local selected, draft = 1, nil

local function label(parent, text, x, y, width, font)
    local region = parent:CreateFontString(nil, "OVERLAY", font or "GameFontNormal")
    region:SetPoint("TOPLEFT", x, y)
    region:SetWidth(width or 540)
    region:SetJustifyH("LEFT")
    region:SetText(text)
    return region
end

local function button(parent, text, x, y, width, callback)
    local control = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    control:SetSize(width or 110, 24)
    control:SetPoint("TOPLEFT", x, y)
    control:SetText(text)
    control:SetScript("OnClick", callback)
    return control
end

local function edit(parent, x, y, width, text, numeric)
    local control = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    control:SetSize(width, 24)
    control:SetPoint("TOPLEFT", x, y)
    control:SetAutoFocus(false)
    control:SetMaxLetters(numeric and 12 or 60)
    if numeric then control:SetNumeric(true) end
    control:SetText(text or "")
    control:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    control:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    return control
end

local function coins(parent, x, y)
    local controls = {}
    for i, part in ipairs({ "Gold", "Silver", "Copper" }) do
        label(parent, part, x + (i - 1) * 90, y + 18, 80, "GameFontNormalSmall")
        controls[i] = edit(parent, x + (i - 1) * 90, y, 75, "", true)
    end
    return controls
end

local function setCoins(controls, amount)
    local parts = { Model.SplitCoins(amount) }
    for i = 1, 3 do controls[i]:SetText(tostring(parts[i])) end
end

local function getCoins(controls)
    return Model.ParseCoins(controls[1]:GetText(), controls[2]:GetText(), controls[3]:GetText())
end

local function copyGoal(goal)
    local result = { name = goal.name, targetLevel = goal.targetLevel, targetCopper = goal.targetCopper,
        curve = goal.curve, active = goal.active, milestones = {} }
    for level, amount in pairs(goal.milestones) do result.milestones[level] = amount end
    return result
end

local function window(name, width, height, title)
    local frame = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
    frame:SetSize(width, height)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 32,
        edgeSize = 32, insets = { left = 11, right = 12, top = 12, bottom = 11 } })
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    label(frame, title, 24, -22, width - 48, "GameFontNormalLarge")
    tinsert(UISpecialFrames, name)
    frame:Hide()
    return frame
end

local function readEditor()
    local ui = ns.ui
    local goal = copyGoal(draft)
    goal.name = ui.name:GetText():match("^%s*(.-)%s*$")
    goal.targetLevel = tonumber(ui.level:GetText())
    local amount, errorText = getCoins(ui.amount)
    if not amount then return nil, errorText end
    goal.targetCopper = amount
    goal.active = ui.active:GetChecked() and true or false
    local valid, validationError = Model.ValidateGoal(goal)
    if not valid then return nil, validationError end
    return goal
end

local function preview(goal)
    local lines = { "Level       Reserved for this goal       Add since prior level" }
    for level = 1, Model.MAX_LEVEL do
        local amount = Model.TargetAtLevel(goal, level)
        local prior = Model.TargetAtLevel(goal, math.max(1, level - 1))
        local milestone = goal.milestones[level] ~= nil or level == goal.targetLevel
        lines[#lines + 1] = string.format("%2d%s        %s        +%s", level,
            milestone and "*" or " ", Model.FormatCoins(amount), Model.FormatCoins(amount - prior))
    end
    return table.concat(lines, "\n")
end

local function showEditor()
    local ui = ns.ui
    local goal = ns.db.goals[selected]
    draft = goal and copyGoal(goal) or { name = "", targetLevel = 40, targetCopper = 0,
        curve = 2, active = true, milestones = {} }
    ui.selection:SetText(goal and ("Goal " .. selected .. " of " .. #ns.db.goals) or "New goal")
    ui.name:SetText(draft.name)
    ui.level:SetText(tostring(draft.targetLevel))
    setCoins(ui.amount, draft.targetCopper)
    ui.active:SetChecked(draft.active)
    ui.curve:SetText("Savings curve: " .. draft.curve)
    ui.milestoneLevel:SetText(tostring(math.min(UnitLevel("player"), draft.targetLevel - 1)))
    setCoins(ui.milestoneAmount, 0)
    ui.error:SetText("")
    ui.previewText:SetText(goal and preview(goal) or "Enter a final amount and save your goal to see its level plan.")
    ui.scroll:SetVerticalScroll(0)
    ui.delete:SetEnabled(goal ~= nil)
    ns.RefreshUI()
end

function ns.RefreshUI()
    if not ns.ui or not ns.db then return end
    local budget = ns.GetBudget()
    ns.ui.summary:SetText("Level " .. UnitLevel("player") .. "  |  Balance: " .. Model.FormatCoins(budget.balance)
        .. "\nReserved today: " .. Model.FormatCoins(budget.reserved)
        .. "  |  Available to spend: " .. Model.FormatCoins(budget.spendable)
        .. (budget.shortfall > 0 and ("\nBehind today's plan by " .. Model.FormatCoins(budget.shortfall)) or ""))
    ns.ui.warnings:SetChecked(ns.db.warnings)
end

local function createUI()
    local ui = window("GoldEnvelopeWindow", 650, 680, "Gold Envelope")
    ns.ui = ui
    button(ui, "Close", 554, -18, 70, function() ui:Hide() end)
    ui.summary = label(ui, "", 24, -56, 602, "GameFontHighlight")
    ui.selection = label(ui, "", 24, -124, 170)
    button(ui, "Previous", 214, -118, 90, function()
        if #ns.db.goals > 0 then selected = math.max(1, math.min(#ns.db.goals, selected - 1)); showEditor() end
    end)
    button(ui, "Next", 314, -118, 90, function()
        if #ns.db.goals > 0 then selected = math.min(#ns.db.goals, selected + 1); showEditor() end
    end)
    button(ui, "New goal", 414, -118, 100, function() selected = #ns.db.goals + 1; showEditor() end)
    label(ui, "Goal name", 24, -159, 100)
    ui.name = edit(ui, 140, -153, 450)
    label(ui, "Save by level", 24, -196, 110)
    ui.level = edit(ui, 140, -190, 60, "40", true)
    ui.amount = coins(ui, 260, -190)
    ui.active = CreateFrame("CheckButton", nil, ui, "UICheckButtonTemplate")
    ui.active:SetPoint("TOPLEFT", 20, -229)
    label(ui, "Reserve money for this goal (uncheck when ready to use it)", 54, -237, 560, "GameFontHighlightSmall")
    ui.curve = button(ui, "", 24, -273, 180, function()
        draft.curve = draft.curve % 4 + 1
        ui.curve:SetText("Savings curve: " .. draft.curve)
    end)
    label(ui, "1 = even saving; 2-4 = more saving at later levels.", 220, -280, 400, "GameFontHighlightSmall")
    label(ui, "Optional checkpoint: have this much saved at this level", 24, -320, 590)
    ui.milestoneLevel = edit(ui, 30, -354, 55, "", true)
    label(ui, "Level", 30, -336, 60, "GameFontNormalSmall")
    ui.milestoneAmount = coins(ui, 110, -354)
    button(ui, "Set", 396, -354, 85, function()
        local amount, coinError = getCoins(ui.milestoneAmount)
        local level = tonumber(ui.milestoneLevel:GetText())
        if not level or level ~= math.floor(level) or level < 2 or level > Model.MAX_LEVEL then
            ui.error:SetText("Checkpoint level must be a whole number from 2 to 60."); return
        end
        if not amount then ui.error:SetText(coinError); return end
        local previous = draft.milestones[level]
        draft.milestones[level] = amount
        local goal, errorText = readEditor()
        if not goal then draft.milestones[level] = previous; ui.error:SetText(errorText); return end
        ui.previewText:SetText(preview(goal)); ui.error:SetText("Checkpoint set; click Save goal to keep changes.")
    end)
    button(ui, "Remove", 490, -354, 100, function()
        local level = tonumber(ui.milestoneLevel:GetText())
        if level then draft.milestones[level] = nil end
        local goal, errorText = readEditor()
        ui.error:SetText(goal and "Checkpoint removed; click Save goal to keep changes." or errorText)
        if goal then ui.previewText:SetText(preview(goal)) end
    end)
    label(ui, "Savings plan (* = checkpoint). Amounts are cumulative.", 24, -402, 595, "GameFontHighlightSmall")
    ui.scroll = CreateFrame("ScrollFrame", "GoldEnvelopePlanScroll", ui, "UIPanelScrollFrameTemplate")
    ui.scroll:SetPoint("TOPLEFT", 25, -426)
    ui.scroll:SetSize(565, 132)
    local content = CreateFrame("Frame", nil, ui.scroll)
    content:SetSize(560, 1050)
    ui.previewText = label(content, "", 0, 0, 555, "GameFontHighlightSmall")
    ui.previewText:SetSpacing(3)
    ui.scroll:SetScrollChild(content)
    ui.error = label(ui, "", 24, -566, 590, "GameFontHighlightSmall")
    ui.error:SetTextColor(1, 0.65, 0.35)
    button(ui, "Save goal", 24, -601, 110, function()
        local goal, errorText = readEditor()
        if not goal then ui.error:SetText(errorText); return end
        ns.db.goals[selected] = goal
        ns.Changed(); showEditor(); ui.error:SetText("Goal saved.")
    end)
    ui.delete = button(ui, "Delete goal", 145, -601, 110, function()
        if ns.db.goals[selected] then table.remove(ns.db.goals, selected) end
        selected = math.max(1, math.min(selected, #ns.db.goals))
        ns.Changed(); showEditor()
    end)
    ui.warnings = CreateFrame("CheckButton", nil, ui, "UICheckButtonTemplate")
    ui.warnings:SetPoint("TOPLEFT", 20, -635)
    label(ui, "Confirm before spending reserved savings", 54, -643, 550, "GameFontHighlightSmall")
    ui.warnings:SetScript("OnClick", function(self)
        ns.db.warnings = self:GetChecked() and true or false
        ns.CancelPurchase(); ns.Changed()
    end)
end

function ns.ToggleUI()
    if not ns.ui then createUI(); showEditor() end
    if ns.ui:IsShown() then ns.ui:Hide() else ns.RefreshUI(); ns.ui:Show() end
end

function ns.ShowWarning(pending)
    if not ns.warningFrame then
        local frame = window("GoldEnvelopeSavingsWarning", 430, 286, "This uses your savings")
        ns.warningFrame = frame
        frame:SetFrameLevel(3000)
        frame.body = label(frame, "", 26, -57, 378, "GameFontHighlight")
        frame.body:SetSpacing(5)
        frame:SetScript("OnHide", function() ns.pending = nil end)
        button(frame, "Spend anyway", 36, -242, 155, ns.ConfirmPurchase)
        button(frame, "Cancel", 233, -242, 155, ns.CancelPurchase)
    end
    local budget = pending.budget
    ns.warningFrame.body:SetText(string.format("%s\n\nCost: %s\nBalance after spending: %s\nReserved at level %d: %s\nShortfall after spending: %s",
        pending.action.label or "Purchase", Model.FormatCoins(budget.cost), Model.FormatCoins(budget.remaining),
        UnitLevel("player"), Model.FormatCoins(budget.reserved), Model.FormatCoins(budget.afterShortfall)))
    ns.warningFrame:Show()
end
