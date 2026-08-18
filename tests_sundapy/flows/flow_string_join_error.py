# TEST PURPOSE: Verify that join fails when called with non-string list items.
# EXPECTED RESULT: ERROR (TypeError panic at runtime)

def test_join_error():
    separator = "-"
    items = [1, 2, 3]
    res = separator.join(items)
    print(res)

test_join_error()
