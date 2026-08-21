#strict
def heavy_loop() -> i64:
    native_sum: i64 = 0
    i: i64 = 0
    for i in range(5000000):
        native_sum = native_sum + 1
    return native_sum
