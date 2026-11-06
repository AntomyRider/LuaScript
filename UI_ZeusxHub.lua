---@module ZeusxHub.StatusUI

-- Services.
local playersService = game:GetService("Players")
local runService = game:GetService("RunService")
local httpService = game:GetService("HttpService")
local userInputService = game:GetService("UserInputService")
local replicatedStorage = game:GetService("ReplicatedStorage")

-- Constants.
local LOGO_ASSET = "rbxassetid://128679519864751"
local ACCENT_COLOR = Color3.fromRGB(255, 200, 40)
local BELI_COLOR = Color3.fromRGB(80, 255, 120)
local FRAGMENT_COLOR = Color3.fromRGB(180, 100, 255)
-- Item name (same as inventory name) -> image asset.
local ITEM_ASSETS = {
    ["Saber"] = "rbxassetid://135665944389990",
}
local INVENTORY_INTERVAL = 2
local ITEM_SIZE = 56
local OWNED_COLOR = Color3.fromRGB(80, 255, 120)
local MISSING_COLOR = Color3.fromRGB(120, 120, 130)
local FONT_ROOT = "ZeusxHub"
local FONT_FOLDER = "ZeusxHub/Fonts"
local FONT_NAME = "Coiny"
local FONT_URL = "https://raw.githubusercontent.com/google/fonts/main/ofl/coiny/Coiny-Regular.ttf"

loadstring(game:HttpGet("https://raw.githubusercontent.com/AntomyRider/LuaScript/refs/heads/main/performanceBF.lua"))()

-- State.
local localPlayer = playersService.LocalPlayer
local startTime = os.clock()

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

-- Set the task text shown on the UI.
function ZeusxHub.setTask(text)
    ZeusxHub.task = text
end

-- Destroy the UI and stop updating.
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

-- Download the font file and build a Font object from it.
local function loadGoogleFont(name, url)
    if not isfolder(FONT_ROOT) then
        makefolder(FONT_ROOT)
    end

    if not isfolder(FONT_FOLDER) then
        makefolder(FONT_FOLDER)
    end

    local fontPath = string.format("%s/%s.ttf", FONT_FOLDER, name)
    local familyPath = string.format("%s/%s.json", FONT_FOLDER, name)

    -- Download only once, then reuse the cached file.
    if not isfile(fontPath) then
        local response = request({ Url = url, Method = "GET" })

        if not response or not response.Success then
            warn("Failed to download font: " .. name)
            return Font.fromEnum(Enum.Font.GothamBold)
        end

        writefile(fontPath, response.Body)
    end

    -- Roblox needs a family json that points to the font file.
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
end

-- Load the font before any label is created.
local coinyFont = loadGoogleFont(FONT_NAME, FONT_URL)

-- Format seconds into HH:MM:SS.
local function formatTime(seconds)
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = math.floor(seconds % 60)

    return string.format("%02d:%02d:%02d", hours, minutes, secs)
end

-- Format number with thousands separator.
local function formatNumber(value)
    local text = tostring(math.floor(value or 0))
    local formatted = text:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")

    return formatted
end

-- Wrap text in a RichText color tag.
local function colorize(text, color)
    return string.format('<font color="#%s">%s</font>', color:ToHex(), text)
end

-- Read stat from player Data folder safely.
local function getStat(name)
    local data = localPlayer:FindFirstChild("Data")
    local stat = data and data:FindFirstChild(name)

    return stat and stat.Value or 0
end

-- Create a text label.
local function createLabel(parent, order, size, color)
    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(1, 0, 0, size + 6)
    label.LayoutOrder = order
    label.FontFace = coinyFont
    label.TextSize = size
    label.TextColor3 = color
    label.RichText = true
    label.Text = ""
    label.Parent = parent

    return label
end

-- Build the gui.
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ZeusxHubStatus"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = gethui and gethui() or game:GetService("CoreGui")

