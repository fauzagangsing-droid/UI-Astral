# Audit sumber dan VALIDATION — 2.0.0 belum dirilis

## Ruang lingkup dan bukti

Baseline asli terdiri dari **dua berkas**, `ui.lua` (2.043 baris) dan `aftman.toml`, tanpa konfigurasi Rojo saat itu. Keadaan sekarang sudah memiliki `default.project.json`, source modular termasuk Core/Window, Main tipis, bundler/validator, package.json, tes Node dan dua spec Studio. Path `src/shared/UILibrary` sengaja dipertahankan untuk kompatibilitas Rojo, bukan kelalaian rename.

Audit ini memisahkan pembacaan sumber, validasi tooling, dan runtime. **2026-11-02:** eksekusi final pekerjaan utama telah berhasil untuk tes Node, bundle/check, Rojo, validator/compiler dan diagnostik editor, sesuai hasil yang dilaporkan pemilik pekerjaan utama pada tabel di bawah. Sesi ini mencatat hasil tersebut dan memeriksa perubahan lifecycle/versi, bukan mengklaim menjalankan ulang seluruh pipeline. Entry/package **2.0.0, belum dirilis; release/tag belum dipublikasikan**. Runtime Studio tidak tersedia, sehingga pengujian Studio belum dijalankan. Perubahan sesi hanya delapan dokumen; sumber/config/toolchain/tes/output, termasuk tests/README.md, tidak diedit. Arsip ui.lua dan aftman.toml tetap tidak berubah.

`ui.lua` menyebut “UI-only demonstration”, tetapi tidak ditemukan pemanggilan demo factory otomatis. Loop asli hanya membuat halaman/judul/tab lalu memilih Home. Main mempertahankan delapan kategori Home, Combat, Teleport, Player, Visuals, World, Misc, Settings, isi awal hanya judul/layout. **Generic CreateWindow sendiri nol tab**, delapan tab berasal dari Main. Tidak ada gameplay dari nama kategori. Inspirasi pola API WindUI tidak memasukkan dependensi, kode, atau branding salinan.

## Inventaris fungsi asli

Semua factory asli merupakan fungsi lokal dalam monolit, bukan export ModuleScript.

| Kelompok | Fungsi bernama dalam ui.lua |
| --- | --- |
| Utilitas dan shell | `make`, `tween`, `updateScale`, `topbarButton`, `selectPage`, `createPage`, `createTab`, `createPageTitle`, `cardRow`, `getNotificationHolder` |
| Factory (15) | `createToggle`, `CreateSlider`, `CreateButton`, `CreateDropdown`, `CreateMultiDropdown`, `CreateTextBox`, `CreateKeybind`, `CreateColorPicker`, `CreateNotification`, `CreateSection`, `CreateLabel`, `CreateParagraph`, `CreateDivider`, `CreateProgressBar`, `CreateSearchBox` |
| Nested Toggle/Slider | `apply`; `snap`, `render`, `setValue`, `updateFromInput` |
| Nested Dropdown | `updateSize`, `setExpanded`; `rebuild` ditugaskan melalui forward declaration |
| Nested MultiDropdown | `isSelected`, `refreshHeader`, `rebuild`, `setExpanded` |
| Nested Keybind | `stopCapture` |
| Nested ColorPicker | `applyColor`, `channelRow`, `setExpanded`; di channelRow: `set`, `updateFromInput` |
| Nested Notification/Section/ProgressBar | `destroy`; `setExpanded`; `render` |

Selain fungsi bernama, tabel API mengandung closure getter/setter/destroy dan event handler anonim. Inventaris metode hasil factory lama:

| Komponen | Metode/field asli |
| --- | --- |
| Toggle | GetValue, SetValue, SetCallback, Destroy, `_instance` |
| Slider | GetValue, SetValue, SetCallback, `_instance` (**tanpa Destroy**) |
| Button | SetText, SetCallback, Destroy, `_instance` |
| Dropdown | GetValue, SetValue, SetOptions, SetCallback, Destroy, `_instance` |
| MultiDropdown | GetValues, SetValues, SetOptions, SetCallback, Destroy, `_instance` |
| TextBox | GetValue, SetValue, SetCallback, Clear, Destroy, `_instance` |
| Keybind | GetKey, SetKey, SetCallback, Destroy, `_instance` |
| ColorPicker | GetColor, SetColor, SetCallback, Destroy, `_instance` |
| Notification | Show, Destroy (tidak ada `_instance` di API asli) |
| Section | AddComponent, SetExpanded, Destroy, `_instance` |
| Label | SetText, Destroy, `_instance` |
| Paragraph | SetTitle, SetContent, Destroy, `_instance` |
| Divider | Destroy, `_instance` |
| ProgressBar | GetValue, SetValue, SetCallback, Destroy, `_instance` |
| SearchBox | GetValue, SetValue, SetCallback, Clear, Destroy, `_instance` |

