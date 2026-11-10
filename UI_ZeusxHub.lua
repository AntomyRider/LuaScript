-- Services.
local playersService = game:GetService("Players")
local replicatedStorage = game:GetService("ReplicatedStorage")
local runService = game:GetService("RunService")
local userInputService = game:GetService("UserInputService")

-- Constants.
local FONT = Enum.Font.Code
local FONT_SIZE = 14
local TITLE_FONT_SIZE = 11
local ROW_HEIGHT = 18
local TITLE_HEIGHT = 14
local INVENTORY_INTERVAL = 2
local COLORS = {
    background = Color3.fromRGB(16, 16, 18),
    card = Color3.fromRGB(24, 24, 28),
    stroke = Color3.fromRGB(44, 44, 50),
    title = Color3.fromRGB(130, 130, 145),
    text = Color3.fromRGB(225, 225, 230),
    good = Color3.fromRGB(80, 255, 120),
    bad = Color3.fromRGB(255, 70, 70),
}

-- ปุ่มที่รองรับการ ซ่อน/แสดง UI (Ctrl และ Alt ทั้งซ้าย-ขวา)
local TOGGLE_KEYS = {
    [Enum.KeyCode.LeftAlt] = true,
    [Enum.KeyCode.RightAlt] = true,
    [Enum.KeyCode.LeftControl] = true,
    [Enum.KeyCode.RightControl] = true,
}

-- Display label -> inventory label.
local LEFT_ITEMS = {
    { label = "Valkyries Helm", match = "Valkyrie Helmet", kind = "check" },
    { label = "Mirror Fractal", match = "Mirror Fractal", kind = "check" },
    { label = "Dark Fragment", match = "Dark Fragment", kind = "total" },
}

local MELEES = {
    { label = "Death Step", match = "Death Step" },
    { label = "Superhuman", match = "Superhuman" },
    { label = "Sharkman Karate", match = "Sharkman Karate" },
    { label = "Electric Claw", match = "Electric Claw" },
    { label = "Dragon Talon", match = "Dragon Talon" },
    { label = "Godhuman", match = "Godhuman" },
}

local SWORDS = {
    { label = "Saber", match = "Saber" },
    { label = "Yama", match = "Yama" },
    { label = "Tushita", match = "Tushita" },
    { label = "Cursed Dual Katana", match = "Cursed Dual Katana" },
    { label = "Hollow Scythe", match = "Hollow Scythe" },
    { label = "Shark Anchor", match = "Shark Anchor" },
}

-- State.
local localPlayer = playersService.LocalPlayer
local startTime = os.clock()
local pendingInventory = nil
local rows = {}
local configWidgets = {}
local currentTask = "Idle"

shared.ZeusxHub = shared.ZeusxHub or {}
local ZeusxHub = shared.ZeusxHub

-- Clean up the previous execution.
if ZeusxHub.destroy then
    ZeusxHub.destroy()
end

---Normalize an inventory label for comparison.
---@param name string
---@return string
local function normalize(name)
    name = tostring(name or "")
    name = name:match("^(.-)%s*%[") or name
    return (name:lower():gsub("[%s%p_]+", ""))
end

