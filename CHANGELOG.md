# Catatan perubahan

## 2.0.0 — Belum dirilis

Entry/package `2.0.0`; **release/tag belum dipublikasikan**. Validasi final sumber/tooling/dokumentasi **2026-11-02** selesai: 24 tes Node pass, 0 fail/skip; build bundle 20 modul v2.0.0 dan byte-exact check lulus; build/sourcemap Rojo 7.7.0-rc.1 lulus; validator 20 modul/15 factory dan kompilasi 24 berkas Lua lulus; editor 0 error/0 warning. [AUDIT](docs/AUDIT.md) mencatat hasil dan batas bukti. Studio source/bundle specs serta pengujian input/render/perangkat/memori belum dijalankan karena runtime Studio tidak tersedia.

### API dan distribusi baru

- API utama `AstralLite:CreateWindow(config)` → `window:CreateTab(config)` → 14 `tab:CreateX(config)`; Notification lewat `window:CreateNotification(config)` dan Show eksplisit. Window generik dimulai nol tab, tab pertama otomatis dipilih.
- Metadata Version dan ComponentNames sorted/frozen; window/tab/komponen kompatibel titik/kolon. Pola API terinspirasi WindUI tanpa dependensi, kode, atau branding salinan.
- Factory shell dependency-injected di `Core/Window.lua`; Main menjadi bootstrap tipis delapan kategori asli, isi hanya judul/layout, tanpa demo komponen/gameplay.
- Window memiliki GUI dan menyediakan CreateTab/GetTab/SelectTab, Show/Hide/Minimize/Restore/IsVisible/Destroy. Tab dinamis menyediakan Select/Destroy, Container, serta 14 factory tanpa parent dengan LayoutOrder otomatis per tab.
- `Main.GetUI` BindableFunction kini mengembalikan UI, pages, **window**; dua return awal kompatibel.
- `scripts/build.mjs` membangun source satu ModuleScript `dist/AstralLite.lua` dan manifest SHA-256 deterministik. Bundler leksikal/token-aware meresolusi static script.Child/Parent require, graph topologis, cache internal, dan menolak missing/cycle/dynamic/unreferenced dependencies, interpolated strings serta runtime script refs di library.
- `npm run build:check` mendeteksi artifact/manifest stale tanpa menulis. Node 18+, tanpa dependensi npm/runtime eksternal; tidak memakai loadstring, runtime external require, unduhan kode atau API executor.
- `scripts/validate.mjs` memeriksa output terkini, Rojo mapping/sourcemap opsional, API, keberadaan cakupan spec, API terlarang dan tautan dokumentasi; compiler Luau standar opsional untuk sintaks saja.
- Suite `tests/build.test.mjs` berisi 24 kasus Node untuk tooling (kasus compiler opsional mengikuti LUAU_COMPILER); dua spec Studio opt-in Components/Window menerima source default atau injeksi library bundle. Eksekusi final dengan LUAU_COMPILER aktif telah lulus 24/24 tanpa skip; dua spec Studio tetap belum dijalankan.
- Panduan rilis dengan checksum, instalasi manual bundle, dan pemisahan bukti Node/compiler/Rojo/Studio.

### Lifecycle dan koreksi

- `.new({ScreenGui, Theme?})` dan semua factory UI tingkat rendah tetap ada. UI.Destroy hanya komponen/holder, **bukan** GUI suplai; window.Destroy menghapus keseluruhan GUI buatannya.
- Komponen memakai scope state untuk guard explicit Destroy langsung, idempoten; metode lain setelah mati error. Window.IsVisible pengecualian: tetap false setelah destroy. Hapus root eksternal mengikuti penjadwalan signal Roblox.
- Ownership/wrapper komponen dipasang sebelum publication; konstruksi gagal/observer destroy dibersihkan. Factory tab menyalin config dan hanya memajukan order saat sukses; guard tambahan memeriksa window/tab setelah pemilihan tab awal.
- Helpers.Scope.Destroy secara rekursif menghancurkan scope descendant yang dikenal pada registry Helpers secara sinkron sebelum root.Destroy; wrapper segera menolak metode berdasarkan flag scope tanpa menunggu deferred signal.
- Notification tanpa config memakai default sama pada titik/kolon. Config false, Callback false, dan SetCallback(false) ditolak; gunakan nil untuk menghapus callback.
- Section mengonversi AbsoluteContentSize piksel ke tinggi logis melalui kalibrasi header di bawah UIScale. Spec skala 0,5/1/2 tersedia; belum diuji di Studio.
- Cleanup endpoint Main terikat GUI/script, tetapi self-Destroying script hanya upaya terbaik pada deferred signals; pemilik harus mengutamakan window.Destroy eksplisit sebelum menghancurkan script.

### Dipertahankan dari modularisasi terhadap arsip asli

- 15 jenis komponen, nama/metode lama, serta pemanggilan metode titik. Toggle positional `createToggle(title, order, parent)` berpindah ke config CreateToggle.
- Konstruksi silent; validasi Name/LayoutOrder/Callback, Options/values array padat disalin/di-deduplikasi, MaxSelections eksplisit finite integer nonnegatif (hilangkan untuk tanpa batas).
- MultiDropdown Default/Searchable, getter/metode tambahan, Slider Destroy dan koreksi snap/presisi/batas, ColorPicker RGB layout/render atomik, NumericOnly TextBox, Keybind capture cancellation, dan ProgressBar tween/rasio.
- Notification Show eksplisit; destroy/timeout langsung, bukan fade-out seperti arsip. Callback setter berbeda menurut komponen, tidak diseragamkan.
- Scope cleanup gesture/timer/tween; logo clamp inset-aware/konversi scale-offset; rebinding kamera/skala viewport dan guard RightShift saat TextBox fokus.
- Tema parsial per grup saat konstruksi saja; tidak ada live update, persistence, fitur gameplay, atau demo factory otomatis (arsip asli pun tidak ditemukan menjalankan demo otomatis).

### Kompatibilitas sumber dan prasyarat rilis

- `src/shared/UILibrary` sengaja dipertahankan. `default.project.json` sudah memetakan ReplicatedStorage.UILibrary dan StarterPlayerScripts; arsip/dist/tests tidak dipetakan.
- `ui.lua` arsip asli dan `aftman.toml` tetap tanpa perubahan. `.tools/` dan `build/` ignored; dist Lua/manifest adalah hasil yang perlu dilacak bersama source untuk rilis.
- Entry Version dan package.json.version sudah selaras 2.0.0. Bundler tetap membaca versi entry, bukan memvalidasi kecocokan package otomatis.
- Validasi sumber/build/tooling/dokumentasi sudah selesai; pengujian runtime Studio belum dilakukan. Belum ada release/tag/URL unduhan yang dipublikasikan.
