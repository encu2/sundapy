import ffi

print("--- Testing High-Level FFI API ---")

# 1. Load dynamic library via ffi.load
lib = ffi.load("tests_sundapy/fixtures/libnative_math.so")
print("Library loaded successfully")

# 2. Bind integer functions
add_fn = lib.bind("add_i32", ffi.i32, [ffi.i32, ffi.i32])
res_add = add_fn(100, 250)
print(f"add_i32(100, 250) = {res_add}")
assert res_add == 350

mul_fn = lib.bind("mul_i64", ffi.i64, [ffi.i64, ffi.i64])
res_mul = mul_fn(12, 12)
print(f"mul_i64(12, 12) = {res_mul}")
assert res_mul == 144

# 3. Bind floating point functions
add_f = lib.bind("add_f64", ffi.f64, [ffi.f64, ffi.f64])
res_f = add_f(3.5, 2.5)
print(f"add_f64(3.5, 2.5) = {res_f}")
assert res_f == 6.0

sq_f = lib.bind("square_f64", ffi.f64, [ffi.f64])
res_sq = sq_f(4.0)
print(f"square_f64(4.0) = {res_sq}")
assert res_sq == 16.0

# 4. High-level Struct definition and instantiation
Point = ffi.create_struct("Point", [("x", ffi.f64), ("y", ffi.f64)])
p = Point(10.5, 20.25)
print(f"Point created: x={p.x}, y={p.y}")
assert p.x == 10.5
assert p.y == 20.25

# 5. Mutating struct fields
p.x = 42.0
print(f"Point after update: x={p.x}, y={p.y}")
assert p.x == 42.0

# 6. Struct size and address
sz = ffi.sizeof(Point)
print(f"sizeof(Point) = {sz}")
assert sz == 16

inst_sz = ffi.sizeof(p)
print(f"sizeof(p) = {inst_sz}")
assert inst_sz == 16

addr = ffi.addressof(p)
print(f"addressof(p) = {addr}")
assert addr != 0

# 7. Close library
lib.close()
print("High-Level FFI tests passed successfully!")
