# The Official SundaPy Programming Language & Toolchain Reference Manual
> **The SundaPy Programming Language & Toolchain Reference Manual**  
> *Documentation Version: 1.0.0-LTS | Target: Linux x86_64 / AArch64 | Editorial Standard: The Rust Programming Language Reference Standard*

---

## Preface: Bridging Python Expressiveness with Machine-Speed Performance

Welcome to **The Official SundaPy Reference Manual**. This documentation is engineered as a definitive, pedagogical, and rigorous textbook for **every developer across the learning curve**:
- **Beginner Curve:** Programmers learning their first language or migrating from standard Python, who require clear explanations of lexical grammar, indentation rules, variables, control flow, functions, and compiler diagnostics.
- **Intermediate Curve:** Application developers building modular software, applying object-oriented design (OOP), structured exception handling, REST API integration, or interactive visual tools.
- **Advanced & Systems Curve:** Systems architects, performance engineers, and infrastructure developers who demand raw CPU register performance via `#strict` mode, true multi-core Zero-GIL concurrency, deterministic zero-GC memory lifecycles via Two-Pass Escape Analysis, direct C header integration (`@cImport`), and low-level dynamic FFI shared library dispatch.

SundaPy is not an interpreter; SundaPy is an **Ahead-Of-Time (AOT) Native Transpiler and Runtime Toolchain** that compiles Python 3 syntax directly into standalone machine code binaries (ELF executables) powered by the **Zig** toolchain and the **LLVM** optimization backend.

---

## The Learning Curve Roadmap

```text
+-----------------------------------------------------------------------------------+
|                        THE SUNDAPY LEARNING CURVE ROADMAP                         |
+-----------------------------------------------------------------------------------+
|                                                                                   |
|  [BEGINNER CURVE]                                                                 |
|  - Chapter 1: Lexical Grammar, Syntax Structure & 4-Space Indentation Rules       |
|  - Chapter 2: The Exhaustive Catalog of All 38 SundaPy Reserved Keywords          |
|  - Chapter 3: Operators, Walrus Assignment (:=), & Precedence Hierarchy           |
|  - Chapter 4: Variables & Dynamic Mode (Expressive & Beginner-Friendly)           |
|                                     |                                             |
|                                     v                                             |
|  [INTERMEDIATE CURVE]                                                             |
|  - Chapter 5: Modern Syntax (PEP 822 d"...", PEP 750 t"...", Operators ?? & ?.)   |
|  - Chapter 6: Object-Oriented Programming (OOP) & Single Inheritance              |
|  - Chapter 7: Exception Handling (PEP 758 Multi-Catch) & Context Managers         |
|  - Chapter 8: Core Standard Library (math, time, socket, requests)                |
|                                     |                                             |
|                                     v                                             |
|  [ADVANCED & SYSTEMS CURVE]                                                       |
|  - Chapter 9: Mode #strict & Hardware Primitive ALU Types (i8..i64, f32, f64)     |
|  - Chapter 10: Execution Model & Zero-GIL Concurrency (Native POSIX Threads)      |
|  - Chapter 11: Zero-GC Memory Model (Escape Analysis: Stack Frame vs Arena)       |
|  - Chapter 12: Direct C Interoperability (@cImport & #@link)                      |
|  - Chapter 13: Dynamic Foreign Function Interface (FFI) Subsystem                 |
|  - Chapter 14: X11 MIT-SHM 60 FPS Desktop GUI & GPU VRAM Array Fields             |
|  - Chapter 15: Toolchain, Package Manager sundafetch, & Wyhash Build Caching      |
|  - Chapter 16: Compiler Diagnostic Error Index (E0001 - E0010)                    |
|  - Chapter 17: The SundaPy Cookbook: 7 Real-World End-to-End Projects            |
|  - Chapter 18: Extreme Performance Optimization, SIMD, & Comprehensive FAQ        |
|                                                                                   |
+-----------------------------------------------------------------------------------+
```

---

## Table of Contents

