unpack = unpack or table.unpack
local ns, tests = {}, 0
local function loadAddon(file) assert(loadfile('GoldEnvelope/' .. file))('GoldEnvelope', ns) end
local function equal(actual, expected, name)
    assert(actual == expected, (name or 'value') .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual))
end
local function test(name, callback) callback(); tests=tests+1; print('PASS ' .. name) end
local level, money, class = 25, 48705, 'WARRIOR'
local elapsed = 1000
local inCombat, sounds = false, 0
local knownSpells, services, messages, controls = {}, {}, {}, {}
local function frame(parent)
    local value={parent=parent,scripts={},hidden=false}
    local methods={}
    function methods:SetText(text) self.text=tostring(text) end
    function methods:GetText() return self.text or '' end
    function methods:SetChecked(checked) self.checked=checked end
    function methods:GetChecked() return self.checked end
    function methods:SetScript(name,callback) self.scripts[name]=callback end
    function methods:GetScript(name) return self.scripts[name] end
    function methods:SetSize(w,h) self.width,self.height=w,h end
    function methods:SetWidth(w) self.width=w end
    function methods:SetHeight(h) self.height=h end
    function methods:GetWidth() return self.width end
    function methods:GetHeight() return self.height end
    function methods:SetPoint(...) self.point={...} end
    function methods:ClearAllPoints() self.point=nil end
    function methods:SetTexture(texture) self.texture=texture end
    function methods:SetDesaturated(desaturated) self.desaturated=desaturated end
    function methods:SetVertexColor(r,g,b,a) self.color={r,g,b,a} end
    function methods:SetAlpha(alpha) self.alpha=alpha end
    function methods:GetAlpha() return self.alpha or 1 end
    function methods:EnableMouse(enabled) self.mouseEnabled=enabled end
    function methods:EnableKeyboard(enabled) self.keyboardEnabled=enabled end
    function methods:SetEnabled(enabled) self.disabled=not enabled end
    function methods:Enable() self.disabled=false end
    function methods:Disable() self.disabled=true end
    function methods:IsEnabled() return not self.disabled end
    function methods:IsShown() return not self.hidden end
    function methods:Show() self.hidden=false end
    function methods:Hide()
        local before=not self.hidden; self.hidden=true
        if before and self.scripts.OnHide then self.scripts.OnHide(self) end
    end
    function methods:SetShown(shown) if shown then self:Show() else self:Hide() end end
    function methods:GetID() return self.id end
    function methods:GetParent() return self.parent end
    function methods:GetFrameLevel() return 1 end
    function methods:IsProtected() return false end
    function methods:CreateTexture() return frame(self) end
    function methods:CreateFontString() return frame(self) end
    function methods:SetNormalTexture() self.normal=frame(self) end
    function methods:GetNormalTexture() return self.normal end
    setmetatable(value,{__index=function(_,key) return methods[key] or (key:match('^%u') and function() end or nil) end})
    controls[#controls+1]=value; return value
end
CreateFrame=function(kind,_,parent,template)
    local value=frame(parent); value.kind,value.template=kind,template; return value
end
UIParent,UISpecialFrames,tinsert={}, {}, table.insert
SlashCmdList={}
GetMoney=function() return money end
UnitLevel=function() return level end
UnitClass=function() return class,class end
UnitRace=function() return 'Human','Human',1 end
UnitName=function() return 'Trainer' end
time=function() return 123456 end
GetTime=function() return elapsed end
IsPlayerSpell=function(id) return knownSpells[id] or false end
InCombatLockdown=function() return inCombat end
PlaySound=function() sounds=sounds+1 end
IsModifiedClick=function() return false end
IsTradeskillTrainer=function() return false end
GetNumTrainerServices=function() return #services end
GetTrainerServiceInfo=function(index)
    local item=services[index]; if not item then return end
    return item.name,item.status or 'available','icon',item.level,item.rank
end
GetTrainerServiceCost=function(index) return services[index] and services[index].cost end
GetTrainerServiceLevelReq=function(index) return services[index] and services[index].level end
GetTrainerServiceItemLink=function(index) return services[index] and services[index].link end
C_Timer={After=function(_,callback) callback() end}
C_Trainer={GetTrainerType=function() return 1 end}
Enum={TrainerType={Pet=2},TooltipDataType={Spell=0,Item=1}}
C_TooltipInfo={GetTrainerService=function(index) return services[index] and services[index].tooltip end}
DEFAULT_CHAT_FRAME={AddMessage=function(_,message) messages[#messages+1]=message end}
GameTooltip=frame()
function GameTooltip:SetOwner(owner,anchor) self.owner,self.anchor=owner,anchor end
function GameTooltip:ClearLines() self.lines,self.spellID,self.link,self.text={},nil,nil,nil end
function GameTooltip:SetSpellByID(spellID) self:ClearLines(); self.spellID=spellID; return true end
function GameTooltip:SetHyperlink(link) self:ClearLines(); self.link=link; return true end
function GameTooltip:SetText(text) self:ClearLines(); self.text=tostring(text) end
function GameTooltip:AddLine(text) self.lines=self.lines or {}; self.lines[#self.lines+1]=text end
hooksecurefunc=function() end
StaticPopup_Show=function() end
loadAddon('Data/IncomeWeights.lua'); loadAddon('Data/ClassTraining.lua'); loadAddon('Model.lua'); loadAddon('Presets.lua')
local names={[33388]='Apprentice Riding',[33391]='Journeyman Riding'}
for _,entries in pairs(ns.ClassTrainingData) do for _,entry in ipairs(entries) do names[entry.spellID]=entry.name end end
C_Spell={GetSpellName=function(id) return names[id] end,GetSpellTexture=function(id) return 'spell-icon:' .. id end}
GetSpellTexture=C_Spell.GetSpellTexture
loadAddon('Core.lua')
local eventFrame=controls[#controls]
loadAddon('Training.lua'); loadAddon('UI.lua'); loadAddon('Toasts.lua'); loadAddon('PlanningUI.lua'); loadAddon('Guards.lua')
local M=ns.Model
local function reset(newLevel,newMoney)
    ns.CancelPurchase(); ns.ClosePlanningWindows()
    ns.HideLevelUpToast()
    level,money,class=newLevel or 25,newMoney or 48705,'WARRIOR'
    ns.db={version=2,goals={},trainerCatalog={},warnings=true,earnings={},levelUpToasts=true}
    ns.lastMoney,ns.sessionStarted=money,true
    ns.lastLevelUpEvent=level
    elapsed,ns.warningCooldownUntil=1000,0
    inCombat,sounds=false,0
    knownSpells,services,messages={},{},{}
    for _,entry in ipairs(ns.ClassTrainingData[class]) do if entry.level<level then knownSpells[entry.spellID]=true end end
end
local function goal(target,finish,start)
    return {name='Goal',targetCopper=target or 1000000,targetLevel=finish or 40,startLevel=start or 25,
        initialCopper=0,savedCopper=0,curve=0,active=true,milestones={},expenses={},planDecision='simple'}
end
local function click(parent,text)
    for _,control in ipairs(controls) do
        if control.parent==parent and control.text==text and control.scripts.OnClick then control.scripts.OnClick(control,'LeftButton'); return end
    end
    error('Button not found: ' .. text)
end
local function blur(control,text)
    if text~=nil then control:SetText(text) end
    assert(control.scripts.OnEditFocusLost,'Input has no autosave on blur')
    control.scripts.OnEditFocusLost(control)
end

test('coin parsing preserves every copper and rejects invalid input',function()
    equal(M.ParseCoins('4','87','5'),48705); equal(M.FormatCoins(48705),'4g 87s 5c')
    equal(M.ParseCoins('-1','0','0'),nil); equal(M.ParseCoins('1.5','0','0'),nil)
    equal(M.ParseCoins('0','100','0'),nil); equal(M.ParseCoins('0','0','100'),nil)
end)
test('income-based weights put less saving at early levels than the old default',function()
    local g=goal(1000000,40,1)
    assert(M.TargetAtLevel(g,25)<1000000*((25-1)/(40-1))^2)
    assert(M.TargetAtLevel(g,25)<250000)
    equal(M.TargetAtLevel(g,1),0); equal(M.TargetAtLevel(g,40),1000000)
end)
test('a level-25 goal has no historical target and reaches the final amount exactly',function()
    local g=goal(); g.initialCopper=9741
    for l=1,24 do equal(M.TargetAtLevel(g,l),0) end
    equal(M.TargetAtLevel(g,25),9741); equal(M.TargetAtLevel(g,40),1000000)
    local previous=0
    for l=25,60 do local target=M.TargetAtLevel(g,l); assert(target>=previous); previous=target end
end)
test('initial investment protects the next two training levels',function()
    equal(M.InitialInvestment(48705,30000,0,20,nil,1000000),9741)
    equal(M.InitialInvestment(29999,30000,0,20,nil,1000000),0)
    equal(M.InitialInvestment(48705,30000,0,20,40000,1000000),18705)
    equal(M.InitialInvestment(48705,30000,10000,20,40000,1000000),8705)
end)
test('every playable class has a preloaded training catalog through level 60',function()
    local count=0
    for _,token in ipairs({'WARRIOR','PALADIN','HUNTER','ROGUE','PRIEST','SHAMAN','MAGE','WARLOCK','DRUID'}) do
        local entries=ns.ClassTrainingData[token]; assert(#entries>50)
        local last=0
        for _,entry in ipairs(entries) do assert(entry.level>=1 and entry.level<=60); last=math.max(last,entry.level); count=count+1 end
        equal(last,60)
    end
    equal(count,1374)
end)
test('warrior training at level 26 is included without any trainer visit',function()
    reset()
    local g=goal(); g.includeClassTraining=true; ns.SyncExpenses(g)
    local totals=ns.TrainingByLevel(g)
    equal(totals[26],30000); equal(ns.TrainingRunway(g),30000)
    assert(#g.expenses>50); equal(g.targetCopper,1000000)
end)
test('live trainer prices override base prices without duplicate ranks',function()
    reset()
    services={{name='Charge',rank='Rank 2',level=26,cost=9000}}
    ns.CaptureTrainerPrices()
    local g=goal(); g.includeClassTraining=true; ns.SyncExpenses(g)
    equal(ns.TrainingRunway(g),29000)
    local count=0
    for _,entry in ipairs(g.expenses) do if entry.spellID==6178 then count=count+1; equal(entry.copper,9000) end end
    equal(count,1)
end)
test('ability pictures prefer the exact rank and safely fall back for manual expenses',function()
    equal(ns.ExpenseIcon({spellID=6178,icon='trainer-picture'}),'spell-icon:6178')
    local texture=C_Spell.GetSpellTexture; C_Spell.GetSpellTexture=function() return nil end
    equal(ns.ExpenseIcon({spellID=6178,icon='trainer-picture'}),'trainer-picture')
    equal(ns.ExpenseIcon({name='Manual expense'}),'Interface\\Icons\\INV_Misc_QuestionMark')
    C_Spell.GetSpellTexture=texture
end)
test('trainer spell links and typed tooltips preserve the exact ability rank',function()
    reset()
    services={{name='Charge',rank='Rank 2',level=26,cost=9000,link='|cffffffff|Hspell:6178|h[Charge]|h|r'},
        {name='Challenging Shout',level=26,cost=8000,tooltip={type=Enum.TooltipDataType.Spell,id=1161}},
        {name='Non-spell service',level=27,cost=7000,link='item:555',tooltip={type=Enum.TooltipDataType.Item,id=555}}}
    ns.CaptureTrainerPrices()
    local captured={}
    for _,quote in pairs(ns.db.trainerCatalog) do captured[quote.name]=quote end
    equal(captured.Charge.spellID,6178); equal(captured['Challenging Shout'].spellID,1161)
    equal(captured['Non-spell service'].spellID,nil)
    for _,entry in ipairs(ns.ClassCatalog()) do
        if entry.spellID==6178 then equal(entry.copper,9000); equal(entry.icon,'spell-icon:6178') end
    end
end)
test('unchecked class ranks stay excluded when prices refresh',function()
    reset(); local g=goal(); g.includeClassTraining=true; ns.SyncExpenses(g)
    for _,entry in ipairs(g.expenses) do if entry.spellID==6178 then entry.selected=false end end
    equal(ns.TrainingRunway(g),20000)
    services={{name='Charge',rank='Rank 2',level=26,cost=9000}}; ns.CaptureTrainerPrices(); ns.SyncExpenses(g)
    equal(ns.TrainingRunway(g),20000)
end)
test('newly observed ranks inherit ability exclusions while new abilities default to included',function()
    reset(); local g=goal(1000000,60); g.includeClassTraining=true; ns.SyncExpenses(g); ns.db.goals={g}
    for _,entry in ipairs(g.expenses) do if entry.source=='class' and entry.name=='Charge' then entry.selected=false end end
    services={{name='Charge',rank='Rank 4',level=54,cost=80000,link='spell:555555'},
        {name='Experimental Strike',rank='Rank 1',level=56,cost=70000,link='spell:555556'}}
    ns.CaptureTrainerPrices()
    local foundCharge,foundNew=false,false
    for _,entry in ipairs(g.expenses) do
        if entry.spellID==555555 then foundCharge=true; equal(entry.selected,false) end
        if entry.spellID==555556 then foundNew=true; equal(entry.selected,true) end
    end
    assert(foundCharge and foundNew); equal(g.targetCopper,1000000)
end)
test('learned ranks no longer require training money',function()
    reset(); knownSpells[6178]=true
    local g=goal(); g.includeClassTraining=true; ns.SyncExpenses(g)
    equal(ns.TrainingRunway(g),20000)
end)
test('two goals share a single training budget',function()
    reset(); local a,b=goal(),goal(10000000,60)
    a.includeClassTraining,b.includeClassTraining=true,true
    ns.SyncExpenses(a); ns.SyncExpenses(b); ns.db.goals={a,b}
    equal(ns.TrainingRunway(),30000)
    for _,g in ipairs(ns.db.goals) do for _,entry in ipairs(g.expenses) do if entry.spellID==6178 then entry.selected=false end end end
    equal(ns.TrainingRunway(),20000)
end)
local function chooseTraining(g,selected)
    g.includeClassTraining=true; ns.SyncExpenses(g)
    for _,entry in ipairs(g.expenses) do if entry.source=='class' then entry.selected=selected[entry.spellID] or false end end
end
test('a new goal cannot invest money promised to another goals class training',function()
    reset(25,40000); local existing=goal(); existing.includeClassTraining=true; ns.SyncExpenses(existing); ns.db.goals={existing}
    local candidate=goal(); chooseTraining(candidate,{})
    candidate.savedCopper=nil; candidate.initialOverrideCopper=40000
    ns.PrepareGoal(candidate); equal(candidate.initialCopper,10000)
end)
test('initial investment protects the union of training choices across goals',function()
    reset(25,30000); local existing=goal(); chooseTraining(existing,{[6178]=true}); ns.db.goals={existing}
    local candidate=goal(); chooseTraining(candidate,{[7400]=true})
    equal(ns.TrainingRunway(candidate,true,{existing}),20000)
    candidate.savedCopper=nil; candidate.initialOverrideCopper=30000
    ns.PrepareGoal(candidate); equal(candidate.initialCopper,10000)
end)
test('replacing a goal releases its removed training choices during initial investment',function()
    reset(); local existing=goal(); existing.includeClassTraining=true; ns.SyncExpenses(existing); ns.db.goals={existing}
    local candidate=goal(); chooseTraining(candidate,{})
    candidate.savedCopper=nil; candidate.initialOverrideCopper=48705
    ns.PrepareGoal(candidate,existing); equal(candidate.initialCopper,48705)
end)
test('the reported reserve is always backed by the actual wallet',function()
    local g=goal(); g.savedCopper=143412
    local b=M.Budget({g},25,48705,30000)
    equal(b.saved,48705); equal(b.trainingFunded,0); equal(b.reserved,48705)
    M.Reconcile({g},48705); equal(g.savedCopper,48705)
    assert(b.reserved<=b.balance)
end)
test('progress distinguishes expected targets from real savings',function()
    local g=goal(); g.savedCopper=48705
    local p=M.GoalProgress(g,30)
    equal(p.saved,48705); assert(p.expected>p.saved); equal(p.behind,p.expected-p.saved)
    equal(p.percent,4.8705)
end)
test('funding protects training first and never counts cash twice',function()
    local a,b=goal(),goal(2000000,60)
    M.FundGoals({a,b},10000,48705,30000)
    equal(a.savedCopper,10000); equal(b.savedCopper,0)
    M.FundGoals({a,b},10000,58705,30000)
    equal(a.savedCopper,20000)
    local budget=M.Budget({a,b},25,58705,30000)
    equal(budget.saved,20000); equal(budget.trainingFunded,30000); equal(budget.reserved,50000)
end)
test('spending consumes unassigned cash before reducing savings',function()
    local g=goal(); g.savedCopper=10000
    M.Reconcile({g},15000); equal(g.savedCopper,10000)
    M.Reconcile({g},7000); equal(g.savedCopper,7000)
end)
test('an expected deficit does not pretend that missing gold is saved',function()
    local g=goal(); g.savedCopper=1000
    local b=M.Budget({g},35,48705,30000)
    assert(b.expected>48705); equal(b.saved,1000); equal(b.reserved,31000); assert(b.behind>0)
end)
test('exact protected limit is allowed but one copper beyond warns',function()
    local g=goal(); g.savedCopper=10000
    equal(M.Purchase({g},25,48705,8705,30000).warning,false)
    equal(M.Purchase({g},25,48705,8706,30000).warning,true)
    equal(M.Purchase({g},25,48705,0,30000).warning,false)
end)
test('planned training can use its own budget without using goal savings',function()
    local g=goal(); g.savedCopper=9741
    equal(M.Purchase({g},25,48705,30000,30000,true).warning,false)
    equal(M.Purchase({g},25,48705,30000,30000,false).warning,true)
end)
test('itemized costs follow their own due levels while training stays separate',function()
    local g=goal(30000,40); g.planMode='items'
    g.expenses={{key='a',name='Near',level=26,copper=10000,selected=true},
        {key='b',name='Later',level=40,copper=20000,selected=true},
        {key='c',name='Spell',level=26,copper=30000,selected=true,source='class'}}
    equal(M.ExpenseTotal(g),30000); equal(M.TargetAtLevel(g,25),0)
    assert(M.TargetAtLevel(g,26)>=10000); equal(M.TargetAtLevel(g,40),30000)
end)
test('itemizing a simple goal preserves its amount when class ranks were already preloaded',function()
    reset(); local g=goal(); g.includeClassTraining=true; ns.SyncExpenses(g)
    assert(#g.expenses>50); equal(M.ExpenseTotal(g),0)
    for _,entry in ipairs(g.expenses) do if entry.spellID==6178 then entry.selected=false end end
    ns.EnableItemPlanning(g)
    equal(g.targetCopper,1000000); equal(M.ExpenseTotal(g),1000000)
    equal(ns.TrainingRunway(g),20000)
    local manual=0
    for _,entry in ipairs(g.expenses) do if entry.source=='manual' then manual=manual+1; equal(entry.copper,1000000) end end
    equal(manual,1); ns.EnableItemPlanning(g); equal(M.ExpenseTotal(g),1000000)
end)
test('random income and spending preserve the wallet conservation invariant',function()
    math.randomseed(10)
    local goals={goal(),goal(2000000,60)}; local wallet=10000
    for i=1,1000 do
        local change=math.random(-5000,9000); wallet=math.max(0,wallet+change)
        if change>0 then M.FundGoals(goals,change,wallet,30000) else M.Reconcile(goals,wallet) end
        local budget=M.Budget(goals,25,wallet,30000)
        assert(budget.saved>=0 and budget.reserved<=wallet and budget.trainingFunded>=0)
        equal(goals[1].savedCopper+goals[2].savedCopper,budget.saved)
    end
end)

local executions=0
local action={key='item:1',label='Item',cost=20000}
local function read() return action end
local function execute() executions=executions+1 end
local function pending()
    reset(25,48705); local g=goal(); g.savedCopper=30000; ns.db.goals={g}
    executions=0; action={key='item:1',label='Item',cost=20000}; ns.RequestPurchase(read,execute)
end
test('warning rows show actual protected money apart from long purchase names',function()
    reset(35,987654321)
    local g=goal(10000000000,40,25); g.savedCopper=900000000; ns.db.goals={g}
    local longName=string.rep('Very long purchase name ',10)
    action={key='large:item',label=longName,cost=123456789}; ns.RequestPurchase(read,execute)
    local budget=ns.pending.budget
    assert(budget.expected>budget.balance); equal(budget.reserved,900000000)
    equal(ns.warningFrame.itemName.text,longName)
    for key,value in pairs({cost=123456789,remaining=864197532,reserved=900000000,used=35802468}) do
        local row=ns.warningFrame.moneyRows[key]
        equal(row.amount.text,ns.MoneyText(value))
        assert(not row.caption.text:find(longName,1,true))
    end
    assert(not ns.warningFrame.moneyRows.reserved.caption.text:find('level',1,true))
end)
test('cancel spends nothing and Spend anyway authorizes once',function()
    pending(); equal(executions,0); ns.CancelPurchase(); ns.ConfirmPurchase(); equal(executions,0)
    ns.RequestPurchase(read,execute); ns.ConfirmPurchase(); ns.ConfirmPurchase(); equal(executions,1)
end)
test('Spend anyway suppresses repeat warnings for exactly two minutes',function()
    pending(); ns.ConfirmPurchase(); equal(executions,1); equal(ns.WarningCooldownRemaining(),120)
    elapsed=elapsed+119
    ns.RequestPurchase(read,execute); equal(executions,2); equal(ns.pending,nil)
    equal(ns.WarningCooldownRemaining(),1)
    elapsed=elapsed+1
    ns.RequestPurchase(read,execute); equal(executions,2); assert(ns.pending)
    equal(ns.WarningCooldownRemaining(),0)
end)
test('ordinary purchases do not begin a warning cooldown',function()
    reset(); executions=0; action={key='item',label='Item',cost=20000}
    ns.RequestPurchase(read,execute); equal(executions,1); equal(ns.WarningCooldownRemaining(),0)
    local g=goal(); g.savedCopper=30000; ns.db.goals={g}
    ns.RequestPurchase(read,execute); equal(executions,1); assert(ns.pending)
end)
test('closing a purchase window preserves an already approved cooldown',function()
    pending(); ns.ConfirmPurchase(); elapsed=elapsed+30
    eventFrame.scripts.OnEvent(nil,'MERCHANT_CLOSED'); equal(ns.WarningCooldownRemaining(),90)
    ns.RequestPurchase(read,execute); equal(executions,2); equal(ns.pending,nil)
end)
test('Cancel does not start or extend the warning cooldown',function()
    pending(); ns.CancelPurchase(); equal(ns.WarningCooldownRemaining(),0)
    ns.RequestPurchase(read,execute); assert(ns.pending); equal(executions,0)
    ns.ConfirmPurchase(); elapsed=elapsed+120
    ns.RequestPurchase(read,execute); ns.CancelPurchase(); equal(ns.WarningCooldownRemaining(),0)
    ns.RequestPurchase(read,execute); assert(ns.pending); equal(executions,1)
end)
test('cooldown purchases still validate current availability prices and funds',function()
    pending(); ns.ConfirmPurchase(); equal(executions,1)
    action=nil; ns.RequestPurchase(read,execute); equal(executions,1)
    for _,cost in ipairs({-1,0.5,math.huge,0/0,1000000000001,50000}) do
        action={key='item',label='Item',cost=cost}; ns.RequestPurchase(read,execute); equal(executions,1)
    end
    action={key='item',label='Item',cost=30000}; ns.RequestPurchase(read,execute); equal(executions,2)
    equal(ns.WarningCooldownRemaining(),120)
end)
test('invalidated confirmation does not grant a cooldown',function()
    pending(); action={key='item:1',label='Item',cost=21000}; ns.ConfirmPurchase()
    equal(executions,0); equal(ns.WarningCooldownRemaining(),0)
    ns.RequestPurchase(read,execute); assert(ns.pending)
end)
test('insufficient funds at confirmation do not grant a cooldown',function()
    pending(); money=10000; ns.ConfirmPurchase(); equal(executions,0); equal(ns.WarningCooldownRemaining(),0)
end)
test('price or selection changes invalidate confirmation',function()
    pending(); action={key='item:1',label='Item',cost=21000}; ns.ConfirmPurchase(); equal(executions,0)
    pending(); action={key='other',label='Other',cost=20000}; ns.ConfirmPurchase(); equal(executions,0)
end)
test('a closed purchase window cannot use a pending confirmation',function()
    pending(); eventFrame.scripts.OnEvent(nil,'MERCHANT_CLOSED'); ns.ConfirmPurchase(); equal(executions,0)
end)
test('changing real savings refreshes a risky confirmation',function()
    pending(); ns.db.goals[1].savedCopper=31000; ns.Changed(); ns.ConfirmPurchase()
    equal(executions,0); assert(ns.pending); ns.ConfirmPurchase(); equal(executions,1)
end)
test('invalid and unaffordable prices never proceed',function()
    for _,cost in ipairs({-1,0.5,math.huge,0/0,1000000000001,50000}) do
        reset(); executions=0; action={key='item',label='Item',cost=cost}; ns.RequestPurchase(read,execute); equal(executions,0)
    end
end)
test('money events fund real earnings and debit actual spending',function()
    reset(); local g=goal(); g.savedCopper=9741; ns.db.goals={g}
    money=money+10000; ns.ObserveMoney(); equal(g.savedCopper,19741); equal(ns.db.earnings[25].income,10000)
    money=5000; ns.ObserveMoney(); equal(g.savedCopper,5000); equal(ns.db.earnings[25].spending,53705)
end)
test('status prints the exact wallet, saved progress and no Available figure',function()
    reset(); local g=goal(); g.savedCopper=9741; ns.db.goals={g}
    SlashCmdList.GOLDENVELOPE('status')
    local text=table.concat(messages,'\n')
    assert(text:find('4g 87s 5c',1,true)); assert(text:find('0g 97s 41c',1,true))
    assert(not text:lower():find('available',1,true)); assert(not text:find('14g 34s 12c',1,true))
end)
test('legacy goals migrate to the current level without claiming historical savings',function()
    reset(); ns.sessionStarted=false
    ns.db.goals={{name='Mount',targetLevel=40,targetCopper=1000000,curve=2,active=true,milestones={[10]=1000},expenses={}}}
    eventFrame.scripts.OnEvent(nil,'PLAYER_LOGIN')
    local g=ns.db.goals[1]; equal(g.startLevel,25); equal(g.curve,0); equal(g.milestones[10],nil)
    equal(g.savedCopper,9741); equal(ns.lastMoney,48705)
end)

test('the main UI is only slightly larger than the native trade window',function()
    reset(); ns.ToggleUI(); equal(ns.ui.width,400); equal(ns.ui.height,450)
    assert(ns.ui.width/344<1.2 and ns.ui.height/446<1.2)
end)
test('new presets save immediately from the current level with a safe automatic allocation',function()
    reset(); ns.UsePreset('mount-first')
    equal(ns.ui.planRows[1],nil); assert(ns.ui.planRows[25]:IsShown())
    equal(#ns.db.goals,1)
    equal(ns.db.goals[1].startLevel,25); equal(ns.db.goals[1].savedCopper,9741)
    equal(ns.ui.initialAmount,nil); equal(ns.ui.initialPercent,nil); equal(ns.ui.planRows[25].addition.text,'')
end)
test('insufficient training cash makes a presets automatic allocation zero',function()
    reset(25,20000); ns.UsePreset('mount-first')
    equal(ns.db.goals[1].initialCopper,0); equal(ns.db.goals[1].savedCopper,0)
end)
local function expenseButton(spellID)
    for _,button in ipairs(ns.planningFrame.expenseButtons) do
        if button:IsShown() and button.expense.spellID==spellID then return button end
    end
    error('Visible ability icon not found: ' .. spellID)
end
local function openClassPlanner(onApply,targetLevel)
    local g=goal(1000000,targetLevel or 40); g.includeClassTraining=true
    ns.EnableItemPlanning(g); ns.OpenTrainingPlanner(g,onApply or function() end)
    return g
end
test('new mount goals include class training and open its dedicated planner from the editor',function()
    reset(); ns.UsePreset('mount-first'); click(ns.ui.editor,'Class training')
    equal(ns.planningFrame.width,420); equal(ns.planningFrame.height,520)
    equal(ns.planningFrame.classMode,true)
    equal(ns.planningFrame.goalName.text,'Goal: ' .. ns.FindPreset('mount-first').name); equal(ns.planningFrame.manual:IsShown(),false)
    for _,button in ipairs(ns.planningFrame.expenseButtons) do
        if button:IsShown() then equal(button.expense.source,'class') end
    end
    click(ns.planningFrame,'Close')
    local g=ns.db.goals[1]; equal(g.includeClassTraining,true); equal(g.targetCopper,1000000)
    assert(#g.expenses>50); equal(ns.TrainingRunway(),30000)
    equal(ns.ui.planRows[26].training.text,ns.MoneyText(30000))
end)
test('closing class training preserves changes saved by the icon click',function()
    local previous=#ns.db.goals[1].expenses
    click(ns.ui.editor,'Class training')
    local button=expenseButton(6178); button.scripts.OnClick(button,'LeftButton'); equal(ns.TrainingRunway(),20000)
    assert(ns.planningFrame:IsShown()); click(ns.planningFrame,'Close')
    equal(ns.db.goals[1].includeClassTraining,true); equal(#ns.db.goals[1].expenses,previous)
    equal(ns.TrainingRunway(),20000)
    ns.UsePreset('mount-first'); click(ns.ui.editor,'Class training'); equal(expenseButton(6178).expense.selected,false)
    click(ns.planningFrame,'Close')
end)
test('goal progress in the UI refreshes after new actual income',function()
    local g=ns.db.goals[1]; local previous=g.savedCopper; money=money+10000; ns.ObserveMoney()
    assert(g.savedCopper>previous); assert(ns.ui.progress.text:find(ns.MoneyText(g.savedCopper),1,true))
end)
test('invalid field blur preserves the last saved goal and reports an error',function()
    local previous=ns.db.goals[1].targetLevel
    blur(ns.ui.level,''); assert(ns.ui.error.text:find('target level',1,true)); equal(ns.db.goals[1].targetLevel,previous)
    blur(ns.ui.level,'40')
    local amount=ns.db.goals[1].targetCopper
    blur(ns.ui.amount[2],'100'); equal(ns.db.goals[1].targetCopper,amount); assert(ns.ui.error.text~='')
    blur(ns.ui.amount[2],'0')
end)
test('every new preset and custom goal includes eligible unlearned class training by default',function()
    reset()
    for _,preset in ipairs(ns.Presets) do
        local g=ns.NewPresetGoal(preset.id); equal(g.includeClassTraining,true); ns.PrepareGoal(g)
        for _,entry in ipairs(g.expenses) do
            if entry.source=='class' and not entry.paid and entry.eligible then equal(entry.selected,true) end
        end
    end
    ns.ui.name:SetText(''); click(ns.ui,'New'); ns.ui.amount[1]:SetText('1'); blur(ns.ui.name,'Custom goal')
    click(ns.ui.editor,'Class training'); equal(ns.planningFrame.classMode,true)
    for _,button in ipairs(ns.planningFrame.expenseButtons) do
        if button:IsShown() and not button.expense.paid and button.expense.eligible then equal(button.expense.selected,true) end
    end
    click(ns.planningFrame,'Close')
    equal(ns.db.goals[1].includeClassTraining,true)
end)
test('class icon clicks autosave immediately while preserving the separate main budget',function()
    reset(); ns.UsePreset('mount-first')
    equal(ns.db.goals[1].planMode,nil); equal(ns.TrainingRunway(),30000)
    click(ns.ui.editor,'Class training'); local button=expenseButton(6178); button.scripts.OnClick(button,'LeftButton')
    equal(ns.TrainingRunway(),20000); equal(ns.ui.planRows[26].training.text,ns.MoneyText(20000))
    assert(ns.ui.amount[1]:IsEnabled()); equal(ns.ui.amount[1].text,'100')
    equal(ns.db.goals[1].planMode,nil); equal(ns.db.goals[1].targetCopper,1000000)
    assert(ns.planningFrame:IsShown()); click(ns.planningFrame,'Close')
end)
test('main fields autosave without closing training or being reverted by later icon clicks',function()
    reset(); ns.UsePreset('mount-first'); click(ns.ui.editor,'Class training')
    blur(ns.ui.name,'My mount fund'); blur(ns.ui.level,'38')
    assert(ns.planningFrame:IsShown()); equal(ns.db.goals[1].name,'My mount fund'); equal(ns.db.goals[1].targetLevel,38)
    local button=expenseButton(6178); button.scripts.OnClick(button,'LeftButton')
    assert(ns.planningFrame:IsShown()); equal(ns.db.goals[1].name,'My mount fund'); equal(ns.db.goals[1].targetLevel,38)
    equal(ns.TrainingRunway(),20000); click(ns.planningFrame,'Close')
end)
test('field edits and reopened windows never allocate initial money a second time',function()
    reset(); ns.UsePreset('mount-first'); local initial=ns.db.goals[1].savedCopper
    for index=1,3 do
        blur(ns.ui.name,'Mount ' .. index); blur(ns.ui.level,tostring(40+index))
        ns.ui.curve.scripts.OnClick(ns.ui.curve,'LeftButton')
        click(ns.ui.editor,'Class training'); click(ns.planningFrame,'Close'); ns.UsePreset('mount-first')
        equal(ns.db.goals[1].savedCopper,initial); equal(ns.db.goals[1].initialCopper,initial)
    end
    money=money+10000; ns.ObserveMoney(); local earned=ns.db.goals[1].savedCopper
    blur(ns.ui.name,'Mount with earnings'); equal(ns.db.goals[1].savedCopper,earned)
    equal(ns.db.goals[1].initialCopper,initial)
end)
test('a custom goal autosaves its name and seeds automatic allocation only when first given a budget',function()
    reset(); ns.ui.name:SetText(''); click(ns.ui,'New'); blur(ns.ui.name,''); equal(#ns.db.goals,0)
    blur(ns.ui.name,'New custom goal'); equal(#ns.db.goals,1); equal(ns.db.goals[1].name,'New custom goal')
    equal(ns.db.goals[1].savedCopper,0); blur(ns.ui.amount[1],'2')
    equal(ns.db.goals[1].targetCopper,20000); equal(ns.db.goals[1].savedCopper,9741)
    blur(ns.ui.amount[1],'3'); equal(ns.db.goals[1].savedCopper,9741)
    for _,control in ipairs(controls) do
        if control.parent==ns.ui and control.text=='Save goal' then error('A Save button is still present') end
    end
end)
test('existing goals keep disabled training and previously excluded ranks',function()
    reset(); local g=goal(); g.presetID='mount-first'; g.includeClassTraining=false
    ns.db.goals={g}; ns.UsePreset('mount-first'); blur(ns.ui.name,'Existing mount')
    equal(ns.db.goals[1].includeClassTraining,false)
    g=ns.db.goals[1]; g.includeClassTraining=true; ns.SyncExpenses(g)
    for _,entry in ipairs(g.expenses) do if entry.spellID==6178 then entry.selected=false end end
    ns.UsePreset('mount-first'); click(ns.ui.editor,'Class training')
    equal(expenseButton(6178).expense.selected,false); click(ns.planningFrame,'Close')
    equal(ns.TrainingRunway(),20000)
end)
test('generic goal expenses show the main goal and keep class ranks in their dedicated popup',function()
    reset(); local g=goal(); g.name='Mount fund'; g.includeClassTraining=true; ns.SyncExpenses(g); ns.EnableItemPlanning(g)
    ns.OpenExpensePlanner(g,function() end)
    equal(ns.planningFrame.classMode,false); equal(ns.planningFrame.goalName.text,'Goal: Mount fund')
    equal(ns.planningFrame.manual:IsShown(),true)
    local count=0
    for _,button in ipairs(ns.planningFrame.expenseButtons) do
        if button:IsShown() then count=count+1; assert(button.expense.source~='class') end
    end
    equal(count,1)
    click(ns.planningFrame,'Close'); ns.OpenTrainingPlanner(g,function() end)
    equal(ns.planningFrame.classMode,true); equal(ns.planningFrame.manual:IsShown(),false)
    for _,button in ipairs(ns.planningFrame.expenseButtons) do if button:IsShown() then equal(button.expense.source,'class') end end
end)

test('clicking a spell picture immediately reports a saved copy of all rank choices',function()
    reset(); local updated
    local original=openClassPlanner(function(g) updated=g end)
    local button=expenseButton(6178)
    equal(button.kind,'Button'); equal(button.icon.texture,'spell-icon:6178'); equal(button.icon.desaturated,false)
    button.scripts.OnClick(button,'LeftButton')
    button=expenseButton(6178); equal(button.expense.selected,false); equal(button.icon.desaturated,true)
    equal(#button.expenses,3)
    for _,entry in ipairs(button.expenses) do equal(entry.selected,false) end
    equal(ns.TrainingByLevel(original)[26],30000)
    assert(updated); equal(ns.TrainingByLevel(updated)[26],20000); equal(updated.targetCopper,1000000)
    local firstSaved=updated
    click(ns.planningFrame,'Close'); ns.OpenTrainingPlanner(updated,function(g) updated=g end)
    button=expenseButton(6178); equal(button.expense.selected,false); equal(button.icon.desaturated,true)
    button.scripts.OnClick(button,'LeftButton')
    button=expenseButton(6178); equal(button.expense.selected,true); equal(button.icon.desaturated,false)
    for _,entry in ipairs(button.expenses) do equal(entry.selected,true) end
    equal(ns.TrainingByLevel(updated)[26],30000); equal(ns.TrainingByLevel(firstSaved)[26],20000)
    click(ns.planningFrame,'Close')
    equal(ns.TrainingByLevel(updated)[26],30000)
end)
test('hover shows the native tooltip for the exact spell rank even when excluded',function()
    reset(); openClassPlanner()
    local button=expenseButton(6178); button.scripts.OnClick(button,'LeftButton')
    button=expenseButton(6178); button.scripts.OnEnter(button)
    equal(GameTooltip.spellID,6178); equal(GameTooltip.owner,button); equal(GameTooltip:IsShown(),true)
    assert(table.concat(GameTooltip.lines,'\n'):find(ns.MoneyText(10000),1,true))
    button.scripts.OnLeave(button); equal(GameTooltip:IsShown(),false)
end)
test('learned and ineligible ability pictures stay grey and hoverable without toggling',function()
    reset(); knownSpells[6178]=true; openClassPlanner(nil,44)
    for _,spellID in ipairs({6178,20616}) do
        local button=expenseButton(spellID); local selected=button.expense.selected
        equal(button.icon.desaturated,true)
        button.scripts.OnClick(button,'LeftButton'); button=expenseButton(spellID)
        equal(button.expense.selected,selected); equal(button.icon.desaturated,true)
        button.scripts.OnEnter(button); equal(GameTooltip.spellID,spellID); equal(GameTooltip:IsShown(),true)
        button.scripts.OnLeave(button)
    end
end)
test('class training shows one icon per ability and excludes every rank across levels',function()
    reset(); local updated; local original=openClassPlanner(function(g) updated=g end,60)
    local abilities={}
    for _,button in ipairs(ns.planningFrame.expenseButtons) do
        if button:IsShown() then
            assert(not abilities[button.expense.name],'Repeated ability icon: ' .. button.expense.name)
            abilities[button.expense.name]=true
            equal(button.rank,nil)
        end
    end
    local charge=expenseButton(6178); equal(charge.expense.name,'Charge'); equal(#charge.expenses,3)
    equal(charge.level.text,'Lv 26'); charge.scripts.OnClick(charge,'LeftButton')
    local before,after=ns.TrainingByLevel(original),ns.TrainingByLevel(updated)
    equal(before[26]-after[26],10000); equal(before[46]-after[46],36000)
    for _,entry in ipairs(updated.expenses) do if entry.source=='class' and entry.name=='Charge' then equal(entry.selected,false) end end
end)
test('the icon grid fits eight spaced columns and wraps without individual checkboxes',function()
    reset(); local g=goal(10000,40); g.planMode='items'
    for index=1,10 do
        g.expenses[index]={key='manual:' .. index,name=string.format('Expense %02d',index),level=40,copper=1000,source='manual',selected=true}
    end
    local updated; ns.OpenExpensePlanner(g,function(value) updated=value end)
    local buttons=ns.planningFrame.expenseButtons
    for index=1,10 do
        local button=buttons[index]; assert(button:IsShown()); equal(button.kind,'Button')
        equal(button.width,36); equal(button.height,36)
        equal(button.point[2],6+((index-1)%8)*44); equal(button.point[3],-math.floor((index-1)/8)*54-2)
        assert(button.point[2]+button.width<=ns.planningFrame.content.width)
        equal(button.level.text,'Lv 40')
    end
    assert(ns.planningFrame.content.height>=108)
    for _,control in ipairs(controls) do
        local parent=control.parent
        while parent and parent~=ns.planningFrame.content do parent=parent.parent end
        if parent then assert(control.kind~='CheckButton','Individual expense still uses a checkbox') end
    end
    equal(ns.planningFrame.classMode,false)
    buttons[1].scripts.OnClick(buttons[1],'LeftButton')
    equal(updated.targetCopper,9000); equal(M.ExpenseTotal(updated),9000)
end)
test('manual expense fields autosave on blur and update the existing cost without Add or Apply',function()
    reset(); local g=goal(1000,40); g.planMode='items'
    g.expenses={{key='manual:seed',name='Existing cost',level=40,copper=1000,selected=true,source='manual'}}
    local updated; ns.OpenExpensePlanner(g,function(value) updated=value end)
    ns.planningFrame.expenseName:SetText('Repairs'); ns.planningFrame.expenseAmount[2]:SetText('10')
    blur(ns.planningFrame.expenseName)
    assert(updated); equal(updated.targetCopper,2000); equal(#updated.expenses,2)
    blur(ns.planningFrame.expenseAmount[2],'5'); equal(updated.targetCopper,1500); equal(#updated.expenses,2)
    local lastValid=updated; blur(ns.planningFrame.expenseLevel,'100')
    equal(updated,lastValid); assert(ns.planningFrame.error.text~='')
    click(ns.planningFrame,'Close'); equal(updated.targetCopper,1500)
end)
test('quoted profession expenses keep their native hyperlink tooltip when no spell ID is available',function()
    reset(); local g=goal(1000,40); g.planMode='items'
    g.expenses={{key='profession:recipe',name='Recipe',level=40,copper=1000,selected=true,source='profession',icon='recipe-picture',link='item:555'}}
    ns.OpenExpensePlanner(g,function() end)
    local button=ns.planningFrame.expenseButtons[1]
    equal(button.icon.texture,'recipe-picture'); button.scripts.OnEnter(button)
    equal(GameTooltip.link,'item:555'); equal(GameTooltip.owner,button)
    button.scripts.OnLeave(button); equal(GameTooltip:IsShown(),false)
end)

local merchant=frame(); merchant.selectedTab=1; MerchantFrame=merchant
local control=frame(merchant); control.id=1; control.scripts.OnClick=execute; control.SplitStack=execute; MerchantItem1ItemButton=control
C_MerchantFrame={GetItemInfo=function() return {name='Supplies',price=20000,stackCount=5} end}
GetMerchantItemLink=function() return 'item:supplies' end
GetNumBuybackItems=function() return 0 end
local dialog=frame(); dialog.itemID=100; dialog.quantity=2; dialog.PriceFrame={GetAmount=function() return 20000 end}
dialog.BuyNowButton=frame(dialog); dialog.BuyNowButton.scripts.OnClick=execute
AuctionHouseFrame=frame(); AuctionHouseFrame.BuyDialog=dialog
local quoteTime=10
C_AuctionHouse={GetQuoteDurationRemaining=function() return quoteTime end}
ns.InstallGuards()
test('vendor quantity guards use the whole stack price and are installed once',function()
    reset(); local g=goal(); g.savedCopper=30000; ns.db.goals={g}; executions=0
    ns.InstallGuards(); control.scripts.OnClick(control,'RightButton'); equal(executions,0); equal(ns.pending.action.cost,20000)
    ns.ConfirmPurchase(); equal(executions,1)
    elapsed=elapsed+120
    executions=0; control.SplitStack(control,10); equal(ns.pending.action.cost,40000); ns.CancelPurchase(); equal(executions,0)
end)
test('expired commodity quotes cannot complete a pending purchase',function()
    reset(); local g=goal(); g.savedCopper=30000; ns.db.goals={g}; executions=0
    quoteTime=10; dialog.BuyNowButton.scripts.OnClick(dialog.BuyNowButton,'LeftButton'); equal(executions,0)
    quoteTime=0; ns.ConfirmPurchase(); equal(executions,0)
end)

local function advanceToast(seconds)
    elapsed=elapsed+seconds
    local toast=ns.levelUpToast
    if toast and toast.scripts.OnUpdate then toast.scripts.OnUpdate(toast,seconds) end
end
local function shownToast()
    assert(ns.levelUpToast and ns.levelUpToast:IsShown(),'Expected a visible goal toast')
    assert(ns.levelUpToast.summary,'Expected an actual goal snapshot')
    return ns.levelUpToast
end
test('level-up summaries omit paused goals and show two soonest deadlines with a remaining count',function()
    reset(25,100000)
    local later,near,tie,paused=goal(10000,60),goal(10000,30),goal(10000,30),goal(10000,26)
    later.name,near.name,tie.name,paused.name='Later','Near','Same deadline','Paused'; paused.active=false
    ns.db.goals={later,near,tie,paused}
    local summary=ns.BuildLevelUpSummary(26)
    equal(summary.level,26); equal(summary.activeCount,3); equal(summary.remainingCount,1); equal(#summary.goals,2)
    equal(summary.goals[1].name,'Near'); equal(summary.goals[2].name,'Same deadline')
    equal(ns.db.goals[1],later); equal(ns.db.goals[2],near)
    for _,g in ipairs(ns.db.goals) do g.active=false end
    equal(ns.BuildLevelUpSummary(26),nil)
end)
test('level-up progress uses real savings and copies values without allocating imaginary income',function()
    reset(); local g=goal(); g.savedCopper=143412; ns.db.goals={g}
    local summary=ns.BuildLevelUpSummary(26); local row=summary.goals[1]
    equal(summary.balance,48705); equal(row.saved,48705); equal(g.savedCopper,143412)
    equal(row.percent,4.8705); equal(money,48705); equal(ns.lastMoney,48705)
    equal(next(ns.db.earnings),nil)
    g.name='Renamed later'; g.savedCopper=10
    equal(row.name,'Goal'); equal(row.saved,48705)
end)
test('level-up statuses distinguish ahead behind on track and fully saved goals',function()
    for _,case in ipairs({{7000,'ahead',1000,0},{3000,'behind',0,3000},{6000,'ontrack',0,0},{10000,'complete',4000,0}}) do
        reset(); local g=goal(10000,30); g.curve=1; g.savedCopper=case[1]; ns.db.goals={g}
        local row=ns.BuildLevelUpSummary(28).goals[1]
        equal(row.expected,6000); equal(row.status,case[2]); equal(row.ahead,case[3]); equal(row.behind,case[4])
    end
end)
test('training-only goal progress uses that levels funded runway rather than claiming completion',function()
    reset(25,1000000); local g=goal(0,60); g.includeClassTraining=true; ns.SyncExpenses(g); ns.db.goals={g}
    local row=ns.BuildLevelUpSummary(26).goals[1]
    equal(row.training,true); equal(row.trainingComplete,true); equal(row.status,'ontrack')
    local training=ns.TrainingRunway(nil,nil,nil,26)
    equal(row.target,training); equal(row.saved,row.target)
    assert(row.target>30000,'Level 26 must include the level-28 training costs')
    equal(g.savedCopper,0)
end)
test('level-up events use their new level while UnitLevel is stale and ignore duplicate events',function()
    reset(); local g=goal(); g.savedCopper=9741; ns.db.goals={g}
    eventFrame.scripts.OnEvent(nil,'PLAYER_LEVEL_UP','26'); equal(level,25)
    advanceToast(0.6)
    local toast=shownToast(); local snapshot=toast.summary
    equal(snapshot.level,26); equal(snapshot.goals[1].saved,9741)
    equal(snapshot.goals[1].expected,M.TargetAtLevel(g,26)); equal(g.savedCopper,9741)
    eventFrame.scripts.OnEvent(nil,'PLAYER_LEVEL_UP',26); advanceToast(0.6)
    equal(toast.summary,snapshot); equal(g.savedCopper,9741); equal(next(ns.db.earnings),nil)
end)
test('successive level-up events coalesce into one toast for the newest level',function()
    reset(); ns.db.goals={goal()}
    eventFrame.scripts.OnEvent(nil,'PLAYER_LEVEL_UP',26)
    eventFrame.scripts.OnEvent(nil,'PLAYER_LEVEL_UP',27)
    advanceToast(0.6); equal(shownToast().summary.level,27)
    local snapshot=ns.levelUpToast.summary
    eventFrame.scripts.OnEvent(nil,'PLAYER_LEVEL_UP',26); advanceToast(0.6)
    equal(ns.levelUpToast.summary,snapshot)
    local frame=ns.levelUpToast
    eventFrame.scripts.OnEvent(nil,'PLAYER_LEVEL_UP',28); advanceToast(0.6)
    equal(ns.levelUpToast,frame); equal(shownToast().summary.level,28)
end)
test('notification defaults are enabled for a new database while a saved disabled preference persists',function()
    reset(); local previous=GoldEnvelopeDB
    GoldEnvelopeDB={goals={}}; eventFrame.scripts.OnEvent(nil,'ADDON_LOADED','GoldEnvelope')
    equal(ns.db.levelUpToasts,true)
    GoldEnvelopeDB={goals={},levelUpToasts=false}; eventFrame.scripts.OnEvent(nil,'ADDON_LOADED','GoldEnvelope')
    equal(ns.db.levelUpToasts,false); GoldEnvelopeDB=previous
end)
test('login seeds notification tracking without showing an old level-up toast',function()
    reset(); ns.db.goals={goal()}; ns.sessionStarted=false
    eventFrame.scripts.OnEvent(nil,'PLAYER_LOGIN')
    equal(ns.lastLevelUpEvent,25); assert(not ns.levelUpToast:IsShown())
    eventFrame.scripts.OnEvent(nil,'PLAYER_LEVEL_UP',25); advanceToast(0.6)
    assert(not ns.levelUpToast:IsShown())
end)
test('normal level-up events without active goals never show a notification',function()
    reset(); eventFrame.scripts.OnEvent(nil,'PLAYER_LEVEL_UP',26); advanceToast(0.6)
    assert(not ns.levelUpToast:IsShown())
    local paused=goal(); paused.active=false; ns.db.goals={paused}
    eventFrame.scripts.OnEvent(nil,'PLAYER_LEVEL_UP',27); advanceToast(0.6)
    assert(not ns.levelUpToast:IsShown()); equal(sounds,0)
end)
test('level-up toasts never capture clicks keyboard input or play sound and fade away automatically',function()
    reset(); ns.db.goals={goal()}; ns.QueueLevelUpToast(26); advanceToast(0.6)
    local toast=shownToast()
    equal(toast.mouseEnabled,false); equal(toast.keyboardEnabled,false)
    equal(toast.scripts.OnClick,nil); equal(toast.scripts.OnKeyDown,nil)
    for _,control in ipairs(controls) do
        local parent=control.parent
        while parent and parent~=toast do parent=parent.parent end
        if parent and control.kind then
            equal(control.mouseEnabled,false,'Toast child mouse input'); equal(control.keyboardEnabled,false,'Toast child keyboard input')
        end
    end
    advanceToast(0.35); assert(toast:GetAlpha()>0)
    advanceToast(7); equal(toast:IsShown(),false); equal(sounds,0)
end)
test('combat defers a toast and shows a fresh actual-wallet snapshot after combat',function()
    reset(); local g=goal(); g.savedCopper=30000; ns.db.goals={g}
    inCombat=true; ns.QueueLevelUpToast(26); advanceToast(1)
    assert(not ns.levelUpToast:IsShown())
    level=26; money=7000; ns.ObserveMoney(); equal(g.savedCopper,7000)
    inCombat=false; eventFrame.scripts.OnEvent(nil,'PLAYER_REGEN_ENABLED'); advanceToast(0.6)
    local summary=shownToast().summary
    equal(summary.level,26); equal(summary.balance,7000); equal(summary.goals[1].saved,7000)
end)
test('combat-delayed progress includes real earnings received after the level-up event',function()
    reset(); local g=goal(); g.savedCopper=9741; ns.db.goals={g}; inCombat=true
    eventFrame.scripts.OnEvent(nil,'PLAYER_LEVEL_UP',26)
    level=26; money=money+10000; eventFrame.scripts.OnEvent(nil,'PLAYER_MONEY')
    equal(g.savedCopper,19741)
    inCombat=false; eventFrame.scripts.OnEvent(nil,'PLAYER_REGEN_ENABLED'); advanceToast(0.6)
    equal(shownToast().summary.goals[1].saved,19741); equal(ns.db.earnings[26].income,10000)
end)
test('entering combat while a toast is queued hides it and keeps the newest level for later',function()
    reset(); ns.db.goals={goal()}; ns.QueueLevelUpToast(26)
    inCombat=true; advanceToast(0.6); assert(not ns.levelUpToast:IsShown())
    ns.QueueLevelUpToast(27); inCombat=false; ns.FlushLevelUpToast(); advanceToast(0.6)
    equal(shownToast().summary.level,27)
end)
test('the toasts setting can hide and disable pending notifications without losing level tracking',function()
    reset(); ns.db.goals={goal()}; inCombat=true
    eventFrame.scripts.OnEvent(nil,'PLAYER_LEVEL_UP',26)
    SlashCmdList.GOLDENVELOPE('toasts'); equal(ns.db.levelUpToasts,false)
    inCombat=false; eventFrame.scripts.OnEvent(nil,'PLAYER_REGEN_ENABLED'); advanceToast(0.6)
    assert(not ns.levelUpToast:IsShown())
    eventFrame.scripts.OnEvent(nil,'PLAYER_LEVEL_UP',27); advanceToast(0.6)
    equal(ns.lastLevelUpEvent,27); assert(not ns.levelUpToast:IsShown())
    SlashCmdList.GOLDENVELOPE('toasts'); equal(ns.db.levelUpToasts,true)
    eventFrame.scripts.OnEvent(nil,'PLAYER_LEVEL_UP',27); advanceToast(0.6)
    assert(not ns.levelUpToast:IsShown())
    eventFrame.scripts.OnEvent(nil,'PLAYER_LEVEL_UP',28); advanceToast(0.6)
    equal(shownToast().summary.level,28)
end)
test('testtoast previews actual progress immediately even when level-up notifications are disabled',function()
    reset(); local g=goal(); g.savedCopper=143412; ns.db.goals={g}; ns.db.levelUpToasts=false
    SlashCmdList.GOLDENVELOPE('testtoast')
    local summary=shownToast().summary
    equal(summary.preview,true); equal(summary.level,25); equal(summary.goals[1].saved,48705)
    equal(g.savedCopper,143412); equal(money,48705); equal(ns.lastMoney,48705); equal(next(ns.db.earnings),nil)
    assert(table.concat(messages,'\n'):find('Preview only',1,true))
end)
test('testtoast with no goals shows a clearly marked example without creating or funding a goal',function()
    reset(); SlashCmdList.GOLDENVELOPE('testtoast')
    local toast=shownToast(); equal(toast.summary.preview,true)
    assert(toast.title.text:lower():find('preview',1,true)); equal(#ns.db.goals,0)
    equal(money,48705); equal(ns.lastMoney,48705); equal(next(ns.db.earnings),nil)
end)
print(tests .. ' tests passed')
