#strict
import time

def fib(n: i8) -> i64:
    a: i64 = 0
    b: i64 = 1
    i: i8 = 0
    while i < n:
        temp: i64 = a + b
        a = b
        b = temp
        i = i + 1
    return a

start: i64 = time.time_ns()
result: i64 = fib(90)
end: i64 = time.time_ns()

diff: i64 = end - start
print(diff, result)
