"""
SundaPy Native Desktop Windowing, Input & Display Engine.
Menyediakan antarmuka interaksi jendela desktop X11 / SHM zero-copy berkecepatan 60-144 FPS
serta penanganan event mouse dan keyboard.
"""

from typing import Any, Dict, List, Tuple, Union

def init(width: int, height: int, title: str = "SundaPy Window") -> None:
    """
    ### Inisialisasi Jendela Desktop Fisik
    
    **Tujuan:**
    Membuka jendela desktop X11 dengan double-buffered shared memory (SHM) presentation.
    
    **Kapan Menggunakan `screenGUI` vs `GUIEngine`:**
    - 📺 **`screenGUI`:** Mengatur jendela fisik di layar monitor, menangani input keyboard/mouse, dan mempresentasikan buffer ke layar.
    - 🎨 **`GUIEngine`:** Kuas untuk menggambar bentuk 2D, garis, lingkaran, dan teks font ke dalam buffer kanvas sebelum dikirim ke `screenGUI.render()`.
    
    **Parameter:**
    - `width`: Lebar jendela dalam piksel (misal `1280` atau `1920`).
    - `height`: Tinggi jendela dalam piksel (misal `720` atau `1080`).
    - `title`: Judul teks pada window title bar.
    """
    ...

def is_running() -> bool:
    """
    Mengembalikan `True` jika jendela masih aktif, dan `False` jika jendela ditutup pengguna.
    Gunakan sebagai kondisi perulangan utama game loop: `while screenGUI.is_running():`
    """
    ...

def close() -> None:
    """Menutup jendela desktop dan membebaskan alokasi memori grafis X11."""
    ...

def render(buffer: Any) -> None:
    """
    ### Presentasi Buffer ke Layar Monitor
    
    Mentransfer buffer kanvas (dari `GUIEngine.create_surface` atau buffer GPU)
    langsung ke display server via DMA zero-copy sub-milidetik.
    """
    ...

def poll_events() -> List[Dict[str, Any]]:
    """
    ### Polling Antrian Event Input
    
    Mengambil daftar seluruh event input (klik, tombol ditekan, resize, window close).
    Contoh:
    ```python
    for ev in screenGUI.poll_events():
        if ev.get("type") == "quit" or ev.get("key") == "Escape":
            screenGUI.close()
    ```
    """
    ...

def get_mouse_pos() -> Tuple[int, int]:
    """
    Mengembalikan koordinat kursor mouse saat ini dalam tuple `(x, y)` relatif terhadap jendela.
    """
    ...

def is_key_pressed(key_name: str) -> bool:
    """
    Mengecek apakah suatu tombol keyboard sedang ditekan secara real-time.
    Contoh key_name yang valid: `"Right"`, `"Left"`, `"Up"`, `"Down"`, `"Escape"`, `"Space"`, `"w"`, `"a"`, `"s"`, `"d"`, `"Return"`.
    """
    ...

def is_mouse_button_down(button_index: int = 1) -> bool:
    """
    Mengecek apakah tombol mouse sedang ditekan:
    - `1`: Klik Kiri
    - `2`: Klik Tengah (Scroll Wheel)
    - `3`: Klik Kanan
    """
    ...

def get_fps() -> float:
    """Mengembalikan nilai frame per detik (FPS) rata-rata saat ini."""
    ...

def get_cpu_usage() -> float:
    """Mengembalikan persentase penggunaan CPU host saat ini (0.0 s.d. 100.0%)."""
    ...

def get_gpu_usage() -> float:
    """Mengembalikan persentase pemanfaatan mesin render GPU saat ini."""
    ...

def get_render_time_ms() -> float:
    """Mengembalikan durasi waktu render frame dalam milidetik."""
    ...

def get_compression_ratio() -> float:
    """Mengembalikan rasio kompresi bandwidth framebuffer monitor saat ini."""
    ...

def get_compression_stats() -> Dict[str, Any]:
    """Mengembalikan rincian statistik kompresi tile framebuffer (clean, solid, rle, bandwidth saved)."""
    ...

def reset_compression_stats() -> None:
    """Mereset akumulator statistik kompresi layar."""
    ...

def compress_framebuffer(buffer: Any, width: int, height: int) -> Dict[str, Any]:
    """
    ### Mengompresi Buffer Tampilan Layar
    Mengompresi framebuffer menggunakan sistem tile 16x16 delta RLE hemat bandwidth.
    """
    ...

def get_dirty_percentage() -> float:
    """Mengembalikan persentase area tile framebuffer yang berubah pada frame terakhir (0.0 s.d. 100.0%)."""
    ...

def get_buffer_mode() -> str:
    """Mengembalikan mode presentasi buffer aktif ('X11 SHM Zero-Copy Double-Buffer' atau 'Heap Zero-Allocation Triple-Buffer')."""
    ...

def get_saved_bandwidth_mb() -> float:
    """Mengembalikan total Megabytes bandwidth scanout bus layar yang berhasil dihemat via delta kompresi."""
    ...

def force_redraw() -> None:
    """Memaksa render ulang penuh seluruh tile layar pada frame berikutnya."""
    ...

