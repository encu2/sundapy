from .sibling import get_sibling_msg
from .sibling import sibling_add
from . import sibling
from .sub.child import child_greet as pkg_child_greet

def call_via_pure_dot():
    return sibling.get_sibling_msg()
