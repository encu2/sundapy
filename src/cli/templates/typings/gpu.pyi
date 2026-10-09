"""
SundaPy GPU Compute & High-Performance Accelerator Module.
Menyediakan antarmuka High-Level Array (HLA) dan Low-Level Allocator (LLA)
untuk akselerasi komputasi dan grafika langsung pada perangkat keras GPU (NVIDIA CUDA / PTX).
"""

from typing import Any, Callable, List, Optional, Tuple, Union

class GPUBuffer:
    """
    Handle representasi buffer memori linier di VRAM perangkat keras GPU.
    Mendukung kompresi in-place lossy dan lossless berkecepatan tinggi.
    """
    size: int
    dev_ptr: int
    is_device: bool
    is_managed: bool
    is_compressed: bool
    compression_ratio: float
    savings_pct: float
    compressed_bytes: int
    original_bytes: int
    scheme: str

    def compress(self, codec: str = "fpc") -> "GPUBuffer":
        """Mengompresi buffer in-place di VRAM/RAM dengan codec tertentu."""
        ...

    def decompress(self) -> "GPUBuffer":
        """Mendekompresi buffer in-place kembali ke float uncompressed."""
        ...

    def stats(self) -> dict:
        """Mengembalikan statistik memori dan rasio kompresi buffer."""
        ...

class GPUField:
    """
    ### High-Level Array Multidimensi GPU (HLA)
    
    Struktur data array terstruktur 2D, 3D, atau 4D yang dialokasikan di VRAM GPU.
    Mendukung pengindeksan koordinat natural `field[y, x]` atau `field[z, y, x]`.
    """
    shape: List[int]
    size: int

    def __getitem__(self, index: Union[int, Tuple[int, ...]]) -> float:
        """Membaca nilai elemen pada koordinat tertentu."""
        ...

    def __setitem__(self, index: Union[int, Tuple[int, ...]], value: float) -> None:
        """Menulis nilai float ke koordinat tertentu di VRAM GPU."""
        ...

    def fill(self, value: float) -> None:
        """
        Mengisi seluruh elemen array dengan nilai konstanta secara instan via hardware memset.
        """
        ...

def field(dims: List[int], fill: float = 0.0) -> GPUField:
    """
    ### Inisialisasi High-Level Array (HLA) Multidimensi di GPU VRAM
    
    **Tujuan:**
    Mengalokasikan array multidimensi terkelola langsung di VRAM GPU.
    
    **Kapan Menggunakan Ini (Kebutuhan A vs B):**
    - ✅ **Gunakan `gpu.field`:** Jika Anda memproses grid spasial (citra 2D, volume voxel 3D, tensor matriks)
      yang membutuhkan akses koordinat `f[y, x]`.
    - ❌ **Gunakan `gpu.arena_alloc`:** Jika Anda hanya butuh buffer byte linier sementara untuk transfer data
      atau interop shader level rendah dan ingin performa alokasi sub-mikrodetik.
    
    **Parameter & Tipe Valid:**
    - `dims`: `list[int]` — Daftar ukuran dimensi, misal `[1080, 1920]` untuk 2D atau `[64, 64, 64]` untuk 3D.
    - `fill`: `float` *(opsional)* — Nilai inisialisasi awal seluruh elemen (default: `0.0`).
    
    **Contoh Penggunaan:**
    ```python
    import gpu
    grid = gpu.field([1080, 1920], fill=0.0)
    grid[0, 0] = 42.5
    print("Shape:", grid.shape)  # [1080, 1920]
    ```
    """
    ...

def create_field_2d(rows: int, cols: int, fill: float = 0.0) -> GPUField:
    """
    Shortcut untuk membuat array 2D terstruktur `[rows, cols]` di VRAM GPU.
    """
    ...

