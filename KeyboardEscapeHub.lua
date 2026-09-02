-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
-- OUTCOME HUB â€” +1 Speed Keyboard Escape
-- Auto Farm | Auto Win | Auto Rebirth | Movement | ESP
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

local Rayfield = loadstring(game:HttpGet('https://raw.githubusercontent.com/SiriusSoftwareLtd/Rayfield/main/source.lua'))()

-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
-- SERVICES
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualUser = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
-- STATE
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
local State = {
    -- Auto Speed
    AutoSpeed = false,
    AutoSpeedDelay = 0.01,
    AutoSpeedMode = "Quad",

    -- Auto Win
    AutoWin = false,
    AutoWinWorld = 1,
    AutoWinDelay = 0.5,

    -- Auto Rebirth
    AutoRebirth = false,
    AutoRebirthDelay = 1,

    -- Auto Treadmill
    AutoTreadmill = false,

    -- Movement
    WalkSpeedEnabled = false,
    WalkSpeedValue = 50,
    JumpPowerEnabled = false,
    JumpPowerValue = 100,
    InfiniteJump = false,
    NoClip = false,
    FlyEnabled = false,
    FlySpeed = 50,

    -- ESP
    WinPadESP = false,
    PlayerESP = false,

    -- Teleport
    ClickTP = false,
    TP_Speed = 1,

    -- Anti AFK
    AntiAFK = false,

    -- Connections
    Connections = {},
}

-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
-- UTILITY
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
local function GetCharacter()
    return LocalPlayer.Character
end

local function GetRoot()
    local char = GetCharacter()
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function GetHumanoid()
    local char = GetCharacter()
    return char and char:FindFirstChildOfClass("Humanoid")
end

local function IsAlive()
    local hum = GetHumanoid()
    return hum and hum.Health > 0
end

local function Disconnect(name)
    if State.Connections[name] then
        State.Connections[name]:Disconnect()
        State.Connections[name] = nil
    end
end

local function WaitSpawn(callback)
    if IsAlive() then
        callback()
    else
        LocalPlayer.CharacterAdded:Once(function()
            task.wait(1)
            callback()
        end)
    end
end

-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
-- WINDOW
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
local Window = Rayfield:CreateWindow({
    Name = "OUTCOME HUB",
    LoadingTitle = "+1 Speed Keyboard Escape",
    LoadingSubtitle = "outcome hub v1",
    ConfigurationSaving = { Enabled = false },
    Discord = { Enabled = false },
    KeySystem = false,
})

-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
-- TABS
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
local FarmTab = Window:CreateTab("Auto Farm", 4483362458)
local MovementTab = Window:CreateTab("Movement", 4483362458)
local ESPTab = Window:CreateTab("ESP", 4483362458)
local TeleportTab = Window:CreateTab("Teleport", 4483362458)
local MiscTab = Window:CreateTab("Misc", 4483362458)

-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
-- AUTO FARM TAB
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
FarmTab:CreateSection("Speed Farm")

-- Auto Speed: rapid micro-movements to trigger key presses
local AutoSpeedToggle = FarmTab:CreateToggle({
    Name = "Auto Speed (Key Trigger)",
    CurrentValue = false,
    Flag = "AutoSpeedFlag",
    Callback = function(Value)
        State.AutoSpeed = Value
        if Value then
            task.spawn(function()
                while State.AutoSpeed do
                    local root = GetRoot()
                    local hum = GetHumanoid()
                    if root and hum and IsAlive() then
                        if State.AutoSpeedMode == "Quad" then
                            for _, dir in ipairs({
                                CFrame.new(0, 0, -2),
                                CFrame.new(0, 0, 2),
                                CFrame.new(2, 0, 0),
                                CFrame.new(-2, 0, 0),
                            }) do
                                if not State.AutoSpeed or not IsAlive() then break end
                                root.CFrame = root.CFrame * dir
                                hum:Move(Vector3.new(dir.X, 0, dir.Z), true)
                                RunService.Heartbeat:Wait()
                            end
                        elseif State.AutoSpeedMode == "Spin" then
                            if not State.AutoSpeed or not IsAlive() then break end
                            root.CFrame = root.CFrame * CFrame.Angles(0, math.rad(90), 0)
                            hum:Move(Vector3.new(1, 0, 0), true)
                            RunService.Heartbeat:Wait()
                        elseif State.AutoSpeedMode == "Forward" then
                            if not State.AutoSpeed or not IsAlive() then break end
                            root.CFrame = root.CFrame * CFrame.new(0, 0, -3)
                            hum:Move(Vector3.new(0, 0, -1), true)
                            RunService.Heartbeat:Wait()
                        end
                    end
                    task.wait(State.AutoSpeedDelay)
                end
            end)
        end
    end,
})

