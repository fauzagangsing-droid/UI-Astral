# ASTRAL LITE

Pustaka UI Roblox sisi klien berbasis Instance native, dipisahkan dari shell jendela. Ada **15 factory total**: 14 memakai `UI:CreateX(parent, config)`, satu memakai `UI:CreateNotification(config)`. Tidak ada dependensi runtime eksternal, `loadstring`, unduhan kode, atau API executor. Logo memakai aset Roblox; ketersediaannya mengikuti izin/moderasi aset.

## Status dan persyaratan

- Roblox Studio untuk menjalankan dan menguji UI pada klien (mode **Play**, bukan hanya Run/server).
- Rojo CLI dan plugin Studio untuk sinkronisasi; CLI saja cukup untuk membangun place setelah konfigurasi proyek tersedia.
- Aftman **opsional**. `aftman.toml` tetap seperti semula, termasuk pin Rojo `7.7.0-rc.1`; dokumentasi ini tidak mengubah toolchain.
- Node.js hanya diperlukan bila validator statis opsional kelak ditambahkan, bukan untuk runtime UI.

**Saat dokumentasi ditulis:** modul dan shell sudah ada; konfigurasi proyek Rojo, tes, serta validator di bawah masih direncanakan. Build Rojo dan pengujian Studio **belum dijalankan**. Perintah berikut adalah prosedur yang dapat direproduksi setelah berkas pendukung tersedia, bukan laporan kelulusan.

## Struktur

```text
UI SCRIPT/
├── README.md
├── CHANGELOG.md
├── aftman.toml                    # dipertahankan tanpa perubahan
├── ui.lua                         # arsip asli, tidak dipetakan Rojo
├── default.project.json           # direncanakan
├── src/
│   ├── client/
│   │   └── Main.client.lua        # LocalScript Main
│   └── shared/
│       └── UILibrary/
│           ├── init.lua           # Library.new dan wrapper API
│           ├── Theme.lua
│           ├── Helpers.lua
│           └── Components/
│               ├── init.lua
│               ├── Toggle.lua
│               ├── Slider.lua
│               ├── Button.lua
│               ├── Dropdown.lua
│               ├── MultiDropdown.lua
│               ├── TextBox.lua
│               ├── Keybind.lua
│               ├── ColorPicker.lua
│               ├── Notification.lua
│               ├── Section.lua
│               ├── Label.lua
│               ├── Paragraph.lua
│               ├── Divider.lua
│               ├── ProgressBar.lua
│               └── SearchBox.lua
├── docs/
│   ├── ARCHITECTURE.md
│   ├── COMPONENTS.md
│   ├── API_REFERENCE.md
│   ├── MIGRATION.md
│   └── AUDIT.md
├── tests/                         # direncanakan
│   ├── Components.spec.lua
│   └── README.md
└── scripts/                       # direncanakan, opsional
    └── validate.mjs
```

## Mapping Rojo yang dituju

| Path sumber | Instance tujuan |
| --- | --- |
| `src/shared/UILibrary` | `ReplicatedStorage.UILibrary` (ModuleScript dari `init.lua`) |
| `src/client` | `StarterPlayer.StarterPlayerScripts` |
| `src/client/Main.client.lua` | `StarterPlayer.StarterPlayerScripts.Main` (LocalScript), lalu `PlayerScripts.Main` saat Play |

Jangan memetakan seluruh root. `ui.lua` hanya arsip monolit asli; jangan jalankan bersama `Main`, karena akan membuat shell tambahan. Tes dan skrip validator bukan bagian runtime produksi.

## Sinkronisasi dan build

Jalankan dari root proyek setelah `default.project.json` dengan mapping di atas tersedia. Jika menggunakan Aftman, jalankan `aftman install` terlebih dahulu (membutuhkan akses jaringan untuk mengunduh tool).

```sh
rojo serve
```

Hubungkan plugin Rojo di Studio ke sesi tersebut. Alternatif build pada shell POSIX/Git Bash/WSL:

```sh
mkdir -p build
rojo build -o build/AstralLite.rbxlx
```

