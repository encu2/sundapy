#strict
import "tests_sundapy/fixtures/sample_zig_lib.zig" as my_zig
from "tests_sundapy/fixtures/sample_zig_lib.zig" import add_i32
from "tests_sundapy/fixtures/sample_zig_lib.zig" import Point
from "tests_sundapy/fixtures/sample_zig_lib.zig" import PI
from "tests_sundapy/fixtures/sample_zig_lib.zig" import ANSWER

import "tests_sundapy/fixtures/sample_c_lib.h" as my_c
from "tests_sundapy/fixtures/sample_c_lib.h" import c_add
from "tests_sundapy/fixtures/sample_c_lib.h" import c_multiply

import sample_zig_local
from sample_zig_local import local_double

def test_strict() -> void:
    a: i32 = 15
    b: i32 = 25
    r: i32 = my_zig.add_i32(a, b)
    print("strict my_zig.add_i32:")
    print(r)
    assert r == 40

    f1: f64 = 3.5
    f2: f64 = 2.0
    fr: f64 = my_zig.multiply_f64(f1, f2)
    print("strict my_zig.multiply_f64:")
    print(fr)
    assert fr == 7.0

    r2: i32 = add_i32(100, 50)
    print("strict add_i32:")
    print(r2)
    assert r2 == 150

    p: Point = Point.init(10, 20)
    ps: i32 = p.sum()
    print("strict Point.sum:")
    print(ps)
    assert ps == 30

    p_fallible: i32 = p.fallible_sum()
    print("strict Point.fallible_sum:")
    print(p_fallible)
    assert p_fallible == 30

    neg_p: Point = Point.init(-5, 15)
    caught: bool = False
    try:
        bad: i32 = neg_p.fallible_sum()
    except:
        caught = True
    assert caught == True

    ca: i32 = my_c.c_add(5, 7)
    print("strict my_c.c_add:")
    print(ca)
    assert ca == 12

    ca2: i32 = c_add(30, 40)
    print("strict c_add:")
    print(ca2)
    assert ca2 == 70

    ld: i32 = local_double(25)
    print("strict local_double:")
    print(ld)
    assert ld == 50

    print("ALL STRICT ZIG & C TESTS PASSED")

test_strict()
