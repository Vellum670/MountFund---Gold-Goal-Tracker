-- A dependency-free launcher; only its visibility and final angle are persisted.
local _, ns = ...
local defaultAngle = 225

local function validAngle(value)
    if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
        return defaultAngle
    end
    return value % 360
end

local function position(button)
    local radians = math.rad(button.angle)
    local x = math.cos(radians) * (Minimap:GetWidth() / 2 + 10)
    local y = math.sin(radians) * (Minimap:GetHeight() / 2 + 10)
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

function ns.FinishMinimapDrag()
    local button = ns.minimapButton
    if not button or not button.dragging then return end
    button.dragging = nil
    if ns.db then ns.db.minimapAngle = validAngle(button.angle) end
end

function ns.RefreshMinimapButton()
    if not ns.db or not Minimap then return end
    local button = ns.minimapButton
    if not button then
        button = CreateFrame("Button", "MountfundMinimapButton", Minimap)
        ns.minimapButton = button
        button:SetSize(32, 32)
        button:SetFrameLevel(Minimap:GetFrameLevel() + 8)
        button:RegisterForClicks("LeftButtonUp")
        button:RegisterForDrag("LeftButton")
        button.icon = button:CreateTexture(nil, "BACKGROUND")
        button.icon:SetSize(20, 20); button.icon:SetPoint("CENTER")
        button.icon:SetTexture("Interface\\Icons\\INV_Misc_Coin_01")
        button.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        button.border = button:CreateTexture(nil, "OVERLAY")
        button.border:SetSize(54, 54); button.border:SetPoint("TOPLEFT")
        button.border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
        button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
        button:SetScript("OnMouseDown", function(self) self.wasDragged = nil end)
        button:SetScript("OnClick", function(self)
            if not self.wasDragged then GameTooltip:Hide(); ns.ToggleUI() end
        end)
        button:SetScript("OnDragStart", function(self)
            self.dragging, self.wasDragged = true, true
            GameTooltip:Hide()
        end)
        button:SetScript("OnDragStop", ns.FinishMinimapDrag)
        button:SetScript("OnHide", function() ns.FinishMinimapDrag(); GameTooltip:Hide() end)
        button:SetScript("OnUpdate", function(self)
            if not self.dragging then return end
            local x, y = GetCursorPosition()
            local centerX, centerY = Minimap:GetCenter()
            if not x or not y or not centerX or not centerY then return end
            local scale = Minimap:GetEffectiveScale()
            self.angle = math.deg(math.atan2(y / scale - centerY, x / scale - centerX)) % 360
            position(self)
        end)
        button:SetScript("OnEnter", function(self)
            if self.dragging then return end
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            GameTooltip:SetText("Mountfund")
            GameTooltip:AddLine("Left-click to open or close.", 1, 1, 1)
            GameTooltip:AddLine("Drag around the minimap to move. Hide in Settings.", 1, 0.82, 0, true)
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    if not button.dragging then
        button.angle = validAngle(ns.db.minimapAngle)
        position(button)
    end
    button:SetShown(ns.db.showMinimapButton ~= false)
end
