local _, ns = ...
local Model = ns.Model
local selected, draft = 1, nil

local coinTextures = {
    "Interface\\MoneyFrame\\UI-GoldIcon",
    "Interface\\MoneyFrame\\UI-SilverIcon",
    "Interface\\MoneyFrame\\UI-CopperIcon",
}

-- Keep chat output plain; use Blizzard's coin art in the native UI.
function ns.MoneyText(amount)
    local values = { Model.SplitCoins(amount) }
    local parts = {}
    for i = 1, 3 do
        parts[i] = values[i] .. " |T" .. coinTextures[i] .. ":14:14:1:0|t"
    end
    return table.concat(parts, "  ")
end

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
        local fieldX = x + (i - 1) * 90
        controls[i] = edit(parent, fieldX, y, 55, "", true)
        local icon = parent:CreateTexture(nil, "ARTWORK")
        icon:SetSize(16, 16)
        icon:SetPoint("TOPLEFT", fieldX + 61, y - 4)
        icon:SetTexture(coinTextures[i])
        controls[i]:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(part)
            GameTooltip:Show()
        end)
        controls[i]:SetScript("OnLeave", function() GameTooltip:Hide() end)
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
    return Model.CopyGoal(goal)
end

local function window(name, width, height, title)
    local frame = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
    frame:SetSize(width, height)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16,
        edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 } })
    frame:SetBackdropColor(0.055, 0.04, 0.025, 0.96)
    frame:SetBackdropBorderColor(0.64, 0.58, 0.47, 1)
    local header = frame:CreateTexture(nil, "BACKGROUND")
    header:SetPoint("TOPLEFT", 5, -5)
    header:SetPoint("TOPRIGHT", -5, -5)
    header:SetHeight(39)
    header:SetColorTexture(0.16, 0.11, 0.065, 0.85)
    local divider = frame:CreateTexture(nil, "BORDER")
    divider:SetPoint("TOPLEFT", 8, -44)
    divider:SetPoint("TOPRIGHT", -8, -44)
    divider:SetHeight(1)
    divider:SetColorTexture(0.65, 0.48, 0.22, 0.65)
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

ns.UI = { Label = label, Button = button, Edit = edit, Coins = coins, SetCoins = setCoins,
    GetCoins = getCoins, Window = window }

local function readEditor(skipValidation)
    local ui = ns.ui
    local goal = copyGoal(draft)
    goal.name = ui.name:GetText():match("^%s*(.-)%s*$")
    goal.targetLevel = tonumber(ui.level:GetText())
    local amount, errorText = getCoins(ui.amount)
    if not amount then return nil, errorText end
    goal.targetCopper = amount
    goal.active = ui.active:GetChecked() and true or false
    if goal.planMode == "items" then ns.SyncExpenses(goal) end
    if not skipValidation then
        local valid, validationError = Model.ValidateGoal(goal)
        if not valid then return nil, validationError end
    end
    return goal
end

local function renderPlan(goal)
    local ui = ns.ui
    ui.planRows = ui.planRows or {}
    for _, row in ipairs(ui.planRows) do row:Hide() end
    ui.planEmpty:SetShown(goal == nil)
    if not goal then ui.planContent:SetHeight(1); return end
    local currentLevel = UnitLevel("player")
    for level = 1, Model.MAX_LEVEL do
        local row = ui.planRows[level]
        if not row then
            row = CreateFrame("Frame", nil, ui.planContent)
            row:SetSize(580, 22)
            row:SetPoint("TOPLEFT", 0, -(level - 1) * 22)
            row.background = row:CreateTexture(nil, "BACKGROUND")
            row.background:SetAllPoints()
            row.level = label(row, "", 0, -3, 50, "GameFontHighlightSmall")
            row.reserve = label(row, "", 62, -3, 258, "GameFontHighlightSmall")
            row.addition = label(row, "", 332, -3, 246, "GameFontHighlightSmall")
            ui.planRows[level] = row
        end
        local amount = Model.TargetAtLevel(goal, level)
        local prior = Model.TargetAtLevel(goal, math.max(1, level - 1))
        local checkpoint = goal.planMode ~= "items" and (goal.milestones[level] ~= nil or level == goal.targetLevel)
        row.level:SetText(level .. (checkpoint and " *" or ""))
        row.reserve:SetText(ns.MoneyText(amount))
        row.addition:SetText("+ " .. ns.MoneyText(amount - prior))
        row.background:SetColorTexture(0.65, 0.48, 0.22, level == currentLevel and 0.35 or (level % 2 == 0 and 0.07 or 0))
        row:Show()
    end
    ui.planContent:SetHeight(Model.MAX_LEVEL * 22)
