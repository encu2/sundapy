import sys
from math import sin, cos, tan
from math import (
    asin,
    acos,
    atan,
)

# 1. Test multiple from-imports on one line
print("sin(0):", sin(0))
print("cos(0):", cos(0))
print("tan(0):", tan(0))
assert sin(0) == 0.0
assert cos(0) == 1.0

# 2. Test parenthesized multi-line from-imports
print("asin(0):", asin(0))
print("acos(1):", acos(1))
assert asin(0) == 0.0
assert acos(1) == 0.0

# 3. Test tuple unpacking in list comprehension
pairs = [(1, 2), (3, 4), (5, 6)]
sums = [a + b for a, b in pairs]
print("sums from tuple comp:", sums)
assert sums == [3, 7, 11]

# 4. Test tuple unpacking with condition
filtered = [a * b for a, b in pairs if a > 1]
print("filtered comp:", filtered)
assert filtered == [12, 30]

# 5. Test sys.path manipulation
orig_len = len(sys.path)
sys.path.insert(0, "/test/path/sundapy")
assert sys.path[0] == "/test/path/sundapy"
assert len(sys.path) == orig_len + 1
removed = sys.path.pop(0)
assert removed == "/test/path/sundapy"
assert len(sys.path) == orig_len
print("sys.path operations succeeded!")

print("ALL ADVANCED IMPORTS AND TUPLE COMPREHENSION TESTS PASSED!")
