# Referensi API

Referensi ini mengikuti `src/shared/UILibrary`, bukan asumsi dari nama komponen. Contoh penggunaan ada di [COMPONENTS.md](COMPONENTS.md).

## Entry point dan kontrak umum

```lua
local Library = require(game:GetService("ReplicatedStorage"):WaitForChild("UILibrary"))
local UI = Library.new({ ScreenGui = gui, Theme = optionalPartialTheme })
```

- `Library.new(config) -> UI`: hanya klien (`RunService:IsClient()`); `config` harus tabel dan `ScreenGui` wajib Instance ScreenGui. `Theme` opsional.
- `UI:CreateX(parent, config?) -> component`: untuk 14 jenis selain Notification; `parent` wajib GuiObject (misalnya Frame/ScrollingFrame), **bukan ScreenGui**.
- `UI:CreateNotification(config?) -> notification`: parent ditetapkan ke holder internal dalam ScreenGui.
- `UI:Destroy()`: menghapus semua komponen terdaftar dan holder notifikasi serta koneksinya; tidak menghapus ScreenGui yang disuplai, shell, atau parent lain milik pemanggil. Idempoten. Factory setelah ini error `Library is destroyed`.
- `UI.Theme`: tabel tema milik instance library. `UI.Helpers`: helper terikat tema (bagian terakhir referensi).
- `component._instance`: root Instance; tersedia pada seluruh 15 jenis. Menghapusnya langsung juga memicu cleanup dan menandai API telah destroyed. Preferensikan `component:Destroy()`.
- Semua komponen mempunyai `Destroy()` idempoten. **Seluruh metode komponen lainnya error setelah root dihancurkan**, termasuk getter, `Show`, dan `SetCallback`. Aturan wrapper ini berlaku walaupun fungsi internal modul memiliki guard yang hanya return.
- Wrapper factory UI dan metode komponen mendukung titik/kolon: `UI.CreateSlider(parent, config)`, `UI:CreateSlider(parent, config)`, `slider.SetValue(5)`, `slider:SetValue(5)`. `UI.Destroy()`/`UI:Destroy()` juga boleh. Ini bukan jaminan untuk constructor `Library.new`, modul leaf, atau helper.
- Konstruksi silent: tidak ada callback awal, termasuk saat normalisasi Default. Tidak ada parameter publik `silent` pada setter.

### Config umum

| Field | Kontrak |
| --- | --- |
| `Name` | String opsional; default per komponen di bawah. Kebanyakan menjadi nama root dan sebagian menjadi teks judul. Notification tetap bernama `Notification`, meski `Name` valid diberikan. |
| `LayoutOrder` | Angka finite integer, default `1` untuk **semua**, termasuk Notification. Negatif/0 diizinkan; bukan harus positif. Parent perlu layout yang memakai LayoutOrder. |
| `Callback` | Function atau nil, divalidasi bahkan pada komponen yang tidak memakainya. Tidak otomatis menambah metode `SetCallback` pada jenis pasif. |

`config` yang dihilangkan menjadi `{}`. Validasi bukan skema tertutup: field tak dikenal tidak ditolak, tetapi tidak berarti didukung. Field numerik yang melewati `H.Number` menolak NaN/infinity. Teks/warna/style lain sebagian diteruskan ke properti Roblox; gunakan tipe yang tercantum, jangan mengandalkan coercion/error seragam. Boolean bertanda *truthy* dikonversi dengan aturan Luau (0 dan string kosong tetap true).

Options/values menerima array padat berindeks `1..n`, hanya string atau angka finite. Array berlubang/dictionary/tipe lain ditolak; duplikat dihapus dengan mempertahankan kemunculan pertama. Angka `1` berbeda dari string `"1"`. Daftar disalin, bukan referensi hidup ke tabel pemanggil.

## 1. Toggle

`UI:CreateToggle(parent, config?)`

