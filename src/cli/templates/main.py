#strict
import time

def hitung_tambah(a: i64, b: i64) -> i64:
    # Contoh fungsi komputasi dengan hardware static typing murni.
    # Dieksekusi langsung di CPU register tanpa alokasi heap.
    return a + b

def main() -> void:
    print("========================================")
    print("      Selamat Datang di SundaPy!       ")
    print("========================================")
    
    # Pengukuran waktu komputasi presisi nanodetik
    mulai: i64 = time.time_ns()
    hasil: i64 = hitung_tambah(1000, 2500)
    durasi: i64 = time.time_ns() - mulai
    
    print("Hasil Perhitungan :", hasil)
    print("Waktu Eksekusi    :", durasi, "ns")

main()

# ==============================================================================
# PANDUAN CEPAT PENGEMBANGAN SUNDAPY:
# ------------------------------------------------------------------------------
# 1. Jalankan script ini:
#    $ sundapy main.py
#
# 2. Jalankan dengan optimasi maksimal (ReleaseFast / -O3):
#    $ sundapy --fast main.py
#
# 3. Kompilasi menjadi binary executable mandiri (C-like standalone):
#    $ sundapy --build --outname aplikasi_saya main.py
#
# 4. Shortcut VSCode Task:
#    Tekan Ctrl + Shift + B untuk menjalankan program secara instan!
#
# 5. Template Boilerplate Instan (Ketik prefix lalu tekan Tab):
#    - sunda-strict    : Template komputasi numerik berkecepatan tinggi
#    - sunda-gui       : Template aplikasi desktop X11 60 FPS
#    - sunda-canvas    : Template menggambar 2D kanvas grafis (GUIEngine)
#    - sunda-gpu-field : Template array multidimensi di GPU VRAM (HLA)
#    - sunda-gpu-arena : Template fast VRAM sub-allocator (LLA)
#    - sunda-bench     : Template microbenchmark presisi nanodetik
#    - sunda-tcp-server: Template server soket TCP non-blocking
#
# 6. Dokumentasi Lengkap:
#    Buka file 'SUNDAPY_GUIDE.md' untuk melihat kamus lengkap API dan Decision Matrix.
# ==============================================================================
