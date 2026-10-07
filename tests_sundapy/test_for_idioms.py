items = ["apple", "banana", "cherry"]
print("--- Test enumerate ---")
for i, x in enumerate(items):
    print("idx:", i, "val:", x)

print("--- Test enumerate with start ---")
for i, x in enumerate(items, 10):
    print("idx:", i, "val:", x)

print("--- Test zip ---")
nums = [100, 200, 300]
for a, b in zip(items, nums):
    print("item:", a, "num:", b)

print("--- Test zip 3 iterables ---")
flags = [True, False, True]
for a, b, c in zip(items, nums, flags):
    print(a, b, c)

print("LOOP IDIOMS PASSED!")
