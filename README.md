# LangArena: Programming Language Evaluation Suite

[Results](https://kostya.github.io/LangArena/)

## What is it?

My experiment. It evaluates 27 programming languages across 50 real-world-inspired tasks using 5 metrics: runtime, runtime score, memory usage, compile time, and expressiveness. The results are aggregated to provide a rough picture of each language's performance. This is a comparative evaluation, not a race to crown the fastest language. 8/50 tests cover ecosystem capabilities JSON, CSV, Regexp - while the rest are pure algorithms.

The implementations follow a simple, Rosetta Code-like approach: comparable implementations of the same algorithms, with exceptions where necessary. The aim is not to squeeze the maximum performance out of each language, but to write roughly equivalent code across languages. Idiomatic constructs are used where they don't compromise comparability. This reflects typical production code written by teams: readable, maintainable solutions using standard libraries, familiar idioms, and conventional compiler flags.

The suite began with my original implementation in Crystal. The other languages were ported from it with LLM assistance. Each task has a checksum to validate implementation correctness and prevent DCE.

The main table shows results for standard safe release flags. A separate "Hacking" section explores unsafe optimizations - disabling bounds checks, runtime checks, and other trade-offs that prioritize speed over safety.

Since this is a language-level evaluation, cross-language comparisons are rough and approximate. Comparing different runtimes or compilers for the same language, however, gives a fairer test - OpenJDK/GraalVM, Node/Bun/Deno, Clang/GCC, CRuby/Spinel, and others.

**Languages:** `C`, `C++`, `Crystal`, `Rust`, `Go`, `Swift`, `C#`, `Java`, `Kotlin`, `TypeScript`, `Zig`, `D`, `V`, `Julia`, `Nim`, `F#`, `Dart`, `Python`, `Odin`, `Scala`, `C3`, `Ruby`, `PHP`, `Mojo`, `JavaScript`, `Gossamer`, `Goose`.

Note on `Mojo`: this is a young language, and many tests use Python interop instead of native implementations, simply because I can't compile libraries for JSON, Regex. Performance is still very raw.

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
* `Goose`: [Goose](https://github.com/aardappel/goose) (compiles to C, built with Clang)

## Benchmarking Methodology

* Each test runs in a Docker container.
* Each test runs in isolation, with data preparation excluded from the measured runtime. 
* All implementations get a separate warmup phase before measurement, which matters most for JIT-based languages.
* Checksums validate results across implementations.
* Dependency fetching is excluded from the cold compile time measurement.
* Incremental compile time is measured after a single file is changed and recompiled.

## Sources

Benchmark ideas were taken from:

*   [The Computer Language Benchmarks Game](https://madnight.github.io/benchmarksgame/)
*   My own collections: [benchmarks](https://github.com/kostya/benchmarks), [jit-benchmarks](https://github.com/kostya/jit-benchmarks), [crystal-benchmarks-game](https://github.com/kostya/crystal-benchmarks-game), [crystal-metric](https://github.com/kostya/crystal-metric)
*   Crystal code samples

## Related

* A single-file, self-contained [stress test](https://github.com/kostya/index-c) for C compilers and optimizers.

## Hardware

AMD Ryzen 7 3800X 8-Core, 78GB RAM (x86_64-linux-gnu)

# Running

## Local run without docker:

`cd Lang` and run scripts `./test` (for fast testing) and `./run` (for local measure):

	cd rust
	./test [BenchName]
	./run [BenchName]

## Run all

Requires only: `docker`, `docker compose`, and `ruby`. Warning: Docker images take up more than 35 GB of disk space.

	sh build-docker.sh
	ruby benchmarks.rb

## Generate Website

	cd docs
	ruby gen.rb ../results/2026-02-02-x86_64-linux-gnu.js
	open index.html
