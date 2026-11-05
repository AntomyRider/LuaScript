-- Check for table that is shared between executions.
if not shared then
	return warn("No shared, no script.")
end

-- Initialize Luraph globals if they do not exist.
loadstring("getfenv().LPH_NO_VIRTUALIZE = function(...) return ... end")()

-- Module table.
local SuperpowerPerformance = {
	connections = {},
	running = false,
	cache = {},
	stats = { optimized = 0, skipped = 0 },
}

-- Constants.
local BATCH_SIZE = 750
local PROCESS_BUDGET = 0.004
local GUI_ENABLED = true
local TERRAIN_WATER_CLEAR = true

-- Classes that are simply switched off.
local DISABLED_CLASSES = {
	ParticleEmitter = true,
	Trail = true,
	Beam = true,
	Smoke = true,
	Fire = true,
	Sparkles = true,
	BlurEffect = true,
	BloomEffect = true,
	SunRaysEffect = true,
	ColorCorrectionEffect = true,
	DepthOfFieldEffect = true,
	Atmosphere = true,
	Clouds = true,
}

-- Classes that are made invisible instead of disabled.
local HIDDEN_CLASSES = {
	Decal = true,
	Texture = true,
	SurfaceAppearance = true,
}

-- Lighting effect classes that are safe to destroy to free memory.
local LIGHT_CLASSES = {
	PointLight = true,
	SpotLight = true,
	SurfaceLight = true,
}

-- Services.
local playersService = game:GetService("Players")
local lightingService = game:GetService("Lighting")
local workspaceService = game:GetService("Workspace")
local runService = game:GetService("RunService")
local coreGui = game:GetService("CoreGui")

-- State.
local localPlayer = playersService.LocalPlayer
local startTime = os.clock()

---Check whether an instance belongs to a player character.
---@param instance Instance
---@return boolean
local function isCharacterPart(instance)
	local model = instance:FindFirstAncestorOfClass("Model")
	if not model then
		return false
	end

	return model:FindFirstChildOfClass("Humanoid") ~= nil
end

---Store a property so it can be restored on detach.
---@param instance Instance
---@param property string
local function remember(instance, property)
	local entry = SuperpowerPerformance.cache[instance]
	if not entry then
		entry = {}
		SuperpowerPerformance.cache[instance] = entry
	end

	if entry[property] == nil then
		entry[property] = instance[property]
	end
end

---Safely write a property and remember its original value.
---@param instance Instance
---@param property string
---@param value any
local function setProperty(instance, property, value)
	remember(instance, property)
	instance[property] = value
end

---Disable heavy visual effects on an instance.
---@param instance Instance
local function optimizeInstance(instance)
	local className = instance.ClassName

	-- Turn off effects that cost render time.
	if DISABLED_CLASSES[className] then
		setProperty(instance, "Enabled", false)
		SuperpowerPerformance.stats.optimized += 1
		return
	end

	-- Lights are expensive in dense scenes, so dim them out.
	if LIGHT_CLASSES[className] then
		setProperty(instance, "Enabled", false)
		SuperpowerPerformance.stats.optimized += 1
		return
	end

	-- Flatten materials and drop shadows on parts.
	if instance:IsA("BasePart") then
		-- Keep own character readable.
		if isCharacterPart(instance) then
			setProperty(instance, "CastShadow", false)
			return
		end

		setProperty(instance, "CastShadow", false)
		setProperty(instance, "Material", Enum.Material.SmoothPlastic)
		setProperty(instance, "Reflectance", 0)

		-- Meshes render cheaper with default fidelity.
		if instance:IsA("MeshPart") then
			pcall(setProperty, instance, "RenderFidelity", Enum.RenderFidelity.Performance)
		end

		SuperpowerPerformance.stats.optimized += 1
		return
	end

	-- Hide decals, textures and surface appearances.
	if HIDDEN_CLASSES[className] then
		if className == "SurfaceAppearance" then
			SuperpowerPerformance.stats.skipped += 1
			return
		end

		setProperty(instance, "Transparency", 1)
		SuperpowerPerformance.stats.optimized += 1
		return
	end

	SuperpowerPerformance.stats.skipped += 1
end

