--[[
    SCHOOL WAR [V2] Crows Zero - RECON
    PlaceId: 77160678446964

    Jalankan sebelum tuning:
        loadstring(game:HttpGet("URL_RAW_recon.lua"))()

    Lalu di game: serang orang, klaim wilayah, ambil reward, respawn.
    Recon akan mencatat remote + bentuk argumen yang dikirim game.

    Perintah:
        getgenv().SWR.dump()          -- dump semua remote + path
        getgenv().SWR.start(30)       -- rekam trafik 30 detik
        getgenv().SWR.stop()
        getgenv().SWR.report()        -- cetak hasil rekaman
        getgenv().SWR.clipboard()     -- salin hasil rekaman ke clipboard
        getgenv().SWR.unload()

    Output juga tersimpan di getgenv().SWR.log.
--]]

--!nocheck

if getgenv and getgenv().SWR and getgenv().SWR.unload then
    pcall(getgenv().SWR.unload)
end

local Players = game:GetService("Players")
local LP = Players.LocalPlayer

local R = {
    remotes = {},
    log = {},
    seen = {},
    recording = false,
    stopAt = 0,
    hook = nil,
}

local function pathOf(inst)
    local parts = {}
    local node = inst
    while node and node ~= game do
        table.insert(parts, 1, node.Name)
        node = node.Parent
    end
    return table.concat(parts, ".")
end

local function isRemote(inst)
    local ok, yes = pcall(function()
        return inst:IsA("RemoteEvent") or inst:IsA("RemoteFunction") or inst:IsA("UnreliableRemoteEvent")
    end)
    return ok and yes
end

local function roots()
    local list = { game:GetService("ReplicatedStorage"), game:GetService("ReplicatedFirst"), LP }
    local ok, gui = pcall(function()
        return LP:FindFirstChild("PlayerGui")
    end)
    if ok and gui then
        table.insert(list, gui)
    end
    return list
end

function R.dump()
    table.clear(R.remotes)
    for _, root in ipairs(roots()) do
        pcall(function()
            for _, inst in ipairs(root:GetDescendants()) do
                if isRemote(inst) then
                    table.insert(R.remotes, { class = inst.ClassName, path = pathOf(inst) })
                end
            end
        end)
    end
    print(("[SWR] %d remote ditemukan:"):format(#R.remotes))
    for _, item in ipairs(R.remotes) do
        print(("[SWR] %s :: %s"):format(item.class, item.path))
    end
    return R.remotes
end

local function describe(value)
    local t = typeof(value)
    if t == "Instance" then
        local ok, p = pcall(pathOf, value)
        return "Instance(" .. value.ClassName .. ":" .. (ok and p or value.Name) .. ")"
    elseif t == "Vector3" then
        return ("Vector3(%.1f, %.1f, %.1f)"):format(value.X, value.Y, value.Z)
    elseif t == "CFrame" then
        return "CFrame"
    elseif t == "table" then
        return "table#" .. tostring(#value)
    elseif t == "string" then
        return ("string(%q)"):format(value:sub(1, 60))
    elseif t == "number" or t == "boolean" or t == "nil" then
        return tostring(value)
    elseif t == "EnumItem" then
        return "EnumItem(" .. tostring(value) .. ")"
    end
    return t
end

local function record(remote, method, args)
    if not R.recording then
        return
    end
    local key = pathOf(remote) .. "#" .. method
    R.seen[key] = (R.seen[key] or 0) + 1
    if #R.log > 400 then
        return
    end
    local parts = {}
    for i = 1, args.n or #args do
        table.insert(parts, describe(args[i]))
    end
    local entry = {
        remote = pathOf(remote),
        method = method,
        args = table.concat(parts, ", "),
        at = os.clock(),
    }
    table.insert(R.log, entry)
    print(("[SWR] %s:%s(%s)"):format(entry.remote, method, entry.args))
end

function R.start(seconds)
    seconds = tonumber(seconds) or 30
    R.recording = true
    R.stopAt = os.clock() + seconds
    print(("[SWR] Merekam %d detik. Lakukan aksi di game sekarang."):format(seconds))
    task.spawn(function()
        while R.recording and os.clock() < R.stopAt do
            task.wait(0.25)
        end
        if R.recording then
            R.stop()
            R.report()
        end
    end)
end

function R.stop()
    R.recording = false
    print("[SWR] Rekaman berhenti.")
end

function R.report()
    print(("[SWR] ==== REPORT (%d entri) ===="):format(#R.log))
    local byRemote = {}
    for _, entry in ipairs(R.log) do
        local key = entry.remote .. ":" .. entry.method
        byRemote[key] = byRemote[key] or { count = 0, sample = entry.args }
        byRemote[key].count += 1
    end
    local keys = {}
    for key in pairs(byRemote) do
        table.insert(keys, key)
    end
    table.sort(keys, function(a, b)
        return byRemote[a].count > byRemote[b].count
    end)
    for _, key in ipairs(keys) do
        local item = byRemote[key]
        print(("[SWR] %dx  %s  contoh(%s)"):format(item.count, key, item.sample))
    end
    print("[SWR] ==== END REPORT ====")
end

function R.clipboard()
    local lines = {}
    for _, entry in ipairs(R.log) do
        table.insert(lines, ("%s:%s(%s)"):format(entry.remote, entry.method, entry.args))
    end
    local text = table.concat(lines, "\n")
    pcall(function()
        setclipboard(text)
    end)
    print("[SWR] Hasil rekaman disalin ke clipboard.")
end

function R.unload()
    R.recording = false
    pcall(function()
        if R.hook then
            R.hook()
        end
    end)
    getgenv().SWR = nil
    print("[SWR] Unloaded.")
end

local function installHook()
    if R.hook then
        return true
    end
    local oldNamecall
    local ok = pcall(function()
        local m = getrawmetatable(game)
        oldNamecall = m.__namecall
        setreadonly(m, false)
        m.__namecall = newcclosure(function(self, ...)
            local method = getnamecallmethod()
            if R.recording and (method == "FireServer" or method == "InvokeServer") and isRemote(self) then
                record(self, method, table.pack(...))
            end
            return oldNamecall(self, ...)
        end)
        setreadonly(m, true)
    end)

    if ok then
        R.hook = function()
            local m = getrawmetatable(game)
            setreadonly(m, false)
            m.__namecall = oldNamecall
            setreadonly(m, true)
        end
        return true
    end

    warn("[SWR] hookmetamethod tidak tersedia; fallback ke deskripsi remote saja.")
    return false
end

getgenv().SWR = R
installHook()
R.dump()
print("[SWR] Siap. Jalankan getgenv().SWR.start(30) lalu main seperti biasa.")
