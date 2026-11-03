--[[
    SCHOOL WAR [V2] Crows Zero - Toolkit
    PlaceId   : 77160678446964
    Universe  : 10170333176
    Creator   : Rnat_666
    Build     : 2026-11-03

    Cara pakai:
        loadstring(game:HttpGet("URL_RAW_SchoolWar.lua"))()

    Sebagian besar fitur bersifat adaptif: nama remote dicari otomatis dari pola.
    Kalau auto attack / auto capture tidak jalan, jalankan tab Recon, lalu isi
    override remote lewat getgenv().SCHOOLWAR_CONFIG (lihat README.md).

    Butuh executor dengan akses penuh: loadstring, CoreGui, Drawing (opsional),
    setclipboard (opsional), hookmetamethod/namecall (untuk recon).
--]]

--!nocheck

if getgenv and getgenv().SchoolWar_Unload then
    pcall(getgenv().SchoolWar_Unload)
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local TeleportService = game:GetService("TeleportService")
local StarterGui = game:GetService("StarterGui")
local VirtualUser = game:GetService("VirtualUser")
local HttpService = game:GetService("HttpService")

local LP = Players.LocalPlayer
local PLACE_ID = 77160678446964
local UNIVERSE_ID = 10170333176

local OVERRIDE = (getgenv and getgenv().SCHOOLWAR_CONFIG) or {}

local CFG = {
    AutoAttack       = false,
    KillAura         = false,
    AutoEquip        = true,
    AttackDelay      = 0.18,
    AuraRange        = 18,
    AutoCapture      = false,
    CaptureDelay     = 1.0,
    AutoReward       = false,
    RewardDelay      = 8.0,
    AutoRespawn      = true,
    WalkSpeed        = 24,
    JumpPower        = 60,
    Fly              = false,
    FlySpeed         = 60,
    Noclip           = false,
    InfiniteJump     = false,
    ESP              = false,
    Tracers          = false,
    Fullbright       = false,
    AntiAFK          = true,
    ShowUI           = true,
    AttackArgs       = OVERRIDE.AttackArgs or "tool",
    AuraArgs         = OVERRIDE.AuraArgs or "targetchar,char,pos",
    CaptureArgs      = OVERRIDE.CaptureArgs or "pos,char",
}

local conns = {}
local esp = {}
local tracers = {}
local running = true
local gui
local espFolder

local function stealthEnabled()
    return OVERRIDE.Stealth ~= false
end

local function uiParent()
    if stealthEnabled() then
        local ok, hidden = pcall(function()
            return gethui and gethui()
        end)
        if ok and hidden then
            return hidden
        end
    end
    return LP:FindFirstChild("PlayerGui") or game:GetService("CoreGui")
end

local function protectGui(target)
    pcall(function()
        if syn and syn.protect_gui then
            syn.protect_gui(target)
        end
    end)
    pcall(function()
        if protect_gui then
            protect_gui(target)
        end
    end)
    pcall(function()
        if protectgui then
            protectgui(target)
        end
    end)
end

local loadDelay = tonumber(OVERRIDE.LoadDelay) or 0
if loadDelay > 0 then
    task.wait(loadDelay)
end

local function notify(title, text)
    pcall(function()
        StarterGui:SetCore("SendNotification", { Title = title, Text = text, Duration = 4 })
    end)
    print(("[SchoolWar] %s: %s"):format(title, text))
end

local function bind(inst, evt, fn)
    local c = inst[evt]:Connect(fn)
    table.insert(conns, c)
    return c
end

local function getChar()
    return LP.Character
end

local function getHum()
    local c = getChar()
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function getRoot()
    local c = getChar()
    return c and c:FindFirstChild("HumanoidRootPart")
end

-- ============================================================
--  Resolver remote
-- ============================================================

local ATK_WORDS = { "attack", "hit", "punch", "kick", "m1", "combo", "damage", "swing", "strike", "melee", "fight", "skill" }
local CAP_WORDS = { "capture", "claim", "territory", "flag", "zone", "sector", "conquer", "takeover", "point", "base" }
local REW_WORDS = { "reward", "daily", "claim", "spin", "chest", "gift", "bonus", "login", "mission", "quest" }
local SPAWN_WORDS = { "respawn", "spawn", "revive", "restart" }

local function isRemote(inst)
    if inst:IsA("RemoteEvent") or inst:IsA("RemoteFunction") then
        return true
    end
    local ok, yes = pcall(function()
        return inst:IsA("UnreliableRemoteEvent")
    end)
    return ok and yes
end

local function pathOf(inst)
    local parts = {}
    local node = inst
    while node and node ~= game do
        table.insert(parts, 1, node.Name)
        node = node.Parent
    end
    return table.concat(parts, ".")
end

local function resolvePath(path)
    if type(path) ~= "string" or path == "" then
        return nil
    end
    local node = game
    for part in string.gmatch(path, "[^%.]+") do
        if part ~= "game" then
            node = node:FindFirstChild(part)
        end
        if not node then
            return nil
        end
    end
    return node
end

local function scoreName(name, words)
    local lower = string.lower(name)
    for i, word in ipairs(words) do
        if string.find(lower, word, 1, true) then
            return #words - i + 1
        end
    end
    return 0
end

local function collectRemotes()
    local found = {}
    local roots = {
        game:GetService("ReplicatedStorage"),
        game:GetService("ReplicatedFirst"),
        LP,
    }
    for _, root in ipairs(roots) do
        local ok = pcall(function()
            for _, inst in ipairs(root:GetDescendants()) do
                if isRemote(inst) then
                    table.insert(found, inst)
                end
            end
        end)
        if not ok then
            break
        end
    end
    return found
end

local function rankedRemotes(words, limit)
    local list = {}
    for _, remote in ipairs(collectRemotes()) do
        local score = scoreName(remote.Name, words) + scoreName(pathOf(remote), words)
        if score > 0 then
            table.insert(list, { remote = remote, score = score })
        end
    end
    table.sort(list, function(a, b)
        return a.score > b.score
    end)
    local out = {}
    for i, entry in ipairs(list) do
        if limit and i > limit then
            break
        end
        table.insert(out, entry.remote)
    end
    return out