- Config: `Name="Toggle"`, `Default=false` (*truthy*), `Callback`.
- `GetValue() -> boolean`.
- `SetValue(value)`: konversi *truthy*, render tween, panggil `Callback(state: boolean)` **setiap pemanggilan**, walaupun state sama.
- `SetCallback(functionOrNil)` mengganti/menghapus callback tanpa memanggilnya.
- `Destroy()`.

Klik baris membalik state dan mengirim callback. Tidak ada `SetText` atau mode silent.

## 2. Slider

`UI:CreateSlider(parent, config?)`

- Config: `Name="Slider"`, `Min=0`, `Max=100`, `Step=1`, `Default=Min` setelah normalisasi batas, `Callback`. Semua angka finite.
- Jika Max < Min, batas ditukar **sebelum** Default dinormalisasi. Step <= 0 diganti 1. Min == Max diizinkan (fill 0).
- Nilai di-clamp, dibulatkan ke step relatif terhadap Min, lalu di-clamp lagi. Format desimal mengikuti Min/Max/Step dengan toleransi drift; ini bukan aritmetika presisi tak terbatas.
- `GetValue() -> number`.
- `SetValue(number)`: validasi, snap, render, `Callback(value: number)` setiap pemanggilan, termasuk nilai efektif sama.
- `SetCallback(functionOrNil)`, `Destroy()`.

Drag mouse/touch juga mengirim nilai; tidak ada debounce, `SetMin`, `SetMax`, `SetStep`, atau argumen silent publik. Rentang floating-point ekstrem tidak dijamin stabil; gunakan rentang UI wajar.

## 3. Button

`UI:CreateButton(parent, config?)`

- Config: `Name="Button"`, `Text=Name`, `Style=""`, `Callback`. `Style` string; hanya `"primary"` (case-insensitive) memilih gaya primary; nilai string lain memakai gaya biasa.
- `GetText() -> string`, `SetText(text?)` (nil/false menjadi `""`, tidak memanggil callback).
- `SetCallback(functionOrNil)`, `Destroy()`.
- Klik: `Callback()` tanpa argumen. Tidak ada metode publik `Click`/`Activate`.

## 4. Dropdown

`UI:CreateDropdown(parent, config?)`

- Config: `Name="Dropdown"`, `Options={}`, `Default=nil`, `Searchable=false` (*truthy*), `Callback`.
- Default hanya dipakai bila ada di Options; selain itu selected nil dan teks `Select...`. Awalnya collapsed.
- `GetValue() -> string | number | nil`.
- `SetValue(value) -> boolean`: bila anggota Options, pilih, tutup daftar, kirim `Callback(selected: string | number)`, return true. Nilai tak dikenal (termasuk nil) return false tanpa mengubah state/callback. Nilai sama yang valid tetap mengirim callback.
- `SetOptions(arrayOrNil)`: nil menjadi daftar kosong; mempertahankan selected hanya bila masih ada, selain itu mengosongkannya. **Silent**, meskipun selected hilang; daftar dibangun ulang.
- `SetExpanded(open)`: konversi *truthy*; membuka mengosongkan pencarian dan membangun ulang daftar. `GetExpanded() -> boolean`.
- `SetCallback(functionOrNil)`, `Destroy()`.

Pencarian substring literal case-insensitive pada `tostring(option)`. Tinggi area opsi maksimal 120 piksel dan menggunakan scrolling; bukan portal/popover global dan tidak otomatis menutup saat klik di luar. Untuk mengosongkan pilihan gunakan perubahan Options, bukan `SetValue(nil)`.

## 5. MultiDropdown

`UI:CreateMultiDropdown(parent, config?)`

