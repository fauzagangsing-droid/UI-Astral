# Contoh 15 komponen

Contoh API utama **2.0.0, belum dirilis**, untuk LocalScript klien dengan bundle yang dipasang manual sesuai [README](../README.md). Pola window/tab terinspirasi penggunaan WindUI, tanpa dependensi atau branding salinan. Factory dan metode window/tab/komponen mendukung titik/kolon. Semua factory silent saat konstruksi. Detail lengkap ada di [API_REFERENCE.md](API_REFERENCE.md); contoh ini bukan demo otomatis Main atau laporan uji Studio.

Status **2026-11-02**: build/check bundle 20 modul v2.0.0, 24/24 tes Node tanpa fail/skip, build/sourcemap Rojo, validator 15 factory dan kompilasi 24 Lua lulus; entry/package selaras dan editor 0 error/0 warning. [Audit](AUDIT.md) membedakan validasi sumber/tooling/dokumentasi ini dari spec Studio source/bundle serta uji input/render/perangkat/memori yang belum dijalankan karena runtime Studio tidak tersedia. Release/tag belum dipublikasikan.

## Persiapan

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AstralLite = require(ReplicatedStorage:WaitForChild("AstralLite"))
local window = AstralLite:CreateWindow({ Title = "Pengaturan" })
local tab = window:CreateTab({ Name = "Settings", Icon = "⚙" })
local UI = window.UI
```

Window generik awalnya nol tab; CreateTab pertama otomatis aktif. Factory tab menerima **config saja** dan memberi order otomatis per tab bila LayoutOrder dihilangkan; contoh memakai order eksplisit agar mudah diikuti. Factory UI tingkat rendah tetap menerima parent GuiObject (bukan ScreenGui), dengan order default 1. Untuk memakai Main yang sudah berjalan, ganti persiapan dengan `local UI, pages, window = main:WaitForChild("GetUI"):Invoke()` lalu `local tab = window:GetTab("Settings")`, setelah menunggu PlayerScripts.Main. Jangan membuat bootstrap bundle dan Main sekaligus tanpa sengaja.

## 1. Toggle

```lua
local toggle = tab:CreateToggle({
    Name = "Musik", LayoutOrder = 1, Default = false,
    Callback = function(enabled) print("Musik:", enabled) end,
})
toggle:SetValue(true) -- mengirim callback, termasuk bila nilainya sudah true
print(toggle:GetValue())
```

## 2. Slider

```lua
local slider = tab:CreateSlider({
    Name = "Volume", LayoutOrder = 2,
    Min = 0, Max = 1, Step = 0.05, Default = 0.5,
    Callback = function(value) print("Volume:", value) end,
})
slider.SetValue(0.73) -- gaya titik tetap valid; snap ke step dan kirim callback
print(slider:GetValue())
```

## 3. Button

```lua
local button = tab:CreateButton({
    Name = "Simpan", Text = "Simpan pengaturan", LayoutOrder = 3,
    Style = "primary",
    Callback = function() print("Diminta menyimpan") end,
})
button:SetText("Simpan sekarang") -- silent, tidak melakukan penyimpanan otomatis
print(button:GetText())
```

## 4. Dropdown

```lua
local dropdown = tab:CreateDropdown({
    Name = "Bahasa", LayoutOrder = 4,
    Options = { "Indonesia", "English" }, Default = "Indonesia",
    Searchable = true,
    Callback = function(value) print("Bahasa:", value) end,
})
assert(dropdown:SetValue("English")) -- callback; pilihan invalid return false
print(dropdown:GetValue())
dropdown:SetOptions({ "Indonesia", "English", "日本語" }) -- silent
dropdown:SetExpanded(true)
```

## 5. MultiDropdown

```lua
local multi = tab:CreateMultiDropdown({
    Name = "Kanal", LayoutOrder = 5,
    Options = { "Umum", "Tim", "Sistem" }, Default = { "Umum" },
    Searchable = true, MaxSelections = 2,
    Callback = function(values) print(table.concat(values, ", ")) end,
})
multi:SetValues({ "Tim", "Sistem", "Tim" }) -- deduplikasi; callback menerima salinan
print(#multi:GetValues())
multi:SetOptions({ "Umum", "Tim" }) -- Sistem dibuang tanpa callback
```

`Searchable` kini didukung MultiDropdown. MaxSelections eksplisit harus integer finite >= 0; hilangkan field untuk tanpa batas. Jangan mengirim `math.huge`. `SetValues(nil)` mengosongkan dan tetap mengirim callback.

## 6. TextBox

```lua
local textBox = tab:CreateTextBox({
    Name = "Jumlah", LayoutOrder = 6,
    Default = "10", Placeholder = "Masukkan jumlah", NumericOnly = true,
    Callback = function(text)
        local amount = tonumber(text)
        if amount then print("Jumlah:", amount) end
    end,
})
textBox:SetValue("12.5") -- silent; callback hanya ketika submit Enter
print(textBox:GetValue()) -- string, bukan number
```

NumericOnly menyaring karakter, bukan memvalidasi angka/domain lengkap; tetap tangani nilai kosong atau minus/titik tanpa digit.

## 7. Keybind

```lua
local keybind = tab:CreateKeybind({
    Name = "Pilih tombol", LayoutOrder = 7, Default = Enum.KeyCode.K,
    Callback = function(key) print("Pilihan tombol:", key.Name) end,
})
keybind:SetKey(Enum.KeyCode.L) -- silent; bukan menjalankan aksi hotkey
assert(keybind:GetValue() == keybind:GetKey())
keybind:CancelCapture()
```

Klik kontrol untuk capture; Escape membatalkan. Callback melaporkan pemilihan key, **bukan** aktivasi key yang tersimpan. Dispatcher hotkey terpisah menjadi tanggung jawab integrasi.

## 8. ColorPicker

```lua
local picker = tab:CreateColorPicker({
    Name = "Warna penanda", LayoutOrder = 8,
    DefaultColor = Color3.fromRGB(168, 121, 255),
    Callback = function(color) print("Warna:", color:ToHex()) end,
})
picker:SetColor(Color3.fromRGB(80, 180, 255)) -- satu callback setelah tiga kanal sinkron
picker:SetExpanded(true) -- wajib boolean
print(picker:GetColor())
```

Editor hanya RGB; tidak ada input HSV/hex/alpha atau alias SetValue.

## 9. Notification

```lua
local notification = window:CreateNotification({
    Title = "Tersimpan", Content = "Pengaturan lokal diperbarui",
    Type = "Success", Duration = 3, LayoutOrder = 9,
})
notification:SetContent("Siap dipakai")
notification:Show() -- wajib eksplisit; timer baru dimulai di sini
```

Tidak menerima parent. `Show` kedua selama hidup tidak me-restart timer. Setelah timeout, jangan panggil getter/setter/Show lagi; buat notifikasi baru. `Destroy()` tetap aman berulang dan langsung menghapus, bukan fade-out.

## 10. Section

```lua
local section = tab:CreateSection({
    Name = "Lanjutan", LayoutOrder = 10,
    Collapsible = true, DefaultExpanded = true,
})
UI:CreateButton(section.Container, {
    Name = "Reset", LayoutOrder = 1,
    Callback = function() print("Diminta reset") end,
})
local child = tab:CreateLabel({ Text = "Catatan", LayoutOrder = 2 })
section:AddComponent(child) -- pindah, bukan clone
section:SetExpanded(false)
print(section:GetExpanded())
```

Container adalah field Frame, bukan metode. Gunakan UI tingkat rendah untuk anak langsung Container; factory tab tetap memparent ke halaman. Anak ikut dihancurkan saat Section dihapus. Tidak ada callback ekspansi; SetExpanded tetap bekerja jika Collapsible false. Koreksi UIScale memakai ukuran header untuk mengubah tinggi piksel layout ke satuan logis; spec skala tersedia tetapi belum dijalankan di Studio.

## 11. Label

```lua
local label = tab:CreateLabel({
    Name = "StatusLabel", Text = "Status: siap", LayoutOrder = 11,
    TextSize = 13, Color = Color3.fromRGB(240, 240, 255),
})
label:SetText("Status: diperbarui")
print(label:GetText())
```

Label sederhana tinggi tetap; Name tidak menjadi default Text.

## 12. Paragraph

```lua
local paragraph = tab:CreateParagraph({
    Name = "Informasi", LayoutOrder = 12,
    Title = "Tentang panel", Content = "Panel ini hanya mengelola tampilan lokal.",
})
paragraph:SetTitle("Informasi panel")
paragraph:SetContent("Teks isi mendukung wrapping dan tinggi otomatis.")
print(paragraph:GetTitle(), paragraph:GetContent())
```

## 13. Divider

```lua
local divider = tab:CreateDivider({
    Name = "Pemisah", LayoutOrder = 13,
})
-- Tidak ada setter; warna mengikuti Border tema saat dibuat.
-- divider:Destroy() jika pemisah tidak dibutuhkan lagi.
```

## 14. ProgressBar

```lua
local progress = tab:CreateProgressBar({
    Name = "Memuat", LayoutOrder = 14,
    Min = 0, Max = 200, Default = 20, Color = Color3.fromRGB(110, 200, 140),
    Callback = function(value) print("Nilai proses:", value) end,
})
progress:SetValue(100) -- tampilan 50%, callback menerima 100 (bukan 50)
print(progress:GetValue())
```

Ini indikator programatik, bukan slider yang bisa ditarik.

## 15. SearchBox

```lua
local search = tab:CreateSearchBox({
    Name = "Cari", LayoutOrder = 15, Placeholder = "Cari item...",
    Callback = function(query)
        print("Terapkan filter sendiri:", query)
    end,
})
search:SetValue("panel") -- perubahan Text dapat memicu callback
search:Clear() -- juga memicu bila teks berubah
```

Awal selalu kosong; tidak ada Default, debounce, atau pencarian otomatis ke halaman/komponen lain.

## Cleanup

```lua
button:SetCallback(nil) -- tersedia hanya pada komponen interaktif yang mendukungnya
button:Destroy()
button.Destroy() -- idempoten, gaya titik juga valid
-- button:GetText() sekarang error: Component is destroyed

-- Hanya pemilik keseluruhan window, saat benar-benar selesai:
-- window:Destroy()
-- window:IsVisible() sekarang false; window:Show() error
```

Untuk satu kontrol, panggil Destroy kontrol tersebut. `tab:Destroy()` menghapus halaman/anak dan memperbarui navigasi/maps; `window:Destroy()` menghapus seluruh ScreenGui dan listener window. `UI:Destroy()` hanya komponen/holder, bukan shell. Explicit Helpers.Scope.Destroy secara rekursif menghancurkan scope descendant yang dikenal pada registry Helpers yang sama secara sinkron sebelum root.Destroy; wrapper segera menolak metode melalui flag scope, termasuk anak terkelola yang ikut dihancurkan. Penghapusan Instance langsung dari luar tetap mengikuti penjadwalan signal Roblox. Jika memakai window dari GetUI, ia dibagi dengan integrasi lain; hanya pemilik yang boleh mematikan seluruh window. Utamakan destroy eksplisit sebelum script pemilik dihancurkan (script.Destroying hanya upaya terbaik pada deferred signals). Lihat [ARCHITECTURE.md](ARCHITECTURE.md).
