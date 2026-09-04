-- ══════════════════════════════════════════════════════════════
-- OUTCOME HUB — +1 Speed Keyboard Escape v4
-- Auto Farm | Auto Win | Auto Rebirth | Movement | ESP
-- v4 — cycle win 1→15, pooled ESP all types, humanized TP, throttled scans, file persist, FPS/ping, treadmill priority
-- ══════════════════════════════════════════════════════════════

local Rayfield = loadstring(game:HttpGet('https://raw.githubusercontent.com/SiriusSoftwareLtd/Rayfield/main/source.lua'))()

-- ══════════════════════════════════════════════════════════════
-- SERVICES
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
-- KNOWN COORDINATES (from game research)
-- ══════════════════════════════════════════════════════════════
-- ══════════════════════════════════════════════════════════════
-- STAGE WIN PAD COORDINATES (hardcoded from in-game)
-- ══════════════════════════════════════════════════════════════
local STAGE_CFAMES = {
    [1]  = CFrame.new(-16.488636, 6.8571434, 284.741302),
    [2]  = CFrame.new(-16.488636, 6.8571434, 506.733978),
    [3]  = CFrame.new(-16.488636, 75.1460419, 774.375122),
    [4]  = CFrame.new(-16.488636, 75.1460419, 1108.35461),
    [5]  = CFrame.new(-16.488636, 75.1460419, 1411.3446),
    [6]  = CFrame.new(-538.371643, 52.5018692, 1447.88953),
    [7]  = CFrame.new(-1007.7088, 52.5018692, 1447.88953),
    [8]  = CFrame.new(-1123.46582, 294.501862, 1447.88953),
    [9]  = nil, -- auto-learn: save in-game then Print Coords
    [10] = nil,
    [11] = nil,
    [12] = nil,
    [13] = nil,
    [14] = nil,
    [15] = nil,
}

local TREADMILL_CF = CFrame.new(18.0236549, 7.54272556, -40.5097961)

local WIN_COORDS = {
    World1 = Vector3.new(-14003.95, 750.54, 3066),
    World2 = Vector3.new(7984, 728, 5144),
    World3 = Vector3.new(7984, 1200, 5144),
}

-- Stage rewards for reference
local STAGE_REWARDS = {
    [1] = 1, [2] = 3, [3] = 10, [4] = 20, [5] = 60,
    [6] = 100, [7] = 150, [8] = 300, [9] = 500, [10] = 1000,
    [11] = 2500, [12] = 10000, [13] = 25000, [14] = 50000, [15] = 150000,
}

-- ══════════════════════════════════════════════════════════════
-- STATE
-- ══════════════════════════════════════════════════════════════
local State = {
    -- Auto Speed
    AutoSpeed = false,
    AutoSpeedDelay = 0.01,
    AutoSpeedMode = "Quad",

    -- Auto Win
    AutoWin = false,
    AutoWinCycle = false,
    AutoWinTween = false,
    AutoWinTweenSpeed = 0.5,
    AutoWinDelay = 3,

    -- Auto Rebirth
    AutoRebirth = false,
    AutoRebirthDelay = 1,

    -- Auto Treadmill
    AutoTreadmill = false,

    -- Auto Step (fires UpdateSpeed remote)
    AutoStep = false,
    AutoStepDelay = 0.1,

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
    TreadmillESP = false,

    -- Teleport
    ClickTP = false,

    -- Anti AFK
    AntiAFK = false,

    -- Connections
    Connections = {},
}

-- ══════════════════════════════════════════════════════════════
-- UTILITY
-- ══════════════════════════════════════════════════════════════
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

-- ══════════════════════════════════════════════════════════════
-- REMOTE SCANNER — find game remotes for speed/rebirth
-- ══════════════════════════════════════════════════════════════
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

-- Throttle helper (prevents GetDescendants spam)
local _lastScan = {}
local function Throttled(key, interval, fn) local now=os.clock(); if now - (_lastScan[key] or 0) < interval then return nil end; _lastScan[key]=now; return fn() end

-- ══════════════════════════════════════════════════════════════
-- WIN PAD DETECTION — dual mode: auto-scan OR manual coords
-- ══════════════════════════════════════════════════════════════
local WinPadCache = { pads = {}, lastScan = 0 }

