# SundaPy & Sundafetch: The AI Agent Specification, Architectural Guide, and Integration Manual

**Welcome, AI Agent.**
This document is the absolute single-source-of-truth regarding the architecture, operational semantics, codebase layout, and developer integration guidelines for **SundaPy** and its companion package manager **sundafetch**.

When an AI agent is tasked with creating, maintaining, optimizing, testing, or building Python projects with SundaPy, or extending the SundaPy compiler itself, **this manual is the primary reference**. Do not assume standard CPython interpreter constraints or behaviors apply universally here.

---

## 1. Executive Overview & Core Philosophy

### 1.1 What is SundaPy?
**SundaPy** is an extreme-performance **Ahead-Of-Time (AOT) Python-to-Zig transpiler, LLVM native compiler, and standalone runtime**. It translates standard Python source code directly into pure native Zig source code, which is then compiled via Zig's LLVM backend into tiny, self-contained, bare-metal native executable binaries (ELF on Linux, Mach-O on macOS) with instantaneous startup times (< 2 ms) and zero runtime dependencies.

SundaPy is engineered as a **drop-in substitute** for developers and AI agents who want to execute Python projects with bare-metal, native machine performance while completely shedding the performance bottlenecks of the standard Python Virtual Machine (CPython).

### 1.2 Core Architectural Pillars

```text
+-----------------------------------------------------------------------------------------+
|                                SUNDAPY ARCHITECTURAL PILLARS                            |
+-----------------------------------------------------------------------------------------+
|                                                                                         |
|  1. ZERO PYTHON VM OVERHEAD                                                             |
|     - No CPython interpreter, no bytecode loop, no PVM overhead.                        |
|     - Python AST is lowered directly to pure native Zig source code.                    |
|     - Compiled into standalone ELF binaries (often < 500 KB) with bare-metal execution. |
|                                                                                         |
|  2. TRUE MULTI-CORE CONCURRENCY & ZERO GIL                                              |
|     - The Global Interpreter Lock (GIL) is completely eliminated.                       |
|     - Python threads map directly to native OS kernel threads (std.Thread).             |
|     - CPU-bound parallel workloads scale linearly across all CPU cores.                 |
|                                                                                         |
|  3. SEAMLESS PYTHON ECOSYSTEM COMPATIBILITY (C-ABI INTEGRATION)                         |
|     - Full compatibility with the existing Python ecosystem (PyPI / pip).               |
|     - Host Python C-ABI bridge dynamically links libpython3.*.so on-demand.             |
|     - Binary packages (NumPy, PyTorch, SciPy, bs4, etc.) run with zero friction.        |
|     - Dual-mode: Pure Native Mode (0% Python linkage) vs Enabled C-ABI Mode.            |
|                                                                                         |
|  4. OPTIONAL STRONG STATIC TYPING & RAW HARDWARE OPTIMIZATION (#strict)                 |
|     - #strict directive on line 1 enables optional strong static typing.                |
|     - Hardware primitive types (i8..i1024, u8..u1024, f32, f64, bool).                  |
|     - Zero dynamic boxing overhead (bypasses 24-byte Dynamic tagged union).             |
|     - Direct CPU register and stack allocation via Two-Pass Escape Analysis.            |
|     - Raw CPU ALU instructions, SIMD vectorization, and @setRuntimeSafety guards.       |
|                                                                                         |
+-----------------------------------------------------------------------------------------+
```

1. **Elimination of the Python VM**:
   Standard Python programs depend on the CPython virtual machine to interpret bytecode sequentially. SundaPy completely removes this dependency. The Python source code is transpiled to optimized Zig code and compiled directly into native machine code. Programs execute directly on hardware registers and native system call interfaces.

2. **Zero Global Interpreter Lock (No GIL)**:
   In CPython, multithreading is crippled by the Global Interpreter Lock (GIL), forcing threads to serialize execution. In SundaPy, multithreading (`import threading` or `import _thread`) spawns true POSIX/OS kernel threads (`std.Thread`). Parallel computing, physics loops, ray tracing, and vector operations achieve genuine 100% multi-core CPU saturation.

3. **Full Python Ecosystem Compatibility (Host Python C-ABI)**:
   SundaPy does not isolate itself from the vast Python package ecosystem. When code imports pure Python modules or SundaPy native standard libraries, SundaPy runs in **Pure Native Mode** (`[SUNDAPY] Python C-ABI compatibility layer: NOT REQUIRED`). When binary extension wheels containing compiled `.so` or `.pyd` files (such as `numpy`, `torch`, `scipy`, or `pandas`) are imported, SundaPy automatically switches to **Enabled C-ABI Mode** (`[SUNDAPY] Python C-ABI compatibility layer: ENABLED`). It dynamically links against the host device's existing `libpython3.*.so` runtime via `dlopen`/`dlsym`, marshals arguments, and releases the GIL during heavy operations.

4. **Optional Strong Static Typing & Raw Code Optimization (`#strict`)**:
   By placing `#strict` on the very first line of a script, developers can opt into strong static typing. Types are not mere hints—they are strictly enforced at compile time. Variables and functions map directly to native Zig hardware types (`i32`, `i64`, `f32`, `f64`, etc.), eliminating all boxing overhead and memory allocations.

5. **Zero External GUI/Network Dependencies**:
   SundaPy's standard libraries (`screenGUI`, `GUIEngine`, `socket`, `requests`, `gpu`) are written in 100% pure Zig using direct Linux kernel syscalls and wire protocols—requiring zero external C libraries like Xlib, XCB, SDL, GTK, Qt, or OpenSSL.

---

## 2. Package Management with `sundafetch`