- Config: `Name="Multi Dropdown"`, `Options={}`, `Default={}`, `Searchable=false` (*truthy*, baru dibanding arsip), `MaxSelections` opsional, `Callback`.
- Bila diberikan, MaxSelections wajib **integer finite >= 0**; NaN, infinity, negatif, dan pecahan ditolak. Jika dihilangkan, internal memakai tanpa batas. `0` melarang semua pilihan; gunakan nil untuk tanpa batas, bukan `math.huge` eksplisit.
- Default/SetValues di-deduplikasi, difilter ke anggota Options, lalu dipotong sesuai batas dalam urutan input. Awalnya collapsed; kosong ditampilkan `None`.
- `GetValues() -> array`: salinan pilihan, bukan tabel internal.
- `SetValues(arrayOrNil)`: normalisasi dan panggil `Callback(values: array<string | number>)` dengan salinan, **termasuk saat isi efektif sama/kosong**.
- `SetOptions(arrayOrNil)`: mengganti opsi dan membuang pilihan yang tidak valid; **silent**. Urutan pilihan yang tersisa dipertahankan.
- `SetExpanded(open)` (*truthy*), `GetExpanded() -> boolean`, `SetCallback(functionOrNil)`, `Destroy()`.

Klik opsi toggle pilihan tanpa menutup daftar; klik penambahan saat batas penuh tidak mengirim callback. Filter, reset pencarian saat membuka, dan batas tinggi daftar sama seperti Dropdown. Tidak ada `GetValue`, `SetValue`, atau setter MaxSelections.

## 6. TextBox

`UI:CreateTextBox(parent, config?)`

- Config: `Name="TextBox"`, `Default=""`, `Placeholder=""`, `NumericOnly=false` (*truthy*), `Callback`.
- Default dan SetValue melalui `tostring`, lalu sanitasi bila NumericOnly: hanya digit, satu titik desimal, dan satu minus di awal yang dipertahankan. Tidak mengubah hasil menjadi number.
- `GetValue() -> string`, `SetValue(value)` (silent), `Clear()` (silent, menjadi string kosong).
- `SetCallback(functionOrNil)`, `Destroy()`.
- `Callback(text: string)` **hanya** pada `FocusLost(enterPressed=true)`, bukan setiap edit atau blur biasa.

NumericOnly bukan validasi angka lengkap: `""`, `"-"`, `"."`, `"-."` masih mungkin; notasi eksponen/koma tidak didukung. Lakukan `tonumber` dan validasi domain di integrasi.

## 7. Keybind

`UI:CreateKeybind(parent, config?)`

- Config: `Name="Keybind"`, `Default=Enum.KeyCode.Unknown`, `Callback`. Default/setter wajib EnumItem dari Enum.KeyCode.
- `GetKey() -> Enum.KeyCode`; `GetValue()` alias getter tersebut.
- `SetKey(keyCode)`; `SetValue(keyCode)` alias setter. Keduanya **silent**, memperbarui tampilan dan menghentikan capture. Unknown mengosongkan binding (`None`).
- `CancelCapture()` membatalkan tanpa callback; `SetCallback(functionOrNil)`, `Destroy()`.
- Klik tombol masuk capture; klik lagi, Escape, mouse kiri/touch saat capture membatalkan. Keyboard Unknown diabaikan. Pemilihan tombol keyboard valid mengirim `Callback(key: Enum.KeyCode)`.

Ini **pemilih key**, bukan dispatcher hotkey: menekan key yang sudah tersimpan tidak otomatis menjalankan callback. Tidak ada metode publik `StartCapture`, tidak ada binding tombol mouse, dan tidak ada koordinasi capture antar-komponen. Listener capture tidak memfilter `gameProcessed` atau focused TextBox; integrasi perlu menghindari konflik.

## 8. ColorPicker

`UI:CreateColorPicker(parent, config?)`

- Config: `Name="Color Picker"`, `DefaultColor=UI.Theme.Colors.Primary`, `Callback`. Color3 dengan kanal finite wajib.
- Awalnya collapsed; editor RGB, bukan HSV/hex/alpha.
- `GetColor() -> Color3`.
- `SetColor(color3)`: memperbarui warna dan ketiga kanal secara atomik, kemudian `Callback(color: Color3)` **sekali**, termasuk bila sama.
- `SetExpanded(boolean)`: **harus boolean**, berbeda dari Dropdown/MultiDropdown/Section. `GetExpanded() -> boolean`.
- `SetCallback(functionOrNil)`, `Destroy()`.

