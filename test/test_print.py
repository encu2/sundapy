print("--- [TEST] Operasi Cetak (Print) dan Instansiasi Class ---")

class Person:
    def __init__(self, name, age):
        self.name = name
        self.age = age

    def greet(self):
        print("Hello, nama saya", self.name, "dan saya berumur", self.age, "tahun.")

print("Status: Sebelum melakukan instansiasi.")
p = Person("ZigZag", 99)
print("Status: Setelah melakukan instansiasi (Class Person).")
print("Memanggil metode greet()...")
p.greet()
print("Status: Selesai mengeksekusi metode greet().")
