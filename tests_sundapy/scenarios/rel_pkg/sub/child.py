from ..sibling import get_sibling_msg
from ..sibling import sibling_add as parent_add
from .. import sibling

def child_greet():
    return get_sibling_msg()

def child_calc(x: int):
    return parent_add(x, 10)

def child_via_pure_dots():
    return sibling.sibling_add(100, 200)
