# Migrasi dari ui.lua

## Baseline

Repositori asli hanya berisi `ui.lua` dan `aftman.toml`, tanpa konfigurasi proyek Rojo. `ui.lua` membangun shell secara langsung dan mendefinisikan factory lokal; tidak mengembalikan ModuleScript API. Komentar “demonstration” bukan bukti adanya demo komponen otomatis: inspeksi menemukan delapan halaman dengan judul saja, tanpa pemanggilan demo factory.

Arsip `ui.lua` tetap dipertahankan, tidak dipetakan ke runtime baru. `aftman.toml` tidak berubah. Jangan menjalankan arsip bersama Main.

## 1. Pindahkan entry point

Mapping yang akan digunakan:

| Sumber | Tujuan |
| --- | --- |
| `src/shared/UILibrary` | `ReplicatedStorage.UILibrary` |
| `src/client` | `StarterPlayer.StarterPlayerScripts` |
| `Main.client.lua` dalam direktori klien | LocalScript `Main`, kemudian `PlayerScripts.Main` saat Play |

`default.project.json` masih direncanakan saat penulisan. Setelah tersedia, ikuti `rojo serve` atau `rojo build -o build/AstralLite.rbxlx` dalam [README](../README.md). Jangan memetakan root secara keseluruhan atau mengasumsikan build telah diuji.

## 2. Dapatkan instance library

Untuk integrasi ke shell bawaan:

```lua
local Players = game:GetService("Players")
local main = Players.LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("Main")
local UI, pages = main:WaitForChild("GetUI"):Invoke()
```

GetUI adalah BindableFunction klien yang mengembalikan UI dan map ScrollingFrame delapan kategori asli. Bukan RemoteFunction, bukan daftar demo, bukan factory tab.

Untuk layar sendiri:

```lua
local Library = require(game:GetService("ReplicatedStorage"):WaitForChild("UILibrary"))
local UI = Library.new({
    ScreenGui = gui,
    Theme = { Colors = { Primary = Color3.fromRGB(120, 180, 255) } },
})
```

Constructor wajib di klien dengan ScreenGui dari pemanggil. Komponen memerlukan parent GuiObject, bukan ScreenGui. Tema hanya override saat konstruksi, tidak ada setter tema live.

## 3. Ganti factory lokal dengan factory instance publik

Semua nama factory dan metode lama dipertahankan pada API baru, dengan dua perubahan bentuk utama: factory sekarang milik instance UI dan toggle positional menjadi config. Pengetatan validasi/perilaku dijelaskan setelah tabel.

| Bentuk lama | Bentuk baru |
| --- | --- |
| `createToggle(title, order, parent)` | `UI:CreateToggle(parent, {Name=title, LayoutOrder=order})` |
| `CreateSlider(parent, config)` dan 12 factory parent lain | `UI:CreateSlider(parent, config)` dan `UI:CreateX(parent, config)` sesuai jenis |
| `CreateNotification(config)` | `UI:CreateNotification(config)`, kemudian `notification:Show()` |

Jumlah keseluruhan tetap 15 jenis: **14 menerima parent, satu Notification tanpa parent**. Contoh toggle:

```lua
-- Sebelumnya di dalam monolit:
-- local toggle = createToggle("Musik", 1, pages.Settings)
-- toggle.SetCallback(function(enabled) print(enabled) end)

local toggle = UI:CreateToggle(pages.Settings, {
    Name = "Musik", LayoutOrder = 1, Default = false,
    Callback = function(enabled) print(enabled) end,
})
toggle.SetValue(true) -- gaya titik lama tetap berfungsi
toggle:SetValue(false) -- kolon juga didukung
```

Wrapper mendukung titik/kolon pada factory dan metode komponen; constructor tetap `Library.new(config)`. Section.AddComponent sekarang konsisten dengan dua gaya: `section:AddComponent(component)` atau `section.AddComponent(component)`. Tidak perlu argumen self dummy lama.

## 4. Sesuaikan validasi dan state

- Semua config: LayoutOrder finite integer default 1, Name string bila diberikan, Callback function/nil. Pembuatan silent.
- Angka yang divalidasi menolak NaN/infinity. Keybind memerlukan Enum.KeyCode; ColorPicker memerlukan Color3 dengan kanal finite. ColorPicker.SetExpanded wajib boolean.
- Options dan values: array padat string/angka finite, disalin dan di-deduplikasi. Jangan mengirim dictionary, array berlubang, boolean, atau objek; perubahan tabel input setelah factory bukan pembaruan live.
- Dropdown.Default yang tidak ada di opsi menjadi nil. SetValue invalid mengembalikan false tanpa callback; valid mengembalikan true dan menutup daftar.
- MultiDropdown kini mendukung Default dan Searchable. Default/SetValues difilter, di-deduplikasi, serta dibatasi MaxSelections. MaxSelections eksplisit wajib integer finite >= 0; hilangkan untuk tanpa batas. `math.huge` eksplisit kini tidak valid. Nilai 0 berarti tidak boleh ada pilihan.
- Slider menukar Min/Max sebelum clamp Default; snap/label mengikuti presisi batas dan step, tidak lagi dibatasi pembulatan enam desimal. Step <= 0 tetap menjadi 1.
- NumericOnly TextBox kini membatasi minus ke depan dan titik desimal tunggal, termasuk saat Default/SetValue. Hasil tetap string dan belum tentu angka lengkap.
- Keybind Escape membatalkan, Unknown saat capture diabaikan, mouse/touch dapat membatalkan. Callback tetap pemilihan binding, bukan aktivasi hotkey.
- ColorPicker.SetColor menyelaraskan preview dan tiga kanal dari satu warna, lalu callback sekali; setter lama dapat memakai state kanal yang termutasi bertahap.

