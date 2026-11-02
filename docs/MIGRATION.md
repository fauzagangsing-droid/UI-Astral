# Migrasi ke AstralLite 2.0.0

**2.0.0 belum dirilis; release belum dipublikasikan.** API window/tab terinspirasi pola WindUI tanpa dependensi, kode, atau branding salinan. Source modular tetap `src/shared/UILibrary` demi kompatibilitas Rojo; tidak perlu rename subtree menjadi AstralLite.

## Pilih jalur instalasi

| Jalur | Library/entry |
| --- | --- |
| Source Rojo | `default.project.json` yang sudah ada: `ReplicatedStorage.UILibrary` ← `src/shared/UILibrary`; StarterPlayerScripts ← `src/client`, menghasilkan Main |
| Satu ModuleScript | `npm run build` → `dist/AstralLite.lua` + manifest, pasang seluruh source Lua manual ke `ReplicatedStorage.AstralLite`; buat LocalScript bootstrap sendiri |

Konfigurasi, build/validate scripts, tes Node dan dua spec Studio tersedia. Validasi final sumber/tooling/dokumentasi **2026-11-02** selesai: 24/24 tes Node, 0 fail/skip; bundle 20 modul v2.0.0 dan byte-exact check; build/sourcemap Rojo 7.7.0-rc.1; validator 20 modul/15 factory dan kompilasi 24 Lua; editor 0 error/0 warning. Entry/package sudah selaras 2.0.0. Lihat [AUDIT.md](AUDIT.md); hasil Rojo tetap generated/ignored. Runtime Studio tidak tersedia, sehingga specs source/bundle serta uji input/render/perangkat/memori belum dijalankan.

Jangan jalankan Main sumber sekaligus bootstrap bundle yang membuat window kecuali menginginkan beberapa window. `ui.lua` tetap arsip asli, tidak dipetakan/dibundle; aftman tetap tidak diubah. Baseline asli hanya ui.lua/aftman tanpa config proyek dan tidak ditemukan demo factory otomatis (hanya delapan halaman dengan judul).

## Dari low-level modular ke window/tab

