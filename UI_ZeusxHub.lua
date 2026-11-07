---@module ZeusxHub.StatusUI

-- Services.
local playersService = game:GetService("Players")
local runService = game:GetService("RunService")
local httpService = game:GetService("HttpService")
local userInputService = game:GetService("UserInputService")
local replicatedStorage = game:GetService("ReplicatedStorage")

-- Theme: Cute Minimal Gold & Bronze.
local THEME = {
    Background = Color3.fromRGB(25, 20, 15),
    Panel = Color3.fromRGB(39, 31, 23),
    Section = Color3.fromRGB(49, 39, 28),
    Card = Color3.fromRGB(63, 49, 34),
    Border = Color3.fromRGB(128, 101, 59),
    Gold = Color3.fromRGB(232, 196, 119),
    GoldLight = Color3.fromRGB(247, 224, 177),
    Text = Color3.fromRGB(245, 229, 197),
    Muted = Color3.fromRGB(191, 167, 125),
    Green = Color3.fromRGB(139, 211, 151),
    Purple = Color3.fromRGB(190, 157, 224),
    Blue = Color3.fromRGB(151, 195, 220),
    Missing = Color3.fromRGB(145, 130, 108),
}

local ITEM_ASSETS = {
    ["Godhuman"] = "rbxassetid://75176997304682",
    ["Saber"] = "rbxassetid://135665944389990",
    ["Yama"] = "rbxassetid://138342732332076",
    ["Tushita"] = "rbxassetid://127659543896119",
    ["Cursed Dual Katana"] = "rbxassetid://139876489530430",
    ["Hallow Scythe"] = "rbxassetid://108136486901075",
}

-- Items recognized from the player's quantity inventory.
-- Items without an image asset use a text placeholder automatically.
local ITEM_CATALOG = {
    -- Melee / Sword.
    { name = "Godhuman", category = "Combat" },
    { name = "Saber", category = "Combat" },
    { name = "Yama", category = "Combat" },
    { name = "Tushita", category = "Combat" },
    { name = "Cursed Dual Katana", category = "Combat" },
    { name = "Hallow Scythe", category = "Combat" },

    -- Accessories / Items.
    { name = "Dark Fragment", category = "Items" },
    { name = "Valkyrie Helm", category = "Items" },
    { name = "Mirror Fractal", category = "Items" },
    { name = "God's Chalice", category = "Items" },
    { name = "Fist of Darkness", category = "Items" },
    { name = "Hallow Essence", category = "Items" },
    { name = "Fire Essence", category = "Items" },
    { name = "Alucard Fragment", category = "Items" },
    { name = "Library Key", category = "Items" },
    { name = "Holy Torch", category = "Items" },
    { name = "Musketeer Hat", category = "Items" },
    { name = "Swan Glasses", category = "Items" },
    { name = "Pale Scarf", category = "Items" },
    { name = "Lei", category = "Items" },
    { name = "Kitsune Ribbon", category = "Items" },
    { name = "Dragon Scale", category = "Items" },
    { name = "Radioactive Material", category = "Items" },
    { name = "Mystic Droplet", category = "Items" },
    { name = "Vampire Fang", category = "Items" },
    { name = "Magma Ore", category = "Items" },
    { name = "Scrap Metal", category = "Items" },
    { name = "Leather", category = "Items" },
    { name = "Fish Tail", category = "Items" },
    { name = "Conjured Cocoa", category = "Items" },
    { name = "Ectoplasm", category = "Items" },
    { name = "Bones", category = "Items" },
}

-- Normalize inventory labels.
local ITEM_NAME_LOOKUP = {}

local function normalizeItemName(name)
    name = tostring(name or "")
    name = name:match("^(.-)%s*%[") or name
    name = name:lower():gsub("[%s%p_]+", "")
    return name
end

for _, itemInfo in ipairs(ITEM_CATALOG) do
    ITEM_NAME_LOOKUP[normalizeItemName(itemInfo.name)] = itemInfo.name
end

-- Optional aliases for labels that may differ in ItemConfig.
ITEM_NAME_LOOKUP[normalizeItemName("Valkyrie Helmet")] = "Valkyrie Helm"
ITEM_NAME_LOOKUP[normalizeItemName("Mirror Fractal")] = "Mirror Fractal"
ITEM_NAME_LOOKUP[normalizeItemName("Dark Fragment")] = "Dark Fragment"

local INVENTORY_INTERVAL = 2
local AWAKEN_INTERVAL = 5
local AWAKEN_REMOTE = "getAwakenedAbilities"

