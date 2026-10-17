-- Shared native chrome and scroll affordances, independent of page contents.
local _, ns = ...
local buttonFaceInset = 1
local buttonAtlas = "common-button-list-collapseExpand"

local function updateTabArtwork(chrome)
    local prefix = chrome.selected and "uiframe-activetab" or "uiframe-tab"
    if chrome.tabAtlas == prefix then return end
    chrome.tabAtlas = prefix
    for _, texture in ipairs({chrome.face, chrome.pushed, chrome.disabled, chrome.highlight}) do
        texture:SetAtlas("_" .. prefix .. "-center")
        texture:ClearTextureSlice()
        texture:SetTexCoord(0, 1, 1, 0.25)
    end
    for _, entry in ipairs({{chrome.tabLeft, "left"}, {chrome.tabRight, "right"},
        {chrome.tabGlowLeft, "left"}, {chrome.tabGlowRight, "right"}}) do
        entry[1]:SetAtlas(prefix .. "-" .. entry[2])
        entry[1]:ClearTextureSlice()
        entry[1]:SetTexCoord(0, 1, 1, 0.25)
    end
    local button = chrome.tabLeft:GetParent()
    local leftOffset, rightOffset = chrome.selected and -1 or -3, chrome.selected and 8 or 7
    for _, entry in ipairs({{chrome.tabLeft, "LEFT", leftOffset}, {chrome.tabRight, "RIGHT", rightOffset}}) do
        local edge, side, offset = entry[1], entry[2], entry[3]
        local info = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(prefix .. "-" .. side:lower())
        edge:ClearAllPoints()
        edge:SetPoint("TOP" .. side, button, "TOP" .. side, offset, 0)
        edge:SetPoint("BOTTOM" .. side, button, "BOTTOM" .. side, offset, 0)
        edge:SetWidth(info and info.width or 16)
    end
end

local function updateButtonChrome(button, pressed)
    local chrome = button.mountfundChrome
    if not chrome then return end
    local enabled = button:IsEnabled()
    local selected = chrome.kind == "tab" and chrome.selected
    local r, g, b, alpha = 1, 1, 1, 1
    if not enabled then
        if chrome.kind == "tab" then r, g, b, alpha = 0.45, 0.42, 0.36, 0.8
        else r, g, b, alpha = 0.45, 0.42, 0.36, 0.8 end
    elseif pressed then
        if chrome.kind == "tab" then r, g, b = 0.65, 0.57, 0.45
        else r, g, b = 0.7, 0.65, 0.55 end
    elseif chrome.kind == "icon" then
        if chrome.light then r, g, b = 1, 0.94, 0.78
        else r, g, b = 0.95, 0.82, 0.6 end
    elseif chrome.kind == "tab" then
        if selected then r, g, b = 1, 0.94, 0.8
        else r, g, b = 0.72, 0.65, 0.53 end
    end
    if chrome.kind == "tab" then
        updateTabArtwork(chrome)
        chrome.tabLeft:SetVertexColor(r, g, b, alpha)
        chrome.tabRight:SetVertexColor(r, g, b, alpha)
    end
    chrome.face:SetVertexColor(r, g, b, alpha)
    chrome.face:SetDesaturated(not enabled or chrome.kind == "icon")
    if chrome.kind == "tab" then chrome.pushed:SetVertexColor(0.65, 0.57, 0.45, 1)
    else chrome.pushed:SetVertexColor(0.7, 0.65, 0.55, 1) end
    chrome.pushed:SetDesaturated(chrome.kind == "icon")
    if chrome.kind == "tab" then chrome.disabled:SetVertexColor(0.45, 0.42, 0.36, 0.8)
    else chrome.disabled:SetVertexColor(0.45, 0.42, 0.36, 0.8) end
    chrome.disabled:SetDesaturated(true)
    local caption = button:GetFontString()
    if caption then
        if not enabled then caption:SetTextColor(0.5, 0.48, 0.43)
        elseif selected then caption:SetTextColor(1, 0.82, 0.3)
        elseif chrome.kind == "tab" then caption:SetTextColor(0.84, 0.79, 0.68)
        else caption:SetTextColor(0.95, 0.91, 0.82) end
    end
    if chrome.indicator then chrome.indicator:SetShown(selected and enabled or false) end
end

local function anchorButtonTexture(texture, button)
    texture:ClearAllPoints()
    texture:SetPoint("TOPLEFT", button, "TOPLEFT", buttonFaceInset, -buttonFaceInset)
    texture:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -buttonFaceInset, buttonFaceInset)
end