### 2.1 Overview & Architecture
`sundafetch` is a standalone, high-performance, zero-dependency package manager and wheel installer built directly into the SundaPy repository (`src/fetcher/`). It serves as an isolated, modern alternative to `pip`.

### 2.2 Key Features
- **Zero External Dependencies**: Implemented in 100% pure Zig using `std.http.Client` for network requests and an internal pure Zig ZIP/Deflate decompressor (`src/fetcher/zip.zig`).
- **Target Environment Autodetection**: Inspects the host machine to determine:
  - Python version (`sys.version_info`)
  - Target ABI tag (e.g. `cp314`, `cp313`, `cp312`, or free-threaded `cp313t` / `cp314t`)
  - Target OS (`linux`, `macosx`)
  - Target CPU architecture (`x86_64`, `aarch64`)
- **Direct PyPI JSON API Integration**: Queries `https://pypi.org/pypi/<pkg>/json` directly, evaluates wheel compatibility according to PEP 425 tags, and downloads matching `.whl` archives.
- **Recursive Dependency Resolution**: Parses `requires_dist` metadata from wheel `METADATA` files, resolving and downloading transitive dependencies automatically.
- **Strictly Isolated Local Installation**: All packages are installed into `.cache/pyLibrary/` within the project root. This ensures:
  - Zero contamination of system or global Python environments.
  - Fully reproducible, project-local dependency resolution.
  - Offline execution once dependencies are cached.
- **Supply-Chain & Archive Security Hardening**:
  - **Zip-Slip Prevention**: Path sanitization, segment verification, and traversal rejection (`..`, `:`, `/`, `\0`).
  - **Decompression Bomb Protection**: Quotas enforcing max entry size (1 GB), total archive size (4 GB), entry count (50,000), and max compression ratio (100:1).
  - **Symlink & Special File Rejection**: Rejects symlinks and device files violating PEP 427.
  - **Cryptographic Digest Validation**: Automatic streaming SHA-256 calculation and verification against PyPI JSON digests.
  - **Package & Identifier Validation**: Strict PEP 508 / PEP 426 package name sanitization and entrypoint identifier verification.
- **Native TLS Certificate Handling**: Uses Zig's `std.crypto.Certificate.Bundle.rescan` to load root trust anchors from the host operating system without requiring OpenSSL.

### 2.3 CLI Usage
```bash
# Fetch a single package into .cache/pyLibrary/
sundafetch numpy
# Or via the compiler driver:
sundapy fetch numpy

# Fetch multiple packages
sundafetch requests beautifulsoup4 pillow

# Install from requirements.txt
sundafetch -r requirements.txt
# Or passing requirements file directly:
sundafetch requirements.txt

# Fetch or install, then immediately build into a standalone binary:
sundafetch --build yt-dlp
# Or with a custom output binary name:
sundafetch -b yt-dlp -o yt-dlp-bin
# Or build a cloned local repository / directory:
sundafetch --build ./path/to/repo -o my-cli
# Or in the current project directory (auto-detects entrypoints):
sundafetch --build

# Help
sundafetch --help
```

---

## 3. Dual Compilation & Execution Modes: Dynamic vs `#strict`

SundaPy operates in one of two distinct compilation modes determined by the first line of the file:

```text
+------------------------------------------------------------------------------------------------+
|                             COMPILATION MODES COMPARISON MATRIX                                |
+-----------------------------------+------------------------------------------------------------+
| Dynamic Mode (Default)            | #strict Mode (Line 1 Directive)                            |
+-----------------------------------+------------------------------------------------------------+
| First line: Regular Python code   | First line: #strict                                        |
| Dynamic duck typing               | Strong compile-time static type invariance                 |
| Boxed into 24-byte Dynamic union  | Pure hardware primitives (i8..i1024, u8..u1024, f32, f64)  |
| Full Python semantics & flexibility| Bare-metal CPU register & ALU instructions                 |
| Automatic escape stack promotion  | Zero boxing, zero allocation overhead                      |
| Great for scripts, JSON, scraping | Great for algorithms, physics, SIMD, shaders, game loops   |
+-----------------------------------+------------------------------------------------------------+
```

### 3.1 Dynamic Mode (Default)
When `#strict` is absent:
- Every variable is encapsulated within a 24-byte `Dynamic` tagged union (`src/datatype/dynamic.zig`), capable of representing 37 distinct Python runtime types (`int_type`, `float_type`, `str_type`, `list_type`, `dict_type`, `py_obj_type`, `gpu_buffer_type`, etc.).
- Operations (`+`, `-`, `*`, `[]`, `.`, `()`) resolve dynamically via tagged union dispatchers.
- **Two-Pass Escape Analysis** automatically identifies unescaped local variables and optimizes them onto the native CPU stack, minimizing heap allocations.

### 3.2 `#strict` Mode (Hardware Native Performance)
When `#strict` is placed on line 1:
- **Mandatory Static Type Annotations**: All variable definitions and function signatures must have explicit static types:
  ```python
  #strict

  def calculate_energy(mass: f64, velocity: f64) -> f64:
      kinetic: f64 = 0.5 * mass * velocity * velocity
      return kinetic

  def main() -> void:
      m: f64 = 10.0
      v: f64 = 25.0
      e: f64 = calculate_energy(m, v)
      print(e)

  main()
  ```
- **Supported Hardware Primitive Types**:
  - **Signed Integers**: `i8`, `i16`, `i32`, `i64` (default canonical integer), `i128`, `i256`, `i512`, `i1024`.
  - **Unsigned Integers**: `u8` (bytes, colors), `u16` (ports), `u32` (ARGB packed), `u64` (device pointers, hashes), `u128`..`u1024`.
  - **Floating Point**: `f32` (standard 3D graphics/GPU), `f64` (standard main float).
  - **Boolean**: `bool` (`true`, `false`).
  - **String Slice**: `str` (maps directly to Zig `[]const u8`).
  - **Return Type**: `void` (for functions without a return value).
