"""
SundaPy Core Builtin Types, Keywords, Directives, and Functions Specification.
Mendefinisikan tipe primitif hardware native, direktif kompilasi, kata kunci bahasa,
dan seluruh fungsi & tipe global bawaan SundaPy untuk VSCode IntelliSense dan Hover Tooltips.
"""

from typing import (
    Any,
    Callable,
    Generic,
    Iterable,
    Iterator,
    NoReturn,
    Optional,
    Sequence,
    Sized,
    TypeVar,
    Union,
    overload,
)

T = TypeVar("T")
KT = TypeVar("KT")
VT = TypeVar("VT")

# ==============================================================================
# 1. DIREKTIF KOMPILER SUNDAPY (COMPILER DIRECTIVES)
# ==============================================================================

class _StrictDirective:
    """
    ### Direktif Kompiler SundaPy: `#strict`
    
    Tulis `#strict` pada **baris paling pertama** berkas `.py` untuk mengaktifkan
    **Mode Kompilasi Hardware Native Penuh**.

    ---
    **Karakteristik `#strict`:**
    * **Zero Heap Boxing:** Tipe numerik dialokasikan di register CPU dan stack native.
    * **Static Typing Wajib:** Semua parameter fungsi dan nilai balik wajib bertipe eksplisit:
      ```python
      #strict
      def tambah(a: i64, b: i64) -> i64:
          return a + b
      ```
    * **Kecepatan Setara C/Zig:** Melewati overhead dynamic dispatch CPython, mencapai latensi sub-mikrodetik.
    * **Runtime Safety:** Compiler menyisipkan perlindungan memori aman (`@setRuntimeSafety(true)`).
    """
    pass

class _LinkDirective:
    """
    ### Direktif Linker SundaPy: `#@link: <libraries>` (atau `#link:`)
    
    Tulis `#@link: nama_lib1, nama_lib2` untuk memberi tahu linker compiler agar menautkan
    biner executable ke pustaka C dinamis (`.so`) atau statis sistem.

    ---
    **Contoh Penggunaan:**
    ```python
    #strict
    #@link: raylib, m
    import raylib
    ```
    Bekerja secara native dengan fitur **Direct C Header Import** (`@cImport`).
    """
    pass

strict: _StrictDirective = _StrictDirective()
link: _LinkDirective = _LinkDirective()

# ==============================================================================
# 2. TIPE DATA PRIMITIF PERANGKAT KERAS (HARDWARE NATIVE TYPES)
# ==============================================================================

class i8(int):
    """
    ### SundaPy Hardware Type: `i8` (Signed 8-bit Integer)
    **Rentang Nilai:** `-128` s.d. `127` (Ukuran: 1 Byte di Register CPU)
    * Cocok untuk sample audio 8-bit, koordinat tile mikro, byte data bertanda.
    """
    pass

class u8(int):
    """
    ### SundaPy Hardware Type: `u8` (Unsigned 8-bit Integer / Byte)
    **Rentang Nilai:** `0` s.d. `255` (Ukuran: 1 Byte di Register CPU)
    * Cocok untuk warna RGB/RGBA (0-255), raw binary byte buffer, header paket jaringan.
    """
    pass

class i16(int):
    """
    ### SundaPy Hardware Type: `i16` (Signed 16-bit Integer)
    **Rentang Nilai:** `-32,768` s.d. `32,767` (Ukuran: 2 Byte)
    * Cocok untuk koordinat game 2D, data sensor 16-bit, audio PCM 16-bit.
    """
    pass

class u16(int):
    """
    ### SundaPy Hardware Type: `u16` (Unsigned 16-bit Integer)
    **Rentang Nilai:** `0` s.d. `65,535` (Ukuran: 2 Byte)
    * Cocok untuk nomor port jaringan (0-65535), indeks vertex mesh 3D menengah.
    """
    pass

class i32(int):
    """
    ### SundaPy Hardware Type: `i32` (Signed 32-bit Integer)
    **Rentang Nilai:** `-2,147,483,648` s.d. `2,147,483,647` (Ukuran: 4 Byte)
    * Cocok untuk koordinat layar FHD/4K, shader vertex offset, kalkulasi integer standar C.
    """
    pass

class u32(int):
    """
    ### SundaPy Hardware Type: `u32` (Unsigned 32-bit Integer)
    **Rentang Nilai:** `0` s.d. `4,294,967,295` (Ukuran: 4 Byte)
    * Cocok untuk warna ARGB 32-bit packed (`0xAARRGGBB`), hash index, ukuran alokasi VRAM s.d. 4 GB.
    """
    pass

