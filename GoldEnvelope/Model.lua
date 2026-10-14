local _, ns = ...
local Model = {}
ns.Model = Model

Model.MAX_LEVEL = 60
Model.MAX_COPPER = 1000000000000

local function integer(value, minimum, maximum)
    return type(value) == "number" and value == math.floor(value)
        and value >= minimum and value <= maximum
end

function Model.ParseCoins(gold, silver, copper)
    local parts = { gold, silver, copper }
    for i = 1, 3 do
        local text = tostring(parts[i] or ""):match("^%s*(.-)%s*$")
        if text == "" then text = "0" end
        if not text:match("^%d+$") then return nil, "Enter whole, non-negative coin amounts." end
        parts[i] = tonumber(text)
        local maximum = i == 1 and Model.MAX_COPPER / 10000 or 99
        if not integer(parts[i], 0, maximum) then
            return nil, i == 1 and "Gold amount is too large." or "Silver and copper must be from 0 to 99."
        end
    end
    local amount = parts[1] * 10000 + parts[2] * 100 + parts[3]
    if amount > Model.MAX_COPPER then return nil, "Amount is too large." end
    return amount
end

function Model.SplitCoins(amount)
    amount = math.max(0, math.floor(amount or 0))
    return math.floor(amount / 10000), math.floor(amount / 100) % 100, amount % 100
end

function Model.FormatCoins(amount)
    local gold, silver, copper = Model.SplitCoins(amount)
    return string.format("%dg %ds %dc", gold, silver, copper)
end

function Model.CopyGoal(goal)
    local result = {}
    for key, value in pairs(goal) do
        if key ~= "milestones" and key ~= "expenses" then result[key] = value end
    end
    result.milestones, result.expenses = {}, {}
    for level, amount in pairs(goal.milestones or {}) do result.milestones[level] = amount end
    for index, expense in ipairs(goal.expenses or {}) do
        result.expenses[index] = {}
        for key, value in pairs(expense) do result.expenses[index][key] = value end
    end
    return result
end

function Model.ExpenseTotal(goal)
    local total = 0
    for _, expense in ipairs(goal.expenses or {}) do
        if expense.selected and not expense.paid and expense.source ~= "class" and expense.level <= goal.targetLevel then
            total = total + (expense.copper or 0)
        end
    end
    return total
end

function Model.ValidateGoal(goal)
    if type(goal) ~= "table" or type(goal.name) ~= "string" or not goal.name:match("%S") then
        return nil, "Give your goal a name."
    end
    if #goal.name > 60 then return nil, "Use a name of 60 characters or fewer." end
    if not integer(goal.targetLevel, 2, Model.MAX_LEVEL) then
        return nil, "Target level must be from 2 to " .. Model.MAX_LEVEL .. "."
    end
    if not integer(goal.targetCopper, (goal.planMode == "items" or goal.includeClassTraining) and 0 or 1, Model.MAX_COPPER) then
        return nil, "Set a positive savings amount."
    end
    if not integer(goal.curve, 0, 4) then return nil, "Choose an income-based or custom savings curve." end
    if goal.startLevel and not integer(goal.startLevel, 1, Model.MAX_LEVEL) then return nil, "Invalid start level." end
    if goal.initialCopper and not integer(goal.initialCopper, 0, Model.MAX_COPPER) then return nil, "Invalid initial investment." end
    if goal.savedCopper and not integer(goal.savedCopper, 0, Model.MAX_COPPER) then return nil, "Invalid saved balance." end
    if goal.planMode == "items" then
        if type(goal.expenses) ~= "table" then return nil, "Invalid expense plan." end
        local keys = {}
        for _, expense in ipairs(goal.expenses) do
            if type(expense) ~= "table" or type(expense.key) ~= "string" or keys[expense.key]
                or type(expense.name) ~= "string" or not expense.name:match("%S")
                or not integer(expense.level, 1, Model.MAX_LEVEL)
                or (expense.copper ~= nil and not integer(expense.copper, 0, Model.MAX_COPPER)) then
                return nil, "Each expense needs a name, a unique key, a valid level and a whole coin amount."
            end
            keys[expense.key] = true
        end
        if Model.ExpenseTotal(goal) > Model.MAX_COPPER then return nil, "Total expense amount is too large." end
        return true
    end
    if type(goal.milestones) ~= "table" then return nil, "Invalid milestones." end
    for level, amount in pairs(goal.milestones) do
        if not integer(level, (goal.startLevel or 1) + 1, goal.targetLevel - 1)
            or not integer(amount, 0, goal.targetCopper) then
            return nil, "Milestones must fall before the target level and within the final amount."
        end
    end
    local previous = 0
    for _, point in ipairs(Model.Points(goal)) do
        if point.copper < previous then return nil, "Saved amounts must increase or stay equal as levels rise." end
        previous = point.copper
    end
    return true
end