Semua metode lama tetap tersedia di wrapper baru; tambahan dan perubahan kontrak dicatat dalam [MIGRATION.md](MIGRATION.md). Toggle positional dan akses factory lokal berubah menjadi config dan factory instance publik.

## Inventaris service dan objek platform

| Sumber | Service/objek | Pemakaian |
| --- | --- | --- |
| Asli | Players, LocalPlayer, PlayerGui | Memasang ScreenGui jika script bukan anak ScreenGui |
| Asli | TweenService | Animasi warna/posisi/fill/notifikasi |
| Asli | UserInputService | Input mouse/touch/keyboard global, drag dan capture |
| Asli | workspace.CurrentCamera | ViewportSize untuk skala dan clamp logo |
| Baru: Main | ReplicatedStorage, BindableFunction, script.Destroying | Bootstrap CreateWindow/delapan tab, GetUI tiga return, hook cleanup endpoint |
| Baru: Core/Window | Players, UserInputService, RunService, workspace.CurrentCamera | ScreenGui/shell milik window, navigasi/input/viewport dan API window/tab |
| Baru: entry | RunService | Assert inisialisasi di klien |
| Baru: Helpers | TweenService, UserInputService | Tween dan gesture dengan cleanup |
| Baru: Keybind | UserInputService | Capture keyboard sementara |

Objek UI utama asli: ScreenGui; Frame; ScrollingFrame; TextButton; ImageButton; TextLabel; ImageLabel; TextBox; UICorner; UIStroke; UIPadding; UIListLayout; UIScale. Baru juga menambahkan BindableFunction `GetUI` sebagai endpoint lokal. Tidak ada remote jaringan, DataStore, HttpService, paket eksternal, loadstring, atau API executor pada sumber yang diperiksa. Logo tetap menggunakan `rbxassetid://101879171935546`; “tanpa dependensi eksternal” tidak menjamin aset tersedia offline/di semua izin pengalaman.

## Inventaris event dan pekerjaan asinkron

| Event/pekerjaan asli | Lokasi/tanggung jawab |
| --- | --- |
| `camera:GetPropertyChangedSignal("ViewportSize")` | Skala shell; kamera awal disimpan sekali |
| `MouseEnter`, `MouseLeave` | Hover tombol topbar |
| `MouseButton1Click` | Tab, toggle, tombol, header/opsi dropdown, capture key, header color/section, minimize/restore/close |
| `InputBegan` pada GuiObject | Track slider, kanal warna, topbar, logo memulai drag |
| `input.Changed` | Mengakhiri state drag saat UserInputState.End |
| `UserInputService.InputChanged` | Menggerakkan slider/kanal warna/jendela/logo |
| `UserInputService.InputBegan` | Keybind capture dan RightShift |
| `GetPropertyChangedSignal("Text")` | Filter Dropdown, NumericOnly TextBox, callback SearchBox |
| `TextBox.FocusLost` | Callback submit TextBox bila entered true |
| `Tween.Completed` | Destroy kartu setelah fade-out Notification |
| `task.delay(Duration, ...)` | Timeout Notification |

Perubahan baru: root/GUI/script `Destroying` untuk cleanup; `Activated` untuk navigasi/kontrol shell; `UserInputService.InputEnded` dan `WindowFocusReleased` untuk gesture; `workspace.CurrentCamera` changed untuk rebinding; `bounds.AbsoluteSize` untuk layout inset-aware; `UIListLayout.AbsoluteContentSize` untuk Section; Tween.Completed/Destroying untuk melepaskan listener; task.cancel untuk timer notifikasi. Callback GetUI dipasang melalui `BindableFunction.OnInvoke`, bukan event jaringan.

Listener lokal opsi dropdown terhubung ke tombol yang dibangun ulang; penghancuran tombol melepaskan koneksi signal miliknya. Listener global/gesture/capture memerlukan cleanup eksplisit dan kini dikelola scope/handler terkait. Scope menyimpan fungsi cleanup sampai root mati; ini tidak sama dengan jaminan footprint nol atau benchmark kebocoran memori.

