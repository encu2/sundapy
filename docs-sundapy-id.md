# Buku Panduan Resmi & Referensi Bahasa SundaPy
> **The SundaPy Programming Language & Toolchain Reference Manual**  
> *Versi Dokumentasi: 1.0.0-LTS | Target: Linux x86_64 / AArch64 | Standar: The Rust Programming Language Reference Standard*

---

## Prakata: Menjembatani Kemudahan Python dengan Kecepatan Mesin Native

Selamat datang di **Buku Panduan Resmi SundaPy**. Dokumentasi ini dirancang sebagai manual definitif, komprehensif, dan pedagogis untuk **seluruh spektrum pengembang**:
- **Tingkat Pemula (*Beginner Curve*):** Pengguna yang baru memulai belajar pemrograman atau beralih dari Python standar, yang membutuhkan penjelasan jelas mengenai sintaksis dasar, struktur indentasi, variabel, percabangan, fungsi, dan cara membaca pesan kesalahan compiler.
- **Tingkat Menengah (*Intermediate Curve*):** Pengembang aplikasi yang ingin membangun modul perangkat lunak modular, menerapkan pemrograman berorientasi objek (OOP), menangani exception secara aman, mengonsumsi REST API, atau membangun utilitas desktop.
- **Tingkat Lanjut & Arsitek Sistem (*Advanced & Systems Curve*):** Software engineer, pengembang infrastruktur, dan peneliti AI/HPC yang membutuhkan performa komputasi register CPU murni via mode `#strict`, multithreading paralel bebas GIL (*Zero-GIL*), manajemen memori prediktif tanpa *Garbage Collector*, integrasi langsung header C (`@cImport`), serta manipulasi memori mentah dan shared library dinamis melalui FFI.

SundaPy bukan sebuah interpreter baru; SundaPy adalah **Ahead-Of-Time (AOT) Native Transpiler & Runtime Toolchain** yang menerjemahkan sintaks Python 3 menjadi biner mesin mandiri (*standalone ELF executable*) bertenaga compiler **Zig** dan backend pengoptimal **LLVM**.

---

## Peta Kurva Pembelajaran (The Learning Curve Roadmap)

```text
+-----------------------------------------------------------------------------------+
|                           PETA KURVA PEMBELAJARAN SUNDAPY                         |
+-----------------------------------------------------------------------------------+
|                                                                                   |
|  [TINGKAT PEMULA]                                                                 |
|  - Bab 1: Struktur Leksikal, Sintaksis & Aturan Indentasi 4-Spasi                  |
|  - Bab 2: Katalog Lengkap 38 Kata Kunci (Keywords) SundaPy                        |
|  - Bab 3: Sistem Operator, Assignment Walrus (:=), & Presedensi                   |
|  - Bab 4: Variabel & Dynamic Mode (Ekspresif & Ramah Pemula)                      |
|                                     |                                             |
|                                     v                                             |
|  [TINGKAT MENENGAH]                                                               |
|  - Bab 5: Fitur Sintaks Modern (PEP 822 d"...", PEP 750 t"...", Operator ?? & ?.) |
|  - Bab 6: Pemrograman Berorientasi Objek (OOP) & Single Inheritance               |
|  - Bab 7: Penanganan Eksepsi (PEP 758 Multiple Exceptions) & Context Manager      |
|  - Bab 8: Modul Standar Dasar (math, time, socket, requests)                      |
|                                     |                                             |
|                                     v                                             |
|  [TINGKAT LANJUT & SISTEM]                                                        |
|  - Bab 9: Mode #strict & Tipe Data Primitif Hardware ALU (i8..i64, f32, f64)      |
|  - Bab 10: Model Eksekusi & Concurrency Bebas GIL (Zero-GIL POSIX Multithreading) |
|  - Bab 11: Model Memori Zero-GC (Escape Analysis: Stack Frame vs Arena Allocator) |
|  - Bab 12: Direct C Interoperability (@cImport & #@link)                          |
|  - Bab 13: Sub-Sistem Foreign Function Interface (FFI) High & Low-Level           |
|  - Bab 14: Grafika Desktop X11 MIT-SHM 60 FPS & Komputasi Array VRAM GPU         |
|  - Bab 15: Toolchain, Package Manager sundafetch, & CLI Caching Wyhash            |
|  - Bab 16: Katalog Kode Diagnostik Compiler (Error Index E0001 - E0010)           |
|  - Bab 17: The SundaPy Cookbook: 7 Proyek Nyata End-to-End                       |
|  - Bab 18: Panduan Optimasi Performa Ekstrim, SIMD, & FAQ Komprehensif            |
|                                                                                   |
+-----------------------------------------------------------------------------------+
```

---

## Daftar Isi Terperinci (Table of Contents)

