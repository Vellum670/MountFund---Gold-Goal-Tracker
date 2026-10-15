-- Native pages and silent field persistence; draft input stays separate from goals.
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
    control:SetScript("OnEscapePressed", function(self) self:ClearFocus(); if ns.CloseUI then ns.CloseUI() end end)
    control:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    return control
end

local function coins(parent, x, y)
    local controls = {}
    local fieldWidth,iconSize,gap=38,16,5
    -- InputBoxTemplate's visible left border extends five units past the field.
    local spacing=fieldWidth+iconSize+gap*2+5
    for i, part in ipairs({ "Gold", "Silver", "Copper" }) do
        local fieldX = x + (i - 1) * spacing
        controls[i] = edit(parent, fieldX, y, fieldWidth, "", true)
        local icon = parent:CreateTexture(nil, "ARTWORK")
        icon:SetSize(iconSize, iconSize)
        icon:SetPoint("LEFT",controls[i],"RIGHT",gap,0)
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

local createUI, showEditor, saveCurrentGoal, refreshGoalList, deleteGoal
local function tooltip(control,title,body)
    control:SetScript("OnEnter",function(self)
        GameTooltip:SetOwner(self,"ANCHOR_RIGHT"); GameTooltip:SetText(title)
        GameTooltip:AddLine(body,1,1,1,true); GameTooltip:Show()
    end)
    control:SetScript("OnLeave",function() GameTooltip:Hide() end)
end
local function makePage(key,title,height)
    local page=CreateFrame("Frame",nil,ns.ui)
    page:SetPoint("TOPLEFT",16,-55); page:SetSize(368,332)
    page.pageTitle,page.windowHeight=title,height or 450
    page:Hide(); ns.ui.pages[key]=page
    return page
end
function ns.EnsureUI()
    if not ns.ui then createUI(); showEditor(); ns.ShowMainPage() end
    return ns.ui
end
function ns.UI.CreatePage(key,title,height)
    ns.EnsureUI()
    return ns.ui.pages[key] or makePage(key,title,height)
end
function ns.ResizePage(height)
    local ui=ns.ui
    local left,top=ui:GetLeft(),ui:GetTop()
    ui:SetHeight(height)
    if left and top then ui:ClearAllPoints(); ui:SetPoint("TOPLEFT",UIParent,"BOTTOMLEFT",left,top) end
    if ui.currentPage and ui.pages[ui.currentPage] then ui.pages[ui.currentPage].windowHeight=height end
end
function ns.SetPageTitle(key,title)
    ns.ui.pages[key].pageTitle=title
    if ns.ui.currentPage==key then ns.ui.title:SetText(title) end
end
local function editorInputs()
    local ui=ns.ui
    return {ui.name:GetText(),ui.level:GetText(),ui.amount[1]:GetText(),ui.amount[2]:GetText(),ui.amount[3]:GetText()}
end
local function editorInputsChanged()
    local previous=ns.ui.savedEditorInputs or {}
    for index,value in ipairs(editorInputs()) do
        if value~=previous[index] then return true end
    end
    return false
end
function ns.SaveAllFields(onlyPending)
    if not ns.ui or ns.ui.updatingEditor then return end
    if ns.FlushExpenseFields then ns.FlushExpenseFields() end
    if ns.ui.currentPage=="main" and (not onlyPending or editorInputsChanged()) then saveCurrentGoal() end
    if ns.ui.currentPage=="settings" then
        ns.db.warnings=ns.ui.warnings:GetChecked() and true or false
        ns.db.levelUpToasts=ns.ui.toastToggle:GetChecked() and true or false
    end