- **Zero Boxing Overhead**: Primitives map 1:1 to native Zig CPU types. No tagged union wrapper, no reference counting, no heap allocations.
- **Compiler Safety Guards**: The transpiler automatically injects `@setRuntimeSafety(true)`. Arithmetic overflows panic immediately rather than wrapping or corrupting memory silently.
- **Forbidden Constructs in `#strict`**:
  - Untyped variables will fail at transpile time with `error.MissingTypeAnnotation`.
  - Dynamic list comprehensions without an explicit allocator are disallowed to preserve zero-allocation guarantees.

---

## 4. Python C-ABI Integration & Ecosystem Compatibility

One of SundaPy's crowning architectural achievements is the transparent C-ABI bridge (`src/datatype/python_abi.zig`, `src/datatype/python_abi/`).

```text
+------------------------------------------------------------------------------------------+
|                              PYTHON C-ABI BRIDGING ARCHITECTURE                          |
+------------------------------------------------------------------------------------------+
|                                                                                          |
|    SundaPy Code (Pure Zig / Native Executable)                                           |
|        |                                                                                 |
|        +---> Imports pure Python / stdlib?                                               |
|        |         |                                                                       |
|        |         +--> [PURE NATIVE MODE]                                                 |
|        |              - 0% Python VM linkage                                             |
|        |              - Instantaneous startup (<2ms), tiny ELF binary (<500 KB)          |
|        |                                                                                 |
|        +---> Imports binary wheel (numpy, torch, scipy, etc.)?                            |
|                  |                                                                       |
|                  +--> [ENABLED C-ABI MODE]                                               |
|                       - dlopen("libpython3.*.so", RTLD_LAZY | RTLD_GLOBAL)               |
|                       - Non-recursive flat iterative SO scanner (scanDirForSo)           |
|                       - PyGILState_Ensure() / PyGILState_Release() on native threads     |
|                       - Bidirectional Dynamic <-> PyObject value marshaling              |
|                       - Transparent asynchronous coroutine resolution (_sundapy_eval_coro)|
|                                                                                          |
+------------------------------------------------------------------------------------------+
```

### 4.1 Flat Iterative SO/PYD Scanner (`compiler.zig`)
During compilation, the compiler analyzes import statements. Instead of recursive filesystem directory walks that risk stack exhaustion, SundaPy uses an iterative heap-backed stack scanner (`scanDirForSo`) to detect binary extension modules (`.so` or `.pyd`) in local directories and `.cache/pyLibrary/`.

### 4.2 Dynamic Loading via `dlopen`/`dlsym` (`symbols.zig`)
If binary modules are detected:
- SundaPy dynamically loads the host's Python shared library (`libpython3.14.so` down through `libpython3.10.so`).
- No C headers or build-time Python development libraries (`python3-dev`) are required during initial SundaPy compilation.
- Resolves core CPython symbols at runtime: `Py_Initialize`, `PyImport_Import`, `PyObject_Call`, `PyGILState_Ensure`, `PyGILState_Release`, `PyEval_SaveThread`, etc.

### 4.3 GIL State Management & Multithreading
When running across multi-core native threads:
- SundaPy initializes Python and saves the main thread state with `PyEval_SaveThread()`, freeing the GIL.
- Whenever a native thread interacts with a CPython object, it acquires the GIL via `PyGILState_Ensure()` and immediately releases it via `PyGILState_Release()`.
- Native CPU computations outside the C-ABI call continue running completely in parallel across cores without GIL interference!

### 4.4 Value Marshaling (`conv.zig`)
Automatic bidirectional conversion:
- Integers: `i64` $\leftrightarrow$ `PyLong_FromLongLong` / `PyLong_AsLongLong`
- Floats: `f64` $\leftrightarrow$ `PyFloat_FromDouble` / `PyFloat_AsDouble`
- Booleans: `bool` $\leftrightarrow$ `PyBool_FromLong`
- Strings: `[]const u8` $\leftrightarrow$ `PyUnicode_FromStringAndSize` / `PyUnicode_AsUTF8AndSize`
- Lists & Tuples: Native lists $\leftrightarrow$ `PyList_New` / `PyTuple_New`
- Dictionaries: Native dicts $\leftrightarrow$ `PyDict_New` / `PyDict_SetItemString`
- Objects: Arbitrary CPython objects wrap into `Dynamic.value.py_obj_type`.

---

## 5. Built-in Subsystems & Standard Library Deep Dive

### 5.1 GPU Computing Engine (`sundapy_std/gpu.zig`, `gpu_types.zig`, `GUIEngine.zig`)
SundaPy provides a high-throughput, bare-metal GPU computing engine:
- **Dynamic Multi-Distro Driver Loading**: Dynamically probes 17+ distribution paths (Arch, CachyOS, Ubuntu, Debian, Fedora, Jetson ARM64, Alpine) for `libcuda.so.1`, `libvulkan.so.1`, and `libOpenCL.so.1`. Zero CUDA Toolkit required.
- **Hardware Virtual Memory Management (VMM)**: Direct driver calls to `cuMemAddressReserve`, `cuMemCreate`, `cuMemMap`, and `cuMemSetAccess` for physical allocation stitching.
- **Pinned Host Memory (Page-Locked DMA)**: `gpu.alloc_pinned(size, "f32")` allocates memory with `cuMemHostAlloc` for zero-staging-bounce DMA PCIe transfers.
- **Sub-1.5 µs CUDA Graph Engine**: Instantiates and executes dependency graphs (`cuGraphCreate`, `cuGraphAddKernelNode`, `cuGraphInstantiate`, `cuGraphLaunch`) for near-zero launch overhead.
- **Multi-Codec Memory Compression**: Built-in GPU compression algorithms including FPC (Floating-Point Compression), LZ, Quantization, and Ultra-compression.
- **Memory Abstractions**:
  - High-Level Arrays (HLA): `gpu.field(dims, fill)` for natural multidimensional grid indexing (`f[y, x]`).
  - Low-Level Allocator (LLA): `gpu.arena_alloc(bytes)` and `gpu.arena_reset()` for ultra-fast sub-microsecond scratchpad allocations per frame.
  - Multi-Worker Pool: `gpu.pool_dispatch(func, args)` for parallel background compute batches.
