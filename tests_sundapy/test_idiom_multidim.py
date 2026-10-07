def test_2d_matrix():
    N = 3
    D = 4
    matrix = [[0.0] * D for _ in range(N)]
    print("matrix len:", len(matrix))
    print("row 0 len:", len(matrix[0]))
    print("initial:", matrix[0][0])
    matrix[0][0] = 42.0
    print("matrix[0][0]:", matrix[0][0])
    print("matrix[1][0] (independent):", matrix[1][0])

def test_3d_tensor():
    W = 2
    H = 3
    D = 4
    tensor = [[[0.0] * D for _ in range(H)] for _ in range(W)]
    print("tensor len W:", len(tensor))
    print("tensor len H:", len(tensor[0]))
    print("tensor len D:", len(tensor[0][0]))
    tensor[0][1][2] = 99.5
    print("tensor[0][1][2]:", tensor[0][1][2])
    print("tensor[1][1][2] (independent):", tensor[1][1][2])

def test_4d_deep_tensor():
    W = 2
    H = 2
    C = 3
    D = 4
    tensor4d = [[[[1.0] * D for _ in range(C)] for _ in range(H)] for _ in range(W)]
    print("4D tensor shape:", len(tensor4d), len(tensor4d[0]), len(tensor4d[0][0]), len(tensor4d[0][0][0]))
    tensor4d[1][0][2][3] = 777.0
    print("tensor4d[1][0][2][3]:", tensor4d[1][0][2][3])
    print("tensor4d[0][0][2][3]:", tensor4d[0][0][2][3])

def test_5d_worst_case():
    A = 2
    B = 2
    C = 2
    D = 2
    E = 3
    tensor5d = [[[[[0.0] * E for _ in range(D)] for _ in range(C)] for _ in range(B)] for _ in range(A)]
    print("5D tensor depth check:", len(tensor5d), len(tensor5d[0]), len(tensor5d[0][0]), len(tensor5d[0][0][0]), len(tensor5d[0][0][0][0]))
    tensor5d[1][1][1][1][2] = 123.45
    print("tensor5d[1][1][1][1][2]:", tensor5d[1][1][1][1][2])
    print("tensor5d[0][0][0][0][2]:", tensor5d[0][0][0][0][2])

def test_pure_replication():
    N = 3
    D = 4
    rep = [0.0] * D
    print("1d replication len:", len(rep))

print("=== Testing 2D ===")
test_2d_matrix()
print("=== Testing 3D ===")
test_3d_tensor()
print("=== Testing 4D ===")
test_4d_deep_tensor()
print("=== Testing 5D ===")
test_5d_worst_case()
print("=== Testing 1D ===")
test_pure_replication()
print("ALL TESTS PASSED!")
