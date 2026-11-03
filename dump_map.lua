--[[
    SCHOOL WAR - MAP DUMPER
    PlaceId: 77160678446964

    Place ini copy-protected, jadi file .rbxl tidak bisa diunduh dari link.
    Script ini mengekstrak geometri dari client yang sedang berjalan.

    Hasil:
        SchoolWar_map.csv     -- semua BasePart: posisi, ukuran, rotasi, warna
        SchoolWar_assets.csv  -- SoundId / Texture / MeshId yang dipakai

    Jalankan LANGSUNG setelah spawn (sebelum anti-cheat sempat kick):
        loadstring(game:HttpGet("URL_RAW_dump_map.lua"))()

    Butuh executor dengan writefile / setclipboard.

    CATATAN
    - Kalau game memakai StreamingEnabled, hanya area yang sudah ter-load yang
      tercatat. Jalan keliling map dulu, baru jalankan ulang.
    - Kalau executor punya saveinstance(), itu lebih lengkap:
          saveinstance({ FileName = "SchoolWar.rbxl" })
--]]

--!nocheck

if getgenv and getgenv().SWDump_Running then
    return
end
getgenv().SWDump_Running = true

local MAX_PARTS = 80000
local parts = {}
local assets = {}
local assetSeen = {}

local function esc(value)
    return '"' .. tostring(value):gsub('"', '""') .. '"'
end

local function hex(color)
    return ("%02X%02X%02X"):format(
        math.floor(color.R * 255 + 0.5),
        math.floor(color.G * 255 + 0.5),
        math.floor(color.B * 255 + 0.5)
    )
end

local function addAsset(kind, value, path)
    if not value or value == "" then
        return
    end
    local key = kind .. ":" .. value
    if assetSeen[key] then
        return
    end
    assetSeen[key] = true
    table.insert(assets, ("%s,%s,%s"):format(esc(kind), esc(value), esc(path)))
end

local function scanAssets(inst)
    local ok, cls = pcall(function()
        return inst.ClassName
    end)
    if not ok then
        return
    end
    if cls == "Sound" then
        addAsset("Sound", inst.SoundId, inst:GetFullName())
    elseif cls == "Decal" or cls == "Texture" then
        addAsset("Texture", inst.Texture, inst:GetFullName())
    elseif cls == "MeshPart" then
        addAsset("Mesh", inst.MeshId, inst:GetFullName())
        addAsset("Texture", inst.TextureID, inst:GetFullName())
    elseif cls == "SpecialMesh" then
        addAsset("Mesh", inst.MeshId, inst:GetFullName())
    elseif cls == "ImageLabel" or cls == "ImageButton" then
        addAsset("Image", inst.Image, inst:GetFullName())
    elseif cls == "ParticleEmitter" or cls == "Beam" or cls == "Trail" then
        addAsset("Texture", inst.Texture, inst:GetFullName())
    elseif cls == "SurfaceAppearance" then
        addAsset("Texture", inst.ColorMap, inst:GetFullName())
        addAsset("Texture", inst.NormalMap, inst:GetFullName())
        addAsset("Texture", inst.RoughnessMap, inst:GetFullName())
    elseif cls == "Sky" then
        addAsset("Sky", inst.SkyboxBk, inst:GetFullName())
        addAsset("Sky", inst.SkyboxDn, inst:GetFullName())
        addAsset("Sky", inst.SkyboxFt, inst:GetFullName())
        addAsset("Sky", inst.SkyboxLf, inst:GetFullName())
        addAsset("Sky", inst.SkyboxRt, inst:GetFullName())
        addAsset("Sky", inst.SkyboxUp, inst:GetFullName())
    end
end

local function scanPart(inst)
    if #parts >= MAX_PARTS then
        return
    end
    local pos = inst.Position
    local size = inst.Size
    local cframe = inst.CFrame
    local right = cframe.RightVector
    local yaw = math.deg(math.atan2(right.Z, right.X))
    table.insert(parts, ("%s,%s,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,%.1f,%s,%.2f,%s"):format(
        esc(inst.ClassName),
        esc(inst.Name),
        pos.X, pos.Y, pos.Z,
        size.X, size.Y, size.Z,
        yaw,
        hex(inst.Color),
        1 - inst.Transparency,
        esc(inst.Material.Name)
    ))
end

local ok = pcall(function()
    for _, inst in ipairs(workspace:GetDescendants()) do
        if inst:IsA("BasePart") then
            scanPart(inst)
        end
        scanAssets(inst)
    end
end)

local header = "class,name,x,y,z,sx,sy,sz,yaw,color,alpha,material\n"
local mapData = header .. table.concat(parts, "\n")
local assetData = "kind,id,path\n" .. table.concat(assets, "\n")

local function save(name, data)
    local okWrite = pcall(function()
        writefile(name, data)
    end)
    if okWrite then
        print(("[SWDump] Tersimpan: %s (%d byte)"):format(name, #data))
        return true
    end
    return false
end

local saved = save("SchoolWar_map.csv", mapData)
save("SchoolWar_assets.csv", assetData)

if not saved then
    pcall(function()
        setclipboard(mapData:sub(1, 190000))
    end)
    print("[SWDump] writefile tidak tersedia; CSV disalin ke clipboard (dipotong bila terlalu besar).")
end

print(("[SWDump] Selesai: %d part, %d asset."):format(#parts, #assets))
getgenv().SWDump_Running = false
