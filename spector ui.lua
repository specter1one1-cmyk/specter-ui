-- ============================================
-- SPECTER UI - Universal FPS (STABLE)
-- ============================================

if _G.HubCleanup then _G.HubCleanup() end

-- Try multiple Rayfield sources
local Rayfield = nil
local success = false

-- Attempt 1: Sirius
pcall(function()
    Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
    success = true
end)

-- Attempt 2: Alternative source
if not success then
    pcall(function()
        Rayfield = loadstring(game:HttpGet('https://raw.githubusercontent.com/shlexware/Rayfield/main/source'))()
        success = true
    end)
end

-- Attempt 3: Another mirror
if not success then
    pcall(function()
        Rayfield = loadstring(game:HttpGet('https://pastebin.com/raw/Gdz1p3Bm'))()
        success = true
    end)
end

-- If all fail, use simple UI
if not success or not Rayfield then
    warn("Rayfield failed to load, using fallback UI")
    -- Create simple fallback or error
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "Specter UI",
        Text = "UI Library failed to load. Retrying...",
        Duration = 3
    })
    -- Try one more time with direct load
    Rayfield = loadstring(game:HttpGet("https://raw.githubusercontent.com/SiriusSoftwareLtd/Rayfield/main/source.lua"))()
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- Wait for character
if not player.Character then
    player.CharacterAdded:Wait()
end

-- ═══ STATE ═══
local espEnabled = false
local aimbotEnabled = false
local aimFOV = 200
local aimSmoothing = 1
local aimPart = "Head"
local bhopEnabled = false
local noclipEnabled = false
local wallbangEnabled = false
local speedEnabled = false
local speedValue = 22
local infJumpEnabled = false
local rightHeld = false
local lockedTarget = nil
local spaceHeld = false

-- Fly Variables
local flying = false
local flySpeed = 2
local bv, bg

local espObjects = {}
local connections = {}

-- FOV Circle
local fovCircle = Drawing.new("Circle")
fovCircle.Color = Color3.fromRGB(255, 50, 50)
fovCircle.Thickness = 2
fovCircle.Transparency = 0.8
fovCircle.Filled = false
fovCircle.NumSides = 64
fovCircle.Visible = false

-- ═══ UTILITY ═══
local function isAlive(p)
    local char = p and p.Character
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
    return hum and root and hum.Health > 0
end

local function isValidTarget(p)
    if p == player then return false end
    if not isAlive(p) then return false end
    if p.Team and player.Team and p.Team == player.Team then return false end
    return true
end

local function getClosestEnemy()
    local closest = nil
    local closestDist = aimFOV
    local screenCenter = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
    
    for _, p in pairs(Players:GetPlayers()) do
        if isValidTarget(p) then
            local char = p.Character
            local targetPart = char:FindFirstChild(aimPart) or char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
            if targetPart then
                local screenPos, onScreen = camera:WorldToViewportPoint(targetPart.Position)
                if onScreen and screenPos.Z > 0 then
                    local dist2D = (Vector2.new(screenPos.X, screenPos.Y) - screenCenter).Magnitude
                    if dist2D < closestDist then 
                        closestDist = dist2D 
                        closest = p 
                    end
                end
            end
        end
    end
    return closest
end

local function getChar()
    return player.Character or player.CharacterAdded:Wait()
end

-- ═══ FLY FUNCTIONS ═══
local function startFly()
    local character = getChar()
    local hrp = character:WaitForChild("HumanoidRootPart")
    local humanoid = character:WaitForChild("Humanoid")

    bv = Instance.new("BodyVelocity")
    bg = Instance.new("BodyGyro")

    bv.MaxForce = Vector3.new(9e9,9e9,9e9)
    bg.MaxTorque = Vector3.new(9e9,9e9,9e9)

    bv.Parent = hrp
    bg.Parent = hrp

    humanoid.PlatformStand = true
    flying = true

    RunService.RenderStepped:Connect(function()
        if not flying then
            if bv then bv:Destroy() end
            if bg then bg:Destroy() end
            humanoid.PlatformStand = false
            return
        end

        local cam = workspace.CurrentCamera
        local move = Vector3.zero

        if UIS:IsKeyDown(Enum.KeyCode.W) then move += cam.CFrame.LookVector end
        if UIS:IsKeyDown(Enum.KeyCode.S) then move -= cam.CFrame.LookVector end
        if UIS:IsKeyDown(Enum.KeyCode.A) then move -= cam.CFrame.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.D) then move += cam.CFrame.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.Space) then move += Vector3.new(0,1,0) end
        if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then move -= Vector3.new(0,1,0) end

        bv.Velocity = move * (flySpeed * 50)
        bg.CFrame = cam.CFrame
    end)