1. [Bab 1: Struktur Leksikal, Sintaksis & Aturan Indentasi](#bab-1-struktur-leksikal-sintaksis--aturan-indentasi)
   - [1.1 Anatomi Program & Titik Masuk](#11-anatomi-program--titik-masuk)
   - [1.2 Aturan Emas Indentasi (The Golden Rule of Indentation)](#12-aturan-emas-indentasi-the-golden-rule-of-indentation)
   - [1.3 Token Indent, Dedent, dan Pelacakan Stack Whitespace](#13-token-indent-dedent-dan-pelacakan-stack-whitespace)
   - [1.4 Baris Lanjutan: Explicit (\) vs Implicit ((), [], {})](#14-baris-lanjutan-explicit--vs-implicit---)
   - [1.5 Komentar, Docstrings, dan Direktif Compiler (#strict, #@link)](#15-komentar-docstrings-dan-direktif-compiler-strict-link)
   - [1.6 Aturan Penamaan Pengenal (Identifiers) & Case-Sensitivity](#16-aturan-penamaan-pengenal-identifiers--case-sensitivity)
2. [Bab 2: Katalog Lengkap 38 Kata Kunci (The Exhaustive Keywords Catalog)](#bab-2-katalog-lengkap-38-kata-kunci-the-exhaustive-keywords-catalog)
   - [2.1 Tabel Ringkasan Kata Kunci SundaPy](#21-tabel-ringkasan-kata-kunci-sundapy)
   - [2.2 Percabangan & Logika: `if`, `elif`, `else`](#22-percabangan--logika-if-elif-else)
   - [2.3 Perulangan & Aliran: `while`, `for`, `in`, `break`, `continue`, `pass`](#23-perulangan--aliran-while-for-in-break-continue-pass)
   - [2.4 Fungsi & Generator: `def`, `return`, `lambda`, `yield`](#24-fungsi--generator-def-return-lambda-yield)
   - [2.5 Pemrograman Kelas: `class`](#25-pemrograman-kelas-class)
   - [2.6 Sistem Modul & Impor: `import`, `from`, `as`](#26-sistem-modul--impor-import-from-as)
   - [2.7 Penanganan Eksepsi: `try`, `except`, `finally`, `raise`](#27-penanganan-eksepsi-try-except-finally-raise)
   - [2.8 Context Manager & Asersi: `with`, `assert`](#28-context-manager--asersi-with-assert)
   - [2.9 Pattern Matching: `match`, `case`](#29-pattern-matching-match-case)
   - [2.10 Asinkronus: `async`, `await`](#210-asinkronus-async-await)
   - [2.11 Cakupan Variabel & Memori: `global`, `nonlocal`, `del`, `const`](#211-cakupan-variabel--memori-global-nonlocal-del-const)
   - [2.12 Nilai Literal & Logika Bawaan: `True`, `False`, `None`, `is`, `and`, `or`, `not`](#212-nilai-literal--logika-bawaan-true-false-none-is-and-or-not)
3. [Bab 3: Operator Lengkap & Hirarki Presedensi](#bab-3-operator-lengkap--hirarki-presedensi)
   - [3.1 Operator Aritmatika & Matematika](#31-operator-aritmatika--matematika)
   - [3.2 Operator Relasional & Perbandingan](#32-operator-relasional--perbandingan)
   - [3.3 Operator Logika Boolean](#33-operator-logika-boolean)
   - [3.4 Operator Bitwise Perangkat Keras](#34-operator-bitwise-perangkat-keras)
   - [3.5 Operator Penugasan & Walrus (`:=`)](#35-operator-penugasan--walrus-)
   - [3.6 Operator Modern SundaPy: None-Coalescing (`??`) & Safe Navigation (`?.`)](#36-operator-modern-sundapy-none-coalescing---safe-navigation-)
   - [3.7 Tabel Presedensi Operator Lengkap](#37-tabel-presedensi-operator-lengkap)
4. [Bab 4: Sistem Tipe Data & Paradigma Ganda (Dynamic vs Strict)](#bab-4-sistem-tipe-data--paradigma-ganda-dynamic-vs-strict)
   - [4.1 Dynamic Mode: Prototyping Fleksibel & Duck Typing](#41-dynamic-mode-prototyping-fleksibel--duck-typing)
   - [4.2 Strict Mode (`#strict`): Type Invariance & Kecepatan Native](#42-strict-mode-strict-type-invariance--kecepatan-native)
   - [4.3 Tipe Primitif Hardware ALU: `i8`..`i64`, `u8`..`u64`, `f32`, `f64`, `bool`, `str`](#43-tipe-primitif-hardware-alu-i8i64-u8u64-f32-f64-bool-str)
   - [4.4 Tata Letak Memori Tagged Union `Dynamic` 24-Byte](#44-tata-letak-memori-tagged-union-dynamic-24-byte)
   - [4.5 Koleksi Bawaan: `list`, `dict`, `set`, `tuple`, Sentinel `None`](#45-koleksi-bawaan-list-dict-set-tuple-sentinel-none)
5. [Bab 5: Fitur Sintaksis Modern & Implementasi PEP Mutakhir](#bab-5-fitur-sintaksis-modern--implementasi-pep-mutakhir)
   - [5.1 PEP 822: Compile-Time Dedented Strings (`d"..."`)](#51-pep-822-compile-time-dedented-strings-d)
   - [5.2 PEP 750: Template Strings (`t"..."`)](#52-pep-750-template-strings-t)
   - [5.3 PEP 758: Multiple Exceptions Tanpa Tanda Kurung](#53-pep-758-multiple-exceptions-tanpa-tanda-kurung)
   - [5.4 Structural Pattern Matching Tingkat Lanjut](#54-structural-pattern-matching-tingkat-lanjut)
   - [5.5 Idiom Looping: `enumerate()`, `zip()`, Multi-Dimensional Replications](#55-idiom-looping-enumerate-zip-multi-dimensional-replications)
6. [Bab 6: Pemrograman Berorientasi Objek (OOP) & Inheritance](#bab-6-pemrograman-berorientasi-objek-oop--inheritance)
   - [6.1 Deklarasi Kelas, Atribut, dan Konstruktor `__init__`](#61-deklarasi-kelas-atribut-dan-konstruktor-__init__)
   - [6.2 Pewarisan Tunggal (Single Inheritance) & Resolusi `super()`](#62-pewarisan-tunggal-single-inheritance--resolusi-super)
   - [6.3 Method Overriding & Dispatch Statis](#63-method-overriding--dispatch-statis)
7. [Bab 7: Arsitektur Eksekusi & Concurrency Bebas GIL](#bab-7-arsitektur-eksekusi--concurrency-bebas-gil)
   - [7.1 Pipeline Kompilasi AOT ke Native ELF Executable](#71-pipeline-kompilasi-aot-ke-native-elf-executable)
   - [7.2 Concurrency Zero-GIL di Atas POSIX Kernel Threads](#72-concurrency-zero-gil-di-atas-posix-kernel-threads)
   - [7.3 Sinkronisasi & Penghindaran Data Race (`threading.Lock`)](#73-sinkronisasi--penghindaran-data-race-threadinglock)
8. [Bab 8: Model Keamanan Memori Tanpa Garbage Collector](#bab-8-model-keamanan-memori-tanpa-garbage-collector)
   - [8.1 Two-Pass Escape Analysis](#81-two-pass-escape-analysis)
   - [8.2 Alokasi Stack Frame (Zero Cost & Auto Clean)](#82-alokasi-stack-frame-zero-cost--auto-clean)
   - [8.3 Thread-Local Arena Allocator (Zero Fragmentation & Bulk Free)](#83-thread-local-arena-allocator-zero-fragmentation--bulk-free)
9. [Bab 9: Direct C Interoperability & Linker Directives](#bab-9-direct-c-interoperability--linker-directives)
   - [9.1 Direct C Header Import (`@cImport`)](#91-direct-c-header-import-cimport)
   - [9.2 Direktif Linker Sistem (`#@link`)](#92-direktif-linker-sistem-link)
   - [9.3 Interaksi Header C Lokal & Struktur Data Eksternal](#93-interaksi-header-c-lokal--struktur-data-eksternal)
10. [Bab 10: Sub-Sistem Foreign Function Interface (FFI) Dinamis](#bab-10-sub-sistem-foreign-function-interface-ffi-dinamis)
    - [10.1 High-Level FFI: Dynamic Library Loading & C-Structs](#101-high-level-ffi-dynamic-library-loading--c-structs)
    - [10.2 Low-Level FFI: Pointer Mentah, libc Direct Alloc/Free & Raw Dispatch](#102-low-level-ffi-pointer-mentah-libc-direct-allocfree--raw-dispatch)
11. [Bab 11: Spesifikasi Modul Pustaka Standar (`sundapy_std`)](#bab-11-spesifikasi-modul-pustaka-standar-sundapy_std)
    - [11.1 Modul `math` (FPU Math & Hardware Integer Intrinsics PEP 619)](#111-modul-math-fpu-math--hardware-integer-intrinsics-pep-619)
    - [11.2 Modul `time` (Nanosecond Clock & Non-Busy Sleep)](#112-modul-time-nanosecond-clock--non-busy-sleep)
    - [11.3 Modul `threading` (POSIX Concurrency & Mutex)](#113-modul-threading-posix-concurrency--mutex)
    - [11.4 Modul `socket` & `requests` (High-Throughput Networking)](#114-modul-socket--requests-high-throughput-networking)
    - [11.5 Modul `screenGUI` & `GUIEngine` (X11 Zero-Copy SHM 60 FPS)](#115-modul-screengui--guiengine-x11-zero-copy-shm-60-fps)
    - [11.6 Modul `gpu` (VRAM Field Arrays, Morton Curves & Sub-microsecond Arena)](#116-modul-gpu-vram-field-arrays-morton-curves--sub-microsecond-arena)
12. [Bab 12: Toolchain, Package Manager `sundafetch` & CLI Manual](#bab-12-toolchain-package-manager-sundafetch--cli-manual)
    - [12.1 Driver Compiler `sundapy` (Flags & Commands)](#121-driver-compiler-sundapy-flags--commands)
    - [12.2 Package Manager Mandiri `sundafetch`](#122-package-manager-mandiri-sundafetch)
    - [12.3 Sistem Caching Wyhash / Artifact Reusability](#123-sistem-caching-wyhash--artifact-reusability)
13. [Bab 13: Integrasi Editor VS Code & Developer Experience](#bab-13-integrasi-editor-vs-code--developer-experience)
    - [13.1 Typing Stubs (`.pyi`) & Pylance Setup](#131-typing-stubs-pyi--pylance-setup)
    - [13.2 Koleksi Snippet Autocomplete](#132-koleksi-snippet-autocomplete)
    - [13.3 Shortcut Build Tasks (`Ctrl+Shift+B`)](#133-shortcut-build-tasks-ctrlshiftb)
14. [Bab 14: Katalog Kode Diagnostik Compiler (Error Index E0001 - E0010)](#bab-14-katalog-kode-diagnostik-compiler-error-index-e0001---e0010)
15. [Bab 15: The SundaPy Cookbook: 7 Proyek Praktis End-to-End](#bab-15-the-sundapy-cookbook-7-proyek-praktis-end-to-end)
    - [Proyek 1 (Pemula): Kalkulator Terminal & Analisis Teks](#proyek-1-pemula-kalkulator-terminal--analisis-teks)
    - [Proyek 2 (Menengah): Sistem Manajemen Inventaris Berorientasi Objek](#proyek-2-menengah-sistem-manajemen-inventaris-berorientasi-objek)
    - [Proyek 3 (Menengah): Concurrent Web Scraper dengan `requests`](#proyek-3-menengah-concurrent-web-scraper-dengan-requests)
    - [Proyek 4 (Lanjut): High-Performance Multithreaded TCP Server](#proyek-4-lanjut-high-performance-multithreaded-tcp-server)
    - [Proyek 5 (Lanjut): Kanvas Desktop 60 FPS Menggunakan X11 MIT-SHM](#proyek-5-lanjut-kanvas-desktop-60-fps-menggunakan-x11-mit-shm)
    - [Proyek 6 (Sistem): Rendering Game 2D Interaktif Raylib via Direct C](#proyek-6-sistem-rendering-game-2d-interaktif-raylib-via-direct-c)
    - [Proyek 7 (Sistem): Komputasi Kriptografi Vektor & Bitwise ALU dalam #strict](#proyek-7-sistem-komputasi-kriptografi-vektor--bitwise-alu-dalam-strict)
16. [Bab 16: Panduan Optimasi Performa Ekstrim, SIMD, & FAQ Komprehensif](#bab-16-panduan-optimasi-performa-ekstrim-simd--faq-komprehensif)

---

## Bab 1: Struktur Leksikal, Sintaksis & Aturan Indentasi

### 1.1 Anatomi Program & Titik Masuk
Program SundaPy ditulis dalam file teks berekstensi `.py`. Berbeda dengan bahasa turunan C yang mewajibkan fungsi pembungkus seperti `int main()`, SundaPy mengeksekusi instruksi tingkat atas (*top-level statements*) secara berurutan dari baris pertama. Namun, untuk aplikasi terstruktur atau modular, penggunaan pola idiomatis fungsi `main()` sangat dianjurkan:

```python
def main():
    print("Halo, Dunia dari SundaPy!")

main()
```

Setiap instruksi secara alami dipisahkan oleh karakter baris baru (*newline* `\n`). Anda juga dapat menuliskan beberapa instruksi pendek dalam satu baris dengan menggunakan karakter titik koma (`;`):
```python
x = 10; y = 20; print(x + y)
```

---

### 1.2 Aturan Emas Indentasi (The Golden Rule of Indentation)
SundaPy mengadopsi filosofi sintaksis Python di mana **blok kode ditentukan oleh tingkat indentasi visual**, bukan menggunakan tanda kurung kurawal `{}` seperti pada C, Rust, atau Java.

Prinsip dasar indentasi SundaPy:
1. **Header Blok Diawali Tanda Titik Dua (`:`):** Setiap pernyataan pengendali alur (`if`, `elif`, `else`, `for`, `while`, `def`, `class`, `try`, `except`, `finally`, `match`, `case`, `with`) wajib diakhiri dengan tanda titik dua `:`.
2. **Kenaikan Indentasi Memulai Blok Baru:** Baris berikutnya setelah tanda titik dua wajib memiliki indentasi yang lebih dalam.
3. **Standar 4 Spasi:** Komunitas SundaPy secara ketat menetapkan standar **4 spasi** untuk setiap tingkat hierarki blok.
4. **Penanganan Karakter Tab (`\t`):** Lexer SundaPy secara otomatis menghitung satu karakter tab sebagai ekuivalen 4 kolom spasi untuk menjaga kompatibilitas visual editor. Namun, mencampurkan spasi dan tab dalam baris atau blok yang sama dilarang keras dan akan memicu error kompilasi `E0008: IndentationTabSpaceMismatch`.

Contoh blok kode bersarang yang benar:
```python
def evaluasi_angka(nilai: int):
    # Tingkat indentasi 1 (4 spasi)
    if nilai > 0:
        # Tingkat indentasi 2 (8 spasi)
        print("Angka positif")
        if nilai % 2 == 0:
            # Tingkat indentasi 3 (12 spasi)
            print("Angka genap")
        else:
            print("Angka ganjil")
    else:
        print("Angka nol atau negatif")
```

---

### 1.3 Token Indent, Dedent, dan Pelacakan Stack Whitespace
Bagaimana compiler SundaPy memahami struktur blok tanpa kurung kurawal? Di balik layar, **Lexer SundaPy** menggunakan mekanisme pelacakan berbasis stack:

```text
Baris Kode                              Stack Indentasi        Token Virtual
-----------------------------------------------------------------------------
def proses():                           [0]                    def, proses, (, ), :
    x = 1                               [0, 4]                 Indent, x, =, 1, Newline
    if x > 0:                           [0, 4]                 if, x, >, 0, :
        print(x)                        [0, 4, 8]              Indent, print, (, x, ), Newline
    y = 2                               [0, 4]                 Dedent, y, =, 2, Newline
print("Selesai")                        [0]                    Dedent, print, (, ... ), Newline
```

1. **Inisialisasi Stack:** Lexer menginisialisasi stack indentasi dengan nilai dasar `[0]`.
2. **Token `Indent`:** Ketika baris non-kosong memiliki jumlah spasi awal lebih besar daripada nilai teratas pada stack, jumlah spasi baru tersebut didorong (*pushed*) ke stack dan token virtual `Indent` diemisikan ke Parser.
3. **Token `Dedent`:** Ketika baris baru memiliki jumlah spasi lebih kecil daripada nilai teratas pada stack, compiler mengeluarkan (*pops*) elemen stack hingga mencapai nilai yang cocok. Untuk setiap elemen yang dikeluarkan, token virtual `Dedent` diemisikan. Jika tidak ditemukan nilai yang persis cocok, compiler mendeteksi ketidakkonsistenan indentasi.
4. **Baris Kosong & Komentar:** Baris yang hanya berisi spasi atau komentar (`#`) sepenuhnya diabaikan dan tidak mempengaruhi stack indentasi.

---

### 1.4 Baris Lanjutan: Explicit (`\`) vs Implicit (`()`, `[]`, `{}`)
Ketika sebuah ekspresi matematika atau pernyataan kode terlalu panjang dan melebihi batas kolom layar (misalnya 80 atau 100 karakter), SundaPy menyediakan dua mekanisme pemecahan baris:

#### 1. Explicit Line Continuation (Karakter Backslash `\`)
Menempatkan karakter garis miring terbalik `\` di ujung baris menginstruksikan lexer untuk mengabaikan karakter baris baru berikutnya dan menyambungkan baris tersebut:
```python
total_biaya = harga_pokok + \
              biaya_pengiriman + \
              pajak_pertambahan_nilai - \
              diskon_promosi
```

#### 2. Implicit Line Continuation (Tanda Kurung Buka & Tutup)
Setiap ekspresi yang berada di dalam tanda kurung biasa `(...)`, tanda kurung siku `[...]`, atau tanda kurung kurawal `{...}` secara otomatis mendukung baris lanjutan implisit. Lexer meningkatkan penghitung `paren_level > 0`, sehingga karakter baris baru tidak akan menghasilkan token `Newline` ataupun memicu pemeriksaan indentasi:
```python
daftar_pengguna = [
    "Ahmad Dahlan",
    "Dewi Sartika",
    "Ki Hajar Dewantara",
    "Raden Ajeng Kartini"
]

hasil_perhitungan = (
    angka_pertama * faktor_pengali
    + angka_kedua * faktor_bobot
    - penyesuaian_konstanta
)
```

---

### 1.5 Komentar, Docstrings, dan Direktif Compiler (`#strict`, `#@link`)
SundaPy membagi anotasi teks non-eksekusi ke dalam tiga kategori:

#### 1. Komentar Satu Baris (`#`)
Dimulai dengan karakter tanda pagar `#`. Seluruh teks dari karakter tersebut hingga akhir baris diabaikan oleh compiler:
```python
# Ini adalah komentar penjelasan algoritma
kecepatan = 120 # Nilai dalam satuan km/jam
```

#### 2. Docstrings Multi-Baris (`"""` atau `'''`)
String literal multi-baris yang berdiri sendiri di awal file, kelas, atau fungsi diperlakukan sebagai dokumentasi (*docstring*). Teks ini dapat diakses untuk inspeksi dokumentasi:
```python
def hitung_akar_kuadrat(n: int) -> int:
    """Menghitung akar kuadrat integer menggunakan hardware bitwise intrinsics.
    
    Argumen:
        n (int): Bilangan bulat positif.
    Kembalian:
        int: Nilai floor(sqrt(n)).
    """
    return math.isqrt(n)
```

#### 3. Direktif Khusus Compiler & Linker
SundaPy menggunakan format komentar khusus sebagai instruksi pragma tingkat tinggi bagi compiler dan linker:
- `#strict`: Mengaktifkan mode tipe data statis ketat (*type invariance*) pada seluruh file atau badan fungsi. Menghilangkan boxing objek dan memaksimalkan performa CPU register. Wajib ditulis di baris pertama file atau baris pertama isi fungsi.
- `#@link: lib1, lib2`: Menginstruksikan LLVM backend untuk menautkan library biner sistem (misal `-lm`, `-lraylib`, `-lpthread`).

```python
#strict
#@link: m, raylib
import "math.h" as cmath
```

---

### 1.6 Aturan Penamaan Pengenal (Identifiers) & Case-Sensitivity
Pengenal (*identifier*) digunakan untuk menamai variabel, fungsi, kelas, modul, dan konstanta:
1. **Karakter Valid:** Huruf alfabet Latin (`a-z`, `A-Z`), karakter garis bawah (*underscore* `_`), dan angka (`0-9`).
2. **Tidak Boleh Diawali Angka:** `data1` valid, namun `1data` memicu error sintaksis.
3. **Peka Huruf Besar-Kecil (*Case-Sensitive*):** `variabel`, `Variabel`, dan `VARIABEL` adalah 3 entitas yang sepenuhnya berbeda di memori.
4. **Bukan Kata Kunci:** Nama pengenal tidak boleh menggunakan salah satu dari 38 kata kunci yang dilindungi (*reserved keywords*).
5. **Konvensi Standar SundaPy:**
   - Variabel dan Fungsi: `snake_case` (contoh: `hitung_total_harga`, `nama_lengkap`).
   - Kelas dan Struct: `PascalCase` (contoh: `ManajerSesi`, `Vector3D`).
   - Konstanta Immutabel: `SCREAMING_SNAKE_CASE` (contoh: `MAX_BUFFER_SIZE`, `DEFAULT_PORT`).

---

## Bab 2: Katalog Lengkap 38 Kata Kunci (The Exhaustive Keywords Catalog)

### 2.1 Tabel Ringkasan Kata Kunci SundaPy
SundaPy memiliki **38 kata kunci reserved** yang terdaftar di dalam `src/lexer/lexer_keyword.zig`:

| Kata Kunci | Kategori Fungsional | Deskripsi Singkat |
|---|---|---|
| `if` | Kontrol Aliran | Memulai percabangan logika berkondisi. |
| `elif` | Kontrol Aliran | Alternatif kondisi berikutnya jika kondisi sebelumnya `False`. |
| `else` | Kontrol Aliran | Blok default jika seluruh kondisi sebelumnya tidak terpenuhi. |
| `while` | Perulangan | Loop iterasi yang berjalan selama kondisi bernilai `True`. |
| `for` | Perulangan | Loop iterasi atas elemen koleksi, list, generator, atau range. |
| `in` | Keanggotaan & Loop | Menguji keanggotaan elemen atau memisahkan target dalam for loop. |
| `break` | Kontrol Loop | Menghentikan loop seketika dan melompat keluar. |
| `continue` | Kontrol Loop | Melewati sisa iterasi saat ini dan lanjut ke iterasi berikutnya. |
| `pass` | Placeholder | Pernyataan kosong (*no-op*) untuk memenuhi syarat blok indentasi. |
| `def` | Deklarasi Fungsi | Mendeklarasikan fungsi baru. |
| `return` | Aliran Fungsi | Mengembalikan nilai dari fungsi ke pemanggil dan keluar. |
| `lambda` | Fungsi Anonim | Membuat fungsi sebaris (*inline single-expression closure*). |
| `yield` | Generator | Menghasilkan nilai secara lazy dari fungsi generator. |
| `class` | Struktur Data & OOP | Mendeklarasikan kelas objek atau struktur data struct. |
| `import` | Modul & Header | Mengimpor pustaka internal, file C (`import "h"`), atau FFI. |
| `from` | Seleksi Modul | Mengimpor entitas atau fungsi tertentu dari suatu modul. |
| `as` | Aliasing | Memberikan nama alias pada modul atau tangkapan objek eksepsi. |
| `try` | Manajemen Eksepsi | Membuka blok pemantauan potensi kesalahan runtime. |
| `except` | Manajemen Eksepsi | Menangkap jenis kesalahan tertentu (mendukung tuple/multi-type PEP 758). |
| `finally` | Manajemen Eksepsi | Blok pembersihan yang dijamin selalu dieksekusi. |
| `raise` | Memicu Error | Memicu eksepsi kesalahan secara sengaja. |
| `with` | Resource Management | Mengelola siklus hidup resource secara aman (*RAII Context Manager*). |
| `assert` | Validasi Debug | Memvalidasi kebenaran asumsi logika selama pengujian/debug. |
| `match` | Pattern Matching | Membuka evaluasi pencocokan pola struktural modern. |
| `case` | Pattern Matching | Cabang pola nilai atau struktur di dalam blok `match`. |
| `async` | Concurrency | Mendeklarasikan fungsi asinkronus (*coroutine*). |
| `await` | Concurrency | Menunggu penyelesaian task/promise asinkronus secara non-blocking. |
| `global` | Scoping Variabel | Menandai variabel lokal agar merujuk ke scope tingkat modul global. |
| `nonlocal` | Scoping Variabel | Menandai variabel agar merujuk ke scope fungsi pembungkus terdekat. |
| `del` | Manajemen Memori | Menghapus binding variabel atau entri koleksi secara eksplisit. |
| `const` | Immutabilitas | Mendeklarasikan konstanta read-only stack/register yang tidak dapat diubah. |
| `True` | Literal Boolean | Nilai logika benar ($1$). |
| `False` | Literal Boolean | Nilai logika salah ($0$). |
| `None` | Sentinel Nilai | Representasi ketiadaan nilai atau pointer kosong (*nullable*). |
| `is` | Identitas Objek | Menguji apakah dua operan merujuk pada alamat memori fisik yang sama. |
| `not` | Logika Boolean | Pembalik nilai boolean (negasi/inversi logika). |
| `and` | Logika Boolean | Konjungsi logika boolean dengan evaluasi *short-circuit*. |
| `or` | Logika Boolean | Disjungsi logika boolean dengan evaluasi *short-circuit*. |

---

### 2.2 Percabangan & Logika: `if`, `elif`, `else`
Digunakan untuk mengarahkan alur komputasi berdasarkan evaluasi ekspresi kondisi:

```python
skor = 85

if skor >= 90:
    grade = "A"
elif skor >= 80:
    grade = "B"
elif skor >= 70:
    grade = "C"
else:
    grade = "D"

print("Grade:", grade) # Output: B
```

SundaPy juga mendukung ekspresi kondisional ternary inline:
```python
status = "Dewasa" if usia >= 18 else "Anak-anak"
```

---

### 2.3 Perulangan & Aliran: `while`, `for`, `in`, `break`, `continue`, `pass`

#### Loop `for ... in`
Mengiterasi deret angka atau elemen koleksi:
```python
for i in range(5):
    print("Iterasi ke-", i)

buah = ["Apel", "Mangga", "Pisang"]
for item in buah:
    print("Buah:", item)
```

#### Loop `while`
Mengulang blok instruksi selama kondisi evaluasi bernilai `True`:
```python
antrian = 3
while antrian > 0:
    print("Memproses antrian...", antrian)
    antrian -= 1
```

#### Pengendali Loop: `break`, `continue`, `pass`
- `break`: Menghentikan seluruh proses perulangan seketika.
- `continue`: Melewati baris-baris berikutnya dalam iterasi saat ini dan langsung meloncat ke evaluasi siklus berikutnya.
- `pass`: Placeholder tidak melakukan operasi apa pun (*no-op*), sangat berguna saat merancang kerangka awal fungsi atau kelas.

```python
for angka in range(10):
    if angka == 2:
        continue # Lewati angka 2
    if angka == 7:
        break    # Hentikan loop di angka 7
    print(angka)

def fungsi_akan_datang():
    pass # Kerangka belum diimplementasikan
```

---

### 2.4 Fungsi & Generator: `def`, `return`, `lambda`, `yield`

#### `def` dan `return`
Mendeklarasikan unit kode yang dapat digunakan kembali:
```python
def kalikan(a: int, b: int) -> int:
    return a * b

hasil = kalikan(6, 7)
print("Hasil kali:", hasil) # 42
```

#### `lambda`
Fungsi anonim ekspresi tunggal yang ringkas untuk operasi pemetaan atau penyortiran:
```python
kuadrat = lambda x: x * x
print("Kuadrat 9:", kuadrat(9)) # 81
```

#### `yield`
Mengubah fungsi biasa menjadi sebuah generator yang menghasilkan deret data secara malas (*lazy evaluation*) tanpa membebani memori RAM:
```python
def deret_genap(batas: int):
    n = 0
    while n <= batas:
        yield n
        n += 2

for val in deret_genap(6):
    print("Genap:", val) # 0, 2, 4, 6
```

---

### 2.5 Pemrograman Kelas: `class`
Kata kunci `class` digunakan untuk mendefinisikan tipe objek kustom, enkapsulasi data atribut, dan fungsionalitas method:

```python
class Pengguna:
    def __init__(self, nama: str, peran: str):
        self.nama = nama
        self.peran = peran

    def sapa(self) -> str:
        return f"Halo, saya {self.nama} ({self.peran})"

u = Pengguna("Budi", "DevOps")
print(u.sapa())
```

---

### 2.6 Sistem Modul & Impor: `import`, `from`, `as`
Digunakan untuk mengorganisir kode ke dalam berbagai file, pustaka bawaan, maupun pustaka eksternal:

```python
# 1. Impor modul penuh
import math
print("Akar 64:", math.isqrt(64))

# 2. Impor fungsi spesifik dengan 'from'
from time import sleep, time_ns
waktu_awal = time_ns()

# 3. Memberikan nama alias dengan 'as'
import screenGUI as gui
import "math.h" as cmath # Direct C Header Import
```

---

### 2.7 Penanganan Eksepsi: `try`, `except`, `finally`, `raise`
SundaPy mengelola kegagalan runtime secara aman dan terstruktur:

```python
def bagi_angka(pembilang: float, penyebut: float) -> float:
    if penyebut == 0.0:
        raise ValueError("Penyebut tidak boleh bernilai nol!")
    return pembilang / penyebut

try:
    hasil = bagi_angka(10.0, 0.0)
except ValueError, ZeroDivisionError as err: # PEP 758: Tanpa tanda kurung
    print("Tertangkap error perhitungan:", err)
finally:
    print("Pembersihan resource selesai.")
```

---

### 2.8 Context Manager & Asersi: `with`, `assert`

#### `with` (Resource Acquisition Is Initialization / RAII)
Menjamin pembersihan atau pelepasan kunci (*lock*) secara otomatis bahkan jika terjadi error di tengah blok:
```python
import threading

kunci = threading.Lock()
with kunci:
    # Bagian kritis terlindungi dari data race
    print("Operasi thread-safe aman berjalan di sini")
```

#### `assert`
Memvalidasi asumsi kebenaran program saat pengujian:
```python
def hitung_diskon(harga: float, diskon: float) -> float:
    assert 0.0 <= diskon <= 1.0, "Persentase diskon harus antara 0.0 dan 1.0!"
    return harga * (1.0 - diskon)
```

---

### 2.9 Pattern Matching: `match`, `case`
SundaPy mengompilasi structural pattern matching menjadi evaluasi percabangan kilat:

```python
def rute_perintah(cmd: str):
    match cmd:
        case "mulai":
            print("Server dinyalakan...")
        case "berhenti":
            print("Server dimatikan...")
        case "restart" | "muat_ulang":
            print("Me-restart layanan server...")
        case _:
            print("Perintah tidak dikenali:", cmd)
```

---

### 2.10 Asinkronus: `async`, `await`
Menyediakan sintaks coroutine native untuk pemrosesan I/O asinkronus tanpa blocking:

```python
async def unduh_halaman(url: str):
    print("Mengunduh:", url)
    # Simulasi task asinkronus
    return "Konten halaman"

async def main():
    hasil = await unduh_halaman("https://example.com")
    print("Hasil unduhan:", hasil)
```

---

### 2.11 Cakupan Variabel & Memori: `global`, `nonlocal`, `del`, `const`

#### `global` dan `nonlocal`
- `global`: Menginstruksikan fungsi agar mengubah variabel yang dideklarasikan di tingkat paling atas modul (*module-level scope*).
- `nonlocal`: Menginstruksikan fungsi bersarang (*closure*) agar memodifikasi variabel pada fungsi pembungkus induknya.

```python
penghitung_global = 0

def tingkatkan():
    global penghitung_global
    penghitung_global += 1

def induk():
    skor = 10
    def anak():
        nonlocal skor
        skor += 5
    anak()
    print("Skor induk:", skor) # 15
```

#### `del`
Menghapus binding variabel dari scope atau membuang elemen dari dalam koleksi:
```python
data = [10, 20, 30, 40]
del data[1] # Menghapus angka 20
print(data) # [10, 30, 40]
```

#### `const` (SundaPy Static Feature)
Mendeklarasikan konstanta murni yang disimpan langsung di register atau stack frame, dan dilarang dimutasi kembali oleh compiler:
```python
const KECEPATAN_CAHAYA: i64 = 299792458
const PI_APPROX: f64 = 3.1415926535
```

---

### 2.12 Nilai Literal & Logika Bawaan: `True`, `False`, `None`, `is`, `and`, `or`, `not`
- `True` dan `False`: Nilai kebenaran logika boolean (1 byte).
- `None`: Nilai sentinel ketiadaan objek (diterjemahkan ke optional pointer Zig `?T`).
- `is`: Memeriksa kesamaan identitas pointer alamat memori fisik (berbeda dengan `==` yang memeriksa kesamaan nilai konten).
- `not`, `and`, `or`: Operator logika dengan evaluasi *short-circuit* (jika operan kiri `and` bernilai `False`, sisi kanan tidak akan dieksekusi).

```python
a = [1, 2, 3]
b = [1, 2, 3]
c = a

print(a == b) # True  (konten sama)
print(a is b) # False (alamat memori heap berbeda)
print(a is c) # True  (merujuk pada objek fisik yang persis sama)
```

---

## Bab 3: Operator Lengkap & Hirarki Presedensi

### 3.1 Operator Aritmatika & Matematika
| Simbol | Nama Operator | Contoh | Penjelasan Teknis |
|---|---|---|---|
| `+` | Penjumlahan | `a + b` | Menjumlahkan dua angka atau menggabungkan dua string/list. |
| `-` | Pengurangan | `a - b` | Mengurangkan operan kanan dari operan kiri. |
| `*` | Perkalian | `a * b` | Mengalikan dua angka atau menduplikasi deret string/list. |
| `/` | Pembagian Floating | `a / b` | Pembagian matematis menghasilkan pecahan `f64`. |
| `//` | Pembagian Bulat | `a // b` | Pembagian bulat (*floor division*), memotong pecahan ke bawah. |
| `%` | Modulo | `a % b` | Menghitung sisa hasil bagi integer. |
| `**` | Pemangkatan | `a ** b` | Menghitung $a$ pangkat $b$ ($a^b$). |

### 3.2 Operator Relasional & Perbandingan
| Simbol | Nama Operator | Contoh | Evaluasi Kebenaran |
|---|---|---|---|
| `==` | Sama Dengan | `a == b` | `True` jika nilai konten kedua operan identik. |
| `!=` | Tidak Sama Dengan | `a != b` | `True` jika nilai kedua operan tidak sama. |
| `<` | Kurang Dari | `a < b` | `True` jika $a$ secara numerik lebih kecil dari $b$. |
| `<=` | Kurang Dari / Sama | `a <= b` | `True` jika $a \le b$. |
| `>` | Lebih Dari | `a > b` | `True` jika $a > b$. |
| `>=` | Lebih Dari / Sama | `a >= b` | `True` jika $a \ge b$. |

### 3.3 Operator Logika Boolean
- `not x`: Bernilai `True` jika $x$ bernilai `False` atau ekuivalen falsy (`0`, `None`, `""`).
- `a and b`: Mengembalikan $b$ jika $a$ truthy; jika $a$ falsy, langsung mengembalikan $a$ (*short-circuit*).
- `a or b`: Mengembalikan $a$ jika $a$ truthy; jika $a$ falsy, mengembalikan $b$ (*short-circuit*).

### 3.4 Operator Bitwise Perangkat Keras
Berjalan langsung di atas register Arithmetic Logic Unit (ALU) prosesor:
| Simbol | Operasi Bitwise | Contoh | Operasi Biner Mesin |
|---|---|---|---|
| `&` | Bitwise AND | `a & b` | Bit bernilai 1 hanya jika kedua bit terkait bernilai 1. |
| `\|` | Bitwise OR | `a \| b` | Bit bernilai 1 jika salah satu atau kedua bit bernilai 1. |
| `^` | Bitwise XOR | `a ^ b` | Bit bernilai 1 jika tepat satu bit bernilai 1 (eksklusif). |
| `~` | Bitwise NOT | `~a` | Membalik seluruh bit (inversi komplemen dua). |
| `<<` | Shift Kiri | `a << n` | Menggeser bit ke kiri sebanyak $n$ posisi (mengalikan $2^n$). |
| `>>` | Shift Kanan | `a >> n` | Menggeser bit ke kanan sebanyak $n$ posisi (membagi $2^n$). |

### 3.5 Operator Penugasan & Walrus (`:=`)
Selain penugasan standar (`=`) dan augmented assignment (`+=`, `-=`, `*=`, `/=`, `%=`, `&=`, `|=`, `^=`, `<<=`, `>>=`), SundaPy mendukung **Walrus Operator (`:=`)**:
Operator ini memungkinkan penugasan nilai ke variabel di dalam sebuah ekspresi evaluasi:

```python
# Membaca buffer data sekaligus menguji kondisi berhenti
while (chunk := baca_paket_jaringan()) != "":
    proses_data(chunk)
```

### 3.6 Operator Modern SundaPy: None-Coalescing (`??`) & Safe Navigation (`?.`)
SundaPy mengeliminasi boilerplate pengecekan `if x is not None`:

#### Operator None-Coalescing (`??`)
Mengembalikan operan kanan jika operan kiri bernilai `None`:
```python
nama_profil = input_nama ?? "Pengguna Tamu"
timeout_detik = konfigurasi_klien?.timeout ?? 30
```

#### Operator Safe Navigation (`?.`)
Mencegah crash eksepsi `AttributeError` bila objek induk bernilai `None`:
```python
# Jika 'user' atau 'alamat' bernilai None, hasil evaluasi langsung 'None'
kode_pos = user?.alamat?.kode_pos
print("Kode Pos:", kode_pos ?? "Tidak Tersedia")
```

### 3.7 Tabel Presedensi Operator Lengkap
Urutan evaluasi operasi dari prioritas tertinggi ke terendah:

| Prioritas | Kategori Operator | Simbol / Sintaksis |
|---|---|---|
| 1 (Tertinggi) | Akses Anggota & Call | `()`, `[]`, `.`, `?.` |
| 2 | Pemangkatan | `**` |
| 3 | Unary Bitwise & Tanda | `+x`, `-x`, `~x` |
| 4 | Perkalian & Pembagian | `*`, `/`, `//`, `%` |
| 5 | Penjumlahan & Pengurangan | `+`, `-` |
| 6 | Pergeseran Bitwise | `<<`, `>>` |
| 7 | Bitwise AND | `&` |
| 8 | Bitwise XOR | `^` |
| 9 | Bitwise OR | `\|` |
| 10 | Perbandingan & Keanggotaan | `==`, `!=`, `<`, `<=`, `>`, `>=`, `is`, `in` |
| 11 | Logika NOT | `not` |
| 12 | Logika AND | `and` |
| 13 | Logika OR | `or` |
| 14 | None-Coalescing | `??` |
| 15 (Terendah)| Penugasan & Walrus | `=`, `+=`, `-=`, `:=`, dll. |

---

## Bab 4: Sistem Tipe Data & Paradigma Ganda (Dynamic vs Strict)

SundaPy menghadirkan fleksibilitas tanpa kompromi dengan mendukung dua paradigma pengetikan data yang berdampingan secara harmonis: **Dynamic Mode** untuk prototyping ekspresif berkecepatan tinggi, dan **Strict Mode (`#strict`)** untuk rekayasa sistem berkinerja mutlak setara C dan Zig.

---

### 4.1 Dynamic Mode: Prototyping Fleksibel & Duck Typing
Secara bawaan (*default*), tanpa direktif `#strict`, SundaPy beroperasi dalam Dynamic Mode. Variabel tidak memerlukan deklarasi tipe eksplisit dan dapat menampung nilai dengan tipe yang berubah-ubah sepanjang siklus hidup program:

```python
data = 42                 # Integer
print("Tipe integer :", data)

data = "Empat Puluh Dua"  # Berubah menjadi String
print("Tipe string  :", data)

data = [10, 20, 30]       # Berubah menjadi List
print("Tipe list    :", data)
```

#### Kapan Menggunakan Dynamic Mode?
- Pembuatan prototipe awal (*rapid prototyping*) dan eksplorasi ide.
- Penulisan skrip otomasi sistem, parsing konfigurasi JSON, atau manipulasi file teks.
- Interaksi awal dengan dependensi Python dinamis sebelum dioptimalkan ke mode ketat.

---

### 4.2 Strict Mode (`#strict`): Type Invariance & Kecepatan Native
Ketika performa puncak menjadi prioritas utama (misalnya pemrosesan data real-time, grafik, komputasi sains, game engine, atau backend transaksi), aktifkan **Strict Mode** dengan menambahkan komentar `#strict` di baris pertama file:

```python
#strict

def hitung_energi_kinetik(massa: f64, kecepatan: f64) -> f64:
    energi: f64 = 0.5 * massa * (kecepatan * kecepatan)
    return energi

print("Energi:", hitung_energi_kinetik(80.0, 15.0), "Joule")
```

#### Aturan Ketat Mode `#strict`:
1. **Type Invariance (Kekekalan Tipe):** Sebuah variabel tidak dapat diubah tipenya setelah dideklarasikan.
2. **Wajib Beranotasi Tipe Saat Deklarasi:** Setiap variabel lokal baru wajib memiliki tipe statis eksplisit (`variabel: tipe = nilai`). Variabel tanpa tipe akan memicu compiler diagnostic `E0001: StrictModeUnannotatedVariable`.
3. **Pemetaan Register Mesin Langsung:** Variabel statis tidak dibungkus (*unboxed*) ke struktur tagged union; melainkan dialokasikan langsung pada register CPU fisik atau stack frame C.
4. **Nol Overhead Dynamic Dispatch:** Seluruh pemanggilan fungsi dan kalkulasi numerik di-resolve secara Ahead-Of-Time (AOT), memungkinkan LLVM melakukan auto-vectorization SIMD dan inlining agresif.

---

### 4.3 Tipe Primitif Hardware ALU: `i8`..`i64`, `u8`..`u64`, `f32`, `f64`, `bool`, `str`
Dalam mode `#strict`, SundaPy membuka akses penuh ke seluruh tipe register perangkat keras modern:

| Tipe Data | Representasi Hardware | Ukuran | Rentang Nilai | Contoh Pemakaian |
|---|---|---|---|---|
| `i8` | Signed 8-bit Integer | 1 Byte | $-128$ s.d. $127$ | Audio DSP sampling, intensitas sinyal |
| `u8` | Unsigned 8-bit (Byte) | 1 Byte | $0$ s.d. $255$ | Buffer biner, channel warna RGB |
| `i16` | Signed 16-bit Integer | 2 Bytes | $-32,768$ s.d. $32,767$ | Format sensor ADC/DAC, audio PCM 16-bit |
| `u16` | Unsigned 16-bit Integer | 2 Bytes | $0$ s.d. $65,535$ | Port jaringan TCP/UDP, indeks grafis 16-bit |
| `i32` | Signed 32-bit Integer | 4 Bytes | $-2 \times 10^9$ s.d. $2 \times 10^9$ | Koordinat visual desktop, kalkulasi loop umum |
| `u32` | Unsigned 32-bit Integer | 4 Bytes | $0$ s.d. $4.29 \times 10^9$ | Pixel RGBA 32-bit, checksum CRC32 |
| `i64` | Signed 64-bit (Default int)| 8 Bytes | $-9.22 \times 10^{18}$ s.d. $9.22 \times 10^{18}$ | Timestamp nanodetik, pointer address offset |
| `u64` | Unsigned 64-bit Integer | 8 Bytes | $0$ s.d. $1.84 \times 10^{19}$ | Hashing kriptografi 64-bit, ukuran kapasitas |
| `f32` | Single Precision Float | 4 Bytes | IEEE 754 float (7 digit presisi) | Vertex 3D shader GPU, neural network weights |
| `f64` | Double Precision Float | 8 Bytes | IEEE 754 double (15-17 digit presisi) | Simulasi astrofisika, kalkulasi finansial |
| `bool` | Flag Logika Boolean | 1 Byte | `True` ($1$) atau `False` ($0$) | Status pengkondisian alur program |
| `str` | Slice String Immutabel | 16 Bytes | Struct: Pointer 64-bit + Panjang 64-bit | String UTF-8 tanpa overhead alokasi |

---

### 4.4 Tata Letak Memori Tagged Union `Dynamic` 24-Byte
Bagaimana Dynamic Mode menyimpan berbagai macam tipe data ke dalam satu variabel?
SundaPy merepresentasikan setiap objek dinamis menggunakan **Tagged Union 24-Byte**:

```text
        +---------------------------------------------------------------+
        |             Tata Letak Memori Objek Dynamic (24 Byte)         |
        +---------------------------------------------------------------+
        | Offset (Byte) | Ukuran (Byte) | Deskripsi Isi                 |
        +---------------+---------------+-------------------------------+
        |   0           | 1             | DynamicTag Discriminator Enum |
        |   1 - 7       | 7             | Memory Alignment Padding      |
        |   8 - 23      | 16            | Payload Data Union            |
        +---------------------------------------------------------------+
```

Struktur representasi internal pada kode sumber Zig:
```zig
pub const DynamicTag = enum(u8) {
    none,       // Nilai None
    boolean,    // Nilai bool
    integer,    // Nilai i64
    float,      // Nilai f64
    string,     // String slice: pointer + len
    list,       // Pointer ke header List
    dict,       // Pointer ke header Dictionary
    object,     // Pointer ke header Instansi Objek
    ffi_obj,    // Pointer ke handle Native FFI
};
```
Ketika dieksekusi, CPU memeriksa byte diskriminator pada offset 0 untuk menentukan rute percabangan instruksi mesin (*dispatch jump*), lalu membaca payload 16 byte pada offset 8.

---

### 4.5 Koleksi Bawaan: `list`, `dict`, `set`, `tuple`, Sentinel `None`

#### 1. List (`list`)
Koleksi terurut dinamis berbasis array kontigu di memori.
- Pertumbuhan kapasitas eksponensial ($1.5\times$) mengeliminasi overhead realokasi memori berulang.
- Operasi umum: `append(item)`, `pop()`, `insert(index, item)`, `len(list)`.

```python
angka = [10, 20, 30]
angka.append(40)
print("Panjang list:", len(angka)) # 4
print("Elemen ke-2 :", angka[1])    # 20
```

#### 2. Kamus (`dict`)
Koleksi pasangan kunci-nilai berkecepatan tinggi berbasis **Robin Hood Open Addressing Hash Table**:
- Lookup amortized berkecepatan $O(1)$.
- Menggunakan benih *Wyhash* yang tahan terhadap serangan DoS Hash-Flooding.

```python
harga_buah = {
    "mangga": 15000,
    "jeruk": 20000,
    "pisang": 12000
}
harga_buah["apel"] = 25000
print("Harga jeruk:", harga_buah["jeruk"])
```

#### 3. Nilai Sentinel `None`
Nilai ketiadaan nilai `None` diimplementasikan secara efisien tanpa alokasi heap pointer terpisah. Pada level biner, nilai ini dipetakan ke representasi optional type `?T` milik Zig, di mana nilai null hanya diwakili oleh bit flag atau pointer beralamat $0$ (`0x0`).

---

## Bab 5: Fitur Sintaksis Modern & Implementasi PEP Mutakhir

SundaPy berada di garis terdepan adopsi sintaksis Python dengan mengimplementasikan proposal peningkatan Python (PEP) modern langsung di tingkat parser dan compiler:

### 5.1 PEP 822: Compile-Time Dedented Strings (`d"..."`)
String multi-baris sering kali merusak visual keterbacaan kode karena harus diletakkan menempel ke margin kiri file:
```python
def get_query() -> str:
    # PEP 822: Indentasi umum dibersihkan saat kompilasi (Zero Runtime Overhead)
    return d"""
        SELECT users.id, users.nama, pesanan.total
        FROM users
        JOIN pesanan ON pesanan.user_id = users.id
        WHERE users.aktif = 1
        ORDER BY pesanan.tanggal DESC
    """
```
Compiler menghitung spasi minimum di depan baris (*common leading whitespace*) saat tokenisasi dan menyimpannya langsung dalam keadaan bersih di segmen data read-only biner (`.rodata`). Tidak ada pemanggilan fungsi string strip saat runtime.

---

### 5.2 PEP 750: Template Strings (`t"..."`)
SundaPy mengadopsi proposal **PEP 750 (Template Strings)** dengan awalan literal `t"`:
```python
user_input = "Admin' OR '1'='1"
query_template = t"SELECT * FROM accounts WHERE username = {user_input}"
```
Berbeda dengan f-string konvensional yang langsung menggabungkan string mentah, template string menghasilkan token terurai (*template literal components*) yang memungkinkan sanitasi keamanan otomatis terhadap kerentanan SQL Injection atau Cross-Site Scripting (XSS).

---

### 5.3 PEP 758: Multiple Exceptions Tanpa Tanda Kurung
Penangkapan beberapa jenis exception kini dapat ditulis secara ringkas dan deklaratif:
```python
try:
    nilai = 100 / int(teks_input)
except ValueError, ZeroDivisionError as err:
    print("Gagal mengonversi atau membagi angka:", err)
```

---

### 5.4 Structural Pattern Matching Tingkat Lanjut
SundaPy mengompilasi blok `match ... case` menjadi jump table LLVM:
```python
def evaluasi_paket(paket: list):
    match paket:
        case [0, 0]:
            print("Titik pusat koordinat (Origin)")
        case [x, 0]:
            print("Titik pada sumbu horizontal X:", x)
        case [0, y]:
            print("Titik pada sumbu vertikal Y:", y)
        case [x, y]:
            print(f"Titik 2D koordinat ({x}, {y})")
        case _:
            print("Paket koordinat tidak valid")
```

---

### 5.5 Idiom Looping: `enumerate()`, `zip()`, Multi-Dimensional Replications
SundaPy mengenali idiom looping umum dan menurunkannya ke instruksi register counter berkecepatan tinggi:

#### 1. Idiom `enumerate()`
```python
nama_hari = ["Senin", "Selasa", "Rabu"]
for idx, hari in enumerate(nama_hari):
    print(f"Hari ke-{idx + 1}: {hari}")
```

#### 2. Idiom `zip()`
Mengiterasi beberapa koleksi secara simultan:
```python
nama = ["Budi", "Siti", "Agus"]
nilai = [90, 85, 95]
for n, s in zip(nama, nilai):
    print(f"{n} memperoleh nilai: {s}")
```

#### 3. Multi-Dimensional Array Replication
SundaPy mengoptimalkan idiom list comprehension pembuatan matriks multi-dimensi (2D, 3D, hingga 5D) menjadi alokasi blok memori kontigu murni:
```python
# Matriks 2D (Tinggi 3, Lebar 4)
matriks_2d = [[0] * 4 for _ in range(3)]
matriks_2d[0][0] = 42
matriks_2d[1][0] = 10 # Mandiri, baris tidak saling mereferensi
```

---

## Bab 6: Pemrograman Berorientasi Objek (OOP) & Inheritance

SundaPy menyediakan model Object-Oriented Programming (OOP) yang bersih, mendukung single inheritance, pemanggilan konstruktor induk via `super()`, dan *method overriding* statis.

### 6.1 Deklarasi Kelas, Atribut, dan Konstruktor `__init__`
```python
#strict

class Titik:
    x: f64
    y: f64

    def __init__(self, x: f64, y: f64):
        self.x = x
        self.y = y

    def jarak_ke_pusat(self) -> f64:
        return (self.x * self.x + self.y * self.y) ** 0.5

p = Titik(3.0, 4.0)
print("Jarak:", p.jarak_ke_pusat()) # 5.0
```

---

### 6.2 Pewarisan Tunggal (Single Inheritance) & Resolusi `super()`
Kelas turunan mewarisi seluruh atribut dan method dari kelas induk:

```python
#strict

class Karyawan:
    nama: str
    gaji_pokok: f64

    def __init__(self, nama: str, gaji_pokok: f64):
        self.nama = nama
        self.gaji_pokok = gaji_pokok

    def hitung_total_gaji(self) -> f64:
        return self.gaji_pokok

class Manajer(Karyawan):
    tunjangan: f64

    def __init__(self, nama: str, gaji_pokok: f64, tunjangan: f64):
        super().__init__(nama, gaji_pokok) # Delegasi ke konstruktor Karyawan
        self.tunjangan = tunjangan

    def hitung_total_gaji(self) -> f64:
        # Method overriding
        return self.gaji_pokok + self.tunjangan

m = Manajer("Dewi", 15000000.0, 5000000.0)
print("Nama       :", m.nama)
print("Total Gaji :", m.hitung_total_gaji())
```

---

### 6.3 Method Overriding & Dispatch Statis
Dalam mode `#strict`, method overriding di-resolve oleh compiler menggunakan vtable minimalis berkecepatan tinggi atau inlined static dispatch jika tipe instansi diketahui pasti saat kompilasi. Ini menghilangkan overhead dynamic method lookup yang biasa terjadi pada CPython.

---

## Bab 7: Arsitektur Eksekusi & Concurrency Bebas GIL

### 7.1 Pipeline Kompilasi AOT ke Native ELF Executable
SundaPy tidak menggunakan interpreter atau bytecode virtual machine. Seluruh pipeline bersifat statis Ahead-Of-Time (AOT):
1. **Lexer & Parser:** Menghasilkan AST kaya tipe dari kode Python.
2. **Escape Analysis:** Mengklasifikasikan variabel apakah dialokasikan di CPU Stack atau Thread-Local Arena.
3. **Zig Code Emitter:** Meng-emit source code Zig optimal ke `.cache/src/`.
4. **LLVM Compiler Backend:** Mengompilasi kode Zig menjadi file biner mesin mandiri (*standalone ELF executable*) dengan optimasi ReleaseFast (O3).
5. **Eksekusi Langsung:** Menghasilkan latensi start-up instan (0.5 ms) tanpa runtime initialization overhead.

---

### 7.2 Concurrency Zero-GIL di Atas POSIX Kernel Threads
Pada CPython tradisional, Global Interpreter Lock (GIL) mengunci seluruh eksekusi bytecode ke dalam satu core fisik tunggal:

```text
CPython (GIL-Locked):
Core 1: [ Thread 1 ] ===GIL===> [ Thread 2 ] ===GIL===> [ Thread 3 ]
Core 2: (IDLE / Menunggu GIL)
Core 3: (IDLE / Menunggu GIL)
Core 4: (IDLE / Menunggu GIL)

SundaPy (Zero-GIL Native Multi-Core):
Core 1: [ Thread 1 POSIX (Kernel Native) ] -> 100% CPU Penuh
Core 2: [ Thread 2 POSIX (Kernel Native) ] -> 100% CPU Penuh
Core 3: [ Thread 3 POSIX (Kernel Native) ] -> 100% CPU Penuh
Core 4: [ Thread 4 POSIX (Kernel Native) ] -> 100% CPU Penuh
```

Di SundaPy:
- Pemanggilan `threading.Thread(target=...)` secara langsung memicu pembuatan thread kernel POSIX nyata (`pthread_create` di Linux).
- Tidak ada lock interpreter global. Setiap thread memiliki stack register dan context alokasi mandiri.
- Algoritma komputasi CPU-bound (hashing, simulasi fisika, raytracing) diskalakan secara linear di seluruh core prosesor.

---

### 7.3 Sinkronisasi & Penghindaran Data Race (`threading.Lock`)
Karena thread berjalan secara paralel murni antar core, akses ke variabel global yang dibagi (*shared state*) wajib disinkronkan untuk mencegah *data race*:

```python
import threading

kunci_akses = threading.Lock()
saldo_rekening = 1000000

def proses_penarikan(jumlah: int):
    global saldo_rekening
    with kunci_akses:
        # Critical Section terlindungi secara thread-safe
        if saldo_rekening >= jumlah:
            saldo_rekening -= jumlah
            print("Penarikan sukses. Sisa saldo:", saldo_rekening)

t1 = threading.Thread(target=proses_penarikan, args=(300000,))
t2 = threading.Thread(target=proses_penarikan, args=(500000,))

t1.start()
t2.start()

t1.join()
t2.join()
```

---

## Bab 8: Model Keamanan Memori Tanpa Garbage Collector

SundaPy membuang siklus *cyclic tracing Garbage Collector* yang sering memicu jeda henti (*latency spike*) tak terduga, dan menggantikannya dengan pendekatan hibrida deterministik:

### 8.1 Two-Pass Escape Analysis
Saat kompilasi berlangsung, transpiler menjalankan dua fase analisis pelolosan:
- **Pass 1 (Lifetime Scope Analysis):** Melacak apakah referensi sebuah variabel lokal pernah dikembalikan (*returned*) atau disimpan ke struktur data global yang hidup lebih lama dari fungsi pemanggil.
- **Pass 2 (Target Allocation Assignment):** Menetapkan strategi alokasi memori fisik. Variabel yang *tidak meloloskan diri* diarahkan ke CPU Stack Frame, sedangkan variabel dinamis yang *meloloskan diri* diarahkan ke Thread-Local Arena Allocator.

---

### 8.2 Alokasi Stack Frame (Zero Cost & Auto Clean)
Variabel bertipe primitif (`i8`..`i64`, `f32`, `f64`, `bool`), struct lokal berukuran tetap, dan array sementara ditempatkan langsung di CPU Stack:
- Alokasi hanya berupa instruksi tunggal pergeseran Stack Pointer (`sub rsp, bytes`).
- Saat fungsi kembali (*return*), stack pointer digeser kembali secara instan (`add rsp, bytes`).
- Biaya alokasi dan dealokasi adalah **nol siklus CPU tambahan (Zero-Cost)**.

---

### 8.3 Thread-Local Arena Allocator (Zero Fragmentation & Bulk Free)
Untuk data dengan ukuran dinamis yang bertumbuh:
- Memori dialokasikan secara linier pada halaman arena penyangga thread lokal.
- Tidak ada pencarian daftar blok bebas (*free list traversal*) yang memicu fragmentasi memori RAM.
- Ketika sebuah siklus task atau fungsi pembungkus selesai, seluruh halaman arena dikembalikan ke OS dalam satu operasi pelepasan massal (*bulk deallocation*). Ini memberikan performa latensi deterministik yang stabil bagi aplikasi real-time.

---

## Bab 9: Direct C Interoperability & Linker Directives

SundaPy memanfaatkan arsitektur Zig compiler yang mampu mem-parsing kode C secara native untuk mengintegrasikan header dan library C tanpa perlu menulis wrapper C-Extension manual:

### 9.1 Direct C Header Import (`@cImport`)
Sintaks impor menggunakan path bertanda kutip:
```python
#@link: m
import "math.h" as cmath

nilai_sin = cmath.sin(1.5707963)
nilai_cos = cmath.cos(0.0)

print("sin(pi/2) =", nilai_sin) # 1.0
print("cos(0)    =", nilai_cos) # 1.0
```

---

### 9.2 Direktif Linker Sistem (`#@link`)
Ketika mengimpor header C sistem atau pihak ketiga, berikan instruksi penautan pustaka biner menggunakan format `#@link:` di bagian atas file:
```python
# Menautkan pustaka matematika (-lm) dan Raylib (-lraylib)
#@link: raylib, m
```
Compiler SundaPy akan mengekstrak direktif ini dan meneruskannya ke flag linker LLVM saat biner dibangun.

---

### 9.3 Interaksi Header C Lokal & Struktur Data Eksternal
Anda dapat menyertakan file header C buatan Anda sendiri di direktori proyek:

```c
// File: my_driver.h
#ifndef MY_DRIVER_H
#define MY_DRIVER_H

typedef struct {
    int id;
    float suhu;
} SensorData;

static inline float konversi_fahrenheit(float celsius) {
    return (celsius * 9.0f / 5.0f) + 32.0f;
}

#endif
```

Dapat langsung dipanggil dari skrip SundaPy:
```python
import "my_driver.h" as sensor

f_suhu = sensor.konversi_fahrenheit(37.0)
print("Suhu tubuh (F):", f_suhu)
```

---

## Bab 10: Sub-Sistem Foreign Function Interface (FFI) Dinamis

SundaPy memisahkan interaksi biner menjadi dua kebutuhan:
1. **Direct C Import:** Digunakan waktu kompilasi saat file header `.h` tersedia.
2. **Sub-Sistem FFI (`import ffi`):** Digunakan waktu runtime untuk memuat file pustaka dinamis (*shared library* `.so`, `.dll`, `.dylib`) tanpa memerlukan file header C. Bekerja mulus dengan shared library yang ditulis dalam bahasa apa pun (Rust, Go, C++, Zig, C).

### 10.1 High-Level FFI: Dynamic Library Loading & C-Structs
Menyediakan antarmuka tingkat tinggi yang aman dengan validasi tipe data:

```python
import ffi

# 1. Muat shared library dinamis
lib = ffi.load("libmatematika_native.so")

# 2. Binding fungsi dengan signature tipe yang eksplisit
# lib.bind(nama_simbol: str, tipe_kembalian, [tipe_parameter...])
tambah_angka = lib.bind("tambah_i32", ffi.i32, [ffi.i32, ffi.i32])
hasil = tambah_angka(40, 60)
print("Hasil tambah FFI:", hasil) # 100

# 3. Definisikan Layout Memori C-Struct
# ffi.create_struct(nama: str, [(nama_field, tipe_field)...])
Point3D = ffi.create_struct("Point3D", [
    ("x", ffi.f64),
    ("y", ffi.f64),
    ("z", ffi.f64)
])

# 4. Instansiasi dan manipulasi memori native struct
p = Point3D(10.0, 20.0, 30.0)
print("Ukuran struct dalam byte:", ffi.sizeof(Point3D))
print("Alamat memori struct    :", ffi.addressof(p))

p.z = 99.5
print("Nilai p.z setelah update:", p.z)

lib.close()
```

---

### 10.2 Low-Level FFI: Pointer Mentah, libc Direct Alloc/Free & Raw Dispatch
Untuk kebutuhan kontrol memori mutlak, manipulasi hardware driver, atau komunikasi antarmuka biner tingkat rendah:

```python
import ffi

# 1. Buka shared library libc sistem
libc = ffi.open("libc.so.6")

# 2. Ambil alamat pointer simbol fungsi via dlsym
simbol_puts = libc.get_symbol("puts")

# 3. Alokasikan null-terminated C-string di memori native
teks_c = ffi.c_str("Halo dari Low-Level SundaPy FFI!")

# 4. Eksekusi fungsi langsung melalui alamat memorinya
libc.call_raw(simbol_puts, teks_c)

# 5. Alokasi buffer memori mentah berukuran 256 byte
buffer_raw = ffi.alloc(256)
print("Buffer beralamat di:", buffer_raw)

# 6. Bebaskan buffer kembali ke kernel
ffi.free(buffer_raw)

libc.close()
```

---

## Bab 11: Spesifikasi Modul Pustaka Standar (`sundapy_std`)

### 11.1 Modul `math` (FPU Math & Hardware Integer Intrinsics PEP 619)
Modul `math` mengintegrasikan kalkulasi FPU standar dan fungsi matematika integer perangkat keras:

#### Fungsi Integer Hardware Intrinsics (PEP 619)
- `math.isqrt(n: int) -> int`: Menghitung akar kuadrat integer terpotong ke bawah (`floor(sqrt(n))`) melalui manipulasi pergeseran bit CPU biner murni tanpa menyentuh register pecahan FPU.
- `math.gcd(a: int, b: int) -> int`: Menghitung Faktor Persekutuan Terbesar (*Greatest Common Divisor*) menggunakan algoritma biner Stein dengan instruksi mesin CTZ (*Count Trailing Zeros*).
- `math.lcm(a: int, b: int) -> int`: Kelipatan Persekutuan Terkecil (*Least Common Multiple*).
- `math.comb(n: int, k: int) -> int`: Koefisien kombinasi binomial matematis $C(n, k)$.
- `math.factorial(n: int) -> int`: Faktorial $n!$ menggunakan akumulasi integer cepat.

#### Fungsi Trigonometri & Pangkat FPU
- `math.sin(x)`, `math.cos(x)`, `math.tan(x)`: Trigonometri radian.
- `math.asin(x)`, `math.acos(x)`, `math.atan(x)`, `math.atan2(y, x)`: Invers trigonometri.
- `math.sqrt(x)`, `math.pow(x, y)`, `math.exp(x)`, `math.log(x)`, `math.log2(x)`, `math.log10(x)`.
- `math.floor(x)`, `math.ceil(x)`, `math.trunc(x)`, `math.round(x)`, `math.fabs(x)`.
- `math.isnan(x)`, `math.isinf(x)`, `math.isfinite(x)`.
- **Konstanta Matematis:** `math.pi` ($\pi \approx 3.14159265$), `math.e` ($e \approx 2.71828182$), `math.tau` ($\tau \approx 6.28318530$).

```python
import math

print("isqrt(10000)  =", math.isqrt(10000))  # 100
print("gcd(108, 48)  =", math.gcd(108, 48))   # 12
print("lcm(14, 21)   =", math.lcm(14, 21))   # 42
print("comb(8, 3)    =", math.comb(8, 3))    # 56
print("factorial(6)  =", math.factorial(6))  # 720
```

---

### 11.2 Modul `time` (Nanosecond Clock & Non-Busy Sleep)
- `time.time() -> float`: Mengembalikan waktu detik saat ini (presisi desimal float).
- `time.time_ns() -> int`: Mengembalikan timestamp monotonic nanodetik dari register siklus CPU. Ideal untuk micro-benchmarking akurat.
- `time.sleep(detik: float) -> None`: Menidurkan eksekusi thread menggunakan syscall `nanosleep` kernel Linux tanpa membuang siklus komputasi (*non-busy waiting*).

```python
import time

mulai_ns = time.time_ns()
time.sleep(0.05) # Tidur 50 milidetik
selesai_ns = time.time_ns()
print("Waktu tidur nyata:", (selesai_ns - mulai_ns) / 1000000.0, "ms")
```

---

### 11.3 Modul `threading` (POSIX Concurrency & Mutex)
- `threading.Thread(target=fn, args=(a, b))`: Menginisialisasi thread kernel POSIX independen.
- `t.start()`: Memulai eksekusi paralel murni di core prosesor yang tersedia.
- `t.join()`: Menunggu hingga thread menyelesaikan tugasnya.
- `threading.Lock()`: Mutex pengaman sinkronisasi memori bersama (*shared memory*).

```python
import threading

kunci = threading.Lock()

def tugas_paralel(id_thread: int):
    with kunci:
        print(f"Thread #{id_thread} sedang berjalan di core CPU native!")

threads = [threading.Thread(target=tugas_paralel, args=(i,)) for i in range(4)]
for t in threads: t.start()
for t in threads: t.join()
```

---

### 11.4 Modul `socket` & `requests` (High-Throughput Networking)
- **`socket`:** Interface socket jaringan POSIX non-blocking (`socket.socket`, `AF_INET`, `SOCK_STREAM`, `SOCK_DGRAM`, `bind`, `listen`, `accept`, `send`, `recv`, `close`).
- **`requests`:** REST HTTP Client bawaan mandiri:
  - `requests.get(url, headers=None) -> Response`
  - `requests.post(url, data=None, json=None, headers=None) -> Response`
  - Objek `Response`: `status_code: int`, `text: str`, `json() -> dynamic`.

```python
import requests

res = requests.get("https://httpbin.org/get")
print("Status:", res.status_code)
print("Respon:", res.text)
```

---

### 11.5 Modul `screenGUI` & `GUIEngine` (X11 Zero-Copy SHM 60 FPS)
Engine rendering antarmuka visual desktop berkinerja 60 FPS:
- **X11 MIT-SHM Zero-Copy:** Mengalokasikan frame buffer RGBA langsung pada shared memory Linux (`shmget`/`shmat`). Server X11 membaca layar langsung tanpa penyalinan socket IPC.
- **Renderer Simetris:** `win.clear(r, g, b)`, `win.draw_rect(x, y, w, h, r, g, b)`, `win.draw_circle(cx, cy, radius, r, g, b)`, `win.draw_text(x, y, teks, r, g, b)`.

---

### 11.6 Modul `gpu` (VRAM Field Arrays, Morton Curves & Sub-microsecond Arena)
Dirancang untuk komputasi tensor, simulasi fisika, dan grafika GPU modern:
- **`gpu.field`:** Array multidimensi yang ditempatkan secara langsung pada memori VRAM GPU.
- **Morton Z-Order Space-Filling Curves:** Mengonversi koordinat spasial 2D/3D menjadi alamat memori linier untuk memaksimalkan efisiensi *texture cache locality* GPU.
- **Sub-Microsecond VRAM Arena:** Sistem alokasi buffer temporer instan tanpa syscall context-switch driver kernel yang mahal.

---

## Bab 12: Toolchain, Package Manager `sundafetch` & CLI Manual

### 12.1 Driver Compiler `sundapy` (Flags & Commands)
Sintaks dasar CLI driver:
```bash
sundapy [OPSI] [SUB_COMMAND] <script.py> [ARGUMEN_PROGRAM...]
```

#### Tabel Opsi Flag Lengkap:
| Flag / Opsi | Deskripsi Fungsionalitas |
|---|---|
| `-h`, `--help` | Menampilkan panduan bantuan dan sintaks CLI. |
| `--build` | Mengompilasi script menjadi biner mandiri (*standalone executable*) tanpa menjalankannya. |
| `--outname <nama>` | Menentukan nama biner ELF keluaran (otomatis mengaktifkan `--build`). |
| `--fast`, `-O3` | Mengaktifkan optimasi performa LLVM `ReleaseFast` untuk benchmark dan produksi. |
| `--debug` | Mengompilasi dalam mode `ReleaseSafe` dengan simbol debug dan bounds checking aktif. |
| `-y` | Mengabaikan cache hash dan memaksa kompilasi ulang penuh dari awal. |
| `--no-panic` | Menonaktifkan penulisan trace backtrace saat terjadi fatal crash. |
| `init` | Menyiapkan scaffold proyek baru, typings `.pyi`, dan konfigurasi VS Code. |
| `fetch <pkg>` | Mengunduh package PyPI ke dalam sandbox `.cache/pyLibrary/`. |

---

### 12.2 Package Manager Mandiri `sundafetch`
`sundafetch` adalah package manager zero-dependency yang ditulis dalam Zig murni:
```bash
# Mengunduh package tunggal
sundafetch requests

# Mengunduh dependensi dari requirements.txt
sundafetch -r requirements.txt
```
- **Isolasi Ketat:** Package selalu diisolasi ke dalam `.cache/pyLibrary/`, menjaga environment sistem operasi tetap bersih.
- **Resolusi Smart Wheel:** Mengunduh binary wheel kompatibel (`cp314`, `abi3`, `manylinux2014_x86_64`).

---

### 12.3 Sistem Caching Wyhash / Artifact Reusability
Compiler SundaPy menghitung sidik jari Wyhash dari kode sumber, parameter mode kompilasi, dan direktif link. Jika hash identik ditemukan di `.cache/bin/`, kompilasi dilewati dan biner langsung dieksekusi dengan latensi start-up **0.5 s.d. 1.2 milidetik**.

---

## Bab 13: Integrasi Editor VS Code & Developer Experience

### 13.1 Typing Stubs (`.pyi`) & Pylance Setup
Ketika Anda menjalankan perintah `sundapy init`, folder `.vscode/typings/` otomatis dibuat dengan stubs definisi tipe:
- `__builtins__.pyi`: Mendefinisikan tipe hardware (`i8`..`i64`, `u8`..`u64`, `f32`, `f64`, operator `??`, `?.`).
- `math.pyi`: Seluruh signature matematika FPU dan integer hardware intrinsics.
- `ffi.pyi`: Definisi lengkap struct builder, library loader, dan fungsi manipulasi pointer.
- `screenGUI.pyi` & `GUIEngine.pyi`: Definisi canvas dan windowing X11.
- `gpu.pyi`: Definisi field array VRAM dan GPU arena memory.

File `.vscode/settings.json` menyambungkan stubs ini ke IntelliSense Pylance:
```json
{
  "python.analysis.extraPaths": [
    "${workspaceFolder}/.vscode/typings",
    "${workspaceFolder}/.cache/pyLibrary"
  ],
  "python.analysis.typeCheckingMode": "basic"
}
```

---

### 13.2 Koleksi Snippet Autocomplete
SundaPy menyertakan snippet cepat di `.vscode/sundapy.code-snippets`:
- `sunda-strict`: Kerangka komputasi performa tinggi `#strict`.
- `sunda-c-import`: Kerangka Direct C Header Import (`#@link` & `import "header.h"`).
- `sunda-ffi-high`: Kerangka High-Level FFI Dynamic Binding & C-Struct.
- `sunda-ffi-low`: Kerangka Low-Level FFI raw pointers dan manipulasi memori.
- `sunda-inherit`: Kerangka class inheritance dengan `super().__init__()`.
- `sunda-gui`: Kerangka visual desktop canvas 60 FPS.

---

### 13.3 Shortcut Build Tasks (`Ctrl+Shift+B`)
File `.vscode/tasks.json` menyediakan pintasan build satu tombol:
- `Ctrl+Shift+B` $\rightarrow$ Menjalankan file aktif dengan compiler `sundapy`.
- Opsi task kedua $\rightarrow$ Mengompilasi file menjadi biner standalone dengan flag `--fast`.

---

## Bab 14: Katalog Kode Diagnostik Compiler (Error Index E0001 - E0010)

### `E0001: StrictModeUnannotatedVariable`
- **Penyebab:** Pada file dengan `#strict`, terdapat variabel yang dideklarasikan tanpa anotasi tipe statis.
- **Kode Salah:** `x = 100`
- **Solusi:** `x: i64 = 100`

### `E0002: TypeMismatchAssignment`
- **Penyebab:** Menetapkan nilai bertipe lain ke variabel dengan tipe statis invariant.
- **Kode Salah:** `umur: i32 = 25; umur = "Dua Puluh Lima"`
- **Solusi:** Gunakan tipe data yang konsisten atau konversi eksplisit.

### `E0003: UnlinkedExternalSymbol`
- **Penyebab:** Mengimpor header C tetapi lupa menautkan shared library biner ke linker.
- **Kode Salah:** `import "raylib.h" as rl` (undefined symbol: `InitWindow`)
- **Solusi:** Tambahkan `#@link: raylib, m` di baris pertama file.

### `E0004: DirectCHeaderNotFound`
- **Penyebab:** File header C yang ditentukan pada `import "nama.h"` tidak ditemukan di sistem include path maupun folder lokal.
- **Solusi:** Pastikan path dan ejaan file `.h` benar.

### `E0005: InvalidFFISignature`
- **Penyebab:** Menyediakan tipe data non-FFI saat memanggil `lib.bind()`.
- **Solusi:** Gunakan konstanta tipe dari modul `ffi` (`ffi.i32`, `ffi.f64`, `ffi.ptr`, dll.).

### `E0006: IncompatibleParentMethodOverride`
- **Penyebab:** Subclass meng-override method milik kelas induk dengan jumlah parameter atau tipe argumen yang tidak cocok.
- **Solusi:** Samakan signature method turunan agar sesuai dengan kontrak method kelas induk.

### `E0007: VRAMAllocationExhausted`
- **Penyebab:** Alokasi `gpu.field` atau `gpu.arena_alloc` meminta ukuran memori yang melampaui kapasitas fisik VRAM GPU.
- **Solusi:** Kurangi resolusi dimensi array atau bebaskan buffer yang tidak terpakai.

### `E0008: IndentationTabSpaceMismatch`
- **Penyebab:** Pencampuran karakter tab (`\t`) dan spasi dalam blok indentasi yang sama.
- **Solusi:** Gunakan 4 spasi secara konsisten di seluruh kode.

### `E0009: NullDerefOnNonOptional`
- **Penyebab:** Akses atribut atau pemanggilan method pada objek yang berpotensi bernilai `None` tanpa pengamanan.
- **Solusi:** Gunakan safe navigation `?.` atau none-coalescing `??`.

### `E0010: UnsupportedDynamicInPureStrict`
- **Penyebab:** Penggunaan duck typing dinamis (seperti penambahan atribut objek sembarang di luar deklarasi kelas) di dalam mode `#strict`.
- **Solusi:** Deklarasikan seluruh atribut kelas di badan kelas secara eksplisit.

---

## Bab 15: The SundaPy Cookbook: 7 Proyek Praktis End-to-End

Koleksi proyek praktis nyata ini dirancang untuk memandu Anda menguasai SundaPy dari tingkat pemula hingga rekayasa sistem tingkat tinggi:

### Proyek 1 (Pemula): Kalkulator Terminal & Analisis Teks
Proyek ramah pemula yang menggabungkan input pengguna, percabangan logika, list, dan pemrosesan string sederhana:

```python
def jalankan_kalkulator():
    print("=== KALKULATOR STATISTIK SUNDAPY ===")
    angka_list = [12, 45, 67, 23, 89, 34, 56, 78, 90]
    
    total = 0
    maksimal = angka_list[0]
    minimal = angka_list[0]
    
    for val in angka_list:
        total += val
        if val > maksimal:
            maksimal = val
        if val < minimal:
            minimal = val
            
    rata_rata = total / len(angka_list)
    
    print("Daftar Angka :", angka_list)
    print("Total Jumlah :", total)
    print("Rata-rata    :", rata_rata)
    print("Nilai Maks   :", maksimal)
    print("Nilai Min    :", minimal)

jalankan_kalkulator()
```

---

### Proyek 2 (Menengah): Sistem Manajemen Inventaris Berorientasi Objek
Menerapkan pemrograman berorientasi objek (OOP), enkapsulasi class, dan pelacakan dictionary:

```python
class Barang:
    def __init__(self, kode: str, nama: str, harga: float, stok: int):
        self.kode = kode
        self.nama = nama
        self.harga = harga
        self.stok = stok

    def tambah_stok(self, jumlah: int):
        self.stok += jumlah

    def kurangi_stok(self, jumlah: int) -> bool:
        if self.stok >= jumlah:
            self.stok -= jumlah
            return True
        return False

    def info(self) -> str:
        return f"[{self.kode}] {self.nama} - Rp{self.harga:,.0f} (Stok: {self.stok})"

class Toko:
    def __init__(self, nama: str):
        self.nama = nama
        self.inventaris = {}

    def daftarkan_barang(self, barang: Barang):
        self.inventaris[barang.kode] = barang

    def cetak_katalog(self):
        print(f"\n--- KATALOG TOKO: {self.nama} ---")
        for kode, b in self.inventaris.items():
            print(b.info())

toko = Toko("Sunda Mart Modern")
b1 = Barang("BRG01", "Kopi Robusta 250g", 35000.0, 50)
b2 = Barang("BRG02", "Teh Hitam Organik", 22000.0, 30)

toko.daftarkan_barang(b1)
toko.daftarkan_barang(b2)
toko.cetak_katalog()

b1.kurangi_stok(5)
print("\nSetelah pembelian 5 bungkus kopi:")
print(b1.info())
```

---

### Proyek 3 (Menengah): Concurrent Web Scraper dengan `requests`
Mengambil data HTTP dari beberapa endpoint secara paralel murni tanpa terhambat GIL:

```python
import threading
import requests

daftar_url = [
    "https://httpbin.org/get?worker=1",
    "https://httpbin.org/get?worker=2",
    "https://httpbin.org/get?worker=3",
    "https://httpbin.org/get?worker=4"
]

def pekerja_pengunduh(url: str, id_pekerja: int):
    print(f"[Worker #{id_pekerja}] Memulai request ke {url}...")
    respon = requests.get(url)
    print(f"[Worker #{id_pekerja}] Selesai! Status HTTP: {respon.status_code}")

def main():
    threads = []
    for idx, link in enumerate(daftar_url):
        t = threading.Thread(target=pekerja_pengunduh, args=(link, idx + 1))
        threads.append(t)
        t.start()

    for t in threads:
        t.join()

    print("Semua data berhasil diambil secara konkuren multi-core!")

main()
```

---

### Proyek 4 (Lanjut): High-Performance Multithreaded TCP Server
Membangun server backend jaringan dengan arsitektur non-blocking:

```python
#strict
import socket
import threading

def layani_koneksi(klien_socket: socket.socket, alamat: str):
    print("Klien terhubung:", alamat)
    while True:
        data: str = klien_socket.recv(1024)
        if len(data) == 0:
            break
        # Echo data kembali
        klien_socket.send(data)
    klien_socket.close()
    print("Klien putus:", alamat)

def main():
    server: socket.socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.bind("0.0.0.0", 9090)
    server.listen(128)
    print("TCP Server aktif di port 9090 (Bebas GIL)...")

    while True:
        klien_sock, klien_addr = server.accept()
        t = threading.Thread(target=layani_koneksi, args=(klien_sock, klien_addr))
        t.start()

main()
```

---

### Proyek 5 (Lanjut): Kanvas Desktop 60 FPS Menggunakan X11 MIT-SHM
Aplikasi grafis interaktif dengan manipulasi shared-memory langsung ke X Server:

```python
import screenGUI
import time

def main():
    layar = screenGUI.Window(800, 600, "SundaPy MIT-SHM Desktop App")
    x = 100
    arah = 4

    while layar.is_open():
        layar.poll_events()

        x += arah
        if x > 740 or x < 60:
            arah = -arah

        layar.clear(0x11, 0x11, 0x1B) # Warna gelap elegan
        layar.draw_rect(50, 50, 700, 6, 0x45, 0x47, 0x5A)
        layar.draw_circle(x, 300, 28, 0x89, 0xB4, 0xFA) # Bola biru terang
        layar.draw_text(20, 20, "SundaPy 60 FPS Native Graphics", 0xCD, 0xD6, 0xF4)

        layar.present()
        time.sleep(0.016) # Target 60 Frame Per Detik

main()
```

---

### Proyek 6 (Sistem): Rendering Game 2D Interaktif Raylib via Direct C
Menggunakan `#@link: raylib, m` dan header C Raylib untuk membuat game 2D interaktif:

```python
#@link: raylib, m
import "raylib.h" as rl

def main():
    rl.InitWindow(800, 450, "SundaPy Direct C Raylib Game")
    rl.SetTargetFPS(60)

    pos_x: f32 = 400.0
    pos_y: f32 = 225.0

    while not rl.WindowShouldClose():
        # Kontrol arah panah keyboard
        if rl.IsKeyDown(rl.KEY_RIGHT): pos_x += 4.5
        if rl.IsKeyDown(rl.KEY_LEFT):  pos_x -= 4.5
        if rl.IsKeyDown(rl.KEY_UP):    pos_y -= 4.5
        if rl.IsKeyDown(rl.KEY_DOWN):  pos_y += 4.5

        # Render frame
        rl.BeginDrawing()
        rl.ClearBackground(rl.RAYWHITE)
        rl.DrawText("Gunakan Tombol Panah untuk Menggerakkan Karakter", 15, 15, 20, rl.DARKGRAY)
        rl.DrawCircle(int(pos_x), int(pos_y), 24.0, rl.MAROON)
        rl.EndDrawing()

    rl.CloseWindow()

main()
```

---

### Proyek 7 (Sistem): Komputasi Kriptografi Vektor & Bitwise ALU dalam `#strict`
Pipeline benchmark pemrosesan integer berkecepatan 10 juta iterasi pada register CPU murni:

```python
#strict
import math
import time

def jalankan_pipeline_kriptografi(total_iterasi: i32) -> u64:
    hash_akumulator: u64 = 0xCBF29CE484222325
    bilangan_prima: u64 = 0x100000001B3
    i: i32 = 1

    while i <= total_iterasi:
        akar_int: i32 = math.isqrt(i)
        gcd_val: i32 = math.gcd(i, 42)

        # Operasi bitwise shift dan XOR
        hash_akumulator ^= (u64(akar_int) << 8) | u64(gcd_val)
        hash_akumulator *= bilangan_prima
        i += 1

    return hash_akumulator

def main():
    print("Memulai komputasi intensif 10.000.000 iterasi dalam mode #strict...")
    t_awal: i64 = time.time_ns()
    hasil_hash: u64 = jalankan_pipeline_kriptografi(10000000)
    t_akhir: i64 = time.time_ns()

    durasi_ms: f64 = f64(t_akhir - t_awal) / 1000000.0
    print("Komputasi tuntas!")
    print("Hasil Checksum Final:", hasil_hash)
    print("Waktu Eksekusi Total:", durasi_ms, "ms")

main()
```

---

## Bab 16: Panduan Optimasi Performa Ekstrim, SIMD, & FAQ Komprehensif

### 5 Aturan Emas Optimasi Performa SundaPy
1. **Gunakan `#strict` pada Fungsi Komputasi Intensif:** Menghilangkan overhead tagged union dan mempromosikan variabel langsung ke CPU register.
2. **Pilih Ukuran Integer yang Presisi:** Gunakan `i32` untuk koordinat visual atau grafik dan `i64` untuk komputasi timestamp atau akumulator besar.
3. **Manfaatkan Hardware Intrinsics:** Selalu gunakan `math.isqrt`, `math.gcd`, `math.lcm` alih-alih algoritma iterasi manual di Python.
4. **Kompilasi Produksi dengan Flag `--fast` (`-O3`):**
   ```bash
   sundapy --fast --build server_app.py
   ```
   Flag ini mengaktifkan LLVM SIMD Auto-Vectorization, loop unrolling, dan menghilangkan runtime bounds checking yang tidak perlu.
5. **Manfaatkan Multithreading Multi-Core:** Pecah pekerjaan CPU-bound ke banyak thread via `threading.Thread` untuk memanfaatkan 100% inti prosesor tanpa hambatan GIL.

---

### FAQ (Pertanyaan yang Sering Diajukan)

- **Q: Apakah SundaPy membutuhkan runtime Python yang terpasang di sistem operasi?**  
  *A: Tidak sama sekali. Biner keluaran SundaPy adalah file executable ELF Linux mandiri (*standalone*) yang dapat didistribusikan ke server tanpa instalasi Python atau CPython.*

- **Q: Mengapa multithreading di SundaPy jauh lebih cepat daripada CPython?**  
  *A: Karena SundaPy tidak memiliki Global Interpreter Lock (GIL). Setiap thread berjalan di atas thread kernel POSIX nyata secara independen di setiap inti prosesor.*

- **Q: Kapan saya harus menggunakan Dynamic Mode dan kapan harus menggunakan `#strict`?**  
  *A: Gunakan Dynamic Mode untuk scripting cepat, otomasi, dan prototyping. Gunakan mode `#strict` saat Anda membangun algoritma matematika berat, game engine, server berkinerja tinggi, atau berinteraksi langsung dengan C FFI.*

- **Q: Apakah saya bisa mengimpor library binary C atau Rust saya sendiri?**  
  *A: Sangat bisa. Anda dapat mengimpornya langsung via Direct C Import (`import "my_lib.h"`) atau memuat file shared library `.so` via modul `ffi`.*

- **Q: Bagaimana cara mendistribusikan aplikasi SundaPy ke server produksi?**  
  *A: Cukup kompilasi dengan `sundapy --fast --build --outname my_service main.py`, lalu salin file biner biner `my_service` ke server Anda.*

---
*Buku panduan ini merupakan properti teknis resmi proyek SundaPy. Seluruh hak cipta arsitektur dilindungi.*

