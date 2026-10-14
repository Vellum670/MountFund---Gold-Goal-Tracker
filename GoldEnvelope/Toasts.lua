local _, ns = ...
local UI = ns.UI
local DISPLAY_SECONDS, FADE_IN, FADE_OUT = 6, 0.3, 0.8

local function inCombat()
    return InCombatLockdown and InCombatLockdown()
end

function ns.HideLevelUpToast()
    ns.pendingLevelUpToast = nil
    if ns.levelUpToast then
        ns.levelUpToast.startedAt = nil
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

local function showPending()
    local pending = ns.pendingLevelUpToast
    if not pending then return end
    ns.pendingLevelUpToast = nil
    local summary = pending.preview and previewSummary(pending.level) or ns.BuildLevelUpSummary(pending.level)
    if not summary then ns.HideLevelUpToast(); return end
    local frame = ns.levelUpToast
    frame.summary, frame.startedAt = summary, GetTime()
    frame:SetSize(330, 68 + #summary.goals * 62 + (summary.remainingCount > 0 and 16 or 0))
    frame.title:SetText((summary.preview and "Preview: " or "") .. "Level " .. summary.level .. "!")
    local first = summary.goals[1]
    frame.cheer:SetText(first.status == "complete" and "Fully funded. Adventure awaits!"
        or first.status == "behind" and "New level, fresh adventure!"
        or "Keep the coins rolling!")
    for _, row in ipairs(frame.rows) do row:Hide() end
    for index, progress in ipairs(summary.goals) do
        local row = frame.rows[index]
        row.icon:SetTexture(progress.icon)
        row.name:SetText(progress.name)
        row.detail:SetText(ns.MoneyText(progress.saved) .. " / " .. ns.MoneyText(progress.target)
            .. string.format("  %.0f%%", progress.percent))
        local r, g, b = 0.65, 0.9, 0.65
        if progress.status == "complete" then
            row.status:SetText("Goal funded!"); r, g, b = 1, 0.82, 0.2
        elseif progress.status == "behind" then
            row.status:SetText("Behind " .. ns.MoneyText(progress.behind)
                .. (progress.training and " on upcoming training" or " on this level's plan"))
            r, g, b = 0.95, 0.77, 0.4
        elseif progress.status == "ahead" then
            row.status:SetText("Ahead " .. ns.MoneyText(progress.ahead) .. " of this level's plan")
        else
            row.status:SetText(progress.training and "Upcoming training covered" or "Right on track")
        end
        if progress.training and progress.trainingComplete == false then row.status:SetText("Some training prices are unknown") end
        row.status:SetTextColor(r, g, b)
        row.bar:SetStatusBarColor(r, g, b)
        row.percent = math.max(0, math.min(100, progress.percent))
        row.bar:SetValue(0)
        row:Show()
    end
    frame.footer:SetText(summary.remainingCount > 0 and ("+ " .. summary.remainingCount .. " more goals - /ge shows all") or "")
    frame.footer:ClearAllPoints(); frame.footer:SetPoint("BOTTOMLEFT", 16, 10)
    frame:SetAlpha(0); frame:Show()
end

local function onUpdate(frame)
    if inCombat() then
        -- Resume with a fresh snapshot after combat, without stacking cards.
        if not ns.pendingLevelUpToast and frame.startedAt then
            ns.pendingLevelUpToast = { level = frame.summary.level, preview = frame.summary.preview, readyAt = GetTime() + 0.5 }
        end
        frame.startedAt = nil; frame:SetAlpha(0); frame:Hide()
        return
    end
    if ns.pendingLevelUpToast and GetTime() >= ns.pendingLevelUpToast.readyAt then showPending() end
    if not frame.startedAt then return end
    local age = GetTime() - frame.startedAt
    if age >= DISPLAY_SECONDS then ns.HideLevelUpToast(); return end
    local alpha = math.min(1, age / FADE_IN, (DISPLAY_SECONDS - age) / FADE_OUT)
    frame:SetAlpha(math.max(0, alpha))
    frame.glow:SetAlpha(0.16 + 0.1 * math.sin(age * 5))
    for _, row in ipairs(frame.rows) do
        if row:IsShown() then row.bar:SetValue(row.percent * math.min(1, age / 0.6)) end
    end
end

local function createToast()
    if ns.levelUpToast then return ns.levelUpToast end
    local frame = CreateFrame("Frame", "GoldEnvelopeLevelUpToast", UIParent, "BackdropTemplate")
    ns.levelUpToast = frame
    frame:SetSize(330, 130)
    frame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -40, 210)
    frame:SetFrameStrata("LOW")
    frame:EnableMouse(false); frame:EnableKeyboard(false)
    frame:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    frame:SetBackdropColor(0.055, 0.04, 0.025, 0.96)
    frame:SetBackdropBorderColor(0.72, 0.55, 0.24, 0.9)
    local coin = frame:CreateTexture(nil, "ARTWORK")
    coin:SetTexture("Interface\\MoneyFrame\\UI-GoldIcon"); coin:SetSize(20, 20); coin:SetPoint("TOPLEFT", 16, -12)
    frame.glow = frame:CreateTexture(nil, "ARTWORK")
    frame.glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    frame.glow:SetBlendMode("ADD"); frame.glow:SetVertexColor(1, 0.78, 0.2)
    frame.glow:SetSize(40, 40); frame.glow:SetPoint("TOPLEFT", 6, -2)
    frame.title = UI.Label(frame, "", 44, -15, 270)
    frame.cheer = UI.Label(frame, "", 16, -38, 298, "GameFontHighlightSmall")
    frame.rows = {}
    for index = 1, 2 do
        local row = CreateFrame("Frame", nil, frame)
        row:SetSize(298, 58); row:SetPoint("TOPLEFT", 16, -62 - (index - 1) * 62)
        row:EnableMouse(false); row:EnableKeyboard(false)
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(28, 28); row.icon:SetPoint("TOPLEFT", 0, -2)
        row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        row.name = UI.Label(row, "", 40, 0, 258, "GameFontNormalSmall")
        row.name:SetWordWrap(false); row.name:SetHeight(14)
        row.detail = UI.Label(row, "", 40, -17, 258, "GameFontHighlightSmall")
        row.detail:SetWordWrap(false)
        row.status = UI.Label(row, "", 40, -33, 258, "GameFontHighlightSmall")
        row.status:SetWordWrap(false)
        row.bar = CreateFrame("StatusBar", nil, row)
        row.bar:SetPoint("TOPLEFT", 40, -52); row.bar:SetSize(258, 4)
        row.bar:EnableMouse(false); row.bar:EnableKeyboard(false)
        row.bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
        row.bar:SetMinMaxValues(0, 100)
        local track = row.bar:CreateTexture(nil, "BACKGROUND")
        track:SetAllPoints(); track:SetColorTexture(0.25, 0.21, 0.14, 0.8)
        frame.rows[index] = row
    end
    frame.footer = UI.Label(frame, "", 16, 0, 298, "GameFontDisableSmall")
    frame:SetScript("OnUpdate", onUpdate)
    frame:SetAlpha(0); frame:Hide()
    return frame
end

function ns.FlushLevelUpToast()
    local pending = ns.pendingLevelUpToast
    if not pending then return end
    if not pending.preview and not ns.db.levelUpToasts then ns.HideLevelUpToast(); return end
    if inCombat() then return end
    local frame = createToast()
    frame.startedAt = nil; frame:SetAlpha(0); frame:Show()
    if GetTime() >= pending.readyAt then showPending() end
end

function ns.QueueLevelUpToast(level)
    if not ns.db.levelUpToasts or not ns.BuildLevelUpSummary(level) then return end
    ns.pendingLevelUpToast = { level = level, preview = ns.testPlayerLevel ~= nil, readyAt = GetTime() + 0.5 }
    if inCombat() and ns.levelUpToast then
        ns.levelUpToast.startedAt = nil; ns.levelUpToast:SetAlpha(0); ns.levelUpToast:Hide()
    end
    ns.FlushLevelUpToast()
end

-- TEMPORARY: remove this helper and /ge testtoast after in-game review.
function ns.TestLevelUpToast()
    ns.pendingLevelUpToast = { level = ns.GetPlayerLevel(), preview = true, readyAt = GetTime() }
    ns.FlushLevelUpToast()
end