Drag kanal ketika panel terbuka mengirim callback. Angka kanal ditampilkan 0..255 dibulatkan, tetapi nilai warna disimpan sebagai Color3; setter tidak menyediakan clamp kanal eksplisit ke 0..1. Tidak ada alias GetValue/SetValue.

## 9. Notification

`UI:CreateNotification(config?)` — **tanpa parent**.

- Config: `Title="Notification"`, `Content=""`, `Type="Info"`, `Duration=3`, ditambah field umum.
- Type memakai key case-sensitive `Info`, `Success`, `Warning`, `Error`; nilai tidak dikenal fallback Info. Duration angka finite, negatif di-clamp 0.
- `Name` divalidasi tetapi tidak dipakai mengganti root `Notification`. `Callback` divalidasi tetapi tidak dipakai; tidak ada SetCallback.
- `Show()`: tampilkan sekali dan mulai timer Duration; panggilan ulang saat masih hidup tidak mereset timer. Membuat notifikasi saja **tidak menampilkannya**.
- `GetTitle() -> string`, `SetTitle(text?)`, `GetContent() -> string`, `SetContent(text?)`: setter nil/false menjadi `""`, silent.
- `Destroy()`: hapus **langsung**, membatalkan timer/tween. Timeout juga menghapus langsung. Tidak lagi fade-out seperti arsip; masuk masih tween background 0,2 detik.

Setelah timeout, semua metode kecuali Destroy error; untuk menampilkan lagi buat instance baru. Timer mulai saat Show, bukan saat factory. Duration 0 menjadwalkan penghapusan segera melalui scheduler, bukan notifikasi permanen. Tidak ada Hide, SetDuration, SetType, antrian terbatas, atau callback selesai; teks content satu baris terpotong dan holder tidak berscroll.

## 10. Section

`UI:CreateSection(parent, config?)`

- Config: `Name="Section"`, `Collapsible=false` (*truthy*), `DefaultExpanded=true` (hanya literal false menutup).
- `Container: Frame` adalah field publik untuk parent komponen anak.
- `AddComponent(componentOrInstance)`: memindahkan Instance atau `table._instance` ke Container, lalu memperbarui ukuran; input tanpa Instance diabaikan. Bukan cloning/registrasi ownership library baru.
- `SetExpanded(open)` (*truthy*), `GetExpanded() -> boolean`, `Destroy()`.

Collapsible hanya mengatur interaksi klik header; SetExpanded tetap bekerja saat false. Tidak ada callback ekspansi. Tinggi dihitung dari `UIListLayout.AbsoluteContentSize` dan padding (bukan lingkar AutomaticSize); pakai tinggi anak berbasis offset yang wajar. Menghapus Section juga menghancurkan seluruh descendant, termasuk Instance eksternal yang dipindahkan ke Container.

## 11. Label

`UI:CreateLabel(parent, config?)`

- Config: `Name="Label"`, `Text="Label"` (bukan default Name), `TextSize=13` (finite), `Color=UI.Theme.Colors.Text` (Color3).
- `GetText() -> string`, `SetText(text?)`, `Destroy()`.

Setter nil/false menjadi `""`, silent; tidak ada SetColor/SetTextSize/SetCallback. Tinggi tetap 18 piksel, tanpa wrapping otomatis. TextSize hanya divalidasi finite oleh helper, bukan rentang desain positif oleh library; ikuti batas properti Roblox.

## 12. Paragraph

`UI:CreateParagraph(parent, config?)`

- Config: `Name="Paragraph"`, `Title="Title"`, `Content=""`.
- `GetTitle() -> string`, `SetTitle(text?)`, `GetContent() -> string`, `SetContent(text?)`, `Destroy()`.

