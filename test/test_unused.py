strict
print("--- [TEST] Fitur Mode Strict (Deteksi Unused Variable Lokal) ---")

print("Mendefinisikan fungsi `my_func` yang mendeklarasikan `a` (digunakan) dan `b` (tidak digunakan)...")
def my_func():
    a: int = 10
    b: int = 20
    return a

print("Memanggil fungsi `my_func()` (SEHARUSNYA CRASH saat fungsi selesai)...")
my_func()

print("Status: GAGAL CRASH! Jika Anda melihat teks ini, maka mode strict rusak!")
