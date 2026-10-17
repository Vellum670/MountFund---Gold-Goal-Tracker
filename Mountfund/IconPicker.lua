-- A separate selector owns a temporary choice; only Apply changes the goal draft.
local _, ns = ...
local catalog
local function tokenKey(texture) return type(texture) .. ":" .. tostring(texture):lower() end
local function normalizeTexture(texture)
    if type(texture)=="string" then
        local number=tonumber(texture)
        if number then texture=number
        elseif not texture:find("[\\/]") then texture="Interface\\Icons\\" .. texture end
    end
    return ns.Model.NormalizeIcon(texture)
end

function ns.GetGoalIconCatalog()
    if catalog then return catalog end
    local entries,byTexture={},{}
    local function add(texture,name)
        texture=normalizeTexture(texture)
        if not texture then return end
        local key=tokenKey(texture); local entry=byTexture[key]
        local caption=name or tostring(texture):match("([^\\]+)$") or tostring(texture)
        if not entry then
            entry={texture=texture,name=caption,search=""}; byTexture[key]=entry; entries[#entries+1]=entry
        end
        entry.search=entry.search .. " " .. caption:lower()
        if name and entry.name==tostring(texture) then entry.name=name end
    end
    add(ns.ADDON_ICON,"MountFund custom goal")
    for _,id in ipairs({"mount-first","mount-epic"}) do
        local preset=ns.FindPreset(id); add(preset.icon,preset.name .. " mount riding")
    end
    for _,choice in ipairs({
        {"INV_Misc_Bag_10","Bags bank storage"},
        {"INV_Potion_54","Health potions supplies consumables"},
        {"INV_Potion_76","Mana potions supplies consumables"},
        {"INV_Sword_04","Weapons equipment upgrades"},
        {"INV_Shield_06","Armor equipment shields"},
        {"Trade_BlackSmithing","Blacksmithing profession crafting"},
        {"Trade_Engineering","Engineering profession crafting"},
        {"Trade_Alchemy","Alchemy profession crafting"},
        {"INV_Misc_Fish_02","Fishing food cooking"},
        {"INV_Misc_Gem_01","Materials gems reagents"},
        {"INV_Misc_Book_09","Training spells abilities"},
    }) do add(choice[1],choice[2]) end
    -- Use the same four catalog APIs as Forever's IconDataProvider. Entries
    -- may be filenames or file IDs, so normalize before deduplicating.
    for _,name in ipairs({"GetLooseMacroIcons","GetLooseMacroItemIcons","GetMacroIcons","GetMacroItemIcons"}) do
        local callback=_G[name]
        if type(callback)=="function" then
            local icons={}; local ok=pcall(callback,icons)
            if ok then for _,icon in ipairs(icons) do add(icon) end end
        end
    end
    for _,class in ipairs({"WARRIOR","PALADIN","HUNTER","ROGUE","PRIEST","SHAMAN","MAGE","WARLOCK","DRUID"}) do
        for _,ability in ipairs(ns.ClassTrainingData[class] or {}) do
            local name=C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(ability.spellID) or ability.name
            add(ns.ExpenseIcon(ability),(name or ability.name or "Ability") .. " " .. class)
        end
    end
    for _,entry in ipairs(entries) do entry.search=entry.search .. " " .. tostring(entry.texture):lower() end
    catalog=entries
    return entries
end

function ns.FilterGoalIcons(query)
    local result={}; query=(query or ""):lower():match("^%s*(.-)%s*$")
    for _,entry in ipairs(ns.GetGoalIconCatalog()) do
        if query=="" or entry.search:find(query,1,true) then result[#result+1]=entry end
    end
    return result
end

local function redraw(frame)
    local width=frame.content:GetWidth()
    local columns=math.max(1,math.floor(width/42))
    local firstRow=math.floor((frame.scroll:GetVerticalScroll() or 0)/42)
    local visibleRows=math.ceil(frame.scroll:GetHeight()/42)+1
    local last=math.min(#frame.filtered,(firstRow+visibleRows)*columns)
    local visible=0
    for index=firstRow*columns+1,last do
        visible=visible+1
        local button=frame.buttons[visible]
        if not button then
            button=CreateFrame("Button",nil,frame.content)
            button:SetSize(36,36)
            button.icon=button:CreateTexture(nil,"ARTWORK"); button.icon:SetAllPoints()
            button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
            button.selection=button:CreateTexture(nil,"OVERLAY"); button.selection:SetAllPoints()
            button.selection:SetTexture("Interface\\Buttons\\CheckButtonHilight"); button.selection:SetVertexColor(1,0.82,0.25,0.8)
            button:SetScript("OnClick",function(self)
                frame.selected=self.entry.texture; frame.preview:SetTexture(frame.selected)
                frame.apply:SetEnabled(true); redraw(frame)
            end)
            button:SetScript("OnEnter",function(self)
                GameTooltip:SetOwner(self,"ANCHOR_RIGHT"); GameTooltip:SetText(self.entry.name)
                GameTooltip:AddLine(tostring(self.entry.texture),0.7,0.7,0.7,true); GameTooltip:Show()
            end)
            button:SetScript("OnLeave",function() GameTooltip:Hide() end)
            frame.buttons[visible]=button
        end
        local entry=frame.filtered[index]; button.entry=entry
        button:ClearAllPoints(); button:SetPoint("TOPLEFT",((index-1)%columns)*42,-math.floor((index-1)/columns)*42)
        button.icon:SetTexture(entry.texture)
        button.selection:SetShown(tokenKey(entry.texture)==tokenKey(frame.selected)); button:Show()
    end
    for index=visible+1,#frame.buttons do frame.buttons[index]:Hide() end
    frame.content:SetHeight(math.max(1,math.ceil(#frame.filtered/columns)*42))
    frame.empty:SetShown(#frame.filtered==0)
    frame.count:SetText(#frame.filtered .. " icons")
    ns.UpdateScrollAffordance(frame.scroll)
end

function ns.ShowIconPicker(current,onApply)
    ns.EnsureUI()
    local frame=ns.iconPicker
    if not frame then
        frame=ns.UI.Window("MountfundIconPicker",358,432,"Choose goal icon"); ns.iconPicker=frame
        frame:SetMovable(false); frame:SetScript("OnDragStart",nil)
        frame:SetClampedToScreen(true)
        ns.UI.Button(frame,"X",314,-10,28,function() frame:Hide() end)
        ns.UI.Label(frame,"Search icons",18,-53,245,"GameFontNormalSmall")
        frame.search=ns.UI.Edit(frame,24,-72,254,""); frame.search:SetMaxLetters(80)
        frame.preview=frame:CreateTexture(nil,"ARTWORK"); frame.preview:SetSize(36,36); frame.preview:SetPoint("TOPRIGHT",-18,-57)
        frame.search:SetScript("OnEnter",function(self)
            GameTooltip:SetOwner(self,"ANCHOR_TOP"); GameTooltip:SetText("Search goal icons")
            GameTooltip:AddLine("Search categories, spell names, icon filenames, or file IDs.",1,1,1,true); GameTooltip:Show()
        end)
        frame.search:SetScript("OnLeave",function() GameTooltip:Hide() end)
        frame.count=ns.UI.Label(frame,"",18,-106,300,"GameFontDisableSmall")
        frame.scroll=CreateFrame("ScrollFrame",nil,frame,"ScrollFrameTemplate")
        frame.content=CreateFrame("Frame",nil,frame.scroll); frame.content:SetSize(300,1); frame.scroll:SetScrollChild(frame.content)
        frame.empty=ns.UI.Label(frame.content,"No matching icons.",0,-10,286,"GameFontHighlightSmall")
        frame.buttons={}
        ns.SetScrollViewport(frame.scroll,frame,18,130,300,244)
        frame.apply=ns.UI.Button(frame,"Apply icon",18,-391,151,function()
            local callback,icon=frame.onApply,frame.selected
            frame:Hide()
            if callback and ns.Model.NormalizeIcon(icon) then callback(icon) end
        end)
        ns.UI.Button(frame,"Cancel",187,-391,151,function() frame:Hide() end)
        frame.search:SetScript("OnTextChanged",function(self)
            frame.filtered=ns.FilterGoalIcons(self:GetText()); frame.scroll:SetVerticalScroll(0); redraw(frame)
        end)
        frame.search:SetScript("OnEscapePressed",function() frame:Hide() end)
        frame.scroll:HookScript("OnVerticalScroll",function() if frame.filtered then redraw(frame) end end)
        frame:SetScript("OnHide",function() frame.onApply=nil; frame.search:ClearFocus(); GameTooltip:Hide() end)
    end
    frame:SetParent(ns.ui)
    local anchor=ns.ui.characterDocked and _G.CharacterFrame or ns.ui
    frame:ClearAllPoints(); frame:SetPoint("TOPLEFT",anchor,"TOPRIGHT",8,0)
    frame:SetFrameStrata("DIALOG"); frame:SetFrameLevel(ns.ui:GetFrameLevel()+30)
    frame.onApply=onApply; frame.selected=ns.Model.NormalizeIcon(current) or ns.ADDON_ICON
    frame.preview:SetTexture(frame.selected); frame.search:SetText("")
    frame.filtered=ns.FilterGoalIcons(""); frame.scroll:SetVerticalScroll(0)
    frame:Show(); redraw(frame); frame.search:SetFocus()
end

local events=CreateFrame("Frame")
events:RegisterEvent("SPELLS_CHANGED")
events:SetScript("OnEvent",function() catalog=nil end)
