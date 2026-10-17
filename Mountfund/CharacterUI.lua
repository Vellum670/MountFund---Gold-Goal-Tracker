-- Presentation adapter: reuse the validated editor and planners inside the character pane.
local _, ns = ...
local UI = ns.UI
local headerButtonSize, headerButtonGap, headerGlyphSize = 26, 6, 16
local function place(control, parent, x, y, width, height)
    if parent then control:SetParent(parent) end
    control:ClearAllPoints(); control:SetPoint("TOPLEFT", x, -y)
    if width then control:SetWidth(math.max(1, width)) end
    if height then control:SetHeight(math.max(1, height)) end
end
local function text(parent, caption, font)
    return UI.Label(parent, caption, 0, 0, 100, font or "GameFontHighlightSmall")
end
local function paneDivider(parent)
    local region=parent:CreateTexture(nil,"BORDER")
    region:SetAtlas("common-framedivider")
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
    control:GetFontString():SetJustifyV("MIDDLE")
    control:SetText(caption)
    control:SetScript("OnClick",callback)
    ns.StyleButton(control)
    return control
end
local function buttonIcon(control, texture)
    -- Native button states can change their texture layers. Keep the image in
    -- a child frame above all of that button's chrome, with input passing through.
    local foreground=CreateFrame("Frame",nil,control)
    foreground:SetAllPoints(control); foreground:SetFrameLevel(control:GetFrameLevel()+1)
    foreground:EnableMouse(false); foreground:EnableKeyboard(false)
    local icon=foreground:CreateTexture(nil,"ARTWORK")
    icon:SetTexture(texture)
    return icon
end
local function iconButton(parent, texture, caption, body, callback, light)
    local control=CreateFrame("Button",nil,parent)
    control:SetSize(24,24)
    control:SetScript("OnClick",callback)
    control.icon=buttonIcon(control,texture)
    control.icon:SetPoint("TOPLEFT",control,"TOPLEFT",4,-4)
    control.icon:SetPoint("BOTTOMRIGHT",control,"BOTTOMRIGHT",-4,4)
    control.icon:SetDesaturated(true); control.icon:SetVertexColor(0.95,0.78,0.44,1)
    hint(control,caption,body)
    ns.StyleIconButton(control,light)
    return control
end
local function headerIconButton(parent, texture, caption, body, callback, crop)
    local control=iconButton(parent,texture,caption,body,callback,true)
    control.icon:SetVertexColor(1,0.94,0.76,1)
    control:SetSize(headerButtonSize,headerButtonSize)
    control.icon:ClearAllPoints(); control.icon:SetPoint("CENTER",control,"CENTER")
    control.icon:SetSize(headerGlyphSize,headerGlyphSize)
    -- These native files have different padding; normalize the glyphs inside
    -- shared chrome instead of stretching each file across the whole button.
    control.icon:SetTexCoord(crop,1-crop,crop,1-crop)
    return control
end
local function pane(parent)
    local result=CreateFrame("Frame",nil,parent)
    result.scroll=CreateFrame("ScrollFrame",nil,result,"ScrollFrameTemplate")
    result.content=CreateFrame("Frame",nil,result.scroll)
    result.content:SetSize(100,1); result.scroll:SetScrollChild(result.content)
    ns.SetupScrollAffordance(result.scroll)
    result:EnableMouseWheel(true)
    result:SetScript("OnMouseWheel",function(_,delta)
        local handler=result.scroll:GetScript("OnMouseWheel")
        if handler then handler(result.scroll,delta) end
    end)
    return result
end
local function contentHeight(paneFrame,height)
    paneFrame.content:SetHeight(math.max(1,height))
    -- The hint only needs a footer when content actually overflows. Reserving
    -- it unconditionally can make an otherwise fitting list scroll.
    local available=paneFrame:GetHeight()
    local viewport=height<=available+1 and available or math.max(20,available-16)
    paneFrame.scroll:SetHeight(viewport)
    ns.RefreshScrollRange(paneFrame.scroll)
end
local function wrap(region,width,minimum)
    region:SetWidth(math.max(1,width)); region:SetWordWrap(true); region:SetHeight(0)
    if region.SetNonSpaceWrap then region:SetNonSpaceWrap(true) end
    if region.SetMaxLines then region:SetMaxLines(0) end
    region:SetJustifyV("TOP")
    local height=math.max(minimum or 14,math.ceil(region:GetStringHeight() or 14)+2)
    region:SetHeight(height)
    return height
end
local function layoutButton(control,parent,x,y,width,minimum)
    place(control,parent,x,y,width)
    local caption=control:GetFontString()
    caption:ClearAllPoints(); caption:SetPoint("CENTER",control,"CENTER")
    caption:SetJustifyH("CENTER")
    local height=math.max(minimum or 24,wrap(caption,width-24,12)+10)
    caption:SetJustifyV("MIDDLE")
    control:SetHeight(height)
    return height
end
local function buttonPair(first,second,parent,y,width)
    local half=math.floor((width-8)/2)
    local height=math.max(layoutButton(first,parent,0,y,half),layoutButton(second,parent,half+8,y,width-half-8))
    first:SetHeight(height); second:SetHeight(height)
    return height
end
local function layoutInfo(shell,width)
    local icon=shell.infoIcon:IsShown()
    local centered=ns.ui.currentPage=="training"
    shell.infoIcon:ClearAllPoints()
    shell.infoIcon:SetPoint(centered and "TOP" or "TOPLEFT",shell.info,centered and "TOP" or "TOPLEFT",0,0)
    shell.infoTitle:SetJustifyH(centered and "CENTER" or "LEFT")
    shell.infoBody:SetJustifyH(centered and "CENTER" or "LEFT")
    place(shell.infoTitle,nil,0,icon and 58 or 0,width)
    local titleHeight=wrap(shell.infoTitle,width,18)
    local top=(icon and 58 or 0)+titleHeight+14
    place(shell.infoBody,nil,0,top,width)
    local height=top+wrap(shell.infoBody,width,20)+20
    shell.info:SetWidth(width); shell.info:SetHeight(height)
    contentHeight(shell.right,height)
