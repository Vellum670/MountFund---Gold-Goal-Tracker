-- Mountfund owns one subframe; the character sheet continues to own its shell.
local _, ns = ...
local panelName = "MountfundCharacterPanel"
local state = { hooked = {}, pendingOpen = false }

local function inCombat()
    return InCombatLockdown and InCombatLockdown() or false
end

local function supportedHost()
    local host = _G.CharacterFrame
    if not host or not host.LeftPaneHost or not host.RightPaneHost then return nil end
    if not host.ModeTabs or type(host.ModeTabs.Tabs) ~= "table" then return nil end
    if type(host.ShowSubFrame) ~= "function" or type(host.RefreshDisplay) ~= "function" then return nil end
    if type(CHARACTERFRAME_SUBFRAMES) ~= "table" or type(characterFrameDisplayInfo) ~= "table" then return nil end
    return host
end

local function applyLayout()
    local panel, ui = state.panel, ns.ui
    if not panel or not ui or ui:GetParent() ~= panel then return end
    local width, height = panel:GetWidth(), panel:GetHeight()
    if width <= 0 or height <= 0 then return end
    -- A replacement can provide less room than the editor's minimum layout.
    -- Scale the logical surface to its host instead of letting it protrude.
    local scale = math.min(1, width / 480, height / 300)
    local logicalWidth, logicalHeight = width / scale, height / scale
    ui:SetScale(scale)
    ui:SetSize(logicalWidth, logicalHeight)
    if ns.LayoutCharacterUI then ns.LayoutCharacterUI(logicalWidth, logicalHeight) end
end

local function applyTabIdentity()
    local tab, host = state.tab, state.host
    if not tab or not host then return end
    for index, candidate in ipairs(host.ModeTabs.Tabs) do
        if candidate == tab then tab:SetID(index); break end
    end
    tab.frameName = panelName
    tab.tooltipText = "Mountfund - Gold Goal Tracker"
    tab.iconTexture = "Interface\\Icons\\INV_Misc_Coin_01"
    if tab.Icon then tab.Icon:SetTexture(tab.iconTexture) end
    tab:SetChecked(host.activeSubframe == panelName)
end

local function skinNativeTab()
    -- ElvUI exposes this same handler for the other Forever side tabs. Do not
    -- change its profile or assume that an installed skin is enabled.
    local engine = type(_G.ElvUI) == "table" and _G.ElvUI[1]
    local private = engine and engine.private
    local enabled = private and private.skins and private.skins.blizzard
    if not engine or not enabled or not enabled.enable or not enabled.character then return end
    if type(engine.GetModule) ~= "function" then return end
    local ok, skin = pcall(engine.GetModule, engine, "Skins", true)
    if not ok or not skin or type(skin.HandleLargeSideTab) ~= "function" or state.tabSkin == skin then return end
    if pcall(skin.HandleLargeSideTab, skin, state.tab) then state.tabSkin = skin end
end

local function ensureExpanded()
    local host = state.host
    if not host or inCombat() or state.restoring then return end
    local toggle = host.RightPaneToggleButton
    if toggle and state.previousToggleShown == nil then
        state.previousToggleShown = toggle:IsShown()
        toggle:Hide()
    end
    if host.IsRightPaneCollapsed and host.SetRightPaneCollapsed and host:IsRightPaneCollapsed() then
        if state.previousCollapsed == nil then state.previousCollapsed = true end
        host:SetRightPaneCollapsed(false)
    end
end

local function restoreCharacterPane()
    local host = state.host
    if not host then return end
    if state.tab then state.tab:SetChecked(false) end
    if inCombat() and (state.previousCollapsed or state.previousToggleShown ~= nil) then
        state.pendingRestore = true
        return
    end
    state.restoring = true
    if state.previousToggleShown ~= nil then
        if host.RightPaneToggleButton then host.RightPaneToggleButton:SetShown(state.previousToggleShown) end
        state.previousToggleShown = nil
    end
    if state.previousCollapsed and host.SetRightPaneCollapsed then
        state.previousCollapsed = nil
        host:SetRightPaneCollapsed(true)
    end
    state.pendingRestore = nil
    state.restoring = nil
end

