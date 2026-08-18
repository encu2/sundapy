# Testing comparison operators dynamically
a = 10
b = 10
c = 5

print("eq:", a == b)
print("neq:", a != c)
print("lt:", c < a)
print("gt:", a > c)
print("le:", a <= b)
print("ge:", c >= a)

# Float comparisons
d = 10.0
print("eq float:", a == d)

# String comparisons
s1 = "apple"
s2 = "banana"
s3 = "apple"
print("str eq:", s1 == s3)
print("str neq:", s1 != s2)
print("str lt:", s1 < s2)

