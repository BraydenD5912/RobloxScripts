-- ══════════════════════════════════════════════════════════════
-- OUTCOME HUB — Multi-Game Roblox Hub v3 (improved)
-- Auto-detects the game and loads the right module
-- Games: +1 Speed Keyboard Escape | Basketball Legends | Sniper Duels | Hypershot | Blox Fruits | Runaways | Clean The Leaves | Adopt Me | [FPS] One Tap
-- Improvements: throttled scans, ESP pooling, reversible WhiteScreen, lazy Fly/NoClip, visibility-checked aimbot, humanized jitter
-- ══════════════════════════════════════════════════════════════

local Rayfield = loadstring(game:HttpGet('https://raw.githubusercontent.com/SiriusSoftwareLtd/Rayfield/main/source.lua'))()
print("[OUTCOME HUB] v3 step 1: Rayfield loaded (perf: throttled scans, pooled ESP, jittered waits)")

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

-- Throttle helper to reduce GetDescendants spam
Util._lastScan = {}
function Util.Throttled(key, intervalSec, fn)
    local now = os.clock()
    local last = Util._lastScan[key] or 0
    if now - last < intervalSec then return nil end
    Util._lastScan[key] = now
    return fn()
end

-- ESP pooling: track created highlights to avoid flicker/leak
Util._espPool = {}
function Util.ClearESP(pool)
    for _, v in ipairs(pool) do pcall(function() v:Destroy() end) end
    table.clear(pool)
end

-- Unified "is this input currently held?" for both keyboard keys and mouse buttons.
-- AimKey stores a token string (e.g. "LMouse","RMouse","X",...). Returns KeyCode or nil.
function Util.ResolveInput(token)
    if not token then return nil end
    local mouse = {
        ["LMouse"] = Enum.UserInputType.MouseButton1,
        ["RMouse"] = Enum.UserInputType.MouseButton2,
        ["MMouse"] = Enum.UserInputType.MouseButton3,
        ["MB4"]    = Enum.UserInputType.MouseButton4,
        ["MB5"]    = Enum.UserInputType.MouseButton5,
    }
    if mouse[token] then return mouse[token] end
    -- otherwise it's a keyboard KeyCode token
    local kc = Enum.KeyCode[token]
    if kc then return kc end
    return nil
end

function Util.IsHeld(token)
    local inp = Util.ResolveInput(token)
    if not inp then return false end
    local inpType = typeof(inp)
    if inpType == "EnumItem" and inp.EnumType == Enum.KeyCode then
        return UserInputService:IsKeyDown(inp)
    elseif inpType == "EnumItem" and inp.EnumType == Enum.UserInputType then
        return UserInputService:IsMouseButtonPressed(inp)
    end
    return false
end

-- Config persistence (executor file IO if available)
Util.ConfigFile = "OutcomeHub_Config.json"
function Util.SaveConfig(tbl)
    if not writefile then return end
    pcall(function() writefile(Util.ConfigFile, game:GetService("HttpService"):JSONEncode(tbl)) end)
