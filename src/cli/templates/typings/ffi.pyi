"""
SundaPy FFI (Foreign Function Interface) Module Specification.
Menyediakan antarmuka low-level dan high-level untuk memanggil pustaka dinamis C/C++/Rust/Zig/Go (.so / .dll / .dylib)
serta manipulasi memori mentah berkinerja tinggi secara zero-cost.
"""

from typing import Any, Callable, Dict, List, Optional, Tuple, Type, Union

void: int = 0
i8: int = 1
i16: int = 2
i32: int = 3
i64: int = 4
u8: int = 5
u16: int = 6
u32: int = 7
u64: int = 8
f32: int = 9
f64: int = 10
bool: int = 11
c_str_type: int = 12
ptr: int = 13
struct: int = 14

RTLD_LOCAL: int = 0
RTLD_LAZY: int = 1
RTLD_NOW: int = 2
RTLD_GLOBAL: int = 256

class FfiStructInstance:
    """Instansi dari struct C yang dialokasikan di memori native."""
    def __getattr__(self, name: str) -> Any: ...
    def __setattr__(self, name: str, value: Any) -> None: ...

class FfiStructDesc:
    """Deskriptor tipe struct C yang dapat diinisiasi seperti kelas biasa."""
    def __call__(self, *args: Any) -> FfiStructInstance: ...

class FfiLib:
    """
    Representasi handle pustaka dinamis (shared library / dynlib) yang dibuka.
    Mendukung pemanggilan langsung berkecepatan tinggi baik via low-level pointer maupun high-level type binding.
    """
    def get_symbol(self, symbol_name: str) -> int: ...
    def call_raw(self, symbol_address: int, *args: Any) -> Any: ...
    def bind(self, symbol_name: str, return_type: int, param_types: List[int]) -> Callable[..., Any]: ...
    def close(self) -> None: ...

def open(path: str) -> FfiLib: ...
def load(path: str) -> FfiLib: ...
def alloc(size: int) -> int: ...
def free(ptr: int) -> None: ...
def memcpy(dst: int, src: int, size: int) -> None: ...
def c_str(s: str) -> int: ...
def cast(addr: int, type_id: int) -> Any: ...
def sizeof(val: Union[int, Any]) -> int: ...
def addressof(val: Any) -> int: ...
def create_struct(name: str, fields: List[Tuple[str, int]]) -> FfiStructDesc: ...
