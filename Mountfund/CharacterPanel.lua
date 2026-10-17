-- Own the overlay and its tab; Blizzard's tab registries and lifecycle stay native.
local _, ns = ...
local panelName = "MountfundCharacterPanel"
local state = { hooked = {}, pendingOpen = false }
local borderPieces = {"TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner",
    "TopEdge", "BottomEdge", "LeftEdge", "RightEdge"}

local function isRegion(value)
    return type(value) == "table" or type(value) == "userdata"
end

local function mirrorTexture(target, source)
    if not isRegion(source) or type(source.GetTexture) ~= "function" then target:Hide(); return end
    local atlas, texture = source:GetAtlas(), source:GetTexture()
    if atlas then target:SetAtlas(atlas)
    elseif texture then target:SetTexture(texture) end
    if atlas or texture then
        local coords = {source:GetTexCoord()}
        if #coords == 8 then target:SetTexCoord(unpack(coords)) end
        target:SetHorizTile(source:GetHorizTile()); target:SetVertTile(source:GetVertTile())
        local r, g, b, a = source:GetVertexColor()
        if type(r) == "number" then target:SetVertexColor(r, g, b, a) end
        target:SetAlpha(source:GetAlpha())
        target:ClearAllPoints(); target:SetAllPoints(source)
    end
    target:SetShown((atlas or texture) and source:IsVisible() or false)
end

local function refreshChrome(panel)
    local chrome, native = panel.chrome, state.host.NineSlice
    if not isRegion(native) then
        if chrome.nativeSource then
            for _, key in ipairs(borderPieces) do
                if isRegion(chrome[key]) then chrome[key]:Hide() end
            end
            chrome.nativeSource = nil
        end
        for _, copy in ipairs(chrome.cornerCopies) do copy.texture:Hide() end
        return
    end
    chrome.nativeSource = native
    for _, key in ipairs(borderPieces) do
        local source = native[key]
        local target = chrome[key]
        if not isRegion(target) then
            target = chrome:CreateTexture(nil, "OVERLAY")
            chrome[key] = target
        end
        -- Corner tails are mirrored only inside the background masks below;
        -- their full rectangles would cover the native portrait and close button.
        if key == "TopLeftCorner" or key == "TopRightCorner" then target:Hide()
        else mirrorTexture(target, source) end
    end
    for index, copy in ipairs(chrome.cornerCopies) do
        mirrorTexture(copy.texture, native[index <= 2 and "TopLeftCorner" or "TopRightCorner"])
    end
end

local function inCombat()
    return InCombatLockdown and InCombatLockdown() or false
end

local function supportedHost()
    local host = _G.CharacterFrame
    if not host or not host.LeftPaneHost or not host.RightPaneHost then return nil end
    if not host.ModeTabs or type(host.ModeTabs.Tabs) ~= "table" then return nil end
    if not EventRegistry or type(EventRegistry.RegisterCallback) ~= "function" then return nil end
    return host
end

-- Keep native panel requests outside combat and retain their callback boundary.
-- Lifecycle observation uses EventRegistry rather than frame script hooks.
local function callNativePanel(callback, host)
    if inCombat() or type(securecallfunction) ~= "function" or type(callback) ~= "function" then return false end
    securecallfunction(callback, host)
    return true
end

local function portraitEdges(region, panel)
    if not isRegion(region) or not region.GetRight or not region.GetBottom then return end
    local right, bottom = region:GetRight(), region:GetBottom()
    local left, top = panel:GetLeft(), panel:GetTop()
    local scale = panel:GetEffectiveScale()
    if right and bottom and left and top and scale > 0 then
        local regionScale = region:GetEffectiveScale()
        return (right * regionScale - left * scale) / scale,
            (top * scale - bottom * regionScale) / scale
    end
end

