# TEST PURPOSE: Verify nested loops and break/continue work correctly.
# EXPECTED RESULT: PASS

def sum_nested():
    total = 0
    i = 0
    while i < 5:
        j = 0
        while j < 5:
            if i == j:
                j = j + 1
                continue
            if i + j > 7:
                break
            total = total + (i * j)
            j = j + 1
        i = i + 1
    return total

print(sum_nested())
