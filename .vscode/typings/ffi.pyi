"""
SundaPy FFI (Foreign Function Interface) Module Specification.
Menyediakan antarmuka low-level dan high-level untuk memanggil pustaka dinamis C/C++/Rust/Zig/Go (.so / .dll / .dylib)
serta manipulasi memori mentah berkinerja tinggi secara zero-cost.
"""

from typing import Any, Callable, Dict, List, Optional, Tuple, Type, Union

# ==============================================================================
# TIPE DATA FFI DAN KONSTANTA FLAG
# ==============================================================================

void: int = 0
i8: int = 1
i16: int = 2
i32: int = 3
i64: int = 4
u8: int = 5
u16: int = 6
u32: int = 7
u64: int = 8
f32: int = 9
f64: int = 10
bool: int = 11
c_str_type: int = 12
ptr: int = 13
struct: int = 14

RTLD_LOCAL: int = 0
RTLD_LAZY: int = 1
RTLD_NOW: int = 2
RTLD_GLOBAL: int = 256

# ==============================================================================
# KELAS HIGH-LEVEL FFI
# ==============================================================================

class FfiStructInstance:
    """Instansi dari struct C yang dialokasikan di memori native."""
    def __getattr__(self, name: str) -> Any: ...
    def __setattr__(self, name: str, value: Any) -> None: ...

class FfiStructDesc:
    """Deskriptor tipe struct C yang dapat diinisiasi seperti kelas biasa."""
    def __call__(self, *args: Any) -> FfiStructInstance: ...

class FfiLib:
    """
    Representasi handle pustaka dinamis (shared library / dynlib) yang dibuka.
    Mendukung pemanggilan langsung berkecepatan tinggi baik via low-level pointer maupun high-level type binding.
    """
    def get_symbol(self, symbol_name: str) -> int:
        """
        Mencari alamat memori simbol fungsi / variabel di dalam pustaka dinamis via `dlsym`.
        Mengembalikan pointer integer mentah.
        """
        ...

    def call_raw(self, symbol_address: int, *args: Any) -> Any:
        """
        Memanggil simbol fungsi secara langsung melalui pointer alamat memori mentah.
        Performa ultra tinggi tanpa overhead binding.
        """
        ...

    def bind(self, symbol_name: str, return_type: int, param_types: List[int]) -> Callable[..., Any]:
        """
        Melakukan bind simbol fungsi C menjadi callable Python/SundaPy dengan validasi dan konversi tipe otomatis.
        Contoh:
            add_fn = lib.bind("add_i32", ffi.i32, [ffi.i32, ffi.i32])
            res = add_fn(10, 20)
        """
        ...

    def close(self) -> None:
        """Menutup handle pustaka dinamis dan melepaskan referensi dlclose."""
        ...

# ==============================================================================
# FUNGSI-FUNGSI UTAMA FFI
# ==============================================================================

def open(path: str) -> FfiLib:
    """
    Membuka pustaka dinamis (.so / .dll / .dylib) pada path yang ditentukan.
    Ekuivalen dengan `load(path)`.
    """
    ...

def load(path: str) -> FfiLib:
    """
    Membuka pustaka dinamis (.so / .dll / .dylib) pada path yang ditentukan.
    Ekuivalen dengan `open(path)`.
    """
    ...

def alloc(size: int) -> int:
    """
    Mengalokasikan blok memori mentah berukuran `size` byte menggunakan libc malloc / Zig page_allocator.
    Mengembalikan integer pointer alamat awal memori.
    """
    ...

def free(ptr: int) -> None:
    """
    Membebaskan blok memori mentah yang sebelumnya dialokasikan via `ffi.alloc`.
    """
    ...

def memcpy(dst: int, src: int, size: int) -> None:
    """
    Menyalin `size` byte memori dari alamat pointer `src` ke alamat pointer `dst`.
    Dipetakan langsung ke operasi hardware native memcpy.
    """
    ...

def c_str(s: str) -> int:
    """
    Mengonversi string Python/SundaPy menjadi C null-terminated string (`const char*`).
    Mengembalikan alamat memori integer pointer.
    """
    ...

def cast(addr: int, type_id: int) -> Any:
    """
    Membaca data dari alamat memori `addr` dan mengonversinya sesuai dengan tipe data `type_id`.
    """
    ...

def sizeof(val: Union[int, Any]) -> int:
    """
    Mengembalikan ukuran (dalam byte) dari tipe data FFI primitif, struct descriptor, atau struct instance.
    Contoh:
        ffi.sizeof(ffi.i64) -> 8
        ffi.sizeof(Point)   -> 16
    """
    ...

def addressof(val: Any) -> int:
    """
    Mengembalikan alamat pointer memori fisik dari struct instance native.
    """
    ...

def create_struct(name: str, fields: List[Tuple[str, int]]) -> FfiStructDesc:
    """
    Mendefinisikan layout C struct baru secara dinamis dengan nama dan daftar field `(nama_field, tipe_ffi)`.
    Contoh:
        Point = ffi.create_struct("Point", [("x", ffi.f64), ("y", ffi.f64)])
        p = Point(1.0, 2.0)
    """
    ...
