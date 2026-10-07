# Test all Zig-style Idiom Lowerings in SundaPy

# 1. Enumerate and Zip
items = ["apple", "banana", "cherry"]
enum_res = []
for idx, val in enumerate(items):
    enum_res.append(f"{idx}:{val}")
assert enum_res == ["0:apple", "1:banana", "2:cherry"], f"enumerate failed: {enum_res}"

nums = [10, 20, 30]
zip_res = []
for k, v in zip(items, nums):
    zip_res.append(f"{k}={v}")
assert zip_res == ["apple=10", "banana=20", "cherry=30"], f"zip failed: {zip_res}"

# 2. Reduction Comprehensions (sum, any, all)
arr = [1, 2, 3, 4, 5]
s1 = sum(x for x in arr)
assert s1 == 15, f"sum gen failed: {s1}"

s2 = sum([x * 2 for x in arr if x > 2])
assert s2 == 24, f"sum comp with if failed: {s2}"

has_negative = any(x < 0 for x in arr)
assert has_negative == False, f"any negative failed: {has_negative}"

has_three = any(x == 3 for x in arr)
assert has_three == True, f"any three failed: {has_three}"

all_positive = all(x > 0 for x in arr)
assert all_positive == True, f"all positive failed: {all_positive}"

all_small = all(x < 4 for x in arr)
assert all_small == False, f"all small failed: {all_small}"

# 3. Clamping Idiom
v1 = -10
c1 = max(0, min(100, v1))
assert c1 == 0, f"clamp low failed: {c1}"

v2 = 50
c2 = max(0, min(100, v2))
assert c2 == 50, f"clamp mid failed: {c2}"

v3 = 150
c3 = max(0, min(100, v3))
assert c3 == 100, f"clamp high failed: {c3}"

# 4. Constant Membership Test (in / not in unrolled)
fruit = "banana"
assert fruit in ("apple", "banana", "cherry"), "in tuple failed"
assert fruit in ["apple", "banana", "cherry"], "in list failed"
assert fruit not in ["grape", "orange"], "not in list failed"
assert (fruit in []) == False, "in empty list failed"
assert (fruit not in []) == True, "not in empty list failed"

# 5. Chained Comparisons (0 <= x < 10)
x = 5
assert 0 <= x < 10, "chained cmp mid failed"
assert not (0 <= -1 < 10), "chained cmp low failed"
assert not (0 <= 15 < 10), "chained cmp high failed"

a = 1
b = 2
c = 3
assert a < b < c, "chained cmp 3 vars failed"

# 6. Multiple Assignment & Tuple Swap
val_a = "first"
val_b = "second"
val_a, val_b = val_b, val_a
assert val_a == "second", f"swap a failed: {val_a}"
assert val_b == "first", f"swap b failed: {val_b}"

m1, m2, m3 = 100, 200, 300
assert m1 == 100 and m2 == 200 and m3 == 300, f"multi assign failed: {m1}, {m2}, {m3}"

(p, q) = ("alpha", "beta")
(p, q) = (q, p)
assert p == "beta" and q == "alpha", f"parenthesized swap failed: {p}, {q}"

# 7. Multi-dimensional array lowering
grid = [[0.0] * 4 for _ in range(3)]
assert len(grid) == 3, "grid rows failed"
assert len(grid[0]) == 4, "grid cols failed"
grid[1][2] = 42.0
assert grid[1][2] == 42.0, "grid set failed"
assert grid[0][2] == 0.0, "grid aliasing check failed"

print("ALL ZIG IDIOM LOWERING TESTS PASSED!")
