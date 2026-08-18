# Test ternary operator
x = 10
y = 20 if x > 5 else 30
z = "less" if x < 5 else "greater"

print(y)
print(z)

# Python doesn't have an inline for loop statement, it has list comprehensions
# For a list comprehension `[i for i in range(5)]`, we might need parser support.
# Let's see if we can do one line if statements:
a = 0
if x == 10: a = 1
else: a = 2
print(a)
