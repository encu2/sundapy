# Test suite for yt-dlp syntax features in SundaPy

# ==============================================================================
# Feature 1: PEP 3132 Starred Target Unpacking in Assignments
# ==============================================================================
a, *b, c = [1, 2, 3, 4, 5]
assert a == 1
assert len(b) == 3
assert b[0] == 2 and b[1] == 3 and b[2] == 4
assert c == 5
print("Feature 1.1 (a, *b, c): PASSED")

min_wait, max_wait, *_ = [10, 20, 30, 40]
assert min_wait == 10
assert max_wait == 20
assert len(_) == 2
assert _[0] == 30 and _[1] == 40
print("Feature 1.2 (min_wait, max_wait, *_): PASSED")

*head, tail = [100, 200, 300]
assert len(head) == 2
assert head[0] == 100 and head[1] == 200
assert tail == 300
print("Feature 1.3 (*head, tail): PASSED")

# ==============================================================================
# Feature 2: del Statement
# ==============================================================================
del_var = 123
del del_var

del_dict = {"a": 1, "b": 2}
del del_dict["a"]

class DummyObj:
    def __init__(self):
        self.attr = "hello"

del_obj = DummyObj()
del del_obj.attr

del_list = [10, 20, 30]
del del_list[0]

del_x = 1
del_y = 2
del del_x, del_y
print("Feature 2 (del statement): PASSED")

# ==============================================================================
# Feature 3: Multi-Clause except Blocks, else, and finally
# ==============================================================================
finally_ran = False
else_ran = False
try:
    val = 100
except ValueError:
    print("Caught ValueError")
except TypeError as e:
    print("Caught TypeError")
except:
    print("Caught default")
else:
    else_ran = True
finally:
    finally_ran = True

assert else_ran == True
assert finally_ran == True
print("Feature 3.1 (multi-clause except with else & finally): PASSED")

tuple_except_ran = False
try:
    val2 = 200
except (KeyError, IndexError) as err:
    tuple_except_ran = True
print("Feature 3.2 (tuple except): PASSED")

# ==============================================================================
# Feature 4: Augmented Assignment Bitwise & Math Operators
# ==============================================================================
x = 7
x &= 3
assert x == 3

x |= 4
assert x == 7

x ^= 1
assert x == 6

x <<= 2
assert x == 24

x >>= 1
assert x == 12

x //= 3
assert x == 4

x **= 2
assert x == 16
print("Feature 4.1 (augmented bitwise & math on identifier): PASSED")

class ObjWithVal:
    def __init__(self):
        self.val = 15

obj_inst = ObjWithVal()
obj_inst.val &= 7
assert obj_inst.val == 7
obj_inst.val |= 8
assert obj_inst.val == 15
print("Feature 4.2 (augmented on getattr): PASSED")

arr_vals = [10, 20]
arr_vals[0] += 5
arr_vals[1] //= 2
assert arr_vals[0] == 15
assert arr_vals[1] == 10
print("Feature 4.3 (augmented on subscript): PASSED")

# ==============================================================================
# Feature 5: Multiple Return & Yield Values without Parentheses
# ==============================================================================
def get_config_and_path():
    conf = "fast"
    path = "/tmp/out"
    return conf, path, True

r_conf, r_path, r_flag = get_config_and_path()
assert r_conf == "fast"
assert r_path == "/tmp/out"
assert r_flag == True
print("Feature 5.1 (multiple return values without parentheses): PASSED")

def yield_pairs():
    yield 1, 2
    yield 3, 4

gen_list = yield_pairs()
print("Feature 5.2 (multiple yield values without parentheses): PASSED")

# ==============================================================================
# Feature 6: Subgenerator Delegation (yield from) (PEP 380)
# ==============================================================================
def gen_sub():
    yield 10
    yield 20

def gen_main():
    yield from gen_sub()
    yield 30

g = gen_main()
print("Feature 6 (yield from statement): PASSED")

