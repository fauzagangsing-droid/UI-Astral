# AstralLite

Pustaka UI Roblox modular dengan distribusi **satu ModuleScript**, API window/tab yang terinspirasi pola penggunaan WindUI, tetapi **tanpa dependensi WindUI, kode, atau branding yang disalin**. Tampilan tetap identitas ASTRAL LITE. Tidak ada paket runtime eksternal, unduhan/eksekusi kode lewat URL, `loadstring`, atau API executor.

**Versi `2.0.0` — belum dirilis; belum ada release/tag yang dipublikasikan.** Validasi sumber, tooling, dan dokumentasi selesai **2026-11-02**: 24 tes Node lulus (0 gagal/skip), bundle 20 modul v2.0.0 dihasilkan dan lolos pemeriksaan byte-exact, build/sourcemap Rojo 7.7.0-rc.1 lulus, validator lulus untuk 20 modul/15 factory dan mengompilasi 24 berkas Lua; diagnostik editor 0 error/0 warning. Entry/package sudah selaras 2.0.0. [Hasil lengkap](docs/AUDIT.md) terpisah dari pengujian Studio source/bundle, input/render/perangkat/memori yang **belum dijalankan karena runtime Studio tidak tersedia**.

## Persyaratan

- Roblox Studio, mode **Play/client**, untuk pemakaian dan uji UI.
- Node.js **18+** dan npm untuk build, tes Node, serta validasi statis. `package.json` memakai modul bawaan Node, tanpa dependensi npm; tidak memerlukan `npm install` untuk perintah yang tersedia.
- Rojo CLI untuk alur sumber/build place; plugin Rojo Studio untuk sinkronisasi. Tidak wajib untuk pemasangan bundle manual.
- Aftman opsional; `aftman.toml` tetap tidak diubah, pin Rojo `7.7.0-rc.1`.
- Compiler Luau standar opsional untuk pemeriksaan sintaks, bukan emulator Roblox. Tool lokal `.tools/` diabaikan Git dan bukan dependensi pustaka.

## Mulai cepat: satu ModuleScript

1. Dari root proyek, jalankan:

   ```sh
   npm run build
   ```

   Hasil: `dist/AstralLite.lua` dan `dist/AstralLite.manifest.json`. File Lua berisi **source ModuleScript lengkap yang mengembalikan tabel library**, bukan LocalScript bootstrap, bytecode, atau installer. Build final 2026-11-02 sudah menghasilkan 20 modul v2.0.0 dan lolos build:check; rebuild diperlukan bila sumber berubah lagi.
2. Di Studio, buat ModuleScript bernama **AstralLite** di **ReplicatedStorage**. Ganti seluruh Source dengan isi lengkap `dist/AstralLite.lua`; tidak perlu membuat anak modul. Jangan membungkusnya dengan `loadstring` atau memakai URL.
3. Buat LocalScript pada StarterPlayerScripts, lalu gunakan:

   ```lua
   local ReplicatedStorage = game:GetService("ReplicatedStorage")
   local AstralLite = require(ReplicatedStorage:WaitForChild("AstralLite"))
   local window = AstralLite:CreateWindow({ Title = "Panel saya" })
   local home = window:CreateTab({ Name = "Home", Icon = "⌂" })
   local toggle = home:CreateToggle({
       Name = "Musik", Default = false,
       Callback = function(enabled) print("Musik:", enabled) end,
   })
   local notice = window:CreateNotification({ Title = "Siap", Duration = 3 })
   notice:Show()
   -- Saat pemilik aplikasi selesai, sebelum menghancurkan script:
   -- window:Destroy()
   ```

`CreateWindow()` generik dimulai dengan **nol tab**. Tab pertama otomatis dipilih. Ada **15 komponen total**: 14 `tab:CreateX(config?)` dan Notification melalui `window:CreateNotification(config?)` + `:Show()`. Factory/metode window, tab, UI tingkat rendah, dan komponen mendukung titik/kolon. `.new(config)` serta fungsi helper tetap mengikuti bentuk pemanggilannya sendiri.

**Pilih satu bootstrap.** Jangan menjalankan contoh bundle yang membuat window sekaligus `Main` bawaan sumber atau arsip `ui.lua`, kecuali memang ingin beberapa window. Require library saja tidak membuat UI, tetapi setiap pemanggilan CreateWindow/Main membuat window tersendiri.

## Pengembangan sumber dengan Rojo

Struktur `src/shared/UILibrary` sengaja dipertahankan untuk kompatibilitas. `default.project.json` yang tersedia memetakan:

| Sumber | Instance |
| --- | --- |
| `src/shared/UILibrary` | `ReplicatedStorage.UILibrary` (ModuleScript dari init.lua) |
| `src/client` | `StarterPlayer.StarterPlayerScripts` |
| `src/client/Main.client.lua` | LocalScript Main, kemudian `PlayerScripts.Main` saat Play |

`dist`, tes, dan arsip tidak dipetakan. Jalankan `rojo serve`, lalu hubungkan plugin Studio. Untuk membangun place pada shell POSIX/Git Bash:

```sh
mkdir -p build
rojo build -o build/AstralLite.rbxlx
```

PowerShell: buat folder dengan `New-Item -ItemType Directory -Force build`, lalu perintah build yang sama. Bila memilih Aftman, `aftman install` dapat menyiapkan tool (memerlukan jaringan). `build/` dan `.tools/` ignored; hasil place bukan artefak source bundle yang harus dilacak untuk rilis.

Main sekarang bootstrap tipis: CreateWindow lalu delapan tab asli `Home`, `Combat`, `Teleport`, `Player`, `Visuals`, `World`, `Misc`, `Settings`, masing-masing hanya judul/layout. Tidak ada demo komponen otomatis atau fitur gameplay.

