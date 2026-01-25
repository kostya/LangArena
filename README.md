## LangArena: A Balanced Programming Language Benchmark Suite
---

**LangArena** is a collection of **40 diverse benchmarks** designed for a **realistic, apples-to-apples comparison** of programming language performance. The goal is not to find the ultimate winner in micro-optimizations, but to evaluate how well each language's compiler or runtime optimizes clean, idiomatic, production-style code.

### Results Page

[Results](https://kostya.github.io/LangArena/)

### Origin & Methodology

The suite was initially authored in **Crystal** and then translated to other languages using AI-assisted tools (DeepSeek). This approach ensures functional and algorithmic parity, though the resulting code may not always be the absolute fastest version a language expert could write.

**Sources:** Benchmark ideas were taken from:

*   **The Computer Language Benchmarks Game**
*   **My own collections:** [benchmarks](https://github.com/kostya/benchmarks), [jit-benchmarks](https://github.com/kostya/jit-benchmarks), [crystal-benchmarks-game](https://github.com/kostya/crystal-benchmarks-game), [crystal-metric](https://github.com/kostya/crystal-metric)
*   **Crystal code samples**

### Core Philosophy

*   **Realistic Code:** Benchmarks reflect how an average developer would solve a problem, using standard libraries and idiomatic constructs.
*   **Algorithmic Consistency:** The same core algorithm is implemented across all languages for each task to ensure a fair comparison.
*   **No "Hacks":** Low-level tricks, impractical compiler flags (e.g., bounds check disabling), or non-standard libraries are intentionally avoided.
*   **Pull Requests Welcome:** While consistency is key, improvements that maintain the philosophy and fix suboptimal implementations are encouraged.

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
`C`, `C++`, `Crystal`, `Rust`, `Go`, `Swift`, `C#`, `Java`, `Kotlin`, `TypeScript`, `Zig`.

Languages like Python, Ruby, or PHP are intentionally excluded to maintain a focused comparison within a similar performance bracket.

### Beyond Just Ranking
This suite is also a practical tool for:

*   **Compiler Tracking:** Monitor performance regressions/improvements across compiler versions.
*   **New Language Evaluation:** Get a standardized "score" to position a new language against established ones.

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

	docker compose build
	ruby benchmarks.rb

## Generate Website

	cd github_pages
	ruby gen.rb ../results/2026-01-16-x86_64-linux-gnu.js
	open index.html