- **CPU SIMD Fallback**: If no GPU driver is installed, SundaPy automatically executes kernels using a high-speed multi-core CPU SIMD engine without failing.

### 5.2 Zero-Dependency Desktop GUI Engine (`sundapy_std/screenGUI.zig`, `GUIEngine.zig`)
- **100% Pure Zig Wire Protocol**: Communicates directly over the Linux Unix domain socket `/tmp/.X11-unix/X{display}`. Compatible with native X11 servers and Wayland compositors (via Xwayland).
- **0 Bytes External C GUI Libraries**: Eliminates all dependencies on Xlib, XCB, SDL, GLFW, GTK, or Qt.
- **Authentication**: Natively parses binary `MIT-MAGIC-COOKIE-1` from `$XAUTHORITY` / `~/.Xauthority`.
- **Ultra-High Framerate Blitting**: Chunked scanline `PutImage` requests render full-screen 1440p/4K frames in < 2.5 ms (achieving 60–120+ FPS).
- **Interactive Event Loop**: Non-blocking `recvfrom(MSG.DONTWAIT)` loop captures keyboard keysyms, mouse coordinates, and window close events (`WM_DELETE_WINDOW`).
- **Telemetry HUD**: Real-time on-screen telemetry tracking FPS, render time, display time, GPU %, CPU %, and RSS memory usage.
- **2D Drawing API (`GUIEngine`)**: Primitive canvas functions for drawing pixels, lines, rectangles, circles, anti-aliased text, and blitting bitmap surfaces.

### 5.3 Concurrency & Multithreading (`threading.zig`, `_thread.zig`, `asyncio.zig`)
- **Zero-GIL POSIX Threads**: `threading.Thread(target=fn, args=(...))` creates native OS kernel threads.
- **Mutex Locks**: `threading.Lock()` provides non-blocking and blocking synchronization primitives.
- **Asynchronous Coroutines**: `async def`, `await`, `asyncio.sleep()`, and `asyncio.gather()` operate on a native event loop.

### 5.4 Networking (`socket.zig`, `requests.zig`)
- **Raw POSIX Sockets**: `socket.socket(AF_INET, SOCK_STREAM)` provides non-blocking TCP/UDP network communication.
- **Native HTTP/1.1 Client (`requests`)**: Zero-dependency pure Zig HTTP client with `requests.get()`, `requests.post()`, header support, and JSON parsing.

### 5.5 Direct C & Zig Interoperability vs Dynamic FFI (`@cImport`, `@import`, `ffi.zig`, `#@link`)
- **Direct C Header Import**:
  Imports `.h` or `.c` files directly using the `import` keyword, lowering directly to Zig `@cImport` with automatic linking:
  ```python
  import "math.h" as cmath
  #@link "-lm"

  print(cmath.sqrt(144.0))
  ```
- **Direct Zig Source Import**:
  Native Zig files (`.zig`) can be imported directly using the standard `import` keyword. SundaPy compiles and links them directly without boxing overhead, supporting structs, methods, error unions, and constants across both Dynamic and `#strict` modes:
  ```python
  import "fixtures/sample_zig_lib.zig" as my_zig
  from "fixtures/sample_zig_lib.zig" import Point, add_i32

  # Direct struct instantiation and method invocation
  pt = Point.init(10, 20)
  print(pt.sum())
  ```
  Or importing project-local Zig modules directly without quotes:
  ```python
  import sample_zig_local
  print(sample_zig_local.local_double(21))
  ```
- **Dynamic FFI Subsystem for Shared Objects (`.so`, `.dll`)**:
  Compiled dynamic libraries from Rust, Go, C++, or prebuilt Zig remain controlled explicitly through the `ffi` module:
  ```python
  import ffi

  libc = ffi.load("libc.so.6")
  puts = libc.get_fn("puts", "i32", ["str"])
  puts("Hello from direct libc FFI!")
  ```

### 5.6 Modern Python Syntax & PEP Features
- **PEP 822 Dedented Strings (`d"..."`)**: Compile-time stripped multiline text.
- **PEP 750 Template Strings (`t"..."`)**: Zero-overhead template tokens.
- **PEP 758 Multi-Catch Exceptions**: `except (TypeError, ValueError):` and `except TypeError, ValueError:`.
- **Pattern Matching (`match ... case`)**: Structural pattern matching with literal, sequence, and wildcard matching.
- **Modern Operators**: Walrus operator `:=`, Null-Coalescing `??`, and Safe Navigation `?.`.

---

## 6. Complete Modular File Registry of `src/` (183 Source Files)

Every file in `src/` adheres to a strict modular design with **strictly $\le$ 400 lines of code per file**:

```text
src/
├── main.zig                              # Minimal entrypoint delegating CLI arguments to runner
├── embedded_datatype.zig                 # Compile-time @embedFile registry of all runtime datatypes & stdlib
│
├── cli/                                  # Command Line Interface & Build Orchestrator
│   ├── runner.zig                        # Main CLI dispatcher, compilation flow, caching, binary execution
│   ├── builder.zig                       # Executable builder, zig build-exe invocation, binary stripping
│   ├── init.zig                          # Project initializer (sundapy init) embedding templates & AGENTS.md
│   ├── missing_modules.zig               # Interactive prompt & auto-installer for missing PyPI dependencies
│   └── templates/                        # Project scaffolding templates
│       ├── main.py                       # Default #strict template file
│       ├── AGENTS.md                     # The definitive AI agent manual (embedded in new projects)
│       ├── SUNDAPY_GUIDE.md              # User cheatsheet & decision matrix
│       ├── pyrightconfig.json            # VSCode type checker configuration
│       ├── typings/                      # Rich Python type stubs (.pyi) for IDE IntelliSense
│       └── vscode/                       # VSCode settings, tasks (Ctrl+Shift+B), and code snippets
│
├── fetcher/                              # `sundafetch` Standalone Package Manager
│   ├── main.zig                          # CLI entrypoint for package resolution & extraction
│   ├── env.zig                           # Environment detection (Python version, ABI tags, OS, Arch)
│   ├── installer.zig                     # PyPI JSON API client, wheel resolver, transitive dependencies
│   ├── types.zig                         # Target environment & package metadata structures
│   ├── zip.zig                           # Pure Zig streaming ZIP/Deflate archive decompressor
│   ├── detect_dist.zig                   # Dist-info & egg-info console_scripts entry point parser
│   ├── detect_entry.zig                  # Project entrypoint detection (pyproject.toml, setup.py, __main__.py)
│   └── build_exec.zig                    # Entrypoint wrapper generator & compiler invocation
│
├── core/                                 # Compiler Core State & Orchestration
│   ├── ast.zig                           # Unified Abstract Syntax Tree (AST) node definitions
│   ├── compiler.zig                      # Global compiler state, SO file scanner, missing module tracker
│   ├── compiler_check.zig                # Validates Zig 0.16.0 compiler presence in PATH or local cache
│   ├── cache.zig                         # Wyhash-based incremental content hashing & .cache/ management
│   └── transpile_file.zig                # File-level transpilation pipeline & import dependency graph
│
├── lexer/                                # Indentation-Aware Python Lexer
│   ├── token.zig                         # Token enum and Token structure definitions
│   ├── lexer_keyword.zig                 # Keyword matcher (if, def, class, match, async, strict, etc.)
│   └── lexer.zig                         # Indentation stack tracker (handles newlines, indents, dedents)
│
├── parser/                               # Pratt Recursive-Descent Parser Engine
│   ├── parser.zig                        # Parser state, operator precedence hierarchy
│   ├── expr.zig                          # Expression parsing dispatcher using Pratt algorithm
│   ├── expr_prefix.zig                   # Prefix expressions (literals, unary, list comp, await, walrus)
│   ├── expr_infix.zig                    # Infix expressions (calls, attributes, indexing, slicing, binops)
│   ├── stmt.zig                          # Statement dispatcher & block indentation processor
│   ├── stmt_decl.zig                     # Function (def) & Class (class) declaration parser
│   ├── stmt_assign_parse.zig             # Assignment expressions parser
│   └── stmt_control_parse.zig            # Control flow parser (if, while, for, match, try-except)
│
├── transpiler/                           # Code Generation & Emission Engine
│   ├── transpiler.zig                    # Central transpiler struct, code emitter, scope tracker
│   ├── driver.zig                        # Transpilation orchestration, import collection, strict pass
│   ├── stmt_dispatcher.zig               # Statement code generation dispatcher
│   ├── stmt.zig                          # Statement emission helpers
│   ├── analysis/                         # Multi-Pass Static & Escape Analysis
│   │   ├── analysis.zig                  # Static analysis coordinator
│   │   ├── escape.zig                    # Escape analysis orchestrator & storage classifier
│   │   ├── escape_pass1.zig              # Pass 1: Variable definitions, primitive origins, scopes
│   │   └── escape_pass2.zig              # Pass 2: Variable escape detection & stack promotion
│   ├── stmt/                             # Specialized Statement Generators
│   │   ├── stmt_assign.zig               # Assignments (=, +=, :=, tuple unpacking, subscripts)
│   │   ├── stmt_class.zig                # OOP classes to Zig structs and methods
│   │   ├── stmt_control.zig              # Control statements (if, while, for, try-except-finally)
│   │   ├── stmt_def.zig                  # Functions, decorators, hardware type signatures
│   │   ├── stmt_for_idiom.zig            # Optimized counter loops without iterator allocation
│   │   ├── stmt_match.zig                # Pattern matching (match/case) transpilation
│   │   └── stmt_misc.zig                 # Return, yield, raise, expression statements
│   └── expr/                             # Specialized Expression Generators
│       ├── expr.zig                      # Dynamic mode expression code generation
│       ├── expr_strict.zig               # Strict mode native expression code generation
│       ├── expr_strict_call.zig          # Strict mode function and method calls
│       ├── expr_strict_call_builtin.zig  # Strict mode built-in function calls
│       ├── expr_strict_call_class.zig    # Strict mode class instantiations
│       ├── expr_strict_method.zig        # Strict mode methods on native structures
│       ├── expr_access.zig               # Attribute and item access
│       ├── expr_fstring.zig              # F-string interpolation lowering
│       ├── expr_idiom_bit.zig            # Bitwise operation idioms
│       ├── expr_idiom_bit_ops.zig        # Hardware bit twiddling idioms
│       ├── expr_idiom_call.zig           # Inlined call idioms
│       ├── expr_idiom_cmp.zig            # Fast comparison lowering
│       ├── expr_idiom_lowering.zig       # Expression lowering optimizer
│       ├── expr_math_intrinsics.zig      # Hardware math intrinsics (isqrt, gcd, lcm, etc.)
│       ├── expr_op_map.zig               # Operator mapping tables
│       └── expr_string_tools.zig         # String formatting tools
│
└── datatype/                             # Runtime Datatypes & Standard Library (Pure Zig)
    ├── dynamic.zig                       # Central 24-byte Dynamic tagged union (PyObject equivalent)
    ├── dynamic_dispatch.zig              # Dynamic function dispatching & method invocation
    ├── dynamic_item.zig                  # Dynamic item retrieval & slicing (__getitem__)
    ├── dynamic_items.zig                 # Dynamic item assignment (__setitem__)
    ├── dynamic_ops.zig                   # Dynamic arithmetic operations (+, -, *, /, %, **)
    ├── dynamic_ops_bitwise.zig           # Dynamic bitwise operations (&, |, ^, ~, <<, >>)
    ├── dynamic_ops_cmp.zig               # Dynamic comparisons (==, !=, <, >, <=, >=, in, is)
    ├── dynamic_str.zig                   # Dynamic string conversion & formatting
    ├── str_methods.zig                   # Core string methods helper
    ├── gpu_types.zig                     # GpuBuffer & GpuKernel core types
    ├── gpu_buffer_ops.zig                # GPU buffer manipulation operations
    ├── gpu_compress_read.zig             # Decompression read routines
    ├── gpu_kernel_types.zig              # Kernel invocation types
    ├── python_abi.zig                    # CPython C-ABI dynamic bridge coordinator
    ├── sentinel.zig                      # Sentinel values (None, Ellipsis)
    ├── dynamic/                          # Dynamic Built-in Function Implementations
    │   ├── builtins.zig                  # Python built-ins aggregator
    │   ├── builtins_conv.zig             # Conversion built-ins (int, float, str, bool, list, dict)
    │   ├── builtins_extra.zig            # Utility built-ins (any, all, sum, enumerate, zip, id)
    │   ├── builtins_iter.zig             # Iterators (iter, next, range, reversed, sorted)
    │   ├── builtins_math.zig             # Math functions (abs, round, pow, min, max, divmod)
    │   ├── list_methods.zig              # List methods (append, pop, extend, sort, reverse)
    │   ├── print.zig                     # Zero-allocation console printing
    │   └── str_methods.zig               # String methods (upper, lower, strip, split, replace)
    ├── primitive/                        # Hardware Primitive Wrappers
    │   ├── index.zig                     # Primitive exports index
    │   └── bool.zig                      # Native boolean type wrapper
    ├── numeric/                          # Numerical Type Implementations
    │   ├── index.zig                     # Numeric exports index
    │   ├── int.zig                       # Arbitrary bit-width integer operations
    │   ├── float.zig                     # Floating point operations (f32, f64, f128)
    │   └── complex.zig                   # Complex numbers (std.math.Complex)
    ├── sequence/                         # Sequence Data Structures
    │   ├── sequence.zig                  # Sequence protocols index
    │   ├── range.zig                     # range(start, stop, step) iterator
    │   ├── list.zig                      # Dynamic resizable list (ArrayList backing)
    │   ├── binary.zig                    # Bytes and bytearray implementations
    │   └── string/                       # UTF-8 & UTF-16 String Implementations
    │       ├── index.zig                 # String module exports
    │       ├── types.zig                 # Core string structures
    │       ├── methods_case.zig          # Case transformations (upper, lower, title)
    │       └── methods_split.zig         # Splitting & partitioning (split, rsplit)
    ├── mapping/                          # Hash Maps & Dictionaries
    │   ├── mapping.zig                   # Mapping module index
    │   ├── dict.zig                      # Dynamic hash map (Python dict implementation)
    │   └── frozendict.zig                # Immutable hash map
    ├── set/                              # Hash Sets
    │   ├── set.zig                       # Dynamic hash set implementation
    │   └── index.zig                     # Set module exports
    ├── python_abi/                       # CPython C-ABI Interop Internals
    │   ├── symbols.zig                   # Dynamic symbol loader (dlopen libpython3.*.so)
    │   └── conv.zig                      # PyObject <-> Dynamic marshaling routines
    └── sundapy_std/                      # Native Built-in Standard Libraries
        ├── time.zig                      # High-resolution timers (time_ns(), perf_counter(), sleep())
        ├── _thread.zig                   # Low-level native threading
        ├── threading.zig                 # High-level threading (Thread, Lock, zero-GIL)
        ├── socket.zig                    # Raw POSIX network sockets (TCP/UDP, non-blocking)
        ├── requests.zig                  # Zero-dependency native HTTP/1.1 client
        ├── asyncio.zig                   # Native event loop & coroutine scheduler
        ├── math.zig                      # Accelerated FPU math & hardware intrinsics
        ├── math_integer.zig              # Integer math functions (gcd, lcm, isqrt, comb, factorial)
        ├── ffi.zig                       # Dynamic Foreign Function Interface
        ├── screenGUI.zig                 # 100% pure Zig Native X11 wire protocol window engine
        ├── screen_*.zig                  # X11 init, input, compression, dirty-rects, ANSI fallback
        ├── GUIEngine.zig                 # 2D canvas drawing & blitting engine
        ├── gui_*.zig                     # Canvas batching, clipping, font, palette, primitives
        ├── gpu.zig                       # CUDA Driver API & SIMD CPU fallback coordinator
        └── gpu_*.zig                     # Virtual memory management, graphs, compression, arenas
```

