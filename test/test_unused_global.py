strict
print("--- [TEST] Fitur Mode Strict (Deteksi Unused Variable Global) ---")

print("Mendeklarasikan variabel `a` = 1 di tingkat global, dan tidak pernah dipakai...")
a = 1

print("Eksekusi skrip selesai. Program SEHARUSNYA CRASH sebelum proses exit membuang peringatan unused variable...")
print("Status: GAGAL CRASH! Jika Anda melihat teks ini dan program exit 0, maka mode strict rusak!")
