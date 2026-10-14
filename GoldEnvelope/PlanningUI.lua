local _, ns = ...
local UI, Model = ns.UI, ns.Model
local planningGoal, applyPlanning, yesPlanning, noPlanning

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
        .. "?\n\nYou can uncheck purchases you do not plan to make. Otherwise, keep a single savings amount."
        .. (goal.presetID == "class-training" and "\nBundled spell estimates update from your class trainer."
            or goal.presetID == "profession-training" and "\nPrices will come from your profession trainers." or ""))
    ns.planningConsent:Show()
end

function ns.RefreshExpensePlanner()
    local frame=ns.planningFrame
    if not frame or not planningGoal then return end
    ns.SyncExpenses(planningGoal)
    frame.classTraining:SetChecked(planningGoal.includeClassTraining)
    frame.rows=frame.rows or {}
    for _,row in ipairs(frame.rows) do row:Hide() end
    local visible,unknown=0,0
    for _,expense in ipairs(planningGoal.expenses) do
        if expense.level >= (planningGoal.startLevel or UnitLevel("player")) and expense.level <= planningGoal.targetLevel
            and (expense.source ~= "class" or planningGoal.includeClassTraining) then
            visible=visible+1
            local item=expense
            local row=frame.rows[visible]
            if not row then
                row=CreateFrame("Frame",nil,frame.content); row:SetSize(356,47)
                row.check=CreateFrame("CheckButton",nil,row,"UICheckButtonTemplate"); row.check:SetPoint("TOPLEFT",0,-2)
                row.name=UI.Label(row,"",32,-5,310,"GameFontHighlightSmall"); row.name:SetWordWrap(false)
                row.detail=UI.Label(row,"",32,-26,124,"GameFontNormalSmall")
                row.cost=UI.Label(row,"",160,-26,186,"GameFontHighlightSmall"); frame.rows[visible]=row
            end
            row:ClearAllPoints(); row:SetPoint("TOPLEFT",0,-(visible-1)*49)
            row.name:SetText(expense.name .. (expense.rank and expense.rank~="" and " (" .. expense.rank .. ")" or ""))
            row.detail:SetText("Level " .. expense.level .. (expense.paid and " - learned" or ""))
            row.cost:SetText(expense.copper and ns.MoneyText(expense.copper) or "Price unknown")
            row.check:SetChecked(expense.selected); row.check:SetEnabled(not expense.paid)
            row.check:SetScript("OnClick",function(self) item.selected=self:GetChecked() and true or false; ns.RefreshExpensePlanner() end)
            row:SetScript("OnEnter",function(self)
                GameTooltip:SetOwner(self,"ANCHOR_RIGHT"); GameTooltip:SetText(item.name)
                if item.priceSource then GameTooltip:AddLine(item.priceSource) end
                if item.trainer then GameTooltip:AddLine("Quoted by " .. item.trainer) end
                if item.requiresSpell then GameTooltip:AddLine("Requires its earlier talent or quest rank.",1,0.8,0.4,true) end
                GameTooltip:Show()
            end)
            row:SetScript("OnLeave",function() GameTooltip:Hide() end); row:EnableMouse(true); row:Show()
            if expense.selected and not expense.paid and not expense.copper then unknown=unknown+1 end
        end
    end
    frame.content:SetHeight(math.max(1,visible*49))
    local training,complete=ns.TrainingRunway(planningGoal)
    frame.summary:SetText("Goal costs " .. ns.MoneyText(Model.ExpenseTotal(planningGoal))
        .. "\nNext two levels' training " .. ns.MoneyText(training)
        .. ((unknown>0 or not complete) and " - some prices unknown" or ""))
end

function ns.OpenExpensePlanner(goal,onApply)
    if not ns.planningFrame then
        local frame=UI.Window("GoldEnvelopeExpensePlanner",420,520,"Choose goal expenses"); ns.planningFrame=frame
        frame:SetFrameLevel(2100)
        frame.classTraining=CreateFrame("CheckButton",nil,frame,"UICheckButtonTemplate"); frame.classTraining:SetPoint("TOPLEFT",12,-49)
        UI.Label(frame,"Class training",46,-57,354)
        frame.classTraining:SetScript("OnClick",function(self)
            if not planningGoal then return end
            planningGoal.includeClassTraining=self:GetChecked() and true or false; ns.RefreshExpensePlanner()
        end)
        frame.summary=UI.Label(frame,"",16,-89,388,"GameFontHighlightSmall")
        frame.scroll=CreateFrame("ScrollFrame",nil,frame,"UIPanelScrollFrameTemplate")
        frame.scroll:SetPoint("TOPLEFT",16,-131); frame.scroll:SetSize(368,211)
        frame.content=CreateFrame("Frame",nil,frame.scroll); frame.content:SetSize(356,1); frame.scroll:SetScrollChild(frame.content)
        UI.Label(frame,"Add or update a manual cost",16,-354,388,"GameFontNormalSmall")
        frame.expenseName=UI.Edit(frame,22,-380,240,"")
        frame.expenseLevel=UI.Edit(frame,310,-380,62,"",true)
        UI.Label(frame,"Level",310,-363,62,"GameFontNormalSmall")
        frame.expenseAmount=UI.Coins(frame,22,-414)
        UI.Button(frame,"Add / update",236,-414,140,function()
            local name=frame.expenseName:GetText():match("^%s*(.-)%s*$")
            local level=tonumber(frame.expenseLevel:GetText())
            local copper,errorText=UI.GetCoins(frame.expenseAmount)
            if not name:match("%S") then frame.error:SetText("Enter an expense name."); return end
            if not level or level~=math.floor(level) or level<(planningGoal.startLevel or 1) or level>planningGoal.targetLevel then
                frame.error:SetText("Use a level within this goal's start and target."); return
            end
            if not copper then frame.error:SetText(errorText); return end
            for _,item in ipairs(planningGoal.expenses) do
                if item.source=="manual" and item.name==name and item.level==level then
                    item.copper,item.estimated=copper,false; ns.RefreshExpensePlanner(); frame.error:SetText("Cost updated."); return
                end
            end
            planningGoal.nextExpenseID=(planningGoal.nextExpenseID or 0)+1
            planningGoal.expenses[#planningGoal.expenses+1]={key="manual:" .. planningGoal.nextExpenseID,name=name,
                level=level,copper=copper,selected=true,source="manual"}
            ns.RefreshExpensePlanner(); frame.error:SetText("Cost added.")
        end)
        frame.error=UI.Label(frame,"",16,-453,388,"GameFontHighlightSmall")
        UI.Button(frame,"Apply choices",16,-481,170,function()
            ns.SyncExpenses(planningGoal)
            local valid,errorText=Model.ValidateGoal(planningGoal)
            if not valid then frame.error:SetText(errorText); return end
            local callback,updated=applyPlanning,planningGoal; planningGoal,applyPlanning=nil,nil; frame:Hide()
            if callback then callback(updated) end
        end)
        UI.Button(frame,"Cancel",234,-481,170,function() planningGoal,applyPlanning=nil,nil; frame:Hide() end)
        frame:SetScript("OnHide",function() planningGoal,applyPlanning=nil,nil end)
    end
    planningGoal,applyPlanning=Model.CopyGoal(goal),onApply
    ns.planningFrame.expenseName:SetText(""); ns.planningFrame.expenseLevel:SetText(tostring(goal.targetLevel))
    UI.SetCoins(ns.planningFrame.expenseAmount,0); ns.planningFrame.error:SetText("")
    ns.planningFrame.scroll:SetVerticalScroll(0); ns.RefreshExpensePlanner(); ns.planningFrame:Show()
end
