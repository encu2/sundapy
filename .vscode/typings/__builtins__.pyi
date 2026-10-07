"""
SundaPy Core Builtin Types and Functions Specification.
Mendefinisikan tipe primitif hardware native dan fungsi global SundaPy.
"""

from typing import Any, Callable, Iterable, Iterator, NoReturn, Optional, TypeVar, Union

T = TypeVar("T")

# ==============================================================================
# TIPE DATA PRIMITIF PERANGKAT KERAS (HARDWARE NATIVE PRIMITIVES)
# ==============================================================================

class i8(int):
    """
    ### SundaPy Hardware Type: `i8` (Signed 8-bit Integer)
    
    **Rentang Nilai:** `-128` s.d. `127` (Ukuran: 1 Byte)
    
    **Kapan Menggunakan Ini (Kebutuhan A vs B):**
    - ✅ **Gunakan `i8`:** Untuk data numerik kecil berukuran 1 byte bertanda (misal offset koordinat mikro, audio 8-bit sample).
    - ❌ **Gunakan `u8`:** Jika nilai tidak pernah negatif (seperti nilai warna RGB `0..255` atau raw memory byte).
    """
    pass

class u8(int):
    """
    ### SundaPy Hardware Type: `u8` (Unsigned 8-bit Integer / Byte)
    
    **Rentang Nilai:** `0` s.d. `255` (Ukuran: 1 Byte)
    
    **Kapan Menggunakan Ini (Kebutuhan A vs B):**
    - ✅ **Gunakan `u8`:** Untuk komponen warna RGB/RGBA (`0-255`), indeks palet warna, atau raw binary buffer data.
    - ❌ **Gunakan `i16`/`i32`:** Jika membutuhkan nilai di atas 255 atau nilai bertanda negatif.
    """
    pass

class i16(int):
    """
    ### SundaPy Hardware Type: `i16` (Signed 16-bit Integer)
    
    **Rentang Nilai:** `-32,768` s.d. `32,767` (Ukuran: 2 Byte)
    
    **Kapan Menggunakan Ini (Kebutuhan A vs B):**
    - ✅ **Gunakan `i16`:** Untuk game 2D (koordinat piksel/tile), parameter counter perulangan ringan, atau data sensor 16-bit.
    - ❌ **Gunakan `i32`/`i64`:** Jika angka koordinat dapat melampaui 32.767 piksel.
    """
    pass

class u16(int):
    """
    ### SundaPy Hardware Type: `u16` (Unsigned 16-bit Integer)
    
    **Rentang Nilai:** `0` s.d. `65,535` (Ukuran: 2 Byte)
    
    **Kapan Menggunakan Ini (Kebutuhan A vs B):**
    - ✅ **Gunakan `u16`:** Untuk nomor port jaringan (`0-65535`), indeks vertex mesh 3D menengah, atau ukuran tekstur.
    """
    pass

class i32(int):
    """
    ### SundaPy Hardware Type: `i32` (Signed 32-bit Integer)
    
    **Rentang Nilai:** `-2,147,483,648` s.d. `2,147,483,647` (Ukuran: 4 Byte)
    
    **Kapan Menggunakan Ini (Kebutuhan A vs B):**
    - ✅ **Gunakan `i32`:** Untuk koordinat layar resolusi tinggi (1080p, 1440p, 4K), indeks buffer, atau komputasi grafika 3D.
    - ❌ **Gunakan `i64`:** Jika membutuhkan timestamp nanodetik (karena nanodetik melebihi 2 miliar dalam 2 detik).
    """
    pass

class u32(int):
    """
    ### SundaPy Hardware Type: `u32` (Unsigned 32-bit Integer)
    
    **Rentang Nilai:** `0` s.d. `4,294,967,295` (Ukuran: 4 Byte)
    
    **Kapan Menggunakan Ini (Kebutuhan A vs B):**
    - ✅ **Gunakan `u32`:** Untuk warna ARGB 32-bit packed (`0xAARRGGBB`), hash index, atau ukuran alokasi VRAM hingga 4 GB.
    """
    pass

class i64(int):
    """
    ### SundaPy Hardware Type: `i64` (Signed 64-bit Integer - DEFAULT INTEGER)
    
    **Rentang Nilai:** `-9,223,372,036,854,775,808` s.d. `9,223,372,036,854,775,807` (Ukuran: 8 Byte)
    
    **Kapan Menggunakan Ini (Kebutuhan A vs B):**
    - ✅ **Gunakan `i64`:** **Tipe integer standar untuk komputasi umum**, counter perulangan besar, timestamp nanodetik (`time.time_ns()`), dan penunjuk memori (pointer 64-bit).
    """
    pass

