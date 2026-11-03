# SCHOOL WAR [V2] Crows Zero — Toolkit

Script buat game **SCHOOL WAR [V2] Crows Zero**.

| Info | Nilai |
| --- | --- |
| Game | SCHOOL WAR [V2] Crows Zero |
| Place ID | `77160678446964` |
| Universe ID | `10170333176` |
| Creator | `Rnat_666` |

> Place tidak mengizinkan copy, jadi script ini **tidak** memakai nama remote hardcoded.
> Remote dicari otomatis dari pola nama. Kalau ada fitur yang tidak jalan, pakai `recon.lua`
> untuk melihat remote asli game lalu isi override (lihat bagian **Tuning**).

## File

- `SchoolWar.lua` — hub menu utama (Player, Combat, Visual, Farm, Teleport, Recon, Misc)
- `recon.lua` — perekam remote untuk tuning
- `diagnose.lua` — cek pemicu kick 267 (service/GUI/metatable)
- `dump_map.lua` — ekstrak geometri map + asset ID dari client
- `render_map.py` — ubah hasil dump jadi denah SVG
- `assets/` — icon & gambar media game (hasil ambil lewat API publik)
- `README.md` — dokumen ini

## Fitur

**Player**
- WalkSpeed & JumpPower slider
- Infinite jump
- Fly (WASD, Space naik, LeftCtrl turun) + slider kecepatan
- Noclip
- Anti-AFK

**Combat**
- Auto attack (tool activation + remote attack)
- Kill aura dengan range
- Auto equip tool
- Delay attack & argumen remote bisa diatur

**Visual**
- ESP highlight + nama + HP + jarak
- Tracer
- Fullbright
- FPS boost

**Farm**
- Auto capture territory berbasis pencarian part zona
- Auto claim reward
- Auto respawn

**Lain**
- Teleport ke pemain & waypoint
- Dump remote, ranking remote, override remote
- Server hop / rejoin

## Cara pakai

