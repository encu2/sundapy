# SundaPy - The AI Agent Instruction Manual & Codebase Architecture

**Welcome, fellow AI Agent.** 
If you are reading this file, you have been assigned to develop, debug, maintain, or optimize **SundaPy**. This document contains the absolute single-source-of-truth regarding SundaPy's architecture, internal design, file registry, and developer rules. **Do not assume standard CPython behavior applies universally here.**

---

## 1. What is SundaPy?

SundaPy is an extreme-performance **Python-to-Zig transpiler, ahead-of-time (AOT) compiler, and native runtime**. It translates standard Python source code into clean, highly optimized Zig source code, then compiles it via Zig's LLVM backend into tiny, zero-dependency native standalone binaries (often < 500 KB) with bare-metal execution speeds.

### Core Philosophy (Absolute Non-Negotiables)
1. **Speed & Minimal Footprint**: The resulting binary must be as small and fast as humanly and artificially possible (`ReleaseSmall` optimization, automatic symbol stripping).
2. **Native Python Syntax**: SundaPy ingests standard Python 3.10–3.14 syntax (indents, defs, classes, match-case, async/await, list comprehensions, f-strings, decorators).
3. **Zero External GUI/Network Dependencies**: Native libraries (`screenGUI`, `socket`, `requests`, `gpu`) are written in 100% pure Zig and Linux kernel syscalls/wire protocols—no external C libraries like Xlib, SDL, GTK, or OpenSSL.
4. **Intelligent C-ABI Bridging**: Pure native mode when possible (zero overhead); automatic on-demand dynamic bridging to CPython C-ABI when binary packages like `numpy` or `PyQt` are imported.
5. **Strict Static Type Safety**: In `#strict` mode, strict compile-time types with hardware arithmetic and runtime safety guards (`@setRuntimeSafety(true)`).

---

## 2. Complete File Registry of `src/` (84 Source Files)

Every single file in `src/` is indexed below with its exact responsibility:

