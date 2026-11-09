---@module ZeusxHub.StatusUI

-- Services.
local playersService = game:GetService("Players")
local runService = game:GetService("RunService")
local httpService = game:GetService("HttpService")
local userInputService = game:GetService("UserInputService")
local replicatedStorage = game:GetService("ReplicatedStorage")
local tweenService = game:GetService("TweenService")

-- Theme.
local THEME = {
	Background = Color3.fromRGB(22, 18, 13),
	Panel = Color3.fromRGB(39, 31, 23),
	Section = Color3.fromRGB(46, 37, 27),
	Card = Color3.fromRGB(58, 46, 32),
	Border = Color3.fromRGB(128, 101, 59),
	Gold = Color3.fromRGB(232, 196, 119),
	GoldLight = Color3.fromRGB(247, 224, 177),
	Text = Color3.fromRGB(245, 229, 197),
	Muted = Color3.fromRGB(191, 167, 125),
	Green = Color3.fromRGB(110, 224, 130),
	Purple = Color3.fromRGB(190, 157, 224),
}

-- Fallback images (add ids for Valkyrie Helm / Mirror Fractal to show them before owning).
local ITEM_ASSETS = {
	["Godhuman"] = "rbxassetid://75176997304682",
	["Saber"] = "rbxassetid://135665944389990",
	["Tushita"] = "rbxassetid://127659543896119",
	["Yama"] = "rbxassetid://138342732332076",
	["Cursed Dual Katana"] = "rbxassetid://139876489530430",
	["Valkyrie Helmet"] = "rbxassetid://112006685928352",
	["Mirror Fractal"] = "rbxassetid://120175105489971",
}

-- Fixed slots, shown in this order.
local FEATURED_ITEMS = {
	"Saber",
	"Godhuman",
	"Yama",
	"Tushita",
	"Cursed Dual Katana",
	"Valkyrie Helmet",
	"Mirror Fractal",
}

-- Normalize inventory labels.
local ITEM_NAME_LOOKUP = {}

local function normalizeItemName(name)
	name = tostring(name or "")
	name = name:match("^(.-)%s*%[") or name
	name = name:lower():gsub("[%s%p_]+", "")
	return name
end

for _, itemName in ipairs(FEATURED_ITEMS) do
	ITEM_NAME_LOOKUP[normalizeItemName(itemName)] = itemName
end

ITEM_NAME_LOOKUP[normalizeItemName("Valkyrie Helmet")] = "Valkyrie Helm"

-- Melee styles counted in the melee box.
local MELEE_LIST = {
	"Superhuman",
	"Death Step",
	"Sharkman Karate",
	"Electric Claw",
	"Dragon Talon",
	"Godhuman",
}

local MELEE_LOOKUP = {}

for _, meleeName in ipairs(MELEE_LIST) do
	MELEE_LOOKUP[normalizeItemName(meleeName)] = meleeName
end

local INVENTORY_INTERVAL = 2
local AWAKEN_INTERVAL = 5
local AWAKEN_REMOTE = "getAwakenedAbilities"
local TWEEN_INFO = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- VT323 Font.
local FONT_ROOT = "ZeusxHub"
local FONT_FOLDER = "ZeusxHub/Fonts"
local FONT_NAME = "VT323"
local FONT_URL = "https://raw.githubusercontent.com/google/fonts/main/ofl/vt323/VT323-Regular.ttf"

-- State.
local localPlayer = playersService.LocalPlayer
local startTime = os.clock()
local commF = replicatedStorage:WaitForChild("Remotes"):WaitForChild("CommF_")

shared.ZeusxHub = shared.ZeusxHub or { task = "Idle" }
local ZeusxHub = shared.ZeusxHub

if ZeusxHub.gui then
	ZeusxHub.gui:Destroy()
end

if ZeusxHub.connection then
	ZeusxHub.connection:Disconnect()
	ZeusxHub.connection = nil
end

if ZeusxHub.inputConnection then
	ZeusxHub.inputConnection:Disconnect()
	ZeusxHub.inputConnection = nil
end

if ZeusxHub.itemsThread then
	pcall(task.cancel, ZeusxHub.itemsThread)
	ZeusxHub.itemsThread = nil
end

function ZeusxHub.setTask(text)
	ZeusxHub.task = text
end

