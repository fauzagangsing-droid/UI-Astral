# Prosedur rilis AstralLite

## Status saat ini

**2.0.0 belum dirilis; release/tag belum dipublikasikan.** Entry Version dan package.json.version sudah selaras 2.0.0. Validasi final sumber/tooling/dokumentasi selesai **2026-11-02**, berdasarkan eksekusi pekerjaan utama yang dilaporkan pemilik:

| Pemeriksaan | Hasil aktual |
| --- | --- |
| npm test dengan LUAU_COMPILER lokal aktif | **24 tests, 24 pass, 0 fail, 0 skip** |
| npm run build + build:check | **20 modul v2.0.0**, Lua/manifest dihasilkan; check **byte-exact lulus** |
| Rojo build + sourcemap | **Lulus**, Rojo **7.7.0-rc.1**; place/sourcemap generated/ignored |
| validate dengan --compiler lokal | **Lulus**, 20 modul/15 factory, mapping/API/forbidden tokens/tautan docs; **24 Lua dikompilasi** |
| Diagnostik editor | **0 error, 0 warning** |

Studio source/bundle specs, input/render/perangkat/memori **belum dijalankan** karena runtime Studio tidak tersedia. Detail perintah dan batas bukti ada pada tabel **VALIDATION** di [AUDIT.md](AUDIT.md). Tidak ada perubahan sumber lanjutan yang direncanakan. Langkah di bawah tetap prosedur untuk reproduksi, pemeriksaan runtime yang tersisa, dan rilis/perubahan berikutnya; bukan klaim bahwa pipeline saat ini masih menunggu build atau penyelarasan versi.

## 1. Bekukan source dan versi

1. Tinjau diff dan pastikan hanya perubahan yang hendak dirilis masuk. Source tetap di `src/shared/UILibrary` untuk Rojo; jangan rename hanya demi nama artefak.
2. Kandidat saat ini sudah memiliki literal `UILibrary.Version = "2.0.0"` dan `"version": "2.0.0"` di package.json. Pertahankan kecocokan; pada versi berikutnya bump keduanya ke versi yang disepakati. Config CreateWindow.Version hanya label UI, bukan sumber versi build.
3. Perbarui CHANGELOG, migrasi/API bila kontrak berubah. Jangan mengubah “belum dirilis” menjadi klaim publikasi sebelum benar-benar diterbitkan.
4. Periksa `.gitignore`: `build/` dan `.tools/` tetap lokal/ignored. Arsip `ui.lua` dan aftman tidak perlu diedit. Dist Lua/manifest harus dapat dilacak bersama source.

Bundler mengambil versi hanya dari entry; **tidak otomatis memverifikasi package.json**. Kecocokan saat ini sudah diperiksa; pemeriksaan manual berikut dapat diulang dari root:

```sh
node -e 'const fs=require("node:fs");const p=JSON.parse(fs.readFileSync("package.json","utf8"));const s=fs.readFileSync("src/shared/UILibrary/init.lua","utf8");if(p.version!=="2.0.0"||!s.includes("UILibrary.Version = "+JSON.stringify(p.version)))throw Error("Versi entry/package belum selaras");console.log("Versi selaras:",p.version)'
```

Perintah tersebut khusus kandidat 2.0.0 dan bentuk assignment entry sekarang; sesuaikan versi target saat rilis berikutnya. Status versi saat ini selaras, bukan gate yang belum terpenuhi.

## 2. Bangun distribusi satu berkas

Node.js 18+ dan npm diperlukan; tidak ada dependensi paket yang perlu di-install untuk skrip saat ini:

```sh
npm run build
npm run build:check
```

Hasil yang wajib dipasangkan:

| Berkas | Isi |
| --- | --- |
| `dist/AstralLite.lua` | Source ModuleScript standalone yang return tabel library |
| `dist/AstralLite.manifest.json` | Version, entry, sourceSha256, artifactSha256, daftar source/hash dan urutan modul |

