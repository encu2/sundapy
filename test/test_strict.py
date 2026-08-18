strict
print("--- [TEST] Fitur Mode Strict (Static Typing) ---")

print("Mendeklarasikan fungsi `add` dengan parameter wajib bertipe `int` dan kembalian `int`.")
def add(a: int, b: int) -> int:
    return a + b

print("Hasil pemanggilan fungsi add(5, 10) yang valid sesuai tipe:", add(5, 10))

print("\nTest Akses Tipe Undefined/None (SEHARUSNYA CRASH)...")
# Undefined behavior equivalent to None
x: undefined = None
print("Mencoba membaca variabel 'x' yang menyimpan nilai None...")
print("Hasil (jika lolos):", x)

print("Status: GAGAL CRASH! Jika Anda melihat teks ini, maka mode strict rusak!")