---

## 7. CLI Command Reference & Build Tooling

```bash
# 1. Project Scaffolding
sundapy init
# Scaffolds main.py, AGENTS.md, SUNDAPY_GUIDE.md, pyrightconfig.json, and .vscode/ typings.

# 2. Run Script (Standard Balanced Mode)
sundapy main.py
# Uses ReleaseSmall optimization, Wyhash caching, sub-2ms startup.

# 3. Force Recompilation
sundapy -y main.py
# Bypasses the .cache/bin/ content hash check and forces a full re-transpile and build.

# 4. Maximum Performance Execution
sundapy --fast main.py
# Compiles with LLVM ReleaseFast (-O3), enables SIMD, and disables integer overflow checks.

# 5. Debug Mode
sundapy --debug main.py
# Compiles with ReleaseSafe, retains full debug symbols and runtime safety guards.

# 6. Build Standalone Native Binary
sundapy --build main.py
# Emits standalone executable './main' in current directory (ELF on Linux, Mach-O on macOS).

# 7. Build with Custom Binary Name
sundapy --outname my_app main.py
# Compiles and generates standalone binary './my_app'.

# 8. Dependency Management & Binary Packaging via sundafetch
sundapy fetch <package_name>
# Or standalone:
sundafetch <package_name>
sundafetch -r requirements.txt
# Fetch and build directly into a standalone binary:
sundafetch --build <package_or_repo> -o <bin_name>
# Or via compiler driver:
sundapy fetch --build <package_or_repo> -o <bin_name>
```

