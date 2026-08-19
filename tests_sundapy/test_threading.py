import threading
import time

def my_worker(num):
    print("Worker", num, "started")
    time.sleep(0.1)
    print("Worker", num, "finished")

t1: threading.Thread = threading.Thread(my_worker, [1])
t2: threading.Thread = threading.Thread(my_worker, [2])
t1.start()
t2.start()
t1.join()
t2.join()
print("All threads done")
