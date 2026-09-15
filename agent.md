# SundaPy - The AI Agent Instruction Manual

**Welcome, fellow AI Agent.** 
If you are reading this file, you have been assigned to write, debug, or optimize code for **SundaPy**. This document contains the absolute truth about SundaPy's architecture, rules, and internal mechanisms. **Do not assume standard Python behavior applies universally here.**

## 1. What is SundaPy?
SundaPy is an extreme-performance **Python-to-Zig transpiler** and runtime. It is designed to take standard Python syntax and compile it down into a tiny, standalone, zero-dependency, ultra-fast native binary (often under 500KB) using Zig's `ReleaseSmall` optimization.

**Core Philosophy (Absolute Non-Negotiables):**
1. **Speed & Size**: The output binary must be as small and fast as humanly (and artificially) possible.
2. **Native Python Syntax**: It must parse standard `.py` files.
3. **Strict Enforcement**: No silent failures in strict mode; absolute type compliance is required.

---

## 2. The Two Execution Modes

SundaPy operates in two completely different paradigms depending on a single magic comment at the top of the file.

### A. Dynamic Mode (Standard Python)
If a file **does not** start with `#strict`, it runs in Dynamic Mode.
- **Behavior**: Acts like standard CPython. Variables are duck-typed.
- **Internal Mapping**: Everything is boxed into a Zig `Dynamic` struct (equivalent to `PyObject`). 
- **Performance**: Slower than strict mode, uses heap allocation, but guarantees 100% Python compatibility for dynamic scripts.

### B. `#strict` Mode (Native Zig Mapping)
If the absolute first line of a file is exactly `#strict`, the transpiler shifts into high-performance static compilation.
- **Behavior**: All variables and function parameters **MUST** have explicit type annotations.
- **Internal Mapping**: Python primitives are mapped *directly* to Zig/C hardware primitives.
  - `int` -> `i64`
  - `i8`, `i16`, `i32`, `i64`, `i128`, `i256`, `i512`, `i1024` -> Native Zig integers (signed)
  - `u8`, `u16`, `u32`, `u64`, `u128`, `u256`, `u512`, `u1024` -> Native Zig unsigned integers
  - *Fun Fact*: You can actually use ANY arbitrary bit-width integer (e.g., `i7`, `u33`) because the transpiler passes types directly to Zig's LLVM backend which supports `i1` up to `i65535`!
  - `float` -> `f64`
  - `str` -> `[]const u8` (string slices)
  - `Dynamic` -> Boxed PyObject (used for bridging)
- **Math Operators**: `+`, `-`, `*`, `/` are transpiled to native Zig hardware instructions. **You CANNOT use these operators on `Dynamic` objects in `#strict` mode.** If you have `Dynamic` objects, you must use C-ABI libraries (like `numpy.add`, `numpy.subtract`) to perform math.
- **Safety**: The transpiler automatically injects `@setRuntimeSafety(true)` into strict functions. If an integer overflows (e.g., `i8 = 127 + 1`), it will violently `panic: integer overflow` rather than silently wrapping around.

#### Example of Strict Mode:
```python
#strict
import time
import numpy as np

# 'n' must be i16 to avoid i8 overflow if n > 127
def fib(n: i16) -> i128:
    a: i128 = 0
    b: i128 = 1
    i: i16 = 0
    while i < n:
        temp: i128 = a + b
        a = b
        b = temp
        i = i + 1
    return a

# System module returning primitive
start: i64 = time.time_ns()
result: i128 = fib(100)
end: i64 = time.time_ns()

print(end - start, result)
```

---

## 3. Tooling & CLI Commands

SundaPy uses a local CLI workflow.
- **Run a script**: `./zig-out/bin/sundapy script.py` (Compiles and executes silently).
- **Force rebuild**: `./zig-out/bin/sundapy script.py -y`
- **Build a standalone binary**: `./zig-out/bin/sundapy --build script.py` (Outputs an executable named `script` in the current directory).
- **Fetch pip packages**: `./zig-out/bin/sundafetch <package_name>` or `sundafetch -r requirements.txt` (Downloads and extracts wheels natively via `sundafetch` into `.cache/pyLibrary` with zero external dependencies).
- **Build system fetch**: `zig build fetch -- <pkg>` or `zig build fetch -- -r requirements.txt` (Installs external Python libraries via the Zig build system directly into `.cache/pyLibrary`).

---

## 4. Internal Architecture (No Secrets)

As an AI, if you need to debug SundaPy's compiler, here is exactly how it works:
1. **Parser & Lexer**: Located in `src/lexer/` and `src/parser/`. Parses Python into an AST.
2. **Transpiler**: Located in `src/transpiler/`. Converts AST to Zig source code.
3. **Cache System**: 
   - Transpiled code is written to `.cache/src/__entry.zig`.
   - SundaPy hashes the input `.py` file. If the hash hasn't changed, **it will just run the cached binary** in `.cache/bin/`. 
   - **CRITICAL**: If you edit the *compiler source code* (e.g., `src/transpiler/stmt_def.zig`), running the CLI on an unmodified Python script **will still use the old cache**. You MUST `rm -rf .cache` to force the compiler to re-transpile and re-compile using your new compiler logic!
4. **Standard Library Bridging (`sundapy_std`)**:
   - Located in `src/datatype/sundapy_std/`.
   - Modules (like `time.zig`, `_thread.zig`) are mapped here.
   - The transpiler uses `@embedFile` via `generate_embedded.py` to bake these libraries into the compiler binary. **If you edit files in `src/datatype/`, you MUST run `./install.sh`** to regenerate the embedded architecture and recompile `sundapy`.
5. **Python C-ABI (Embedding)**:
   - SundaPy embeds `libpython` dynamically. When Python imports `numpy`, it actually bridges memory directly via C-ABI into Zig. `Dynamic` structs store raw C-pointers to `PyObject`.

## 5. C-ABI Compatibility Layer & Detection
- **Conditional Inclusion**: The compiler scans dependencies and imported modules. If a library or script does NOT require external binary extensions (`.so`/`.pyd`) or Python C-ABI symbols, it compiles in **Pure Native Mode** with zero C-ABI overhead (`[SUNDAPY] Python C-ABI compatibility layer: NOT REQUIRED`). If external binary C-ABI modules (e.g. `numpy`, `bs4`, `requests`) are imported, SundaPy automatically enables the Python C-ABI bridge (`[SUNDAPY] Python C-ABI compatibility layer: ENABLED`).
- **Iterative Directory Scanner**: Directory traversal for binary discovery (`scanDirForSo`) in both compiler and `sundafetch` strictly uses a flat, heap-backed iterative stack (`std.ArrayList([]const u8)`) without function recursion, preventing stack exhaustion / recursion bombs on deep dependency trees.

## 6. Agent Instructions for Modifying Code
- **Always check for `#strict`**: Before you write a loop or math operation, look at line 1. If it's strict, use correct bit-width types (e.g., `i16`, `i64`).
- **Never use `cat` in bash**: Use native specific tools or write helper python scripts to patch files.
- **Cache invalidation**: If you patch the compiler in `src/`, always run `echo "n" | ./install.sh` to rebuild the binary, and then `rm -rf .cache` to ensure your target `.py` file actually gets recompiled by the new logic.

*End of manual. Godspeed, Agent.*
