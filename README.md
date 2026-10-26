# Apa itu SundaPy?

**SundaPy** adalah Ahead-Of-Time (AOT) Python-to-Zig transpiler, LLVM native compiler, dan standalone runtime berkinerja tinggi. SundaPy mentranspilasi kode sumber Python langsung menjadi kode sumber Zig native, yang kemudian dikompilasi oleh LLVM menjadi biner executable mandiri (*bare-metal ELF binary* di Linux) dengan waktu startup sekejap (< 2 ms) dan nol runtime dependency eksternal.

Proyek ini dirancang agar developer dapat mengeksekusi kode Python dengan performa mesin native setara bahasa C/Zig tanpa terhambat oleh overhead CPython Virtual Machine dan GIL.

---

## Pilar Utama SundaPy

1. **Zero Python VM Overhead**:
   Tidak ada bytecode loop atau PVM. AST Python diturunkan langsung ke kode native Zig dan menghasilkan biner ELF ringkas (< 500 KB) dengan eksekusi bare-metal.
2. **True Multi-Core Concurrency & Zero GIL**:
   Global Interpreter Lock (GIL) dieliminasi total. Thread Python (`import threading` atau `_thread`) memetakan langsung ke kernel thread OS (`std.Thread`) sehingga komputasi paralel dapat memanfaatkan 100% core CPU secara linier.
3. **Seamless Python Ecosystem Compatibility (C-ABI Bridge)**:
   Mendukung ekosistem package Python melalui C-ABI bridge dinamis (`libpython3.*.so`). Library binary wheel (NumPy, PyTorch, SciPy, bs4, dsb.) dapat dijalankan berdampingan dengan mode Pure Native.
4. **Strong Static Typing Opsional (`#strict`)**:
   Menulis `#strict` di baris pertama file mengaktifkan pengetikan statis kuat. Tipe data hardware primitif (`i8`..`i1024`, `u8`..`u1024`, `f32`, `f64`, `bool`) dipetakan 1:1 ke register CPU dan stack tanpa boxing overhead.
5. **Subsistem Mandiri Tanpa Ketergantungan Eksternal**:
   - **`screenGUI` & `GUIEngine`**: Desktop GUI native 100% pure Zig yang berkomunikasi langsung via wire-protocol soket domain Linux X11 tanpa Xlib, XCB, GTK, atau Qt.
   - **`gpu` Computing Engine**: Compute GPU langsung berbasis driver syscalls (CUDA / Vulkan / OpenCL) dengan graph launch sub-1.5 µs.
   - **`sundafetch`**: Zero-dependency package manager terisolasi berbasis pure Zig HTTP dan internal ZIP/Deflate decompressor.

---

## Fitur Sintaks Python Modern yang Didukung

SundaPy mendukung berbagai fitur sintaks modern Python 3.8–3.13:

* **Extended Iterable Unpacking (PEP 3132)**: Starred target di assignment (`a, *b, c = seq`, `*head, tail = seq`, `min_w, max_w, *_ = seq`).
* **Nested Comprehensions & Multi-Clause Filters (PEP 202, PEP 289)**: Multi-loop `[x for row in matrix for x in row]` dan filter bertingkat `[x for x in seq if c1 if c2]`.
* **Pernyataan Hapus (`del`)**: Deallokasi dan penghapusan variabel, dict item (`del d[key]`), list index (`del arr[0]`), atribut objek (`del obj.attr`), dan tuple sekuensial (`del a, b, c`).
* **Penanganan Error Lengkap (`try / except / else / finally`)**: Multi-tipe exception `except (ValueError, TypeError) as e:`, multi-klausa `except`, blok `else:` bebas exception, dan blok cleanup `finally:`.
* **Augmented In-Place Assignments Lengkap**: Operator bitwise (`&=`, `|=`, `^=`, `<<=`, `>>=`), pembagian bulat (`//=`), dan eksponen (`**=`) pada variabel, atribut, maupun subscript (`dict[k] &= mask`).
* **Multiple Return & Yield**: Mengembalikan atau me-yield tuple koma tanpa tanda kurung (`return a, b, c`, `yield x, y`).
* **Subgenerator Delegation (`yield from` PEP 380)**: Delegasi generator langsung ke subgenerator.
* **Anotasi Tipe Berdiri Sendiri (PEP 526)**: Deklarasi tipe variabel/field tanpa nilai awal (`title: str`, `count: int`).
* **Parameter Positional-Only (PEP 570)**: Sintaks garis miring (`def fn(a, b, /, c):`).
* **Chained Assignment**: Penugasan ganda berantai (`a = b = c = 42`, `obj.x = obj.y = "val"`).
* **Target Kompleks Unpacking**: Unpacking langsung ke atribut dan subscript (`opts.mark, sub_dict["k"], _ = parse()`).
* **Built-in `getattr` & Dot Utilities**: `getattr(obj, name, default)`, relative import (`from . import mod`, `from ..parent import sub`), Ellipsis (`...`), dan float literal titik (`.5`).
* **Pattern Matching (`match / case`)**: Pencocokan pola struktural.
* **String Dedent (PEP 822 `d"..."`) & Template String (PEP 750 `t"..."`)**.

---

## Package Manager: `sundafetch`

`sundafetch` adalah package manager mandiri bawaan yang mengunduh dan mengekstrak package wheel Python secara terisolasi ke dalam `.cache/pyLibrary/`:

```bash
# Mengunduh package PyPI
sundafetch numpy requests beautifulsoup4

# Mengunduh dari requirements.txt
sundafetch -r requirements.txt

# Mengunduh dan langsung mengompilasi package menjadi biner mandiri:
sundafetch --build yt-dlp -o yt-dlp-bin

# Mengompilasi direktori proyek lokal:
sundafetch --build ./path/to/repo -o my-cli
```

---

## Dokumentasi & Referensi Lengkap

* **[SUNDAPY_GUIDE.md](file:///home/encu/myCode/zigCode/pythonZigZag/SUNDAPY_GUIDE.md)**: Panduan lengkap developer, cheatsheet tipe data hardware, kamus API built-in, dan matriks keputusan modul.
* **[AGENTS.md](file:///home/encu/myCode/zigCode/pythonZigZag/AGENTS.md)**: Manual arsitektur lengkap dan spesifikasi integrasi AI agent untuk seluruh codebase compiler SundaPy.
* **[tests_sundapy/](file:///home/encu/myCode/zigCode/pythonZigZag/tests_sundapy/)**: Kumpulan 170+ file test otomatis untuk seluruh fitur dan idiom. Jalankan dengan `./run_tests.sh`.

---

### DO WITH YOUR OWN RISK

**Keseluruhan project ini dibangun dengan menggunakan bantuan Gemini 3.1 Pro High + Agy-cli + Ponytail skill. Selain memudahkan proses pengembangan, hal ini juga karena saya sendiri penggagas projek ini merasa masih skill issue terutama untuk low-level programming seperti memory management, interaksi dengan OS / Kernel, dan keterbatasan knowledge tentang algoritma pemrograman. Perlu diingat kembali projek ini adalah pure hobi dan eksperimen saja, kalau merasa ada yang terbantu dengan projek ini saya sangat bersyukur dan jangan lupa menautkan sumber :V.**