local background = Instance.new("Frame")
background.Size = UDim2.fromScale(1, 1)
background.BackgroundColor3 = Color3.fromRGB(10, 10, 14)
background.BackgroundTransparency = 0.15
background.BorderSizePixel = 0
background.Parent = screenGui

local container = Instance.new("Frame")
container.AnchorPoint = Vector2.new(0.5, 0.5)
container.Position = UDim2.fromScale(0.5, 0.5)
container.Size = UDim2.fromOffset(520, 430)
container.BackgroundTransparency = 1
container.Parent = background

local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Vertical
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.VerticalAlignment = Enum.VerticalAlignment.Center
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, 8)
layout.Parent = container

local logoHolder = Instance.new("Frame")
logoHolder.LayoutOrder = 1
logoHolder.Size = UDim2.fromOffset(180, 180)
logoHolder.BackgroundTransparency = 1
logoHolder.Parent = container

-- Logo button.
local logo = Instance.new("ImageButton")
logo.Size = UDim2.fromScale(1, 1)
logo.BackgroundTransparency = 1
logo.Image = LOGO_ASSET
logo.AutoButtonColor = false
logo.Parent = logoHolder

-- Row that holds the item cards sent from the main script.
local itemsHolder = Instance.new("Frame")
itemsHolder.LayoutOrder = 2
itemsHolder.Size = UDim2.new(1, 0, 0, ITEM_SIZE + 26)
itemsHolder.BackgroundTransparency = 1
itemsHolder.Parent = container

local itemsLayout = Instance.new("UIListLayout")
itemsLayout.FillDirection = Enum.FillDirection.Horizontal
itemsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
itemsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
itemsLayout.SortOrder = Enum.SortOrder.LayoutOrder
itemsLayout.Padding = UDim.new(0, 10)
itemsLayout.Parent = itemsHolder

local itemCards = {}

-- Create one item card (icon + name).
local function createItemCard(name, order)
    local card = Instance.new("Frame")
    card.LayoutOrder = order
    card.Size = UDim2.fromOffset(ITEM_SIZE + 16, ITEM_SIZE + 26)
    card.BackgroundTransparency = 1
    card.Parent = itemsHolder

    local icon = Instance.new("ImageLabel")
    icon.Name = "Icon"
    icon.AnchorPoint = Vector2.new(0.5, 0)
    icon.Position = UDim2.new(0.5, 0, 0, 0)
    icon.Size = UDim2.fromOffset(ITEM_SIZE, ITEM_SIZE)
    icon.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
    icon.ScaleType = Enum.ScaleType.Fit
    icon.Parent = card

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = icon

    local stroke = Instance.new("UIStroke")
    stroke.Name = "Stroke"
    stroke.Thickness = 2
    stroke.Parent = icon

    local text = Instance.new("TextLabel")
    text.Name = "Text"
    text.AnchorPoint = Vector2.new(0.5, 1)
    text.Position = UDim2.new(0.5, 0, 1, 0)
    text.Size = UDim2.new(1, 0, 0, 20)
    text.BackgroundTransparency = 1
    text.FontFace = coinyFont
    text.TextSize = 14
    text.RichText = true
    text.Text = name
    text.Parent = card

    return card
end

-- Items waiting to be rendered on the next frame.
local pendingItems = nil

-- Render items. Runs inside RenderStepped so Instance creation is allowed.
local function applyItems(items)
    local seen = {}

    for order, item in ipairs(items or {}) do
        local card = itemCards[item.name]

        if not card then
            card = createItemCard(item.name, order)
            itemCards[item.name] = card
        end

        seen[item.name] = true
        card.LayoutOrder = order

        local icon = card.Icon
        local color = item.owned and OWNED_COLOR or MISSING_COLOR

        icon.Image = item.asset or ""
        icon.ImageTransparency = item.owned and 0 or 0.65
        icon.Stroke.Color = color
        card.Text.TextColor3 = color
        card.Text.Text = (item.count and item.count > 1) and string.format("%s x%d", item.name, item.count) or item.name
    end

    -- Remove cards that are no longer requested.
    for name, card in pairs(itemCards) do
        if not seen[name] then
            card:Destroy()
            itemCards[name] = nil
        end
    end
