# LangArena: Programming Language Benchmark Suite

---
# *Updates are frozen due to technical issues with my PC*
---

[Results Page](https://kostya.github.io/LangArena/)

## What is it?

A collection of 50 tasks across 26 languages - complex, non-synthetic, and inspired by real-world problems (JSON, Base64, CSV, neural networks, compression, maze A*, graph algorithms, sorting, hashing, interpreters, parallel matmul, and more). Where possible, the same core algorithm is implemented across all languages using idiomatic constructs; for library-based (JSON, Base64, CSV), I use the best practical option for each language. Checksums verify correctness and prevent dead-code elimination. The suite runs monthly with full history, so you can watch compiler performance evolve over time. The goal is not to crown a micro-optimization champion, but to see how well each language's compiler or runtime optimizes clean, readable, idiomatic code. The results include runtime, Runtime Score, memory usage, compile time, and expressiveness.

**Contenders:** `C`, `C++`, `Crystal`, `Rust`, `Go`, `Swift`, `C#`, `Java`, `Kotlin`, `TypeScript`, `Zig`, `D`, `V`, `Julia`, `Nim`, `F#`, `Dart`, `Python`, `Odin`, `Scala`, `C3`, `Ruby`, `PHP`, `Mojo`, `Javascript`, `Gossamer`.

Note on `Mojo`: this is a young language, and many tests use Python interop instead of native implementations, simply because I can't compile libraries for JSON, Regex, or implement certain tasks better due to missing language features. Performance is still very raw.

Participating Compilers/Runtimes:

* `C`: [Clang](https://clang.llvm.org/), [GCC](https://gcc.gnu.org/), [mycc](https://github.com/kostya/myc), [cproc](https://git.sr.ht/~mcf/cproc)
* `C++`: [Clang++](https://clang.llvm.org/), [G++](https://gcc.gnu.org/)
* `Rust`: [rustc](https://www.rust-lang.org/), rustc/WASM ([Node](https://nodejs.org/), [Wasmtime](https://wasmtime.dev/), [Wasmer](https://wasmer.io/), [WasmEdge](https://wasmedge.org/))
* `Zig`: [Zig](https://ziglang.org/)
* `Crystal`: [Crystal](https://crystal-lang.org/)
* `Mojo`: [Mojo](https://www.modular.com/mojo)
* `D`: [DMD](https://dlang.org/download.html), [LDC](https://github.com/ldc-developers/ldc)
* `V`: [V/GCC, V/Clang](https://vlang.io/)
* `Go`: [Go](https://go.dev/)
* `C#`: [.NET/JIT](https://dotnet.microsoft.com/), [.NET/AOT](https://learn.microsoft.com/en-us/dotnet/core/deploying/native-aot/)
* `F#`: [.NET/JIT](https://dotnet.microsoft.com/languages/fsharp)
* `Nim`: [Nim/GCC, Nim/Clang, Nim++/GCC, Nim++/Clang++](https://nim-lang.org/), [Nim/NLVM](https://github.com/arnetheduck/nlvm)
* `Julia`: [Julia](https://julialang.org/)
* `Swift`: [Swift](https://swift.org/)
* `Odin`: [Odin](https://odin-lang.org/)
* `C3`: [C3](https://c3-lang.org/)
* `Java`: [OpenJDK](https://openjdk.org/), [GraalVM](https://www.graalvm.org/)
* `Kotlin`: [Kotlin/JVM](https://kotlinlang.org/), [Kotlin/GraalVM](https://www.graalvm.org/)
* `Scala`: [Scala/JVM](https://www.scala-lang.org/), [Scala/GraalVM](https://www.graalvm.org/)
* `Dart`: [Dart/AOT, Dart/JIT](https://dart.dev/)
* `TypeScript`: [Node](https://nodejs.org/), [Bun](https://bun.sh/), [Deno](https://deno.com/)
* `Python`: [PyPy](https://www.pypy.org/)
* `Ruby`: [CRuby/YJIT](https://www.ruby-lang.org/), [TruffleRuby](https://www.graalvm.org/ruby/), [Spinel](https://github.com/matz/spinel)
* `PHP`: [PHP/JIT](https://www.php.net/)
* `JavaScript`: [Node](https://nodejs.org/), [Bun](https://bun.sh/), [Deno](https://deno.com/)
* `Gossamer`: [Gossamer](https://gossamer-lang.org)


## Why?

Most existing benchmarks suffer from the same problems: they measure micro-optimizations or synthetic loops, mix multiple concepts so it's unclear what's being measured, and often degenerate into assembly or parallelism competitions rather than clean code. The same algorithm is rarely preserved across implementations. They measure code that nobody runs in production - where you use standard language constructs, not hand-tuned assembly - and they rely on unsafe flags (`--no-bounds-check`) that no one enables in real projects. On top of that, there's no history: I'd love to see how Clang improved over time on a simple graph, but most suites are one-off runs.

## Origin & Approach

The suite began with my original implementation in Crystal. AI tools assisted in translating it to other languages, but this was far from a one-shot process. Many implementations went through multiple iterations - fixing incorrect checksums, correcting algorithms, rewriting code I didn't like, or investigating unexpected slowness. Others were fine from the start. Either way, every implementation was reviewed for semantic correctness and idiomatic accuracy to ensure fair benchmarking.

## Core Philosophy

* Code for Humans: Benchmarks are written in a clear, idiomatic style that prioritizes readability and maintainability. No bit hacks, no arcane optimizations, no clever tricks - just code you'd actually want to maintain in production. All the optimizations should be done by the compiler - you should be able to wake up at 3 AM 5 years from now and still understand this code.
* Algorithmic Consistency: The same core algorithm is used across all languages for each task (exceptions possible).
* Standard vs Unsafe Modes: All benchmarks use standard production compiler flags (safe mode by default). A separate "Hacking" section explores unsafe optimizations - disabling bounds checks, runtime checks, and other trade-offs that prioritize speed over safety.
* Testing Language "Muscle": We measure the cost of abstractions. Can a language optimize clean, idiomatic code to efficient machine code? Languages that can (like Rust, Java) prove their compilers are powerful. Those that can't reveal the honest price of their abstractions. Benchmarks like matrix multiplication use naive implementations intentionally - not to measure C library calls (e.g., BLAS via numpy), but to see how efficiently the language handles fundamental computational patterns. Because one day, you'll have to write that loop yourself.

## Benchmarking Methodology

Each benchmark runs in isolation, with data preparation excluded from timing. JIT-based languages (C#, Java, Julia, etc.) receive a separate warmup phase to reach steady-state performance before measurements begin. This ensures fair comparisons. Checksums verify algorithmic correctness across all implementations.

## Disclaimer: This Is a Subjective Benchmark

LangArena is not an objective, peer-reviewed, or industry-standard benchmark suite. It represents my personal vision of what "clean", "idiomatic" code looks like across many languages.

The rules, library choices, implementation styles, and even which optimizations I consider "fair" - 
all of these live in my head. They are not formalized, not voted on, and not guaranteed to be 
"correct" by any external standard.

### Think I'm wrong?

* If you disagree with a library choice or implementation - you're probably right.
* You are welcome to open an issue or a PR with suggestions.
* However, whether I accept or reject your change depends solely on my subjective judgment - not on community consensus, not on "popularity", not on objective metrics. I prioritize maintaining the benchmark's philosophy over chasing better numbers.

### Runtime Score: Reducing the Impact of Subjectivity

The Runtime Score is a normalized 0–100 metric based on four reference points: 100 (best result), 90 (average of the fastest languages), 50 (overall average), and 0 (worst result). This normalization is applied per test, so each test contributes equally to the final score - regardless of its absolute runtime. The per-benchmark scores are then averaged across all 50 tests to produce the final Runtime Score for each language.

**Why this removes subjectivity:**

- One "bad" implementation affects one benchmark out of 50 - just 2% of the final score.
- To significantly hurt a language's ranking, it would have to underperform consistently across many different tests.
- One lucky benchmark can't carry a language that's slow everywhere else.
- Even if I pick a "wrong" JSON library for some language, it affects only 3 tests - just 6% of the final score.

The result: subjective choices - libraries, implementation details, even human errors - get smoothed out by the numbers. The final ranking reflects average performance across 50 diverse real-world tasks, not my pick for a single test.

## Does it make sense if it's subjective?

It depends.

* Comparing languages by raw runtime in seconds? Fun to watch, useful per benchmark, but misleading as an overall ranking. One slow test can skew the entire picture.

* Comparing languages by Runtime Score? Robust. It gives a holistic view across 50 diverse tests - smoothing out outliers and reducing the impact of any single decision. To score high in this metric is genuinely hard - a language has to be consistently strong across the board.

* Comparing memory usage, compile time, and expressiveness? Solid. These depend less on implementation details and benefit from better averaging across benchmarks.

* Comparing compilers/runtimes for the same language? Perfect. The code is identical - you can clearly see the difference between TypeScript/Node vs TypeScript/Bun, Java vs GraalVM, Clang vs GCC, CRuby vs Spinel, etc.

* Tracking history over time? Monthly runs let you watch performance regressions and improvements as compilers mature.

* Comparing different flags (safe vs unsafe)? Check the Hacking section for that.

## Sources

Benchmark ideas were taken from:

*   The Computer Language Benchmarks Game
*   My own collections: [benchmarks](https://github.com/kostya/benchmarks), [jit-benchmarks](https://github.com/kostya/jit-benchmarks), [crystal-benchmarks-game](https://github.com/kostya/crystal-benchmarks-game), [crystal-metric](https://github.com/kostya/crystal-metric)
*   Crystal code samples

## Beyond Just Ranking

This suite is also a practical tool for:

* Compiler Tracking - monitor performance regressions and improvements across compiler versions.
* New Language Evaluation - get a standardized score to position a new language against established ones.

## Hardware

AMD Ryzen 7 3800X 8-Core, 78GB RAM (x86_64-linux-gnu)

# Running

## Local run without docker:

`cd Lang` and run scripts `./test` (for fast testing) and `./run` (for local measure):

	cd rust
	./test [BenchName]
	./run [BenchName]

## Run all benchmarks

Requires only: `docker`, `docker compose`, and `ruby`. Warning: Docker images take up more than 35 GB of disk space.

	sh build-docker.sh
	ruby benchmarks.rb

## Generate Website

	cd docs
	ruby gen.rb ../results/2026-02-02-x86_64-linux-gnu.js
	open index.html


