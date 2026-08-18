print("--- [TEST] Argument Script (sys.argv) ---")
import sys

print("Pesan: Hello from Python-in-Zig!")
print("Jumlah argumen yang dilewatkan ke dalam script ini adalah:", len(sys.argv))
print("Daftar Argumen:")
for i in sys.argv:
    print("->", i)
