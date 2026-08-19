with open("src/transpiler/expr/expr_strict_method.zig", "r") as f:
    text = f.read()

text = text.replace('emit("        if (@TypeOf(_target.{s}) == type) {\\n"', 'emit("        if (@TypeOf(_target.{s}) == type) {{\\n"')
text = text.replace('emit("            var _obj = _target.{s}{};\\n"', 'emit("            var _obj = _target.{s}{{}};\\n"')
text = text.replace('emit("            if (@hasDecl(_target.{s}, \\"__init__\\")) {\\n"', 'emit("            if (@hasDecl(_target.{s}, \\"__init__\\")) {{\\n"')
text = text.replace('emit("            }\\n"', 'emit("            }}\\n"')
text = text.replace('emit("        } else {\\n"', 'emit("        }} else {{\\n"')
text = text.replace('emit("        }\\n"', 'emit("        }}\\n"')

with open("src/transpiler/expr/expr_strict_method.zig", "w") as f:
    f.write(text)
