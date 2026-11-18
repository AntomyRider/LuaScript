-- Check for table that is shared between executions.
if not shared then
	return warn("No shared, no script.")
end

-- Initialize Luraph globals if they do not exist.
loadstring("getfenv().LPH_NO_VIRTUALIZE = function(...) return ... end")()

-- Module table.
local MobOnlyView = {
	connections = {},
	running = false,
	pass = 0,
	cache = {},
	queue = {},
	terrainColors = {},
	notifications = nil,
	notificationsParent = nil,
}

-- Constants.
local FRAME_BUDGET = 0.004
local QUEUE_BUDGET = 0.003
local LOW_QUALITY = true
local REMOVE_NOTIFICATIONS = true
local REMOVE_WATER_EFFECTS = true
local WHITE = Color3.fromRGB(255, 255, 255)

-- Classes that are simply switched off.
local DISABLED_CLASSES = {
	ParticleEmitter = true,
	Trail = true,
	Beam = true,
	Smoke = true,
	Fire = true,
	Sparkles = true,
	PointLight = true,
	SpotLight = true,
	SurfaceLight = true,
	BloomEffect = true,
	BlurEffect = true,
	ColorCorrectionEffect = true,
	DepthOfFieldEffect = true,
	SunRaysEffect = true,
	Highlight = true,
	SurfaceGui = true,
	BillboardGui = true,
}

-- Clothing classes mapped to the property that holds their texture.
local CLOTHING_CLASSES = {
	Shirt = "ShirtTemplate",
	Pants = "PantsTemplate",
	ShirtGraphic = "Graphic",
}

-- Body color properties of BodyColors.
local BODY_COLOR_PROPERTIES = {
	"HeadColor3",
	"TorsoColor3",
	"LeftArmColor3",
	"RightArmColor3",
	"LeftLegColor3",
	"RightLegColor3",
}

-- Terrain water properties and the value that removes their effect.
local WATER_PROPERTIES = {
	WaterTransparency = 1,
	WaterReflectance = 0,
	WaterWaveSize = 0,
	WaterWaveSpeed = 0,
}

-- Lighting properties lowered and whitened.
local LIGHTING_PROPERTIES = {
	GlobalShadows = false,
	ShadowSoftness = 0,
	EnvironmentDiffuseScale = 0,
	EnvironmentSpecularScale = 0,
	Ambient = WHITE,
	OutdoorAmbient = WHITE,
	FogColor = WHITE,
	FogEnd = 1000000,
	FogStart = 1000000,
}

-- Services.
local playersService = game:GetService("Players")
local workspaceService = game:GetService("Workspace")
local lightingService = game:GetService("Lighting")
local runService = game:GetService("RunService")

-- State.
local localPlayer = playersService.LocalPlayer

---Write a property and remember its original value.
---@param instance Instance
---@param property string
---@param value any
local function setProperty(instance, property, value)
	local current = instance[property]

	-- Skip redundant writes to save performance.
	if current == value then
		return
	end

	local entry = MobOnlyView.cache[instance]
	if not entry then
		entry = {}
		MobOnlyView.cache[instance] = entry
	end

	if entry[property] == nil then
		entry[property] = current
	end

	instance[property] = value
end

---Paint every terrain material white and flatten the water.
local function whitenTerrain()
	local terrain = workspaceService:FindFirstChildOfClass("Terrain")
	if not terrain then
		return
	end

	for _, material in ipairs(Enum.Material:GetEnumItems()) do
		pcall(function()
			if not MobOnlyView.terrainColors[material] then
				MobOnlyView.terrainColors[material] = terrain:GetMaterialColor(material)
			end

			terrain:SetMaterialColor(material, WHITE)
		end)
	end

	if not REMOVE_WATER_EFFECTS then
		return
	end

	for property, value in pairs(WATER_PROPERTIES) do
		pcall(setProperty, terrain, property, value)
	end

	pcall(setProperty, terrain, "Decoration", false)
