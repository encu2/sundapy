def test_list_comp_basic():
    arr = [1, 2, 3, 4, 5]
    res = [x * 2 for x in arr]
    print(res)

def test_list_comp_with_if():
    arr = [1, 2, 3, 4, 5, 6, 7, 8]
    res = [x for x in arr if x % 2 == 0]
    print(res)

def test_list_comp_with_inline_if():
    arr = [1, 2, 3, 4, 5]
    # x*10 if x is even, else x
    res = [x * 10 if x % 2 == 0 else x for x in arr]
    print(res)

def test_list_comp_with_inline_if_and_filter():
    arr = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
    # filter only > 3, then x*10 if even else x
    res = [x * 10 if x % 2 == 0 else x for x in arr if x > 3]
    print(res)

print("--- Basic ---")
test_list_comp_basic()
print("--- With If ---")
test_list_comp_with_if()
print("--- With Inline If ---")
test_list_comp_with_inline_if()
print("--- With Inline If and Filter ---")
test_list_comp_with_inline_if_and_filter()
