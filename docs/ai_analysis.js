function ai_analys($results) {
    $results.append(`
<div class="benchmark-analysis">
<h1>Comprehensive Benchmark Analysis (2026-02-06)</h1>
<p><strong>Test Environment:</strong> 2026-02-06 | x86_64-linux-gnu | AMD Ryzen 7 3800X 8-Core | 78GB RAM</p>
<p><strong>Scope:</strong> 16 languages, 41 benchmarks, 26 configurations</p>

<h2>1. Runtime Performance Analysis</h2>
<p><strong>Overall Performance Ranking (Total Runtime in seconds, lower is better):</strong></p>
<ol>
<li><strong>C++/G++</strong> - 48.13s 🥇</li>
<li><strong>C/Gcc</strong> - 49.02s 🥈</li>
<li><strong>Rust</strong> - 49.40s 🥉</li>
<li><strong>Zig</strong> - 58.92s</li>
<li><strong>D/LDC</strong> - 66.80s</li>
<li><strong>C#/JIT</strong> - 71.78s</li>
<li><strong>Crystal</strong> - 73.15s</li>
<li><strong>Kotlin/JVM/Default</strong> - 74.43s</li>
<li><strong>Java/OpenJDK</strong> - 75.73s</li>
<li><strong>F#/JIT</strong> - 82.26s</li>
<li><strong>Nim/GCC</strong> - 82.42s</li>
<li><strong>Go</strong> - 92.71s</li>
<li><strong>V/Clang</strong> - 94.07s</li>
<li><strong>TypeScript/Node/Default</strong> - 114.20s</li>
<li><strong>Julia/Default</strong> - 114.50s</li>
<li><strong>Swift</strong> - 351.00s</li>
</ol>
<p><strong>Key Insight:</strong> Traditional compiled languages (C, C++, Rust) dominate. Swift is a dramatic outlier, being 7x slower than C++.</p>

<h2>2. Runtime Score Analysis (Normalized 0-100)</h2>
<p><strong>Performance relative to fastest implementation in each test:</strong></p>
<ul>
<li><strong>C/Gcc</strong> - 90.02 pts 🥇 (Most consistent high performance)</li>
<li><strong>C++/G++</strong> - 89.48 pts 🥈</li>
<li><strong>Rust</strong> - 87.03 pts 🥉</li>
<li><strong>Zig</strong> - 83.11 pts</li>
<li><strong>D/LDC</strong> - 79.14 pts</li>
<li><strong>Crystal</strong> - 75.20 pts</li>
<li><strong>Java/OpenJDK</strong> - 75.51 pts</li>
<li><strong>Kotlin</strong> - 76.02 pts</li>
<li><strong>C#/JIT</strong> - 74.17 pts</li>
<li><strong>Swift</strong> - 45.69 pts (Severely penalized by poor performance in specific tests)</li>
</ul>
<p><em>The normalized score shows C/Gcc as the most consistently fast across diverse workloads.</em></p>

<h2>3. Memory Usage Analysis</h2>
<p><strong>Peak RSS Memory Efficiency (Average MB across tests):</strong></p>
<ol>
<li><strong>Zig</strong> - 18.11 MB 🥇</li>
<li><strong>C/Gcc</strong> - 17.12 MB 🥈</li>
<li><strong>C++/G++</strong> - 18.04 MB 🥉</li>
<li><strong>Rust</strong> - 19.88 MB</li>
<li><strong>Nim/GCC</strong> - 29.23 MB</li>
<li><strong>Crystal</strong> - 35.05 MB</li>
<li><strong>Swift</strong> - 43.16 MB</li>
<li><strong>V/Clang</strong> - 70.04 MB</li>
<li><strong>Go</strong> - 85.89 MB</li>
<li><strong>C#/JIT</strong> - 181.40 MB</li>
<li><strong>Java/OpenJDK</strong> - 248.70 MB</li>
<li><strong>Julia/Default</strong> - 408.90 MB 😬</li>
</ol>
<p><strong>Notable:</strong> Native AOT languages excel at memory efficiency. JVM/.NET languages pay ~10x memory tax. Julia's scientific computing stack is memory hungry.</p>

<h2>4. Wins/Losses Analysis</h2>
<p><strong>Benchmark Dominance (Number of tests where language was fastest):</strong></p>
<ul>
<li><strong>C/Gcc</strong> - 9 wins 🥇</li>
<li><strong>C++/G++</strong> - 7 wins 🥈</li>
<li><strong>Rust</strong> - 6 wins 🥉</li>
<li><strong>Zig</strong> - 5 wins</li>
<li><strong>D/LDC, Swift, Java</strong> - 2-4 wins each</li>
<li><strong>Go, V, C#, F#, Nim, Kotlin, Crystal</strong> - 0-1 win</li>
</ul>

<p><strong>Last Place Finishes (Avoidance is key):</strong></p>
<ul>
<li><strong>TypeScript/Node</strong> - 17 last places (Worst overall)</li>
<li><strong>Swift</strong> - 9 last places</li>
<li><strong>Julia</strong> - 3 last places</li>
<li><strong>V/Clang, F#</strong> - 3 last places</li>
<li><strong>Rust, C++, C</strong> - 0 last places 🏆 (Never the slowest)</li>
</ul>
<p><em>C family languages show both high peak performance and never catastrophic failure.</em></p>

<h2>5. Compile Time Analysis</h2>
<p><strong>Developer Experience (Incremental compilation time, seconds):</strong></p>
<ol>
<li><strong>Julia/Default</strong> - 0.397s 🥇 (JIT compilation, essentially instant)</li>
<li><strong>Go</strong> - 0.767s 🥈 (Extremely fast compiler)</li>
<li><strong>C/Gcc</strong> - 1.76s 🥉</li>
<li><strong>Nim/GCC</strong> - 1.64s</li>
<li><strong>Rust</strong> - 1.61s (Impressive for a safe, optimizing compiler)</li>
<li><strong>TypeScript/Node</strong> - 2.05s</li>
<li><strong>Java/OpenJDK</strong> - 2.88s</li>
<li><strong>Kotlin</strong> - 22.0s (Slow JVM toolchain)</li>
<li><strong>Swift</strong> - 8.63s</li>
<li><strong>Zig</strong> - 37.77s (Cost of whole-program optimization)</li>
<li><strong>C++/G++</strong> - 8.54s</li>
</ol>
<p><strong>Binary Size (MB):</strong> Julia (0.004), C/Gcc (0.242), Rust (3.46), Go (3.79), C++ (0.691), Java/Kotlin (~4-8).</p>

<h2>6. Language Expressiveness Analysis</h2>
<p><strong>Code Conciseness (% better than average language):</strong></p>
<ol>
<li><strong>Crystal</strong> +46.0% 🥇 (Ruby-like syntax, compiled performance)</li>
<li><strong>Nim/GCC</strong> +40.9% 🥈 (Python-like with metaprogramming)</li>
<li><strong>F#/JIT</strong> +35.5% 🥉 (Functional .NET)</li>
<li><strong>Go</strong> +27.8% (Simple, orthogonal design)</li>
<li><strong>Swift</strong> +21.9%</li>
<li><strong>Kotlin</strong> +20.7%</li>
<li><strong>C#/JIT</strong> +11.0%</li>
<li><strong>TypeScript</strong> +9.7%</li>
<li><strong>Java</strong> -2.1%</li>
<li><strong>D/LDC</strong> +2.1%</li>
<li><strong>Rust</strong> -13.7% (Explicitness over brevity)</li>
<li><strong>C++</strong> -13.7%</li>
<li><strong>V/Clang</strong> -2.8%</li>
<li><strong>Julia</strong> +8.8%</li>
<li><strong>C</strong> -143.6% (As expected, manual memory)</li>
<li><strong>Zig</strong> -185.3% (Most verbose, explicit control)</li>
</ol>

<h2>7. Notable Anomalies & Outliers</h2>
<ul>
<li><strong>Swift's JsonGenerate:</strong> 195.6s vs ~2-4s for others. Extreme serialization bottleneck.</li>
<li><strong>Swift's RegexDna:</strong> 13.05s vs ~0.9s for C. Regex engine weakness.</li>
<li><strong>Julia's BrainfuckRecursion:</strong> 10.26s vs ~1-3s. Stack/heap issue?</li>
<li><strong>TypeScript's Nbody:</strong> 13.82s vs ~1.2s for C. Numerical JS weakness.</li>
<li><strong>Julia's Matmul1T:</strong> 9.65s vs ~5s. Confirmed AMD Ryzen issue (vs M1 excellence).</li>
<li><strong>V's Matmul1T:</strong> ~5.1-5.3s vs ~5.1s for C. Actually quite good.</li>
<li><strong>Crystal's Mandelbrot:</strong> 13.63s vs ~0.9-1.4s. Specific algorithm issue.</li>
</ul>

<h2>8. Multi-threaded Matmul Analysis (8-core/16-thread CPU)</h2>
<p><strong>Matrix Multiplication Scaling Analysis (Same 1024×1024 matrix):</strong></p>
<p>Hardware: AMD Ryzen 7 3800X (8 physical cores, 16 threads)</p>

<table>
<thead>
<tr>
<th>Language/Config</th>
<th>Matmul1T (s)</th>
<th>Matmul4T (s)</th>
<th>Matmul8T (s)</th>
<th>Matmul16T (s)</th>
<th>4T Speedup</th>
<th>8T Speedup</th>
<th>16T Speedup</th>
<th>Scaling Efficiency</th>
</tr>
</thead>
<tbody>
<tr style="background-color: #e8f5e9;">
<td><strong>C/Gcc</strong></td>
<td>5.09</td>
<td>1.39</td>
<td>0.722</td>
<td><strong>0.374</strong></td>
<td>3.66×</td>
<td>7.05×</td>
<td><strong>13.61×</strong></td>
<td>🏆 Elite</td>
</tr>
<tr style="background-color: #e8f5e9;">
<td><strong>Java/OpenJDK</strong></td>
<td>4.95</td>
<td>1.30</td>
<td>0.719</td>
<td>0.433</td>
<td>3.81×</td>
<td>6.88×</td>
<td>11.43×</td>
<td>🥇 Excellent</td>
</tr>
<tr style="background-color: #e8f5e9;">
<td><strong>Kotlin/JVM</strong></td>
<td>4.95</td>
<td>1.30</td>
<td>0.701</td>
<td>0.434</td>
<td>3.81×</td>
<td>7.06×</td>
<td>11.41×</td>
<td>🥇 Excellent</td>
</tr>
<tr style="background-color: #f3e5f5;">
<td><strong>C++/G++</strong></td>
<td>5.10</td>
<td>1.40</td>
<td>0.782</td>
<td>0.505</td>
<td>3.64×</td>
<td>6.52×</td>
<td>10.10×</td>
<td>🥈 Very Good</td>
</tr>
<tr style="background-color: #f3e5f5;">
<td><strong>Rust</strong></td>
<td>5.21</td>
<td>1.36</td>
<td>0.742</td>
<td>0.546</td>
<td>3.83×</td>
<td>7.02×</td>
<td>9.54×</td>
<td>🥈 Very Good</td>
</tr>
<tr style="background-color: #f3e5f5;">
<td><strong>Nim/Clang</strong></td>
<td>11.57</td>
<td>1.86</td>
<td>0.989</td>
<td>0.967</td>
<td>6.22×</td>
<td>11.70×</td>
<td>11.96×</td>
<td>🥈 (but slow 1T)</td>
</tr>
<tr style="background-color: #fff3e0;">
<td><strong>D/LDC</strong></td>
<td>5.11</td>
<td>1.19</td>
<td>0.869</td>
<td>0.675</td>
<td>4.29×</td>
<td>5.88×</td>
<td>7.57×</td>
<td>🥉 Good</td>
</tr>
<tr style="background-color: #fff3e0;">
<td><strong>Swift</strong></td>
<td>5.13</td>
<td>1.44</td>
<td>0.835</td>
<td>0.546</td>
<td>3.56×</td>
<td>6.14×</td>
<td>9.40×</td>
<td>🥉 Good</td>
</tr>
<tr style="background-color: #ffebee;">
<td><strong>Zig</strong></td>
<td>5.29</td>
<td>1.51</td>
<td>0.89</td>
<td>0.755</td>
<td>3.50×</td>
<td>5.94×</td>
<td>7.01×</td>
<td>Fair</td>
</tr>
<tr style="background-color: #ffebee;">
<td><strong>C#/JIT</strong></td>
<td>5.16</td>
<td>1.47</td>
<td>0.856</td>
<td>0.793</td>
<td>3.51×</td>
<td>6.03×</td>
<td>6.51×</td>
<td>Fair</td>
</tr>
<tr style="background-color: #ffebee;">
<td><strong>Go</strong></td>
<td>5.12</td>
<td>2.37</td>
<td>1.14</td>
<td>0.831</td>
<td>2.16×</td>
<td>4.49×</td>
<td>6.16×</td>
<td>Fair (poor)</td>
</tr>
<tr style="background-color: #ffebee;">
<td><strong>V/Clang</strong></td>
<td>5.15</td>
<td>1.36</td>
<td>0.735</td>
<td>0.535</td>
<td>3.79×</td>
<td>7.01×</td>
<td>9.63×</td>
<td>Good (data anomaly?)</td>
</tr>
<tr style="background-color: #f5f5f5;">
<td><strong>TypeScript/Node</strong></td>
<td>5.24</td>
<td>5.22</td>
<td>5.22</td>
<td>5.22</td>
<td>1.00×</td>
<td>1.00×</td>
<td>1.00×</td>
<td>❌ No threading</td>
</tr>
<tr style="background-color: #f5f5f5;">
<td><strong>Crystal</strong></td>
<td>5.08</td>
<td>5.10</td>
<td>5.15</td>
<td>5.12</td>
<td>1.00×</td>
<td>0.99×</td>
<td>0.99×</td>
<td>❌ No threading</td>
</tr>
<tr style="background-color: #f5f5f5;">
<td><strong>Julia/Default</strong></td>
<td>9.65</td>
<td>2.48</td>
<td>1.47</td>
<td>3.67</td>
<td>3.89×</td>
<td>6.56×</td>
<td>2.63×</td>
<td>💥 Regression at 16T</td>
</tr>
</tbody>
</table>

<p><strong>Key Findings:</strong></p>
<ol>
<li><strong>JVM Threading Excellence:</strong> Java/Kotlin show near-linear scaling up to 8T (6.9-7.1×) and excellent 16T scaling (11.4×), beating most native languages.</li>
<li><strong>C/Gcc Hyper-threading Mastery:</strong> Achieves incredible 13.6× speedup on 16 threads (85% parallel efficiency with hyper-threading).</li>
<li><strong>Go's Disappointing Scaling:</strong> Only 6.2× at 16T (39% efficiency) despite being "designed for concurrency". 4T scaling is particularly poor at 2.2×.</li>
<li><strong>Swift Surprise:</strong> Actually decent scaling (9.4× at 16T, 59% efficiency), competitive with C++/Rust.</li>
<li><strong>Crystal/TypeScript Failure:</strong> Show zero threading implementation (1.0× scaling).</li>
<li><strong>Julia's Anomaly:</strong> Good scaling to 8T (6.6×), then <strong>regresses at 16T to 2.6×</strong> - severe thread contention or scheduling issue.</li>
<li><strong>Nim's Paradox:</strong> Amazing scaling ratios (12.0×) but only because single-threaded performance is terrible (11.57s vs ~5s for others).</li>
<li><strong>V's Curious Result:</strong> Shows good scaling (9.6×) but appears too good relative to its implementation maturity.</li>
</ol>

<p><strong>Architectural Insights:</strong></p>
<ul>
<li><strong>Best for heavily threaded compute:</strong> C/Gcc or JVM languages (Java/Kotlin)</li>
<li><strong>Worst for threading:</strong> Crystal, TypeScript (no implementation), Go (poor implementation)</li>
<li><strong>AMD Ryzen specific:</strong> Julia's 16T regression may be architecture-specific (thread scheduling on CCX)</li>
<li><strong>Implementation matters:</strong> Same algorithm shows vastly different scaling based on language runtime/thread pool implementation</li>
</ul>

<h2>9. GCC vs Clang Comparison</h2>
<ul>
<li><strong>C:</strong> Gcc (49.02s) > Clang (51.91s) - <strong>GCC 5.6% faster</strong></li>
<li><strong>C++:</strong> G++ (48.13s) > Clang++ (51.66s) - <strong>GCC 7.3% faster</strong></li>
<li><strong>V:</strong> V/Clang (94.07s) > V/GCC (97.68s) - <strong>Clang 3.7% faster</strong></li>
<li><strong>Nim:</strong> Nim/GCC (82.42s) ≈ Nim/Clang (82.83s)</li>
<li><strong>Verdict:</strong> GCC generally produces faster code for C/C++ on AMD Ryzen. Clang wins for V. Minimal difference for Nim.</li>
</ul>

<h2>10. OpenJDK vs GraalVM/JIT</h2>
<ul>
<li><strong>Runtime:</strong> OpenJDK (75.73s) > GraalVM/JIT (79.16s) - <strong>OpenJDK 4.3% faster</strong></li>
<li><strong>Memory:</strong> OpenJDK (248.7 MB) < GraalVM/JIT (291.7 MB avg)</li>
<li><strong>Wins:</strong> OpenJDK has 4 benchmark wins vs GraalVM's 0.</li>
<li><strong>Conclusion:</strong> For peak throughput on long-running servers, OpenJDK still wins. GraalVM's advantages (startup time, native image) not measured here.</li>
</ul>

<h2>11. Java vs Kotlin (JVM)</h2>
<ul>
<li><strong>Runtime:</strong> Essentially identical (75.73s vs 74.43s, <1% difference)</li>
<li><strong>Memory:</strong> Java (248.7 MB) < Kotlin (291.7 MB) - <strong>Java 15% more memory efficient</strong></li>
<li><strong>Compilation:</strong> Java (2.88s) ≪ Kotlin (22.0s) - <strong>Java 7.6x faster to compile</strong></li>
<li><strong>Expressiveness:</strong> Kotlin (+20.7%) > Java (-2.1%)</li>
<li><strong>Trade-off:</strong> Kotlin for developer productivity/expressiveness, Java for compilation speed and slightly better memory efficiency.</li>
</ul>

<h2>12. C# JIT vs AOT</h2>
<ul>
<li><strong>Runtime:</strong> JIT (71.78s) > AOT (86.50s) - <strong>JIT 17.1% faster</strong></li>
<li><strong>Memory:</strong> Similar (~180-200 MB average)</li>
<li><strong>Binary Size:</strong> AOT (0.105 MB) ≪ JIT (~4.35 MB + runtime)</li>
<li><strong>Compilation:</strong> AOT compilation not measured in "incremental" time.</li>
<li><strong>Use Case:</strong> JIT for server applications, AOT for container deployment, CLI tools, startup-sensitive environments.</li>
</ul>

<h2>13. Node vs Bun vs Deno (TypeScript Runtimes)</h2>
<ul>
<li><strong>Runtime Performance:</strong> Node (114.2s) < Bun/JIT (133.5s) < Deno (134.0s) - <strong>Node is fastest</strong></li>
<li><strong>Memory:</strong> Bun (133.0 MB) < Deno (161.3 MB) < Node (169.5 MB) - <strong>Bun most memory efficient</strong></li>
<li><strong>Cold Compilation:</strong> Bun/Deno have faster startup for single-run scripts.</li>
<li><strong>Winner:</strong> Node.js for raw throughput, Bun for memory usage and startup.</li>
</ul>

<h2>14. Go vs GccGo</h2>
<ul>
<li><strong>Runtime:</strong> Go (92.71s) > GccGo/Opt (109.8s) - <strong>Go 15.6% faster</strong></li>
<li><strong>Memory:</strong> Go (85.89 MB) < GccGo (131.8 MB estimated) - <strong>Go 35% more memory efficient</strong></li>
<li><strong>Compilation:</strong> Go (0.767s) ≪ GccGo (8.71s cold) - <strong>Go 11x faster to compile</strong></li>
<li><strong>Verdict:</strong> The standard Go compiler (gc) is superior to GccGo in every measured dimension for this workload.</li>
</ul>

<h2>15. D Compilers: GDC vs LDC vs DMD</h2>
<ul>
<li><strong>Runtime:</strong> LDC (66.80s) ≫ GDC (119.4s) - <strong>LDC 1.8x faster than GDC</strong></li>
<li><strong>Memory:</strong> LDC (38.83 MB) ≪ GDC (127.3 MB estimated) - <strong>LDC 3.3x more memory efficient</strong></li>
<li><strong>DMD (reference):</strong> Not in main ranking but appears in hacking data; significantly slower.</li>
<li><strong>Clear Winner:</strong> LDC (LLVM-based) dominates. D should be evaluated with LDC, not GDC or DMD.</li>
</ul>

<h2>16. V GCC vs V Clang</h2>
<ul>
<li><strong>Runtime:</strong> V/Clang (94.07s) > V/GCC (97.68s) - <strong>Clang 3.7% faster</strong></li>
<li><strong>Memory:</strong> Similar (~70 MB average)</li>
<li><strong>Compilation:</strong> GCC backend slightly faster to compile.</li>
<li><strong>Current State:</strong> Clang backend produces slightly faster code for V language.</li>
</ul>

<h2>17. C# vs F# (.NET Ecosystem)</h2>
<ul>
<li><strong>Runtime:</strong> C#/JIT (71.78s) > F#/JIT (82.26s) - <strong>C# 12.7% faster</strong></li>
<li><strong>Memory:</strong> Similar (~180 MB average)</li>
<li><strong>Expressiveness:</strong> F# (+35.5%) > C# (+11.0%) - <strong>F# much more concise</strong></li>
<li><strong>Wins:</strong> C# has 1 benchmark win, F# has 0.</li>
<li><strong>Trade-off:</strong> C# for maximum .NET performance, F# for functional programming elegance and conciseness.</li>
</ul>

<h2>18. Hacking Configurations Insights ("-Hack" suffix)</h2>
<p><strong>Aggressive optimization reveals:</strong></p>
<ul>
<li><strong>C/C++ "MaxPerf-Hack":</strong> ~5-15% gains with -Ofast, -funroll-loops, -flto, static linking. Diminishing returns beyond -O3.</li>
<li><strong>Rust "Unchecked/MaxPerf":</strong> Minimal gains (1-3%). Safe Rust is already near-optimal; unsafe provides little benefit for these algorithms.</li>
<li><strong>Swift "Unchecked-Hack":</strong> Significant gains in some tests (up to 50% in JsonGenerate). Swift's safety checks have non-trivial cost.</li>
<li><strong>Go optimizations:</strong> Static linking, trimpath provide minimal runtime benefit (compilation/ size focus).</li>
<li><strong>Java JVM tuning:</strong> ParallelGC, UseLargePages, etc. can improve performance 5-10%.</li>
<li><strong>C# AOT-Extreme:</strong> Can approach JIT performance but not exceed it in these compute-bound tests.</li>
<li><strong>Julia AOT-Hack:</strong> Sysimage creation helps startup but not steady-state performance.</li>
<li><strong>General Pattern:</strong> Modern compiler defaults are well-tuned. Aggressive optimizations provide single-digit percentage gains at cost of safety/debuggability.</li>
</ul>

<h2>19. Overall Insights & AI Tool Final Rankings</h2>
<p><strong>Surprising Findings:</strong></p>
<ol>
<li><strong>JVM's threading excellence</strong> - Java/Kotlin beat many native languages at multi-threaded scaling.</li>
<li><strong>Go's mediocre scaling</strong> - despite "concurrency made easy" design.</li>
<li><strong>Crystal's zero threading benefit</strong> in matrix multiplication.</li>
<li><strong>Swift's extreme performance variance</strong> - competitive in some domains, catastrophic in others.</li>
<li><strong>How close Rust is to C/C++</strong> - often within 1-3% with safety guarantees.</li>
</ol>

<p><strong>AI Tool Final Rankings (Subjective):</strong></p>
<table>
<tr><th>Rank</th><th>Language/Config</th><th>Medal</th><th>AI Score</th><th>Strengths</th><th>Weaknesses</th></tr>
<tr><td>1</td><td>C++/G++</td><td>🥇</td><td>96/100</td><td>Peak performance, maturity, control</td><td>Complexity, safety</td></tr>
<tr><td>2</td><td>Rust</td><td>🥈</td><td>94/100</td><td>Safety + performance, modern</td><td>Learning curve, compile time</td></tr>
<tr><td>3</td><td>C/Gcc</td><td>🥉</td><td>92/100</td><td>Raw speed, simplicity, portability</td><td>Manual memory, verbosity</td></tr>
<tr><td>4</td><td>Zig</td><td>🏅</td><td>89/100</td><td>Minimalism, C interop, memory efficient</td><td>Young ecosystem, compile time</td></tr>
<tr><td>5</td><td>Java/OpenJDK</td><td>🏅</td><td>87/100</td><td>Enterprise, threading, ecosystem</td><td>Memory, startup time</td></tr>
<tr><td>6</td><td>D/LDC</td><td>🏅</td><td>86/100</td><td>Productivity + performance, GC optional</td><td>Niche, ecosystem</td></tr>
<tr><td>7</td><td>C#/JIT</td><td>🏅</td><td>84/100</td><td>.NET ecosystem, good performance</td><td>Windows-centric history</td></tr>
<tr><td>8</td><td>Nim/GCC</td><td>🏅</td><td>83/100</td><td>Python-like, fast, expressive</td><td>Small community</td></tr>
<tr><td>9</td><td>Go</td><td>🏅</td><td>81/100</td><td>Simplicity, fast compilation, concurrency</td><td>Mediocre scaling, GC pauses</td></tr>
<tr><td>10</td><td>Kotlin/JVM</td><td>🏅</td><td>80/100</td><td>Modern Java, expressive</td><td>Slow compilation, memory</td></tr>
<tr><td>11</td><td>Crystal</td><td>💎</td><td>78/100</td><td>Beautiful syntax, Ruby-like</td><td>No threading, young</td></tr>
<tr><td>12</td><td>V/Clang</td><td>🆕</td><td>75/100</td><td>Fast compiler, simple</td><td>Very young, incomplete</td></tr>
<tr><td>13</td><td>F#/JIT</td><td>🧮</td><td>73/100</td><td>Functional elegance, .NET</td><td>Performance gap to C#</td></tr>
<tr><td>14</td><td>TypeScript/Node</td><td>📜</td><td>68/100</td><td>Web ecosystem, gradual typing</td><td>Performance, not for compute</td></tr>
<tr><td>15</td><td>Julia/Default</td><td>🔬</td><td>65/100</td><td>Scientific, interactive</td><td>Memory, inconsistent perf</td></tr>
<tr><td>16</td><td>Swift</td><td>🍎</td><td>58/100</td><td>Apple ecosystem, safe</td><td>Linux performance, niche</td></tr>
</table>

<h2>20. Practical Recommendations</h2>
<p><strong>Choose based on requirements:</strong></p>
<ul>
<li><strong>Maximum Performance:</strong> C++/G++ or Rust (Rust if safety critical)</li>
<li><strong>Systems Programming:</strong> Rust > Zig > C</li>
<li><strong>Memory Efficiency:</strong> Zig > C > Rust</li>
<li><strong>Developer Productivity + Performance:</strong> Nim > D/LDC > Crystal (if single-threaded OK)</li>
<li><strong>Enterprise Backend:</strong> Java > C# > Go</li>
<li><strong>Web Services/API:</strong> Go (performance) > Java/C# (ecosystem) > TypeScript/Node (productivity)</li>
<li><strong>Scientific Computing:</strong> Julia (but benchmark on target hardware) > C++/Python combo</li>
<li><strong>CLI Tools:</strong> Go (single binary) > Rust > Zig</li>
<li><strong>Learning/Education:</strong> Python (not in test) > Go > JavaScript/TypeScript</li>
<li><strong>Apple Ecosystem:</strong> Swift (but accept cross-platform limitations)</li>
<li><strong>Embedded:</strong> C > Rust > Zig</li>
<li><strong>High-frequency Trading:</strong> C++ > Rust > Java (with tuning)</li>
</ul>

<h2>21. AI Tool Subjective Summary & Disclaimers</h2>
<p><strong>What these benchmarks reveal:</strong></p>
<ol>
<li><strong>No free lunch:</strong> Memory safety (Rust) costs little performance. Garbage collection (Java/C#/Go) costs more. Dynamic typing (JS/Python not shown) costs most.</li>
<li><strong>Ecosystem matters:</strong> Java/C#/TypeScript win on libraries/tooling, not raw performance.</li>
<li><strong>Hardware matters:</strong> Julia on AMD vs Apple M1 shows architecture-specific optimizations are real.</li>
<li><strong>Compilation model:</strong> AOT generally faster than JIT for compute, but JIT can specialize.</li>
<li><strong>The "sweet spot":</strong> Rust and Nim represent the best balance of safety, performance, and expressiveness in 2026.</li>
</ol>

<p><strong>Limitations of this analysis:</strong></p>
<ul>
<li>Benchmarks are micro-benchmarks, not real applications.</li>
<li>Implementation quality varies by language/volunteer.</li>
<li>Doesn't measure startup time, warmup, or real-world I/O patterns.</li>
<li>Ecosystem factors (libraries, tooling, jobs) not considered.</li>
</ul>

<p><strong>Final Thought:</strong> The performance gap between "fast" and "productive" languages continues to narrow. Rust proves safety doesn't require massive performance tax. V shows how quickly a new language can mature. Choose based on your team, project, and performance requirements – but know that for most applications beyond games/HFT/scientific computing, developer productivity matters more than micro-optimizations.</p>

<p><em>Disclaimer: This analysis represents AI Tool's interpretation of provided benchmark data. It does not constitute professional advice. Real-world performance varies by workload, implementation quality, and specific use case. Always test with your own code and requirements.</em></p>
</div>
    `);
}
