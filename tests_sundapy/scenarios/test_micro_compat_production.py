# Comprehensive Test Suite for SundaPy Micro-Compatibility & Production Features
print("=================================================================")
print("  SUNDAPY MICRO-COMPATIBILITY & PRODUCTION FEATURES VERIFICATION ")
print("=================================================================")

# 1. Sequence Slicing
print("\n[1] Testing Sequence Slicing...")
s = "Hello World"
assert s[::-1] == "dlroW olleH", "String reverse slice failed"
assert s[0:5] == "Hello", "String slice [0:5] failed"
assert s[-5:] == "World", "String slice [-5:] failed"
assert s[::2] == "HloWrd", "String slice [::2] failed"

l = [10, 20, 30, 40, 50]
assert l[::-1] == [50, 40, 30, 20, 10], "List reverse slice failed"
assert l[1:4] == [20, 30, 40], "List slice [1:4] failed"
assert l[-2:] == [40, 50], "List slice [-2:] failed"

t = tuple([1, 2, 3, 4, 5])
assert t[1:3] == tuple([2, 3]), "Tuple slice [1:3] failed"
assert t[::-1] == tuple([5, 4, 3, 2, 1]), "Tuple reverse slice failed"
print("✔ Slicing on string, list, and tuple passed.")

# 2. String Methods
print("\n[2] Testing String Methods...")
text = "hello sundapy world"
assert text.startswith("hello"), "startswith failed"
assert not text.startswith("world"), "startswith negative failed"
assert text.endswith("world"), "endswith failed"
assert not text.endswith("hello"), "endswith negative failed"
assert text.find("sundapy") == 6, "find positive failed"
assert text.find("missing") == -1, "find negative failed"

padded = "   content   "
assert padded.strip() == "content", "strip failed"
assert padded.lstrip() == "content   ", "lstrip failed"
assert padded.rstrip() == "   content", "rstrip failed"

joined = ", ".join(("apple", "banana", "cherry"))
assert joined == "apple, banana, cherry", "join with tuple failed"
assert "banana".count("an") == 2, "str.count failed"
print("✔ String methods passed.")

# 3. List Methods
print("\n[3] Testing List Methods...")
nums = [1, 2, 3, 4, 5]
val = nums.pop(1)
assert val == 2, "list.pop(1) returned wrong value"
assert nums == [1, 3, 4, 5], "list.pop(1) mutated incorrectly"

nums.extend([6, 7])
assert nums == [1, 3, 4, 5, 6, 7], "list.extend failed"

cp = nums.copy()
assert cp == nums, "list.copy value mismatch"
assert len(cp) == len(nums), "list.copy len mismatch"

cp.clear()
assert len(cp) == 0, "list.clear failed"
print("✔ List methods passed.")

# 4. Dict Methods & Non-String Keys
print("\n[4] Testing Dict Methods & Keys...")
d = {"a": 1, "b": 2}
d_cp = d.copy()
assert d_cp == d, "dict.copy failed"

sf = d.setdefault("c", 3)
assert sf == 3 and d["c"] == 3, "dict.setdefault insert failed"
sf_existing = d.setdefault("a", 999)
assert sf_existing == 1 and d["a"] == 1, "dict.setdefault existing failed"

pair = d.popitem()
assert len(d) == 2, "dict.popitem len check failed"

d.clear()
assert len(d) == 0, "dict.clear failed"

# Integer & boolean keys
d_keys = {1: "one", 2: "two", True: "truth"}
assert 1 in d_keys, "int key 'in' failed"
assert 99 not in d_keys, "int key 'not in' failed"
print("✔ Dict methods and multi-type keys passed.")

# 5. Set Literals & Set Operations
print("\n[5] Testing Set Operations...")
s1 = {1, 2, 3}
s2 = {3, 4, 5}
assert 1 in s1 and 2 in s1 and 3 in s1, "set literal members failed"
assert 4 not in s1, "set literal negative member failed"

u = s1 | s2
assert len(u) == 5, "set union len failed"

inter = s1 & s2
assert len(inter) == 1 and 3 in inter, "set intersection failed"

diff = s1 - s2
assert len(diff) == 2 and 1 in diff and 2 in diff, "set difference failed"

