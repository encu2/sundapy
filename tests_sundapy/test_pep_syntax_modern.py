# =============================================================================
#   SUNDAPY MODERN PEP COMPATIBILITY SUITE (PEP 619 - 826)
#   Testing Category 1: Modern Syntax, Semantics & Pattern Matching
# =============================================================================

# Test PEP 634: Pattern Matching with Guards & Sequences
def test_match_guard(val: int) -> str:
    match val:
        case 0:
            return "zero"
        case x if x > 100:
            return "huge"
        case x if x > 10:
            return "medium"
        case _:
            return "small"

print("Match 0:", test_match_guard(0))
print("Match 15:", test_match_guard(15))
print("Match 500:", test_match_guard(500))
print("Match 5:", test_match_guard(5))

# Test PEP 634: Sequence Pattern Matching
def test_match_seq(items: list) -> str:
    match items:
        case [1, 2]:
            return "one_two"
        case [x, 0]:
            return "ends_zero"
        case _:
            return "other"

print("Seq [1, 2]:", test_match_seq([1, 2]))
print("Seq [9, 0]:", test_match_seq([9, 0]))
print("Seq [3, 4]:", test_match_seq([3, 4]))

# Test PEP 823 & PEP 824: Safe Navigation (?.) and None-Coalescing (??)
class Person:
    def __init__(self, name: str, age: int):
        self.name = name
        self.age = age

p1 = Person("Alice", 30)
p_null = None

# Safe attribute access
name1 = p1?.name
print("Safe access valid:", name1)
name_none = p_null?.name
print("Safe access null:", name_none)

# None-coalescing
resolved_name = name_none ?? "Anonymous"
print("Coalescing default:", resolved_name)
fallback_test = name1 ?? "Backup"
print("Coalescing present:", fallback_test)

# Test PEP 822: Dedented String (d"...")
d_str = d"""
    Hello SundaPy!
    This is compile-time dedented text.
    Zero runtime overhead.
"""
print("D-String dedented successfully:")
print(d_str)

# Test PEP 750: Template Strings (t"...")
tmpl = t"Template: item count is {count}"
print("Template string tokenized:", tmpl)

# Test PEP 758: Multiple exceptions without parentheses
try:
    x = 10 / 2
    print("Try block ok:", x)
except ValueError, ZeroDivisionError as e:
    print("Caught error:", e)

print("All Modern PEP Syntax Tests Passed!")