local function FindWinPads(forceRescan)
    if not forceRescan and WinPadCache.pads and #WinPadCache.pads > 0
        and os.clock() - WinPadCache.lastScan < 4 then
        return WinPadCache.pads
    end

    local pads = {}
    local seen = {}

    local function scan(parent)
        for _, obj in ipairs(parent:GetChildren()) do
            if obj:IsA("BasePart") and not seen[obj] then
                local name = obj.Name:lower()
                local isWin = false
                -- Name-based detection
                if name:find("win") or name:find("trophy") or name:find("finish")
                    or name:find("end") or name:find("pad") or name:find("zone")
                    or name:find("button") or name:find("block") then
                    isWin = true
                end
                -- Color-based: bright yellow, flat pad
                local r, g, b = obj.Color.R, obj.Color.G, obj.Color.B
                if r > 0.85 and g > 0.85 and b < 0.3 then
                    isWin = true
                end
                -- Material-based: neon parts are often interactables
                if obj.Material == Enum.Material.Neon and r > 0.8 and g > 0.8 then
                    isWin = true
                end
                if isWin then
                    seen[obj] = true
                    table.insert(pads, obj)
                end
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
                    if r > 0.85 and g > 0.85 and b < 0.3 then
                        isWin = true
                    end
                    if primary.Material == Enum.Material.Neon and r > 0.8 and g > 0.8 then
                        isWin = true
                    end
                    if isWin then
                        seen[primary] = true
                        table.insert(pads, primary)
                    end
                end
                scan(obj)
            elseif obj:IsA("Folder") then
                scan(obj)
            end
        end
    end

    scan(Workspace)

    -- Also scan ScreenGui for WinButton references
    local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if playerGui then
        for _, gui in ipairs(playerGui:GetDescendants()) do
            if gui:IsA("GuiButton") then
                local gname = gui.Name:lower()
                local gtext = ""
                pcall(function() gtext = gui.Text:lower() end)
                if gname:find("win") or gtext:find("win") or gname:find("trophy") then
                    -- Mark as found but can't teleport to GUI element directly
                end
            end
        end
    end

    -- Sort by stage progression: World1 (low Y) -> World2 (mid) -> World3 (high)
    -- For 1-8: Y 6 -> 75 -> 52 -> 294, Z 284->1447, X -16->-1123
    -- For 9-15: group by Y first, then Z, then X to keep win pads in track order
    if #pads > 1 then
        -- Try to read stage number from Gui/Text if available (most accurate)
        local function GetStageNum(part)
            for _, obj in ipairs(part:GetDescendants()) do
                if obj:IsA("TextLabel") or obj:IsA("BillboardGui") then
                    local text = ""
                    pcall(function() text = obj.Text or "" end)
                    local num = text:match("Stage%s*(%d+)") or text:match("%D(%d+)%D") or obj.Name:match("%d+")
                    if num then return tonumber(num) end
                end
                if obj.Name:match("Stage") then
                    local num = obj.Name:match("%d+")
                    if num then return tonumber(num) end
                end
            end
            return nil
        end
        -- Check if any pad has stage number
        local hasStageNum = false
        for _, pad in ipairs(pads) do if GetStageNum(pad) then hasStageNum=true; break end end
        if hasStageNum then
            table.sort(pads, function(a,b)
                local na = GetStageNum(a) or 999
                local nb = GetStageNum(b) or 999
                if na ~= nb then return na < nb end
                return (a.Position.Y * 10000 + a.Position.Z) < (b.Position.Y * 10000 + b.Position.Z)
            end)
        else
            -- Fallback: spatial sort Y -> Z -> X (tracks are built sequentially)
            table.sort(pads, function(a,b)
                if math.abs(a.Position.Y - b.Position.Y) > 10 then
                    return a.Position.Y < b.Position.Y
                end
                if math.abs(a.Position.Z - b.Position.Z) > 10 then
                    return a.Position.Z < b.Position.Z
                end
                return a.Position.X < b.Position.X
            end)
        end
    end

    WinPadCache.pads = pads
    WinPadCache.lastScan = os.clock()
    return pads
end