local function portraitInsets(panel)
    -- Control clearance includes the metal ring. Backgrounds leave only the
    -- visible portrait open; extra padding exposes the native equipment header.
    local container = state.host and state.host.PortraitContainer
    local mask = container and container.CircleMask
    local right, bottom = 56, 44
    local paintRight, paintBottom = isRegion(mask) and 47 or 49, isRegion(mask) and 21 or 25
    local imageRight, imageBottom = portraitEdges(container and container.portrait, panel)
    local ready = imageRight ~= nil
    if ready then
        right, bottom = math.max(right, imageRight + 8), math.max(bottom, imageBottom + 10)
        paintRight, paintBottom = imageRight, imageBottom
    end
    if isRegion(mask) then
        local maskRight, maskBottom = portraitEdges(mask, panel)
        ready = ready and maskRight ~= nil
        if maskRight then
            paintRight, paintBottom = math.min(paintRight, maskRight), math.min(paintBottom, maskBottom)
        end
    end
    return math.min(panel:GetWidth(), right), math.min(panel:GetHeight(), bottom),
        math.max(0, math.min(panel:GetWidth(), paintRight)), math.max(0, math.min(panel:GetHeight(), paintBottom)), ready
end

local function applyLayout()
    local panel, ui = state.panel, ns.ui
    if not panel or not ui or ui:GetParent() ~= panel then return end
    local width, height = panel:GetWidth(), panel:GetHeight()
    if width <= 0 or height <= 0 then return end
    local scale = math.min(1, width / 480, height / 300)
    ui:SetScale(scale)
    local insetX, insetY, paintX, paintY, portraitReady = portraitInsets(panel)
    panel.portraitBoundsReady = portraitReady
    ui.characterPortraitInsetX, ui.characterPortraitInsetY = insetX / scale, insetY / scale
    ui.characterFrameHeaderOffset = 9 / scale
    ui.characterFrameFooterOffset, ui.characterFrameSideInset = 8 / scale, 8 / scale
    -- StatisticsFrame.xml centers its separator on a one-unit frame anchored
    -- to ScrollBox TOP: LeftPaneHost TOP - 40, then half a unit below that.
    local statistics = _G.StatisticsFrame
    local scroll = statistics and statistics.ScrollBox
    local source = scroll or state.host.LeftPaneHost
    local sourceTop = source:GetTop()
    local sourceScale = source:GetEffectiveScale()
    local separatorInset = scroll and 0.5 or 40.5
    if not sourceTop or source:GetHeight() <= 0 then
        source, separatorInset = state.host, 60.5
        sourceTop, sourceScale = source:GetTop(), source:GetEffectiveScale()
    end
    ui.characterTabBaseline = (panel:GetTop() * panel:GetEffectiveScale()
        - (sourceTop - separatorInset) * sourceScale) / ui:GetEffectiveScale()
    local split = width * (398 / 631)
    local nativeRight = state.host.LeftPaneHost:GetRight()
    local panelLeft = panel:GetLeft()
    if nativeRight and panelLeft then
        local nativeSplit = (nativeRight * state.host.LeftPaneHost:GetEffectiveScale()
            - panelLeft * panel:GetEffectiveScale()) / panel:GetEffectiveScale()
        if nativeSplit > width * 0.4 and nativeSplit < width * 0.8 then split = nativeSplit end
    end
    ui.characterSplitRatio = split / width
    local headerRight = width - 24
    local close = state.host.CloseButton
    ui.characterCloseButton = isRegion(close) and close or nil
    if isRegion(close) and close.GetLeft then
        local closeLeft = close:GetLeft()
        if closeLeft and panelLeft then
            headerRight = math.min(width, (closeLeft * close:GetEffectiveScale()
                - panelLeft * panel:GetEffectiveScale()) / panel:GetEffectiveScale())
        end
    end
    for index, region in ipairs(panel.backgrounds) do
        local left, right = index <= 2 and 0 or split, index <= 2 and split or width
        local upper = index % 2 == 1
        local x = upper and math.max(left, paintX) or left
        local y = upper and (index == 1 and -10 or 0) or paintY
        local clipRight, regionHeight = right, upper and paintY - y or height - paintY
        if index == 5 then y, regionHeight, clipRight = -10, 10, headerRight end
        local regionWidth = clipRight - x
        region:ClearAllPoints(); region:SetPoint("TOPLEFT", panel, "TOPLEFT", x, -y)
        region:SetSize(math.max(1, regionWidth), math.max(1, regionHeight))
        region:SetShown(regionWidth > 0 and regionHeight > 0)
        -- Clipped sections sample the same full-pane image. Resizing the
        -- portrait opening must not restart the background's gradient.
        region.paint:ClearAllPoints()
        region.paint:SetPoint("TOPLEFT", panel, "TOPLEFT", left, 10)
        region.paint:SetPoint("BOTTOMRIGHT", panel, "TOPLEFT", right, -height)
    end
    refreshChrome(panel)
    if state.title then
        local title, native = state.title, state.host.TitleContainer
        local caption = title.caption
        title:ClearAllPoints(); caption:ClearAllPoints()
        if isRegion(native) and isRegion(native.TitleText) then
            title:SetAllPoints(native)
            caption:SetAllPoints(native.TitleText)
            local font, size, flags = native.TitleText:GetFont()
            if font then caption:SetFont(font, size, flags) end
        else
            title:SetPoint("TOPLEFT", state.host, "TOPLEFT", 58, -1)
            title:SetPoint("TOPRIGHT", state.host, "TOPRIGHT", -24, -1)
            title:SetHeight(20)
            caption:SetPoint("TOP", title, "TOP", 0, -5)
            caption:SetPoint("LEFT", title, "LEFT"); caption:SetPoint("RIGHT", title, "RIGHT")
            caption:SetHeight(13)
        end
    end
    if ns.LayoutCharacterUI then ns.LayoutCharacterUI(width / scale, height / scale) end