end
local function showInfo(title, body, icon)
    local ui=ns.ui; local shell=ui and ui.characterUI
    if not shell then return end
    shell.info:Show(); ui.pages.main:Hide()
    if shell.infoTitle:GetText()~=(title or "MountFund") then shell.right.scroll:SetVerticalScroll(0) end
    shell.infoTitle:SetText(title or "MountFund")
    shell.infoBody:SetText(body or "")
    shell.infoIcon:SetShown(icon~=nil)
    if icon then shell.infoIcon:SetTexture(icon) end
    layoutInfo(shell,shell.right.content:GetWidth())
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
local function layoutEditor(ui,shell,width,editorTop)
    local main=ui.pages.main
    place(main,shell.left.content,0,0,width,640)
    place(ui.editor,main,0,editorTop,width,640)
    place(ui.goalIcon,ui.editor,0,0,36,36)
    place(ui.selection,ui.editor,48,0,width-48)
    local titleHeight=math.max(36,wrap(ui.selection,width-48,18))
    place(ui.progress,ui.editor,0,titleHeight+8,width)
    local progressHeight=wrap(ui.progress,width,16)
    local goalTop=titleHeight+progressHeight+25
    place(ui.levelGoal,ui.editor,0,goalTop,width)
    place(ui.levelGoalHeading,ui.levelGoal,0,0,width)
    local headingHeight=wrap(ui.levelGoalHeading,width,15)
    place(ui.levelGoalAmount,ui.levelGoal,0,headingHeight+4,width)
    local amountHeight=wrap(ui.levelGoalAmount,width,15)
    place(ui.levelGoalDetail,ui.levelGoal,0,headingHeight+amountHeight+8,width)
    local detailHeight=wrap(ui.levelGoalDetail,width,14)
    local goalHeight=headingHeight+amountHeight+detailHeight+8
    ui.levelGoal:SetHeight(goalHeight)
    local fieldsTop=goalTop+goalHeight+16
    place(ui.editorFields,ui.editor,0,fieldsTop,width,314)
    place(ui.nameLabel,nil,0,0,width)
    local y=wrap(ui.nameLabel,width,14)+6
    place(ui.name,nil,6,y,width-12,24)
    y=y+36
    place(ui.amountLabel,nil,0,y,width)
    y=y+wrap(ui.amountLabel,width,14)+6
    layoutCoins(ui.amount,ui.editorFields,y,width)
    y=y+38
    y=y+layoutButton(ui.basis,nil,0,y,width)+8
    place(ui.level,nil,6,y,width-12,24)
    y=y+35
    place(ui.active,nil,0,y,26,26)
    place(ui.trackLabel,nil,32,y+6,width-32)
    y=y+math.max(28,wrap(ui.trackLabel,width-32,14)+6)+10
    y=y+layoutButton(ui.curve,nil,0,y,width)+8
    y=y+layoutButton(ui.planning,nil,0,y,width)+20
    ui.savingsPlan:Hide(); ui.training:Hide()
    local buttonsHeight=math.max(buttonPair(ui.complete,ui.delete,nil,y,width),
        buttonPair(shell.createButton,shell.cancelDraft,ui.editorFields,y,width))
    shell.createButton:SetShown(ui.creatingGoal==true)
    shell.cancelDraft:SetShown(ui.creatingGoal==true)
    ui.complete:SetShown(not ui.creatingGoal); ui.delete:SetShown(not ui.creatingGoal)
    ui.editorFields:SetHeight(y+buttonsHeight+12)
    local height=editorTop+fieldsTop+ui.editorFields:GetHeight()
    main:SetHeight(height); ui.editor:SetHeight(height-editorTop)
    contentHeight(shell.left,height)
end