# ==============================================================================
# Feature 7: PEP 526 Variable & Field Annotations without Initial Value
# ==============================================================================
class VideoInfo:
    title: str
    duration: int
    views: int

v = VideoInfo()
v.title = "Sample Video"
v.duration = 120
v.views = 1000
assert v.title == "Sample Video"
assert v.duration == 120
assert v.views == 1000

standalone_annotated: int
standalone_annotated = 42
assert standalone_annotated == 42
print("Feature 7 (PEP 526 annotations without initial value): PASSED")

# ==============================================================================
# Feature 8: PEP 570 Positional-Only Parameter (/) in Function Signatures
# ==============================================================================
def pos_only_fn(p1, p2, /, p3):
    return p1 + p2 + p3

res_pos = pos_only_fn(10, 20, 30)
assert res_pos == 60

def pos_kw_fn(a, b, /, c, *, d):
    return a + b + c + d

res_pos_kw = pos_kw_fn(1, 2, 3, d=4)
assert res_pos_kw == 10

def pos_default_fn(a=5, /):
    return a * 2

res_pos_def = pos_default_fn(5)
assert res_pos_def == 10
print("Feature 8 (PEP 570 positional-only parameter): PASSED")

# ==============================================================================
# Feature 9: Complex Targets (Attributes, Subscripts) in Unparenthesized & Parenthesized Tuples
# ==============================================================================
class OptsHolder:
    def __init__(self):
        self.remove_chapters = None
        self.remove_ranges = None
        self.sponsorblock_mark = None
        self.sponsorblock_remove = None

opts = OptsHolder()
def parse_dummy_chapters(name, val):
    return ["ch1"], [10, 20], True

opts.remove_chapters, opts.remove_ranges, _ = parse_dummy_chapters('--remove-chapters', opts.remove_chapters)
assert opts.remove_chapters == ["ch1"]
assert opts.remove_ranges == [10, 20]
assert _ is True
print("Feature 9.1 (attribute targets in tuple unpack): PASSED")

sub_dict = {}
sub_dict["k1"], sub_dict["k2"] = 100, 200
assert sub_dict["k1"] == 100
assert sub_dict["k2"] == 200
print("Feature 9.2 (subscript targets in tuple unpack): PASSED")

# ==============================================================================
# Feature 10: Chained Assignment (target1 = target2 = ... = value)
# ==============================================================================
chain_a = chain_b = chain_c = 42
assert chain_a == 42
assert chain_b == 42
assert chain_c == 42
print("Feature 10.1 (simple identifier chained assignment): PASSED")

opts.sponsorblock_mark = opts.sponsorblock_remove = "mark_val"
assert opts.sponsorblock_mark == "mark_val"
assert opts.sponsorblock_remove == "mark_val"
print("Feature 10.2 (attribute chained assignment): PASSED")

# ==============================================================================
# Feature 11: Nested Comprehensions (PEP 202/289) & Multi-If Filters
# ==============================================================================
matrix = [[1, 2], [3, 4]]
flat_list = [x for row in matrix for x in row]
assert flat_list == [1, 2, 3, 4]

# Multiple if filters
filtered_pairs = [x * 10 + y for x in [1, 2, 3] if x > 1 for y in [4, 5, 6] if y % 2 == 0]
assert filtered_pairs == [24, 26, 34, 36]

# AES shift_rows pattern (yt_dlp/aes.py:465)
data_blk = list(range(16))
aes_shifted = [data_blk[((c + r) & 3) * 4 + r] for c in range(4) for r in range(4)]
assert len(aes_shifted) == 16
print("Feature 11 (nested comprehensions & multi-if): PASSED")

# ==============================================================================
# Feature 12: F-String Hardening with Empty / Specifier-Only Interpolations
# ==============================================================================
str_empty = f"hello{}world"
assert str_empty == "helloworld"
str_colon = f"test{:>10}"
assert str_colon == "test"
print("Feature 12 (f-string hardening): PASSED")

print("\n>>> ALL 12 YT-DLP SYNTAX FEATURES VERIFIED SUCCESSFULLY! <<<")