```
src/
├── main.zig                              # Minimal entrypoint delegating process args to runner
├── embedded_datatype.zig                 # Compile-time @embedFile registry of all runtime datatypes & stdlib
├── cli/
│   └── runner.zig                        # SundaPy CLI orchestrator, compilation coordinator, cache & execution
├── fetcher/
│   └── main.zig                          # `sundafetch` standalone package manager & wheel extractor
├── core/
│   ├── ast.zig                           # Unified Abstract Syntax Tree (AST) node & struct definitions
│   ├── cache.zig                         # Wyhash-based content hashing & .cache/ management
│   ├── compiler_check.zig                # Validates Zig 0.16.0 compiler presence in PATH or local cache
│   ├── compiler.zig                      # Shared compiler state, iterative SO scanner, missing modules tracker
│   └── transpile_file.zig                # File-level transpilation pipeline, import resolution, C-ABI stub gen
├── lexer/
│   ├── token.zig                         # Token enum and Token structure definitions
│   ├── lexer_keyword.zig                 # Python keyword matcher (if, def, class, match, async, strict, etc.)
│   └── lexer.zig                         # Indentation-aware Python lexer (handles \n, indents, dedents, fstrings)
├── parser/
│   ├── parser.zig                        # Pratt recursive-descent parser engine & operator precedence table
│   ├── expr.zig                          # Expression parsing dispatcher using Pratt algorithm
│   ├── expr_prefix.zig                   # Prefix expression parser (literals, unary, list comp, await, walrus)
│   ├── expr_infix.zig                    # Infix expression parser (calls, getattr, subscript, slicing, binary ops)
│   ├── stmt.zig                          # Statement dispatcher & block indentation processor
│   ├── stmt_decl.zig                     # Function (def) & Class (class) declaration parser
│   └── stmt_control_parse.zig            # Control flow statement parser (if/elif/else, while, for, match, try)
├── transpiler/
│   ├── transpiler.zig                    # Transpiler struct, code emitter, scope tracker, keyword escaper
│   ├── driver.zig                        # High-level transpile orchestration, passes, module struct init
│   ├── stmt_dispatcher.zig               # Statement code generation dispatcher
│   ├── stmt.zig                          # General statement transpiler dispatcher helper
│   ├── stmt/
│   │   ├── stmt_assign.zig               # Assignments (=, +=, :=, tuple unpacking, subscript/attr assign)
│   │   ├── stmt_class.zig                # OOP class transpilation into Zig structs & methods
│   │   ├── stmt_control.zig              # Control statements (if, while, for, try-except-finally)
│   │   ├── stmt_def.zig                  # Function definitions, decorators, strict type mapping
│   │   ├── stmt_match.zig                # Python 3.10+ Pattern Matching (match/case) transpilation
│   │   └── stmt_misc.zig                 # Return, yield, raise, calls, and expression statements
│   ├── expr/
│   │   ├── expr.zig                      # Dynamic mode expression code generation
│   │   ├── expr_strict.zig               # Strict mode native Zig expression code generation
│   │   ├── expr_strict_call.zig          # Strict mode function/method calls & C-ABI invocations
│   │   └── expr_strict_method.zig        # Strict mode method calls on native Zig structures
│   └── analysis/
│       ├── analysis.zig                  # AST static analysis aggregator
│       ├── escape.zig                    # Escape analysis orchestrator & storage class classifier (stack vs heap)
│       ├── escape_pass1.zig              # First pass: variable definition, primitive identification, and scope
│       └── escape_pass2.zig              # Second pass: variable escape detection & stack-to-heap promotion
└── datatype/
    ├── dynamic.zig                       # Central Dynamic boxing struct (PyObject equivalent in pure Zig)
    ├── dynamic_dispatch.zig              # Dynamic function dispatching & method invocation
    ├── dynamic_item.zig                  # Dynamic item retrieval & slicing (__getitem__)
    ├── dynamic_items.zig                 # Dynamic item assignment (__setitem__)
    ├── dynamic_ops.zig                   # Dynamic arithmetic operations (+, -, *, /, %, **)
    ├── dynamic_ops_bitwise.zig           # Dynamic bitwise operations (&, |, ^, ~, <<, >>)
    ├── dynamic_ops_cmp.zig               # Dynamic comparison operations (==, !=, <, >, <=, >=, in, is)
    ├── dynamic_str.zig                   # Dynamic string conversion & string formatting logic
    ├── str_methods.zig                   # Core string methods helper
    ├── gpu_types.zig                     # GpuBuffer & GpuKernel core types for GPU compute
    ├── python_abi.zig                    # CPython C-ABI dynamic bridge (dlopen libpython, PyObject marshaling)
    ├── dynamic/
    │   ├── builtins.zig                  # Python builtins aggregator
    │   ├── builtins_conv.zig             # Conversion builtins (int, float, str, bool, list, dict, set, tuple)
    │   ├── builtins_extra.zig            # Utility builtins (any, all, sum, enumerate, zip, id, hash, type)
    │   ├── builtins_iter.zig             # Iterator builtins (iter, next, range, reversed, sorted)
    │   ├── builtins_math.zig             # Math builtins (abs, round, pow, min, max, divmod)
    │   ├── list_methods.zig              # Built-in list methods (append, pop, extend, sort, reverse)
    │   ├── print.zig                     # Native Python print() implementation with separators and ends
    │   └── str_methods.zig               # Built-in string methods (upper, lower, strip, split, replace, find)
    ├── primitive/
    │   ├── index.zig                     # Primitive module exports
    │   └── bool.zig                      # Native boolean type wrapper
    ├── numeric/
    │   ├── index.zig                     # Numeric module exports
    │   ├── int.zig                       # Integer types (arbitrary bit-width integer support)
    │   ├── float.zig                     # Floating point operations (f32, f64, f128)
    │   └── complex.zig                   # Complex numbers support via std.math.Complex
    ├── sequence/
    │   ├── sequence.zig                  # Sequence protocols and types index
    │   ├── range.zig                     # Python range(start, stop, step) iterator implementation
    │   ├── list.zig                      # Dynamic list implementation (resizable ArrayList backing)
    │   ├── binary.zig                    # Bytes and bytearray implementations
    │   └── string/
    │       ├── index.zig                 # String module index
    │       ├── types.zig                 # UTF-8 & UTF-16 string data structures
    │       ├── methods_case.zig          # Case conversion (upper, lower, title, capitalize, swapcase)
    │       └── methods_split.zig         # String splitting & partitioning (split, rsplit, splitlines)
    ├── mapping/
    │   ├── mapping.zig                   # Mapping module index
    │   └── dict.zig                      # Dynamic hash map (Python dict implementation)
    ├── set/
    │   ├── set.zig                       # Dynamic hash set implementation (Python set and frozenset)
    │   └── index.zig                     # Set module index
    ├── set.zig                           # Root alias export for set module
    └── sundapy_std/
        ├── time.zig                      # time module (time(), time_ns(), sleep(), perf_counter())
        ├── _thread.zig                   # Low-level native threading (start_new_thread, cross-thread frames)
        ├── threading.zig                 # High-level threading.Thread native interface
        ├── socket.zig                    # Pure Zig POSIX socket networking (TCP/UDP, AF_INET, SOCK_STREAM)
        ├── requests.zig                  # Zero-dependency HTTP/1.1 client (get(), post(), headers, json())
        ├── asyncio.zig                   # Asyncio event loop, Task, sleep(), gather() coroutine runner
        ├── math.zig                      # Accelerated math functions (sin, cos, tan, sqrt, pow, log, etc.)
        ├── gpu.zig                       # Multi-distro GPU accelerator (CUDA Driver API + SIMD CPU fallback)
        ├── screenGUI.zig                 # Zero-dependency Pure Zig Native X11/Wayland Wire Protocol Window Engine
        └── GUIEngine.zig                 # Multi-purpose media engine, 2D canvas, sprite blitter, and game rasterizer
```

