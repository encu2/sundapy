"""
SundaPy Native Multi-Core Threading Module.
Di SundaPy, thread dieksekusi secara nyata di multi-core prosesor (PARALEL SEJATI)
karena SundaPy bebas dari Global Interpreter Lock (GIL).
"""

from typing import Any, Callable, Optional, Tuple

class Lock:
    """Mutex lock untuk sinkronisasi akses data bersama antar thread."""
    def acquire(self, blocking: bool = True) -> bool:
        """Mengunci mutex."""
        ...
        
    def release(self) -> None:
        """Melepaskan kunci mutex."""
        ...

class Thread:
    """Thread native sistem operasi Linux."""
    def __init__(self, target: Optional[Callable] = None, args: Tuple[Any, ...] = (), kwargs: Optional[dict] = None):
        ...
        
    def start(self) -> None:
        """Menjalankan thread secara paralel di latar belakang."""
        ...
        
    def join(self) -> None:
        """Menunggu thread selesai sebelum melanjutkan kode utama."""
        ...