-- Press Start 2P Font.
local FONT_ROOT = "ZeusxHub"
local FONT_FOLDER = "ZeusxHub/Fonts"
local FONT_NAME = "PressStart2P"
local FONT_URL = "https://raw.githubusercontent.com/google/fonts/main/ofl/pressstart2p/PressStart2P-Regular.ttf"

loadstring(game:HttpGet("https://raw.githubusercontent.com/AntomyRider/LuaScript/refs/heads/main/performanceBF.lua"))()

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

-- Set task text.
function ZeusxHub.setTask(text)
    ZeusxHub.task = text
end

-- Destroy UI.
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

local pressStartFont = loadGoogleFont(FONT_NAME, FONT_URL)

-- Format time.
local function formatTime(seconds)
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = math.floor(seconds % 60)

    return string.format("%02d:%02d:%02d", hours, minutes, secs)
end

-- Format number.
local function formatNumber(value)
    local text = tostring(math.floor(tonumber(value) or 0))

    return text:reverse()
        :gsub("(%d%d%d)", "%1,")
        :reverse()
        :gsub("^,", "")
end

-- Read player stat.
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
    stroke.Parent = object

    return stroke
end

local function createText(parent, name, text, size, color, position, dimensions)
    local label = Instance.new("TextLabel")
    label.Name = name
    label.BackgroundTransparency = 1
    label.Position = position or UDim2.new()
    label.Size = dimensions or UDim2.new(1, 0, 0, 22)
    label.FontFace = pressStartFont
    label.Text = text or ""
    label.TextSize = size or 14
    label.TextColor3 = color or THEME.Text
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextYAlignment = Enum.TextYAlignment.Center
    label.TextTruncate = Enum.TextTruncate.AtEnd
    label.Parent = parent

    return label
end

local function createSection(parent, name, title, height)
    local section = Instance.new("Frame")
    section.Name = name
    section.Size = UDim2.new(1, 0, 0, height)
    section.BackgroundColor3 = THEME.Section
    section.BorderSizePixel = 0
    section.Parent = parent

    addCorner(section, 11)
    addStroke(section, THEME.Border, 1, 0.15)

    local titleLabel = createText(
        section,
        "SectionTitle",
        title,
        14,
        THEME.Gold,
        UDim2.fromOffset(12, 5),
        UDim2.new(1, -24, 0, 20)
    )

    titleLabel.TextXAlignment = Enum.TextXAlignment.Left

    return section
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
background.BackgroundTransparency = 1
background.BorderSizePixel = 0
background.Parent = screenGui

local container = Instance.new("Frame")
container.Name = "MainPanel"
container.AnchorPoint = Vector2.new(0.5, 0.5)
container.Position = UDim2.fromScale(0.5, 0.5)
container.Size = UDim2.fromOffset(590, 600)
container.BackgroundColor3 = THEME.Background
container.BorderSizePixel = 0
container.Parent = background

addCorner(container, 16)
addStroke(container, THEME.Gold, 1.4, 0.08)

local containerPadding = Instance.new("UIPadding")
containerPadding.PaddingTop = UDim.new(0, 11)
containerPadding.PaddingBottom = UDim.new(0, 11)
containerPadding.PaddingLeft = UDim.new(0, 11)
containerPadding.PaddingRight = UDim.new(0, 11)
containerPadding.Parent = container

local mainLayout = Instance.new("UIListLayout")
mainLayout.FillDirection = Enum.FillDirection.Vertical
mainLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
mainLayout.VerticalAlignment = Enum.VerticalAlignment.Top
mainLayout.SortOrder = Enum.SortOrder.LayoutOrder
mainLayout.Padding = UDim.new(0, 8)
mainLayout.Parent = container

-- Section 1: Player profile and stats.
local playerSection = createSection(
    container,
    "PlayerSection",
    "PLAYER PROFILE",
    112
)
playerSection.LayoutOrder = 1

local profileImage = Instance.new("ImageButton")
profileImage.Name = "PlayerThumbnail"
profileImage.Position = UDim2.fromOffset(12, 27)
profileImage.Size = UDim2.fromOffset(76, 76)
profileImage.BackgroundColor3 = THEME.Card
profileImage.BorderSizePixel = 0
profileImage.AutoButtonColor = false
profileImage.ScaleType = Enum.ScaleType.Crop
profileImage.Parent = playerSection

addCorner(profileImage, 10)
addStroke(profileImage, THEME.Gold, 1.2, 0.1)

