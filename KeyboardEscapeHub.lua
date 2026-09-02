-- ══════════════════════════════════════════════════════════════
-- OUTCOME HUB — Multi-Game Roblox Hub
-- Auto-detects the game and loads the right module
-- Games: +1 Speed Keyboard Escape | Basketball Legends
-- ══════════════════════════════════════════════════════════════

local Rayfield = loadstring(game:HttpGet('https://raw.githubusercontent.com/SiriusSoftwareLtd/Rayfield/main/source.lua'))()

-- ══════════════════════════════════════════════════════════════
-- SERVICES (shared)
-- ══════════════════════════════════════════════════════════════
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualUser = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- ══════════════════════════════════════════════════════════════
-- SHARED UTILITY
-- ══════════════════════════════════════════════════════════════
local Util = {}

function Util.GetCharacter()
    return LocalPlayer.Character
end

function Util.GetRoot()
    local char = Util.GetCharacter()
    return char and char:FindFirstChild("HumanoidRootPart")
end

function Util.GetHumanoid()
    local char = Util.GetCharacter()
    return char and char:FindFirstChildOfClass("Humanoid")
end

function Util.IsAlive()
    local hum = Util.GetHumanoid()
    return hum and hum.Health > 0
end

function Util.FindInstance(parent, className, names, depth)
    depth = depth or 0
    if depth > 8 then return nil end
    for _, obj in ipairs(parent:GetChildren()) do
        for _, n in ipairs(names) do
            if obj.Name == n and obj:IsA(className) then
                return obj
            end
        end
        local found = Util.FindInstance(obj, className, names, depth + 1)
        if found then return found end
    end
    return nil
end

function Util.FindRemote(names)
    return Util.FindInstance(ReplicatedStorage, "RemoteEvent", names)
end

function Util.ScanCompare(name, patterns)
    name = name:lower()
    for _, p in ipairs(patterns) do
        if name:find(p) then return true end
    end
    return false
end

-- ══════════════════════════════════════════════════════════════
-- GAME DETECTION
-- ══════════════════════════════════════════════════════════════
local GameName = "unknown"
local GameId = tostring(game.PlaceId)

-- Known PlaceIds (add these if auto-name detection fails)
local KNOWN_PLACE_IDS = {
    ["95082159892680"] = "keyboardescape", -- +1 Speed Keyboard Escape (root)
    ["9584852943"]     = "keyboardescape", -- +1 Speed Keyboard Escape (version)
    ["14259168147"]    = "basketball",     -- Basketball Legends (older/universe)
    ["71832465156084"] = "basketball",     -- Basketball Legends (current)
}

local function DetectGame()
    local pn = tostring(game.Name or ""):lower()

    -- 1) Explicit override via _G
    if _G.OutcomeGame then
        GameName = _G.OutcomeGame
        return GameName
    end

    -- 2) Place ID lookup
    local byPlace = KNOWN_PLACE_IDS[GameId]
    if byPlace then
        GameName = byPlace
        return GameName
    end

    -- 3) Name-based detection
    if pn:find("basketball") then
        GameName = "basketball"
    elseif pn:find("keyboard") or pn:find("escape") or pn:find("speed") then
        GameName = "keyboardescape"
    end

    return GameName
end

-- Enhance name detection with Marketplace product info (non-blocking)
task.spawn(function()
    if GameName ~= "unknown" then return end
    task.wait(1)
    local ok, info = pcall(function()
        return game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId)
    end)
    if ok and info and info.Name then
        local n = info.Name:lower()
        if n:find("basketball") then
            GameName = "basketball"
        elseif n:find("keyboard") or n:find("escape") or n:find("speed") then
            GameName = "keyboardescape"
        end
    end
end)

DetectGame()

-- ══════════════════════════════════════════════════════════════
-- WINDOW (shared)
-- ══════════════════════════════════════════════════════════════
local Window = Rayfield:CreateWindow({
    Name = "OUTCOME HUB",
    LoadingTitle = "Multi-Game Hub",
    LoadingSubtitle = (GameName == "keyboardescape" and "+1 Speed Keyboard Escape")
        or (GameName == "basketball" and "Basketball Legends")
        or "Game: " .. tostring(game.Name),
    ConfigurationSaving = { Enabled = false },
    Discord = { Enabled = false },
    KeySystem = false,
})