---

## 3. Subsystem Architecture & Features

### A. Execution Modes (`#strict` vs Dynamic)

SundaPy switches behavior based on the first line of the Python script:

1. **Dynamic Mode (Default)**:
   - Everything is boxed in `Dynamic` structs (tagged union supporting 37 types).
   - Duck-typing, Python semantics, dynamic method resolution.
   - Escape analysis automatically optimizes unescaped local variables into stack primitives where safe.

2. **`#strict` Mode**:
   - The absolute first line of the file must be `#strict`.
   - Variables and function signatures **MUST** have explicit static type annotations (`x: i64 = 10`, `def foo(a: f64) -> f64:`).
   - Primitives map directly to native Zig types (`i64`, `f64`, `bool`, `[]const u8`).
   - Supports arbitrary-width integers: `i8`, `i16`, `i32`, `i64`, `i128`, `i256`, `i512`, `i1024` (signed) and `u8`..`u1024` (unsigned).
   - Strict safety: The compiler automatically injects `@setRuntimeSafety(true)`. Integer overflows panic immediately rather than wrapping silently.
   - Mathematical operators compile down to bare-metal CPU hardware instructions.

### B. GPU Computing Engine (`sundapy_std/gpu.zig`, `gpu_types.zig` & `GUIEngine.zig`)

SundaPy features a native GPU parallel programming model:
- **Zero Compilation Overhead**: GPU compute scripts are written in standard Python syntax.
- **Dynamic Multi-Distro Shared Library Discovery**: Dynamically scans across 17+ distribution paths (Arch, CachyOS, Ubuntu, Debian, Fedora, RHEL, Alpine, Jetson ARM64, SUSE, LD_LIBRARY_PATH) for `libcuda.so.1`, `libvulkan.so.1`, and `libOpenCL.so.1`.
- **Direct Driver API via `dlopen`/`dlsym`**: Bypasses heavy CUDA Toolkit installations by loading the kernel driver directly (`cuInit`, `cuCtxCreate`, `cuModuleLoadData`, `cuMemAlloc`, `cuLaunchKernel`).
- **Unified Memory Buffers**: `gpu.buffer(size)` creates `GpuBuffer` objects that synchronize seamlessly between host RAM and GPU VRAM via `toDevice()` and `toHost()`.
- **Kernel Abstraction**: Functions decorated with `@gpu.kernel` can be invoked with multidimensional grid and block dimensions: `kernel[grid_dim, block_dim](args...)`.
- **Multidimensional Thread Indexing**: `gpu.threadIdx.x`, `gpu.blockIdx.x`, `gpu.blockDim.x`, `gpu.gridDim.x` (along with `.y` and `.z`).
- **Native CPU Fallback**: If no supported GPU hardware/driver is present, it automatically executes on a high-speed multi-core CPU SIMD engine without failing.
- **Dedicated Media & Game Graphics Pipeline**: High-throughput scanline rasterization directly on GPU/SIMD multi-core buffers via `GUIEngine` and `gpu.render_game_frame(...)`.