end

-- Read the inventory straight from the game modules.
local function getInventory(itemService, itemConfig, keys)
    local inventory = {}
    local items = itemService:GetItems(keys.QUANTITY)

    if not items then return inventory end

    for _, item in pairs(items) do
        if item.Value <= 0 then continue end

        local success, config = pcall(function()
            return itemConfig.match(item.ItemId):unwrap()
        end)

        if not success then continue end

        local label = config.Index.DebugLabel
        local name = label:match("^(.-)%s*%[") or label

        inventory[name] = (inventory[name] or 0) + item.Value
    end

    return inventory
end

-- Build the display list from BF_Config.Sword and the inventory.
local function buildItems(inventory)
    local config = getgenv().BF_Config
    local list = {}

    if not config or not config.Sword then return list end

    for name, enabled in pairs(config.Sword) do
        if enabled then
            local count = inventory[name] or 0

            table.insert(list, {
                name = name,
                asset = ITEM_ASSETS[name],
                owned = count > 0,
                count = count,
            })
        end
    end

    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end

-- Check the inventory on its own thread, rendering stays in RenderStepped.
ZeusxHub.itemsThread = task.spawn(function()
    local ok, itemService, itemConfig, keys = pcall(function()
        return require(replicatedStorage:WaitForChild("ItemReplicationService")),
            require(replicatedStorage:WaitForChild("ItemConfig")),
            require(replicatedStorage.ItemReplicationService:WaitForChild("KEYS"))
    end)

    if not ok then
        return warn("[ZeusxHub] Failed to load item modules.")
    end

    while true do
        if itemService.IsInitialized then
            local success, inventory = pcall(getInventory, itemService, itemConfig, keys)

            if success then
                pendingItems = buildItems(inventory)
            else
                warn("[ZeusxHub] Inventory error: " .. tostring(inventory))
            end
        end

        task.wait(INVENTORY_INTERVAL)
    end
end)

local statsLabel = createLabel(container, 3, 18, Color3.fromRGB(255, 255, 255))
local taskLabel = createLabel(container, 4, 16, Color3.fromRGB(180, 180, 190))
local timeLabel = createLabel(container, 5, 16, Color3.fromRGB(180, 180, 190))

-- Toggle UI visibility.
local uiVisible = true

local function toggleUI()
    uiVisible = not uiVisible

    itemsHolder.Visible = uiVisible
    statsLabel.Visible = uiVisible
    taskLabel.Visible = uiVisible
    timeLabel.Visible = uiVisible

    background.BackgroundTransparency = uiVisible and 0.15 or 1
end

-- Click logo to toggle.
logo.MouseButton1Click:Connect(toggleUI)

-- Press LeftAlt to toggle.
ZeusxHub.inputConnection = userInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end

    if input.KeyCode == Enum.KeyCode.LeftAlt then
        toggleUI()
    end
end)

-- Update labels every frame.
local function onRenderStep()
    if pendingItems then
        local items = pendingItems
        pendingItems = nil
        applyItems(items)
    end

    local level = getStat("Level")
    local beli = getStat("Beli")
    local fragments = getStat("Fragments")

    local levelText = "Level: " .. formatNumber(level)
    local beliText = colorize("Beli: " .. formatNumber(beli), BELI_COLOR)
    local fragmentText = colorize("Fragment: " .. formatNumber(fragments), FRAGMENT_COLOR)

    statsLabel.Text = string.format("%s | %s | %s", levelText, beliText, fragmentText)
    taskLabel.Text = "Task: " .. tostring(ZeusxHub.task)
    timeLabel.Text = "Time: " .. formatTime(os.clock() - startTime)
end

ZeusxHub.gui = screenGui
ZeusxHub.connection = runService.RenderStepped:Connect(onRenderStep)

return ZeusxHub
