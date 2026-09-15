print("--- [TEST] Pustaka Sistem (Subprocess, Socket, Threading) ---")
import subprocess
import socket
import threading

print("\n1. Test Modul Subprocess:")
print("Akan menjalankan perintah shell: 'echo hello'")
res = subprocess.run(["echo", "hello"])
print("Hasil eksekusi:", res)

print("\n2. Test Modul Socket:")
print("Akan mencoba mendapatkan hostname dari sistem...")
host = socket.gethostname()
print("Hasil Hostname sistem ini adalah:", host)

print("\n3. Test Modul Threading:")
print("Akan mencoba menjalankan pekerjaan di thread latar belakang (asynchronous)...")
def worker():
    print("[Thread Background] Pekerja thread berhasil dieksekusi secara asinkron!")

threading.spawn(worker)

print("Memutar loop buang-waktu di thread utama untuk menunggu thread latar selesai...")
counter = 0
while counter < 100000:
    counter = counter + 1

print("\nStatus: Semua operasi sistem selesai dieksekusi.")