---Format seconds as HH:MM:SS.
---@param seconds number
---@return string
local function formatTime(seconds)
    return string.format("%02d:%02d:%02d", seconds // 3600, seconds % 3600 // 60, seconds % 60)
end

---Format a number with thousands separators.
---@param value any
---@return string
local function formatNumber(value)
    local text = tostring(math.floor(tonumber(value) or 0))
    return (text:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end

---Read a value from the player's Data folder.
---@param name string
---@return any
local function getData(name)
    local data = localPlayer:FindFirstChild("Data")
    local value = data and data:FindFirstChild(name)
    return value and value.Value or "-"
end

---Create an instance with properties.
---@param className string
---@param props table
---@return Instance
local function create(className, props)
    local instance = Instance.new(className)
    for key, value in next, props do
        instance[key] = value
    end
    return instance
end

---Create a text label.
---@param parent Instance
---@param text string
---@param color Color3
---@param alignment Enum.TextXAlignment
---@param textSize number?
---@return TextLabel
local function createLabel(parent, text, color, alignment, textSize)
    return create("TextLabel", {
        Parent = parent,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
        Font = FONT,
        TextSize = textSize or FONT_SIZE,
        TextColor3 = color,
        Text = text,
        TextXAlignment = alignment,
    })
end

---Create a column that stacks cards.
---@param parent Instance
---@param position UDim2
---@return Frame
local function createColumn(parent, position)
    local column = create("Frame", {
        Parent = parent,
        BackgroundTransparency = 1,
        Position = position,
        Size = UDim2.new(0.5, -4, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
    })

    create("UIListLayout", { Parent = column, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder })
    return column
end

---Create a titled card sized by its content.
---@param parent Instance
---@param title string
---@param showCounter boolean?
---@return Frame, TextLabel?
local function createCard(parent, title, showCounter)
    local card = create("Frame", {
        Parent = parent,
        BackgroundColor3 = COLORS.card,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
    })

    create("UICorner", { Parent = card, CornerRadius = UDim.new(0, 4) })
    create("UIStroke", { Parent = card, Color = COLORS.stroke, Thickness = 1 })
    create("UIPadding", {
        Parent = card,
        PaddingTop = UDim.new(0, 8),
        PaddingBottom = UDim.new(0, 8),
        PaddingLeft = UDim.new(0, 10),
        PaddingRight = UDim.new(0, 10),
    })
    create("UIListLayout", { Parent = card, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder })

    local header = create("Frame", {
        Parent = card,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, TITLE_HEIGHT),
        LayoutOrder = 0,
    })

    createLabel(header, string.upper(title), COLORS.title, Enum.TextXAlignment.Left, TITLE_FONT_SIZE)

    local counterLabel = nil
    if showCounter then
        counterLabel = createLabel(header, "(0/0)", COLORS.title, Enum.TextXAlignment.Right, TITLE_FONT_SIZE)
    end

    -- เส้นคั่นระหว่างหัวข้อและเนื้อหา
    create("Frame", {
        Parent = card,
        BackgroundColor3 = COLORS.stroke,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 1),
        LayoutOrder = 1,
    })

    return card, counterLabel
end

---Create a row and return its value label.
---@param card Frame
---@param label string
---@return TextLabel
local function createRow(card, label)
    local row = create("Frame", {
        Parent = card,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
        LayoutOrder = #card:GetChildren(),
    })

    createLabel(row, label, COLORS.text, Enum.TextXAlignment.Left)
    return createLabel(row, "-", COLORS.text, Enum.TextXAlignment.Right)
end

---Create a checkbox row.
---@param card Frame
---@param label string
---@param initialState boolean
---@return table
local function createCheckbox(card, label, initialState)
    local row = create("Frame", {
        Parent = card,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
        LayoutOrder = #card:GetChildren(),
    })

    createLabel(row, label, COLORS.text, Enum.TextXAlignment.Left)

    local box = create("Frame", {
        Parent = row,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.fromOffset(13, 13),
        BorderSizePixel = 0,
    })

    create("UICorner", { Parent = box, CornerRadius = UDim.new(0, 3) })
    local stroke = create("UIStroke", { Parent = box, Color = COLORS.stroke, Thickness = 1 })

    local checkMark = create("TextLabel", {
        Parent = box,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
        Font = FONT,
        TextSize = 11,
        TextColor3 = Color3.fromRGB(15, 25, 18),
        Text = "✓",
    })

    local widget = {
        box = box,
        stroke = stroke,
        checkMark = checkMark,
        state = false,
        setValue = function(self, isChecked)
            self.state = isChecked
            if isChecked then
                self.box.BackgroundColor3 = COLORS.good
                self.box.BackgroundTransparency = 0
                self.stroke.Color = COLORS.good
                self.checkMark.Visible = true
            else
                self.box.BackgroundTransparency = 1
                self.stroke.Color = COLORS.stroke
                self.checkMark.Visible = false
            end
        end,
    }

    widget:setValue(initialState)
    return widget
end

---Create a header or footer bar with a left and right text.
---@param parent Instance
---@param leftText string
---@param rightText string
---@param order number
---@return Frame
local function createBar(parent, leftText, rightText, order)
    local bar = create("Frame", {
        Parent = parent,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
        LayoutOrder = order,
    })

    createLabel(bar, leftText, COLORS.text, Enum.TextXAlignment.Left)

    if rightText ~= "" then
        createLabel(bar, rightText, COLORS.title, Enum.TextXAlignment.Right, TITLE_FONT_SIZE)
    end

    return bar
end

---Show a green check or red cross on a label.
---@param label TextLabel
---@param owned boolean
local function setCheck(label, owned)
    label.Font = Enum.Font.Code
    label.Text = owned and "✅" or "❌"
    label.TextColor3 = owned and COLORS.good or COLORS.bad
end

-- Build GUI.
local screenGui = create("ScreenGui", {
    Name = "ZeusxHubStatus",
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})
screenGui.Parent = (gethui and gethui()) or game:GetService("CoreGui")

local main = create("Frame", {
    Parent = screenGui,
    BackgroundColor3 = COLORS.background,
    BorderSizePixel = 0,
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(540, 0),
    AutomaticSize = Enum.AutomaticSize.Y,
})
create("UICorner", { Parent = main, CornerRadius = UDim.new(0, 6) })
create("UIStroke", { Parent = main, Color = COLORS.stroke, Thickness = 1 })
create("UIPadding", {
    Parent = main,
    PaddingTop = UDim.new(0, 8),
    PaddingBottom = UDim.new(0, 8),
    PaddingLeft = UDim.new(0, 8),
    PaddingRight = UDim.new(0, 8),
})

-- Layout: header, body, footer.
create("UIListLayout", { Parent = main, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder })

createBar(main, "Zeusx Hub | Blox Fruits Kaitan", "Ctrl / Alt : Hide UI", 0)

local body = create("Frame", {
    Parent = main,
    BackgroundTransparency = 1,
    Size = UDim2.new(1, 0, 0, 0),
    AutomaticSize = Enum.AutomaticSize.Y,
    LayoutOrder = 1,
})

createBar(main, "Blox Fruit Kaitan Made By Nutx", "", 2)

local leftColumn = createColumn(body, UDim2.new(0, 0, 0, 0))
local rightColumn = createColumn(body, UDim2.new(0.5, 4, 0, 0))

-- Left column.
local timeCard = createCard(leftColumn, "Time Running")
local timeValue = createRow(timeCard, "Running")

-- Config Card (ถัดจาก Time Running)
local configCard = createCard(leftColumn, "Config")
configWidgets["OneClick"] = createCheckbox(configCard, "OneClick", true)

local infoCard = createCard(leftColumn, "Player Info")
createRow(infoCard, "Name").Text = localPlayer.Name
local levelValue = createRow(infoCard, "Level")
local beliValue = createRow(infoCard, "Beli")
local fragmentValue = createRow(infoCard, "Fragment")
local raceValue = createRow(infoCard, "Race")

-- Items Card (have/total)
local itemCard, itemsCounter = createCard(leftColumn, "Items", true)
for _, item in ipairs(LEFT_ITEMS) do
    rows[item.label] = createRow(itemCard, item.label)
end

-- Right column.
-- Task Card (วางก่อนหน้า Melee)
local taskCard = createCard(rightColumn, "Status")
local taskRow = create("Frame", {
	Parent = taskCard,
	BackgroundTransparency = 1,
	Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
	LayoutOrder = #taskCard:GetChildren(),
})

local taskValue = create("TextLabel", {
	Parent = taskRow,
	BackgroundTransparency = 1,
	Size = UDim2.new(1, 0, 1, 0),
	Font = FONT,
	TextSize = FONT_SIZE,
	TextColor3 = COLORS.text,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextTruncate = Enum.TextTruncate.AtEnd,
	TextWrapped = false,
	Text = currentTask,
})

-- Melee Card (วางก่อนหน้า Sword พร้อม have/total)
local meleeCard, meleeCounter = createCard(rightColumn, "Melee", true)
for _, melee in ipairs(MELEES) do
    rows[melee.label] = createRow(meleeCard, melee.label)
end

-- Sword Card (have/total)
local swordCard, swordCounter = createCard(rightColumn, "Sword", true)
for _, sword in ipairs(SWORDS) do
    rows[sword.label] = createRow(swordCard, sword.label)
end

---Set task status from external scripts.
---@param task string?
function ZeusxHub.setTask(task)
	if task and tostring(task) ~= "" then
		currentTask = tostring(task)
	else
		currentTask = "Idle"
	end
end

---Set config value.
---@param key string
---@param value boolean
function ZeusxHub.setConfig(key, value)
    if configWidgets[key] then
        configWidgets[key]:setValue(value and true or false)
    end
end

-- Toggle visibility (รองรับ Ctrl / Alt ทั้งซ้ายและขวา)
local inputConnection = userInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then
        return
    end

    if TOGGLE_KEYS[input.KeyCode] then
        main.Visible = not main.Visible
    end
end)