function ns.LayoutCharacterGoalList()
    local ui=ns.ui; local shell=ui and ui.characterUI
    if not shell or shell.layingOutGoals then return end
    shell.layingOutGoals=true
    local picker=ui.goalPicker; local width=shell.right.content:GetWidth()
    place(picker,shell.right.content,0,0,width,1)
    place(shell.goalsHeading,picker,0,0,width)
    local headingHeight=wrap(shell.goalsHeading,width,18)
    local totalsTop=headingHeight+9
    place(shell.totals,picker,0,totalsTop,width)
    local totalHeight=wrap(shell.totals,width,16)
    place(shell.totalsHover,picker,0,totalsTop-2,width,totalHeight+4)
    place(picker.instructions,picker,0,totalsTop+totalHeight+7,width)
    picker.instructions:SetText("Drag the dots to prioritize your goals.")
    local hintHeight=wrap(picker.instructions,width,28)
    local listTop=totalsTop+totalHeight+hintHeight+16
    place(picker.content,picker,0,listTop,width,1)
    picker.dropLine:SetWidth(width)
    local activeHeight,completedHeight=0,0
    for slot,row in ipairs(picker.rows or {}) do
        if slot<=picker.visibleRows then
            local goal=ns.GetGoals()[row.goalIndex]
            if goal then
                local completed=goal.completedAt~=nil
                local parent=completed and picker.completedContent or picker.content
                local y=completed and completedHeight or activeHeight
                if not row.characterStyled then
                    row:SetHighlightTexture("Interface\\Buttons\\WHITE8X8")
                    -- The handle and goal share one visual footprint while
                    -- keeping their separate drag and edit hit areas.
                    for _,control in ipairs({row,row.handle}) do
                        local highlight=control:GetHighlightTexture()
                        highlight:SetTexture("Interface\\Buttons\\WHITE8X8")
                        highlight:SetBlendMode("BLEND")
                        highlight:SetVertexColor(1,0.82,0.2,0.1)
                        highlight:ClearAllPoints()
                        highlight:SetPoint("TOPLEFT",row.handle,"TOPLEFT")
                        highlight:SetPoint("BOTTOMRIGHT",row,"BOTTOMRIGHT")
                    end
                    row.progressTrack=row:CreateTexture(nil,"BACKGROUND",nil,-1)
                    row.progressTrack:SetHeight(3)
                    row.progressTrack:SetColorTexture(0.38,0.29,0.14,0.65)
                    row.fill=row:CreateTexture(nil,"BACKGROUND"); row.fill:SetHeight(3)
                    row.icon=row:CreateTexture(nil,"ARTWORK")
                    row.detail=text(row,"","GameFontHighlightSmall")
                    row.characterStyled=true
                end
                row.deleteGoal:Hide()
                place(row,parent,22,y,width-22,50)
                place(row.icon,nil,0,2,28,28); row.icon:SetTexture(ns.GoalIcon(goal))
                -- A standalone label keeps button-state updates from centering
                -- the name or restoring inherited action-button artwork.
                local caption=row.caption
                caption:SetText(goal.name)
                place(caption,nil,35,0,width-61)
                local titleHeight=wrap(caption,width-61,16)
                local deadline=goal.goalType=="date" and date("%m/%d",goal.deadlineTime)
                    or goal.goalType=="played" and string.format("%.1fh",goal.durationSeconds/3600) or "Level " .. goal.targetLevel
                row.detail:SetText((goal.completedAt and "Completed" or goal.active==false and "Not tracked • " .. deadline or deadline) .. "\n"
                    .. ns.MoneyText(completed and (goal.completedCopper or goal.targetCopper) or (goal.savedCopper or 0)) .. " / " .. ns.MoneyText(goal.targetCopper))
                place(row.detail,nil,0,math.max(34,titleHeight+6),width-22)
                local detailHeight=wrap(row.detail,width-22,28)
                local height=math.max(34,titleHeight+6)+detailHeight+12
                row:SetHeight(height); row.layoutTop=y
                place(row.handle,parent,0,y,18,height); row.handle:SetShown(not completed)
                local progress=completed and 1 or goal.targetCopper>0
                    and math.max(0,math.min(1,(goal.savedCopper or 0)/goal.targetCopper)) or 0
                row.progressTrack:ClearAllPoints(); row.progressTrack:SetPoint("BOTTOMLEFT",0,0)
                row.progressTrack:SetWidth(width-22)
                row.fill:ClearAllPoints(); row.fill:SetPoint("BOTTOMLEFT",row.progressTrack,"BOTTOMLEFT")
                row.fill:SetWidth(math.max(1,(width-22)*progress))
                row.fill:SetShown(progress>0)
                row.fill:SetColorTexture(0.7,0.52,0.24,0.75)
                if row.goalIndex==ui.selectedGoalIndex and not ui.creatingGoal then row:LockHighlight() else row:UnlockHighlight() end
                if completed then completedHeight=y+height+8 else activeHeight=y+height+8 end
            end
        end
    end
    picker.empty:SetText(picker.activeRows==0 and "No active goals. Choose New goal or Presets." or "")
    place(picker.empty,picker.content,0,0,width)
    local emptyHeight=wrap(picker.empty,width,42)
    if picker.activeRows==0 then activeHeight=emptyHeight+10 end
    picker.content:SetHeight(math.max(1,activeHeight))
    local historyTop=listTop+activeHeight+8
    local historyHeight=layoutButton(picker.history,picker,0,historyTop,width)
    -- Collapsed history stays at the pane bottom when priorities fit. Expanded
    -- history follows the active rows so its entries stay beneath the heading.
    if picker.completedRows==0 then historyTop=math.max(historyTop,shell.right:GetHeight()-historyHeight-12) end
    place(picker.history,picker,0,historyTop,width,historyHeight)
    place(picker.completedContent,picker,0,historyTop+historyHeight+8,width,math.max(1,completedHeight))
    picker.completedContent:SetShown(picker.completedRows>0)
    picker:SetHeight(historyTop+historyHeight+(picker.completedRows>0 and completedHeight+8 or 0)+12)
    if ui.currentPage=="main" or ui.currentPage=="presets" then contentHeight(shell.right,picker:GetHeight()) end
    shell.layingOutGoals=nil
