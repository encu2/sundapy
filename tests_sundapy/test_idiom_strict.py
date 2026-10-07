def test_strict_grid() -> Dynamic:
    #strict
    grid: list = [[0.0] * 4 for _ in range(3)]
    return grid

g: Dynamic = test_strict_grid()
print("Strict grid len:", len(g))
print("Strict row 0 len:", len(g[0]))
print("Strict row 0 col 0:", g[0][0])
