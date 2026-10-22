#strict

# Test strict function stubs with ellipsis
def strict_stub1(x: i64) -> void:
    ...

def strict_stub2() -> void:
    ...

class StrictStubClass:
    def method_stub(self, val: f64) -> void:
        ...

# Test float dot literals in strict mode
def test_strict_floats() -> void:
    f1: f64 = .5
    f2: f64 = 10.
    f3: f64 = .125
    f4: f64 = .1e4
    f5: f64 = 2.e3
    
    sum_f: f64 = f1 + f2 + f3
    print("Strict float sum:", sum_f)
    assert sum_f == 10.625
    assert f4 == 1000.0
    assert f5 == 2000.0

def main() -> void:
    strict_stub1(42)
    strict_stub2()
    sc: StrictStubClass = StrictStubClass()
    sc.method_stub(3.14)
    test_strict_floats()
    print("All strict dot utility tests passed!")

main()
