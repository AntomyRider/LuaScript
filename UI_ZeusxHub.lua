---@module ZeusxHub.StatusUI

-- Services.
local playersService = game:GetService("Players")
local runService = game:GetService("RunService")
local httpService = game:GetService("HttpService")
local userInputService = game:GetService("UserInputService")

-- Constants.
local LOGO_ASSET = "rbxassetid://128679519864751"
local ACCENT_COLOR = Color3.fromRGB(255, 200, 40)
local BELI_COLOR = Color3.fromRGB(80, 255, 120)
local FRAGMENT_COLOR = Color3.fromRGB(180, 100, 255)
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
container.Size = UDim2.fromOffset(420, 440)
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

local statsLabel = createLabel(container, 3, 18, Color3.fromRGB(255, 255, 255))
local taskLabel = createLabel(container, 4, 16, Color3.fromRGB(180, 180, 190))
local timeLabel = createLabel(container, 5, 16, Color3.fromRGB(180, 180, 190))

-- Item images synced from the main script.
local itemHolder = Instance.new("Frame")
itemHolder.Name = "ItemHolder"
itemHolder.LayoutOrder = 6
itemHolder.Size = UDim2.new(1, 0, 0, 76)
itemHolder.BackgroundTransparency = 1
itemHolder.Parent = container

local itemList = Instance.new("ScrollingFrame")
itemList.Name = "ItemList"
itemList.Size = UDim2.fromScale(1, 1)
itemList.BackgroundTransparency = 1
itemList.BorderSizePixel = 0
itemList.ScrollBarThickness = 2
itemList.ScrollingDirection = Enum.ScrollingDirection.X
itemList.CanvasSize = UDim2.fromOffset(0, 0)
itemList.AutomaticCanvasSize = Enum.AutomaticSize.X
itemList.Parent = itemHolder

local itemLayout = Instance.new("UIListLayout")
itemLayout.FillDirection = Enum.FillDirection.Horizontal
itemLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
itemLayout.VerticalAlignment = Enum.VerticalAlignment.Center
itemLayout.SortOrder = Enum.SortOrder.LayoutOrder
itemLayout.Padding = UDim.new(0, 8)
itemLayout.Parent = itemList

-- Update only the item images. No names, quantities, or status text.
function ZeusxHub.setItems(items)
    for _, child in ipairs(itemList:GetChildren()) do
        if child:IsA("ImageLabel") then
            child:Destroy()
        end
    end

    for index, item in ipairs(items or {}) do
        if item.asset and item.asset ~= "" then
            local image = Instance.new("ImageLabel")
            image.Name = "ItemImage"
            image.Size = UDim2.fromOffset(58, 58)
            image.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
            image.BackgroundTransparency = 0.15
            image.BorderSizePixel = 0
            image.Image = item.asset
            image.ImageTransparency = item.owned and 0 or 0.5
            image.ScaleType = Enum.ScaleType.Fit
            image.LayoutOrder = index
            image.Parent = itemList

            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(0, 10)
            corner.Parent = image

        end
    end
end

-- Toggle UI visibility.
local uiVisible = true

local function toggleUI()
    uiVisible = not uiVisible

    statsLabel.Visible = uiVisible
    taskLabel.Visible = uiVisible
    timeLabel.Visible = uiVisible
    itemHolder.Visible = uiVisible

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