local function GetWinPadByIndex(index)
    local pads = FindWinPads(true)
    if #pads == 0 then return nil end
    index = math.clamp(index, 1, #pads)
    return pads[index]
end

local function GetNearestWinPad()
    local pads = FindWinPads(true)
    if #pads == 0 then return nil end
    local root = GetRoot()
    if not root then return pads[1] end
    local nearest, nearestDist = nil, math.huge
    for _, pad in ipairs(pads) do
        if pad and pad.Parent then
            local dist = (root.Position - pad.Position).Magnitude
            if dist < nearestDist then
                nearestDist = dist
                nearest = pad
            end
        end
    end
    return nearest
end

-- ══════════════════════════════════════════════════════════════
-- TREADMILL SCANNER
-- ══════════════════════════════════════════════════════════════
local function FindTreadmills()
    local treadmills = {}
    local seen = {}

    local function scan(parent)
        for _, obj in ipairs(parent:GetChildren()) do
            local name = obj.Name:lower()
            if (name:find("treadmill") or name:find("tread") or name:find("training")
                or name:find("afk") or name:find("farm")) and not seen[obj] then
                seen[obj] = true
                if obj:IsA("BasePart") then
                    table.insert(treadmills, obj)
                elseif obj:IsA("Model") then
                    local primary = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
                    if primary then
                        table.insert(treadmills, primary)
                    end
                end
            end
            if obj:IsA("Model") or obj:IsA("Folder") then
                scan(obj)
            end
        end
    end

    scan(Workspace)

    -- Also check for parts with ProximityPrompts (treadmill activation)
    for _, prompt in ipairs(Workspace:GetDescendants()) do
        if prompt:IsA("ProximityPrompt") then
            local pName = prompt.ObjectText:lower()
            if pName:find("treadmill") or pName:find("train") then
                local parent = prompt.Parent
                if parent and parent:IsA("BasePart") and not seen[parent] then
                    seen[parent] = true
                    table.insert(treadmills, parent)
                end
            end
        end
    end

    return treadmills
end

local function GetBestTreadmill()
    local treads = FindTreadmills()
    if #treads == 0 then return nil end

    local root = GetRoot()
    if not root then return treads[1] end

    -- Prefer by name (Admin > Candy > Diamond > Gold > Normal)
    local priority = { admin = 5, candy = 4, diamond = 3, gold = 2, normal = 1 }

    local best = nil
    local bestPriority = -1

    for _, tread in ipairs(treads) do
        if tread and tread.Parent then
            local name = tread.Name:lower()
            local p = 1
            for key, val in pairs(priority) do
                if name:find(key) then
                    p = val
                    break
                end
            end
            if p > bestPriority then
                bestPriority = p
                best = tread
            end
        end
    end

    -- Fallback: closest
    if not best and #treads > 0 then
        local closest = nil
        local closestDist = math.huge
        for _, tread in ipairs(treads) do
            if tread and tread.Parent then
                local dist = (root.Position - tread.Position).Magnitude
                if dist < closestDist then
                    closestDist = dist
                    closest = tread
                end
            end
        end
        best = closest
    end

    return best
end

-- ══════════════════════════════════════════════════════════════
-- WINDOW
-- ══════════════════════════════════════════════════════════════
local Window = Rayfield:CreateWindow({
    Name = "OUTCOME HUB — Keyboard Escape v4",
    LoadingTitle = "+1 Speed Keyboard Escape",
    LoadingSubtitle = "v4 — cycle win, pooled ESP, humanized",
    ConfigurationSaving = { Enabled = false },
    Discord = { Enabled = false },
    KeySystem = false,
})

-- ══════════════════════════════════════════════════════════════
-- TABS
-- ══════════════════════════════════════════════════════════════
local FarmTab = Window:CreateTab("Auto Farm", 4483362458)
local MovementTab = Window:CreateTab("Movement", 4483362458)
local ESPTab = Window:CreateTab("ESP", 4483362458)
local TeleportTab = Window:CreateTab("Teleport", 4483362458)
local MiscTab = Window:CreateTab("Misc", 4483362458)

-- ══════════════════════════════════════════════════════════════
-- AUTO FARM TAB
-- ══════════════════════════════════════════════════════════════
FarmTab:CreateSection("Speed Farm")

FarmTab:CreateToggle({
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
                                CFrame.new(0, 0, -2-math.random()*0.5),
                                CFrame.new(0, 0, 2+math.random()*0.5),
                                CFrame.new(2+math.random()*0.5, 0, 0),
                                CFrame.new(-2-math.random()*0.5, 0, 0),
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
                            local d = 3 + math.random()*0.4
                            root.CFrame = root.CFrame * CFrame.new(0, 0, -d)
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
    Name = "Speed Delay",
    Range = {0.01, 0.5},
    Increment = 0.01,
    Suffix = "s",
    CurrentValue = 0.01,
    Flag = "SpeedDelayFlag",
    Callback = function(Value)
        State.AutoSpeedDelay = Value
    end,
})

-- ══════════════════════════════════════════════════════════════
FarmTab:CreateSection("Auto Step (Remote)")

FarmTab:CreateToggle({
    Name = "Auto Step (Fire UpdateSpeed)",
    CurrentValue = false,
    Flag = "AutoStepFlag",
    Callback = function(Value)
        State.AutoStep = Value
        if Value then
            task.spawn(function()
                while State.AutoStep do
                    if Remotes.UpdateSpeed then
                        pcall(function()
                            Remotes.UpdateSpeed:FireServer()
                        end)
                    end
                    task.wait(State.AutoStepDelay)
                end
            end)
        end
    end,
})

FarmTab:CreateSlider({
    Name = "Step Fire Rate",
    Range = {0.05, 1},
    Increment = 0.05,
    Suffix = "s",
    CurrentValue = 0.1,
    Flag = "StepDelayFlag",
    Callback = function(Value)
        State.AutoStepDelay = Value
    end,
})

-- ══════════════════════════════════════════════════════════════
FarmTab:CreateSection("Auto Win")

-- Saved coordinates per stage (user records them as they play)
local SavedStageCoords = {}
local SelectedStage = 1
pcall(function() if _G.OutcomeWinCoords then SavedStageCoords = _G.OutcomeWinCoords end end)
-- file persist if executor supports
pcall(function() if isfile and readfile and isfile("OutcomeHub_KE_Config.json") then local d=game:GetService("HttpService"):JSONDecode(readfile("OutcomeHub_KE_Config.json")); if d.winCoords then for k,v in pairs(d.winCoords) do if not SavedStageCoords[k] then SavedStageCoords[k]=Vector3.new(v.X or v[1], v.Y or v[2], v.Z or v[3]) end end end end end)

local function SaveCoordsForStage(stage, pos)
    SavedStageCoords[stage] = pos
    _G.OutcomeWinCoords = SavedStageCoords
    pcall(function() if writefile then writefile("OutcomeHub_KE_Config.json", game:GetService("HttpService"):JSONEncode({winCoords=SavedStageCoords})) end end)
    print(string.format("[KE] Saved stage %d: Vector3.new(%.2f, %.2f, %.2f)", stage, pos.X, pos.Y, pos.Z))
end

local function GetSavedCoord(stage)
    -- Hardcoded coords take priority
    if STAGE_CFAMES[stage] then
        return STAGE_CFAMES[stage].Position
    end
    -- Fallback to manually saved coords
    return SavedStageCoords[stage]
end

local function GetStageCFrame(stage)
    -- Returns full CFrame (position + rotation) for precise teleport
    if STAGE_CFAMES[stage] then
        return STAGE_CFAMES[stage]
    end
    local saved = SavedStageCoords[stage]
    if saved then
        return CFrame.new(saved)
    end
    return nil
end

local CoordStatus = FarmTab:CreateLabel("Coords saved: none yet")

local function RefreshCoordStatus()
    local count = 0
    for _ in pairs(SavedStageCoords) do count = count + 1 end
    CoordStatus:Set(string.format("Coords saved: %d / 15 stages", count))
end

RefreshCoordStatus()

FarmTab:CreateDropdown({
    Name = "Select Stage",
    Options = {"Stage 1", "Stage 2", "Stage 3", "Stage 4", "Stage 5", "Stage 6",
               "Stage 7", "Stage 8", "Stage 9", "Stage 10", "Stage 11", "Stage 12",
               "Stage 13", "Stage 14", "Stage 15"},
    CurrentOption = {"Stage 1"},
    Flag = "SelectedStageFlag",
    Callback = function(Option)
        local name = Option[1] or "Stage 1"
        local num = tonumber(name:match("%d+")) or 1
        SelectedStage = num
    end,
})

FarmTab:CreateButton({
    Name = "Save My Position as Stage Win Pad",
    Callback = function()
        local root = GetRoot()
        if root then
            SaveCoordsForStage(SelectedStage, root.Position)
            Rayfield:Notify({
                Title = "Position Saved",
                Content = string.format("Stage %d coords: %.0f, %.0f, %.0f", SelectedStage, root.Position.X, root.Position.Y, root.Position.Z),
                Duration = 4,
            })
            RefreshCoordStatus()
        end
    end,
})

FarmTab:CreateButton({
    Name = "Clear All Saved Coords",
    Callback = function()
        SavedStageCoords = {}
        _G.OutcomeWinCoords = SavedStageCoords
        pcall(function() if isfile and isfile("OutcomeHub_KE_Config.json") then delfile("OutcomeHub_KE_Config.json") end end)
        RefreshCoordStatus()
        Rayfield:Notify({ Title = "Cleared", Content = "All saved coordinates removed", Duration = 2 })
    end,
})
FarmTab:CreateButton({
    Name = "Print Stage Coords (copy for hardcode)",
    Callback = function()
        print("===== STAGE_CFAMES (copy this) =====")
        for i=1,15 do
            local cf = GetStageCFrame(i)
            local vec = SavedStageCoords[i] or (cf and cf.Position)
            if vec then
                print(string.format("    [%d]  = CFrame.new(%.6f, %.6f, %.6f),", i, vec.X, vec.Y, vec.Z))
            else
                print(string.format("    [%d]  = nil, -- not saved", i))
            end
        end
        pcall(function() print(game:GetService("HttpService"):JSONEncode(SavedStageCoords)) end)
        Rayfield:Notify({Title="Printed", Content="Check console (F9) for coords", Duration=3})
    end,
})

-- Also try auto-scan as fallback
FarmTab:CreateButton({
    Name = "Auto-Scan Win Pads (smart)",
    Callback = function()
        WinPadCache.pads = {}
        WinPadCache.lastScan = 0
        local pads = FindWinPads(true)
        local saved=0
        for i, pad in ipairs(pads) do
            if i <= 15 and not SavedStageCoords[i] then
                SaveCoordsForStage(i, pad.Position)
                saved=saved+1
                print(string.format("[SCAN] Stage %d -> %.1f, %.1f, %.1f (%s)", i, pad.Position.X, pad.Position.Y, pad.Position.Z, pad.Name))
            end
        end
        RefreshCoordStatus()
        Rayfield:Notify({
            Title = "Scan Complete",
            Content = string.format("Found %d pads, saved %d new", #pads, saved),
            Duration = 3,
        })
        if #pads < 15 then
            Rayfield:Notify({Title="Note", Content="Only "..#pads.." pads found - move near 9-15 and rescan or Save manually", Duration=5})
        end
    end,
})

FarmTab:CreateToggle({
    Name = "Auto Win (selected stage)",
    CurrentValue = false,
    Flag = "AutoWinFlag",
    Callback = function(Value)
        State.AutoWin = Value
        if Value then
            State.AutoWinCycle = false
            task.spawn(function()
                while State.AutoWin do
                    local root = GetRoot()
                        if root and IsAlive() then
                        local targetCF = GetStageCFrame(SelectedStage)

                        if not targetCF then
                            -- Fallback: try scanning for a pad near current position
                            local nearest = GetNearestWinPad()
                            if nearest then
                                targetCF = nearest.CFrame
                            end
                        end

                        if targetCF then
                            local humanized = (targetCF + Vector3.new(0, 3, 0)) * CFrame.new((math.random()-0.5)*2, 0, (math.random()-0.5)*2)
                            if State.AutoWinTween then
                                local tween = TweenService:Create(
                                    root,
                                    TweenInfo.new(State.AutoWinTweenSpeed + math.random()*0.15, Enum.EasingStyle.Linear),
                                    {CFrame = humanized}
                                )
                                tween:Play()
                                tween.Completed:Wait()
                            else
                                root.AssemblyLinearVelocity = Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
                                root.CFrame = humanized
                                task.wait(0.03 + math.random()*0.04)
                            end
                        end
                    end
                    task.wait(State.AutoWinDelay)
                end
            end)
        end
    end,
})

FarmTab:CreateToggle({
    Name = "Auto Win CYCLE (1→15 loop, best for wins farm)",
    CurrentValue = false,
    Flag = "AutoWinCycleFlag",
    Callback = function(Value)
        State.AutoWinCycle = Value
        if Value then
            State.AutoWin = false
            task.spawn(function()
                local cycle = SelectedStage
                while State.AutoWinCycle do
                    local root = GetRoot()
                    if root and IsAlive() then
                        local targetCF = GetStageCFrame(cycle)
                        if not targetCF then
                            local pads = FindWinPads(true)
                            if pads[cycle] then targetCF = pads[cycle].CFrame end
                            if not targetCF and #pads>0 then targetCF = pads[1].CFrame end
                        end
                        if targetCF then
                            local humanized = (targetCF + Vector3.new(0, 3, 0)) * CFrame.new((math.random()-0.5)*2, 0, (math.random()-0.5)*2)
                            if State.AutoWinTween then
                                local tween = TweenService:Create(root, TweenInfo.new(State.AutoWinTweenSpeed + math.random()*0.12, Enum.EasingStyle.Linear), {CFrame = humanized})
                                tween:Play(); tween.Completed:Wait()
                            else
                                root.AssemblyLinearVelocity = Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
                                root.CFrame = humanized
                                task.wait(0.03 + math.random()*0.04)
                            end
                            Rayfield:Notify({Title="Cycle Win", Content="Stage "..cycle.." -> "..((cycle%15)+1), Duration=1})
                        end
                    end
                    cycle = cycle + 1
                    if cycle > 15 then cycle = 1 end
                    task.wait(State.AutoWinDelay)
                end
            end)
        end
    end,
})

FarmTab:CreateToggle({
    Name = "Tween Mode (Smooth TP)",
    CurrentValue = false,
    Flag = "WinTweenFlag",
    Callback = function(Value)
        State.AutoWinTween = Value
    end,
})

FarmTab:CreateSlider({
    Name = "Tween Speed",
    Range = {0.1, 3},
    Increment = 0.1,
    Suffix = "s",
    CurrentValue = 0.5,
    Flag = "WinTweenSpeedFlag",
    Callback = function(Value)
        State.AutoWinTweenSpeed = Value
    end,
})

FarmTab:CreateSlider({
    Name = "Auto Win Delay (between TPs)",
    Range = {0.5, 10},
    Increment = 0.5,
    Suffix = "s",
    CurrentValue = 3,
    Flag = "WinDelayFlag",
    Callback = function(Value)
        State.AutoWinDelay = Value
    end,
})

-- ══════════════════════════════════════════════════════════════
FarmTab:CreateSection("Auto Rebirth")

local function ClickRebirth()
    -- Method 1: Fire remote
    if Remotes.Rebirth then
        pcall(function()
            Remotes.Rebirth:FireServer()
        end)
    end

    -- Method 2: Scan UI for rebirth button
    local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if playerGui then
        local function scanUI(parent)
            for _, obj in ipairs(parent:GetChildren()) do
                if obj:IsA("TextLabel") or obj:IsA("TextButton") then
                    local text = obj.Text:lower()
                    if text:find("rebirth") then
                        local button = obj:FindFirstAncestorOfClass("TextButton")
                            or obj:FindFirstAncestorOfClass("ImageButton")
                        if button then
                            pcall(function()
                                local pos = button.AbsolutePosition + button.AbsoluteSize / 2
                                VirtualUser:ClickButtonAt(Vector2.new(pos.X, pos.Y))
                            end)
                            return true
                        end
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
end

FarmTab:CreateToggle({
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
    Name = "Rebirth Delay",
    Range = {0.5, 10},
    Increment = 0.5,
    Suffix = "s",
    CurrentValue = 1,
    Flag = "RebirthDelayFlag",
    Callback = function(Value)
        State.AutoRebirthDelay = Value
    end,
})

-- ══════════════════════════════════════════════════════════════
FarmTab:CreateSection("Auto Treadmill")

FarmTab:CreateToggle({
    Name = "Auto Treadmill (AFK Farm)",
    CurrentValue = false,
    Flag = "AutoTreadmillFlag",
    Callback = function(Value)
        State.AutoTreadmill = Value
        if Value then
            task.spawn(function()
                while State.AutoTreadmill do
                    if State.AutoWin then break end
                    local root = GetRoot()
                    if root and IsAlive() then
                        -- Prefer hardcoded treadmill coords, else scan
                        local targetCF = TREADMILL_CF
                        if not targetCF then
                            local treadmill = GetBestTreadmill()
                            if treadmill then
                                targetCF = treadmill.CFrame
                            end
                        end
                        if targetCF then
                            root.CFrame = targetCF + Vector3.new(0, 3, 0)
                        end
                    end
                    task.wait(3)
                end
            end)
        end
    end,
})

-- ══════════════════════════════════════════════════════════════
-- MOVEMENT TAB
-- ══════════════════════════════════════════════════════════════
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

-- ══════════════════════════════════════════════════════════════
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
                if not State.NoClip then return end
                local char = GetCharacter()
                if not char then return end
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") and part.CanCollide then part.CanCollide = false end
                end
            end)
        else
            Disconnect("NoClip")
        end
    end,
})

-- ══════════════════════════════════════════════════════════════
-- ESP TAB
-- ══════════════════════════════════════════════════════════════
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
                    local pads = FindWinPads()
                    local existing={}; for _,e in ipairs(ESPObjects) do if e.Adornee then existing[e.Adornee]=true end end
                    for i, pad in ipairs(pads) do if pad and pad.Parent and not existing[pad] then CreateHighlight(pad, Color3.fromRGB(255, 255, 0), "WinPad"); CreateBillboard(pad, "WIN #" .. i, Color3.fromRGB(255, 255, 0)) end end
                    for i=#ESPObjects,1,-1 do local v=ESPObjects[i]; if not v or not v.Parent or (v.Adornee and not v.Adornee.Parent) then pcall(function() v:Destroy() end); table.remove(ESPObjects,i) end end
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
                    local existing={}; for _,e in ipairs(ESPObjects) do if e.Adornee then existing[e.Adornee]=true end end
                    for _, player in ipairs(Players:GetPlayers()) do
                        if player ~= LocalPlayer and player.Character and not existing[player.Character] then
                            local root = player.Character:FindFirstChild("HumanoidRootPart")
                            if root and not player.Character:FindFirstChild("OutcomeESP_Player") then
                                CreateHighlight(player.Character, Color3.fromRGB(255, 50, 50), "Player")
                                CreateBillboard(root, player.Name, Color3.fromRGB(255, 50, 50))
                            end
                        end
                    end
                    for i=#ESPObjects,1,-1 do local v=ESPObjects[i]; if not v or not v.Parent or (v.Adornee and not v.Adornee.Parent) then pcall(function() v:Destroy() end); table.remove(ESPObjects,i) end end
                    task.wait(2)
                end
            end)
        else
            ClearESP()
        end
    end,
})