end

local cache = { attack = {}, capture = {}, reward = {}, respawn = {} }

local function refreshCache()
    cache.attack = rankedRemotes(ATK_WORDS, 8)
    cache.capture = rankedRemotes(CAP_WORDS, 6)
    cache.reward = rankedRemotes(REW_WORDS, 4)
    cache.respawn = rankedRemotes(SPAWN_WORDS, 3)
end

local function withOverride(key, fallback)
    local path = OVERRIDE[key]
    local inst = path and resolvePath(path)
    if inst and isRemote(inst) then
        return { inst }
    end
    return fallback
end

local function attackRemotes()
    return withOverride("AttackRemote", cache.attack)
end

local function captureRemotes()
    return withOverride("CaptureRemote", cache.capture)
end

local function rewardRemotes()
    return withOverride("RewardRemote", cache.reward)
end

local function respawnRemotes()
    return withOverride("RespawnRemote", cache.respawn)
end

-- ============================================================
--  Arg builder
-- ============================================================

local function buildArgs(expr, ctx)
    local packed = table.pack()
    for token in string.gmatch(expr or "", "[^,%s]+") do
        local value
        local lower = string.lower(token)
        if lower == "tool" then
            value = ctx.tool
        elseif lower == "char" then
            value = ctx.char
        elseif lower == "root" then
            value = ctx.root
        elseif lower == "target" then
            value = ctx.target
        elseif lower == "targetchar" then
            value = ctx.targetChar
        elseif lower == "pos" or lower == "vector" then
            value = ctx.pos
        elseif lower == "name" then
            value = ctx.target and ctx.target.Name
        elseif lower == "true" then
            value = true
        elseif lower == "false" then
            value = false
        elseif lower == "nil" or lower == "none" then
            value = nil
        else
            value = tonumber(token) or token
        end
        packed.n = packed.n + 1
        packed[packed.n] = value
    end
    return packed
end

local function fireRemote(remote, packed)
    if not remote or not remote.Parent then
        return
    end
    local args = table.unpack(packed, 1, packed.n or 0)
    pcall(function()
        if remote:IsA("RemoteFunction") then
            remote:InvokeServer(args)
        else
            remote:FireServer(args)
        end
    end)
end

local function currentTool()
    local c = getChar()
    if not c then
        return nil
    end
    local tool = c:FindFirstChildOfClass("Tool")
    if not tool then
        local backpack = LP:FindFirstChild("Backpack")
        tool = backpack and backpack:FindFirstChildOfClass("Tool")
    end
    return tool
end

local function makeContext(target)
    local c = getChar()
    local root = getRoot()
    return {
        char = c,
        root = root,
        tool = currentTool(),
        target = target,
        targetChar = target and target.Character,
        pos = root and root.Position or Vector3.zero,
    }
end

-- ============================================================
--  Zone finder (auto capture)
-- ============================================================

local zoneCache, zoneCacheAt = {}, 0

local function refreshZones()
    if os.clock() - zoneCacheAt < 5 and #zoneCache > 0 then
        return
    end
    zoneCacheAt = os.clock()
    table.clear(zoneCache)
    pcall(function()
        for _, inst in ipairs(workspace:GetDescendants()) do
            if inst:IsA("BasePart") and scoreName(inst.Name, CAP_WORDS) > 0 then
                table.insert(zoneCache, inst)
            end
        end
    end)
end

local function nearestZone(maxDist)
    local root = getRoot()
    if not root then
        return nil, nil
    end
    refreshZones()
    local best, bestDist
    for _, inst in ipairs(zoneCache) do
        if inst.Parent then
            local d = (inst.Position - root.Position).Magnitude
            if d <= maxDist and (not bestDist or d < bestDist) then
                best, bestDist = inst, d
            end
        end
    end
    return best, bestDist
end

-- ============================================================
--  Combat
-- ============================================================

local function nearestPlayer(maxDist)
    local root = getRoot()
    if not root then
        return nil, math.huge
    end
    local best, bestDist = nil, maxDist
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP and plr.Character then
            local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
            local hum = plr.Character:FindFirstChildOfClass("Humanoid")
            if hrp and hum and hum.Health > 0 then
                local d = (hrp.Position - root.Position).Magnitude
                if d < bestDist then
                    best, bestDist = plr, d
                end
            end
        end
    end
    return best, bestDist
end

local function facePosition(pos)
    local root = getRoot()
    if root and pos then
        local flat = Vector3.new(pos.X, root.Position.Y, pos.Z)
        if (flat - root.Position).Magnitude > 0.1 then
            root.CFrame = CFrame.lookAt(root.Position, flat)
        end
    end
end

local function equipTool()
    local c = getChar()
    local hum = getHum()
    if not c or not hum then
        return nil
    end
    local tool = c:FindFirstChildOfClass("Tool")
    if tool then
        return tool
    end
    local backpack = LP:FindFirstChild("Backpack")
    if backpack then
        for _, item in ipairs(backpack:GetChildren()) do
            if item:IsA("Tool") then
                pcall(function()
                    hum:EquipTool(item)
                end)
                return item
            end
        end
    end
    return nil
end

local function attackTick(target)
    local ctx = makeContext(target)
    if CFG.AutoEquip then
        ctx.tool = equipTool() or ctx.tool
    end
    if ctx.tool then
        pcall(function()
            ctx.tool:Activate()
        end)
    end
    for _, remote in ipairs(attackRemotes()) do
        fireRemote(remote, buildArgs(CFG.AttackArgs, ctx))
    end
    pcall(function()
        VirtualUser:ClickButton1(Vector2.new(workspace.CurrentCamera.ViewportSize.X / 2, workspace.CurrentCamera.ViewportSize.Y / 2))
    end)