local function styleControl(button, kind, light)
    local chrome = button.mountfundChrome
    if not chrome then
        chrome = {}
        button.mountfundChrome = chrome
        for _, state in ipairs({"Normal", "Pushed", "Disabled", "Highlight"}) do
            button["Set" .. state .. "Texture"](button, "Interface\\Buttons\\WHITE8X8")
            local texture = button["Get" .. state .. "Texture"](button)
            anchorButtonTexture(texture, button)
            if state ~= "Highlight" then texture:SetDrawLayer("BACKGROUND", 0) end
            chrome[state:lower()] = texture
        end
        chrome.face = chrome.normal
        chrome.highlight:SetBlendMode("ADD")
        chrome.highlight:SetVertexColor(1, 0.82, 0.45, 0.16)
        for _, script in ipairs({"OnEnable", "OnDisable", "OnMouseUp", "OnLeave", "OnHide"}) do
            button:HookScript(script, function(self) updateButtonChrome(self, false) end)
        end
        button:HookScript("OnMouseDown", function(self) updateButtonChrome(self, true) end)
    end
    chrome.kind = kind
    if light ~= nil then chrome.light = light end
    -- Native Statistics headers supply action gradients. Top tabs use the
    -- client's flipped tab pieces, keeping rounded tops and a flat baseline.
    if kind == "icon" then
        chrome.face:SetTexture("Interface\\Buttons\\UI-SquareButton-Up")
        chrome.pushed:SetTexture("Interface\\Buttons\\UI-SquareButton-Down")
        chrome.disabled:SetTexture("Interface\\Buttons\\UI-SquareButton-Disabled")
        chrome.highlight:SetTexture("Interface\\Buttons\\UI-SquareButton-Up")
        for _, texture in ipairs({chrome.face, chrome.pushed, chrome.disabled, chrome.highlight}) do
            texture:SetTexCoord(0, 1, 0, 1)
        end
    elseif kind == "tab" then
        if not chrome.tabLeft then
            for _, side in ipairs({"Left", "Right"}) do
                local edge = button:CreateTexture(nil, "BACKGROUND")
                edge:SetPoint("TOP" .. side:upper(), button, "TOP" .. side:upper())
                edge:SetPoint("BOTTOM" .. side:upper(), button, "BOTTOM" .. side:upper())
                edge:SetWidth(12)
                chrome["tab" .. side] = edge
                local glow = button:CreateTexture(nil, "HIGHLIGHT")
                glow:SetAllPoints(edge); glow:SetBlendMode("ADD")
                glow:SetVertexColor(1, 0.82, 0.45, 0.16)
                chrome["tabGlow" .. side] = glow
            end
        end
        for _, texture in ipairs({chrome.face, chrome.pushed, chrome.disabled, chrome.highlight}) do
            texture:ClearAllPoints()
            texture:SetPoint("TOPLEFT", chrome.tabLeft, "TOPRIGHT")
            texture:SetPoint("BOTTOMRIGHT", chrome.tabRight, "BOTTOMLEFT")
        end
    else
        for _, texture in ipairs({chrome.face, chrome.pushed, chrome.disabled, chrome.highlight}) do
            texture:SetAtlas(buttonAtlas)
        end
    end
    if kind == "tab" and not chrome.indicator then
        chrome.indicator = button:CreateTexture(nil, "OVERLAY")
        chrome.indicator:SetPoint("BOTTOMLEFT", 4, 0)
        chrome.indicator:SetPoint("BOTTOMRIGHT", -4, 0)
        chrome.indicator:SetHeight(2)
        chrome.indicator:SetColorTexture(0.95, 0.73, 0.3, 1)
    end
    updateButtonChrome(button, false)
end

function ns.StyleHeaderDivider(texture, scale)
    local atlas = "UI-Character-Info-ScrollLine-Long"
    local info = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas)
    texture:SetAtlas(atlas)
    texture:SetVertexColor(1, 1, 1, 1)
    texture:SetDrawLayer("OVERLAY", 0)
    return (info and info.height or 8) / (scale or 1)
end

function ns.StyleButton(button)
    styleControl(button, "button")
end

function ns.StyleTab(button)
    styleControl(button, "tab")
end

function ns.StyleIconButton(button, light)
    styleControl(button, "icon", light)
end

function ns.SetTabSelected(button, selected)
    local chrome = button.mountfundChrome
    if not chrome or chrome.kind ~= "tab" then return end
    chrome.selected = selected == true
    updateButtonChrome(button, false)
end

local function scrollbar(scroll)
    if scroll.mountfundScroll and scroll.mountfundScroll.bar then return scroll.mountfundScroll.bar end
    local bar=scroll.ScrollBar
    if type(bar)=="table" or type(bar)=="userdata" then return bar end
    local name=scroll:GetName()
    return name and _G[name .. "ScrollBar"] or nil
end

local function scrollRange(scroll)
    local child=scroll:GetScrollChild()
    -- Managed layouts set the child height from their visible contents. Do not
    -- enable scrolling from a stale native rectangle after a list shrinks.
    if child and child:GetHeight()<=scroll:GetHeight()+1 then return 0 end
    local range=math.max(0,scroll:GetVerticalScrollRange() or 0)
    return range>1 and range or 0
end

