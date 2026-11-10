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
	hideObjects = true,
	pass = 0,
	cache = {},
	ground = {},
	notifications = nil,
	notificationsParent = nil,
}

-- Constants.
local BATCH_SIZE = 750
local GROUND_INTERVAL = 0.5
local GROUND_RAY_LENGTH = 50
local HIDE_OBJECTS = true
local LOW_QUALITY = true
local KEEP_GROUND_VISIBLE = false
local HIDE_OTHER_PLAYERS = false
local REMOVE_NOTIFICATIONS = true
local REMOVE_WATER_EFFECTS = true
local LOCAL_CLAY_COLOR = Color3.fromRGB(120, 200, 255)
local PLAYER_CLAY_COLOR = Color3.fromRGB(255, 170, 200)

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
}

-- Clothing classes mapped to the property that holds their texture.
local CLOTHING_CLASSES = {
	Shirt = "ShirtTemplate",
	Pants = "PantsTemplate",
	ShirtGraphic = "Graphic",
}

-- Terrain water properties and the value that removes their effect.
local WATER_PROPERTIES = {
	WaterTransparency = 1,
	WaterReflectance = 0,
	WaterWaveSize = 0,
	WaterWaveSpeed = 0,
}

-- Lighting properties lowered for the low quality mode.
local LOW_LIGHTING_PROPERTIES = {
	GlobalShadows = false,
	ShadowSoftness = 0,
	EnvironmentDiffuseScale = 0,
	EnvironmentSpecularScale = 0,
}

-- Services.
local playersService = game:GetService("Players")
local workspaceService = game:GetService("Workspace")
local lightingService = game:GetService("Lighting")

-- State.
local localPlayer = playersService.LocalPlayer

---Check whether a model is a living entity (mob, NPC, player).
---@param model Instance
---@return boolean
local function isLivingModel(model)
	return model:FindFirstChildOfClass("Humanoid") ~= nil
		or model:FindFirstChildOfClass("AnimationController") ~= nil
end

---Find the living model an instance belongs to.
---@param instance Instance
---@return Model?
local function getLivingModel(instance)
	local current = instance.Parent

	while current and current ~= game do
		if current:IsA("Model") and isLivingModel(current) then
			local owner = playersService:GetPlayerFromCharacter(current)

			-- Other players can be hidden when requested.
			if HIDE_OTHER_PLAYERS and owner and owner ~= localPlayer then
				return nil
			end

			return current
		end

		current = current.Parent
	end

	return nil
end

---Pick the clay color for a living model.
---@param model Model
---@return Color3
local function getClayColor(model)
	local owner = playersService:GetPlayerFromCharacter(model)

	if owner == localPlayer then
		return LOCAL_CLAY_COLOR
	end

	if owner then
		return PLAYER_CLAY_COLOR
	end

	-- Mobs get a stable pastel color from their name.
	local hash = 0
	for index = 1, #model.Name do
		hash = (hash * 31 + model.Name:byte(index)) % 360
	end

	return Color3.fromHSV(hash / 360, 0.5, 1)
end

---Write a property and remember its original value.
---@param instance Instance
---@param property string
---@param value any
local function setProperty(instance, property, value)
	local entry = MobOnlyView.cache[instance]
	if not entry then
		entry = {}
		MobOnlyView.cache[instance] = entry
	end

	if entry[property] == nil then
		entry[property] = instance[property]
	end

	instance[property] = value
end

---Flatten the terrain water so it has no visual effect.
local function removeWaterEffects()
	local terrain = workspaceService:FindFirstChildOfClass("Terrain")
	if not terrain then
		return
	end

	for property, value in pairs(WATER_PROPERTIES) do
		pcall(setProperty, terrain, property, value)
	end
end

---Lower every global graphics setting.
local function applyLowSettings()
	pcall(setProperty, settings().Rendering, "QualityLevel", Enum.QualityLevel.Level01)

	for property, value in pairs(LOW_LIGHTING_PROPERTIES) do
		pcall(setProperty, lightingService, property, value)
	end

	local terrain = workspaceService:FindFirstChildOfClass("Terrain")
	if terrain then
		pcall(setProperty, terrain, "Decoration", false)
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

---Turn a part into flat clay.
---@param part BasePart
---@param color Color3
local function clayifyPart(part, color)
	-- Leave invisible helper parts alone.
	if part.Transparency >= 1 then
		return
	end

	setProperty(part, "Material", Enum.Material.SmoothPlastic)
	setProperty(part, "Color", color)
	setProperty(part, "Reflectance", 0)
	setProperty(part, "CastShadow", false)

	if part:IsA("MeshPart") then
		pcall(setProperty, part, "TextureID", "")
		pcall(setProperty, part, "RenderFidelity", Enum.RenderFidelity.Performance)
	end
end

