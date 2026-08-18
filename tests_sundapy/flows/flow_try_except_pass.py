# TEST PURPOSE: Verify try/except/finally and raise statements work via Zig catch and defer.
# EXPECTED RESULT: PASS

def safe_divide(a, b):
    result = 0
    try:
        if b == 0:
            raise "Division by zero"
        result = a / b
    except:
        result = -1
    finally:
        pass
    return result

print(safe_divide(10, 2))
print(safe_divide(10, 0))

# Nested try/except
def complex_op():
    status = 0
    try:
        try:
            raise "Inner Error"
        except:
            status = 1
            raise "Propagate"
    except:
        status = status + 10
    return status

print(complex_op())