ESPTab:CreateToggle({
    Name = "Treadmill ESP",
    CurrentValue = false,
    Flag = "TreadmillESPFlag",
    Callback = function(Value)
        State.TreadmillESP = Value
        if Value then
            task.spawn(function()
                while State.TreadmillESP do
                    local treads = FindTreadmills()
                    local existing={}; for _,e in ipairs(ESPObjects) do if e.Adornee then existing[e.Adornee]=true end end
                    for _, tread in ipairs(treads) do
                        if tread and tread.Parent and not existing[tread] then
                            CreateHighlight(tread, Color3.fromRGB(0, 200, 255), "Treadmill")
                            CreateBillboard(tread, tread.Name, Color3.fromRGB(0, 200, 255))
                        end
                    end
                    for i=#ESPObjects,1,-1 do local v=ESPObjects[i]; if not v or not v.Parent or (v.Adornee and not v.Adornee.Parent) then pcall(function() v:Destroy() end); table.remove(ESPObjects,i) end end
                    task.wait(3)
                end
            end)
        else
            ClearESP()
        end
    end,
})

-- ══════════════════════════════════════════════════════════════
-- TELEPORT TAB
-- ══════════════════════════════════════════════════════════════
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
                myRoot.CFrame = targetRoot.CFrame + Vector3.new(0, 3, 0)
            end
        end
    end,
})

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