FarmTab:CreateDropdown({
    Name = "Speed Mode",
    Options = {"Quad", "Spin", "Forward"},
    CurrentOption = {"Quad"},
    Flag = "SpeedModeFlag",
    Callback = function(Option)
        State.AutoSpeedMode = Option[1]
    end,
})

FarmTab:CreateSlider({
    Name = "Speed Delay (s)",
    Range = {0.01, 0.5},
    Increment = 0.01,
    Suffix = "s",
    CurrentValue = 0.01,
    Flag = "SpeedDelayFlag",
    Callback = function(Value)
        State.AutoSpeedDelay = Value
    end,
})

-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
FarmTab:CreateSection("Win Farm")

-- Find all win pads in the workspace
local function FindWinPads()
    local pads = {}
    local function scan(parent)
        for _, obj in ipairs(parent:GetChildren()) do
            if obj:IsA("BasePart") then
                local name = obj.Name:lower()
                if name:find("win") or name:find("trophy") or name:find("finish") or name:find("end") then
                    table.insert(pads, obj)
                end
                if obj.Color == Color3.fromRGB(255, 255, 0) and obj.Size.Y < 5 then
                    table.insert(pads, obj)
                end
            end
            if obj:IsA("Model") or obj:IsA("Folder") then
                scan(obj)
            end
        end
    end
    scan(Workspace)
    return pads
end

-- Auto Win: teleport to win pad positions
local AutoWinToggle = FarmTab:CreateToggle({
    Name = "Auto Win (Teleport to Pad)",
    CurrentValue = false,
    Flag = "AutoWinFlag",
    Callback = function(Value)
        State.AutoWin = Value
        if Value then
            task.spawn(function()
                while State.AutoWin do
                    local root = GetRoot()
                    if root and IsAlive() then
                        local pads = FindWinPads()
                        if #pads > 0 then
                            local closest = nil
                            local closestDist = math.huge
                            for _, pad in ipairs(pads) do
                                if pad and pad.Parent then
                                    local dist = (root.Position - pad.Position).Magnitude
                                    if dist < closestDist then
                                        closestDist = dist
                                        closest = pad
                                    end
                                end
                            end
                            if closest then
                                local tween = TweenService:Create(
                                    root,
                                    TweenInfo.new(State.TP_Speed, Enum.EasingStyle.Linear),
                                    {CFrame = closest.CFrame + Vector3.new(0, 5, 0)}
                                )
                                tween:Play()
                                tween.Completed:Wait()
                            end
                        end
                    end
                    task.wait(State.AutoWinDelay)
                end
            end)
        end
    end,
})

FarmTab:CreateSlider({
    Name = "Win TP Speed",
    Range = {0.1, 3},
    Increment = 0.1,
    Suffix = "s",
    CurrentValue = 0.5,
    Flag = "WinTPSpeedFlag",
    Callback = function(Value)
        State.AutoWinDelay = Value
        State.TP_Speed = Value
    end,
})

-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
FarmTab:CreateSection("Auto Rebirth")