## Temuan dan perbaikan pada sumber baru

Status “ditangani di sumber” berarti implementasinya terlihat saat inspeksi; **belum membuktikan pengujian Studio berhasil**.

| Temuan asli | Penanganan yang terlihat di sumber baru |
| --- | --- |
| Monolit mencampur shell, tema, factory lokal; tidak ada API require publik | Entry library, Theme/Helpers, registry leaf, Main terpisah, GetUI setelah shell siap |
| Slider tidak punya Destroy; global input/camera listener tidak dikelola terpusat | Scope terikat root; Destroy semua komponen; cleanup library/Main; koneksi gesture sementara |
| Drag touch dapat merespons sentuhan lain; listener per-gesture lama tidak dibersihkan eksplisit | BindDrag melacak InputObject pemulai, stop pada release/focus lost/destroy |
| Logo mencampur offset yang di-clamp dengan scale awal 1; potensi lompatan/keluar layar | Resolusi scale+offset ke piksel, clamp DragBounds sesuai anchor/ukuran, penanganan layar lebih kecil dari logo |
| Pemulihan logo rawan menyamakan release drag dengan klik | Ambang gerak dan pengecekan posisi input akhir pada Activated |
| Skala minimum 0,55 dapat meluap pada layar sangat kecil; kamera awal bisa nil/diganti | Skala rasio tanpa floor; listener CurrentCamera dan hanya satu koneksi viewport aktif |
| RightShift tidak mengecek TextBox fokus secara eksplisit | Guard GetFocusedTextBox selain gameProcessed |
| Slider clamp Default sebelum swap batas; pembulatan tetap enam desimal dan label integer untuk step >= 1 | Swap dahulu, format berdasarkan batas/step dan toleransi half-step |
| ColorPicker kanal tanpa layout; SetColor merender melalui setter kanal yang memutasi warna bertahap | Layout tiga kanal dan renderer murni; applyColor menyelaraskan semua sebelum callback sekali |
| Section AutomaticSize dengan container relatif berpotensi feedback layout; tinggi piksel layout tidak setara unit offset di bawah UIScale | Tinggi logis AbsoluteContentSize.Y dibagi scale dari header.AbsoluteSize.Y/32, tambah padding; listener layout dan header, spec skala 0,5/1/2 tersedia, belum diuji Studio |
| Daftar/Default tidak dinormalisasi; duplikat/tipe buruk bisa merusak state | Validasi array padat, salinan dan deduplikasi; selected difilter; transaksi staging untuk kegagalan konstruksi |
| MultiDropdown tanpa Default/Searchable; MaxSelections tak divalidasi | Default, pencarian, normalisasi batas finite integer >= 0, SetValues terfilter |
| TextBox NumericOnly hanya membuang karakter asing; tanda/titik berulang masih lolos | Satu tanda minus awal dan satu desimal, termasuk Default/setter; masih bukan validasi angka lengkap |
| Keybind capture global permanen dan tipe key tak divalidasi | Listener capture sementara, validasi Enum.KeyCode, pembatalan Escape/touch, alias nilai dan CancelCapture |
| Notification timer tidak dibatalkan; destroy bergantung fade completion | Timer/tween dibatalkan, Destroy langsung, timeout langsung, Show tetap eksplisit |
| Tween state dapat bertumpuk; rasio ProgressBar ekstrem dapat overflow | Cancel tween Toggle/ProgressBar sebelumnya; ProgressBar menghitung rasio alternatif saat selisih overflow |
| Pembuatan Instance gagal dapat meninggalkan objek parsial | H.Make menghancurkan Instance yang gagal diisi; staging factory dihancurkan bila error |
| Akses setelah root mati tidak punya kontrak seragam | Wrapper memeriksa flag scope/GetScope segera; explicit Helpers.Scope.Destroy merekursi scope descendant yang dikenal registry yang sama secara sinkron sebelum root.Destroy, tanpa menunggu deferred signal |
| Kebutuhan single-file tanpa loader eksekusi string | Bundler leksikal/static dependency graph menghasilkan source ModuleScript dengan closure/cache internal dan manifest hash |
| Shell hanya tersedia lewat script bootstrap | Core.Window dependency-injected, CreateWindow nol tab, tab dinamis dan ownership window penuh; Main bootstrap saja; guard setelah seleksi tab awal menolak window/tab yang dihancurkan selama seleksi |
| Notification kolon tanpa config sebelumnya berisiko memakai self sebagai config | Cabang wrapper eksplisit untuk titik/kolon; default identik dan false ditolak |
| Config/callback false bisa lolos sebagai default atau callback nonfungsi | Validasi tabel/function-nil, spec penolakan false tersedia; nil saja untuk melepas callback |

