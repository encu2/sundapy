from rel_pkg.sibling import get_sibling_msg
from rel_pkg import sibling_add
from rel_pkg.sub.child import child_greet
from rel_pkg.sub.child import child_calc
from rel_pkg.sub.deep.leaf import leaf_greet
from rel_pkg.sub.deep.leaf import leaf_math

msg = get_sibling_msg()
print("Direct import:", msg)
assert msg == "hello from sibling"

res1 = sibling_add(5, 7)
print("sibling_add:", res1)
assert res1 == 12

cg = child_greet()
print("child_greet (via ..):", cg)
assert cg == "hello from sibling"

cc = child_calc(15)
print("child_calc (via .. with alias):", cc)
assert cc == 25

lg = leaf_greet()
print("leaf_greet (via ...):", lg)
assert lg == "hello from sibling"

lm = leaf_math(50)
print("leaf_math (via ...):", lm)
assert lm == 150

from rel_pkg import call_via_pure_dot
from rel_pkg.sub.child import child_via_pure_dots
from rel_pkg.sub.deep.leaf import leaf_via_pure_dots

cvpd = call_via_pure_dot()
print("call_via_pure_dot (via from . import sibling):", cvpd)
assert cvpd == "hello from sibling"

cvpd2 = child_via_pure_dots()
print("child_via_pure_dots (via from .. import sibling):", cvpd2)
assert cvpd2 == 300

cvpd3 = leaf_via_pure_dots()
print("leaf_via_pure_dots (via from ... import sibling):", cvpd3)
assert cvpd3 == 1000

from rel_pkg import pkg_child_greet
pkg_cg = pkg_child_greet()
print("pkg_child_greet (via from .sub.child import):", pkg_cg)
assert pkg_cg == "hello from sibling"

from rel_pkg.circ_a import call_b
from rel_pkg.circ_b import call_a
msg_b = call_b()
msg_a = call_a()
print("circular relative import call_b:", msg_b)
print("circular relative import call_a:", msg_a)
assert msg_b == "message from b"
assert msg_a == "message from a"

from rel_pkg.conditional_mod import run_cond
cond_true = run_cond(True)
cond_false = run_cond(False)
print("conditional relative import True:", cond_true)
print("conditional relative import False:", cond_false)
assert cond_true == 30
assert cond_false == "hello from sibling"

print("All relative import tests passed successfully!")