---Hide or clayify an instance depending on the current mode.
---@param instance Instance
local function processInstance(instance)
	if instance:IsA("Terrain") then
		return
	end

	local hideObjects = MobOnlyView.hideObjects
	local className = instance.ClassName
	local model = getLivingModel(instance)

	if className == "Atmosphere" then
		pcall(setProperty, instance, "Density", 0)
		pcall(setProperty, instance, "Haze", 0)
		return
	end

	-- Effects are always off in low quality, otherwise only outside mobs.
	if DISABLED_CLASSES[className] then
		if LOW_QUALITY or not model then
			setProperty(instance, "Enabled", false)
		end
		return
	end

	if instance:IsA("BasePart") then
		if model then
			clayifyPart(instance, getClayColor(model))
			return
		end

		-- Clay mode keeps every object visible as clay.
		if not hideObjects then
			clayifyPart(instance, instance.Color)
			return
		end

		-- Ground parts stay visible.
		if MobOnlyView.ground[instance] then
			return
		end

		setProperty(instance, "LocalTransparencyModifier", 1)
		return
	end

	-- Strip textures from everything in clay mode, only mobs otherwise.
	if instance:IsA("Decal") or instance:IsA("Texture") then
		setProperty(instance, "Transparency", 1)
		return
	end

	if hideObjects and not model then
		return
	end

	if CLOTHING_CLASSES[className] then
		pcall(setProperty, instance, CLOTHING_CLASSES[className], "")
	elseif className == "SpecialMesh" then
		pcall(setProperty, instance, "TextureId", "")
	elseif className == "SurfaceAppearance" then
		pcall(setProperty, instance, "ColorMap", "")
	end
end

---Find the ground under every living entity and keep it visible.
local function updateGround()
	local filter = {}

	for _, descendant in ipairs(workspaceService:GetDescendants()) do
		if descendant:IsA("Humanoid") or descendant:IsA("AnimationController") then
			table.insert(filter, descendant.Parent)
		end
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = filter

	for _, model in ipairs(filter) do
		local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
		if not root then
			continue
		end

		local result = workspaceService:Raycast(root.Position, Vector3.new(0, -GROUND_RAY_LENGTH, 0), params)
		local part = result and result.Instance
		if not part or part:IsA("Terrain") or MobOnlyView.ground[part] then
			continue
		end

		MobOnlyView.ground[part] = true
		pcall(setProperty, part, "LocalTransparencyModifier", 0)
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
	table.clear(MobOnlyView.ground)
end

---Process the whole game in batches, stopping if a newer pass started.
---@param pass number
local function processExisting(pass)
	for index, instance in ipairs(game:GetDescendants()) do
		if not MobOnlyView.running or MobOnlyView.pass ~= pass then
			return
		end

		pcall(processInstance, instance)

		if index % BATCH_SIZE == 0 then
			task.wait()
		end
	end
end

---Reset everything and apply the current mode from scratch.
local function applyAll()
	MobOnlyView.pass = MobOnlyView.pass + 1
	local pass = MobOnlyView.pass

	restoreAll()

	if LOW_QUALITY then
		pcall(applyLowSettings)
	end

	if REMOVE_WATER_EFFECTS then
		pcall(removeWaterEffects)
	end

	if MobOnlyView.hideObjects and KEEP_GROUND_VISIBLE then
		pcall(updateGround)
	end

	task.spawn(processExisting, pass)
end

---Switch between hiding objects and showing them as clay.
---@param state boolean
function MobOnlyView.setHideObjects(state)
	MobOnlyView.hideObjects = state
	applyAll()
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
	MobOnlyView.hideObjects = HIDE_OBJECTS

	-- Remove the notifications gui first.
	if REMOVE_NOTIFICATIONS then
		pcall(removeNotifications)
	end

	applyAll()

	-- Handle anything that spawns later.
	table.insert(
		MobOnlyView.connections,
		game.DescendantAdded:Connect(function(instance)
			task.defer(pcall, processInstance, instance)
		end)
	)

	-- Remove Notifications again if the game re-creates it (e.g. on respawn).
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

	-- Reapply the water values if the game changes them back.
	if REMOVE_WATER_EFFECTS then
		local terrain = workspaceService:FindFirstChildOfClass("Terrain")
		if terrain then
			for property in pairs(WATER_PROPERTIES) do
				table.insert(
					MobOnlyView.connections,
					terrain:GetPropertyChangedSignal(property):Connect(function()
						if terrain[property] ~= WATER_PROPERTIES[property] then
							pcall(setProperty, terrain, property, WATER_PROPERTIES[property])
						end
					end)
				)
			end
		end
	end

	-- Refresh ground under moving mobs.
	if KEEP_GROUND_VISIBLE then
		task.spawn(function()
			while MobOnlyView.running do
				if MobOnlyView.hideObjects then
					pcall(updateGround)
				end

				task.wait(GROUND_INTERVAL)
			end
		end)
	end
end

MobOnlyView.setHideObjects(false)

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
