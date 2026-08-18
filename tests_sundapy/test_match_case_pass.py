def test_match(x: int) -> int:
    match x:
        case 1:
            return 10
        case 2 | 3:
            return 20
        case _:
            return 0

print(test_match(1))
print(test_match(2))
print(test_match(3))
print(test_match(100))

def test_match_dynamic(val):
    match val:
        case "hello":
            return "world"
        case "foo" | "bar":
            return "baz"
        case _:
            return "unknown"

print(test_match_dynamic("hello"))
print(test_match_dynamic("bar"))
print(test_match_dynamic(999))
