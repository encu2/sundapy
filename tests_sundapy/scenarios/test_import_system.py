#strict

import submodule
import submodule.my_module as my_module
import error

def local_import_test(name: str) -> void:
    import submodule as local_sub
    local_sub.greet(name)

def test_imports() -> void:
    submodule.greet("World")
    
    x: int = my_module.do_magic(10)
    print(x)
    
    msg: str = error.fail_gracefully()
    print(msg)
    
    local_import_test("Local")

test_imports()