end

local function queuePortraitLayout()
    local panel = state.panel
    if not panel then return end
    panel.portraitLayoutRetries = 3
    panel:SetScript("OnUpdate", function(self)
        self.portraitLayoutRetries = self.portraitLayoutRetries - 1
        applyLayout()
        if self.portraitBoundsReady or self.portraitLayoutRetries <= 0 then self:SetScript("OnUpdate", nil) end
    end)
end

local function layoutTab()
    local host, tab = state.host, state.tab
    if not host or not tab or host ~= supportedHost() then return end
    local previous
    for _, candidate in ipairs(host.ModeTabs.Tabs) do
        if candidate:IsShown() then previous = candidate end
    end
    tab:ClearAllPoints()
    if previous then
        tab:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -2)
    else
        tab:SetPoint("TOPLEFT", host.ModeTabs, "TOPLEFT")
    end
    tab:SetChecked(state.active == true)
end

local function hideOwnedPanel()
    state.active = false
    if ns.iconPicker then ns.iconPicker:Hide() end
    if state.panel then state.panel:Hide() end
    if state.title then state.title:Hide() end
    if state.tab then state.tab:SetChecked(false) end
end

local function skinNativeTab()
    local engine = type(_G.ElvUI) == "table" and _G.ElvUI[1]
    local private = engine and engine.private
    local enabled = private and private.skins and private.skins.blizzard
    if not engine or not enabled or not enabled.enable or not enabled.character then return end
    if type(engine.GetModule) ~= "function" then return end
    local ok, skin = pcall(engine.GetModule, engine, "Skins", true)
    if not ok or not skin or type(skin.HandleLargeSideTab) ~= "function" or state.tabSkin == skin then return end
    if pcall(skin.HandleLargeSideTab, skin, state.tab) then state.tabSkin = skin end
end