local function ClickRebirth()
    local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if not playerGui then return end

    -- Search for rebirth button in UI
    local function scanUI(parent)
        for _, obj in ipairs(parent:GetChildren()) do
            if obj:IsA("TextLabel") or obj:IsA("TextButton") then
                local text = obj.Text:lower()
                if text:find("rebirth") then
                    local button = obj:FindFirstAncestorOfClass("TextButton") or obj:FindFirstAncestorOfClass("ImageButton")
                    if button and button:IsA("GuiButton") then
                        -- Simulate click via InputObject
                        local pos = button.AbsolutePosition + button.AbsoluteSize / 2
                        VirtualUser:ClickButtonAt(Vector2.new(pos.X, pos.Y))
                        return true
                    end
                    -- Try to fire ClickDetector or activate directly
                    if obj:IsA("TextButton") then
                        obj:Activate()
                        return true
                    end
                end
            end
            if obj:IsA("GuiButton") then
                local name = obj.Name:lower()
                if name:find("rebirth") then
                    obj:Activate()
                    return true
                end
            end
            scanUI(obj)
        end
    end
    scanUI(playerGui)
end

local AutoRebirthToggle = FarmTab:CreateToggle({
    Name = "Auto Rebirth",
    CurrentValue = false,
    Flag = "AutoRebirthFlag",
    Callback = function(Value)
        State.AutoRebirth = Value
        if Value then
            task.spawn(function()
                while State.AutoRebirth do
                    ClickRebirth()
                    task.wait(State.AutoRebirthDelay)
                end
            end)
        end
    end,
})

FarmTab:CreateSlider({
    Name = "Rebirth Check Delay",
    Range = {0.5, 10},
    Increment = 0.5,
    Suffix = "s",
    CurrentValue = 1,
    Flag = "RebirthDelayFlag",
    Callback = function(Value)
        State.AutoRebirthDelay = Value
    end,
})

-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
FarmTab:CreateSection("Auto Treadmill")

local function FindTreadmill()
    local function scan(parent)
        for _, obj in ipairs(parent:GetChildren()) do
            local name = obj.Name:lower()
            if name:find("treadmill") or name:find("tread") then
                if obj:IsA("BasePart") then
                    return obj
                end
                if obj:IsA("Model") then
                    local primary = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
                    if primary then return primary end
                end
            end
            if obj:IsA("Model") or obj:IsA("Folder") then
                local found = scan(obj)
                if found then return found end
            end
        end
        return nil
    end
    return scan(Workspace)
end

local AutoTreadmillToggle = FarmTab:CreateToggle({
    Name = "Auto Treadmill (AFK Farm)",
    CurrentValue = false,
    Flag = "AutoTreadmillFlag",
    Callback = function(Value)
        State.AutoTreadmill = Value
        if Value then
            task.spawn(function()
                while State.AutoTreadmill do
                    local root = GetRoot()
                    if root and IsAlive() then
                        local treadmill = FindTreadmill()
                        if treadmill then
                            root.CFrame = treadmill.CFrame + Vector3.new(0, 3, 0)
                        end
                    end
                    task.wait(5)
                end
            end)
        end
    end,
})

-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
-- MOVEMENT TAB
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
MovementTab:CreateSection("Speed & Jump")

MovementTab:CreateToggle({
    Name = "Custom WalkSpeed",
    CurrentValue = false,
    Flag = "WalkSpeedFlag",
    Callback = function(Value)
        State.WalkSpeedEnabled = Value
        if not Value then
            local hum = GetHumanoid()
            if hum then hum.WalkSpeed = 16 end
        end
    end,
})

MovementTab:CreateSlider({
    Name = "WalkSpeed Value",
    Range = {16, 500},
    Increment = 1,
    Suffix = " studs/s",
    CurrentValue = 50,
    Flag = "WalkSpeedValueFlag",
    Callback = function(Value)
        State.WalkSpeedValue = Value
    end,
})

