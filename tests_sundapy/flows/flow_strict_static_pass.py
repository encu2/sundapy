#strict
# TEST PURPOSE: Verify complex static control flow in strict mode passes and runs fast
# EXPECTED RESULT: PASS

def factorial(n: int) -> int:
    if n <= 1:
        return 1
    
    result: int = 1
    i: int = 1
    while i <= n:
        result = result * i
        i = i + 1
        
    return result

def check_even(val: int) -> bool:
    is_even: bool = False
    if val % 2 == 0:
        is_even = True
    else:
        is_even = False
    return is_even

print(factorial(5))
print(check_even(4))