function ns.AttachCharacterPanel(ui)
    if not ui or not state.panel then return false end
    if not supportedHost() or state.host ~= _G.CharacterFrame then return false end
    if inCombat() then return ui.characterDocked and ui:GetParent() == state.panel or false end
    if not ui.characterDocked and not ui.standaloneBackdrop and ui.GetBackdrop then
        ui.standaloneBackdrop = ui:GetBackdrop()
        if ui.GetBackdropColor then
            local r, g, b, a = ui:GetBackdropColor()
            if type(r) == "number" then ui.standaloneBackdropColor = {r, g, b, a} end
        end
        if ui.GetBackdropBorderColor then
            local r, g, b, a = ui:GetBackdropBorderColor()
            if type(r) == "number" then ui.standaloneBackdropBorderColor = {r, g, b, a} end
        end
    end
    ui.characterDocked = true
    ns.characterUI = ui
    ui:SetParent(state.panel)
    ui:ClearAllPoints()
    ui:SetPoint("TOPLEFT", state.panel, "TOPLEFT")
    ui:SetMovable(false)
    ui:SetClampedToScreen(false)
    ui:SetFrameStrata(state.panel:GetFrameStrata())
    ui:SetFrameLevel(state.panel:GetFrameLevel() + 2)
    ui:SetBackdrop(nil)
    local name = ui:GetName()
    for index = #(UISpecialFrames or {}), 1, -1 do
        if UISpecialFrames[index] == name then table.remove(UISpecialFrames, index) end
    end
    applyLayout()
    if not state.panel.portraitBoundsReady then queuePortraitLayout() end
    return true
end

