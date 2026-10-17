-- Session notifications animate display snapshots without changing saved progress.
local _, ns = ...
local UI = ns.UI
local DISPLAY_SECONDS, FADE_IN, FADE_OUT = 6, 0.3, 0.8

local function inCombat()
    return InCombatLockdown and InCombatLockdown()
end

function ns.HideLevelUpToast()
    if ns.toastMoving and ns.FinishToastMove then ns.FinishToastMove(); return end
    ns.pendingLevelUpToast = nil
    if ns.levelUpToast then
        ns.levelUpToast.startedAt, ns.levelUpToast.expiresAt = nil, nil
        ns.levelUpToast:SetAlpha(0)
        ns.levelUpToast:Hide()
    end
end

local function previewSummary(level)
    local summary = ns.BuildLevelUpSummary(level)
    if not summary then
        summary = { level = level, activeCount = 1, remainingCount = 0, goals = {
            { name = "Example mount fund", icon = "Interface\\Icons\\Ability_Mount_RidingHorse",
                saved = 350000, target = 1000000, percent = 35, expected = 300000,
                ahead = 50000, behind = 0, status = "ahead", targetLevel = 40 },
        } }
    end
    summary.preview = true
    return summary
end

local function layoutText(region, x, y, width, minimum)
    region:ClearAllPoints()
    region:SetPoint("TOPLEFT", x, -y)
    region:SetWidth(width)
    region:SetWordWrap(true)
    if region.SetNonSpaceWrap then region:SetNonSpaceWrap(true) end
    if region.SetMaxLines then region:SetMaxLines(0) end
    region:SetJustifyV("TOP")
    region:SetHeight(0)
    local height = math.max(minimum or 14, math.ceil(region:GetStringHeight() or 14) + 2)
    region:SetHeight(height)
    return height
end

local function layoutToast(frame)
    local width = math.max(200, math.min(360, (UIParent:GetWidth() or 1920) - 24))
    local innerWidth = width - 32
    frame:SetWidth(width)
    local titleHeight = layoutText(frame.title, 50, 13, width - 68, 18)
    local headerHeight = math.max(42, titleHeight + 24)
    frame.header:SetSize(width - 16, headerHeight - 8)
    local cheerHeight = layoutText(frame.cheer, 16, headerHeight + 10, innerWidth)
    local y = headerHeight + cheerHeight + 24
    for index = 1, math.min(#frame.summary.goals, #frame.rows) do
        local row = frame.rows[index]
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 16, -y)
        row:SetWidth(innerWidth)
        local textWidth = innerWidth - 46
        local rowY = layoutText(row.name, 46, 0, textWidth) + 4
        rowY = rowY + layoutText(row.detail, 46, rowY, textWidth) + 4
        rowY = rowY + layoutText(row.status, 46, rowY, textWidth) + 9
        row.bar:ClearAllPoints()
        row.bar:SetPoint("TOPLEFT", 46, -rowY)
        row.bar:SetSize(textWidth - 1, 6)
        local rowHeight = math.max(36, rowY + 7)
        row:SetHeight(rowHeight)
        y = y + rowHeight + 14
    end
    if frame.footer:GetText() ~= "" then
        y = y + layoutText(frame.footer, 16, y, innerWidth) + 8
    end
    frame:SetHeight(y + 2)
end