---Apply global lighting and terrain settings.
local function optimizeGlobals()
	-- Remember lighting values for a clean restore.
	SuperpowerPerformance.cache[lightingService] = {
		GlobalShadows = lightingService.GlobalShadows,
		FogEnd = lightingService.FogEnd,
		Brightness = lightingService.Brightness,
		EnvironmentDiffuseScale = lightingService.EnvironmentDiffuseScale,
		EnvironmentSpecularScale = lightingService.EnvironmentSpecularScale,
	}

	lightingService.GlobalShadows = false
	lightingService.FogEnd = 9e9
	lightingService.Brightness = 2
	lightingService.EnvironmentDiffuseScale = 0
	lightingService.EnvironmentSpecularScale = 0

	-- Terrain water costs a lot on big maps.
	local terrain = workspaceService:FindFirstChildOfClass("Terrain")
	if terrain and TERRAIN_WATER_CLEAR then
		SuperpowerPerformance.cache[terrain] = {
			WaterWaveSize = terrain.WaterWaveSize,
			WaterWaveSpeed = terrain.WaterWaveSpeed,
			WaterReflectance = terrain.WaterReflectance,
			WaterTransparency = terrain.WaterTransparency,
			Decoration = terrain.Decoration,
		}

		terrain.WaterWaveSize = 0
		terrain.WaterWaveSpeed = 0
		terrain.WaterReflectance = 0
		terrain.WaterTransparency = 1
		pcall(function()
			terrain.Decoration = false
		end)
	end

	-- Lower render quality and uncap the framerate.
	pcall(function()
		settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
	end)

	pcall(function()
		if setfpscap then
			setfpscap(1000)
		end
	end)
end

---Restore every property that was changed.
local function restoreAll()
	for instance, properties in pairs(SuperpowerPerformance.cache) do
		if typeof(instance) == "Instance" then
			for property, value in pairs(properties) do
				pcall(function()
					instance[property] = value
				end)
			end
		end
	end

	table.clear(SuperpowerPerformance.cache)
end

---Process the whole game in time-budgeted batches.
local function optimizeExisting()
	local descendants = game:GetDescendants()
	local lastYield = os.clock()

	for index, instance in ipairs(descendants) do
		if not SuperpowerPerformance.running then
			return
		end

		pcall(optimizeInstance, instance)

		-- Yield by time budget and batch size to stay smooth.
		if index % BATCH_SIZE == 0 or os.clock() - lastYield > PROCESS_BUDGET then
			task.wait()
			lastYield = os.clock()
		end
	end
end

---Create a small FPS and stats overlay with Drawing.
local function createOverlay()
	if not GUI_ENABLED or not Drawing then
		return
	end

	local label = Drawing.new("Text")
	label.Size = 16
	label.Font = Drawing.Fonts.Monospace
	label.Color = Color3.fromRGB(120, 255, 160)
	label.Outline = true
	label.Position = Vector2.new(12, 12)
	label.Visible = true

	local frames, lastTick = 0, os.clock()

	-- Update the overlay once per second.
	local connection = runService.RenderStepped:Connect(function()
		frames += 1

		local now = os.clock()
		if now - lastTick < 1 then
			return
		end

		label.Text = string.format(
			"FPS: %d | Optimized: %d | Uptime: %ds",
			frames,
			SuperpowerPerformance.stats.optimized,
			math.floor(now - startTime)
		)

		frames = 0
		lastTick = now
	end)

	table.insert(SuperpowerPerformance.connections, connection)
	SuperpowerPerformance.overlay = label
end

---Stop the optimizer and disconnect listeners.
function SuperpowerPerformance.detach()
	SuperpowerPerformance.running = false

	for _, connection in ipairs(SuperpowerPerformance.connections) do
		pcall(function()
			connection:Disconnect()
		end)
	end

	table.clear(SuperpowerPerformance.connections)

	-- Remove the overlay.
	if SuperpowerPerformance.overlay then
		pcall(function()
			SuperpowerPerformance.overlay:Remove()
		end)
		SuperpowerPerformance.overlay = nil
	end

	restoreAll()
end

---Start the optimizer.
function SuperpowerPerformance.init()
	SuperpowerPerformance.running = true
	optimizeGlobals()
	createOverlay()

	-- Optimize existing instances without freezing the client.
	task.spawn(optimizeExisting)

	-- Optimize anything that spawns later (skills, effects, fruits).
	table.insert(
		SuperpowerPerformance.connections,
		game.DescendantAdded:Connect(function(instance)
			-- Defer so properties are fully replicated first.
			task.defer(pcall, optimizeInstance, instance)
		end)
	)

	-- Keep lighting settings from being reset by the game.
	table.insert(
		SuperpowerPerformance.connections,
		lightingService:GetPropertyChangedSignal("GlobalShadows"):Connect(function()
			if SuperpowerPerformance.running and lightingService.GlobalShadows then
				lightingService.GlobalShadows = false
			end
		end)
	)
end

---This is called when initialization errors.
---@param error string
local function onInitializeError(error)
	warn("Failed to initialize.")
	warn(error)
	warn(debug.traceback())
	SuperpowerPerformance.detach()
end

-- Detach the previous instance before re-initializing.
if shared.SuperpowerPerformance then
	shared.SuperpowerPerformance.detach()
end

shared.SuperpowerPerformance = SuperpowerPerformance
xpcall(SuperpowerPerformance.init, onInitializeError)

return SuperpowerPerformance