end

task.spawn(function()
    while running do
        if CFG.AutoAttack then
            local target
            if CFG.KillAura then
                target = nearestPlayer(CFG.AuraRange)
                if target and target.Character then
                    local hrp = target.Character:FindFirstChild("HumanoidRootPart")
                    facePosition(hrp and hrp.Position)
                end
            end
            pcall(attackTick, target)
            task.wait(math.max(0.05, CFG.AttackDelay))
        else
            task.wait(0.1)
        end
    end
end)

-- Kill aura terpisah supaya tetap jalan walau AutoAttack mati
task.spawn(function()
    while running do
        if CFG.KillAura and not CFG.AutoAttack then
            local target = nearestPlayer(CFG.AuraRange)
            if target and target.Character then
                local hrp = target.Character:FindFirstChild("HumanoidRootPart")
                facePosition(hrp and hrp.Position)
                local ctx = makeContext(target)
                ctx.tool = equipTool() or ctx.tool
                if ctx.tool then
                    pcall(function()
                        ctx.tool:Activate()
                    end)
                end
                for _, remote in ipairs(attackRemotes()) do
                    fireRemote(remote, buildArgs(CFG.AuraArgs, ctx))
                end
            end
            task.wait(math.max(0.05, CFG.AttackDelay))
        else
            task.wait(0.1)
        end
    end
end)

task.spawn(function()
    while running do
        if CFG.AutoCapture then
            local zone = nearestZone(400)
            if zone then
                local ctx = makeContext()
                ctx.pos = zone.Position
                ctx.tool = currentTool()
                for _, remote in ipairs(captureRemotes()) do
                    fireRemote(remote, buildArgs(CFG.CaptureArgs, ctx))
                end
            end
            task.wait(CFG.CaptureDelay)
        else
            task.wait(0.2)
        end
    end
end)

task.spawn(function()
    while running do
        if CFG.AutoReward then
            for _, remote in ipairs(rewardRemotes()) do
                fireRemote(remote, buildArgs("", makeContext()))
            end
            task.wait(CFG.RewardDelay)
        else
            task.wait(1)
        end
    end
end)

task.spawn(function()
    while running do
        if CFG.AutoRespawn then
            local c = getChar()
            local hum = getHum()
            if (not c or not hum or hum.Health <= 0) then
                for _, remote in ipairs(respawnRemotes()) do
                    fireRemote(remote, buildArgs("", makeContext()))
                end
                pcall(function()
                    LP:LoadCharacter()
                end)
                task.wait(3)
            end
        end
        task.wait(1)
    end
end)

-- ============================================================
--  Movement
-- ============================================================

local function applyWalkSpeed(value)
    local hum = getHum()
    if hum then
        hum.WalkSpeed = value
    end
end

local function applyJumpPower(value)
    local hum = getHum()
    if hum then
        hum.UseJumpPower = true
        hum.JumpPower = value
    end
end

local flyBV, flyBG, flyConn

local function stopFly()
    if flyConn then
        flyConn:Disconnect()
        flyConn = nil
    end
    if flyBV then flyBV:Destroy() end
    if flyBG then flyBG:Destroy() end
    flyBV, flyBG = nil, nil
    local hum = getHum()
    if hum then
        hum:ChangeState(Enum.HumanoidStateType.Landed)
    end
end

local function startFly()
    stopFly()
    local root = getRoot()
    if not root then
        return
    end
    flyBV = Instance.new("BodyVelocity")
    flyBV.Name = "SW_Fly"
    flyBV.MaxForce = Vector3.new(1e5, 1e5, 1e5)
    flyBV.Velocity = Vector3.zero
    flyBV.Parent = root
    flyBG = Instance.new("BodyGyro")
    flyBG.Name = "SW_Gyro"
    flyBG.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
    flyBG.P = 1e4
    flyBG.Parent = root
    flyConn = RunService.RenderStepped:Connect(function()
        local cam = workspace.CurrentCamera
        if not flyBV or not flyBV.Parent then
            return
        end
        local dir = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir += cam.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir -= cam.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir -= cam.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir += cam.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir += Vector3.yAxis end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then dir -= Vector3.yAxis end
        flyBV.Velocity = dir.Magnitude > 0 and dir.Unit * CFG.FlySpeed or Vector3.zero
        flyBG.CFrame = cam.CFrame
    end)
    table.insert(conns, flyConn)
end