---Read the player's inventory counts keyed by normalized name.
---@param itemService table
---@param itemConfig table
---@param keys table
---@return table
local function getInventory(itemService, itemConfig, keys)
    local inventory = {}
    local items = itemService:GetItems(keys.QUANTITY)

    if not items then
        return inventory
    end

    for _, item in pairs(items) do
        if not item.Value or item.Value <= 0 then
            continue
        end

        local success, config = pcall(function()
            return itemConfig.match(item.ItemId):unwrap()
        end)

        if not success or not config or not config.Index then
            continue
        end

        local key = normalize(config.Index.DebugLabel)
        inventory[key] = (inventory[key] or 0) + item.Value
    end

    return inventory
end

-- Inventory polling thread.
ZeusxHub.itemsThread = task.spawn(function()
    local ok, itemService, itemConfig, keys = pcall(function()
        local service = require(replicatedStorage:WaitForChild("ItemReplicationService"))
        local config = require(replicatedStorage:WaitForChild("ItemConfig"))
        local serviceKeys = require(replicatedStorage.ItemReplicationService:WaitForChild("KEYS"))
        return service, config, serviceKeys
    end)

    if not ok then
        return warn("[ZeusxHub] Failed to load item modules.")
    end

    while true do
        if itemService.IsInitialized then
            local success, inventory = pcall(getInventory, itemService, itemConfig, keys)
            if success then
                pendingInventory = inventory
            end
        end

        task.wait(INVENTORY_INTERVAL)
    end
end)

