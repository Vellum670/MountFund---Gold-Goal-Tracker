-- Presentation adapter: reuse the validated editor and planners inside the character pane.
local _, ns = ...
local UI = ns.UI
local function place(control, parent, x, y, width, height)
    if parent then control:SetParent(parent) end
    control:ClearAllPoints(); control:SetPoint("TOPLEFT", x, -y)
    if width then control:SetWidth(math.max(1, width)) end
    if height then control:SetHeight(math.max(1, height)) end
end
local function text(parent, caption, font)
    return UI.Label(parent, caption, 0, 0, 100, font or "GameFontHighlightSmall")
end
local function line(parent)
    local region=parent:CreateTexture(nil,"BORDER")
    region:SetColorTexture(0.55,0.4,0.18,0.55)
    return region
end
local function hint(control, title, body)
    control:SetScript("OnEnter",function(self)
        GameTooltip:SetOwner(self,"ANCHOR_RIGHT"); GameTooltip:SetText(title)
        GameTooltip:AddLine(body,1,1,1,true); GameTooltip:Show()
    end)
    control:SetScript("OnLeave",function() GameTooltip:Hide() end)
end
local function flatButton(parent, caption, callback)
    local control=CreateFrame("Button",nil,parent)
    control:SetSize(90,24)
    control:SetFontString(text(control,caption,"GameFontNormalSmall"))
    control:GetFontString():SetAllPoints(); control:GetFontString():SetJustifyH("CENTER")
    control:SetText(caption)
    control.tint=control:CreateTexture(nil,"BACKGROUND"); control.tint:SetAllPoints()
    control.tint:SetColorTexture(0.5,0.36,0.12,0.14)
    control:SetHighlightTexture("Interface\\Buttons\\WHITE8X8")
    control:GetHighlightTexture():SetVertexColor(1,0.82,0.2,0.12)
    control:SetScript("OnClick",callback)
    return control
end
local function iconButton(parent, texture, caption, body, callback)
    local control=flatButton(parent,"",callback)
    control.icon=control:CreateTexture(nil,"ARTWORK"); control.icon:SetAllPoints()
    control.icon:SetTexture(texture); control.icon:SetDesaturated(true); control.icon:SetVertexColor(0.95,0.78,0.44,1)
    hint(control,caption,body)
    return control
end
local function pane(parent)
    local result=CreateFrame("Frame",nil,parent)
    result.scroll=CreateFrame("ScrollFrame",nil,result,"UIPanelScrollFrameTemplate")
    result.scroll:SetPoint("TOPLEFT"); result.scroll:SetPoint("BOTTOMRIGHT",-21,0)
    result.content=CreateFrame("Frame",nil,result.scroll)
    result.content:SetSize(100,1); result.scroll:SetScrollChild(result.content)
    return result
end
local function contentHeight(paneFrame, height)
    paneFrame.content:SetHeight(math.max(1,height))
    local maximum=math.max(0,height-paneFrame:GetHeight())
    paneFrame.scroll:SetVerticalScroll(math.min(paneFrame.scroll:GetVerticalScroll() or 0,maximum))
end
local function showInfo(title, body, icon)
    local ui=ns.ui; local shell=ui and ui.characterUI
    if not shell then return end
    shell.info:Show(); ui.pages.main:Hide()
    if shell.infoTitle:GetText()~=(title or "Mountfund") then shell.right.scroll:SetVerticalScroll(0) end
    shell.infoTitle:SetText(title or "Mountfund")
    shell.infoBody:SetText(body or "")
    shell.infoIcon:SetShown(icon~=nil)
    if icon then shell.infoIcon:SetTexture(icon) end
    local width=shell.right.content:GetWidth()
    place(shell.infoTitle,nil,0,icon and 58 or 0,width)
    shell.infoTitle:SetWordWrap(true)
    local top=(icon and 58 or 0)+math.max(18,shell.infoTitle:GetStringHeight() or 18)+14
    place(shell.infoBody,nil,0,top,width)
    shell.infoBody:SetWordWrap(true)
    local height=top+math.max(20,shell.infoBody:GetStringHeight() or 20)+20
    shell.info:SetWidth(width); shell.info:SetHeight(height); contentHeight(shell.right,height)