local profileInfo = Instance.new("Frame")
profileInfo.Name = "ProfileInfo"
profileInfo.Position = UDim2.fromOffset(101, 27)
profileInfo.Size = UDim2.new(1, -113, 0, 77)
profileInfo.BackgroundTransparency = 1
profileInfo.Parent = playerSection

local profileLayout = Instance.new("UIListLayout")
profileLayout.FillDirection = Enum.FillDirection.Vertical
profileLayout.SortOrder = Enum.SortOrder.LayoutOrder
profileLayout.Padding = UDim.new(0, 1)
profileLayout.Parent = profileInfo

local playerNameLabel = createText(
    profileInfo,
    "PlayerName",
    localPlayer.DisplayName .. "  (@" .. localPlayer.Name .. ")",
    16,
    THEME.GoldLight,
    nil,
    UDim2.new(1, 0, 0, 23)
)
playerNameLabel.LayoutOrder = 1

local levelLabel = createText(
    profileInfo,
    "Level",
    "Level : 0",
    13,
    THEME.Text,
    nil,
    UDim2.new(1, 0, 0, 17)
)
levelLabel.LayoutOrder = 2

local beliLabel = createText(
    profileInfo,
    "Beli",
    "Beli : 0",
    13,
    THEME.Green,
    nil,
    UDim2.new(1, 0, 0, 17)
)
beliLabel.LayoutOrder = 3

local fragmentLabel = createText(
    profileInfo,
    "Fragments",
    "Fragment : 0",
    13,
    THEME.Purple,
    nil,
    UDim2.new(1, 0, 0, 17)
)
fragmentLabel.LayoutOrder = 4

-- Load player thumbnail for the profile and the minimized button.
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
local fruitSection = createSection(
    container,
    "FruitSection",
    "FRUIT STATUS",
    83
)
fruitSection.LayoutOrder = 2

local fruitContent = Instance.new("Frame")
fruitContent.Name = "FruitContent"
fruitContent.Position = UDim2.fromOffset(10, 27)
fruitContent.Size = UDim2.new(1, -20, 0, 46)
fruitContent.BackgroundTransparency = 1
fruitContent.Parent = fruitSection

local fruitColumns = {}
local fruitColumnNames = {
    "Fruit",
    "Mastery",
    "Awakening"
}

for index, columnName in ipairs(fruitColumnNames) do
    local column = Instance.new("Frame")
    column.Name = columnName .. "Column"
    column.Position = UDim2.new((index - 1) / 3, 0, 0, 0)
    column.Size = UDim2.new(1 / 3, index == 3 and 0 or -1, 1, 0)
    column.BackgroundTransparency = 1
    column.Parent = fruitContent

    if index > 1 then
        local separator = Instance.new("Frame")
        separator.Name = "VerticalBorder"
        separator.Position = UDim2.fromOffset(0, 3)
        separator.Size = UDim2.new(0, 1, 1, -6)
        separator.BackgroundColor3 = THEME.Border
        separator.BorderSizePixel = 0
        separator.Parent = column
    end

    local value = createText(
        column,
        "Value",
        "-",
        14,
        THEME.Text,
        UDim2.new(0, 8, 0, 0),
        UDim2.new(1, -16, 0, 24)
    )
    value.TextXAlignment = Enum.TextXAlignment.Center

    local caption = createText(
        column,
        "Caption",
        columnName,
        11,
        THEME.Muted,
        UDim2.new(0, 8, 0, 23),
        UDim2.new(1, -16, 0, 18)
    )
    caption.TextXAlignment = Enum.TextXAlignment.Center

    fruitColumns[columnName] = value
end

-- Section 3: Current task.
local taskSection = createSection(
    container,
    "TaskSection",
    "CURRENT TASK",
    57
)
taskSection.LayoutOrder = 3

local taskIcon = createText(
    taskSection,
    "TaskIcon",
    "✦",
    17,
    THEME.Gold,
    UDim2.fromOffset(13, 27),
    UDim2.fromOffset(22, 22)
)
taskIcon.TextXAlignment = Enum.TextXAlignment.Center

local taskLabel = createText(
    taskSection,
    "Task",
    "Idle",
    14,
    THEME.Text,
    UDim2.fromOffset(40, 27),
    UDim2.new(1, -160, 0, 22)
)

local timeLabel = createText(
    taskSection,
    "Runtime",
    "00:00:00",
    12,
    THEME.Muted,
    UDim2.new(1, -112, 0, 27),
    UDim2.fromOffset(100, 22)
)
timeLabel.TextXAlignment = Enum.TextXAlignment.Right

-- Item section helpers.
local itemCards = {}

