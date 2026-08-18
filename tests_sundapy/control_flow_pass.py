# Test if/elif/else and ternary operator
x = 10
if x > 5:
    print("x is greater than 5")
elif x == 5:
    print("x is 5")
else:
    print("x is less than 5")

y = 2
if y < 5:
    if y == 2:
        print("y is 2")
    else:
        print("y is not 2")

# Ternary operator
status = "Adult" if x >= 18 else "Minor"
print(status)
