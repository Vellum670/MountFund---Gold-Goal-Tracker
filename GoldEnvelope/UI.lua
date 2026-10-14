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
        if values[i] > 0 or (i == 3 and #parts == 0) then parts[#parts + 1] = values[i] .. " |T" .. coinTextures[i] .. ":12:12:1:0|t" end
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
        local fieldX = x + (i - 1) * 64
        controls[i] = edit(parent, fieldX, y, 38, "", true)
        local icon = parent:CreateTexture(nil, "ARTWORK")
        icon:SetSize(16, 16)
        icon:SetPoint("TOPLEFT", fieldX + 43, y - 4)
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
    frame.title=label(frame, title, 24, -22, width - 48, "GameFontNormalLarge")
    tinsert(UISpecialFrames, name)
    frame:Hide()
    return frame
end

ns.UI = { Label = label, Button = button, Edit = edit, Coins = coins, SetCoins = setCoins,
    GetCoins = getCoins, Window = window }

local function readEditor(skipValidation)
    local ui = ns.ui
    local goal = copyGoal(draft)
    local saved = ns.db.goals[selected]
    goal.name = ui.name:GetText():match("^%s*(.-)%s*$")
    goal.targetLevel = tonumber(ui.level:GetText())
    if not goal.targetLevel or goal.targetLevel ~= math.floor(goal.targetLevel) or goal.targetLevel < 2 or goal.targetLevel > 60 then
        return nil, "Choose a target level from 2 to 60."
    end
    local amount, errorText = getCoins(ui.amount)
    if not amount then return nil, errorText end
    goal.targetCopper = amount
    goal.active = ui.active:GetChecked() and true or false
    if not saved then
        goal.startLevel, goal.savedCopper = nil, nil
    elseif saved.targetCopper == 0 and (saved.savedCopper or 0) == 0 and goal.targetCopper > 0 then
        -- A name can be saved before its amount is entered. Seed the first
        -- positive budget once, using the same protected automatic allocation.
        goal.savedCopper = nil
    else
        goal.savedCopper = saved.savedCopper
        goal.initialCopper = math.min(goal.initialCopper or 0, goal.targetCopper)
    end
    ns.PrepareGoal(goal, saved)
    if not skipValidation then
        local valid, validationError = Model.ValidateGoal(goal)
        if not valid then return nil, validationError end
    end
    return goal
end

local function renderPlan(goal)
    local ui = ns.ui
    ui.planRows = ui.planRows or {}
    for _, row in pairs(ui.planRows) do row:Hide() end
    local training = goal.includeClassTraining and ns.TrainingByLevel(goal) or {}
    local start, finish = goal.startLevel or UnitLevel("player"), math.max(goal.startLevel or 1, goal.targetLevel)
    for level = start, finish do
        local row = ui.planRows[level]
        if not row then
            row = CreateFrame("Frame", nil, ui.planContent)
            row:SetSize(354, 37)
            row.background = row:CreateTexture(nil, "BACKGROUND"); row.background:SetAllPoints()
            row.level = label(row, "", 0, -5, 30, "GameFontHighlightSmall")
            row.target = label(row, "", 36, -5, 157, "GameFontHighlightSmall")
            row.addition = label(row, "", 36, -21, 157, "GameFontDisableSmall")
            row.training = label(row, "", 204, -5, 145, "GameFontHighlightSmall")
            ui.planRows[level] = row
        end
        row:ClearAllPoints(); row:SetPoint("TOPLEFT", 0, -(level - start) * 37)
        local target = Model.TargetAtLevel(goal, level)
        local prior = level == start and 0 or Model.TargetAtLevel(goal, level - 1)
        row.level:SetText(level)
        row.target:SetText(ns.MoneyText(target))
        row.addition:SetText(level == start and "" or "+ " .. ns.MoneyText(math.max(0,target-prior)))
        row.training:SetText(ns.MoneyText(training[level] or 0))
        row.background:SetColorTexture(0.65,0.48,0.22,level == UnitLevel("player") and 0.35 or (level % 2 == 0 and 0.07 or 0))
        row:Show()
    end
    ui.planContent:SetHeight(math.max(1,(finish-start+1)*37))
    ui.scroll:SetVerticalScroll(math.max(0,UnitLevel("player")-start-1)*37)
end

local refreshGoalList, saveCurrentGoal

local function refreshEditorControls()
    local ui=ns.ui
    local updating=ui.updatingEditor; ui.updatingEditor=true
    ui.selection:SetText(draft.name ~= "" and draft.name or "New goal")
    ui.curve:SetText(draft.curve == 0 and "Income-based schedule" or "Custom curve: " .. draft.curve)
    ui.planning:SetText(draft.planMode == "items" and "Choose expenses" or "Customize expenses")
    for _, input in ipairs(ui.amount) do if draft.planMode == "items" then input:Disable() else input:Enable() end end
    ui.delete:SetEnabled(ns.db.goals[selected] ~= nil)
    ui.updatingEditor=updating
end

local function showEditor(updated)
    if ns.ClosePlanningWindows then ns.ClosePlanningWindows() end
    if ns.ui.goalPicker then ns.ui.goalPicker:Hide() end
    local ui = ns.ui
    ui.updatingEditor=true
    local saved = ns.db.goals[selected]
    draft = updated or (saved and copyGoal(saved)) or { name = "", targetLevel = math.min(60,math.max(40,UnitLevel("player")+1)),
        targetCopper = 0, curve = 0, active = true, milestones = {}, expenses = {}, initialPercent = 20,
        includeClassTraining = true }
    ns.PrepareGoal(draft, saved)
    ui.name:SetText(draft.name); ui.level:SetText(tostring(draft.targetLevel))
    setCoins(ui.amount,draft.targetCopper); ui.active:SetChecked(draft.active)
    refreshEditorControls(); ui.error:SetText("")
    ui.updatingEditor=false
    renderPlan(draft); ns.RefreshUI()
end

-- Planner snapshots own expense choices only; the main fields may have been
-- edited since the popup opened. Keep them and leave the popup in place.
local function applyPlannerChoices(updated)
    local choices=copyGoal(updated)
    draft.expenses=choices.expenses
    draft.includeClassTraining=choices.includeClassTraining
    draft.nextExpenseID=choices.nextExpenseID
    draft.planMode,draft.planDecision=choices.planMode,choices.planDecision
    if draft.planMode == "items" then
        draft.targetCopper=Model.ExpenseTotal(draft)
        ns.ui.updatingEditor=true; setCoins(ns.ui.amount,draft.targetCopper); ns.ui.updatingEditor=false
    end
    refreshEditorControls()
    saveCurrentGoal()
end

function ns.UsePreset(id)
    local goal = ns.NewPresetGoal(id)
    if not goal then return end
    for index,existing in ipairs(ns.db.goals) do
        if existing.presetID == id then selected=index; showEditor(); return end
    end
    selected=#ns.db.goals+1; showEditor(goal); saveCurrentGoal()
end

local function planCurrentGoal()
    local goal,errorText=readEditor(true)
    if not goal then ns.ui.error:SetText(errorText); return end
    if not goal.targetLevel or goal.targetLevel < 2 or goal.targetLevel > 60 then ns.ui.error:SetText("Choose a target level from 2 to 60."); return end
    local function open()
        ns.EnableItemPlanning(goal)
        ns.OpenExpensePlanner(goal,applyPlannerChoices)
    end
    if goal.planMode == "items" then open() else ns.AskGoalPlanning(goal,open,function()
        draft.planDecision="simple"; saveCurrentGoal()
    end) end
end

local function planClassTraining()
    local goal,errorText=readEditor(true)
    if not goal then ns.ui.error:SetText(errorText); return end
    ns.OpenTrainingPlanner(goal,applyPlannerChoices)
end

saveCurrentGoal=function()
    if not draft or ns.ui.updatingEditor then return end
    local goal,errorText=readEditor()
    if not goal then ns.ui.error:SetText(errorText); return end
    ns.db.goals[selected]=goal; Model.Reconcile(ns.db.goals,GetMoney())
    draft=copyGoal(goal); refreshEditorControls()
    if ns.UpdateOpenPlannerGoal then ns.UpdateOpenPlannerGoal(goal) end
    ns.Changed()
    ns.ui.error:SetText("Changes saved.")
end

function ns.CatalogChanged()
    if draft then
        ns.SyncExpenses(draft)
        setCoins(ns.ui.amount,draft.targetCopper); renderPlan(draft)
    end
    if ns.RefreshExpensePlanner then ns.RefreshExpensePlanner() end
end

function ns.RefreshUI()
    if not ns.ui or not ns.db then return end
    local ui,budget=ns.ui,ns.GetBudget()
    ui.summary:SetText("Wallet " .. ns.MoneyText(budget.balance) .. "\nSaved " .. ns.MoneyText(budget.saved)
        .. "  |  " .. (budget.behind > 0 and "Behind " or "Ahead ") .. ns.MoneyText(budget.behind > 0 and budget.behind or budget.ahead)
        .. (not budget.trainingComplete and "\nSome training prices are unknown." or ""))
    if draft then
        if ns.db.goals[selected] then draft.savedCopper = ns.db.goals[selected].savedCopper end
        local progress=Model.GoalProgress(draft,UnitLevel("player"))
        if draft.targetCopper == 0 and draft.includeClassTraining then
            ui.progress:SetText("Training funded " .. ns.MoneyText(budget.trainingFunded) .. " / " .. ns.MoneyText(budget.trainingDue))
        else
            ui.progress:SetText(ns.MoneyText(progress.saved) .. " / " .. ns.MoneyText(progress.target)
                .. "  |  " .. (progress.behind > 0 and "Behind " or "Ahead ")
                .. ns.MoneyText(progress.behind > 0 and progress.behind or progress.ahead))
        end
        renderPlan(draft)
    end
    ui.warnings:SetChecked(ns.db.warnings)
    if refreshGoalList then refreshGoalList() end
end

refreshGoalList=function()
    local picker=ns.ui.goalPicker
    if not picker then return end
    picker.rows=picker.rows or {}
    for _,row in ipairs(picker.rows) do row:Hide() end
    for index,goal in ipairs(ns.db.goals) do
        local choice=index
        local row=picker.rows[index]
        if not row then row=button(picker.content,"",0,0,260,function() end); picker.rows[index]=row end
        row:ClearAllPoints(); row:SetPoint("TOPLEFT",0,-(index-1)*34)
        row:SetText(goal.name .. " (" .. goal.targetLevel .. ")")
        row:SetScript("OnClick",function() saveCurrentGoal(); selected=choice; showEditor() end); row:Show()
    end
    picker.content:SetHeight(math.max(1,#ns.db.goals*34))
end

local function showGoalPicker()
    local ui=ns.ui
    saveCurrentGoal()
    if not ui.goalPicker then
        local picker=window("GoldEnvelopeGoalPicker",310,360,"Your goals"); ui.goalPicker=picker
        picker.scroll=CreateFrame("ScrollFrame",nil,picker,"UIPanelScrollFrameTemplate")
        picker.scroll:SetPoint("TOPLEFT",20,-55); picker.scroll:SetSize(260,250)
        picker.content=CreateFrame("Frame",nil,picker.scroll); picker.content:SetSize(260,1)
        picker.scroll:SetScrollChild(picker.content)
        button(picker,"Close",210,-320,75,function() picker:Hide() end)
    end
    refreshGoalList(); ui.goalPicker:Show()
end

local function createUI()
    local ui=window("GoldEnvelopeWindow",400,450,"Gold Envelope"); ns.ui=ui
    button(ui,"Close",326,-14,60,function() ui:Hide() end)
    ui.summary=label(ui,"",16,-55,368,"GameFontHighlightSmall")
    button(ui,"Goals",16,-103,75,showGoalPicker)
    button(ui,"New",99,-103,55,function() saveCurrentGoal(); selected=#ns.db.goals+1; showEditor() end)
    button(ui,"Presets",162,-103,75,function()
        saveCurrentGoal()
        if not ui.presetPicker then
            local count=#ns.Presets; local picker=window("GoldEnvelopePresetPicker",330,100+count*37,"Goal presets")
            ui.presetPicker=picker
            for index,preset in ipairs(ns.Presets) do
                local id=preset.id
                button(picker,"|T" .. preset.icon .. ":16:16|t " .. preset.name,16,-54-(index-1)*37,298,function() picker:Hide(); ns.UsePreset(id) end)
            end
            button(picker,"Close",234,-64-count*37,80,function() picker:Hide() end)
        end
        ui.presetPicker:Show()
    end)
    button(ui,"Plan / edit",245,-103,139,function()
        saveCurrentGoal()
        local shown=ui.plan:IsShown()
        ui.plan:SetShown(not shown); ui.editor:SetShown(shown)
        if not shown then local goal=readEditor(true); if goal then renderPlan(goal) end end
    end)
    local editor=CreateFrame("Frame",nil,ui); editor:SetPoint("TOPLEFT",0,-139); editor:SetSize(400,240); ui.editor=editor
    ui.selection=label(editor,"",16,-3,368)
    ui.progress=label(editor,"",16,-25,368,"GameFontHighlightSmall")
    label(editor,"Name",16,-58,70); ui.name=edit(editor,94,-52,274)
    label(editor,"By level",16,-94,70); ui.level=edit(editor,94,-88,44,"40",true); ui.amount=coins(editor,172,-88)
    ui.active=CreateFrame("CheckButton",nil,editor,"UICheckButtonTemplate"); ui.active:SetPoint("TOPLEFT",12,-118)
    ui.active:SetScript("OnClick",saveCurrentGoal)
    label(editor,"Track this goal",46,-126,165,"GameFontHighlightSmall")
    ui.training=button(editor,"Class training",222,-119,162,planClassTraining)
    ui.curve=button(editor,"Income-based schedule",16,-166,180,function()
        draft.curve=(draft.curve+1)%5; ui.curve:SetText(draft.curve==0 and "Income-based schedule" or "Custom curve: " .. draft.curve)
        saveCurrentGoal()
    end)
    ui.planning=button(editor,"Customize expenses",204,-166,180,planCurrentGoal)
    label(editor,"Changes save as you edit.",16,-207,368,"GameFontDisableSmall")
    ui.name:SetScript("OnEditFocusLost",saveCurrentGoal)
    ui.level:SetScript("OnEditFocusLost",saveCurrentGoal)
    for _,input in ipairs(ui.amount) do input:SetScript("OnEditFocusLost",saveCurrentGoal) end
    ui.plan=CreateFrame("Frame",nil,ui); ui.plan:SetPoint("TOPLEFT",16,-139); ui.plan:SetSize(368,240); ui.plan:Hide()
    label(ui.plan,"Level",0,-4,32,"GameFontNormalSmall")
    label(ui.plan,"Goal target / addition",36,-4,155,"GameFontNormalSmall")
    label(ui.plan,"Training due",204,-4,145,"GameFontNormalSmall")
    ui.scroll=CreateFrame("ScrollFrame","GoldEnvelopePlanScroll",ui.plan,"UIPanelScrollFrameTemplate")
    ui.scroll:SetPoint("TOPLEFT",0,-29); ui.scroll:SetSize(354,200)
    ui.planContent=CreateFrame("Frame",nil,ui.scroll); ui.planContent:SetSize(354,1); ui.scroll:SetScrollChild(ui.planContent)
    ui.error=label(ui,"",16,-388,368,"GameFontHighlightSmall"); ui.error:SetTextColor(1,0.65,0.35)
    ui.delete=button(ui,"Delete goal",16,-419,90,function()
        if ns.db.goals[selected] then table.remove(ns.db.goals,selected) end
        selected=math.max(1,math.min(selected,#ns.db.goals)); ns.Changed(); showEditor()
    end)
    ui.warnings=CreateFrame("CheckButton",nil,ui,"UICheckButtonTemplate"); ui.warnings:SetPoint("TOPLEFT",286,-415)
    label(ui,"Warn",320,-424,64,"GameFontHighlightSmall")
    ui.warnings:SetScript("OnClick",function(self) ns.db.warnings=self:GetChecked() and true or false; ns.CancelPurchase(); ns.Changed() end)
    ui:SetScript("OnHide",function()
        saveCurrentGoal()
        if ui.goalPicker then ui.goalPicker:Hide() end
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
        local frame=window("GoldEnvelopeSavingsWarning",400,300,"Spend protected money?"); ns.warningFrame=frame
        frame:SetFrameLevel(3000)
        -- The tooltip backdrop texture is translucent even with an opaque tint.
        -- Give this confirmation its own solid surface so world labels do not show through.
        local surface=frame:CreateTexture(nil,"BACKGROUND",nil,-8)
        surface:SetPoint("TOPLEFT",5,-5); surface:SetPoint("BOTTOMRIGHT",-5,5)
        surface:SetColorTexture(0.055,0.04,0.025,1)
        frame.itemName=label(frame,"",20,-57,360,"GameFontHighlight")
        frame.itemName:SetWordWrap(false); frame.itemName:SetHeight(20)
        label(frame,"This purchase uses money you set aside.",20,-82,360,"GameFontDisableSmall")
        frame.moneyRows={}
        for index,row in ipairs({
            { key="cost", text="Purchase cost" },
            { key="remaining", text="Wallet after purchase" },
            { key="reserved", text="Protected money now" },
            { key="used", text="Protected money used" },
        }) do
            local y=-109-(index-1)*25
            local caption=label(frame,row.text,20,y,184,"GameFontHighlightSmall")
            local amount=label(frame,"",216,y,164,"GameFontHighlightSmall")
            caption:SetWordWrap(false); amount:SetWordWrap(false)
            amount:SetJustifyH("RIGHT")
            if row.key=="used" then caption:SetTextColor(1,0.65,0.35); amount:SetTextColor(1,0.65,0.35) end
            frame.moneyRows[row.key]={caption=caption,amount=amount}
        end
        local divider=frame:CreateTexture(nil,"BORDER")
        divider:SetPoint("TOPLEFT",20,-210); divider:SetSize(360,1)
        divider:SetColorTexture(0.65,0.48,0.22,0.4)
        local note=label(frame,"Spend anyway silences warnings for 2 minutes.",20,-222,360,"GameFontDisableSmall")
        note:SetHeight(26)
        frame:SetScript("OnHide",function() ns.pending=nil end)
        button(frame,"Spend anyway",20,-260,170,ns.ConfirmPurchase); button(frame,"Cancel",210,-260,170,ns.CancelPurchase)
    end
    local b=pending.budget
    ns.warningFrame.itemName:SetText(pending.action.label)
    for key,amount in pairs({cost=b.cost,remaining=b.remaining,reserved=b.reserved,used=b.afterShortfall}) do
        ns.warningFrame.moneyRows[key].amount:SetText(ns.MoneyText(amount))
    end
    ns.warningFrame:Show()
end
