import "tests_sundapy/fixtures/sample_zig_lib.zig" as my_zig
from "tests_sundapy/fixtures/sample_zig_lib.zig" import add_i32
from "tests_sundapy/fixtures/sample_zig_lib.zig" import Point
from "tests_sundapy/fixtures/sample_zig_lib.zig" import PI
from "tests_sundapy/fixtures/sample_zig_lib.zig" import ANSWER
from "tests_sundapy/fixtures/sample_zig_lib.zig" import GREETING
from "tests_sundapy/fixtures/sample_zig_lib.zig" import multiply_f64
from "tests_sundapy/fixtures/sample_zig_lib.zig" import get_message

import "tests_sundapy/fixtures/sample_c_lib.h" as my_c
from "tests_sundapy/fixtures/sample_c_lib.h" import c_add
from "tests_sundapy/fixtures/sample_c_lib.h" import c_multiply
from "tests_sundapy/fixtures/sample_c_lib.h" import C_MAGIC_CONST

import sample_zig_local
from sample_zig_local import local_double
from sample_zig_local import LOCAL_VAL

# 1. Zig module calls and constants via alias
res1 = my_zig.add_i32(10, 25)
print("my_zig.add_i32:", res1)
assert res1 == 35

prod1 = my_zig.multiply_f64(2.5, 4.0)
print("my_zig.multiply_f64:", prod1)
assert prod1 == 10.0

print("my_zig.ANSWER:", my_zig.ANSWER)
assert my_zig.ANSWER == 42

print("my_zig.GREETING:", my_zig.GREETING)

# Zig struct instantiation and method call
pt1 = my_zig.Point.init(15, 27)
s1 = pt1.sum()
print("pt1.sum:", s1)
assert s1 == 42

# 2. Zig functions and types via from-import
res2 = add_i32(100, 200)
print("add_i32:", res2)
assert res2 == 300

prod2 = multiply_f64(3.0, 7.0)
print("multiply_f64:", prod2)
assert prod2 == 21.0

print("ANSWER:", ANSWER)
assert ANSWER == 42

msg = get_message()
print("get_message:", msg)

pt2 = Point.init(50, 60)
s2 = pt2.sum()
print("pt2.sum:", s2)
assert s2 == 110

# 3. Companion C import
c_res1 = my_c.c_add(20, 30)
print("my_c.c_add:", c_res1)
assert c_res1 == 50

c_res2 = c_add(40, 60)
print("c_add:", c_res2)
assert c_res2 == 100

c_prod = c_multiply(4.0, 5.0)
print("c_multiply:", c_prod)
assert c_prod == 20.0

print("C_MAGIC_CONST:", C_MAGIC_CONST)
assert C_MAGIC_CONST == 999

# 4. Local Zig module import without quotes
loc_res = sample_zig_local.local_double(21)
print("sample_zig_local.local_double:", loc_res)
assert loc_res == 42

loc_from = local_double(50)
print("local_double:", loc_from)
assert loc_from == 100

print("LOCAL_VAL:", LOCAL_VAL)
assert LOCAL_VAL == 12345

# 5. Nested Zig struct and fallible method tests
v1 = my_zig.Geometry.Vector2.init(3, 4)
v2 = my_zig.Geometry.Vector2.init(5, 6)
v_dot = v1.dot(v2)
print("v1.dot(v2):", v_dot)
assert v_dot == 39

pt3: Point = my_zig.create_point(7, 8)
s3 = pt3.sum()
print("pt3.sum:", s3)
assert s3 == 15

fsum = pt1.fallible_sum()
print("pt1.fallible_sum:", fsum)
assert fsum == 42

neg_pt: Point = Point.init(-10, 20)
err_caught = False
try:
    bad_sum = neg_pt.fallible_sum()
except:
    err_caught = True
print("err_caught:", err_caught)
assert err_caught == True

print("ALL ZIG & C DIRECT IMPORT TESTS PASSED")
