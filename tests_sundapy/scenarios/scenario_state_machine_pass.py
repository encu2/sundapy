#strict
def compute_state(initial: int, steps: int) -> int:
    state: int = initial
    i: int = 0
    while i < steps:
        match state:
            case 0:
                state = 1
            case 1:
                state = 2
            case 2:
                state = 0
            case _:
                state = -1
        i = i + 1
    return state

def evaluate_threshold(val: int) -> int:
    if val > 100:
        return 2
    elif val > 50:
        return 1
    else:
        return 0

def run_simulation() -> void:
    print(compute_state(0, 10))
    print(compute_state(1, 5))
    print(compute_state(99, 1))

    print(evaluate_threshold(120))
    print(evaluate_threshold(75))
    print(evaluate_threshold(10))

run_simulation()
