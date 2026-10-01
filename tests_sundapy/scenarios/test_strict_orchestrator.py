import numpy as np
import threading
import time
import native_compute

# Modul ini tidak menggunakan #strict global karena harus menampung Dynamic (Numpy ABI).
def worker_heavy_compute(thread_id, base_val):
    print("Thread", thread_id, "memulai komputasi paralel untuk base", base_val)
    
    # 1. ZONA NUMPY (C-API dengan GIL yang dipinjam sekejap)
    arr1 = np.array([base_val, base_val+10, base_val+20, base_val+30])
    arr2 = np.array([2, 4, 6, 8])
    res_np = (arr1 * arr2) + (arr1 - arr2)
    val = res_np[0]
    
    # 2. ZONA NATIVE KASTA 1 (ZERO GIL)
    # Kita mendelegasikan beban ekstrem ke modul dengan Global #strict!
    native_sum = native_compute.heavy_loop()
        
    print("Thread", thread_id, "selesai! Numpy val:", val, "| Native Sum:", native_sum)

print("Starting strict multi-module threaded test...")
t1: threading.Thread = threading.Thread(worker_heavy_compute, [1, 100])
t2: threading.Thread = threading.Thread(worker_heavy_compute, [2, 200])
t3: threading.Thread = threading.Thread(worker_heavy_compute, [3, 300])
t4: threading.Thread = threading.Thread(worker_heavy_compute, [4, 400])

t1.start()
t2.start()
t3.start()
t4.start()

time.sleep(1.0)
print("Seluruh komputasi paralel strict selesai!")