function ZeusxHub.destroy()
	if ZeusxHub.connection then
		ZeusxHub.connection:Disconnect()
		ZeusxHub.connection = nil
	end

	if ZeusxHub.inputConnection then
		ZeusxHub.inputConnection:Disconnect()
		ZeusxHub.inputConnection = nil
	end

	if ZeusxHub.itemsThread then
		pcall(task.cancel, ZeusxHub.itemsThread)
		ZeusxHub.itemsThread = nil
	end

	if ZeusxHub.gui then
		ZeusxHub.gui:Destroy()
		ZeusxHub.gui = nil
	end
end

-- Load font.
local function loadGoogleFont(name, url)
	local success, result = pcall(function()
		if not isfolder(FONT_ROOT) then
			makefolder(FONT_ROOT)
		end

		if not isfolder(FONT_FOLDER) then
			makefolder(FONT_FOLDER)
		end

		local fontPath = string.format("%s/%s.ttf", FONT_FOLDER, name)
		local familyPath = string.format("%s/%s.json", FONT_FOLDER, name)

		if not isfile(fontPath) then
			local response = request({
				Url = url,
				Method = "GET"
			})

			if not response or not response.Success then
				error("Failed to download font: " .. name)
			end

			writefile(fontPath, response.Body)
		end

		local family = {
			name = name,
			faces = {
				{
					name = "Regular",
					weight = 400,
					style = "normal",
					assetId = getcustomasset(fontPath),
				},
			},
		}

		writefile(familyPath, httpService:JSONEncode(family))

		return Font.new(getcustomasset(familyPath))
	end)

	if success then
		return result
	end

	warn("[ZeusxHub] Custom font unavailable; using Gotham.")
	return Font.fromEnum(Enum.Font.GothamMedium)
end

local vtFont = loadGoogleFont(FONT_NAME, FONT_URL)

local function formatTime(seconds)
	local hours = math.floor(seconds / 3600)
	local minutes = math.floor((seconds % 3600) / 60)
	local secs = math.floor(seconds % 60)

	return string.format("%02d:%02d:%02d", hours, minutes, secs)
end

local function formatNumber(value)
	local text = tostring(math.floor(tonumber(value) or 0))

	return text:reverse()
		:gsub("(%d%d%d)", "%1,")
		:reverse()
		:gsub("^,", "")
end

local function getStat(name)
	local data = localPlayer:FindFirstChild("Data")
	local stat = data and data:FindFirstChild(name)

	return stat and stat.Value or 0
end

-- UI helpers.
local function addCorner(object, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 10)
	corner.Parent = object

	return corner
end

local function addStroke(object, color, thickness, transparency)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or THEME.Border
	stroke.Thickness = thickness or 1
	stroke.Transparency = transparency or 0
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = object

	return stroke
end

local function addGradient(object, top, bottom)
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(top, bottom)
	gradient.Rotation = 90
	gradient.Parent = object

	return gradient
end

local function createText(parent, name, text, size, color, position, dimensions)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Position = position or UDim2.new()
	label.Size = dimensions or UDim2.new(1, 0, 0, 20)
	label.FontFace = vtFont
	label.Text = text or ""
	label.TextSize = size or 18
	label.TextColor3 = color or THEME.Text
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.Parent = parent

	return label
end

local function createSection(parent, name, height, order)
	local section = Instance.new("Frame")
	section.Name = name
	section.Size = UDim2.new(1, 0, 0, height)
	section.BackgroundColor3 = THEME.Section
	section.BorderSizePixel = 0
	section.LayoutOrder = order
	section.Parent = parent

	addCorner(section, 12)
	addStroke(section, THEME.Border, 1, 0.2)
	addGradient(section, Color3.fromRGB(255, 255, 255), Color3.fromRGB(205, 205, 205))

	return section
end

