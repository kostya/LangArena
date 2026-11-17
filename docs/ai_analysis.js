function ai_analys($results) {
    $results.append(`
<div class="benchmark-analysis">
<h1>🔍 Comprehensive AI Analysis: Programming Language Benchmarks 2026-11-04</h1>

<p><strong>Test Environment:</strong> AMD Ryzen 7 3800X (8-core/16-thread) | 78GB RAM | x86_64-linux-gnu<br>
<strong>Scope:</strong> 27 languages · 50 benchmarks · 31 production configurations · 115 configurations including hacks</p>

<p><em>All numbers below are for the production (safe release) configuration of each language unless stated otherwise. "Best config" means the fastest production configuration of a language.</em></p>

<hr>

<h2>📊 The Big Picture: What Changed Since March</h2>

<p>The previous analysis (2026-03-06) covered 20 languages. Since then seven languages joined — <strong>Goose, Gossamer, C3, Mojo, Ruby, PHP, JavaScript</strong> — and almost every existing toolchain had a major release. The map has been redrawn:</p>

<ul>
<li><strong>A newcomer took the crown.</strong> Goose/Clang finishes the suite in <strong>38.3s</strong> — 30% faster than the next language — and wins 24 of 50 benchmarks.</li>
<li><strong>Rust is now the fastest of the "classic" systems languages:</strong> 54.53s vs C/Clang 55.01s and C++/Clang++ 59.07s.</li>
<li><strong>The middle class got much faster:</strong> Swift −38%, Odin −32%, Julia −27%, Go −26%, D −21%, Bun −19%, Zig −15% compared to March.</li>
<li><strong>One notable regression:</strong> Nim +24%, entirely from regex-heavy tests.</li>
</ul>

<h3>Runtime Performance Clusters (Total Seconds, best config)</h3>
<pre>
🚀 TIER 0 (The Outlier)               38s        Goose
🏁 TIER 1 (The Speed Demons)          54-60s     Rust, C, C++, Gossamer
🏁 TIER 2 (The Systems Contenders)    63-80s     Zig, Odin, C3, D, Java/GraalVM, Crystal, Mojo
🏁 TIER 3 (The Managed Contenders)    82-108s    Kotlin, C#, Go, Julia, Scala, F#, V, Nim
🏁 TIER 4 (The JIT Challengers)       120-205s   TypeScript, JavaScript, Dart, Swift
🏁 TIER 5 (The Specialized)           297-505s   Ruby/Spinel, Python/PyPy, PHP
</pre>

<p><strong>The Gap:</strong> The field is remarkably compressed: 20 of 25 ranked languages finish within 2× of Rust. Python/PyPy (301s) is 5.5× slower than Rust and 7.9× slower than Goose.</p>

<hr>

<h2>🪿 Goose: The Newcomer That Rewrote the Leaderboard</h2>

<p><strong>Goose/Clang: 38.3s · Runtime score 96.8 · 26.5MB memory · 24 wins · 0 last places · +37% expressiveness</strong></p>

<p>No language has ever dominated this suite like this. Goose wins almost half of all benchmarks, never finishes last, uses less memory than Rust, and is one of the most concise languages in the suite (+37%, #5 overall). On paper it is the best language in the dataset on every axis except compile time (4.44s cold).</p>

<p><strong>But look at where the wins come from.</strong> The biggest margins are on allocation-heavy tests:</p>
<ul>
<li><strong>Binarytrees::Obj:</strong> 0.229s vs C 2.47s, Rust 2.59s — 10× faster</li>
<li><strong>Compress::LZWDecode:</strong> 0.117s vs C 0.553s</li>
<li><strong>Calculator::Ast:</strong> 0.135s vs C 1.05s, Rust 0.612s</li>
<li><strong>Graph::AStar:</strong> 0.414s vs C 1.79s, Rust 1.97s</li>
<li><strong>Hash::SHA256:</strong> 0.268s vs C 1.02s, Rust 0.999s</li>
</ul>

<p>The Goose source shows why. Its value-oriented data model makes the natural way to build a tree to <strong>push nodes into a growable array and hold references into it</strong> — Binarytrees::Obj in Goose is effectively an arena, while C, Rust and the rest allocate each node separately. That is idiomatic Goose, and that is exactly what this suite wants to measure ("the actual cost of language abstractions"). But it means a share of those 38 seconds is a <strong>data-layout advantage</strong> that other languages could also get by writing different code, not just better code generation. On pure compute tests (Matmul, Mandelbrot, Spectralnorm, Fannkuch, Sort::Quick) Goose lands right next to C and Rust, not far ahead.</p>

<p>The alternative Goose.go implementation (Goose/Go, 67.89s) shows that the compiler backend matters too — the same language runs 1.8× slower there.</p>

<p><strong>Verdict:</strong> A genuinely impressive result and the headline of this update. The fair reading is: "a language whose default memory model leads to cache-friendly layouts beats languages whose default is one heap allocation per object." That is a real and valuable lesson — and a young language worth watching closely.</p>

<hr>

<h2>🏆 The Unsung Heroes: Achievements That Deserve Recognition</h2>

<h3>🌱 Gossamer: The Quiet All-Rounder</h3>

<p><strong>Gossamer: 60.0s · 39.5MB · 1.23s cold compile · +27% expressiveness · 0 last places</strong></p>

<p>Gossamer is the other big newcomer story. It sits in Tier 1 alongside C and C++ (60.0s), compiles the whole suite in 1.23 seconds (#3 overall), uses under 40MB, and is more concise than Go and Python. It never wins outright, but it is 2nd on Etc::Words, Etc::LogParser and Distance::NGram. No other language in the dataset combines Tier-1 speed with sub-2-second compiles <em>and</em> top-third expressiveness.</p>

<h3>🦀 Rust: Fastest Safe Language, Now Faster Than C</h3>

<p><strong>Rust: 54.53s · C/Clang: 55.01s · C/Gcc: 56.15s · C++/Clang++: 59.07s</strong></p>

<p>In March Rust trailed C/C++ by 1.3%. Now, with rustc 1.99, it is ahead of both — with bounds checks on and safe idiomatic code. Rust also improved its incremental compile time to 1.11s.</p>

<h3>🐹 Go: The Regex Problem Got (Half) Fixed</h3>

<p><strong>Go: 85.07s (was 115.6s in March) · 0.79s cold compile · 0.31s incremental</strong></p>

<p>In March Go was dragged down by two regex benchmarks. Switching to <code>coregex</code> took Etc::LogParser from 30.8s to <strong>0.795s</strong>. Template::Regex is still slow (10.84s — 13× behind the leader); excluding it, Go would finish in about 74s, alongside D and Java. Go remains the fastest compiler in the suite by a wide margin, and its 16-thread scaling jumped from 6.5× to 10.2×.</p>

<h3>🍎 Swift on Linux: From Disaster to Merely Slow</h3>

<p><strong>Swift: 332.98s → 204.8s (−38%)</strong></p>

<p>Swift 6.4 is the most improved language since March. It still has 7 last places (CSV::Parse at 45.7s, Template::Regex 19.0s, Etc::LogParser 13.3s, JSON parsing ~7s) — Swift's string and regex handling on Linux remains its Achilles' heel — but on numeric code it is competitive, and its matmul scaling (11.5×) is excellent.</p>

<h3>☕ The JVM: Still Getting Faster After 30 Years</h3>

<p><strong>Java/GraalVM: 76.61s · Kotlin: 81.92s · Java/OpenJDK: 83.57s · Scala: 90.25s</strong></p>

<p>Every JVM language improved 6–14%. GraalVM/JIT is now <strong>8% faster than OpenJDK</strong> (in March they were tied), and Kotlin/GraalVM (76.16s) and Scala/GraalVM (83.09s) benefit similarly. The JVM also holds the Sort::Self podium together with Julia (0.186s vs C 1.99s).</p>

<h3>🔬 Julia: The Type-Specialized Winner</h3>

<p><strong>Julia: 90.18s (was 122.8s) · Sort::Self 0.118s (17× faster than C) · CLBG::Mandelbrot win</strong></p>

<p>Julia still wins Sort::Self by choosing a specialized algorithm for integer arrays at runtime, and Julia 1.13 brought a 27% overall improvement. Memory (480MB) remains the price.</p>

<h3>💎 Ruby/Spinel: Ahead-of-Time Ruby Is Real</h3>

<p><strong>Ruby/Spinel: 297.5s (519s two weeks ago) · CRuby 4/YJIT: 2410s · TruffleRuby: 329.9s</strong></p>

<p>Spinel, an AOT compiler for Ruby, is <strong>8× faster than CRuby with YJIT</strong> and already beats TruffleRuby and Python/PyPy. It improved 43% in just two weeks. Ruby is also the #3 most expressive language (+39.9%).</p>

<h3>🔥 Mojo: Halved in Two Weeks</h3>

<p><strong>Mojo: 157.4s (1.2.0-dev) → 79.5s (1.2.0)</strong></p>

<p>The Mojo 1.2.0 release fixed regex (Etc::LogParser 13.3s → 0.26s), JSON, CSV and matmul. It now wins CLBG::Nbody and has the best matmul scaling in the suite (14.9×). Its compile time (28.9s cold, 2.9GB RAM) is the heaviest in the dataset.</p>

<hr>

<h2>🧠 Memory: The Hidden Tax</h2>

<pre>
💎 SUB-32MB CLUB        C (23.3), Goose (26.5), C3 (28.1), Rust (29.5), C++ (30.6), Zig (31.2)
📦 39-71MB ZONE         Gossamer (39.5), Odin (42.3), Nim (50.3), Mojo (56.0), Swift (65.1),
                        Crystal (66.2), D (66.6), Go (67.7), V (70.4)
🏛️ 100-125MB REALM      C# (108.6), F# (120.7)
🔥 215-480MB BEASTS      Python (216.8), TypeScript/Bun (219.7), Ruby/Spinel (254.5), Dart/JIT (325.9),
                        Kotlin (328.1), Java/OpenJDK (335.6), Scala (379.5), Java/GraalVM (407.6), Julia (479.6)
</pre>

<p><strong>C3's surprise:</strong> 28MB — in Rust/C territory. <strong>Goose</strong> at 26.5MB is the lowest of any non-C language.</p>

<p><strong>WASM tax:</strong> Rust/WASM/Node uses 101MB vs 29.5MB for native Rust — the cost of running inside V8 — but still 2.7× less than TypeScript/Node (270.5MB).</p>

<hr>

<h2>⚡ Scaling: Who Actually Uses Your 16 Cores?</h2>

<p>Matmul::Single vs Matmul::T16 on an 8-core/16-thread CPU (ideal: 12–16×):</p>

<table>
<tr><th>Language</th><th>Speedup</th><th>Verdict</th></tr>
<tr><td><strong>Mojo</strong></td><td>14.89×</td><td>🏆 Best scaling</td></tr>
<tr><td><strong>C/Clang</strong></td><td>14.07×</td><td>✅ Excellent</td></tr>
<tr><td><strong>Kotlin/JVM</strong></td><td>13.23×</td><td>✅ Excellent</td></tr>
<tr><td>C++/G++, Java/GraalVM, Java/OpenJDK</td><td>12.2–12.6×</td><td>✅ Excellent</td></tr>
<tr><td>Swift</td><td>11.47×</td><td>✅ Very good</td></tr>
<tr><td>Goose</td><td>10.86×</td><td>✅ Good</td></tr>
<tr><td><strong>Go</strong></td><td>10.20×</td><td>✅ Good — up from 6.51× in March</td></tr>
<tr><td>Scala, F#, Rust, Odin, C3, V, D</td><td>9.3–10.2×</td><td>✅ Good</td></tr>
<tr><td>Gossamer, Zig</td><td>8.1–8.8×</td><td>🟡 Decent</td></tr>
<tr><td>C#/JIT, Julia</td><td>7.0–7.8×</td><td>🟡 Mediocre</td></tr>
<tr><td>Ruby/Spinel, Nim</td><td>6.5–6.7×</td><td>🟡 Mediocre</td></tr>
<tr><td>Crystal</td><td>2.46×</td><td>🔴 Poor — stalls at 4 threads (T4 3.02s, T16 2.05s)</td></tr>
<tr><td>Dart/JIT</td><td>2.04×</td><td>🔴 Poor — 16T slower than 8T</td></tr>
<tr><td>TypeScript, Rust/WASM, Python</td><td>~1.0×</td><td>⚫ Single-threaded</td></tr>
</table>

<p>Matmul::Single itself is now a near tie: 26 of 31 configurations finish within 4.9–5.3s. Single-threaded numeric code is a solved problem; threading is where languages still differ.</p>

<hr>

<h2>📦 Compile Times: The Developer Experience Tax</h2>

<h3>Cold Compile (whole suite, wall time, seconds)</h3>
<pre>
⚡ INSTANT (&lt;1.5s)        Go (0.79), C3 (1.01), Gossamer (1.23), TypeScript (1.46)
🚀 FAST (2-5s)            C# (2.18), Nim (2.46), C/Clang (2.69), Java (4.33), Goose (4.44), F# (4.45)
⏱️ MODERATE (5-11s)       V (5.10), C++/Clang++ (5.98), Rust (7.03), Odin (7.64), C/Gcc (8.03), Ruby/Spinel (9.49), Scala (10.74)
🐢 SLOW (17-25s)          Kotlin (17.37), C++/G++ (17.39), Zig (20.37), Crystal (22.82), Swift (24.11)
🦥 VERY SLOW (28s+)       Mojo (28.9), D/LDC (37.17)
</pre>

<h3>Incremental Compile (one file changed)</h3>
<p>Languages with real separate compilation shine here: C (0.05s), Go (0.31s), C++ (0.73s), C3 (1.01s), Rust (1.11s), Nim (1.69s). Whole-program compilers pay full price every time: Zig (19.7s), Crystal (22.9s), Mojo (27.8s), and Kotlin (17.4s).</p>

<p><strong>Crystal's Dilemma persists:</strong> #1 expressiveness (+44.0%), 78.5s runtime, but 22.8s on every rebuild.</p>

<p><strong>C3's Sweet Spot:</strong> 1.01s compiles, 28MB memory, 71.9s runtime — the fastest-compiling native systems language here.</p>

<hr>

<h2>✍️ Expressiveness: The Code You Don't Write</h2>

<h3>Expressiveness vs Average Language (%)</h3>
<pre>
🎯 TIER S (Elite)         Crystal (+44.0%), Scala (+41.7%), Ruby (+39.9%), Nim (+38.1%), Goose (+37.0%)
📝 TIER A (Expressive)    Kotlin (+28.0%), Python (+27.2%), Gossamer (+27.0%), Go (+26.8%), F# (+22.5%), Dart (+21.0%), Swift (+19.6%)
📄 TIER B (Average)       Julia (+12.6%), JavaScript (+11.0%), C# (+5.5%), TypeScript (+1.8%), C++ (+1.0%), Java (−1.3%), Mojo (−2.0%), V (−5.7%)
📜 TIER C (Verbose)       PHP (−16.4%), Rust (−24.6%), D (−33.7%), Odin (−37.4%)
📚 TIER D (Very Verbose)  C3 (−115.5%), C (−126.8%), Zig (−169.0%)
</pre>

<p><strong>Rust got more concise:</strong> −28.7% → −24.6%. <strong>Kotlin</strong> jumped from +22% to +28%. <strong>C</strong> got more verbose (−119.8% → −126.8%) and now has more lines than Zig (9167 vs 9116), though Zig still has far more bytes (279KB vs 231KB).</p>

<p><strong>Goose and Gossamer</strong> prove that the top of the speed table and the top of the expressiveness table are no longer disjoint sets.</p>

<hr>

<h2>🏆 Wins & Losses</h2>

<h3>Most Benchmarks Won (out of 50, per language)</h3>
<ol>
<li><strong>Goose</strong> — 24 wins 🥇</li>
<li><strong>C</strong> — 7 wins 🥈</li>
<li><strong>C++</strong> — 4 wins 🥉</li>
<li>D, Mojo, Kotlin, Julia, V — 2 wins each</li>
<li>Rust, Zig, C3, Scala, Nim — 1 win each</li>
</ol>

<p>In March C/C++/Rust shared 29 wins. Now Goose alone has 24, and Rust — the fastest overall after Goose — has just one: it is rarely first but never far behind.</p>

<h3>Most Last Places</h3>
<ol>
<li><strong>Python/PyPy</strong> — 21 💀</li>
<li><strong>Ruby/Spinel</strong> — 10</li>
<li><strong>Swift</strong> — 7</li>
<li><strong>Dart/JIT</strong> — 5</li>
<li><strong>TypeScript/Bun</strong> — 3</li>
<li>Scala — 2; Java/GraalVM, Nim — 1</li>
</ol>

<p><strong>The Zero Club (never last):</strong> Goose, Rust, C, C++, Gossamer, Zig, Odin, C3, D, Crystal, Mojo, Kotlin, C#, Go, Julia, F#, V — 17 of 25 production languages.</p>

<hr>

<h2>🛡️ The Safety Revelation, Revisited</h2>

<p>In March Rust was within 1.3% of C. Now:</p>

<p><strong>Rust: 54.53s · C/Clang: 55.01s · C++/Clang++: 59.07s</strong></p>

<p>Safe Rust is faster than both safe-flag C and C++. What the hacks tell us about headroom:</p>
<ul>
<li><strong>C/Clang/Unsafe:</strong> 47.89s — 13% faster than C/Clang</li>
<li><strong>C++/Clang++/Unsafe:</strong> 50.42s — 15% faster than C++/Clang++</li>
<li><strong>Zig/Unchecked:</strong> 51.09s — 20% faster than Zig</li>
<li><strong>Rust/MaxPerf/Unsafe:</strong> 53.55s — only 1.8% faster than Rust</li>
</ul>

<p>Rust's safe code is 98% of its unsafe peak. The gap between "safe" and "unsafe" C/C++/Zig is 13–20%, and those languages get no memory-safety guarantees in exchange for leaving it on the table. The conclusion from March holds and is stronger: <strong>the safety tax in Rust is effectively zero.</strong></p>

<hr>

<h2>🔧 Compiler & Runtime Wars</h2>

<h3>GCC vs Clang</h3>
<ul>
<li><strong>C:</strong> Clang 2.0% faster (55.01 vs 56.15) — reversed since March</li>
<li><strong>C++:</strong> tie (59.07 vs 59.26) — G++ led by 7% in March</li>
<li><strong>Nim:</strong> GCC 5% faster (101.9 vs 107.5)</li>
<li><strong>V:</strong> Clang 2% faster (98.32 vs 100.3)</li>
</ul>
<p><strong>Verdict:</strong> Clang 23 has closed the gap. GCC compiles C/C++ 3× slower cold (8.0s vs 2.7s, 17.4s vs 6.0s).</p>

<h3>Alternative C Compilers</h3>
<p><strong>mycc/LLVM: 55.43s</strong> — a hobby C compiler with an LLVM backend lands within 1% of Clang. With the QBE backend it runs 76.57s, cproc/QBE 87.35s. The backend is everything.</p>

<h3>OpenJDK vs GraalVM</h3>
<p>Java: 83.57s vs <strong>76.61s</strong> · Kotlin: 81.92s vs <strong>76.16s</strong> · Scala: 90.25s vs <strong>83.09s</strong>. GraalVM's JIT is now 7–9% faster across all JVM languages, at a cost of ~70MB more memory.</p>

<h3>C# JIT vs AOT</h3>
<p>JIT 82.71s · AOT 100.9s (22% slower) · R2R 101.6s. Memory: JIT 108.6MB. <strong>Verdict:</strong> JIT still wins throughput; AOT is for startup and containers.</p>

<h3>Node vs Bun vs Deno</h3>
<p>TypeScript: Bun 120.4s &lt; Node 135.6s &lt; Deno 168.8s. JavaScript: Bun 121.8s &lt; Node 134.4s &lt; Deno 157.7s. <strong>TypeScript and plain JavaScript perform identically</strong> — types cost nothing at runtime. Bun is fastest and, now, also leaner (219.7MB vs Node 270.5MB).</p>

<h3>WASM Runtimes (Rust)</h3>
<p>Node 71.98s · WasmEdge 73.06s · Wasmer 91.88s · Wasmtime 102.9s. Rust/WASM/Node is <strong>1.9× faster than TypeScript/Node</strong> and faster than native Odin, C3, D, Crystal and Go.</p>

<h3>Ruby Implementations</h3>
<p>Spinel (AOT) 297.5s · TruffleRuby 329.9s · CRuby 4/YJIT 2410s. For CPU-bound code, Ruby implementation choice is an 8× decision.</p>

<h3>Dart JIT vs AOT</h3>
<p>JIT 177.2s · AOT 196.1s — the JIT is now 10% faster, so it became the production config.</p>

<hr>

<h2>🔬 JVM Ecosystem: Java, Kotlin, Scala</h2>

<table>
<tr><th>Metric</th><th>Java (GraalVM)</th><th>Kotlin</th><th>Scala</th><th>Winner</th></tr>
<tr><td>Runtime (s)</td><td>76.61</td><td>81.92</td><td>90.25</td><td>Java 🥇</td></tr>
<tr><td>Memory (MB)</td><td>407.6 (OpenJDK 335.6)</td><td>328.1</td><td>379.5</td><td>Kotlin 🥇</td></tr>
<tr><td>Cold compile (s)</td><td>4.40</td><td>17.37</td><td>10.74</td><td>Java 🥇</td></tr>
<tr><td>Expressiveness</td><td>−1.3%</td><td>+28.0%</td><td>+41.7%</td><td>Scala 🥇</td></tr>
<tr><td>Scaling (16T)</td><td>12.55×</td><td>13.23×</td><td>10.16×</td><td>Kotlin 🥇</td></tr>
<tr><td>Last places</td><td>1</td><td>0</td><td>2</td><td>Kotlin 🥇</td></tr>
</table>

<p><strong>The Trade-off Triangle is unchanged:</strong> Java = speed and compile time, Scala = expressiveness, Kotlin = scaling and balance.</p>

<hr>

<h2>💀 The Hacking Section</h2>

<h3>Biggest Gains</h3>
<ul>
<li><strong>Zig/Unchecked:</strong> 51.09s vs 63.81s — <strong>20% faster</strong></li>
<li><strong>C3/Unsafe:</strong> 58.36s vs 71.89s — <strong>19% faster</strong></li>
<li><strong>Nim/Clang/Danger:</strong> 91.1s vs 107.5s — <strong>15% faster</strong></li>
<li><strong>C++/Clang++/Unsafe:</strong> 50.42s vs 59.07s — 15% faster</li>
<li><strong>C/Clang/Unsafe:</strong> 47.89s vs 55.01s — 13% faster</li>
<li><strong>Swift/Unchecked:</strong> 184.7s vs 204.8s — 10% faster</li>
<li><strong>Rust/PGO:</strong> 52.11s vs 54.53s — 4.4% faster (PGO beats unsafe for Rust)</li>
<li><strong>Rust/MaxPerf/Unsafe:</strong> 53.55s — 1.8% faster</li>
</ul>

<h3>Hacks That Backfired or Did Nothing</h3>
<ul>
<li><strong>Crystal/O3:</strong> 263.9s vs 78.51s — still <strong>3.4× slower</strong></li>
<li><strong>C/Clang/Fast (-Ofast):</strong> 59.35s vs 55.01s — slower; in March -Ofast gave 20%</li>
<li><strong>C/Clang/PGO:</strong> 57.0s — slower than plain C/Clang</li>
<li><strong>D/LDC/MaxPerf:</strong> 76.15s vs 75.86s — no gain</li>
<li><strong>Goose/Clang/Fast:</strong> 38.21s vs 38.3s — no gain</li>
</ul>

<p><strong>Lesson:</strong> Removing bounds checks is still worth 10–20% for languages that rely on them (Zig, C3, Nim, Swift). Exotic flags (-Ofast, -O3 in Crystal, PGO in C) are unreliable from release to release. Default release mode remains the sweet spot.</p>

<hr>

<h2>📈 Historical Trends (March 9 → November 4)</h2>

<h3>Biggest Improvements (same 50 tests)</h3>
<ul>
<li><strong>Swift:</strong> 333.0s → 204.8s (−38.5%) — Swift 6.2 → 6.4</li>
<li><strong>Odin:</strong> 103.1s → 70.0s (−32.0%) — partly JSON fixes in the latest nightly</li>
<li><strong>Julia:</strong> 122.8s → 90.2s (−26.6%) — Julia 1.12 → 1.13</li>
<li><strong>Go:</strong> 115.6s → 85.1s (−26.4%) — coregex for Etc::LogParser</li>
<li><strong>D/LDC:</strong> 96.4s → 75.9s (−21.3%)</li>
<li><strong>TypeScript/Bun:</strong> 149.2s → 120.4s (−19.3%)</li>
<li><strong>Zig:</strong> 75.1s → 63.8s (−15.1%) — Zig 0.15 → 0.17</li>
<li><strong>Java/GraalVM:</strong> 88.9s → 76.6s (−13.8%)</li>
<li><strong>Kotlin:</strong> 93.7s → 81.9s (−12.5%)</li>
</ul>

<h3>Regressions</h3>
<ul>
<li><strong>Nim/Clang:</strong> 86.9s → 107.5s (+23.7%) — the switch to the pure-Nim <code>regex</code> package took Etc::LogParser from 0.65s to 23.4s (last place) and Template::Regex from 1.8s to 10.2s. Outside regex, Nim actually got faster (Matmul::Single 11.5s → 6.1s).</li>
<li><strong>Crystal:</strong> 75.1s → 78.5s (+4.5%)</li>
<li><strong>C++/G++:</strong> 57.1s → 59.3s (+3.8%)</li>
</ul>

<h3>Last Two Weeks (Oct 21 → Nov 4)</h3>
<p>Mojo 1.2.0 (157.4s → 79.5s) and Ruby/Spinel (519s → 297.5s) halved their times. Everything else moved by less than 4%.</p>

<hr>

<h2>🎯 AI Tool's Final Rankings (Multi-Factor)</h2>

<p>Weighted: Runtime 30% | Memory 20% | Expressiveness 15% | Cold Compile Time 15% | Scaling 10% | Wins 10%. Runtime, memory and compile time are scored on a log scale between the best and worst language; JIT languages without a compile step get a neutral 50 for compile time. Best production config per language.</p>

<table>
<tr><th>Rank</th><th>Language</th><th>Score</th><th>Medal</th><th>Archetype</th></tr>
<tr><td>1</td><td><strong>Goose</strong></td><td>89.0</td><td>🥇 GOLD</td><td>The Disruptor — 38.3s, 24 wins, 26.5MB, +37% expressiveness</td></tr>
<tr><td>2</td><td><strong>C++</strong></td><td>74.1</td><td>🥈 SILVER</td><td>The Workhorse — 59.1s, 12.2× scaling, 0 last places</td></tr>
<tr><td>3</td><td><strong>C</strong></td><td>73.8</td><td>🥉 BRONZE</td><td>The Veteran — lowest memory (23.3MB), 7 wins, 14× scaling, but −127% expressiveness</td></tr>
<tr><td>4</td><td><strong>Gossamer</strong></td><td>72.7</td><td>🏅</td><td>The All-Rounder — 60.0s, 1.23s compile, +27% expressiveness</td></tr>
<tr><td>5</td><td><strong>Rust</strong></td><td>68.5</td><td>🏅</td><td>The Safe Speedster — fastest classic language (54.5s), zero safety tax, but only 1 win</td></tr>
<tr><td>6</td><td><strong>Go</strong></td><td>66.8</td><td>🏅</td><td>The Productivity King — 0.79s compiles, +27% expressiveness, scaling fixed</td></tr>
<tr><td>7</td><td><strong>C3</strong></td><td>65.9</td><td>🏅</td><td>The Lean Native — 1.01s compiles, 28MB, but very verbose</td></tr>
<tr><td>8</td><td><strong>Nim</strong></td><td>61.1</td><td>🏅</td><td>The Expressive Native — +38%, 2.5s compiles, held back by its regex library</td></tr>
<tr><td>9</td><td><strong>Mojo</strong></td><td>59.7</td><td>🔥</td><td>The Rising Star — 79.5s, best scaling (14.9×), slowest compiles</td></tr>
<tr><td>10</td><td><strong>Odin</strong></td><td>59.0</td><td>⚙️</td><td>The Improver — 70.0s (−32%), 42MB</td></tr>
<tr><td>11</td><td><strong>V</strong></td><td>57.9</td><td>🆕</td><td>The Steady One — 98.3s, 2 wins, 0 last places</td></tr>
<tr><td>12</td><td><strong>C#</strong></td><td>56.8</td><td>🏅</td><td>The Balanced .NET — 82.7s, 2.2s compiles, 0 last places</td></tr>
<tr><td>13</td><td><strong>F#</strong></td><td>54.5</td><td>🧮</td><td>The Functional .NET — 92.2s, +22.5% expressiveness</td></tr>
<tr><td>14</td><td><strong>D</strong></td><td>52.1</td><td>🏅</td><td>The Comeback — 75.9s (−21%), but slowest compiler (37s)</td></tr>
<tr><td>15</td><td><strong>Crystal</strong></td><td>50.6</td><td>💎</td><td>The Paradox — #1 expressiveness, 78.5s, but 23s compiles and poor scaling</td></tr>
<tr><td>16</td><td><strong>Kotlin</strong></td><td>50.5</td><td>🏅</td><td>The Scaling Star — 13.2×, +28%, but 328MB and 17s compiles</td></tr>
<tr><td>17</td><td><strong>Zig</strong></td><td>50.3</td><td>🏅</td><td>The Fast but Wordy — 63.8s, 31MB, but −169% expressiveness and 20s compiles</td></tr>
<tr><td>18</td><td><strong>Java</strong></td><td>49.4</td><td>🏅</td><td>The Enterprise — 76.6s on GraalVM, but 400MB</td></tr>
<tr><td>19</td><td><strong>Scala</strong></td><td>47.5</td><td>🧮</td><td>The Expressive JVM — +41.7%, 90.3s</td></tr>
<tr><td>20</td><td><strong>Julia</strong></td><td>45.6</td><td>🔬</td><td>The Scientist — 90.2s, Sort::Self champion, 480MB</td></tr>
<tr><td>21</td><td><strong>Swift</strong></td><td>41.3</td><td>🍎</td><td>The Most Improved — −38%, but still 7 last places</td></tr>
<tr><td>22</td><td><strong>TypeScript</strong></td><td>38.0</td><td>📜</td><td>The Web Native — 120.4s on Bun, single-threaded</td></tr>
<tr><td>23</td><td><strong>Dart</strong></td><td>31.9</td><td>🎯</td><td>The UI Specialist — 177.2s, 5 last places</td></tr>
<tr><td>24</td><td><strong>Ruby</strong></td><td>28.5</td><td>💎</td><td>The AOT Experiment — Spinel 8× faster than CRuby, +40% expressiveness</td></tr>
<tr><td>25</td><td><strong>Python</strong></td><td>26.6</td><td>🐍</td><td>The Ecosystem King — 301s, 21 last places</td></tr>
</table>

<p><em>JavaScript and PHP have no production configuration and are not ranked. JS/Bun (121.8s) would sit next to TypeScript; PHP (505.4s) would be last.</em></p>

<hr>

<h2>💡 Strategic Recommendations</h2>

<h3>🔹 For Systems Programming</h3>
<ul>
<li><strong>Choose Rust</strong> for safety with zero speed sacrifice — now faster than C and C++ in this suite</li>
<li><strong>Choose C3 or Odin</strong> for C-like control with fast compiles (C3: 1s) and tiny memory</li>
<li><strong>Choose Zig</strong> if you want explicit control and can afford 20s compiles and verbose code</li>
<li><strong>Watch Goose</strong> — if its results hold as it matures, it is the most interesting new option in the dataset</li>
</ul>

<h3>🔹 For Web Services / Microservices</h3>
<ul>
<li><strong>Choose Go</strong> for sub-second compiles and now-good scaling (10.2×)</li>
<li><strong>Choose Java/Kotlin on GraalVM</strong> for raw JVM throughput (76s)</li>
<li><strong>Choose C#</strong> for the best balance of runtime, memory, and compile time among managed runtimes</li>
<li><strong>Choose Bun</strong> if you are in JS/TS land — fastest and leanest of the three runtimes</li>
</ul>

<h3>🔹 For Developer Productivity</h3>
<ul>
<li><strong>Choose Gossamer</strong> for Tier-1 speed, 1.2s compiles and +27% expressiveness</li>
<li><strong>Choose Crystal or Ruby/Spinel</strong> for maximum concision — Crystal if you need speed</li>
<li><strong>Choose Nim</strong> for concise native code — but bring your own regex if you need speed there</li>
</ul>

<h3>🔹 For Parallel Compute</h3>
<ul>
<li><strong>Choose Mojo, C, Kotlin, C++, or Java</strong> (12–15× on 16 threads)</li>
<li><strong>Avoid Crystal, Dart and single-threaded runtimes</strong> for CPU-bound parallel work</li>
</ul>

<h3>🔹 For Memory-Constrained Environments</h3>
<ul>
<li><strong>Choose C, Goose, C3, Rust, C++, Zig</strong> (23–31MB)</li>
<li><strong>Avoid JVM languages and Julia</strong> (330–480MB)</li>
</ul>

<hr>

<h2>🤯 What Shocked Me</h2>

<ul>
<li><strong>A brand-new language beat C by 30%.</strong> Goose's lead is real — and the source shows it comes largely from an arena-like default memory layout. It is a reminder that "how the language makes you lay out data" can matter more than the compiler backend.</li>
<li><strong>Rust passed C.</strong> 54.53s vs 55.01s, with bounds checks on. In March it was 1.3% behind.</li>
<li><strong>-Ofast stopped helping.</strong> In March, C/Clang -Ofast was 20% faster. Now it is 8% slower. Unsafe flags are not a stable investment.</li>
<li><strong>Swift fixed a third of its runtime in one year</strong> — but still loses 7 benchmarks, all string/regex/JSON. The problem is Foundation/string handling on Linux, not the compiler.</li>
<li><strong>Mojo and Spinel halved their times in two weeks.</strong> Young toolchains move fast; any snapshot of them is out of date quickly.</li>
<li><strong>A hobby C compiler (mycc/LLVM) is within 1% of Clang.</strong> LLVM is still the great equalizer.</li>
<li><strong>TypeScript = JavaScript</strong> to within 1% on every runtime. Types are free.</li>
<li><strong>One library choice cost Nim 20 seconds.</strong> Two regex benchmarks out of 50 turned Nim from a Tier-2 language into a Tier-3 one.</li>
</ul>

<p><strong>What I got wrong in March:</strong> I called Go's goroutines "overhyped for compute" — Go now scales 10.2×. I said GraalVM's JIT offers no advantage — it is now 8% faster than OpenJDK. I said Nim was "the best balanced language" — a regex library change dropped it 23%. I said C leaves 20% on the table unless you cheat — that number is now 13%, and -Ofast no longer helps at all.</p>

<hr>

<h2>🔮 Final Thoughts</h2>

<p><strong>1. Data layout beats codegen.</strong> Goose's biggest wins are allocation-heavy tests. Arena-friendly defaults can give an order of magnitude where compiler tuning gives percent.</p>

<p><strong>2. The safety tax is gone.</strong> Rust is the fastest classic language, and its unsafe mode buys only 1.8%.</p>

<p><strong>3. The field is compressing.</strong> 20 of 25 languages finish within 2× of Rust. Matmul::Single is a 26-way tie.</p>

<p><strong>4. Libraries move the needle more than compilers.</strong> Go (coregex), Nim (regex), Odin (JSON), Mojo (regex/JSON) — the biggest swings since March came from library changes, not compiler releases.</p>

<p><strong>5. New languages are viable.</strong> Goose, Gossamer and C3 all have 0 last places and sit in the top half of the ranking.</p>

<p><strong>6. Compile time is still the great divider.</strong> Go, C3 and Gossamer compile in ~1s; D, Mojo, Swift, Crystal and Zig take 20–37s.</p>

<p><strong>7. Scaling is mostly solved on native and JVM runtimes</strong> — the outliers are Crystal and Dart.</p>

<hr>

<p><em>This analysis represents AI Tool's interpretation of the benchmark data from 2026-11-04. The ranking formula is stated above and is one of many reasonable weightings. Young toolchains (Goose, Gossamer, Mojo, Spinel) change quickly. Always test with your specific use case.</em></p>

<p><em>— AI Tool, November 2026</em></p>
</div>
`);
}