end
local function layoutSettings(ui,shell,width)
    local page=ui.pages.settings
    place(page,shell.left.content,0,0,width)
    place(ui.warnings,nil,0,2,26,26); place(ui.warningsLabel,nil,32,8,width-32)
    local y=math.max(30,wrap(ui.warningsLabel,width-32,14)+8)+18
    ui.warningsHelp:Hide()
    place(ui.warningDurationLabel,nil,0,y,width)
    y=y+wrap(ui.warningDurationLabel,width,14)+10
    place(ui.warningDuration,nil,6,y,70,24)
    local selectorWidth=math.min(130,width-86)
    local selectorHeight=layoutButton(ui.warningUnit,nil,86,y,selectorWidth)
    local caption=ui.warningUnit:GetFontString()
    wrap(caption,selectorWidth-32,12)
    caption:ClearAllPoints(); caption:SetPoint("LEFT",ui.warningUnit,"LEFT",8,0)
    caption:SetJustifyH("LEFT"); caption:SetJustifyV("MIDDLE")
    place(ui.warningUnits,nil,86,y+selectorHeight+2,selectorWidth,60)
    for _,option in ipairs({ui.warningUnits:GetChildren()}) do
        if option.GetFontString and option:GetFontString() then
            local _,_,_,_,optionY=option:GetPoint()
            layoutButton(option,nil,4,-(optionY or 0),selectorWidth-8,25)
        end
    end
    y=y+math.max(24,selectorHeight)+8
    place(ui.warningDurationHelp,nil,0,y,width)
    y=y+wrap(ui.warningDurationHelp,width,14)+6
    place(ui.warningDurationError,nil,0,y,width)
    y=y+wrap(ui.warningDurationError,width,14)+16
    place(ui.toastToggle,nil,0,y,26,26); place(ui.toastLabel,nil,32,y+6,width-32)
    y=y+math.max(28,wrap(ui.toastLabel,width-32,14)+6)+14
    y=y+buttonPair(ui.moveToast,ui.resetToast,nil,y,width)+8
    place(ui.moveToastHelp,nil,0,y,width)
    y=y+wrap(ui.moveToastHelp,width,28)+18
    for _,setting in ipairs(ui.summarySettings) do
        place(setting.control,nil,0,y,26,26)
        place(setting.label,nil,32,y+6,width-32)
        y=y+math.max(28,wrap(setting.label,width-32,14)+6)+12
    end
    place(ui.settingsVersion,nil,0,y+8,width)
    y=y+8+wrap(ui.settingsVersion,width,14)+12
    ui.settingsVersion:SetJustifyV("MIDDLE")
    page:SetHeight(y+4); contentHeight(shell.left,y+4)
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
    local rowWidth=width
    local levelWidth=42
    local numberWidth=math.floor((rowWidth-levelWidth-16)/2)
    local changeX=levelWidth+8
    local targetX=changeX+numberWidth+8
    place(ui.planHeading,nil,0,0,levelWidth)
    place(ui.planChangeHeading,nil,changeX,0,numberWidth)
    place(ui.planTargetHeading,nil,targetX,0,numberWidth)
    local headingHeight=math.max(wrap(ui.planHeading,levelWidth,16),
        wrap(ui.planChangeHeading,numberWidth,16),wrap(ui.planTargetHeading,numberWidth,16))
    local gridTop=headingHeight+10
    ns.SetScrollViewport(ui.scroll,ui.plan,0,gridTop,rowWidth,height-gridTop)
    ui.planContent:SetWidth(rowWidth)
    local steps={}
    for step,row in pairs(ui.planRows) do
        if row:IsShown() then steps[#steps+1]=step end
    end
    table.sort(steps)
    local y=0
    for _,step in ipairs(steps) do
        local row=ui.planRows[step]
        place(row,ui.planContent,0,y,rowWidth)
        place(row.level,nil,0,3,levelWidth)
        place(row.addition,nil,changeX,3,numberWidth)
        place(row.target,nil,targetX,3,numberWidth)
        local amountHeight=math.max(wrap(row.level,levelWidth,14),
            wrap(row.addition,numberWidth,14),wrap(row.target,numberWidth,14))
        place(row.expense,nil,changeX,amountHeight+7,numberWidth)
        local expenseHeight=row.expense:IsShown() and wrap(row.expense,numberWidth,14)+4 or 0
        local rowHeight=amountHeight+expenseHeight+12
        row:SetHeight(rowHeight); row.layoutTop=y; y=y+rowHeight
        row.expenseHover:Hide()
        row:EnableMouse(true)
        row:SetScript("OnMouseUp",function(_,mouse)
            if mouse=="LeftButton" then shell.planSelection=row; planDetails(row) end
        end)
    end
    ui.planContent:SetHeight(math.max(1,y))
    ns.RefreshScrollRange(ui.scroll)
    planDetails(shell.planSelection)
end
local function layoutManual(page,shell,width)
    if not page.manualHeading then return 0 end
    local manual=page.manual
    place(manual,shell.right.content,0,0,width); manual:Show()
    place(page.manualHeading,nil,0,0,width)
    local y=wrap(page.manualHeading,width,16)+10
    place(page.expenseName,nil,6,y,width-12,24)
    y=y+38
    place(page.manualLevelLabel,nil,0,y,width)
    y=y+wrap(page.manualLevelLabel,width,14)+6
    place(page.expenseLevel,nil,6,y,width-12,24)
    y=y+38
    layoutCoins(page.expenseAmount,manual,y,width)
    y=y+40
    y=y+layoutButton(page.manualNewButton,nil,0,y,width)+10
    manual:SetHeight(y)
    return y
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
        local top=shell.info:GetHeight()+12
        local manualHeight=layoutManual(page,shell,shell.right.content:GetWidth())
        place(page.manual,nil,0,top,nil,nil)
        contentHeight(shell.right,top+manualHeight)
    end
end
local function layoutPlanning(ui,shell,page,width,height)
    place(page,shell.left.content,0,0,width,height)
    page.goalName:Hide(); page.summary:Hide()
    local hintTop=0
    if not page.classMode then
        if not page.backToGoal then page.backToGoal=flatButton(page,"Back to goal",ns.ShowMainPage) end
        hintTop=layoutButton(page.backToGoal,nil,0,0,width)+12
    end
    place(page.hint,nil,0,hintTop,width)
    page.hint:SetText("Left-click for details. Right-click to include or exclude.")
    local gridTop=hintTop+wrap(page.hint,width,16)+10
    local gridHeight=math.max(42,height-gridTop-20)
    page.hint:SetTextColor(0.8,0.75,0.65)
    if page.hostWidth~=width or page.hostGridHeight~=gridHeight then
        ns.SetPlanningContentWidth(page,width,gridHeight)
    end
    ns.SetScrollViewport(page.scroll,page,0,gridTop,width-22,gridHeight+16)
    page.content:SetWidth(width-24)
    place(page.empty,page.content,4,4,width-32)
    wrap(page.empty,width-32,16)
    ns.RefreshScrollRange(page.scroll)
    page.manual:SetShown(not page.classMode)
    ns.OnPlanningSelection(page,page.selectedGroup)
end
function ns.LayoutCharacterUI(width,height)
    local ui=ns.ui; local shell=ui and ui.characterUI
    if not shell or shell.layingOut then return end
    shell.layingOut=true
    width=math.max(480,width or shell.width or 720); height=math.max(300,height or shell.height or 540)
    shell.width,shell.height=width,height; ui:SetSize(width,height)
    if not ui.characterDocked then
        ui:SetScale(math.min(1,math.max(0.1,((UIParent:GetWidth() or 1920)-32)/width),math.max(0.1,((UIParent:GetHeight() or 1080)-32)/height)))
    end
    local side=ui.characterDocked and 8 or 16
    local top=ui.characterDocked and 4 or 38
    local frameScale=ui.characterDocked and ui:GetScale() or 1
    ui.title:SetShown(not ui.characterDocked); ui.header:SetShown(not ui.characterDocked)
    ui.divider:Show(); ui.close:SetShown(not ui.characterDocked)
    place(ui.title,nil,16,12,width-100); place(ui.close,nil,width-76,8,60,24)
    local available=width-side*2
    local split=ui.characterDocked and width*(ui.characterSplitRatio or (398/631)) or side+math.floor(available*0.63)+1
    local leftWidth=split-side-10
    local rightX=split+12; local rightWidth=width-side-rightX
    local tabLeft=ui.characterDocked and math.max(side,ui.characterPortraitInsetX or 56) or side
    local tabCount=ns.ClassTrainingRetired() and 2 or 3
    local tabGap=8
    local tabRight=split-24
    local tabsBelowPortrait=false
    -- Compact labels can wrap above the native baseline. Move navigation below
    -- the portrait only when a skin leaves too little width for readable tabs.
    if ui.characterDocked and tabRight-tabLeft<tabCount*40+(tabCount-1)*tabGap then
        top=math.max(top,(ui.characterPortraitInsetY or 44)+8); tabLeft=side; tabsBelowPortrait=true
    end
    local tabWidths,tabMinimums,totalWidth,minimumWidth={},{},0,0
    for _,tab in ipairs(shell.tabs) do
        if tab.key~="training" or not ns.ClassTrainingRetired() then
            local caption=tab:GetFontString()
            caption:SetWordWrap(false); caption:SetWidth(0)
            local chrome=tab.mountfundChrome
            local minimum=math.max(40,chrome.tabLeft:GetWidth()+chrome.tabRight:GetWidth()-6)
            local naturalWidth=math.max(minimum,math.ceil(caption:GetStringWidth())+24)
            tabMinimums[tab]=minimum; minimumWidth=minimumWidth+minimum
            tabWidths[tab]=naturalWidth; totalWidth=totalWidth+naturalWidth
            tab:Show()
        else tab:Hide() end
    end
    if ui.characterDocked and not tabsBelowPortrait and tabRight-tabLeft<minimumWidth+(tabCount-1)*tabGap then
        top=math.max(top,(ui.characterPortraitInsetY or 44)+8); tabLeft=side; tabsBelowPortrait=true
    end
    -- Size to the captions, reserving room after the last cap. Only compact
    -- layouts reduce widths and wrap labels; spare space never stretches tabs.
    local widthBudget=math.max(minimumWidth,tabRight-tabLeft-(tabCount-1)*tabGap)
    local reduction=totalWidth>widthBudget and (widthBudget-minimumWidth)/(totalWidth-minimumWidth) or 1
    local tabX,tabHeight=tabLeft,headerButtonSize
    for _,tab in ipairs(shell.tabs) do
        if tab:IsShown() then
            local tabWidth=tabMinimums[tab]+math.floor((tabWidths[tab]-tabMinimums[tab])*reduction)
            tabWidths[tab]=tabWidth
            tabHeight=math.max(tabHeight,layoutButton(tab,nil,tabX,top,tabWidth,25))
            tabX=tabX+tabWidth+tabGap
        end
    end
    local tabBaseline=top+tabHeight
    if ui.characterDocked then
        local nativeBaseline=ui.characterTabBaseline or 30.5/frameScale
        -- Keep oversized portrait skins clear when they force navigation down.
        tabBaseline=tabsBelowPortrait and math.max(nativeBaseline,tabBaseline) or nativeBaseline
        top=tabBaseline-tabHeight
    end
    tabX=tabLeft
    for _,tab in ipairs(shell.tabs) do
        if tab:IsShown() then
            place(tab,nil,tabX,top,tabWidths[tab],tabHeight)
            local caption=tab:GetFontString()
            caption:ClearAllPoints(); caption:SetPoint("CENTER",tab,"CENTER",0,-2)
            caption:SetJustifyV("MIDDLE")
            tabX=tabX+tabWidths[tab]+tabGap
        end
    end
    shell.settingsButton:SetSize(headerButtonSize,headerButtonSize)
    shell.bugButton:SetSize(headerButtonSize,headerButtonSize)
    shell.settingsButton:ClearAllPoints(); shell.bugButton:ClearAllPoints()
    local close=ui.close
    if ui.characterDocked then close=ui.characterCloseButton end
    if close then
        shell.bugButton:SetPoint("RIGHT",close,"LEFT",-headerButtonGap/frameScale,0)
    else
        -- Match the native close-button slot while its frame is unavailable.
        shell.bugButton:SetPoint("TOPRIGHT",ui,"TOPRIGHT",-26/frameScale,32/frameScale)
    end
    shell.settingsButton:SetPoint("RIGHT",shell.bugButton,"LEFT",-headerButtonGap/frameScale,0)
    local summaryTop=top+tabHeight+9
    if ui.characterDocked then summaryTop=math.max(summaryTop,(ui.characterPortraitInsetY or 44)+8) end
    if ui.characterDocked then
        local frameInset=(ui.characterFrameSideInset or 8)-4/frameScale
        local lineHeight=ns.StyleHeaderDivider(ui.divider,frameScale)
        place(ui.divider,nil,-frameInset,tabBaseline-lineHeight/2,split+frameInset,lineHeight)
    else
        ui.divider:SetTexture("Interface\\Buttons\\WHITE8X8")
        ui.divider:SetVertexColor(0.65,0.48,0.22,0.65)
        place(ui.divider,nil,8,44,split-8,1)
    end
    place(ui.summary,ui,side,summaryTop,leftWidth)
    -- Keep the legacy summary as a layout anchor; separate columns prevent
    -- currency icons and changing training labels from crowding one sentence.
    ui.summary:Hide()
    local summaryHeight=0
    local summaryWidth=leftWidth-28
    local labelWidth=math.floor(summaryWidth*.48)
    for _,row in ipairs(shell.budgetRows) do
        if row.shown~=false then
            place(row.label,ui,side+6,summaryTop+summaryHeight,labelWidth)
            place(row.value,ui,side+6+labelWidth+8,summaryTop+summaryHeight,summaryWidth-labelWidth-8)
            local rowHeight=math.max(wrap(row.label,labelWidth,14),wrap(row.value,summaryWidth-labelWidth-8,14))
            row.label:Show(); row.value:Show()
            summaryHeight=summaryHeight+rowHeight+2
        else row.label:Hide(); row.value:Hide() end
    end
    shell.budgetPreview:SetShown(shell.budgetPreviewShown==true)
    if shell.budgetPreviewShown then
        place(shell.budgetPreview,ui,side+6,summaryTop+summaryHeight,summaryWidth)
        summaryHeight=summaryHeight+wrap(shell.budgetPreview,summaryWidth,14)+2
    end
    ui.summary:SetHeight(summaryHeight)
    place(shell.budgetHover,ui,side+6,summaryTop,summaryWidth,summaryHeight)
    local bodyTop=summaryTop+summaryHeight+14
    -- Keep border artwork and glyph overhang inside the scroll viewport, with
    -- a separate gutter for the native scrollbar on each column's right edge.
    local inset=6
    local lw=leftWidth-inset-22
    local trainingHelp=ui.currentPage=="training"
    -- Balanced text margins keep both centered and left-aligned context on the
    -- pane's axis. The outer column margin also leaves room for the scrollbar.
    local rightInset=14
    local rw=rightWidth-rightInset*2
    local tipsShown=not trainingHelp and ns.db.showGoldTips~=false and ui.goldTipBracket~=nil
    local footerShown=trainingHelp or tipsShown
    local tipHeight=0
    if trainingHelp then
        place(shell.trainingHelpHeading,nil,0,0,leftWidth)
        local headingHeight=wrap(shell.trainingHelpHeading,leftWidth,18)
        place(shell.trainingHelpText,nil,0,headingHeight+8,leftWidth)
        tipHeight=headingHeight+12+wrap(shell.trainingHelpText,leftWidth,40)
    elseif tipsShown then
        place(ui.goldTipHeading,nil,0,0,leftWidth-118)
        local headingHeight=math.max(25,wrap(ui.goldTipHeading,leftWidth-118,18)+4)
        place(ui.goldTipToggle,nil,leftWidth-112,0,22,22)
        place(ui.goldTipPrevious,nil,leftWidth-86,0,22,22)
        place(ui.goldTipCount,nil,leftWidth-61,5,32,15)
        place(ui.goldTipNext,nil,leftWidth-24,0,22,22)
        place(ui.goldTipText,ui.goldTips,0,headingHeight+8,leftWidth)
        tipHeight=ns.db.tipsCollapsed and headingHeight or headingHeight+12+wrap(ui.goldTipText,leftWidth,40)
    end
    local leftHeight=math.max(50,height-bodyTop-tipHeight-(footerShown and 28 or 14))
    -- Only the left pane reserves space for tabs, wallet, and tips.
    local rightTop=ui.characterDocked and 4 or 38
    local rightHeight=math.max(50,height-rightTop-14)
    place(shell.left,nil,side,bodyTop,leftWidth,leftHeight)
    place(shell.right,nil,rightX,rightTop,rightWidth,rightHeight)
    -- Savings plan scrolls inside its table. Let its outer viewport include
    -- the table's scrollbar gutter instead of reserving a second one.
    local leftViewportWidth=ui.currentPage=="plan" and leftWidth-inset or lw
    ns.SetScrollViewport(shell.left.scroll,shell.left,inset,0,leftViewportWidth,leftHeight)
    ns.SetScrollViewport(shell.right.scroll,shell.right,rightInset,0,rw,rightHeight)
    shell.left.content:SetWidth(leftViewportWidth); shell.right.content:SetWidth(rw)
    local dividerTop=ui.characterDocked and -(ui.characterFrameHeaderOffset or 0) or 38
    local dividerBottom=height+(ui.characterDocked and (ui.characterFrameFooterOffset or 0) or 0)
    place(shell.columnDivider,nil,split-6/frameScale,dividerTop,11/frameScale,dividerBottom-dividerTop)
    place(ui.error,ui,side,height-12,available,12); ui.error:SetWordWrap(false)
    place(ui.goldTips,ui,side,height-tipHeight-14,leftWidth,math.max(1,tipHeight))
    place(shell.trainingHelp,ui,side,height-tipHeight-14,leftWidth,math.max(1,tipHeight))
    place(ui.tipDivider,ui,side,height-tipHeight-22,leftWidth,1)
    ui.goldTips:SetShown(tipsShown); ui.tipDivider:SetShown(footerShown)
    shell.trainingHelp:SetShown(trainingHelp)
    ui.goldTipText:SetShown(tipsShown and not ns.db.tipsCollapsed)
    ui.goldTipToggle:SetText(ns.db.tipsCollapsed and "+" or "−")
    local mode=ui.currentPage
    -- Keep each pane's content height until its page has been measured. A
    -- temporary viewport-sized child clamps a scrolled editor or list to zero.
    if mode~="main" and mode~="presets" then layoutInfo(shell,rw) end
    shell.toolbarDivider:SetShown(mode=="main" or mode=="presets")
    if mode=="main" or mode=="presets" then
        local toolbarHeight=buttonPair(shell.newButton,shell.presetButton,shell.left.content,0,lw)
        place(shell.toolbarDivider,shell.left.content,0,toolbarHeight+8,lw,1)
        local editorTop=toolbarHeight+21
        if mode=="presets" then
            ui.pages.main:Hide()
            place(shell.presets,shell.left.content,0,editorTop,lw)
            local y=0
            for _,row in ipairs(shell.presetRows) do
                place(row,nil,0,y,lw)
                local caption=row:GetFontString()
                caption:ClearAllPoints(); caption:SetPoint("LEFT",row,"LEFT",48,0)
                local rowHeight=math.max(56,wrap(caption,lw-56,16)+16)
                caption:SetJustifyV("MIDDLE")
                row:SetHeight(rowHeight); y=y+rowHeight+8
            end
            y=y+layoutButton(shell.presetsBack,shell.presets,0,y+4,lw)+12
            shell.presets:SetHeight(y); contentHeight(shell.left,editorTop+y)
        else layoutEditor(ui,shell,lw,editorTop); ui.pages.main:Show() end
        shell.presets:SetShown(mode=="presets")
        if mode=="presets" then shell.presetButton:LockHighlight() else shell.presetButton:UnlockHighlight() end
        ui.goalPicker:Show(); ns.LayoutCharacterGoalList()
    elseif mode=="settings" then layoutSettings(ui,shell,lw)
    elseif mode=="plan" then
        contentHeight(shell.left,leftHeight)
        layoutPlan(ui,shell,lw,leftHeight)
    elseif mode=="training" or mode=="expenses" then
        contentHeight(shell.left,leftHeight-16)
        layoutPlanning(ui,shell,ui.pages[mode],lw,leftHeight-16)
    elseif mode=="bugreport" then
        local page=ui.pages.bugreport
        place(page,shell.left.content,0,0,lw)
        place(page.intro,nil,0,0,lw)
        local y=wrap(page.intro,lw,30)+14
        place(page.caption,nil,0,y,lw)
        y=y+wrap(page.caption,lw,14)+8
        place(page.link,nil,6,y,lw-12,24)
        y=y+38
        place(page.help,nil,0,y,lw)
        y=y+wrap(page.help,lw,40)+12
        page:SetHeight(y); contentHeight(shell.left,y)
    elseif mode=="planning" then
        local page=ui.pages.planning; place(page,shell.left.content,0,0,lw)
        place(page.body,nil,0,0,lw)
        local y=wrap(page.body,lw,30)+16
        if page.yesButton then
            y=y+layoutButton(page.yesButton,nil,0,y,lw)+10
            y=y+layoutButton(page.noButton,nil,0,y,lw)+12
        end
        page:SetHeight(y); contentHeight(shell.left,y)
    end
    if mode~="main" and mode~="presets" and mode~="expenses" then shell.info:SetWidth(rw) end
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
    shell.totals:SetWordWrap(true)
    shell.budgetRows[1].value:SetText(ns.MoneyText(ns.GetPlayerMoney()))
    local training=shell.budgetRows[2]
    training.shown=ns.db.trainingProtection~=false and not ns.ClassTrainingRetired()
    training.label:SetText("Class training")
    training.value:SetText(ns.MoneyText(status.budget.trainingDue))
    hint(shell.budgetHover,"Spending pool",
        "Training and everyday purchases share " .. ns.MoneyText(status.budget.spendingBalance)
        .. ". Included training reserve: " .. ns.MoneyText(status.budget.trainingDue)
        .. ". After included training: " .. ns.MoneyText(status.budget.spendingAvailable)
        .. (status.budget.trainingShortfall>0 and (". Training still needs " .. ns.MoneyText(status.budget.trainingShortfall)) or ""))
    shell.budgetRows[3].value:SetText(ns.MoneyText(status.budget.spendingBalance))
    local remaining=shell.budgetRows[4]
    remaining.shown=training.shown
    remaining.label:SetText(status.budget.trainingShortfall>0 and "Training shortfall" or "After training")
    remaining.value:SetText(ns.MoneyText(status.budget.trainingShortfall>0
        and status.budget.trainingShortfall or status.budget.spendingAvailable))
    if status.budget.trainingShortfall>0 then remaining.value:SetTextColor(1,0.65,0.35)
    else remaining.value:SetTextColor(1,1,1) end
    shell.budgetPreviewShown=ns.testMoneyCopper~=nil or ns.testPlayerLevel~=nil
    local mode=ui.currentPage
    for _,tab in ipairs(shell.tabs) do
        local selected=tab.key==mode or tab.key=="main" and (mode=="presets" or mode=="expenses" or mode=="planning")
        ns.SetTabSelected(tab,selected)
    end
    ns.LayoutCharacterUI()
end
function ns.ShowCharacterPage(key,replace)
    local ui=ns.ui; local shell=ui.characterUI
    if key=="goals" then key="main" end
    local page=assert(ui.pages[key],"Unknown page: " .. key)
    if key~="main" and ns.iconPicker then ns.iconPicker:Hide() end
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
    place(page,shell.left.content,0,0)
    page:Show()
    local goalsPage=key=="main" or key=="presets"
    shell.newButton:SetShown(goalsPage); shell.presetButton:SetShown(goalsPage)
    shell.totals:SetShown(goalsPage); shell.totalsHover:SetShown(goalsPage); ui.goalPicker:SetShown(goalsPage)
    shell.presets:SetShown(key=="presets")
    shell.info:SetShown(not goalsPage)
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
    local picker=ui.goalPicker
    picker:Hide()
    for _,row in ipairs(picker.rows or {}) do row:Hide(); row.handle:Hide(); row.deleteGoal:Hide() end
    picker.rows={}; picker.visibleRows=0
    picker.completedContent=CreateFrame("Frame",nil,picker)
    ui.training:Hide()
    local shell={tabs={},width=720,height=540}; ui.characterUI=shell
    shell.left=pane(ui); shell.right=pane(ui); shell.columnDivider=paneDivider(ui)
    shell.budgetHover=CreateFrame("Frame",nil,ui); shell.budgetHover:EnableMouse(true)
    shell.budgetRows={}
    for _,caption in ipairs({"Wallet","Class training","Spending pool","After training"}) do
        local row={label=text(ui,caption,"GameFontDisableSmall"),value=text(ui,"")}
        row.label:SetJustifyH("LEFT"); row.value:SetJustifyH("RIGHT")
        shell.budgetRows[#shell.budgetRows+1]=row
    end
    shell.budgetPreview=text(ui,"Test mode: changes reset on reload","GameFontNormalSmall")
    shell.toolbarDivider=shell.left.content:CreateTexture(nil,"BORDER")
    shell.toolbarDivider:SetColorTexture(0.65,0.48,0.22,0.4)
    shell.trainingHelp=CreateFrame("Frame",nil,ui)
    shell.trainingHelpHeading=text(shell.trainingHelp,"How Class training works","GameFontNormalSmall")
    shell.trainingHelpText=text(shell.trainingHelp,
        "Choose training to protect across all goals. Left-click a spell for details; "
        .. "right-click to grey it out or include it. When protection is enabled, it covers your current level and the next two levels.")
    local scrollLeft=shell.left.scroll:GetScript("OnMouseWheel")
    shell.left.scroll:SetScript("OnMouseWheel",function(self,delta)
        local page=ui.pages[ui.currentPage]
        local inner=ui.currentPage=="plan" and ui.scroll
            or (ui.currentPage=="training" or ui.currentPage=="expenses") and page and page.scroll
        local handler=inner and inner:GetScript("OnMouseWheel")
        if handler then handler(inner,delta) else scrollLeft(self,delta) end
    end)
    shell.info=CreateFrame("Frame",nil,shell.right.content); shell.info:SetPoint("TOPLEFT"); shell.info:SetWidth(200)
    shell.infoTitle=text(shell.info,"MountFund","GameFontNormal")
    shell.infoBody=text(shell.info,"")
    shell.infoIcon=shell.info:CreateTexture(nil,"ARTWORK"); shell.infoIcon:SetSize(48,48); shell.infoIcon:SetPoint("TOPLEFT")
    local function tab(key,caption,callback)
        local control=flatButton(ui,caption,callback); control.key=key
        ns.StyleTab(control)
        shell.tabs[#shell.tabs+1]=control
    end
    tab("main","Goals",function() ns.SaveAllFields(); ns.SelectPriorityGoal(); ns.ShowPage("goals") end)
    tab("plan","Savings plan",function() ns.ShowPage("plan") end)
    tab("training","Class training",function() ns.SaveAllFields(true); ns.OpenTrainingPlanner() end)
    shell.settingsButton=headerIconButton(ui,"Interface\\Buttons\\UI-OptionsButton","Settings","Change warnings, notifications, training protection, and display options.",ns.OpenSettings,0.125)
    shell.bugButton=headerIconButton(ui,"Interface\\HelpFrame\\HelpIcon-Bug","Report a bug","Copy a link to report a problem on GitHub.",ns.OpenBugReport,0.2)
    shell.newButton=flatButton(shell.left.content,"New goal",function() ns.BeginGoalDraft() end)
    shell.presetButton=flatButton(shell.left.content,"Presets",function() ns.ShowPage("presets") end)
    shell.totals=text(shell.right.content,"","GameFontNormalSmall")
    shell.goalsHeading=text(ui.goalPicker,"Your goals","GameFontNormal")
    shell.totalsHover=CreateFrame("Frame",nil,shell.right.content); shell.totalsHover:EnableMouse(true)
    -- Use ordinary page navigation so saving, scroll resets, and returning to
    -- a selected goal do not depend on a second visibility flag.
    ui.pages.presets:Hide()
    shell.presets=CreateFrame("Frame",nil,shell.left.content); shell.presetRows={}
    ui.pages.presets=shell.presets
    local choices={ns.FindPreset("mount-first"),ns.FindPreset("mount-epic")}
    for index,preset in ipairs(choices) do
        local choice=preset
        local row=flatButton(shell.presets,choice.name,function() ns.BeginGoalDraft(choice.id) end)
        row.icon=buttonIcon(row,choice.icon); row.icon:SetSize(36,36); row.icon:SetPoint("LEFT",row,"LEFT",4,0)
        row:GetFontString():ClearAllPoints(); row:GetFontString():SetPoint("LEFT",48,0); row:GetFontString():SetJustifyH("LEFT"); row:GetFontString():SetWordWrap(true)
        shell.presetRows[index]=row
    end
    shell.presetsBack=flatButton(shell.presets,"Back to goal",function() ns.ShowPage("main") end)
    shell.createButton=UI.Button(ui.editorFields,"Create goal",0,0,180,function()
        if ns.CommitGoalDraft() then ns.RefreshCharacterUI() end
    end)
    shell.cancelDraft=flatButton(ui.editorFields,"Cancel new goal",ns.CancelGoalDraft)
    ui.goalPicker.instructions=ui.goalPicker.instructions or text(ui.goalPicker,"")
    settingsHelp(ui.warnings,"Excluded-ability warnings","Warn before buying an ability you greyed out in Class training. Other purchases do not trigger this warning. Turn it off here to stop these prompts.",ui.warningsLabel)
    settingsHelp(ui.toastToggle,"Goal progress notifications","Show progress and confirmed completion notifications. Drag the preview with Move toast to choose where they appear.",ui.toastLabel)
    settingsHelp(ui.warningUnit,"Warning silence","After Spend anyway, silence excluded-ability warnings for 30 seconds to 60 minutes. Changing units preserves the duration.")
    ui.warningDuration:HookScript("OnEnter",function() ns.ShowSettingHelp("Warning silence","Choose 30 seconds to 60 minutes. The default is 2 minutes. This applies to excluded-ability warnings after Spend anyway.") end)
    for _,setting in ipairs(ui.summarySettings) do settingsHelp(setting.control,setting.text,setting.help,setting.label) end
    ui.goalIcon=iconButton(ui.editor,ns.ADDON_ICON,"Choose goal icon","Search the game's icons and choose an image for this goal.",ns.OpenGoalIconPicker)
    ui.goalIcon.icon:SetDesaturated(false); ui.goalIcon.icon:SetVertexColor(1,1,1,1)
    picker.legacyScroll=picker.scroll
    picker.legacyScroll:SetScrollChild(CreateFrame("Frame",nil,picker.legacyScroll))
    picker.legacyScroll:Hide(); picker.scroll=shell.right.scroll
    picker.content:SetParent(picker)
    for _,control in ipairs({ui.goldTipToggle,ui.goldTipPrevious,ui.goldTipNext,picker.history}) do ns.StyleButton(control) end
    ui:HookScript("OnHide",function() if ns.iconPicker then ns.iconPicker:Hide() end end)
    ui.goldTips:SetParent(ui); ui.tipDivider:SetParent(ui); ui.summary:SetParent(ui)
    ui.summary:SetWordWrap(false)
    ui:SetClampedToScreen(true)
    ui:SetScript("OnDragStart",function(self) if not self.characterDocked then self:StartMoving() end end)
    if ns.AttachCharacterPanel then ns.AttachCharacterPanel(ui) end
    ns.LayoutCharacterUI()
end