MovementTab:CreateToggle({
    Name = "Custom JumpPower",
    CurrentValue = false,
    Flag = "JumpPowerFlag",
    Callback = function(Value)
        State.JumpPowerEnabled = Value
        if not Value then
            local hum = GetHumanoid()
            if hum then
                hum.JumpPower = 50
                hum.UseJumpPower = true
            end
        end
    end,
})

MovementTab:CreateSlider({
    Name = "JumpPower Value",
    Range = {50, 300},
    Increment = 5,
    Suffix = " studs",
    CurrentValue = 100,
    Flag = "JumpPowerValueFlag",
    Callback = function(Value)
        State.JumpPowerValue = Value
    end,
})

MovementTab:CreateToggle({
    Name = "Infinite Jump",
    CurrentValue = false,
    Flag = "InfJumpFlag",
    Callback = function(Value)
        State.InfiniteJump = Value
        if Value then
            State.Connections.InfJump = UserInputService.JumpRequest:Connect(function()
                if State.InfiniteJump and IsAlive() then
                    local hum = GetHumanoid()
                    if hum then
                        hum:ChangeState(Enum.HumanoidStateType.Jumping)
                    end
                end
            end)
        else
            Disconnect("InfJump")
        end
    end,
})

-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
MovementTab:CreateSection("Fly & NoClip")

MovementTab:CreateToggle({
    Name = "Fly (Space=Up, Ctrl=Down)",
    CurrentValue = false,
    Flag = "FlyFlag",
    Callback = function(Value)
        State.FlyEnabled = Value
        if Value then
            local bodyVelocity
            local bodyGyro
            local flying = true

            State.Connections.Fly = RunService.RenderStepped:Connect(function()
                local root = GetRoot()
                if not root or not IsAlive() then
                    State.FlyEnabled = false
                    if bodyVelocity then bodyVelocity:Destroy() end
                    if bodyGyro then bodyGyro:Destroy() end
                    Disconnect("Fly")
                    return
                end

                if not bodyVelocity then
                    bodyVelocity = Instance.new("BodyVelocity")
                    bodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                    bodyVelocity.Velocity = Vector3.zero
                    bodyVelocity.Parent = root

                    bodyGyro = Instance.new("BodyGyro")
                    bodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
                    bodyGyro.P = 9000
                    bodyGyro.D = 500
                    bodyGyro.Parent = root
                end

                local moveDir = Vector3.zero
                local camCF = Camera.CFrame

                if UserInputService:IsKeyDown(Enum.KeyCode.W) then
                    moveDir = moveDir + camCF.LookVector
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.S) then
                    moveDir = moveDir - camCF.LookVector
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.A) then
                    moveDir = moveDir - camCF.RightVector
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.D) then
                    moveDir = moveDir + camCF.RightVector
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                    moveDir = moveDir + Vector3.new(0, 1, 0)
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
                    moveDir = moveDir - Vector3.new(0, 1, 0)
                end

                if moveDir.Magnitude > 0 then
                    moveDir = moveDir.Unit * State.FlySpeed
                end

                bodyVelocity.Velocity = moveDir
                bodyGyro.CFrame = camCF
            end)
        else
            Disconnect("Fly")
            local root = GetRoot()
            if root then
                for _, v in ipairs(root:GetChildren()) do
                    if v:IsA("BodyVelocity") or v:IsA("BodyGyro") then
                        v:Destroy()
                    end
                end
            end
        end
    end,
})

MovementTab:CreateSlider({
    Name = "Fly Speed",
    Range = {10, 200},
    Increment = 5,
    Suffix = " studs/s",
    CurrentValue = 50,
    Flag = "FlySpeedFlag",
    Callback = function(Value)
        State.FlySpeed = Value
    end,
})

MovementTab:CreateToggle({
    Name = "NoClip",
    CurrentValue = false,
    Flag = "NoClipFlag",
    Callback = function(Value)
        State.NoClip = Value
        if Value then
            State.Connections.NoClip = RunService.Stepped:Connect(function()
                if State.NoClip then
                    local char = GetCharacter()
                    if char then
                        for _, part in ipairs(char:GetDescendants()) do
                            if part:IsA("BasePart") then
                                part.CanCollide = false
                            end
                        end
                    end
                end
            end)
        else
            Disconnect("NoClip")
        end
    end,
})