Jangan mengedit dist manual atau menyalin arsip ui.lua sebagai hasil build. Build final saat ini sudah selesai; bila source berubah di masa depan, selesaikan perubahan sebelum rebuild. `build:check` membandingkan byte exact tanpa menulis, dan gagal bila artifact/manifest hilang, stale, atau pasangan tidak cocok.

Bundler custom leksikal/token-aware menerima static require script.Child/Parent dan menggantinya dengan loader closure/cache internal, bukan loadstring. Source library tidak boleh menggunakan interpolated strings, runtime script refs bebas, require dinamis/alias/eksternal, cycle, missing/folder dependency, atau Lua tidak terjangkau; lihat [ARCHITECTURE.md](ARCHITECTURE.md). Ini bukan compiler Luau penuh. Output deterministik dari BOM/LF-normalized source; manifest/hash berubah bila input berubah. Pair output memakai rename atomik per file, bukan satu transaksi atomik pasangan; jalankan check setelah gangguan proses.

## 3. Verifikasi tooling dan sintaks

```sh
npm test
npm run validate
# Hanya bila tool lokal sudah tersedia:
npm run validate -- --compiler=.tools/luau/luau-compile.exe
```

- Eksekusi 2026-11-02 dengan LUAU_COMPILER aktif telah lulus 24/24, 0 fail/skip. Pada rerun/versi berikutnya catat pass/fail/skip aktual, bukan menyimpulkan dari jumlah deklarasi kasus; suite ini menguji scanner/resolver/graph/hash/build/check/CLI/validator, bukan runtime Studio.
- Kasus compiler Node opsional memakai environment `LUAU_COMPILER`. Contoh PowerShell bila ingin mengaktifkannya:

  ```powershell
  $env:LUAU_COMPILER = '.tools/luau/luau-compile.exe'
  npm test
  Remove-Item Env:LUAU_COMPILER
  ```

- `--compiler=...` pada validate atau LUAU_COMPILER menjalankan compiler Luau standar yang disuplai pemilik, tidak mengunduh executable. Tool `.tools/` bukan library dependency dan ignored.
- Compiler hanya syntax-check source, spec dan bundle. Ia tidak menjalankan Roblox, fixture, rendering, input, signal, atau timer.
- Validator juga menjalankan build check, mapping/API/test-token coverage/forbidden-token/local-link checks; token coverage bukan bukti assertion Studio dijalankan.

## 4. Verifikasi Rojo dan source mapping

`default.project.json` sudah tersedia. Pastikan hanya dua path: library → ReplicatedStorage.UILibrary dan `src/client` → StarterPlayer.StarterPlayerScripts (Main LocalScript).

```sh
mkdir -p build
rojo build default.project.json -o build/AstralLite.rbxlx
rojo sourcemap default.project.json -o build/sourcemap.json
npm run validate
```

PowerShell: buat direktori lewat `New-Item -ItemType Directory -Force build`. Jika sourcemap ada, validator memeriksa kelas/path/hierarki seluruh module; regenerasi setelah source hierarchy berubah. Place/sourcemap tetap generated/ignored, bukan artefak source bundle yang perlu dipublikasikan sebagai satu ModuleScript.

Aftman opsional (`aftman install` memerlukan jaringan bila mengunduh tool); toolchain yang ada tidak perlu diubah untuk menulis docs. `rojo serve` + plugin adalah alternatif sinkronisasi Studio, bukan perintah tes yang berakhir otomatis.

## 5. Jalankan Studio manual pada dua bentuk library

Ikuti [tests/README.md](../tests/README.md). Impor opt-in Components.spec dan Window.spec sebagai ModuleScripts test-only, bukan LocalScript yang auto-run dan bukan bagian mapping produksi. Require spec mengembalikan fungsi runner; panggil berurutan dalam **Play/client**:

- Source default: runner tanpa argumen menggunakan ReplicatedStorage.UILibrary.
- Bundle: pasang seluruh dist source sebagai ReplicatedStorage.AstralLite, lalu injeksikan tabel hasil require ke masing-masing runner. Jangan berikan Instance ModuleScript sebagai override.

Jalankan sesi terpisah/restart Play saat memperbarui source karena cache require. Catat Output, return count, kegagalan async, versi Studio dan perangkat; jangan tulis “lulus Studio” hanya dari compiler/tes Node.

Manual tambahan: Main.GetUI tiga return, delapan tab judul-saja vs CreateWindow nol tab, mouse/touch drag dan threshold logo, RightShift saat fokus, capture keyboard/Enter/focus loss, viewport/inset/kamera, Section UIScale, notifikasi timeout dan destroy aktif. Gamepad belum diuji; jangan mengklaim dukungan terverifikasi tanpa pengujian.

Utamakan window.Destroy sebelum menghancurkan script pemilik. Self-Destroying script hanya upaya terbaik pada deferred signals. UI.Destroy bukan shutdown shell. Hapus spec test-only sebelum mempublikasikan pengalaman; tidak memerlukan paket test framework.

## 6. Pemeriksaan instalasi single-file

Dari hasil yang baru dibangun dan diverifikasi:

1. Buat **ReplicatedStorage.AstralLite** sebagai ModuleScript.
2. Ganti seluruh Source dengan isi penuh dist/AstralLite.lua. Tidak perlu child ModuleScripts, URL atau loadstring.
3. LocalScript terpisah me-require modul lalu CreateWindow → CreateTab Home → CreateToggle, seperti [README](../README.md).
4. Pastikan Notification perlu Show eksplisit dan window.Destroy benar-benar menghapus GUI.
5. Jangan mengaktifkan Main sumber/arsip sekaligus bootstrap bundle tanpa sengaja; keduanya membuat window sendiri. Require library saja tidak membuat window.

## 7. Integritas, commit, tag, dan publikasi oleh pemilik

- Setelah seluruh pemeriksaan, ulangi `npm run build:check`. Jika source berubah lagi, rebuild dan ulangi validasi yang relevan sebelum mengambil checksum.
- Cocokkan hash file `dist/AstralLite.lua` dengan `artifactSha256` manifest. Contoh PowerShell:

  ```powershell
  Get-FileHash dist/AstralLite.lua -Algorithm SHA256
  ```

  Bandingkan nilai hex tanpa mempermasalahkan huruf besar/kecil. `sourceSha256` adalah hash agregat daftar source normalized, **bukan hash file artifact**. Hash mendeteksi perubahan, bukan membuktikan identitas penerbit.
- Tabel VALIDATION saat ini sudah terisi hasil final 2026-11-02. Pada pemeriksaan berikutnya perbarui hasil/skip dan batasan aktual, terutama Studio yang belum dijalankan. Pertahankan kecocokan entry/package/manifest dan changelog.
- **Hanya atas tindakan/persetujuan pemilik**, commit source, docs, package metadata, `dist/AstralLite.lua`, dan `dist/AstralLite.manifest.json` bersama. Jangan commit tool `.tools/` atau build place. Tag versi hanya dibuat pemilik setelah gate dipenuhi; prosedur ini tidak membuat commit/tag otomatis.
- Pemilik membuat release pada kanal yang dipilih, mengunggah artifact Lua, manifest, dan checksum yang dihitung dari file final. Jangan memasang URL contoh seolah release sudah ada. Perbarui status “belum dirilis”/catatan publikasi hanya setelah benar-benar diterbitkan.

Bundle final serta validasi sumber/tooling/dokumentasi sudah selesai, tetapi rilis/tag belum dipublikasikan dan pengujian Studio tetap belum dilakukan. Dokumen ini tidak membuat commit, tag, upload, atau publikasi otomatis.