local function showPending()
    local pending = ns.pendingLevelUpToast
    if not pending then return end
    ns.pendingLevelUpToast = nil
    local summary = pending.summary or (pending.preview and previewSummary(pending.level) or ns.BuildLevelUpSummary(pending.level))
    if not summary then ns.HideLevelUpToast(); return end
    summary.reason=pending.reason
    local frame = ns.levelUpToast
    frame.summary, frame.startedAt = summary, GetTime()
    frame:SetFrameStrata(summary.reason=="completion" and "DIALOG" or "LOW")
    frame.expiresAt=frame.startedAt+DISPLAY_SECONDS
    frame.title:SetText((summary.preview and "Preview: " or "")
        .. (summary.reason=="completion" and "Goal complete!" or summary.reason=="login" and "Welcome back!" or "Level " .. summary.level .. "!"))
    local first = summary.goals[1]
    frame.cheer:SetText(summary.reason=="completion" and "One goal down. Adventure awaits!"
        or first.status == "complete" and "Fully funded. Adventure awaits!"
        or first.status == "behind" and (summary.reason=="login" and "A fresh adventure awaits!" or "New level, fresh adventure!")
        or "Keep the coins rolling!")
    for _, row in ipairs(frame.rows) do row:Hide() end
    for index, progress in ipairs(summary.goals) do
        local row = frame.rows[index]
        row.icon:SetTexture(progress.icon)
        row.name:SetText(progress.name)
        row.detail:SetText(ns.MoneyText(progress.saved) .. " / " .. ns.MoneyText(progress.target)
            .. string.format("  %.0f%%", progress.percent))
        local r, g, b = 0.86, 0.82, 0.67
        if progress.status == "completed" then
            row.status:SetText("Completed - saved in your goal history"); r, g, b = 1, 0.82, 0.2
        elseif progress.status == "complete" then
            row.status:SetText("Goal funded!"); r, g, b = 1, 0.82, 0.2
        elseif progress.status == "behind" then
            row.status:SetText("Behind " .. ns.MoneyText(progress.behind)
                .. (progress.training and " on upcoming training" or " on your savings plan"))
            r, g, b = 0.95, 0.77, 0.4
        elseif progress.status == "ahead" then
            row.status:SetText("Ahead " .. ns.MoneyText(progress.ahead) .. " of your savings plan")
        else
            row.status:SetText(progress.training and "Upcoming training covered" or "Right on track")
        end
        if progress.training and progress.trainingComplete == false then row.status:SetText("Some training prices are unknown") end
        row.status:SetTextColor(r, g, b)
        local funded = progress.status == "completed" or progress.status == "complete"
        row.bar:SetStatusBarColor(funded and 0.9 or 0.72, 0.58, 0.26)
        row.percent = math.max(0, math.min(100, progress.percent))
        row.bar:SetValue(0)
        row:Show()
    end
    frame.footer:SetText(summary.remainingCount > 0 and ("+ " .. summary.remainingCount .. " more goals - /mf shows all") or "")
    frame.footer:SetShown(summary.remainingCount > 0)
    layoutToast(frame)
    frame:SetAlpha(0); frame:Show()
end

local function cursorOverToast(frame)
    -- Use geometry rather than mouse focus: this toast passes clicks through,
    -- so the client may report the frame underneath it as the hovered frame.
    if GetCursorPosition then
        local x,y=GetCursorPosition()
        local scale=frame:GetEffectiveScale()
        local left,right,bottom,top=frame:GetLeft(),frame:GetRight(),frame:GetBottom(),frame:GetTop()
        if x and y and scale and scale>0 and left and right and bottom and top then
            x,y=x/scale,y/scale
            return x>=left and x<=right and y>=bottom and y<=top
        end
        return false
    end
    return MouseIsOver and MouseIsOver(frame) or false
end

