#strict

def calculate_discount(price: int, discount_rate: int) -> int:
    discount: int = (price * discount_rate) / 100
    return price - discount

def start() -> void:
    final_price: int = calculate_discount(200, 15)
    # This should fail because final_price is int, and we assign string
    final_price = "Free"
    print(final_price)

start()
