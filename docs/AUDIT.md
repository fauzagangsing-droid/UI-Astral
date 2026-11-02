# Audit sumber dan rencana verifikasi

## Ruang lingkup dan bukti

Baseline asli terdiri dari **dua berkas**, `ui.lua` (2.043 baris) dan `aftman.toml`; tidak ada konfigurasi proyek Rojo asli. Perbandingan dilakukan terhadap arsip tersebut dan sumber modular yang tersedia: entry `UILibrary/init.lua`, Theme, Helpers, registry dan seluruh 15 modul komponen, serta `src/client/Main.client.lua`.

Ini **audit pembacaan sumber**, bukan audit runtime tersertifikasi. Dokumen ini tidak menyatakan Studio, build Rojo, tes otomatis, atau validator statis yang direncanakan telah lulus. Perubahan sesi dokumentasi dibatasi ke README, CHANGELOG, dan lima dokumen di docs; arsip, toolchain, modul, dan entry tidak diedit.

`ui.lua` menyebut “UI-only demonstration”, tetapi tidak ditemukan pemanggilan demo factory otomatis. Loop halaman asli hanya membuat halaman, PageTitle, dan tab, lalu memilih Home. Main baru mempertahankan keadaan itu: delapan kategori Home, Combat, Teleport, Player, Visuals, World, Misc, Settings, isi awal hanya judul/layout. Tidak ada fitur Combat/Teleport/gameplay yang diimplementasikan oleh nama kategori.

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
| Baru: Main | Players, ReplicatedStorage, UserInputService, workspace.CurrentCamera | Bootstrap klien, require library, shell dan viewport |
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
| Section AutomaticSize dengan container relatif berpotensi feedback layout | Tinggi offset dari AbsoluteContentSize + padding; collapse menghitung ulang tinggi |
| Daftar/Default tidak dinormalisasi; duplikat/tipe buruk bisa merusak state | Validasi array padat, salinan dan deduplikasi; selected difilter; transaksi staging untuk kegagalan konstruksi |
| MultiDropdown tanpa Default/Searchable; MaxSelections tak divalidasi | Default, pencarian, normalisasi batas finite integer >= 0, SetValues terfilter |
| TextBox NumericOnly hanya membuang karakter asing; tanda/titik berulang masih lolos | Satu tanda minus awal dan satu desimal, termasuk Default/setter; masih bukan validasi angka lengkap |
| Keybind capture global permanen dan tipe key tak divalidasi | Listener capture sementara, validasi Enum.KeyCode, pembatalan Escape/touch, alias nilai dan CancelCapture |
| Notification timer tidak dibatalkan; destroy bergantung fade completion | Timer/tween dibatalkan, Destroy langsung, timeout langsung, Show tetap eksplisit |
| Tween state dapat bertumpuk; rasio ProgressBar ekstrem dapat overflow | Cancel tween Toggle/ProgressBar sebelumnya; ProgressBar menghitung rasio alternatif saat selisih overflow |
| Pembuatan Instance gagal dapat meninggalkan objek parsial | H.Make menghancurkan Instance yang gagal diisi; staging factory dihancurkan bila error |
| Akses setelah root mati tidak punya kontrak seragam | Wrapper menolak seluruh metode komponen setelah destroy kecuali Destroy idempoten |

## Batasan dan perbedaan yang harus diketahui

- **Jumlah factory bukan 15 berparent + Notification:** registry berisi 15 total, 14 berparent dan satu Notification.
- Nama/metode asli dipertahankan, tetapi validasi lebih ketat dan lifecycle guard dapat mematahkan kode yang bergantung input invalid atau akses setelah destroy.
- Callback setter tidak seragam; lihat tabel dalam referensi. Pembuatan silent dan SetOptions silent bukan bug yang perlu “diseragamkan”.
- Field Name/Callback divalidasi pada semua factory, tetapi Notification mengabaikan Name untuk root dan komponen pasif tidak memakai Callback.
- MaxSelections default internal tanpa batas tidak berarti `math.huge` boleh dipasok eksplisit.
- Destroy Notification sekarang langsung, bukan fade-out; notifikasi kedaluwarsa tidak dapat dipakai ulang. Holder tanpa scrolling/limit antrian dan content satu baris.
- UI.Destroy tidak memiliki ScreenGui suplai atau shell/GetUI; penghancuran UI saja bukan shutdown Main. Section menghancurkan semua descendant termasuk Instance eksternal yang direparent.
- Theme override hanya konstruksi; mutasi tabel bukan live theme API. Beberapa ukuran tetap literal per komponen, jadi RowHeight/CornerRadius bukan sistem layout universal.
- Topbar drag belum di-clamp. Skala sangat kecil menjaga ukuran total tetapi dapat mengurangi keterbacaan. Pengujian lintas perangkat/gamepad/aksesibilitas belum dilakukan.
- Keybind adalah pemilih key, tidak dispatch hotkey; capture tidak mengoordinasikan komponen lain atau memfilter focused TextBox/gameProcessed.
- SearchBox tidak memfilter halaman otomatis dan tidak debounce. NumericOnly masih bisa menghasilkan string bukan angka. Slider memakai floating-point biasa, bukan jaminan numerik pada semua ekstrem finite.
- Tidak ada persistence, sinkronisasi server, fitur gameplay, atau demo otomatis.