## Batasan dan perbedaan yang harus diketahui

- **Jumlah factory bukan 15 berparent + Notification:** registry berisi 15 total, 14 berparent dan satu Notification.
- Nama/metode asli dipertahankan, tetapi validasi lebih ketat dan lifecycle guard dapat mematahkan kode yang bergantung input invalid atau akses setelah destroy.
- Callback setter tidak seragam; lihat tabel dalam referensi. Pembuatan silent dan SetOptions silent bukan bug yang perlu “diseragamkan”.
- Field Name/Callback divalidasi pada semua factory, tetapi Notification mengabaikan Name untuk root dan komponen pasif tidak memakai Callback.
- MaxSelections default internal tanpa batas tidak berarti `math.huge` boleh dipasok eksplisit.
- Destroy Notification sekarang langsung, bukan fade-out; notifikasi kedaluwarsa tidak dapat dipakai ulang. Holder tanpa scrolling/limit antrian dan content satu baris.
- UI.Destroy tidak memiliki ScreenGui suplai atau shell/GetUI; shutdown penuh memakai **window.Destroy**, yang memiliki GUI buatannya. Section menghancurkan descendant termasuk Instance eksternal yang direparent. Window.IsVisible tetap valid setelah destroy (false), berbeda dari getter komponen.
- Theme override hanya konstruksi; mutasi tabel bukan live theme API. Beberapa ukuran tetap literal per komponen, jadi RowHeight/CornerRadius bukan sistem layout universal.
- Topbar drag belum di-clamp. Skala sangat kecil mengurangi keterbacaan. Capture independen, tidak ada global input coordinator; RightShift memulihkan semua window hidup. Gamepad/lintas perangkat/aksesibilitas belum diuji.
- Self-Destroying script Main hanya upaya terbaik pada deferred signals; utamakan window.Destroy eksplisit sebelum script dihancurkan. Penghapusan Instance dari luar mengikuti jadwal signal Roblox.
- Keybind adalah pemilih key, tidak dispatch hotkey; capture tidak mengoordinasikan komponen lain atau memfilter focused TextBox/gameProcessed.
- SearchBox tidak memfilter halaman otomatis dan tidak debounce. NumericOnly masih bisa menghasilkan string bukan angka. Slider memakai floating-point biasa, bukan jaminan numerik pada semua ekstrem finite.
- Tidak ada persistence, sinkronisasi server, fitur gameplay, atau demo otomatis.

## Tooling, source restrictions, dan distribusi

`scripts/build.mjs` memakai scanner leksikal/token-aware, bukan sekadar substitusi regex require. Komentar/quoted/long strings dibedakan dari ekspresi; string interpolasi ditolak. Hanya static dot require(script.Child/Parent...) di library yang diterima; alias/dynamic require dan script runtime bebas ditolak. Resolver meniru node Rojo init/child/folder, menolak missing/folder/escaping target, cycle, ambigu, file client/server di library, symlink, dan Lua tidak terjangkau. Nama internal loader reserved tidak boleh dipakai source.

Normalisasi BOM/line-ending, path/DFS terurut, serta SHA-256 source/artifact membuat hasil deterministik. Source menjadi closure factory dan require internal cached/lazy, bukan loadstring atau runtime external require/script refs. Ini bundler terbatas, bukan parser/kompiler Luau lengkap atau analisis keamanan universal. Kebijakan API terlarang validator bukan bukti ketiadaan seluruh perilaku berbahaya yang mungkin.

Output `dist/AstralLite.lua` mengembalikan library; manifest menyimpan versi, entry, hash source/agregat/artifact, daftar source dan urutan modul. SHA bukan tanda tangan penerbit. Pair output ditulis lewat rename atomik per file, bukan transaksi pasangan atomik; build:check mendeteksi stale/interrupted pair. Main/arsip/tests tidak dibundle. Generasi final dan byte-exact check sudah lulus pada 2026-11-02; ini bukan publikasi release atau bukti runtime Studio.