class i64(int):
    """
    ### SundaPy Hardware Type: `i64` (Signed 64-bit Integer - DEFAULT INTEGER)
    **Rentang Nilai:** `-9,223,372,036,854,775,808` s.d. `9,223,372,036,854,775,807` (Ukuran: 8 Byte)
    * **Tipe integer standar SundaPy** untuk komputasi umum, pointer 64-bit, perulangan besar, nanodetik `time.time_ns()`.
    """
    pass

class u64(int):
    """
    ### SundaPy Hardware Type: `u64` (Unsigned 64-bit Integer)
    **Rentang Nilai:** `0` s.d. `18,446,744,073,709,551,615` (Ukuran: 8 Byte)
    * Cocok untuk alamat memori GPU/Host 64-bit mentah, hash Wyhash / 64-bit bitboard catur.
    """
    pass

class i128(int):
    """
    ### SundaPy Hardware Type: `i128` (Signed 128-bit Integer)
    **Rentang Nilai:** `±1.7 × 10^38` (Ukuran: 16 Byte)
    * Operasi angka raksasa tanpa alokasi BigInt (Fibonacci 128, faktorial, kriptografi).
    """
    pass

class u128(int):
    """
    ### SundaPy Hardware Type: `u128` (Unsigned 128-bit Integer)
    **Rentang Nilai:** `0` s.d. `3.4 × 10^38` (Ukuran: 16 Byte)
    * Hash 128-bit (MurmurHash3, MD5 digest integer).
    """
    pass

class f32(float):
    """
    ### SundaPy Hardware Type: `f32` (Single-Precision 32-bit Float)
    **Presisi:** ~7 digit desimal (Ukuran: 4 Byte)
    * **Standar industri untuk Grafika 3D**, GPU Field, vektor posisi, dan shader CUDA/PTX.
    """
    pass

class f64(float):
    """
    ### SundaPy Hardware Type: `f64` (Double-Precision 64-bit Float - DEFAULT FLOAT)
    **Presisi:** ~15-17 digit desimal (Ukuran: 8 Byte)
    * Standar komputasi sains, kalkulasi delta-time sub-milidetik di CPU host.
    """
    pass

class void:
    """
    ### SundaPy Return Type: `void`
    Menandakan fungsi yang tidak mengembalikan nilai apapun (setara `None` / `void` di C).
    Contoh: `def main() -> void:`
    """
    pass

# ==============================================================================
# 3. TIPE DATA KOLEKSI MODERN & PEP 619/826
# ==============================================================================

class frozendict(dict[KT, VT]):
    """
    ### SundaPy Built-in Type: `frozendict` (PEP 814)
    Koleksi dictionary immutable (tidak dapat diubah setelah dibuat) dengan hash terhitung.
    * **Thread-Safe Alami:** Aman dibagikan antar multi-core worker threads tanpa lock.
    * **O(1) Hash:** Nilai hash di-cache saat inisialisasi.
    """
    def __init__(self, *args: Any, **kwargs: Any) -> None: ...

class sentinel:
    """
    ### SundaPy Built-in Sentinel: `sentinel` (PEP 661)
    Singleton opaque pointer unik di memori.
    Evaluasi `x is sentinel` dieksekusi dalam 1 siklus CPU register (`cmp %rax, %rbx`).
    """
    pass

# ==============================================================================
# 4. KATA KUNCI & FITUR KHUSUS SUNDAPY
# ==============================================================================

def const(target: Any) -> Any:
    """
    ### SundaPy Keyword: `const`
    Mendeklarasikan variabel bernilai konstan (immutable) pada waktu kompilasi.
    Contoh: `const PI: f64 = 3.1415926535`
    Percobaan reassign ke variabel `const` akan ditolak oleh compiler SundaPy saat kompilasi.
    """
    return target

None: None
"""
### SundaPy Keyword / Singleton Constant: `None`
Representasi nilai kosong (null / void pointer `0x0`).
* **Optimasi Hardware:** Di mode `#strict`, disimpan sebagai nilai 0 di register CPU tanpa alokasi heap.
* **1 CPU Cycle Check:** Pengecekan `x is None` dievaluasi dalam 1 instruksi `test %rax, %rax`.
* **Operator Terkait:** Mendukung operator None-Coalescing `??` dan Safe Navigation `?.`.
"""

