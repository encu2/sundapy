def add(a, b):
    return a + b

def test_scope(x):
    y = x + 10
    return y

res1 = add(5, 7)
res2 = test_scope(20)
print(res1)
print(res2)
