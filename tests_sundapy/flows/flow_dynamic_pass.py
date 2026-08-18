# TEST PURPOSE: Verify that without strict mode, variables can change types dynamically across complex control flows.
# EXPECTED RESULT: PASS

def dynamic_processor(val):
    result = None
    if val < 0:
        result = "Negative"
    elif val == 0:
        result = 0
    else:
        result = [1, 2, 3]
    return result

print(dynamic_processor(-5))
print(dynamic_processor(0))
print(dynamic_processor(5))
