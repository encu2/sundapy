# Test Bitwise Optimizations and Idiom Lowering in SundaPy

def test_even_odd():
    print("Testing even/odd lowering...")
    evens = [0, 2, 4, 100, -2, -100]
    odds = [1, 3, 5, 101, -1, -101]
    
    for x in evens:
        assert x % 2 == 0
        assert not (x % 2 != 0)
        assert not (x % 2 == 1)

    for x in odds:
        assert not (x % 2 == 0)
        assert x % 2 != 0
        assert x % 2 == 1
    print("even/odd OK")

def test_pow2_mod():
    print("Testing power-of-2 modulo lowering...")
    assert 15 % 8 == 7
    assert 16 % 8 == 0
    assert 17 % 8 == 1
    assert 255 % 64 == 63
    assert 1025 % 1024 == 1
    # Python negative modulo matches two's complement & (M - 1)
    assert (-1) % 8 == 7
    assert (-8) % 8 == 0
    assert (-9) % 8 == 7
    assert (-1) % 64 == 63
    print("power-of-2 modulo OK")

def test_pow2_mul_div():
    print("Testing power-of-2 multiplication and floor division...")
    x = 10
    assert x * 2 == 20
    assert 2 * x == 20
    assert x * 8 == 80
    assert 8 * x == 80
    assert x * 64 == 640
    
    assert 80 // 8 == 10
    assert 87 // 8 == 10
    assert (-16) // 8 == -2
    assert (-17) // 8 == -3
    print("power-of-2 mul/div OK")

def test_popcount():
    print("Testing popcount / bit_count lowering...")
    assert (0).bit_count() == 0
    assert (1).bit_count() == 1
    assert (7).bit_count() == 3
    assert (255).bit_count() == 8
    assert (1023).bit_count() == 10
    assert (-7).bit_count() == 3

    assert bin(0).count("1") == 0
    assert bin(1).count("1") == 1
    assert bin(7).count("1") == 3
    assert bin(255).count("1") == 8
    assert bin(1023).count("1") == 10
    print("popcount OK")

def test_bit_length():
    print("Testing bit_length lowering...")
    assert (0).bit_length() == 0
    assert (1).bit_length() == 1
    assert (2).bit_length() == 2
    assert (3).bit_length() == 2
    assert (4).bit_length() == 3
    assert (255).bit_length() == 8
    assert (256).bit_length() == 9
    assert (-4).bit_length() == 3
    print("bit_length OK")

def test_bit_rotation():
    print("Testing circular bit rotation lowering...")
    val = 0x1234567890ABCDEF
    rotl13 = (val << 13) | (val >> 51)
    rotr13 = (val >> 13) | (val << 51)
    assert rotl13 != val
    assert rotr13 != val
    assert ((rotl13 << 51) | (rotl13 >> 13)) == val
    print("bit rotation OK")

def test_bit_twiddling():
    print("Testing bit twiddling (isolate LSB, clear LSB, Hacker's Delight)...")
    # Isolate lowest set bit: x & -x and commutative -x & x
    assert (12 & -12) == 4
    assert (-12 & 12) == 4
    assert (40 & -40) == 8
    assert (1 & -1) == 1

    # Clear lowest set bit: x & (x - 1) and commutative (x - 1) & x
    assert (12 & (12 - 1)) == 8
    assert ((12 - 1) & 12) == 8
    assert (40 & (40 - 1)) == 32
    assert (16 & (16 - 1)) == 0  # power of 2 check

    # Clear trailing ones: x & (x + 1)
    assert (11 & (11 + 1)) == 8  # 1011b -> 1000b
    assert ((11 + 1) & 11) == 8

    # Isolate lowest zero: ~x & (x + 1)
    assert (~12 & (12 + 1)) == 1

    # Set lowest zero: x | (x + 1)
    assert (5 | (5 + 1)) == 7    # 101b -> 111b
    assert ((5 + 1) | 5) == 7

    # Turn on all bits below LSB: x | (x - 1)
    assert (12 | (12 - 1)) == 15  # 1100b -> 1111b
    assert ((12 - 1) | 12) == 15

    # LSB and trailing zeros mask: x ^ (x - 1)
    assert (12 ^ (12 - 1)) == 7   # 1100b ^ 1011b = 0111b
    assert ((12 - 1) ^ 12) == 7
    print("bit twiddling OK")

def test_native_bit_ops():
    print("Testing native bitwise ALU ops...")
    a = 0b1100
    b = 0b1010
    assert (a & b) == 0b1000
    assert (a | b) == 0b1110
    assert (a ^ b) == 0b0110
    assert (~0) == -1
    assert (~(-1)) == 0
    assert (a << 2) == 0b110000
    assert (a >> 2) == 0b0011
    print("native bitwise ops OK")

def main():
    test_even_odd()
    test_pow2_mod()
    test_pow2_mul_div()
    test_popcount()
    test_bit_length()
    test_bit_rotation()
    test_bit_twiddling()
    test_native_bit_ops()
    print("ALL BITWISE TESTS PASSED SUCCESSFULLY!")

main()