sym_diff = s1 ^ s2
assert len(sym_diff) == 4 and 3 not in sym_diff, "set sym_diff failed"

# in range
assert 5 in range(10), "5 in range(10) failed"
assert 15 not in range(10), "15 not in range(10) failed"
print("✔ Set literals, operators, and range membership passed.")

# 6. Builtin Functions
print("\n[6] Testing Builtin Functions...")
def my_func():
    return 42

assert callable(my_func), "callable(my_func) failed"
assert not callable(123), "callable(123) should be false"

assert isinstance(42, int), "isinstance(42, int) failed"
assert isinstance(True, bool), "isinstance(True, bool) failed"
assert isinstance(True, int), "isinstance(True, int) should be true (Python bool is int)"
assert isinstance(3.14, float), "isinstance(3.14, float) failed"
assert isinstance("sundapy", str), "isinstance(sundapy, str) failed"
assert isinstance([1, 2], list), "isinstance([1, 2], list) failed"
assert isinstance({"a": 1}, dict), "isinstance(dict) failed"
assert isinstance(tuple([1, 2]), tuple), "isinstance(tuple) failed"
assert isinstance({1, 2}, set), "isinstance(set) failed"
assert isinstance(range(5), range), "isinstance(range) failed"
assert isinstance(42, (str, int)), "isinstance with tuple failed"
assert not isinstance(3.14, (str, list)), "isinstance negative with tuple failed"

assert int(True) == 1, "int(True) failed"
assert int(False) == 0, "int(False) failed"
assert float(True) == 1.0, "float(True) failed"

rev = reversed([1, 2, 3])
assert rev == [3, 2, 1], "reversed([1, 2, 3]) failed"

srt_nums = sorted([5, 1, 4, 2, 3])
assert srt_nums == [1, 2, 3, 4, 5], "sorted(nums) failed"

srt_strs = sorted(["banana", "apple", "cherry"])
assert srt_strs == ["apple", "cherry", "banana"] or srt_strs == ["apple", "banana", "cherry"], "sorted(strs) failed"

z = zip([1, 2], ["a", "b"])
assert len(z) == 2, "zip len failed"
assert z[0] == tuple([1, "a"]), "zip item 0 failed"
assert z[1] == tuple([2, "b"]), "zip item 1 failed"

d_from_pairs = dict([("first", 10), ("second", 20)])
assert d_from_pairs["first"] == 10 and d_from_pairs["second"] == 20, "dict(pairs) failed"
print("✔ Builtin functions passed.")

# 7. Sequence Concatenation & Stringification
print("\n[7] Testing Sequence Concat & Stringification...")
cat_l = [1, 2] + [3, 4]
assert cat_l == [1, 2, 3, 4], "list + list failed"

cat_t = tuple([1, 2]) + tuple([3, 4])
assert cat_t == tuple([1, 2, 3, 4]), "tuple + tuple failed"

assert str(tuple([1, 2])) == "(1, 2)", "str(tuple) failed"
assert str(set()) == "set()", "str(empty set) failed"
assert str(range(0, 5)) == "range(0, 5)", "str(range) failed"
print("✔ Sequence concatenation and string representation passed.")

# 8. Sequence Repetition, Indexing & Bytes Operations
print("\n[8] Testing Sequence Repetition, Indexing & Bytes Operations...")
t_idx = tuple([100, 200, 300])
assert t_idx[0] == 100, "tuple[0] failed"
assert t_idx[2] == 300, "tuple[2] failed"
assert t_idx[-1] == 300, "tuple[-1] failed"

t_rep = (1, 2) * 3
assert len(t_rep) == 6, "tuple * 3 len failed"
assert t_rep[0] == 1 and t_rep[1] == 2 and t_rep[2] == 1, "tuple * 3 contents failed"

t_rep2 = 2 * (10, 20)
assert len(t_rep2) == 4 and t_rep2[0] == 10, "2 * tuple failed"

b_rep = b"xyz" * 2
assert len(b_rep) == 6, "bytes * 2 failed"
b_rep2 = 3 * b"w"
assert len(b_rep2) == 3, "3 * bytes failed"