-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
-- ESP TAB
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
ESPTab:CreateSection("Highlights")

local ESPObjects = {}

local function ClearESP()
    for _, v in ipairs(ESPObjects) do
        if v and v.Parent then v:Destroy() end
    end
    ESPObjects = {}
end

local function CreateHighlight(parent, color, name)
    if not parent or not parent.Parent then return nil end
    local hl = Instance.new("Highlight")
    hl.Name = "OutcomeESP_" .. (name or "")
    hl.FillColor = color
    hl.OutlineColor = color
    hl.FillTransparency = 0.6
    hl.OutlineTransparency = 0
    hl.Adornee = parent
    hl.Parent = parent
    table.insert(ESPObjects, hl)
    return hl
end

local function CreateBillboard(parent, text, color)
    if not parent or not parent.Parent then return nil end
    local bb = Instance.new("BillboardGui")
    bb.Name = "OutcomeLabel"
    bb.Size = UDim2.new(0, 100, 0, 30)
    bb.StudsOffset = Vector3.new(0, 3, 0)
    bb.AlwaysOnTop = true
    bb.Adornee = parent
    bb.Parent = parent

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = color
    label.TextStrokeTransparency = 0.3
    label.TextScaled = true
    label.Font = Enum.Font.GothamBold
    label.Parent = bb
    table.insert(ESPObjects, bb)
    return bb
end

ESPTab:CreateToggle({
    Name = "Win Pad ESP",
    CurrentValue = false,
    Flag = "WinPadESPFlag",
    Callback = function(Value)
        State.WinPadESP = Value
        if Value then
            task.spawn(function()
                while State.WinPadESP do
                    ClearESP()
                    local pads = FindWinPads()
                    for _, pad in ipairs(pads) do
                        if pad and pad.Parent then
                            CreateHighlight(pad, Color3.fromRGB(255, 255, 0), "WinPad")
                            CreateBillboard(pad, "WIN", Color3.fromRGB(255, 255, 0))
                        end
                    end
                    task.wait(3)
                end
            end)
        else
            ClearESP()
        end
    end,
})

ESPTab:CreateToggle({
    Name = "Player ESP",
    CurrentValue = false,
    Flag = "PlayerESPFlag",
    Callback = function(Value)
        State.PlayerESP = Value
        if Value then
            task.spawn(function()
                while State.PlayerESP do
                    ClearESP()
                    for _, player in ipairs(Players:GetPlayers()) do
                        if player ~= LocalPlayer and player.Character then
                            local root = player.Character:FindFirstChild("HumanoidRootPart")
                            if root then
                                CreateHighlight(player.Character, Color3.fromRGB(255, 50, 50), "Player")
                                CreateBillboard(root, player.Name, Color3.fromRGB(255, 50, 50))
                            end
                        end
                    end
                    task.wait(2)
                end
            end)
        else
            ClearESP()
        end
    end,
})

-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
-- TELEPORT TAB
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
TeleportTab:CreateSection("Player Teleport")

local PlayerDropdown = TeleportTab:CreateDropdown({
    Name = "Select Player",
    Options = {},
    CurrentOption = {},
    Flag = "PlayerTPDropdown",
    Callback = function(Option)
        local target = Players:FindFirstChild(Option[1])
        if target and target.Character then
            local targetRoot = target.Character:FindFirstChild("HumanoidRootPart")
            local myRoot = GetRoot()
            if targetRoot and myRoot then
                myRoot.CFrame = targetRoot.CFrame
            end
        end
    end,
})

-- Refresh player list
local function RefreshPlayerList()
    local names = {}
    for _, p in ipairs(Players:GetPlayers()) do
        table.insert(names, p.Name)
    end
    PlayerDropdown:Refresh(names)
