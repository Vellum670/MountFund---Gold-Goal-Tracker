unpack = unpack or table.unpack
local ns, tests = {}, 0
local function loadAddon(file) assert(loadfile('GoldEnvelope/' .. file))('GoldEnvelope', ns) end
local function equal(actual, expected, name)
    assert(actual == expected, (name or 'value') .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual))
end
local function test(name, callback) callback(); tests=tests+1; print('PASS ' .. name) end
local level, money, class = 25, 48705, 'WARRIOR'
local elapsed = 1000
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
CreateFrame=function(_,_,parent) return frame(parent) end
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
InCombatLockdown=function() return false end
IsModifiedClick=function() return false end
IsTradeskillTrainer=function() return false end
GetNumTrainerServices=function() return #services end
GetTrainerServiceInfo=function(index)
    local item=services[index]; if not item then return end
    return item.name,item.status or 'available','icon',item.level,item.rank
end
GetTrainerServiceCost=function(index) return services[index] and services[index].cost end
GetTrainerServiceLevelReq=function(index) return services[index] and services[index].level end
C_Timer={After=function(_,callback) callback() end}
C_Trainer={GetTrainerType=function() return 1 end}
Enum={TrainerType={Pet=2}}
DEFAULT_CHAT_FRAME={AddMessage=function(_,message) messages[#messages+1]=message end}
GameTooltip=frame()
hooksecurefunc=function() end
StaticPopup_Show=function() end
loadAddon('Data/IncomeWeights.lua'); loadAddon('Data/ClassTraining.lua'); loadAddon('Model.lua'); loadAddon('Presets.lua')
local names={[33388]='Apprentice Riding',[33391]='Journeyman Riding'}
for _,entries in pairs(ns.ClassTrainingData) do for _,entry in ipairs(entries) do names[entry.spellID]=entry.name end end
C_Spell={GetSpellName=function(id) return names[id] end}
loadAddon('Core.lua')
local eventFrame=controls[#controls]
loadAddon('Training.lua'); loadAddon('UI.lua'); loadAddon('PlanningUI.lua'); loadAddon('Guards.lua')
local M=ns.Model
local function reset(newLevel,newMoney)
    ns.CancelPurchase(); ns.ClosePlanningWindows()
    level,money,class=newLevel or 25,newMoney or 48705,'WARRIOR'
    ns.db={version=2,goals={},trainerCatalog={},warnings=true,earnings={}}
    ns.lastMoney,ns.sessionStarted=money,true
    elapsed,ns.warningCooldownUntil=1000,0
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
test('unchecked class ranks stay excluded when prices refresh',function()
    reset(); local g=goal(); g.includeClassTraining=true; ns.SyncExpenses(g)
    for _,entry in ipairs(g.expenses) do if entry.spellID==6178 then entry.selected=false end end
    equal(ns.TrainingRunway(g),20000)
    services={{name='Charge',rank='Rank 2',level=26,cost=9000}}; ns.CaptureTrainerPrices(); ns.SyncExpenses(g)
    equal(ns.TrainingRunway(g),20000)
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
    reset(); ns.ToggleUI(); equal(ns.ui.width,400); equal(ns.ui.height,500)
    assert(ns.ui.width/344<1.2 and ns.ui.height/446<1.2)
end)
test('new presets begin at the current level and preview a safe initial investment',function()
    reset(); ns.UsePreset('mount-first')
    equal(ns.ui.initialAmount[1]:GetText(),'0'); equal(ns.ui.initialAmount[2]:GetText(),'97'); equal(ns.ui.initialAmount[3]:GetText(),'41')
    equal(ns.ui.planRows[1],nil); assert(ns.ui.planRows[25]:IsShown())
    click(ns.ui,'Save goal'); assert(ns.planningConsent:IsShown()); equal(#ns.db.goals,0)
    click(ns.planningConsent,'Keep simple budget')
    equal(ns.db.goals[1].startLevel,25); equal(ns.db.goals[1].savedCopper,9741)
end)
test('insufficient training cash forces even an overridden investment to zero',function()
    reset(25,20000); ns.UsePreset('mount-first')
    ns.ui.autoInitial=false; ns.ui.initialAmount[1]:SetText('1'); ns.ui.initialAmount[2]:SetText('0'); ns.ui.initialAmount[3]:SetText('0')
    click(ns.ui,'Save goal'); click(ns.planningConsent,'Keep simple budget')
    equal(ns.db.goals[1].initialCopper,0); equal(ns.db.goals[1].savedCopper,0)
end)
test('Class training checkbox loads the class catalog and coexists with a mount',function()
    reset(); ns.UsePreset('mount-first'); click(ns.ui,'Save goal'); click(ns.planningConsent,'Choose expenses')
    equal(ns.planningFrame.width,420); equal(ns.planningFrame.height,520)
    ns.planningFrame.classTraining:SetChecked(true); ns.planningFrame.classTraining.scripts.OnClick(ns.planningFrame.classTraining)
    click(ns.planningFrame,'Apply choices'); click(ns.ui,'Save goal')
    local g=ns.db.goals[1]; equal(g.includeClassTraining,true); equal(g.targetCopper,1000000)
    assert(#g.expenses>50); equal(ns.TrainingRunway(),30000)
    equal(ns.ui.planRows[26].training.text,ns.MoneyText(30000))
end)
test('canceling expense selection preserves the stored choices',function()
    local previous=#ns.db.goals[1].expenses
    click(ns.ui.editor,'Choose expenses'); ns.planningFrame.classTraining:SetChecked(false)
    ns.planningFrame.classTraining.scripts.OnClick(ns.planningFrame.classTraining); click(ns.planningFrame,'Cancel')
    click(ns.ui,'Save goal'); equal(ns.db.goals[1].includeClassTraining,true); equal(#ns.db.goals[1].expenses,previous)
end)
test('goal progress in the UI refreshes after new actual income',function()
    local g=ns.db.goals[1]; local previous=g.savedCopper; money=money+10000; ns.ObserveMoney()
    assert(g.savedCopper>previous); assert(ns.ui.progress.text:find(ns.MoneyText(g.savedCopper),1,true))
end)
test('editing a goal to an invalid level returns an error rather than crashing',function()
    ns.ui.level:SetText(''); click(ns.ui,'Save goal'); assert(ns.ui.error.text:find('target level',1,true))
    ns.ui.level:SetText('40')
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
print(tests .. ' tests passed')