end

local function stopFly()
    flying = false
end

-- ═══ ESP ═══
local function createESP(target)
    if espObjects[target] then return end
    local highlight = Instance.new("Highlight")
    highlight.FillTransparency = 0.85
    highlight.OutlineTransparency = 0
    highlight.FillColor = Color3.fromRGB(255, 50, 50)
    highlight.OutlineColor = Color3.fromRGB(255, 0, 0)
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    espObjects[target] = highlight
end

local function removeESP(target)
    local esp = espObjects[target]
    if esp then esp:Destroy() espObjects[target] = nil end
end

-- ═══ RENDER LOOP ═══
connections.render = RunService.RenderStepped:Connect(function()
    local screenCenter = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
    
    fovCircle.Visible = aimbotEnabled
    fovCircle.Position = screenCenter
    fovCircle.Radius = aimFOV
    
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= player then
            if espEnabled and isValidTarget(p) then
                createESP(p)
                espObjects[p].Parent = p.Character
            else
                removeESP(p)
            end
        end
    end
end)

-- ═══ AIMBOT ═══
local function aimbotLoop()
    if not aimbotEnabled then return end
    if not rightHeld then 
        lockedTarget = nil
        return 
    end
    
    if not lockedTarget or not isValidTarget(lockedTarget) then
        lockedTarget = getClosestEnemy()
    end
    
    if lockedTarget and lockedTarget.Character then
        local targetPart = lockedTarget.Character:FindFirstChild(aimPart) or lockedTarget.Character:FindFirstChild("Head") or lockedTarget.Character:FindFirstChild("HumanoidRootPart")
        if targetPart then
            local targetPos = targetPart.Position
            if aimPart == "Head" then
                targetPos = targetPos + Vector3.new(0, 0.1, 0)
            end
            
            local cameraPos = camera.CFrame.Position
            local targetCF = CFrame.new(cameraPos, targetPos)
            
            if aimSmoothing <= 1 then
                camera.CFrame = targetCF
            else
                camera.CFrame = camera.CFrame:Lerp(targetCF, 1 / aimSmoothing)
            end
        end
    end
end

-- Bind aimbot with high priority
RunService:BindToRenderStep("SpecterAimbot", Enum.RenderPriority.Camera.Value + 1, aimbotLoop)

-- ═══ INPUT ═══
connections.inputBegan = UIS.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    
    if input.UserInputType == Enum.UserInputType.MouseButton2 then 
        rightHeld = true 
    end
    
    if input.KeyCode == Enum.KeyCode.Space then
        spaceHeld = true
        if infJumpEnabled then
            local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
            if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
        end
    end
end)

connections.inputEnded = UIS.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then 
        rightHeld = false 
    end
    if input.KeyCode == Enum.KeyCode.Space then 
        spaceHeld = false 
    end
end)

-- ═══ HEARTBEAT ═══
connections.heartbeat = RunService.Heartbeat:Connect(function()
    local char = player.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
    if not hum or not root then return end

    if bhopEnabled and spaceHeld and hum.FloorMaterial ~= Enum.Material.Air then
        hum:ChangeState(Enum.HumanoidStateType.Jumping)
        root.Velocity = Vector3.new(root.Velocity.X, hum.JumpPower, root.Velocity.Z)
    end

    if noclipEnabled then
        for _, part in pairs(char:GetDescendants()) do
            if part:IsA("BasePart") then part.CanCollide = false end
        end
    end

    if speedEnabled then hum.WalkSpeed = speedValue end
end)

-- ═══ WALLBANG ═══
local geometryParts = {}
local map = workspace:FindFirstChild("Map") or workspace
for _, obj in pairs(map:GetDescendants()) do
    if obj:IsA("BasePart") then table.insert(geometryParts, obj) end
end

local function setWallbang(state)
    for _, part in pairs(geometryParts) do
        if part and part.Parent then part.CanQuery = not state end
    end
end

connections.removing = Players.PlayerRemoving:Connect(function(p) removeESP(p) end)

-- ═══ CREATE UI ═══
local Window = nil
local createSuccess = pcall(function()
    Window = Rayfield:CreateWindow({
        Name = "Specter UI",
        LoadingTitle = "Specter UI",
        LoadingSubtitle = "Loading...",
        Theme = "Default",
        ConfigurationSaving = { Enabled = false },
        Discord = { Enabled = false },
        KeySystem = false
    })
end)

if not createSuccess or not Window then
    error("Failed to create UI window")
    return
end

-- Welcome Tab
local WelcomeTab = Window:CreateTab("Welcome", 4483362458)
WelcomeTab:CreateLabel("Welcome to Specter UI!")
WelcomeTab:CreateLabel("Player: " .. player.DisplayName)