True: bool
"""
### SundaPy Keyword / Boolean Constant: `True`
Nilai logika kebenaran boolean (Benar).
* **Level Register:** Di-lower menjadi bit/integer `1` di register flag CPU.
"""

False: bool
"""
### SundaPy Keyword / Boolean Constant: `False`
Nilai logika kebenaran boolean (Salah).
* **Level Register:** Di-lower menjadi bit/integer `0` di register flag CPU.
"""

Ellipsis: Any
"""
### SundaPy Literal: `...` (Ellipsis)
Objek singleton penanda placeholder kode atau operasi multidimensional slice.
"""

NotImplemented: Any
"""
### SundaPy Constant: `NotImplemented`
Nilai balik khusus dari binary dunder methods yang menandakan operasi tidak didukung untuk tipe terkait.
"""


# ==============================================================================
# 5. TIPE-TIPE DASAR STANDAR & DECORATOR (STANDARD TYPES & DECORATORS)
# ==============================================================================

class bytes(Sequence[int]):
    """Objek deretan byte biner immutable."""
    def __init__(self, source: Any = b"") -> None: ...

class bytearray(Sequence[int]):
    """Objek deretan byte biner mutable (dapat diubah)."""
    def __init__(self, source: Any = b"") -> None: ...

class memoryview(Sequence[int]):
    """Akses zero-copy ke buffer memori objek pendukung buffer protocol."""
    def __init__(self, obj: Any) -> None: ...

class list(Sequence[T]):
    """Daftar terurut elemen dinamis."""
    def __init__(self, iterable: Optional[Iterable[T]] = None) -> None: ...
    def append(self, item: T) -> None: ...
    def extend(self, iterable: Iterable[T]) -> None: ...
    def pop(self, index: int = -1) -> T: ...
    def clear(self) -> None: ...

class dict(Generic[KT, VT]):
    """Kamus pasangan kunci-nilai (key-value mapping)."""
    def __init__(self, *args: Any, **kwargs: Any) -> None: ...
    def get(self, key: KT, default: Optional[VT] = None) -> Optional[VT]: ...
    def keys(self) -> Iterable[KT]: ...
    def values(self) -> Iterable[VT]: ...
    def items(self) -> Iterable[tuple[KT, VT]]: ...

class set(Generic[T]):
    """Himpunan elemen unik tak terurut."""
    def __init__(self, iterable: Optional[Iterable[T]] = None) -> None: ...
    def add(self, item: T) -> None: ...
    def remove(self, item: T) -> None: ...

class frozenset(Generic[T]):
    """Himpunan elemen unik immutable."""
    def __init__(self, iterable: Optional[Iterable[T]] = None) -> None: ...

class tuple(Sequence[Any]):
    """Tupel deretan elemen terurut immutable."""
    def __init__(self, *args: Any) -> None: ...

class slice:
    """Objek pemotongan urutan sequence [start:stop:step]."""
    def __init__(self, start: Optional[int], stop: Optional[int] = None, step: Optional[int] = None) -> None: ...

def classmethod(f: Callable) -> Callable:
    """Decorator untuk mendefinisikan class method yang menerima parameter kelas `cls`."""
    ...

def staticmethod(f: Callable) -> Callable:
    """Decorator untuk mendefinisikan method statis tanpa akses `self` atau `cls`."""
    ...

def property(fget: Optional[Callable] = None, fset: Optional[Callable] = None, fdel: Optional[Callable] = None) -> Any:
    """Decorator untuk mendefinisikan getter/setter atribut properti."""
    ...

# ==============================================================================
# 6. PENANGANAN EKSEPSI & KELAS KESALAHAN (EXCEPTIONS)
# ==============================================================================

class BaseException:
    """Akar hirarki seluruh exception di SundaPy."""
    pass

class Exception(BaseException):
    """Kelas dasar seluruh runtime exception non-exit."""
    pass

class ValueError(Exception):
    """Exception jika fungsi menerima tipe yang sesuai tetapi nilai argumen tidak tepat."""
    pass

class TypeError(Exception):
    """Exception jika operasi dilakukan pada tipe data yang tidak cocok."""
    pass

class KeyError(Exception):
    """Exception jika kunci dictionary tidak ditemukan."""
    pass

class IndexError(Exception):
    """Exception jika indeks list atau sequence berada di luar rentang."""
    pass

class ZeroDivisionError(Exception):
    """Exception jika terjadi pembagian dengan angka nol."""
    pass

