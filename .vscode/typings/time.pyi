"""
SundaPy Native Time & High-Resolution Clock Module.
Menyediakan pengukuran waktu berpresisi nanodetik dan fungsi jeda thread.
"""

def time_ns() -> int:
    """
    ### Timestamp Jam Monotonik / Realtime dalam Nanodetik
    
    Mengembalikan waktu Linux `clock_gettime` dalam satuan nanodetik (1 detik = 1.000.000.000 ns).
    Sangat ideal untuk benchmark mikro komputasi hardware.
    
    **Contoh:**
    ```python
    t0 = time.time_ns()
    operasi_berat()
    durasi_ns = time.time_ns() - t0
    ```
    """
    ...

def time() -> float:
    """Mengembalikan waktu epoch saat ini dalam detik desimal (`float`)."""
    ...

def sleep(seconds: float) -> None:
    """
    Menidurkan eksekusi thread saat ini selama `seconds` detik.
    Memanfaatkan syscall Linux `nanosleep` sub-milidetik.
    """
    ...
