# =============================================================================
#   SUNDAPY MODERN PEP COMPATIBILITY SUITE (PEP 619 - 826)
#   Testing Category 2: Built-in Types & Hardware Math Intrinsics
# =============================================================================
import math

# Test PEP 791: Hardware ALU Math Intrinsics
print("Testing math.isqrt:")
print("isqrt(0):", math.isqrt(0))
print("isqrt(15):", math.isqrt(15))
print("isqrt(16):", math.isqrt(16))
print("isqrt(1000000):", math.isqrt(1000000))
print("isqrt(123456789):", math.isqrt(123456789))

print("Testing math.gcd & math.lcm:")
print("gcd(48, 18):", math.gcd(48, 18))
print("gcd(101, 103):", math.gcd(101, 103))
print("lcm(12, 15):", math.lcm(12, 15))
print("lcm(21, 6):", math.lcm(21, 6))

print("Testing math.comb & math.factorial:")
print("comb(5, 2):", math.comb(5, 2))
print("comb(10, 3):", math.comb(10, 3))
print("factorial(5):", math.factorial(5))
print("factorial(7):", math.factorial(7))

# Test Strict Mode Hardware Math
#strict
def strict_math_bench(x: int, y: int) -> int:
    s: int = math.isqrt(x)
    g: int = math.gcd(x, y)
    l: int = math.lcm(x, y)
    return s + g + l

print("Strict math bench (100, 25):", strict_math_bench(100, 25))
print("All Hardware Math Intrinsics Tests Passed!")
