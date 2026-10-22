def run_cond(flag: bool):
    if flag:
        from .sibling import sibling_add
        return sibling_add(10, 20)
    else:
        from .sibling import get_sibling_msg
        return get_sibling_msg()