function Model.Points(goal)
    local points = { { level = goal.startLevel or 1, copper = goal.initialCopper or 0 } }
    for level, copper in pairs(goal.milestones) do
        points[#points + 1] = { level = level, copper = copper }
    end
    points[#points + 1] = { level = goal.targetLevel, copper = goal.targetCopper }
    table.sort(points, function(a, b) return a.level < b.level end)
    return points
end

function Model.Fraction(startLevel, endLevel, level, curve)
    if endLevel <= startLevel then return level >= startLevel and 1 or 0 end
    if level <= startLevel then return 0 end
    if level >= endLevel then return 1 end
    if curve ~= 0 then return ((level - startLevel) / (endLevel - startLevel)) ^ curve end
    local earned, total = 0, 0
    for step = startLevel + 1, endLevel do
        local weight = ns.IncomeWeights and ns.IncomeWeights[step] or step ^ 3
        total = total + weight
        if step <= level then earned = earned + weight end
    end
    return total > 0 and earned / total or 0
end

function Model.TargetAtLevel(goal, level)
    local start = goal.startLevel or 1
    if level < start then return 0 end
    local initial = math.min(goal.initialCopper or 0, goal.targetCopper)
    if goal.planMode == "items" then
        local total, weighted = Model.ExpenseTotal(goal), 0
        for _, expense in ipairs(goal.expenses) do
            if expense.selected and not expense.paid and expense.source ~= "class"
                and expense.level <= goal.targetLevel and expense.copper then
                weighted = weighted + expense.copper * Model.Fraction(start, expense.level, level, goal.curve)
            end
        end
        if total == 0 then return 0 end
        return math.floor(initial + (total - initial) * weighted / total)
    end
    if level == start and goal.targetLevel > start then return initial end
    if level >= goal.targetLevel then return goal.targetCopper end
    local points = Model.Points(goal)
    for i = 2, #points do
        local left, right = points[i - 1], points[i]
        if level <= right.level then
            return math.floor(left.copper + (right.copper - left.copper)
                * Model.Fraction(left.level, right.level, level, goal.curve))
        end
    end
    return initial
end

function Model.GoalProgress(goal, level)
    local saved = math.min(goal.savedCopper or 0, goal.targetCopper)
    local expected = Model.TargetAtLevel(goal, level)
    return { saved = saved, expected = expected, target = goal.targetCopper,
        ahead = math.max(0, saved - expected), behind = math.max(0, expected - saved),
        percent = goal.targetCopper > 0 and math.min(100, saved / goal.targetCopper * 100) or 100 }
end

function Model.Reconcile(goals, balance)
    local left = math.max(0, balance)
    for _, goal in ipairs(goals) do
        if goal.active then
            goal.savedCopper = math.min(goal.savedCopper or 0, goal.targetCopper, left)
            left = left - goal.savedCopper
        else goal.savedCopper = 0 end
    end
end

function Model.Budget(goals, level, balance, trainingDue)
    local saved, expected = 0, 0
    for _, goal in ipairs(goals) do
        if goal.active then
            saved = saved + math.min(goal.savedCopper or 0, goal.targetCopper)
            expected = expected + Model.TargetAtLevel(goal, level)
        end
    end
    saved = math.min(balance, saved)
    trainingDue = math.max(0, trainingDue or 0)
    local trainingFunded = math.min(math.max(0, balance - saved), trainingDue)
    return { balance = balance, saved = saved, expected = expected,
        ahead = math.max(0, saved - expected), behind = math.max(0, expected - saved),
        trainingDue = trainingDue, trainingFunded = trainingFunded,
        trainingShortfall = trainingDue - trainingFunded, reserved = saved + trainingFunded }
end

function Model.FundGoals(goals, amount, balance, trainingDue)
    Model.Reconcile(goals, balance)
    local budget = Model.Budget(goals, 1, balance, trainingDue)
    local left = math.min(amount, math.max(0, balance - budget.saved - (trainingDue or 0)))
    local ordered = {}
    for _, goal in ipairs(goals) do if goal.active then ordered[#ordered + 1] = goal end end
    table.sort(ordered, function(a, b) return a.targetLevel < b.targetLevel end)
    for _, goal in ipairs(ordered) do
        local addition = math.min(left, math.max(0, goal.targetCopper - (goal.savedCopper or 0)))
        goal.savedCopper = (goal.savedCopper or 0) + addition
        left = left - addition
    end
end

function Model.InitialInvestment(balance, trainingDue, allocated, percent, override, target)
    if balance < trainingDue then return 0 end
    local free = math.max(0, balance - trainingDue - allocated)
    local wanted = override or math.floor(balance * (percent or 20) / 100)
    return math.floor(math.max(0, math.min(wanted, free, target)))
end

function Model.Purchase(goals, level, balance, cost, trainingDue, plannedTraining)
    local budget = Model.Budget(goals, level, balance, trainingDue)
    budget.cost, budget.remaining, budget.affordable = cost, balance - cost, cost <= balance
    local protected = budget.reserved
    if plannedTraining then protected = protected - math.min(cost, budget.trainingFunded) end
    budget.warning = cost > 0 and budget.remaining < protected
    budget.afterSaved = math.min(budget.saved, math.max(0, budget.remaining))
    budget.savingsUsed = budget.saved - budget.afterSaved
    budget.afterShortfall = math.max(0, protected - budget.remaining)
    return budget
end
