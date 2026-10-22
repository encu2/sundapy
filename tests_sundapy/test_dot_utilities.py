# Test Suite: Dot Utilities in SundaPy
# Covering:
# 1. Numeric float literals with leading/trailing dots (.5, 10., .1e5, 10.e2)
# 2. Ellipsis literal (...) in expressions, function stubs, type annotations, and indexing
# 3. Relative imports (from . import ..., from .mod import ..., from ..parent import ...)

# 1. Numeric float literals
f1 = .5
print("Leading dot .5:", f1)
assert f1 == 0.5

f2 = 10.
print("Trailing dot 10.:", f2)
assert f2 == 10.0

f3 = .125
print("Leading dot .125:", f3)
assert f3 == 0.125

f4 = .1e4
print("Leading dot with exponent .1e4:", f4)
assert f4 == 1000.0

f5 = 2.e3
print("Trailing dot with exponent 2.e3:", f5)
assert f5 == 2000.0

f6 = .5_000
print("Leading dot with underscore .5_000:", f6)
assert f6 == 0.5

f_sum = .5 + 10. + .25
print("Float arithmetic with dot literals:", f_sum)
assert f_sum == 10.75

# 2. Ellipsis (...) in expressions
el = ...
print("Ellipsis expression:", el)
assert el == Ellipsis
assert el is Ellipsis
assert bool(...) == True

# Type and isinstance
print("type(...):", type(...))
assert type(...) == "ellipsis"
assert isinstance(..., ellipsis)

# 3. Ellipsis in function stubs
def stub_func1():
    ...

def stub_func2(): ...

assert stub_func1() is None
assert stub_func2() is None
print("Function stubs executed successfully.")

# 4. Ellipsis in class stubs
class EmptyStub:
    ...

inst = EmptyStub()
print("Class stub instantiated successfully.")

# 5. Ellipsis in type annotations
annotated_var: ... = 42
print("Annotated var:", annotated_var)
assert annotated_var == 42

def annotated_func(val: ...) -> ...:
    return val

ret_val = annotated_func("test")
assert ret_val == "test"
print("Annotated func returned:", ret_val)

# 6. Ellipsis in indexing
d = {...: "found"}
assert d[...] == "found"
print("Dict with ellipsis key:", d[...])

# 7. Composite ellipsis dictionary indexing
d_comp = {}
d_comp[..., 0] = 42
d_comp[1, ...] = 100
assert d_comp[..., 0] == 42
assert d_comp[1, ...] == 100
print("Composite ellipsis keys passed:", d_comp[..., 0], d_comp[1, ...])

# 8. Trailing dot with attribute access
f_real = 10..real
f_real_paren = (10.).real
f_imag = 10..imag
assert f_real == 10.0
assert f_real_paren == 10.0
assert f_imag == 0.0
print("Trailing dot attribute access passed:", f_real, f_real_paren, f_imag)

print("All dot utility tests passed successfully!")
