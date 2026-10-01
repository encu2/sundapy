import numpy as np
import native_math
import threading
import time

def worker(thread_id, base_val):
    print("Thread", thread_id, "started")
    arr1 = np.array([base_val, base_val+10])
    arr2 = np.array([2, 4])
    res_np = (arr1 * arr2)
    val = res_np[0]
    
    native_sum = native_math.heavy_loop()
    print("Thread", thread_id, "done. Numpy:", val, "Native:", native_sum)

t1: threading.Thread = threading.Thread(worker, [1, 100])
t1.start()
time.sleep(0.5)
