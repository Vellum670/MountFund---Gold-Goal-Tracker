local _, ns = ...
local UI,Model=ns.UI,ns.Model

function ns.ClosePlanningWindows()
    if ns.planningFrames then
        for _,page in pairs(ns.planningFrames) do page.goal,page.onChange=nil,nil; page:Hide() end
    end
    if ns.planningConsent then ns.planningConsent.yes,ns.planningConsent.no=nil,nil; ns.planningConsent:Hide() end
    if ns.ui and (ns.ui.currentPage=="training" or ns.ui.currentPage=="expenses" or ns.ui.currentPage=="planning") then ns.ShowMainPage() end
end
function ns.AskGoalPlanning(goal,onYes,onNo)
    ns.EnsureUI()
    if not ns.planningConsent then
        local page=UI.CreatePage("planning","Planning choices",240); ns.planningConsent=page
        page.body=UI.Label(page,"",0,0,368,"GameFontHighlightSmall"); page.body:SetSpacing(5)
        UI.Button(page,"Choose expenses",0,-128,178,function()
            local callback=page.yes
            if callback then callback() end
        end)
        UI.Button(page,"Keep simple budget",190,-128,178,function()
            local callback=page.no; ns.GoBack(); if callback then callback() end
        end)
    end
    local page=ns.planningConsent; page.yes,page.no=onYes,onNo
    page.body:SetText("Choose individual purchases for " .. (goal.name~="" and goal.name or "this goal")
        .. "?\n\nClick ability icons to include or exclude them, or keep one savings amount.")
    ns.ShowPage("planning")
end
local function changed(page)
    ns.SyncExpenses(page.goal)
    if page.onChange then page.onChange(Model.CopyGoal(page.goal)) end