end

---Restore the original terrain material colors.
local function restoreTerrain()
	local terrain = workspaceService:FindFirstChildOfClass("Terrain")
	if not terrain then
		return
	end

	for material, color in pairs(MobOnlyView.terrainColors) do
		pcall(terrain.SetMaterialColor, terrain, material, color)
	end

	table.clear(MobOnlyView.terrainColors)
end

---Lower every global graphics setting and turn the lighting white.
local function applyLowSettings()
	pcall(setProperty, settings().Rendering, "QualityLevel", Enum.QualityLevel.Level01)

	for property, value in pairs(LIGHTING_PROPERTIES) do
		pcall(setProperty, lightingService, property, value)
	end
end

---Remove the Notifications gui, remembering its parent for restoring.
local function removeNotifications()
	local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
	local notifications = playerGui and playerGui:FindFirstChild("Notifications")
	if not notifications then
		return
	end

	MobOnlyView.notifications = notifications
	MobOnlyView.notificationsParent = playerGui
	notifications.Parent = nil
end

---Put the Notifications gui back where it was.
local function restoreNotifications()
	local notifications = MobOnlyView.notifications
	local parent = MobOnlyView.notificationsParent

	if notifications and parent then
		pcall(function()
			notifications.Parent = parent
		end)
	end

	MobOnlyView.notifications = nil
	MobOnlyView.notificationsParent = nil
end

---Turn a part into flat white.
---@param part BasePart
local function whitenPart(part)
	-- Leave fully invisible helper parts alone.
	if part.Transparency >= 1 then
		return
	end

	setProperty(part, "Material", Enum.Material.SmoothPlastic)
	setProperty(part, "Color", WHITE)
	setProperty(part, "Reflectance", 0)
	setProperty(part, "CastShadow", false)

	-- Unions can keep their own colors, force the part color.
	if part:IsA("UnionOperation") then
		pcall(setProperty, part, "UsePartColor", true)
	end

	-- Cheapest mesh rendering and no mesh texture.
	if part:IsA("MeshPart") then
		pcall(setProperty, part, "RenderFidelity", Enum.RenderFidelity.Performance)
		pcall(setProperty, part, "TextureID", "")
	end
end

---Whiten one instance.
---@param instance Instance
local function processInstance(instance)
	if instance:IsA("Terrain") then
		return
	end

	local className = instance.ClassName

	if instance:IsA("BasePart") then
		whitenPart(instance)
		return
	end

	if DISABLED_CLASSES[className] then
		pcall(setProperty, instance, "Enabled", false)
		return
	end

	if className == "Atmosphere" then
		pcall(setProperty, instance, "Density", 0)
		pcall(setProperty, instance, "Haze", 0)
		pcall(setProperty, instance, "Color", WHITE)
		pcall(setProperty, instance, "Decay", WHITE)
	elseif className == "Sky" then
		pcall(setProperty, instance, "StarCount", 0)
		pcall(setProperty, instance, "CelestialBodiesShown", false)
	elseif className == "ForceField" then
		pcall(setProperty, instance, "Visible", false)
	elseif className == "BodyColors" then
		for _, property in ipairs(BODY_COLOR_PROPERTIES) do
			pcall(setProperty, instance, property, WHITE)
		end
	elseif instance:IsA("Decal") or instance:IsA("Texture") then
		pcall(setProperty, instance, "Transparency", 1)
	elseif CLOTHING_CLASSES[className] then
		pcall(setProperty, instance, CLOTHING_CLASSES[className], "")
	elseif className == "SpecialMesh" then
		pcall(setProperty, instance, "TextureId", "")
		pcall(setProperty, instance, "VertexColor", Vector3.new(1, 1, 1))
	elseif className == "SurfaceAppearance" then
		pcall(setProperty, instance, "ColorMap", "")
	end
end

