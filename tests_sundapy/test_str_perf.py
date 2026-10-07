# Test String join, split, replace zero-allocation optimization

def test_string_operations():
    # Empty and single-element join
    assert "-".join([]) == ""
    assert "-".join(["hello"]) == "hello"

    # Multi-element join
    words = ["fast", "lowlevel", "native", "zig"]
    joined = " ".join(words)
    assert joined == "fast lowlevel native zig"

    delimited = ",".join(words)
    assert delimited == "fast,lowlevel,native,zig"

    # Split
    parts = delimited.split(",")
    assert len(parts) == 4
    assert parts[0] == "fast"
    assert parts[1] == "lowlevel"
    assert parts[2] == "native"
    assert parts[3] == "zig"

    # Split whitespace
    sentence = "sundapy is super fast"
    words2 = sentence.split()
    assert len(words2) == 4
    assert words2[0] == "sundapy"
    assert words2[3] == "fast"

    # Replace
    rep = sentence.replace("fast", "blazing")
    assert rep == "sundapy is super blazing"

    print("ALL STRING OPTIMIZATION TESTS PASSED!")

test_string_operations()
