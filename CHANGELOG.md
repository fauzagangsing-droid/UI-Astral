# Catatan perubahan

## Belum dirilis — modularisasi ASTRAL LITE

Catatan berdasarkan inspeksi modul baru terhadap arsip `ui.lua`. Ini bukan pernyataan bahwa build Rojo atau pengujian Studio telah lulus.

### Ditambahkan

- Entry ModuleScript `UILibrary` dengan `Library.new({ScreenGui, Theme?})`, context terpisah, registry Components, Theme, dan Helpers.
- Factory publik per instance UI untuk seluruh 15 jenis: 14 `CreateX(parent, config)` dan satu `CreateNotification(config)`.
- Wrapper titik/kolon, validasi config umum, konstruksi staging dengan cleanup bila gagal, registry lifecycle, dan `UI:Destroy()`.
- Dukungan config Name string, LayoutOrder finite integer default 1, serta validasi Callback function/nil di semua factory.
- Override tema parsial per grup saat konstruksi; default disalin per library, tanpa live update.
- MultiDropdown.Default dan Searchable; normalisasi opsi/nilai dan validasi MaxSelections finite integer nonnegatif.
- Getter/metode tambahan: GetText pada Button/Label; expanded pada Dropdown/MultiDropdown/ColorPicker; alias nilai dan CancelCapture pada Keybind; getter/setter teks Notification; Container/GetExpanded pada Section; getter Paragraph; Destroy pada Slider.
- Shell `Main.client.lua` dengan GetUI BindableFunction lokal di `PlayerScripts.Main`, mengembalikan UI dan map delapan halaman asli yang hanya berisi judul.
- Dokumentasi Indonesia: panduan, arsitektur, contoh 15 komponen, referensi API, migrasi, dan audit.

### Diubah dan diperbaiki

- Toggle positional `createToggle(title, order, parent)` menjadi `UI:CreateToggle(parent, config)`; metode titik lama tetap kompatibel melalui wrapper.
- Destroy komponen idempoten; semua metode lain setelah destroy error. Library menghancurkan komponen dan holder notifikasi, **bukan** ScreenGui yang disuplai.
- Cleanup scope untuk koneksi, timer, dan tween; listener drag global hanya aktif selama gesture dan melacak touch pemulai.
- Slider menormalisasi batas sebelum Default, memperbaiki snap/presisi label dan half-step desimal. ProgressBar membatalkan tween lama dan menangani rasio rentang finite ekstrem.
- Options/values kini array padat string/angka finite, disalin dan di-deduplikasi. Dropdown menolak pilihan di luar opsi; SetOptions tetap silent.
- ColorPicker menambahkan layout kanal, pembaruan warna atomik, dan satu callback setelah SetColor.
- NumericOnly TextBox menyaring satu minus awal dan satu titik desimal. Callback submit tetap string dan hanya pada Enter.
- Keybind memvalidasi Enum.KeyCode, mendukung pembatalan Escape/touch, dan membersihkan koneksi capture.
- Section menghitung tinggi dari layout tanpa feedback loop AutomaticSize.
- Main mengoreksi koordinat drag logo scale/offset, clamp inset-aware, pembeda klik/drag, skala viewport kecil, rebinding kamera, dan guard RightShift ketika TextBox fokus.

### Perubahan perilaku penting

- Notification tetap memerlukan Show eksplisit. Destroy dan timeout sekarang **langsung menghapus**, bukan fade-out seperti arsip; timer dibatalkan saat cleanup.
- MaxSelections eksplisit tidak menerima infinity; hilangkan field untuk tanpa batas, atau gunakan 0 untuk melarang pilihan.
- Konstruksi silent; callback setter tetap berbeda antarjenis. TextBox/Keybind setter silent, SearchBox mengikuti perubahan Text, setter nilai interaktif lain umumnya mengirim callback. Lihat referensi sebelum migrasi.
- Tidak ada fitur gameplay, dependensi runtime eksternal, API executor, atau demo komponen otomatis. Arsip asli juga tidak ditemukan menjalankan demo factory otomatis.

### Dipertahankan dan direncanakan

- `ui.lua` tetap arsip asli, tidak untuk dipetakan ke runtime. `aftman.toml` tetap tanpa perubahan.
- Mapping Rojo direncanakan: `src/shared/UILibrary` ke `ReplicatedStorage.UILibrary`; `src/client` ke `StarterPlayer.StarterPlayerScripts`, menghasilkan LocalScript Main.
- `default.project.json`, `tests/Components.spec.lua`, `tests/README.md`, serta validator statis opsional `scripts/validate.mjs` belum tersedia pada inspeksi ini. Jangan menganggapnya sudah dibuat atau tesnya sudah lulus.
- Build `rojo build -o build/AstralLite.rbxlx` dan pengujian Studio masih perlu dijalankan setelah konfigurasi tersedia; prosedur ada di README dan audit.