1. [Chapter 1: Lexical Grammar, Syntax Structure & Indentation Rules](#chapter-1-lexical-grammar-syntax-structure--indentation-rules)
   - [1.1 Program Anatomy & Entry Points](#11-program-anatomy--entry-points)
   - [1.2 The Golden Rule of Indentation](#12-the-golden-rule-of-indentation)
   - [1.3 Indent, Dedent Tokens & Stack Whitespace Tracking](#13-indent-dedent-tokens--stack-whitespace-tracking)
   - [1.4 Line Continuation: Explicit (\) vs Implicit ((), [], {})](#14-line-continuation-explicit--vs-implicit---)
   - [1.5 Comments, Docstrings, and Compiler Directives (#strict, #@link)](#15-comments-docstrings-and-compiler-directives-strict-link)
   - [1.6 Identifier Naming Rules & Case Sensitivity](#16-identifier-naming-rules--case-sensitivity)
2. [Chapter 2: The Exhaustive Catalog of All 38 Reserved Keywords](#chapter-2-the-exhaustive-catalog-of-all-38-reserved-keywords)
   - [2.1 Summary Table of All 38 Reserved Keywords](#21-summary-table-of-all-38-reserved-keywords)
   - [2.2 Branching & Logic: `if`, `elif`, `else`](#22-branching--logic-if-elif-else)
   - [2.3 Loops & Flow Control: `while`, `for`, `in`, `break`, `continue`, `pass`](#23-loops--flow-control-while-for-in-break-continue-pass)
   - [2.4 Functions & Generators: `def`, `return`, `lambda`, `yield`](#24-functions--generators-def-return-lambda-yield)
   - [2.5 Classes & Types: `class`](#25-classes--types-class)
   - [2.6 Module System & Imports: `import`, `from`, `as`](#26-module-system--imports-import-from-as)
   - [2.7 Exception Handling: `try`, `except`, `finally`, `raise`](#27-exception-handling-try-except-finally-raise)
   - [2.8 Context Managers & Assertions: `with`, `assert`](#28-context-managers--assertions-with-assert)
   - [2.9 Pattern Matching: `match`, `case`](#29-pattern-matching-match-case)
   - [2.10 Asynchronous Programming: `async`, `await`](#210-asynchronous-programming-async-await)
   - [2.11 Scoping & Memory Directives: `global`, `nonlocal`, `del`, `const`](#211-scoping--memory-directives-global-nonlocal-del-const)
   - [2.12 Built-in Literals & Logic: `True`, `False`, `None`, `is`, `and`, `or`, `not`](#212-built-in-literals--logic-true-false-none-is-and-or-not)
3. [Chapter 3: Complete Operators & Precedence Hierarchy](#chapter-3-complete-operators--precedence-hierarchy)
   - [3.1 Arithmetic & Mathematical Operators](#31-arithmetic--mathematical-operators)
   - [3.2 Relational & Comparison Operators](#32-relational--comparison-operators)
   - [3.3 Boolean Logic Operators](#33-boolean-logic-operators)
   - [3.4 Hardware Bitwise Operators](#34-hardware-bitwise-operators)
   - [3.5 Assignment & Walrus (`:=`) Operators](#35-assignment--walrus--operators)
   - [3.6 Modern SundaPy Operators: None-Coalescing (`??`) & Safe Navigation (`?.`)](#36-modern-sundapy-operators-none-coalescing---safe-navigation-)
   - [3.7 Comprehensive Operator Precedence Table](#37-comprehensive-operator-precedence-table)
4. [Chapter 4: Type System & Dual Typing (Dynamic vs Strict)](#chapter-4-type-system--dual-typing-dynamic-vs-strict)
   - [4.1 Dynamic Mode: Flexible Prototyping & Duck Typing](#41-dynamic-mode-flexible-prototyping--duck-typing)
   - [4.2 Strict Mode (`#strict`): Type Invariance & Native Speed](#42-strict-mode-strict-type-invariance--native-speed)
   - [4.3 Hardware Primitive Types: `i8`..`i64`, `u8`..`u64`, `f32`, `f64`, `bool`, `str`](#43-hardware-primitive-types-i8i64-u8u64-f32-f64-bool-str)
   - [4.4 The 24-Byte `Dynamic` Tagged Union Memory Layout](#44-the-24-byte-dynamic-tagged-union-memory-layout)
   - [4.5 Built-in Collections: `list`, `dict`, `set`, `tuple`, Sentinel `None`](#45-built-in-collections-list-dict-set-tuple-sentinel-none)
5. [Chapter 5: Modern Syntax Features & PEP Implementations](#chapter-5-modern-syntax-features--pep-implementations)
   - [5.1 PEP 822: Compile-Time Dedented Strings (`d"..."`)](#51-pep-822-compile-time-dedented-strings-d)
   - [5.2 PEP 750: Template Strings (`t"..."`)](#52-pep-750-template-strings-t)
   - [5.3 PEP 758: Multiple Exceptions Without Parentheses](#53-pep-758-multiple-exceptions-without-parentheses)
   - [5.4 Advanced Structural Pattern Matching](#54-advanced-structural-pattern-matching)
   - [5.5 Loop Idioms: `enumerate()`, `zip()`, Multi-Dimensional Replications](#55-loop-idioms-enumerate-zip-multi-dimensional-replications)
6. [Chapter 6: Object-Oriented Programming (OOP) & Inheritance](#chapter-6-object-oriented-programming-oop--inheritance)
   - [6.1 Class Declarations, Attributes, and `__init__` Constructors](#61-class-declarations-attributes-and-__init__-constructors)
   - [6.2 Single Inheritance & `super()` Resolution](#62-single-inheritance--super-resolution)
   - [6.3 Method Overriding & Static Dispatch](#63-method-overriding--static-dispatch)
7. [Chapter 7: Execution Architecture & Zero-GIL Concurrency](#chapter-7-execution-architecture--zero-gil-concurrency)
   - [7.1 AOT Compilation Pipeline to Native Standalone ELF](#71-aot-compilation-pipeline-to-native-standalone-elf)
   - [7.2 True Multi-Core Concurrency on POSIX Kernel Threads](#72-true-multi-core-concurrency-on-posix-kernel-threads)
   - [7.3 Synchronization & Race Prevention (`threading.Lock`)](#73-synchronization--race-prevention-threadinglock)
8. [Chapter 8: Deterministic Memory Safety Without a Garbage Collector](#chapter-8-deterministic-memory-safety-without-a-garbage-collector)
   - [8.1 Two-Pass Escape Analysis](#81-two-pass-escape-analysis)
   - [8.2 Stack Frame Allocation (Zero-Cost & Instant Scope Release)](#82-stack-frame-allocation-zero-cost--instant-scope-release)
   - [8.3 Thread-Local Arena Allocator (Zero Fragmentation & Bulk Free)](#83-thread-local-arena-allocator-zero-fragmentation--bulk-free)
9. [Chapter 9: Direct C Interoperability & Linker Directives](#chapter-9-direct-c-interoperability--linker-directives)
   - [9.1 Direct C Header Import (`@cImport`)](#91-direct-c-header-import-cimport)
   - [9.2 System Linker Directives (`#@link`)](#92-system-linker-directives-link)
   - [9.3 Compiling Local C Headers & Custom Native Libraries](#93-compiling-local-c-headers--custom-native-libraries)
10. [Chapter 10: Dynamic Foreign Function Interface (FFI) Subsystem](#chapter-10-dynamic-foreign-function-interface-ffi-subsystem)
    - [10.1 High-Level FFI: Dynamic Library Loading & C-Structs](#101-high-level-ffi-dynamic-library-loading--c-structs)
    - [10.2 Low-Level FFI: Raw Pointers, libc Direct Alloc/Free & Dynamic Dispatch](#102-low-level-ffi-raw-pointers-libc-direct-allocfree--dynamic-dispatch)
11. [Chapter 11: Standard Library Specification (`sundapy_std`)](#chapter-11-standard-library-specification-sundapy_std)
    - [11.1 The `math` Module (FPU Math & Hardware Integer Intrinsics PEP 619)](#111-the-math-module-fpu-math--hardware-integer-intrinsics-pep-619)
    - [11.2 The `time` Module (Nanosecond Precision & Non-Busy Sleep)](#112-the-time-module-nanosecond-precision--non-busy-sleep)
    - [11.3 The `threading` Module (True Multi-Core Concurrency & Mutexes)](#113-the-threading-module-true-multi-core-concurrency--mutexes)
    - [11.4 The `socket` & `requests` Modules (High-Throughput Networking)](#114-the-socket--requests-modules-high-throughput-networking)
    - [11.5 The `screenGUI` & `GUIEngine` Modules (X11 Zero-Copy SHM 60 FPS)](#115-the-screengui--guiengine-modules-x11-zero-copy-shm-60-fps)
    - [11.6 The `gpu` Module (VRAM Field Arrays, Morton Curves & Sub-microsecond Arena)](#116-the-gpu-module-vram-field-arrays-morton-curves--sub-microsecond-arena)
12. [Chapter 12: Toolchain, Package Manager `sundafetch` & CLI Manual](#chapter-12-toolchain-package-manager-sundafetch--cli-manual)
    - [12.1 The `sundapy` Compiler Driver (Flags & Commands)](#121-the-sundapy-compiler-driver-flags--commands)
    - [12.2 Isolated Package Management with `sundafetch`](#122-isolated-package-management-with-sundafetch)
    - [12.3 Wyhash Incremental Build Caching](#123-wyhash-incremental-build-caching)
13. [Chapter 13: IDE Integration & Developer Experience (VS Code)](#chapter-13-ide-integration--developer-experience-vs-code)
    - [13.1 Typing Stubs (`.pyi`) & Pylance Setup](#131-typing-stubs-pyi--pylance-setup)
    - [13.2 Autocomplete Snippets Collection](#132-autocomplete-snippets-collection)
    - [13.3 Build Tasks Shortcuts (`Ctrl+Shift+B`)](#133-build-tasks-shortcuts-ctrlshiftb)
14. [Chapter 14: Compiler Diagnostic Error Index (E0001 - E0010)](#chapter-14-compiler-diagnostic-error-index-e0001---e0010)
15. [Chapter 15: The SundaPy Cookbook: 7 Real-World Practical Projects](#chapter-15-the-sundapy-cookbook-7-real-world-practical-projects)
    - [Project 1 (Beginner): Terminal Calculator & Statistical Text Processor](#project-1-beginner-terminal-calculator--statistical-text-processor)
    - [Project 2 (Intermediate): Object-Oriented Inventory Management System](#project-2-intermediate-object-oriented-inventory-management-system)
    - [Project 3 (Intermediate): Concurrent Web Scraper with `requests`](#project-3-intermediate-concurrent-web-scraper-with-requests)
    - [Project 4 (Advanced): High-Throughput Multithreaded TCP Server](#project-4-advanced-high-throughput-multithreaded-tcp-server)
    - [Project 5 (Advanced): Interactive 60 FPS Desktop Canvas via X11 MIT-SHM](#project-5-advanced-interactive-60-fps-desktop-canvas-via-x11-mit-shm)
    - [Project 6 (Systems): 2D Game Rendering with Raylib via Direct C Import](#project-6-systems-2d-game-rendering-with-raylib-via-direct-c-import)
    - [Project 7 (Systems): High-Speed Vector & Cryptographic Hash ALU in #strict](#project-7-systems-high-speed-vector--cryptographic-hash-alu-in-strict)
16. [Chapter 16: Extreme Performance Optimization, SIMD, & Comprehensive FAQ](#chapter-16-extreme-performance-optimization-simd--comprehensive-faq)

---

## Chapter 1: Lexical Grammar, Syntax Structure & Indentation Rules

### 1.1 Program Anatomy & Entry Points
SundaPy programs are authored in plain text files with the standard `.py` extension. Unlike languages in the C family that demand a mandatory boilerplate wrapper such as `int main()`, SundaPy executes top-level statements sequentially from line 1. For modular, structured software design, using an idiomatic `main()` function is strongly recommended:

```python
def main():
    print("Hello, World from SundaPy!")

main()
```

Individual statements are delimited by the newline character (`\n`). Semicolons (`;`) are supported to chain multiple short statements on a single line:
```python
x = 10; y = 20; print(x + y)
```

---

### 1.2 The Golden Rule of Indentation
SundaPy embraces Python's visual grammar where **code blocks are demarcated by indentation levels**, rather than curly braces `{}`.

Core rules of SundaPy indentation:
1. **Block Headers End with a Colon (`:`):** Every control-flow header (`if`, `elif`, `else`, `for`, `while`, `def`, `class`, `try`, `except`, `finally`, `match`, `case`, `with`) must terminate with a colon `:`.
2. **Indentation Increase Starts a Block:** The subsequent line following a colon must feature deeper indentation.
3. **The 4-Space Standard:** The canonical SundaPy convention strictly mandates **4 spaces** per nesting level.
4. **Tab Handling (`\t`):** The SundaPy lexer computes a tab character as exactly 4 visual columns. However, mixing tabs and spaces within the same block or line is rejected with compiler diagnostic `E0008: IndentationTabSpaceMismatch`.

Example of valid nested blocks:
```python
def evaluate_number(n: int):
    # Level 1 (4 spaces)
    if n > 0:
        # Level 2 (8 spaces)
        print("Positive number")
        if n % 2 == 0:
            # Level 3 (12 spaces)
            print("Even number")
        else:
            print("Odd number")
    else:
        print("Zero or negative")
```

---

### 1.3 Indent, Dedent Tokens & Stack Whitespace Tracking
Under the hood, the **SundaPy Lexer** tracks whitespace using an internal indentation stack:

```text
Source Line                             Indent Stack           Emitted Virtual Tokens
-------------------------------------------------------------------------------------
def process():                          [0]                    def, process, (, ), :
    x = 1                               [0, 4]                 Indent, x, =, 1, Newline
    if x > 0:                           [0, 4]                 if, x, >, 0, :
        print(x)                        [0, 4, 8]              Indent, print, (, x, ), Newline
    y = 2                               [0, 4]                 Dedent, y, =, 2, Newline
print("Done")                           [0]                    Dedent, print, (, ... ), Newline
```

1. **Stack Initialization:** The lexer initializes its stack to `[0]`.
2. **`Indent` Token:** When a non-empty line has more leading spaces than the current stack top, the new column depth is pushed onto the stack, and a virtual `Indent` token is dispatched to the parser.
3. **`Dedent` Token:** When a subsequent line retreats to a shallower column depth, the lexer pops values from the stack until a matching depth is found. For every level popped, a virtual `Dedent` token is emitted. If the indentation level does not match an existing stack entry, a compilation error is raised.
4. **Blank Lines & Comments:** Lines containing only whitespace or comments (`#`) are ignored and do not alter the indentation stack.

---

### 1.4 Line Continuation: Explicit (`\`) vs Implicit (`()`, `[]`, `{}`)
To prevent overly long lines that exceed screen width limits (such as 80 or 100 columns), SundaPy supports two line continuation mechanisms:

#### 1. Explicit Line Continuation (Backslash `\`)
Placing a backslash `\` at the very end of a line instructs the lexer to discard the upcoming newline and merge the statements:
```python
total_price = base_price + \
              shipping_cost + \
              sales_tax - \
              discount_rebate
```

#### 2. Implicit Line Continuation (Enclosing Brackets)
Any expression contained within parentheses `(...)`, square brackets `[...]`, or curly braces `{...}` automatically enables implicit continuation. The lexer tracks nesting via `paren_level > 0`, treating newlines as whitespace without emitting `Newline` or `Indent` tokens:
```python
user_list = [
    "Grace Hopper",
    "Ada Lovelace",
    "Margaret Hamilton",
    "Katherine Johnson"
]

computed_val = (
    first_factor * weight_multiplier
    + second_factor * scaling_factor
    - baseline_offset
)
```

---

### 1.5 Comments, Docstrings, and Compiler Directives (`#strict`, `#@link`)

#### 1. Single-Line Comments (`#`)
Begins with `#` and continues until the end of the line:
```python
# Calculate projectile trajectory
velocity = 45.0 # meters per second
```

#### 2. Multiline Docstrings (`"""` or `'''`)
Standalone string literals placed at the head of a module, class, or function serve as docstrings:
```python
def calculate_isqrt(n: int) -> int:
    """Computes truncated integer square root using ALU intrinsics.
    
    Args:
        n (int): Positive integer.
    Returns:
        int: floor(sqrt(n)).
    """
    return math.isqrt(n)
```

#### 3. Compiler Directives (`#strict`, `#@link`)
SundaPy interprets structured comments as compiler pragmas:
- `#strict`: Enables static type invariance and hardware register mapping. Must be positioned on line 1 of the file or at the beginning of a function body.
- `#@link: lib1, lib2`: Informs LLVM to link system dynamic or static libraries (`-lm`, `-lraylib`, `-lpthread`).

```python
#strict
#@link: m, raylib
import "math.h" as cmath
```

---

### 1.6 Identifier Naming Rules & Case Sensitivity
1. **Permitted Characters:** ASCII alphanumeric characters (`a-z`, `A-Z`, `0-9`) and underscores (`_`).
2. **Initial Character:** Must begin with a letter or underscore, never a number (`val1` is valid; `1val` is illegal).
3. **Strict Case Sensitivity:** `data`, `Data`, and `DATA` represent three distinct identifiers in memory.
4. **Reserved Words:** Cannot collide with any of the 38 reserved keywords.
5. **Idiomatic Conventions:**
   - Functions and Variables: `snake_case` (e.g., `calculate_checksum`, `total_count`).
   - Classes and Structs: `PascalCase` (e.g., `NetworkSocket`, `Matrix3x3`).
   - Constants: `SCREAMING_SNAKE_CASE` (e.g., `MAX_RETRY_COUNT`, `DEFAULT_BUFFER_SIZE`).

---

## Chapter 2: The Exhaustive Catalog of All 38 Reserved Keywords

### 2.1 Summary Table of All 38 Reserved Keywords
SundaPy reserves **38 keywords** registered in `src/lexer/lexer_keyword.zig`:

| Keyword | Category | Description |
|---|---|---|
| `if` | Control Flow | Evaluates a boolean conditional branch. |
| `elif` | Control Flow | Alternate conditional branch evaluated if prior tests are `False`. |
| `else` | Control Flow | Default fallback block when all prior conditions fail. |
| `while` | Loops | Iterative loop executing while a condition holds `True`. |
| `for` | Loops | Iterates across elements of an iterable, list, or range. |
| `in` | Membership & Loops | Tests membership in a collection or delimits targets in for loops. |
| `break` | Loop Control | Immediately terminates and exits the innermost loop. |
| `continue` | Loop Control | Skips the remainder of the current loop cycle and restarts iteration. |
| `pass` | Placeholder | Empty no-operation statement satisfying block grammar requirements. |
| `def` | Function Definition| Declares a new callable function. |
| `return` | Function Flow | Terminates function execution and yields a value to the caller. |
| `lambda` | Anonymous Function| Defines an inline single-expression anonymous function. |
| `yield` | Generators | Lazily yields a value from a generator function. |
| `class` | Data Structuring | Declares a custom class, object prototype, or native struct. |
| `import` | Modules & Headers | Imports internal modules, C headers (`import "h"`), or FFI. |
| `from` | Module Selection | Selectively imports attributes or symbols from a module. |
| `as` | Aliasing | Binds an imported symbol or caught exception to an alias. |
| `try` | Exception Handling | Encloses code blocks monitored for runtime exceptions. |
| `except` | Exception Handling | Traps specified exceptions (supports PEP 758 tuples/multi-types). |
| `finally` | Exception Handling | Cleanup block guaranteed to execute regardless of exceptions. |
| `raise` | Exception Trigger | Manually triggers an exception. |
| `with` | Resource Safety | Scopes resources via RAII context managers. |
| `assert` | Verification | Validates debugging assumptions and preconditions. |
| `match` | Pattern Matching | Evaluates structural pattern matching. |
| `case` | Pattern Matching | Specifies target pattern branches inside `match`. |
| `async` | Concurrency | Declares an asynchronous coroutine function. |
| `await` | Concurrency | Suspends coroutine execution until an asynchronous task resolves. |
| `global` | Variable Scoping | Binds variable mutations to module-level global scope. |
| `nonlocal` | Variable Scoping | Binds mutations to the nearest enclosing non-global scope. |
| `del` | Memory Management | Explicitly deletes a variable binding or collection item. |
| `const` | Immutability | Declares a stack/register immutable constant value. |
| `True` | Boolean Literal | Boolean true constant ($1$). |
| `False` | Boolean Literal | Boolean false constant ($0$). |
| `None` | Null Sentinel | Sentinel denoting absence of a value (nullable pointer). |
| `is` | Identity Testing | Tests whether two operands share identical physical memory addresses. |
| `not` | Boolean Logic | Unary boolean inversion (logical NOT). |
| `and` | Boolean Logic | Short-circuit logical conjunction (AND). |
| `or` | Boolean Logic | Short-circuit logical disjunction (OR). |

---

### 2.2 Branching & Logic: `if`, `elif`, `else`
```python
score = 85

if score >= 90:
    grade = "A"
elif score >= 80:
    grade = "B"
elif score >= 70:
    grade = "C"
else:
    grade = "D"

print("Grade:", grade) # B
```
Supports inline ternary syntax:
```python
status = "Adult" if age >= 18 else "Minor"
```

---

### 2.3 Loops & Flow Control: `while`, `for`, `in`, `break`, `continue`, `pass`
```python
# For loop
for i in range(5):
    if i == 2:
        continue # Skip 2
    if i == 4:
        break    # Stop at 4
    print("Value:", i)

# While loop
queue_count = 3
while queue_count > 0:
    print("Processing item...", queue_count)
    queue_count -= 1

def pending_feature():
    pass # No-op placeholder
```

---

### 2.4 Functions & Generators: `def`, `return`, `lambda`, `yield`
```python
def multiply(a: int, b: int) -> int:
    return a * b

square = lambda x: x * x

def even_generator(limit: int):
    val = 0
    while val <= limit:
        yield val
        val += 2

for num in even_generator(6):
    print("Even:", num) # 0, 2, 4, 6
```

---

### 2.5 Classes & Types: `class`
```python
class Account:
    def __init__(self, owner: str, balance: float):
        self.owner = owner
        self.balance = balance

    def deposit(self, amount: float):
        self.balance += amount

acc = Account("Alice", 1000.0)
acc.deposit(250.0)
print(f"Owner: {acc.owner}, Balance: {acc.balance}")
```

---

### 2.6 Module System & Imports: `import`, `from`, `as`
```python
import math
from time import sleep, time_ns
import screenGUI as gui
import "math.h" as cmath # Direct C Header
```

---

### 2.7 Exception Handling: `try`, `except`, `finally`, `raise`
```python
def safe_divide(a: float, b: float) -> float:
    if b == 0.0:
        raise ZeroDivisionError("Denominator cannot be zero")
    return a / b

try:
    res = safe_divide(10.0, 0.0)
except ZeroDivisionError, ValueError as err: # PEP 758: No parentheses
    print("Calculation failed:", err)
finally:
    print("Cleanup guaranteed.")
```

---

### 2.8 Context Managers & Assertions: `with`, `assert`
```python
import threading

mutex = threading.Lock()
with mutex:
    # Thread-safe critical region
    print("Executing inside protected critical section")

assert 1 + 1 == 2, "Logic verification failure"
```

---

### 2.9 Pattern Matching: `match`, `case`
```python
def parse_action(cmd: str):
    match cmd:
        case "start":
            print("System booting")
        case "stop":
            print("System halting")
        case "reload" | "restart":
            print("System rebooting")
        case _:
            print("Unknown command:", cmd)
```

---

### 2.10 Asynchronous Programming: `async`, `await`
```python
async def fetch_task(endpoint: str):
    return f"Response from {endpoint}"

async def main():
    data = await fetch_task("https://api.example.com")
    print("Fetched:", data)
```

---

### 2.11 Scoping & Memory Directives: `global`, `nonlocal`, `del`, `const`
```python
global_counter = 0

def increment():
    global global_counter
    global_counter += 1

const SPEED_OF_LIGHT: i64 = 299792458

items = [10, 20, 30]
del items[1] # Deletes element 20
```

---

### 2.12 Built-in Literals & Logic: `True`, `False`, `None`, `is`, `and`, `or`, `not`
```python
x = [1, 2]
y = [1, 2]
z = x

print(x == y) # True (value equality)
print(x is y) # False (distinct heap allocations)
print(x is z) # True (shared pointer identity)
```

---

## Chapter 3: Complete Operators & Precedence Hierarchy

### 3.1 Arithmetic & Mathematical Operators
| Operator | Function | Example | Notes |
|---|---|---|---|
| `+` | Addition | `a + b` | Arithmetic addition or string/list concatenation. |
| `-` | Subtraction | `a - b` | Numerical subtraction. |
| `*` | Multiplication | `a * b` | Arithmetic multiplication or sequence replication. |
| `/` | True Division | `a / b` | Floating-point quotient (`f64`). |
| `//` | Floor Division | `a // b` | Integer quotient truncated toward negative infinity. |
| `%` | Modulo | `a % b` | Integer remainder. |
| `**` | Exponentiation | `a ** b` | Powers ($a^b$). |

### 3.2 Relational & Comparison Operators
`==` (equal), `!=` (not equal), `<` (less than), `<=` (less than or equal), `>` (greater than), `>=` (greater than or equal).

### 3.3 Boolean Logic Operators
`not` (logical NOT), `and` (short-circuit AND), `or` (short-circuit OR).

### 3.4 Hardware Bitwise Operators
`&` (Bitwise AND), `|` (Bitwise OR), `^` (Bitwise XOR), `~` (Bitwise NOT), `<<` (Left Shift), `>>` (Right Shift).

### 3.5 Assignment & Walrus (`:=`) Operators
`=`, `+=`, `-=`, `*=`, `/=`, `%=`, `&=`, `|=`, `^=`, `<<=`, `>>=`.
Walrus operator (`:=`) allows assignment within an evaluating conditional expression:
```python
while (chunk := socket.recv(1024)) != "":
    process_chunk(chunk)
```

### 3.6 Modern SundaPy Operators: None-Coalescing (`??`) & Safe Navigation (`?.`)
- `a ?? b`: Returns `b` if `a` is `None`; otherwise returns `a`.
- `obj?.field?.method()`: Evaluates safely without raising `AttributeError` when `obj` or `field` is `None`.

### 3.7 Comprehensive Operator Precedence Table
| Precedence Level | Operators | Description |
|---|---|---|
| 1 (Highest) | `()`, `[]`, `.`, `?.` | Primary expressions & safe traversal |
| 2 | `**` | Exponentiation |
| 3 | `+x`, `-x`, `~x` | Unary sign & bitwise NOT |
| 4 | `*`, `/`, `//`, `%` | Multiplication & division |
| 5 | `+`, `-` | Addition & subtraction |
| 6 | `<<`, `>>` | Bitwise shifts |
| 7 | `&` | Bitwise AND |
| 8 | `^` | Bitwise XOR |
| 9 | `\|` | Bitwise OR |
| 10 | `==`, `!=`, `<`, `<=`, `>`, `>=`, `is`, `in` | Comparisons & membership |
| 11 | `not` | Boolean NOT |
| 12 | `and` | Boolean AND |
| 13 | `or` | Boolean OR |
| 14 | `??` | None-Coalescing |
| 15 (Lowest) | `=`, `+=`, `-=`, `:=`, etc. | Assignment & Walrus |

---

## Chapter 4: Type System & Dual Typing (Dynamic vs Strict)

SundaPy provides two complementary typing paradigms: **Dynamic Mode** for rapid prototyping and duck typing, and **Strict Mode (`#strict`)** for zero-overhead, statically-invariable systems programming.

### 4.1 Dynamic Mode: Flexible Prototyping & Duck Typing
By default, variables are dynamically typed and can be reassigned freely across types without compilation errors:
```python
val = 100
val = "One Hundred"
val = [10, 20, 30]
print(val)
```

---

### 4.2 Strict Mode (`#strict`): Type Invariance & Native Speed
Placing `#strict` on line 1 forces static typing:
- Variable types are invariant once declared.
- All variable declarations must include an explicit type annotation (`x: i64 = 10`).
- Variables are mapped directly into CPU registers and machine stack frames.
- Boxing overhead is eliminated, enabling LLVM auto-vectorization and loop unrolling.

```python
#strict

def kinetic_energy(mass: f64, velocity: f64) -> f64:
    ke: f64 = 0.5 * mass * (velocity * velocity)
    return ke

print("Kinetic Energy:", kinetic_energy(80.0, 15.0), "Joules")
```

---

### 4.3 Hardware Primitive Types: `i8`..`i64`, `u8`..`u64`, `f32`, `f64`, `bool`, `str`
Under `#strict` mode, SundaPy exposes direct hardware ALU representations:

| Type | Machine Representation | Size | Range | Use Cases |
|---|---|---|---|---|
| `i8` | Signed 8-bit Integer | 1 Byte | $-128$ to $127$ | Audio DSP sampling |
| `u8` | Unsigned 8-bit (Byte) | 1 Byte | $0$ to $255$ | Binary buffers, RGB color |
| `i16` | Signed 16-bit Integer | 2 Bytes | $-32,768$ to $32,767$ | ADC/DAC sensor data |
| `u16` | Unsigned 16-bit Integer | 2 Bytes | $0$ to $65,535$ | Network ports, 16-bit indices |
| `i32` | Signed 32-bit Integer | 4 Bytes | $-2 \times 10^9$ to $2 \times 10^9$ | Desktop visual coordinates |
| `u32` | Unsigned 32-bit Integer | 4 Bytes | $0$ to $4.29 \times 10^9$ | RGBA pixel color, CRC32 |
| `i64` | Signed 64-bit (Default int)| 8 Bytes | $-9.22 \times 10^{18}$ to $9.22 \times 10^{18}$ | Nanosecond timestamps |
| `u64` | Unsigned 64-bit Integer | 8 Bytes | $0$ to $1.84 \times 10^{19}$ | Cryptographic hash digests |
| `f32` | Single Precision Float | 4 Bytes | IEEE 754 float | 3D vertex shaders, ML tensors |
| `f64` | Double Precision Float | 8 Bytes | IEEE 754 double | Scientific simulation |
| `bool` | Boolean Byte Flag | 1 Byte | `True` ($1$) or `False` ($0$) | Conditional branching |
| `str` | Immutable String Slice | 16 Bytes | Struct: Pointer 64-bit + Length 64-bit | Zero-copy UTF-8 slices |

---

### 4.4 The 24-Byte `Dynamic` Tagged Union Memory Layout
In Dynamic Mode, each object is held within a 24-byte tagged union:
```text
        +---------------------------------------------------------------+
        |              Dynamic Object Memory Layout (24 Bytes)          |
        +---------------------------------------------------------------+
        | Offset (Bytes) | Size (Bytes) | Field Description             |
        +----------------+--------------+-------------------------------+
        |   0            | 1            | DynamicTag Discriminator Enum |
        |   1 - 7        | 7            | Alignment Padding             |
        |   8 - 23       | 16           | Union Payload Data            |
        +---------------------------------------------------------------+
```

---

### 4.5 Built-in Collections: `list`, `dict`, `set`, `tuple`, Sentinel `None`
- **List:** Dynamic contiguous buffer with $1.5\times$ geometric growth factor.
- **Dict:** Robin Hood Open-Addressing Hash Table with Wyhash collision resistance ($O(1)$ amortized lookups).
- **Sentinel `None`:** Lowered directly to Zig optional pointers (`?T`), avoiding separate heap allocations.

---

## Chapter 5: Modern Syntax Features & PEP Implementations

### 5.1 PEP 822: Compile-Time Dedented Strings (`d"..."`)
```python
def get_query() -> str:
    # Common indentation stripped at compile time with zero runtime overhead
    return d"""
        SELECT id, username, email
        FROM users
        WHERE is_active = 1
        ORDER BY id DESC
    """
```

---

### 5.2 PEP 750: Template Strings (`t"..."`)
```python
param = "SELECT"
template = t"Query template: {param}"
print(template)
```
Generates structured template token components to prevent injection vulnerabilities.

---

### 5.3 PEP 758: Multiple Exceptions Without Parentheses
```python
try:
    num = 100 / int(raw_input)
except ValueError, ZeroDivisionError as err:
    print("Caught calculation exception:", err)
```

---

### 5.4 Advanced Structural Pattern Matching
```python
def route_packet(pkt: list):
    match pkt:
        case [0, 0]:
            print("Origin")
        case [x, 0]:
            print("X-axis:", x)
        case [0, y]:
            print("Y-axis:", y)
        case [x, y]:
            print(f"Coordinates ({x}, {y})")
        case _:
            print("Unknown packet")
```

---

### 5.5 Loop Idioms: `enumerate()`, `zip()`, Multi-Dimensional Replications
```python
# enumerate
for idx, val in enumerate(["apple", "banana"]):
    print(idx, val)

# zip
for k, v in zip(["a", "b"], [1, 2]):
    print(k, v)

# Multi-dimensional grid
grid_2d = [[0] * 4 for _ in range(3)]
grid_2d[0][0] = 42
```

---

## Chapter 6: Object-Oriented Programming (OOP) & Inheritance

SundaPy provides clean, performant single inheritance with constructor chaining via `super()` and static dispatch:

```python
#strict

class Vehicle:
    brand: str
    year: i32

    def __init__(self, brand: str, year: i32):
        self.brand = brand
        self.year = year

    def description(self) -> str:
        return "Generic vehicle"

class ElectricCar(Vehicle):
    battery_kwh: f64

    def __init__(self, brand: str, year: i32, battery_kwh: f64):
        super().__init__(brand, year)
        self.battery_kwh = battery_kwh

    def description(self) -> str:
        return "Eco-friendly battery-powered electric vehicle"

car = ElectricCar("Tesla Model 3", 2024, 75.0)
print("Brand  :", car.brand)
print("Year   :", car.year)
print("Battery:", car.battery_kwh, "kWh")
print("Info   :", car.description())
```

---

## Chapter 7: Execution Architecture & Zero-GIL Concurrency

### 7.1 AOT Compilation Pipeline to Native Standalone ELF
SundaPy compiles Python 3 directly into native ELF binaries via 5 static phases:
1. **Lexer & Parser:** High-speed recursive-descent AST creation.
2. **Escape Analysis:** Resolves allocation boundaries (Stack vs Arena).
3. **Zig Code Emitter:** Translates AST into high-efficiency Zig intermediate source code.
4. **LLVM Backend Compilation:** Emits optimized machine code with aggressive inlining and SIMD auto-vectorization.
5. **Direct Execution:** Executes instantly with sub-millisecond cold starts (0.5 ms).

---

### 7.2 True Multi-Core Concurrency on POSIX Kernel Threads
Standard Python concurrency is constrained by the Global Interpreter Lock (GIL). SundaPy removes the GIL entirely:

```text
CPython (GIL Constrained):
Core 1: [ Thread 1 ] ===GIL===> [ Thread 2 ] ===GIL===> [ Thread 3 ]
Core 2: (IDLE)
Core 3: (IDLE)
Core 4: (IDLE)

SundaPy (Zero-GIL Multi-Core Native):
Core 1: [ Native POSIX Thread 1 ] -> 100% CPU Utilization
Core 2: [ Native POSIX Thread 2 ] -> 100% CPU Utilization
Core 3: [ Native POSIX Thread 3 ] -> 100% CPU Utilization
Core 4: [ Native POSIX Thread 4 ] -> 100% CPU Utilization
```

Invoking `threading.Thread(target=...)` spawns a true Linux kernel thread (`pthread_create`). Each thread owns its own register context and thread-local arena allocator, unlocking linear multi-core hardware scaling.

---

### 7.3 Synchronization & Race Prevention (`threading.Lock`)
Because threads execute in pure parallel fashion across CPU cores, shared mutable state must be guarded using mutex locks:

```python
import threading

lock = threading.Lock()
shared_counter = 0

def worker_task(count: int):
    global shared_counter
    for _ in range(count):
        with lock:
            shared_counter += 1

t1 = threading.Thread(target=worker_task, args=(25000,))
t2 = threading.Thread(target=worker_task, args=(25000,))

t1.start()
t2.start()

t1.join()
t2.join()

print("Final Counter:", shared_counter) # Exactly 50000
```

---

## Chapter 8: Deterministic Memory Safety Without a Garbage Collector

SundaPy replaces cyclic tracing garbage collection with deterministic memory management:

### 8.1 Two-Pass Escape Analysis
During compilation, SundaPy tracks the escape scope of every allocated structure:
- **Pass 1 (Lifetime Scope):** Analyzes whether a structure's reference outlives its defining scope.
- **Pass 2 (Target Assignment):** Targets non-escaping structures to the CPU Stack Frame and escaping data to a Thread-Local Arena Allocator.

---

### 8.2 Stack Frame Allocation (Zero-Cost & Instant Scope Release)
Primitive values, local class copies, and fixed buffers are allocated directly on the CPU stack. Allocation and deallocation require adjusting the stack pointer register (`rsp`), incurring **zero additional CPU instructions**.

---

### 8.3 Thread-Local Arena Allocator (Zero Fragmentation & Bulk Free)
Escaping structures are allocated sequentially in an arena buffer. When a task completes, the arena is reclaimed in one single bulk deallocation operation. This eliminates free-list traversals, memory fragmentation, and unpredictable GC pauses.

---

## Chapter 9: Direct C Interoperability & Linker Directives

### 9.1 Direct C Header Import (`@cImport`)
SundaPy compiles C headers directly into native symbols without glue code:
```python
#@link: m
import "math.h" as cmath

print("sin(pi/2) =", cmath.sin(1.5707963))
```

---

### 9.2 System Linker Directives (`#@link`)
Direct the LLVM linker to link system shared libraries:
```python
#@link: raylib, m
```
The compiler parses this directive and appends `-lraylib -lm` to the linker flags.

---

### 9.3 Compiling Local C Headers & Custom Native Libraries
```c
// File: native_math.h
#ifndef NATIVE_MATH_H
#define NATIVE_MATH_H

static inline double square(double x) {
    return x * x;
}

#endif
```

Import directly in SundaPy:
```python
import "native_math.h" as nm

print("square(9.0) =", nm.square(9.0))
```

---

## Chapter 10: Dynamic Foreign Function Interface (FFI) Subsystem

### 10.1 High-Level FFI: Dynamic Library Loading & C-Structs
```python
import ffi

# 1. Load shared library (.so, .dll, .dylib)
lib = ffi.load("libcalculator.so")

# 2. Bind function symbol with typed signature
add_fn = lib.bind("add_i64", ffi.i64, [ffi.i64, ffi.i64])
print("Result:", add_fn(200, 300))

# 3. Define C-Struct memory layout
Point3D = ffi.create_struct("Point3D", [
    ("x", ffi.f64),
    ("y", ffi.f64),
    ("z", ffi.f64)
])

# 4. Instantiate and mutate struct in native memory
p = Point3D(1.0, 2.0, 3.0)
print("Struct byte size:", ffi.sizeof(Point3D))
print("Memory address  :", ffi.addressof(p))
p.z = 42.0

lib.close()
```

---

### 10.2 Low-Level FFI: Raw Pointers, libc Direct Alloc/Free & Dynamic Dispatch
```python
import ffi

libc = ffi.open("libc.so.6")
puts_sym = libc.get_symbol("puts")
msg_ptr = ffi.c_str("Direct invocation via Low-Level FFI!")

libc.call_raw(puts_sym, msg_ptr)

raw_buf = ffi.alloc(1024)
print("Raw buffer address:", raw_buf)
ffi.free(raw_buf)

libc.close()
```

---

## Chapter 11: Standard Library Specification (`sundapy_std`)

### 11.1 The `math` Module (FPU Math & Hardware Integer Intrinsics PEP 619)
- `math.isqrt(n: int) -> int`: Truncated integer square root calculated via binary bit-shifts without FPU overhead.
- `math.gcd(a: int, b: int) -> int`: Greatest Common Divisor via binary Stein's algorithm and hardware Count Trailing Zeros (CTZ).
- `math.lcm(a: int, b: int) -> int`: Least Common Multiple.
- `math.comb(n: int, k: int) -> int`: Binomial coefficient $C(n, k)$.
- `math.factorial(n: int) -> int`: Exact 64-bit integer factorial.
- FPU operations: `sin`, `cos`, `tan`, `asin`, `acos`, `atan`, `atan2`, `sqrt`, `pow`, `exp`, `log`, `log2`, `log10`, `floor`, `ceil`, `trunc`, `round`, `fabs`, `isnan`, `isinf`, `isfinite`.
- Constants: `math.pi`, `math.e`, `math.tau`.

```python
import math

print("isqrt(10000) =", math.isqrt(10000)) # 100
print("gcd(48, 18)   =", math.gcd(48, 18))   # 6
print("lcm(12, 15)   =", math.lcm(12, 15))   # 60
print("comb(5, 2)    =", math.comb(5, 2))    # 10
print("factorial(5)  =", math.factorial(5))  # 120
```

---

### 11.2 The `time` Module (Nanosecond Precision & Non-Busy Sleep)
- `time.time() -> float`: Returns current wall-clock seconds.
- `time.time_ns() -> int`: Returns monotonic timestamp with nanosecond resolution via CPU hardware counters.
- `time.sleep(seconds: float) -> None`: Non-busy sleeping backed by the Linux `nanosleep` kernel syscall.

```python
import time

start_ns = time.time_ns()
time.sleep(0.02)
end_ns = time.time_ns()
print("Elapsed ms:", (end_ns - start_ns) / 1000000.0)
```

---

### 11.3 The `threading` Module (True Multi-Core Concurrency & Mutexes)
- `threading.Thread(target=fn, args=tuple)`: Initializes a POSIX thread.
- `t.start()`: Begins concurrent execution.
- `t.join()`: Awaits thread termination.
- `threading.Lock()`: POSIX mutex synchronization primitive.

---

### 11.4 The `socket` & `requests` Modules (High-Throughput Networking)
- **`socket`:** Exposes POSIX Berkeley sockets (`socket.socket`, `AF_INET`, `SOCK_STREAM`, `SOCK_DGRAM`) with non-blocking support.
- **`requests`:** Native HTTP client without external dependencies:
  - `requests.get(url, headers=None) -> Response`
  - `requests.post(url, data=None, json=None, headers=None) -> Response`
  - `Response`: `status_code`, `text`, `json()`.

---

### 11.5 The `screenGUI` & `GUIEngine` Modules (X11 Zero-Copy SHM 60 FPS)
- **X11 MIT-SHM Zero-Copy:** Shared memory architecture (`shmget`/`shmat`) for direct framebuffer rendering.
- **Primitives:** `win.clear(r, g, b)`, `win.draw_rect(x, y, w, h, r, g, b)`, `win.draw_circle(cx, cy, radius, r, g, b)`, `win.draw_text(x, y, text, r, g, b)`.

---

### 11.6 The `gpu` Module (VRAM Field Arrays, Morton Curves & Sub-microsecond Arena)
- **`gpu.field`:** Multi-dimensional arrays located directly in GPU VRAM.
- **Morton Z-Order Space-Filling Curves:** Re-indexes 2D/3D coordinates to optimize L1/L2 GPU cache locality.
- **Sub-Microsecond VRAM Arena:** Sub-microsecond buffer allocation avoiding kernel driver context switches.

---

## Chapter 12: Toolchain, Package Manager `sundafetch` & CLI Manual

### 12.1 The `sundapy` Compiler Driver (Flags & Commands)
```bash
sundapy [OPTIONS] [SUB_COMMAND] <script.py> [ARGS...]
```

| Flag | Purpose |
|---|---|
| `-h`, `--help` | Displays help message and CLI options. |
| `--build` | Compiles script into a standalone ELF binary without execution. |
| `--outname <name>` | Sets output binary name (enables `--build`). |
| `--fast`, `-O3` | Enables LLVM `ReleaseFast` optimization for peak throughput. |
| `--debug` | Enables `ReleaseSafe` with debug symbols and bounds checking. |
| `-y` | Forces a complete rebuild, ignoring cached artifacts. |
| `--no-panic` | Disables stack trace dumps on panic crashes. |
| `init` | Scaffolds a new project with type stubs and editor configurations. |
| `fetch <pkg>` | Fetches PyPI packages into `.cache/pyLibrary/`. |

---

### 12.2 Isolated Package Management with `sundafetch`
```bash
# Fetch single package
sundafetch requests

# Fetch from requirements.txt
sundafetch -r requirements.txt
```
Isolates all dependencies inside `.cache/pyLibrary/` and extracts binary wheels matching the host architecture.

---

### 12.3 Wyhash Incremental Build Caching
Calculates a fast Wyhash fingerprint of script contents, mode flags, and linked libraries. If a matching binary exists in `.cache/bin/`, execution starts in **0.5 to 1.2 ms**.

---

## Chapter 13: IDE Integration & Developer Experience (VS Code)

### 13.1 Typing Stubs (`.pyi`) & Pylance Setup
Running `sundapy init` creates `.vscode/typings/`:
- `__builtins__.pyi`: Hardware primitives (`i8`..`i64`, `u8`..`u64`, `f32`, `f64`, `??`, `?.`).
- `math.pyi`: Full math and hardware integer intrinsics.
- `ffi.pyi`: Struct definitions, symbol binders, and memory primitives.
- `screenGUI.pyi` & `GUIEngine.pyi`: X11 windowing and rendering.
- `gpu.pyi`: VRAM fields and arena buffers.

Configured in `.vscode/settings.json`:
```json
{
  "python.analysis.extraPaths": [
    "${workspaceFolder}/.vscode/typings",
    "${workspaceFolder}/.cache/pyLibrary"
  ],
  "python.analysis.typeCheckingMode": "basic"
}
```

---

### 13.2 Autocomplete Snippets Collection
Configured in `.vscode/sundapy.code-snippets`:
- `sunda-strict`: High-performance `#strict` template.
- `sunda-c-import`: Direct C Header Import template.
- `sunda-ffi-high`: High-level dynamic FFI template.
- `sunda-inherit`: Class inheritance template.
- `sunda-gui`: 60 FPS X11 canvas loop template.

---

### 13.3 Build Tasks Shortcuts (`Ctrl+Shift+B`)
Pressing `Ctrl+Shift+B` compiles and runs the active script instantly via `.vscode/tasks.json`.

---

## Chapter 14: Compiler Diagnostic Error Index (E0001 - E0010)

### `E0001: StrictModeUnannotatedVariable`
- **Cause:** In `#strict` mode, a local variable was declared without an explicit type annotation.
- **Incorrect:** `count = 10`
- **Correction:** `count: i64 = 10`

### `E0002: TypeMismatchAssignment`
- **Cause:** Assigning an incompatible value to a statically typed variable.
- **Incorrect:** `age: i32 = 25; age = "Twenty-Five"`
- **Correction:** Maintain consistent types or perform explicit casting.

### `E0003: UnlinkedExternalSymbol`
- **Cause:** C header imported, but required shared libraries omitted from `#@link`.
- **Incorrect:** `import "raylib.h" as rl` (undefined symbol: `InitWindow`)
- **Correction:** Add `#@link: raylib, m` on line 1.

### `E0004: DirectCHeaderNotFound`
- **Cause:** C header file not found in system or local include paths.
- **Correction:** Verify header name or place `.h` in the workspace directory.

### `E0005: InvalidFFISignature`
- **Cause:** Passing non-FFI types into `lib.bind()`.
- **Correction:** Use constant types from `ffi` (`ffi.i32`, `ffi.f64`, `ffi.ptr`).

### `E0006: IncompatibleParentMethodOverride`
- **Cause:** Subclass method signature does not conform to parent class signature.
- **Correction:** Align parameter count and argument types with parent class contract.

### `E0007: VRAMAllocationExhausted`
- **Cause:** Array field or arena requests exceed physical device VRAM.
- **Correction:** Reduce dimensions or free unused GPU buffers.

### `E0008: IndentationTabSpaceMismatch`
- **Cause:** Mixing tabs (`\t`) and spaces in the same indentation block.
- **Correction:** Standardize on 4 spaces across all files.

### `E0009: NullDerefOnNonOptional`
- **Cause:** Unchecked attribute access on a potentially `None` variable.
- **Correction:** Use safe navigation `?.` or none-coalescing `??`.

### `E0010: UnsupportedDynamicInPureStrict`
- **Cause:** Arbitrary dynamic attribute assignment inside `#strict` classes.
- **Correction:** Explicitly declare all attributes in the class header.

---

## Chapter 15: The SundaPy Cookbook: 7 Real-World Practical Projects

This collection of end-to-end recipes guides developers across all skill levels:

### Project 1 (Beginner): Terminal Calculator & Statistical Text Processor
A gentle introduction combining list operations, loops, and basic formatted output:

```python
def run_calculator():
    print("=== SUNDAPY STATISTICAL CALCULATOR ===")
    numbers = [15, 42, 68, 23, 91, 35, 57, 79, 90]

    total = 0
    max_val = numbers[0]
    min_val = numbers[0]

    for n in numbers:
        total += n
        if n > max_val:
            max_val = n
        if n < min_val:
            min_val = n

    average = total / len(numbers)

    print("Data List :", numbers)
    print("Total Sum :", total)
    print("Average   :", average)
    print("Maximum   :", max_val)
    print("Minimum   :", min_val)

run_calculator()
```

---

### Project 2 (Intermediate): Object-Oriented Inventory Management System
Applies OOP class encapsulation, state tracking, and formatted reporting:

```python
class Item:
    def __init__(self, sku: str, name: str, unit_price: float, stock: int):
        self.sku = sku
        self.name = name
        self.unit_price = unit_price
        self.stock = stock

    def restock(self, qty: int):
        self.stock += qty

    def purchase(self, qty: int) -> bool:
        if self.stock >= qty:
            self.stock -= qty
            return True
        return False

    def info(self) -> str:
        return f"[{self.sku}] {self.name} - ${self.unit_price:.2f} (Stock: {self.stock})"

class StoreInventory:
    def __init__(self, store_name: str):
        self.store_name = store_name
        self.catalog = {}

    def register_item(self, item: Item):
        self.catalog[item.sku] = item

    def print_catalog(self):
        print(f"\n--- CATALOG: {self.store_name} ---")
        for sku, itm in self.catalog.items():
            print(itm.info())

store = StoreInventory("Global Sunda Tech")
i1 = Item("SKU-01", "Mechanical Keyboard", 120.0, 25)
i2 = Item("SKU-02", "Wireless Gaming Mouse", 75.0, 40)

store.register_item(i1)
store.register_item(i2)
store.print_catalog()

i1.purchase(3)
print("\nAfter purchasing 3 units:")
print(i1.info())
```

---

### Project 3 (Intermediate): Concurrent Web Scraper with `requests`
Demonstrates concurrent HTTP requests across native threads without GIL contention:

```python
import threading
import requests

endpoints = [
    "https://httpbin.org/get?worker=1",
    "https://httpbin.org/get?worker=2",
    "https://httpbin.org/get?worker=3",
    "https://httpbin.org/get?worker=4"
]

def fetch_worker(url: str, wid: int):
    print(f"[Worker #{wid}] Requesting {url}...")
    res = requests.get(url)
    print(f"[Worker #{wid}] Completed with HTTP status {res.status_code}")

def main():
    threads = []
    for idx, u in enumerate(endpoints):
        t = threading.Thread(target=fetch_worker, args=(u, idx + 1))
        threads.append(t)
        t.start()

    for t in threads:
        t.join()

    print("All requests completed concurrently across CPU cores!")

main()
```

---

### Project 4 (Advanced): High-Throughput Multithreaded TCP Server
```python
#strict
import socket
import threading

def client_handler(sock: socket.socket, addr: str):
    print("Client connected:", addr)
    while True:
        data: str = sock.recv(1024)
        if len(data) == 0:
            break
        sock.send(data) # Echo back
    sock.close()
    print("Client disconnected:", addr)

def main():
    server: socket.socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.bind("0.0.0.0", 8080)
    server.listen(128)
    print("Server listening on 0.0.0.0:8080 (Zero-GIL)...")

    while True:
        c_sock, c_addr = server.accept()
        t = threading.Thread(target=client_handler, args=(c_sock, c_addr))
        t.start()

main()
```

---

### Project 5 (Advanced): Interactive 60 FPS Desktop Canvas via X11 MIT-SHM
```python
import screenGUI
import time

def main():
    win = screenGUI.Window(800, 600, "SundaPy MIT-SHM 60 FPS Canvas")
    ball_x = 100
    velocity = 5

    while win.is_open():
        win.poll_events()

        ball_x += velocity
        if ball_x > 740 or ball_x < 60:
            velocity = -velocity

        win.clear(0x18, 0x18, 0x25) # Modern dark background
        win.draw_rect(50, 50, 700, 8, 0x45, 0x47, 0x5A)
        win.draw_circle(ball_x, 300, 26, 0x89, 0xB4, 0xFA) # Bright blue sphere
        win.draw_text(20, 20, "SundaPy Native 60 FPS Desktop Engine", 0xCD, 0xD6, 0xF4)

        win.present()
        time.sleep(0.016)

main()
```

---

### Project 6 (Systems): 2D Game Rendering with Raylib via Direct C Import
```python
#@link: raylib, m
import "raylib.h" as rl

def main():
    rl.InitWindow(800, 450, "SundaPy Direct C Raylib Game")
    rl.SetTargetFPS(60)

    player_x: f32 = 400.0
    player_y: f32 = 225.0

    while not rl.WindowShouldClose():
        if rl.IsKeyDown(rl.KEY_RIGHT): player_x += 5.0
        if rl.IsKeyDown(rl.KEY_LEFT):  player_x -= 5.0
        if rl.IsKeyDown(rl.KEY_UP):    player_y -= 5.0
        if rl.IsKeyDown(rl.KEY_DOWN):  player_y += 5.0

        rl.BeginDrawing()
        rl.ClearBackground(rl.RAYWHITE)
        rl.DrawText("Use Arrow Keys to control character", 15, 15, 20, rl.DARKGRAY)
        rl.DrawCircle(int(player_x), int(player_y), 22.0, rl.MAROON)
        rl.EndDrawing()

    rl.CloseWindow()

main()
```

---

### Project 7 (Systems): High-Speed Vector & Cryptographic Hash ALU in `#strict`
```python
#strict
import math
import time

def run_cryptographic_pipeline(total_iterations: i32) -> u64:
    accumulator: u64 = 0xCBF29CE484222325
    fnv_prime: u64 = 0x100000001B3
    i: i32 = 1

    while i <= total_iterations:
        root_val: i32 = math.isqrt(i)
        gcd_val: i32 = math.gcd(i, 42)

        accumulator ^= (u64(root_val) << 8) | u64(gcd_val)
        accumulator *= fnv_prime
        i += 1

    return accumulator

def main():
    print("Executing 10,000,000 hardware ALU iterations in #strict mode...")
    start_ns: i64 = time.time_ns()
    digest: u64 = run_cryptographic_pipeline(10000000)
    end_ns: i64 = time.time_ns()

    elapsed_ms: f64 = f64(end_ns - start_ns) / 1000000.0
    print("Pipeline Complete!")
    print("Final Checksum:", digest)
    print("Execution Time:", elapsed_ms, "ms")

main()
```

---

## Chapter 16: Extreme Performance Optimization, SIMD, & Comprehensive FAQ

### 5 Golden Rules of SundaPy Performance Optimization
1. **Annotate Compute-Intensive Hotspots with `#strict`:** Eliminates tagged union boxing and promotes variable storage to hardware registers.
2. **Select Appropriate Integer Widths:** Use `i32` for geometry/rendering and `i64` for large accumulators and timestamps.
3. **Use Hardware Intrinsics:** Prefer `math.isqrt`, `math.gcd`, and `math.lcm` over manual Python loops.
4. **Compile for Production with `--fast` (`-O3`):**
   ```bash
   sundapy --fast --build app.py
   ```
   Enables LLVM SIMD auto-vectorization, loop unrolling, and dead-code elimination.
5. **Leverage POSIX Multithreading:** Split CPU-bound tasks across `threading.Thread` instances to utilize 100% of all available CPU cores without GIL interference.

---

### Comprehensive FAQ

- **Q: Does SundaPy require Python installed on the target machine?**  
  *A: No. SundaPy compiles code Ahead-Of-Time into completely standalone ELF executable binaries with zero external Python runtime dependencies.*

- **Q: Why does multithreading scale linearly across CPU cores in SundaPy?**  
  *A: Because SundaPy has no Global Interpreter Lock (GIL). Each thread executes on its own native kernel POSIX thread with independent memory context.*

- **Q: When should I choose Dynamic Mode vs Strict Mode?**  
  *A: Use Dynamic Mode for scripting, rapid prototyping, and flexible tooling. Use `#strict` mode for high-throughput network servers, game development, numeric algorithms, and direct C/FFI interop.*

- **Q: Can I import existing C or Rust shared libraries?**  
  *A: Yes. Use Direct C Import (`import "header.h"`) for compile-time headers, or `import ffi` to load `.so` libraries dynamically at runtime.*

- **Q: How do I deploy a SundaPy application to production?**  
  *A: Run `sundapy --fast --build --outname my_app main.py` and deploy the single standalone `my_app` binary directly to your Linux server.*

---
*This manual is the official technical reference of the SundaPy project. All rights reserved.*

