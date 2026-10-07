import ffi

print("--- Testing Low-Level FFI API ---")

# 1. Open dynamic library
lib = ffi.open("tests_sundapy/fixtures/libnative_math.so")
print("Library opened successfully")

# 2. Get symbol and call_raw
sym_add = lib.get_symbol("add_i32")
res_add = lib.call_raw(sym_add, 15, 27)
print(f"add_i32(15, 27) = {res_add}")
assert res_add == 42

sym_mul = lib.get_symbol("mul_i64")
res_mul = lib.call_raw(sym_mul, 7, 8)
print(f"mul_i64(7, 8) = {res_mul}")
assert res_mul == 56

# 3. String via raw memory and c_str
sym_strlen = lib.get_symbol("str_len")
msg_ptr = ffi.c_str("Hello SundaPy FFI!")
res_strlen = lib.call_raw(sym_strlen, msg_ptr)
print(f"str_len('Hello SundaPy FFI!') = {res_strlen}")
assert res_strlen == 18

# 4. Alloc, memcpy, cast, free
buf_size = 64
p1 = ffi.alloc(buf_size)
print(f"Allocated memory at: {p1}")
assert p1 != 0

sz = ffi.sizeof(ffi.i64)
print(f"sizeof(i64) = {sz}")
assert sz == 8

ffi.free(p1)
print("Memory freed successfully")

# 5. Close library
lib.close()
print("Low-Level FFI tests passed successfully!")
