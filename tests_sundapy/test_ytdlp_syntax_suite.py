# Test suite for yt-dlp syntax features:
# Starred unpacking, del statement, multi-clause except,
# bitwise/advanced augmented assignments, multiple returns,
# subgenerator yield from, and standalone annotations.

def test_starred_unpacking():
    print("Testing PEP 3132 Starred Target Unpacking...")
    # Tail slice
    min_wait, max_wait, *rest = [5, 10, 15, 20, 25]
    assert min_wait == 5
    assert max_wait == 10
    assert len(rest) == 3
    assert rest[0] == 15
    assert rest[1] == 20
    assert rest[2] == 25

    # Middle slice
    a, *b, c = [1, 2, 3, 4, 5]
    assert a == 1
    assert len(b) == 3
    assert b[0] == 2
    assert b[1] == 3
    assert b[2] == 4
    assert c == 5

    # Head slice
    *head, tail = [100, 200, 300]
    assert len(head) == 2
    assert head[0] == 100
    assert head[1] == 200
    assert tail == 300

    # Empty middle slice
    x, *mid, y = [10, 20]
    assert x == 10
    assert len(mid) == 0
    assert y == 20

    # Starred underscore wildcard
    p, q, *_ = [7, 8, 9, 10]
    assert p == 7
    assert q == 8

    # Single starred target with trailing comma
    *only_star, = [1, 2, 3]
    assert len(only_star) == 3
    assert only_star[0] == 1
    assert only_star[1] == 2
    assert only_star[2] == 3

    # Starred target into dictionary subscript
    d_star = {}
    [a_sub, *d_star["items"], c_sub] = [10, 20, 30, 40]
    assert a_sub == 10
    assert len(d_star["items"]) == 2
    assert d_star["items"][0] == 20
    assert d_star["items"][1] == 30
    assert c_sub == 40

    # Unbracketed subscript target
    d_nobracket = {}
    u_a, *d_nobracket["sub"], u_c = [100, 200, 300, 400]
    assert u_a == 100
    assert len(d_nobracket["sub"]) == 2
    assert u_c == 400

    # Unpacking inside inner block (verifies function scope promotion)
    if True:
        inner_h, *inner_t = [11, 22, 33]
    assert inner_h == 11
    assert len(inner_t) == 2
    assert inner_t[0] == 22
    assert inner_t[1] == 33

    print("Starred unpacking passed!")

def test_del_statement():
    print("Testing del statement...")
    # Dict delete
    d = {"a": 1, "b": 2, "c": 3}
    del d["b"]
    assert "b" not in d
    assert d["a"] == 1
    assert d["c"] == 3

    # List delete
    lst = [10, 20, 30, 40]
    del lst[1]
    assert len(lst) == 3
    assert lst[0] == 10
    assert lst[1] == 30
    assert lst[2] == 40

    # Var delete / invalidate
    v = 42
    del v
    assert v is None

    # Compound del
    d2 = {"x": 100, "y": 200}
    del d2["x"], d2["y"]
    assert "x" not in d2
    assert "y" not in d2
    print("del statement passed!")

def test_multi_clause_except():
    print("Testing multi-clause except...")
    res = ""
    try:
        raise ValueError
    except KeyError:
        res = "key"
    except ValueError as e:
        res = "value"
    except Exception:
        res = "other"
    assert res == "value"

    res2 = ""
    try:
        raise KeyError
    except (ValueError, TypeError):
        res2 = "vt"
    except KeyError as e:
        res2 = "key"
    assert res2 == "key"

    # Bare except fallback
    res3 = ""
    try:
        raise Exception
    except ValueError:
        res3 = "val"
    except:
        res3 = "fallback"
    assert res3 == "fallback"

    # Outer variable shadowing test
    err_var = "initial"
    try:
        raise ValueError
    except ValueError as err_var:
        pass
    assert str(err_var) == "ValueError"

    # Inner variable assignment in except clause used afterwards
    try:
        raise TypeError
    except TypeError:
        assigned_in_except = 999
    assert assigned_in_except == 999

    print("Multi-clause except passed!")