Setter nil/false menjadi `""`, silent. Content wrapped dan tinggi otomatis; title tinggi tetap. Tidak ada callback atau setter gaya publik.

## 13. Divider

`UI:CreateDivider(parent, config?)`

- Config: `Name="Divider"`, ditambah field umum.
- `Destroy()` saja; `_instance` adalah holder setinggi 9 piksel dengan garis 1 piksel.

Warna garis berasal dari Border tema; tidak ada SetColor atau callback.

## 14. ProgressBar

`UI:CreateProgressBar(parent, config?)`

- Config: `Name="Progress"`, `Min=0`, `Max=100`, `Default=Min`, `Color=UI.Theme.Colors.Primary` (Color3), `Callback`.
- Batas/nilai finite; batas terbalik ditukar, nilai di-clamp. Min == Max menghasilkan 0%.
- `GetValue() -> number`: nilai dalam rentang, **bukan persentase**.
- `SetValue(number)`: clamp, animasi fill 0,15 detik (tween lama dibatalkan), `Callback(value: number)` setiap panggilan termasuk nilai sama.
- `SetCallback(functionOrNil)`, `Destroy()`.

Tampilan persen relatif terhadap Min..Max dibulatkan; tidak ada drag input, setter batas, atau setter warna. Perhitungan rasio menangani selisih ekstrem finite yang overflow.

## 15. SearchBox

`UI:CreateSearchBox(parent, config?)`

- Config: `Name="SearchBox"`, `Placeholder="Search..."`, `Callback`. Awal teks selalu `""`; **tidak ada Default**.
- `GetValue() -> string`, `SetValue(value)` (`tostring`), `Clear()` (`""`), `SetCallback(functionOrNil)`, `Destroy()`.
- `Callback(text: string)` mengikuti signal perubahan properti Text: edit pengguna, SetValue, dan Clear bila teks berubah. Menulis teks yang sama tidak menjanjikan callback baru.

Tidak ada debounce atau filtering komponen otomatis. Pemanggil menerapkan pencarian pada datanya sendiri. Callback dapat terjadwal mengikuti perilaku signal Roblox, bukan jaminan eksekusi sinkron sebelum setter return.

## Ringkasan callback setter

| Komponen/aksi | Callback |
| --- | --- |
| Semua factory | Tidak |
| Toggle.SetValue, Slider.SetValue, ProgressBar.SetValue, ColorPicker.SetColor | Ya, juga saat nilai sama |
| Dropdown.SetValue | Ya bila anggota opsi; tidak bila return false |
| MultiDropdown.SetValues | Ya setelah normalisasi, termasuk sama/kosong |
| Dropdown/MultiDropdown.SetOptions | Tidak, meski pilihan terhapus |
| TextBox.SetValue/Clear; Keybind.SetKey/SetValue | Tidak |
| SearchBox.SetValue/Clear | Melalui perubahan Text, bila berubah |
| SetText/SetTitle/SetContent/SetExpanded/SetCallback/AddComponent | Tidak |
| Destroy/Notification.Show/timeout | Tidak |

Callback diteruskan apa adanya, tanpa pcall/debounce otomatis atau pengiriman ke server. Hindari setter rekursif dari callback dan tangani error/logika bisnis sendiri.

## Tema

`Theme.new(overrides?) -> table` dipakai oleh `Library.new`; default disalin rekursif per library. Override **parsial per grup**, bukan field flat. Grup/key tak dikenal, tipe berbeda, font bukan Enum.Font, angka non-finite atau <= 0 ditolak. Semua field berikut didukung:

| Grup | Field dan default |
| --- | --- |
| `Colors` | Background `#10111A`, Sidebar `#151622`, Card `#1B1C2A`, Primary `#A879FF`, Secondary `#8055D9`, Border `#303044`, Text `#F4F2FA`, SubText `#9693A9` (Color3) |
| `Fonts` | Regular `Enum.Font.Gotham`, Medium `Enum.Font.GothamMedium`, Bold `Enum.Font.GothamBold` |
| `NotificationColors` | Info `#8055D9`, Success `#6BCB77`, Warning `#F4B860`, Error `#FF6B6B` (Color3) |
| `Dimensions` | RowHeight=44, CornerRadius=6, WindowWidth=650, WindowHeight=420, TopbarHeight=65, SidebarWidth=150, NotificationWidth=260 |
| `Assets` | Dragon=`"rbxassetid://101879171935546"` (string) |
| `Window` | ViewportWidth=740, ViewportHeight=500, MaxScale=1, DragThreshold=6 |

Override hanya kontrak **konstruksi**. Tidak ada `SetTheme`/observer/live update; mengubah UI.Theme langsung tidak memperbarui seluruh Instance dan tidak didukung sebagai mekanisme tema dinamis. Library mandiri tidak membangun shell; parameter Window dan dimensi jendela dikonsumsi Main. Main saat ini memakai default; untuk menyesuaikannya, integrasi harus memasok Theme pada pemanggilan constructor di Main sebelum shell dibuat.

## Helpers yang diekspos

`Helpers.new(theme) -> H`, tersedia sebagai `UI.Helpers`. Helper bukan komponen terdaftar; Instance/koneksi yang dibuat langsung lewat H tetap tanggung jawab pemanggil. Fungsi H berikut memakai **titik**, sedangkan metode scope memakai **kolon**:

| Fungsi | Perilaku/hasil |
| --- | --- |
| `H.Number(value, default, name?) -> number` | Mengganti nil dengan default, assert angka finite; label name untuk pesan error. |
| `H.Callback(callback) -> function | nil` | Memvalidasi function/nil. |
| `H.Options(values?) -> array` | Validasi/salin/deduplikasi array seperti aturan Options; nil menjadi kosong. |
| `H.Make(className, props) -> Instance` | Set properti sebelum Parent; bila gagal hapus Instance parsial dan error. Props tabel wajib untuk pemakaian ini. |
| `H.Tween(instance, duration, goal) -> Tween` | Quad Out, langsung Play; cancel saat target destroyed; disconnect listener pada selesai/destroy. Bukan pembatal otomatis semua tween sebelumnya pada target. |
| `H.CardRow(parent, name, height) -> Frame` | Row bergaya kartu dengan corner dan stroke tema. |
| `H.Scope(root) -> scope` | Scope terikat root.Destroying; field Destroyed boolean. |
| `scope:Add(cleanupFunction) -> function` | Cleanup urutan terbalik, langsung dijalankan bila scope sudah destroyed. Error cleanup diperingatkan dan cleanup lain dilanjutkan. |
| `scope:Connect(signal, callback) -> RBXScriptConnection` | Callback hanya selama hidup; disconnect pada cleanup. Connect setelah destroy error. |
| `scope:Destroy()` | Idempoten; jalankan cleanup lalu hapus root. Menghapus root eksternal juga memicu cleanup. |
| `H.BindDrag(scope, target, onUpdate, onEnd?)` | Mouse kiri/touch. `onUpdate(input, began: boolean)` saat mulai dan bergerak; `onEnd(startInput)` saat release normal. Listener global hanya selama gesture; sentuhan lain diabaikan. Focus lost/destroy membatalkan tanpa onEnd. Tidak mengembalikan controller publik. |

## Main.GetUI

`Players.LocalPlayer.PlayerScripts.Main:WaitForChild("GetUI"):Invoke() -> UI, pages` pada klien. `pages` hanya map delapan nama asli ke ScrollingFrame. Ini BindableFunction, bukan jaringan atau factory halaman. Main mengelola ScreenGui `AstralLite`, shell, input, listener kamera, dan endpoint; penghancuran script/GUI membersihkan scope Main. `UI:Destroy()` sendiri tidak menghapus endpoint atau shell, sehingga GetUI yang masih ada bisa mengembalikan UI yang sudah destroyed. Pemilik shell harus mengelola siklus hidup tersebut.