---

## 8. AI Agent Integration & Developer Playbook

When an AI agent is building, optimizing, debugging, or integrating projects using SundaPy, it must follow these structured protocols:

### 8.1 Step 1: Project Initialization
Always start by initializing the project workspace:
```bash
sundapy init
```
This guarantees the existence of `.vscode/typings/`, `pyrightconfig.json`, `SUNDAPY_GUIDE.md`, and `AGENTS.md`.

### 8.2 Step 2: Choosing the Right Execution Mode

| Task / Problem Domain | Recommended Mode | Directive | Rationale |
| :--- | :--- | :--- | :--- |
| Mathematical calculation, matrix algebra, simulations | **#strict Mode** | `#strict` on Line 1 | Direct CPU registers, hardware ALU, zero dynamic boxing |
| 3D / 2D Game loops, physics engines, shaders | **#strict Mode** | `#strict` on Line 1 | Nanosecond latencies, zero GC pauses, deterministic memory |
| Benchmarks & algorithmic competition | **#strict Mode** | `#strict` on Line 1 | Equivalent to C/Zig execution speeds |
| General automation, JSON parsing, file utilities | **Dynamic Mode** | Omit `#strict` | Duck typing, flexible structures, rapid prototyping |
| Heavy external PyPI ecosystem workflows | **Dynamic Mode** | Omit `#strict` | Automatic C-ABI bridging to NumPy, bs4, etc. |

### 8.3 Step 3: Writing Idiomatic `#strict` Code
In `#strict` mode, adhere to these non-negotiable rules:
1. `#strict` must be the absolute first line of the `.py` file.
2. Every variable initialization must specify an explicit hardware type annotation:
   ```python
   # Correct:
   counter: i64 = 0
   rate: f64 = 0.05
   is_active: bool = True

   # Incorrect (will trigger error.MissingTypeAnnotation):
   counter = 0
   ```
3. Every function signature must annotate all parameter types and the return type:
   ```python
   def process_data(samples: i64, scale: f64) -> f64:
       return samples * scale
   ```
4. Choose appropriate hardware types:
   - Use `i64` as standard integer and `f64` as standard float.
   - Use `u8` for raw bytes and RGBA color channels (`0..255`).
   - Use `i32` for screen coordinates and dimensions.
   - Use `f32` for GPU field arrays and 3D vector coordinates.
   - Use `void` for procedures that return nothing.

### 8.4 Step 4: Installing and Importing External Dependencies
To integrate external PyPI libraries:
1. Run `sundapy fetch <pkg>` (or `sundafetch -r requirements.txt`).
2. Packages will install into `.cache/pyLibrary/`.
3. In your Python script, simply `import <pkg>` or `from <pkg> import ...`.
4. SundaPy's compiler will scan for `.so`/`.pyd` binaries, automatically enable the C-ABI compatibility layer, and execute seamlessly.

### 8.5 Step 5: Compiling and Distributing Executables
When preparing a project for deployment:
```bash
# Maximum performance standalone build:
sundapy --build --fast --outname release_app main.py
```
This produces a single, stripped native machine binary with zero dependencies on Python or Zig runtimes.

### 8.6 Step 6: Modifying SundaPy Compiler Source Code (Developer Rules)

If an AI agent is tasked with extending or debugging the SundaPy compiler itself, it must strictly observe the following ironclad engineering rules:

1. **The Rule of Line Count (Strictly $\le$ 400 lines per file)**:
   Every single `.zig` file in `src/` must remain strictly $\le$ 400 lines of code. If a file approaches or exceeds 400 lines, it must be modularized into sub-files or helper modules.
2. **The Rule of Embedded Datatypes**:
   Any file inside `src/datatype/` that is used at runtime is embedded into the compiler binary via `src/embedded_datatype.zig`. If you add, modify, or rename any file in `src/datatype/`:
   ```bash
   python3 generate_embedded.py
   zig build
   rm -rf .cache
   ```
