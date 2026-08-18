#strict
# TEST PURPOSE: Verify recursive function calls work properly in strict mode.
# EXPECTED RESULT: PASS

def fibonacci(n: int) -> int:
    if n <= 1:
        return n
    return fibonacci(n - 1) + fibonacci(n - 2)

print(fibonacci(7))