## 5. Jangan menyeragamkan callback setter

| Aksi | Kontrak baru yang harus diikuti |
| --- | --- |
| Toggle.SetValue, Slider.SetValue, ProgressBar.SetValue | Callback setiap panggilan, termasuk nilai efektif sama |
| ColorPicker.SetColor | Callback sekali setelah pembaruan atomik, termasuk warna sama |
| Dropdown.SetValue | Callback hanya jika nilai anggota opsi |
| MultiDropdown.SetValues | Callback setelah normalisasi, termasuk sama/kosong |
| Dropdown/MultiDropdown.SetOptions | Silent walaupun pilihan terhapus |
| TextBox.SetValue/Clear, Keybind.SetKey/SetValue | Silent |
| TextBox interaksi | Callback hanya submit Enter pada FocusLost |
| SearchBox.SetValue/Clear | Callback melalui perubahan Text bila berubah |
| Factory, setter teks/judul/isi/expanded, SetCallback, Destroy | Silent |

Tidak ada argumen silent publik yang universal. Jangan mengandalkan callback saat SetOptions untuk menyinkronkan model; baca hasilnya sendiri jika perlu.

## 6. Kelola destroy dan notifikasi

```lua
local notice = UI:CreateNotification({ Title = "Siap", Duration = 3 })
notice:Show() -- tetap eksplisit, bukan otomatis saat factory
-- notice:Destroy() menghapus langsung bila perlu dibatalkan

UI:Destroy() -- seluruh komponen dan holder, bukan ScreenGui milik pemanggil
-- gui:Destroy() hanya bila pemilik layar hendak menghapus keseluruhan layar
```

Notification sekarang berada dalam holder sejak dibuat, tetapi invisible sampai Show. Show ulang saat hidup tidak restart timer; timeout menghancurkan root. **Destroy dan timeout kini langsung menghapus, bukan fade-out 0,2 detik seperti arsip.** Duration negatif menjadi 0; 0 bukan permanen. Jangan memakai kembali objek setelah timeout.

Seluruh komponen kini memiliki Destroy, termasuk Slider yang dahulu tidak memilikinya. Destroy idempoten; semua metode lain setelah destroy error (sebelumnya banyak metode tidak memiliki guard). Penghapusan parent/root eksternal juga menginvalidasi API. Anak Section ikut mati ketika Section dihapus.

`UI:Destroy()` tidak menghapus shell Main/GetUI. Jika endpoint masih hidup, Invoke bisa mengembalikan UI yang sudah destroyed; jangan memakainya sebagai reset shell. Close hanya menyembunyikan; RightShift membuka lagi bila input tidak diproses dan TextBox tidak fokus.

## Tambahan API tanpa menghapus metode lama

- Button/Label: GetText.
- Dropdown/MultiDropdown: SetExpanded dan GetExpanded.
- MultiDropdown: config Default dan Searchable.
- Keybind: GetValue/SetValue alias, CancelCapture.
- ColorPicker: SetExpanded/GetExpanded.
- Notification: GetTitle/SetTitle/GetContent/SetContent dan `_instance`.
- Section: Container dan GetExpanded; AddComponent tetap tersedia.
- Paragraph: GetTitle/GetContent.
- Slider: Destroy; seluruh komponen memperoleh lifecycle guard melalui wrapper.

## Checklist penerapan

1. Siapkan mapping Rojo, jangan ikutkan arsip.
2. Jalankan pada Play/client, periksa delapan halaman tanpa demo otomatis.
3. Pindah ke UI dari GetUI atau constructor sendiri; ubah toggle positional.
4. Tetapkan LayoutOrder eksplisit bila urutan penting, terutama karena default semua sama-sama 1.
5. Periksa tipe config, Options, MaxSelections, dan kebutuhan callback setter.
6. Uji notifikasi dengan Show eksplisit, timeout, dan Destroy langsung.
7. Uji destroy root/parent/GUI dan referensi API setelahnya di Studio.

Belum ada hasil build/Studio yang diklaim. Prosedur verifikasi manual dan keterbatasan lain tercatat dalam [AUDIT.md](AUDIT.md).
