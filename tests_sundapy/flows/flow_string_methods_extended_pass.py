# TEST PURPOSE: Verify extended string method behaviors (split, join, replace, upper, lower).
# EXPECTED RESULT: PASS

def test_string_methods():
    text = "zig,python,zig,c++,zig"
    
    # split
    parts = text.split(",")
    print(parts)
    
    # join with multi-char
    joined = " | ".join(parts)
    print(joined)
    
    # replace
    replaced = joined.replace("zig", "sundapy")
    print(replaced)
    
    # case conversions
    print(replaced.upper())
    print(replaced.lower())
    
    # chained (using variables to avoid transpiler method chaining limits)
    temp = " hello ".replace(" ", "")
    print(temp.upper())

test_string_methods()
