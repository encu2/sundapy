print("--- [TEST] Metode Primitif Tipe Data ---")

# 1. String methods
print("\nTest String Method (.upper):")
my_str = "hello"
print("Hasil konversi string 'hello' dengan metode upper() adalah:", my_str.upper())

# 2. List methods
print("\nTest List Methods (.append, .pop):")
my_list = [1, 2]
print("List awal:", my_list)
my_list.append(3)
print("Hasil setelah melakukan append(3):", my_list)

popped = my_list.pop()
print("Hasil dari operasi pop():", popped)
print("List terakhir setelah elemen di pop:", my_list)

# 3. Dict methods
print("\nTest Dictionary Methods (.get):")
my_dict = {"a": 100}
print("Isi dictionary:", my_dict)
print("Hasil dari dict.get('a') adalah:", my_dict.get("a"))
print("Hasil dari dict.get('b') (key yang tidak ada) adalah:", my_dict.get("b"))
