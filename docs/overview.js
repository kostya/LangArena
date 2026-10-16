function overview_tab($results) {
    $results.append(`
<style>
.overview {
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
  line-height: 1.6;
  color: #1a1a1a;
  max-width: 1000px;
  margin: 0 auto;
  padding: 2rem 1.5rem;
  background-color: #ffffff;
}

.overview h1 {
  font-size: 2.2rem;
  font-weight: 500;
  color: #111111;
  margin-top: 0;
  margin-bottom: 1.5rem;
  padding-bottom: 0.5rem;
  border-bottom: 1px solid #cccccc;
  letter-spacing: -0.02em;
}

.overview h2 {
  font-size: 1.6rem;
  font-weight: 500;
  color: #222222;
  margin-top: 2rem;
  margin-bottom: 1rem;
  padding-bottom: 0.25rem;
  border-bottom: 1px solid #dddddd;
}

.overview h3 {
  font-size: 1.3rem;
  font-weight: 500;
  color: #333333;
  margin-top: 1.5rem;
  margin-bottom: 0.75rem;
}

.overview p {
  margin-bottom: 1.25rem;
  text-align: justify;
}

.overview strong {
  font-weight: 600;
  color: #000000;
}

.overview ul, ol {
  margin-top: 0.5rem;
  margin-bottom: 1.5rem;
  padding-left: 1.8rem;
}

.overview li {
  margin-bottom: 0.4rem;
}

.overview a {
  color: #1a1a1a;
  text-decoration: underline;
  text-decoration-color: #999999;
  text-underline-offset: 0.2rem;
}

.overview a:hover {
  text-decoration-color: #000000;
}

.overview hr {
  border: none;
  border-top: 1px solid #eeeeee;
  margin: 2rem 0;
}

.highlight {
  background-color: #f2f2f2;
  padding: 0.1rem 0.3rem;
  font-weight: 500;
}

.languages {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
  margin: 1rem 0 0.5rem 0;
}

.language-tag {
  background-color: #f0f0f0;
  color: #222222;
  padding: 0.3rem 0.8rem;
  border-radius: 0;
  font-family: 'SF Mono', 'Menlo', 'Monaco', 'Cascadia Code', 'Consolas', monospace;
  font-size: 0.9rem;
  border: 1px solid #d0d0d0;
}

.language-note {
  font-style: italic;
  color: #555555;
  margin-top: 0.5rem;
  padding-left: 1rem;
  border-left: 2px solid #cccccc;
}

.code {
  font-family: 'SF Mono', 'Menlo', 'Monaco', 'Cascadia Code', 'Consolas', monospace;
  background-color: #f2f2f2;
  color: #1a1a1a;
  padding: 0.2rem 0.4rem;
  border-radius: 0;
  font-size: 0.9em;
  border: 1px solid #e0e0e0;
}

.runtimes-table {
  width: 100%;
  border-collapse: collapse;
  margin: 1rem 0 1.5rem 0;
  font-size: 0.95rem;
}

.runtimes-table th,
.runtimes-table td {
  text-align: left;
  padding: 0.5rem 0.75rem;
  border-bottom: 1px solid #e5e5e5;
  vertical-align: top;
}

.runtimes-table th {
  font-weight: 600;
  color: #111111;
  background-color: #fafafa;
}

.runtimes-table td:first-child {
  white-space: nowrap;
  font-weight: 500;
}

.runtimes-table a {
  color: #1a1a1a;
  text-decoration: underline;
  text-decoration-color: #bbbbbb;
  text-underline-offset: 0.15rem;
}

.runtimes-table a:hover {
  text-decoration-color: #000000;
}
</style>

<div class="overview">

<h1>LangArena: Programming Language Evaluation Suite</h1>

<h2>What is it?</h2>

<p>My experiment. It evaluates 27 programming languages across 50 real-world-inspired tasks using 5 metrics: runtime, runtime score, memory usage, compile time, and expressiveness. The results are aggregated to provide a rough picture of each language's performance. This is a comparative evaluation, not a race to crown the fastest language. 8/50 tests cover ecosystem capabilities JSON, CSV, Regexp - while the rest are pure algorithms.</p>

<p>The implementations follow a simple, Rosetta Code-like approach: comparable implementations of the same algorithms, with exceptions where necessary. The aim is not to squeeze the maximum performance out of each language, but to write roughly equivalent code across languages. Idiomatic constructs are used where they don't compromise comparability. This reflects typical production code written by teams: readable, maintainable solutions using standard libraries, familiar idioms, and conventional compiler flags.</p>

<p>The suite began with my original implementation in Crystal. The other languages were ported from it with LLM assistance. Each task has a checksum to validate implementation correctness and prevent DCE.</p>

<p>The main table shows results for standard safe release flags. A separate "Hacking" section explores unsafe optimizations - disabling bounds checks, runtime checks, and other trade-offs that prioritize speed over safety.</p>

<p>Since this is a language-level evaluation, cross-language comparisons are rough and approximate. Comparing different runtimes or compilers for the same language, however, gives a fairer test - OpenJDK/GraalVM, Node/Bun/Deno, Clang/GCC, CRuby/Spinel, and others.</p>

<p><strong>Languages:</strong> <span class="language-tag">C</span> <span class="language-tag">C++</span> <span class="language-tag">Crystal</span> <span class="language-tag">Rust</span> <span class="language-tag">Go</span> <span class="language-tag">Swift</span> <span class="language-tag">C#</span> <span class="language-tag">Java</span> <span class="language-tag">Kotlin</span> <span class="language-tag">TypeScript</span> <span class="language-tag">Zig</span> <span class="language-tag">D</span> <span class="language-tag">V</span> <span class="language-tag">Julia</span> <span class="language-tag">Nim</span> <span class="language-tag">F#</span> <span class="language-tag">Dart</span> <span class="language-tag">Python</span> <span class="language-tag">Odin</span> <span class="language-tag">Scala</span> <span class="language-tag">C3</span> <span class="language-tag">Ruby</span> <span class="language-tag">PHP</span> <span class="language-tag">Mojo</span> <span class="language-tag">JavaScript</span> <span class="language-tag">Gossamer</span> <span class="language-tag">Goose</span></p>

<p class="language-note"><strong>Note on Mojo:</strong> this is a young language, and many tests use Python interop instead of native implementations, simply because I can't compile libraries for JSON, Regex. Performance is still very raw.</p>

<h3>Participating Compilers/Runtimes</h3>

<table class="runtimes-table">
  <thead>
    <tr>
      <th>Language</th>
      <th>Compilers / Runtimes</th>
    </tr>
  </thead>
  <tbody>
    <tr><td>C</td><td><a href="https://clang.llvm.org/">Clang</a>, <a href="https://gcc.gnu.org/">GCC</a>, <a href="https://github.com/kostya/myc">mycc</a>, <a href="https://git.sr.ht/~mcf/cproc">cproc</a></td></tr>
    <tr><td>C++</td><td><a href="https://clang.llvm.org/">Clang++</a>, <a href="https://gcc.gnu.org/">G++</a></td></tr>
    <tr><td>Rust</td><td><a href="https://www.rust-lang.org/">rustc</a>, rustc/WASM (<a href="https://nodejs.org/">Node</a>, <a href="https://wasmtime.dev/">Wasmtime</a>, <a href="https://wasmer.io/">Wasmer</a>, <a href="https://wasmedge.org/">WasmEdge</a>)</td></tr>
    <tr><td>Zig</td><td><a href="https://ziglang.org/">Zig</a></td></tr>
    <tr><td>Crystal</td><td><a href="https://crystal-lang.org/">Crystal</a></td></tr>
    <tr><td>Mojo</td><td><a href="https://www.modular.com/mojo">Mojo</a></td></tr>
    <tr><td>D</td><td><a href="https://dlang.org/download.html">DMD</a>, <a href="https://github.com/ldc-developers/ldc">LDC</a></td></tr>
    <tr><td>V</td><td><a href="https://vlang.io/">V/GCC, V/Clang</a></td></tr>
    <tr><td>Go</td><td><a href="https://go.dev/">Go</a></td></tr>
    <tr><td>C#</td><td><a href="https://dotnet.microsoft.com/">.NET/JIT</a>, <a href="https://learn.microsoft.com/en-us/dotnet/core/deploying/native-aot/">.NET/AOT</a></td></tr>
    <tr><td>F#</td><td><a href="https://dotnet.microsoft.com/languages/fsharp">.NET/JIT</a></td></tr>
    <tr><td>Nim</td><td><a href="https://nim-lang.org/">Nim/GCC, Nim/Clang, Nim++/GCC, Nim++/Clang++</a>, <a href="https://github.com/arnetheduck/nlvm">Nim/NLVM</a></td></tr>
    <tr><td>Julia</td><td><a href="https://julialang.org/">Julia</a></td></tr>
    <tr><td>Swift</td><td><a href="https://swift.org/">Swift</a></td></tr>
    <tr><td>Odin</td><td><a href="https://odin-lang.org/">Odin</a></td></tr>
    <tr><td>C3</td><td><a href="https://c3-lang.org/">C3</a></td></tr>
    <tr><td>Java</td><td><a href="https://openjdk.org/">OpenJDK</a>, <a href="https://www.graalvm.org/">GraalVM</a></td></tr>
    <tr><td>Kotlin</td><td><a href="https://kotlinlang.org/">Kotlin/JVM</a>, <a href="https://www.graalvm.org/">Kotlin/GraalVM</a></td></tr>
    <tr><td>Scala</td><td><a href="https://www.scala-lang.org/">Scala/JVM</a>, <a href="https://www.graalvm.org/">Scala/GraalVM</a></td></tr>
    <tr><td>Dart</td><td><a href="https://dart.dev/">Dart/AOT, Dart/JIT</a></td></tr>
    <tr><td>TypeScript</td><td><a href="https://nodejs.org/">Node</a>, <a href="https://bun.sh/">Bun</a>, <a href="https://deno.com/">Deno</a></td></tr>
    <tr><td>Python</td><td><a href="https://www.pypy.org/">PyPy</a></td></tr>
    <tr><td>Ruby</td><td><a href="https://www.ruby-lang.org/">CRuby/YJIT</a>, <a href="https://www.graalvm.org/ruby/">TruffleRuby</a>, <a href="https://github.com/matz/spinel">Spinel</a></td></tr>
    <tr><td>PHP</td><td><a href="https://www.php.net/">PHP/JIT</a></td></tr>
    <tr><td>JavaScript</td><td><a href="https://nodejs.org/">Node</a>, <a href="https://bun.sh/">Bun</a>, <a href="https://deno.com/">Deno</a></td></tr>
    <tr><td>Gossamer</td><td><a href="https://gossamer-lang.org">Gossamer</a></td></tr>
    <tr><td>Goose</td><td><a href="https://github.com/aardappel/goose">Goose</a> (compiles to C, built with Clang)</td></tr>
  </tbody>
</table>

<h2>Benchmarking Methodology</h2>

<ul>
  <li>Each test runs in a Docker container.</li>
  <li>Each test runs in isolation, with data preparation excluded from the measured runtime.</li>
  <li>All implementations get a separate warmup phase before measurement, which matters most for JIT-based languages.</li>
  <li>Checksums validate results across implementations.</li>
  <li>Dependency fetching is excluded from the cold compile time measurement.</li>
  <li>Incremental compile time is measured after a single file is changed and recompiled.</li>
</ul>

<h2>Sources</h2>

<p>Benchmark ideas were taken from:</p>

<ul>
  <li><a href="https://madnight.github.io/benchmarksgame/">The Computer Language Benchmarks Game</a></li>
  <li>My own collections: <a href="https://github.com/kostya/benchmarks">benchmarks</a>, <a href="https://github.com/kostya/jit-benchmarks">jit-benchmarks</a>, <a href="https://github.com/kostya/crystal-benchmarks-game">crystal-benchmarks-game</a>, <a href="https://github.com/kostya/crystal-metric">crystal-metric</a></li>
  <li>Crystal code samples</li>
</ul>

<h2>Related</h2>

<ul>
  <li>A single-file, self-contained <a href="https://github.com/kostya/index-c">stress test</a> for C compilers and optimizers.</li>
</ul>

<h2>Hardware</h2>

<p>AMD Ryzen 7 3800X 8-Core, 78GB RAM (x86_64-linux-gnu)</p>

<h2>Running</h2>

<h3>Local run without docker</h3>

<p><code class="code">cd Lang</code> and run scripts <code class="code">./test</code> (for fast testing) and <code class="code">./run</code> (for local measure):</p>

<pre class="code" style="display:block; padding:1rem; white-space:pre; overflow-x:auto;">cd rust
./test [BenchName]
./run [BenchName]</pre>

<h3>Run all</h3>

<p>Requires only: <code class="code">docker</code>, <code class="code">docker compose</code>, and <code class="code">ruby</code>. Warning: Docker images take up more than 35 GB of disk space.</p>

<pre class="code" style="display:block; padding:1rem; white-space:pre; overflow-x:auto;">sh build-docker.sh
ruby benchmarks.rb</pre>

<h3>Generate Website</h3>

<pre class="code" style="display:block; padding:1rem; white-space:pre; overflow-x:auto;">cd docs
ruby gen.rb ../results/2026-02-02-x86_64-linux-gnu.js
open index.html</pre>

</div>
    `);
}