def test_augmented_assignments():
    print("Testing augmented bitwise & advanced assignments...")
    x = 12  # 1100 in binary
    x &= 10 # 1010 -> 1000 = 8
    assert x == 8

    x |= 3  # 1000 | 0011 = 1011 = 11
    assert x == 11

    x ^= 6  # 1011 ^ 0110 = 1101 = 13
    assert x == 13

    x <<= 2 # 13 * 4 = 52
    assert x == 52

    x >>= 1 # 52 // 2 = 26
    assert x == 26

    x //= 4 # 26 // 4 = 6
    assert x == 6

    x **= 2 # 6 ** 2 = 36
    assert x == 36

    # Subscript augmented assign
    d = {"n": 100}
    d["n"] //= 3
    assert d["n"] == 33
    d["n"] &= 17
    assert d["n"] == 1
    print("Augmented assignments passed!")

def get_coords():
    return 100, 200

def get_meta():
    return "video", 1080, True

def test_multiple_returns():
    print("Testing multiple return expressions...")
    tup = get_coords()
    assert tup[0] == 100
    assert tup[1] == 200

    cx, cy = get_coords()
    assert cx == 100
    assert cy == 200

    kind, res, ok = get_meta()
    assert kind == "video"
    assert res == 1080
    assert ok is True
    print("Multiple returns passed!")

def subgen1():
    yield 10
    yield 20

def subgen2():
    yield 30
    yield 40

def combined():
    yield from subgen1()
    yield 25
    yield from subgen2()

def test_subgenerator_yield_from():
    print("Testing subgenerator yield from...")
    vals = combined()
    assert len(vals) == 5
    assert vals[0] == 10
    assert vals[1] == 20
    assert vals[2] == 25
    assert vals[3] == 30
    assert vals[4] == 40
    print("Subgenerator yield from passed!")

class VideoMetadata:
    title: str
    duration: int
    resolution: str

    def __init__(self, title, duration, resolution):
        self.title = title
        self.duration = duration
        self.resolution = resolution

    def summary(self):
        return self.title

def test_standalone_annotations():
    print("Testing standalone field and variable annotations...")
    # Standalone variable annotation
    count: int
    count = 100
    assert count == 100

    # Class with field annotations
    vid = VideoMetadata("Test Video", 360, "1080p")
    assert vid.title == "Test Video"
    assert vid.duration == 360
    assert vid.resolution == "1080p"
    assert vid.summary() == "Test Video"
    print("Standalone annotations passed!")

# Module-level tuple unpacking test
top_x, top_y = 111, 222
def get_top_x():
    return top_x

def except_yield_gen():
    try:
        raise TypeError
    except ValueError:
        pass
    except TypeError:
        yield 42
    else:
        yield 99

def test_yield_in_except():
    print("Testing yield in except and else...")
    ey_res = except_yield_gen()
    assert len(ey_res) == 1
    assert ey_res[0] == 42
    print("Yield in except passed!")

def test_param_shadowing(top_x):
    print("Testing function parameter shadowing global variable...")
    assert top_x == 5
    top_x = 10
    top_x += 15
    return top_x

class ShadowClass:
    def method(self, top_y):
        assert top_y == 50
        top_y += 5
        return top_y

def run_shadow_tests():
    res_fn = test_param_shadowing(5)
    assert res_fn == 25
    assert top_x == 111

    sc = ShadowClass()
    res_m = sc.method(50)
    assert res_m == 55
    assert top_y == 222
    print("Parameter shadowing passed!")

def main():
    test_starred_unpacking()
    test_del_statement()
    test_multi_clause_except()
    test_augmented_assignments()
    test_multiple_returns()
    test_subgenerator_yield_from()
    test_standalone_annotations()
    test_yield_in_except()
    assert get_top_x() == 111
    run_shadow_tests()
    print("ALL YT-DLP SYNTAX SUITE TESTS PASSED SUCCESSFULLY!")

main()