### C. Zero-Dependency Native Desktop GUI (`sundapy_std/screenGUI.zig`)

A built-in GUI engine created entirely in pure Zig without external dependencies:
- **No External C Libraries**: 0 bytes of Xlib, XCB, Wayland, SDL, GLFW, GTK, or Qt.
- **Pure X11/Wayland Wire Protocol Client**: Connects directly to the Linux Unix domain socket `/tmp/.X11-unix/X{display}` (natively supporting Native X Server and Wayland compositors via Xwayland).
- **Authentication**: Natively reads and parses binary `MIT-MAGIC-COOKIE-1` from `$XAUTHORITY` / `~/.Xauthority`, with seamless fallback for unauthenticated local sockets.
- **Window Management**: Implements `CreateWindow`, `ChangeProperty` (`WM_NAME`, `_NET_WM_NAME`, `_NET_WM_PID`, `WM_PROTOCOLS`, `WM_DELETE_WINDOW`), `CreateGC`, and `MapWindow`.
- **High-Framerate Blitting**: Uses chunked `PutImage` requests (ZPixmap 24-bit TrueColor / 32bpp BGR0) split into scanline strips to respect 16-bit X11 word limits, rendering frames in < 2.5 ms.
- **Event Handling**: Non-blocking `recvfrom(MSG.DONTWAIT)` event loop processes window close requests (`WM_DELETE_WINDOW`) and keyboard events (Keysym: Esc, 'q', 'r', arrows, space, shift, etc.).
- **Real-Time Telemetry**: Built-in heads-up display tracking FPS, GPU usage %, CPU usage %, RSS memory, render time, and display time.
- **Headless Fallback**: Falls back automatically to an ANSI TrueColor terminal buffer if `$DISPLAY` is unavailable.

### D. Super Mario Bros NES Engine & Benchmark Suite (`marioBros/`)

A complete, ultra-optimized 1-level Super Mario Bros World 1-1 game suite built for extreme GPU testing:
- **Zero External Assets**: No PNG/BMP sprites, textures, fonts, or audio. 100% of the 64-color NES palette, tile patterns (ground, bricks, question blocks, pipes, castle, flag), Mario sprites (idle, walk 1-3, jump, skid, flag slide, die), Goomba sprites (walk 1-2, squished), bouncing coins, and 8x8 retro font are generated procedurally at compile/start time.
- **120 FPS Frame Pacing**: Sub-millisecond sleep precision with delta-time compensation running at a native 120 FPS framerate target.
- **Architecture & Modules**:
  - `marioBros/level_1_1.py`: Full 224-column NES World 1-1 map layout, item positions, Goomba spawn points, staircases, and end-of-level flagpole & castle.
  - `marioBros/physics.py`: Frame-rate independent platformer physics, AABB sub-pixel collision resolution with map tiles, variable-height jump curves, Goomba stomp bounces, death arcs, flagpole sliding, and castle walk sequences.
  - `marioBros/entities.py`: Goomba patrol AI with tile collisions and pit turnaround, bouncing coin animations, and zero-allocation entity array pools.
  - `marioBros/ai_bot.py`: Frame-perfect speedrunner autopilot capable of clearing World 1-1 flawlessly, with seamless zero-latency human keyboard override.
  - `marioBros/main.py`: Interactive and benchmark game loop reporting comprehensive telemetry (Render Time, Screen Blit Time, FPS, GPU load, CPU usage, RSS footprint).
  - `src/datatype/sundapy_std/GUIEngine.zig`: Multi-purpose media & game engine rasterizer producing 240x224 NES framebuffers upscaled 4x to 960x480 native desktop windows with zero blit tearing.

### E. Package Manager (`sundafetch` - `src/fetcher/main.zig`)