local noclipConn
local function startNoclip()
    noclipConn = RunService.Stepped:Connect(function()
        local c = getChar()
        if c then
            for _, part in ipairs(c:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
            end
        end
    end)
end

local function stopNoclip()
    if noclipConn then
        noclipConn:Disconnect()
        noclipConn = nil
    end
    local c = getChar()
    if c then
        for _, part in ipairs(c:GetDescendants()) do
            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                part.CanCollide = true
            end
        end
    end
end

bind(UserInputService, "JumpRequest", function()
    if CFG.InfiniteJump then
        local hum = getHum()
        if hum then
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end
end)

-- ============================================================
--  Visual
-- ============================================================

local function ensureEspFolder()
    if espFolder and espFolder.Parent then
        return espFolder
    end
    espFolder = Instance.new("Folder")
    espFolder.Name = "HUD"
    espFolder.Parent = gui or LP:FindFirstChild("PlayerGui")
    return espFolder
end

local function removeESP(plr)
    local data = esp[plr]
    if data then
        for i = 1, 4 do
            if data[i] then
                pcall(function()
                    data[i]:Destroy()
                end)
            end
        end
        esp[plr] = nil
    end
    local line = tracers[plr]
    if line then
        pcall(function() line:Remove() end)
        tracers[plr] = nil
    end
end

local function colorForHealth(hum)
    local ratio = 1
    if hum then
        ratio = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
    end
    return Color3.fromHSV(ratio * 0.33, 1, 1)
end

local function applyESP(plr)
    if plr == LP or esp[plr] then
        return
    end
    local c = plr.Character
    if not c then
        return
    end
    local hum = c:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then
        return
    end
    local highlight = Instance.new("Highlight")
    highlight.Name = "SW_HL"
    highlight.FillTransparency = 0.55
    highlight.OutlineTransparency = 0
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Adornee = c
    highlight.FillColor = colorForHealth(hum)
    highlight.OutlineColor = Color3.fromRGB(255, 255, 255)

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "SW_Label"
    billboard.Adornee = c:FindFirstChild("Head")
    billboard.Size = UDim2.fromOffset(220, 40)
    billboard.StudsOffset = Vector3.new(0, 2.6, 0)
    billboard.AlwaysOnTop = true
    billboard.MaxDistance = 400
    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Size = UDim2.fromScale(1, 1)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 13
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextStrokeTransparency = 0.4
    label.Text = plr.Name
    label.Parent = billboard

    highlight.Parent = ensureEspFolder()
    billboard.Parent = ensureEspFolder()

    local data = { highlight, billboard, label, billboard, hum }
    esp[plr] = data

    if CFG.Tracers and Drawing then
        local line = Drawing.new("Line")
        line.Thickness = 1.6
        line.Color = Color3.fromRGB(120, 220, 255)
        line.Transparency = 0.8
        tracers[plr] = line
    end

    bind(hum, "Died", function()
        removeESP(plr)
    end)
end

local function rebuildESP()
    for plr in pairs(esp) do
        removeESP(plr)
    end
    if not CFG.ESP then
        return
    end
    for _, plr in ipairs(Players:GetPlayers()) do
        applyESP(plr)
    end
end

bind(Players, "PlayerAdded", function(plr)
    bind(plr, "CharacterAdded", function()
        task.wait(0.5)
        if CFG.ESP then
            applyESP(plr)
        end
    end)
    if CFG.ESP then
        task.wait(0.5)
        applyESP(plr)
    end
end)

bind(Players, "PlayerRemoving", function(plr)
    removeESP(plr)
end)

RunService.RenderStepped:Connect(function()
    if not CFG.ESP then
        return
    end
    local cam = workspace.CurrentCamera
    local bottom = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y)
    for plr, data in pairs(esp) do
        local hum = data[5]
        if hum and hum.Health > 0 then
            data[1].FillColor = colorForHealth(hum)
            local head = hum.Parent and hum.Parent:FindFirstChild("Head")
            local root = getRoot()
            if head and root then
                data[3].Text = ("%s [%d] %dm"):format(plr.Name, math.floor(hum.Health), math.floor((head.Position - root.Position).Magnitude))
            end
            local line = tracers[plr]
            if line and head then
                local pos, onScreen = cam:WorldToViewportPoint(head.Position)
                if onScreen then
                    line.From = bottom
                    line.To = Vector2.new(pos.X, pos.Y)
                    line.Visible = true
                else
                    line.Visible = false
                end
            end
        end
    end
end)

local lightBackup
local function setFullbright(on)
    if on then
        lightBackup = {
            Brightness = Lighting.Brightness,
            ClockTime = Lighting.ClockTime,
            FogEnd = Lighting.FogEnd,
            Ambient = Lighting.Ambient,
            OutdoorAmbient = Lighting.OutdoorAmbient,
        }
        Lighting.Brightness = 2
        Lighting.ClockTime = 14
        Lighting.FogEnd = 1e6
        Lighting.Ambient = Color3.fromRGB(180, 180, 180)
        Lighting.OutdoorAmbient = Color3.fromRGB(180, 180, 180)
        Lighting.GlobalShadows = false
    elseif lightBackup then
        Lighting.Brightness = lightBackup.Brightness
        Lighting.ClockTime = lightBackup.ClockTime
        Lighting.FogEnd = lightBackup.FogEnd
        Lighting.Ambient = lightBackup.Ambient
        Lighting.OutdoorAmbient = lightBackup.OutdoorAmbient
        Lighting.GlobalShadows = true
        lightBackup = nil
    end
end

-- ============================================================
--  Teleport
-- ============================================================

local function teleportTo(position)
    local root = getRoot()
    if not root or not position then
        return
    end
    pcall(function()
        root.CFrame = CFrame.new(position + Vector3.new(0, 3, 0))
    end)
end

local function teleportToPlayer(plr)
    local targetRoot = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
    if targetRoot then
        teleportTo(targetRoot.Position)
    end
end

local waypoints = {}

-- ============================================================
--  Anti-AFK
-- ============================================================

bind(LP, "Idled", function()
    if not CFG.AntiAFK then
        return
    end
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end)

-- ============================================================
--  UI
-- ============================================================

local COLORS = {
    bg = Color3.fromRGB(18, 18, 22),
    panel = Color3.fromRGB(26, 26, 32),
    panel2 = Color3.fromRGB(34, 34, 42),
    accent = Color3.fromRGB(120, 200, 255),
    accent2 = Color3.fromRGB(90, 160, 255),
    text = Color3.fromRGB(236, 238, 245),
    muted = Color3.fromRGB(150, 154, 168),
    on = Color3.fromRGB(90, 200, 130),
}

local function corner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 8)
    c.Parent = parent
    return c
end

local function stroke(parent, color, thickness)
    local s = Instance.new("UIStroke")
    s.Color = color or Color3.fromRGB(50, 50, 62)
    s.Thickness = thickness or 1
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = parent
    return s
end

gui = Instance.new("ScreenGui")
gui.Name = "RobloxHud"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 999
gui.IgnoreGuiInset = true
gui.Parent = uiParent()
protectGui(gui)

local uiScale = Instance.new("UIScale")
uiScale.Parent = gui
local function rescaleUI()
    local cam = workspace.CurrentCamera
    if cam then
        local vp = cam.ViewportSize
        uiScale.Scale = math.clamp(math.min(vp.X / 620, vp.Y / 460), 0.55, 1)
    end
