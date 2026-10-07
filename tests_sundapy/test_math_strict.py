#strict
import math

def test_math_intrinsics() -> void:
    # Roots and Powers
    s1: float = math.sqrt(16.0)
    assert s1 == 4.0

    s2: float = math.sqrt(25)
    assert s2 == 5.0

    p1: float = math.pow(2.0, 3.0)
    assert p1 == 8.0

    # Trig functions
    c1: float = math.cos(0.0)
    assert c1 == 1.0

    s3: float = math.sin(0.0)
    assert s3 == 0.0

    # Rounding & Float ops
    f1: float = math.floor(3.7)
    assert f1 == 3.0

    c2: float = math.ceil(3.2)
    assert c2 == 4.0

    t1: float = math.trunc(3.9)
    assert t1 == 3.0

    ab1: float = math.fabs(-42.5)
    assert ab1 == 42.5

    h1: float = math.hypot(3.0, 4.0)
    assert h1 == 5.0

    # Constants
    pi_val: float = math.pi
    assert pi_val > 3.1415

    e_val: float = math.e
    assert e_val > 2.718

    # Angles
    rad: float = math.radians(180.0)
    assert rad == math.pi

    deg: float = math.degrees(math.pi)
    assert deg == 180.0

    # Checks
    assert math.isfinite(42.0)
    assert not math.isinf(42.0)

test_math_intrinsics()
print("STRICT MATH INTRINSICS TESTS PASSED!")
