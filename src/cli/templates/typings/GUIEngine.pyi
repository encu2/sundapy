"""
SundaPy 2D Rasterizer & Graphics Primitives Engine.
Menyediakan fungsi penggambaran bentuk 2D (piksel, garis, kotak, lingkaran, teks bitmap font),
alokasi permukaan kanvas, dan operasi blitting.
"""

from typing import Any

def create_surface(width: int, height: int) -> Any:
    """
    ### Alokasi Permukaan Kanvas Grafis
    
    Membuat buffer permukaan grafis (surface) 32-bit BGRA berukuran `width x height`.
    Gunakan buffer ini sebagai target penggambaran fungsi-fungsi `draw_*`.
    """
    ...

def clear(buffer: Any, r: float, g: float, b: float) -> None:
    """
    Membersihkan kanvas dengan warna latar belakang solid (RGB 0..255).
    """
    ...

def draw_pixel(buffer: Any, width: int, height: int, x: int, y: int, r: float, g: float, b: float) -> None:
    """Menggambar 1 piksel dengan koordinat (x, y) dan warna RGB."""
    ...

def draw_rect(buffer: Any, width: int, height: int, x: int, y: int, rect_w: int, rect_h: int, r: float, g: float, b: float) -> None:
    """
    Menggambar persegi panjang terisi (*filled rectangle*).
    - `(x, y)`: Titik sudut kiri atas.
    - `(rect_w, rect_h)`: Lebar dan tinggi persegi panjang.
    """
    ...

def draw_line(buffer: Any, width: int, height: int, x0: int, y0: int, x1: int, y1: int, r: float, g: float, b: float) -> None:
    """
    Menggambar garis lurus dari `(x0, y0)` ke `(x1, y1)` menggunakan algoritma Bresenham cepat.
    """
    ...

def draw_circle(buffer: Any, width: int, height: int, cx: int, cy: int, radius: int, r: float, g: float, b: float) -> None:
    """
    Menggambar lingkaran terisi (*filled circle*) dengan pusat `(cx, cy)` dan jari-jari `radius`.
    """
    ...

def draw_text(buffer: Any, width: int, height: int, text: str, x: int, y: int, scale: int = 1, r: float = 255.0, g: float = 255.0, b: float = 255.0) -> None:
    """
    Me-render teks menggunakan font retro 8x8 bitmap bawaan.
    - `scale`: Skala ukuran font (1 = 8x8 px, 2 = 16x16 px, 3 = 24x24 px).
    - `(r, g, b)`: Warna teks (0.0 s.d. 255.0).
    """
    ...

def blit(src_buffer: Any, dst_buffer: Any, src_w: int, src_h: int, dst_w: int, dst_h: int, dst_x: int, dst_y: int) -> None:
    """
    Mentransfer (copy) sebagian/seluruh area buffer sumber ke dalam buffer tujuan pada koordinat `(dst_x, dst_y)`.
    """
    ...

def rgb_to_bgr(color_packed: int) -> int:
    """Konversi format byte order warna RGB ke BGR 32-bit."""
    ...

def compress_surface(surface: Any, codec: str = "rle") -> dict:
    """
    ### Mengompresi Permukaan Grafis 2D
    Mengompresi buffer permukaan canvas menggunakan codec RLE atau FPC untuk menghemat VRAM.
    """
    ...

def decompress_surface(comp: dict, out_surface: Any = None) -> Any:
    """
    ### Mendekompresi Permukaan Grafis
    Mendekompresi permukaan terkompresi kembali ke buffer surface siap gambar/blit.
    """
    ...

def compress_ratio(surface: Any, codec: str = "rle") -> float:
    """Mengukur rasio kompresi memori permukaan 2D."""
    ...

def get_surface_stats(surface: Any) -> dict:
    """Mengambil rincian statistik memori permukaan kanvas grafis."""
    ...

def benchmark_surface(surface: Any) -> list:
    """Menjalankan benchmark kompresi terhadap permukaan aktif."""
    ...

