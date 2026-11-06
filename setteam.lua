local function setTeam()
    local teamPlayers = game:GetService("Players")
    local teamPlayer = teamPlayers.LocalPlayer
    local teamClickSignals = {
        "MouseButton1Click",
        "MouseButton1Down",
        "MouseButton1Up",
        "Activated"
    }

    local teamPlayerGui = teamPlayer:WaitForChild("PlayerGui")
    local teamSelection = teamPlayerGui:WaitForChild("TeamSelection", 10)

    if not teamSelection then
        return
    end

    local teamRoot = teamSelection:WaitForChild("ROOT", 5)
    if not teamRoot then return end

    local teamFrame = teamRoot:WaitForChild("Frame", 5)
    if not teamFrame then return end

    local teamContent = teamFrame:WaitForChild("content", 5)
    if not teamContent then return end

    local teamPirateFrame = teamContent:WaitForChild("pirateFrame", 5)
    if not teamPirateFrame then return end

    local teamButton = teamPirateFrame:WaitForChild("pirate", 5)
    if not teamButton then return end

    for _, teamSignalName in ipairs(teamClickSignals) do
        for _, teamConnection in ipairs(getconnections(teamButton[teamSignalName])) do
            teamConnection:Fire()
        end
    end
end

setTeam()