local function onUpdate(frame)
    if ns.toastMoving then frame:SetAlpha(1); return end
    if inCombat() then
        -- Resume with a fresh snapshot after combat, without stacking cards.
        if not ns.pendingLevelUpToast and frame.startedAt then
            ns.pendingLevelUpToast = { level = frame.summary.level, preview = frame.summary.preview,
                reason=frame.summary.reason, summary=frame.summary.reason=="completion" and frame.summary or nil,
                readyAt = GetTime() + 0.5 }
        end
        frame.startedAt,frame.expiresAt = nil,nil; frame:SetAlpha(0); frame:Hide()
        return
    end
    if ns.pendingLevelUpToast and GetTime() >= ns.pendingLevelUpToast.readyAt then showPending() end
    if not frame.startedAt then return end
    local now=GetTime(); local age=now-frame.startedAt
    -- Poll cursor bounds so hovering does not require capturing mouse clicks.
    local hovered=cursorOverToast(frame)
    if hovered then frame.expiresAt=now+DISPLAY_SECONDS end
    local remaining=(frame.expiresAt or frame.startedAt+DISPLAY_SECONDS)-now
    if remaining<=0 then ns.HideLevelUpToast(); return end
    local alpha=hovered and 1 or math.min(1,age/FADE_IN,remaining/FADE_OUT)
    frame:SetAlpha(math.max(0, alpha))
    for _, row in ipairs(frame.rows) do
        if row:IsShown() then row.bar:SetValue(row.percent * math.min(1, age / 0.6)) end
    end
end

