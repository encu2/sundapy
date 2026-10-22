def stub_func():
    ...

def stub_func_args(a, b):
    ...

class StubClass:
    ...

class StubMethods:
    def method_a(self):
        ...
    def method_b(self, x):
        ...

def ret_ellipsis():
    return ...

def test_ellipsis_basic():
    e = ...
    print(e)
    print("assert e == ...:", e == ...)
    assert e == ...
    print("assert e is ...:", e is ...)
    assert e is ...
    print("assert ... == Ellipsis:", ... == Ellipsis)
    assert ... == Ellipsis
    print("assert ... is Ellipsis:", ... is Ellipsis)
    assert ... is Ellipsis
    print("bool(...):", bool(...))
    assert bool(...) == True
    print("str(...):", str(...))
    assert str(...) == "Ellipsis"
    print("type(...):", type(...))
    assert type(...) == "ellipsis"
    assert isinstance(..., "ellipsis")
    assert isinstance(..., "EllipsisType")

def test_ellipsis_stubs():
    res1 = stub_func()
    assert res1 == None
    res2 = stub_func_args(1, 2)
    assert res2 == None
    
    cls = StubClass()
    m = StubMethods()
    res3 = m.method_a()
    assert res3 == None
    res4 = m.method_b(10)
    assert res4 == None
    
    val = ret_ellipsis()
    assert val == ...
    print("All Ellipsis dynamic tests passed!")

test_ellipsis_basic()
test_ellipsis_stubs()