function ns.DetachCharacterPanel(ui)
    ui = ui or ns.ui
    if not ui then return false end
    if inCombat() then
        state.pendingDetach = ui
        return true
    end
    state.pendingDetach = nil
    state.pendingOpen = false
    local wasActive = state.active and state.panel and ui:GetParent() == state.panel
    hideOwnedPanel()
    if wasActive and state.host and state.host:IsShown() then callNativePanel(HideUIPanel, state.host) end
    if state.tab then state.tab:Hide() end
    ui.characterDocked = nil
    ui.characterPortraitInsetX, ui.characterPortraitInsetY = nil, nil
    ui.characterSplitRatio = nil
    ui.characterFrameHeaderOffset = nil
    ui.characterFrameFooterOffset, ui.characterFrameSideInset = nil, nil
    ui.characterCloseButton = nil
    ui.characterTabBaseline = nil
    ui:SetParent(UIParent)
    ui:ClearAllPoints()
    ui:SetPoint("CENTER", UIParent, "CENTER")
    ui:SetMovable(true)
    ui:SetFrameStrata("DIALOG")
    ui:SetClampedToScreen(true)
    ui:SetScale(1)
    if ui.standaloneBackdrop then
        ui:SetBackdrop(ui.standaloneBackdrop)
        if ui.standaloneBackdropColor then ui:SetBackdropColor(unpack(ui.standaloneBackdropColor)) end
        if ui.standaloneBackdropBorderColor then ui:SetBackdropBorderColor(unpack(ui.standaloneBackdropBorderColor)) end
    end
    local name = ui:GetName()
    if name and UISpecialFrames then
        local registered = false
        for _, candidate in ipairs(UISpecialFrames) do
            if candidate == name then registered = true; break end
        end
        if not registered then UISpecialFrames[#UISpecialFrames + 1] = name end
    end
    if ns.LayoutCharacterUI then ns.LayoutCharacterUI(720, 540) else ui:SetSize(720, 540) end
    ui:Show()
    return true
end

local function installHostHooks(host)
    if state.hooked[host] then return end
    state.hooked[host] = true
    -- Native OnShow/OnHide update secret-valued health bars. Even script hooks
    -- can taint their dispatch; use the callbacks emitted after those updates.
    EventRegistry:RegisterCallback("CharacterFrame.Show", function()
        if not state.opening then hideOwnedPanel() end
        applyLayout()
        layoutTab()
    end, state)
    EventRegistry:RegisterCallback("CharacterFrame.Hide", hideOwnedPanel, state)
    if hooksecurefunc then
        for _, method in ipairs({"ShowSubFrame", "OnModeTabClicked"}) do
            if type(host[method]) == "function" then hooksecurefunc(host, method, hideOwnedPanel) end
        end
        for _, method in ipairs({"UpdateTabLayout", "SetupModeTabs"}) do
            if type(host[method]) == "function" then hooksecurefunc(host, method, layoutTab) end
        end
    end
end

function ns.InitializeCharacterPanel()
    if inCombat() then
        state.pendingInitialize = true
        return false
    end
    local host = supportedHost()
    if not host or (state.host and state.host ~= host) then return false end
    state.host = host
    state.pendingInitialize = nil
    if not state.panel then
        local panel = CreateFrame("Frame", panelName, host)
        state.panel = panel
        ns.characterPanel = panel
        panel:Hide()
        panel:EnableMouse(true)
        panel:SetPoint("TOPLEFT", host, "TOPLEFT", 8, -30)
        panel:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -8, 8)
        panel:SetFrameLevel(math.max(host:GetFrameLevel() + 20, 520))
        panel:SetFrameStrata("DIALOG")
        -- Cover the still-native content rather than hiding its protected
        -- subframes or changing activeSubframe/characterFrameDisplayInfo.
        -- Clip continuous native pane backgrounds around the portrait; the
        -- right pane has its own artwork, as on the Statistics page.
        panel.backgrounds = {}
        for index = 1, 5 do
            local region = CreateFrame("Frame", nil, panel)
            region:SetFrameLevel(panel:GetFrameLevel())
            region:SetClipsChildren(true); region:EnableMouse(false)
            region.paint = CreateFrame("Frame", nil, region)
            region.paint:SetFrameLevel(panel:GetFrameLevel()); region.paint:EnableMouse(false)
            local surface = region.paint:CreateTexture(nil, "BACKGROUND", nil, -8)
            surface:SetAllPoints()
            surface:SetColorTexture(0.055, 0.04, 0.025, 1)
            local background = region.paint:CreateTexture(nil, "BACKGROUND", nil, -7)
            background:SetAtlas(index <= 2 and "UI-Character-Info-General-BG" or "UI-Character-Info-Stat-BG")
            background:SetAllPoints()
            region.background = background
            panel.backgrounds[index] = region
        end
        panel.chrome = CreateFrame("Frame", nil, panel)
        panel.chrome:SetAllPoints(host); panel.chrome:SetFrameLevel(panel:GetFrameLevel() + 1)
        panel.chrome:EnableMouse(false)
        panel.chrome.cornerCopies = {}
        for index, background in ipairs(panel.backgrounds) do
            -- The background's clipping applies to descendants, so each copy
            -- lives in a child frame rather than directly on that viewport.
            local copy = CreateFrame("Frame", nil, background)
            copy:SetAllPoints(background); copy:EnableMouse(false)
            copy:SetFrameLevel(panel.chrome:GetFrameLevel())
            copy.texture = copy:CreateTexture(nil, "OVERLAY")
            panel.chrome.cornerCopies[index] = copy
        end
        if not isRegion(host.NineSlice) and NineSliceUtil and NineSliceUtil.ApplyLayoutByName then
            NineSliceUtil.ApplyLayoutByName(panel.chrome, "PortraitFrameTemplate")
            for _, key in ipairs({"TopLeftCorner", "TopRightCorner"}) do
                if isRegion(panel.chrome[key]) then panel.chrome[key]:Hide() end
            end
        end
        panel:SetScript("OnHide", function()
            panel:SetScript("OnUpdate", nil)
            if ns.iconPicker then ns.iconPicker:Hide() end
            if ns.SaveAllFields then ns.SaveAllFields() end
        end)
        panel:SetScript("OnShow", queuePortraitLayout)
        panel:SetScript("OnSizeChanged", function()
            applyLayout()
            layoutTab()
        end)
        local title = CreateFrame("Frame", nil, host)
        state.title = title
        panel.title = title
        title:Hide()
        title:SetFrameStrata(panel:GetFrameStrata())
        title:SetFrameLevel(panel:GetFrameLevel() + 3)
        title:SetPoint("TOPLEFT", host, "TOPLEFT", 80, -2)
        title:SetPoint("TOPRIGHT", host, "TOPRIGHT", -80, -2)
        title:SetHeight(19)
        local caption = title:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title.caption = caption
        caption:SetAllPoints()
        caption:SetText("MountFund")
    end
    if not state.tab then
        -- The generic template has the native artwork without the native
        -- CharacterModeTabButtonMixin callback or a parentArray registration.
        local tab = CreateFrame("Frame", "MountfundCharacterTab", host.ModeTabs, "LargeSideTabButtonTemplate")
        state.tab = tab
        ns.characterTab = tab
        tab.fillToInterior = true
        tab.tooltipText = "MountFund - Gold Goal Tracker"
        tab.iconTexture = ns.ADDON_ICON
        if not tab.Icon then
            tab.Icon = tab:CreateTexture(nil, "ARTWORK")
            tab.Icon:SetPoint("TOPLEFT", 7, -7)
            tab.Icon:SetPoint("BOTTOMRIGHT", -7, 7)
        end
        tab.Icon:SetTexture(ns.ADDON_ICON)
        tab:SetCustomOnMouseUpHandler(function(_, button, inside)
            if button == "LeftButton" and inside then
                if state.active then ns.CloseCharacterPanel() else ns.OpenCharacterPanel() end
            end
        end)
    end
    state.tab:Show()
    layoutTab()
    installHostHooks(host)
    skinNativeTab()
    return true