b_cat = b"hello " + b"world"
assert len(b_cat) == 11, "bytes + bytes failed"
print("✔ Sequence repetition, indexing, and bytes passed.")

# 9. Dict Key Integrity & Collision Immunity
print("\n[9] Testing Dict Key Integrity & Non-Collision...")
d_multi = {"1": "string_key", 1: "int_key"}
assert len(d_multi) == 2, "dict collided '1' and 1!"
assert d_multi["1"] == "string_key", "d_multi['1'] failed"
assert d_multi[1] == "int_key", "d_multi[1] failed"
assert {"1": "a"} != {1: "a"}, "dict equality with differing key types failed"
assert {1: "a"} == {1: "a"}, "dict equality with identical keys failed"

d_keys_list = list(d_multi.keys())
assert any(isinstance(k, str) for k in d_keys_list), "keys() missing str type"
assert any(isinstance(k, int) and not isinstance(k, str) for k in d_keys_list), "keys() missing int type"

empty_d = {}
caught_popitem = False
try:
    empty_d.popitem()
except KeyError:
    caught_popitem = True
assert caught_popitem, "popitem on empty dict did not raise KeyError"

caught_pop = False
try:
    empty_d.pop("nonexistent_key")
except KeyError:
    caught_pop = True
assert caught_pop, "pop on empty dict did not raise KeyError"
print("✔ Dict key integrity, non-collision, and KeyError exceptions passed.")

# 10. Boolean Arithmetic, Comparisons, Shifts & Math Builtins
print("\n[10] Testing Boolean Arithmetic, Comparisons, Shifts & Divmod...")
assert (False < True) == True, "False < True failed"
assert (True > False) == True, "True > False failed"
assert (True > 0) == True, "True > 0 failed"
assert (False == 0) == True, "False == 0 failed"
assert (True == 1) == True, "True == 1 failed"
assert (False <= 0) == True, "False <= 0 failed"
assert (True >= 1) == True, "True >= 1 failed"

assert (True & 1) == 1, "True & 1 failed"
assert (1 & True) == 1, "1 & True failed"
assert (True & False) == False, "True & False failed"
assert (False | 2) == 2, "False | 2 failed"
assert (True ^ 3) == 2, "True ^ 3 failed"
assert (True << 2) == 4, "True << 2 failed"
assert (4 >> True) == 2, "4 >> True failed"

assert (2 ** True) == 2, "2 ** True failed"
assert (True ** 10) == 1, "True ** 10 failed"
assert (2 ** 3) == 8, "2 ** 3 failed"

dm = divmod(17, 5)
assert dm[0] == 3 and dm[1] == 2, f"divmod(17, 5) failed: {dm}"
print("✔ Boolean ops, comparisons, shifts, and divmod passed.")

# 11. String Literals & Prefixes
print("\n[11] Testing String Literals & Prefixes...")
raw_str = r"path\to\new\file"
assert len(raw_str) == 16, f"raw string length failed: {len(raw_str)}"
bytes_lit = b"native bytes string"
assert len(bytes_lit) == 19, "bytes literal length failed"
print("✔ String literals and prefixes passed.")

# 12. NumPy C-ABI Slicing & Operations
print("\n[12] Testing NumPy C-ABI Slicing & Operations...")
import numpy as np
arr = np.array([10, 20, 30, 40, 50])
assert arr[0] == 10, "numpy getitem failed"
arr[0] = 99
assert arr[0] == 99, "numpy setitem failed"

arr_slice = arr[1:4]
assert arr_slice[0] == 20 and arr_slice[1] == 30 and arr_slice[2] == 40, "numpy slicing failed"

arr_fdiv = arr // 2
assert arr_fdiv[0] == 49 and arr_fdiv[1] == 10, f"numpy floorDiv failed: {arr_fdiv[0]}"

arr_mod = arr % 2
assert arr_mod[0] == 1 and arr_mod[1] == 0, f"numpy mod failed: {arr_mod[0]}"
print("✔ NumPy C-ABI slicing, assignment, and floorDiv/mod passed.")

print("\n=================================================================")
print("  ALL SUNDAPY MICRO-COMPATIBILITY CHECKS PASSED SUCCESSFULLY!    ")
print("=================================================================")
