#strict

def fib(n: i16) -> i128:
    a: i128 = 0
    b: i128 = 1
    i: i16 = 0
    while i < n:
        temp: i128 = a + b
        a = b
        b = temp
        i = i + 1
    return a

result: i128 = fib(128)

print(result)