def arena_alloc(byte_size: int) -> GPUBuffer:
    """
    ### Low-Level Memory Arena Sub-Allocator (LLA)
    
    **Tujuan:**
    Alokasi memori berkecepatan sub-mikrodetik (< 0.2 µs) di VRAM GPU tanpa overhead
    driver CUDA `cudaMalloc` yang lambat.
    
    **Kapan Menggunakan Ini (Kebutuhan A vs B):**
    - ✅ **Gunakan `gpu.arena_alloc`:** Jika Anda mengalokasikan ratusan hingga ribuan buffer sementara
      setiap frame (misal partikel, scratchpad buffer raytracing) yang akan dibersihkan di akhir frame.
    - ❌ **Gunakan `gpu.field`:** Jika Anda membutuhkan array terstruktur persisten dengan indeks koordinat `[x, y]`.
    
    **Cara Pakai:**
    Dialokasikan dengan `gpu.arena_alloc(bytes)`, lalu reset seluruh arena sekaligus
    dengan `gpu.arena_reset()` tanpa risiko kebocoran memori (memory leak).
    """
    ...

def arena_reset() -> None:
    """
    ### Reset Total VRAM Arena Sub-Allocator
    
    Mengembalikan seluruh offset memori arena GPU ke 0 seketika (0.00 ms).
    Seluruh buffer yang dialokasikan via `arena_alloc` akan dibebaskan sekaligus tanpa fragmentasi.
    """
    ...

def get_raw_pointer(buffer: Union[GPUBuffer, GPUField]) -> int:
    """
    Mengambil alamat pointer fisik 64-bit perangkat keras GPU (`dev_ptr`).
    Sangat berguna untuk operasi zero-copy dan interop dengan kernel C / CUDA / PTX.
    """
    ...

def make_raw_handle(dev_ptr: int, byte_size: int, stride: int = 4) -> dict:
    """
    Membangun deskriptor handle memori zero-copy untuk pertukaran memori antara LLA dan HLA.
    """
    ...

def pool_dispatch(func: Callable, args: list) -> Any:
    """
    ### Persistent Worker Pool Multi-Core Dispatch
    
    Mendistribusikan batch komputasi paralel melintasi pool worker thread persisten
    tanpa membuat thread baru (latensi per dispatch ~28 µs).
    """
    ...

def render_earth_3d(buffer: Any, width: int, height: int, angle: float) -> None:
    """
    Me-render bola bumi 3D fotorealistik via kernel PTX ray-tracer hardware-accelerated.
    """
    ...

def render_4d(buffer: Any, width: int, height: int, time: float) -> None:
    """
    Me-render visualisasi 4D hypersphere raymarching langsung pada perangkat keras GPU.
    """
    ...

def compress(buf: GPUBuffer, codec: str = "fpc") -> dict:
    """
    ### Mengompresi Buffer GPU VRAM
    Mengompresi data buffer GPU menggunakan codec terpilih (fpc, quant8, quant4, fp16, fp8, fp4, lz_fast, rle, bpc, delta_rle, sparse).
    Mengembalikan dictionary CompressedBuffer.
    """
    ...

def decompress(comp: dict, out_buf: Optional[GPUBuffer] = None) -> GPUBuffer:
    """
    ### Mendekompresi Buffer GPU
    Mendekompresi objek buffer yang terkompresi kembali ke GPUBuffer.
    """
    ...

def compress_ratio(buf: GPUBuffer, codec: str = "fpc") -> float:
    """Mengukur rasio kompresi data buffer GPU tanpa menyimpan hasil kompresi."""
    ...

def get_codecs() -> List[str]:
    """Mengembalikan daftar seluruh codec kompresi GPU yang didukung."""
    ...

def set_memory_budget(bytes: int) -> None:
    """Menetapkan batas anggaran VRAM/RAM (memory budget) dalam byte (0 = unlimited)."""
    ...

def get_memory_budget() -> dict:
    """Mengambil status pemakaian memory budget saat ini."""
    ...

def get_memory_stats() -> dict:
    """Mengambil rincian statistik memori subsistem GPU (alokasi, penghematan, rasio)."""
    ...

def compact_memory() -> int:
    """Memicu pemadatan dan kompresi aktif seluruh buffer pasif untuk menghemat VRAM."""
    ...

def memory_report() -> dict:
    """Mencetak dan mengembalikan laporan ringkasan penggunaan memori GPU tingkat produksi."""
    ...

def benchmark_compression(size_or_buf: Union[int, GPUBuffer] = 65536) -> List[dict]:
    """
    ### Menjalankan Benchmark Komparatif Seluruh Codec Kompresi VRAM
    Menghasilkan tabel performa lengkap (Rasio, Penghematan %, Kecepatan Kompresi & Dekompresi dalam GB/s, Max Error).
    """
    ...

