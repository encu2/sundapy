"""
SundaPy Native HTTP/HTTPS Client Module.
Menggunakan client HTTP/TLS native Zig untuk komunikasi web tanpa dependensi luar.
"""

from typing import Any, Dict, Optional

class Response:
    """Objek hasil respons HTTP dari server."""
    status_code: int
    text: str
    
    def json(self) -> Dict[str, Any]:
        """Mengurai teks respons sebagai dictionary JSON."""
        ...

def get(url: str, headers: Optional[Dict[str, str]] = None) -> Response:
    """
    Mengirimkan HTTP GET request ke URL target.
    
    **Contoh:**
    ```python
    res = requests.get("https://httpbin.org/get")
    print("Status:", res.status_code)
    print("Body  :", res.text)
    ```
    """
    ...

def post(url: str, data: Optional[Any] = None, json: Optional[Dict[str, Any]] = None, headers: Optional[Dict[str, str]] = None) -> Response:
    """
    Mengirimkan HTTP POST request dengan payload data teks atau JSON.
    """
    ...