-- ══════════════════════════════════════════════════════════════
-- GAME MODULE: +1 SPEED KEYBOARD ESCAPE
-- ══════════════════════════════════════════════════════════════
function require_KeyboardEscape()
    -- KNOWN COORDINATES
    local STAGE_CFAMES = {
        [1]  = CFrame.new(-16.488636, 6.8571434, 284.741302),
        [2]  = CFrame.new(-16.488636, 6.8571434, 506.733978),
        [3]  = CFrame.new(-16.488636, 75.1460419, 774.375122),
        [4]  = CFrame.new(-16.488636, 75.1460419, 1108.35461),
        [5]  = CFrame.new(-16.488636, 75.1460419, 1411.3446),
        [6]  = CFrame.new(-538.371643, 52.5018692, 1447.88953),
        [7]  = CFrame.new(-1007.7088, 52.5018692, 1447.88953),
        [8]  = CFrame.new(-1123.46582, 294.501862, 1447.88953),
        [9]  = nil,
        [10] = nil,
        [11] = nil,
        [12] = nil,
        [13] = nil,
        [14] = nil,
        [15] = nil,
    }
    local TREADMILL_CF = CFrame.new(18.0236549, 7.54272556, -40.5097961)

    -- STATE
    local S = {
        AutoSpeed = false, AutoSpeedDelay = 0.01, AutoSpeedMode = "Quad",
        AutoWin = false, AutoWinTween = false, AutoWinTweenSpeed = 0.5, AutoWinDelay = 3,
        AutoRebirth = false, AutoRebirthDelay = 1,
        AutoTreadmill = false,
        AutoStep = false, AutoStepDelay = 0.1,
        WalkSpeedEnabled = false, WalkSpeedValue = 50,
        JumpPowerEnabled = false, JumpPowerValue = 100,
        InfiniteJump = false, NoClip = false, FlyEnabled = false, FlySpeed = 50,
        ClickTP = false, AntiAFK = false,
        Connections = {},
    }

    local function DConn(name)
        if S.Connections[name] then S.Connections[name]:Disconnect(); S.Connections[name] = nil end
    end

    local Remotes = {}
    local function ScanRemotes()
        local function scan(parent, depth)
            if depth > 5 then return end
            for _, obj in ipairs(parent:GetChildren()) do
                if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
                    local name = obj.Name:lower()
                    if name:find("speed") or name:find("update") or name:find("step") then
                        Remotes.UpdateSpeed = obj
                    elseif name:find("rebirth") then
                        Remotes.Rebirth = obj
                    elseif name:find("win") then
                        Remotes.Win = obj
                    elseif name:find("teleport") or name:find("tp") then
                        Remotes.Teleport = obj
                    end
                end
                scan(obj, depth + 1)
            end
        end
        scan(ReplicatedStorage, 0)
        scan(Workspace, 0)
    end
    pcall(ScanRemotes)

    -- Saved per-stage coords (user + auto)
    local SavedStageCoords = {}
    local SelectedStage = 1
    pcall(function() if _G.OutcomeWinCoords then SavedStageCoords = _G.OutcomeWinCoords end end)

    local function SaveCoordsForStage(stage, pos)
        SavedStageCoords[stage] = pos
        _G.OutcomeWinCoords = SavedStageCoords
    end

    local function GetStageCFrame(stage)
        if STAGE_CFAMES[stage] then return STAGE_CFAMES[stage] end
        local saved = SavedStageCoords[stage]
        if saved then return CFrame.new(saved) end
        return nil
    end

    -- Win pad scanner (workspace parts by name/color)
    local WinPadCache = { pads = {}, lastScan = 0 }

    local function FindWinPads(forceRescan)
        if not forceRescan and WinPadCache.pads and #WinPadCache.pads > 0
            and os.clock() - WinPadCache.lastScan < 3 then
            return WinPadCache.pads
        end
        local pads = {}
        local seen = {}
        local function scan(parent)
            for _, obj in ipairs(parent:GetChildren()) do
                if obj:IsA("BasePart") and not seen[obj] then
                    local name = obj.Name:lower()
                    local isWin = false
                    if name:find("win") or name:find("trophy") or name:find("finish")
                        or name:find("end") or name:find("pad") or name:find("zone")
                        or name:find("button") or name:find("block") then
                        isWin = true
                    end
                    local r, g, b = obj.Color.R, obj.Color.G, obj.Color.B
                    if r > 0.85 and g > 0.85 and b < 0.3 then isWin = true end
                    if isWin then seen[obj] = true; table.insert(pads, obj) end
                elseif obj:IsA("Model") then
                    local primary = obj.PrimaryPart
                    if primary and not seen[primary] then
                        local name = primary.Name:lower()
                        local isWin = false
                        if name:find("win") or name:find("trophy") or name:find("finish")
                            or name:find("end") or name:find("pad") or name:find("zone")
                            or name:find("button") or name:find("block") then
                            isWin = true
                        end
                        local r, g, b = primary.Color.R, primary.Color.G, primary.Color.B
                        if r > 0.85 and g > 0.85 and b < 0.3 then isWin = true end
                        if isWin then seen[primary] = true; table.insert(pads, primary) end
                    end
                    scan(obj)
                elseif obj:IsA("Folder") then
                    scan(obj)
                end
            end
        end
        scan(Workspace)
        if #pads > 1 then
            table.sort(pads, function(a, b)
                return (a.Position - LocalPlayer:GetMouse().Hit.Position).Magnitude
                    < (b.Position - LocalPlayer:GetMouse().Hit.Position).Magnitude
            end)
        end
        WinPadCache.pads = pads
        WinPadCache.lastScan = os.clock()
        return pads
    end

    local function GetNearestWinPad()
        local pads = FindWinPads(true)
        if #pads == 0 then return nil end
        local root = Util.GetRoot()
        if not root then return pads[1] end
        local nearest, nd = nil, math.huge
        for _, p in ipairs(pads) do
            if p and p.Parent then
                local d = (root.Position - p.Position).Magnitude
                if d < nd then nd = d; nearest = p end
            end
        end
        return nearest
    end

    -- Treadmill scanner
    local function FindTreadmills()
        local treads = {}
        local seen = {}
        local function scan(parent)
            for _, obj in ipairs(parent:GetChildren()) do
                local name = obj.Name:lower()
                if (name:find("treadmill") or name:find("tread") or name:find("training")
                    or name:find("afk") or name:find("farm")) and not seen[obj] then
                    seen[obj] = true
                    if obj:IsA("BasePart") then table.insert(treads, obj)
                    elseif obj:IsA("Model") then
                        local p = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
                        if p then table.insert(treads, p) end
                    end
                end
                if obj:IsA("Model") or obj:IsA("Folder") then scan(obj) end
            end
        end
        scan(Workspace)
        return treads
    end

    local function GetBestTreadmill()
        local treads = FindTreadmills()
        if #treads == 0 then return nil end
        local priority = { admin = 5, candy = 4, diamond = 3, gold = 2, normal = 1 }
        local best, bestP = nil, -1
        for _, t in ipairs(treads) do
            if t and t.Parent then
                local name = t.Name:lower()
                local p = 1
                for k, v in pairs(priority) do if name:find(k) then p = v; break end end
                if p > bestP then bestP = p; best = t end
            end
        end
        return best
    end

    -- Coordinator status label helper
    local function RefreshCoordStatus(label, coords)
        local count = 0
        for _ in pairs(coords) do count = count + 1 end
        label:Set(string.format("Coords saved: %d / 15 stages", count))
    end

    -- TABS
    local FarmTab = Window:CreateTab("Auto Farm", 4483362458)
    local MovementTab = Window:CreateTab("Movement", 4483362458)
    local ESPTab = Window:CreateTab("ESP", 4483362458)
    local TeleportTab = Window:CreateTab("Teleport", 4483362458)
    local MiscTab = Window:CreateTab("Misc", 4483362458)

    -- Speed Farm
    FarmTab:CreateSection("Speed Farm")
    FarmTab:CreateToggle({ Name = "Auto Speed (Key Trigger)", CurrentValue = false, Flag = "KESpeedFlag",
        Callback = function(v)
            S.AutoSpeed = v
            if v then task.spawn(function()
                while S.AutoSpeed do
                    local root, hum = Util.GetRoot(), Util.GetHumanoid()
                    if root and hum and Util.IsAlive() then
                        if S.AutoSpeedMode == "Quad" then
                            for _, dir in ipairs({CFrame.new(0,0,-2),CFrame.new(0,0,2),CFrame.new(2,0,0),CFrame.new(-2,0,0)}) do
                                if not S.AutoSpeed or not Util.IsAlive() then break end
                                root.CFrame = root.CFrame * dir
                                hum:Move(Vector3.new(dir.X,0,dir.Z), true)
                                RunService.Heartbeat:Wait()
                            end
                        elseif S.AutoSpeedMode == "Spin" then
                            if not S.AutoSpeed or not Util.IsAlive() then break end
                            root.CFrame = root.CFrame * CFrame.Angles(0, math.rad(90), 0)
                            hum:Move(Vector3.new(1,0,0), true)
                            RunService.Heartbeat:Wait()
                        elseif S.AutoSpeedMode == "Forward" then
                            if not S.AutoSpeed or not Util.IsAlive() then break end
                            root.CFrame = root.CFrame * CFrame.new(0,0,-3)
                            hum:Move(Vector3.new(0,0,-1), true)
                            RunService.Heartbeat:Wait()
                        end
                    end
                    task.wait(S.AutoSpeedDelay)
                end
            end) end
        end })
    FarmTab:CreateDropdown({ Name = "Speed Mode", Options = {"Quad","Spin","Forward"}, CurrentOption = {"Quad"}, Flag = "KESpeedModeFlag",
        Callback = function(o) S.AutoSpeedMode = o[1] end })
    FarmTab:CreateSlider({ Name = "Speed Delay", Range = {0.01,0.5}, Increment = 0.01, Suffix = "s", CurrentValue = 0.01, Flag = "KESpeedDelayFlag",
        Callback = function(v) S.AutoSpeedDelay = v end })

    -- Auto Step remote
    FarmTab:CreateSection("Auto Step (Remote)")
    FarmTab:CreateToggle({ Name = "Auto Step (Fire UpdateSpeed)", CurrentValue = false, Flag = "KEStepFlag",
        Callback = function(v)
            S.AutoStep = v
            if v then task.spawn(function()
                while S.AutoStep do
                    if Remotes.UpdateSpeed then pcall(function() Remotes.UpdateSpeed:FireServer() end) end
                    task.wait(S.AutoStepDelay)
                end
            end) end
        end })
    FarmTab:CreateSlider({ Name = "Step Fire Rate", Range = {0.05,1}, Increment = 0.05, Suffix = "s", CurrentValue = 0.1, Flag = "KEStepDelayFlag",
        Callback = function(v) S.AutoStepDelay = v end })

    -- Auto Win
    FarmTab:CreateSection("Auto Win")
    local CoordStatus = FarmTab:CreateLabel("Coords saved: none yet")
    RefreshCoordStatus(CoordStatus, SavedStageCoords)

    FarmTab:CreateDropdown({ Name = "Select Stage", Options = {"Stage 1","Stage 2","Stage 3","Stage 4","Stage 5","Stage 6","Stage 7","Stage 8","Stage 9","Stage 10","Stage 11","Stage 12","Stage 13","Stage 14","Stage 15"}, CurrentOption = {"Stage 1"}, Flag = "KEStageFlag",
        Callback = function(o)
            local name = o[1] or "Stage 1"
            SelectedStage = tonumber(name:match("%d+")) or 1
        end })

    FarmTab:CreateButton({ Name = "Save My Position as Stage Win Pad",
        Callback = function()
            local root = Util.GetRoot()
            if root then
                SaveCoordsForStage(SelectedStage, root.Position)
                Rayfield:Notify({ Title = "Position Saved", Content = string.format("Stage %d: %.0f, %.0f, %.0f", SelectedStage, root.Position.X, root.Position.Y, root.Position.Z), Duration = 4 })
                RefreshCoordStatus(CoordStatus, SavedStageCoords)
            end
        end })
    FarmTab:CreateButton({ Name = "Clear All Saved Coords",
        Callback = function() SavedStageCoords = {}; _G.OutcomeWinCoords = {}; RefreshCoordStatus(CoordStatus, SavedStageCoords); Rayfield:Notify({Title="Cleared",Content="All saved coords removed",Duration=2}) end })
    FarmTab:CreateButton({ Name = "Auto-Scan Win Pads (fallback)",
        Callback = function()
            WinPadCache.pads = {}; WinPadCache.lastScan = 0
            local pads = FindWinPads(true)
            for i, pad in ipairs(pads) do if i <= 15 and not SavedStageCoords[i] then SaveCoordsForStage(i, pad.Position) end end
            RefreshCoordStatus(CoordStatus, SavedStageCoords)
            Rayfield:Notify({ Title = "Scan Complete", Content = string.format("Found %d pads", #pads), Duration = 3 })
        end })

    FarmTab:CreateToggle({ Name = "Auto Win", CurrentValue = false, Flag = "KEAutoWinFlag",
        Callback = function(v)
            S.AutoWin = v
            if v then task.spawn(function()
                while S.AutoWin do
                    local root = Util.GetRoot()
                    if root and Util.IsAlive() then
                        local targetCF = GetStageCFrame(SelectedStage)
                        if not targetCF then
                            local nearest = GetNearestWinPad()
                            if nearest then targetCF = nearest.CFrame + Vector3.new(0,3,0) end
                        end
                        if targetCF then
                            local tp = targetCF + Vector3.new(0,3,0)
                            if S.AutoWinTween then
                                local tw = TweenService:Create(root, TweenInfo.new(S.AutoWinTweenSpeed, Enum.EasingStyle.Linear), {CFrame = tp})
                                tw:Play(); tw.Completed:Wait()
                            else
                                root.CFrame = tp
                            end
                        end
                    end
                    task.wait(S.AutoWinDelay)
                end
            end) end
        end })
    FarmTab:CreateToggle({ Name = "Tween Mode (Smooth TP)", CurrentValue = false, Flag = "KEWinTweenFlag",
        Callback = function(v) S.AutoWinTween = v end })
    FarmTab:CreateSlider({ Name = "Tween Speed", Range = {0.1,3}, Increment = 0.1, Suffix = "s", CurrentValue = 0.5, Flag = "KEWinTweenSpeedFlag",
        Callback = function(v) S.AutoWinTweenSpeed = v end })
    FarmTab:CreateSlider({ Name = "Auto Win Delay (between TPs)", Range = {0.5,10}, Increment = 0.5, Suffix = "s", CurrentValue = 3, Flag = "KEWinDelayFlag",
        Callback = function(v) S.AutoWinDelay = v end })

    -- Auto Rebirth
    FarmTab:CreateSection("Auto Rebirth")
    local function ClickRebirth()
        if Remotes.Rebirth then pcall(function() Remotes.Rebirth:FireServer() end) end
        local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
        if pg then
            local function scanUI(parent)
                for _, obj in ipairs(parent:GetChildren()) do
                    if obj:IsA("TextLabel") or obj:IsA("TextButton") then
                        local text = obj.Text and obj.Text:lower() or ""
                        if text:find("rebirth") then
                            local btn = obj:FindFirstAncestorOfClass("TextButton") or obj:FindFirstAncestorOfClass("ImageButton")
                            if btn then pcall(function() local p = btn.AbsolutePosition + btn.AbsoluteSize/2; VirtualUser:ClickButtonAt(p) end); return true end
                            if obj:IsA("TextButton") then obj:Activate(); return true end
                        end
                    end
                    if obj:IsA("GuiButton") and obj.Name:lower():find("rebirth") then obj:Activate(); return true end
                    scanUI(obj)
                end
            end
            scanUI(pg)
        end
    end
    FarmTab:CreateToggle({ Name = "Auto Rebirth", CurrentValue = false, Flag = "KERebirthFlag",
        Callback = function(v)
            S.AutoRebirth = v
            if v then task.spawn(function() while S.AutoRebirth do ClickRebirth(); task.wait(S.AutoRebirthDelay) end end) end
        end })
    FarmTab:CreateSlider({ Name = "Rebirth Delay", Range = {0.5,10}, Increment = 0.5, Suffix = "s", CurrentValue = 1, Flag = "KERebirthDelayFlag",
        Callback = function(v) S.AutoRebirthDelay = v end })

    -- Auto Treadmill
    FarmTab:CreateSection("Auto Treadmill")
    FarmTab:CreateToggle({ Name = "Auto Treadmill (AFK Farm)", CurrentValue = false, Flag = "KETreadmillFlag",
        Callback = function(v)
            S.AutoTreadmill = v
            if v then task.spawn(function()
                while S.AutoTreadmill do
                    if S.AutoWin then break end
                    local root = Util.GetRoot()
                    if root and Util.IsAlive() then
                        local targetCF = TREADMILL_CF
                        if not targetCF then local t = GetBestTreadmill(); if t then targetCF = t.CFrame end end
                        if targetCF then root.CFrame = targetCF + Vector3.new(0,3,0) end
                    end
                    task.wait(3)
                end
            end) end
        end })

    -- Movement
    MovementTab:CreateSection("Speed & Jump")
    MovementTab:CreateToggle({ Name = "Custom WalkSpeed", CurrentValue = false, Flag = "KEWalkSpeedFlag",
        Callback = function(v) S.WalkSpeedEnabled = v; if not v then local h = Util.GetHumanoid(); if h then h.WalkSpeed = 16 end end end })
    MovementTab:CreateSlider({ Name = "WalkSpeed Value", Range = {16,500}, Increment = 1, Suffix = " studs/s", CurrentValue = 50, Flag = "KEWalkSpeedValFlag",
        Callback = function(v) S.WalkSpeedValue = v end })
    MovementTab:CreateToggle({ Name = "Custom JumpPower", CurrentValue = false, Flag = "KEJumpFlag",
        Callback = function(v) S.JumpPowerEnabled = v; if not v then local h = Util.GetHumanoid(); if h then h.JumpPower = 50; h.UseJumpPower = true end end end })
    MovementTab:CreateSlider({ Name = "JumpPower Value", Range = {50,300}, Increment = 5, Suffix = " studs", CurrentValue = 100, Flag = "KEJumpValFlag",
        Callback = function(v) S.JumpPowerValue = v end })
    MovementTab:CreateToggle({ Name = "Infinite Jump", CurrentValue = false, Flag = "KEInfJumpFlag",
        Callback = function(v)
            S.InfiniteJump = v
            if v then S.Connections.InfJump = UserInputService.JumpRequest:Connect(function() if S.InfiniteJump and Util.IsAlive() then local h = Util.GetHumanoid(); if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end end end)
            else DConn("InfJump") end
        end })

    MovementTab:CreateSection("Fly & NoClip")
    MovementTab:CreateToggle({ Name = "Fly (Space=Up, Ctrl=Down)", CurrentValue = false, Flag = "KEFlyFlag",
        Callback = function(v)
            S.FlyEnabled = v
            if v then
                local bv, bg
                S.Connections.Fly = RunService.RenderStepped:Connect(function()
                    local root = Util.GetRoot()
                    if not root or not Util.IsAlive() then
                        S.FlyEnabled = false
                        if bv then bv:Destroy() end; if bg then bg:Destroy() end
                        DConn("Fly"); return
                    end
                    if not bv then
                        bv = Instance.new("BodyVelocity"); bv.MaxForce = Vector3.new(math.huge,math.huge,math.huge); bv.Velocity = Vector3.zero; bv.Parent = root
                        bg = Instance.new("BodyGyro"); bg.MaxTorque = Vector3.new(math.huge,math.huge,math.huge); bg.P = 9000; bg.D = 500; bg.Parent = root
                    end
                    local md = Vector3.zero
                    local cam = Camera.CFrame
                    if UserInputService:IsKeyDown(Enum.KeyCode.W) then md = md + cam.LookVector end
                    if UserInputService:IsKeyDown(Enum.KeyCode.S) then md = md - cam.LookVector end
                    if UserInputService:IsKeyDown(Enum.KeyCode.A) then md = md - cam.RightVector end
                    if UserInputService:IsKeyDown(Enum.KeyCode.D) then md = md + cam.RightVector end
                    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then md = md + Vector3.new(0,1,0) end
                    if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then md = md - Vector3.new(0,1,0) end
                    if md.Magnitude > 0 then md = md.Unit * S.FlySpeed end
                    bv.Velocity = md; bg.CFrame = cam
                end)
            else
                DConn("Fly")
                local root = Util.GetRoot()
                if root then for _, v in ipairs(root:GetChildren()) do if v:IsA("BodyVelocity") or v:IsA("BodyGyro") then v:Destroy() end end end
            end
        end })
    MovementTab:CreateSlider({ Name = "Fly Speed", Range = {10,200}, Increment = 5, Suffix = " studs/s", CurrentValue = 50, Flag = "KEFlySpeedFlag",
        Callback = function(v) S.FlySpeed = v end })
    MovementTab:CreateToggle({ Name = "NoClip", CurrentValue = false, Flag = "KENoClipFlag",
        Callback = function(v)
            S.NoClip = v
            if v then S.Connections.NoClip = RunService.Stepped:Connect(function() if S.NoClip then local c = Util.GetCharacter(); if c then for _, p in ipairs(c:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide = false end end end end end)
            else DConn("NoClip") end
        end })

    -- ESP
    local ESPObjects = {}
    local function ClearESP()
        for _, v in ipairs(ESPObjects) do if v and v.Parent then v:Destroy() end end
        ESPObjects = {}
    end
    local function MkHighlight(parent, color, name)
        if not parent or not parent.Parent then return nil end
        local hl = Instance.new("Highlight"); hl.Name = "OH_"..(name or ""); hl.FillColor = color; hl.OutlineColor = color; hl.FillTransparency = 0.6; hl.OutlineTransparency = 0; hl.Adornee = parent; hl.Parent = parent
        table.insert(ESPObjects, hl); return hl
    end
    local function MkLabel(parent, text, color)
        if not parent or not parent.Parent then return nil end
        local bb = Instance.new("BillboardGui"); bb.Name = "OHLabel"; bb.Size = UDim2.new(0,100,0,30); bb.StudsOffset = Vector3.new(0,3,0); bb.AlwaysOnTop = true; bb.Adornee = parent; bb.Parent = parent
        local l = Instance.new("TextLabel"); l.Size = UDim2.new(1,0,1,0); l.BackgroundTransparency = 1; l.Text = text; l.TextColor3 = color; l.TextStrokeTransparency = 0.3; l.TextScaled = true; l.Font = Enum.Font.GothamBold; l.Parent = bb
        table.insert(ESPObjects, bb); return bb
    end

    ESPTab:CreateSection("Highlights")
    ESPTab:CreateToggle({ Name = "Win Pad ESP", CurrentValue = false, Flag = "KEWinPadESPFlag",
        Callback = function(v)
            S.WinPadESP = v
            if v then task.spawn(function()
                while S.WinPadESP do
                    ClearESP()
                    local pads = FindWinPads(true)
                    for i, p in ipairs(pads) do if p and p.Parent then MkHighlight(p, Color3.fromRGB(255,255,0), "WinPad"); MkLabel(p, "WIN #"..i, Color3.fromRGB(255,255,0)) end end
                    task.wait(3)
                end
            end) else ClearESP() end
        end })
    ESPTab:CreateToggle({ Name = "Player ESP", CurrentValue = false, Flag = "KEPlayerESPFlag",
        Callback = function(v)
            S.PlayerESP = v
            if v then task.spawn(function()
                while S.PlayerESP do
                    for _, pl in ipairs(Players:GetPlayers()) do
                        if pl ~= LocalPlayer and pl.Character then
                            local r = pl.Character:FindFirstChild("HumanoidRootPart")
                            if r then MkHighlight(pl.Character, Color3.fromRGB(255,50,50), "Player"); MkLabel(r, pl.Name, Color3.fromRGB(255,50,50)) end
                        end
                    end
                    task.wait(2)
                end
            end) else ClearESP() end
        end })
    ESPTab:CreateToggle({ Name = "Treadmill ESP", CurrentValue = false, Flag = "KETreadESPFlag",
        Callback = function(v)
            S.TreadmillESP = v
            if v then task.spawn(function()
                while S.TreadmillESP do
                    local treads = FindTreadmills()
                    for _, t in ipairs(treads) do if t and t.Parent then MkHighlight(t, Color3.fromRGB(0,200,255), "Tread"); MkLabel(t, t.Name, Color3.fromRGB(0,200,255)) end end
                    task.wait(3)
                end
            end) else ClearESP() end
        end })

    -- Teleport
    TeleportTab:CreateSection("Player Teleport")
    local PlayerDropdown = TeleportTab:CreateDropdown({ Name = "Select Player", Options = {}, CurrentOption = {}, Flag = "KEPlayerTP",
        Callback = function(o)
            local t = Players:FindFirstChild(o[1])
            if t and t.Character then local tr = t.Character:FindFirstChild("HumanoidRootPart"); local mr = Util.GetRoot(); if tr and mr then mr.CFrame = tr.CFrame + Vector3.new(0,3,0) end end
        end })
    local function RefreshPlayers()
        local names = {}
        for _, p in ipairs(Players:GetPlayers()) do table.insert(names, p.Name) end
        PlayerDropdown:Refresh(names)
    end
    TeleportTab:CreateButton({ Name = "Refresh Player List", Callback = RefreshPlayers })

    TeleportTab:CreateSection("Stage Teleport")
    TeleportTab:CreateLabel("Uses Stage from Auto Farm tab")
    TeleportTab:CreateButton({ Name = "TP to Selected Stage Win Pad",
        Callback = function()
            local cf = GetStageCFrame(SelectedStage)
            if cf then local root = Util.GetRoot(); if root then root.CFrame = cf + Vector3.new(0,3,0) end
            else
                local pad = FindWinPads(true)[SelectedStage]
                if pad then local root = Util.GetRoot(); if root then root.CFrame = pad.CFrame + Vector3.new(0,3,0) end
                else Rayfield:Notify({Title="No Coords",Content="No saved coords for stage "..SelectedStage..". Save one in Auto Farm.",Duration=4}) end
            end
        end })
    TeleportTab:CreateButton({ Name = "TP to Nearest Win Pad",
        Callback = function() local p = GetNearestWinPad(); if p then local r = Util.GetRoot(); if r then r.CFrame = p.CFrame + Vector3.new(0,3,0) end end end })

    TeleportTab:CreateSection("World Teleport")
    TeleportTab:CreateButton({ Name = "TP to World 1 Win Zone", Callback = function() local r = Util.GetRoot(); if r then r.CFrame = CFrame.new(-14003.95, 755.54, 3066) end end })
    TeleportTab:CreateButton({ Name = "TP to World 2 Win Zone", Callback = function() local r = Util.GetRoot(); if r then r.CFrame = CFrame.new(7984, 733, 5144) end end })

    TeleportTab:CreateSection("Click Teleport")
    TeleportTab:CreateToggle({ Name = "Click TP (Right Click)", CurrentValue = false, Flag = "KEClickTPFlag",
        Callback = function(v)
            S.ClickTP = v
            if v then S.Connections.ClickTP = UserInputService.InputBegan:Connect(function(input, processed)
                if processed then return end
                if input.UserInputType == Enum.UserInputType.MouseButton2 then
                    local root = Util.GetRoot()
                    if root then local m = LocalPlayer:GetMouse(); if m.Hit then root.CFrame = m.Hit + Vector3.new(0,5,0) end end
                end
            end) else DConn("ClickTP") end
        end })

    -- Misc
    MiscTab:CreateSection("Position Tracker")
    local LX = MiscTab:CreateLabel("X: 0"); local LY = MiscTab:CreateLabel("Y: 0"); local LZ = MiscTab:CreateLabel("Z: 0")
    S.Connections.PosTracker = RunService.Heartbeat:Connect(function()
        local root = Util.GetRoot()
        if root then local p = root.Position; LX:Set(string.format("X: %.1f", p.X)); LY:Set(string.format("Y: %.1f", p.Y)); LZ:Set(string.format("Z: %.1f", p.Z)) end
    end)

    MiscTab:CreateSection("Anti AFK")
    MiscTab:CreateToggle({ Name = "Anti AFK", CurrentValue = false, Flag = "KEAntiAFKFlag",
        Callback = function(v)
            S.AntiAFK = v
            if v then S.Connections.AntiAFK = LocalPlayer.Idled:Connect(function() VirtualUser:CaptureController(); VirtualUser:ClickButton2(Vector2.new()) end)
            else DConn("AntiAFK") end
        end })

    MiscTab:CreateSection("Cleanup")
    MiscTab:CreateButton({ Name = "Destroy All ESP", Callback = ClearESP })
    MiscTab:CreateButton({ Name = "Reset All Speed/Jump",
        Callback = function() local h = Util.GetHumanoid(); if h then h.WalkSpeed = 16; h.JumpPower = 50 end; S.WalkSpeedEnabled = false; S.JumpPowerEnabled = false end })
    MiscTab:CreateButton({ Name = "Destroy UI",
        Callback = function()
            ClearESP()
            for name, _ in pairs(S.Connections) do DConn(name) end
            S.AutoSpeed=false; S.AutoWin=false; S.AutoRebirth=false; S.AutoTreadmill=false; S.AutoStep=false
            S.FlyEnabled=false; S.NoClip=false; S.InfiniteJump=false; S.WalkSpeedEnabled=false; S.JumpPowerEnabled=false; S.ClickTP=false; S.AntiAFK=false
            Window:Destroy()
        end })

    -- Core loops
    RunService.RenderStepped:Connect(function()
        local h = Util.GetHumanoid()
        if not h then return end
        if S.WalkSpeedEnabled then h.WalkSpeed = S.WalkSpeedValue end
        if S.JumpPowerEnabled then h.JumpPower = S.JumpPowerValue; h.UseJumpPower = true end
    end)

    task.spawn(function() while task.wait(5) do pcall(RefreshPlayers) end end)

    LocalPlayer.CharacterAdded:Connect(function(char)
        task.wait(1)
        if S.WalkSpeedEnabled then local h = char:WaitForChild("Humanoid"); h.WalkSpeed = S.WalkSpeedValue end
        if S.NoClip then
            S.Connections.NoClip = RunService.Stepped:Connect(function()
                if S.NoClip then for _, p in ipairs(char:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide = false end end end
            end)
        end
    end)

    Rayfield:Notify({ Title = "OUTCOME HUB", Content = "+1 Speed Keyboard Escape loaded", Duration = 3 })
end

-- ══════════════════════════════════════════════════════════════
-- GAME MODULE: BASKETBALL LEGENDS
-- ══════════════════════════════════════════════════════════════
function require_Basketball()
    local S = {
        AutoShoot = false, ShotPower = 1.0, ShotDelay = 0.25,
        AutoGreenOnly = true,
        BallMagnet = false, MagnetRange = 30,
        AutoGuard = false, AutoGuardHold = false,
        SpeedBoost = false, SpeedVal = 20,
        AutoShootOnRelease = false,
        Connections = {},
    }

    local function DConn(name)
        if S.Connections[name] then S.Connections[name]:Disconnect(); S.Connections[name] = nil end
    end

    -- Locate shooting remote + shooting UI element
    local ShootRemote
    local ShootingUI

    local function FindShootRemote()
        -- Known path: ReplicatedStorage.Packages.Knit.Services.ControlService.RE.Shoot
        ShootRemote = Util.FindInstance(ReplicatedStorage, "RemoteEvent", { "Shoot" })
        if not ShootRemote then
            ShootRemote = Util.FindInstance(ReplicatedStorage, "RemoteEvent", { "DoShoot", "ShootBall", "ThrowBall" })
        end
    end

    local function FindShootingUI()
        local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
        if not pg then return end
        ShootingUI = Util.FindInstance(pg, "Frame", { "Shooting", "ShotMeter", "ShootBar" })
    end

    FindShootRemote()
    FindShootingUI()

    -- Ball finder
    local function FindBasketball()
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj.Name == "Basketball" and obj:IsA("BasePart") then
                return obj
            end
        end
        return nil
    end

    -- Player with ball finder
    local function FindBallCarrier()
        for _, pl in ipairs(Players:GetPlayers()) do
            if pl ~= LocalPlayer and pl.Character then
                if pl.Character:FindFirstChild("Basketball") then
                    return pl, pl.Character:FindFirstChild("HumanoidRootPart")
                end
            end
        end
        return nil, nil
    end

    local function FireShoot()
        if ShootRemote then
            pcall(function() ShootRemote:FireServer(S.ShotPower) end)
        end
    end

    -- TABS
    local MainTab = Window:CreateTab("Shooting", 6074139177)
    local DefenseTab = Window:CreateTab("Defense", 6074139177)
    local BallTab = Window:CreateTab("Ball", 6074139177)
    local PlayerTab = Window:CreateTab("Player", 6074139177)
    local MiscTab = Window:CreateTab("Misc", 6074139177)

    -- SHOOTING
    MainTab:CreateSection("Auto Shoot")
    MainTab:CreateToggle({ Name = "Auto Green Shot", CurrentValue = false, Flag = "BLAutoGreenFlag",
        Callback = function(v)
            S.AutoShoot = v
            if v then
                -- Watch shooting UI visibility; fire when visible
                S.Connections.AutoShoot = RunService.RenderStepped:Connect(function()
                    if not S.AutoShoot then return end
                    if ShootingUI and ShootingUI.Visible then
                        task.wait(S.ShotDelay)
                        FireShoot()
                    end
                end)
            else
                DConn("AutoShoot")
            end
        end })
    MainTab:CreateSlider({ Name = "Shot Power %", Range = {50,100}, Increment = 1, Suffix = "%", CurrentValue = 100, Flag = "BLShotPowerFlag",
        Callback = function(v) S.ShotPower = v / 100 end })
    MainTab:CreateSlider({ Name = "Release Delay (s)", Range = {0,1}, Increment = 0.05, Suffix = "s", CurrentValue = 0.25, Flag = "BLShotDelayFlag",
        Callback = function(v) S.ShotDelay = v end })

    MainTab:CreateSection("Shoot Keybind")
    MainTab:CreateToggle({ Name = "Auto Shoot On Key Press (G)", CurrentValue = false, Flag = "BLShootKeyFlag",
        Callback = function(v)
            S.AutoShootOnRelease = v
            if v then S.Connections.ShootKey = UserInputService.InputBegan:Connect(function(input, proc)
                if proc then return end
                if input.KeyCode == Enum.KeyCode.G then
                    task.wait(0.1)
                    FireShoot()
                end
            end) else DConn("ShootKey") end
        end })

    -- DEFENSE
    DefenseTab:CreateSection("Auto Guard")
    DefenseTab:CreateToggle({ Name = "Auto Guard (Hold G)", CurrentValue = false, Flag = "BLAutoGuardFlag",
        Callback = function(v)
            S.AutoGuard = v
            if v then
                S.Connections.AutoGuard = RunService.RenderStepped:Connect(function()
                    if not S.AutoGuard then return end
                    if S.AutoGuardHold and not UserInputService:IsKeyDown(Enum.KeyCode.G) then return end
                    local carrier, carrierRoot = FindBallCarrier()
                    local myChar = Util.GetCharacter()
                    if carrier and carrierRoot and myChar then
                        local myRoot = Util.GetRoot()
                        if myRoot then
                            local hum = Util.GetHumanoid()
                            if hum then
                                local dist = (myRoot.Position - carrierRoot.Position).Magnitude
                                if dist < 15 then
                                    hum:MoveTo(carrierRoot.Position)
                                    -- Press F to attempt steal/block
                                end
                            end
                        end
                    end
                end)
            else DConn("AutoGuard") end
        end })
    DefenseTab:CreateToggle({ Name = "Require Holding G", CurrentValue = false, Flag = "BLGuardHoldFlag",
        Callback = function(v) S.AutoGuardHold = v end })

    -- BALL
    BallTab:CreateSection("Ball Magnet")
    BallTab:CreateToggle({ Name = "Ball Magnet", CurrentValue = false, Flag = "BLMagnetFlag",
        Callback = function(v)
            S.BallMagnet = v
            if v then S.Connections.Magnet = RunService.Heartbeat:Connect(function()
                if not S.BallMagnet then return end
                local root = Util.GetRoot()
                if not root then return end
                local ball = FindBasketball()
                if ball then
                    if (root.Position - ball.Position).Magnitude < S.MagnetRange then
                        pcall(function()
                            firetouchinterest(root, ball, 0)
                            firetouchinterest(root, ball, 1)
                        end)
                    end
                end
            end) else DConn("Magnet") end
        end })
    BallTab:CreateSlider({ Name = "Magnet Range", Range = {10,60}, Increment = 1, Suffix = " studs", CurrentValue = 30, Flag = "BLMagnetRangeFlag",
        Callback = function(v) S.MagnetRange = v end })

    -- PLAYER
    PlayerTab:CreateSection("Movement")
    PlayerTab:CreateToggle({ Name = "Speed Boost", CurrentValue = false, Flag = "BLSpeedFlag",
        Callback = function(v)
            S.SpeedBoost = v
            if v then S.Connections.Speed = RunService.RenderStepped:Connect(function()
                if not S.SpeedBoost then return end
                local root = Util.GetRoot()
                local hum = Util.GetHumanoid()
                if root and hum and hum.MoveDirection.Magnitude > 0 then
                    root.CFrame = root.CFrame + (hum.MoveDirection.Unit * (S.SpeedVal - 16) * 0.05)
                end
            end) else DConn("Speed") end
        end })
    PlayerTab:CreateSlider({ Name = "Speed Amount", Range = {16,50}, Increment = 1, Suffix = "", CurrentValue = 20, Flag = "BLSpeedValFlag",
        Callback = function(v) S.SpeedVal = v end })
    PlayerTab:CreateSection("Jump")
    PlayerTab:CreateToggle({ Name = "Custom JumpPower", CurrentValue = false, Flag = "BLJumpFlag",
        Callback = function(v)
            S.JumpPowerEnabled = v
            if v then S.Connections.Jump = RunService.RenderStepped:Connect(function() if S.JumpPowerEnabled then local h = Util.GetHumanoid(); if h then h.JumpPower = S.JumpPowerValue; h.UseJumpPower = true end end end)
            else DConn("Jump"); local h = Util.GetHumanoid(); if h then h.JumpPower = 50 end end
        end })
    PlayerTab:CreateSlider({ Name = "JumpPower Value", Range = {50,200}, Increment = 5, Suffix = "", CurrentValue = 80, Flag = "BLJumpValFlag",
        Callback = function(v) S.JumpPowerValue = v end })

    -- MISC
    MiscTab:CreateSection("Info")
    local ShootStatus = MiscTab:CreateLabel("Shoot remote: scanning...")
    task.spawn(function()
        task.wait(2)
        if ShootRemote then ShootStatus:Set("Shoot remote: FOUND") else ShootStatus:Set("Shoot remote: not found") end
    end)
    MiscTab:CreateButton({ Name = "Rescan Remotes/UI",
        Callback = function()
            FindShootRemote()
            FindShootingUI()
            if ShootRemote then ShootStatus:Set("Shoot remote: FOUND") else ShootStatus:Set("Shoot remote: not found") end
        end })
    MiscTab:CreateSection("Cleanup")
    MiscTab:CreateButton({ Name = "Destroy UI",
        Callback = function()
            for name, _ in pairs(S.Connections) do DConn(name) end
            S.AutoShoot=false; S.BallMagnet=false; S.AutoGuard=false; S.SpeedBoost=false; S.JumpPowerEnabled=false
            Window:Destroy()
        end })

    Rayfield:Notify({ Title = "OUTCOME HUB", Content = "Basketball Legends loaded", Duration = 3 })
end

-- LAUNCH
-- ══════════════════════════════════════════════════════════════
local HUB_SOURCE_URL = 'https://raw.githubusercontent.com/BraydenD5912/RobloxScripts/refs/heads/main/KeyboardEscapeHub.lua'

-- Fully re-execute the hub from scratch so never build tabs on a destroyed window.
local function Reload(gameName)
    _G.OutcomeGame = gameName
    pcall(function() Window:Destroy() end)
    loadstring(game:HttpGet(HUB_SOURCE_URL))()
end

local HomeBuilt = false
local function ShowHomeTab()
    if HomeBuilt then return end
    HomeBuilt = true
    local HomeTab = Window:CreateTab("Info", 4483362458)
    HomeTab:CreateSection("Game Not Detected")
    HomeTab:CreateLabel("Game: " .. tostring(game.Name))
    HomeTab:CreateLabel("PlaceId: " .. tostring(game.PlaceId))
    HomeTab:CreateButton({ Name = "Reload as Keyboard Escape", Callback = function() Reload("keyboardescape") end })
    HomeTab:CreateButton({ Name = "Reload as Basketball Legends", Callback = function() Reload("basketball") end })
end

local Launched = false
function LaunchGame()
    if Launched then return end
    Launched = true
    if GameName == "keyboardescape" then
        require_KeyboardEscape()
    elseif GameName == "basketball" then
        require_Basketball()
    else
        Launched = false
        ShowHomeTab()
    end
end

LaunchGame()

if not Launched then
    -- Async product-info fallback may resolve the game later; re-execute fresh.
    task.spawn(function()
        task.wait(3)
        if Launched then return end
        if GameName == "keyboardescape" or GameName == "basketball" then
            Reload(GameName)
        end
    end)
end

print("[OUTCOME HUB] Launched — " .. GameName)
