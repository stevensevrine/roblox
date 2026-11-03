-- Contoh konfigurasi override untuk SCHOOL WAR [V2] Crows Zero.
-- Isi nilai dari hasil recon.lua, lalu jalankan SEBELUM SchoolWar.lua:
--
--   loadstring(game:HttpGet("URL_RAW_config.lua"))()
--   loadstring(game:HttpGet("URL_RAW_SchoolWar.lua"))()

getgenv().SCHOOLWAR_CONFIG = {
    -- Path remote (bukan nama saja). Boleh dikosongkan.
    AttackRemote  = "game.ReplicatedStorage.Remotes.Combat.Attack",
    CaptureRemote = "game.ReplicatedStorage.Remotes.Zone.Capture",
    RewardRemote  = "game.ReplicatedStorage.Remotes.Daily.Claim",
    RespawnRemote = "game.ReplicatedStorage.Remotes.Character.Respawn",

    -- Bentuk argumen, dipisah koma.
    -- Placeholder: tool, char, root, target, targetchar, pos, name, true, false, nil, angka
    AttackArgs  = "tool,pos",
    AuraArgs    = "targetchar,char,pos",
    CaptureArgs = "pos,targetchar",
}