```lua
local Players = game:GetService("Players")
local main = Players.LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("Main")
local UI, pages, window = main:WaitForChild("GetUI"):Invoke()
window:GetTab("Settings"):CreateButton({ Name = "Simpan" })
-- API lama tetap dapat dipakai:
UI:CreateLabel(pages.Home, { Text = "Siap", LayoutOrder = 1 })
```

GetUI adalah **BindableFunction lokal**, bukan remote; return pertama/kedua kompatibel, ketiga adalah window pemilik. API tingkat rendah tetap `AstralLite.new({ScreenGui=gui, Theme=partialTheme})`, dengan `UI:CreateX(parent, config)` untuk parent GuiObject, bukan ScreenGui.

## Siklus hidup dan batas penting

- `window:Destroy()` memiliki dan menghapus seluruh GUI, tab, komponen, serta listener window. Idempoten; `window:IsVisible()` sesudahnya false, metode window lain selain Destroy error.
- `UI:Destroy()` tingkat rendah hanya menghapus komponen/holder, **bukan ScreenGui suplai atau shell window**. Bukan pengganti window.Destroy. Explicit scope.Destroy juga secara rekursif menghancurkan scope descendant yang dikenal Helpers secara sinkron sebelum root.Destroy; wrapper segera melihat flag destroyed.
- Utamakan destroy eksplisit sebelum script pemilik dihancurkan; handler `script.Destroying` Main bersifat upaya terbaik pada deferred signals, bukan jaminan cleanup saat script berhenti.
- Hide/close hanya menyembunyikan. Minimize menampilkan logo; klik tanpa drag memulihkan. RightShift membuka semua window yang memasang listener, saat input tidak diproses dan TextBox tidak fokus.
- Tema parsial per grup hanya saat konstruksi, tanpa live update. Pembuatan komponen silent; callback setter berbeda antarjenis.
- LayoutOrder tingkat rendah default 1; factory tab memakai urutan otomatis per tab. Config false, Name bukan string, dan Callback bukan function/nil ditolak.
- Topbar drag belum di-clamp, capture key independen, dan gamepad belum diuji. Logo memakai aset Roblox yang ketersediaannya bergantung izin/moderasi platform.

## Struktur proyek

```text
UI SCRIPT/
├── README.md, CHANGELOG.md, package.json
├── aftman.toml, default.project.json, .gitignore
├── ui.lua                         # arsip asli, tidak dipetakan
├── src/
│   ├── client/Main.client.lua     # bootstrap delapan tab + GetUI
│   └── shared/UILibrary/          # path dipertahankan untuk Rojo
│       ├── init.lua               # Version, ComponentNames, CreateWindow, new
│       ├── Theme.lua, Helpers.lua
│       ├── Core/Window.lua        # factory shell/window/tab
│       └── Components/
│           ├── init.lua
│           └── 15 modul komponen
├── scripts/build.mjs, validate.mjs
├── tests/
│   ├── build.test.mjs
│   ├── Components.spec.lua, Window.spec.lua
│   └── README.md
├── docs/
│   ├── ARCHITECTURE.md, COMPONENTS.md, API_REFERENCE.md
│   └── MIGRATION.md, AUDIT.md, RELEASING.md
├── dist/                          # hasil npm run build, dilacak untuk rilis
│   ├── AstralLite.lua
│   └── AstralLite.manifest.json
├── build/                         # generated/ignored, termasuk place/sourcemap
└── .tools/                        # tool lokal opsional/ignored
```

`dist/` berisi bundle final dan manifest hasil build tervalidasi 2026-11-02; keberadaan artefak tidak berarti release/tag sudah dipublikasikan. `build/AstralLite.rbxlx` dan sourcemap tetap generated/ignored.

## Build dan pemeriksaan

```sh
npm run build
npm run build:check
npm test
npm run validate
# Opsional, bila compiler lokal tersedia:
npm run validate -- --compiler=.tools/luau/luau-compile.exe
```

- Build memakai bundler leksikal/token-aware khusus: static require script.Child/Parent, graph dependensi topologis, cache internal, normalisasi sumber dan SHA-256 deterministik. Tidak ada loadstring, require eksternal, atau referensi script runtime dalam bundle.
- `build:check` menolak bundle/manifest hilang atau stale tanpa menulis output. Validator juga memerlukan output terkini.
- Eksekusi final `LUAU_COMPILER=.tools/luau/luau-compile.exe npm test` lulus **24 tes, 24 pass, 0 fail, 0 skip**. Ini tes tooling Node, bukan tes Studio. Pada eksekusi lain tanpa environment compiler, kasus opsional dapat dilewati.
- Validator memeriksa mapping, API, keberadaan cakupan tes, API terlarang, tautan lokal, dan opsional sintaks via compiler; bukan menjalankan tes Roblox.
- Dua spec Studio opt-in dapat memakai hierarchy sumber atau injeksi tabel library bundle. Petunjuk ada di [tests/README.md](tests/README.md); keduanya belum dijalankan di Studio.

## Dokumentasi

[Arsitektur](docs/ARCHITECTURE.md) · [Contoh 15 komponen](docs/COMPONENTS.md) · [Referensi API](docs/API_REFERENCE.md) · [Migrasi](docs/MIGRATION.md) · [Audit dan VALIDATION](docs/AUDIT.md) · [Prosedur rilis](docs/RELEASING.md) · [Catatan perubahan](CHANGELOG.md)

Entry Version dan `package.json.version` sudah sama-sama `2.0.0`; tidak ada selisih versi yang terbuka. Bundler mengambil versi dari entry, sehingga kecocokan package tetap perlu dijaga pada perubahan berikutnya. Arsip `ui.lua` dan `aftman.toml` tidak berubah. Release/tag belum dipublikasikan.