end
function ns.ShowSettingHelp(title,body)
    local shell=ns.ui and ns.ui.characterUI
    if not shell then return end
    shell.settingTitle,shell.settingHelp=title,body
    if ns.ui.currentPage=="settings" then showInfo(title,body) end
end
local function settingsHelp(control,title,body,caption)
    local original=control:GetScript("OnClick")
    control:SetScript("OnClick",function(self,...)
        if original then original(self,...) end
        ns.ShowSettingHelp(title,body)
    end)
    control:SetScript("OnEnter",function() ns.ShowSettingHelp(title,body) end)
    control:SetScript("OnLeave",function() GameTooltip:Hide() end)
    if caption then
        local row=CreateFrame("Button",nil,control:GetParent())
        row:SetScript("OnEnter",function() ns.ShowSettingHelp(title,body) end)
        row:SetScript("OnClick",function()
            control:SetChecked(not control:GetChecked())
            local callback=control:GetScript("OnClick")
            if callback then callback(control,"LeftButton") end
        end)
        row:SetPoint("TOPLEFT",caption,"TOPLEFT",0,5)
        row:SetPoint("BOTTOMRIGHT",caption,"BOTTOMRIGHT",0,-5)
        control.helpRow=row
    end
end
local function layoutCoins(fields,parent,y,width)
    local spacing=math.floor((width-6)/3)
    for i,field in ipairs(fields) do
        place(field,parent,6+(i-1)*spacing,y,math.max(26,spacing-23),24)
        if field.coinIcon then
            field.coinIcon:ClearAllPoints(); field.coinIcon:SetPoint("LEFT",field,"RIGHT",3,0)
            field.coinIcon:SetSize(12,12)
        end
    end
end
local function layoutEditor(ui,shell,width)
    local main=ui.pages.main
    place(main,shell.right.content,0,0,width,640)
    place(ui.editor,main,0,0,width,640)
    place(ui.selection,ui.editor,0,0,width)
    ui.selection:SetWordWrap(true)
    local titleHeight=math.max(18,ui.selection:GetStringHeight() or 18)
    place(ui.progress,ui.editor,0,titleHeight+7,width)
    ui.progress:SetWordWrap(true)
    local progressHeight=math.max(28,ui.progress:GetStringHeight() or 28)
    local goalTop=titleHeight+progressHeight+18
    place(ui.levelGoal,ui.editor,0,goalTop,width,62)
    place(ui.levelGoalHeading,ui.levelGoal,0,0,width)
    place(ui.levelGoalAmount,ui.levelGoal,0,18,width)
    place(ui.levelGoalDetail,ui.levelGoal,0,36,width)
    ui.levelGoalDetail:SetWordWrap(true)
    local fieldsTop=goalTop+78
    place(ui.editorFields,ui.editor,0,fieldsTop,width,404)
    place(ui.nameLabel,nil,0,0,width)
    place(ui.name,nil,6,21,width-12,24)
    place(ui.amountLabel,nil,0,59,width)
    layoutCoins(ui.amount,ui.editorFields,80,width)
    place(ui.basis,nil,0,116,width,24)
    place(ui.level,nil,6,147,width-12,24)
    place(ui.active,nil,-3,181,26,26)
    place(ui.trackLabel,nil,27,189,width-27)
    place(ui.curve,nil,0,222,width,24)
    place(ui.planning,nil,0,255,width,24)
    place(ui.savingsPlan,nil,0,288,width,24)
    local half=math.floor((width-8)/2)
    place(ui.complete,nil,0,328,half,24)
    place(ui.delete,nil,half+8,328,half,24)
    if width<190 then
        place(ui.complete,nil,0,328,width,24)
        place(ui.delete,nil,0,362,width,24)
    end
    ui.training:Hide()
    place(shell.createButton,ui.editorFields,0,328,width,24)
    place(shell.cancelDraft,ui.editorFields,0,362,width,24)
    shell.createButton:SetShown(ui.creatingGoal==true)
    shell.cancelDraft:SetShown(ui.creatingGoal==true)
    ui.complete:SetShown(not ui.creatingGoal); ui.delete:SetShown(not ui.creatingGoal)
    local height=fieldsTop+((ui.creatingGoal or width<190) and 398 or 366)
    main:SetHeight(height); ui.editor:SetHeight(height)
    contentHeight(shell.right,height)