3. **The Rule of Cache Invalidation**:
   SundaPy aggressively caches compiled binaries in `.cache/bin/` keyed by Wyhash hashes. If you patch the compiler source code (`src/transpiler/`, `src/parser/`, etc.), running `sundapy test.py` will execute the old binary unless you clear `.cache`:
   ```bash
   rm -rf .cache/src .cache/bin .cache/hashes.txt
   ```
4. **Module Global Visibility**:
   In Zig, module-level variables are private by default. When transpiling Python module globals, ensure they are declared as `pub var` so that `@hasDecl` and reflection can find them across imported modules.
5. **Zero External Build Dependencies**:
   Never introduce external C library bindings (e.g. `libcurl`, `Xlib`, `SDL`, `GTK`, `OpenSSL`). Always use pure Zig standard library, POSIX sockets, or Linux kernel syscalls.
6. **Continuous Verification**:
   Before declaring any task complete, always run the automated test suite:
   ```bash
   ./run_tests.sh
   ```
   Ensure all 157+ test scenarios pass cleanly with 0 errors.

### 8.7 Concrete Code Recipes for AI Agents

#### Recipe 1: Pure Hardware Performance Loop (#strict)
```python
#strict
import time

def compute_mandelbrot(max_iter: i64, cr: f64, ci: f64) -> i64:
    zr: f64 = 0.0
    zi: f64 = 0.0
    iter: i64 = 0
    while iter < max_iter:
        zr2: f64 = zr * zr
        zi2: f64 = zi * zi
        if (zr2 + zi2) > 4.0:
            return iter
        zi = 2.0 * zr * zi + ci
        zr = zr2 - zi2 + cr
        iter += 1
    return max_iter

def main() -> void:
    t0: i64 = time.time_ns()
    res: i64 = compute_mandelbrot(10000000, -0.75, 0.1)
    t1: i64 = time.time_ns()
    elapsed_ms: f64 = (t1 - t0) / 1000000.0
    print("Mandelbrot result:", res, "in", elapsed_ms, "ms")

main()
```

#### Recipe 2: True Multi-Core Concurrency (Zero GIL)
```python
import threading
import time

def cpu_heavy_worker(worker_id, iterations):
    print(f"Worker {worker_id} started on native OS thread")
    total = 0
    for i in range(iterations):
        total += (i ^ (i << 2)) & 0xFFFFFFFF
    print(f"Worker {worker_id} completed: total={total}")

threads = []
t0 = time.time()
for id in range(8):
    t = threading.Thread(target=cpu_heavy_worker, args=(id, 20_000_000))
    threads.append(t)
    t.start()

for t in threads:
    t.join()

print(f"All 8 native threads finished in {time.time() - t0:.3f}s with 100% multi-core saturation!")
```

#### Recipe 3: Seamless PyPI Ecosystem Integration (Host C-ABI)
```python
# Step 1: Install with sundafetch: sundafetch numpy
# Step 2: Write standard Python code:
import numpy as np

arr = np.array([1.0, 2.0, 3.0, 4.0, 5.0])
mean_val = np.mean(arr)
std_val = np.std(arr)
print(f"NumPy Array: {arr}, Mean: {mean_val}, Std: {std_val}")
```

#### Recipe 4: Zero-Dependency GUI Desktop Application
```python
import screenGUI
import GUIEngine
import time

win = screenGUI.init(800, 600, "SundaPy Zero-Dependency Native GUI")
canvas = GUIEngine.create_canvas(800, 600)

running = True
x = 100
while running:
    events = win.poll_events()
    for ev in events:
        if ev.type == "close" or (ev.type == "key" and ev.key == "Escape"):
            running = False
    
    canvas.clear(0xFF1E1E2E)  # Dark background
    canvas.draw_rect(x, 250, 100, 100, 0xFF89B4FA)  # Blue rectangle
    canvas.draw_text("SundaPy Native 100% Pure Zig Wire Protocol X11", 50, 50, 0xFFCDD6F4)
    
    win.blit(canvas)
    x = (x + 2) % 700
    time.sleep(0.016)

win.destroy()
```

### 8.8 Troubleshooting & Diagnostic Matrix for AI Agents

| Issue / Symptom | Root Cause | Solution for AI Agent |
| :--- | :--- | :--- |
| `error.MissingTypeAnnotation` | Variable or function in `#strict` mode lacks a hardware type annotation. | Add explicit type: `x: i64 = 0` or `def fn(a: f64) -> void:`. |
| Code change has no effect when running `sundapy file.py` | Compiler cached the previously generated binary in `.cache/bin/`. | Use `sundapy -y file.py` or run `rm -rf .cache/src .cache/bin .cache/hashes.txt`. |
| Missing external module (e.g. `ModuleNotFoundError: No module named 'numpy'`) | Package is not installed in local `.cache/pyLibrary/`. | Run `sundafetch <pkg>` or `sundapy fetch <pkg>`. |
| Binary wheel cannot load host `libpython3.*.so` | Target machine does not have a matching CPython shared library in library search path. | Verify host Python installation (`python3 -c "import sys; print(sys.version)"`) or check `LD_LIBRARY_PATH`. |
| `src/` file exceeds 400 lines during compiler development | Architectural rule: strictly $\le$ 400 lines per Zig file. | Split file into helper sub-modules (e.g., `feature.zig` -> `feature_core.zig`, `feature_ops.zig`). |
| Modifications to `src/datatype/*.zig` not reflected in compiler build | Runtime datatypes are statically embedded via `embedded_datatype.zig`. | Run `python3 generate_embedded.py`, then `zig build`, and clear `.cache/`. |

---

*AGENTS.md updated and verified for SundaPy & sundafetch.*
