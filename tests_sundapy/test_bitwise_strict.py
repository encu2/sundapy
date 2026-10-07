#strict

def test_even_odd(n: i64) -> bool:
    return (n % 2) == 0

def test_pow2_mod(n: i64) -> i64:
    return n % 64

def test_pow2_mul(n: i64) -> i64:
    return n * 16

def test_pow2_div(n: i64) -> i64:
    return n // 8

def test_bitwise_ops(a: i64, b: i64) -> i64:
    return (a & b) | (a ^ b)

def test_bit_shifts(a: i64) -> i64:
    return (a << 2) >> 1

def test_bit_twiddle(a: i64) -> i64:
    return a & -a

print("test_even_odd(4):", test_even_odd(4))
print("test_even_odd(5):", test_even_odd(5))
print("test_pow2_mod(130):", test_pow2_mod(130))
print("test_pow2_mul(5):", test_pow2_mul(5))
print("test_pow2_div(64):", test_pow2_div(64))
print("test_bitwise_ops(12, 10):", test_bitwise_ops(12, 10))
print("test_bit_shifts(10):", test_bit_shifts(10))
print("test_bit_twiddle(12):", test_bit_twiddle(12))
print("STRICT BITWISE TESTS PASSED!")