class RuntimeError(Exception):
    """Exception jika terjadi kesalahan umum saat eksekusi runtime."""
    pass

class FileNotFoundError(Exception):
    """Exception jika berkas file yang diminta tidak ditemukan pada sistem."""
    pass

class IOError(Exception):
    """Exception jika terjadi kegagalan operasi Input/Output perangkat."""
    pass

class OSError(Exception):
    """Exception kesalahan level sistem operasi Linux/POSIX."""
    pass

class StopIteration(Exception):
    """Exception penanda akhir iterasi objek iterator."""
    pass

class AttributeError(Exception):
    """Exception jika atribut atau method tidak ditemukan pada objek."""
    pass

class ImportError(Exception):
    """Exception jika modul atau pustaka gagal diimpor."""
    pass

class NotImplementedError(Exception):
    """Exception penanda bahwa method atau operasi belum diimplementasikan."""
    pass

# ==============================================================================
# 7. SELURUH FUNGSI-FUNGSI BAWAAN GLOBAL (EXHAUSTIVE BUILT-INS)
# ==============================================================================

def print(*args: Any, sep: str = " ", end: str = "\n") -> None:
    """Mencetak argumen ke stdout/stderr secara native via `std.debug.print` tanpa overhead Python VM."""
    ...

def input(prompt: str = "") -> str:
    """Membaca sebaris teks dari standard input (stdin) pengguna."""
    ...

def len(obj: Union[Iterable, Sized]) -> int:
    """Mengembalikan jumlah elemen dalam list, dict, str, bytes, atau tuple dalam $O(1)$ konstan."""
    ...

def range(start: int, stop: Optional[int] = None, step: int = 1) -> Iterator[int]:
    """Menghasilkan deret angka. Di `#strict`, otomatis di-lower menjadi loop `while` register CPU."""
    ...

def type(obj: Any) -> type:
    """Mengembalikan tipe data runtime dari objek."""
    ...

def isinstance(obj: Any, class_or_tuple: Any) -> bool:
    """Mengecek apakah objek merupakan instansiasi dari kelas tertentu."""
    ...

def issubclass(cls: type, class_or_tuple: Any) -> bool:
    """Mengecek apakah kelas merupakan turunan dari kelas target."""
    ...

def id(obj: Any) -> int:
    """Mengembalikan alamat pointer memori unik 64-bit dari objek."""
    ...

def hash(obj: Any) -> int:
    """Mengembalikan nilai hash 64-bit integer dari objek."""
    ...

def repr(obj: Any) -> str:
    """Mengembalikan representasi string formal dari objek."""
    ...

def ascii(obj: Any) -> str:
    """Mengembalikan representasi string berkarakter ASCII murni (escape karakter non-ASCII)."""
    ...

def callable(obj: Any) -> bool:
    """Mengecek apakah objek dapat dipanggil sebagai fungsi."""
    ...

def int(x: Any = 0, base: int = 10) -> int:
    """Mengonversi nilai menjadi bilangan bulat (integer)."""
    ...

def float(x: Any = 0.0) -> float:
    """Mengonversi nilai menjadi bilangan desimal berkoma (float 64-bit)."""
    ...

def str(x: Any = "") -> str:
    """Mengonversi nilai menjadi string representasi UTF-8 native."""
    ...

def bool(x: Any = False) -> bool:
    """Mengonversi nilai menjadi boolean (`True` atau `False`)."""
    ...

def complex(real: float = 0.0, imag: float = 0.0) -> complex:
    """Membentuk bilangan kompleks dengan bagian riil dan imajiner."""
    ...

def bin(x: int) -> str:
    """Mengonversi integer menjadi string representasi biner (prefix `0b`)."""
    ...

def oct(x: int) -> str:
    """Mengonversi integer menjadi string representasi oktal (prefix `0o`)."""
    ...

def hex(x: int) -> str:
    """Mengonversi integer menjadi string representasi heksadesimal (prefix `0x`)."""
    ...

def ord(c: str) -> int:
    """Mengembalikan kode ASCII / Unicode codepoint integer dari sebuah karakter string tunggal."""
    ...

def chr(i: int) -> str:
    """Mengembalikan karakter string tunggal dari nilai integer Unicode codepoint."""
    ...

def abs(x: Union[int, float]) -> Union[int, float]:
    """Mengembalikan nilai absolut/mutlak. Di-lower ke instruksi CPU hardware murni."""
    ...