local gameName = "Unknown"
pcall(function() 
    gameName = game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name 
end)
WelcomeTab:CreateLabel("Game: " .. gameName)

-- Combat Tab
local CombatTab = Window:CreateTab("Combat", 4483362458)

CombatTab:CreateToggle({
    Name = "Aimbot (Hold RMB)",
    CurrentValue = false,
    Flag = "Aimbot",
    Callback = function(v) 
        aimbotEnabled = v 
        if not v then 
            lockedTarget = nil 
            fovCircle.Visible = false
        end 
    end
})

CombatTab:CreateDropdown({
    Name = "Target Part",
    Options = {"Head", "HumanoidRootPart", "Torso"},
    CurrentOption = "Head",
    Flag = "AimPart",
    Callback = function(v) aimPart = v end
})

CombatTab:CreateSlider({
    Name = "FOV",
    Range = {50, 800},
    Increment = 25,
    CurrentValue = 200,
    Flag = "FOV",
    Callback = function(v) aimFOV = v end
})

CombatTab:CreateSlider({
    Name = "Smooth",
    Range = {1, 20},
    Increment = 1,
    CurrentValue = 1,
    Flag = "Smooth",
    Callback = function(v) aimSmoothing = v end
})

CombatTab:CreateToggle({
    Name = "Wallbang",
    CurrentValue = false,
    Flag = "Wall",
    Callback = function(v) wallbangEnabled = v setWallbang(v) end
})

-- Visuals Tab
local VisualsTab = Window:CreateTab("Visuals", 4483362458)

VisualsTab:CreateToggle({
    Name = "ESP",
    CurrentValue = false,
    Flag = "ESP",
    Callback = function(v)
        espEnabled = v
        if not v then for _, p in pairs(Players:GetPlayers()) do removeESP(p) end end
    end
})

VisualsTab:CreateColorPicker({
    Name = "ESP Color",
    Color = Color3.fromRGB(255, 50, 50),
    Flag = "Color",
    Callback = function(v)
        for _, esp in pairs(espObjects) do
            esp.FillColor = v
            esp.OutlineColor = v
        end
        fovCircle.Color = v
    end
})

-- Movement Tab (Combined Main & Movement)
local MovementTab = Window:CreateTab("Movement", 4483362458)

MovementTab:CreateToggle({
    Name = "Fly",
    CurrentValue = false,
    Callback = function(v) if v then startFly() else stopFly() end end,
})

MovementTab:CreateSlider({
    Name = "Fly Speed",
    Range = {1, 10},
    Increment = 1,
    CurrentValue = 2,
    Callback = function(v) flySpeed = v end,
})

MovementTab:CreateToggle({
    Name = "Bhop",
    CurrentValue = false,
    Flag = "Bhop",
    Callback = function(v) bhopEnabled = v end
})

MovementTab:CreateToggle({
    Name = "Speed",
    CurrentValue = false,
    Flag = "Speed",
    Callback = function(v)
        speedEnabled = v
        if not v then
            local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
            if hum then hum.WalkSpeed = 16 end
        end
    end
})

MovementTab:CreateSlider({
    Name = "Speed",
    Range = {16, 200},
    Increment = 2,
    CurrentValue = 22,
    Flag = "SpeedV",
    Callback = function(v) speedValue = v end
})

MovementTab:CreateToggle({
    Name = "Noclip",
    CurrentValue = false,
    Flag = "Noclip",
    Callback = function(v) noclipEnabled = v end
})

MovementTab:CreateToggle({
    Name = "Inf Jump",
    CurrentValue = false,
    Flag = "InfJump",
    Callback = function(v) infJumpEnabled = v end
})

Rayfield:Notify({
   Title = "Loaded!",
   Content = "Infinite Jump & ESP Added",
   Duration = 6,
})

-- Cleanup
_G.HubCleanup = function()
    RunService:UnbindFromRenderStep("SpecterAimbot")
    for _, c in pairs(connections) do
        if typeof(c) == "RBXScriptConnection" then c:Disconnect() end
    end
    connections = {}
    for _, p in pairs(Players:GetPlayers()) do removeESP(p) end
    espObjects = {}
    fovCircle:Remove()
    setWallbang(false)
    stopFly()
    local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    if hum then hum.WalkSpeed = 16 end
    if Rayfield and Rayfield.Destroy then Rayfield:Destroy() end
    _G.HubCleanup = nil
end

-- Notify
game:GetService("StarterGui"):SetCore("SendNotification", {
    Title = "Specter UI",
    Text = "Loaded Successfully!",
    Duration = 3
})