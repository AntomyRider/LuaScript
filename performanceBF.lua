-- Check for table that is shared between executions.
if not shared then
	return warn("No shared, no script.")
end

-- Initialize Luraph globals if they do not exist.
loadstring("getfenv().LPH_NO_VIRTUALIZE = function(...) return ... end")()

-- Module table.
local SuperpowerPerformance = { connections = {}, running = false }

-- Constants.
local DISABLED_CLASSES = {
	ParticleEmitter = true,
	Trail = true,
	Beam = true,
	Smoke = true,
	Fire = true,
	Sparkles = true,
	PostEffect = true,
	BlurEffect = true,
	BloomEffect = true,
	SunRaysEffect = true,
	ColorCorrectionEffect = true,
	DepthOfFieldEffect = true,
}

-- Services.
local lightingService = game:GetService("Lighting")
local workspaceService = game:GetService("Workspace")

---Disable heavy visual effects on an instance.
---@param instance Instance
local function optimizeInstance(instance)
	-- Turn off effects that cost render time.
	if DISABLED_CLASSES[instance.ClassName] or instance:IsA("PostEffect") then
		instance.Enabled = false
		return
	end

	-- Flatten materials and drop shadows on parts.
	if instance:IsA("BasePart") then
		instance.CastShadow = false
		instance.Material = Enum.Material.SmoothPlastic
		instance.Reflectance = 0
		return
	end

	-- Hide decals and textures.
	if instance:IsA("Decal") or instance:IsA("Texture") then
		instance.Transparency = 1
	end
end

---Apply global lighting and terrain settings.
local function optimizeGlobals()
	lightingService.GlobalShadows = false
	lightingService.FogEnd = 9e9
	lightingService.Brightness = 2

	local terrain = workspaceService:FindFirstChildOfClass("Terrain")
	if terrain then
		terrain.WaterWaveSize = 0
		terrain.WaterWaveSpeed = 0
		terrain.WaterReflectance = 0
		terrain.WaterTransparency = 1
	end

	settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
end

---Stop the optimizer and disconnect listeners.
function SuperpowerPerformance.detach()
	SuperpowerPerformance.running = false

	for _, connection in ipairs(SuperpowerPerformance.connections) do
		connection:Disconnect()
	end

	table.clear(SuperpowerPerformance.connections)
end

---Start the optimizer.
function SuperpowerPerformance.init()
	SuperpowerPerformance.running = true
	optimizeGlobals()

	-- Optimize existing instances in batches to avoid freezing.
	task.spawn(function()
		for index, instance in ipairs(game:GetDescendants()) do
			if not SuperpowerPerformance.running then
				return
			end

			pcall(optimizeInstance, instance)

			if index % 500 == 0 then
				task.wait()
			end
		end
	end)

	-- Optimize anything that spawns later (skills, effects, fruits).
	table.insert(SuperpowerPerformance.connections, game.DescendantAdded:Connect(function(instance)
		pcall(optimizeInstance, instance)
	end))
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