local function createColumns(section, count, height, inset)
	local row = Instance.new("Frame")
	row.Name = "Columns"
	row.Position = UDim2.fromOffset(inset, 0)
	row.Size = UDim2.new(1, -inset * 2, 0, height)
	row.BackgroundTransparency = 1
	row.Parent = section

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Parent = row

	local columns = {}

	for index = 1, count do
		local column = Instance.new("Frame")
		column.Name = "Column" .. index
		column.LayoutOrder = index
		column.Size = UDim2.new(1 / count, 0, 1, 0)
		column.BackgroundTransparency = 1
		column.Parent = row

		if index > 1 then
			local separator = Instance.new("Frame")
			separator.Name = "Separator"
			separator.Position = UDim2.fromOffset(0, 8)
			separator.Size = UDim2.new(0, 1, 1, -16)
			separator.BackgroundColor3 = THEME.Border
			separator.BackgroundTransparency = 0.5
			separator.BorderSizePixel = 0
			separator.Parent = column
		end

		local label = createText(column, "Value", "-", 20, THEME.Text, UDim2.fromOffset(6, 0), UDim2.new(1, -12, 1, 0))
		label.TextXAlignment = Enum.TextXAlignment.Center

		columns[index] = label
	end

	return columns
end

-- Build GUI.
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ZeusxHubStatus"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = gethui and gethui() or game:GetService("CoreGui")

local background = Instance.new("Frame")
background.Name = "Background"
background.Size = UDim2.fromScale(1, 1)
background.BackgroundColor3 = Color3.new(0, 0, 0)
background.BackgroundTransparency = 0.45
background.BorderSizePixel = 0
background.Parent = screenGui

local container = Instance.new("Frame")
container.Name = "MainPanel"
container.AnchorPoint = Vector2.new(0.5, 0.5)
container.Position = UDim2.fromScale(0.5, 0.5)
container.Size = UDim2.fromOffset(580, 0)
container.AutomaticSize = Enum.AutomaticSize.Y
container.BackgroundColor3 = THEME.Background
container.BorderSizePixel = 0
container.Parent = background

addCorner(container, 18)
addStroke(container, THEME.Gold, 1.5, 0.05)

local containerPadding = Instance.new("UIPadding")
containerPadding.PaddingTop = UDim.new(0, 12)
containerPadding.PaddingBottom = UDim.new(0, 12)
containerPadding.PaddingLeft = UDim.new(0, 12)
containerPadding.PaddingRight = UDim.new(0, 12)
containerPadding.Parent = container

local mainLayout = Instance.new("UIListLayout")
mainLayout.FillDirection = Enum.FillDirection.Vertical
mainLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
mainLayout.SortOrder = Enum.SortOrder.LayoutOrder
mainLayout.Padding = UDim.new(0, 8)
mainLayout.Parent = container

-- Header.
local header = Instance.new("Frame")
header.Name = "Header"
header.Size = UDim2.new(1, 0, 0, 28)
header.BackgroundTransparency = 1
header.LayoutOrder = 0
header.Parent = container

local titleLabel = createText(header, "Title", "✦ ZEUSX HUB", 28, THEME.Gold, UDim2.fromOffset(2, 0), UDim2.new(0.5, 0, 1, 0))
local hintLabel = createText(header, "Hint", "LeftAlt : Hide", 18, THEME.Muted, UDim2.new(0.5, 0, 0, 0), UDim2.new(0.5, -2, 1, 0))
hintLabel.TextXAlignment = Enum.TextXAlignment.Right

local headerLine = Instance.new("Frame")
headerLine.Name = "Line"
headerLine.AnchorPoint = Vector2.new(0, 1)
headerLine.Position = UDim2.new(0, 0, 1, 0)
headerLine.Size = UDim2.new(1, 0, 0, 1)
headerLine.BackgroundColor3 = THEME.Gold
headerLine.BackgroundTransparency = 0.5
headerLine.BorderSizePixel = 0
headerLine.Parent = header

-- Section 1: Profile.
local playerSection = createSection(container, "PlayerSection", 106, 1)

local profileImage = Instance.new("ImageButton")
profileImage.Name = "PlayerThumbnail"
profileImage.Position = UDim2.fromOffset(10, 11)
profileImage.Size = UDim2.fromOffset(84, 84)
profileImage.BackgroundColor3 = THEME.Card
profileImage.BorderSizePixel = 0
profileImage.AutoButtonColor = false
profileImage.ScaleType = Enum.ScaleType.Crop
profileImage.Parent = playerSection

addCorner(profileImage, 42)
addStroke(profileImage, THEME.Gold, 2, 0)

createText(
	playerSection,
	"PlayerName",
	localPlayer.DisplayName,
	22,
	THEME.GoldLight,
	UDim2.fromOffset(108, 6),
	UDim2.new(1, -120, 0, 24)
)