API lama tetap tersedia; jalur baru menghilangkan kebutuhan membuat ScreenGui/parent/layout sendiri:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AstralLite = require(ReplicatedStorage:WaitForChild("AstralLite"))
local window = AstralLite:CreateWindow({
    Title = "Pengaturan",
    Theme = { Colors = { Primary = Color3.fromRGB(120, 180, 255) } },
})
local settings = window:CreateTab({ Name = "Settings", Icon = "⚙" })
local toggle = settings:CreateToggle({
    Name = "Musik", Default = false,
    Callback = function(enabled) print(enabled) end,
})
toggle.SetValue(true) -- gaya titik lama tetap valid
```

CreateWindow generik mulai **nol tab**, bukan delapan. CreateTab memerlukan Name unik tidak kosong, Icon glyph string opsional; tab pertama dipilih. Pakai `window:GetTab`, `window:SelectTab`, `tab:Select`, dan `tab:Destroy` untuk navigasi dinamis.

| Sebelumnya | Sekarang disarankan | Tetap kompatibel |
| --- | --- | --- |
| `Library.new({ScreenGui=gui, Theme=...})` dan shell manual | `AstralLite:CreateWindow(config)` | `.new` tetap low-level, tidak membuat shell |
| `UI:CreateX(parent, config)` | `tab:CreateX(config)` untuk 14 jenis non-Notification | UI:CreateX tetap menerima parent GuiObject |
| `UI:CreateNotification(config)` | `window:CreateNotification(config)`, lalu Show | UI.CreateNotification tetap ada; tidak ada tab.CreateNotification |
| Seluruh order low-level default 1 | Tab memberi urutan otomatis per tab | Order eksplisit finite integer tetap diizinkan |
| Shutdown shell manual | `window:Destroy()` | UI.Destroy hanya komponen/holder, bukan ScreenGui suplai |

Factory tab menyalin config dangkal dan memakai maksimum order sukses + 1. Order eksplisit tinggi memajukan penghitung, negatif tidak menurunkannya; factory gagal tidak memajukan penghitung. Mencampur factory UI langsung tidak menyinkronkan penghitung tab. Untuk anak Section tetap gunakan `window.UI:CreateX(section.Container, config)` atau AddComponent.

Semua metode/factory window, tab, UI dan komponen mendukung dot/colon. Constructor `.new` memakai titik; fungsi H memakai titik dan scope memakai kolon. Jangan menganggap dukungan dua gaya berlaku pada semua fungsi internal.

## Main.GetUI kini tiga return

```lua
local Players = game:GetService("Players")
local main = Players.LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("Main")
local UI, pages, window = main:WaitForChild("GetUI"):Invoke()
assert(UI == window.UI and pages == window.Pages)
window:GetTab("Settings"):CreateLabel({ Text = "Siap" })
-- Kode lama masih sah:
UI:CreateButton(pages.Home, { Name = "Simpan", LayoutOrder = 1 })
```

Dua return pertama tidak berubah. Main sekarang bootstrap tipis yang membuat delapan tab judul-saja Home, Combat, Teleport, Player, Visuals, World, Misc, Settings; implementasi shell ada di Core/Window. GetUI adalah BindableFunction klien, tidak ada otomatis pada generic CreateWindow/bundle, dan bukan remote. Window dapat menambah tab setelah Main berjalan.

## Dari monolit ui.lua

Factory lokal asli berpindah ke API publik instance. Toggle adalah perubahan bentuk khusus:

```lua
-- Lama: createToggle("Musik", 1, parent)
-- Low-level kompatibel:
local toggle = UI:CreateToggle(parent, { Name = "Musik", LayoutOrder = 1 })
-- Atau API utama: settings:CreateToggle({ Name = "Musik" })
```

Nama/metode hasil komponen lama tetap tersedia; setter titik masih bekerja. Section.AddComponent kini konsisten `section:AddComponent(child)` atau `section.AddComponent(child)` tanpa self dummy.

Tambahan dibanding monolit: Destroy Slider, GetText Button/Label, expanded getter/setter Dropdown/MultiDropdown/ColorPicker, Default/Searchable MultiDropdown, GetValue/SetValue alias dan CancelCapture Keybind, getter/setter title/content Notification, Container/GetExpanded Section, getter Paragraph, serta Version/ComponentNames/CreateWindow dan seluruh API window/tab.

## Pengetatan kontrak dan perbaikan

- Config false ditolak (bukan alias config kosong); Name harus string; Callback function/nil, termasuk SetCallback. `false` bukan cara mematikan callback, gunakan nil. LayoutOrder finite integer; default low-level/Notification 1, tab otomatis.
- Konstruksi selalu silent. Tidak ada flag silent setter publik universal.
- Options/values harus array padat string/angka finite, disalin/di-deduplikasi. Dropdown default invalid menjadi nil dan SetValue invalid return false, valid true.
- MultiDropdown Default dan SetValues difilter opsi/batas. Searchable didukung. MaxSelections eksplisit **integer finite >= 0**; hilangkan field untuk tanpa batas. `math.huge` eksplisit ditolak; 0 berarti tidak ada pilihan.
- Slider swap batas sebelum Default, step <= 0 menjadi 1, snap/format memperhitungkan asal pecahan, step kecil dan half-step. Masih floating-point biasa, bukan presisi tanpa batas.
- ColorPicker.SetColor sinkron preview/tiga kanal secara atomik lalu callback sekali. SetExpanded memerlukan boolean, tidak seperti beberapa komponen lain yang memakai truthiness.
- NumericOnly TextBox menyaring satu minus awal dan satu titik, termasuk default/setter; hasil tetap string dan bisa belum berupa angka lengkap. Keybind adalah pemilih key, bukan dispatcher hotkey; Escape/touch membatalkan capture.
- Section menghitung tinggi logis dengan kalibrasi UIScale dari header 32-unit; listener perubahan header/layout menyesuaikan skala ancestor. Spec tersedia, bukan bukti Studio telah lulus.
- Scope guard explicit destroy sinkron: Helpers secara rekursif menghancurkan scope descendant yang dikenal registry-nya sebelum root.Destroy; wrapper segera melihat flag scope sehingga metode descendant terkelola ikut ditolak sebelum Destroy return. Penghapusan root eksternal tetap mengikuti penjadwalan Roblox.
- CreateTab memeriksa flag window/tab lagi setelah pemilihan tab awal; penghancuran oleh observer saat seleksi tidak menghasilkan API tab mati yang dikembalikan seolah sukses.

## Callback setter tidak diseragamkan

| Aksi | Callback |
| --- | --- |
| Semua factory | Tidak |
| Toggle.SetValue, Slider.SetValue, ProgressBar.SetValue | Ya setiap pemanggilan, termasuk nilai efektif sama |
| ColorPicker.SetColor | Sekali setelah render atomik, termasuk sama |
| Dropdown.SetValue | Hanya jika anggota opsi |
| MultiDropdown.SetValues | Ya setelah normalisasi, termasuk sama/kosong |
| Dropdown/MultiDropdown.SetOptions | Tidak meski pilihan hilang |
| TextBox.SetValue/Clear; Keybind.SetKey/SetValue | Tidak |
| TextBox input | Hanya submit Enter pada FocusLost |
| SearchBox.SetValue/Clear | Melalui perubahan Text bila berubah |
| Setter teks/judul/isi/expanded, SetCallback, Destroy | Tidak |

## Notifikasi dan ownership

```lua
local notice = window:CreateNotification({ Title = "Siap", Duration = 3 })
notice:Show() -- tetap wajib eksplisit
-- notice:Destroy() langsung menghapus, bukan fade-out
-- Saat menutup seluruh aplikasi, pemiliknya:
-- window:Destroy()
```

Notification sekarang hidden dalam holder sejak factory; Show mulai timer sekali. Show ulang tidak restart, duration negatif jadi 0, 0 bukan permanen. Destroy/timeout langsung menghapus, berbeda dari fade-out arsip. Setelah timeout hanya Destroy yang tetap valid; buat notifikasi baru untuk tampil lagi.

`window:Destroy()` memiliki GUI buatannya, tab/maps, seluruh komponen/listener. `window:IsVisible()` false sesudahnya; Destroy idempoten, metode window lain error. Tab/component juga idempoten tetapi getter/metode lain error setelah mati. Menghapus Section menghancurkan descendant termasuk Instance eksternal yang direparent.

**Jangan mengganti window.Destroy dengan UI.Destroy.** `.new({ScreenGui=gui})` tidak mengambil ownership gui; UI.Destroy hanya komponen/holder dan meninggalkan shell. Jika memakai Main, endpoint bisa masih mengembalikan UI mati setelah hanya UI.Destroy. Explicit window.Destroy menyelesaikan ownership penuh.

Utamakan `window:Destroy()` **sebelum script pemilik dihancurkan**. Hook script.Destroying Main hanya upaya terbaik pada deferred signals. Close/Hide/Minimize tetap reversibel, bukan cleanup; RightShift dapat memulihkan semua window hidup, bukan hanya yang terakhir aktif.

## Distribusi dan verifikasi

Gunakan Node 18+ (`npm run build`, `build:check`, `npm test`, `npm run validate`), compiler opsional, Rojo, dan Studio sebagai lapisan berbeda. Dua spec Studio opt-in menerima hierarchy sumber atau injeksi hasil require bundle; instruksi ada di [tests/README.md](../tests/README.md). Jangan memetakan/mengautorun spec produksi.

Entry Version dan package.json.version sudah selaras 2.0.0; build dan validasi akhir sudah selesai. Untuk perubahan sumber/versi berikutnya, rebuild dan ulangi pemeriksaan sesuai [RELEASING.md](RELEASING.md). Uji runtime Studio tetap belum dilakukan; belum ada release/tag/URL publik yang diterbitkan.