end
function ns.AbilityGroups(goal,classOnly)
    local groups,byKey={},{}; local level=ns.GetPlayerLevel(); local _,class=UnitClass("player")
    for _,item in ipairs(goal.expenses or {}) do
        local visible=(classOnly and item.source=="class" and (not item.class or item.class==class))
            or (not classOnly and item.source~="class")
        if visible then
            local isAbility=item.source=="class" or item.source=="profession"
            local key=isAbility and item.source .. ":" .. item.name or item.key
            local group=byKey[key]
            if not group then group={expenses={},cost=0,readOnly=false,included=false,maxed=false}; byKey[key]=group; groups[#groups+1]=group end
            group.expenses[#group.expenses+1]=item
            if isAbility then
                group.included=group.included or item.selected~=false
                if not group.lastRank or item.level>group.lastRank.level then group.lastRank=item end
                if not item.paid and item.eligible==false then group.blocked=true end
                if not item.paid and item.level>level and (not group.expense or item.level<group.requiredLevel) then
                    group.expense,group.requiredLevel=item,item.level
                end
            end
            if not item.paid then
                if not isAbility and item.level<=goal.targetLevel then
                    group.expense,group.requiredLevel=item,item.level; group.included=group.included or item.selected~=false
                end
                local relevant=(not isAbility or item.level>=level or item.priceSource=="trainer quote") and item.level<=goal.targetLevel
                if relevant and item.eligible~=false then
                    if item.copper then group.cost=group.cost+item.copper else group.unknown=true end
                end
            end
        end
    end
    local result={}
    for _,group in ipairs(groups) do
        if not group.expense and group.lastRank then group.expense,group.maxed=group.lastRank,true end
        if group.expense then group.sortLevel=group.requiredLevel or Model.MAX_LEVEL+1; result[#result+1]=group end
    end
    table.sort(result,function(a,b) if a.sortLevel~=b.sortLevel then return a.sortLevel<b.sortLevel end return a.expense.name<b.expense.name end)
    return result
end
local function showTooltip(button)
    local item=button.expense; local page=button.page
    GameTooltip:SetOwner(button,"ANCHOR_RIGHT")
    if item.spellID then GameTooltip:SetSpellByID(item.spellID,false,false,true)
    elseif item.link then GameTooltip:SetHyperlink(item.link) else GameTooltip:SetText(item.name) end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(button.maxed and "Max - no further rank upgrades" or "Next rank: level " .. button.requiredLevel,1,0.82,0)
    GameTooltip:AddLine("Cost through level " .. page.goal.targetLevel .. ": " .. ns.MoneyText(button.cost)
        .. (button.unknown and " (some prices unknown)" or ""),1,1,1)
    GameTooltip:AddLine(button.included and "Included - click to exclude ability" or "Excluded - click to include ability",1,0.82,0)
    if button.blocked then GameTooltip:AddLine("Some ranks need a quest, talent, or race prerequisite before their costs count.",0.7,0.7,0.7,true) end
    if item.priceSource then GameTooltip:AddLine(item.priceSource,0.6,0.6,0.6) end
    GameTooltip:Show()
end
function ns.RefreshExpensePlanner()
    local page=ns.planningFrame
    if not page or not page.goal or not ns.ui or ns.ui.currentPage~=page.key then return end
    ns.SyncExpenses(page.goal)
    page.goalName:SetText("Goal: " .. (page.goal.name~="" and page.goal.name or "New goal"))
    local training,complete=ns.TrainingRunway(page.goal)
    page.summary:SetText("Goal target " .. ns.MoneyText(page.goal.targetCopper) .. "\nNext two levels' training " .. ns.MoneyText(training)
        .. (not complete and " - some prices unknown" or ""))
    local className=UnitClass("player")
    page.hint:SetText(page.classMode and ((className or "Class") .. " - level " .. ns.GetPlayerLevel() .. " - next upgrades") or "Click icons to include or exclude purchases.")
    page.expenseButtons=page.expenseButtons or {}; for _,button in ipairs(page.expenseButtons) do button:Hide() end
    local groups=ns.AbilityGroups(page.goal,page.classMode)
    for index,group in ipairs(groups) do
        local button=page.expenseButtons[index]
        if not button then
            button=CreateFrame("Button",nil,page.content); button:SetSize(36,36); button.page=page
            button.border=button:CreateTexture(nil,"BACKGROUND"); button.border:SetAllPoints()
            button.icon=button:CreateTexture(nil,"ARTWORK"); button.icon:SetPoint("TOPLEFT",2,-2); button.icon:SetPoint("BOTTOMRIGHT",-2,2)
            button.icon:SetTexCoord(0.07,0.93,0.07,0.93)
            button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square","BLEND")
            local glow=button:GetHighlightTexture(); glow:ClearAllPoints(); glow:SetPoint("TOPLEFT",2,-2); glow:SetPoint("BOTTOMRIGHT",-2,2); glow:SetColorTexture(1,1,1,0.12)
            button.level=UI.Label(button,"",-2,-39,40,"GameFontDisableSmall"); button.level:SetJustifyH("CENTER")
            button:SetScript("OnClick",function(self)
                local selected=not self.included
                for _,item in ipairs(self.expenses) do item.selected=selected end
                changed(page); ns.RefreshExpensePlanner(); showTooltip(self)
            end)
            button:SetScript("OnEnter",showTooltip); button:SetScript("OnLeave",function() GameTooltip:Hide() end)
            page.expenseButtons[index]=button
        end
        button.unknown,button.maxed,button.blocked,button.requiredLevel=group.unknown,group.maxed,group.blocked,group.requiredLevel
        for field,value in pairs(group) do button[field]=value end
        button:ClearAllPoints(); button:SetPoint("TOPLEFT",6+((index-1)%8)*44,-math.floor((index-1)/8)*54-2)
        button.icon:SetTexture(ns.ExpenseIcon(group.expense))
        local included=group.included
        button.icon:SetDesaturated(not included); local tint=included and 1 or 0.5; button.icon:SetVertexColor(tint,tint,tint)
        button.border:SetColorTexture(included and 0.72 or 0.3,included and 0.55 or 0.3,included and 0.24 or 0.3,1)
        button.level:SetText(group.maxed and "Max" or "Lv " .. group.requiredLevel); button:Enable(); button:EnableMouse(true); button:Show()
    end
    local rows=math.ceil(#groups/8); page.content:SetHeight(math.max(1,rows*54))
    page.empty:SetText(#groups==0 and (page.classMode and "No training abilities found for this class." or "Add a purchase below to get started.") or "")
    if page.classMode then
        local grid=math.min(260,math.max(42,rows*54)); page.scroll:SetHeight(grid)
        ns.ResizePage(math.max(230,55+84+grid+46))
    else
        local grid=math.min(124,math.max(42,rows*54)); page.scroll:SetHeight(grid)
        page.manual:ClearAllPoints(); page.manual:SetPoint("TOPLEFT",0,-(84+grid+14))
        ns.ResizePage(55+84+grid+14+82+46)
    end
end
local function storeManualDraft(page)
    local pending={index=ns.ui.selectedGoalIndex,name=page.goal.name,expenseName=page.expenseName:GetText(),level=page.expenseLevel:GetText(),coins={},key=page.manualKey}
    for i,field in ipairs(page.expenseAmount) do pending.coins[i]=field:GetText() end
    if ns.testMoneyCopper~=nil then ns.testExpenseDraft=pending else ns.db.expenseDraft=pending end
end
local function saveManual(page)
    if not page.goal or page.classMode then return end
    local name=page.expenseName:GetText():match("^%s*(.-)%s*$"); if name=="" then return end
    local level=tonumber(page.expenseLevel:GetText()); local amount,err=UI.GetCoins(page.expenseAmount)
    if not level or level~=math.floor(level) or level<1 or level>page.goal.targetLevel then err="Use a valid due level within this goal." end
    if err then storeManualDraft(page); ns.ui.error:SetText(err); return end
    local found
    for _,item in ipairs(page.goal.expenses) do
        if item.source=="manual" and (item.key==page.manualKey or (not page.manualKey and item.name==name and item.level==level)) then found=item; break end
    end
    if not found then
        page.goal.nextExpenseID=(page.goal.nextExpenseID or 0)+1
        found={key="manual:" .. page.goal.nextExpenseID,source="manual",selected=true}; page.goal.expenses[#page.goal.expenses+1]=found
    end
    page.manualKey=found.key; found.name,found.level,found.copper,found.estimated=name,level,amount,false
    changed(page)
    if ns.testMoneyCopper~=nil then ns.testExpenseDraft=nil else ns.db.expenseDraft=nil end
    ns.ui.error:SetText(""); ns.RefreshExpensePlanner()
end
function ns.FlushExpenseFields()
    local page=ns.planningFrame
    if page and ns.ui and ns.ui.currentPage==page.key then saveManual(page) end
end
function ns.OpenExpensePlanner(goal,onChange,classOnly)
    ns.EnsureUI(); ns.planningFrames=ns.planningFrames or {}
    local key=classOnly and "training" or "expenses"; local page=ns.planningFrames[key]
    if not page then
        page=UI.CreatePage(key,classOnly and "Class training" or "Goal expenses",classOnly and 450 or 405); ns.planningFrames[key]=page
        page.key,page.classMode=key,classOnly and true or false
        page.goalName=UI.Label(page,"",0,0,368); page.goalName:SetWordWrap(false)
        page.summary=UI.Label(page,"",0,-24,368,"GameFontHighlightSmall")
        page.hint=UI.Label(page,"",0,-59,368,"GameFontDisableSmall")
        page.scroll=CreateFrame("ScrollFrame",nil,page,"UIPanelScrollFrameTemplate"); page.scroll:SetPoint("TOPLEFT",0,-84); page.scroll:SetSize(354,classOnly and 260 or 124)
        page.content=CreateFrame("Frame",nil,page.scroll); page.content:SetSize(352,1); page.scroll:SetScrollChild(page.content)
        page.empty=UI.Label(page.content,"",0,-4,350,"GameFontHighlightSmall")
        page.manual=CreateFrame("Frame",nil,page); page.manual:SetSize(368,82)
        UI.Label(page.manual,"Add or update a purchase",0,0,268,"GameFontNormalSmall")
        page.expenseName=UI.Edit(page.manual,6,-22,226,""); page.expenseLevel=UI.Edit(page.manual,290,-22,64,"",true)
        UI.Label(page.manual,"Due level",290,-6,64,"GameFontNormalSmall")
        page.expenseAmount=UI.Coins(page.manual,6,-58)
        UI.Button(page.manual,"New cost",226,-58,128,function()
            saveManual(page); page.manualKey=nil; page.expenseName:SetText(""); UI.SetCoins(page.expenseAmount,0)
        end)
        for _,field in ipairs({page.expenseName,page.expenseLevel,unpack(page.expenseAmount)}) do field:SetScript("OnEditFocusLost",function() saveManual(page) end) end
        page.manual:SetShown(not classOnly)
        page:SetScript("OnHide",function() saveManual(page); GameTooltip:Hide() end)
        page:SetScript("OnShow",function() ns.planningFrame=page; ns.RefreshExpensePlanner() end)
    end
    page.goal,page.onChange=Model.CopyGoal(goal),onChange; page.manualKey=nil; ns.planningFrame=page
    if classOnly then page.goal.includeClassTraining=true; changed(page) end
    page.expenseName:SetText(""); page.expenseLevel:SetText(tostring(goal.targetLevel)); UI.SetCoins(page.expenseAmount,0)
    local pending=ns.testMoneyCopper~=nil and ns.testExpenseDraft or ns.db.expenseDraft
    if pending and pending.index==ns.ui.selectedGoalIndex and pending.name==goal.name then
        page.expenseName:SetText(pending.expenseName); page.expenseLevel:SetText(pending.level); page.manualKey=pending.key
        for i,field in ipairs(page.expenseAmount) do field:SetText(pending.coins[i]) end
    end
    page.scroll:SetVerticalScroll(0)
    ns.ShowPage(key,ns.ui.currentPage=="planning"); ns.RefreshExpensePlanner()
end
function ns.OpenTrainingPlanner(goal,onChange) ns.OpenExpensePlanner(goal,onChange,true) end
function ns.UpdateOpenPlannerGoal(goal)
    local page=ns.planningFrame
    if not page or not page.goal or not ns.ui or ns.ui.currentPage~=page.key then return end
    page.goal=Model.CopyGoal(goal); ns.RefreshExpensePlanner()
end