**Versi selaras:** entry Version dan package.json.version kini sama-sama 2.0.0. Bundler tetap membaca literal versi entry saja; jaga kecocokan saat bump berikutnya. Tidak ada gate selisih versi yang masih terbuka.

## VALIDATION — hasil final 2026-11-02

Validasi sumber, build, tooling dan dokumentasi **selesai**. Hasil berikut berasal dari perintah yang dijalankan pada workspace selama refactor. Angka tes Node tidak mencakup spec Roblox yang belum dijalankan.

| Pemeriksaan | Perintah/cakupan | Hasil aktual 2026-11-02 |
| --- | --- | --- |
| Versi | Entry Version dan package.json.version | **Selaras 2.0.0** |
| Suite Node + compiler | `LUAU_COMPILER=.tools/luau/luau-compile.exe npm test` | **24 tests, 24 pass, 0 fail, 0 skip** |
| Bundle final | `npm run build` | **Lulus**; dist/AstralLite.lua + manifest, **20 modul v2.0.0** |
| Kesesuaian output | `npm run build:check` | **Lulus**, byte-exact |
| Rojo place | `rojo build default.project.json -o build/AstralLite.rbxlx` | **Lulus**, Rojo **7.7.0-rc.1** |
| Rojo sourcemap | `rojo sourcemap default.project.json -o build/sourcemap.json` | **Lulus** |
| Validator + sintaks | `npm run validate -- --compiler=.tools/luau/luau-compile.exe` | **Lulus**: **20 modul, 15 factory**, mapping/API/forbidden tokens/tautan docs; **24 berkas Lua dikompilasi** |
| Diagnostik editor | Error dan warning proyek | **0 error, 0 warning** |
| Studio source specs | Components.spec dan Window.spec, client Play | **Belum dijalankan**; runtime Studio tidak tersedia |
| Studio bundle specs | Kedua runner dengan injeksi hasil require bundle | **Belum dijalankan**; runtime Studio tidak tersedia |
| Input/render/perangkat/memori dan Main.GetUI | Checklist manual di bawah | **Belum dijalankan**; tidak disimpulkan dari Node/compiler/build |
| Release/tag | Publikasi oleh pemilik | **Belum dipublikasikan** |

Place/sourcemap tetap generated/ignored. Compiler memeriksa sintaks 24 Lua, bukan menjalankan 24 tes Roblox. Keberhasilan tooling dan diagnostik tidak membuktikan rendering, input, koordinasi signal/timer, atau ketiadaan kebocoran memori di Studio.

Node 18+ dan npm memakai modul built-in, tidak membutuhkan install dependency. Compiler standar lokal opsional (`LUAU_COMPILER` atau --compiler), tidak diunduh otomatis dan bukan dependency runtime; `.tools/` ignored. Compiler hanya memeriksa sintaks source/spec/bundle, bukan rendering/signal/UI. Validator memeriksa token cakupan spec, **tidak menjalankan** assertion Roblox. Optional `build/sourcemap.json` diperiksa bila ada; regenerasi jika stale.

```sh
npm run build
npm run build:check
npm test
npm run validate
npm run validate -- --compiler=.tools/luau/luau-compile.exe
mkdir -p build
rojo build -o build/AstralLite.rbxlx
rojo sourcemap default.project.json -o build/sourcemap.json
```

Perintah compiler hanya bila executable tersebut tersedia. PowerShell: buat folder lewat `New-Item -ItemType Directory -Force build`. `rojo serve` untuk sinkronisasi/plugin, bukan tes yang selesai sendiri. Aftman opsional untuk instalasi tool, memerlukan jaringan bila mengunduhnya. Prosedur lengkap [RELEASING.md](RELEASING.md).

## Spec Studio opt-in

`tests/Components.spec.lua` dan `tests/Window.spec.lua` sudah tersedia, masing-masing ModuleScript yang mengembalikan `function(libraryOverride)`. Require saja tidak menjalankan tes. Impor manual sebagai ReplicatedStorage["Components.spec"] dan ["Window.spec"], Play/client, jalankan **berurutan**, jangan map/autorun dari Main. Ikuti [tests/README.md](../tests/README.md).

```lua
local RS = game:GetService("ReplicatedStorage")
-- Source default memakai RS.UILibrary:
local componentCount = require(RS:WaitForChild("Components.spec"))()
local windowCount = require(RS:WaitForChild("Window.spec"))()
-- Pada sesi terpisah, bundle yang sudah dipasang manual:
-- local library = require(RS:WaitForChild("AstralLite"))
-- require(RS:WaitForChild("Components.spec"))(library)
-- require(RS:WaitForChild("Window.spec"))(library)
```

