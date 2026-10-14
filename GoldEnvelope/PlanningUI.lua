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
        local frame = UI.Window("GoldEnvelopePlanningConsent", 460, 250, "Choose how to plan this goal")
        ns.planningConsent = frame
        frame:SetFrameLevel(2000)
        frame.body = UI.Label(frame, "", 26, -60, 406, "GameFontHighlight")
        frame.body:SetSpacing(5)
        UI.Button(frame, "Choose expenses", 26, -200, 190, function()
            local callback = yesPlanning
            yesPlanning, noPlanning = nil, nil
            frame:Hide()
            if callback then callback() end
        end)
        UI.Button(frame, "Keep simple budget", 244, -200, 190, function()
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
        .. (goal.presetID == "class-training" and "\nSpell prices will come from your class trainer."
            or goal.presetID == "profession-training" and "\nPrices will come from your profession trainers." or ""))
    ns.planningConsent:Show()
end

function ns.RefreshExpensePlanner()
    local frame = ns.planningFrame
    if not frame or not planningGoal then return end
    ns.SyncExpenses(planningGoal)
    local unknown = 0
    frame.rows = frame.rows or {}
    for _, row in ipairs(frame.rows) do row:Hide() end
    for index, expense in ipairs(planningGoal.expenses) do
        local item = expense
        local row = frame.rows[index]
        if not row then
            row = CreateFrame("Frame", nil, frame.content)
            row:SetSize(628, 45)
            row.check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
            row.check:SetPoint("TOPLEFT", 0, -2)
            row.name = UI.Label(row, "", 34, -5, 328, "GameFontHighlightSmall")
            row.name:SetWordWrap(false)
            row.detail = UI.Label(row, "", 34, -25, 328, "GameFontNormalSmall")
            row.cost = UI.Label(row, "", 370, -10, 245, "GameFontHighlightSmall")
            frame.rows[index] = row
        end
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, -(index - 1) * 47)
        row.name:SetText(expense.name .. (expense.rank and expense.rank ~= "" and " (" .. expense.rank .. ")" or ""))
        row.detail:SetText("Level " .. expense.level .. (expense.paid and "  - learned / paid" or "")
            .. (expense.estimated and "  - starter estimate" or "")
            .. (expense.level > planningGoal.targetLevel and "  - beyond this goal" or ""))
        row.check:SetChecked(expense.selected)
        row.check:SetEnabled(not expense.paid)
        row.check:SetScript("OnClick", function(self)
            item.selected = self:GetChecked() and true or false
            ns.RefreshExpensePlanner()
        end)
        row.cost:SetText(expense.copper and ns.MoneyText(expense.copper) or "Price unknown")
        if expense.selected and not expense.paid and expense.copper == nil then unknown = unknown + 1 end
        row:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(item.name)
            if item.trainer then GameTooltip:AddLine("Last quote: " .. item.trainer) end
            if item.source == "class" then GameTooltip:AddLine("Higher spell ranks may require earlier ranks.", 1, 0.8, 0.4, true) end
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)
        row:EnableMouse(true)
        row:Show()
    end
    frame.content:SetHeight(math.max(1, #planningGoal.expenses * 47))
    local guidance = planningGoal.presetID == "class-training"
        and "Visit your class trainer with all service filters shown. Unlisted spell prices are unknown."
        or planningGoal.presetID == "profession-training"
        and "Visit profession trainers with all service filters shown. Unlisted recipe prices are unknown."
        or "Trainer quotes update when observed. You can add your own itemized costs below."
    frame.summary:SetText("Known selected costs: " .. ns.MoneyText(Model.ExpenseTotal(planningGoal))
        .. "\n" .. guidance .. (unknown > 0 and ("\n" .. unknown .. " selected prices still unknown; total is incomplete.") or ""))
end

function ns.OpenExpensePlanner(goal, onApply)
    if not ns.planningFrame then
        local frame = UI.Window("GoldEnvelopeExpensePlanner", 720, 650, "Choose goal expenses")
        ns.planningFrame = frame
        frame:SetFrameLevel(2100)
        frame.summary = UI.Label(frame, "", 26, -59, 668, "GameFontHighlightSmall")
        frame.scroll = CreateFrame("ScrollFrame", "GoldEnvelopeExpenseScroll", frame, "UIPanelScrollFrameTemplate")
        frame.scroll:SetPoint("TOPLEFT", 26, -128)
        frame.scroll:SetSize(640, 335)
        frame.content = CreateFrame("Frame", nil, frame.scroll)
        frame.content:SetSize(628, 1)
        frame.scroll:SetScrollChild(frame.content)
        UI.Label(frame, "Add a cost (use the same name and level to update a manual entry)", 26, -480, 668, "GameFontNormalSmall")
        frame.expenseName = UI.Edit(frame, 32, -513, 350, "")
        UI.Label(frame, "Needed at level", 418, -492, 150, "GameFontNormalSmall")
        frame.expenseLevel = UI.Edit(frame, 422, -513, 65, "", true)
        frame.expenseAmount = UI.Coins(frame, 32, -550)
        UI.Button(frame, "Add / update", 422, -550, 145, function()
            if not planningGoal then return end
            local name = frame.expenseName:GetText():match("^%s*(.-)%s*$")
            local level = tonumber(frame.expenseLevel:GetText())
            local copper, errorText = UI.GetCoins(frame.expenseAmount)
            if not name:match("%S") then frame.error:SetText("Enter an expense name."); return end
            if not level or level ~= math.floor(level) or level < 1 or level > planningGoal.targetLevel then
                frame.error:SetText("Choose a whole level from 1 to your goal's target level."); return
            end
            if not copper then frame.error:SetText(errorText); return end
            for _, item in ipairs(planningGoal.expenses) do
                if item.source == "manual" and item.name == name and item.level == level then
                    item.copper, item.estimated = copper, false
                    ns.RefreshExpensePlanner(); frame.error:SetText("Cost updated."); return
                end
            end
            local serial = (planningGoal.nextExpenseID or 0) + 1
            planningGoal.nextExpenseID = serial
            planningGoal.expenses[#planningGoal.expenses + 1] = { key = "manual:" .. serial,
                name = name, level = level, copper = copper, selected = true, source = "manual" }
            ns.RefreshExpensePlanner(); frame.error:SetText("Cost added.")
        end)
        frame.error = UI.Label(frame, "", 26, -588, 668, "GameFontHighlightSmall")
        UI.Button(frame, "Apply choices", 26, -610, 150, function()
            if not planningGoal then return end
            ns.SyncExpenses(planningGoal)
            local valid, errorText = Model.ValidateGoal(planningGoal)
            if not valid then frame.error:SetText(errorText); return end
            local callback, updated = applyPlanning, planningGoal
            planningGoal, applyPlanning = nil, nil
            frame:Hide()
            if callback then callback(updated) end
        end)
        UI.Button(frame, "Cancel", 548, -610, 145, function()
            planningGoal, applyPlanning = nil, nil; frame:Hide()
        end)
        frame:SetScript("OnHide", function() planningGoal, applyPlanning = nil, nil end)
    end
    planningGoal, applyPlanning = Model.CopyGoal(goal), onApply
    ns.planningFrame.expenseName:SetText("")
    ns.planningFrame.expenseLevel:SetText(tostring(goal.targetLevel))
    UI.SetCoins(ns.planningFrame.expenseAmount, 0)
    ns.planningFrame.error:SetText("")
    ns.planningFrame.scroll:SetVerticalScroll(0)
    ns.RefreshExpensePlanner()
    ns.planningFrame:Show()
end