1. Simpan dua file ini di host raw (GitHub Gist / repo public).
2. Jalankan di executor:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/USER/REPO/main/SchoolWar.lua"))()
```

Atau paste isi file langsung ke executor.

- `RightCtrl` atau tombol `X` = sembunyikan / tampilkan UI
- Unload: tab **Misc → Unload script**

## Tuning (penting)

Default argumen sengaja generik:

- `AttackArgs = "tool"`
- `AuraArgs = "targetchar,char,pos"`
- `CaptureArgs = "pos,char"`

Alur tuning yang disarankan:

1. Jalankan `recon.lua`, lalu di game lakukan: serang, klaim wilayah, ambil reward.
2. Buka console (`F9`) atau jalankan `getgenv().SWR.report()`.
3. Lihat remote + bentuk argumen yang dipakai game. Contoh hasil:

```
Remotes.Combat.Attack:FireServer(tool, Vector3(...))
Remotes.Zone.Capture:FireServer(Instance(Part:FlagZone))
```

4. Isi override sebelum load script utama:

```lua
getgenv().SCHOOLWAR_CONFIG = {
    AttackRemote  = "game.ReplicatedStorage.Remotes.Combat.Attack",
    AttackArgs    = "tool,pos",
    CaptureRemote = "game.ReplicatedStorage.Remotes.Zone.Capture",
    CaptureArgs   = "pos,targetchar",
    RewardRemote  = "game.ReplicatedStorage.Remotes.Daily.Claim",
}
-- lalu load SchoolWar.lua
```

Override juga bisa diisi langsung dari tab **Recon**.

### Placeholder argumen

`tool`, `char`, `root`, `target`, `targetchar`, `pos`, `name`, `true`, `false`, `nil`, angka.

Contoh: `"targetchar,char,pos"` akan mengirim `target.Character, player.Character, root.Position`.

## Kalau kena kick 267 (Disallowed Services Detected)

Ini **kick dari anti-cheat game**, bukan ban. Rejoin biasanya bisa. Penyebab umum:
GUI executor/hub berada di `CoreGui`, nama GUI cocok dengan daftar cheat, service
tambahan dari executor, atau script ke-load saat anti-cheat masih scan di awal join.

Urutan penanganan:

1. Jalankan `diagnose.lua`, lihat baris bertanda `[!]` dan `[?]`. Kalau ada GUI executor
   (`Delta`, `Arceus`, `Codex`, dll.) di `CoreGui`, itu tersangka utama.
2. Sembunyikan UI bawaan executor (tutup floating icon / pilih mode stealth di executor).
3. Pakai executor lain sebagai pembanding. Kalau kick hanya terjadi di satu executor,
   masalahnya bukan di script.
4. Load hub dengan stealth + delay:

```lua
getgenv().SCHOOLWAR_CONFIG = { Stealth = true, LoadDelay = 20 }
loadstring(game:HttpGet("https://raw.githubusercontent.com/stevensevrine/roblox/main/SchoolWar.lua"))()
```

`Stealth` memindahkan GUI ke `gethui()` dan memanggil `protect_gui`/`syn.protect_gui`
bila tersedia. `LoadDelay` menunda load sampai scan awal server selesai.
5. Kalau masih kick saat idle, matikan fitur yang mengubah objek terus-menerus:
   ESP, Fly, Noclip. Auto attack/capture yang terlalu cepat bisa memicu validasi server.
6. Jangan jalankan `recon.lua` bersamaan dengan hub. Recon memasang hook `__namecall`;
   restart client dulu kalau sudah pernah dipakai.

Catatan: `Stealth` tidak menjamin 100%. Anti-cheat bisa juga memeriksa child `PlayerGui`
atau fingerprint executor. Hasil `diagnose.lua` yang menentukan langkah berikutnya.

## Mengambil aset / map lewat link

Place ini **copy-protected** (`copyingAllowed = false`). Hasil uji langsung:

| Sumber | Hasil |
| --- | --- |
| `assetdelivery` place file | `409 User is not authorized to access Asset` |
| Icon game | bisa (`thumbnails/v1/games/icons`) |
| Gambar media/thumbnail | bisa (`games/v2/{universeId}/media` + `thumbnails/v1/assets`) |
| Metadata, votes, server list | bisa |
| Geometri map / `.rbxl` | tidak lewat link, harus dump dari client |

Gambar yang sudah berhasil diambil ada di `assets/` (`icon-512.png`, `media-1.png`).

### Dump layout map

Jalankan secepatnya setelah spawn, sebelum anti-cheat kick:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/stevensevrine/roblox/main/dump_map.lua"))()
```

Hasil di folder workspace executor: `SchoolWar_map.csv` dan `SchoolWar_assets.csv`.
Render jadi denah:

```
python render_map.py SchoolWar_map.csv map.svg
```

Kalau executor punya `saveinstance()` (Delta/Codex dll.), itu lebih lengkap:

```lua
saveinstance({ FileName = "SchoolWar.rbxl" })
```

Batasan: dengan `StreamingEnabled`, hanya area yang sudah ter-load yang tercatat.
Jalan keliling map dulu lalu dump ulang. Dump juga tidak menyertakan script server.

## Batasan

- Nama remote berbeda tiap update; kalau fitur berhenti bekerja, ulangi recon.
- Auto capture hanya mendeteksi part yang namanya mengandung `capture`, `flag`, `zone`,
  `territory`, `point`, `base`, dll.
- Kill aura tidak punya pathfinding; kalau target di balik tembok, hanya menembak remote.
- Script berjalan penuh di client. Beberapa game memvalidasi jarak di server.
- Beberapa executor tidak punya `Drawing`; tracer otomatis dilewati.

## Struktur teknis

- Remote resolver menjalankan `GetDescendants` pada `ReplicatedStorage`,
  `ReplicatedFirst`, dan `LocalPlayer`, lalu memberi skor berdasarkan kata kunci.
- Argumen dibangun dengan template string; `RemoteFunction` memakai `InvokeServer`.
- Semua panggilan remote dibungkus `pcall` supaya satu error tidak mematikan loop.
- Cleanup menyimpan semua koneksi dan mengembalikan lighting saat unload.

## Disclaimer

Gunakan di akun alt kalau khawatir. Tidak ada jaminan bebas ban; fitur yang agresif
(auto attack / capture) bisa terdeteksi kalau delay terlalu kecil.