end
function ns.ShowPage(key,replace)
    ns.EnsureUI()
    local ui=ns.ui; local page=assert(ui.pages[key],"Unknown page: " .. key)
    if ui.currentPage==key then return end
    ns.SaveAllFields()
    if ui.currentPage and not replace then ui.history[#ui.history+1]=ui.currentPage end
    for _,other in pairs(ui.pages) do other:Hide() end
    ui.currentPage=key; page:Show()
    ui.back:SetShown(key~="main")
    ui.title:ClearAllPoints(); ui.title:SetPoint("TOPLEFT",key=="main" and 24 or 100,-22)
    ui.title:SetWidth(key=="main" and 196 or 218); ui.title:SetText(page.pageTitle)
    if ui.reportBug then ui.reportBug:SetShown(key == "main") end
    ui.error:SetText(""); ns.ResizePage(page.windowHeight); ui:Show()
end
function ns.ShowMainPage()
    ns.EnsureUI(); ns.ui.history={}; ns.ShowPage("main",true); ns.ui:Show()
end
function ns.GoBack()
    local ui=ns.ui
    if not ui or ui.currentPage=="main" then return end
    ns.SaveAllFields()
    local previous=table.remove(ui.history) or "main"
    ns.ShowPage(previous,true)
end
function ns.CloseUI()
    if ns.ui then ns.SaveAllFields() end
    if ns.FinishToastMove then ns.FinishToastMove() end
    if ns.ui then ns.ui:Hide() end
end
local function storeInputDraft()
    local ui=ns.ui
    local pending={index=selected,goal=copyGoal(draft),name=ui.name:GetText(),deadline=ui.level:GetText(),coins={}}
    for i,field in ipairs(ui.amount) do pending.coins[i]=field:GetText() end
    if ns.testMoneyCopper~=nil then ns.testEditorDraft=pending else ns.db.editorDraft=pending end
end
local function readEditor(skipValidation)
    local ui=ns.ui; local goal=copyGoal(draft); local saved=ns.GetGoals()[selected]
    goal.name=ui.name:GetText():match("^%s*(.-)%s*$")
    local mode=goal.goalType or "level"
    if mode=="level" then
        goal.targetLevel=tonumber(ui.level:GetText())
        if not goal.targetLevel or goal.targetLevel~=math.floor(goal.targetLevel) or goal.targetLevel<2 or goal.targetLevel>60 then
            return nil,"Choose a target level from 2 to 60."
        end
    elseif mode=="date" then
        local deadline,err=ns.ParseGoalDate(ui.level:GetText():match("^%s*(.-)%s*$"))
        if not deadline then return nil,err end
        goal.deadlineTime=deadline; goal.targetLevel=60
    else
        local hours=tonumber(ui.level:GetText())
        if not hours or hours~=hours or hours<=0 or hours>8760 then return nil,"Enter play-time hours above zero, up to one year." end
        goal.durationSeconds=math.floor(hours*3600); goal.targetLevel=60
    end
    local amount,err=getCoins(ui.amount); if not amount then return nil,err end
    goal.targetCopper=amount; goal.active=ui.active:GetChecked() and true or false
    if not saved then goal.startLevel,goal.savedCopper=nil,nil
    elseif saved.targetCopper==0 and (saved.savedCopper or 0)==0 and amount>0 then goal.savedCopper=nil
    else goal.savedCopper=saved.savedCopper; goal.initialCopper=math.min(goal.initialCopper or 0,amount) end
    ns.PrepareGoal(goal,saved)
    if not skipValidation then local valid,errorText=Model.ValidateGoal(goal); if not valid then return nil,errorText end end
    return goal
end
local function refreshEditorControls()
    local ui=ns.ui; if not ui or not draft then return end
    ui.selection:SetText(draft.name~="" and draft.name or "New goal")
    local curve=Model.CURVES[draft.curve]
    ui.curve:SetText(curve.name)
    tooltip(ui.curve,curve.name,curve.description .. " Click to change planned targets and additions. Your actual saved money stays the same.")
    ui.planning:SetText("Additional Expenses")
    local mode=draft.goalType or "level"
    ui.basis:SetText(mode=="date" and "By calendar date" or mode=="played" and "By play time" or "By level")
    ui.level:SetNumeric(mode=="level")
    tooltip(ui.level,mode=="date" and "Target date" or mode=="played" and "Play-time hours" or "Target level",
        mode=="date" and "Enter YYYY-MM-DD. The goal is due at the end of that day in your computer's local time."
        or mode=="played" and "Enter hours logged into this character from this goal's start. Offline time does not count."
        or "Enter the level when you want this goal funded.")
    for _,field in ipairs(ui.amount) do field:SetEnabled(draft.planMode~="items") end
    ui.delete:SetEnabled(ns.GetGoals()[selected]~=nil)
end
local function renderPlan(goal)
    local ui=ns.ui; if not ui.planRows then return end
    for _,row in pairs(ui.planRows) do row:Hide() end
    local timed=Model.IsTimeGoal(goal)
    ui.planHeading:SetText(timed and "Time progress" or "By level")
    ui.planChangeHeading:SetText(timed and "This interval" or "This level")
    ui.planTargetHeading:SetText(timed and "Goal target" or "Goal for level")
    local expenses=not timed and ns.ExpensesByLevel(goal) or {}
    local first=goal.startLevel or ns.GetPlayerLevel(); local last=math.max(first,goal.targetLevel)
    if timed then first,last=0,10 end
    for step=first,last do
        local row=ui.planRows[step]
        if not row then
            row=CreateFrame("Frame",nil,ui.planContent); row:SetSize(350,35)
            row.background=row:CreateTexture(nil,"BACKGROUND"); row.background:SetAllPoints()
            row.level=label(row,"",0,-3,88,"GameFontHighlightSmall")
            row.target=label(row,"",245,-3,105,"GameFontHighlightSmall")
            row.addition=label(row,"",94,-3,140,"GameFontHighlightSmall")
            row.expense=label(row,"",94,-19,140,"GameFontDisableSmall")
            row.expenseHover=CreateFrame("Frame",nil,row); row.expenseHover:SetPoint("TOPLEFT",94,-17); row.expenseHover:SetSize(140,17); row.expenseHover:EnableMouse(true)
            row.expenseHover:SetScript("OnEnter",function(self)
                local parent=self:GetParent(); local costs=parent.expenses
                if not parent.planLevel then GameTooltip:Hide(); return end
                GameTooltip:SetOwner(self,"ANCHOR_RIGHT"); GameTooltip:SetText("Expenses at level " .. parent.planLevel)
                if not costs or #costs.items==0 then GameTooltip:AddLine("Nothing due at this level.",1,1,1)
                else
                    for _,item in ipairs(costs.items) do
                        local rank=item.rank and item.rank~="" and " (" .. item.rank .. ")" or ""
                        GameTooltip:AddLine(item.name .. rank .. " - " .. (item.copper~=nil and ns.MoneyText(item.copper) or "Unknown price"),1,1,1,true)
                    end
                    GameTooltip:AddLine("Total " .. ns.MoneyText(costs.total) .. (not costs.complete and " + unknown prices" or ""),1,0.82,0,true)
                end
                GameTooltip:Show()
            end)
            row.expenseHover:SetScript("OnLeave",function() GameTooltip:Hide() end)
            ui.planRows[step]=row
        end
        row:ClearAllPoints(); row:SetPoint("TOPLEFT",0,-(step-first)*35)
        local target,previous,current
        if timed then
            local fraction=step/10; local initial=math.min(goal.initialCopper or 0,goal.targetCopper)
            target=math.floor(initial+(goal.targetCopper-initial)*fraction^(goal.curve==0 and 1 or goal.curve))
            previous=step==0 and target or math.floor(initial+(goal.targetCopper-initial)*((step-1)/10)^(goal.curve==0 and 1 or goal.curve))
            row.level:SetText(goal.goalType=="played" and string.format("%.1fh",fraction*goal.durationSeconds/3600)
                or date("%m/%d",goal.startTime+fraction*(goal.deadlineTime-goal.startTime)))
            current=math.floor(Model.ScheduleFraction(goal,ns.GetPlayerLevel())*10)==step
        else
            target=Model.TargetAtLevel(goal,step); previous=step==first and target or Model.TargetAtLevel(goal,step-1)
            row.level:SetText(step); current=step==ns.GetPlayerLevel()
        end
        row.planLevel=not timed and step or nil; row.expenses=expenses[step]
        row.expense:SetText(not timed and ("- " .. ns.MoneyText(row.expenses and row.expenses.total or 0)
            .. (row.expenses and not row.expenses.complete and " ?" or "")) or "")
        row.expense:SetShown(not timed); row.expenseHover:SetShown(not timed)
        row.target:SetText(ns.MoneyText(target)); row.addition:SetText("+ " .. ns.MoneyText(math.max(0,target-previous)))
        row.background:SetColorTexture(0.65,0.48,0.22,current and 0.35 or (step%2==0 and 0.07 or 0)); row:Show()
    end
    local contentHeight=math.max(1,(last-first+1)*35)
    local viewportHeight=math.min(310,math.max(70,contentHeight))
    ui.planContent:SetHeight(contentHeight); ui.scroll:SetHeight(viewportHeight)
    if ui.currentPage=="plan" then ns.ResizePage(55+25+viewportHeight+46) end
end
showEditor=function(updated,restore)
    local ui=ns.ui; ui.updatingEditor=true
    if not updated and not restore then
        local pending
        if ns.testMoneyCopper~=nil then pending=ns.testEditorDraft else pending=ns.db.editorDraft end
        local saved=ns.GetGoals()[selected]
        if pending and pending.index==selected and (not saved or pending.goal.name==saved.name) then
            updated=copyGoal(pending.goal); restore=pending
        end
    end
    if ns.ClosePlanningWindows then ns.ClosePlanningWindows() end
    local saved=ns.GetGoals()[selected]
    ui.selectedGoalIndex=selected
    draft=updated or (saved and copyGoal(saved)) or {name="",goalType="level",targetLevel=math.min(60,math.max(40,ns.GetPlayerLevel()+1)),
        targetCopper=0,curve=0,active=true,milestones={},expenses={},initialPercent=20,includeClassTraining=true}
    if draft.goalType=="date" and not draft.deadlineTime then draft.deadlineTime=ns.ParseGoalDate(date("%Y-%m-%d",ns.Now()+7*86400)) end
    if draft.goalType=="played" and not draft.durationSeconds then draft.durationSeconds=36000 end
    if Model.IsTimeGoal(draft) and draft.curve==0 then draft.curve=1 end
    ns.PrepareGoal(draft,saved)
    ui.name:SetText(draft.name); setCoins(ui.amount,draft.targetCopper); ui.active:SetChecked(draft.active)
    local mode=draft.goalType or "level"
    ui.level:SetText(mode=="date" and date("%Y-%m-%d",draft.deadlineTime or ns.Now()+7*86400)
        or mode=="played" and tostring((draft.durationSeconds or 36000)/3600) or tostring(draft.targetLevel))
    if restore then
        ui.name:SetText(restore.name); ui.level:SetText(restore.deadline)
        for i,field in ipairs(ui.amount) do field:SetText(restore.coins[i]) end
    end
    ui.savedEditorInputs=editorInputs()
    refreshEditorControls(); ui.error:SetText(""); ui.updatingEditor=false; ns.RefreshUI()
end
function ns.RefreshTestContext()
    if not ns.ui or not ns.db then return end
    ns.ui.updatingEditor=true
    selected=math.max(1,math.min(selected,math.max(1,#ns.GetGoals())))
    showEditor(); ns.ShowMainPage()
end
saveCurrentGoal=function()
    if not draft or ns.ui.updatingEditor then return end
    local goal,err=readEditor()
    if not goal then storeInputDraft(); ns.ui.error:SetText(err); return false end
    ns.GetGoals()[selected]=goal; Model.Reconcile(ns.GetGoals(),ns.GetPlayerMoney())
    draft=copyGoal(goal)
    ns.ui.savedEditorInputs=editorInputs()
    local buffers=ns.testMoneyCopper~=nil and ns or ns.db
    local key=ns.testMoneyCopper~=nil and "testEditorDraft" or "editorDraft"
    if buffers[key] and buffers[key].index==selected then buffers[key]=nil end
    refreshEditorControls()
    if ns.UpdateOpenPlannerGoal then ns.UpdateOpenPlannerGoal(goal) end
    ns.Changed(); ns.ui.error:SetText(""); return true
end
deleteGoal=function(index)
    local goals=ns.GetGoals(); if not goals[index] then return end
    local testing=ns.testMoneyCopper~=nil
    local buffers=testing and ns or ns.db
    local editorKey=testing and "testEditorDraft" or "editorDraft"
    local expenseKey=testing and "testExpenseDraft" or "expenseDraft"
    for _,key in ipairs({editorKey,expenseKey}) do
        local pending=buffers[key]
        if pending then
            if pending.index==index then buffers[key]=nil
            elseif pending.index>index then pending.index=pending.index-1 end
        end
    end
    table.remove(goals,index)
    if selected>index then selected=selected-1
    elseif selected==index then selected=math.min(index,#goals) end
    local pending=buffers[editorKey]
    if not (pending and pending.index==selected and selected==#goals+1) then
        selected=math.max(1,math.min(selected,math.max(1,#goals)))
    end
    Model.Reconcile(goals,ns.GetPlayerMoney())
    if pending and pending.index==selected then showEditor(copyGoal(pending.goal),pending) else showEditor() end
    ns.CancelPurchase(); GameTooltip:Hide(); ns.Changed()
end
local function applyPlannerChoices(updated)
    local choices=copyGoal(updated)
    draft.expenses,draft.includeClassTraining,draft.nextExpenseID=choices.expenses,choices.includeClassTraining,choices.nextExpenseID
    draft.planMode=choices.planMode
    if draft.planMode=="items" then
        draft.targetCopper=Model.ExpenseTotal(draft); ns.ui.updatingEditor=true
        setCoins(ns.ui.amount,draft.targetCopper); ns.ui.updatingEditor=false
    end
    refreshEditorControls(); saveCurrentGoal()
end
function ns.UsePreset(id)
    ns.EnsureUI(); ns.SaveAllFields()
    for index,goal in ipairs(ns.GetGoals()) do
        if goal.presetID==id then selected=index; showEditor(); ns.ShowMainPage(); return end
    end
    local goal=ns.NewPresetGoal(id); if not goal then return end
    selected=#ns.GetGoals()+1; showEditor(goal); saveCurrentGoal(); ns.ShowMainPage()
end
local function planCurrentGoal()
    local goal,err=readEditor(true); if not goal then ns.ui.error:SetText(err); return end
    local function open() ns.EnableItemPlanning(goal); ns.OpenExpensePlanner(goal,applyPlannerChoices) end
    if goal.planMode=="items" then open() else ns.AskGoalPlanning(goal,open,saveCurrentGoal) end
end
local function planClassTraining()
    ns.SaveAllFields(true)
    ns.OpenTrainingPlanner()
end
function ns.CatalogChanged()
    if draft then ns.SyncExpenses(draft); if draft.planMode=="items" then setCoins(ns.ui.amount,draft.targetCopper) end end
    ns.RefreshUI(); if ns.RefreshExpensePlanner then ns.RefreshExpensePlanner() end
end
local OVERVIEW_MAX_HEIGHT = 180

local function overviewColumns(parent, y, font)
    local name = label(parent, "", 0, y, 134, font)
    local saved = label(parent, "", 142, y, 98, font)
    local target = label(parent, "", 250, y, 100, font)
    for _, region in ipairs({name, saved, target}) do
        region:SetWordWrap(false)
        region:SetHeight(16)
    end
    saved:SetJustifyH("RIGHT")
    target:SetJustifyH("RIGHT")
    return name, saved, target
end

local function createGoalOverview(main)
    local ui = ns.ui
    local overview = CreateFrame("Frame", nil, main)
    ui.goalOverview = overview
    overview:SetPoint("TOPLEFT", 0, -22)
    overview:SetSize(368, 24)
    overview.toggle = button(overview, "All goals", 0, 0, 368, function()
        ns.SaveAllFields(true)
        ns.db.goalOverviewCollapsed = not ns.db.goalOverviewCollapsed
        ns.RefreshUI()
    end)
    tooltip(overview.toggle, "All goals", "Collapse or expand your goal summary. This choice is saved for this character.")
    overview.body = CreateFrame("Frame", nil, overview)
    overview.body:SetPoint("TOPLEFT", 0, -28)
    overview.body:SetSize(368, 1)
    overview.nameHeading, overview.savedHeading, overview.targetHeading = overviewColumns(overview.body, 0, "GameFontNormalSmall")
    overview.nameHeading:SetText("Goal / interval")
    overview.savedHeading:SetText("Saved")
    overview.targetHeading:SetText("Target")
    overview.scroll = CreateFrame("ScrollFrame", nil, overview.body, "UIPanelScrollFrameTemplate")
    overview.scroll:SetPoint("TOPLEFT", 0, -22)
    overview.scroll:SetSize(354, 1)
    overview.content = CreateFrame("Frame", nil, overview.scroll)
    overview.content:SetSize(350, 1)
    overview.scroll:SetScrollChild(overview.content)
    overview.rows = {}
end

local function refreshGoalOverview(status)
    local overview = ns.ui.goalOverview
    if not overview then return end
    overview.status = status
    local collapsed = ns.db.goalOverviewCollapsed == true
    overview.toggle:SetText((collapsed and "+ " or "- ") .. "All goals (" .. status.count .. ")")
    overview.body:SetShown(not collapsed)
    for _, row in ipairs(overview.rows) do row:Hide() end
    if collapsed then overview:SetHeight(24); return end

    local count, y = 0, 0
    local function render(kind, caption, saved, target, detail, goal)
        count = count + 1
        local row = overview.rows[count]
        if not row then
            row = CreateFrame("Button", nil, overview.content)
            row:SetSize(350, 22)
            row.background = row:CreateTexture(nil, "BACKGROUND")
            row.background:SetAllPoints()
            row.name, row.saved, row.target = overviewColumns(row, -3, "GameFontHighlightSmall")
            -- A highlight draw layer can cover font strings on this client.
            -- Use a faint solid tint below text instead of an opaque button asset.
            row.hoverTint = row:CreateTexture(nil, "BACKGROUND", nil, 1)
            row.hoverTint:SetAllPoints()
            row.hoverTint:SetColorTexture(1, 0.82, 0.2, 0.08)
            row.hoverTint:Hide()
            overview.rows[count] = row
        end
        row.kind, row.goalIndex = kind, goal and goal.index or nil
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, -y)
        row:SetHeight(kind == "heading" and 20 or 22)
        row.name:SetWidth((kind == "heading" or kind == "empty") and 350 or 134)
        -- Keep section headings full width; numeric columns only appear on values.
        row.name:SetText(caption)
        row.name:SetTextColor((kind == "heading" or kind == "total") and 1 or 0.9, 0.82, kind == "heading" and 0.2 or 0.65)
        row.saved:SetText(saved ~= nil and ns.MoneyText(saved) or "")
        row.target:SetText(target ~= nil and ns.MoneyText(target) or "")
        row.background:SetColorTexture(0.65, 0.48, 0.22, kind == "total" and 0.14 or (count % 2 == 0 and 0.04 or 0))
        row:SetScript("OnClick", goal and function()
            ns.SaveAllFields()
            selected = goal.index
            showEditor()
            ns.ShowMainPage()
        end or nil)
        tooltip(row, caption, detail)
        local showDetails = row:GetScript("OnEnter")
        row:SetScript("OnEnter", function(self)
            self.hoverTint:Show()
            showDetails(self)
        end)
        row:SetScript("OnLeave", function(self) self.hoverTint:Hide(); GameTooltip:Hide() end)
        row:Show()
        y = y + row:GetHeight()
        return row
    end

    local costs = status.trainingCosts
    local currentFunded = math.min(status.trainingFunded, costs.current)
    if costs.current > 0 or not costs.currentComplete then
        local row = render("trainingDue", "Training due now", currentFunded, costs.current,
            "Unlearned training due at your current level or earlier observed trainer ranks. These costs stay protected, separately from upcoming upgrades."
                .. (not costs.currentComplete and " Some prices are unknown." or ""))
        if not costs.currentComplete then row.target:SetText(ns.MoneyText(costs.current) .. " ?") end
        y = y + 4
    end
    if status.trainingLevel then
        local funded = math.min(costs.upcoming, math.max(0, status.trainingFunded - currentFunded))
        local details = {"Upcoming included training within your next two levels:"}
        local shownLevel
        for _, spell in ipairs(costs.upcomingSpells or {}) do
            if shownLevel ~= spell.level then
                details[#details + 1] = "\nLevel " .. spell.level
                shownLevel = spell.level
            end
            local rank = spell.rank and spell.rank ~= "" and " (" .. spell.rank .. ")" or ""
            details[#details + 1] = spell.name .. rank .. " - "
                .. (spell.copper ~= nil and ns.MoneyText(spell.copper) or "Unknown price")
        end
        details[#details + 1] = "\nSaved is funded training money; Target is the upcoming cost. Current and overdue costs appear separately."
        local row = render("training", ns.TrainingCaption(status), funded, costs.upcoming, table.concat(details, "\n"))
        if not costs.upcomingComplete then row.target:SetText(ns.MoneyText(costs.upcoming) .. " ?") end
        y = y + 4
    end
    for _, section in ipairs(status.sections) do
        if #section.rows > 0 then
            render("heading", section.title, nil, nil, section.label .. " totals all tracked goals in this group.")
            for _, goal in ipairs(section.rows) do
                local deadline = goal.goalType == "date" and date("%Y-%m-%d", goal.deadlineTime)
                    or goal.goalType == "played" and string.format("%.1f played hours", goal.durationSeconds / 3600)
                    or "level " .. goal.targetLevel
                render("goal", goal.name, goal.saved, goal.target,
                    "Saved " .. ns.MoneyText(goal.saved) .. " / " .. ns.MoneyText(goal.target)
                        .. "\nDue: " .. deadline .. "\n" .. (goal.behind > 0 and "Behind " or "Ahead ")
                        .. ns.MoneyText(goal.behind > 0 and goal.behind or goal.ahead)
                        .. ". Click to edit this goal.", goal)
            end
            render("total", section.label, section.saved, section.target,
                "Net savings added during this interval: " .. ns.MoneyText(section.saved)
                    .. "\nCombined scheduled addition: " .. ns.MoneyText(section.target)
                    .. ". These totals include all tracked goals in this group. Initial investments are separate; spending savings reduces progress.")
            y = y + 6
        end
    end
    if #status.untracked > 0 then
        render("heading", "NOT TRACKED", nil, nil, "These goals do not receive savings or count toward interval totals.")
        for _, goal in ipairs(status.untracked) do
            render("goal", goal.name, goal.saved, goal.target,
                "Not tracked - savings allocation released. Target " .. ns.MoneyText(goal.target)
                    .. ". Click to edit and enable tracking.", goal)
        end
    end
    if status.count == 0 then
        render("empty", "No goals yet. Create one below.", nil, nil, "Create a goal or choose a preset to begin saving.")
    end
    local contentHeight = math.max(1, y)
    -- Bound the overview so the editor and tips remain reachable on small screens.
    local screenHeight = UIParent:GetHeight() or 1080
    local lowerHeight = ns.db.tipsCollapsed == true and 516 or 596
    local availableHeight = math.max(44, screenHeight - lowerHeight - 40)
    local viewportHeight = math.min(OVERVIEW_MAX_HEIGHT, availableHeight, contentHeight)
    overview.content:SetHeight(contentHeight)
    overview.scroll:SetHeight(viewportHeight)
    local scroll = overview.scroll:GetVerticalScroll() or 0
    overview.scroll:SetVerticalScroll(math.min(scroll, math.max(0, contentHeight - viewportHeight)))
    overview.body:SetHeight(22 + viewportHeight)
    overview:SetHeight(28 + overview.body:GetHeight())
end

local function layoutMainPage()
    local ui=ns.ui; if not ui or not ui.goldTipToggle then return end
    local navTop = 22 + ui.goalOverview:GetHeight() + 10
    local editorTop = navTop + 36
    for _,item in ipairs(ui.mainNav) do
        item.control:ClearAllPoints(); item.control:SetPoint("TOPLEFT",item.x,-navTop)
    end
    ui.editor:ClearAllPoints(); ui.editor:SetPoint("TOPLEFT",0,-editorTop)
    local tipsTop=editorTop+292
    local collapsed=ns.db.tipsCollapsed==true
    ui.tipDivider:ClearAllPoints(); ui.tipDivider:SetPoint("TOPLEFT",0,-(tipsTop-6))
    ui.goldTips:ClearAllPoints(); ui.goldTips:SetPoint("TOPLEFT",0,-tipsTop)
    ui.goldTips:SetHeight(collapsed and 28 or 108)
    ui.goldTipText:SetShown(not collapsed)
    ui.goldTipToggle:SetText(collapsed and "+" or "-")
    tooltip(ui.goldTipToggle,collapsed and "Expand gold tips" or "Collapse gold tips",
        "Show or hide the tip text. Your choice is saved; the arrows still browse tips.")
    local main=ui.pages.main
    main:SetHeight(tipsTop+ui.goldTips:GetHeight()); main.windowHeight=main:GetHeight()+78
    if ui.currentPage=="main" and ui:GetHeight()~=main.windowHeight then ns.ResizePage(main.windowHeight) end
end
local function refreshGoldTips(step)
    local ui=ns.ui
    if not ui or not ui.goldTips then return end
    local bracket=ns.GetGoldTipBracket(ns.GetPlayerLevel())
    ui.goldTips:SetShown(bracket~=nil)
    if not bracket then return end
    if ui.goldTipBracket~=bracket then ui.goldTipBracket=bracket; ui.goldTipIndex=1 end
    ui.goldTipIndex=((ui.goldTipIndex-1+(step or 0))%#bracket.tips)+1
    local tip=bracket.tips[ui.goldTipIndex]
    ui.goldTipHeading:SetText("Gold tips: " .. bracket.label)
    ui.goldTipCount:SetText(ui.goldTipIndex .. "/" .. #bracket.tips)
    ui.goldTipText:SetText("|cffffd36e" .. tip.title .. "|r\n" .. tip.text)
    tooltip(ui.goldTips,tip.title,tip.text)
    layoutMainPage()
end
function ns.RefreshUI()
    if not ns.ui or not ns.db then return end
    local ui=ns.ui
    local status = ns.BuildGoalStatus()
    local budget = status.budget
    ui.training:SetShown(not ns.ClassTrainingRetired())
    if ns.ClassTrainingRetired() and ui.currentPage == "training" then ns.ClosePlanningWindows() end
    refreshGoalOverview(status)
    refreshGoldTips()
    local summary=(ns.testMoneyCopper~=nil and "Test wallet " or "Wallet ") .. ns.MoneyText(budget.balance)
        .. (ns.testPlayerLevel and "  [Test level " .. ns.testPlayerLevel .. "]" or "")
    ui.summary:SetText(summary)
    if draft then
        local saved=ns.GetGoals()[selected]; if saved then draft.savedCopper=saved.savedCopper end
        local g=saved or draft; local progress=Model.GoalProgress(g,ns.GetPlayerLevel())
        local timed=Model.IsTimeGoal(g); local trainingOnly=g.targetCopper==0 and g.includeClassTraining
        ui.levelGoalHeading:SetText(timed and "Goal for now" or "Goal for this level")
        local headingWidth=ui.levelGoalHeading:GetStringWidth()
        ui.levelGoalHeading:SetWidth(math.ceil(headingWidth and headingWidth>0 and headingWidth or (timed and 72 or 108)))
        ui.levelGoalAmount:SetWidth(math.max(1,368-ui.levelGoalHeading:GetWidth()-8))
        if not saved and g.name=="" and g.targetCopper==0 then
            ui.levelGoalAmount:SetText(""); ui.levelGoalDetail:SetText("Create or choose a goal to see its target.")
        else
            if trainingOnly then
                ui.levelGoalAmount:SetText(ns.MoneyText(budget.trainingDue))
                ui.levelGoalDetail:SetText("Training for the current and next two levels")
            elseif timed then
                ui.levelGoalAmount:SetText(ns.MoneyText(progress.expected))
                ui.levelGoalDetail:SetText(g.goalType=="date" and "Based on your calendar deadline" or "Based on logged-in play time")
            else
                local step=Model.LevelPlanStep(g,ns.GetPlayerLevel())
                ui.levelGoalAmount:SetText(ns.MoneyText(step.target))
                ui.levelGoalDetail:SetText("Add this level " .. ns.MoneyText(step.addition)
                    .. (step.byLevel and "  - By level " .. step.byLevel or ""))
            end
        end
        tooltip(ui.levelGoal,timed and "Goal for now" or "Goal for this level",
            (trainingOnly and "The shared training budget for your current level and the next two levels."
            or timed and "The total amount planned by now on this goal's calendar or play-time schedule."
            or "The total amount to aim for before your next level. Add this level is the planned increase from your current-level checkpoint. The Savings plan lists those targets under By level. Actual saved progress compares against the checkpoint already reached.")
            .. (g.active==false and " This goal is not tracked; its savings allocation has been released." or ""))
        if g.active==false then
            ui.progress:SetText("Not tracked - savings allocation released")
            ui.levelGoalDetail:SetText("Enable tracking to fund this goal again.")
        elseif g.targetCopper==0 and g.includeClassTraining then
            ui.progress:SetText("Training funded " .. ns.MoneyText(budget.trainingFunded) .. " / " .. ns.MoneyText(budget.trainingDue))
        else ui.progress:SetText(ns.MoneyText(progress.saved) .. " / " .. ns.MoneyText(progress.target) .. "  |  "
            .. (progress.behind>0 and "Behind " or "Ahead ") .. ns.MoneyText(progress.behind>0 and progress.behind or progress.ahead)) end
        renderPlan(g)
    end
    ui.warnings:SetChecked(ns.db.warnings); ui.toastToggle:SetChecked(ns.db.levelUpToasts)
    if refreshGoalList then refreshGoalList() end
    if ns.RefreshExpensePlanner then ns.RefreshExpensePlanner() end
end
refreshGoalList=function()
    local picker=ns.ui.goalPicker; if not picker then return end
    picker.rows=picker.rows or {}
    for _,row in ipairs(picker.rows) do row:Hide(); row.deleteGoal:Hide() end
    for index,goal in ipairs(ns.GetGoals()) do
        local choice=index; local row=picker.rows[index]
        if not row then
            row=button(picker.content,"",0,0,264,function() end)
            row.deleteGoal=button(picker.content,"Delete",272,0,78,function() end)
            picker.rows[index]=row
        end
        row:ClearAllPoints(); row:SetPoint("TOPLEFT",0,-(index-1)*34)
        row.deleteGoal:ClearAllPoints(); row.deleteGoal:SetPoint("TOPLEFT",272,-(index-1)*34)
        row.deleteGoal:SetScript("OnClick",function() deleteGoal(choice) end)
        tooltip(row.deleteGoal,"Delete " .. goal.name,"Remove this goal and its plan. Your actual gold and trainer data are kept.")
        row.deleteGoal:Show()
        local deadline=goal.goalType=="date" and date("%m/%d",goal.deadlineTime) or goal.goalType=="played" and string.format("%.1fh",goal.durationSeconds/3600) or "Lv " .. goal.targetLevel
        row:SetText(goal.name .. " (" .. deadline .. ")")
        tooltip(row,goal.name,"Click to edit this goal.")
        row:SetScript("OnClick",function() ns.SaveAllFields(); selected=choice; showEditor(); ns.ShowMainPage() end); row:Show()
    end
    picker.content:SetHeight(math.max(1,#ns.GetGoals()*34))
    picker.empty:SetText(#ns.GetGoals()==0 and "No goals yet. Go back to create one or choose a preset." or "")
    if ns.ui.currentPage=="goals" then
        local height=math.max(70,math.min(300,#ns.GetGoals()*34))
        picker.scroll:SetHeight(height); ns.ResizePage(55+height+50)
    end
end
-- WoW cannot submit web requests. Give players a selectable browser destination
-- without adding a network dependency or collecting any character information.
ns.BUG_REPORT_URL = "https://github.com/Vellum670/WoW-Forever-Addon/issues/new"

function ns.OpenBugReport()
    ns.EnsureUI()
    local page = ns.ui.pages.bugreport
    if not page then
        page = makePage("bugreport", "Report a bug", 250)
        local intro = label(page, "Copy this link into your browser to report a Mountfund bug on GitHub.",
            0, 0, 368, "GameFontHighlightSmall")
        intro:SetHeight(40)
        intro:SetWordWrap(true)
        label(page, "GitHub bug report link", 0, -55, 368, "GameFontNormalSmall")
        page.link = edit(page, 6, -76, 356, ns.BUG_REPORT_URL)
        page.link:SetMaxLetters(0)
        page.link:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
        page.link:SetScript("OnMouseUp", function(self)
            self:SetFocus()
            self:HighlightText()
        end)
        -- Keep the destination intact while still allowing keyboard copying.
        page.link:SetScript("OnTextChanged", function(self)
            if self:GetText() ~= ns.BUG_REPORT_URL then
                self:SetText(ns.BUG_REPORT_URL)
                self:HighlightText()
            end
        end)
        local help = label(page,
            "Press Ctrl+C to copy, then paste into your browser. Sign in to GitHub, describe the problem and steps to reproduce, and submit the issue there.",
            0, -115, 368, "GameFontHighlightSmall")
        help:SetHeight(65)
        help:SetWordWrap(true)
        page:SetScript("OnHide", function() page.link:ClearFocus() end)
    end
    ns.ShowPage("bugreport")
    page.link:SetFocus()
    page.link:HighlightText()
end

local function settingsPage()
    if ns.ui.pages.settings then ns.ShowPage("settings"); return end
    local page=makePage("settings","Settings",310)
    ns.ui.warnings=CreateFrame("CheckButton",nil,page,"UICheckButtonTemplate"); ns.ui.warnings:SetPoint("TOPLEFT",0,-2)
    label(page,"Confirm before spending protected gold",34,-10,332,"GameFontHighlightSmall")
    label(page,"Warns before supported purchases use goal savings or training money. Spend anyway silences warnings for two minutes.",34,-34,325,"GameFontDisableSmall")
    tooltip(ns.ui.warnings,"Purchase confirmations","Checks supported merchant, trainer, repair, and auction purchases before they use protected money. It does not lock your wallet.")
    ns.ui.warnings:SetScript("OnClick",function(self) ns.db.warnings=self:GetChecked() and true or false; ns.CancelPurchase() end)
    ns.ui.toastToggle=CreateFrame("CheckButton",nil,page,"UICheckButtonTemplate"); ns.ui.toastToggle:SetPoint("TOPLEFT",0,-97)
    label(page,"Show goal progress notifications",34,-105,332,"GameFontHighlightSmall")
    tooltip(ns.ui.toastToggle,"Goal progress notifications","Show goal progress on login and level-up. Zoning and UI reloads do not trigger a notification.")
    ns.ui.toastToggle:SetScript("OnClick",function(self) ns.db.levelUpToasts=self:GetChecked() and true or false; if not ns.db.levelUpToasts then ns.HideLevelUpToast() end end)
    ns.ui.moveToast=button(page,"Move toast",0,-150,230,function() ns.ToggleToastMove() end)
    button(page,"Reset position",238,-150,130,function() ns.ResetToastPosition() end)
    label(page,"Drag the preview. Escape or pressing Move toast again saves its position.",0,-186,368,"GameFontHighlightSmall")
    ns.RefreshUI(); ns.ShowPage("settings")
end
createUI=function()
    local ui=window("MountfundWindow",400,560,"Mountfund"); ns.ui=ui
    ui.pages,ui.history={},{}
    ui.error=label(ui,"",16,0,368,"GameFontHighlightSmall"); ui.error:ClearAllPoints(); ui.error:SetPoint("BOTTOMLEFT",16,12); ui.error:SetTextColor(1,0.65,0.35)
    button(ui,"Close",326,-14,60,ns.CloseUI)
    ui.reportBug = button(ui, "Report bug", 226, -14, 92, ns.OpenBugReport)
    tooltip(ui.reportBug, "Report a bug", "Copy the GitHub issue link to report a problem in your browser.")
    ui.back=button(ui,"Back",16,-14,70,ns.GoBack); ui.back:Hide()
    local main=makePage("main","Mountfund",560); main:SetHeight(482); main:Show(); ui.currentPage="main"
    ui.summary=label(main,"",0,0,368,"GameFontHighlightSmall")
    createGoalOverview(main)
    ui.mainNav={
        {x=0,control=button(main,"Goals",0,-43,74,function() ns.ShowPage("goals") end)},
        {x=82,control=button(main,"New",82,-43,54,function() ns.SaveAllFields(); selected=#ns.GetGoals()+1; showEditor() end)},
        {x=144,control=button(main,"Presets",144,-43,86,function() ns.ShowPage("presets") end)},
        {x=238,control=button(main,"Settings",238,-43,130,settingsPage)},
    }
    local editor=CreateFrame("Frame",nil,main); editor:SetPoint("TOPLEFT",0,-82); editor:SetSize(368,282); ui.editor=editor
    ui.selection=label(editor,"",0,0,368); ui.progress=label(editor,"",0,-19,368,"GameFontHighlightSmall")
    ui.levelGoal=CreateFrame("Frame",nil,editor); ui.levelGoal:SetPoint("TOPLEFT",0,-40); ui.levelGoal:SetSize(368,32); ui.levelGoal:EnableMouse(true)
    ui.levelGoalHeading=label(ui.levelGoal,"Goal for this level",0,0,108,"GameFontNormalSmall"); ui.levelGoalHeading:SetWordWrap(false)
    ui.levelGoalAmount=label(ui.levelGoal,"",116,0,252,"GameFontHighlightSmall"); ui.levelGoalAmount:SetJustifyH("LEFT")
    ui.levelGoalAmount:SetWordWrap(false); ui.levelGoalAmount:ClearAllPoints(); ui.levelGoalAmount:SetPoint("LEFT",ui.levelGoalHeading,"RIGHT",8,0)
    ui.levelGoalDetail=label(ui.levelGoal,"",0,-18,368,"GameFontDisableSmall")
    label(editor,"Name",0,-89,85); ui.name=edit(editor,94,-83,260)
    ui.basis=button(editor,"By level",0,-119,162,function()
        local mode=draft.goalType or "level"
        draft.goalType=mode=="level" and "date" or mode=="date" and "played" or "level"
        draft.milestones={}
        if draft.goalType=="date" then
            draft.startTime=ns.Now(); draft.curve=draft.curve==0 and 1 or draft.curve; draft.targetLevel=60
            local text=date("%Y-%m-%d",ns.Now()+7*86400); draft.deadlineTime=ns.ParseGoalDate(text); ui.level:SetText(text)
        elseif draft.goalType=="played" then
            draft.startPlayed=math.floor(ns.GetPlayedSeconds()); draft.durationSeconds=36000; draft.targetLevel=60
            draft.curve=draft.curve==0 and 1 or draft.curve; ui.level:SetText("10")
        else ui.level:SetText(tostring(math.min(60,math.max(40,ns.GetPlayerLevel()+1)))) end
        refreshEditorControls(); saveCurrentGoal()
    end)
    ui.basisIndicator=ui.basis:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
    ui.basisIndicator:SetPoint("RIGHT",-8,0); ui.basisIndicator:SetText(">")
    tooltip(ui.basis,"Change goal type","Click to cycle: Level > Calendar date > Play time.")
    ui.level=edit(editor,180,-119,174,"40")
    label(editor,"Goal amount",0,-161,90); ui.amount=coins(editor,94,-155)
    ui.active=CreateFrame("CheckButton",nil,editor,"UICheckButtonTemplate"); ui.active:SetPoint("TOPLEFT",-4,-188)
    label(editor,"Track this goal",30,-197,164,"GameFontHighlightSmall"); ui.active:SetScript("OnClick",saveCurrentGoal)
    tooltip(ui.active,"Track this goal","Unchecking releases this goal's saved allocation and stops funding it. Checking again starts funding from zero; it does not restore the released amount. Your actual gold stays in your wallet.")
    ui.training=button(editor,"Class training",186,-189,182,planClassTraining)
    ui.curve=button(editor,"Income-based",0,-223,178,function()
        draft.curve=(draft.curve+1)%3; if Model.IsTimeGoal(draft) and draft.curve==0 then draft.curve=1 end
        refreshEditorControls(); saveCurrentGoal()
    end)
    ui.planning=button(editor,"Additional Expenses",186,-223,182,planCurrentGoal)
    button(editor,"Savings plan",0,-257,178,function() ns.ShowPage("plan") end)
    ui.delete=button(editor,"Delete goal",186,-257,182,function() deleteGoal(selected) end)
    tooltip(ui.delete,"Delete goal","Remove the selected goal and its plan. Your actual gold and trainer data are kept.")
    for _,field in ipairs({ui.name,ui.level,unpack(ui.amount)}) do field:SetScript("OnEditFocusLost",saveCurrentGoal) end
    local tipDivider=main:CreateTexture(nil,"BORDER"); ui.tipDivider=tipDivider
    tipDivider:SetPoint("TOPLEFT",0,-368); tipDivider:SetSize(368,1)
    tipDivider:SetColorTexture(0.65,0.48,0.22,0.4)
    ui.goldTips=CreateFrame("Frame",nil,main); ui.goldTips:SetPoint("TOPLEFT",0,-374); ui.goldTips:SetSize(368,108); ui.goldTips:EnableMouse(true)
    ui.goldTipHeading=label(ui.goldTips,"",0,0,242,"GameFontNormalSmall")
    ui.goldTipText=label(ui.goldTips,"",0,-26,368,"GameFontHighlightSmall")
    ui.goldTipText:SetHeight(82); ui.goldTipText:SetWordWrap(true)
    ui.goldTipToggle=button(ui.goldTips,"-",246,-2,24,function()
        ns.db.tipsCollapsed=not ns.db.tipsCollapsed; refreshGoldTips()
    end)
    ui.goldTipPrevious=button(ui.goldTips,"<",276,-2,24,function() refreshGoldTips(-1) end)
    ui.goldTipCount=label(ui.goldTips,"",302,-7,40,"GameFontHighlightSmall"); ui.goldTipCount:SetJustifyH("CENTER")
    ui.goldTipNext=button(ui.goldTips,">",344,-2,24,function() refreshGoldTips(1) end)
    tooltip(ui.goldTipPrevious,"Previous gold tip","Browse gold-making ideas for your current level bracket.")
    tooltip(ui.goldTipNext,"Next gold tip","Browse gold-making ideas for your current level bracket.")
    local goals=makePage("goals","Your goals",340); ui.goalPicker=goals
    goals.scroll=CreateFrame("ScrollFrame",nil,goals,"UIPanelScrollFrameTemplate"); goals.scroll:SetPoint("TOPLEFT",0,0); goals.scroll:SetSize(354,240)
    goals.content=CreateFrame("Frame",nil,goals.scroll); goals.content:SetSize(350,1); goals.scroll:SetScrollChild(goals.content)
    goals.empty=label(goals.content,"",0,0,350,"GameFontHighlightSmall")
    goals:SetScript("OnShow",function() refreshGoalList() end)
    local presets=makePage("presets","Goal presets",55+math.max(1,#ns.Presets)*40+25); ui.presetPicker=presets
    for index,preset in ipairs(ns.Presets) do local id=preset.id
        button(presets,"|T" .. preset.icon .. ":18:18|t " .. preset.name,0,-(index-1)*40,368,function() ns.UsePreset(id) end)
    end
    local plan=makePage("plan","Savings plan",450); ui.plan=plan
    ui.planHeading=label(plan,"Level",0,0,90,"GameFontNormalSmall")
    ui.planChangeHeading=label(plan,"This level",94,0,140,"GameFontNormalSmall"); ui.planTargetHeading=label(plan,"Goal for level",245,0,105,"GameFontNormalSmall")
    ui.scroll=CreateFrame("ScrollFrame",nil,plan,"UIPanelScrollFrameTemplate"); ui.scroll:SetPoint("TOPLEFT",0,-25); ui.scroll:SetSize(354,310)
    ui.planContent=CreateFrame("Frame",nil,ui.scroll); ui.planContent:SetSize(350,1); ui.scroll:SetScrollChild(ui.planContent); ui.planRows={}
    plan:SetScript("OnShow",function()
        if draft then
            local goal=ns.GetGoals()[selected] or draft
            renderPlan(goal)
            ui.scroll:SetVerticalScroll(Model.IsTimeGoal(goal) and 0 or math.max(0,ns.GetPlayerLevel()-(goal.startLevel or ns.GetPlayerLevel())-1)*35)
        end
    end)
    plan:SetScript("OnHide",function() GameTooltip:Hide() end)
    -- Settings controls exist before any refresh, but the page stays hidden.
    settingsPage(); ui.history={}; ns.ShowPage("main",true)
    ui:SetScript("OnHide",function() ns.SaveAllFields(); if ns.FinishToastMove then ns.FinishToastMove() end; GameTooltip:Hide() end)
    -- Only reopening the outer window advances a tip; page changes and
    -- periodic progress refreshes keep the current tip in place.
    ui:SetScript("OnShow",function()
        refreshGoldTips(ui.goldTipsOpened and 1 or 0)
        ui.goldTipsOpened=true
    end)
    ui.goldTipsOpened=ui:IsShown()
end
function ns.ToggleUI()
    local existing=ns.ui
    ns.EnsureUI()
    if existing and ns.ui:IsShown() then ns.CloseUI() else
        local pending=ns.testMoneyCopper~=nil and ns.testEditorDraft or ns.db.editorDraft
        if pending then selected=pending.index; showEditor(copyGoal(pending.goal),pending) end
        ns.RefreshUI(); ns.ui:Show()
    end
end

function ns.ShowWarning(pending)
    if not ns.warningFrame then
        local frame=window("MountfundSavingsWarning",400,300,"Spend protected money?"); ns.warningFrame=frame
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
