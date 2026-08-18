# 1. Variables and Arithmetic
print("--- [TEST] Operasi Aritmatika ---")
a = 10
b = 5
print("Nilai awal: a = 10, b = 5")
print("Hasil a + b =", a + b)
print("Hasil a - b =", a - b)
print("Hasil a * b =", a * b)
print("Hasil a / b =", a / b)
print("Hasil a == 10:", a == 10)

# 2. Control Flow
print("\n--- [TEST] Control Flow (While Loop dari 1 sampai 3 dengan Continue) ---")
counter = 0
while counter < 3:
    counter = counter + 1
    if counter == 2:
        print("Mendeteksi nilai 2, melakukan operasi 'continue'...")
        continue
    print("Hasil Iterasi Counter:", counter)

# 3. Functions
print("\n--- [TEST] Pemanggilan Fungsi ---")
def add_numbers(x, y):
    return x + y
print("Hasil eksekusi fungsi add_numbers(3, 4) =", add_numbers(3, 4))

# 4. Classes and Objects
print("\n--- [TEST] Deklarasi dan Instansiasi Class ---")
class Person:
    def __init__(self, name, age):
        self.name = name
        self.age = age

    def greet(self):
        print("Hello, nama saya", self.name, "dan saya berumur", self.age, "tahun.")

p = Person("ZigZag", 99)
print("Hasil pemanggilan method dari instansi Person:")
p.greet()

# 5. Generators
print("\n--- [TEST] Operasi Yield / Generator dari 1 sampai 3 ---")
def count_up_to(max_val):
    count = 1
    while count <= max_val:
        yield count
        count = count + 1

gen = count_up_to(3)
print("Hasil Generator ke-1:", next(gen))
print("Hasil Generator ke-2:", next(gen))
print("Hasil Generator ke-3:", next(gen))

print("\n--- SEMUA PENGUJIAN UMUM SELESAI ---")