## Status integrasi dan validasi

| Bagian | Status saat dokumentasi ditulis |
| --- | --- |
| Pembacaan arsip, Main, entry, Helpers, Theme, seluruh modul komponen | Dilakukan untuk menyusun kontrak dokumentasi |
| Konfigurasi Rojo | Belum tersedia; target mapping didokumentasikan |
| `tests/Components.spec.lua`, `tests/README.md` | Direncanakan; belum ada runner/hasil tes untuk diklaim |
| `scripts/validate.mjs` | Opsional, direncanakan; bukan validator yang sudah dijalankan |
| Build Rojo | Belum dijalankan |
| Studio Play/manual, rendering/input/timer/cleanup | Belum dijalankan |

### Perintah yang dapat direproduksi nanti

Dari root, setelah konfigurasi Rojo tersedia:

```sh
# Bila memilih Aftman; instalasi tool memerlukan jaringan:
aftman install

# Sinkronisasi ke plugin Studio (proses berkelanjutan, hentikan setelah selesai):
rojo serve
```

Untuk build, buat folder jika belum ada:

```sh
mkdir -p build
rojo build -o build/AstralLite.rbxlx
```

PowerShell: gunakan `New-Item -ItemType Directory -Force build`, kemudian perintah build yang sama. Setelah validator opsional benar-benar tersedia, `node scripts/validate.mjs` dapat dipakai untuk pemeriksaan statis. Jangan menjalankannya sekarang dengan asumsi berkas sudah ada; jangan menafsirkan validasi statis sebagai kelulusan runtime Luau/Roblox. Cara menjalankan tes komponen kelak harus mengikuti `tests/README.md`, bukan mengasumsikan TestEZ/dependensi lain.

### Checklist Studio manual (belum dieksekusi)

1. **Bootstrap:** mapping menghasilkan ReplicatedStorage.UILibrary dan LocalScript PlayerScripts.Main. Play di klien; tunggu GetUI, Invoke, cek dua return dan delapan key pages. Pastikan hanya judul/layout, tanpa demo otomatis/GUI ganda dari arsip.
2. **Shell:** pindah semua tab; drag topbar dengan mouse/touch; minimize; drag logo dari posisi awal sudut kanan bawah; klik tanpa drag untuk restore; close; RightShift saat normal, gameProcessed, dan TextBox fokus.
3. **Viewport:** desktop/ponsel, layar lebih kecil dari logo, resize/orientasi, CurrentCamera nil lalu diganti. Cek skala, inset, clamp logo, dan tidak ada listener viewport lama yang tetap aktif.
4. **Factory/config:** buat 15 jenis dari contoh; uji titik/kolon, LayoutOrder default 1/negatif/pecahan, Name bukan string, Callback bukan function, parent ScreenGui, config invalid. Kegagalan jangan meninggalkan row/connection parsial.
5. **State/callback:** pastikan konstruksi silent; Toggle/Slider/ProgressBar setter callback walau nilai sama; Slider swap/Min==Max/step pecahan/half-step; ColorPicker SetColor satu callback dengan tiga kanal sesuai.
6. **Daftar:** uji pencarian literal case-insensitive, angka vs string, opsi duplikat/berlubang/invalid, Dropdown default invalid/SetValue return false, SetOptions silent; MultiDropdown Default, Searchable, MaxSelections 0/2/nil, serta penolakan negatif/pecahan/infinity. Mutasi salinan GetValues/callback tidak mengubah internal.
7. **Teks/key:** TextBox Enter vs blur, NumericOnly tanda/titik dan setter silent; SearchBox perubahan Text dari input/SetValue/Clear tanpa Default; Keybind pemilihan, Escape/touch cancel, alias, setter silent, bukan dispatcher hotkey.
8. **Layout:** Section bertambah/berkurang anak, collapse/expand, AddComponent kedua gaya; Paragraph wrapped; Label panjang/besar; panel dropdown dan RGB tidak menumpuk.
9. **Notification:** factory invisible, Show eksplisit sekali, Show ulang tidak restart timer, Duration 0/negatif, timeout/Destroy langsung, Destroy sebelum Show, tidak ada callback, tidak ada timer/tween tersisa setelah cleanup.
10. **Lifecycle:** Destroy komponen dua kali; metode lain error. Hapus root/parent/Section dari luar; UI.Destroy menghapus seluruh komponen/holder tetapi bukan ScreenGui/panel/shell. Hapus GUI/script Main saat drag/capture/notifikasi aktif, pantau Output dan koneksi tertinggal.
11. **Regresi:** ulangi create/destroy dan ganti kamera berkali-kali, inspeksi jumlah Instance/koneksi/memori dengan alat Studio yang sesuai. Catat perangkat, versi Studio/Rojo, langkah, hasil aktual, dan error sebelum menyatakan lolos.

Temuan audit yang belum teruji runtime tetap perlu reproduksi; daftar penanganan di atas tidak menggantikan bukti eksekusi tersebut.