end
rescaleUI()
if workspace.CurrentCamera then
    bind(workspace.CurrentCamera, "ViewportSize", rescaleUI)
end

local main = Instance.new("Frame")
main.Name = "Main"
main.AnchorPoint = Vector2.new(0.5, 0.5)
main.Position = UDim2.fromScale(0.5, 0.5)
main.Size = UDim2.fromOffset(600, 430)
main.BackgroundColor3 = COLORS.bg
main.BorderSizePixel = 0
main.Parent = gui
corner(main, 12)
stroke(main, Color3.fromRGB(60, 62, 78))

local titleBar = Instance.new("Frame")
titleBar.Name = "TitleBar"
titleBar.Size = UDim2.new(1, 0, 0, 42)
titleBar.BackgroundColor3 = COLORS.panel
titleBar.BorderSizePixel = 0
titleBar.Parent = main
corner(titleBar, 12)

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(14, 0)
title.Size = UDim2.new(1, -120, 1, 0)
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextColor3 = COLORS.accent
title.Text = "SCHOOL WAR // TOOLKIT"
title.Parent = titleBar

local status = Instance.new("TextLabel")
status.BackgroundTransparency = 1
status.AnchorPoint = Vector2.new(1, 0)
status.Position = UDim2.new(1, -46, 0, 0)
status.Size = UDim2.fromOffset(120, 42)
status.Font = Enum.Font.Gotham
status.TextSize = 11
status.TextXAlignment = Enum.TextXAlignment.Right
status.TextColor3 = COLORS.muted
status.Text = "idle"
status.Parent = titleBar

local close = Instance.new("TextButton")
close.AnchorPoint = Vector2.new(1, 0)
close.Position = UDim2.new(1, -8, 0, 8)
close.Size = UDim2.fromOffset(26, 26)
close.BackgroundColor3 = Color3.fromRGB(60, 32, 38)
close.Text = "X"
close.TextColor3 = COLORS.text
close.Font = Enum.Font.GothamBold
close.TextSize = 12
close.BorderSizePixel = 0
close.Parent = titleBar
corner(close, 6)

local tabBar = Instance.new("Frame")
tabBar.Position = UDim2.fromOffset(8, 50)
tabBar.Size = UDim2.new(1, -16, 0, 30)
tabBar.BackgroundTransparency = 1
tabBar.Parent = main

local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.Padding = UDim.new(0, 4)
tabLayout.Parent = tabBar

local content = Instance.new("Frame")
content.Position = UDim2.fromOffset(8, 88)
content.Size = UDim2.new(1, -16, 1, -96)
content.BackgroundColor3 = COLORS.panel
content.BorderSizePixel = 0
content.Parent = main
corner(content, 10)
stroke(content, Color3.fromRGB(44, 46, 58))

local pages = {}
local activePage

local function makePage(name)
    local page = Instance.new("ScrollingFrame")
    page.Name = name
    page.Size = UDim2.fromScale(1, 1)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 4
    page.ScrollBarImageColor3 = COLORS.accent2
    page.CanvasSize = UDim2.new(0, 0, 0, 0)
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.Padding = UDim.new(0, 6)
    page.Visible = false
    page.Parent = content

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 6)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = page

    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 10)
    pad.PaddingLeft = UDim.new(0, 10)
    pad.PaddingRight = UDim.new(0, 10)
    pad.PaddingBottom = UDim.new(0, 10)
    pad.Parent = page

    pages[name] = page
    return page
end

local function showPage(name)
    if activePage then
        activePage.Visible = false
    end
    activePage = pages[name]
    if activePage then
        activePage.Visible = true
    end
    for _, tab in ipairs(tabBar:GetChildren()) do
        if tab:IsA("TextButton") then
            local active = tab.Name == name
            tab.BackgroundColor3 = active and COLORS.accent2 or COLORS.panel2
            tab.TextColor3 = active and Color3.new(1, 1, 1) or COLORS.muted
        end
    end
end

for _, name in ipairs({ "Player", "Combat", "Visual", "Farm", "Teleport", "Recon", "Misc" }) do
    makePage(name)
    local tab = Instance.new("TextButton")
    tab.Name = name
    tab.Size = UDim2.fromOffset(72, 28)
    tab.BackgroundColor3 = COLORS.panel2
    tab.Text = name
    tab.Font = Enum.Font.GothamBold
    tab.TextSize = 11
    tab.TextColor3 = COLORS.muted
    tab.BorderSizePixel = 0
    tab.AutoButtonColor = false
    tab.Parent = tabBar
    corner(tab, 6)
    tab.MouseButton1Click:Connect(function()
        showPage(name)
    end)
end

local function section(page, text)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0, 22)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamBold
    label.TextSize = 11
    label.TextColor3 = COLORS.accent
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Text = string.upper(text)
    label.Parent = page
    return label
end

local function button(page, text, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 30)
    btn.BackgroundColor3 = COLORS.panel2
    btn.Text = text
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 12
    btn.TextColor3 = COLORS.text
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = true
    btn.Parent = page
    corner(btn, 6)
    btn.MouseButton1Click:Connect(function()
        local ok, err = pcall(callback)
        if not ok then
            notify("Error", tostring(err))
        end
    end)
    return btn
end

local toggleRefs = {}