Override adalah tabel library hasil require, bukan Instance; dengan override, runner tidak menunggu hierarchy sumber. Hapus modul test-only sebelum publikasi, restart Play setelah source berubah karena cache require. Spec memeriksa state/config/callback/ownership/lifecycle, 14 factory tab, window nol tab, serta Section UIScale. Tidak melakukan synthetic input, screenshot/asset load check, penghitung timer internal, atau inspeksi listener privat Roblox. Main.GetUI dan self-destruction script tidak otomatis diuji. Descendant count tidak mendeteksi semua Instance unparented atau leak scheduler.

### Checklist Studio manual (belum dieksekusi)

1. **Bootstrap:** mapping menghasilkan ReplicatedStorage.UILibrary dan LocalScript PlayerScripts.Main. Play di klien; tunggu GetUI, Invoke, cek tiga return UI/pages/window dan delapan key pages; CreateWindow generik nol tab. Pastikan hanya judul/layout, tanpa demo otomatis/GUI ganda dari arsip.
2. **Shell:** pindah semua tab; drag topbar dengan mouse/touch; minimize; drag logo dari posisi awal sudut kanan bawah; klik tanpa drag untuk restore; close; RightShift saat normal, gameProcessed, dan TextBox fokus.
3. **Viewport:** desktop/ponsel, layar lebih kecil dari logo, resize/orientasi, CurrentCamera nil lalu diganti. Cek skala, inset, clamp logo, dan tidak ada listener viewport lama yang tetap aktif.
4. **Factory/config:** buat 15 jenis dari contoh; uji titik/kolon, LayoutOrder default low-level 1 vs otomatis tab, order eksplisit/failed order, negatif/pecahan, config/callback false, Name bukan string, Callback bukan function, parent ScreenGui, config invalid. Kegagalan jangan meninggalkan row/connection parsial.
5. **State/callback:** pastikan konstruksi silent; Toggle/Slider/ProgressBar setter callback walau nilai sama; Slider swap/Min==Max/step pecahan/half-step; ColorPicker SetColor satu callback dengan tiga kanal sesuai.
6. **Daftar:** uji pencarian literal case-insensitive, angka vs string, opsi duplikat/berlubang/invalid, Dropdown default invalid/SetValue return false, SetOptions silent; MultiDropdown Default, Searchable, MaxSelections 0/2/nil, serta penolakan negatif/pecahan/infinity. Mutasi salinan GetValues/callback tidak mengubah internal.
7. **Teks/key:** TextBox Enter vs blur, NumericOnly tanda/titik dan setter silent; SearchBox perubahan Text dari input/SetValue/Clear tanpa Default; Keybind pemilihan, Escape/touch cancel, alias, setter silent, bukan dispatcher hotkey.
8. **Layout:** Section bertambah/berkurang anak, collapse/expand, AddComponent kedua gaya dan skala ancestor 0,5/1/2 dengan kalibrasi header; Paragraph wrapped; Label panjang/besar; panel dropdown dan RGB tidak menumpuk.
9. **Notification:** factory invisible, Show eksplisit sekali, Show ulang tidak restart timer, Duration 0/negatif, timeout/Destroy langsung, Destroy sebelum Show, tidak ada callback, tidak ada timer/tween tersisa setelah cleanup.
10. **Lifecycle:** Destroy komponen dua kali; metode lain error. Hapus root/parent/Section dari luar; UI.Destroy menghapus seluruh komponen/holder tetapi bukan ScreenGui/panel/shell. Panggil window.Destroy sebelum menghancurkan script Main saat drag/capture/notifikasi aktif, cek GUI/maps/endpoint cleanup; uji external destruction terpisah dengan deferred signals tanpa menganggap script hook jaminan, pantau Output/koneksi tertinggal.
11. **Regresi:** ulangi create/destroy dan ganti kamera berkali-kali, inspeksi jumlah Instance/koneksi/memori dengan alat Studio yang sesuai. Catat perangkat, versi Studio/Rojo, langkah, hasil aktual, dan error sebelum menyatakan lolos.

Temuan audit yang belum teruji runtime tetap perlu reproduksi; daftar penanganan di atas tidak menggantikan bukti eksekusi tersebut.