local function createItemGrid(section, name, height)
    local scrolling = Instance.new("ScrollingFrame")
    scrolling.Name = name
    scrolling.Position = UDim2.fromOffset(10, 28)
    scrolling.Size = UDim2.new(1, -20, 0, height)
    scrolling.BackgroundTransparency = 1
    scrolling.BorderSizePixel = 0
    scrolling.ScrollBarThickness = 3
    scrolling.ScrollBarImageColor3 = THEME.Gold
    scrolling.CanvasSize = UDim2.new(0, 0, 0, 0)
    scrolling.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scrolling.ScrollingDirection = Enum.ScrollingDirection.Y
    scrolling.Parent = section

    local grid = Instance.new("UIGridLayout")
    grid.CellSize = UDim2.fromOffset(84, 77)
    grid.CellPadding = UDim2.fromOffset(6, 6)
    grid.FillDirection = Enum.FillDirection.Horizontal
    grid.FillDirectionMaxCells = 6
    grid.SortOrder = Enum.SortOrder.LayoutOrder
    grid.Parent = scrolling

    return scrolling
end

-- Section 4: Melee / Sword.
local combatSection = createSection(
    container,
    "CombatSection",
    "MELEE / SWORD",
    119
)
combatSection.LayoutOrder = 4

local combatGrid = createItemGrid(
    combatSection,
    "CombatItems",
    82
)

-- Section 5: Accessories / Items.
local itemsSection = createSection(
    container,
    "ItemsSection",
    "ACCESSORY / ITEMS",
    166
)
itemsSection.LayoutOrder = 5

local inventoryGrid = createItemGrid(
    itemsSection,
    "InventoryItems",
    129
)

-- Mini icon used when the dashboard is hidden.
-- It uses the player's avatar, not a logo.
miniIcon = Instance.new("ImageButton")
miniIcon.Name = "MiniIcon"
miniIcon.AnchorPoint = Vector2.new(0.5, 0)
miniIcon.Position = UDim2.new(0.5, 0, 0, 35)
miniIcon.Size = UDim2.fromOffset(44, 44)
miniIcon.BackgroundColor3 = THEME.Panel
miniIcon.BackgroundTransparency = 0.05
miniIcon.BorderSizePixel = 0
miniIcon.Image = playerThumbnail
miniIcon.ScaleType = Enum.ScaleType.Crop
miniIcon.AutoButtonColor = true
miniIcon.Visible = false
miniIcon.Parent = screenGui

addCorner(miniIcon, 22)
addStroke(miniIcon, THEME.Gold, 1.5, 0)

-- Create an item card.
-- Items without an image use a short text placeholder.
local function createItemCard(item, order, parent)
    local card = Instance.new("Frame")
    card.Name = "Item_" .. item.name:gsub("%W", "")
    card.LayoutOrder = order
    card.BackgroundColor3 = THEME.Card
    card.BorderSizePixel = 0
    card.Parent = parent

    addCorner(card, 8)
    addStroke(card, THEME.Border, 1, 0.25)

    local icon = Instance.new("ImageLabel")
    icon.Name = "Icon"
    icon.AnchorPoint = Vector2.new(0.5, 0)
    icon.Position = UDim2.new(0.5, 0, 0, 5)
    icon.Size = UDim2.fromOffset(39, 39)
    icon.BackgroundTransparency = 1
    icon.BorderSizePixel = 0
    icon.ScaleType = Enum.ScaleType.Fit
    icon.Image = item.asset or ""
    icon.Visible = item.asset ~= nil
    icon.Parent = card

    local placeholder = createText(
        card,
        "Placeholder",
        string.upper(item.name:sub(1, 2)),
        18,
        THEME.Gold,
        UDim2.new(0, 0, 0, 5),
        UDim2.new(1, 0, 0, 39)
    )
    placeholder.TextXAlignment = Enum.TextXAlignment.Center
    placeholder.Visible = not item.asset

    local divider = Instance.new("Frame")
    divider.Name = "Divider"
    divider.Position = UDim2.new(0, 5, 0, 47)
    divider.Size = UDim2.new(1, -10, 0, 1)
    divider.BackgroundColor3 = THEME.Border
    divider.BorderSizePixel = 0
    divider.Parent = card

    local itemName = createText(
        card,
        "ItemName",
        item.name,
        10,
        THEME.GoldLight,
        UDim2.new(0, 3, 0, 50),
        UDim2.new(1, -6, 0, 20)
    )
    itemName.TextXAlignment = Enum.TextXAlignment.Center

    local countLabel = createText(
        card,
        "Count",
        item.count and item.count > 1 and ("x" .. tostring(item.count)) or "",
        9,
        THEME.Green,
        UDim2.new(1, -25, 0, 2),
        UDim2.fromOffset(22, 14)
    )
    countLabel.TextXAlignment = Enum.TextXAlignment.Right

    return card