def round(number: Union[int, float], ndigits: Optional[int] = None) -> Union[int, float]:
    """Membulatkan angka floating-point ke jumlah digit presisi tertentu."""
    ...

def divmod(a: Union[int, float], b: Union[int, float]) -> tuple:
    """Mengembalikan pasangan tupel `(hasil_bagi, sisa_bagi)` dalam 1 instruksi hardware CPU."""
    ...

def pow(base: Union[int, float], exp: Union[int, float], mod: Optional[int] = None) -> Union[int, float]:
    """Menghitung perpangkatan `base ** exp` (opsional modulus `mod`)."""
    ...

def min(*args: Any, key: Optional[Callable] = None) -> Any:
    """Mengembalikan nilai terkecil dari argumen atau koleksi iterasi."""
    ...

def max(*args: Any, key: Optional[Callable] = None) -> Any:
    """Mengembalikan nilai terbesar dari argumen atau koleksi iterasi."""
    ...

def sum(iterable: Iterable, start: Any = 0) -> Any:
    """Menjumlahkan seluruh angka dalam iterasi secara cepat."""
    ...

def enumerate(iterable: Iterable[T], start: int = 0) -> Iterator[tuple[int, T]]:
    """Menghasilkan pasangan (indeks, elemen) dari iterasi tanpa overhead alokasi objek."""
    ...

def zip(*iterables: Iterable) -> Iterator[tuple]:
    """Menggabungkan elemen dari beberapa iterasi secara paralel."""
    ...

def reversed(seq: Sequence[T]) -> Iterator[T]:
    """Menghasilkan iterator elemen dalam urutan terbalik."""
    ...

def sorted(iterable: Iterable[T], key: Optional[Callable] = None, reverse: bool = False) -> list[T]:
    """Mengurutkan elemen koleksi dan mengembalikan list baru yang terurut."""
    ...

def filter(function: Optional[Callable[[T], bool]], iterable: Iterable[T]) -> Iterator[T]:
    """Menyaring elemen koleksi berdasarkan predikat fungsi."""
    ...

def map(function: Callable, *iterables: Iterable) -> Iterator:
    """Menerapkan fungsi ke setiap elemen koleksi iterasi."""
    ...

def all(iterable: Iterable) -> bool:
    """Mengembalikan True jika seluruh elemen dalam iterasi bernilai truthy."""
    ...

def any(iterable: Iterable) -> bool:
    """Mengembalikan True jika minimal ada 1 elemen dalam iterasi bernilai truthy."""
    ...

def iter(obj: Any) -> Iterator:
    """Mengembalikan objek iterator dari koleksi iterabel."""
    ...

def next(iterator: Iterator[T], default: Optional[T] = None) -> T:
    """Mengambil elemen berikutnya dari iterator."""
    ...

def getattr(obj: Any, name: str, default: Optional[Any] = None) -> Any:
    """Mengambil atribut objek berdasarkan string nama."""
    ...

def setattr(obj: Any, name: str, value: Any) -> None:
    """Menetapkan nilai atribut pada objek."""
    ...

def hasattr(obj: Any, name: str) -> bool:
    """Mengecek apakah objek memiliki atribut tertentu."""
    ...

def delattr(obj: Any, name: str) -> None:
    """Menghapus atribut dari objek."""
    ...

def dir(obj: Optional[Any] = None) -> list[str]:
    """Mengembalikan daftar nama atribut dan metode dari objek."""
    ...

def vars(obj: Optional[Any] = None) -> dict:
    """Mengembalikan kamus atribut `__dict__` dari objek."""
    ...

def open(file: str, mode: str = "r", buffering: int = -1, encoding: Optional[str] = None) -> Any:
    """Membuka berkas file secara native menggunakan Linux syscalls murni."""
    ...

def format(value: Any, format_spec: str = "") -> str:
    """Mengonversi nilai menjadi representasi string berformat."""
    ...

def breakpoint() -> None:
    """Menghentikan jalannya eksekusi program ke debugger native."""
    ...

def help(request: Optional[Any] = None) -> None:
    """Menampilkan bantuan dokumentasi SundaPy."""
    ...

def object() -> object:
    """Kelas dasar tertinggi (root base class) dalam hierarki objek."""
    ...

def super(type: Optional[type] = None, object_or_type: Optional[Any] = None) -> Any:
    """Mengakses metode dan atribut dari kelas induk (parent class)."""
    ...
