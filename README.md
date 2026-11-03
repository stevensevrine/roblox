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
