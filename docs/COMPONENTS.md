# Contoh 15 komponen

Contoh ini untuk LocalScript klien setelah Main siap; bukan demo otomatis yang ditambahkan ke Main. Factory dan metode hasilnya mendukung titik/kolon. Semua factory silent saat konstruksi. Detail tipe, default, metode lengkap, dan batasan ada di [API_REFERENCE.md](API_REFERENCE.md).

## Persiapan

```lua
local Players = game:GetService("Players")
local main = Players.LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("Main")
local UI, pages = main:WaitForChild("GetUI"):Invoke()
local parent = pages.Settings
```

Parent harus GuiObject, bukan ScreenGui. Setiap contoh berikut memakai LayoutOrder berbeda agar tetap di bawah `PageTitle` (order 0). Bila menjalankan semua contoh dalam satu script, variabelnya sengaja dibedakan.

## 1. Toggle

```lua
local toggle = UI:CreateToggle(parent, {
    Name = "Musik", LayoutOrder = 1, Default = false,
    Callback = function(enabled) print("Musik:", enabled) end,
})
toggle:SetValue(true) -- mengirim callback, termasuk bila nilainya sudah true
print(toggle:GetValue())
```

## 2. Slider

```lua
local slider = UI:CreateSlider(parent, {
    Name = "Volume", LayoutOrder = 2,
    Min = 0, Max = 1, Step = 0.05, Default = 0.5,
    Callback = function(value) print("Volume:", value) end,
})
slider.SetValue(0.73) -- gaya titik tetap valid; snap ke step dan kirim callback
print(slider:GetValue())
```

## 3. Button

```lua
local button = UI:CreateButton(parent, {
    Name = "Simpan", Text = "Simpan pengaturan", LayoutOrder = 3,
    Style = "primary",
    Callback = function() print("Diminta menyimpan") end,
})
button:SetText("Simpan sekarang") -- silent, tidak melakukan penyimpanan otomatis
print(button:GetText())
```

## 4. Dropdown

```lua
local dropdown = UI:CreateDropdown(parent, {
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
local multi = UI:CreateMultiDropdown(parent, {
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
local textBox = UI:CreateTextBox(parent, {
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
local keybind = UI:CreateKeybind(parent, {
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
local picker = UI:CreateColorPicker(parent, {
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
local notification = UI:CreateNotification({
    Title = "Tersimpan", Content = "Pengaturan lokal diperbarui",
    Type = "Success", Duration = 3, LayoutOrder = 9,
})
notification:SetContent("Siap dipakai")
notification:Show() -- wajib eksplisit; timer baru dimulai di sini
```

Tidak menerima parent. `Show` kedua selama hidup tidak me-restart timer. Setelah timeout, jangan panggil getter/setter/Show lagi; buat notifikasi baru. `Destroy()` tetap aman berulang dan langsung menghapus, bukan fade-out.

## 10. Section

```lua
local section = UI:CreateSection(parent, {
    Name = "Lanjutan", LayoutOrder = 10,
    Collapsible = true, DefaultExpanded = true,
})
UI:CreateButton(section.Container, {
    Name = "Reset", LayoutOrder = 1,
    Callback = function() print("Diminta reset") end,
})
local child = UI:CreateLabel(parent, { Text = "Catatan", LayoutOrder = 2 })
section:AddComponent(child) -- pindah, bukan clone
section:SetExpanded(false)
print(section:GetExpanded())
```

Container adalah field Frame, bukan metode. Anak ikut dihancurkan saat Section dihapus. Tidak ada callback ekspansi; `SetExpanded` tetap bekerja jika Collapsible false.

## 11. Label

```lua
local label = UI:CreateLabel(parent, {
    Name = "StatusLabel", Text = "Status: siap", LayoutOrder = 11,
    TextSize = 13, Color = Color3.fromRGB(240, 240, 255),
})
label:SetText("Status: diperbarui")
print(label:GetText())
```

Label sederhana tinggi tetap; Name tidak menjadi default Text.

## 12. Paragraph

```lua
local paragraph = UI:CreateParagraph(parent, {
    Name = "Informasi", LayoutOrder = 12,
    Title = "Tentang panel", Content = "Panel ini hanya mengelola tampilan lokal.",
})
paragraph:SetTitle("Informasi panel")
paragraph:SetContent("Teks isi mendukung wrapping dan tinggi otomatis.")
print(paragraph:GetTitle(), paragraph:GetContent())
```

## 13. Divider

```lua
local divider = UI:CreateDivider(parent, {
    Name = "Pemisah", LayoutOrder = 13,
})
-- Tidak ada setter; warna mengikuti Border tema saat dibuat.
-- divider:Destroy() jika pemisah tidak dibutuhkan lagi.
```

## 14. ProgressBar

```lua
local progress = UI:CreateProgressBar(parent, {
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
local search = UI:CreateSearchBox(parent, {
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

-- Hanya jika pemanggil memang hendak menonaktifkan SEMUA komponen library:
-- UI:Destroy()
```

`UI` dari GetUI dipakai bersama shell/integrasi lain. Jangan menghancurkannya untuk sekadar menghapus satu kontrol. `UI:Destroy()` tidak menghapus ScreenGui atau shell Main; kepemilikan dijelaskan di [ARCHITECTURE.md](ARCHITECTURE.md).