end

function ns.OpenCharacterPanel()
    if inCombat() then
        if not supportedHost() then return false end
        if not state.host or not state.host:IsShown() or not ns.ui or not ns.AttachCharacterPanel(ns.ui) then
            state.pendingOpen = true
            return true
        end
    elseif not ns.InitializeCharacterPanel() then
        return false
    end
    local host = state.host
    if not host:IsShown() then
        state.opening = true
        local shown = callNativePanel(ShowUIPanel, host)
        state.opening = nil
        if not shown then return false end
    end
    state.pendingOpen = false
    if not ns.ui and ns.EnsureUI then ns.EnsureUI() end
    if not ns.AttachCharacterPanel(ns.ui) then return false end
    local reopening = not state.active
    state.active = true
    state.panel:Show()
    state.title:Show()
    state.tab:SetChecked(true)
    if reopening and ns.ui.currentPage == "main" and ns.SelectPriorityGoal then ns.SelectPriorityGoal() end
    if ns.RefreshUI then ns.RefreshUI() end
    ns.ui:Show()
    applyLayout()
    return true
end

function ns.CloseCharacterPanel()
    if not ns.ui or not ns.ui.characterDocked or not state.active then return false end
    if ns.SaveAllFields then ns.SaveAllFields() end
    state.pendingOpen = false
    hideOwnedPanel()
    -- In combat close only our overlay. The untouched native pane remains
    -- available, and its own close button/key binding keeps its secure path.
    if not inCombat() and state.host and state.host:IsShown() then callNativePanel(HideUIPanel, state.host) end
    return true
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
for _, event in ipairs({"UNIT_PORTRAIT_UPDATE", "PORTRAITS_UPDATED", "PLAYER_TALENT_UPDATE", "ACTIVE_TALENT_GROUP_CHANGED"}) do
    events:RegisterEvent(event)
end
events:SetScript("OnEvent", function(_, event, unit)
    if event == "UNIT_PORTRAIT_UPDATE" or event == "PORTRAITS_UPDATED"
        or event == "PLAYER_TALENT_UPDATE" or event == "ACTIVE_TALENT_GROUP_CHANGED" then
        if state.active and (event ~= "UNIT_PORTRAIT_UPDATE" or unit == "player") then queuePortraitLayout() end
        return
    end
    if event == "PLAYER_REGEN_ENABLED" then
        if state.pendingDetach then ns.DetachCharacterPanel(state.pendingDetach) end
        if state.pendingOpen then
            ns.OpenCharacterPanel()
        elseif state.pendingInitialize then
            ns.InitializeCharacterPanel()
        end
    else
        ns.InitializeCharacterPanel()
    end
end)