local function toggle(page, text, default, callback)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 30)
    row.BackgroundColor3 = COLORS.panel2
    row.BorderSizePixel = 0
    row.Parent = page
    corner(row, 6)

    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Position = UDim2.fromOffset(10, 0)
    label.Size = UDim2.new(1, -58, 1, 0)
    label.Font = Enum.Font.Gotham
    label.TextSize = 12
    label.TextColor3 = COLORS.text
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Text = text
    label.Parent = row

    local state = default and true or false

    local pill = Instance.new("TextButton")
    pill.AnchorPoint = Vector2.new(1, 0.5)
    pill.Position = UDim2.new(1, -8, 0.5, 0)
    pill.Size = UDim2.fromOffset(38, 18)
    pill.BackgroundColor3 = state and COLORS.on or Color3.fromRGB(64, 66, 80)
    pill.Text = ""
    pill.BorderSizePixel = 0
    pill.AutoButtonColor = false
    pill.Parent = row
    corner(pill, 9)

    local knob = Instance.new("Frame")
    knob.AnchorPoint = Vector2.new(0, 0.5)
    knob.Position = UDim2.fromScale(state and 0.95 or 0.05, 0.5)
    knob.Size = UDim2.fromOffset(14, 14)
    knob.BackgroundColor3 = COLORS.text
    knob.BorderSizePixel = 0
    knob.Parent = pill
    corner(knob, 7)

    local function render()
        pill.BackgroundColor3 = state and COLORS.on or Color3.fromRGB(64, 66, 80)
        TweenService:Create(knob, TweenInfo.new(0.12), {
            Position = UDim2.fromScale(state and 0.95 or 0.05, 0.5),
        }):Play()
    end

    local api = {}
    function api.set(value, silent)
        state = value and true or false
        render()
        if not silent then
            local ok, err = pcall(callback, state)
            if not ok then
                notify("Error", tostring(err))
            end
        end
    end

    pill.MouseButton1Click:Connect(function()
        api.set(not state)
    end)

    toggleRefs[text] = api

    return api
end