TeleportTab:CreateSection("World Teleport")

TeleportTab:CreateButton({
    Name = "TP to World 1 Win Zone",
    Callback = function()
        local root = GetRoot()
        if root then
            root.CFrame = CFrame.new(WIN_COORDS.World1 + Vector3.new(0, 5, 0))
        end
    end,
})

TeleportTab:CreateButton({
    Name = "TP to World 2 Win Zone",
    Callback = function()
        local root = GetRoot()
        if root then
            root.CFrame = CFrame.new(WIN_COORDS.World2 + Vector3.new(0, 5, 0))
        end
    end,
})

TeleportTab:CreateButton({
    Name = "TP to World 3 Win Zone",
    Callback = function()
        local root = GetRoot()
        if root then
            root.CFrame = CFrame.new(WIN_COORDS.World3 + Vector3.new(0, 5, 0))
        end
    end,
})

TeleportTab:CreateSection("Stage Teleport")

TeleportTab:CreateLabel("Uses Stage Number from Auto Farm tab")

local LastTP_KE = nil
TeleportTab:CreateButton({
    Name = "TP to Selected Stage Win Pad",
    Callback = function()
        local r=GetRoot(); if r then LastTP_KE=r.CFrame end
        local coord = GetStageCFrame(SelectedStage)
        if coord then
            local root = GetRoot()
            if root then
                root.CFrame = (coord + Vector3.new(0, 3, 0)) * CFrame.new((math.random()-0.5)*1.5,0,(math.random()-0.5)*1.5)
            end
        else
            local pad = GetWinPadByIndex(SelectedStage)
            if pad then
                local root = GetRoot()
                if root then
                    root.CFrame = pad.CFrame + Vector3.new(0, 3, 0)
                end
            else
                Rayfield:Notify({
                    Title = "No Coords",
                    Content = "No saved coords for stage " .. SelectedStage .. ". Save one in Auto Farm tab.",
                    Duration = 4,
                })
            end
        end
    end,
})
TeleportTab:CreateButton({ Name = "Undo Last TP", Callback = function() local r=GetRoot(); if r and LastTP_KE then r.CFrame=LastTP_KE end end })

