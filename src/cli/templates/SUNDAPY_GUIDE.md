# 📖 PANDUAN LENGKAP & REFERENSI ARSITEKTUR SUNDAPY
> **Buku Pegangan Developer Murni (Cheatsheet, API Dictionary & Decision Matrix)**

Selamat datang di **SundaPy**! Dokumen ini adalah kamus referensi lengkap yang dirancang agar Anda dapat menguasai seluruh aspek bahasa, modul bawaan, tipe data perangkat keras, dan pola arsitektural SundaPy tanpa perlu membuka kode sumber compiler.

---

## DAFTAR ISI
1. [Filosofi & Cara Kerja SundaPy](#1-filosofi--cara-kerja-sundapy)
2. [Mode Kompilasi: #strict vs Dinamis](#2-mode-kompilasi-strict-vs-dinamis)
3. [Tipe Data Hardware Primitif (i8 s.d. f64)](#3-tipe-data-hardware-primitif)
4. [Kata Kunci & Alur Kontrol (Keywords)](#4-kata-kunci--alur-kontrol)
5. [Fungsi-Fungsi Bawaan (Built-in Functions)](#5-fungsi-fungsi-bawaan)
6. [Modul Standar & Matriks Keputusan (Decision Matrix)](#6-modul-standar--matriks-keputusan)
   - [A. Grafika & Antarmuka: screenGUI vs GUIEngine](#a-grafika--antarmuka-screengui-vs-guiengine)
   - [B. Komputasi GPU: gpu.field vs gpu.arena vs gpu.pool](#b-komputasi-gpu-gpufield-vs-gpuarena-vs-gpupool)
   - [C. Konkurensi: threading vs asyncio](#c-konkurensi-threading-vs-asyncio)
   - [D. Jaringan: socket vs requests](#d-jaringan-socket-vs-requests)
7. [Perintah CLI & Build Tooling](#7-perintah-cli--build-tooling)
8. [Integrasi VSCode & Daftar Snippets](#8-integrasi-vscode--daftar-snippets)

---

## 1. FILOSOFI & CARA KERJA SUNDAPY

SundaPy adalah dialek bahasa berorientasi Python yang **ditranspilasikan langsung menjadi bahasa Zig native**, lalu dikompilasi oleh LLVM menjadi file biner mesin mandiri (*Ahead-Of-Time / AOT Compilation*).

* **Nol GIL (No Global Interpreter Lock):** Thread Python Anda berjalan paralel murni di multi-core CPU.
* **Nol Garbage Collector Pause:** Tipe hardware dialokasikan di register CPU dan stack.
* **Zero-Copy Memory Interop:** Berbagi buffer memori langsung antara CPU $\leftrightarrow$ GPU VRAM $\leftrightarrow$ Display Server X11 tanpa duplikasi byte.

---

## 2. MODE KOMPILASI: #strict VS DINAMIS

### A. Kapan Menggunakan `#strict`?
Tulis `#strict` di baris pertama file Anda jika:
* Anda membangun algoritma numerik, game loop, simulasi fisika, benchmark, atau shader/grafika.
* Anda membutuhkan **kecepatan hardware native setara bahasa C/Zig** (eksekusi dalam nanodetik).
* **Aturan Strict:** Semua fungsi wajib mendeklarasikan tipe parameter dan tipe balikan (`def func(x: i64) -> f64:`).

### B. Kapan Memakai Mode Dinamis (Tanpa `#strict`)?
Jangan gunakan `#strict` jika:
* Anda membuat script otomatisasi cepat, parsing JSON fleksibel, web scraping, atau mengimpor library dinamis.

---

## 3. TIPE DATA HARDWARE PRIMITIF

| Tipe Data | Ukuran | Rentang Nilai | Kapan Menggunakan? | Skenario Penggunaan |
| :--- | :--- | :--- | :--- | :--- |
| **`i8`** | 1 Byte | -128 s.d. 127 | Offset koordinat kecil, delta signed | Audio sample 8-bit, matriks rotasi diskrit |
| **`u8`** | 1 Byte | 0 s.d. 255 | Nilai warna channel RGBA, byte biner | Buffer warna piksel (`0-255`), raw byte network |
| **`i16`** | 2 Byte | -32.768 s.d. 32.767 | Game retro 2D, koordinat tile map | Posisi karakter platformer, data sensor 16-bit |
| **`u16`** | 2 Byte | 0 s.d. 65.535 | Nomor port jaringan | Port TCP/UDP (`8080`, `443`), mesh vertex index |
| **`i32`** | 4 Byte | ±2,1 Miliar | Resolusi layar modern, counter umum | Lebar/tinggi layar 1440p/4K, offset buffer grafis |
| **`u32`** | 4 Byte | 0 s.d. 4,2 Miliar | Warna ARGB 32-bit packed (`0xAARRGGBB`) | Indeks alokasi VRAM hingga 4 GB |
| **`i64`** | 8 Byte | ±9,2 Triliun Miliar | **STANDAR INTEGER UTAMA** | Waktu nanodetik (`time_ns()`), pointer memori |
| **`u64`** | 8 Byte | 0 s.d. 18 Triliun Miliar | Pointer fisik 64-bit perangkat keras | Alamat VRAM GPU (`dev_ptr`), Wyhash 64-bit |
| **`i128`**| 16 Byte| ±1,7 × $10^{38}$ | Angka raksasa tanpa overhead BigInt | Fibonacci besar, faktorial, kriptografi native |
| **`f32`** | 4 Byte | 7 digit presisi | **STANDAR GRAFIKA 3D & GPU FIELD** | Koordinat partikel GPU, vertex shader, VRAM hemat |
| **`f64`** | 8 Byte | 15-17 digit presisi | **STANDAR FLOAT UTAMA** | Kalkulasi sains, delta-time host, astronomi |
| **`void`**| 0 Byte | - | Return type fungsi tanpa return | `def main() -> void:` |

---

## 4. KATA KUNCI & ALUR KONTROL

* **Perulangan `while`:** Kontrol perulangan berbasis kondisi. Diterjemahkan langsung ke instruksi jump register hardware.
* **Perulangan `for ... in range(...)`:** Dioptimasi compiler menjadi counter register tanpa alokasi iterator objek.
* **Percabangan `if / elif / else`:** Evaluasi logika kondisional native.
* **Pattern Matching `match / case`:**
  ```python
  match status:
      case 200: print("Sukses")
      case 404: print("Tidak Ditemukan")
      case _: print("Lainnya")
  ```
* **Kelas & OOP (`class`):**
  Mendukung atribut bertipe hardware (`x: f64`), konstruktor `__init__`, dan pewarisan.
* **Penanganan Error (`try / except / finally`):**
  Blok pengaman eksekusi exception runtime.
* **Konkurensi (`async def / await`):**
  Mendefinisikan coroutine asinkron non-blocking.

---

## 5. FUNGSI-FUNGSI BAWAAN (BUILT-IN)

* `print(*args)`: Mencetak ke konsol tanpa alokasi buffer string Python.
* `len(obj)`: Membaca ukuran array/list secara $O(1)$.
* `range(start, stop, step)`: Iterator angka hardware.
* `abs(x)`, `min(*args)`, `max(*args)`, `sum(iter)`: Pemetaan ke instruksi aritmatika CPU.
* `enumerate(iter)`, `zip(*iters)`: Iterasi multi-koleksi tanpa duplikasi data.
* `int(x)`, `float(x)`, `str(x)`: Konversi tipe data aman.

---

## 6. MODUL STANDAR & MATRIKS KEPUTUSAN

### A. Grafika & Antarmuka: `screenGUI` vs `GUIEngine`
* **`screenGUI` (Jendela & Layar Fisik):**
  * ✅ Gunakan untuk: Membuka window X11, mendeteksi tombol keyboard (`is_key_pressed`), membaca posisi kursor mouse (`get_mouse_pos`), dan mempresentasikan buffer ke monitor (`render`).
* **`GUIEngine` (Kuas & Kanvas 2D):**
  * ✅ Gunakan untuk: Menggambar objek ke kanvas (`draw_pixel`, `draw_rect`, `draw_line`, `draw_circle`, `draw_text`).
* **Aturan Pakai:** Buat kanvas dengan `GUIEngine`, gambar seluruh objek, lalu kirim hasilnya ke monitor via `screenGUI.render(canvas)`.

---

### B. Komputasi GPU: `gpu.field` vs `gpu.arena` vs `gpu.pool`
* **`gpu.field(dims, fill)` (HLA - High-Level Array):**
  * ✅ Gunakan untuk: Grid 2D citra, volume 3D voxel, atau matriks tensor yang membutuhkan koordinat alami `f[y, x]`.
* **`gpu.arena_alloc(bytes)` (LLA - Low-Level Allocator):**
  * ✅ Gunakan untuk: Alokasi cepat ribuan buffer sementara per frame. Setelah frame selesai, reset total dengan `gpu.arena_reset()` (latensi < 0.2 µs).
* **`gpu.pool_dispatch(func, args)` (Multi-Worker Pool):**
  * ✅ Gunakan untuk: Menjalankan kalkulasi batch berat secara paralel di latar belakang tanpa membuat frame rate tersendat.

---

### C. Konkurensi: `threading` vs `asyncio`
* **`threading` (Multi-Core CPU):**
  * ✅ Gunakan untuk: Tugas CPU-bound berat (kalkulasi fisika, simulasi, AI pathfinding). Berjalan di thread native Linux murni tanpa GIL.
* **`asyncio` (Event Loop Coroutine):**
  * ✅ Gunakan untuk: Tugas I/O-bound (banyak koneksi jaringan menunggu data tanpa memakan thread CPU).

---

### D. Jaringan: `socket` vs `requests`
* **`socket` (POSIX Network Level Rendah):**
  * ✅ Gunakan untuk: Protokol biner kustom, koneksi socket TCP/UDP real-time (game multiplayer, binary stream).
* **`requests` (HTTP/HTTPS Client Tingkat Tinggi):**
  * ✅ Gunakan untuk: Mengambil data dari REST API web (`requests.get("https://...")`).

---

## 7. PERINTAH CLI & BUILD TOOLING

| Perintah | Fungsi & Kegunaan |
| :--- | :--- |
| `sundapy main.py` | Menjalankan program secara normal (mode seimbang). |
| `sundapy --fast main.py` | **Mode Kecepatan Maksimal:** Kompilasi LLVM `-O3` dan mematikan overflow checks (`ReleaseFast`). |
| `sundapy --build main.py` | Menghasilkan file binary executable mandiri di direktori saat ini. |
| `sundapy --outname app main.py` | Mengompilasi menjadi binary mandiri dengan nama kustom `app`. |
| `sundapy -y main.py` | Memaksa kompilasi ulang (bypass hash cache). |
| `sundapy fetch <package>` | Mengunduh package wheel dari PyPI ke `.cache/pyLibrary`. |
| `sundapy fetch --build <pkg>` | Mengunduh package lalu otomatis mengompilasi menjadi binary executable mandiri. |
| `sundafetch --build <pkg/dir> -o <bin>` | Mengompilasi library/repo Python menjadi binary mandiri dengan nama kustom. |

---

## 8. INTEGRASI VSCODE & DAFTAR SNIPPETS

### Keyboard Shortcuts
* **`Ctrl + Shift + B`:** Menjalankan file aktif saat ini secara otomatis di terminal VSCode.

### Daftar Snippet Cepat (Ketik prefix lalu tekan `Tab`):
* `sunda-strict` $\rightarrow$ Template skrip numerik hardware AOT.
* `sunda-bench` $\rightarrow$ Template microbenchmark presisi nanodetik.
* `sunda-gui` $\rightarrow$ Template window game loop X11 60 FPS.
* `sunda-canvas` $\rightarrow$ Template kanvas gambar 2D (`GUIEngine`).
* `sunda-gpu-field` $\rightarrow$ Template array multidimensi GPU VRAM (HLA).
* `sunda-gpu-arena` $\rightarrow$ Template VRAM fast scratchpad sub-allocator (LLA).
* `sunda-class` $\rightarrow$ Template kelas OOP dengan atribut bertipe hardware.
* `sunda-match` $\rightarrow$ Template pattern matching modern.
* `sunda-tcp-server` $\rightarrow$ Template server jaringan socket TCP.
* `sunda-thread` $\rightarrow$ Template multi-core threading dengan Mutex Lock.
* `sunda-async` $\rightarrow$ Template coroutine asinkron `asyncio`.
* `sunda-http` $\rightarrow$ Template HTTP REST client `requests`.