local function slider(page, text, min, max, default, callback)
    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(1, 0, 0, 46)
    holder.BackgroundColor3 = COLORS.panel2
    holder.BorderSizePixel = 0
    holder.Parent = page
    corner(holder, 6)

    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Position = UDim2.fromOffset(10, 4)
    label.Size = UDim2.new(1, -20, 0, 18)
    label.Font = Enum.Font.Gotham
    label.TextSize = 12
    label.TextColor3 = COLORS.text
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Text = text .. ": " .. tostring(default)
    label.Parent = holder

    local bar = Instance.new("Frame")
    bar.Position = UDim2.fromOffset(10, 30)
    bar.Size = UDim2.new(1, -20, 0, 6)
    bar.BackgroundColor3 = Color3.fromRGB(52, 54, 68)
    bar.BorderSizePixel = 0
    bar.Parent = holder
    corner(bar, 3)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.fromScale((default - min) / (max - min), 1)
    fill.BackgroundColor3 = COLORS.accent2
    fill.BorderSizePixel = 0
    fill.Parent = bar
    corner(fill, 3)

    local dragging = false
    local function update(input)
        local rel = math.clamp((input.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
        local value = math.floor(min + (max - min) * rel + 0.5)
        fill.Size = UDim2.fromScale(rel, 1)
        label.Text = text .. ": " .. tostring(value)
        local ok, err = pcall(callback, value)
        if not ok then
            notify("Error", tostring(err))
        end
    end

    bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            update(input)
        end
    end)
    bind(UserInputService, "InputChanged", function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            update(input)
        end
    end)
    bind(UserInputService, "InputEnded", function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    return holder
end

local function textbox(page, text, default, callback)
    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(1, 0, 0, 46)
    holder.BackgroundColor3 = COLORS.panel2
    holder.BorderSizePixel = 0
    holder.Parent = page
    corner(holder, 6)

    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Position = UDim2.fromOffset(10, 2)
    label.Size = UDim2.new(1, -20, 0, 16)
    label.Font = Enum.Font.Gotham
    label.TextSize = 11
    label.TextColor3 = COLORS.muted
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Text = text
    label.Parent = holder

    local box = Instance.new("TextBox")
    box.Position = UDim2.fromOffset(8, 20)
    box.Size = UDim2.new(1, -16, 0, 20)
    box.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
    box.Font = Enum.Font.Code
    box.TextSize = 11
    box.TextColor3 = COLORS.accent
    box.PlaceholderColor3 = COLORS.muted
    box.Text = default or ""
    box.ClearTextOnFocus = false
    box.BorderSizePixel = 0
    box.Parent = holder
    corner(box, 4)

    box.FocusLost:Connect(function()
        local ok, err = pcall(callback, box.Text)
        if not ok then
            notify("Error", tostring(err))
        end
    end)

    return box
end

local function label(page, text)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, 0, 0, 0)
    l.AutomaticSize = Enum.AutomaticSize.Y
    l.BackgroundTransparency = 1
    l.Font = Enum.Font.Gotham
    l.TextSize = 11
    l.TextWrapped = true
    l.TextColor3 = COLORS.muted
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Text = text
    l.Parent = page
    return l
end

-- ============================================================
--  Isi tab
-- ============================================================

do
    local page = pages.Player
    section(page, "Character")
    slider(page, "WalkSpeed", 16, 200, CFG.WalkSpeed, function(v)
        CFG.WalkSpeed = v
        applyWalkSpeed(v)
    end)
    slider(page, "JumpPower", 50, 250, CFG.JumpPower, function(v)
        CFG.JumpPower = v
        applyJumpPower(v)
    end)
    toggle(page, "Infinite Jump", CFG.InfiniteJump, function(on)
        CFG.InfiniteJump = on
    end)
    toggle(page, "Fly (WASD, Space/Ctrl)", CFG.Fly, function(on)
        CFG.Fly = on
        if on then
            startFly()
        else
            stopFly()
        end
    end)
    slider(page, "Fly Speed", 20, 300, CFG.FlySpeed, function(v)
        CFG.FlySpeed = v
    end)
    toggle(page, "Noclip", CFG.Noclip, function(on)
        CFG.Noclip = on
        if on then
            startNoclip()
        else
            stopNoclip()
        end
    end)
    toggle(page, "Anti-AFK", CFG.AntiAFK, function(on)
        CFG.AntiAFK = on
    end)
end

do
    local page = pages.Combat
    section(page, "Melee")
    toggle(page, "Auto Attack", CFG.AutoAttack, function(on)
        CFG.AutoAttack = on
        status.Text = on and "attacking" or "idle"
    end)
    toggle(page, "Kill Aura", CFG.KillAura, function(on)
        CFG.KillAura = on
    end)
    toggle(page, "Auto Equip Tool", CFG.AutoEquip, function(on)
        CFG.AutoEquip = on
    end)
    slider(page, "Attack Delay (ms)", 50, 1000, math.floor(CFG.AttackDelay * 1000), function(v)
        CFG.AttackDelay = v / 1000
    end)
    slider(page, "Aura Range", 5, 60, CFG.AuraRange, function(v)
        CFG.AuraRange = v
    end)
    section(page, "Arg Remote (pisahkan koma)")
    textbox(page, "Auto attack args", CFG.AttackArgs, function(v)
        CFG.AttackArgs = v
    end)
    textbox(page, "Kill aura args", CFG.AuraArgs, function(v)
        CFG.AuraArgs = v
    end)
    label(page, "Placeholder: tool, char, root, target, targetchar, pos, name, true, false, nil, angka.")
end

do
    local page = pages.Visual
    section(page, "Player")
    toggle(page, "ESP (Highlight + Label)", CFG.ESP, function(on)
        CFG.ESP = on
        rebuildESP()
    end)
    toggle(page, "Tracers", CFG.Tracers, function(on)
        CFG.Tracers = on
        rebuildESP()
    end)
    section(page, "World")
    toggle(page, "Fullbright", CFG.Fullbright, function(on)
        CFG.Fullbright = on
        setFullbright(on)
    end)
    button(page, "Reset Lighting", function()
        setFullbright(false)
    end)
    section(page, "Performance")
    button(page, "FPS Boost (ringan)", function()
        pcall(function()
            settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
        end)
        Lighting.GlobalShadows = false
        notify("FPS", "Quality diturunkan.")
    end)
    button(page, "Kembalikan Quality", function()
        pcall(function()
            settings().Rendering.QualityLevel = Enum.QualityLevel.Level21
        end)
        Lighting.GlobalShadows = true
    end)
end

do
    local page = pages.Farm
    section(page, "Otomatis")
    toggle(page, "Auto Capture Territory", CFG.AutoCapture, function(on)
        CFG.AutoCapture = on
    end)
    slider(page, "Capture Delay (ms)", 200, 5000, math.floor(CFG.CaptureDelay * 1000), function(v)
        CFG.CaptureDelay = v / 1000
    end)
    textbox(page, "Capture args", CFG.CaptureArgs, function(v)
        CFG.CaptureArgs = v
    end)
    toggle(page, "Auto Claim Reward", CFG.AutoReward, function(on)
        CFG.AutoReward = on
    end)
    slider(page, "Reward Delay (detik)", 2, 120, math.floor(CFG.RewardDelay), function(v)
        CFG.RewardDelay = v
    end)
    toggle(page, "Auto Respawn", CFG.AutoRespawn, function(on)
        CFG.AutoRespawn = on
    end)
    section(page, "Info")
    label(page, "Auto capture mencari part bernama zone/flag/territory/point lalu mengirim posisinya ke remote capture terdekat.")
end

do
    local page = pages.Teleport
    section(page, "Pemain")
    local list = Instance.new("Frame")
    list.Size = UDim2.new(1, 0, 0, 0)
    list.AutomaticSize = Enum.AutomaticSize.Y
    list.BackgroundTransparency = 1
    list.Parent = page
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 4)
    layout.Parent = list

    local function refresh()
        for _, child in ipairs(list:GetChildren()) do
            if child:IsA("TextButton") then
                child:Destroy()
            end
        end
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LP then
                local btn = Instance.new("TextButton")
                btn.Size = UDim2.new(1, 0, 0, 26)
                btn.BackgroundColor3 = COLORS.panel2
                btn.Text = "TP ke " .. plr.Name
                btn.Font = Enum.Font.Gotham
                btn.TextSize = 11
                btn.TextColor3 = COLORS.text
                btn.BorderSizePixel = 0
                btn.Parent = list
                corner(btn, 5)
                btn.MouseButton1Click:Connect(function()
                    teleportToPlayer(plr)
                end)
            end
        end
    end

    bind(Players, "PlayerAdded", refresh)
    bind(Players, "PlayerRemoving", refresh)
    refresh()

    section(page, "Waypoint")
    local nameBox = textbox(page, "Nama waypoint", "base", function() end)
    button(page, "Simpan posisi sekarang", function()
        local root = getRoot()
        if root then
            waypoints[nameBox.Text] = root.Position
            notify("Waypoint", "Disimpan: " .. nameBox.Text)
        end
    end)
    local wpList = Instance.new("Frame")
    wpList.Size = UDim2.new(1, 0, 0, 0)
    wpList.AutomaticSize = Enum.AutomaticSize.Y
    wpList.BackgroundTransparency = 1
    wpList.Parent = page
    local wpLayout = Instance.new("UIListLayout")
    wpLayout.Padding = UDim.new(0, 4)
    wpLayout.Parent = wpList

    local function refreshWp()
        for _, child in ipairs(wpList:GetChildren()) do
            if child:IsA("TextButton") then
                child:Destroy()
            end
        end
        for name in pairs(waypoints) do
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(1, 0, 0, 26)
            btn.BackgroundColor3 = COLORS.panel2
            btn.Text = "TP " .. name
            btn.Font = Enum.Font.Gotham
            btn.TextSize = 11
            btn.TextColor3 = COLORS.text
            btn.BorderSizePixel = 0
            btn.Parent = wpList
            corner(btn, 5)
            btn.MouseButton1Click:Connect(function()
                teleportTo(waypoints[name])
            end)
        end
    end
    button(page, "Refresh waypoint", refreshWp)
end