Pada PowerShell, buat direktori dengan `New-Item -ItemType Directory -Force build`, lalu jalankan perintah `rojo build` yang sama. Buka hasil `.rbxlx` di Studio dan tekan Play. Tanpa konfigurasi proyek, `rojo serve`/`build` belum dapat dipakai seperti contoh ini.

## Memakai shell Main

Shell membuat delapan halaman asli: `Home`, `Combat`, `Teleport`, `Player`, `Visuals`, `World`, `Misc`, `Settings`. Masing-masing hanya berisi judul dan layout; **tidak ada demo komponen otomatis atau fitur gameplay**. `Home` aktif pertama kali.

Dalam LocalScript klien lain:

```lua
local Players = game:GetService("Players")
local main = Players.LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("Main")
local UI, pages = main:WaitForChild("GetUI"):Invoke()

local toggle = UI:CreateToggle(pages.Settings, {
    Name = "Musik",
    LayoutOrder = 1,
    Default = false,
    Callback = function(enabled)
        print("Musik:", enabled)
    end,
})

local notification = UI:CreateNotification({
    Title = "Siap",
    Content = "Pengaturan telah dimuat",
    Type = "Success",
    Duration = 3,
})
notification:Show()
```

`GetUI` adalah **BindableFunction lokal** di `PlayerScripts.Main.GetUI`, bukan RemoteFunction. Ia dipublikasikan setelah shell siap dan mengembalikan `UI, pages` (map nama kategori ke ScrollingFrame). Jangan menganggapnya API server atau API penambahan kategori.

Kontrol shell: tarik topbar untuk memindah jendela; minimize menampilkan logo yang bisa ditarik; klik logo tanpa drag untuk memulihkan; close hanya menyembunyikan; `RightShift` membuka kembali saat input tidak diproses game dan tidak ada TextBox fokus.

## Memakai pustaka tanpa shell

```lua
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Library = require(ReplicatedStorage:WaitForChild("UILibrary"))

local gui = Instance.new("ScreenGui")
gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
local UI = Library.new({
    ScreenGui = gui,
    Theme = { Colors = { Primary = Color3.fromRGB(110, 190, 255) } },
})
local panel = Instance.new("Frame")
panel.Size = UDim2.fromOffset(320, 160)
panel.Parent = gui
local layout = Instance.new("UIListLayout")
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = panel
UI:CreateButton(panel, { Name = "Simpan", Callback = function() print("Simpan") end })

-- Saat pemilik layar selesai:
UI:Destroy()  -- komponen dan holder notifikasi; BUKAN gui atau panel milik pemanggil
-- gui:Destroy() dilakukan pemiliknya ketika seluruh layar memang ingin dihapus.
```

Tema menerima override parsial per grup hanya saat konstruksi; tidak ada pembaruan tema live. Factory dan metode komponen dari wrapper mendukung titik maupun kolon: `toggle.SetValue(true)` dan `toggle:SetValue(true)` setara. Gunakan `Library.new(...)`, bukan mengasumsikan semua helper juga mendukung dua gaya.

Pembuatan komponen tidak memanggil callback. Semua config menerima `LayoutOrder` integer finite (default `1`), `Name` string opsional, dan `Callback` function/nil yang divalidasi; tidak semua komponen menggunakan callback atau `Name` sebagai nama Instance (lihat referensi). `Destroy()` idempoten; metode komponen lain setelah destroy menghasilkan error, termasuk setelah notifikasi kedaluwarsa.

## Dokumentasi dan validasi

- [Arsitektur dan kepemilikan](docs/ARCHITECTURE.md)
- [Contoh seluruh 15 komponen](docs/COMPONENTS.md)
- [Referensi API lengkap, config, callback, dan batasan](docs/API_REFERENCE.md)
- [Migrasi dari monolit](docs/MIGRATION.md)
- [Audit sumber dan prosedur uji manual](docs/AUDIT.md)
- [Catatan perubahan](CHANGELOG.md)

Rencana validator opsional: `node scripts/validate.mjs`, **hanya setelah berkasnya tersedia**; pemeriksaan statis tidak menggantikan Studio. Rencana tes: `tests/Components.spec.lua` dengan petunjuk di `tests/README.md`; belum ada runner atau hasil tes yang dapat diklaim. Gunakan checklist manual dalam audit untuk memverifikasi rendering, input, callback, dan cleanup di Studio.
