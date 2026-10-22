import numpy as np

arr = np.zeros((3, 3))
print("Array created:", arr)

# 1. Ellipsis index
row = arr[..., 0]
print("arr[..., 0]:", row)

# 2. Assignment with ellipsis
arr[..., 1] = 42
print("After assignment arr[..., 1] = 42:\n", arr)

# 3. Multidimensional scalar access
val = arr[0, 1]
print("arr[0, 1]:", val)
assert val == 42

# 4. Multidimensional slice with ellipsis
sub = arr[..., 0:2]
print("arr[..., 0:2]:\n", sub)

# 5. Ellipsis at end with slice at start
sub2 = arr[0:2, ...]
print("arr[0:2, ...]:\n", sub2)

# 6. Slicing assignment with ellipsis
arr[..., 0:2] = 99
print("After arr[..., 0:2] = 99:\n", arr)
assert arr[0, 0] == 99
assert arr[0, 1] == 99
assert arr[0, 2] == 0

print("ALL NUMPY ELLIPSIS AND MULTIDIMENSIONAL TESTS PASSED SUCCESSFULLY!")