end
function Util.LoadConfig()
    if not readfile or not isfile or not isfile(Util.ConfigFile) then return {} end
    local ok, data = pcall(function() return game:GetService("HttpService"):JSONDecode(readfile(Util.ConfigFile)) end)
    if ok and type(data)=="table" then return data end
    return {}
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
    ["109397169461300"]= "sniper",         -- Sniper Duels
    ["17516596118"]    = "hypershot",      -- Hypershot (place)
    ["5995470825"]     = "hypershot",      -- Hypershot (universe)
    ["2753915549"]     = "bloxfruits",     -- Blox Fruits (main)
    ["4442272183"]     = "bloxfruits",     -- Blox Fruits (second place)
    ["7449423635"]     = "bloxfruits",     -- Blox Fruits (third place)
    ["14282329183"]    = "runaways",       -- Runaways (beta)
    ["920587237"]      = "adoptme",        -- Adopt Me (classic)
    ["603519598"]      = "adoptme",        -- Adopt Me (new)
    ["14600811883"]    = "adoptme",        -- Adopt Me (private server)
    ["90568084448279"] = "onetap",         -- [FPS] One Tap (main)
    ["90568084448280"] = "onetap",         -- [FPS] One Tap (pro servers var)
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
    elseif pn:find("sniper") and pn:find("duel") then
        GameName = "sniper"
    elseif pn:find("hypershot") then
        GameName = "hypershot"
    elseif pn:find("blox") and pn:find("fruit") then
        GameName = "bloxfruits"
    elseif pn:find("runaways") then
        GameName = "runaways"
    elseif pn:find("leaf") or pn:find("rake") or pn:find("yard") or (pn:find("clean") and pn:find("leaf")) then
        GameName = "cleanleaves"
    elseif pn:find("adopt") then
        GameName = "adoptme"
    elseif pn:find("one") and pn:find("tap") then
        GameName = "onetap"
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
        elseif n:find("sniper") and n:find("duel") then
            GameName = "sniper"
        elseif n:find("hypershot") then
            GameName = "hypershot"
        elseif n:find("blox") and n:find("fruit") then
            GameName = "bloxfruits"
        elseif n:find("runaways") then
            GameName = "runaways"
        elseif n:find("leaf") or n:find("rake") or n:find("yard") or (n:find("clean") and n:find("leaf")) then
            GameName = "cleanleaves"
        elseif n:find("adopt") then
            GameName = "adoptme"
        elseif n:find("one") and n:find("tap") then
            GameName = "onetap"
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
    Name = "OUTCOME HUB v3",
    LoadingTitle = "Multi-Game Hub v3",
    LoadingSubtitle = (GameName == "keyboardescape" and "+1 Speed Keyboard Escape")
        or (GameName == "basketball" and "Basketball Legends")
        or (GameName == "sniper" and "Sniper Duels")
        or (GameName == "hypershot" and "Hypershot")
        or (GameName == "bloxfruits" and "Blox Fruits")
        or (GameName == "runaways" and "Runaways (Beta)")
        or (GameName == "cleanleaves" and "Clean The Leaves")
        or (GameName == "adoptme" and "Adopt Me")
        or (GameName == "onetap" and "[FPS] One Tap")
        or "Game: " .. tostring(game.Name),
    ConfigurationSaving = { Enabled = false },
    Discord = { Enabled = false },
    KeySystem = false,
})
print("[OUTCOME HUB] step 2: Window created — GameName=" .. GameName)

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
        -- 9-15 auto-learn via SavedStageCoords + win-pad scan (no hardcoded coords yet)
        [9]  = nil, [10] = nil, [11] = nil, [12] = nil, [13] = nil, [14] = nil, [15] = nil,
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

    -- Saved per-stage coords (user + auto) with file persist
    local SavedStageCoords = {}
    local SelectedStage = 1
    pcall(function() if _G.OutcomeWinCoords then SavedStageCoords = _G.OutcomeWinCoords end end)
    pcall(function()
        local cfg = Util.LoadConfig()
        if cfg.winCoords then for k,v in pairs(cfg.winCoords) do if not SavedStageCoords[k] then SavedStageCoords[k]=Vector3.new(v.X or v[1], v.Y or v[2], v.Z or v[3]) end end end
    end)

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
                            for _, dir in ipairs({CFrame.new(0,0,-2-math.random()*0.5),CFrame.new(0,0,2+math.random()*0.5),CFrame.new(2+math.random()*0.5,0,0),CFrame.new(-2-math.random()*0.5,0,0)}) do
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

    FarmTab:CreateButton({ Name = "Save My Position as Stage Win Pad (also persists)",
        Callback = function()
            local root = Util.GetRoot()
            if root then
                SaveCoordsForStage(SelectedStage, root.Position)
                -- persist via file if possible
                pcall(function() Util.SaveConfig({winCoords = SavedStageCoords}) end)
                Rayfield:Notify({ Title = "Position Saved", Content = string.format("Stage %d: %.0f, %.0f, %.0f (saved)", SelectedStage, root.Position.X, root.Position.Y, root.Position.Z), Duration = 4 })
                RefreshCoordStatus(CoordStatus, SavedStageCoords)
                print(string.format("[OUTCOME] Saved stage %d: Vector3.new(%.2f, %.2f, %.2f)", SelectedStage, root.Position.X, root.Position.Y, root.Position.Z))
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
                            if nearest then targetCF = nearest.CFrame end
                        end
                        if targetCF then
                            local tp = targetCF + Vector3.new(0,3,0)
                            -- humanized TP: random 1-2 stud offset inside pad, preserve velocity check
                            local humanized = tp * CFrame.new((math.random()-0.5)*2, 0, (math.random()-0.5)*2)
                            if S.AutoWinTween then
                                local tw = TweenService:Create(root, TweenInfo.new(S.AutoWinTweenSpeed + math.random()*0.15, Enum.EasingStyle.Linear), {CFrame = humanized})
                                tw:Play(); tw.Completed:Wait()
                            else
                                -- even non-tween: add 1 tick delay and small lerp to look like walk
                                root.AssemblyLinearVelocity = Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
                                root.CFrame = humanized
                                task.wait(0.03 + math.random()*0.04)
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
            if v then S.Connections.NoClip = RunService.Stepped:Connect(function() if not S.NoClip then return end; local c = Util.GetCharacter(); if not c then return end; for _, p in ipairs(c:GetDescendants()) do if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false end end end)
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
                    -- dedup: only add missing highlights
                    local pads = FindWinPads(true)
                    local existing = {}; for _,e in ipairs(ESPObjects) do if e.Adornee then existing[e.Adornee]=true end end
                    for i, p in ipairs(pads) do if p and p.Parent and not existing[p] then MkHighlight(p, Color3.fromRGB(255,255,0), "WinPad"); MkLabel(p, "WIN #"..i, Color3.fromRGB(255,255,0)) end end
                    -- prune stale
                    for i=#ESPObjects,1,-1 do local v=ESPObjects[i]; if not v or not v.Parent or (v.Adornee and not v.Adornee.Parent) then pcall(function() v:Destroy() end); table.remove(ESPObjects,i) end end
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
                        if pl ~= LocalPlayer and pl.Character and not ESPObjects[pl] then
                            local r = pl.Character:FindFirstChild("HumanoidRootPart")
                            if r and not pl.Character:FindFirstChild("OH_PlayerESP") then MkHighlight(pl.Character, Color3.fromRGB(255,50,50), "Player"); MkLabel(r, pl.Name, Color3.fromRGB(255,50,50)) end
                        end
                    end
                    -- prune stale player ESP
                    for i=#ESPObjects,1,-1 do local v=ESPObjects[i]; if v and v.Adornee and not v.Adornee.Parent then pcall(function() v:Destroy() end); table.remove(ESPObjects,i) end end
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
                    local existing = {}; for _,e in ipairs(ESPObjects) do if e.Adornee then existing[e.Adornee]=true end end
                    for _, t in ipairs(treads) do if t and t.Parent and not existing[t] then MkHighlight(t, Color3.fromRGB(0,200,255), "Tread"); MkLabel(t, t.Name, Color3.fromRGB(0,200,255)) end end
                    for i=#ESPObjects,1,-1 do local v=ESPObjects[i]; if not v or not v.Parent or (v.Adornee and not v.Adornee.Parent) then pcall(function() v:Destroy() end); table.remove(ESPObjects,i) end end
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
    local LastTP = nil
    TeleportTab:CreateButton({ Name = "TP to Selected Stage Win Pad",
        Callback = function()
            local root = Util.GetRoot(); if root then LastTP = root.CFrame end
            local cf = GetStageCFrame(SelectedStage)
            if cf then local root2 = Util.GetRoot(); if root2 then root2.CFrame = cf + Vector3.new(0,3,0) end
            else
                local pad = FindWinPads(true)[SelectedStage]
                if pad then local root2 = Util.GetRoot(); if root2 then root2.CFrame = pad.CFrame + Vector3.new(0,3,0) end
                else Rayfield:Notify({Title="No Coords",Content="No saved coords for stage "..SelectedStage..". Save one in Auto Farm.",Duration=4}) end
            end
        end })
    TeleportTab:CreateButton({ Name = "Undo Last TP", Callback = function() local r=Util.GetRoot(); if r and LastTP then r.CFrame = LastTP end end })
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
    local FPSLabel = MiscTab:CreateLabel("FPS: -- | Ping: --")
    do
        local lastTick = os.clock()
        local frameCount = 0
        RunService.RenderStepped:Connect(function()
            frameCount = frameCount + 1
            if os.clock() - lastTick >= 1 then
                local fps = math.floor(frameCount / (os.clock() - lastTick))
                frameCount = 0; lastTick = os.clock()
                local ping = "--"
                pcall(function() ping = tostring(math.floor(game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue())) .. "ms" end)
                FPSLabel:Set(string.format("FPS: %d | Ping: %s", fps, ping))
            end
        end)
    end
    S.Connections.PosTracker = RunService.Heartbeat:Connect(function()
        local root = Util.GetRoot()
        if root then local p = root.Position; LX:Set(string.format("X: %.1f", p.X)); LY:Set(string.format("Y: %.1f", p.Y)); LZ:Set(string.format("Z: %.1f", p.Z)) end
    end)

    MiscTab:CreateSection("Anti AFK")
    MiscTab:CreateToggle({ Name = "Anti AFK", CurrentValue = false, Flag = "KEAntiAFKFlag",
        Callback = function(v)
            S.AntiAFK = v
            if v then S.Connections.AntiAFK = LocalPlayer.Idled:Connect(function() task.wait(math.random()*1.2); pcall(function() VirtualUser:CaptureController(); VirtualUser:ClickButton2(Vector2.new(math.random(100,700), math.random(100,400))) end) end)
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
        if S.WalkSpeedEnabled then
            -- jitter +/- 0.3 to avoid constant flag
            local jitter = (math.random() - 0.5) * 0.6
            h.WalkSpeed = S.WalkSpeedValue + jitter
        end
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
        PerfectShot = false, -- new: force perfect green via meter reading
        BallMagnet = false, MagnetRange = 30,
        AutoGuard = false, AutoGuardHold = false,
        SpeedBoost = false, SpeedVal = 20,
        AutoShootOnRelease = false,
        Connections = {},
    }

    local function DConn(name)
        if S.Connections[name] then pcall(function() S.Connections[name]:Disconnect() end); S.Connections[name] = nil end
    end

    -- Locate shooting remote + shooting UI element
    local ShootRemote
    local ShootingUI
    local MeterFill = nil
    local MeterBackground = nil
    local GreenZone = nil

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
        if ShootingUI then
            -- Find meter components
            for _, obj in ipairs(ShootingUI:GetDescendants()) do
                local name = obj.Name:lower()
                if (name:find("fill") or name:find("meter") or name:find("bar")) and obj:IsA("Frame") then
                    if not MeterFill then MeterFill = obj end
                elseif (name:find("bg") or name:find("back") or name:find("track")) and obj:IsA("Frame") then
                    if not MeterBackground then MeterBackground = obj end
                elseif (name:find("green") or name:find("perfect") or name:find("sweet")) and obj:IsA("Frame") then
                    if not GreenZone then GreenZone = obj end
                end
            end
            -- Fallback: assume first Frame child is fill, second is background
            if not MeterFill or not MeterBackground then
                local frames = {}
                for _, obj in ipairs(ShootingUI:GetDescendants()) do
                    if obj:IsA("Frame") and obj ~= ShootingUI then
                        table.insert(frames, obj)
                    end
                end
                if #frames >= 2 then
                    MeterFill = frames[1]
                    MeterBackground = frames[2]
                end
            end
        end
    end

    FindShootRemote()
    FindShootingUI()

    -- Ball finder
    local function FindBasketball()
        local ok, res = pcall(function()
            for _, obj in ipairs(Workspace:GetDescendants()) do
                if obj.Name == "Basketball" and obj:IsA("BasePart") then return obj end
            end
            return nil
        end)
        if ok then return res end
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

    -- Perfect shot detection: check if meter fill is in green zone
    local function IsMeterInGreen()
        if not MeterFill or not MeterBackground then return false end
        if not MeterFill.Visible or not MeterBackground.Visible then return false end
        
        local fillPos = MeterFill.AbsolutePosition.X
        local fillSize = MeterFill.AbsoluteSize.X
        local bgPos = MeterBackground.AbsolutePosition.X
        local bgSize = MeterBackground.AbsoluteSize.X
        
        local fillCenter = fillPos + fillSize / 2
        local bgCenter = bgPos + bgSize / 2
        
        -- If GreenZone exists, use it; otherwise assume center 20% is green
        if GreenZone and GreenZone.Visible then
            local gzPos = GreenZone.AbsolutePosition.X
            local gzSize = GreenZone.AbsoluteSize.X
            return fillCenter >= gzPos and fillCenter <= gzPos + gzSize
        else
            -- Center 20% of background = green zone
            local greenLeft = bgCenter - bgSize * 0.1
            local greenRight = bgCenter + bgSize * 0.1
            return fillCenter >= greenLeft and fillCenter <= greenRight
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
    MainTab:CreateToggle({ Name = "Auto Green Shot (Legit)", CurrentValue = false, Flag = "BLAutoGreenFlag",
        Callback = function(v)
            S.AutoShoot = v
            if v then
                local lastShot = 0
                S.Connections.AutoShoot = RunService.Heartbeat:Connect(function()
                    if not S.AutoShoot then return end
                    if not ShootingUI or not ShootingUI.Visible then return end
                    if os.clock() - lastShot < S.ShotDelay then return end
                    if S.PerfectShot then
                        if not IsMeterInGreen() then return end
                    end
                    lastShot = os.clock()
                    FireShoot()
                end)
            else
                DConn("AutoShoot")
            end
        end })
    MainTab:CreateToggle({ Name = "Perfect Shot Mode (Read Meter)", CurrentValue = false, Flag = "BLPerfectShotFlag",
        Callback = function(v)
            S.PerfectShot = v
            if v then
                -- Rescan UI to find meter components
                task.spawn(function()
                    task.wait(0.5)
                    FindShootingUI()
                end)
            end
        end })
    MainTab:CreateSlider({ Name = "Shot Power %", Range = {50,100}, Increment = 1, Suffix = "%", CurrentValue = 100, Flag = "BLShotPowerFlag",
        Callback = function(v) S.ShotPower = v / 100 end })
    MainTab:CreateSlider({ Name = "Release Delay (s)", Range = {0,1}, Increment = 0.05, Suffix = "s", CurrentValue = 0.25, Flag = "BLShotDelayFlag",
        Callback = function(v) S.ShotDelay = v end })
    MainTab:CreateButton({ Name = "Rescan Shot Meter UI", Callback = function() FindShootingUI() end })

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

-- ══════════════════════════════════════════════════════════════
-- GAME MODULE: SNIPER DUELS
-- ══════════════════════════════════════════════════════════════
function require_Sniper()
    local S = {
        Aimbot = false, AimFOV = 20, AimTeam = true,
        AimConfig = "Legit", -- "Legit" or "Rage"
        AimHitbox = "Head",
        AimKey = "LMouse", -- token for the input held to drive aimbot (see Util.ResolveInput)
        LegitSmooth = 0.25, LegitOffset = 0.6, -- offset in studs (humanized miss window)
        Triggerbot = false,
        ESP = false, ESPTeamOnly = true,
        WalkSpeedEnabled = false, WalkSpeedValue = 40,
        InfiniteJump = false, NoClip = false, FlyEnabled = false, FlySpeed = 50,
        AutoQueue = false, AutoReady = false,
        AutoShoot = false,
        AntiAFK = false,
        Connections = {},
    }

    local function DConn(name)
        if S.Connections[name] then S.Connections[name]:Disconnect(); S.Connections[name] = nil end
    end

    -- Team handling
    local function IsEnemy(pl)
        if pl == LocalPlayer then return false end
        if not pl.Character then return false end
        local Teams = game:GetService("Teams")
        local t1 = pl.Team
        local t0 = LocalPlayer.Team
        if t1 and t0 then
            return t1 ~= t0
        end
        -- No team info (or ffa) -> treat everyone as enemy
        return true
    end

    local function GetCameraTargetList()
        local out = {}
        for _, pl in ipairs(Players:GetPlayers()) do
            if pl ~= LocalPlayer and pl.Character then
                local hrp = pl.Character:FindFirstChild("HumanoidRootPart")
                local hum = pl.Character:FindFirstChildOfClass("Humanoid")
                if hrp and hum and hum.Health > 0 then
                    if not (S.AimTeam and not IsEnemy(pl)) then
                        table.insert(out, { pl = pl, hrp = hrp, char = pl.Character })
                    end
                end
            end
        end
        return out
    end

    -- Where on the target to aim
    local function GetTargetPoint(char, hrp)
        local part
        if S.AimHitbox == "Head" then
            part = char:FindFirstChild("Head")
        elseif S.AimHitbox == "Body" then
            part = char:FindFirstChild("HumanoidRootPart") or hrp
        else
            part = char:FindFirstChild("HumanoidRootPart") or hrp
        end
        if part then
            return part.Position + Vector3.new(0, (S.AimHitbox == "Head" and 0.3) or 0, 0)
        end
        return hrp.Position + Vector3.new(0, 2, 0)
    end

    local function IsVisible(from, to, ignoreList)
        local params = RaycastParams.new()
        params.FilterDescendantsInstances = ignoreList or {LocalPlayer.Character, Camera}
        params.FilterType = Enum.RaycastFilterType.Exclude
        local dir = to - from
        local result = Workspace:Raycast(from, dir, params)
        if not result then return true end
        -- if hit is part of target character, it's visible
        for _, pl in ipairs(Players:GetPlayers()) do
            if pl.Character and result.Instance:IsDescendantOf(pl.Character) then return true end
        end
        return result.Instance == nil
    end

    -- Choose closest valid target within FOV
    local function PickTarget(camPos, look, fov)
        local targets = GetCameraTargetList()
        local best, bd = nil, fov
        for _, t in ipairs(targets) do
            local pos = GetTargetPoint(t.char, t.hrp)
            local dir = (pos - camPos)
            if dir.Magnitude < 0.01 then dir = Vector3.new(0, 0, 0.01) end
            local ang = math.deg(math.acos(math.clamp(dir.Unit:Dot(look), -1, 1)))
            if ang <= bd and (S.AimConfig == "Rage" or IsVisible(camPos, pos, {LocalPlayer.Character})) then
                bd = ang
                best = { pos = pos, t = t }
            end
        end
        return best
    end

    -- Move mouse toward a world position (works in first-person FPS by feeding the
    -- game's own camera controller mouse deltas).
    local hasMMRel = (mousemoverel ~= nil)
    local hasMMAabs = (mousemoveabs ~= nil)

    -- FOV Circle UI (if Drawing lib available)
    local FOVCircle = nil
    pcall(function()
        if Drawing then
            FOVCircle = Drawing.new("Circle")
            FOVCircle.Visible = false
            FOVCircle.Radius = 120
            FOVCircle.Color = Color3.fromRGB(255,255,255)
            FOVCircle.Thickness = 1.2
            FOVCircle.Transparency = 0.7
            FOVCircle.Filled = false
            FOVCircle.NumSides = 64
            RunService.RenderStepped:Connect(function()
                if not S.Aimbot or S.AimConfig ~= "Legit" then FOVCircle.Visible=false; return end
                local cam = workspace.CurrentCamera
                if not cam then return end
                FOVCircle.Visible = true
                FOVCircle.Position = Vector2.new(cam.ViewportSize.X/2, cam.ViewportSize.Y/2)
                -- FOV deg to pixel radius approximation
                FOVCircle.Radius = math.clamp(S.AimFOV * 5, 30, 400)
            end)
        end
    end)

    -- Aimbot loop with Legit/Rage configs
    local function AimbotLoop()
        while S.Aimbot do
            task.wait()
            if not S.Aimbot then break end
            local cam = Camera
            if not cam then break end
            local firing = Util.IsHeld(S.AimKey) or S.Triggerbot
            if firing then
                local fov = (S.AimConfig == "Rage") and 360 or S.AimFOV
                local camPos, camLook = cam.CFrame.Position, cam.CFrame.LookVector
                local best = PickTarget(camPos, camLook, fov)

                if best then
                    local aimPos = best.pos
                    if S.AimConfig == "Rage" then
                        -- instant hard snap to target
                        local sp = cam:WorldToScreenPoint(aimPos)
                        if sp.Z >= 0 then
                            if hasMMRel then
                                local mp = UserInputService:GetMouseLocation()
                                mousemoverel(sp.X - mp.X, sp.Y - mp.Y)
                            elseif hasMMAabs then
                                mousemoveabs(sp.X, sp.Y)
                            else
                                cam.CFrame = CFrame.lookAt(camPos, aimPos)
                            end
                        end
                    else
                        -- Legit: aim slightly off-center (human miss window) + smooth
                        -- humanized miss: screen-space jitter with damping over distance
                        local distFactor = math.clamp((best.pos - camPos).Magnitude / 200, 0, 1)
                        local jitterScale = S.LegitOffset * (0.5 + distFactor * 0.5)
                        aimPos = best.pos + Vector3.new(
                            (math.random() - 0.5) * jitterScale,
                            (math.random() - 0.5) * jitterScale, 0)
                        local sp = cam:WorldToScreenPoint(aimPos)
                        if sp.Z >= 0 and (hasMMRel or hasMMAabs) then
                            local mp = UserInputService:GetMouseLocation()
                            local t = math.clamp(S.LegitSmooth, 0.05, 1)
                            local mdx, mdy = (sp.X - mp.X) * t, (sp.Y - mp.Y) * t
                            if hasMMRel then
                                mousemoverel(mdx, mdy)
                            else
                                mousemoveabs(sp.X, sp.Y)
                            end
                        else
                            local newLook = CFrame.lookAt(camPos, aimPos)
                            local t = math.clamp(S.LegitSmooth, 0.05, 1)
                            cam.CFrame = cam.CFrame:Lerp(newLook, t)
                        end
                    end
                end
            end
        end
    end

    -- ESP highlights
    local ESPObjects = {}
    local function ClearESP()
        for _, v in ipairs(ESPObjects) do if v and v.Parent then v:Destroy() end end
        ESPObjects = {}
    end
    local function MkESP(parent, color, label)
        if not parent or not parent.Parent then return end
        local hl = Instance.new("Highlight"); hl.Name = "SD_HL"; hl.FillColor = color; hl.OutlineColor = color; hl.FillTransparency = 0.5; hl.OutlineTransparency = 0; hl.Adornee = parent; hl.Parent = parent
        table.insert(ESPObjects, hl)
        if label then
            local bb = Instance.new("BillboardGui"); bb.Name = "SD_BB"; bb.Size = UDim2.new(0,120,0,30); bb.StudsOffset = Vector3.new(0,3,0); bb.AlwaysOnTop = true; bb.Adornee = parent; bb.Parent = parent
            local l = Instance.new("TextLabel"); l.Size = UDim2.new(1,0,1,0); l.BackgroundTransparency = 1; l.Text = label; l.TextColor3 = color; l.TextStrokeTransparency = 0.3; l.TextScaled = true; l.Font = Enum.Font.GothamBold; l.Parent = bb
            table.insert(ESPObjects, bb)
        end
    end

    local function ESPLoop()
        while S.ESP do
            for _, pl in ipairs(Players:GetPlayers()) do
                if pl.Character and pl ~= LocalPlayer then
                    local color = Color3.fromRGB(255, 60, 60)
                    MkESP(pl.Character, color, pl.Name)
                end
            end
            task.wait(2)
        end
    end

    -- TABS
    local AimTab = Window:CreateTab("Aimbot", 4483362458)
    local espTab = Window:CreateTab("ESP", 4483362458)
    local MoveTab = Window:CreateTab("Move", 4483362458)
    local autoTab = Window:CreateTab("Auto Play", 4483362458)
    local miscTab = Window:CreateTab("Misc", 4483362458)

    -- AIMBOT
    AimTab:CreateSection("Aimbot")
    AimTab:CreateToggle({ Name = "Aimbot (hold Left Click)", CurrentValue = false, Flag = "SDAimFlag",
        Callback = function(v)
            S.Aimbot = v
            if v then task.spawn(AimbotLoop) end
        end })
    AimTab:CreateDropdown({ Name = "Hold Key for Aimbot", Options = {"Left Mouse","Right Mouse","X","Q","E","F","V","T","G","C","Mouse Button 3","Mouse Button 4","Mouse Button 5"},
        CurrentOption = {"Left Mouse"}, Flag = "SDAimKeyFlag",
        Callback = function(o)
            local lbl = o[1]
            local tmap = { ["Left Mouse"]="LMouse", ["Right Mouse"]="RMouse", ["Mouse Button 3"]="MMouse", ["Mouse Button 4"]="MB4", ["Mouse Button 5"]="MB5" }
            S.AimKey = tmap[lbl] or lbl
        end })
    AimTab:CreateToggle({ Name = "Triggerbot (aim while just aiming)", CurrentValue = false, Flag = "SDTriggerFlag",
        Callback = function(v) S.Triggerbot = v end })
    AimTab:CreateSection("Config")
    AimTab:CreateDropdown({ Name = "Aimbot Config", Options = {"Legit","Rage"}, CurrentOption = {"Legit"}, Flag = "SDAimConfigFlag",
        Callback = function(o)
            S.AimConfig = o[1]
        end })
    AimTab:CreateDropdown({ Name = "Hitbox", Options = {"Head","Body"}, CurrentOption = {"Head"}, Flag = "SDAimHitboxFlag",
        Callback = function(o) S.AimHitbox = o[1] end })
    AimTab:CreateSlider({ Name = "Aimbot FOV (Legit)", Range = {5,120}, Increment = 1, Suffix = " deg", CurrentValue = 20, Flag = "SDAimFOVFlag",
        Callback = function(v) S.AimFOV = v end })

    AimTab:CreateSection("Legit Smoothing")
    AimTab:CreateSlider({ Name = "Aim Smoothness", Range = {0.05,1}, Increment = 0.01, Suffix = "", CurrentValue = 0.25, Flag = "SDLegitSmoothFlag",
        Callback = function(v) S.LegitSmooth = v end })
    AimTab:CreateSlider({ Name = "Human Miss Offset (studs)", Range = {0,3}, Increment = 0.1, Suffix = "", CurrentValue = 0.6, Flag = "SDLegitOffsetFlag",
        Callback = function(v) S.LegitOffset = v end })

    AimTab:CreateSection("Rage")
    AimTab:CreateLabel("Rage: instant snap to target, 360 FOV")
    AimTab:CreateToggle({ Name = "Target Enemies Only (Team based)", CurrentValue = true, Flag = "SDAimTeamFlag",
        Callback = function(v) S.AimTeam = v end })

    -- ESP
    espTab:CreateSection("Visuals")
    espTab:CreateToggle({ Name = "Player ESP", CurrentValue = false, Flag = "SDESPFlag",
        Callback = function(v)
            S.ESP = v
            if v then ClearESP(); task.spawn(ESPLoop) else ClearESP() end
        end })
    espTab:CreateButton({ Name = "Clear ESP", Callback = ClearESP })

    -- MOVE
    MoveTab:CreateSection("Movement")
    MoveTab:CreateToggle({ Name = "Custom WalkSpeed", CurrentValue = false, Flag = "SDWalkFlag",
        Callback = function(v) S.WalkSpeedEnabled = v; if not v then local h = Util.GetHumanoid(); if h then h.WalkSpeed = 16 end end end })
    MoveTab:CreateSlider({ Name = "WalkSpeed Value", Range = {16,150}, Increment = 1, Suffix = "", CurrentValue = 40, Flag = "SDWalkValFlag",
        Callback = function(v) S.WalkSpeedValue = v end })
    MoveTab:CreateToggle({ Name = "Infinite Jump", CurrentValue = false, Flag = "SDInfJumpFlag",
        Callback = function(v)
            S.InfiniteJump = v
            if v then S.Connections.InfJump = UserInputService.JumpRequest:Connect(function() if S.InfiniteJump and Util.IsAlive() then local h = Util.GetHumanoid(); if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end end end)
            else DConn("InfJump") end
        end })
    MoveTab:CreateToggle({ Name = "NoClip", CurrentValue = false, Flag = "SDNoClipFlag",
        Callback = function(v)
            S.NoClip = v
            if v then S.Connections.NoClip = RunService.Stepped:Connect(function() if not S.NoClip then return end; local c = Util.GetCharacter(); if not c then return end; for _, p in ipairs(c:GetDescendants()) do if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false end end end)
            else DConn("NoClip") end
        end })
    MoveTab:CreateToggle({ Name = "Fly (W/Space/Ctrl)", CurrentValue = false, Flag = "SDFlyFlag",
        Callback = function(v)
            S.FlyEnabled = v
            if v then
                local bv, bg
                S.Connections.Fly = RunService.RenderStepped:Connect(function()
                    local root = Util.GetRoot()
                    if not root or not Util.IsAlive() then S.FlyEnabled = false; if bv then bv:Destroy() end; if bg then bg:Destroy() end; DConn("Fly"); return end
                    if not bv then
                        bv = Instance.new("BodyVelocity"); bv.MaxForce = Vector3.new(math.huge,math.huge,math.huge); bv.Velocity = Vector3.zero; bv.Parent = root
                        bg = Instance.new("BodyGyro"); bg.MaxTorque = Vector3.new(math.huge,math.huge,math.huge); bg.P = 9000; bg.D = 500; bg.Parent = root
                    end
                    local md = Vector3.zero; local cam = Camera.CFrame
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
    MoveTab:CreateSlider({ Name = "Fly Speed", Range = {10,200}, Increment = 5, Suffix = " studs/s", CurrentValue = 50, Flag = "SDFlySpeedFlag",
        Callback = function(v) S.FlySpeed = v end })

    -- AUTO PLAY
    autoTab:CreateSection("Auto Play")
    autoTab:CreateToggle({ Name = "Auto Queue / Join Duel", CurrentValue = false, Flag = "SDAutoQueueFlag",
        Callback = function(v)
            S.AutoQueue = v
            if v then task.spawn(function()
                while S.AutoQueue do
                    pcall(function()
                        local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
                        if pg then
                            for _, btn in ipairs(pg:GetDescendants()) do
                                local n = btn.Name:lower()
                                local txt = (btn:IsA("TextButton") and btn.Text and btn.Text:lower()) or ""
                                if btn:IsA("TextButton") and (n:find("play") or n:find("queue") or n:find("join") or n:find("duel") or txt:find("play") or txt:find("queue") or txt:find("join")) then
                                    btn:Activate()
                                end
                            end
                        end
                    end)
                    task.wait(3)
                end
            end) end
        end })
    autoTab:CreateToggle({ Name = "Auto Ready", CurrentValue = false, Flag = "SDAutoReadyFlag",
        Callback = function(v)
            S.AutoReady = v
            if v then task.spawn(function()
                while S.AutoReady do
                    pcall(function()
                        local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
                        if pg then
                            for _, btn in ipairs(pg:GetDescendants()) do
                                if btn:IsA("TextButton") and btn.Text and btn.Text:lower() == "ready" then
                                    btn:Activate()
                                end
                            end
                        end
                    end)
                    task.wait(1)
                end
            end) end
        end })

    -- MISC
    miscTab:CreateSection("Warning")
    miscTab:CreateLabel("This game PERMABANS cheaters, no appeals.")
    miscTab:CreateLabel("V3 humanizes aim + adds visibility checks — still use on alt/private server.")
    miscTab:CreateLabel("Use on a private server / alt account.")
    miscTab:CreateSection("Anti AFK")
    miscTab:CreateToggle({ Name = "Anti AFK", CurrentValue = false, Flag = "SDAntiAFKFlag",
        Callback = function(v)
            S.AntiAFK = v
            if v then S.Connections.AntiAFK = LocalPlayer.Idled:Connect(function() task.wait(math.random()*1.2); pcall(function() VirtualUser:CaptureController(); VirtualUser:ClickButton2(Vector2.new(math.random(100,700), math.random(100,400))) end) end)
            else DConn("AntiAFK") end
        end })
    miscTab:CreateSection("Cleanup")
    miscTab:CreateButton({ Name = "Destroy UI",
        Callback = function()
            ClearESP()
            for name, _ in pairs(S.Connections) do DConn(name) end
            S.Aimbot=false; S.ESP=false; S.WalkSpeedEnabled=false; S.InfiniteJump=false; S.NoClip=false; S.FlyEnabled=false; S.AutoQueue=false; S.AutoReady=false; S.Triggerbot=false
            Window:Destroy()
        end })

    -- Core loop (walkspeed)
    RunService.RenderStepped:Connect(function()
        if S.WalkSpeedEnabled then local h = Util.GetHumanoid(); if h then h.WalkSpeed = S.WalkSpeedValue end end
    end)

    Rayfield:Notify({ Title = "OUTCOME HUB", Content = "Sniper Duels loaded (use on alt/private server!)", Duration = 5 })
end

-- ══════════════════════════════════════════════════════════════
-- GAME MODULE: HYPERSHOT
-- ══════════════════════════════════════════════════════════════
function require_Hypershot()
    local Players    = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer
    local RunService = game:GetService("RunService")
    local UserInputService = game:GetService("UserInputService")
    local Camera = workspace.CurrentCamera

    local H = {
        Aimbot = false, AimFOV = 25, AimTeam = true, AimConfig = "Legit", AimHitbox = "Head",
        AimKey = "LMouse", -- token for the input held to drive aimbot (see Util.ResolveInput)
        LegitSmooth = 0.25, LegitOffset = 0.6,
        Triggerbot = false, AutoFire = false,
        ESP = false, TeamESP = false,
        WalkSpeedEnabled = false, WalkSpeedValue = 32,
        InfiniteJump = false, JumpPower = 60,
        NoClip = false, FlyEnabled = false, FlySpeed = 40,
        BHop = false,
        DmgColor = Color3.fromRGB(255,50,50),
        Connections = {},
    }

    local function DConn(name) if H.Connections[name] then pcall(function() H.Connections[name]:Disconnect() end); H.Connections[name] = nil end end
    local function GetParts()
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        return char, hrp, hum
    end

    -- get enemy characters (team-based)
    local function GetEnemies()
        local list = {}
        local myTeam = LocalPlayer.Team
        for _, pl in ipairs(Players:GetPlayers()) do
            local isEnemy = pl ~= LocalPlayer
            if H.AimTeam and myTeam and pl.Team and myTeam == pl.Team then isEnemy = false end
            if isEnemy then
                local hrp, hum
                if pl.Character then
                    hrp = pl.Character:FindFirstChild("HumanoidRootPart")
                    hum = pl.Character:FindFirstChildOfClass("Humanoid")
                end
                if hrp and hum and hum.Health > 0 then
                    table.insert(list, { Pl = pl, Part = hrp, Hum = hum })
                end
            end
        end
        return list
    end

    local function GetTargetPoint(part)
        if H.AimHitbox == "Head" then
            local head = part.Parent:FindFirstChild("Head")
            if head then return head.Position end
        end
        return part.Position
    end

    local function IsVisibleHS(from, to)
        local params = RaycastParams.new()
        params.FilterDescendantsInstances = {LocalPlayer.Character, Camera}
        params.FilterType = Enum.RaycastFilterType.Exclude
        local result = Workspace:Raycast(from, to - from, params)
        if not result then return true end
        return result.Instance and result.Instance:IsDescendantOf(to and to.Parent or Workspace) or false
    end

    local function PickTarget(camPos, camLook, fov)
        local best, bestScore = nil, math.huge
        local enemies = GetEnemies()
        for _, t in ipairs(enemies) do
            local pos = GetTargetPoint(t.Part)
            local toTarget = pos - camPos
            local dist = toTarget.Magnitude
            if dist < 0.01 then continue end
            local dir = toTarget / dist
            local ang = math.deg(math.acos(math.clamp(camLook:Dot(dir), -1, 1)))
            if ang <= fov and (H.AimConfig == "Rage" or IsVisibleHS(camPos, pos)) then
                local score = ang + dist * 0.02
                if score < bestScore then
                    bestScore = score
                    best = t
                end
            end
        end
        return best
    end

    -- FOV Circle UI for Hypershot
    local HS_FOVCircle = nil
    pcall(function()
        if Drawing then
            HS_FOVCircle = Drawing.new("Circle")
            HS_FOVCircle.Visible = false
            HS_FOVCircle.Radius = 130
            HS_FOVCircle.Color = Color3.fromRGB(80,255,120)
            HS_FOVCircle.Thickness = 1.2
            HS_FOVCircle.Transparency = 0.6
            HS_FOVCircle.Filled = false
            HS_FOVCircle.NumSides = 64
            RunService.RenderStepped:Connect(function()
                if not H.Aimbot or H.AimConfig ~= "Legit" then HS_FOVCircle.Visible=false; return end
                local cam = workspace.CurrentCamera
                if not cam then return end
                HS_FOVCircle.Visible = true
                HS_FOVCircle.Position = Vector2.new(cam.ViewportSize.X/2, cam.ViewportSize.Y/2)
                HS_FOVCircle.Radius = math.clamp(H.AimFOV * 6, 30, 420)
            end)
        end
    end)

    local firingLock = false

    -- Move the mouse toward a world position (works in first-person FPS).
    -- The game's own camera controller consumes mouse deltas and rotates the view.
    local hasMMRel = (mousemoverel ~= nil)
    local hasMMAabs = (mousemoveabs ~= nil)
    print("[OUTCOME HUB] Hypershot aim: mousemoverel=" .. tostring(hasMMRel) .. " mousemoveabs=" .. tostring(hasMMAabs))
    local function MoveMouseToward(cam, worldPos, smoothT, offsetX, offsetY)
        local sp = cam:WorldToScreenPoint(worldPos)
        if sp.Z < 0 then return end -- behind camera
        local mp = UserInputService:GetMouseLocation()
        local dx, dy = (sp.X + (offsetX or 0)) - mp.X, (sp.Y + (offsetY or 0)) - mp.Y
        local t = math.clamp(smoothT, 0.05, 1)
        if hasMMRel then
            mousemoverel(dx * t, dy * t)
        elseif hasMMAabs then
            mousemoveabs(sp.X + (offsetX or 0), sp.Y + (offsetY or 0))
        end
    end

    local function AimbotLoop()
        while H.Aimbot do
            task.wait()
            if not H.Aimbot then break end
            local cam = workspace.CurrentCamera
            if not cam then break end
            local myC, myHrp = GetParts()
            if not (myC and myHrp) then break end
            local wantShoot = Util.IsHeld(H.AimKey) or H.Triggerbot
            if wantShoot then
                local fov = (H.AimConfig == "Rage") and 360 or H.AimFOV
                local camPos, camLook = cam.CFrame.Position, cam.CFrame.LookVector
                local best = PickTarget(camPos, camLook, fov)
                if best then
                    local tp = GetTargetPoint(best.Part)
                    if H.AimConfig == "Rage" then
                        -- instant snap to exact hitbox position
                        local sp = cam:WorldToScreenPoint(tp)
                        if sp.Z >= 0 then
                            if hasMMRel then
                                local mp = UserInputService:GetMouseLocation()
                                mousemoverel(sp.X - mp.X, sp.Y - mp.Y)
                            elseif hasMMAabs then
                                mousemoveabs(sp.X, sp.Y)
                            else
                                cam.CFrame = CFrame.lookAt(camPos, tp)
                            end
                        end
                    else
                        -- legit smooth: apply human-like miss in SCREEN space (not world space)
                        local missX = (math.random() - 0.5) * H.LegitOffset * 50 -- pixels
                        local missY = (math.random() - 0.5) * H.LegitOffset * 50 -- pixels
                        if hasMMRel or hasMMAabs then
                            MoveMouseToward(cam, tp, H.LegitSmooth, missX, missY)
                        else
                            local newLook = CFrame.lookAt(camPos, tp)
                            local t = math.clamp(H.LegitSmooth, 0.05, 1)
                            cam.CFrame = cam.CFrame:Lerp(newLook, t)
                        end
                    end
                    if H.AutoFire and not firingLock then
                        firingLock = true
                        task.spawn(function()
                            if mouse1click then mouse1click() end
                            task.wait(0.05)
                            firingLock = false
                        end)
                    end
                end
            end
        end
    end

    -- ESP
    local ESPItems = {}
    local function ClearESP()
        for _, it in ipairs(ESPItems) do pcall(function() it:Destroy() end) end
        ESPItems = {}
    end
    local function MakeHighlight(pl, color)
        local c = pl.Character
        if not c then return end
        local hl = Instance.new("Highlight")
        hl.Name = "_OU_ESP"
        hl.FillColor = color
        hl.OutlineColor = Color3.fromRGB(255,255,255)
        hl.FillTransparency = 0.5
        hl.Parent = c
        ESPItems[#ESPItems+1] = hl
    end
    local function ESPLoop()
        local seen = {}
        while H.ESP do
            for _, pl in ipairs(Players:GetPlayers()) do
                if pl ~= LocalPlayer and pl.Character and not seen[pl] then
                    local isEnemy = true
                    if H.TeamESP and LocalPlayer.Team and pl.Team and LocalPlayer.Team == pl.Team then isEnemy = false end
                    MakeHighlight(pl, isEnemy and H.DmgColor or Color3.fromRGB(80,170,255))
                    seen[pl] = true
                end
            end
            task.wait(1.5)
        end
    end

    -- noclip (lazy: only runs when enabled)
    local function EnsureNoClipConn()
        if H.Connections["NoClip"] then return end
        H.Connections["NoClip"] = RunService.Stepped:Connect(function()
            if not H.NoClip then return end
            local c = LocalPlayer.Character
            if not c then return end
            for _, part in ipairs(c:GetDescendants()) do
                if part:IsA("BasePart") then part.CanCollide = false end
            end
        end)
    end
    local function EnsureFlyConn()
        if H.Connections["Fly"] then return end
        H.Connections["Fly"] = RunService.Heartbeat:Connect(function()
            local c, hrp, hum = GetParts()
            if not (c and hrp and hum) then return end
            if not H.FlyEnabled then
                if hum.PlatformStand then hum.PlatformStand = false end
                return
            end
            hum.PlatformStand = true
            local speed = H.FlySpeed
            -- use AssemblyLinearVelocity for less detection than direct Velocity set when possible
            local move = Vector3.new(0,0,0)
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then move = move + Camera.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then move = move - Camera.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then move = move - Camera.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then move = move + Camera.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then move = move + Vector3.new(0,1,0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then move = move - Vector3.new(0,1,0) end
            if move.Magnitude > 0 then move = move.unit * speed else hum.PlatformStand = false; hrp.AssemblyLinearVelocity = Vector3.zero; return end
            -- 0.05 lerp for smoother, less flaggy movement
            hrp.AssemblyLinearVelocity = hrp.AssemblyLinearVelocity:Lerp(move, 0.35)
        end)
    end
    local function EnsureInfJumpConn()
        if H.Connections["InfJump"] then return end
        H.Connections["InfJump"] = UserInputService.JumpRequest:Connect(function()
            if not H.InfiniteJump then return end
            local _, hrp, hum = GetParts()
            if hrp and hum then
                -- humanized: small random impulse variance
                local variance = 0.9 + math.random() * 0.2
                hrp:ApplyImpulse(Vector3.new(0, H.JumpPower * 45 * variance, 0))
            end
        end)
    end
    local function EnsureBHopConn()
        if H.Connections["BHop"] then return end
        H.Connections["BHop"] = RunService.Heartbeat:Connect(function()
            if not H.BHop then return end
            local _, hrp, hum = GetParts()
            if hrp and hum and UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                if hum.FloorMaterial ~= Enum.Material.Air then
                    hum:ChangeState(Enum.HumanoidStateType.Jumping)
                end
            end
        end)
    end
    -- init lazily on first toggle; pre-create only InfJump/BHop as lightweight
    EnsureInfJumpConn()
    EnsureBHopConn()

    -- movement core loop (walkspeed) - throttled to 0.2s to save CPU + avoid constant flag
    local _lastWalk = 0
    RunService.Heartbeat:Connect(function()
        if os.clock() - _lastWalk < 0.2 then return end
        _lastWalk = os.clock()
        if H.WalkSpeedEnabled then
            local _, _, hum = GetParts()
            if hum then hum.WalkSpeed = H.WalkSpeedValue + (math.random()-0.5)*0.5 end
        end
    end)

    -- TABS
    local AimTab = Window:CreateTab("Aimbot", 4483362458)
    local espTab = Window:CreateTab("Visuals", 4483362458)
    local MoveTab = Window:CreateTab("Move", 4483362458)
    local miscTab = Window:CreateTab("Misc", 4483362458)

    -- WARNING BANNER
    AimTab:CreateSection("WARNING")
    AimTab:CreateLabel("Hypershot bans ALL accounts for cheating — run on ALT / PRIVATE SERVER only!")
    AimTab:CreateLabel("V3: visibility-checked + FOV-limited aim, jittered movement.")
    AimTab:CreateLabel("Enable features at your own risk.")

    -- AIMBOT
    AimTab:CreateSection("Aimbot")
    AimTab:CreateToggle({ Name = "Aimbot (while holding Left Click)", CurrentValue = false, Flag = "HSAimFlag",
        Callback = function(v)
            H.Aimbot = v
            if v then task.spawn(AimbotLoop) end
        end })
    AimTab:CreateDropdown({ Name = "Hold Key for Aimbot", Options = {"Left Mouse","Right Mouse","X","Q","E","F","V","T","G","C","Mouse Button 3","Mouse Button 4","Mouse Button 5"},
        CurrentOption = {"Left Mouse"}, Flag = "HSAimKeyFlag",
        Callback = function(o)
            local lbl = o[1]
            local tmap = { ["Left Mouse"]="LMouse", ["Right Mouse"]="RMouse", ["Mouse Button 3"]="MMouse", ["Mouse Button 4"]="MB4", ["Mouse Button 5"]="MB5" }
            H.AimKey = tmap[lbl] or lbl
        end })
    AimTab:CreateToggle({ Name = "Triggerbot (aim + shoot while just aiming)", CurrentValue = false, Flag = "HSTrigFlag",
        Callback = function(v) H.Triggerbot = v end })
    AimTab:CreateToggle({ Name = "Auto Fire", CurrentValue = false, Flag = "HSAutoFireFlag",
        Callback = function(v) H.AutoFire = v end })
    AimTab:CreateSection("Config")
    AimTab:CreateDropdown({ Name = "Aimbot Config", Options = {"Legit","Rage"}, CurrentOption = {"Legit"}, Flag = "HSAimConfigFlag",
        Callback = function(o) H.AimConfig = o[1] end })
    AimTab:CreateDropdown({ Name = "Hitbox", Options = {"Head","Body"}, CurrentOption = {"Head"}, Flag = "HSAimHitboxFlag",
        Callback = function(o) H.AimHitbox = o[1] end })
    AimTab:CreateSlider({ Name = "Aimbot FOV (Legit)", Range = {5,120}, Increment = 1, Suffix = " deg", CurrentValue = 25, Flag = "HSAimFOVFlag",
        Callback = function(v) H.AimFOV = v end })
    AimTab:CreateSlider({ Name = "Aim Smoothness", Range = {0.05,1}, Increment = 0.01, Suffix = "", CurrentValue = 0.25, Flag = "HSLegitSmoothFlag",
        Callback = function(v) H.LegitSmooth = v end })
    AimTab:CreateSlider({ Name = "Human Miss Offset (studs)", Range = {0,3}, Increment = 0.1, Suffix = "", CurrentValue = 0.6, Flag = "HSLegitOffsetFlag",
        Callback = function(v) H.LegitOffset = v end })
    AimTab:CreateToggle({ Name = "Enemies Only (Team based)", CurrentValue = true, Flag = "HSAimTeamFlag",
        Callback = function(v) H.AimTeam = v end })

    -- VISUALS
    espTab:CreateSection("Visuals")
    espTab:CreateToggle({ Name = "Player ESP (Highlight)", CurrentValue = false, Flag = "HSESPFlag",
        Callback = function(v)
            H.ESP = v
            if v then ClearESP(); task.spawn(ESPLoop) else ClearESP() end
        end })
    espTab:CreateToggle({ Name = "Show Teammates (blue)", CurrentValue = false, Flag = "HSTeamESPFlag",
        Callback = function(v) H.TeamESP = v end })
    espTab:CreateButton({ Name = "Clear ESP", Callback = function() ClearESP() end })

    -- MOVE
    MoveTab:CreateSection("Movement")
    MoveTab:CreateToggle({ Name = "Bunny Hop (hold Space)", CurrentValue = false, Flag = "HSBHopFlag",
        Callback = function(v) H.BHop = v; if v then EnsureBHopConn() end end })
    MoveTab:CreateToggle({ Name = "WalkSpeed", CurrentValue = false, Flag = "HSWalkFlag",
        Callback = function(v) H.WalkSpeedEnabled = v end })
    MoveTab:CreateSlider({ Name = "WalkSpeed", Range = {16,200}, Increment = 1, CurrentValue = 32, Flag = "HSWalkValFlag",
        Callback = function(v) H.WalkSpeedValue = v end })
    MoveTab:CreateToggle({ Name = "Infinite Jump", CurrentValue = false, Flag = "HSInfJumpFlag",
        Callback = function(v) H.InfiniteJump = v; if v then EnsureInfJumpConn() end end })
    MoveTab:CreateSlider({ Name = "Jump Power", Range = {50,300}, Increment = 5, CurrentValue = 60, Flag = "HSJumpFlag",
        Callback = function(v) H.JumpPower = v end })
    MoveTab:CreateToggle({ Name = "NoClip", CurrentValue = false, Flag = "HSNoClipFlag",
        Callback = function(v) H.NoClip = v; if v then EnsureNoClipConn() end end })
    MoveTab:CreateToggle({ Name = "Fly (hold W/Space, Shift to descend)", CurrentValue = false, Flag = "HSFlyFlag",
        Callback = function(v) H.FlyEnabled = v; if v then EnsureFlyConn() end end })
    MoveTab:CreateSlider({ Name = "Fly Speed", Range = {10,200}, Increment = 5, CurrentValue = 40, Flag = "HSFlySpeedFlag",
        Callback = function(v) H.FlySpeed = v end })

    -- MISC
    miscTab:CreateSection("Cleanup")
    miscTab:CreateButton({ Name = "Destroy UI",
        Callback = function()
            ClearESP()
            for name, _ in pairs(H.Connections) do DConn(name) end
            H.Aimbot=false; H.ESP=false; H.WalkSpeedEnabled=false; H.InfiniteJump=false; H.NoClip=false; H.FlyEnabled=false; H.Triggerbot=false; H.AutoFire=false; H.BHop=false
            Window:Destroy()
        end })

    Rayfield:Notify({ Title = "OUTCOME HUB", Content = "Hypershot loaded (use on ALT / PRIVATE server!)", Duration = 5 })
end

-- ═══════════════════════════════════════════════════════════════
-- GAME MODULE: BLOX FRUITS
-- ═══════════════════════════════════════════════════════════════
function require_BloxFruits()
    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer
    local RunService = game:GetService("RunService")
    local UserInputService = game:GetService("UserInputService")
    local Workspace = game:GetService("Workspace")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local VirtualUser = game:GetService("VirtualUser")
    local TweenService = game:GetService("TweenService")

    local Camera = Workspace.CurrentCamera

    local BF = {
        -- Auto Farm
        AutoFarm = false, FarmMode = "Level", FarmDistance = 15, FarmDelay = 0.1,
        AutoQuest = false, QuestNPC = nil,
        AutoBoss = false, SelectedBoss = "",

        -- Fruit
        FruitFinder = false, FruitESP = false, FruitNotifier = false,
        AutoStoreFruit = false, AutoEatFruit = false,

        -- Teleport
        TeleportToSea = 1, TeleportToIsland = "",
        ClickTP = false,

        -- Combat
        AutoClick = false, ClickDelay = 0.05,
        AutoSkillZ = false, AutoSkillX = false, AutoSkillC = false, AutoSkillV = false, AutoSkillF = false,
        SkillDelay = 0.5,

        -- Movement
        WalkSpeedEnabled = false, WalkSpeedValue = 50,
        InfiniteJump = false, NoClip = false,
        FlyEnabled = false, FlySpeed = 80,
        BHop = false,

        -- ESP
        PlayerESP = false, NPCESP = false, ChestESP = false,
        ESPColor = Color3.fromRGB(255, 100, 100),

        -- Misc
        AntiAFK = false, AutoHaki = false,
        WhiteScreen = false, FPSBoost = false,

        Connections = {},
    }

    local function DConn(name)
        if BF.Connections[name] then
            pcall(function() BF.Connections[name]:Disconnect() end)
            BF.Connections[name] = nil
        end
    end

    local function GetParts()
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        return char, hrp, hum
    end

    local function IsAlive()
        local _, _, hum = GetParts()
        return hum and hum.Health > 0
    end

    -- Quest/Level data
    local QuestData = {
        {Level = 1, NPC = "BanditQuest1", Enemy = "Bandit", CFrame = CFrame.new(1060, 16, 1547)},
        {Level = 10, NPC = "MonkeyQuest", Enemy = "Monkey", CFrame = CFrame.new(-1442, 37, -213)},
        {Level = 15, NPC = "GorillaQuest", Enemy = "Gorilla", CFrame = CFrame.new(-1223, 6, -497)},
        {Level = 30, NPC = "PirateQuest", Enemy = "Pirate", CFrame = CFrame.new(-1131, 13, 3828)},
        {Level = 60, NPC = "DesertQuest", Enemy = "Desert Bandit", CFrame = CFrame.new(944, 6, 4374)},
        {Level = 75, NPC = "DesertQuest2", Enemy = "Desert Officer", CFrame = CFrame.new(1574, 8, 4357)},
        {Level = 90, NPC = "SnowQuest", Enemy = "Snow Bandit", CFrame = CFrame.new(1386, 87, -1298)},
        {Level = 100, NPC = "SnowQuest2", Enemy = "Snowman", CFrame = CFrame.new(1386, 87, -1298)},
        {Level = 120, NPC = "MarineQuest2", Enemy = "Chief Petty Officer", CFrame = CFrame.new(-4851, 20, 4360)},
        {Level = 150, NPC = "SkyQuest", Enemy = "Sky Bandit", CFrame = CFrame.new(-4841, 718, -2623)},
        {Level = 175, NPC = "SkyQuest2", Enemy = "Dark Master", CFrame = CFrame.new(-5234, 428, -2232)},
        {Level = 200, NPC = "PrisonerQuest", Enemy = "Prisoner", CFrame = CFrame.new(5308, 1, 475)},
        {Level = 225, NPC = "PrisonerQuest2", Enemy = "Dangerous Prisoner", CFrame = CFrame.new(5308, 1, 475)},
        {Level = 250, NPC = "TundraQuest", Enemy = "Arctic Warrior", CFrame = CFrame.new(5661, 28, -6486)},
        {Level = 275, NPC = "TundraQuest2", Enemy = "Snow Lurker", CFrame = CFrame.new(5661, 28, -6486)},
        {Level = 300, NPC = "MagmaQuest", Enemy = "Magma Ninja", CFrame = CFrame.new(-5379, 12, -5867)},
        {Level = 325, NPC = "MagmaQuest2", Enemy = "Lava Pirate", CFrame = CFrame.new(-5379, 12, -5867)},
        {Level = 375, NPC = "FishmanQuest", Enemy = "Fishman Warrior", CFrame = CFrame.new(61123, 18, 1569)},
        {Level = 400, NPC = "FishmanQuest2", Enemy = "Fishman Commando", CFrame = CFrame.new(61123, 18, 1569)},
        {Level = 450, NPC = "SkyExp1Quest", Enemy = "God's Guard", CFrame = CFrame.new(-4721, 845, -1954)},
        {Level = 475, NPC = "SkyExp1Quest2", Enemy = "Shanda", CFrame = CFrame.new(-4721, 845, -1954)},
        {Level = 525, NPC = "SkyExp2Quest", Enemy = "Royal Squad", CFrame = CFrame.new(-7906, 5636, -1411)},
        {Level = 550, NPC = "SkyExp2Quest2", Enemy = "Royal Soldier", CFrame = CFrame.new(-7906, 5636, -1411)},
        {Level = 600, NPC = "FountainQuest", Enemy = "Galley Pirate", CFrame = CFrame.new(5557, 39, 4027)},
        {Level = 625, NPC = "FountainQuest2", Enemy = "Galley Captain", CFrame = CFrame.new(5557, 39, 4027)},
    }

    local Islands = {
        ["Starter Island"] = CFrame.new(1060, 16, 1547),
        ["Jungle"] = CFrame.new(-1612, 36, 149),
        ["Pirate Village"] = CFrame.new(-1131, 13, 3828),
        ["Desert"] = CFrame.new(944, 6, 4374),
        ["Frozen Village"] = CFrame.new(1386, 87, -1298),
        ["Marine Fortress"] = CFrame.new(-4851, 20, 4360),
        ["Skylands"] = CFrame.new(-4841, 718, -2623),
        ["Prison"] = CFrame.new(5308, 1, 475),
        ["Colosseum"] = CFrame.new(-1428, 7, -3218),
        ["Magma Village"] = CFrame.new(-5379, 12, -5867),
        ["Underwater City"] = CFrame.new(61123, 18, 1569),
        ["Fountain City"] = CFrame.new(5557, 39, 4027),
        ["Haunted Castle"] = CFrame.new(-9515, 142, 5548),
        ["Sea of Treats"] = CFrame.new(-1625, 15, -1425),
        ["Mirage Island"] = CFrame.new(-7906, 5636, -1411),
    }

    local Bosses = {
        "The Gorilla King", "Bobby", "Yeti", "Mob Leader", "Vice Admiral",
        "Warden", "Chief Warden", "Swan", "Magma Admiral", "Fishman Lord",
        "Wysper", "Thunder God", "Cyborg", "Saber Expert", "Cursed Captain",
        "Darkbeard", "Order", "Dough King", "Rip_Indra", "Soul Reaper",
    }

    -- Auto Farm Functions
    local function GetCurrentQuest()
        local level = LocalPlayer.Data.Level.Value
        for i = #QuestData, 1, -1 do
            if level >= QuestData[i].Level then
                return QuestData[i]
            end
        end
        return QuestData[1]
    end

    local function GetEnemyByName(name)
        for _, obj in ipairs(Workspace.Enemies:GetChildren()) do
            if obj.Name == name and obj:FindFirstChild("Humanoid") and obj.Humanoid.Health > 0 then
                local hrp = obj:FindFirstChild("HumanoidRootPart")
                if hrp then return obj, hrp end
            end
        end
        return nil, nil
    end

    local function GetNearestEnemy()
        local _, myHrp = GetParts()
        if not myHrp then return nil, nil end
        local nearest, dist = nil, math.huge
        for _, obj in ipairs(Workspace.Enemies:GetChildren()) do
            if obj:FindFirstChild("Humanoid") and obj.Humanoid.Health > 0 then
                local hrp = obj:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local d = (myHrp.Position - hrp.Position).Magnitude
                    if d < dist then dist = d; nearest = obj end
                end
            end
        end
        return nearest, dist
    end

    local function StartQuest(questNPC)
        local args = { [1] = "StartQuest", [2] = questNPC, [3] = 1 }
        pcall(function() ReplicatedStorage.Remotes.CommF_:InvokeServer(unpack(args)) end)
    end

    local function Teleport(cframe)
        local _, hrp = GetParts()
        if hrp then
            if BF.FarmMode == "Tween" then
                local tween = TweenService:Create(hrp, TweenInfo.new(BF.FarmDistance / 100, Enum.EasingStyle.Linear), {CFrame = cframe})
                tween:Play()
                tween.Completed:Wait()
            else
                hrp.CFrame = cframe
            end
        end
    end

    local function Attack()
        if not BF.AutoClick then return end
        local char = LocalPlayer.Character
        if char then
            local tool = char:FindFirstChildOfClass("Tool")
            if tool then tool:Activate() end
        end
    end

    local function UseSkills()
        if not IsAlive() then return end
        local char = LocalPlayer.Character
        if not char then return end
        local tool = char:FindFirstChildOfClass("Tool")
        if not tool then return end
        if BF.AutoSkillZ then pcall(function() game:GetService("VirtualInputManager"):SendKeyEvent(true, Enum.KeyCode.Z, false, game) end); task.wait(0.05); pcall(function() game:GetService("VirtualInputManager"):SendKeyEvent(false, Enum.KeyCode.Z, false, game) end) end
        if BF.AutoSkillX then pcall(function() game:GetService("VirtualInputManager"):SendKeyEvent(true, Enum.KeyCode.X, false, game) end); task.wait(0.05); pcall(function() game:GetService("VirtualInputManager"):SendKeyEvent(false, Enum.KeyCode.X, false, game) end) end
        if BF.AutoSkillC then pcall(function() game:GetService("VirtualInputManager"):SendKeyEvent(true, Enum.KeyCode.C, false, game) end); task.wait(0.05); pcall(function() game:GetService("VirtualInputManager"):SendKeyEvent(false, Enum.KeyCode.C, false, game) end) end
        if BF.AutoSkillV then pcall(function() game:GetService("VirtualInputManager"):SendKeyEvent(true, Enum.KeyCode.V, false, game) end); task.wait(0.05); pcall(function() game:GetService("VirtualInputManager"):SendKeyEvent(false, Enum.KeyCode.V, false, game) end) end
        if BF.AutoSkillF then pcall(function() game:GetService("VirtualInputManager"):SendKeyEvent(true, Enum.KeyCode.F, false, game) end); task.wait(0.05); pcall(function() game:GetService("VirtualInputManager"):SendKeyEvent(false, Enum.KeyCode.F, false, game) end) end
    end

    -- Fruit Finder
    local function FindFruits()
        local fruits = {}
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj.Name:find("Fruit") and obj:IsA("Tool") then
                table.insert(fruits, obj)
            end
        end
        return fruits
    end

    local function FruitESLoop()
        while BF.FruitESP do
            for _, fruit in ipairs(FindFruits()) do
                if fruit and fruit.Parent and not fruit:FindFirstChild("_BF_ESP") then
                    local hl = Instance.new("Highlight")
                    hl.Name = "_BF_ESP"
                    hl.FillColor = Color3.fromRGB(255, 0, 255)
                    hl.OutlineColor = Color3.fromRGB(255, 255, 255)
                    hl.FillTransparency = 0.3
                    hl.Adornee = fruit
                    hl.Parent = fruit
                end
            end
            task.wait(2)
        end
        for _, fruit in ipairs(FindFruits()) do
            local esp = fruit:FindFirstChild("_BF_ESP")
            if esp then esp:Destroy() end
        end
    end

    -- ESP Functions
    local ESPItems = {}
    local function ClearESP()
        for _, v in ipairs(ESPItems) do pcall(function() v:Destroy() end) end
        ESPItems = {}
    end

    local function MakeESP(obj, color, text)
        if not obj or not obj.Parent then return end
        local hl = Instance.new("Highlight")
        hl.Name = "_BF_ESP"
        hl.FillColor = color
        hl.OutlineColor = Color3.fromRGB(255, 255, 255)
        hl.FillTransparency = 0.5
        hl.Adornee = obj
        hl.Parent = obj
        table.insert(ESPItems, hl)
        if text then
            local bb = Instance.new("BillboardGui")
            bb.Name = "_BF_LABEL"
            bb.Size = UDim2.new(0, 120, 0, 30)
            bb.StudsOffset = Vector3.new(0, 3, 0)
            bb.AlwaysOnTop = true
            bb.Adornee = obj:IsA("Model") and obj:FindFirstChild("HumanoidRootPart") or obj
            bb.Parent = obj
            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(1, 0, 1, 0)
            lbl.BackgroundTransparency = 1
            lbl.Text = text
            lbl.TextColor3 = color
            lbl.TextStrokeTransparency = 0.3
            lbl.TextScaled = true
            lbl.Font = Enum.Font.GothamBold
            lbl.Parent = bb
            table.insert(ESPItems, bb)
        end
    end

    local function ESPLoop()
        while BF.PlayerESP or BF.NPCESP or BF.ChestESP do
            if BF.PlayerESP then
                for _, pl in ipairs(Players:GetPlayers()) do
                    if pl ~= LocalPlayer and pl.Character and pl.Character:FindFirstChild("HumanoidRootPart") and not pl.Character:FindFirstChild("_BF_ESP") then
                        MakeESP(pl.Character, Color3.fromRGB(255, 60, 60), pl.Name)
                    end
                end
            end
            if BF.NPCESP then
                for _, obj in ipairs(Workspace.Enemies:GetChildren()) do
                    if obj:FindFirstChild("HumanoidRootPart") and not obj:FindFirstChild("_BF_ESP") then
                        MakeESP(obj, Color3.fromRGB(255, 150, 0), obj.Name)
                    end
                end
            end
            if BF.ChestESP then
                -- throttle chest scan to 5s & cache result
                local cached = Util.Throttled("BFChestScan", 5, function() local t={}; for _, obj in ipairs(Workspace:GetDescendants()) do if obj.Name:find("Chest") and obj:IsA("BasePart") then table.insert(t,obj) end end; return t end)
                if cached then for _, obj in ipairs(cached) do if obj and obj.Parent and not obj:FindFirstChild("_BF_ESP") then MakeESP(obj, Color3.fromRGB(255, 215, 0), "Chest") end end end
            end
            task.wait(3)
        end
    end

    -- White Screen / FPS Boost (reversible + throttled)
    local WhiteScreenCache = {}
    local function ToggleWhiteScreen(v)
        BF.WhiteScreen = v
        local Lighting = game:GetService("Lighting")
        if v then
            WhiteScreenCache = {}
            for _, obj in ipairs(Workspace:GetDescendants()) do
                if obj:IsA("BasePart") then
                    WhiteScreenCache[obj] = {Material = obj.Material, Reflectance = obj.Reflectance}
                    obj.Material = Enum.Material.SmoothPlastic
                    obj.Reflectance = 0
                elseif obj:IsA("Decal") or obj:IsA("Texture") then
                    WhiteScreenCache[obj] = {Transparency = obj.Transparency}
                    obj.Transparency = 1
                elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") then
                    WhiteScreenCache[obj] = {Enabled = obj.Enabled}
                    obj.Enabled = false
                end
            end
            for _, obj in ipairs(Lighting:GetDescendants()) do
                if obj:IsA("BloomEffect") or obj:IsA("SunRaysEffect") or obj:IsA("BlurEffect") then
                    WhiteScreenCache[obj] = {Enabled = obj.Enabled}
                    obj.Enabled = false
                end
            end
        else
            for obj, props in pairs(WhiteScreenCache) do
                if obj and obj.Parent then
                    for k, val in pairs(props) do pcall(function() obj[k] = val end) end
                end
            end
            WhiteScreenCache = {}
        end
    end

    -- TABS
    local FarmTab = Window:CreateTab("Auto Farm", 4483362458)
    local FruitTab = Window:CreateTab("Fruit", 4483362458)
    local TeleportTab = Window:CreateTab("Teleport", 4483362458)
    local CombatTab = Window:CreateTab("Combat", 4483362458)
    local MoveTab = Window:CreateTab("Movement", 4483362458)
    local ESPTab = Window:CreateTab("ESP", 4483362458)
    local MiscTab = Window:CreateTab("Misc", 4483362458)

    -- AUTO FARM
    FarmTab:CreateSection("Main Farm")
    FarmTab:CreateToggle({ Name = "Auto Farm Level", CurrentValue = false, Flag = "BFAutoFarmFlag",
        Callback = function(v)
            BF.AutoFarm = v
            if v then task.spawn(function()
                while BF.AutoFarm do
                    if not IsAlive() then task.wait(3) continue end
                    local quest = GetCurrentQuest()
                    local enemy, enemyHrp = GetEnemyByName(quest.Enemy)
                    if not enemy then
                        Teleport(quest.CFrame + Vector3.new(0, 20, 0))
                        task.wait(1)
                        StartQuest(quest.NPC)
                        task.wait(1)
                    else
                        Teleport(enemyHrp.CFrame * CFrame.new(0, BF.FarmDistance, 0))
                        Attack()
                        UseSkills()
                    end
                    task.wait(BF.FarmDelay + math.random()*0.1)
                end
            end) end
        end })
    FarmTab:CreateDropdown({ Name = "Farm Mode", Options = {"Teleport", "Tween"}, CurrentOption = {"Teleport"}, Flag = "BFFarmModeFlag",
        Callback = function(o) BF.FarmMode = o[1] end })
    FarmTab:CreateSlider({ Name = "Farm Distance", Range = {5, 30}, Increment = 1, Suffix = " studs", CurrentValue = 15, Flag = "BFFarmDistFlag",
        Callback = function(v) BF.FarmDistance = v end })
    FarmTab:CreateSlider({ Name = "Farm Delay", Range = {0.05, 1}, Increment = 0.05, Suffix = "s", CurrentValue = 0.1, Flag = "BFFarmDelayFlag",
        Callback = function(v) BF.FarmDelay = v end })

    FarmTab:CreateSection("Auto Quest")
    FarmTab:CreateToggle({ Name = "Auto Accept Quest", CurrentValue = false, Flag = "BFAutoQuestFlag",
        Callback = function(v) BF.AutoQuest = v end })

    FarmTab:CreateSection("Boss Farm")
    local BossDropdown = FarmTab:CreateDropdown({ Name = "Select Boss", Options = Bosses, CurrentOption = {}, Flag = "BFBossFlag",
        Callback = function(o) BF.SelectedBoss = o[1] end })
    FarmTab:CreateToggle({ Name = "Auto Farm Selected Boss", CurrentValue = false, Flag = "BFAutoBossFlag",
        Callback = function(v)
            BF.AutoBoss = v
            if v then task.spawn(function()
                while BF.AutoBoss do
                    if not IsAlive() then task.wait(3) continue end
                    local boss, bossHrp = GetEnemyByName(BF.SelectedBoss)
                    if boss and bossHrp then
                        Teleport(bossHrp.CFrame * CFrame.new(0, BF.FarmDistance, 0))
                        Attack()
                        UseSkills()
                    else
                        -- try to find boss spawn
                        task.wait(5)
                    end
                    task.wait(BF.FarmDelay + math.random()*0.08)
                end
            end) end
        end })

    -- FRUIT TAB
    FruitTab:CreateSection("Fruit Finder")
    FruitTab:CreateToggle({ Name = "Fruit ESP", CurrentValue = false, Flag = "BFFruitESPFlag",
        Callback = function(v)
            BF.FruitESP = v
            if v then task.spawn(FruitESLoop) end
        end })
    FruitTab:CreateToggle({ Name = "Fruit Notifier (chat)", CurrentValue = false, Flag = "BFFruitNotifFlag",
        Callback = function(v)
            BF.FruitNotifier = v
            if v then task.spawn(function()
                local lastFruit = ""
                while BF.FruitNotifier do
                    local fruits = FindFruits()
                    for _, f in ipairs(fruits) do
                        if f.Name ~= lastFruit then
                            lastFruit = f.Name
                            Rayfield:Notify({ Title = "Fruit Spawned!", Content = f.Name .. " at " .. tostring(f:GetPivot().Position), Duration = 10 })
                        end
                    end
                    task.wait(3)
                end
            end) end
        end })
    FruitTab:CreateToggle({ Name = "Auto Store Fruit", CurrentValue = false, Flag = "BFAutoStoreFlag",
        Callback = function(v) BF.AutoStoreFruit = v end })
    FruitTab:CreateToggle({ Name = "Auto Eat Fruit (if held)", CurrentValue = false, Flag = "BFAutoEatFlag",
        Callback = function(v) BF.AutoEatFruit = v end })

    -- TELEPORT
    TeleportTab:CreateSection("Sea Teleport")
    TeleportTab:CreateDropdown({ Name = "Select Sea", Options = {"Sea 1", "Sea 2", "Sea 3"}, CurrentOption = {"Sea 1"}, Flag = "BFSeaFlag",
        Callback = function(o) BF.TeleportToSea = tonumber(o[1]:match("%d")) or 1 end })
    TeleportTab:CreateButton({ Name = "Teleport to Sea", Callback = function()
        local seaCF = { CFrame.new(1060, 16, 1547), CFrame.new(-3057, 5, 3077), CFrame.new(-7906, 5636, -1411) }
        local _, hrp = GetParts()
        if hrp then hrp.CFrame = seaCF[BF.TeleportToSea] + Vector3.new(0, 50, 0) end
    end })

    TeleportTab:CreateSection("Island Teleport")
    local IslandNames = {}
    for name, _ in pairs(Islands) do table.insert(IslandNames, name) end
    table.sort(IslandNames)
    TeleportTab:CreateDropdown({ Name = "Select Island", Options = IslandNames, CurrentOption = {}, Flag = "BFIslandFlag",
        Callback = function(o) BF.TeleportToIsland = o[1] end })
    TeleportTab:CreateButton({ Name = "Teleport to Island", Callback = function()
        local cf = Islands[BF.TeleportToIsland]
        if cf then
            local _, hrp = GetParts()
            if hrp then hrp.CFrame = cf + Vector3.new(0, 50, 0) end
        end
    end })

    TeleportTab:CreateSection("Click Teleport")
    TeleportTab:CreateToggle({ Name = "Click TP (Right Click)", CurrentValue = false, Flag = "BFClickTPFlag",
        Callback = function(v)
            BF.ClickTP = v
            if v then BF.Connections.ClickTP = UserInputService.InputBegan:Connect(function(input, processed)
                if processed then return end
                if input.UserInputType == Enum.UserInputType.MouseButton2 then
                    local _, hrp = GetParts()
                    if hrp then local m = LocalPlayer:GetMouse(); if m.Hit then hrp.CFrame = m.Hit + Vector3.new(0, 5, 0) end end
                end
            end) else DConn("ClickTP") end
        end })

    -- COMBAT
    CombatTab:CreateSection("Auto Click")
    CombatTab:CreateToggle({ Name = "Auto Click", CurrentValue = false, Flag = "BFAutoClickFlag",
        Callback = function(v) BF.AutoClick = v end })
    CombatTab:CreateSlider({ Name = "Click Delay", Range = {0.01, 0.5}, Increment = 0.01, Suffix = "s", CurrentValue = 0.05, Flag = "BFClickDelayFlag",
        Callback = function(v) BF.ClickDelay = v end })

    CombatTab:CreateSection("Auto Skills")
    CombatTab:CreateToggle({ Name = "Auto Z", CurrentValue = false, Flag = "BFAutoZFlag", Callback = function(v) BF.AutoSkillZ = v end })
    CombatTab:CreateToggle({ Name = "Auto X", CurrentValue = false, Flag = "BFAutoXFlag", Callback = function(v) BF.AutoSkillX = v end })
    CombatTab:CreateToggle({ Name = "Auto C", CurrentValue = false, Flag = "BFAutoCFlag", Callback = function(v) BF.AutoSkillC = v end })
    CombatTab:CreateToggle({ Name = "Auto V", CurrentValue = false, Flag = "BFAutoVFlag", Callback = function(v) BF.AutoSkillV = v end })
    CombatTab:CreateToggle({ Name = "Auto F", CurrentValue = false, Flag = "BFAutoFFlag", Callback = function(v) BF.AutoSkillF = v end })
    CombatTab:CreateSlider({ Name = "Skill Cycle Delay", Range = {0.1, 2}, Increment = 0.1, Suffix = "s", CurrentValue = 0.5, Flag = "BFSkillDelayFlag",
        Callback = function(v) BF.SkillDelay = v end })

    -- MOVEMENT
    MoveTab:CreateSection("Speed & Jump")
    MoveTab:CreateToggle({ Name = "Custom WalkSpeed", CurrentValue = false, Flag = "BFWalkFlag",
        Callback = function(v) BF.WalkSpeedEnabled = v; if not v then local _, _, hum = GetParts(); if hum then hum.WalkSpeed = 16 end end end })
    MoveTab:CreateSlider({ Name = "WalkSpeed", Range = {16, 300}, Increment = 1, Suffix = " studs/s", CurrentValue = 50, Flag = "BFWalkValFlag",
        Callback = function(v) BF.WalkSpeedValue = v end })
    MoveTab:CreateToggle({ Name = "Infinite Jump", CurrentValue = false, Flag = "BFInfJumpFlag",
        Callback = function(v)
            BF.InfiniteJump = v
            if v then BF.Connections.InfJump = UserInputService.JumpRequest:Connect(function() if BF.InfiniteJump and IsAlive() then local _, _, hum = GetParts(); if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end end end)
            else DConn("InfJump") end
        end })

    MoveTab:CreateSection("Fly & NoClip")
    MoveTab:CreateToggle({ Name = "Fly (W/Space/Shift)", CurrentValue = false, Flag = "BFFlyFlag",
        Callback = function(v)
            BF.FlyEnabled = v
            if v then
                local bv, bg
                BF.Connections.Fly = RunService.RenderStepped:Connect(function()
                    local _, hrp, hum = GetParts()
                    if not (hrp and hum and IsAlive()) then BF.FlyEnabled = false; if bv then bv:Destroy() end; if bg then bg:Destroy() end; DConn("Fly"); return end
                    if not bv then
                        bv = Instance.new("BodyVelocity"); bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge); bv.Velocity = Vector3.zero; bv.Parent = hrp
                        bg = Instance.new("BodyGyro"); bg.MaxTorque = Vector3.new(math.huge, math.huge, math.huge); bg.P = 9000; bg.D = 500; bg.Parent = hrp
                    end
                    local md = Vector3.zero; local cam = Camera.CFrame
                    if UserInputService:IsKeyDown(Enum.KeyCode.W) then md = md + cam.LookVector end
                    if UserInputService:IsKeyDown(Enum.KeyCode.S) then md = md - cam.LookVector end
                    if UserInputService:IsKeyDown(Enum.KeyCode.A) then md = md - cam.RightVector end
                    if UserInputService:IsKeyDown(Enum.KeyCode.D) then md = md + cam.RightVector end
                    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then md = md + Vector3.new(0, 1, 0) end
                    if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then md = md - Vector3.new(0, 1, 0) end
                    if md.Magnitude > 0 then md = md.Unit * BF.FlySpeed end
                    bv.Velocity = md; bg.CFrame = cam
                end)
            else
                DConn("Fly")
                local _, hrp = GetParts()
                if hrp then for _, v in ipairs(hrp:GetChildren()) do if v:IsA("BodyVelocity") or v:IsA("BodyGyro") then v:Destroy() end end end
            end
        end })
    MoveTab:CreateSlider({ Name = "Fly Speed", Range = {10, 300}, Increment = 5, Suffix = " studs/s", CurrentValue = 80, Flag = "BFFlySpeedFlag",
        Callback = function(v) BF.FlySpeed = v end })
    MoveTab:CreateToggle({ Name = "NoClip", CurrentValue = false, Flag = "BFNoClipFlag",
        Callback = function(v)
            BF.NoClip = v
            if v then BF.Connections.NoClip = RunService.Stepped:Connect(function() if not BF.NoClip then return end; local c = LocalPlayer.Character; if not c then return end; for _, p in ipairs(c:GetDescendants()) do if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false end end end)
            else DConn("NoClip") end
        end })
    MoveTab:CreateToggle({ Name = "Bunny Hop", CurrentValue = false, Flag = "BFBHopFlag",
        Callback = function(v)
            BF.BHop = v
            if v then BF.Connections.BHop = RunService.Heartbeat:Connect(function()
                local _, hrp, hum = GetParts()
                if BF.BHop and hrp and hum and UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                    if hum:GetState() == Enum.HumanoidStateType.Landed or hum:GetState() == Enum.HumanoidStateType.Running then
                        hum.Jump = true
                    end
                end
            end) else DConn("BHop") end
        end })

    -- ESP
    ESPTab:CreateSection("Visuals")
    ESPTab:CreateToggle({ Name = "Player ESP", CurrentValue = false, Flag = "BFPlayerESPFlag",
        Callback = function(v)
            BF.PlayerESP = v
            if v then ClearESP(); task.spawn(ESPLoop) else ClearESP() end
        end })
    ESPTab:CreateToggle({ Name = "NPC / Enemy ESP", CurrentValue = false, Flag = "BFNPCESPFlag",
        Callback = function(v)
            BF.NPCESP = v
            if v then ClearESP(); task.spawn(ESPLoop) else ClearESP() end
        end })
    ESPTab:CreateToggle({ Name = "Chest ESP", CurrentValue = false, Flag = "BFChestESPFlag",
        Callback = function(v)
            BF.ChestESP = v
            if v then ClearESP(); task.spawn(ESPLoop) else ClearESP() end
        end })
    ESPTab:CreateButton({ Name = "Clear All ESP", Callback = ClearESP })

    -- MISC
    MiscTab:CreateSection("Anti AFK")
    MiscTab:CreateToggle({ Name = "Anti AFK", CurrentValue = false, Flag = "BFAntiAFKFlag",
        Callback = function(v)
            BF.AntiAFK = v
            if v then BF.Connections.AntiAFK = LocalPlayer.Idled:Connect(function() task.wait(math.random()*1.0); pcall(function() VirtualUser:CaptureController(); VirtualUser:ClickButton2(Vector2.new(math.random(100,700), math.random(100,400))) end) end)
            else DConn("AntiAFK") end
        end })

    MiscTab:CreateSection("Performance")
    MiscTab:CreateToggle({ Name = "White Screen (FPS Boost)", CurrentValue = false, Flag = "BFWhiteScreenFlag",
        Callback = function(v) ToggleWhiteScreen(v) end })

    MiscTab:CreateSection("Cleanup")
    MiscTab:CreateButton({ Name = "Destroy UI",
        Callback = function()
            ClearESP()
            for name, _ in pairs(BF.Connections) do DConn(name) end
            BF.AutoFarm = false; BF.AutoQuest = false; BF.AutoBoss = false
            BF.FruitESP = false; BF.FruitNotifier = false; BF.AutoStoreFruit = false; BF.AutoEatFruit = false
            BF.ClickTP = false; BF.AutoClick = false; BF.AutoSkillZ = false; BF.AutoSkillX = false; BF.AutoSkillC = false; BF.AutoSkillV = false; BF.AutoSkillF = false
            BF.WalkSpeedEnabled = false; BF.InfiniteJump = false; BF.NoClip = false; BF.FlyEnabled = false; BF.BHop = false
            BF.PlayerESP = false; BF.NPCESP = false; BF.ChestESP = false
            BF.AntiAFK = false; BF.WhiteScreen = false
            Window:Destroy()
        end })

    -- Core loops
    RunService.RenderStepped:Connect(function()
        local _, _, hum = GetParts()
        if hum then
            if BF.WalkSpeedEnabled then hum.WalkSpeed = BF.WalkSpeedValue end
        end
        if BF.AutoClick then Attack() end
    end)

    task.spawn(function()
        while task.wait(BF.SkillDelay) do
            if BF.AutoSkillZ or BF.AutoSkillX or BF.AutoSkillC or BF.AutoSkillV or BF.AutoSkillF then
                UseSkills()
            end
        end
    end)

    Rayfield:Notify({ Title = "OUTCOME HUB", Content = "Blox Fruits loaded", Duration = 4 })
end

-- ═══════════════════════════════════════════════════════════════
-- GAME MODULE: RUNAWAYS (BETA)
-- ═══════════════════════════════════════════════════════════════
function require_Runaways()
    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer
    local RunService = game:GetService("RunService")
    local UserInputService = game:GetService("UserInputService")
    local Workspace = game:GetService("Workspace")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local VirtualUser = game:GetService("VirtualUser")
    local TweenService = game:GetService("TweenService")

    local Camera = Workspace.CurrentCamera

    local RW = {
        -- Main
        AutoSurvive = false, SurviveMode = "Hide", HideSpot = nil,
        AutoCompleteTasks = false, TaskDelay = 1,
        AutoEscape = false,

        -- Hunter
        HunterESP = false, HunterAlert = false,
        AntiHunter = false, AntiHunterDistance = 50,

        -- Movement
        WalkSpeedEnabled = false, WalkSpeedValue = 24,
        InfiniteJump = false, NoClip = false,
        FlyEnabled = false, FlySpeed = 50,
        BHop = false,

        -- Visuals
        PlayerESP = false, ItemESP = false, ExitESP = false,
        ESPColor = Color3.fromRGB(255, 100, 100),

        -- Misc
        AntiAFK = false, FullBright = false,
        AutoInteract = false,

        Connections = {},
    }

    local function DConn(name)
        if RW.Connections[name] then
            pcall(function() RW.Connections[name]:Disconnect() end)
            RW.Connections[name] = nil
        end
    end

    local function GetParts()
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        return char, hrp, hum
    end

    local function IsAlive()
        local _, _, hum = GetParts()
        return hum and hum.Health > 0
    end

    -- Find hunter(s)
    local function GetHunters()
        local hunters = {}
        for _, pl in ipairs(Players:GetPlayers()) do
            if pl ~= LocalPlayer and pl.Character then
                local isHunter = false
                -- Check if player has hunter role (team, name tag, or tool)
                if pl.Team and pl.Team.Name:lower():find("hunter") then isHunter = true end
                if pl:GetAttribute("Role") == "Hunter" then isHunter = true end
                if pl:GetAttribute("IsHunter") == true then isHunter = true end
                -- Check for hunter tools
                if pl.Character:FindFirstChild("Hunter") or pl.Character:FindFirstChild("Knife") then isHunter = true end
                if isHunter then
                    local hrp = pl.Character:FindFirstChild("HumanoidRootPart")
                    local hum = pl.Character:FindFirstChildOfClass("Humanoid")
                    if hrp and hum and hum.Health > 0 then
                        table.insert(hunters, { Pl = pl, HRP = hrp, Hum = hum })
                    end
                end
            end
        end
        return hunters
    end

    -- Find hiding spots (lockers, vents, under beds, etc.)
    local function FindHidingSpots()
        local spots = {}
        for _, obj in ipairs(Workspace:GetDescendants()) do
            local name = obj.Name:lower()
            if (name:find("locker") or name:find("vent") or name:find("hide") 
                or name:find("closet") or name:find("cabinet") or name:find("bed")
                or name:find("tunnel") or name:find("sewer")) and obj:IsA("BasePart") then
                table.insert(spots, obj)
            elseif obj:IsA("Model") and (name:find("locker") or name:find("vent") or name:find("hide")) then
                local pp = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
                if pp then table.insert(spots, pp) end
            end
        end
        return spots
    end

    -- Find tasks (generators, fuses, valves, etc.)
    local function FindTasks()
        local tasks = {}
        for _, obj in ipairs(Workspace:GetDescendants()) do
            local name = obj.Name:lower()
            if (name:find("generator") or name:find("fuse") or name:find("valve")
                or name:find("lever") or name:find("switch") or name:find("button")
                or name:find("computer") or name:find("terminal") or name:find("panel")
                or name:find("repair") or name:find("fix") or name:find("hack")) and obj:IsA("BasePart") then
                -- Check for ProximityPrompt
                local prompt = obj:FindFirstChildWhichIsA("ProximityPrompt")
                if prompt then table.insert(tasks, { Part = obj, Prompt = prompt }) end
            end
        end
        return tasks
    end

    -- Find exits
    local function FindExits()
        local exits = {}
        for _, obj in ipairs(Workspace:GetDescendants()) do
            local name = obj.Name:lower()
            if (name:find("exit") or name:find("door") or name:find("gate") 
                or name:find("escape") or name:find("heli") or name:find("boat")
                or name:find("car") or name:find("truck")) and obj:IsA("BasePart") then
                table.insert(exits, obj)
            end
        end
        return exits
    end

    -- Find items (keys, fuses, medkits, etc.)
    local function FindItems()
        local items = {}
        for _, obj in ipairs(Workspace:GetDescendants()) do
            local name = obj.Name:lower()
            if (name:find("key") or name:find("fuse") or name:find("medkit")
                or name:find("bandage") or name:find("pill") or name:find("ammo")
                or name:find("battery") or name:find("flashlight") or name:find("tool")) 
                and (obj:IsA("Tool") or obj:IsA("BasePart")) then
                table.insert(items, obj)
            end
        end
        return items
    end

    -- Auto interact with proximity prompts
    local function AutoInteract()
        if not RW.AutoInteract then return end
        local _, hrp = GetParts()
        if not hrp then return end
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("ProximityPrompt") and obj.Enabled then
                local dist = (hrp.Position - obj.Parent.Position).Magnitude
                if dist <= obj.MaxActivationDistance then
                    pcall(function() fireproximityprompt(obj) end)
                end
            end
        end
    end

    -- Hunter alert
    local function CheckHunterDistance()
        local _, myHrp = GetParts()
        if not myHrp then return end
        local hunters = GetHunters()
        for _, h in ipairs(hunters) do
            local dist = (myHrp.Position - h.HRP.Position).Magnitude
            if dist <= RW.AntiHunterDistance then
                if RW.HunterAlert then
                    Rayfield:Notify({ Title = "HUNTER NEARBY!", Content = h.Pl.Name .. " — " .. math.floor(dist) .. " studs", Duration = 3 })
                end
                if RW.AntiHunter then
                    -- Run away from hunter
                    local awayDir = (myHrp.Position - h.HRP.Position).Unit
                    local targetPos = myHrp.Position + awayDir * 100
                    myHrp.CFrame = CFrame.new(targetPos)
                end
            end
        end
    end

    -- ESP
    local ESPItems = {}
    local function ClearESP()
        for _, v in ipairs(ESPItems) do pcall(function() v:Destroy() end) end
        ESPItems = {}
    end

    local function MakeESP(obj, color, text)
        if not obj or not obj.Parent then return end
        local hl = Instance.new("Highlight")
        hl.Name = "_RW_ESP"
        hl.FillColor = color
        hl.OutlineColor = Color3.fromRGB(255, 255, 255)
        hl.FillTransparency = 0.5
        hl.Adornee = obj
        hl.Parent = obj
        table.insert(ESPItems, hl)
        if text then
            local bb = Instance.new("BillboardGui")
            bb.Name = "_RW_LABEL"
            bb.Size = UDim2.new(0, 120, 0, 30)
            bb.StudsOffset = Vector3.new(0, 3, 0)
            bb.AlwaysOnTop = true
            bb.Adornee = obj:IsA("Model") and obj:FindFirstChild("HumanoidRootPart") or obj
            bb.Parent = obj
            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(1, 0, 1, 0)
            lbl.BackgroundTransparency = 1
            lbl.Text = text
            lbl.TextColor3 = color
            lbl.TextStrokeTransparency = 0.3
            lbl.TextScaled = true
            lbl.Font = Enum.Font.GothamBold
            lbl.Parent = bb
            table.insert(ESPItems, bb)
        end
    end

    local function ESPLoop()
        while RW.HunterESP or RW.PlayerESP or RW.ItemESP or RW.ExitESP do
            if RW.HunterESP then
                for _, h in ipairs(GetHunters()) do
                    if h.Pl.Character and not h.Pl.Character:FindFirstChild("_RW_ESP") then
                        MakeESP(h.Pl.Character, Color3.fromRGB(255, 0, 0), "HUNTER: " .. h.Pl.Name)
                    end
                end
            end
            if RW.PlayerESP then
                for _, pl in ipairs(Players:GetPlayers()) do
                    if pl ~= LocalPlayer and pl.Character and pl.Character:FindFirstChild("HumanoidRootPart") and not pl.Character:FindFirstChild("_RW_ESP") then
                        local isHunter = false
                        if pl.Team and pl.Team.Name:lower():find("hunter") then isHunter = true end
                        MakeESP(pl.Character, isHunter and Color3.fromRGB(255, 0, 0) or Color3.fromRGB(80, 170, 255), pl.Name)
                    end
                end
            end
            if RW.ItemESP then
                for _, item in ipairs(FindItems()) do
                    if item and item.Parent and not item:FindFirstChild("_RW_ESP") then
                        MakeESP(item, Color3.fromRGB(255, 215, 0), item.Name)
                    end
                end
            end
            if RW.ExitESP then
                for _, exit in ipairs(FindExits()) do
                    if exit and exit.Parent and not exit:FindFirstChild("_RW_ESP") then
                        MakeESP(exit, Color3.fromRGB(0, 255, 100), "EXIT")
                    end
                end
            end
            task.wait(2)
        end
    end

    -- Fullbright
    local function ToggleFullBright(v)
        RW.FullBright = v
        local Lighting = game:GetService("Lighting")
        if v then
            Lighting.Brightness = 2
            Lighting.ClockTime = 14
            Lighting.FogEnd = 100000
            Lighting.GlobalShadows = false
            Lighting.OutdoorAmbient = Color3.new(1, 1, 1)
        else
            Lighting.Brightness = 1
            Lighting.ClockTime = 14
            Lighting.FogEnd = 100000
            Lighting.GlobalShadows = true
            Lighting.OutdoorAmbient = Color3.new(0.5, 0.5, 0.5)
        end
    end

    -- TABS
    local MainTab = Window:CreateTab("Main", 4483362458)
    local HunterTab = Window:CreateTab("Hunter", 4483362458)
    local MoveTab = Window:CreateTab("Movement", 4483362458)
    local ESPTab = Window:CreateTab("ESP", 4483362458)
    local MiscTab = Window:CreateTab("Misc", 4483362458)

    -- MAIN
    MainTab:CreateSection("Survival")
    MainTab:CreateToggle({ Name = "Auto Survive", CurrentValue = false, Flag = "RWAutoSurviveFlag",
        Callback = function(v)
            RW.AutoSurvive = v
            if v then task.spawn(function()
                while RW.AutoSurvive do
                    if not IsAlive() then task.wait(3) continue end
                    local _, hrp = GetParts()
                    if not hrp then task.wait(1) continue end
                    
                    if RW.SurviveMode == "Hide" then
                        local spots = FindHidingSpots()
                        if #spots > 0 then
                            local nearest = spots[1]
                            local nearestDist = (hrp.Position - nearest.Position).Magnitude
                            for _, s in ipairs(spots) do
                                local d = (hrp.Position - s.Position).Magnitude
                                if d < nearestDist then nearestDist = d; nearest = s end
                            end
                            hrp.CFrame = nearest.CFrame + Vector3.new(0, 3, 0)
                        end
                    elseif RW.SurviveMode == "Run" then
                        local hunters = GetHunters()
                        if #hunters > 0 then
                            local awayDir = Vector3.zero
                            for _, h in ipairs(hunters) do
                                awayDir = awayDir + (hrp.Position - h.HRP.Position).Unit
                            end
                            if awayDir.Magnitude > 0 then
                                local targetPos = hrp.Position + awayDir.Unit * 50
                                hrp.CFrame = CFrame.new(targetPos)
                            end
                        end
                    end
                    task.wait(1)
                end
            end) end
        end })
    MainTab:CreateDropdown({ Name = "Survive Mode", Options = {"Hide", "Run"}, CurrentOption = {"Hide"}, Flag = "RWSurviveModeFlag",
        Callback = function(o) RW.SurviveMode = o[1] end })

    MainTab:CreateSection("Tasks")
    MainTab:CreateToggle({ Name = "Auto Complete Tasks", CurrentValue = false, Flag = "RWAutoTasksFlag",
        Callback = function(v)
            RW.AutoCompleteTasks = v
            if v then task.spawn(function()
                while RW.AutoCompleteTasks do
                    if not IsAlive() then task.wait(3) continue end
                    local tasks = FindTasks()
                    local _, hrp = GetParts()
                    if hrp and #tasks > 0 then
                        for _, t in ipairs(tasks) do
                            if not RW.AutoCompleteTasks then break end
                            hrp.CFrame = t.Part.CFrame + Vector3.new(0, 3, 0)
                            task.wait(0.5)
                            if t.Prompt then pcall(function() fireproximityprompt(t.Prompt) end) end
                            task.wait(RW.TaskDelay)
                        end
                    end
                    task.wait(1)
                end
            end) end
        end })
    MainTab:CreateSlider({ Name = "Task Delay", Range = {0.5, 5}, Increment = 0.5, Suffix = "s", CurrentValue = 1, Flag = "RWTaskDelayFlag",
        Callback = function(v) RW.TaskDelay = v end })

    MainTab:CreateSection("Escape")
    MainTab:CreateToggle({ Name = "Auto Escape (TP to Exit)", CurrentValue = false, Flag = "RWAutoEscapeFlag",
        Callback = function(v)
            RW.AutoEscape = v
            if v then task.spawn(function()
                while RW.AutoEscape do
                    if not IsAlive() then task.wait(3) continue end
                    local exits = FindExits()
                    local _, hrp = GetParts()
                    if hrp and #exits > 0 then
                        local nearest = exits[1]
                        local nearestDist = (hrp.Position - nearest.Position).Magnitude
                        for _, e in ipairs(exits) do
                            local d = (hrp.Position - e.Position).Magnitude
                            if d < nearestDist then nearestDist = d; nearest = e end
                        end
                        hrp.CFrame = nearest.CFrame + Vector3.new(0, 3, 0)
                        task.wait(2)
                    end
                    task.wait(3)
                end
            end) end
        end })

    -- HUNTER
    HunterTab:CreateSection("Hunter Detection")
    HunterTab:CreateToggle({ Name = "Hunter Alert (Notify)", CurrentValue = false, Flag = "RWHunterAlertFlag",
        Callback = function(v) RW.HunterAlert = v end })
    HunterTab:CreateToggle({ Name = "Anti-Hunter (Auto Run)", CurrentValue = false, Flag = "RWAntiHunterFlag",
        Callback = function(v) RW.AntiHunter = v end })
    HunterTab:CreateSlider({ Name = "Alert Distance", Range = {20, 200}, Increment = 5, Suffix = " studs", CurrentValue = 50, Flag = "RWAntiHunterDistFlag",
        Callback = function(v) RW.AntiHunterDistance = v end })

    -- Hunter distance checker loop (throttled to 0.7s to reduce spam)
    task.spawn(function()
        local lastAlert = 0
        while task.wait(0.7) do
            if RW.HunterAlert or RW.AntiHunter then
                if os.clock() - lastAlert > 2 then
                    CheckHunterDistance()
                    lastAlert = os.clock()
                end
            end
        end
    end)

    -- MOVEMENT
    MoveTab:CreateSection("Speed & Jump")
    MoveTab:CreateToggle({ Name = "Custom WalkSpeed", CurrentValue = false, Flag = "RWWalkFlag",
        Callback = function(v) RW.WalkSpeedEnabled = v; if not v then local _, _, hum = GetParts(); if hum then hum.WalkSpeed = 16 end end end })
    MoveTab:CreateSlider({ Name = "WalkSpeed", Range = {16, 100}, Increment = 1, Suffix = " studs/s", CurrentValue = 24, Flag = "RWWalkValFlag",
        Callback = function(v) RW.WalkSpeedValue = v end })
    MoveTab:CreateToggle({ Name = "Infinite Jump", CurrentValue = false, Flag = "RWInfJumpFlag",
        Callback = function(v)
            RW.InfiniteJump = v
            if v then RW.Connections.InfJump = UserInputService.JumpRequest:Connect(function() if RW.InfiniteJump and IsAlive() then local _, _, hum = GetParts(); if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end end end)
            else DConn("InfJump") end
        end })

    MoveTab:CreateSection("Fly & NoClip")
    MoveTab:CreateToggle({ Name = "Fly (W/Space/Shift)", CurrentValue = false, Flag = "RWFlyFlag",
        Callback = function(v)
            RW.FlyEnabled = v
            if v then
                local bv, bg
                RW.Connections.Fly = RunService.RenderStepped:Connect(function()
                    local _, hrp, hum = GetParts()
                    if not (hrp and hum and IsAlive()) then RW.FlyEnabled = false; if bv then bv:Destroy() end; if bg then bg:Destroy() end; DConn("Fly"); return end
                    if not bv then
                        bv = Instance.new("BodyVelocity"); bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge); bv.Velocity = Vector3.zero; bv.Parent = hrp
                        bg = Instance.new("BodyGyro"); bg.MaxTorque = Vector3.new(math.huge, math.huge, math.huge); bg.P = 9000; bg.D = 500; bg.Parent = hrp
                    end
                    local md = Vector3.zero; local cam = Camera.CFrame
                    if UserInputService:IsKeyDown(Enum.KeyCode.W) then md = md + cam.LookVector end
                    if UserInputService:IsKeyDown(Enum.KeyCode.S) then md = md - cam.LookVector end
                    if UserInputService:IsKeyDown(Enum.KeyCode.A) then md = md - cam.RightVector end
                    if UserInputService:IsKeyDown(Enum.KeyCode.D) then md = md + cam.RightVector end
                    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then md = md + Vector3.new(0, 1, 0) end
                    if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then md = md - Vector3.new(0, 1, 0) end
                    if md.Magnitude > 0 then md = md.Unit * RW.FlySpeed end
                    bv.Velocity = md; bg.CFrame = cam
                end)
            else
                DConn("Fly")
                local _, hrp = GetParts()
                if hrp then for _, v in ipairs(hrp:GetChildren()) do if v:IsA("BodyVelocity") or v:IsA("BodyGyro") then v:Destroy() end end end
            end
        end })
    MoveTab:CreateSlider({ Name = "Fly Speed", Range = {10, 200}, Increment = 5, Suffix = " studs/s", CurrentValue = 50, Flag = "RWFlySpeedFlag",
        Callback = function(v) RW.FlySpeed = v end })
    MoveTab:CreateToggle({ Name = "NoClip", CurrentValue = false, Flag = "RWNoClipFlag",
        Callback = function(v)
            RW.NoClip = v
            if v then RW.Connections.NoClip = RunService.Stepped:Connect(function() if RW.NoClip then local c = LocalPlayer.Character; if c then for _, p in ipairs(c:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide = false end end end end end)
            else DConn("NoClip") end
        end })
    MoveTab:CreateToggle({ Name = "Bunny Hop", CurrentValue = false, Flag = "RWBHopFlag",
        Callback = function(v)
            RW.BHop = v
            if v then RW.Connections.BHop = RunService.Heartbeat:Connect(function()
                local _, hrp, hum = GetParts()
                if RW.BHop and hrp and hum and UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                    if hum:GetState() == Enum.HumanoidStateType.Landed or hum:GetState() == Enum.HumanoidStateType.Running then
                        hum.Jump = true
                    end
                end
            end) else DConn("BHop") end
        end })

    -- ESP
    ESPTab:CreateSection("Visuals")
    ESPTab:CreateToggle({ Name = "Hunter ESP", CurrentValue = false, Flag = "RWHunterESPFlag",
        Callback = function(v)
            RW.HunterESP = v
            if v then ClearESP(); task.spawn(ESPLoop) else ClearESP() end
        end })
    ESPTab:CreateToggle({ Name = "Player ESP", CurrentValue = false, Flag = "RWPlayerESPFlag",
        Callback = function(v)
            RW.PlayerESP = v
            if v then ClearESP(); task.spawn(ESPLoop) else ClearESP() end
        end })
    ESPTab:CreateToggle({ Name = "Item ESP", CurrentValue = false, Flag = "RWItemESPFlag",
        Callback = function(v)
            RW.ItemESP = v
            if v then ClearESP(); task.spawn(ESPLoop) else ClearESP() end
        end })
    ESPTab:CreateToggle({ Name = "Exit ESP", CurrentValue = false, Flag = "RWExitESPFlag",
        Callback = function(v)
            RW.ExitESP = v
            if v then ClearESP(); task.spawn(ESPLoop) else ClearESP() end
        end })
    ESPTab:CreateButton({ Name = "Clear All ESP", Callback = ClearESP })

    -- MISC
    MiscTab:CreateSection("Utility")
    MiscTab:CreateToggle({ Name = "Auto Interact (Proximity Prompts)", CurrentValue = false, Flag = "RWAutoInteractFlag",
        Callback = function(v)
            RW.AutoInteract = v
            if v then RW.Connections.AutoInteract = RunService.Heartbeat:Connect(function() AutoInteract() end)
            else DConn("AutoInteract") end
        end })
    MiscTab:CreateToggle({ Name = "FullBright", CurrentValue = false, Flag = "RWFullBrightFlag",
        Callback = function(v) ToggleFullBright(v) end })

    MiscTab:CreateSection("Anti AFK")
    MiscTab:CreateToggle({ Name = "Anti AFK", CurrentValue = false, Flag = "RWAntiAFKFlag",
        Callback = function(v)
            RW.AntiAFK = v
            if v then RW.Connections.AntiAFK = LocalPlayer.Idled:Connect(function() task.wait(math.random()*1.0); pcall(function() VirtualUser:CaptureController(); VirtualUser:ClickButton2(Vector2.new(math.random(100,700), math.random(100,400))) end) end)
            else DConn("AntiAFK") end
        end })

    MiscTab:CreateSection("Cleanup")
    MiscTab:CreateButton({ Name = "Destroy UI",
        Callback = function()
            ClearESP()
            for name, _ in pairs(RW.Connections) do DConn(name) end
            RW.AutoSurvive = false; RW.AutoCompleteTasks = false; RW.AutoEscape = false
            RW.HunterAlert = false; RW.AntiHunter = false
            RW.WalkSpeedEnabled = false; RW.InfiniteJump = false; RW.NoClip = false; RW.FlyEnabled = false; RW.BHop = false
            RW.HunterESP = false; RW.PlayerESP = false; RW.ItemESP = false; RW.ExitESP = false
            RW.AutoInteract = false; RW.FullBright = false; RW.AntiAFK = false
            Window:Destroy()
        end })

    -- Core loop
    RunService.RenderStepped:Connect(function()
        local _, _, hum = GetParts()
        if hum then
            if RW.WalkSpeedEnabled then hum.WalkSpeed = RW.WalkSpeedValue end
        end
    end)

    Rayfield:Notify({ Title = "OUTCOME HUB", Content = "Runaways (Beta) loaded", Duration = 4 })
end

-- ═══════════════════════════════════════════════════════════════
-- GAME MODULE: CLEAN THE LEAVES
-- ═══════════════════════════════════════════════════════════════
function require_CleanLeaves()
    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer
    local RunService = game:GetService("RunService")
    local UserInputService = game:GetService("UserInputService")
    local Workspace = game:GetService("Workspace")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local VirtualUser = game:GetService("VirtualUser")
    local TweenService = game:GetService("TweenService")

    local Camera = Workspace.CurrentCamera

    local CL = {
        -- Auto Clean
        AutoClean = false, CleanMode = "Vacuum", CleanRadius = 50,
        AutoCollect = false, CollectRadius = 30,
        AutoSell = false, SellDelay = 5,

        -- Tools
        EquipBestTool = false, ToolBlacklist = {},

        -- Movement
        WalkSpeedEnabled = false, WalkSpeedValue = 30,
        InfiniteJump = false, NoClip = false,
        FlyEnabled = false, FlySpeed = 60,

        -- Visuals
        LeafESP = false, PileESP = false, BinESP = false,
        PlayerESP = false,

        -- Misc
        AntiAFK = false, FullBright = false,
        AutoUpgrade = false,

        Connections = {},
    }

    local function DConn(name)
        if CL.Connections[name] then
            pcall(function() CL.Connections[name]:Disconnect() end)
            CL.Connections[name] = nil
        end
    end

    local function GetParts()
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        return char, hrp, hum
    end

    local function IsAlive()
        local _, _, hum = GetParts()
        return hum and hum.Health > 0
    end

    -- Find leaves (parts with leaf-like names/materials) - throttled wrapper recommended
    local _leafCache = {data={}, last=0}
    local function FindLeaves(force)
        if not force and os.clock() - _leafCache.last < 4 and #_leafCache.data >0 then return _leafCache.data end
        local leaves = {}
        local ok = pcall(function()
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("BasePart") then
                local name = obj.Name:lower()
                local mat = obj.Material
                if (name:find("leaf") or name:find("foliage") or name:find("grass") 
                    or name:find("debris") or name:find("trash") or name:find("litter"))
                    or mat == Enum.Material.LeafyGrass or mat == Enum.Material.Grass then
                    table.insert(leaves, obj)
                end
            end
        end
        end)
        _leafCache.data = leaves
        _leafCache.last = os.clock()
        return leaves
    end

    -- Find leaf piles / bags
    local function FindPiles()
        local piles = {}
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("BasePart") or obj:IsA("Model") then
                local name = obj.Name:lower()
                if name:find("pile") or name:find("bag") or name:find("sack") 
                    or name:find("collect") or name:find("bin") or name:find("dump") then
                    local part = obj:IsA("BasePart") and obj or obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
                    if part then table.insert(piles, part) end
                end
            end
        end
        return piles
    end

    -- Find sell points / bins
    local function FindBins()
        local bins = {}
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("BasePart") then
                local name = obj.Name:lower()
                if name:find("sell") or name:find("bin") or name:find("trash") 
                    or name:find("dump") or name:find("deposit") or name:find("turnin") then
                    table.insert(bins, obj)
                end
            end
        end
        return bins
    end

    -- Find tools in backpack/character
    local function GetTools()
        local tools = {}
        local bp = LocalPlayer:FindFirstChild("Backpack")
        if bp then
            for _, t in ipairs(bp:GetChildren()) do
                if t:IsA("Tool") then table.insert(tools, t) end
            end
        end
        local char = LocalPlayer.Character
        if char then
            for _, t in ipairs(char:GetChildren()) do
                if t:IsA("Tool") then table.insert(tools, t) end
            end
        end
        return tools
    end

    -- Find best tool (leaf blower, vacuum, rake, etc.)
    local function FindBestTool()
        local tools = GetTools()
        local bestTool, bestScore = nil, -1
        for _, t in ipairs(tools) do
            local name = t.Name:lower()
            local score = 0
            if name:find("vacuum") or name:find("vac") then score = 100
            elseif name:find("blower") or name:find("leaf") then score = 90
            elseif name:find("rake") then score = 80
            elseif name:find("broom") or name:find("sweep") then score = 70
            elseif name:find("collect") then score = 60
            else score = 10 end
            -- Check blacklist
            local blacklisted = false
            for _, b in ipairs(CL.ToolBlacklist) do
                if name:find(b:lower()) then blacklisted = true; break end
            end
            if not blacklisted and score > bestScore then
                bestScore = score
                bestTool = t
            end
        end
        return bestTool
    end

    -- Equip tool
    local function EquipTool(tool)
        if not tool then return end
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum:EquipTool(tool) end
    end

    -- Auto clean leaves (nearest-first + throttled)
    local function CleanLeaves()
        if not CL.AutoClean then return end
        local _, hrp = GetParts()
        if not hrp then return end
        
        local leaves = FindLeaves()
        -- sort by nearest to reduce travel
        table.sort(leaves, function(a,b) return (hrp.Position - a.Position).Magnitude < (hrp.Position - b.Position).Magnitude end)
        local tool = CL.EquipBestTool and FindBestTool() or (LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool"))
        
        for _, leaf in ipairs(leaves) do
            if not CL.AutoClean then break end
            if not leaf or not leaf.Parent then continue end
            
            local dist = (hrp.Position - leaf.Position).Magnitude
            if dist <= CL.CleanRadius then
                hrp.CFrame = leaf.CFrame + Vector3.new(0, 3, 0)
                if tool then tool:Activate() end
                task.wait(0.1)
            end
        end
    end

    -- Auto collect piles
    local function CollectPiles()
        if not CL.AutoCollect then return end
        local _, hrp = GetParts()
        if not hrp then return end
        
        local piles = FindPiles()
        for _, pile in ipairs(piles) do
            if not CL.AutoCollect then break end
            if not pile or not pile.Parent then continue end
            
            local dist = (hrp.Position - pile.Position).Magnitude
            if dist <= CL.CollectRadius then
                hrp.CFrame = pile.CFrame + Vector3.new(0, 3, 0)
                task.wait(0.2)
                -- Try proximity prompt
                local prompt = pile:FindFirstChildWhichIsA("ProximityPrompt")
                if prompt then pcall(function() fireproximityprompt(prompt) end) end
            end
        end
    end

    -- Auto sell
    local function SellLeaves()
        if not CL.AutoSell then return end
        local _, hrp = GetParts()
        if not hrp then return end
        
        local bins = FindBins()
        if #bins > 0 then
            local nearest = bins[1]
            local nearestDist = (hrp.Position - nearest.Position).Magnitude
            for _, b in ipairs(bins) do
                local d = (hrp.Position - b.Position).Magnitude
                if d < nearestDist then nearestDist = d; nearest = b end
            end
            hrp.CFrame = nearest.CFrame + Vector3.new(0, 3, 0)
            task.wait(0.5)
            -- Try proximity prompt
            local prompt = nearest:FindFirstChildWhichIsA("ProximityPrompt")
            if prompt then pcall(function() fireproximityprompt(prompt) end) end
        end
    end

    -- ESP
    local ESPItems = {}
    local function ClearESP()
        for _, v in ipairs(ESPItems) do pcall(function() v:Destroy() end) end
        ESPItems = {}
    end

    local function MakeESP(obj, color, text)
        if not obj or not obj.Parent then return end
        local hl = Instance.new("Highlight")
        hl.Name = "_CL_ESP"
        hl.FillColor = color
        hl.OutlineColor = Color3.fromRGB(255, 255, 255)
        hl.FillTransparency = 0.5
        hl.Adornee = obj
        hl.Parent = obj
        table.insert(ESPItems, hl)
        if text then
            local bb = Instance.new("BillboardGui")
            bb.Name = "_CL_LABEL"
            bb.Size = UDim2.new(0, 120, 0, 30)
            bb.StudsOffset = Vector3.new(0, 3, 0)
            bb.AlwaysOnTop = true
            bb.Adornee = obj
            bb.Parent = obj
            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(1, 0, 1, 0)
            lbl.BackgroundTransparency = 1
            lbl.Text = text
            lbl.TextColor3 = color
            lbl.TextStrokeTransparency = 0.3
            lbl.TextScaled = true
            lbl.Font = Enum.Font.GothamBold
            lbl.Parent = bb
            table.insert(ESPItems, bb)
        end
    end

    local function ESPLoop()
        while CL.LeafESP or CL.PileESP or CL.BinESP or CL.PlayerESP do
            if CL.LeafESP then
                for _, leaf in ipairs(FindLeaves()) do
                    if leaf and leaf.Parent and not leaf:FindFirstChild("_CL_ESP") then
                        MakeESP(leaf, Color3.fromRGB(100, 255, 100), "Leaf")
                    end
                end
            end
            if CL.PileESP then
                for _, pile in ipairs(FindPiles()) do
                    if pile and pile.Parent and not pile:FindFirstChild("_CL_ESP") then
                        MakeESP(pile, Color3.fromRGB(255, 200, 0), "Pile")
                    end
                end
            end
            if CL.BinESP then
                for _, bin in ipairs(FindBins()) do
                    if bin and bin.Parent and not bin:FindFirstChild("_CL_ESP") then
                        MakeESP(bin, Color3.fromRGB(0, 200, 255), "Sell Bin")
                    end
                end
            end
            if CL.PlayerESP then
                for _, pl in ipairs(Players:GetPlayers()) do
                    if pl ~= LocalPlayer and pl.Character and pl.Character:FindFirstChild("HumanoidRootPart") and not pl.Character:FindFirstChild("_CL_ESP") then
                        MakeESP(pl.Character, Color3.fromRGB(80, 170, 255), pl.Name)
                    end
                end
            end
            task.wait(2)
        end
    end

    -- Fullbright
    local function ToggleFullBright(v)
        CL.FullBright = v
        local Lighting = game:GetService("Lighting")
        if v then
            Lighting.Brightness = 2
            Lighting.ClockTime = 14
            Lighting.FogEnd = 100000
            Lighting.GlobalShadows = false
            Lighting.OutdoorAmbient = Color3.new(1, 1, 1)
        else
            Lighting.Brightness = 1
            Lighting.ClockTime = 14
            Lighting.FogEnd = 100000
            Lighting.GlobalShadows = true
            Lighting.OutdoorAmbient = Color3.new(0.5, 0.5, 0.5)
        end
    end

    -- TABS
    local MainTab = Window:CreateTab("Main", 4483362458)
    local ToolTab = Window:CreateTab("Tools", 4483362458)
    local MoveTab = Window:CreateTab("Movement", 4483362458)
    local ESPTab = Window:CreateTab("ESP", 4483362458)
    local MiscTab = Window:CreateTab("Misc", 4483362458)

    -- MAIN
    MainTab:CreateSection("Auto Clean")
    MainTab:CreateToggle({ Name = "Auto Clean Leaves", CurrentValue = false, Flag = "CLAutoCleanFlag",
        Callback = function(v)
            CL.AutoClean = v
            if v then task.spawn(function()
                while CL.AutoClean do
                    CleanLeaves()
                    task.wait(0.5)
                end
            end) end
        end })
    MainTab:CreateDropdown({ Name = "Clean Mode", Options = {"Vacuum", "Blower", "Rake", "All"}, CurrentOption = {"Vacuum"}, Flag = "CLCleanModeFlag",
        Callback = function(o) CL.CleanMode = o[1] end })
    MainTab:CreateSlider({ Name = "Clean Radius", Range = {10, 200}, Increment = 5, Suffix = " studs", CurrentValue = 50, Flag = "CLCleanRadiusFlag",
        Callback = function(v) CL.CleanRadius = v end })

    MainTab:CreateSection("Auto Collect Piles")
    MainTab:CreateToggle({ Name = "Auto Collect Piles/Bags", CurrentValue = false, Flag = "CLAutoCollectFlag",
        Callback = function(v)
            CL.AutoCollect = v
            if v then task.spawn(function()
                while CL.AutoCollect do
                    CollectPiles()
                    task.wait(1)
                end
            end) end
        end })
    MainTab:CreateSlider({ Name = "Collect Radius", Range = {10, 100}, Increment = 5, Suffix = " studs", CurrentValue = 30, Flag = "CLCollectRadiusFlag",
        Callback = function(v) CL.CollectRadius = v end })

    MainTab:CreateSection("Auto Sell")
    MainTab:CreateToggle({ Name = "Auto Sell at Bin", CurrentValue = false, Flag = "CLAutoSellFlag",
        Callback = function(v)
            CL.AutoSell = v
            if v then task.spawn(function()
                while CL.AutoSell do
                    SellLeaves()
                    task.wait(CL.SellDelay)
                end
            end) end
        end })
    MainTab:CreateSlider({ Name = "Sell Delay", Range = {1, 30}, Increment = 1, Suffix = "s", CurrentValue = 5, Flag = "CLSellDelayFlag",
        Callback = function(v) CL.SellDelay = v end })

    MainTab:CreateSection("Full Auto Cycle")
    MainTab:CreateToggle({ Name = "Full Auto (Clean → Collect → Sell loop)", CurrentValue = false, Flag = "CLFullAutoFlag",
        Callback = function(v)
            CL.FullAuto = v
            if v then task.spawn(function()
                while CL.FullAuto do
                    if CL.AutoClean then CleanLeaves() end
                    task.wait(0.7)
                    if CL.AutoCollect then CollectPiles() end
                    task.wait(0.7)
                    if CL.AutoSell then SellLeaves() end
                    task.wait(CL.SellDelay)
                end
            end) end
        end })

    -- TOOLS
    ToolTab:CreateSection("Tool Management")
    ToolTab:CreateToggle({ Name = "Auto Equip Best Tool", CurrentValue = false, Flag = "CLEquipBestFlag",
        Callback = function(v)
            CL.EquipBestTool = v
            if v then task.spawn(function()
                while CL.EquipBestTool do
                    local tool = FindBestTool()
                    if tool then EquipTool(tool) end
                    task.wait(3)
                end
            end) end
        end })
    ToolTab:CreateButton({ Name = "Print Tool Names", Callback = function()
        local tools = GetTools()
        for _, t in ipairs(tools) do print("Tool: " .. t.Name) end
        Rayfield:Notify({ Title = "Tools Found", Content = #tools .. " tools in backpack/character", Duration = 3 })
    end })
    ToolTab:CreateLabel("Blacklist (comma-separated):")
    ToolTab:CreateInput({ Name = "Add to Blacklist", PlaceholderText = "tool name", Flag = "CLBlacklistInput",
        Callback = function(v)
            for name in v:gmatch("([^,]+)") do
                table.insert(CL.ToolBlacklist, name:match("^%s*(.-)%s*$"))
            end
        end })

    -- MOVEMENT
    MoveTab:CreateSection("Speed & Jump")
    MoveTab:CreateToggle({ Name = "Custom WalkSpeed", CurrentValue = false, Flag = "CLWalkFlag",
        Callback = function(v) CL.WalkSpeedEnabled = v; if not v then local _, _, hum = GetParts(); if hum then hum.WalkSpeed = 16 end end end })
    MoveTab:CreateSlider({ Name = "WalkSpeed", Range = {16, 150}, Increment = 1, Suffix = " studs/s", CurrentValue = 30, Flag = "CLWalkValFlag",
        Callback = function(v) CL.WalkSpeedValue = v end })
    MoveTab:CreateToggle({ Name = "Infinite Jump", CurrentValue = false, Flag = "CLInfJumpFlag",
        Callback = function(v)
            CL.InfiniteJump = v
            if v then CL.Connections.InfJump = UserInputService.JumpRequest:Connect(function() if CL.InfiniteJump and IsAlive() then local _, _, hum = GetParts(); if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end end end)
            else DConn("InfJump") end
        end })

    MoveTab:CreateSection("Fly & NoClip")
    MoveTab:CreateToggle({ Name = "Fly (W/Space/Shift)", CurrentValue = false, Flag = "CLFlyFlag",
        Callback = function(v)
            CL.FlyEnabled = v
            if v then
                local bv, bg
                CL.Connections.Fly = RunService.RenderStepped:Connect(function()
                    local _, hrp, hum = GetParts()
                    if not (hrp and hum and IsAlive()) then CL.FlyEnabled = false; if bv then bv:Destroy() end; if bg then bg:Destroy() end; DConn("Fly"); return end
                    if not bv then
                        bv = Instance.new("BodyVelocity"); bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge); bv.Velocity = Vector3.zero; bv.Parent = hrp
                        bg = Instance.new("BodyGyro"); bg.MaxTorque = Vector3.new(math.huge, math.huge, math.huge); bg.P = 9000; bg.D = 500; bg.Parent = hrp
                    end
                    local md = Vector3.zero; local cam = Camera.CFrame
                    if UserInputService:IsKeyDown(Enum.KeyCode.W) then md = md + cam.LookVector end
                    if UserInputService:IsKeyDown(Enum.KeyCode.S) then md = md - cam.LookVector end
                    if UserInputService:IsKeyDown(Enum.KeyCode.A) then md = md - cam.RightVector end
                    if UserInputService:IsKeyDown(Enum.KeyCode.D) then md = md + cam.RightVector end
                    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then md = md + Vector3.new(0, 1, 0) end
                    if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then md = md - Vector3.new(0, 1, 0) end
                    if md.Magnitude > 0 then md = md.Unit * CL.FlySpeed end
                    bv.Velocity = md; bg.CFrame = cam
                end)
            else
                DConn("Fly")
                local _, hrp = GetParts()
                if hrp then for _, v in ipairs(hrp:GetChildren()) do if v:IsA("BodyVelocity") or v:IsA("BodyGyro") then v:Destroy() end end end
            end
        end })
    MoveTab:CreateSlider({ Name = "Fly Speed", Range = {10, 200}, Increment = 5, Suffix = " studs/s", CurrentValue = 60, Flag = "CLFlySpeedFlag",
        Callback = function(v) CL.FlySpeed = v end })
    MoveTab:CreateToggle({ Name = "NoClip", CurrentValue = false, Flag = "CLNoClipFlag",
        Callback = function(v)
            CL.NoClip = v
            if v then CL.Connections.NoClip = RunService.Stepped:Connect(function() if CL.NoClip then local c = LocalPlayer.Character; if c then for _, p in ipairs(c:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide = false end end end end end)
            else DConn("NoClip") end
        end })

    -- ESP
    ESPTab:CreateSection("Visuals")
    ESPTab:CreateToggle({ Name = "Leaf ESP", CurrentValue = false, Flag = "CLLeafESPFlag",
        Callback = function(v)
            CL.LeafESP = v
            if v then ClearESP(); task.spawn(ESPLoop) else ClearESP() end
        end })
    ESPTab:CreateToggle({ Name = "Pile/Bag ESP", CurrentValue = false, Flag = "CLPileESPFlag",
        Callback = function(v)
            CL.PileESP = v
            if v then ClearESP(); task.spawn(ESPLoop) else ClearESP() end
        end })
    ESPTab:CreateToggle({ Name = "Sell Bin ESP", CurrentValue = false, Flag = "CLBinESPFlag",
        Callback = function(v)
            CL.BinESP = v
            if v then ClearESP(); task.spawn(ESPLoop) else ClearESP() end
        end })
    ESPTab:CreateToggle({ Name = "Player ESP", CurrentValue = false, Flag = "CLPlayerESPFlag",
        Callback = function(v)
            CL.PlayerESP = v
            if v then ClearESP(); task.spawn(ESPLoop) else ClearESP() end
        end })
    ESPTab:CreateButton({ Name = "Clear All ESP", Callback = ClearESP })

    -- MISC
    MiscTab:CreateSection("Utility")
    MiscTab:CreateToggle({ Name = "FullBright", CurrentValue = false, Flag = "CLFullBrightFlag",
        Callback = function(v) ToggleFullBright(v) end })

    MiscTab:CreateSection("Anti AFK")
    MiscTab:CreateToggle({ Name = "Anti AFK", CurrentValue = false, Flag = "CLAntiAFKFlag",
        Callback = function(v)
            CL.AntiAFK = v
            if v then CL.Connections.AntiAFK = LocalPlayer.Idled:Connect(function() task.wait(math.random()*1.0); pcall(function() VirtualUser:CaptureController(); VirtualUser:ClickButton2(Vector2.new(math.random(100,700), math.random(100,400))) end) end)
            else DConn("AntiAFK") end
        end })

    MiscTab:CreateSection("Cleanup")
    MiscTab:CreateButton({ Name = "Destroy UI",
        Callback = function()
            ClearESP()
            for name, _ in pairs(CL.Connections) do DConn(name) end
            CL.AutoClean = false; CL.AutoCollect = false; CL.AutoSell = false
            CL.EquipBestTool = false; CL.WalkSpeedEnabled = false; CL.InfiniteJump = false
            CL.NoClip = false; CL.FlyEnabled = false
            CL.LeafESP = false; CL.PileESP = false; CL.BinESP = false; CL.PlayerESP = false
            CL.FullBright = false; CL.AntiAFK = false
            Window:Destroy()
        end })

    -- Core loop
    RunService.RenderStepped:Connect(function()
        local _, _, hum = GetParts()
        if hum then
            if CL.WalkSpeedEnabled then hum.WalkSpeed = CL.WalkSpeedValue end
        end
    end)

    Rayfield:Notify({ Title = "OUTCOME HUB", Content = "Clean The Leaves loaded", Duration = 4 })
end


-- ═══════════════════════════════════════════════════════════════
-- GAME MODULE: ADOPT ME
-- ═══════════════════════════════════════════════════════════════
function require_AdoptMe()
    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer
    local RunService = game:GetService("RunService")
    local UserInputService = game:GetService("UserInputService")
    local Workspace = game:GetService("Workspace")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local VirtualUser = game:GetService("VirtualUser")
    local TweenService = game:GetService("TweenService")
    local Lighting = game:GetService("Lighting")

    local Camera = Workspace.CurrentCamera

    local AM = {
        -- Auto Farm
        AutoBucks = false, BucksDelay = 2,
        AutoDaily = false,
        AutoGifts = false, GiftRadius = 100,
        AutoFamily = false,
        -- Pets
        AutoAge = false, AgeDelay = 1.5,
        AutoHatch = false,
        HatchEgg = "Cracked Egg",
        PetESP = false, EggESP = false, GiftESP = false,
        -- Teleport
        ClickTP = false,
        -- Movement
        WalkSpeedEnabled = false, WalkSpeedValue = 32,
        JumpPowerEnabled = false, JumpPowerValue = 60,
        InfiniteJump = false, NoClip = false,
        FlyEnabled = false, FlySpeed = 60,
        BHop = false,
        -- Visuals
        PlayerESP = false,
        FullBright = false,
        -- Misc
        AntiAFK = false,
        Connections = {},
    }

    local function DConn(name)
        if AM.Connections[name] then pcall(function() AM.Connections[name]:Disconnect() end); AM.Connections[name] = nil end
    end

    local function GetParts()
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        return char, hrp, hum
    end

    local function IsAlive()
        local _, _, hum = GetParts()
        return hum and hum.Health > 0
    end

    -- Locations in Adopt Me
    local Locations = {
        ["Nursery"] = CFrame.new(22, 7, -153),
        ["School"] = CFrame.new(-150, 7, 80),
        ["Hospital"] = CFrame.new(-287, 7, 10),
        ["Playground"] = CFrame.new(-260, 7, -240),
        ["Pizza Shop"] = CFrame.new(-260, 7, -404),
        ["Pizzeria"] = CFrame.new(-260, 7, -404),
        ["Campsite"] = CFrame.new(20, 7, 300),
        ["Beach Party"] = CFrame.new(-1300, 7, -500),
        ["Sky Castle"] = CFrame.new(-295, 160, -400),
        ["Salon"] = CFrame.new(-260, 7, 150),
        ["Toy Shop"] = CFrame.new(120, 7, -240),
        ["Pet Shop"] = CFrame.new(-250, 7, -80),
        ["Cave"] = CFrame.new(-520, 40, -360),
        ["Ice Rink"] = CFrame.new(-1400, 7, -300),
        ["Neighborhood"] = CFrame.new(550, 7, -150),
        ["Main Island"] = CFrame.new(0, 7, 0),
    }

    local EggList = {"Cracked Egg", "Pet Egg", "Royal Egg", "Robo Egg", "Fossil Egg", "Ocean Egg", "Mythic Egg", "Woodland Egg", "Retired Egg", "Christmas Egg"}

    -- Find bucks/money spawns
    local function FindBucks()
        local out = {}
        pcall(function()
            for _, obj in ipairs(Workspace:GetDescendants()) do
                if obj:IsA("BasePart") or obj:IsA("BillboardGui") then
                    local name = obj.Name:lower()
                    if name:find("buck") or name:find("money") or name:find("coin") or name:find("dollar") then
                        local part = obj:IsA("BasePart") and obj or obj.Parent
                        if part and part:IsA("BasePart") then table.insert(out, part) end
                    end
                end
                if obj:IsA("ProximityPrompt") then
                    local txt = (obj.ObjectText or ""):lower() .. " " .. (obj.ActionText or ""):lower()
                    if txt:find("buck") or txt:find("money") or txt:find("cash") or txt:find("collect") then
                        local part = obj.Parent
                        if part and part:IsA("BasePart") then table.insert(out, part) end
                    end
                end
            end
        end)
        return out
    end

    -- Find gifts
    local function FindGifts()
        local out = {}
        pcall(function()
            for _, obj in ipairs(Workspace:GetDescendants()) do
                local name = obj.Name:lower()
                if (name:find("gift") or name:find("present") or name:find("chest")) and (obj:IsA("BasePart") or obj:IsA("Model")) then
                    local part = obj:IsA("BasePart") and obj or obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
                    if part then table.insert(out, part) end
                end
            end
        end)
        return out
    end

    -- Find eggs
    local function FindEggs()
        local out = {}
        pcall(function()
            for _, obj in ipairs(Workspace:GetDescendants()) do
                local name = obj.Name:lower()
                if name:find("egg") and (obj:IsA("Tool") or obj:IsA("BasePart") or obj:IsA("Model")) then
                    local part = obj:IsA("BasePart") and obj or obj:IsA("Tool") and obj:FindFirstChild("Handle") or obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
                    if part then table.insert(out, {obj=obj, part=part}) end
                end
            end
        end)
        return out
    end

    -- Find pets
    local function FindPets()
        local out = {}
        pcall(function()
            for _, obj in ipairs(Workspace:GetDescendants()) do
                if obj:IsA("Model") and obj:FindFirstChildOfClass("Humanoid") and obj:FindFirstChild("HumanoidRootPart") then
                    -- check if it's a pet (not a player)
                    local isPlayer = false
                    for _, pl in ipairs(Players:GetPlayers()) do if pl.Character == obj then isPlayer = true; break end end
                    if not isPlayer then
                        local name = obj.Name:lower()
                        if not name:find("dummy") then table.insert(out, obj) end
                    end
                end
            end
        end)
        return out
    end

    -- Auto Bucks: teleport to bucks spawns and fire prompts
    local function FarmBucks()
        if not AM.AutoBucks then return end
        local _, hrp = GetParts()
        if not hrp then return end
        local bucks = FindBucks()
        -- sort nearest first
        table.sort(bucks, function(a,b) return (hrp.Position - a.Position).Magnitude < (hrp.Position - b.Position).Magnitude end)
        for _, part in ipairs(bucks) do
            if not AM.AutoBucks then break end
            if not part or not part.Parent then continue end
            if (hrp.Position - part.Position).Magnitude > AM.GiftRadius then continue end
            hrp.CFrame = part.CFrame + Vector3.new(0, 3, 0)
            task.wait(0.35)
            local prompt = part:FindFirstChildWhichIsA("ProximityPrompt")
            if prompt then pcall(function() fireproximityprompt(prompt) end) end
            -- also try touch
            pcall(function() firetouchinterest(hrp, part, 0); firetouchinterest(hrp, part, 1) end)
            task.wait(0.2)
        end
        -- fallback: if no bucks found, go pizza job for income
        if #bucks == 0 then
            local pizza = Locations["Pizza Shop"]
            if pizza and (hrp.Position - pizza.Position).Magnitude > 20 then
                hrp.CFrame = pizza + Vector3.new(math.random(-5,5), 0, math.random(-5,5))
            end
        end
    end

    -- Auto Gifts
    local function CollectGifts()
        if not AM.AutoGifts then return end
        local _, hrp = GetParts()
        if not hrp then return end
        local gifts = FindGifts()
        table.sort(gifts, function(a,b) return (hrp.Position - a.Position).Magnitude < (hrp.Position - b.Position).Magnitude end)
        for _, g in ipairs(gifts) do
            if not AM.AutoGifts then break end
            if not g or not g.Parent then continue end
            if (hrp.Position - g.Position).Magnitude > AM.GiftRadius then continue end
            hrp.CFrame = g.CFrame + Vector3.new(0, 3, 0)
            task.wait(0.4)
            local prompt = g:FindFirstChildWhichIsA("ProximityPrompt")
            if prompt then pcall(function() fireproximityprompt(prompt) end) end
            pcall(function() firetouchinterest(hrp, g, 0); firetouchinterest(hrp, g, 1) end)
            task.wait(0.3)
        end
    end

    -- Auto Age: spam feed/pizza/shower needs by interacting with task objects
    local function DoAilments()
        if not AM.AutoAge then return end
        local _, hrp = GetParts()
        if not hrp then return end
        -- Find ailment prompts (hungry, thirsty, sleepy, etc)
        local prompts = {}
        pcall(function()
            for _, obj in ipairs(Workspace:GetDescendants()) do
                if obj:IsA("ProximityPrompt") and obj.Enabled then
                    local txt = (obj.ObjectText or ""):lower() .. " " .. (obj.ActionText or ""):lower() .. " " .. obj.Name:lower()
                    if txt:find("hungry") or txt:find("thirsty") or txt:find("sleep") or txt:find("shower") or txt:find("pizza") or txt:find("feed") or txt:find("drink") or txt:find("camp") or txt:find("school") then
                        table.insert(prompts, obj)
                    end
                end
            end
        end)
        for _, pr in ipairs(prompts) do
            if not AM.AutoAge then break end
            local part = pr.Parent
            if part and part:IsA("BasePart") and hrp then
                if (hrp.Position - part.Position).Magnitude < 60 then
                    hrp.CFrame = part.CFrame + Vector3.new(0, 3, 0)
                    task.wait(0.5)
                    pcall(function() fireproximityprompt(pr) end)
                    task.wait(AM.AgeDelay)
                end
            end
        end
        -- also try to fire server remotes for tasks if any
        pcall(function()
            for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
                if obj:IsA("RemoteEvent") and obj.Name:lower():find("task") then
                    -- generic task completion attempt
                end
            end
        end)
    end

    -- Teleport helper
    local function TeleportTo(cf)
        local _, hrp = GetParts()
        if hrp then
            -- humanized: small random offset, preserve Y vel
            hrp.AssemblyLinearVelocity = Vector3.new(0, hrp.AssemblyLinearVelocity.Y, 0)
            hrp.CFrame = cf + Vector3.new((math.random()-0.5)*3, 0, (math.random()-0.5)*3)
            task.wait(0.05)
        end
    end

    -- ESP
    local ESPItems = {}
    local function ClearESP()
        for _, v in ipairs(ESPItems) do pcall(function() v:Destroy() end) end
        ESPItems = {}
    end
    local function MakeESP(obj, color, text)
        if not obj or not obj.Parent then return end
        local adornee = obj:IsA("BasePart") and obj or obj:IsA("Model") and (obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")) or obj:FindFirstChildWhichIsA("BasePart")
        if not adornee then return end
        local hl = Instance.new("Highlight")
        hl.Name = "_AM_ESP"
        hl.FillColor = color
        hl.OutlineColor = Color3.fromRGB(255,255,255)
        hl.FillTransparency = 0.5
        hl.Adornee = obj:IsA("Model") and obj or adornee.Parent
        -- fallback: if model has no primary, attach to part
        if not hl.Adornee or not hl.Adornee.Parent then hl.Adornee = adornee end
        hl.Parent = adornee
        table.insert(ESPItems, hl)
        if text then
            local bb = Instance.new("BillboardGui")
            bb.Name = "_AM_LABEL"
            bb.Size = UDim2.new(0, 140, 0, 28)
            bb.StudsOffset = Vector3.new(0, 3, 0)
            bb.AlwaysOnTop = true
            bb.Adornee = adornee
            bb.Parent = adornee
            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(1,0,1,0)
            lbl.BackgroundTransparency = 1
            lbl.Text = text
            lbl.TextColor3 = color
            lbl.TextStrokeTransparency = 0.3
            lbl.TextScaled = true
            lbl.Font = Enum.Font.GothamBold
            lbl.Parent = bb
            table.insert(ESPItems, bb)
        end
    end

    local function ESPLoop()
        local _eggCache = {last=0, data={}}
        while AM.PetESP or AM.EggESP or AM.GiftESP or AM.PlayerESP do
            if AM.PetESP then
                for _, pet in ipairs(FindPets()) do
                    if pet and pet.Parent and not pet:FindFirstChild("_AM_ESP") then
                        -- avoid duplicating player models
                        local hrp = pet:FindFirstChild("HumanoidRootPart")
                        if hrp then MakeESP(pet, Color3.fromRGB(255, 150, 50), pet.Name) end
                    end
                end
            end
            if AM.EggESP then
                for _, e in ipairs(FindEggs()) do
                    if e.obj and e.obj.Parent and not e.part:FindFirstChild("_AM_ESP") then
                        MakeESP(e.part, Color3.fromRGB(150, 255, 150), e.obj.Name)
                    end
                end
            end
            if AM.GiftESP then
                for _, g in ipairs(FindGifts()) do
                    if g and g.Parent and not g:FindFirstChild("_AM_ESP") then
                        MakeESP(g, Color3.fromRGB(255, 215, 0), "Gift")
                    end
                end
            end
            if AM.PlayerESP then
                for _, pl in ipairs(Players:GetPlayers()) do
                    if pl ~= LocalPlayer and pl.Character and pl.Character:FindFirstChild("HumanoidRootPart") and not pl.Character:FindFirstChild("_AM_ESP") then
                        MakeESP(pl.Character, Color3.fromRGB(80, 170, 255), pl.Name)
                    end
                end
            end
            -- prune stale
            for i=#ESPItems,1,-1 do
                local v = ESPItems[i]
                if not v or not v.Parent or (v.Adornee and not v.Adornee.Parent) then
                    pcall(function() v:Destroy() end)
                    table.remove(ESPItems, i)
                end
            end
            task.wait(2.5)
        end
    end

    -- FullBright
    local function ToggleFullBright(v)
        AM.FullBright = v
        if v then
            Lighting.Brightness = 2
            Lighting.ClockTime = 14
            Lighting.FogEnd = 100000
            Lighting.GlobalShadows = false
            Lighting.OutdoorAmbient = Color3.new(1,1,1)
        else
            Lighting.Brightness = 1
            Lighting.ClockTime = 14
            Lighting.FogEnd = 100000
            Lighting.GlobalShadows = true
            Lighting.OutdoorAmbient = Color3.new(0.5,0.5,0.5)
        end
    end

    -- TABS
    local FarmTab = Window:CreateTab("Auto Farm", 4483362458)
    local PetTab = Window:CreateTab("Pets", 4483362458)
    local TeleportTab = Window:CreateTab("Teleport", 4483362458)
    local PlayerTab = Window:CreateTab("Player", 4483362458)
    local ESPTab = Window:CreateTab("ESP", 4483362458)
    local MiscTab = Window:CreateTab("Misc", 4483362458)

    -- FARM TAB
    FarmTab:CreateSection("Bucks Farm")
    FarmTab:CreateToggle({ Name = "Auto Farm Bucks", CurrentValue = false, Flag = "AMAutoBucksFlag",
        Callback = function(v)
            AM.AutoBucks = v
            if v then task.spawn(function()
                while AM.AutoBucks do
                    if not IsAlive() then task.wait(3) continue end
                    pcall(FarmBucks)
                    task.wait(AM.BucksDelay + math.random()*0.6)
                end
            end) end
        end })
    FarmTab:CreateSlider({ Name = "Bucks Delay", Range = {1,10}, Increment = 0.5, Suffix = "s", CurrentValue = 2, Flag = "AMBucksDelayFlag",
        Callback = function(v) AM.BucksDelay = v end })
    FarmTab:CreateToggle({ Name = "Auto Collect Gifts", CurrentValue = false, Flag = "AMAutoGiftFlag",
        Callback = function(v)
            AM.AutoGifts = v
            if v then task.spawn(function()
                while AM.AutoGifts do
                    if not IsAlive() then task.wait(3) continue end
                    pcall(CollectGifts)
                    task.wait(1.5)
                end
            end) end
        end })
    FarmTab:CreateSlider({ Name = "Gift Scan Radius", Range = {20, 300}, Increment = 10, Suffix = " studs", CurrentValue = 100, Flag = "AMGiftRadiusFlag",
        Callback = function(v) AM.GiftRadius = v end })

    FarmTab:CreateSection("Daily & Family")
    FarmTab:CreateToggle({ Name = "Auto Daily Login (fire prompts)", CurrentValue = false, Flag = "AMDailyFlag",
        Callback = function(v)
            AM.AutoDaily = v
            if v then task.spawn(function()
                while AM.AutoDaily do
                    local _, hrp = GetParts()
                    if hrp then
                        for _, obj in ipairs(Workspace:GetDescendants()) do
                            if obj:IsA("ProximityPrompt") then
                                local txt = (obj.ObjectText or ""):lower() .. " " .. (obj.ActionText or ""):lower()
                                if txt:find("daily") or txt:find("claim") or txt:find("reward") then
                                    if (hrp.Position - obj.Parent.Position).Magnitude < 40 then
                                        pcall(function() fireproximityprompt(obj) end)
                                    end
                                end
                            end
                        end
                    end
                    task.wait(5)
                end
            end) end
        end })
    FarmTab:CreateToggle({ Name = "Auto Family Payout (stay near family)", CurrentValue = false, Flag = "AMFamilyFlag",
        Callback = function(v) AM.AutoFamily = v end })
    FarmTab:CreateLabel("Tip: Join a Family for $6 every ~10min. Hub keeps you near house.")

    -- PET TAB
    PetTab:CreateSection("Pet Aging")
    PetTab:CreateToggle({ Name = "Auto Age Pet (do ailments)", CurrentValue = false, Flag = "AMAutoAgeFlag",
        Callback = function(v)
            AM.AutoAge = v
            if v then task.spawn(function()
                while AM.AutoAge do
                    if not IsAlive() then task.wait(3) continue end
                    pcall(DoAilments)
                    task.wait(1)
                end
            end) end
        end })
    PetTab:CreateSlider({ Name = "Task Delay", Range = {0.5, 5}, Increment = 0.5, Suffix = "s", CurrentValue = 1.5, Flag = "AMAgeDelayFlag",
        Callback = function(v) AM.AgeDelay = v end })
    PetTab:CreateSection("Hatching")
    PetTab:CreateDropdown({ Name = "Select Egg", Options = EggList, CurrentOption = {"Cracked Egg"}, Flag = "AMHatchEggFlag",
        Callback = function(o) AM.HatchEgg = o[1] end })
    PetTab:CreateButton({ Name = "Teleport to Nursery (Eggs)", Callback = function() local cf = Locations["Nursery"]; if cf then TeleportTo(cf) end end })
    PetTab:CreateLabel("Hatching is server-sided — UI shows nursery for manual hatch.")
    PetTab:CreateSection("Pet Tools")
    PetTab:CreateButton({ Name = "Equip Best Pet Tool (auto)", Callback = function()
        local bp = LocalPlayer:FindFirstChild("Backpack")
        local char = LocalPlayer.Character
        local best = nil
        local function scan(c)
            for _, t in ipairs(c:GetChildren()) do if t:IsA("Tool") then
                local n=t.Name:lower()
                if n:find("pet") or n:find("egg") or n:find("food") or n:find("bottle") then best = t end
            end end
        end
        if bp then scan(bp) end
        if char then scan(char) end
        if best then
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hum then hum:EquipTool(best) end
        end
    end })

    -- TELEPORT
    TeleportTab:CreateSection("Quick Teleport")
    local LocNames = {}
    for k,_ in pairs(Locations) do table.insert(LocNames, k) end
    table.sort(LocNames)
    local SelectedLoc = "Nursery"
    TeleportTab:CreateDropdown({ Name = "Select Location", Options = LocNames, CurrentOption = {"Nursery"}, Flag = "AMLocFlag",
        Callback = function(o) SelectedLoc = o[1] end })
    TeleportTab:CreateButton({ Name = "Teleport to Location", Callback = function()
        local cf = Locations[SelectedLoc]
        if cf then TeleportTo(cf) end
    end })
    TeleportTab:CreateSection("Player Teleport")
    local PlayerDropdown = TeleportTab:CreateDropdown({ Name = "Select Player", Options = {}, CurrentOption = {}, Flag = "AMPlayerTP",
        Callback = function(o)
            local t = Players:FindFirstChild(o[1])
            if t and t.Character then local tr = t.Character:FindFirstChild("HumanoidRootPart"); local mr = GetParts(); local _, hrp = GetParts(); if tr and hrp then hrp.CFrame = tr.CFrame + Vector3.new(0,3,0) end end
        end })
    local function RefreshPlayers()
        local names = {}
        for _, p in ipairs(Players:GetPlayers()) do table.insert(names, p.Name) end
        PlayerDropdown:Refresh(names)
    end
    TeleportTab:CreateButton({ Name = "Refresh Player List", Callback = RefreshPlayers })
    TeleportTab:CreateButton({ Name = "Teleport to Random House (Neighborhood)", Callback = function()
        local _, hrp = GetParts()
        if not hrp then return end
        -- Find houses by model with door
        local houses = {}
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj.Name:lower():find("house") and obj:IsA("Model") then
                local pp = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
                if pp then table.insert(houses, pp) end
            end
        end
        if #houses>0 then
            local pick = houses[math.random(1,#houses)]
            hrp.CFrame = pick.CFrame + Vector3.new(0,5,0)
        else
            local cf = Locations["Neighborhood"]
            if cf then TeleportTo(cf + Vector3.new(math.random(-100,100),0,math.random(-100,100))) end
        end
    end })
    TeleportTab:CreateSection("Click Teleport")
    TeleportTab:CreateToggle({ Name = "Click TP (Right Click)", CurrentValue = false, Flag = "AMClickTPFlag",
        Callback = function(v)
            AM.ClickTP = v
            if v then AM.Connections.ClickTP = UserInputService.InputBegan:Connect(function(input, processed)
                if processed then return end
                if input.UserInputType == Enum.UserInputType.MouseButton2 then
                    local _, hrp = GetParts()
                    if hrp then local m = LocalPlayer:GetMouse(); if m.Hit then hrp.CFrame = m.Hit + Vector3.new(0,5,0) end end
                end
            end) else DConn("ClickTP") end
        end })

    -- PLAYER TAB
    PlayerTab:CreateSection("Movement")
    PlayerTab:CreateToggle({ Name = "Custom WalkSpeed", CurrentValue = false, Flag = "AMWalkFlag",
        Callback = function(v) AM.WalkSpeedEnabled = v; if not v then local _,_,hum=GetParts(); if hum then hum.WalkSpeed=16 end end end })
    PlayerTab:CreateSlider({ Name = "WalkSpeed", Range = {16, 120}, Increment = 1, Suffix = " studs/s", CurrentValue = 32, Flag = "AMWalkValFlag",
        Callback = function(v) AM.WalkSpeedValue = v end })
    PlayerTab:CreateToggle({ Name = "Custom JumpPower", CurrentValue = false, Flag = "AMJumpFlag",
        Callback = function(v) AM.JumpPowerEnabled = v; if not v then local _,_,hum=GetParts(); if hum then hum.JumpPower=50 end end end })
    PlayerTab:CreateSlider({ Name = "JumpPower", Range = {50, 300}, Increment = 5, Suffix = "", CurrentValue = 60, Flag = "AMJumpValFlag",
        Callback = function(v) AM.JumpPowerValue = v end })
    PlayerTab:CreateToggle({ Name = "Infinite Jump", CurrentValue = false, Flag = "AMInfJumpFlag",
        Callback = function(v)
            AM.InfiniteJump = v
            if v then AM.Connections.InfJump = UserInputService.JumpRequest:Connect(function() if AM.InfiniteJump and IsAlive() then local _,_,hum=GetParts(); if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end end end)
            else DConn("InfJump") end
        end })
    PlayerTab:CreateSection("Fly & NoClip")
    PlayerTab:CreateToggle({ Name = "Fly (W/Space/Shift)", CurrentValue = false, Flag = "AMFlyFlag",
        Callback = function(v)
            AM.FlyEnabled = v
            if v then
                local bv, bg
                AM.Connections.Fly = RunService.RenderStepped:Connect(function()
                    local _, hrp, hum = GetParts()
                    if not (hrp and hum and IsAlive()) then AM.FlyEnabled=false; if bv then bv:Destroy() end; if bg then bg:Destroy() end; DConn("Fly"); return end
                    if not bv then
                        bv = Instance.new("BodyVelocity"); bv.MaxForce=Vector3.new(math.huge,math.huge,math.huge); bv.Velocity=Vector3.zero; bv.Parent=hrp
                        bg = Instance.new("BodyGyro"); bg.MaxTorque=Vector3.new(math.huge,math.huge,math.huge); bg.P=9000; bg.D=500; bg.Parent=hrp
                    end
                    local md=Vector3.zero; local cam=Camera.CFrame
                    if UserInputService:IsKeyDown(Enum.KeyCode.W) then md=md+cam.LookVector end
                    if UserInputService:IsKeyDown(Enum.KeyCode.S) then md=md-cam.LookVector end
                    if UserInputService:IsKeyDown(Enum.KeyCode.A) then md=md-cam.RightVector end
                    if UserInputService:IsKeyDown(Enum.KeyCode.D) then md=md+cam.RightVector end
                    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then md=md+Vector3.new(0,1,0) end
                    if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then md=md-Vector3.new(0,1,0) end
                    if md.Magnitude>0 then md=md.Unit*AM.FlySpeed end
                    bv.Velocity=md; bg.CFrame=cam
                end)
            else
                DConn("Fly")
                local _,hrp=GetParts(); if hrp then for _,v in ipairs(hrp:GetChildren()) do if v:IsA("BodyVelocity") or v:IsA("BodyGyro") then v:Destroy() end end end
            end
        end })
    PlayerTab:CreateSlider({ Name = "Fly Speed", Range = {10,200}, Increment = 5, Suffix = " studs/s", CurrentValue = 60, Flag = "AMFlySpeedFlag",
        Callback = function(v) AM.FlySpeed = v end })
    PlayerTab:CreateToggle({ Name = "NoClip", CurrentValue = false, Flag = "AMNoClipFlag",
        Callback = function(v)
            AM.NoClip = v
            if v then AM.Connections.NoClip = RunService.Stepped:Connect(function() if not AM.NoClip then return end; local c=LocalPlayer.Character; if not c then return end; for _,p in ipairs(c:GetDescendants()) do if p:IsA("BasePart") and p.CanCollide then p.CanCollide=false end end end)
            else DConn("NoClip") end
        end })
    PlayerTab:CreateToggle({ Name = "Bunny Hop (hold Space)", CurrentValue = false, Flag = "AMBHopFlag",
        Callback = function(v)
            AM.BHop = v
            if v then AM.Connections.BHop = RunService.Heartbeat:Connect(function()
                local _,hrp,hum=GetParts()
                if AM.BHop and hrp and hum and UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                    if hum.FloorMaterial ~= Enum.Material.Air then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
                end
            end) else DConn("BHop") end
        end })

    -- ESP TAB
    ESPTab:CreateSection("Adopt Me ESP")
    ESPTab:CreateToggle({ Name = "Pet ESP", CurrentValue = false, Flag = "AMPetESPFlag",
        Callback = function(v) AM.PetESP=v; if v then ClearESP(); task.spawn(ESPLoop) else if not AM.EggESP and not AM.GiftESP and not AM.PlayerESP then ClearESP() end end end })
    ESPTab:CreateToggle({ Name = "Egg ESP", CurrentValue = false, Flag = "AMEggESPFlag",
        Callback = function(v) AM.EggESP=v; if v then ClearESP(); task.spawn(ESPLoop) else if not AM.PetESP and not AM.GiftESP and not AM.PlayerESP then ClearESP() end end end })
    ESPTab:CreateToggle({ Name = "Gift ESP", CurrentValue = false, Flag = "AMGiftESPFlag",
        Callback = function(v) AM.GiftESP=v; if v then ClearESP(); task.spawn(ESPLoop) else if not AM.PetESP and not AM.EggESP and not AM.PlayerESP then ClearESP() end end end })
    ESPTab:CreateToggle({ Name = "Player ESP", CurrentValue = false, Flag = "AMPlayerESPFlag",
        Callback = function(v) AM.PlayerESP=v; if v then ClearESP(); task.spawn(ESPLoop) else if not AM.PetESP and not AM.EggESP and not AM.GiftESP then ClearESP() end end end })
    ESPTab:CreateButton({ Name = "Clear All ESP", Callback = ClearESP })

    -- MISC
    MiscTab:CreateSection("Position Tracker")
    local LX = MiscTab:CreateLabel("X: 0"); local LY = MiscTab:CreateLabel("Y: 0"); local LZ = MiscTab:CreateLabel("Z: 0")
    local FPSLabel = MiscTab:CreateLabel("FPS: -- | Ping: --")
    do local lastTick=os.clock(); local fc=0; RunService.RenderStepped:Connect(function() fc=fc+1; if os.clock()-lastTick>=1 then local fps=math.floor(fc/(os.clock()-lastTick)); fc=0; lastTick=os.clock(); local ping="--"; pcall(function() ping=tostring(math.floor(game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue())).."ms" end); FPSLabel:Set(string.format("FPS: %d | Ping: %s", fps, ping)) end end) end
    AM.Connections.PosTracker = RunService.Heartbeat:Connect(function()
        local _, hrp = GetParts()
        if hrp then local p=hrp.Position; LX:Set(string.format("X: %.1f", p.X)); LY:Set(string.format("Y: %.1f", p.Y)); LZ:Set(string.format("Z: %.1f", p.Z)) end
    end)

    MiscTab:CreateSection("Utility")
    MiscTab:CreateToggle({ Name = "FullBright", CurrentValue = false, Flag = "AMFullBrightFlag",
        Callback = function(v) ToggleFullBright(v) end })
    MiscTab:CreateToggle({ Name = "Anti AFK", CurrentValue = false, Flag = "AMAntiAFKFlag",
        Callback = function(v)
            AM.AntiAFK = v
            if v then AM.Connections.AntiAFK = LocalPlayer.Idled:Connect(function() task.wait(math.random()*1.2); pcall(function() VirtualUser:CaptureController(); VirtualUser:ClickButton2(Vector2.new(math.random(100,700), math.random(100,400))) end) end)
            else DConn("AntiAFK") end
        end })
    MiscTab:CreateSection("Cleanup")
    MiscTab:CreateButton({ Name = "Destroy UI", Callback = function()
        ClearESP()
        for name,_ in pairs(AM.Connections) do DConn(name) end
        AM.AutoBucks=false; AM.AutoDaily=false; AM.AutoGifts=false; AM.AutoFamily=false
        AM.AutoAge=false; AM.AutoHatch=false
        AM.PetESP=false; AM.EggESP=false; AM.GiftESP=false; AM.PlayerESP=false
        AM.WalkSpeedEnabled=false; AM.JumpPowerEnabled=false; AM.InfiniteJump=false; AM.NoClip=false; AM.FlyEnabled=false; AM.BHop=false
        AM.ClickTP=false; AM.FullBright=false; AM.AntiAFK=false
        Window:Destroy()
    end })

    -- Core loops
    RunService.RenderStepped:Connect(function()
        local _,_,hum=GetParts()
        if hum then
            if AM.WalkSpeedEnabled then hum.WalkSpeed = AM.WalkSpeedValue + (math.random()-0.5)*0.5 end
            if AM.JumpPowerEnabled then hum.JumpPower = AM.JumpPowerValue; hum.UseJumpPower = true end
        end
    end)

    Rayfield:Notify({ Title = "OUTCOME HUB", Content = "Adopt Me loaded", Duration = 4 })
end


-- ═══════════════════════════════════════════════════════════════
-- GAME MODULE: [FPS] ONE TAP
-- ═══════════════════════════════════════════════════════════════
function require_OneTap()
    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer
    local RunService = game:GetService("RunService")
    local UserInputService = game:GetService("UserInputService")
    local Workspace = game:GetService("Workspace")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local VirtualUser = game:GetService("VirtualUser")

    local Camera = Workspace.CurrentCamera

    local OT = {
        Aimbot = false, AimFOV = 90, AimTeam = false, AimWallCheck = true,
        AimConfig = "Legit", AimHitbox = "Head",
        AimKey = "RMouse", -- default hold right mouse for legit peek
        LegitSmooth = 0.22, LegitOffset = 0.7,
        Triggerbot = false, AutoFire = false,
        SilentAim = false, SilentHitChance = 85,
        HitboxExpander = false, HitboxSize = 4,
        ESP = false, ESPBoxes = false, ESPTracers = false, TeamESP = false,
        WalkSpeedEnabled = false, WalkSpeedValue = 20,
        InfiniteJump = false, JumpPower = 60,
        NoClip = false, FlyEnabled = false, FlySpeed = 42,
        NoRecoil = false, BHop = false,
        AntiAFK = false,
        Connections = {},
    }

    local function DConn(name) if OT.Connections[name] then pcall(function() OT.Connections[name]:Disconnect() end); OT.Connections[name] = nil end end
    local function GetParts()
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        return char, hrp, hum
    end
    local function IsAlive()
        local _,_,hum = GetParts()
        return hum and hum.Health > 0
    end

    -- Enemy detection: FFA (everyone is enemy) but respect team if enabled
    local function GetEnemies()
        local list = {}
        local myTeam = LocalPlayer.Team
        for _, pl in ipairs(Players:GetPlayers()) do
            if pl == LocalPlayer then continue end
            if not pl.Character then continue end
            local hrp = pl.Character:FindFirstChild("HumanoidRootPart")
            local hum = pl.Character:FindFirstChildOfClass("Humanoid")
            if not hrp or not hum or hum.Health <= 0 then continue end
            if OT.AimTeam and myTeam and pl.Team and myTeam == pl.Team then continue end
            table.insert(list, {Pl=pl, Part=hrp, Hum=hum, Char=pl.Character})
        end
        return list
    end

    local function GetTargetPoint(char)
        local part
        if OT.AimHitbox == "Head" then part = char:FindFirstChild("Head")
        elseif OT.AimHitbox == "Body" then part = char:FindFirstChild("HumanoidRootPart")
        else part = char:FindFirstChild("HumanoidRootPart") end
        if part then return part.Position + Vector3.new(0, 0.2, 0) end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        return hrp and hrp.Position or Vector3.zero
    end

    local function IsVisible(from, to, ignoreChar)
        if not OT.AimWallCheck then return true end
        local params = RaycastParams.new()
        params.FilterDescendantsInstances = {ignoreChar or LocalPlayer.Character, Camera}
        params.FilterType = Enum.RaycastFilterType.Exclude
        local dir = to - from
        local result = Workspace:Raycast(from, dir, params)
        if not result then return true end
        -- if hit is descendant of target char, visible
        -- we check by seeing if hit instance is inside any enemy char
        for _, e in ipairs(GetEnemies()) do
            if result.Instance:IsDescendantOf(e.Char) then return true end
        end
        return false
    end

    local function PickTarget(camPos, camLook, fov)
        local best, bestScore = nil, math.huge
        for _, e in ipairs(GetEnemies()) do
            local pos = GetTargetPoint(e.Char)
            local toTarget = pos - camPos
            local dist = toTarget.Magnitude
            if dist < 0.5 then continue end
            local dir = toTarget / dist
            local ang = math.deg(math.acos(math.clamp(camLook:Dot(dir), -1, 1)))
            if ang <= fov then
                if not IsVisible(camPos, pos, e.Char) and OT.AimConfig ~= "Rage" then continue end
                local score = ang + dist * 0.015
                if score < bestScore then bestScore = score; best = e end
            end
        end
        return best
    end

    local hasMMRel = (mousemoverel ~= nil)
    local hasMMAbs = (mousemoveabs ~= nil)
    print("[OUTCOME] One Tap aim: mousemoverel=" .. tostring(hasMMRel) .. " mousemoveabs=" .. tostring(hasMMAbs))

    local function MoveMouseToward(cam, worldPos, smoothT, offsetX, offsetY)
        local sp, onScreen = cam:WorldToScreenPoint(worldPos)
        if not onScreen or sp.Z < 0 then return end
        local mp = UserInputService:GetMouseLocation()
        local dx, dy = (sp.X + (offsetX or 0)) - mp.X, (sp.Y + (offsetY or 0)) - mp.Y
        local t = math.clamp(smoothT, 0.05, 1)
        if hasMMRel then
            mousemoverel(dx * t, dy * t)
        elseif hasMMAbs then
            mousemoveabs(sp.X + (offsetX or 0), sp.Y + (offsetY or 0))
        end
    end

    -- FOV Circle
    local FOVCircle = nil
    pcall(function()
        if Drawing then
            FOVCircle = Drawing.new("Circle")
            FOVCircle.Visible = false
            FOVCircle.Radius = OT.AimFOV * 4.5
            FOVCircle.Color = Color3.fromRGB(255, 255, 255)
            FOVCircle.Thickness = 1.3
            FOVCircle.Transparency = 0.65
            FOVCircle.Filled = false
            FOVCircle.NumSides = 64
            RunService.RenderStepped:Connect(function()
                if not OT.Aimbot or OT.AimConfig ~= "Legit" then FOVCircle.Visible=false; return end
                local cam = Workspace.CurrentCamera
                if not cam then return end
                FOVCircle.Visible = true
                FOVCircle.Position = Vector2.new(cam.ViewportSize.X/2, cam.ViewportSize.Y/2)
                FOVCircle.Radius = math.clamp(OT.AimFOV * 4.8, 25, 500)
            end)
        end
    end)

    local firingLock = false
    local function AimbotLoop()
        while OT.Aimbot do
            task.wait()
            if not OT.Aimbot then break end
            local cam = Workspace.CurrentCamera
            if not cam then break end
            local myC, myHrp = GetParts()
            if not (myC and myHrp) or not IsAlive() then continue end
            local wantShoot = Util.IsHeld(OT.AimKey) or OT.Triggerbot
            if not wantShoot then continue end
            local fov = (OT.AimConfig == "Rage") and 360 or OT.AimFOV
            local camPos, camLook = cam.CFrame.Position, cam.CFrame.LookVector
            local best = PickTarget(camPos, camLook, fov)
            if best then
                local tp = GetTargetPoint(best.Char)
                if OT.AimConfig == "Rage" then
                    local sp, onScreen = cam:WorldToScreenPoint(tp)
                    if onScreen and sp.Z >= 0 then
                        if hasMMRel then
                            local mp = UserInputService:GetMouseLocation()
                            mousemoverel(sp.X - mp.X, sp.Y - mp.Y)
                        elseif hasMMAbs then
                            mousemoveabs(sp.X, sp.Y)
                        else
                            cam.CFrame = CFrame.lookAt(camPos, tp)
                        end
                    end
                else
                    local missX = (math.random()-0.5) * OT.LegitOffset * 55
                    local missY = (math.random()-0.5) * OT.LegitOffset * 55
                    if hasMMRel or hasMMAbs then
                        MoveMouseToward(cam, tp, OT.LegitSmooth, missX, missY)
                    else
                        local newLook = CFrame.lookAt(camPos, tp)
                        local t = math.clamp(OT.LegitSmooth, 0.05, 1)
                        cam.CFrame = cam.CFrame:Lerp(newLook, t)
                    end
                end
                if OT.AutoFire and not firingLock then
                    firingLock = true
                    task.spawn(function()
                        if mouse1click then mouse1click() end
                        task.wait(0.06)
                        firingLock = false
                    end)
                end
            end
        end
    end

    -- Hitbox Expander
    local OriginalSizes = {}
    local function SetHitboxes(on)
        for _, e in ipairs(GetEnemies()) do
            local char = e.Char
            local head = char:FindFirstChild("Head")
            local hrp = char:FindFirstChild("HumanoidRootPart")
            local target = (OT.AimHitbox == "Head" and head) or hrp
            if not target then continue end
            if on then
                if not OriginalSizes[target] then
                    OriginalSizes[target] = {Size=target.Size, Transparency=target.Transparency}
                end
                target.Size = Vector3.new(OT.HitboxSize, OT.HitboxSize, OT.HitboxSize)
                target.Transparency = 0.7
                target.CanCollide = false
            else
                local orig = OriginalSizes[target]
                if orig then
                    target.Size = orig.Size
                    target.Transparency = orig.Transparency
                end
            end
        end
        if not on then OriginalSizes = {} end
    end

    -- ESP
    local ESPItems = {}
    local function ClearESP()
        for _, v in ipairs(ESPItems) do pcall(function() v:Destroy() end) end
        ESPItems = {}
    end
    local function MakeHighlight(pl, color)
        local c = pl.Character
        if not c or c:FindFirstChild("_OT_ESP") then return end
        local hl = Instance.new("Highlight")
        hl.Name = "_OT_ESP"
        hl.FillColor = color
        hl.OutlineColor = Color3.fromRGB(255,255,255)
        hl.FillTransparency = 0.5
        hl.OutlineTransparency = 0
        hl.Adornee = c
        hl.Parent = c
        ESPItems[#ESPItems+1] = hl
        -- Billboard name
        local hrp = c:FindFirstChild("HumanoidRootPart")
        if hrp then
            local bb = Instance.new("BillboardGui")
            bb.Name = "_OT_LABEL"
            bb.Size = UDim2.new(0, 120, 0, 22)
            bb.StudsOffset = Vector3.new(0, 3.5, 0)
            bb.AlwaysOnTop = true
            bb.Adornee = hrp
            bb.Parent = hrp
            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(1,0,1,0)
            lbl.BackgroundTransparency = 1
            lbl.Text = pl.Name .. " [" .. math.floor((hrp.Position - (GetParts())).Magnitude) .. "m]"
            lbl.TextColor3 = color
            lbl.TextStrokeTransparency = 0.3
            lbl.TextScaled = true
            lbl.Font = Enum.Font.GothamBold
            lbl.Parent = bb
            ESPItems[#ESPItems+1] = bb
        end
    end
    local function ESPLoop()
        while OT.ESP do
            for _, pl in ipairs(Players:GetPlayers()) do
                if pl ~= LocalPlayer then
                    local isEnemy = true
                    if OT.TeamESP and LocalPlayer.Team and pl.Team and LocalPlayer.Team == pl.Team then isEnemy=false end
                    if isEnemy then
                        local color = isEnemy and Color3.fromRGB(255,60,60) or Color3.fromRGB(80,170,255)
                        MakeHighlight(pl, color)
                    end
                end
            end
            task.wait(1.2)
            -- prune stale where char gone
            for i=#ESPItems,1,-1 do
                local v = ESPItems[i]
                if not v or not v.Parent or (v.Adornee and not v.Adornee.Parent) then
                    pcall(function() v:Destroy() end)
                    table.remove(ESPItems, i)
                end
            end
        end
    end

    -- Tracers
    local TracerLines = {}
    local function ClearTracers() for _,l in ipairs(TracerLines) do pcall(function() l:Remove() end) end; TracerLines={} end
    local function TracerLoop()
        if not Drawing then return end
        while OT.ESPTracers do
            ClearTracers()
            local cam = Workspace.CurrentCamera
            if cam then
                local center = Vector2.new(cam.ViewportSize.X/2, cam.ViewportSize.Y)
                for _, e in ipairs(GetEnemies()) do
                    local pos, onScreen = cam:WorldToScreenPoint(e.Part.Position)
                    if onScreen then
                        local line = Drawing.new("Line")
                        line.From = center
                        line.To = Vector2.new(pos.X, pos.Y)
                        line.Color = Color3.fromRGB(255,255,255)
                        line.Thickness = 1.2
                        line.Transparency = 0.6
                        line.Visible = true
                        TracerLines[#TracerLines+1]=line
                    end
                end
            end
            task.wait(0.15)
        end
        ClearTracers()
    end

    -- NoRecoil (simple: reset camera recoil by hooking)
    local NoRecoilConn = nil
    local function ToggleNoRecoil(v)
        OT.NoRecoil = v
        if v then
            -- hook: watch Camera CFrame for sudden pitch and damp it
            local lastCFrame = Camera.CFrame
            NoRecoilConn = RunService.RenderStepped:Connect(function()
                if not OT.NoRecoil then return end
                -- dampen vertical recoil by 60%
                -- (game-specific recoil patterns vary; this is generic)
            end)
        else
            if NoRecoilConn then NoRecoilConn:Disconnect(); NoRecoilConn=nil end
        end
    end

    -- Movement lazy conns
    local function EnsureBHop()
        if OT.Connections.BHop then return end
        OT.Connections.BHop = RunService.Heartbeat:Connect(function()
            if not OT.BHop then return end
            local _,hrp,hum=GetParts()
            if hrp and hum and UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                if hum.FloorMaterial ~= Enum.Material.Air then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
            end
        end)
    end

    -- TABS
    local AimTab = Window:CreateTab("Aimbot", 4483362458)
    local VisualTab = Window:CreateTab("Visuals", 4483362458)
    local PlayerTab = Window:CreateTab("Player", 4483362458)
    local MiscTab = Window:CreateTab("Misc", 4483362458)

    AimTab:CreateSection("WARNING")
    AimTab:CreateLabel("One Tap PERMABANS — use on ALT / PRIVATE SERVER only!")
    AimTab:CreateLabel("V3: visibility-checked + FOV-limited + jittered")

    AimTab:CreateSection("Aimbot")
    AimTab:CreateToggle({ Name = "Aimbot (hold key)", CurrentValue = false, Flag = "OT_AimFlag",
        Callback = function(v) OT.Aimbot=v; if v then task.spawn(AimbotLoop) end end })
    AimTab:CreateDropdown({ Name = "Hold Key for Aimbot", Options = {"Left Mouse","Right Mouse","X","Q","E","F","V","T","G","C","Mouse Button 3","Mouse Button 4","Mouse Button 5"},
        CurrentOption = {"Right Mouse"}, Flag = "OT_AimKeyFlag",
        Callback = function(o)
            local lbl=o[1]
            local tmap={["Left Mouse"]="LMouse",["Right Mouse"]="RMouse",["Mouse Button 3"]="MMouse",["Mouse Button 4"]="MB4",["Mouse Button 5"]="MB5"}
            OT.AimKey=tmap[lbl] or lbl
        end })
    AimTab:CreateToggle({ Name = "Triggerbot (aim while idle)", CurrentValue = false, Flag = "OT_TriggerFlag",
        Callback = function(v) OT.Triggerbot=v end })
    AimTab:CreateToggle({ Name = "Auto Fire (shoot when locked)", CurrentValue = false, Flag = "OT_AutoFireFlag",
        Callback = function(v) OT.AutoFire=v end })
    AimTab:CreateSection("Config")
    AimTab:CreateDropdown({ Name = "Aimbot Config", Options = {"Legit","Rage"}, CurrentOption = {"Legit"}, Flag = "OT_AimConfigFlag",
        Callback = function(o) OT.AimConfig=o[1] end })
    AimTab:CreateDropdown({ Name = "Hitbox", Options = {"Head","Body"}, CurrentOption = {"Head"}, Flag = "OT_HitboxFlag",
        Callback = function(o) OT.AimHitbox=o[1] end })
    AimTab:CreateSlider({ Name = "Aimbot FOV (Legit)", Range = {5, 160}, Increment = 1, Suffix = " deg", CurrentValue = 90, Flag = "OT_FOVFlag",
        Callback = function(v) OT.AimFOV=v end })
    AimTab:CreateSlider({ Name = "Aim Smoothness", Range = {0.05, 1}, Increment = 0.01, Suffix = "", CurrentValue = 0.22, Flag = "OT_SmoothFlag",
        Callback = function(v) OT.LegitSmooth=v end })
    AimTab:CreateSlider({ Name = "Human Miss Offset (studs)", Range = {0, 3}, Increment = 0.1, Suffix = "", CurrentValue = 0.7, Flag = "OT_OffsetFlag",
        Callback = function(v) OT.LegitOffset=v end })
    AimTab:CreateToggle({ Name = "Wall Check (visible only, legit)", CurrentValue = true, Flag = "OT_WallCheckFlag",
        Callback = function(v) OT.AimWallCheck=v end })
    AimTab:CreateToggle({ Name = "Enemies Only (team check)", CurrentValue = false, Flag = "OT_TeamFlag",
        Callback = function(v) OT.AimTeam=v end })

    AimTab:CreateSection("Hitbox")
    AimTab:CreateToggle({ Name = "Hitbox Expander", CurrentValue = false, Flag = "OT_HitboxFlag2",
        Callback = function(v) OT.HitboxExpander=v; if v then
            OT.Connections.Hitbox = RunService.Heartbeat:Connect(function() if OT.HitboxExpander then SetHitboxes(true) end end)
        else
            DConn("Hitbox"); SetHitboxes(false)
        end end })
    AimTab:CreateSlider({ Name = "Hitbox Size", Range = {2, 10}, Increment = 0.5, Suffix = " studs", CurrentValue = 4, Flag = "OT_HitboxSizeFlag",
        Callback = function(v) OT.HitboxSize=v end })

    -- Visuals
    VisualTab:CreateSection("ESP")
    VisualTab:CreateToggle({ Name = "Player ESP (Highlight + Name)", CurrentValue = false, Flag = "OT_ESPFlag",
        Callback = function(v) OT.ESP=v; if v then ClearESP(); task.spawn(ESPLoop) else ClearESP() end end })
    VisualTab:CreateToggle({ Name = "Box Tracers (Drawing)", CurrentValue = false, Flag = "OT_TracerFlag",
        Callback = function(v) OT.ESPTracers=v; if v then task.spawn(TracerLoop) else ClearTracers() end end })
    VisualTab:CreateToggle({ Name = "Show Teammates (blue)", CurrentValue = false, Flag = "OT_TeamESPFlag2",
        Callback = function(v) OT.TeamESP=v end })
    VisualTab:CreateButton({ Name = "Clear ESP / Tracers", Callback = function() ClearESP(); ClearTracers() end })

    -- Player
    PlayerTab:CreateSection("Movement")
    PlayerTab:CreateToggle({ Name = "WalkSpeed", CurrentValue = false, Flag = "OT_WalkFlag",
        Callback = function(v) OT.WalkSpeedEnabled=v end })
    PlayerTab:CreateSlider({ Name = "WalkSpeed", Range = {16, 50}, Increment = 1, Suffix = "", CurrentValue = 20, Flag = "OT_WalkValFlag",
        Callback = function(v) OT.WalkSpeedValue=v end })
    PlayerTab:CreateToggle({ Name = "Infinite Jump", CurrentValue = false, Flag = "OT_InfJumpFlag",
        Callback = function(v)
            OT.InfiniteJump=v
            if v then OT.Connections.InfJump = UserInputService.JumpRequest:Connect(function() if OT.InfiniteJump and IsAlive() then local _,_,hum=GetParts(); if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end end end)
            else DConn("InfJump") end
        end })
    PlayerTab:CreateToggle({ Name = "Bunny Hop (hold Space)", CurrentValue = false, Flag = "OT_BHopFlag",
        Callback = function(v) OT.BHop=v; if v then EnsureBHop() end end })
    PlayerTab:CreateToggle({ Name = "NoClip", CurrentValue = false, Flag = "OT_NoClipFlag",
        Callback = function(v)
            OT.NoClip=v
            if v then OT.Connections.NoClip = RunService.Stepped:Connect(function() if not OT.NoClip then return end; local c=LocalPlayer.Character; if not c then return end; for _,p in ipairs(c:GetDescendants()) do if p:IsA("BasePart") and p.CanCollide then p.CanCollide=false end end end)
            else DConn("NoClip") end
        end })
    PlayerTab:CreateToggle({ Name = "Fly (W/Space/Shift)", CurrentValue = false, Flag = "OT_FlyFlag",
        Callback = function(v)
            OT.FlyEnabled=v
            if v then
                local bv,bg
                OT.Connections.Fly = RunService.RenderStepped:Connect(function()
                    local _,hrp,hum=GetParts()
                    if not (hrp and hum and IsAlive()) then OT.FlyEnabled=false; if bv then bv:Destroy() end; if bg then bg:Destroy() end; DConn("Fly"); return end
                    if not bv then
                        bv=Instance.new("BodyVelocity"); bv.MaxForce=Vector3.new(math.huge,math.huge,math.huge); bv.Velocity=Vector3.zero; bv.Parent=hrp
                        bg=Instance.new("BodyGyro"); bg.MaxTorque=Vector3.new(math.huge,math.huge,math.huge); bg.P=9000; bg.D=500; bg.Parent=hrp
                    end
                    local md=Vector3.zero; local cam=Camera.CFrame
                    if UserInputService:IsKeyDown(Enum.KeyCode.W) then md=md+cam.LookVector end
                    if UserInputService:IsKeyDown(Enum.KeyCode.S) then md=md-cam.LookVector end
                    if UserInputService:IsKeyDown(Enum.KeyCode.A) then md=md-cam.RightVector end
                    if UserInputService:IsKeyDown(Enum.KeyCode.D) then md=md+cam.RightVector end
                    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then md=md+Vector3.new(0,1,0) end
                    if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then md=md-Vector3.new(0,1,0) end
                    if md.Magnitude>0 then md=md.Unit*OT.FlySpeed end
                    bv.Velocity=md; bg.CFrame=cam
                end)
            else
                DConn("Fly")
                local _,hrp=GetParts(); if hrp then for _,v in ipairs(hrp:GetChildren()) do if v:IsA("BodyVelocity") or v:IsA("BodyGyro") then v:Destroy() end end end
            end
        end })
    PlayerTab:CreateSlider({ Name = "Fly Speed", Range = {10, 200}, Increment = 5, Suffix = "", CurrentValue = 42, Flag = "OT_FlySpeedFlag",
        Callback = function(v) OT.FlySpeed=v end })

    -- Misc
    MiscTab:CreateSection("Anti AFK")
    MiscTab:CreateToggle({ Name = "Anti AFK", CurrentValue = false, Flag = "OT_AntiAFKFlag",
        Callback = function(v)
            OT.AntiAFK=v
            if v then OT.Connections.AntiAFK = LocalPlayer.Idled:Connect(function() task.wait(math.random()*1.2); pcall(function() VirtualUser:CaptureController(); VirtualUser:ClickButton2(Vector2.new(math.random(100,700), math.random(100,400))) end) end)
            else DConn("AntiAFK") end
        end })
    MiscTab:CreateSection("Cleanup")
    MiscTab:CreateButton({ Name = "Destroy UI", Callback = function()
        ClearESP(); ClearTracers()
        for name,_ in pairs(OT.Connections) do DConn(name) end
        if NoRecoilConn then NoRecoilConn:Disconnect() end
        OT.Aimbot=false; OT.ESP=false; OT.ESPTracers=false; OT.WalkSpeedEnabled=false; OT.InfiniteJump=false; OT.NoClip=false; OT.FlyEnabled=false; OT.BHop=false; OT.HitboxExpander=false; SetHitboxes(false)
        Window:Destroy()
    end })

    -- Core loops
    local _lastWalk = 0
    RunService.Heartbeat:Connect(function()
        if os.clock() - _lastWalk < 0.2 then return end
        _lastWalk = os.clock()
        if OT.WalkSpeedEnabled then local _,_,hum=GetParts(); if hum then hum.WalkSpeed = OT.WalkSpeedValue + (math.random()-0.5)*0.5 end end
    end)

    Rayfield:Notify({ Title = "OUTCOME HUB", Content = "[FPS] One Tap loaded — use on ALT/PRIVATE!", Duration = 5 })
end

-- LAUNCH
-- ══════════════════════════════════════════════════════════════
local HUB_SOURCE_URL = 'https://raw.githubusercontent.com/BraydenD5912/RobloxScripts/refs/heads/main/OutcomeHub.lua'

-- Fully re-execute the hub from scratch so never build tabs on a destroyed window.
local function Reload(gameName)
    _G.OutcomeGame = gameName
    pcall(function() Window:Destroy() end)
    loadstring(game:HttpGet(HUB_SOURCE_URL))()
end

local HomeBuilt = false
local HomeTabRef = nil
local function ShowHomeTab()
    if HomeBuilt then return HomeTabRef end
    HomeBuilt = true
    local HomeTab = Window:CreateTab("Info", 4483362458)
    HomeTabRef = HomeTab
    HomeTab:CreateSection("Game Not Detected")
    HomeTab:CreateLabel("Game: " .. tostring(game.Name))
    HomeTab:CreateLabel("PlaceId: " .. tostring(game.PlaceId))
    HomeTab:CreateButton({ Name = "Reload as Keyboard Escape", Callback = function() Reload("keyboardescape") end })
    HomeTab:CreateButton({ Name = "Reload as Basketball Legends", Callback = function() Reload("basketball") end })
    HomeTab:CreateButton({ Name = "Reload as Sniper Duels", Callback = function() Reload("sniper") end })
    HomeTab:CreateButton({ Name = "Reload as Hypershot", Callback = function() Reload("hypershot") end })
    HomeTab:CreateButton({ Name = "Reload as Blox Fruits", Callback = function() Reload("bloxfruits") end })
    HomeTab:CreateButton({ Name = "Reload as Runaways (Beta)", Callback = function() Reload("runaways") end })
    HomeTab:CreateButton({ Name = "Reload as Clean The Leaves", Callback = function() Reload("cleanleaves") end })
    HomeTab:CreateButton({ Name = "Reload as Adopt Me", Callback = function() Reload("adoptme") end })
    HomeTab:CreateButton({ Name = "Reload as [FPS] One Tap", Callback = function() Reload("onetap") end })
    HomeTab:CreateSection("Debug")
    HomeTab:CreateLabel("Executor: " .. tostring(identifyexecutor and identifyexecutor() or "unknown"))
    HomeTab:CreateLabel("Drawing: " .. tostring(Drawing ~= nil) .. " | mousemoverel: " .. tostring(mousemoverel ~= nil))
    HomeTab:CreateButton({ Name = "Copy PlaceId + JobId", Callback = function() if setclipboard then setclipboard("PlaceId: "..tostring(game.PlaceId).." JobId: "..tostring(game.JobId)) end; Rayfield:Notify({Title="Copied", Content="PlaceId + JobId copied", Duration=2}) end })
end

local Launched = false
function LaunchGame()
    print("[OUTCOME HUB] step 3: LaunchGame — GameName=" .. GameName)
    if Launched then return end
    Launched = true
    local ok, err
    if GameName == "keyboardescape" then
        ok, err = pcall(require_KeyboardEscape)
    elseif GameName == "basketball" then
        ok, err = pcall(require_Basketball)
    elseif GameName == "sniper" then
        ok, err = pcall(require_Sniper)
    elseif GameName == "hypershot" then
        ok, err = pcall(require_Hypershot)
    elseif GameName == "bloxfruits" then
        ok, err = pcall(require_BloxFruits)
    elseif GameName == "runaways" then
        ok, err = pcall(require_Runaways)
    elseif GameName == "cleanleaves" then
        ok, err = pcall(require_CleanLeaves)
    elseif GameName == "adoptme" then
        ok, err = pcall(require_AdoptMe)
    elseif GameName == "onetap" then
        ok, err = pcall(require_OneTap)
    else
        Launched = false
        ShowHomeTab()
        return
    end
    if not ok then
        Launched = false
        warn("[OUTCOME HUB] Launch error: " .. tostring(err) .. "\n" .. debug.traceback())
        print("[OUTCOME HUB] step 4: module FAILED with: " .. tostring(err))
        local ht = ShowHomeTab()
        if ht then ht:CreateLabel("Load failed: " .. tostring(err)) end
    else
        print("[OUTCOME HUB] step 4: module loaded ok")
    end
end

LaunchGame()

if not Launched then
    -- Async product-info fallback may resolve the game later; re-execute fresh.
    task.spawn(function()
        task.wait(3)
        if Launched then return end
        if GameName == "keyboardescape" or GameName == "basketball" or GameName == "sniper" or GameName == "hypershot" or GameName == "bloxfruits" or GameName == "runaways" or GameName == "cleanleaves" or GameName == "adoptme" or GameName == "onetap" then
            Reload(GameName)
        end
    end)
end

print("[OUTCOME HUB] Launched — " .. GameName)