end
local function layoutGoalRows(ui,shell,width,height)
    local picker=ui.goalPicker
    local top=44+(shell.totalLines or 1)*15
    height=math.max(height,top+110)
    place(picker,shell.left.content,0,top,width,height-top)
    place(picker.instructions,nil,0,0,width)
    picker.instructions:SetText("Drag the dots: top goals receive savings first.")
    picker.instructions:SetWordWrap(true); picker.instructions:SetHeight(28)
    place(picker.scroll,nil,0,34,width-18,math.max(34,height-top-75))
    picker.content:SetWidth(width-20)
    picker.dropLine:SetWidth(width-20)
    place(picker.history,nil,0,height-top-29,width-20,24)
    picker.empty:SetWidth(width-20)
    contentHeight(shell.left,height)
    picker.empty:SetText(#ns.GetGoals()==0 and "Choose New goal or Presets to get started." or "")
    for _,row in ipairs(picker.rows or {}) do
        if not row.characterStyled then
            row:SetNormalTexture(nil); row:SetPushedTexture(nil); row:SetDisabledTexture(nil)
            row:SetHighlightTexture("Interface\\Buttons\\WHITE8X8")
            row:GetHighlightTexture():SetVertexColor(1,0.82,0.2,0.1)
            row.fill=row:CreateTexture(nil,"BACKGROUND"); row.fill:SetPoint("BOTTOMLEFT",0,0); row.fill:SetHeight(2)
            row.detail=text(row,"","GameFontHighlightSmall")
            row.characterStyled=true
        end
        row:SetWidth(width-44); row:SetHeight(31); row.deleteGoal:Hide()
        local caption=row:GetFontString()
        if caption then
            place(caption,nil,0,0,width-52,15); caption:SetWordWrap(false); caption:SetJustifyH("LEFT")
        end
        local goal=ns.GetGoals()[row.goalIndex]
        if goal then
            place(row.detail,nil,0,15,width-52,13)
            row.detail:SetWordWrap(false)
            row.detail:SetText(goal.completedAt and "Completed" or ns.MoneyText(goal.savedCopper or 0) .. " / " .. ns.MoneyText(goal.targetCopper))
            local fraction=goal.targetCopper>0 and math.min(1,(goal.savedCopper or 0)/goal.targetCopper) or 0
            row.fill:SetWidth(math.max(1,(width-44)*fraction))
            row.fill:SetColorTexture(0.72,0.55,0.22,goal.completedAt and 0.25 or 0.8)
            if row.goalIndex==ui.selectedGoalIndex and not ui.creatingGoal then row:LockHighlight() else row:UnlockHighlight() end
        end
    end
end
local function layoutSettings(ui,shell,width)
    local page=ui.pages.settings
    place(page,shell.left.content,0,0,width,540)
    place(ui.warnings,nil,-3,2,28,28); place(ui.warningsLabel,nil,30,10,width-30)
    ui.warningsHelp:Hide()
    place(ui.warningDurationLabel,nil,0,48,width); ui.warningDurationLabel:SetWordWrap(true); ui.warningDurationLabel:SetHeight(30)
    place(ui.warningDuration,nil,6,84,70,24); place(ui.warningUnit,nil,86,84,math.min(130,width-86),24)
    place(ui.warningUnits,nil,86,110,math.min(130,width-86),60)
    place(ui.warningDurationHelp,nil,0,115,width)
    place(ui.warningDurationError,nil,0,136,width)
    ui.warningDurationError:SetWordWrap(true); ui.warningDurationError:SetHeight(28)
    place(ui.toastToggle,nil,-3,168,28,28); place(ui.toastLabel,nil,30,176,width-30)
    local half=math.floor((width-8)/2)
    place(ui.moveToast,nil,0,209,half,24); place(ui.resetToast,nil,half+8,209,half,24)
    place(ui.moveToastHelp,nil,0,241,width); ui.moveToastHelp:SetWordWrap(true); ui.moveToastHelp:SetHeight(35)
    for index,setting in ipairs(ui.summarySettings) do
        local y=291+(index-1)*40
        place(setting.control,nil,-3,y,28,28)
        place(setting.label,nil,30,y+7,width-30); setting.label:SetWordWrap(true); setting.label:SetHeight(30)
    end
    contentHeight(shell.left,508)
end
local function planDetails(row)
    if row and not row:IsShown() then row=nil end
    if not row then
        showInfo("Savings plan","Select a level or interval on the left to see its planned savings and expenses.")
        return
    end
    local parts={"Add " .. row.addition:GetText():gsub("^%+ ",""),"Target " .. row.target:GetText()}
    if row.planLevel then
        parts[#parts+1]="\nIncluded expenses"
        for _,item in ipairs(row.expenses and row.expenses.items or {}) do
            local rank=item.rank and item.rank~="" and " (" .. item.rank .. ")" or ""
            parts[#parts+1]=item.name .. rank .. "\n" .. (item.copper~=nil and ns.MoneyText(item.copper) or "Unknown price")
        end
        if not row.expenses or #row.expenses.items==0 then parts[#parts+1]="Nothing due at this level." end
    end
    showInfo(row.planLevel and "Level " .. row.planLevel or row.level:GetText(),table.concat(parts,"\n"))
end
local function layoutPlan(ui,shell,width,height)
    place(ui.plan,shell.left.content,0,0,width,height)
    place(ui.planHeading,nil,0,0,58)
    place(ui.planChangeHeading,nil,62,0,math.floor((width-62)/2))
    place(ui.planTargetHeading,nil,math.floor((width+62)/2),0,math.floor((width-62)/2)-14)
    for _,heading in ipairs({ui.planHeading,ui.planChangeHeading,ui.planTargetHeading}) do
        heading:SetWordWrap(false); heading:SetHeight(16)
    end
    place(ui.scroll,nil,0,27,width-18,height-30)
    ui.planContent:SetWidth(width-20)
    local rowWidth=width-20; local numberWidth=math.floor((rowWidth-62)/2)
    for _,row in pairs(ui.planRows) do
        row:SetWidth(rowWidth)
        place(row.level,nil,0,3,58)
        place(row.addition,nil,62,3,numberWidth)
        place(row.target,nil,62+numberWidth,3,numberWidth)
        place(row.expense,nil,62,19,numberWidth)
        for _,amount in ipairs({row.level,row.addition,row.target,row.expense}) do
            amount:SetWordWrap(false); amount:SetHeight(14)
        end
        row.expenseHover:Hide()
        row:EnableMouse(true)
        row:SetScript("OnMouseUp",function(_,mouse)
            if mouse=="LeftButton" then shell.planSelection=row; planDetails(row) end
        end)
    end
    planDetails(shell.planSelection)
end
local function layoutManual(page,shell,width)
    if not page.manualHeading then return end
    local manual=page.manual
    place(manual,shell.right.content,0,230,width,200); manual:Show()
    place(page.manualHeading,nil,0,0,width)
    place(page.expenseName,nil,6,23,width-12,24)
    place(page.manualLevelLabel,nil,0,60,80)
    place(page.expenseLevel,nil,100,54,math.max(40,width-106),24)
    layoutCoins(page.expenseAmount,manual,94,width)
    place(page.manualNewButton,nil,0,134,width,24)
    contentHeight(shell.right,414)
end
function ns.OnPlanningSelection(page,group)
    local ui=ns.ui
    if not ui or not ui.characterMode or ui.currentPage~=page.key then return end
    local parts={}
    if group then
        parts[#parts+1]=page.classMode and ns.db.trainingProtection==false and "Training protection is off"
            or group.included and "Included in protection" or "Excluded from protection"
        parts[#parts+1]="Left-click selects. Right-click includes or excludes."
        for _,item in ipairs(group.expenses) do
            local rank=item.rank and item.rank~="" and " (" .. item.rank .. ")" or ""
            local price=ns.db.trainingProtection==false and page.classMode and ""
                or item.copper~=nil and ns.MoneyText(item.copper) or "Unknown price"
            parts[#parts+1]="\nLevel " .. item.level .. rank .. (item.paid and " • Learned" or "")
                .. (price~="" and "\n" .. price or "")
        end
        showInfo(group.expense.name,table.concat(parts,"\n"),ns.ExpenseIcon(group.expense))
    else
        showInfo(page.classMode and "Class training" or "Additional expenses",
            "Left-click an icon to see its details. Right-click to include or exclude it."
            .. (page.classMode and "\n\nTraining choices apply across all goals." or "\n\nAdd purchases below."))
    end
    if not page.classMode then
        -- Manual input is persistent; selection must not overwrite an invalid draft.
        local shell=ui.characterUI
        local top=math.max(230,shell.info:GetHeight()+12)
        layoutManual(page,shell,shell.right.content:GetWidth())
        place(page.manual,nil,0,top,nil,nil)
        contentHeight(shell.right,top+180)
    end
end
local function layoutPlanning(ui,shell,page,width,height)
    place(page,shell.left.content,0,0,width,height)
    page.goalName:Hide(); page.summary:Hide()
    place(page.hint,nil,0,0,width,30); page.hint:SetWordWrap(true)
    page.hint:SetText("Left-click for details. Right-click to include or exclude.")
    if page.hostWidth~=width or page.hostGridHeight~=height-43 then
        ns.SetPlanningContentWidth(page,width,height-43)
    end
    place(page.scroll,nil,0,40,width-18,height-43)
    page.manual:SetShown(not page.classMode)
    ns.OnPlanningSelection(page,page.selectedGroup)
end
function ns.LayoutCharacterUI(width,height)
    local ui=ns.ui; local shell=ui and ui.characterUI
    if not shell or shell.layingOut then return end
    shell.layingOut=true
    width=width or shell.width or 720; height=height or shell.height or 540
    width=math.max(480,width); height=math.max(300,height)
    shell.width,shell.height=width,height
    ui:SetSize(width,height)
    if not ui.characterDocked then
        local screenWidth,screenHeight=UIParent:GetWidth() or 1920,UIParent:GetHeight() or 1080
        ui:SetScale(math.min(1,math.max(0.1,(screenWidth-32)/width),math.max(0.1,(screenHeight-32)/height)))
    end
    local side=ui.characterDocked and 0 or 12
    local top=ui.characterDocked and 0 or 38
    ui.title:SetShown(not ui.characterDocked); ui.header:SetShown(not ui.characterDocked)
    ui.divider:SetShown(not ui.characterDocked); ui.close:SetShown(not ui.characterDocked)
    ui.title:ClearAllPoints(); ui.title:SetPoint("TOPLEFT",16,-12); ui.title:SetWidth(width-100)
    place(ui.close,nil,width-76,8,60,24)
    local available=width-side*2
    local tabWidth=math.max(66,math.min(112,math.floor((available-70)/3)))
    local tabIndex=0
    for _,tab in ipairs(shell.tabs) do
        if tab.key~="training" or not ns.ClassTrainingRetired() then
            place(tab,nil,side+tabIndex*(tabWidth+4),top,tabWidth,25)
            tab:Show(); tabIndex=tabIndex+1
        else tab:Hide() end
    end
    place(shell.settingsButton,nil,width-side-54,top,23,23)
    place(shell.bugButton,nil,width-side-25,top,23,23)
    place(ui.summary,ui,side,top+33,available,18)
    local tipHeight=ns.db.showGoldTips==false and 0 or ns.db.tipsCollapsed and 25 or 85
    local bodyTop=top+59
    local bodyHeight=math.max(60,height-bodyTop-tipHeight-15)
    local leftWidth=math.floor(available*0.63)-12
    local rightX=side+leftWidth+23; local rightWidth=width-side-rightX
    place(shell.left,nil,side,bodyTop,leftWidth,bodyHeight)
    place(shell.right,nil,rightX,bodyTop,rightWidth,bodyHeight)
    shell.left.content:SetWidth(leftWidth-21); shell.right.content:SetWidth(rightWidth-21)
    local lw,rw=leftWidth-21,rightWidth-21
    place(shell.columnDivider,nil,side+leftWidth+10,bodyTop,1,bodyHeight)
    place(ui.error,ui,side,height-13,available,13)
    ui.error:SetWordWrap(false)
    place(ui.goldTips,ui,side,height-tipHeight-14,available,math.max(1,tipHeight))
    place(ui.tipDivider,ui,side,height-tipHeight-21,available,1)
    ui.tipDivider:SetShown(tipHeight>0)
    place(ui.goldTipHeading,nil,0,0,available-126)
    place(ui.goldTipToggle,nil,available-120,0,22,21)
    place(ui.goldTipPrevious,nil,available-94,0,22,21)
    place(ui.goldTipCount,nil,available-69,5,40)
    place(ui.goldTipNext,nil,available-24,0,22,21)
    place(shell.tipScroll,ui.goldTips,0,29,available-21,52)
    shell.tipContent:SetWidth(available-23)
    place(ui.goldTipText,shell.tipContent,0,0,available-23)
    ui.goldTipText:SetWordWrap(true)
    local tipTextHeight=math.max(52,ui.goldTipText:GetStringHeight() or 52)
    ui.goldTipText:SetHeight(tipTextHeight); shell.tipContent:SetHeight(tipTextHeight)
    shell.tipScroll:SetShown(not ns.db.tipsCollapsed)
    shell.tipScroll:SetVerticalScroll(math.min(shell.tipScroll:GetVerticalScroll() or 0,math.max(0,tipTextHeight-52)))
    ui.goldTipText:SetShown(not ns.db.tipsCollapsed)
    ui.goldTipToggle:SetText(ns.db.tipsCollapsed and "+" or "−")
    ui.goldTips:SetShown(tipHeight>0)
    local mode=ui.currentPage
    contentHeight(shell.left,bodyHeight)
    if mode=="main" then
        layoutEditor(ui,shell,rw)
        place(shell.newButton,shell.left.content,0,0,math.floor((lw-8)/2),24)
        place(shell.presetButton,shell.left.content,math.floor((lw-8)/2)+8,0,math.floor((lw-8)/2),24)
        place(shell.totals,shell.left.content,0,34,lw,(shell.totalLines or 1)*15)
        place(shell.totalsHover,shell.left.content,0,31,lw,(shell.totalLines or 1)*15+6)
        layoutGoalRows(ui,shell,lw,bodyHeight)
        place(shell.presets,shell.left.content,0,44+(shell.totalLines or 1)*15,lw,220)
        for index,row in ipairs(shell.presetRows) do
            place(row,nil,0,(index-1)*58,lw,52)
            row:GetFontString():SetWidth(lw-50)
        end
        ui.goalPicker:SetShown(not shell.presetsVisible)
        shell.presets:SetShown(shell.presetsVisible==true)
        if shell.presetsVisible then contentHeight(shell.left,math.max(bodyHeight,44+(shell.totalLines or 1)*15+#shell.presetRows*58)) end
    elseif mode=="settings" then
        layoutSettings(ui,shell,lw)
    elseif mode=="plan" then
        layoutPlan(ui,shell,lw,bodyHeight)
    elseif mode=="training" or mode=="expenses" then
        layoutPlanning(ui,shell,ui.pages[mode],lw,bodyHeight)
    elseif mode=="bugreport" then
        local page=ui.pages.bugreport
        place(page,shell.left.content,0,0,lw,240)
        place(page.intro,nil,0,0,lw,55); place(page.caption,nil,0,70,lw)
        place(page.link,nil,6,95,lw-12,24); place(page.help,nil,0,140,lw,95)
        contentHeight(shell.left,240)
    elseif mode=="planning" then
        local page=ui.pages.planning
        place(page,shell.left.content,0,0,lw,260); page.body:SetWidth(lw)
        if page.yesButton then place(page.yesButton,nil,0,170,lw,24); place(page.noButton,nil,0,205,lw,24) end
        contentHeight(shell.left,245)
    end
    shell.layingOut=nil
end
function ns.RefreshCharacterUI(status)
    local ui=ns.ui; local shell=ui and ui.characterUI
    if not shell then return end
    ui.goalOverview:Hide(); ui.back:Hide(); ui.reportBug:Hide()
    for _,item in ipairs(ui.mainNav) do item.control:Hide() end
    status=status or ns.BuildGoalStatus()
    local summaries={}
    for _,section in ipairs(status.sections) do
        if #section.rows>0 then summaries[#summaries+1]=section.label .. ": " .. ns.MoneyText(section.saved) .. " / " .. ns.MoneyText(section.target) end
    end
    shell.totalLines=math.max(1,#summaries)
    shell.totals:SetText(#summaries>0 and table.concat(summaries,"\n") or "Your gold stays in your wallet.")
    hint(shell.totalsHover,"Combined interval targets",#summaries>0 and table.concat(summaries,"\n") or "Create a goal or choose a preset.")
    shell.totals:SetWordWrap(false)
    if ns.testMoneyCopper~=nil or ns.testPlayerLevel then
        ui.summary:SetText("Test mode: changes reset on reload • " .. ns.MoneyText(ns.GetPlayerMoney()))
    elseif ns.db.trainingProtection~=false and not ns.ClassTrainingRetired() then
        ui.summary:SetText("Wallet " .. ns.MoneyText(ns.GetPlayerMoney()) .. "   •   " .. ns.TrainingCaption(status) .. ": " .. ns.MoneyText(status.trainingCosts.upcoming))
    end
    local mode=ui.currentPage
    for _,tab in ipairs(shell.tabs) do
        tab.tint:SetColorTexture(0.6,0.45,0.16,0.2)
        local selected=tab.key==mode or tab.key=="main" and (mode=="expenses" or mode=="planning")
        tab:GetFontString():SetTextColor(selected and 1 or 0.78,selected and 0.82 or 0.72,selected and 0.2 or 0.58)
        tab.tint:SetAlpha(selected and 1 or 0.2)
    end
    ns.LayoutCharacterUI()
end
function ns.ShowCharacterPage(key,replace)
    local ui=ns.ui; local shell=ui.characterUI
    if key=="goals" then shell.presetsVisible=false; key="main"
    elseif key=="presets" then shell.presetsVisible=true; key="main" end
    local page=assert(ui.pages[key],"Unknown page: " .. key)
    if key=="plan" and shell.planGoalIndex~=ui.selectedGoalIndex then
        shell.planSelection=nil; shell.planGoalIndex=ui.selectedGoalIndex
    end
    if ui.currentPage~=key then
        ns.SaveAllFields()
        if not replace and ui.currentPage then ui.history[#ui.history+1]=ui.currentPage end
        for _,other in pairs(ui.pages) do other:Hide() end
        ui.currentPage=key
        shell.left.scroll:SetVerticalScroll(0); shell.right.scroll:SetVerticalScroll(0)
    end
    place(page,key=="main" and shell.right.content or shell.left.content,0,0)
    page:Show()
    shell.newButton:SetShown(key=="main"); shell.presetButton:SetShown(key=="main")
    shell.totals:SetShown(key=="main"); shell.totalsHover:SetShown(key=="main"); ui.goalPicker:SetShown(key=="main" and not shell.presetsVisible)
    shell.presets:SetShown(key=="main" and shell.presetsVisible==true)
    shell.info:SetShown(key~="main")
    for plannerKey,planner in pairs(ns.planningFrames or {}) do
        planner.manual:SetShown(key=="expenses" and plannerKey=="expenses")
    end
    if key=="settings" then
        showInfo(shell.settingTitle or "Settings",shell.settingHelp or "Hover a setting or change it to see what it does here.")
    elseif key=="bugreport" then
        showInfo("Report a bug","Copy the link on the left, then paste it into your browser. Include what happened and how to reproduce it.","Interface\\HelpFrame\\HelpIcon-Bug")
    elseif key=="planning" then
        showInfo("Additional expenses","Keep a simple target or build a target from individual purchases. Class training protection is shared across goals.")
    end
    ui.error:SetText(""); ns.RefreshCharacterUI(); ui:Show()
end
function ns.SetupCharacterUI(ui)
    if ui.characterMode then return end
    ui.characterMode=true; ns.characterUI=ui
    local shell={tabs={},width=720,height=540}; ui.characterUI=shell
    shell.left=pane(ui); shell.right=pane(ui); shell.columnDivider=line(ui)
    shell.info=CreateFrame("Frame",nil,shell.right.content); shell.info:SetPoint("TOPLEFT"); shell.info:SetWidth(200)
    shell.infoTitle=text(shell.info,"Mountfund","GameFontNormal")
    shell.infoBody=text(shell.info,"")
    shell.infoIcon=shell.info:CreateTexture(nil,"ARTWORK"); shell.infoIcon:SetSize(48,48); shell.infoIcon:SetPoint("TOPLEFT")
    local function tab(key,caption,callback)
        local control=flatButton(ui,caption,callback); control.key=key; shell.tabs[#shell.tabs+1]=control
    end
    tab("main","Goals",function() ns.ShowPage("goals") end)
    tab("plan","Savings plan",function() ns.ShowPage("plan") end)
    tab("training","Class training",function() ns.SaveAllFields(true); ns.OpenTrainingPlanner() end)
    shell.settingsButton=iconButton(ui,"Interface\\Buttons\\UI-OptionsButton","Settings","Change warnings, notifications, training protection, and display options.",ns.OpenSettings)
    shell.bugButton=iconButton(ui,"Interface\\HelpFrame\\HelpIcon-Bug","Report a bug","Copy a link to report a problem on GitHub.",ns.OpenBugReport)
    shell.newButton=flatButton(shell.left.content,"New goal",function() shell.presetsVisible=false; ns.BeginGoalDraft() end)
    shell.presetButton=flatButton(shell.left.content,"Presets",function() shell.presetsVisible=not shell.presetsVisible; ns.ShowPage("main") end)
    shell.totals=text(shell.left.content,"","GameFontNormalSmall")
    shell.totalsHover=CreateFrame("Frame",nil,shell.left.content); shell.totalsHover:EnableMouse(true)
    shell.presets=CreateFrame("Frame",nil,shell.left.content); shell.presetRows={}
    local choices={ns.FindPreset("mount-first"),ns.FindPreset("mount-epic"),{name="Custom goal",icon="Interface\\Icons\\INV_Misc_Coin_01"}}
    for index,preset in ipairs(choices) do
        local choice=preset
        local row=flatButton(shell.presets,choice.name,function() ns.BeginGoalDraft(choice.id) end)
        row.icon=row:CreateTexture(nil,"ARTWORK"); row.icon:SetSize(36,36); row.icon:SetPoint("LEFT",4,0); row.icon:SetTexture(choice.icon)
        row:GetFontString():ClearAllPoints(); row:GetFontString():SetPoint("LEFT",48,0); row:GetFontString():SetJustifyH("LEFT"); row:GetFontString():SetWordWrap(true)
        shell.presetRows[index]=row
    end
    shell.createButton=UI.Button(ui.editorFields,"Create goal",0,0,180,function()
        if ns.CommitGoalDraft() then shell.presetsVisible=false; ns.RefreshCharacterUI() end
    end)
    shell.cancelDraft=flatButton(ui.editorFields,"Cancel new goal",ns.CancelGoalDraft)
    ui.goalPicker.instructions=ui.goalPicker.instructions or text(ui.goalPicker,"")
    settingsHelp(ui.warnings,"Excluded-ability warnings","Warn before buying an ability you greyed out in Class training. Other purchases do not trigger this warning. Turn it off here to stop these prompts.",ui.warningsLabel)
    settingsHelp(ui.toastToggle,"Goal progress notifications","Show progress and confirmed completion notifications. Drag the preview with Move toast to choose where they appear.",ui.toastLabel)
    settingsHelp(ui.warningUnit,"Warning silence","After Spend anyway, silence excluded-ability warnings for 30 seconds to 60 minutes. Changing units preserves the duration.")
    ui.warningDuration:HookScript("OnEnter",function() ns.ShowSettingHelp("Warning silence","Choose 30 seconds to 60 minutes. The default is 2 minutes. This applies to excluded-ability warnings after Spend anyway.") end)
    for _,setting in ipairs(ui.summarySettings) do settingsHelp(setting.control,setting.text,setting.help,setting.label) end
    shell.tipScroll=CreateFrame("ScrollFrame",nil,ui.goldTips,"UIPanelScrollFrameTemplate")
    shell.tipContent=CreateFrame("Frame",nil,shell.tipScroll); shell.tipContent:SetSize(100,52)
    shell.tipScroll:SetScrollChild(shell.tipContent)
    ui.goldTips:SetParent(ui); ui.tipDivider:SetParent(ui); ui.summary:SetParent(ui)
    ui.summary:SetWordWrap(false)
    ui:SetClampedToScreen(true)
    ui:SetScript("OnDragStart",function(self) if not self.characterDocked then self:StartMoving() end end)
    if ns.AttachCharacterPanel then ns.AttachCharacterPanel(ui) end
    ns.LayoutCharacterUI()
end
