# Test while loop with break and continue
i = 0
sum_val = 0
while i < 10:
    i = i + 1
    if i == 5:
        continue
    if i == 8:
        break
    sum_val = sum_val + i

print("sum:", sum_val)

# Test for loop with range
for_sum = 0
for x in range(5):
    for_sum = for_sum + x

print("for_sum:", for_sum)

for y in range(2, 6):
    print("y:", y)

for z in range(10, 0, -2):
    print("z:", z)