A standalone pip/wheel alternative built into the compiler:
- Downloads wheels directly from the PyPI JSON API using Zig's native `std.http.Client` and TLS certificate bundle.
- Intelligently detects target environment: Python version, ABI tag (e.g., `cp312`, `cp313`, `cp313t` free-threaded), OS, and architecture.
- Extracts `.whl` (ZIP/Deflate) archives natively into `.cache/pyLibrary`.
- Resolves recursive dependencies from `requires_dist` metadata.
- Reads `requirements.txt` via `sundafetch -r requirements.txt`.

### F. C-ABI Compatibility Layer & Detection (`python_abi.zig`, `compiler.zig`, `transpile_file.zig`)

- **Automatic SO/PYD Detection**: Uses a non-recursive, flat iterative stack (`scanDirForSo`) to search packages for binary extensions (`.so`/`.pyd`) without recursion bomb risks.
- **Conditional Inclusion**:
  - **Pure Native Mode** (`[SUNDAPY] Python C-ABI compatibility layer: NOT REQUIRED`): When code uses pure Python or built-in stdlib, no CPython library is linked.
  - **Enabled C-ABI Mode** (`[SUNDAPY] Python C-ABI compatibility layer: ENABLED`): When binary packages (e.g. `numpy`, `PyQt6`, `scipy`) are imported, it generates a bridge stub and dynamically loads `libpython3.x.so` with GIL release and native thread synchronization.

### G. Multi-Pass Static & Escape Analysis (`src/transpiler/analysis/`)

- **Pass 1 (`escape_pass1.zig`)**: Collects all variable definitions, determines if they originate as primitives (`int`, `float`), and tracks initial scopes.
- **Pass 2 (`escape_pass2.zig`)**: Evaluates references across scopes, function calls, and assignments. Variables that never escape their scope remain on the stack as native Zig hardware primitives (`StorageClass.stack`), eliminating dynamic allocation overhead.

---

## 4. CLI Tooling & Commands

- **Run Script**: `sundapy script.py` (or `./zig-out/bin/sundapy script.py`)
- **Force Recompile**: `sundapy script.py -y` (bypasses hash cache)
- **Build Standalone Binary**: `sundapy --build script.py` (produces native binary in current directory)
- **Fetch Dependencies**: `sundapy fetch <package>` or `sundafetch <package>`
- **Install from Requirements**: `sundafetch -r requirements.txt`
- **Run Mario Bros 1-1 Demo**: `sundapy marioBros/main.py -y`
- **Run Automated Test Suite**: `./run_tests.sh` (executes all 134+ test cases)

---

## 5. Agent Instructions for Modifying Code

1. **Rule of Embedded Datatypes**:
   Any file inside `src/datatype/` that is used at runtime is baked into the compiler binary via `src/embedded_datatype.zig`. If you modify any file in `src/datatype/`:
   ```bash
   python3 generate_embedded.py
   zig build
   rm -rf .cache
   ```
2. **Rule of Cache Invalidation**:
   SundaPy caches binaries in `.cache/bin/` keyed by file hash. If you patch the compiler source code (`src/transpiler/`, `src/parser/`, etc.), running `sundapy test.py` will execute the old binary unless you clear `.cache`:
   ```bash
   rm -rf .cache/src .cache/bin .cache/hashes.txt
   ```
3. **Module Global Visibility**:
   In Zig, module-level variables are private by default. When transpiling Python module globals, ensure they are declared as `pub var` so that `@hasDecl` and reflection can find them across imported modules.
4. **No External GUI/Network Dependencies**:
   Never introduce external C library bindings (e.g. Xlib, SDL, GTK, cURL). Always use pure Zig standard library, POSIX sockets, or kernel syscalls.
5. **Non-Blocking Architecture**:
   When writing tests, GUI loops, or socket listeners, ensure events are polled or non-blocking to prevent deadlocks and socket queue overflow.
6. **Always Run Continuous Verification**:
   Before declaring any task complete, run `./run_tests.sh` to ensure all 134 tests pass cleanly with 0 errors.

---
*Document updated with complete 84 src/ file registry, Mario Bros GPU engine architecture, and multi-pass compiler specifications.*
