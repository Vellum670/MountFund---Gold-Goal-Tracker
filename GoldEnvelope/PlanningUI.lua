local _, ns = ...
local UI, Model = ns.UI, ns.Model
local planningGoal, applyPlanning, yesPlanning, noPlanning
local manualKey

local function savePlannerChange()
    ns.SyncExpenses(planningGoal)
    if applyPlanning then applyPlanning(Model.CopyGoal(planningGoal)) end
end

function ns.ClosePlanningWindows()
    planningGoal, applyPlanning, yesPlanning, noPlanning = nil, nil, nil, nil
    if ns.planningFrame then ns.planningFrame:Hide() end
    if ns.planningConsent then ns.planningConsent:Hide() end
end

function ns.AskGoalPlanning(goal, onYes, onNo)
    if not ns.planningConsent then
        local frame = UI.Window("GoldEnvelopePlanningConsent", 400, 250, "Choose how to plan this goal")
        ns.planningConsent = frame
        frame:SetFrameLevel(2000)
        frame.body = UI.Label(frame, "", 26, -60, 348, "GameFontHighlightSmall")
        frame.body:SetSpacing(5)
        UI.Button(frame, "Choose expenses", 16, -200, 177, function()
            local callback = yesPlanning
            yesPlanning, noPlanning = nil, nil
            frame:Hide()
            if callback then callback() end
        end)
        UI.Button(frame, "Keep simple budget", 207, -200, 177, function()
            local callback = noPlanning
            yesPlanning, noPlanning = nil, nil
            frame:Hide()
            if callback then callback() end
        end)
        frame:SetScript("OnHide", function() yesPlanning, noPlanning = nil, nil end)
    end
    yesPlanning, noPlanning = onYes, onNo
    local name = goal.name ~= "" and goal.name or "this goal"
    ns.planningConsent.body:SetText("Would you like to choose individual expenses for " .. name
        .. "?\n\nClick purchase icons to include or exclude them. Otherwise, keep a single savings amount."
        .. (goal.presetID == "class-training" and "\nBundled spell estimates update from your class trainer."
            or goal.presetID == "profession-training" and "\nPrices will come from your profession trainers." or ""))
    ns.planningConsent:Show()
end

local function showExpenseTooltip(button)
    local item=button.expense
    if not item then return end
    GameTooltip:SetOwner(button,"ANCHOR_RIGHT")
    if item.spellID then
        GameTooltip:SetSpellByID(item.spellID,false,false,true)
    elseif item.link then
        GameTooltip:SetHyperlink(item.link)
    else
        GameTooltip:SetText(item.name)
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Next required level: " .. button.requiredLevel,1,0.82,0)
    GameTooltip:AddLine("Cost through level " .. planningGoal.targetLevel .. ": " .. ns.MoneyText(button.cost)
        .. (button.unknown and " (some prices unknown)" or ""),1,1,1)
    if button.readOnly and item.paid then
        GameTooltip:AddLine("Already learned",0.6,0.6,0.6)
    elseif button.readOnly then
        GameTooltip:AddLine("Not eligible for this character yet",0.6,0.6,0.6)
    else
        GameTooltip:AddLine(button.included and "Included - click to exclude ability" or "Excluded - click to include ability",1,0.82,0)
    end
    if item.priceSource then GameTooltip:AddLine(item.priceSource,0.6,0.6,0.6) end
    if item.trainer then GameTooltip:AddLine("Quoted by " .. item.trainer,0.6,0.6,0.6) end
    if item.requiresSpell then GameTooltip:AddLine("Requires its earlier talent or quest rank.",1,0.8,0.4,true) end
    GameTooltip:Show()
end