TeleportTab:CreateButton({
    Name = "TP to Nearest Win Pad",
    Callback = function()
        local pad = GetNearestWinPad()
        if pad then
            local root = GetRoot()
            if root then
                root.CFrame = pad.CFrame + Vector3.new(0, 3, 0)
            end
        end
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

-- ══════════════════════════════════════════════════════════════
-- MISC TAB
-- ══════════════════════════════════════════════════════════════
MiscTab:CreateSection("Position Tracker")

local PosLabelX = MiscTab:CreateLabel("X: 0")
local PosLabelY = MiscTab:CreateLabel("Y: 0")
local PosLabelZ = MiscTab:CreateLabel("Z: 0")
local FPSLabel = MiscTab:CreateLabel("FPS: --")
do local lastTick=os.clock(); local fc=0; RunService.RenderStepped:Connect(function() fc = fc + 1; if os.clock()-lastTick>=1 then local fps=math.floor(fc/(os.clock()-lastTick)); fc=0; lastTick=os.clock(); local ping="--"; pcall(function() ping=tostring(math.floor(game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue())).."ms" end); FPSLabel:Set(string.format("FPS: %d | Ping: %s", fps, ping)) end end) end

State.Connections.PosTracker = RunService.Heartbeat:Connect(function()
    local root = GetRoot()
    if root then
        local pos = root.Position
        PosLabelX:Set(string.format("X: %.1f", pos.X))
        PosLabelY:Set(string.format("Y: %.1f", pos.Y))
        PosLabelZ:Set(string.format("Z: %.1f", pos.Z))
    end
end)

MiscTab:CreateSection("Remote Info")

local RemoteLabel = MiscTab:CreateLabel("Remotes: scanning...")
task.spawn(function()
    task.wait(2)
    local info = {}
    if Remotes.UpdateSpeed then table.insert(info, "UpdateSpeed") end
    if Remotes.Rebirth then table.insert(info, "Rebirth") end
    if Remotes.Win then table.insert(info, "Win") end
    if Remotes.Teleport then table.insert(info, "Teleport") end
    if #info == 0 then
        RemoteLabel:Set("Remotes: none found")
    else
        RemoteLabel:Set("Remotes: " .. table.concat(info, ", "))
    end
end)

MiscTab:CreateButton({
    Name = "Rescan Remotes",
    Callback = function()
        Remotes = {}
        ScanRemotes()
        local info = {}
        if Remotes.UpdateSpeed then table.insert(info, "UpdateSpeed") end
        if Remotes.Rebirth then table.insert(info, "Rebirth") end
        if Remotes.Win then table.insert(info, "Win") end
        if Remotes.Teleport then table.insert(info, "Teleport") end
        if #info == 0 then
            RemoteLabel:Set("Remotes: none found")
        else
            RemoteLabel:Set("Remotes: " .. table.concat(info, ", "))
        end
    end,
})

MiscTab:CreateSection("Anti AFK")

MiscTab:CreateToggle({
    Name = "Anti AFK",
    CurrentValue = false,
    Flag = "AntiAFKFlag",
    Callback = function(Value)
        State.AntiAFK = Value
        if Value then
            State.Connections.AntiAFK = LocalPlayer.Idled:Connect(function() task.wait(math.random()*1.2); pcall(function() VirtualUser:CaptureController(); VirtualUser:ClickButton2(Vector2.new(math.random(100,700), math.random(100,400))) end) end)
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
        State.AutoWinCycle = false
        State.AutoRebirth = false
        State.AutoTreadmill = false
        State.AutoStep = false
        State.FlyEnabled = false
        State.NoClip = false
        State.InfiniteJump = false
        State.WalkSpeedEnabled = false
        State.JumpPowerEnabled = false
        State.ClickTP = false
        State.AntiAFK = false
        State.WinPadESP = false
        State.PlayerESP = false
        State.TreadmillESP = false
        Window:Destroy()
    end,
})

-- ══════════════════════════════════════════════════════════════
-- CORE LOOPS
-- ══════════════════════════════════════════════════════════════
RunService.RenderStepped:Connect(function()
    local hum = GetHumanoid()
    if not hum then return end

    if State.WalkSpeedEnabled then
        local jitter = (math.random() - 0.5) * 0.6
        hum.WalkSpeed = State.WalkSpeedValue + jitter
    end

    if State.JumpPowerEnabled then
        hum.JumpPower = State.JumpPowerValue
        hum.UseJumpPower = true
    end
end)

-- Auto-refresh player list
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

-- ══════════════════════════════════════════════════════════════
-- TOAST
-- ══════════════════════════════════════════════════════════════
Rayfield:Notify({
    Title = "OUTCOME HUB v4",
    Content = "Keyboard Escape v4 — cycle win, pooled ESP, humanized",
    Duration = 4,
})

print("[OUTCOME HUB] v2 Loaded — +1 Speed Keyboard Escape")
