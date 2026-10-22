from ...sibling import get_sibling_msg
from ...sibling import sibling_add
from ... import sibling

def leaf_greet():
    return get_sibling_msg()

def leaf_math(val: int):
    return sibling_add(val, 100)

def leaf_via_pure_dots():
    return sibling.sibling_add(500, 500)