---Update every value shown in the UI.
local function onRenderStep()
    taskValue.Text = currentTask
    timeValue.Text = formatTime(os.clock() - startTime)
    levelValue.Text = formatNumber(getData("Level"))
    beliValue.Text = formatNumber(getData("Beli"))
    fragmentValue.Text = formatNumber(getData("Fragments"))
    raceValue.Text = tostring(getData("Race"))

    if not pendingInventory then
        return
    end

    local inventory = pendingInventory
    pendingInventory = nil

    -- อัปเดต Items และนับจำนวน
    local itemsOwned = 0
    for _, item in ipairs(LEFT_ITEMS) do
        local count = inventory[normalize(item.match)] or 0

        if count > 0 then
            itemsOwned = itemsOwned + 1
        end

        if item.kind == "total" then
            rows[item.label].Text = "x" .. formatNumber(count)
            rows[item.label].TextColor3 = COLORS.text
        else
            setCheck(rows[item.label], count > 0)
        end
    end
    if itemsCounter then
        itemsCounter.Text = string.format("(%d/%d)", itemsOwned, #LEFT_ITEMS)
    end

    -- อัปเดต Melees และนับจำนวน
    local meleesOwned = 0
    for _, melee in ipairs(MELEES) do
        local owned = (inventory[normalize(melee.match)] or 0) > 0
        if owned then
            meleesOwned = meleesOwned + 1
        end
        setCheck(rows[melee.label], owned)
    end
    if meleeCounter then
        meleeCounter.Text = string.format("(%d/%d)", meleesOwned, #MELEES)
    end

    -- อัปเดต Swords และนับจำนวน
    local swordsOwned = 0
    for _, sword in ipairs(SWORDS) do
        local owned = (inventory[normalize(sword.match)] or 0) > 0
        if owned then
            swordsOwned = swordsOwned + 1
        end
        setCheck(rows[sword.label], owned)
    end
    if swordCounter then
        swordCounter.Text = string.format("(%d/%d)", swordsOwned, #SWORDS)
    end
end

local renderConnection = runService.RenderStepped:Connect(onRenderStep)

---Disconnect everything and remove the UI.
function ZeusxHub.destroy()
    renderConnection:Disconnect()
    inputConnection:Disconnect()
    pcall(task.cancel, ZeusxHub.itemsThread)
    screenGui:Destroy()
    ZeusxHub.destroy = nil
    ZeusxHub.setTask = nil
    ZeusxHub.setConfig = nil
end

return ZeusxHub
