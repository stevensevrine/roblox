--[[
    SCHOOL WAR - DIAGNOSTIC 267 ("Disallowed Services Detected")

    Jalankan di game, lalu lihat console (F9).
    Script ini TIDAK memperbaiki apa pun, hanya menunjukkan apa yang mungkin
    dibaca anti-cheat: service tak biasa, isi CoreGui, nama GUI executor,
    fingerprint executor, dan status metatable.

    Perintah:
        getgenv().SWD.dump()       -- tampilkan laporan
        getgenv().SWD.clipboard()  -- salin laporan
--]]

--!nocheck

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local LP = Players.LocalPlayer

-- Service vanilla yang umum ada di client. Di luar daftar ini ditandai [?].
local VANILLA = {
    ["Workspace"] = true, ["Players"] = true, ["Lighting"] = true,
    ["ReplicatedFirst"] = true, ["ReplicatedStorage"] = true,
    ["StarterGui"] = true, ["StarterPack"] = true, ["StarterPlayer"] = true,
    ["Teams"] = true, ["SoundService"] = true, ["Chat"] = true,
    ["TextChatService"] = true, ["LocalizationService"] = true,
    ["ScriptContext"] = true, ["ContentProvider"] = true, ["AssetService"] = true,
    ["HttpService"] = true, ["DataStoreService"] = true, ["MessagingService"] = true,
    ["MemoryStoreService"] = true, ["MarketplaceService"] = true, ["BadgeService"] = true,
    ["GroupService"] = true, ["PolicyService"] = true, ["PhysicsService"] = true,
    ["CollectionService"] = true, ["TeleportService"] = true, ["SocialService"] = true,
    ["UserInputService"] = true, ["RunService"] = true, ["TweenService"] = true,
    ["GuiService"] = true, ["HapticService"] = true, ["VRService"] = true,
    ["ContextActionService"] = true, ["PathfindingService"] = true,
    ["ProximityPromptService"] = true, ["Selection"] = true, ["CoreGui"] = true,
    ["CorePackages"] = true, ["RobloxGui"] = true, ["RobloxReplicatedStorage"] = true,
    ["InsertService"] = true, ["JointsService"] = true, ["KeyframeSequenceProvider"] = true,
    ["LanguageService"] = true, ["LogService"] = true, ["NetworkClient"] = true,
    ["NetworkServer"] = true, ["NotificationService"] = true, ["Stats"] = true,
    ["TouchInputService"] = true, ["UGCValidationService"] = true, ["UserService"] = true,
    ["VirtualInputManager"] = true, ["VisitService"] = true, ["WhitelistService"] = true,
    ["AppUpdateService"] = true, ["BrowserService"] = true, ["ClusterPacketCache"] = true,
    ["CookiesService"] = true, ["DeviceService"] = true, ["DraftsService"] = true,
    ["GamepadService"] = true, ["GeometryService"] = true, ["IXPService"] = true,
    ["MouseService"] = true, ["PermissionsService"] = true, ["PlayerEmulatorService"] = true,
    ["RemoteCursorService"] = true, ["RuntimeScriptService"] = true, ["SafetyService"] = true,
    ["SessionService"] = true, ["StudioService"] = true, ["ThirdPartyUserService"] = true,
    ["VersionService"] = true, ["PluginGuiService"] = true, ["PluginManager"] = true,
    ["ProcessService"] = true, ["RemoteDebuggerServer"] = true, ["TimerService"] = true,
}

local EXECUTOR_WORDS = {
    "delta", "arceus", "codex", "krnl", "fluxus", "hydrogen", "wave", "solara",
    "swift", "synapse", "scriptware", "eva", "electron", "oxygen", "vanilla",
    "flurry", "cryptic", "awp", "redz", "bunni", "macsploit", "appleware",
    "trigon", "sirius", "neptune", "kazumi", "unknown", "exploit", "hub",
    "rayfield", "orion", "kavo", "nevermore", "owl", "sw_", "schoolwar",
}

local D = {}

local function lines()
    local out = {}
    local function add(fmt, ...)
        table.insert(out, select("#", ...) > 0 and fmt:format(...) or fmt)
    end

    add("=== DIAGNOSTIC 267 ===")
    add("PlaceId: %d  JobId: %s", game.PlaceId, game.JobId)
    add("Waktu: %s", os.date("%Y-%m-%d %H:%M:%S"))

    add("")
    add("--- Executor ---")
    local okId, id = pcall(function()
        return identifyexecutor and identifyexecutor() or "tidak tersedia"
    end)
    add("identifyexecutor: %s", okId and tostring(id) or "error")
    for _, name in ipairs({ "gethui", "protect_gui", "protectgui", "hookmetamethod", "getrawmetatable", "setclipboard", "Drawing" }) do
        local ok, value = pcall(function()
            return _G[name] or getgenv()[name]
        end)
        add("%-16s %s", name, (ok and value ~= nil) and "ADA" or "tidak")
    end

    add("")
    add("--- Metatable ---")
    local okMeta, metaInfo = pcall(function()
        local m = getrawmetatable(game)
        return {
            namecall = typeof(m.__namecall),
            index = typeof(m.__index),
            newindex = typeof(m.__newindex),
        }
    end)
    if okMeta then
        add("__namecall=%s  __index=%s  __newindex=%s", metaInfo.namecall, metaInfo.index, metaInfo.newindex)
    else
        add("getrawmetatable tidak tersedia")
    end

    add("")
    add("--- Global executor di getgenv ---")
    local keys = {}
    pcall(function()
        for key in pairs(getgenv()) do
            if type(key) == "string" and key ~= "SWD" then
                table.insert(keys, key)
            end
        end
    end)
    table.sort(keys)
    for _, key in ipairs(keys) do
        add("  %s", key)
    end

    add("")
    add("--- Service tidak dikenal [?] ---")
    for _, inst in ipairs(game:GetChildren()) do
        if inst:IsA("ServiceProvider") or inst:IsA("Instance") then
            if not VANILLA[inst.Name] then
                add("[?] %s (%s)", inst.Name, inst.ClassName)
            end
        end
    end

    add("")
    add("--- CoreGui (%d anak) ---", #CoreGui:GetChildren())
    for _, inst in ipairs(CoreGui:GetChildren()) do
        local lower = string.lower(inst.Name)
        local hit = false
        for _, word in ipairs(EXECUTOR_WORDS) do
            if string.find(lower, word, 1, true) then
                hit = true
                break
            end
        end
        add("%s %s (%s)", hit and "[!]" or "   ", inst.Name, inst.ClassName)
    end

    add("")
    add("--- PlayerGui (%d anak) ---", #LP:FindFirstChild("PlayerGui"):GetChildren())
    for _, inst in ipairs(LP.PlayerGui:GetChildren()) do
        local lower = string.lower(inst.Name)
        local hit = false
        for _, word in ipairs(EXECUTOR_WORDS) do
            if string.find(lower, word, 1, true) then
                hit = true
                break
            end
        end
        add("%s %s (%s)", hit and "[!]" or "   ", inst.Name, inst.ClassName)
    end

    add("")
    add("=== SELESAI ===")
    return out
end

function D.dump()
    local out = lines()
    print(table.concat(out, "\n"))
    return out
end

function D.clipboard()
    local out = table.concat(lines(), "\n")
    pcall(function()
        setclipboard(out)
    end)
    print("[SWD] Laporan disalin ke clipboard.")
end

function D.unload()
    getgenv().SWD = nil
end

getgenv().SWD = D
D.dump()
