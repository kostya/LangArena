## LangArena: A Balanced Programming Language Benchmark Suite
---

**LangArena** is a collection of **41 diverse benchmarks** designed for a **realistic, apples-to-apples comparison** of programming language performance. The goal is not to find the ultimate winner in micro-optimizations, but to evaluate how well each language's compiler or runtime optimizes clean and readable code.

### Results Page

[Results](https://kostya.github.io/LangArena/)

### Origin & Approach

The suite started with my original implementation in Crystal. AI tools assisted in translating it to other languages. Throughout this process, I reviewed and edited the implementation for semantic correctness and logical consistency to ensure idiomatic accuracy and fair benchmarking.
Not all algorithms could be implemented identically across all languages — simply because the languages are too different (this is particularly true for base64 and JSON tests). However, I made every effort to make the implementations as similar as possible to each other.
**Handling Library Differences**: To address performance differences stemming from varying standard library implementations, I created a special tab in the results — Runtime Score. This metric normalizes execution times (seconds) into a 0–100 scoring system, where 50 represents the average performance across all languages. The overall Runtime Score is calculated as the average across all benchmarks. This approach reduces the impact of outliers and ensures a fair overall assessment: a language that excels in most tasks but struggles with one particular library implementation (like JSON parsing) isn't severely penalized. It reflects the real-world scenario where developers use a mix of algorithms and libraries.

**Sources:** Benchmark ideas were taken from:

*   **The Computer Language Benchmarks Game**
*   **My own collections:** [benchmarks](https://github.com/kostya/benchmarks), [jit-benchmarks](https://github.com/kostya/jit-benchmarks), [crystal-benchmarks-game](https://github.com/kostya/crystal-benchmarks-game), [crystal-metric](https://github.com/kostya/crystal-metric)
*   **Crystal code samples**

### Core Philosophy

*   **Realistic Code:** Benchmarks reflect how an average developer would solve a problem, using standard libraries and idiomatic constructs.
*   **Algorithmic Consistency:** The same core algorithm is implemented across all languages for each task to ensure a fair comparison.
*   **No "Hacks":** Low-level tricks, impractical compiler flags (e.g., bounds check disabling), or non-standard libraries are intentionally avoided.
*   **Pull Requests Welcome:** While consistency is key, improvements that maintain the philosophy and fix suboptimal implementations are encouraged.
* **Testing Language "Muscle"**: We measure the **cost of abstractions**. Can a language take clean, idiomatic code and optimize it to efficient machine code? Languages that can (like Rust, Java) prove their compilers are powerful. Languages that can't show the honest price of their abstractions. Benchmarks like matrix multiplication use **naive implementations** intentionally. We're not measuring how fast a language can call a C library (like BLAS via numpy), but how efficiently it handles fundamental computational patterns — because one day you'll have to write that loop yourself.

### Benchmarking Methodology

Each benchmark's execution time is measured in isolation, with data preparation excluded from timing. The suite includes a separate warmup phase for JIT-based languages (C#, Java, Julia, etc.) to allow compilation and optimization before measurements begin. This ensures fair comparisons by measuring steady-state performance where applicable, while still capturing cold-start characteristics for AOT-compiled languages. All benchmarks produce verifiable checksums to ensure algorithmic correctness across implementations.

### Benchmark Categories
The benchmarks cover common practical tasks:

*   **JSON Processing:** Parsing and generation
*   **Data Encoding:** Base64 encoding/decoding
*   **Text Processing:** Regex matching, string manipulation
*   **Cryptography & Hashing:** SHA-256, CRC32
*   **Sorting Algorithms:** Quick sort, merge sort
*   **Graph Algorithms:** BFS, DFS, Dijkstra, A* pathfinding
*   **Mathematical Computations:** Matrix multiplication, prime calculation, spectral norm
*   **Simulations:** N-body, Game of Life, neural network
*   **Classic Benchmarks:** Binary trees, Fannkuchredux, Mandelbrot (from Computer Language Benchmarks Game)

### Evaluated Languages
The suite currently focuses on **compiled and high-performance managed languages**:
`C`, `C++`, `Crystal`, `Rust`, `Go`, `Swift`, `C#`, `Java`, `Kotlin`, `TypeScript`, `Zig`, `D`, `V`, `Julia`, `Nim`, `F#`, `Dart`, `Python`, `Odin`, `Scala`.

Languages like Python, Ruby, or PHP are intentionally excluded to maintain a focused comparison within a similar performance bracket.

### Beyond Just Ranking
This suite is also a practical tool for:

*   **Compiler Tracking:** Monitor performance regressions/improvements across compiler versions.
*   **New Language Evaluation:** Get a standardized "score" to position a new language against established ones.

### Hardware
AMD Ryzen 7 3800X 8-Core Processor 78GB (x86_64-linux-gnu)

# Running

## Without docker:

	cd rust
	./test [BenchName]
	./run [BenchName]

## With docker:
Require docker-compose-plugin v2, check if it installed: run `docker compose version`, version should be v2.xxx. Or install [it](https://docs.docker.com/engine/install/ubuntu/#set-up-the-repository).

	docker compose build rust
	docker compose run rust
	./test [BenchName]
	./run [BenchName]

## Run all benchmarks

	sh build-docker.sh
	ruby benchmarks.rb

## Generate Website

	cd docs
	ruby gen.rb ../results/2026-02-02-x86_64-linux-gnu.js
	open index.html