local function abilityGroups(goal,classOnly)
    local groups,byKey={},{}
    for _,expense in ipairs(goal.expenses) do
        if (classOnly and expense.source=="class") or (not classOnly and expense.source~="class") then
            local isAbility=expense.source=="class" or expense.source=="profession"
            local key=isAbility and (expense.source .. ":" .. expense.name) or expense.key
            local group=byKey[key]
            if not group then
                group={expenses={},relevant={},readOnly=true,cost=0,included=false}
                byKey[key]=group; groups[#groups+1]=group
            end
            group.expenses[#group.expenses+1]=expense
            if expense.level >= (goal.startLevel or ns.GetPlayerLevel()) and expense.level <= goal.targetLevel then
                group.relevant[#group.relevant+1]=expense
                local trainable=not expense.paid and expense.eligible~=false
                if not group.expense or (trainable and not group.hasTrainable) then
                    group.expense,group.requiredLevel=expense,expense.level
                end
                if trainable then
                    group.hasTrainable,group.readOnly=true,false
                    group.included=group.included or expense.selected
                    if expense.copper then group.cost=group.cost+expense.copper else group.unknown=true end
                end
            end
        end
    end
    table.sort(groups,function(a,b)
        if not a.expense then return false end
        if not b.expense then return true end
        if a.requiredLevel~=b.requiredLevel then return a.requiredLevel<b.requiredLevel end
        return a.expense.name<b.expense.name
    end)
    return groups
end

function ns.RefreshExpensePlanner()
    local frame=ns.planningFrame
    if not frame or not planningGoal then return end
    ns.SyncExpenses(planningGoal)
    frame.goalName:SetText("Goal: " .. (planningGoal.name~="" and planningGoal.name or "New goal"))
    frame.expenseButtons=frame.expenseButtons or {}
    for _,button in ipairs(frame.expenseButtons) do button:Hide() end
    -- Native action-sized icons with an eight-pixel gutter: eight columns fit
    -- the existing 356px content width without shrinking the click targets.
    local columns, strideX, strideY=8,44,54
    local visible,unknown=0,0
    for _,group in ipairs(abilityGroups(planningGoal,frame.classMode)) do
        if group.expense then
            visible=visible+1
            local button=frame.expenseButtons[visible]
            if not button then
                button=CreateFrame("Button",nil,frame.content); button:SetSize(36,36)
                -- A solid inset frame stays inside the button. Quickslot artwork
                -- has oversized decorative corners that overlap this dense grid.
                button.border=button:CreateTexture(nil,"BACKGROUND"); button.border:SetAllPoints()
                button.icon=button:CreateTexture(nil,"ARTWORK")
                button.icon:SetPoint("TOPLEFT",2,-2); button.icon:SetPoint("BOTTOMRIGHT",-2,2)
                button.icon:SetTexCoord(0.07,0.93,0.07,0.93)
                button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square","BLEND")
                local highlight=button:GetHighlightTexture()
                highlight:ClearAllPoints()
                highlight:SetPoint("TOPLEFT",2,-2); highlight:SetPoint("BOTTOMRIGHT",-2,2)
                highlight:SetColorTexture(1,1,1,0.12)
                button.level=UI.Label(button,"",-2,-39,40,"GameFontDisableSmall")
                button.level:SetJustifyH("CENTER"); button.level:SetWordWrap(false)
                button:SetScript("OnClick",function(self)
                    if self.readOnly then return end
                    local selected=not self.included
                    for _,item in ipairs(self.expenses) do item.selected=selected end
                    savePlannerChange()
                    ns.RefreshExpensePlanner(); showExpenseTooltip(self)
                end)
                button:SetScript("OnEnter",showExpenseTooltip)
                button:SetScript("OnLeave",function() GameTooltip:Hide() end)
                frame.expenseButtons[visible]=button
            end
            button.expense,button.expenses=group.expense,group.expenses
            button.readOnly,button.included=group.readOnly,group.included
            button.cost,button.unknown,button.requiredLevel=group.cost,group.unknown,group.requiredLevel
            button:ClearAllPoints()
            button:SetPoint("TOPLEFT",6+((visible-1)%columns)*strideX,-math.floor((visible-1)/columns)*strideY-2)
            button.icon:SetTexture(ns.ExpenseIcon(group.expense))
            local included=group.included and not group.readOnly
            button.icon:SetDesaturated(not included)
            local tint=included and 1 or 0.5
            button.icon:SetVertexColor(tint,tint,tint)
            button.border:SetColorTexture(included and 0.72 or 0.3,included and 0.55 or 0.3,included and 0.24 or 0.3,1)
            button.level:SetText("Lv " .. group.requiredLevel)
            button:Show()
            if included and group.unknown then unknown=unknown+1 end
        end
    end
    frame.content:SetHeight(math.max(1,math.ceil(visible/columns)*strideY))
    local training,complete=ns.TrainingRunway(planningGoal)
    frame.summary:SetText("Goal target " .. ns.MoneyText(planningGoal.targetCopper)
        .. "\nNext two levels' training " .. ns.MoneyText(training)
        .. ((unknown>0 or not complete) and " - some prices unknown" or ""))
end

function ns.OpenExpensePlanner(goal,onApply,classOnly)
    if not ns.planningFrame then
        local frame=UI.Window("GoldEnvelopeExpensePlanner",420,520,"Choose goal expenses"); ns.planningFrame=frame
        frame:SetFrameLevel(2100)
        local surface=frame:CreateTexture(nil,"BACKGROUND",nil,-8)
        surface:SetPoint("TOPLEFT",5,-5); surface:SetPoint("BOTTOMRIGHT",-5,5)
        surface:SetColorTexture(0.055,0.04,0.025,1)
        frame.goalName=UI.Label(frame,"",16,-56,388)
        frame.goalName:SetWordWrap(false); frame.goalName:SetHeight(20)
        frame.summary=UI.Label(frame,"",16,-85,388,"GameFontHighlightSmall")
        UI.Label(frame,"Click icons to toggle. Hover for details.",16,-121,388,"GameFontDisableSmall")
        frame.scroll=CreateFrame("ScrollFrame",nil,frame,"UIPanelScrollFrameTemplate")
        frame.scroll:SetPoint("TOPLEFT",16,-142); frame.scroll:SetSize(368,200)
        frame.content=CreateFrame("Frame",nil,frame.scroll); frame.content:SetSize(356,1); frame.scroll:SetScrollChild(frame.content)
        frame.manual=CreateFrame("Frame",nil,frame); frame.manual:SetAllPoints()
        UI.Label(frame.manual,"Add or update a manual cost",16,-354,388,"GameFontNormalSmall")
        frame.expenseName=UI.Edit(frame.manual,22,-380,240,"")
        frame.expenseLevel=UI.Edit(frame.manual,310,-380,62,"",true)
        UI.Label(frame.manual,"Level",310,-363,62,"GameFontNormalSmall")
        frame.expenseAmount=UI.Coins(frame.manual,22,-414)
        local function saveManualCost()
            if not planningGoal or frame.classMode then return end
            local name=frame.expenseName:GetText():match("^%s*(.-)%s*$")
            local level=tonumber(frame.expenseLevel:GetText())
            local copper,errorText=UI.GetCoins(frame.expenseAmount)
            if not name:match("%S") then return end
            if not level or level~=math.floor(level) or level<(planningGoal.startLevel or 1) or level>planningGoal.targetLevel then
                frame.error:SetText("Use a level within this goal's start and target."); return
            end
            if not copper then frame.error:SetText(errorText); return end
            for _,item in ipairs(planningGoal.expenses) do
                if item.source=="manual" and (item.key==manualKey or (not manualKey and item.name==name and item.level==level)) then
                    manualKey=item.key
                    item.name,item.level,item.copper,item.estimated=name,level,copper,false
                    savePlannerChange(); ns.RefreshExpensePlanner(); frame.error:SetText("Saved automatically."); return
                end
            end
            planningGoal.nextExpenseID=(planningGoal.nextExpenseID or 0)+1
            manualKey="manual:" .. planningGoal.nextExpenseID
            planningGoal.expenses[#planningGoal.expenses+1]={key=manualKey,name=name,
                level=level,copper=copper,selected=true,source="manual"}
            savePlannerChange(); ns.RefreshExpensePlanner(); frame.error:SetText("Saved automatically.")
        end
        for _,field in ipairs({frame.expenseName,frame.expenseLevel,unpack(frame.expenseAmount)}) do
            field:SetScript("OnEditFocusLost",saveManualCost)
        end
        UI.Button(frame.manual,"New cost",236,-414,140,function()
            saveManualCost()
            manualKey=nil
            frame.expenseName:SetText(""); frame.expenseLevel:SetText(tostring(planningGoal.targetLevel))
            UI.SetCoins(frame.expenseAmount,0); frame.error:SetText("")
            frame.expenseName:SetFocus()
        end)
        frame.error=UI.Label(frame,"",16,-453,388,"GameFontHighlightSmall")
        UI.Label(frame,"Changes save automatically.",16,-488,200,"GameFontDisableSmall")
        UI.Button(frame,"Close",274,-481,130,function()
            saveManualCost(); frame:Hide()
        end)
        frame:SetScript("OnHide",function()
            saveManualCost(); planningGoal,applyPlanning=nil,nil; manualKey=nil; GameTooltip:Hide()
        end)
    end
    planningGoal,applyPlanning=Model.CopyGoal(goal),onApply
    manualKey=nil
    local frame=ns.planningFrame
    frame.classMode=classOnly and true or false
    if frame.classMode then
        planningGoal.includeClassTraining=true
        savePlannerChange()
    end
    frame.title:SetText(frame.classMode and "Choose training abilities" or "Choose goal expenses")
    frame.manual:SetShown(not frame.classMode)
    frame.scroll:SetSize(368,frame.classMode and 300 or 200)
    ns.planningFrame.expenseName:SetText(""); ns.planningFrame.expenseLevel:SetText(tostring(goal.targetLevel))
    UI.SetCoins(ns.planningFrame.expenseAmount,0); ns.planningFrame.error:SetText("")
    ns.planningFrame.scroll:SetVerticalScroll(0); ns.RefreshExpensePlanner(); ns.planningFrame:Show()
end

function ns.OpenTrainingPlanner(goal,onApply)
    ns.OpenExpensePlanner(goal,onApply,true)
end

function ns.UpdateOpenPlannerGoal(goal)
    if not planningGoal then return end
    planningGoal=Model.CopyGoal(goal)
    ns.RefreshExpensePlanner()
end