local function createToast()
    if ns.levelUpToast then return ns.levelUpToast end
    local frame = CreateFrame("Frame", "MountfundLevelUpToast", UIParent, "BackdropTemplate")
    ns.levelUpToast = frame
    frame:SetSize(360, 160)
    ns.ApplyToastPosition()
    frame:SetFrameStrata("LOW")
    frame:EnableMouse(false); frame:EnableKeyboard(false)
    if NineSliceUtil and type(NineSliceUtil.ApplyLayoutByName) == "function" then
        -- A compact panel border avoids the window layout's oversized title edge.
        frame.border = CreateFrame("Frame", nil, frame, "NineSlicePanelTemplate")
        frame.border:ClearAllPoints()
        frame.border:SetPoint("TOPLEFT", 5, 0)
        frame.border:SetPoint("BOTTOMRIGHT", -2, 3)
        frame.border:SetFrameLevel(frame:GetFrameLevel() + 1)
        frame.border:EnableMouse(false); frame.border:EnableKeyboard(false)
        NineSliceUtil.ApplyLayoutByName(frame.border, "SimplePanelTemplate")
    else
        frame:SetBackdrop({ edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", edgeSize = 20 })
        frame:SetBackdropBorderColor(0.78, 0.63, 0.38, 1)
    end
    -- Keep the opaque body inside the decorative frame. A full-frame backdrop
    -- also fills its transparent edges, making a second rectangle behind it.
    frame.surface = frame:CreateTexture(nil, "BACKGROUND")
    frame.surface:SetPoint("TOPLEFT", 8, -8)
    frame.surface:SetPoint("BOTTOMRIGHT", -8, 8)
    frame.surface:SetColorTexture(0.055, 0.04, 0.025, 1)
    frame.background = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
    frame.background:SetPoint("TOPLEFT", 8, -8)
    frame.background:SetPoint("BOTTOMRIGHT", -8, 8)
    frame.background:SetAtlas("UI-Character-Info-General-BG")
    -- Native edge textures extend into the header. All visible content belongs
    -- to a higher frame so the border cannot cover the title or addon emblem.
    local content = CreateFrame("Frame", nil, frame)
    frame.content = content
    content:SetAllPoints(frame); content:SetFrameLevel(frame:GetFrameLevel() + 2)
    content:EnableMouse(false); content:EnableKeyboard(false)
    frame.header = content:CreateTexture(nil, "BORDER")
    frame.header:SetPoint("TOPLEFT", 8, -8)
    -- The outer frame supplies the outline; the title band has no second bevel.
    frame.header:SetColorTexture(0.16, 0.11, 0.065, 1)
    frame.emblemBorder = content:CreateTexture(nil, "ARTWORK")
    frame.emblemBorder:SetAtlas("UI-Character-Info-GearSlot")
    frame.emblemBorder:SetSize(30, 30); frame.emblemBorder:SetPoint("TOPLEFT", 14, -9)
    frame.emblem = content:CreateTexture(nil, "ARTWORK", nil, 1)
    frame.emblem:SetTexture(ns.ADDON_ICON)
    frame.emblem:SetSize(24, 24); frame.emblem:SetPoint("TOPLEFT", 17, -12)
    frame.title = UI.Label(content, "", 50, -13, 292)
    frame.cheer = UI.Label(content, "", 16, -52, 328, "GameFontHighlightSmall")
    frame.rows = {}
    for index = 1, 2 do
        local row = CreateFrame("Frame", nil, content)
        row:EnableMouse(false); row:EnableKeyboard(false)
        row.iconBorder = row:CreateTexture(nil, "ARTWORK")
        row.iconBorder:SetAtlas("UI-Character-Info-GearSlot")
        row.iconBorder:SetSize(36, 36); row.iconBorder:SetPoint("TOPLEFT")
        row.icon = row:CreateTexture(nil, "ARTWORK", nil, 1)
        row.icon:SetSize(28, 28); row.icon:SetPoint("TOPLEFT", 4, -4)
        row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        row.name = UI.Label(row, "", 40, 0, 258, "GameFontNormalSmall")
        row.detail = UI.Label(row, "", 40, -17, 258, "GameFontHighlightSmall")
        row.status = UI.Label(row, "", 40, -33, 258, "GameFontHighlightSmall")
        row.bar = CreateFrame("StatusBar", nil, row)
        row.bar:EnableMouse(false); row.bar:EnableKeyboard(false)
        row.bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
        row.bar:SetMinMaxValues(0, 100)
        row.barBorder = row.bar:CreateTexture(nil, "BACKGROUND", nil, -2)
        row.barBorder:SetPoint("TOPLEFT", -1, 1); row.barBorder:SetPoint("BOTTOMRIGHT", 1, -1)
        row.barBorder:SetColorTexture(0.65, 0.49, 0.27, 1)
        row.track = row.bar:CreateTexture(nil, "BACKGROUND", nil, -1)
        row.track:SetAllPoints(); row.track:SetColorTexture(0.08, 0.06, 0.035, 1)
        frame.rows[index] = row
    end
    frame.footer = UI.Label(content, "", 16, 0, 298, "GameFontDisableSmall")
    frame:SetScript("OnUpdate", onUpdate)
    frame:SetMovable(true); frame:SetClampedToScreen(true); frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart",function(self) if ns.toastMoving then self:StartMoving() end end)
    frame:SetScript("OnDragStop",function(self) self:StopMovingOrSizing() end)
    frame:SetScript("OnHide",function(self)
        self.startedAt,self.expiresAt=nil,nil
        if ns.toastMoving then ns.FinishToastMove() end
    end)
    tinsert(UISpecialFrames,"MountfundLevelUpToast")
    frame:SetAlpha(0); frame:Hide()
    return frame
end

function ns.FlushLevelUpToast()
    local pending = ns.pendingLevelUpToast
    if not pending then return end
    if not pending.preview and not ns.db.levelUpToasts then ns.HideLevelUpToast(); return end
    if inCombat() then return end
    local frame = createToast()
    frame.startedAt,frame.expiresAt = nil,nil; frame:SetAlpha(0); frame:Show()
    if GetTime() >= pending.readyAt then showPending() end
end

function ns.QueueGoalCompletedToast(goal,preview)
    if not preview and not ns.db.levelUpToasts then return end
    local summary={level=ns.GetPlayerLevel(),preview=preview,reason="completion",remainingCount=0,goals={{
        name=goal.name,icon=ns.GoalIcon(goal),
        saved=goal.targetCopper,target=goal.targetCopper,percent=100,status="completed",
    }}}
    ns.pendingLevelUpToast={level=summary.level,preview=preview,reason="completion",summary=summary,readyAt=GetTime()}
    ns.FlushLevelUpToast()
end

function ns.QueueLevelUpToast(level,reason)
    if ns.pendingLevelUpToast and ns.pendingLevelUpToast.reason=="completion" then return end
    if ns.levelUpToast and ns.levelUpToast:IsShown() and ns.levelUpToast.summary
        and ns.levelUpToast.summary.reason=="completion" then return end
    -- The funding confirmation already conveys progress at the same anchor.
    if ns.completionFrame and ns.completionFrame:IsShown() then return end
    if not ns.db.levelUpToasts or not ns.BuildLevelUpSummary(level) then return end
    ns.pendingLevelUpToast = { level = level, reason=reason,
        preview = ns.testPlayerLevel ~= nil or ns.testMoneyCopper ~= nil, readyAt = GetTime() + 0.5 }
    if inCombat() and ns.levelUpToast then
        ns.levelUpToast.startedAt,ns.levelUpToast.expiresAt = nil,nil; ns.levelUpToast:SetAlpha(0); ns.levelUpToast:Hide()
    end
    ns.FlushLevelUpToast()
end

function ns.QueueLoginToast()
    ns.QueueLevelUpToast(ns.GetPlayerLevel(),"login")
end

-- Explicit command preview; the slash handler checks the trailing password.
function ns.TestLevelUpToast()
    ns.pendingLevelUpToast = { level = ns.GetPlayerLevel(), preview = true, readyAt = GetTime() }
    ns.FlushLevelUpToast()
end

local function screenSize()
    local w=UIParent.GetWidth and UIParent:GetWidth() or 1920
    local h=UIParent.GetHeight and UIParent:GetHeight() or 1080
    return math.max(1,w),math.max(1,h)
end
function ns.ApplyToastPosition()
    local frame=ns.levelUpToast; if not frame or ns.toastMoving then return end
    if frame.summary then layoutToast(frame) end
    local w,h=screenSize(); local x,y=ns.GetToastPosition()
    frame:ClearAllPoints(); frame:SetPoint("TOP",UIParent,"TOP",(x-0.5)*w,(y-1)*h)
end
function ns.FinishToastMove()
    if not ns.toastMoving then return end
    local frame=ns.levelUpToast; frame:StopMovingOrSizing()
    local w,h=screenSize(); local x=frame:GetCenter(); local top=frame:GetTop()
    if x and top then ns.db.toastPosition={x=math.max(0,math.min(1,x/w)),y=math.max(0,math.min(1,top/h))} end
    ns.toastMoving=false; ns.pendingLevelUpToast=nil
    frame:EnableMouse(false); frame:EnableKeyboard(false); frame:SetFrameStrata("LOW")
    frame.startedAt,frame.expiresAt=nil,nil; frame:SetAlpha(0); frame:Hide(); ns.ApplyToastPosition()
    if ns.ui and ns.ui.moveToast then ns.ui.moveToast:SetText("Move toast") end
    if ns.ui and ns.ui.characterMode and ns.ui.currentPage=="settings" then ns.LayoutCharacterUI() end
end
function ns.ToggleToastMove()
    if ns.toastMoving then ns.FinishToastMove(); return end
    local frame=createToast()
    ns.pendingLevelUpToast={level=ns.GetPlayerLevel(),preview=true,readyAt=GetTime()}
    showPending(); ns.toastMoving=true; frame:SetAlpha(1); frame:EnableMouse(true); frame:SetFrameStrata("DIALOG")
    frame.title:SetText("Drag to move"); frame.cheer:SetText("Escape saves the position and closes the menu.")
    layoutToast(frame)
    if ns.ui and ns.ui.moveToast then ns.ui.moveToast:SetText("Finish moving toast") end
    if ns.ui and ns.ui.characterMode and ns.ui.currentPage=="settings" then ns.LayoutCharacterUI() end
end
function ns.ResetToastPosition()
    if ns.toastMoving then ns.FinishToastMove() end
    ns.db.toastPosition=nil; ns.ApplyToastPosition()
end