end

-- Pending data from the inventory thread.
local pendingItems = nil
local pendingFruit = nil

-- Apply inventory items to the two separate categories.
local function applyItems(items)
    local seen = {}

    for order, item in ipairs(items or {}) do
        local card = itemCards[item.name]
        local parent = item.category == "Combat" and combatGrid or inventoryGrid

        if card and card.Parent ~= parent then
            card:Destroy()
            card = nil
            itemCards[item.name] = nil
        end

        if not card then
            card = createItemCard(item, order, parent)
            itemCards[item.name] = card
        end

        seen[item.name] = true
        card.LayoutOrder = order
        card.ItemName.Text = item.name
        card.Icon.Image = item.asset or ""
        card.Icon.Visible = item.asset ~= nil
        card.Placeholder.Visible = not item.asset
        card.Count.Text = item.count and item.count > 1 and ("x" .. tostring(item.count)) or ""
    end

    for name, card in pairs(itemCards) do
        if not seen[name] then
            card:Destroy()
            itemCards[name] = nil
        end
    end
end

-- Read player inventory.
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

        local debugLabel = config.Index.DebugLabel
        local canonicalName = ITEM_NAME_LOOKUP[normalizeItemName(debugLabel)]

        if canonicalName then
            inventory[canonicalName] = (inventory[canonicalName] or 0) + item.Value
        end
    end

    return inventory
end

-- Build items list from the catalog.
local function buildItems(inventory)
    local list = {}

    for _, itemInfo in ipairs(ITEM_CATALOG) do
        local count = inventory[itemInfo.name] or 0

        if count > 0 then
            table.insert(list, {
                name = itemInfo.name,
                asset = ITEM_ASSETS[itemInfo.name],
                category = itemInfo.category,
                owned = true,
                count = count,
            })
        end
    end

    table.sort(list, function(a, b)
        if a.category == b.category then
            return a.name < b.name
        end

        return a.category < b.category
    end)

    return list
end

-- Get the fruit the player has currently eaten.
local function getEatenFruit()
    local data = localPlayer:FindFirstChild("Data")
    local value = data and data:FindFirstChild("DevilFruit")

    if value and value.Value ~= "" then
        return value.Value
    end

    return nil
end

-- Get only the first word of a fruit name (Ice-Ice -> Ice).
local function getShortFruitName(name)
    return name:match("^[^%-%s]+") or name
end

-- Read mastery of a fruit from item replication.
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

-- Count awakened skills against total skills.
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
            local success, inventory = pcall(
                getInventory,
                itemService,
                itemConfig,
                keys
            )

            if success then
                pendingItems = buildItems(inventory)
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

                local okMastery, mastery = pcall(
                    getFruitMastery,
                    itemService,
                    itemConfig,
                    keys,
                    eaten
                )

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

-- Press LeftAlt to toggle.
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
        local items = pendingItems
        pendingItems = nil
        applyItems(items)
    end

    local level = getStat("Level")
    local beli = getStat("Beli")
    local fragments = getStat("Fragments")

    levelLabel.Text = "Level : " .. formatNumber(level)
    beliLabel.Text = "Beli : " .. formatNumber(beli)
    fragmentLabel.Text = "Fragment : " .. formatNumber(fragments)

    if pendingFruit ~= nil then
        local info = pendingFruit

        if not info then
            fruitColumns.Fruit.Text = "None"
            fruitColumns.Mastery.Text = "-"
            fruitColumns.Awakening.Text = "0/0"
        else
            fruitColumns.Fruit.Text = getShortFruitName(info.name)
            fruitColumns.Mastery.Text = formatNumber(info.mastery)
            fruitColumns.Awakening.Text = string.format(
                "%d/%d",
                info.awake,
                info.total
            )

            if info.total > 0 and info.awake >= info.total then
                fruitColumns.Awakening.TextColor3 = THEME.Green
            else
                fruitColumns.Awakening.TextColor3 = THEME.GoldLight
            end
        end
    end

    taskLabel.Text = tostring(ZeusxHub.task or "Idle")
    timeLabel.Text = formatTime(os.clock() - startTime)
end

-- Start update.
ZeusxHub.gui = screenGui
ZeusxHub.connection = runService.RenderStepped:Connect(onRenderStep)

return ZeusxHub