function ns.UpdateScrollAffordance(scroll)
    local affordance=scroll.mountfundScroll
    if not affordance or affordance.syncing then return end
    local range=scrollRange(scroll)
    local previous=scroll:GetVerticalScroll() or 0
    local position=math.max(0,math.min(range,previous))
    if position~=previous then
        affordance.syncing=true
        scroll:SetVerticalScroll(position)
        affordance.syncing=nil
    end
    scroll:EnableMouseWheel(range>0)
    local bar=scrollbar(scroll)
    if bar then
        if bar.SetVisibleExtentPercentage then
            bar:SetVisibleExtentPercentage(scroll:GetHeight()/math.max(1,range+scroll:GetHeight()))
            bar:SetPanExtentPercentage(math.min(1,42/math.max(1,range)))
        end
        if type(bar.SetScrollPercentage)=="function" then
            local percentage=range>0 and position/range or 0
            local current=type(bar.GetScrollPercentage)=="function" and bar:GetScrollPercentage()
            if type(current)~="number" or math.abs(current-percentage)>0.0000001 then
                -- The content has already moved. Mirror it immediately rather
                -- than starting another interpolated scroll from the thumb.
                affordance.syncing=true
                bar:SetScrollPercentage(percentage,true)
                affordance.syncing=nil
            end
        end
        bar:SetShown(scroll:IsShown() and range>1)
    end
    scroll.mountfundScroll.hint:SetShown(scroll:IsShown() and range-position>1)
end

function ns.RefreshScrollRange(scroll)
    -- Child and viewport sizes can change before the client updates its cached
    -- scroll rectangle. Refresh it before clamping or positioning the thumb.
    if scroll.UpdateScrollChildRect then scroll:UpdateScrollChildRect() end
    local range=scrollRange(scroll)
    local position=scroll:GetVerticalScroll() or 0
    local clamped=math.max(0,math.min(range,position))
    if clamped~=position then scroll:SetVerticalScroll(clamped) end
    ns.UpdateScrollAffordance(scroll)
end

function ns.SetupScrollAffordance(scroll)
    if scroll.mountfundScroll then return end
    local footer=CreateFrame("Frame",nil,scroll:GetParent())
    footer:SetHeight(15)
    local caption=footer:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    caption:SetAllPoints(); caption:SetJustifyH("CENTER"); caption:SetJustifyV("MIDDLE")
    caption:SetText("Scroll for more")
    footer:EnableMouse(false); footer:Hide()
    scroll.mountfundScroll={hint=footer}
    if ScrollUtil and type(ScrollUtil.InitScrollFrameWithScrollBar)=="function" then
        local bar=scrollbar(scroll)
        -- ScrollFrameTemplate already supplies and connects a native bar.
        -- Reuse it so skins, native callbacks, and our layout share one object.
        if not bar or type(bar.RegisterCallback)~="function" or type(bar.SetScrollPercentage)~="function" then
            if bar then bar:Hide() end
            bar=CreateFrame("EventFrame",nil,scroll:GetParent(),"MinimalScrollBar")
            ScrollUtil.InitScrollFrameWithScrollBar(scroll,bar)
        end
        bar:SetWidth(12)
        scroll.mountfundScroll.bar=bar
        scroll.ScrollBar=bar
    end
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel",function(self,delta)
        local range=scrollRange(self)
        self:SetVerticalScroll(math.max(0,math.min(range,(self:GetVerticalScroll() or 0)-delta*42)))
        ns.UpdateScrollAffordance(self)
    end)
    scroll:HookScript("OnScrollRangeChanged",function() ns.UpdateScrollAffordance(scroll) end)
    scroll:HookScript("OnVerticalScroll",function() ns.UpdateScrollAffordance(scroll) end)
    scroll:HookScript("OnShow",function() ns.UpdateScrollAffordance(scroll) end)
    scroll:HookScript("OnHide",function()
        footer:Hide(); local bar=scrollbar(scroll); if bar then bar:Hide() end
    end)
end

function ns.SetScrollViewport(scroll,parent,x,y,width,height)
    ns.SetupScrollAffordance(scroll)
    scroll:SetParent(parent); scroll:ClearAllPoints()
    scroll:SetPoint("TOPLEFT",x,-y); scroll:SetSize(math.max(30,width),math.max(20,height-16))
    local bar=scroll.mountfundScroll.bar
    if bar then
        bar:SetParent(parent); bar:ClearAllPoints()
        bar:SetPoint("TOPLEFT",scroll,"TOPRIGHT",5,-2)
        bar:SetPoint("BOTTOMLEFT",scroll,"BOTTOMRIGHT",5,2)
    end
    local footer=scroll.mountfundScroll.hint
    footer:SetParent(parent); footer:ClearAllPoints()
    footer:SetPoint("TOPLEFT",x,-(y+height-15)); footer:SetWidth(width)
    ns.RefreshScrollRange(scroll)
end
