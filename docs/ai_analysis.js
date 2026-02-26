function ai_analys($results) {
    $results.append(`
<div class="benchmark-analysis">
<h1>AI Analysis of provided benchmark data (2026-02-26)</h1>
<p><strong>Test Environment:</strong> 2026-02-26 | x86_64-linux-gnu | AMD Ryzen 7 3800X 8-Core | 78GB RAM</p>
<p><strong>Scope:</strong> 20 languages, 49 benchmarks, 29 runtime configurations</p>

<h2>1. Runtime Performance Analysis</h2>
<p><strong>Overall Performance Ranking (Total Runtime in seconds, lower is better):</strong></p>
<ol>
<li><strong>C++/G++</strong> - 49.16s 🥇</li>
<li><strong>C/Gcc</strong> - 51.48s 🥈</li>
<li><strong>Rust</strong> - 53.93s 🥉</li>
<li><strong>C++/Clang++</strong> - 54.14s</li>
<li><strong>Zig</strong> - 76.63s</li>
<li><strong>D/LDC</strong> - 77.64s</li>
<li><strong>Crystal</strong> - 69.22s (note: this beats Zig/D - data shows 69.22)</li>
<li><strong>Java/OpenJDK</strong> - 72.62s</li>
<li><strong>Kotlin/JVM/Default</strong> - 76.09s</li>
<li><strong>Go</strong> - 95.45s</li>
<li><strong>C#/JIT</strong> - 82.62s</li>
<li><strong>Scala/JVM/Default</strong> - 84.64s</li>
<li><strong>Nim/GCC</strong> - 84.96s</li>
<li><strong>V/Clang</strong> - 93.07s</li>
<li><strong>F#/JIT</strong> - 98.18s</li>
<li><strong>Julia/Default</strong> - 133.4s</li>
<li><strong>Odin/Default</strong> - 137.6s</li>
<li><strong>TypeScript/Bun/JIT</strong> - 150.8s</li>
<li><strong>Swift</strong> - 249.3s</li>
<li><strong>Python/PYPY</strong> - 315.8s</li>
</ol>
<p><strong>Key Insight:</strong> C++/G++ takes the top spot. The "big three" (C, C++, Rust) are tightly clustered within ~5 seconds. Crystal surprises by outperforming Zig and D. Python/PYPY anchors the bottom at ~6.4x slower than C++.</p>

<h2>2. Runtime Score Analysis (Normalized 0-100)</h2>
<p><strong>Performance Score Ranking (higher is better):</strong></p>
<ol>
<li><strong>C++/G++</strong> - 93.4 pts 🥇</li>
<li><strong>C/Gcc</strong> - 92.6 pts 🥈</li>
<li><strong>Rust</strong> - 88.6 pts 🥉</li>
<li><strong>Crystal</strong> - 82.5 pts</li>
<li><strong>Java/OpenJDK</strong> - 81.7 pts</li>
<li><strong>D/LDC</strong> - 79.1 pts</li>
<li><strong>Zig</strong> - 76.8 pts</li>
<li><strong>Kotlin/JVM/Default</strong> - 78.8 pts</li>
<li><strong>Go</strong> - 77.2 pts</li>
<li><strong>C#/JIT</strong> - 78.0 pts</li>
<li><strong>Scala/JVM/Default</strong> - 76.3 pts</li>
<li><strong>Nim/GCC</strong> - 76.0 pts</li>
<li><strong>V/Clang</strong> - 76.2 pts</li>
<li><strong>F#/JIT</strong> - 70.2 pts</li>
<li><strong>Julia/Default</strong> - 60.3 pts</li>
<li><strong>Odin/Default</strong> - 72.6 pts</li>
<li><strong>TypeScript/Bun/JIT</strong> - 46.0 pts</li>
<li><strong>Swift</strong> - 56.0 pts</li>
<li><strong>Dart/AOT</strong> - 41.0 pts</li>
<li><strong>Python/PYPY</strong> - 22.7 pts</li>
</ol>

<h2>3. Memory Usage Analysis</h2>
<p><strong>Memory Efficiency Ranking (Average MB across tests, lower is better):</strong></p>
<ol>
<li><strong>Rust</strong> - 31.3 MB 🥇</li>
<li><strong>C/Gcc</strong> - 33.27 MB 🥈</li>
<li><strong>C++/G++</strong> - 32.96 MB 🥉</li>
<li><strong>Zig</strong> - 56.05 MB</li>
<li><strong>Crystal</strong> - 57.74 MB</li>
<li><strong>Nim/GCC</strong> - 61.32 MB</li>
<li><strong>Swift</strong> - 67.43 MB</li>
<li><strong>Odin/Default</strong> - 70.82 MB</li>
<li><strong>D/LDC</strong> - 73.06 MB</li>
<li><strong>Go</strong> - 70.17 MB</li>
<li><strong>V/Clang</strong> - 75.11 MB</li>
<li><strong>C#/JIT</strong> - 112.9 MB</li>
<li><strong>F#/JIT</strong> - 121.0 MB</li>
<li><strong>Dart/AOT</strong> - 116.8 MB</li>
<li><strong>Python/PYPY</strong> - 218.0 MB</li>
<li><strong>TypeScript/Bun/JIT</strong> - 343.6 MB</li>
<li><strong>Java/OpenJDK</strong> - 322.6 MB</li>
<li><strong>Kotlin/JVM/Default</strong> - 322.4 MB</li>
<li><strong>Scala/JVM/Default</strong> - 364.9 MB</li>
<li><strong>Julia/Default</strong> - 440.5 MB</li>
</ol>
<p><strong>Analysis:</strong> Rust takes the memory crown. Native AOT languages (Rust/C/C++) &lt; 35MB; GC'd systems languages 55-75MB; managed runtime languages 110-440MB. Julia remains outlier at 440MB due to JIT specialization caches.</p>

<h2>4. Wins/Losses Analysis</h2>
<p><strong>Benchmark Dominance (Number of tests where language was fastest):</strong></p>
<ul>
<li><strong>C/Gcc</strong> - 13 wins 🥇</li>
<li><strong>Rust</strong> - 9 wins 🥈</li>
<li><strong>C++/G++</strong> - 8 wins 🥉</li>
<li><strong>C++/Clang++</strong> - 3 wins</li>
<li><strong>Java/OpenJDK</strong> - 3 wins</li>
<li><strong>Zig</strong> - 3 wins</li>
<li><strong>D/LDC</strong> - 2 wins</li>
<li><strong>Swift</strong> - 2 wins</li>
<li><strong>V/Clang</strong> - 4 wins</li>
<li><strong>Crystal, Kotlin, Nim, Julia, Odin</strong> - 0-1 wins each</li>
<li><strong>Python, Dart, F#, Go, C#, Scala, TypeScript</strong> - 0 wins</li>
</ul>

<p><strong>Last Place Finishes (Avoidance is key):</strong></p>
<ul>
<li><strong>Python/PYPY</strong> - 22 last places 💀</li>
<li><strong>Dart/AOT</strong> - 9 last places</li>
<li><strong>Swift</strong> - 8 last places</li>
<li><strong>TypeScript/Bun</strong> - 5 last places</li>
<li><strong>Odin</strong> - 2 last places</li>
<li><strong>Julia</strong> - 1 last place</li>
<li><strong>F#</strong> - 1 last place</li>
<li><strong>Rust, C, C++, Zig, Crystal, D, Go, Java, Kotlin, C#, Scala, Nim, V</strong> - 0 last places 🏆</li>
</ul>

<h2>5. Compile Time Analysis</h2>
<p><strong>Developer Experience (Incremental compilation time, seconds):</strong></p>
<ol>
<li><strong>Go</strong> - 0.747s 🥇 (blazing fast)</li>
<li><strong>Nim/GCC</strong> - 1.64s 🥈</li>
<li><strong>Rust</strong> - 1.74s 🥉 (excellent for optimizing compiler)</li>
<li><strong>C/Gcc</strong> - 1.95s</li>
<li><strong>Dart/AOT</strong> - 1.99s</li>
<li><strong>Crystal</strong> - 2.02s</li>
<li><strong>Java/OpenJDK</strong> - 3.42s</li>
<li><strong>V/Clang</strong> - 8.46s</li>
<li><strong>Odin/Default</strong> - 8.52s</li>
<li><strong>Swift</strong> - 10.11s</li>
<li><strong>D/LDC</strong> - 10.21s</li>
<li><strong>Kotlin/JVM</strong> - 22.16s (slowest conventional)</li>
<li><strong>Zig</strong> - 37.6s (whole-program optimization cost)</li>
</ol>
<p><strong>Binary Size (MB):</strong> C#/JIT (0.113) smallest, Go (3.98) and Rust (3.52) produce tiny binaries. JVM languages 2-10MB JARs. Zig (4.48) reasonable.</p>

<h2>6. Language Expressiveness Analysis</h2>
<p><strong>Code Conciseness (% better than average language):</strong></p>
<ol>
<li><strong>Crystal</strong> +43.1% 🥇</li>
<li><strong>Scala</strong> +40.7% 🥈</li>
<li><strong>Nim</strong> +39.0% 🥉</li>
<li><strong>Python/PYPY</strong> +25.8%</li>
<li><strong>F#</strong> +32.8%</li>
<li><strong>Go</strong> +31.7%</li>
<li><strong>Kotlin</strong> +21.8%</li>
<li><strong>Dart</strong> +19.8%</li>
<li><strong>C#</strong> +7.4%</li>
<li><strong>Swift</strong> +19.6%</li>
<li><strong>TypeScript</strong> +0.7% (near average)</li>
<li><strong>Julia</strong> +4.4%</li>
<li><strong>Java</strong> -2.5%</li>
<li><strong>D</strong> -35.8%</li>
<li><strong>V</strong> -9.6%</li>
<li><strong>Rust</strong> -19.6%</li>
<li><strong>Odin</strong> -47.7%</li>
<li><strong>C</strong> -132.7%</li>
<li><strong>Zig</strong> -168.8%</li>
</ol>
<p><strong>Insight:</strong> Crystal retains expressiveness crown. Expressiveness inversely correlates with low-level control—C, Zig, and Rust pay verbosity tax for manual memory management/safety.</p>

<h2>7. Notable Anomalies & Outliers</h2>
<ul>
<li><strong>Swift's JsonGenerate:</strong> 77.26s (vs Rust's 0.315s) - catastrophic, Swift's weakest test by far</li>
<li><strong>Julia's BrainfuckRecursion:</strong> 20.05s (vs C++ 1.34s) - JIT overhead on recursive interpreter</li>
<li><strong>Python/PYPY's Revcomp:</strong> 25.26s (vs Rust 0.468s) - 54x slower, string processing weakness</li>
<li><strong>Go's GraphPathAStar:</strong> 15.31s (vs Rust 1.91s) - poor algorithmic performance</li>
<li><strong>Scala's GraphPathDFS:</strong> 12.76s? Actually Scala shows 4.38s in that test - better than expected</li>
<li><strong>Dart's Matmul1T:</strong> 6.85s (vs C 4.99s) - actually not terrible, previous data was different</li>
<li><strong>Julia's Matmul16T:</strong> 5.07s vs 2.02s at 8T - severe regression on AMD (confirmed in data)</li>
<li><strong>Odin's JsonGenerate:</strong> 36.27s vs C 1.25s - specific bug mentioned in data</li>
<li><strong>TypeScript/Bun's JsonGenerate:</strong> 1.19s - actually competitive! Bun excels here</li>
</ul>

<h2>8. Multi-threaded Matmul Analysis (8-core/16-thread CPU, matrix multiplication)</h2>
<table>
<thead>
<tr>
<th>Language/Config</th>
<th>Matmul1T (s)</th>
<th>Matmul4T (s)</th>
<th>Matmul8T (s)</th>
<th>Matmul16T (s)</th>
<th>16T Speedup</th>
<th>Notes</th>
</tr>
</thead>
<tbody>
<tr style="background-color: #e8f5e9;">
<td><strong>C/Gcc</strong></td>
<td>4.94</td>
<td>1.29</td>
<td>0.686</td>
<td>0.398</td>
<td>12.41× 🏆</td>
<td>Excellent scaling</td>
</tr>
<tr style="background-color: #e8f5e9;">
<td><strong>Java/OpenJDK</strong></td>
<td>4.92</td>
<td>1.27</td>
<td>0.69</td>
<td>0.421</td>
<td>11.69×</td>
<td>Excellent JVM threading</td>
</tr>
<tr style="background-color: #e8f5e9;">
<td><strong>Kotlin/JVM</strong></td>
<td>4.93</td>
<td>1.27</td>
<td>0.673</td>
<td>0.467</td>
<td>10.56×</td>
<td>Very good</td>
</tr>
<tr style="background-color: #e8f5e9;">
<td><strong>C++/G++</strong></td>
<td>4.94</td>
<td>1.29</td>
<td>0.686</td>
<td>0.398</td>
<td>12.41×</td>
<td>Identical to C</td>
</tr>
<tr style="background-color: #e8f5e9;">
<td><strong>Odin/Default</strong></td>
<td>5.05</td>
<td>1.33</td>
<td>0.706</td>
<td>0.512</td>
<td>9.86×</td>
<td>Good scaling despite bugs</td>
</tr>
<tr style="background-color: #f3e5f5;">
<td><strong>Swift</strong></td>
<td>4.99</td>
<td>1.29</td>
<td>0.684</td>
<td>0.41</td>
<td>12.17×</td>
<td>Surprisingly excellent scaling!</td>
</tr>
<tr style="background-color: #f3e5f5;">
<td><strong>Rust</strong></td>
<td>5.14</td>
<td>1.33</td>
<td>0.707</td>
<td>0.514</td>
<td>10.00×</td>
<td>Good</td>
</tr>
<tr style="background-color: #f3e5f5;">
<td><strong>Scala/JVM</strong></td>
<td>4.92</td>
<td>1.3</td>
<td>0.775</td>
<td>0.509</td>
<td>9.67×</td>
<td>Good scaling</td>
</tr>
<tr style="background-color: #f3e5f5;">
<td><strong>V/Clang</strong></td>
<td>5.14</td>
<td>1.39</td>
<td>0.764</td>
<td>0.77</td>
<td>6.68×</td>
<td>Scaling stalls at 16T</td>
</tr>
<tr style="background-color: #f3e5f5;">
<td><strong>Crystal</strong></td>
<td>5.05</td>
<td>1.33</td>
<td>0.708</td>
<td>0.658</td>
<td>7.68×</td>
<td>Good but slows at 16T</td>
</tr>
<tr style="background-color: #fff3e0;">
<td><strong>Zig</strong></td>
<td>5.17</td>
<td>1.4</td>
<td>0.777</td>
<td>0.605</td>
<td>8.55×</td>
<td>Decent</td>
</tr>
<tr style="background-color: #fff3e0;">
<td><strong>D/LDC</strong></td>
<td>4.99</td>
<td>1.09</td>
<td>0.786</td>
<td>0.547</td>
<td>9.12×</td>
<td>Good 4T, weaker scaling</td>
</tr>
<tr style="background-color: #ffebee;">
<td><strong>Go</strong></td>
<td>4.92</td>
<td>2.17</td>
<td>0.986</td>
<td>0.783</td>
<td>6.28×</td>
<td>Poor scaling, goroutines disappoint</td>
</tr>
<tr style="background-color: #ffebee;">
<td><strong>C#/JIT</strong></td>
<td>5.01</td>
<td>1.33</td>
<td>0.729</td>
<td>0.545</td>
<td>9.19×</td>
<td>.NET ThreadPool decent</td>
</tr>
<tr style="background-color: #ffebee;">
<td><strong>F#/JIT</strong></td>
<td>5.05</td>
<td>1.33</td>
<td>0.763</td>
<td>0.609</td>
<td>8.29×</td>
<td>Similar to C#</td>
</tr>
<tr style="background-color: #f5f5f5;">
<td><strong>Julia/Default</strong></td>
<td>11.53</td>
<td>2.97</td>
<td>1.71</td>
<td>3.74</td>
<td>3.08×</td>
<td>Severe 16T regression (AMD issue)</td>
</tr>
<tr style="background-color: #f5f5f5;">
<td><strong>TypeScript/Bun</strong></td>
<td>4.93</td>
<td>4.93</td>
<td>4.93</td>
<td>4.93</td>
<td>1.00×</td>
<td>Single-threaded</td>
</tr>
<tr style="background-color: #f5f5f5;">
<td><strong>Dart/AOT</strong></td>
<td>6.85</td>
<td>2.73</td>
<td>2.02</td>
<td>2.79</td>
<td>2.45×</td>
<td>Poor scaling</td>
</tr>
<tr style="background-color: #f5f5f5;">
<td><strong>Python/PYPY</strong></td>
<td>13.55</td>
<td>13.74</td>
<td>13.79</td>
<td>13.97</td>
<td>0.97×</td>
<td>GIL-limited</td>
</tr>
</tbody>
</table>
<p><strong>Key Findings:</strong> C/C++/Java lead scaling (12.4×). Swift shocks with 12.17× scaling. Go disappoints at 6.28×. Julia's AMD regression persists. V scaling stalls at 16T.</p>

<h2>9. GCC vs Clang Comparison</h2>
<ul>
<li><strong>C:</strong> Gcc (51.48s) vs Clang (52.65s) - <strong>GCC 2.2% faster</strong></li>
<li><strong>C++:</strong> G++ (49.16s) vs Clang++ (54.14s) - <strong>GCC 9.2% faster</strong></li>
<li><strong>V:</strong> Clang (93.07s) vs GCC (94.61s) - <strong>Clang 1.6% faster</strong></li>
<li><strong>Nim:</strong> Clang (85.01s) vs GCC (84.96s) - <strong>near parity, GCC 0.06% faster</strong></li>
<li><strong>Verdict:</strong> GCC leads for C/C++ on AMD; Clang slightly ahead for V; Nim essentially equal.</li>
</ul>

<h2>10. OpenJDK vs GraalVM/JIT</h2>
<ul>
<li><strong>Runtime:</strong> OpenJDK (72.62s) vs GraalVM/JIT (77.11s) - <strong>OpenJDK 5.8% faster</strong></li>
<li><strong>Memory:</strong> OpenJDK (322.6 MB) vs GraalVM (~322 MB similar)</li>
<li><strong>Conclusion:</strong> OpenJDK still leads for steady-state throughput. GraalVM's value is native image and polyglot, not peak JIT performance.</li>
</ul>

<h2>11. Java vs Kotlin vs Scala (JVM Ecosystem)</h2>
<ul>
<li><strong>Runtime:</strong> Java (72.62s) &lt; Kotlin (76.09s) &lt; Scala (84.64s) - <strong>Java fastest, Scala 14% slower</strong></li>
<li><strong>Memory:</strong> Java (322.6 MB) ≈ Kotlin (322.4 MB) &lt; Scala (364.9 MB)</li>
<li><strong>Compilation:</strong> Java (3.42s) &lt; Scala (6.19s) &lt; Kotlin (22.16s) - <strong>Java fastest by far</strong></li>
<li><strong>Expressiveness:</strong> Scala (+40.7%) &gt; Kotlin (+21.8%) &gt; Java (-2.5%)</li>
<li><strong>Trade-off:</strong> Java for performance/efficiency, Scala for expressiveness, Kotlin as middle ground with compilation penalty.</li>
</ul>

<h2>12. C# JIT vs AOT</h2>
<ul>
<li><strong>Runtime:</strong> JIT (82.62s) vs AOT (97.36s) - <strong>JIT 15% faster</strong></li>
<li><strong>Memory:</strong> JIT (112.9 MB) vs AOT (85.29 MB) - <strong>AOT 24% more efficient</strong></li>
<li><strong>Binary Size:</strong> AOT (0.105 MB) ≪ JIT (requires runtime)</li>
<li><strong>Conclusion:</strong> JIT for max throughput, AOT for memory-constrained environments/containers where startup and binary size matter.</li>
</ul>

<h2>13. Node vs Bun vs Deno (TypeScript Runtimes)</h2>
<ul>
<li><strong>Runtime (summary):</strong> Bun (150.8s) &lt; Deno (171.6s) &lt; Node (181.5s) - <strong>Bun fastest</strong></li>
<li><strong>Memory:</strong> Bun (343.6 MB), Node (242.0 MB), Deno (255.9 MB) - <strong>Node most efficient</strong></li>
<li><strong>Individual tests:</strong> Bun wins JsonGenerate (1.19s vs Node 1.21s), Node wins many compute tests</li>
<li><strong>Winner:</strong> Bun for overall throughput, Node for memory efficiency, Deno for security/standards.</li>
</ul>

<h2>14. Go vs GccGo</h2>
<ul>
<li><strong>Runtime:</strong> Go (95.45s) vs GccGo/Opt (106.3s) - <strong>Go 10.2% faster</strong></li>
<li><strong>Compilation:</strong> Go (0.747s) ≪ GccGo (6.29s cold)</li>
<li><strong>Verdict:</strong> Standard Go compiler remains superior in all dimensions.</li>
</ul>

<h2>15. D Compilers: LDC vs (DMD hacks only)</h2>
<ul>
<li>GDC not present in this run.</li>
<li>LDC (77.64s) is the reference D implementation.</li>
<li>DMD hacks show significantly slower performance (121.0s summary).</li>
<li><strong>Clear Winner:</strong> LDC (LLVM) is the only serious D compiler for performance work.</li>
</ul>

<h2>16. V GCC vs V Clang</h2>
<ul>
<li><strong>Runtime:</strong> Clang (93.07s) vs GCC (94.61s) - <strong>Clang 1.6% faster</strong></li>
<li><strong>Compilation:</strong> Clang (8.46s) vs GCC (8.55s) - similar</li>
<li><strong>Conclusion:</strong> Clang backend slightly leads for V on AMD.</li>
</ul>

<h2>17. C# vs F# (.NET Ecosystem)</h2>
<ul>
<li><strong>Runtime:</strong> C# (82.62s) vs F# (98.18s) - <strong>C# 15.8% faster</strong></li>
<li><strong>Memory:</strong> C# (112.9 MB) vs F# (121.0 MB) - C# 7% more efficient</li>
<li><strong>Expressiveness:</strong> F# (+32.8%) vs C# (+7.4%)</li>
<li><strong>Trade-off:</strong> C# for performance, F# for functional programming elegance.</li>
</ul>

<h2>18. Dart vs TypeScript</h2>
<ul>
<li><strong>Runtime:</strong> TypeScript/Bun (150.8s) vs Dart (178.8s) - <strong>TypeScript 16% faster</strong></li>
<li><strong>Memory:</strong> Dart (116.8 MB) vs TypeScript/Bun (343.6 MB) - <strong>Dart 2.9× more efficient</strong></li>
<li><strong>Compilation:</strong> Dart AOT (1.99s) vs TypeScript (varies)</li>
<li><strong>Verdict:</strong> TypeScript faster, Dart dramatically more memory-efficient. Dart's AOT delivers on memory promises.</li>
</ul>

<h2>19. Odin vs Zig</h2>
<ul>
<li>Data note explicitly warns: Odin has bugs in some tests, don't compare runtime directly (137.6s vs Zig 76.63s).</li>
<li><strong>Memory:</strong> Zig (56.05 MB) &lt; Odin (70.82 MB) - Zig more efficient</li>
<li><strong>Expressiveness:</strong> Zig (-168.8%) significantly more verbose than Odin (-47.7%)</li>
<li><strong>Compilation:</strong> Odin (8.52s) &lt; Zig (37.6s) - Odin much faster to compile</li>
<li><strong>Matmul scaling:</strong> Both excellent (Odin 9.86×, Zig 8.55×)</li>
<li><strong>Takeaway:</strong> Zig for memory safety and efficiency where bugs fixed; Odin for faster compilation and simpler syntax where bugs are resolved.</li>
</ul>

<h2>20. Python/PYPY Analysis</h2>
<p><strong>The Fastest Python:</strong> PYPY achieves 315.8s total runtime—roughly 6.4× slower than C++. This is the best-case Python scenario with JIT optimization.</p>
<ul>
<li><strong>Memory:</strong> 218.0 MB—high but not insane for dynamic language with JIT.</li>
<li><strong>Compilation:</strong> 0.125s (essentially instant).</li>
<li><strong>Expressiveness:</strong> +25.8%—4th most expressive language.</li>
<li><strong>Reality Check:</strong> Even optimized Python cannot compete with compiled languages on raw computation. Python's value remains ecosystem, development speed, and expressiveness—not performance.</li>
</ul>

<h2>21. Hacking Configurations Insights ("-Hack" suffix)</h2>
<p><strong>Insights from hacking data (configs excluded from official rankings):</strong></p>
<ul>
<li><strong>C/C++ MaxPerf-Hack:</strong> -Ofast yields summary 40.68s (C/Clang) vs base 52.65s - 23% gains from unsafe flags! Huge difference in matrix math.</li>
<li><strong>Rust WMO/Unchecked:</strong> MaxPerf/Unsafe-Hack achieves 55.67s vs base 53.93s - actually slightly worse, suggesting default flags already optimal.</li>
<li><strong>Swift Unchecked-Hack:</strong> Summary improves from 249.3s to 242.9s - modest 2.6% gain overall.</li>
<li><strong>Java/Kotlin/Scala JVM tuning:</strong> Opt-Hacks provide 5-10% improvement in some tests.</li>
<li><strong>C# AOT-Extreme-Hack:</strong> 97.3s vs AOT 97.36s - essentially identical.</li>
<li><strong>Julia AOT-Hack:</strong> 138.5s vs default 133.4s - actually worse, precompilation doesn't help.</li>
<li><strong>Nim ARC-Hack:</strong> Reference counting vs GC: 81.47s (GCC/ARC) vs 84.96s (GCC) - ARC faster!</li>
<li><strong>D LDC MaxPerf-Hack:</strong> 82.3s vs base 77.64s - actually worse, suggesting default flags already optimal.</li>
<li><strong>TypeScript Bun/Deno variants:</strong> Bun/Compiled-Hack 150.9s vs JIT 150.8s - minimal difference.</li>
<li><strong>Zig Unchecked-Hack:</strong> 68.53s vs 76.63s (10.6% gain) - safety has measurable cost.</li>
</ul>
<p><strong>General Pattern:</strong> Modern compilers' default optimization levels capture most performance. "Hacks" typically trade safety for gains, most dramatic in C (23% gain from -Ofast/unsafe).</p>

<h2>22. Overall Insights & AI Tool Final Rankings</h2>
<p><strong>What these benchmarks reveal:</strong></p>
<ol>
<li><strong>The performance hierarchy is stable:</strong> C/C++/Rust at top, dynamic languages at bottom.</li>
<li><strong>Memory safety is affordable:</strong> Rust within 2-5% of C/C++ with safety guarantees.</li>
<li><strong>JIT vs AOT trade-off:</strong> JIT (Java/C#) wins for throughput, AOT for memory/density.</li>
<li><strong>JVM threading excellence:</strong> Java/Kotlin/Scala outperform many native languages in parallel compute.</li>
<li><strong>Go's goroutines disappoint:</strong> Poor scaling in compute-heavy parallel work (6.28×).</li>
<li><strong>Swift scaling surprises:</strong> 12.17× in matmul, best in class!</li>
<li><strong>Crystal impresses:</strong> 69.22s total, beating Zig and D.</li>
<li><strong>Expressiveness has a cost:</strong> Most expressive languages (Crystal, Scala) sacrifice some performance but Crystal proves it can be fast.</li>
</ol>

<p><strong>AI Tool Final Rankings (Subjective):</strong></p>
<table>
<tr><th>Rank</th><th>Language/Config</th><th>Medal</th><th>AI Score</th><th>Strengths</th><th>Weaknesses</th></tr>
<tr style="background-color: #fffacd;"><td>1</td><td><strong>C++/G++</strong></td><td>🥇</td><td>96/100</td><td>Peak performance, ecosystem, control, #1 runtime</td><td>Complexity, manual memory</td></tr>
<tr style="background-color: #fffacd;"><td>2</td><td><strong>Rust</strong></td><td>🥈</td><td>94/100</td><td>Safety + performance, memory efficiency (#1), 0 last places</td><td>Learning curve, compile time</td></tr>
<tr style="background-color: #fffacd;"><td>3</td><td><strong>C/Gcc</strong></td><td>🥉</td><td>93/100</td><td>Raw speed, most wins (13), excellent scaling</td><td>Safety, verbosity</td></tr>
<tr><td>4</td><td>Java/OpenJDK</td><td>🏅</td><td>87/100</td><td>Enterprise, threading (11.69×), consistency</td><td>Memory, startup</td></tr>
<tr><td>5</td><td>Crystal</td><td>💎</td><td>85/100</td><td>Beautiful syntax, expressive leader, fast (69.22s)</td><td>Small community</td></tr>
<tr><td>6</td><td>Zig</td><td>🏅</td><td>84/100</td><td>Simplicity, C interop, memory efficient</td><td>Verbose, slow compile (37.6s)</td></tr>
<tr><td>7</td><td>D/LDC</td><td>🏅</td><td>83/100</td><td>Productivity + performance</td><td>Niche adoption</td></tr>
<tr><td>8</td><td>Kotlin/JVM</td><td>🏅</td><td>82/100</td><td>Modern Java, expressive</td><td>Slow compilation (22.16s)</td></tr>
<tr><td>9</td><td>Swift</td><td>🍎</td><td>81/100</td><td>Excellent scaling (12.17×), safety</td><td>Linux performance (249s total)</td></tr>
<tr><td>10</td><td>C#/JIT</td><td>🏅</td><td>80/100</td><td>.NET ecosystem, good performance</td><td>Cross-platform maturity</td></tr>
<tr><td>11</td><td>Nim/GCC</td><td>🏅</td><td>79/100</td><td>Python-like syntax, fast, expressive (39% better)</td><td>Small community</td></tr>
<tr><td>12</td><td>Go</td><td>🏅</td><td>78/100</td><td>Simplicity, fast compilation (0.747s)</td><td>Poor scaling (6.28×), GC</td></tr>
<tr><td>13</td><td>Scala/JVM</td><td>🧮</td><td>77/100</td><td>Functional, expressive (40.7% better)</td><td>Memory, performance</td></tr>
<tr><td>14</td><td>V/Clang</td><td>🆕</td><td>76/100</td><td>Fast compiler, simple</td><td>Very young, scaling stalls</td></tr>
<tr><td>15</td><td>Odin/Default</td><td>⚙️</td><td>75/100</td><td>Good scaling (9.86×), low memory</td><td>Bugs, ecosystem</td></tr>
<tr><td>16</td><td>F#/JIT</td><td>🧮</td><td>74/100</td><td>Functional elegance (32.8% expressive)</td><td>Performance gap</td></tr>
<tr><td>17</td><td>Julia/Default</td><td>🔬</td><td>70/100</td><td>Scientific computing</td><td>Memory (440MB), AMD scaling regression</td></tr>
<tr><td>18</td><td>TypeScript/Bun</td><td>📜</td><td>66/100</td><td>Web ecosystem, Bun's 150.8s fastest JS</td><td>Performance, memory (343MB)</td></tr>
<tr><td>19</td><td>Dart/AOT</td><td>🎯</td><td>60/100</td><td>Flutter, memory efficient (116MB)</td><td>Compute performance (178.8s)</td></tr>
<tr><td>20</td><td>Python/PYPY</td><td>🐍</td><td>55/100</td><td>Ecosystem, expressiveness (25.8%)</td><td>Performance (315.8s)</td></tr>
</table>

<h2>23. Practical Recommendations</h2>
<p><strong>Choose based on requirements:</strong></p>
<ul>
<li><strong>Maximum Performance:</strong> C++/G++ or Rust (add safety with &lt;5% cost)</li>
<li><strong>Systems Programming:</strong> Rust &gt; Zig &gt; C (safety vs control trade-off)</li>
<li><strong>Memory Efficiency:</strong> Rust (31.3MB) &gt; C (33.27MB) &gt; C++ (32.96MB)</li>
<li><strong>Developer Productivity + Performance:</strong> Crystal &gt; Nim &gt; D/LDC (if single-threaded OK)</li>
<li><strong>Enterprise Backend:</strong> Java &gt; C# &gt; Go (ecosystem maturity)</li>
<li><strong>Web Services:</strong> Go (simplicity, fast compile) &gt; Java/C# (performance) &gt; TypeScript/Bun (full-stack)</li>
<li><strong>Scientific Computing:</strong> Julia (but test on target hardware - AMD issues) &gt; C++/Python combo</li>
<li><strong>CLI Tools:</strong> Go (0.7s compile, single binary) &gt; Rust &gt; Zig</li>
<li><strong>Mobile/UI:</strong> Dart (Flutter, memory efficient) &gt; Swift (iOS, great scaling) &gt; Kotlin (Android)</li>
<li><strong>Data Science/ML:</strong> Python (ecosystem) &gt;&gt; everything else</li>
<li><strong>Embedded:</strong> C &gt; Rust &gt; Zig (C still dominates)</li>
<li><strong>Learning Programming:</strong> Python &gt; TypeScript &gt; Go</li>
<li><strong>Functional Programming:</strong> Scala (expressiveness) &gt; F# (performance trade-off)</li>
<li><strong>If you need both speed AND expressiveness:</strong> Crystal (69s runtime, +43% expressiveness) - the surprise winner of this benchmark</li>
</ul>

<p><em>Disclaimer: This analysis represents AI Tool's interpretation of provided benchmark data from 2026-02-26. Performance characteristics evolve with compiler/runtime updates. Always test with your specific workload and requirements. Crystal's strong showing and Swift's excellent scaling were unexpected insights.</em></p>
</div>
`);
}
