import numpy as np
import threading

# Worker function to perform complex math on a numpy array
def worker_complex_math(thread_id):
    print("Thread started:", thread_id)
    # Generate arrays
    a = np.array([100, 200, 300, 400])
    b = np.array([2, 4, 6, 8])
    
    # Complex array math (add, mul, sub, div)
    c = a * b
    d = c + np.array([10, 20, 30, 40])
    e = d - b
    
    val1 = e[0]
    val2 = e[3]
    print("Thread", thread_id, "done. Result:", val1, val2)

# Spawn threads
t1: threading.Thread = threading.Thread(worker_complex_math, [1])
t2: threading.Thread = threading.Thread(worker_complex_math, [2])
t3: threading.Thread = threading.Thread(worker_complex_math, [3])

t1.start()
t2.start()
t3.start()

t1.join()
t2.join()
t3.join()

print("All threads finished complex numpy math!")
