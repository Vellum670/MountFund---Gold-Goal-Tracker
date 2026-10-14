local _, ns = ...
local scripts = setmetatable({}, { __mode = "k" })
local splits = setmetatable({}, { __mode = "k" })

local function shown(frame)
    return frame and frame:IsShown()
end

-- Wrap UI actions rather than replacing Blizzard's purchase APIs. A post-hook
-- on BuyMerchantItem would run after money had already been spent.
local function wrapClick(control, provider)
    if not control or (control.IsProtected and control:IsProtected()) then return end
    local current = control:GetScript("OnClick")
    if not current or scripts[control] == current then return end
    local wrapper = function(self, mouseButton, ...)
        local action = provider(self, mouseButton)
        if not action then return current(self, mouseButton, ...) end
        local args = { ... }
        local count = select("#", ...)
        ns.RequestPurchase(function() return provider(self, mouseButton) end, function()
            current(self, mouseButton, unpack(args, 1, count))
        end)
    end
    scripts[control] = wrapper
    control:SetScript("OnClick", wrapper)
end

local function merchantInfo(index)
    if C_MerchantFrame and C_MerchantFrame.GetItemInfo then return C_MerchantFrame.GetItemInfo(index) end
    if GetMerchantItemInfo then
        local name, _, price, quantity = GetMerchantItemInfo(index)
        if name then return { name = name, price = price, stackCount = quantity } end
    end
end

local function merchantAction(control, quantity)
    if not shown(MerchantFrame) or MerchantFrame.selectedTab ~= 1 or not shown(control) then return end
    local index = control:GetID()
    local info = merchantInfo(index)
    if not info or not info.price or not info.stackCount or info.stackCount <= 0 then return end
    quantity = quantity or info.stackCount
    if quantity <= 0 then return end
    local link = GetMerchantItemLink(index) or info.name or ""
    return { key = "merchant:" .. index .. ":" .. link .. ":" .. quantity,
        cost = math.ceil(info.price * quantity / info.stackCount), label = (info.name or "Vendor purchase") .. " x" .. quantity }
end

local function buybackAction(index)
    if not shown(MerchantFrame) then return end
    local name, _, price, quantity = GetBuybackItemInfo(index)
    if not name or not price then return end
    return { key = "buyback:" .. index .. ":" .. (GetBuybackItemLink(index) or name) .. ":" .. (quantity or 1),
        cost = price, label = "Buy back " .. name }
end

local function installMerchant()
    if not MerchantFrame then return end
    for index = 1, math.max(MERCHANT_ITEMS_PER_PAGE or 10, BUYBACK_ITEMS_PER_PAGE or 12) do
        local control = _G["MerchantItem" .. index .. "ItemButton"]
        wrapClick(control, function(self, mouseButton)
            if not shown(MerchantFrame) or IsModifiedClick() then return end
            if MerchantFrame.selectedTab == 2 then return buybackAction(self:GetID()) end
            if mouseButton == "RightButton" then return merchantAction(self) end
        end)
        if control and control.SplitStack and splits[control] ~= control.SplitStack
            and not (control.IsProtected and control:IsProtected()) then
            local original = control.SplitStack
            local wrapper = function(self, quantity)
                if quantity <= 0 then return original(self, quantity) end
                ns.RequestPurchase(function() return merchantAction(self, quantity) end, function()
                    original(self, quantity)
                end)
            end
            splits[control] = wrapper
            control.SplitStack = wrapper
        end
    end
    wrapClick(MerchantBuyBackItemItemButton, function()
        return buybackAction(GetNumBuybackItems())
    end)
    wrapClick(MerchantRepairAllButton, function()
        if not shown(MerchantFrame) then return end
        local cost, canRepair = GetRepairAllCost()
        if not canRepair or not cost then return end
        return { key = "repair-all", cost = cost, label = "Repair all equipment" }
    end)
end

local function trainerAction()
    if not shown(ClassTrainerFrame) or not ClassTrainerFrame.selectedService then return end
    local index = ClassTrainerFrame.displayIndexToSkillIndex
        and ClassTrainerFrame.displayIndexToSkillIndex[ClassTrainerFrame.selectedService]
        or ClassTrainerFrame.selectedService
    if not index then return end
    local name, serviceType = GetTrainerServiceInfo(index)
    local cost = GetTrainerServiceCost(index)
    if serviceType ~= "available" or not cost then return end
    -- Pet training points are not coins.
    if C_Trainer and Enum and Enum.TrainerType and C_Trainer.GetTrainerType
        and C_Trainer.GetTrainerType() == Enum.TrainerType.Pet then return end
    local classTraining = not (IsTradeskillTrainer and IsTradeskillTrainer())
    if C_Spell and C_Spell.GetSpellName and (name == C_Spell.GetSpellName(33388) or name == C_Spell.GetSpellName(33391)) then
        classTraining = false
    end
    return { key = "training:" .. index .. ":" .. (name or ""), cost = cost, label = name or "Training",
        classTraining = classTraining }
end

local function commodityAction(control)
    local dialog = control:GetParent()
    if not shown(AuctionHouseFrame) or not shown(dialog) or not control:IsEnabled() then return end
    if not dialog.itemID or not dialog.quantity or not dialog.PriceFrame then return end
    if C_AuctionHouse.GetQuoteDurationRemaining() <= 0 then return end
    return { key = "commodity:" .. dialog.itemID .. ":" .. dialog.quantity,
        cost = dialog.PriceFrame:GetAmount(), label = "Auction purchase x" .. dialog.quantity }
end

local function popupAction(control)
    local popup = control:GetParent()
    if not shown(popup) then return end
    local which, data = popup.which, popup.data
    if which == "BUYOUT_AUCTION" or which == "BID_AUCTION" then
        if not shown(AuctionHouseFrame) or not data or not data.auctionID then return end
        local cost = which == "BUYOUT_AUCTION" and data.buyout or data.bid
        if not cost then return end
        return { key = which .. ":" .. data.auctionID, cost = cost, label = "Auction " .. (which == "BUYOUT_AUCTION" and "buyout" or "bid") }
    elseif which == "CONFIRM_PROFESSION" then
        return trainerAction()
    end
end

local popupHookInstalled = false
function ns.InstallGuards()
    if InCombatLockdown() then return end
    installMerchant()
    wrapClick(ClassTrainerTrainButton, trainerAction)
    if AuctionHouseFrame and AuctionHouseFrame.BuyDialog then
        wrapClick(AuctionHouseFrame.BuyDialog.BuyNowButton, commodityAction)
    end
    for index = 1, STATICPOPUP_NUMDIALOGS or 4 do
        local popup = _G["StaticPopup" .. index]
        local control = popup and (popup.Button1 or popup.button1 or _G["StaticPopup" .. index .. "Button1"])
        wrapClick(control, popupAction)
    end
    if not popupHookInstalled and StaticPopup_Show then
        popupHookInstalled = true
        hooksecurefunc("StaticPopup_Show", function() ns.InstallGuards() end)
    end
end
