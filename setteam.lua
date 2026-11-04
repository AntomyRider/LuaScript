local function setTeam()
	local CLICK_SIGNALS = {"MouseButton1Click", "MouseButton1Down", "MouseButton1Up", "Activated"}

	local playerGui = ply:WaitForChild("PlayerGui")
	local teamSelection = playerGui:WaitForChild("TeamSelection", 10)
	if not teamSelection then return end

	local button = teamSelection:WaitForChild("ROOT", 5)
		and teamSelection.ROOT:WaitForChild("Frame", 5)
		and teamSelection.ROOT.Frame:WaitForChild("content", 5)
		and teamSelection.ROOT.Frame.content:WaitForChild("pirateFrame", 5)
		and teamSelection.ROOT.Frame.content.pirateFrame:WaitForChild("pirate", 5)
	if not button then return end

	for _, signalName in ipairs(CLICK_SIGNALS) do
		for _, connection in ipairs(getconnections(button[signalName])) do
			connection:Fire()
		end
	end
end

setTeam()