end

local refreshGoalList
local function showEditor(presetGoal)
    if ns.ClosePlanningWindows then ns.ClosePlanningWindows() end
    local ui = ns.ui
    local goal = ns.db.goals[selected]
    draft = presetGoal or (goal and copyGoal(goal)) or { name = "", targetLevel = 40, targetCopper = 0,
        curve = 2, active = true, milestones = {} }
    ui.selection:SetText(goal and ("Goal " .. selected .. " of " .. #ns.db.goals) or "New goal")
    ui.name:SetText(draft.name)
    ui.level:SetText(tostring(draft.targetLevel))
    setCoins(ui.amount, draft.targetCopper)
    ui.active:SetChecked(draft.active)
    for _, control in ipairs(ui.amount) do
        if draft.planMode == "items" then control:Disable() else control:Enable() end
    end
    ui.curve:SetText("Savings curve: " .. draft.curve)
    ui.milestoneLevel:SetText(tostring(math.min(UnitLevel("player"), draft.targetLevel - 1)))
    setCoins(ui.milestoneAmount, 0)
    ui.error:SetText("")
    renderPlan((draft.targetCopper > 0 or draft.planMode == "items") and draft or nil)
    local preset = ns.FindPreset(draft.presetID)
    ui.presetHint:SetText(preset and preset.note or "")
    ui.planning:SetText(draft.planMode == "items" and "Choose expenses" or "Customize planning")
    ui.scroll:SetVerticalScroll(math.max(0, math.min(55, UnitLevel("player") - 3)) * 22)
    ui.delete:SetEnabled(goal ~= nil)
    ns.RefreshUI()
    if refreshGoalList then refreshGoalList() end
end

local function planCurrentGoal()
    local goal, errorText = readEditor(true)
    if not goal then ns.ui.error:SetText(errorText); return end
    if not goal.targetLevel or goal.targetLevel < 2 or goal.targetLevel > Model.MAX_LEVEL
        or goal.targetLevel ~= math.floor(goal.targetLevel) then ns.ui.error:SetText("Choose a target level from 2 to 60 first."); return end
    local function open()
        ns.EnableItemPlanning(goal)
        ns.OpenExpensePlanner(goal, function(updated) showEditor(updated) end)
    end
    if goal.planMode == "items" then open() else
        ns.AskGoalPlanning(goal, open, function()
            goal.planDecision = "simple"; showEditor(goal)
        end)
    end
end

local function saveCurrentGoal()
    local goal, errorText = readEditor(true)
    if not goal then ns.ui.error:SetText(errorText); return end
    if not goal.name:match("%S") then ns.ui.error:SetText("Give your goal a name."); return end
    if not goal.targetLevel or goal.targetLevel < 2 or goal.targetLevel > Model.MAX_LEVEL
        or goal.targetLevel ~= math.floor(goal.targetLevel) then ns.ui.error:SetText("Choose a target level from 2 to 60."); return end
    local function save()
        local valid, validationError = Model.ValidateGoal(goal)
        if not valid then ns.ui.error:SetText(validationError); return end
        ns.db.goals[selected] = goal
        ns.Changed(); showEditor(); ns.ui.error:SetText("Goal saved.")
    end
    if UnitLevel("player") < 60 and not goal.planDecision then
        ns.AskGoalPlanning(goal, function()
            ns.EnableItemPlanning(goal)
            ns.OpenExpensePlanner(goal, function(updated) showEditor(updated) end)
        end, function()
            goal.planDecision = "simple"; draft.planDecision = "simple"; save()
        end)
    else save() end
end

function ns.CatalogChanged()
    if draft and draft.planMode == "items" then
        ns.SyncExpenses(draft)
        setCoins(ns.ui.amount, draft.targetCopper)
        renderPlan(draft)
    end
    if ns.RefreshExpensePlanner then ns.RefreshExpensePlanner() end
end

function ns.UsePreset(id)
    local presetGoal = ns.NewPresetGoal(id)
    if not presetGoal then return end
    for index, goal in ipairs(ns.db.goals) do
        if goal.presetID == id then
            selected = index
            showEditor()
            return
        end
    end
    selected = #ns.db.goals + 1
    showEditor(presetGoal)
    ns.ui.error:SetText("Adjust the budget if needed, then click Save goal.")
end

function ns.RefreshUI()
    if not ns.ui or not ns.db then return end
    local budget = ns.GetBudget()
    ns.ui.summary:SetText("Level " .. UnitLevel("player") .. "  |  Balance: " .. ns.MoneyText(budget.balance)
        .. "\nReserved today: " .. ns.MoneyText(budget.reserved)
        .. "  |  Available to spend: " .. ns.MoneyText(budget.spendable)
        .. (budget.shortfall > 0 and ("\nBehind today's plan by " .. ns.MoneyText(budget.shortfall)) or ""))
    ns.ui.warnings:SetChecked(ns.db.warnings)
    if refreshGoalList then refreshGoalList() end
end

refreshGoalList = function()
    local ui = ns.ui
    if not ui or not ui.goalContent then return end
    ui.goalRows = ui.goalRows or {}
    for _, row in ipairs(ui.goalRows) do row:Hide() end
    for index, goal in ipairs(ns.db.goals) do
        local goalIndex = index
        local row = ui.goalRows[index]
        if not row then
            row = CreateFrame("Button", nil, ui.goalContent)
            row:SetSize(178, 48)
            row:SetNormalTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
            row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
            row.name = label(row, "", 30, -5, 143, "GameFontHighlightSmall")
            row.name:SetWordWrap(false)
            row.level = label(row, "", 30, -26, 143, "GameFontNormalSmall")
            row.icon = row:CreateTexture(nil, "ARTWORK")
            row.icon:SetSize(22, 22)
            row.icon:SetPoint("TOPLEFT", 4, -8)
            ui.goalRows[index] = row
        end
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, -(index - 1) * 52)
        row.name:SetText(goal.name)
        row.level:SetText("Level " .. goal.targetLevel .. (goal.active and "" or "  (paused)"))
        local preset = ns.FindPreset(goal.presetID)
        row.icon:SetTexture(preset and preset.icon or "Interface\\Icons\\INV_Misc_Coin_01")
        row:GetNormalTexture():SetAlpha(selected == index and 0.45 or 0.08)
        row:SetScript("OnClick", function() selected = goalIndex; showEditor() end)
        row:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(goal.name)
            GameTooltip:AddLine("Reserved today: " .. ns.MoneyText(Model.TargetAtLevel(goal, UnitLevel("player"))))
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)
        row:Show()
    end
    ui.goalContent:SetHeight(math.max(1, #ns.db.goals * 52))
    ui.emptyGoals:SetShown(#ns.db.goals == 0)
end

local function createUI()
    local ui = window("GoldEnvelopeWindow", 900, 680, "Gold Envelope")
    ns.ui = ui
    button(ui, "Close", 804, -15, 70, function() ui:Hide() end)
    ui.summary = label(ui, "", 24, -58, 852, "GameFontHighlight")
    label(ui, "Your goals", 24, -125, 180)
    ui.goalScroll = CreateFrame("ScrollFrame", "GoldEnvelopeGoalScroll", ui, "UIPanelScrollFrameTemplate")
    ui.goalScroll:SetPoint("TOPLEFT", 20, -154)
    ui.goalScroll:SetSize(178, 388)
    ui.goalContent = CreateFrame("Frame", nil, ui.goalScroll)
    ui.goalContent:SetSize(178, 1)
    ui.goalScroll:SetScrollChild(ui.goalContent)
    ui.emptyGoals = label(ui, "No goals yet.\nChoose a preset or create your own.", 24, -162, 174, "GameFontHighlightSmall")
    button(ui, "New goal", 24, -559, 174, function() selected = #ns.db.goals + 1; showEditor() end)
    button(ui, "Presets", 24, -591, 174, function()
        if not ui.presetPicker then
            local count = #ns.Presets
            local picker = window("GoldEnvelopePresetPicker", 360, 132 + count * 45, "Goal presets")
            ui.presetPicker = picker
            picker:SetFrameLevel(ui:GetFrameLevel() + 10)
            for index, preset in ipairs(ns.Presets) do
                local id = preset.id
                local text = "|T" .. preset.icon .. ":18:18|t " .. preset.name
                button(picker, text, 24, -56 - (index - 1) * 45, 312, function()
                    picker:Hide(); ns.UsePreset(id)
                end)
            end
            label(picker, "Nothing is reserved until you save your goal.", 24, -60 - count * 45, 312, "GameFontHighlightSmall")
            button(picker, "Close", 230, -98 - count * 45, 106, function() picker:Hide() end)
        end
        if ui.presetPicker:IsShown() then ui.presetPicker:Hide() else ui.presetPicker:Show() end
    end)
    local editor = CreateFrame("Frame", nil, ui)
    editor:SetPoint("TOPLEFT", 224, -120)
    editor:SetSize(650, 512)
    ui.editor = editor
    ui.selection = label(editor, "", 12, -5, 600)
    label(editor, "Goal name", 12, -45, 100)
    ui.name = edit(editor, 128, -39, 480)
    label(editor, "Save by level", 12, -82, 110)
    ui.level = edit(editor, 128, -76, 60, "40", true)
    ui.amount = coins(editor, 248, -76)
    ui.active = CreateFrame("CheckButton", nil, editor, "UICheckButtonTemplate")
    ui.active:SetPoint("TOPLEFT", 8, -111)
    label(editor, "Reserve this goal (uncheck when ready to spend it)", 42, -119, 568, "GameFontHighlightSmall")
    ui.presetHint = label(editor, "", 12, -140, 600, "GameFontHighlightSmall")
    ui.curve = button(editor, "", 12, -163, 180, function()
        draft.curve = draft.curve % 4 + 1
        ui.curve:SetText("Savings curve: " .. draft.curve)
    end)
    label(editor, "1 = even saving; 2-4 = more saving later.", 208, -170, 405, "GameFontHighlightSmall")
    ui.planning = button(editor, "Customize planning", 12, -196, 180, planCurrentGoal)
    label(editor, "Optional: choose individual costs to include.", 208, -203, 405, "GameFontHighlightSmall")
    label(editor, "Optional checkpoint: cumulative savings by level", 12, -239, 590)
    ui.milestoneLevel = edit(editor, 18, -270, 55, "", true)
    label(editor, "Level", 18, -253, 60, "GameFontNormalSmall")
    ui.milestoneAmount = coins(editor, 98, -270)
    button(editor, "Set", 384, -270, 85, function()
        if draft.planMode == "items" then ui.error:SetText("Itemized plans use each expense's due level."); return end
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
        renderPlan(goal); ui.error:SetText("Checkpoint set; click Save goal to keep changes.")
    end)
    button(editor, "Remove", 478, -270, 100, function()
        local level = tonumber(ui.milestoneLevel:GetText())
        if level then draft.milestones[level] = nil end
        local goal, errorText = readEditor()
        ui.error:SetText(goal and "Checkpoint removed; click Save goal to keep changes." or errorText)
        if goal then renderPlan(goal) end
    end)
    label(editor, "Savings plan (* = checkpoint). Your current level is highlighted.", 12, -311, 610, "GameFontHighlightSmall")
    label(editor, "Level", 13, -334, 50, "GameFontNormalSmall")
    label(editor, "Reserved", 75, -334, 258, "GameFontNormalSmall")
    label(editor, "Add This Level", 345, -334, 246, "GameFontNormalSmall")
    ui.scroll = CreateFrame("ScrollFrame", "GoldEnvelopePlanScroll", editor, "UIPanelScrollFrameTemplate")
    ui.scroll:SetPoint("TOPLEFT", 13, -355)
    ui.scroll:SetSize(589, 106)
    local content = CreateFrame("Frame", nil, ui.scroll)
    content:SetSize(584, 1350)
    ui.planContent = content
    ui.planEmpty = label(editor, "Enter a final amount and save your goal to see its level plan.", 16, -361, 570, "GameFontHighlightSmall")
    ui.scroll:SetScrollChild(content)
    ui.error = label(editor, "", 12, -470, 620, "GameFontHighlightSmall")
    ui.error:SetTextColor(1, 0.65, 0.35)
    button(editor, "Save goal", 12, -507, 110, saveCurrentGoal)
    ui.delete = button(editor, "Delete goal", 133, -507, 110, function()
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
    ui:SetScript("OnHide", function()
        if ui.presetPicker then ui.presetPicker:Hide() end
        if ns.ClosePlanningWindows then ns.ClosePlanningWindows() end
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
        pending.action.label or "Purchase", ns.MoneyText(budget.cost), ns.MoneyText(budget.remaining),
        UnitLevel("player"), ns.MoneyText(budget.reserved), ns.MoneyText(budget.afterShortfall)))
    ns.warningFrame:Show()
end
