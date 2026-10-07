#strict
import time

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

start_ns: i64 = time.time_ns()
result: i128 = fib(128)
end_ns: i64 = time.time_ns()

elapsed_ns: i64 = end_ns - start_ns
elapsed_ms: f64 = float(elapsed_ns) / 1000000.0

print("Fibonacci(90):", result)
print("Execution Time:", elapsed_ns, "ns")
print("Execution Time:", elapsed_ms, "ms")