do
    local page = pages.Recon
    section(page, "Dump")
    label(page, "Recon menulis ke console (F9) dan menyimpan ke getgenv().SW_RECON. Salin hasilnya ke sini untuk tuning.")
    button(page, "Dump semua remote", function()
        local found = {}
        for _, remote in ipairs(collectRemotes()) do
            table.insert(found, { class = remote.ClassName, path = pathOf(remote) })
        end
        getgenv().SW_RECON = found
        for _, item in ipairs(found) do
            print(("[SW_RECON] %s :: %s"):format(item.class, item.path))
        end
        pcall(function()
            setclipboard(HttpService:JSONEncode(found))
        end)
        notify("Recon", ("%d remote ditemukan (disalin ke clipboard)."):format(#found))
    end)
    button(page, "Ranking remote (attack/capture/reward)", function()
        refreshCache()
        local map = {
            ATTACK = cache.attack,
            CAPTURE = cache.capture,
            REWARD = cache.reward,
            RESPAWN = cache.respawn,
        }
        for tag, list in pairs(map) do
            print(("[SW_RECON] -- %s (%d)"):format(tag, #list))
            for i = 1, math.min(#list, 15) do
                print(("[SW_RECON]   %d. %s"):format(i, pathOf(list[i])))
            end
        end
        notify("Recon", "Ranking ditulis ke console.")
    end)
    button(page, "Refresh cache remote", function()
        refreshCache()
        notify("Recon", "Cache diperbarui.")
    end)
    section(page, "Override manual")
    textbox(page, "Path AttackRemote", (OVERRIDE.AttackRemote or ""), function(v)
        OVERRIDE.AttackRemote = v
    end)
    textbox(page, "Path CaptureRemote", (OVERRIDE.CaptureRemote or ""), function(v)
        OVERRIDE.CaptureRemote = v
    end)
    textbox(page, "Path RewardRemote", (OVERRIDE.RewardRemote or ""), function(v)
        OVERRIDE.RewardRemote = v
    end)
    label(page, "Contoh path: game.ReplicatedStorage.Remotes.Attack")
end

do
    local page = pages.Misc
    section(page, "Server")
    button(page, "Rejoin server ini", function()
        TeleportService:TeleportToPlaceInstance(PLACE_ID, game.JobId, LP)
    end)
    button(page, "Server hop (publik)", function()
        local ok, result = pcall(function()
            return HttpService:JSONDecode(game:HttpGet(
                ("https://games.roblox.com/v1/games/%d/servers/Public?limit=100"):format(PLACE_ID)
            ))
        end)
        if not ok or not result or not result.data then
            notify("Server Hop", "Gagal mengambil daftar server.")
            return
        end
        for _, server in ipairs(result.data) do
            if server.id ~= game.JobId and server.playing < server.maxPlayers then
                TeleportService:TeleportToPlaceInstance(PLACE_ID, server.id, LP)
                notify("Server Hop", "Pindah ke server " .. server.id)
                return
            end
        end
        notify("Server Hop", "Server penuh semua.")
    end)
    section(page, "Hub")
    toggle(page, "Tampilkan UI", CFG.ShowUI, function(on)
        main.Visible = on
    end)
    toggle(page, "Stealth (gethui + protect)", stealthEnabled(), function(on)
        OVERRIDE.Stealth = on
        local parent = on and uiParent() or game:GetService("CoreGui")
        gui.Parent = parent or game:GetService("CoreGui")
        if espFolder then
            espFolder.Parent = gui
        end
        if on then
            protectGui(gui)
        end
        notify("Stealth", on and "UI dipindah ke container tersembunyi." or "UI kembali ke CoreGui.")
    end)
    button(page, "PANIC: matikan semua fitur", function()
        for _, api in pairs(toggleRefs) do
            pcall(api.set, false)
        end
        pcall(stopFly)
        pcall(stopNoclip)
        pcall(setFullbright, false)
        notify("PANIC", "Semua fitur dimatikan.")
    end)
    button(page, "Refresh remote cache", function()
        refreshCache()
    end)
    button(page, "Unload script", function()
        if getgenv().SchoolWar_Unload then
            getgenv().SchoolWar_Unload()
        end
    end)
    section(page, "Info")
    label(page, "Place 77160678446964 | Universe 10170333176 | Creator Rnat_666")
    label(page, "Build 2026-11-03. Gunakan di akun alt bila ragu.")
end

-- drag & show
do
    local dragging, dragStart, startPos
    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = main.Position
        end
    end)
    bind(UserInputService, "InputChanged", function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            main.Position = UDim2.fromOffset(startPos.X.Offset + delta.X, startPos.Y.Offset + delta.Y)
        end
    end)
    bind(UserInputService, "InputEnded", function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

close.MouseButton1Click:Connect(function()
    main.Visible = not main.Visible
end)

bind(UserInputService, "InputBegan", function(input)
    if input.KeyCode == Enum.KeyCode.RightControl then
        main.Visible = not main.Visible
    end
end)

-- ============================================================
--  Init & unload
-- ============================================================

refreshCache()
showPage("Player")
applyWalkSpeed(CFG.WalkSpeed)
applyJumpPower(CFG.JumpPower)

bind(LP, "CharacterAdded", function()
    task.wait(0.8)
    applyWalkSpeed(CFG.WalkSpeed)
    applyJumpPower(CFG.JumpPower)
    if CFG.Fly then
        startFly()
    end
    if CFG.Noclip then
        stopNoclip()
        startNoclip()
    end
    if CFG.ESP then
        rebuildESP()
    end
end)

getgenv().SchoolWar_Unload = function()
    running = false
    getgenv().SchoolWar_Unload = nil
    for _, c in ipairs(conns) do
        pcall(function() c:Disconnect() end)
    end
    table.clear(conns)
    pcall(stopFly)
    pcall(stopNoclip)
    pcall(setFullbright, false)
    for plr in pairs(esp) do
        removeESP(plr)
    end
    pcall(function() gui:Destroy() end)
    pcall(function() espFolder:Destroy() end)
    notify("Unloaded", "Toolkit dimatikan.")
end

notify("SCHOOL WAR", "Toolkit loaded. RightCtrl = sembunyikan UI.")