local statsRow = Instance.new("Frame")
statsRow.Name = "Stats"
statsRow.Position = UDim2.fromOffset(108, 36)
statsRow.Size = UDim2.new(1, -306, 0, 62)
statsRow.BackgroundColor3 = THEME.Card
statsRow.BorderSizePixel = 0
statsRow.Parent = playerSection

addCorner(statsRow, 9)

local statsPadding = Instance.new("UIPadding")
statsPadding.PaddingLeft = UDim.new(0, 10)
statsPadding.PaddingTop = UDim.new(0, 1)
statsPadding.Parent = statsRow

local statsLayout = Instance.new("UIListLayout")
statsLayout.FillDirection = Enum.FillDirection.Vertical
statsLayout.SortOrder = Enum.SortOrder.LayoutOrder
statsLayout.Parent = statsRow

local function createStatLine(name, color, order)
	local line = createText(statsRow, name, "", 18, color, nil, UDim2.new(1, -10, 0, 20))
	line.LayoutOrder = order

	return line
end

local levelLabel = createStatLine("LEVEL", THEME.Text, 1)
local beliLabel = createStatLine("BELI", THEME.Green, 2)
local fragmentLabel = createStatLine("FRAGMENT", THEME.Purple, 3)

-- Melee box.
local meleeBox = Instance.new("Frame")
meleeBox.Name = "MeleeBox"
meleeBox.Position = UDim2.new(1, -190, 0, 36)
meleeBox.Size = UDim2.fromOffset(180, 62)
meleeBox.BackgroundColor3 = THEME.Card
meleeBox.BorderSizePixel = 0
meleeBox.Parent = playerSection

addCorner(meleeBox, 9)

local meleeTitle = createText(meleeBox, "Title", "MALEE", 18, THEME.Muted, UDim2.fromOffset(0, 3), UDim2.new(1, 0, 0, 20))
meleeTitle.TextXAlignment = Enum.TextXAlignment.Center

