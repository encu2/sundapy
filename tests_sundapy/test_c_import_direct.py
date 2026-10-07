#@link: m
import "math.h" as cmath
import "tests_sundapy/fixtures/sample_c_lib.h" as my_c

print("--- Testing Direct C Header Import ---")

# Standard C library math functions via @cImport
v_cos = cmath.cos(0.0)
print(f"cmath.cos(0.0) = {v_cos}")
assert v_cos == 1.0

v_sqrt = cmath.sqrt(49.0)
print(f"cmath.sqrt(49.0) = {v_sqrt}")
assert v_sqrt == 7.0

# User C library functions compiled directly with Zig
v_add = my_c.c_add(30, 12)
print(f"my_c.c_add(30, 12) = {v_add}")
assert v_add == 42

v_mul = my_c.c_multiply(2.5, 4.0)
print(f"my_c.c_multiply(2.5, 4.0) = {v_mul}")
assert v_mul == 10.0

print("Direct C Import tests passed successfully!")