---Restore every property that was changed.
local function restoreAll()
	for instance, properties in pairs(MobOnlyView.cache) do
		for property, value in pairs(properties) do
			pcall(function()
				instance[property] = value
			end)
		end
	end

	table.clear(MobOnlyView.cache)
	table.clear(MobOnlyView.queue)
	restoreTerrain()
end

---Process a container's descendants within a time budget per frame.
---@param root Instance
---@param pass number
local function processContainer(root, pass)
	local frameStart = os.clock()

	for _, instance in ipairs(root:GetDescendants()) do
		if not MobOnlyView.running or MobOnlyView.pass ~= pass then
			return
		end

		pcall(processInstance, instance)

		-- Yield by time instead of by count so frames never spike.
		if os.clock() - frameStart >= FRAME_BUDGET then
			task.wait()
			frameStart = os.clock()
		end
	end
end

---Drain newly added instances in small slices.
local function drainQueue()
	local queue = MobOnlyView.queue
	local start = os.clock()

	while #queue > 0 and os.clock() - start < QUEUE_BUDGET do
		local instance = table.remove(queue)
		if instance and instance.Parent then
			pcall(processInstance, instance)
		end
	end
end

---Reset everything and apply white from scratch.
local function applyAll()
	MobOnlyView.pass = MobOnlyView.pass + 1
	local pass = MobOnlyView.pass

	restoreAll()

	if LOW_QUALITY then
		pcall(applyLowSettings)
	end

	pcall(whitenTerrain)

	-- Everything in workspace plus lighting objects (sky, atmosphere, effects).
	task.spawn(function()
		processContainer(workspaceService, pass)
		processContainer(lightingService, pass)
	end)
end

---Stop and restore everything.
function MobOnlyView.detach()
	MobOnlyView.running = false
	MobOnlyView.pass = MobOnlyView.pass + 1

	for _, connection in ipairs(MobOnlyView.connections) do
		pcall(function()
			connection:Disconnect()
		end)
	end

	table.clear(MobOnlyView.connections)
	restoreAll()
	restoreNotifications()
end

---Start the script.
function MobOnlyView.init()
	MobOnlyView.running = true

	-- Remove the notifications gui first.
	if REMOVE_NOTIFICATIONS then
		pcall(removeNotifications)
	end

	applyAll()

	-- Queue anything new in workspace and lighting instead of processing it instantly.
	for _, container in ipairs({ workspaceService, lightingService }) do
		table.insert(
			MobOnlyView.connections,
			container.DescendantAdded:Connect(function(instance)
				table.insert(MobOnlyView.queue, instance)
			end)
		)
	end

	-- Drain the queue once per frame within a small time budget.
	table.insert(MobOnlyView.connections, runService.Heartbeat:Connect(drainQueue))

	-- Remove Notifications again if the game re-creates it.
	if REMOVE_NOTIFICATIONS then
		table.insert(
			MobOnlyView.connections,
			localPlayer.DescendantAdded:Connect(function(instance)
				if instance.Name == "Notifications" and instance.Parent == localPlayer:FindFirstChildOfClass("PlayerGui") then
					task.defer(pcall, removeNotifications)
				end
			end)
		)
	end

	-- Keep lighting white if the game changes it back.
	if LOW_QUALITY then
		for property, value in pairs(LIGHTING_PROPERTIES) do
			table.insert(
				MobOnlyView.connections,
				lightingService:GetPropertyChangedSignal(property):Connect(function()
					if lightingService[property] ~= value then
						pcall(setProperty, lightingService, property, value)
					end
				end)
			)
		end
	end
end

---This is called when initialization errors.
---@param error string
local function onInitializeError(error)
	warn("Failed to initialize.")
	warn(error)
	warn(debug.traceback())
	MobOnlyView.detach()
end

-- Detach the previous instance before re-initializing.
if shared.MobOnlyView then
	shared.MobOnlyView.detach()
end

shared.MobOnlyView = MobOnlyView
xpcall(MobOnlyView.init, onInitializeError)

return MobOnlyView
