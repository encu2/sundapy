import numpy as np
import threading
import time

def worker_heavy_compute(thread_id, base_val):
    print("Thread", thread_id, "memulai komputasi paralel untuk base", base_val)
    
    # 1. C-API Execution: Pinjam GIL sekilas saja.
    arr1 = np.array([base_val, base_val+10, base_val+20, base_val+30])
    arr2 = np.array([2, 4, 6, 8])
    res_np = (arr1 * arr2) + (arr1 - arr2)
    val = res_np[0]
    
    # 2. Native Zig Execution (Zero GIL): Eksekusi 5 juta operasi paralel
    native_sum = 0
    for i in range(5000000):
        native_sum = native_sum + 1
        
    print("Thread", thread_id, "selesai! Numpy val:", val, "| Native Sum:", native_sum)

print("Starting heavy multi-threaded test...")
t1: threading.Thread = threading.Thread(worker_heavy_compute, [1, 100])
t2: threading.Thread = threading.Thread(worker_heavy_compute, [2, 200])
t3: threading.Thread = threading.Thread(worker_heavy_compute, [3, 300])
t4: threading.Thread = threading.Thread(worker_heavy_compute, [4, 400])

t1.start()
t2.start()
t3.start()
t4.start()

time.sleep(1.0)

print("Seluruh komputasi paralel berat selesai!")