class u64(int):
    """
    ### SundaPy Hardware Type: `u64` (Unsigned 64-bit Integer)
    
    **Rentang Nilai:** `0` s.d. `18,446,744,073,709,551,615` (Ukuran: 8 Byte)
    
    **Kapan Menggunakan Ini (Kebutuhan A vs B):**
    - ✅ **Gunakan `u64`:** Untuk alamat memori GPU/host 64-bit mentah atau perhitungan nilai hash Wyhash / SHA-256.
    """
    pass

class i128(int):
    """
    ### SundaPy Hardware Type: `i128` (Signed 128-bit Integer)
    
    **Rentang Nilai:** ±1.7 × 10^38 (Ukuran: 16 Byte)
    
    **Kapan Menggunakan Ini (Kebutuhan A vs B):**
    - ✅ **Gunakan `i128`:** Untuk operasi matematika dengan angka raksasa (misal Fibonacci(128), faktorial besar, kriptografi) dengan **performa perangkat keras murni tanpa alokasi heap BigInt**.
    - ❌ **Gunakan `i64`:** Untuk perulangan biasa karena register 128-bit membutuhkan 2 register 64-bit di CPU x86_64.
    """
    pass

class u128(int):
    """
    ### SundaPy Hardware Type: `u128` (Unsigned 128-bit Integer)
    
    **Rentang Nilai:** `0` s.d. `3.4 × 10^38` (Ukuran: 16 Byte)
    """
    pass

class f32(float):
    """
    ### SundaPy Hardware Type: `f32` (Single-Precision 32-bit Float)
    
    **Presisi:** ~7 digit desimal (Ukuran: 4 Byte)
    
    **Kapan Menggunakan Ini (Kebutuhan A vs B):**
    - ✅ **Gunakan `f32`:** **Standar industri untuk grafika 3D**, GPU Field, koordinat vektor, dan shader PTX/CUDA. Menghemat 50% bandwidth memori VRAM dibanding f64.
    - ❌ **Gunakan `f64`:** Untuk perhitungan orbit astronomi atau akumulasi waktu jangka panjang yang rentan rounding-error.
    """
    pass

class f64(float):
    """
    ### SundaPy Hardware Type: `f64` (Double-Precision 64-bit Float - DEFAULT FLOAT)
    
    **Presisi:** ~15-17 digit desimal (Ukuran: 8 Byte)
    
    **Kapan Menggunakan Ini (Kebutuhan A vs B):**
    - ✅ **Gunakan `f64`:** Standar komputasi sains, kalkulasi delta-time sub-milidetik di CPU host, dan matematika presisi tinggi.
    """
    pass

class void:
    """
    ### SundaPy Type: `void`
    Menandakan fungsi yang tidak mengembalikan nilai apapun (return None / void).
    Contoh: `def main() -> void:`
    """
    pass

# ==============================================================================
# FUNGSI-FUNGSI BAWAAN (BUILT-IN FUNCTIONS)
# ==============================================================================

def print(*args: Any, sep: str = " ", end: str = "\n") -> None:
    """
    Mencetak argumen ke layar (stderr/stdout).
    Di SundaPy, `print` diterjemahkan langsung ke pemanggilan native `std.debug.print`
    tanpa overhead pembentukan objek string Python yang membebani alokator heap.
    """
    ...

def range(start: int, stop: Optional[int] = None, step: int = 1) -> Iterator[int]:
    """
    Menghasilkan iterator angka. Di SundaPy, perulangan `for i in range(n)`
    dioptimasi secara otomatis oleh compiler menjadi perulangan `while` native register CPU.
    """
    ...

def len(obj: Union[list, dict, str, bytes, tuple]) -> int:
    """
    Mengembalikan panjang elemen dari list, dict, string, atau tuple.
    Waktu eksekusi: O(1) konstan langsung membaca properti panjang memori.
    """
    ...

def abs(x: Union[int, float]) -> Union[int, float]:
    """Mengembalikan nilai mutlak (absolut). Diterjemahkan ke instruksi hardware CPU murni."""
    ...

def min(*args: Any) -> Any:
    """Mengembalikan nilai terkecil dari argumen."""
    ...

def max(*args: Any) -> Any:
    """Mengembalikan nilai terbesar dari argumen."""
    ...

def sum(iterable: Iterable[Union[int, float]]) -> Union[int, float]:
    """Menjumlahkan seluruh angka dalam iterasi secara cepat."""
    ...

def enumerate(iterable: Iterable[T], start: int = 0) -> Iterator[tuple[int, T]]:
    """Menghasilkan pasangan (indeks, elemen) dari iterasi tanpa overhead alokasi memori."""
    ...

def zip(*iterables: Iterable[Any]) -> Iterator[tuple]:
    """Menggabungkan beberapa iterasi menjadi tupel secara paralel."""
    ...