end

TeleportTab:CreateButton({
    Name = "Refresh Player List",
    Callback = function()
        RefreshPlayerList()
    end,
})

TeleportTab:CreateSection("Click Teleport")

TeleportTab:CreateToggle({
    Name = "Click TP (Right Click)",
    CurrentValue = false,
    Flag = "ClickTPFlag",
    Callback = function(Value)
        State.ClickTP = Value
        if Value then
            State.Connections.ClickTP = UserInputService.InputBegan:Connect(function(input, processed)
                if processed then return end
                if input.UserInputType == Enum.UserInputType.MouseButton2 then
                    local root = GetRoot()
                    if root then
                        local mouse = LocalPlayer:GetMouse()
                        if mouse.Hit then
                            root.CFrame = mouse.Hit + Vector3.new(0, 5, 0)
                        end
                    end
                end
            end)
        else
            Disconnect("ClickTP")
        end
    end,
})

-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
-- MISC TAB
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
MiscTab:CreateSection("Anti AFK")

MiscTab:CreateToggle({
    Name = "Anti AFK",
    CurrentValue = false,
    Flag = "AntiAFKFlag",
    Callback = function(Value)
        State.AntiAFK = Value
        if Value then
            State.Connections.AntiAFK = LocalPlayer.Idled:Connect(function()
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new())
            end)
        else
            Disconnect("AntiAFK")
        end
    end,
})

MiscTab:CreateSection("Cleanup")

MiscTab:CreateButton({
    Name = "Destroy All ESP",
    Callback = function()
        ClearESP()
    end,
})

MiscTab:CreateButton({
    Name = "Reset All Speed/Jump",
    Callback = function()
        local hum = GetHumanoid()
        if hum then
            hum.WalkSpeed = 16
            hum.JumpPower = 50
        end
        State.WalkSpeedEnabled = false
        State.JumpPowerEnabled = false
    end,
})

MiscTab:CreateButton({
    Name = "Destroy UI",
    Callback = function()
        ClearESP()
        for name, _ in pairs(State.Connections) do
            Disconnect(name)
        end
        State.AutoSpeed = false
        State.AutoWin = false
        State.AutoRebirth = false
        State.AutoTreadmill = false
        State.FlyEnabled = false
        State.NoClip = false
        State.InfiniteJump = false
        State.WalkSpeedEnabled = false
        State.JumpPowerEnabled = false
        State.ClickTP = false
        State.AntiAFK = false
        State.WinPadESP = false
        State.PlayerESP = false
        Window:Destroy()
    end,
})

-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
-- CORE LOOPS (RenderStepped for movement)
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
RunService.RenderStepped:Connect(function()
    local hum = GetHumanoid()
    if not hum then return end

    if State.WalkSpeedEnabled then
        hum.WalkSpeed = State.WalkSpeedValue
    end

    if State.JumpPowerEnabled then
        hum.JumpPower = State.JumpPowerValue
        hum.UseJumpPower = true
    end
end)

-- Auto-refresh player list periodically
task.spawn(function()
    while task.wait(5) do
        pcall(RefreshPlayerList)
    end
end)

-- Handle respawn
LocalPlayer.CharacterAdded:Connect(function(char)
    task.wait(1)
    if State.WalkSpeedEnabled then
        local hum = char:WaitForChild("Humanoid")
        hum.WalkSpeed = State.WalkSpeedValue
    end
    if State.NoClip then
        State.Connections.NoClip = RunService.Stepped:Connect(function()
            if State.NoClip then
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = false
                    end
                end
            end
        end)
    end
end)

-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
-- TOAST NOTIFICATION
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
Rayfield:Notify({
    Title = "OUTCOME HUB",
    Content = "+1 Speed Keyboard Escape loaded",
    Duration = 3,
})

print("[OUTCOME HUB] Loaded â€” +1 Speed Keyboard Escape")
