"""
SundaPy Asynchronous Event Loop & Coroutines Module.
Menyediakan concurrency non-blocking untuk tugas I/O bound.
"""

from typing import Any, Coroutine, TypeVar

T = TypeVar("T")

class Task:
    """Representasi tugas coroutine asinkron."""
    def __await__(self) -> Any:
        ...

def run(coro: Coroutine[Any, Any, T]) -> T:
    """
    Menjalankan event loop utama dan mengeksekusi coroutine hingga selesai.
    """
    ...

def create_task(coro: Coroutine[Any, Any, Any]) -> Task:
    """
    Menjadwalkan coroutine untuk dieksekusi secara asinkron di event loop.
    """
    ...

async def sleep(delay: float) -> None:
    """
    Jeda asinkron non-blocking tanpa menghentikan thread utama.
    """
    ...
