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

function Model.ValidateGoal(goal)
    if type(goal) ~= "table" or type(goal.name) ~= "string" or not goal.name:match("%S") then
        return nil, "Give your goal a name."
    end
    if #goal.name > 60 then return nil, "Use a name of 60 characters or fewer." end
    if not integer(goal.targetLevel, 2, Model.MAX_LEVEL) then
        return nil, "Target level must be from 2 to " .. Model.MAX_LEVEL .. "."
    end
    if not integer(goal.targetCopper, 1, Model.MAX_COPPER) then
        return nil, "Set a positive savings amount."
    end
    if not integer(goal.curve, 1, 4) then return nil, "Savings curve must be from 1 to 4." end
    if type(goal.milestones) ~= "table" then return nil, "Invalid milestones." end
    for level, amount in pairs(goal.milestones) do
        if not integer(level, 2, goal.targetLevel - 1)
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
    local points = { { level = 1, copper = 0 } }
    for level, copper in pairs(goal.milestones) do
        points[#points + 1] = { level = level, copper = copper }
    end
    points[#points + 1] = { level = goal.targetLevel, copper = goal.targetCopper }
    table.sort(points, function(a, b) return a.level < b.level end)
    return points
end

function Model.TargetAtLevel(goal, level)
    if level <= 1 then return 0 end
    if level >= goal.targetLevel then return goal.targetCopper end
    local points = Model.Points(goal)
    for i = 2, #points do
        local left, right = points[i - 1], points[i]
        if level <= right.level then
            local progress = (level - left.level) / (right.level - left.level)
            return math.floor(left.copper + (right.copper - left.copper) * progress ^ goal.curve)
        end
    end
end

function Model.Reserved(goals, level)
    local reserved = 0
    for _, goal in ipairs(goals) do
        if goal.active then reserved = reserved + Model.TargetAtLevel(goal, level) end
    end
    return reserved
end

function Model.Budget(goals, level, balance)
    local reserved = Model.Reserved(goals, level)
    return { balance = balance, reserved = reserved, spendable = math.max(0, balance - reserved),
        shortfall = math.max(0, reserved - balance) }
end

function Model.Purchase(goals, level, balance, cost)
    local budget = Model.Budget(goals, level, balance)
    budget.cost = cost
    budget.remaining = balance - cost
    budget.affordable = cost <= balance
    budget.warning = cost > 0 and budget.remaining < budget.reserved
    budget.afterShortfall = math.max(0, budget.reserved - budget.remaining)
    return budget
end