function ns.AttachCharacterPanel(ui)
    if inCombat() or not ui or not state.panel then return false end
    if not supportedHost() or state.host ~= _G.CharacterFrame then return false end
    local panel = state.panel
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
    ui:SetParent(panel)
    ui:ClearAllPoints()
    ui:SetPoint("TOPLEFT", panel, "TOPLEFT")
    if ui.SetMovable then ui:SetMovable(false) end
    if ui.SetClampedToScreen then ui:SetClampedToScreen(false) end
    ui:SetFrameStrata(panel:GetFrameStrata())
    if ui.SetBackdrop then ui:SetBackdrop(nil) end
    -- The character sheet already participates in Escape's panel handling.
    -- Keeping a second special-frame entry could hide only our child page.
    local name = ui:GetName()
    for index = #(UISpecialFrames or {}), 1, -1 do
        if UISpecialFrames[index] == name then table.remove(UISpecialFrames, index) end
    end
    applyLayout()
    return true
end

function ns.DetachCharacterPanel(ui)
    ui = ui or ns.ui
    if not ui then return false end
    if inCombat() then state.pendingDetach = ui; return true end
    state.pendingDetach = nil
    state.pendingOpen = false
    state.pendingClose = nil
    if state.panel and ui:GetParent() == state.panel then
        if state.host and state.host.activeSubframe == panelName and state.host:IsShown() then
            if HideUIPanel then HideUIPanel(state.host) else state.host:Hide() end
        end
        state.panel:Hide()
        restoreCharacterPane()
    end
    if state.tab then state.tab:Hide() end
    ui.characterDocked = nil
    ui:SetParent(UIParent)
    ui:ClearAllPoints()
    ui:SetPoint("CENTER", UIParent, "CENTER")
    ui:SetMovable(true)
    ui:SetFrameStrata("DIALOG")
    ui:SetClampedToScreen(true)
    ui:SetScale(1)
    if ui.SetBackdrop and ui.standaloneBackdrop then
        ui:SetBackdrop(ui.standaloneBackdrop)
        if ui.standaloneBackdropColor then ui:SetBackdropColor(unpack(ui.standaloneBackdropColor)) end
        if ui.standaloneBackdropBorderColor then ui:SetBackdropBorderColor(unpack(ui.standaloneBackdropBorderColor)) end
    end
    local name = ui:GetName()
    if name and UISpecialFrames then
        local registered = false
        for _, candidate in ipairs(UISpecialFrames) do if candidate == name then registered = true; break end end
        if not registered then UISpecialFrames[#UISpecialFrames + 1] = name end
    end
    if ns.LayoutCharacterUI then ns.LayoutCharacterUI(720, 540) else ui:SetSize(720, 540) end
    ui:Show()
    return true
end

local function onPanelShown()
    ensureExpanded()
    if not ns.ui and ns.EnsureUI then ns.EnsureUI() end
    if ns.ui and ns.AttachCharacterPanel(ns.ui) then
        if ns.RefreshUI then ns.RefreshUI() end
        ns.ui:Show()
        applyLayout()
    end
    applyTabIdentity()
end

local function installHostHooks(host)
    if state.hooked[host] then return end
    state.hooked[host] = true
    host:HookScript("OnSizeChanged", function() applyLayout() end)
    host:HookScript("OnHide", function()
        if ns.SaveAllFields then ns.SaveAllFields() end
        restoreCharacterPane()
    end)
    -- Secure post-hooks leave the client's callbacks, arguments, and other
    -- character-sheet skins intact. No protected method is replaced.
    if hooksecurefunc then
        if type(host.SetupModeTabs) == "function" then
            hooksecurefunc(host, "SetupModeTabs", applyTabIdentity)
        end
        hooksecurefunc(host, "ShowSubFrame", function(_, name)
            if name ~= panelName then
                restoreCharacterPane()
            else
                applyTabIdentity()
            end
        end)
        if type(host.RefreshDisplay) == "function" then
            hooksecurefunc(host, "RefreshDisplay", function()
                if host.activeSubframe == panelName then ensureExpanded(); applyTabIdentity(); applyLayout() end
            end)
        end
    end
end

function ns.InitializeCharacterPanel()
    if inCombat() then state.pendingInitialize = true; return false end
    local host = supportedHost()
    if not host then return false end
    if state.host and state.host ~= host then return false end
    state.host = host
    state.pendingInitialize = nil
    if not state.panel then
        local panel = CreateFrame("Frame", panelName, host)
        state.panel = panel
        ns.characterPanel = panel
        panel:Hide()
        panel:SetPoint("TOPLEFT", host, "TOPLEFT", 8, -30)
        panel:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -8, 8)
        -- The native right-pane divider is at level 505. Our own body covers
        -- both panes, while the character sheet's header and side tabs remain.
        panel:SetFrameLevel(math.max(host:GetFrameLevel() + 20, 520))
        panel:SetScript("OnShow", onPanelShown)
        panel:SetScript("OnHide", function()
            if ns.SaveAllFields then ns.SaveAllFields() end
            restoreCharacterPane()
        end)
        panel:SetScript("OnSizeChanged", applyLayout)
    end
    local registered = false
    for _, name in ipairs(CHARACTERFRAME_SUBFRAMES) do
        if name == panelName then registered = true; break end
    end
    if not registered then CHARACTERFRAME_SUBFRAMES[#CHARACTERFRAME_SUBFRAMES + 1] = panelName end
    characterFrameDisplayInfo[panelName] = { title = "Mountfund", titleColor = NORMAL_FONT_COLOR }
    if not state.tab then
        local ok, tab = pcall(CreateFrame, "Frame", "MountfundCharacterTab", host.ModeTabs, "CharacterFrameModeSideTabTemplate")
        if not ok then
            -- A replacement may retain the pane API without the side-tab
            -- template. Use ordinary client button art for that adapter.
            tab = CreateFrame("CheckButton", "MountfundCharacterTab", host.ModeTabs)
            tab:SetSize(56, 56)
            tab:SetNormalTexture("Interface\\Buttons\\UI-Quickslot2")
            tab:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
            tab:SetCheckedTexture("Interface\\Buttons\\CheckButtonHilight", "ADD")
        end
        if not tab.Icon then
            tab.Icon = tab:CreateTexture(nil, "ARTWORK")
            tab.Icon:SetPoint("TOPLEFT", 7, -7)
            tab.Icon:SetPoint("BOTTOMRIGHT", -7, 7)
        end
        if tab.SetCustomOnMouseUpHandler then
            tab:SetCustomOnMouseUpHandler(function(_, button, inside)
                if button == "LeftButton" and inside then ns.OpenCharacterPanel() end
            end)
        else
            tab:RegisterForClicks("LeftButtonUp")
            tab:SetScript("OnClick", function() ns.OpenCharacterPanel() end)
        end
        state.tab = tab
        ns.characterTab = tab
        host.ModeTabs.Tabs[#host.ModeTabs.Tabs + 1] = tab
    end
    applyTabIdentity()
    state.tab:Show()
    installHostHooks(host)
    skinNativeTab()
    if host.UpdateTabLayout then host:UpdateTabLayout() end
    return true
end

function ns.OpenCharacterPanel()
    if inCombat() then
        if supportedHost() then state.pendingOpen = true; return true end
        return false
    end
    if not ns.InitializeCharacterPanel() then return false end
    state.pendingOpen = false
    local host = state.host
    ensureExpanded()
    host:ShowSubFrame(panelName)
    if ShowUIPanel then ShowUIPanel(host) else host:Show() end
    host:RefreshDisplay()
    onPanelShown()
    return true
end

function ns.CloseCharacterPanel()
    if ns.ui and not ns.ui.characterDocked then return false end
    if not state.host or state.host.activeSubframe ~= panelName then return false end
    if ns.SaveAllFields then ns.SaveAllFields() end
    if inCombat() then state.pendingClose = true; state.pendingOpen = false; return true end
    state.pendingClose = nil
    if HideUIPanel then HideUIPanel(state.host) else state.host:Hide() end
    return true
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_ENABLED" then
        if state.pendingRestore then restoreCharacterPane() end
        if state.pendingDetach then ns.DetachCharacterPanel(state.pendingDetach) end
        if state.pendingClose then ns.CloseCharacterPanel() end
        if state.pendingOpen then ns.OpenCharacterPanel() elseif state.pendingInitialize then ns.InitializeCharacterPanel() end
    else
        ns.InitializeCharacterPanel()
    end
end)