local meleeCount = createText(meleeBox, "Count", "0 / " .. #MELEE_LIST, 28, THEME.GoldLight, UDim2.fromOffset(0, 22), UDim2.new(1, 0, 0, 34))
meleeCount.TextXAlignment = Enum.TextXAlignment.Center

-- Thumbnail for the profile and mini button.
local playerThumbnail = ""
local miniIcon = nil

task.spawn(function()
	local success, image = pcall(function()
		return playersService:GetUserThumbnailAsync(
			localPlayer.UserId,
			Enum.ThumbnailType.HeadShot,
			Enum.ThumbnailSize.Size420x420
		)
	end)

	if success and image then
		playerThumbnail = image
		profileImage.Image = image

		if miniIcon then
			miniIcon.Image = image
		end
	end
end)

-- Section 2: Fruit / Mastery / Awakening.
local fruitSection = createSection(container, "FruitSection", 38, 2)
local fruitColumns = createColumns(fruitSection, 3, 38, 6)
local fruitLabel = fruitColumns[1]
local masteryLabel = fruitColumns[2]
local awakeningLabel = fruitColumns[3]

fruitLabel.Text = "Fruit : None"
masteryLabel.Text = "Mastery : -"
awakeningLabel.Text = "Awaken : 0/0"

-- Section 3: Task and runtime.
local taskSection = createSection(container, "TaskSection", 38, 3)

local taskIcon = createText(taskSection, "TaskIcon", "✦", 20, THEME.Gold, UDim2.fromOffset(12, 0), UDim2.fromOffset(24, 38))
taskIcon.TextXAlignment = Enum.TextXAlignment.Center

local taskLabel = createText(taskSection, "Task", "Idle", 20, THEME.Text, UDim2.fromOffset(44, 0), UDim2.new(1, -170, 1, 0))

local timeLabel = createText(taskSection, "Runtime", "00:00:00", 20, THEME.Muted, UDim2.new(1, -118, 0, 0), UDim2.fromOffset(106, 38))
timeLabel.TextXAlignment = Enum.TextXAlignment.Right

-- Section 4: Fixed collection slots.
local collectionSection = createSection(container, "CollectionSection", 150, 4)

local collectionTitle = createText(collectionSection, "Title", "COLLECTION", 18, THEME.Muted, UDim2.fromOffset(12, 4), UDim2.new(0.5, 0, 0, 22))
local collectionCount = createText(collectionSection, "Count", "0 / " .. #FEATURED_ITEMS, 20, THEME.GoldLight, UDim2.new(0.5, 0, 0, 4), UDim2.new(0.5, -12, 0, 22))
collectionCount.TextXAlignment = Enum.TextXAlignment.Right

local slotHolder = Instance.new("Frame")
slotHolder.Name = "Slots"
slotHolder.Position = UDim2.fromOffset(10, 30)
slotHolder.Size = UDim2.new(1, -20, 0, 112)
slotHolder.BackgroundTransparency = 1
slotHolder.Parent = collectionSection

local slotGrid = Instance.new("UIGridLayout")
slotGrid.CellSize = UDim2.new(1 / #FEATURED_ITEMS, -6, 1, 0)
slotGrid.CellPadding = UDim2.fromOffset(6, 0)
slotGrid.FillDirection = Enum.FillDirection.Horizontal
slotGrid.SortOrder = Enum.SortOrder.LayoutOrder
slotGrid.Parent = slotHolder

-- Cache sprites so unowned slots keep their picture.
local spriteCache = {}
local slots = {}

local function applySprite(icon, asset)
	if not asset or not asset.image or asset.image == "" then
		icon.Image = ""
		return false
	end

	icon.Image = asset.image
	icon.ImageRectOffset = asset.offset or Vector2.zero
	icon.ImageRectSize = asset.size or Vector2.zero

	return true
end

-- Create one fixed slot.
local function createSlot(itemName, order)
	local card = Instance.new("Frame")
	card.Name = "Slot_" .. (itemName:gsub("%W", ""))
	card.LayoutOrder = order
	card.BackgroundColor3 = THEME.Card
	card.BorderSizePixel = 0
	card.Parent = slotHolder

	addCorner(card, 10)
	local stroke = addStroke(card, THEME.Border, 1.2, 0.2)

	local icon = Instance.new("ImageLabel")
	icon.Name = "Icon"
	icon.AnchorPoint = Vector2.new(0.5, 0)
	icon.Position = UDim2.new(0.5, 0, 0, 12)
	icon.Size = UDim2.fromOffset(52, 52)
	icon.BackgroundTransparency = 1
	icon.ScaleType = Enum.ScaleType.Fit
	icon.ImageTransparency = 0.5
	icon.Parent = card

	local placeholder = createText(card, "Placeholder", string.upper(itemName:sub(1, 2)), 34, THEME.Gold, UDim2.new(0.5, -26, 0, 12), UDim2.fromOffset(52, 52))
	placeholder.TextXAlignment = Enum.TextXAlignment.Center
	placeholder.TextTransparency = 0.5

	local nameLabel = createText(card, "Name", itemName, 17, THEME.Muted, UDim2.new(0, 4, 1, -34), UDim2.new(1, -8, 0, 30))
	nameLabel.TextXAlignment = Enum.TextXAlignment.Center
	nameLabel.TextWrapped = true
	nameLabel.TextTruncate = Enum.TextTruncate.None
	nameLabel.TextTransparency = 0.2

	local countLabel = createText(card, "Count", "", 16, THEME.Green, UDim2.new(1, -34, 0, 3), UDim2.fromOffset(30, 14))
	countLabel.TextXAlignment = Enum.TextXAlignment.Right

	slots[itemName] = {
		card = card,
		icon = icon,
		stroke = stroke,
		placeholder = placeholder,
		nameLabel = nameLabel,
		countLabel = countLabel,
		owned = nil,
	}

	-- Initial unowned look with the fallback image.
	local hasImage = applySprite(icon, ITEM_ASSETS[itemName] and { image = ITEM_ASSETS[itemName] })
	icon.Visible = hasImage
	placeholder.Visible = not hasImage
end

for order, itemName in ipairs(FEATURED_ITEMS) do
	createSlot(itemName, order)
end

-- Update every slot from the latest inventory.
local function updateSlots(inventory, assets)
	local ownedTotal = 0

	for _, itemName in ipairs(FEATURED_ITEMS) do
		local slot = slots[itemName]
		local count = inventory[itemName] or 0
		local owned = count > 0

		if assets[itemName] then
			spriteCache[itemName] = assets[itemName]
		end

		local sprite = spriteCache[itemName] or (ITEM_ASSETS[itemName] ~= "" and { image = ITEM_ASSETS[itemName] } or nil)
		local hasImage = applySprite(slot.icon, sprite)

		slot.icon.Visible = hasImage
		slot.placeholder.Visible = not hasImage
		slot.countLabel.Text = count > 1 and ("x" .. count) or ""

		if owned then
			ownedTotal += 1
		end

		-- Tween only when the owned state changes.
		if slot.owned ~= owned then
			slot.owned = owned

			local imageTransparency = owned and 0 or 0.5

			tweenService:Create(slot.icon, TWEEN_INFO, { ImageTransparency = imageTransparency }):Play()
			tweenService:Create(slot.placeholder, TWEEN_INFO, { TextTransparency = imageTransparency }):Play()
			tweenService:Create(slot.stroke, TWEEN_INFO, {
				Color = owned and THEME.Green or THEME.Border,
				Thickness = owned and 2 or 1.2,
				Transparency = owned and 0 or 0.2,
			}):Play()
			tweenService:Create(slot.nameLabel, TWEEN_INFO, {
				TextColor3 = owned and THEME.Green or THEME.Muted,
			}):Play()
		end
	end

	collectionCount.Text = string.format("%d / %d", ownedTotal, #FEATURED_ITEMS)
	collectionCount.TextColor3 = ownedTotal >= #FEATURED_ITEMS and THEME.Green or THEME.GoldLight
end

-- Mini icon used when the dashboard is hidden.
miniIcon = Instance.new("ImageButton")
miniIcon.Name = "MiniIcon"
miniIcon.AnchorPoint = Vector2.new(0.5, 0)
miniIcon.Position = UDim2.new(0.5, 0, 0, 35)
miniIcon.Size = UDim2.fromOffset(44, 44)
miniIcon.BackgroundColor3 = THEME.Panel
miniIcon.BorderSizePixel = 0
miniIcon.Image = playerThumbnail
miniIcon.ScaleType = Enum.ScaleType.Crop
miniIcon.Visible = false
miniIcon.Parent = screenGui

addCorner(miniIcon, 22)
addStroke(miniIcon, THEME.Gold, 1.5, 0)

-- Read sprite data from an item config.
local function getSprite(config)
	local display = config.Display
	local sprite = display and display.Sprite

	if type(sprite) ~= "table" or not sprite.Image then
		return nil
	end

	return {
		image = sprite.Image,
		offset = sprite.ImageRectOffset or Vector2.zero,
		size = sprite.ImageRectSize or Vector2.zero,
	}
end

-- Pending data from the inventory thread.
local pendingItems = nil
local pendingFruit = nil
local pendingMelee = nil

-- Read player inventory and sprites.
local function getInventory(itemService, itemConfig, keys)
	local inventory = {}
	local assets = {}
	local melees = {}
	local items = itemService:GetItems(keys.QUANTITY)

	if not items then
		return inventory, assets, melees
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

		local normalized = normalizeItemName(config.Index.DebugLabel)
		local canonicalName = ITEM_NAME_LOOKUP[normalized]
		local meleeName = MELEE_LOOKUP[normalized]

		if meleeName then
			melees[meleeName] = true
		end

		if canonicalName then
			inventory[canonicalName] = (inventory[canonicalName] or 0) + item.Value
			assets[canonicalName] = assets[canonicalName] or getSprite(config)
		end
	end

	return inventory, assets, melees
end

local function getEatenFruit()
	local data = localPlayer:FindFirstChild("Data")
	local value = data and data:FindFirstChild("DevilFruit")

	if value and value.Value ~= "" then
		return value.Value
	end

	return nil
end

local function getShortFruitName(name)
	return name:match("^[^%-%s]+") or name
end

local function getFruitMastery(itemService, itemConfig, keys, fruit)
	local items = itemService:GetItems(keys.MASTERY)
	local shortName = getShortFruitName(fruit)

	for _, item in pairs(items or {}) do
		local success, config = pcall(function()
			return itemConfig.match(item.ItemId):unwrap()
		end)

		if not success or not config or not config.Index then
			continue
		end

		local label = config.Index.DebugLabel

		if label:find(fruit, 1, true) or label:find(shortName, 1, true) then
			return item.Value
		end
	end

	return 0
end

local function getAwakenCount()
	local success, data = pcall(function()
		return commF:InvokeServer(AWAKEN_REMOTE)
	end)

	if not success or type(data) ~= "table" then
		return 0, 0
	end

	local awakened, total = 0, 0

	for _, info in pairs(data) do
		total += 1

		if type(info) == "table" and info.Awakened then
			awakened += 1
		end
	end

	return awakened, total
end

-- Inventory and fruit polling thread.
ZeusxHub.itemsThread = task.spawn(function()
	local ok, itemService, itemConfig, keys = pcall(function()
		local service = require(replicatedStorage:WaitForChild("ItemReplicationService"))
		local config = require(replicatedStorage:WaitForChild("ItemConfig"))
		local serviceKeys = require(replicatedStorage.ItemReplicationService:WaitForChild("KEYS"))

		return service, config, serviceKeys
	end)

	if not ok then
		warn("[ZeusxHub] Failed to load item modules.")
		return
	end

	local lastAwaken, awakenCache, totalCache, lastEaten = 0, 0, 0, nil

	while true do
		if itemService.IsInitialized then
			local success, inventory, assets, melees = pcall(getInventory, itemService, itemConfig, keys)

			if success then
				pendingItems = { inventory = inventory, assets = assets }

				local owned = 0

				for _ in pairs(melees) do
					owned += 1
				end

				pendingMelee = owned
			else
				warn("[ZeusxHub] Inventory error: " .. tostring(inventory))
			end

			local eaten = getEatenFruit()

			if eaten then
				if eaten ~= lastEaten then
					lastEaten = eaten
					lastAwaken = 0
				end

				if os.clock() - lastAwaken >= AWAKEN_INTERVAL then
					lastAwaken = os.clock()
					awakenCache, totalCache = getAwakenCount()
				end

				local okMastery, mastery = pcall(getFruitMastery, itemService, itemConfig, keys, eaten)

				pendingFruit = {
					name = eaten,
					mastery = okMastery and mastery or 0,
					awake = awakenCache,
					total = totalCache,
				}
			else
				lastEaten = nil
				pendingFruit = false
			end
		end

		task.wait(INVENTORY_INTERVAL)
	end
end)

-- Toggle UI visibility.
local uiVisible = true

local function toggleUI()
	uiVisible = not uiVisible
	background.Visible = uiVisible
	miniIcon.Visible = not uiVisible
end

profileImage.MouseButton1Click:Connect(toggleUI)
miniIcon.MouseButton1Click:Connect(toggleUI)

ZeusxHub.inputConnection = userInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end

	if input.KeyCode == Enum.KeyCode.LeftAlt then
		toggleUI()
	end
end)

-- Update dashboard values.
local function onRenderStep()
	if pendingItems then
		local data = pendingItems
		pendingItems = nil
		updateSlots(data.inventory, data.assets)
	end

	levelLabel.Text = "Level : " .. formatNumber(getStat("Level"))
	beliLabel.Text = "Beli : " .. formatNumber(getStat("Beli"))
	fragmentLabel.Text = "Fragment : " .. formatNumber(getStat("Fragments"))

	if pendingMelee then
		meleeCount.Text = string.format("%d / %d", pendingMelee, #MELEE_LIST)
		meleeCount.TextColor3 = pendingMelee >= #MELEE_LIST and THEME.Green or THEME.GoldLight
	end

	if pendingFruit ~= nil then
		local info = pendingFruit

		if not info then
			fruitLabel.Text = "FRUIT : -"
			masteryLabel.Text = "MASTERY : -"
			awakeningLabel.Text = "AWAKEN : -"
			awakeningLabel.TextColor3 = THEME.GoldLight
		else
			fruitLabel.Text = "FRUIT : " .. getShortFruitName(info.name)
			masteryLabel.Text = "MASTERY : " .. formatNumber(info.mastery)
			awakeningLabel.Text = string.format("AWAKEN : %d/%d", info.awake, info.total)
			awakeningLabel.TextColor3 = (info.total > 0 and info.awake >= info.total) and THEME.Green or THEME.GoldLight
		end
	end

	taskLabel.Text = tostring(ZeusxHub.task or "Idle")
	timeLabel.Text = formatTime(os.clock() - startTime)
end

ZeusxHub.gui = screenGui
ZeusxHub.connection = runService.RenderStepped:Connect(onRenderStep)

return ZeusxHub
