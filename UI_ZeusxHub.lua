-- Services.
local playersService = game:GetService("Players")
local replicatedStorage = game:GetService("ReplicatedStorage")
local runService = game:GetService("RunService")
local userInputService = game:GetService("UserInputService")

-- Constants.
local FONT = Enum.Font.Code
local FONT_SIZE = 11
local INVENTORY_INTERVAL = 2
local COLORS = {
	background = Color3.fromRGB(16, 16, 18),
	card = Color3.fromRGB(24, 24, 28),
	stroke = Color3.fromRGB(44, 44, 50),
	title = Color3.fromRGB(130, 130, 145),
	text = Color3.fromRGB(225, 225, 230),
	good = Color3.fromRGB(90, 200, 120),
	bad = Color3.fromRGB(215, 80, 80),
}

-- Display label -> inventory label.
local LEFT_ITEMS = {
	{ label = "Valkyries Helm", match = "Valkyrie Helmet", kind = "check" },
	{ label = "Mirror Fractal", match = "Mirror Fractal", kind = "check" },
	{ label = "Dark Fragment", match = "Dark Fragment", kind = "total" },
}

local SWORDS = {
	{ label = "GodHuman", match = "Godhuman" },
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
---@return TextLabel
local function createLabel(parent, text, color, alignment)
	return create("TextLabel", {
		Parent = parent,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0),
		Font = FONT,
		TextSize = FONT_SIZE,
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
		Size = UDim2.new(0.5, -3, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	})

	create("UIListLayout", { Parent = column, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder })
	return column
end

---Create a titled card sized by its content.
---@param parent Instance
---@param title string
---@return Frame
local function createCard(parent, title)
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
		PaddingTop = UDim.new(0, 6),
		PaddingBottom = UDim.new(0, 6),
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
	})
	create("UIListLayout", { Parent = card, Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder })

	local header = create("Frame", {
		Parent = card,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 14),
		LayoutOrder = 0,
	})
	createLabel(header, string.upper(title), COLORS.title, Enum.TextXAlignment.Left)

	return card
end

---Create a row and return its value label.
---@param card Frame
---@param label string
---@return TextLabel
local function createRow(card, label)
	local row = create("Frame", {
		Parent = card,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 13),
		LayoutOrder = #card:GetChildren(),
	})

	createLabel(row, label, COLORS.text, Enum.TextXAlignment.Left)
	return createLabel(row, "-", COLORS.text, Enum.TextXAlignment.Right)
end

---Show a check or cross on a label.
---@param label TextLabel
---@param owned boolean
local function setCheck(label, owned)
	label.Text = owned and "✓" or "✗"
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
	Position = UDim2.fromOffset(20, 120),
	Size = UDim2.fromOffset(320, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	Active = true,
})
create("UICorner", { Parent = main, CornerRadius = UDim.new(0, 6) })
create("UIStroke", { Parent = main, Color = COLORS.stroke, Thickness = 1 })
create("UIPadding", {
	Parent = main,
	PaddingTop = UDim.new(0, 6),
	PaddingBottom = UDim.new(0, 6),
	PaddingLeft = UDim.new(0, 6),
	PaddingRight = UDim.new(0, 6),
})

local body = create("Frame", {
	Parent = main,
	BackgroundTransparency = 1,
	Size = UDim2.new(1, 0, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
})

local leftColumn = createColumn(body, UDim2.new(0, 0, 0, 0))
local rightColumn = createColumn(body, UDim2.new(0.5, 3, 0, 0))

-- Left column.
local timeValue = createRow(createCard(leftColumn, "Time Running"), "Total")

local infoCard = createCard(leftColumn, "Player Info")
createRow(infoCard, "Name").Text = localPlayer.Name
local levelValue = createRow(infoCard, "Level")
local beliValue = createRow(infoCard, "Beli")
local fragmentValue = createRow(infoCard, "Fragment")
local raceValue = createRow(infoCard, "Race")

local itemCard = createCard(leftColumn, "Items")
for _, item in ipairs(LEFT_ITEMS) do
	rows[item.label] = createRow(itemCard, item.label)
end

-- Right column.
local swordCard = createCard(rightColumn, "Sword")
for _, sword in ipairs(SWORDS) do
	rows[sword.label] = createRow(swordCard, sword.label)
end

-- Drag support.
local dragging, dragStart, startPosition

main.InputBegan:Connect(function(input)
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end

	dragging, dragStart, startPosition = true, input.Position, main.Position
end)

local changedConnection = userInputService.InputChanged:Connect(function(input)
	if not dragging then
		return
	end

	if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end

	local delta = input.Position - dragStart
	main.Position = UDim2.fromOffset(startPosition.X.Offset + delta.X, startPosition.Y.Offset + delta.Y)
end)

local endedConnection = userInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = false
	end
end)

-- Toggle visibility.
local inputConnection = userInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end

	if input.KeyCode == Enum.KeyCode.LeftAlt then
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

	for _, item in ipairs(LEFT_ITEMS) do
		local count = inventory[normalize(item.match)] or 0

		if item.kind == "total" then
			rows[item.label].Text = "x" .. formatNumber(count)
			rows[item.label].TextColor3 = COLORS.text
		else
			setCheck(rows[item.label], count > 0)
		end
	end

	for _, sword in ipairs(SWORDS) do
		setCheck(rows[sword.label], (inventory[normalize(sword.match)] or 0) > 0)
	end
end

local renderConnection = runService.RenderStepped:Connect(onRenderStep)

---Disconnect everything and remove the UI.
function ZeusxHub.destroy()
	renderConnection:Disconnect()
	inputConnection:Disconnect()
	changedConnection:Disconnect()
	endedConnection:Disconnect()
	pcall(task.cancel, ZeusxHub.itemsThread)
	screenGui:Destroy()
	ZeusxHub.destroy = nil
end

return ZeusxHub
