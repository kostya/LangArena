function ai_analys($results) {
    $results.append(`
<div class="benchmark-analysis">
<h1>Comprehensive Benchmark Analysis</h1>
<p><strong>Test Environment:</strong> 2026-01-25 | x86_64 | AMD Ryzen 7 3800X 8-Core | 78GB RAM</p>
<p><strong>Scope:</strong> 11 languages, 40 benchmarks, 23 configurations</p>

<h2>1. Runtime Performance Analysis</h2>
<p><strong>Overall Performance Ranking (Total Runtime):</strong></p>
<ol>
<li><strong>C++/G++</strong> - 48.30s (Fastest overall)</li>
<li><strong>C/Gcc</strong> - 48.75s (Most consistent winner)</li>
<li><strong>Zig</strong> - 50.92s (Remarkable for a newer language)</li>
<li><strong>Rust</strong> - 52.11s (Excellent safety/performance balance)</li>
<li><strong>Crystal</strong> - 72.33s (Best GC language performance)</li>
<li><strong>C#/JIT</strong> - 75.77s (Best managed runtime)</li>
<li><strong>Java/OpenJDK</strong> - 80.33s</li>
<li><strong>Go</strong> - 83.92s</li>
<li><strong>Kotlin/JVM</strong> - 84.97s</li>
<li><strong>TypeScript/Node</strong> - 144.20s</li>
<li><strong>Swift</strong> - 240.30s (Unexpectedly slow)</li>
</ol>

<p><strong>Performance Tiers:</strong></p>
<ul>
<li><strong>Tier 1 (Native/Compiled):</strong> C++, C, Zig, Rust (48-53s)</li>
<li><strong>Tier 2 (Managed with JIT):</strong> Crystal, C#, Java, Go, Kotlin (72-85s)</li>
<li><strong>Tier 3 (Scripting):</strong> TypeScript runtimes (144-258s)</li>
<li><strong>Tier 4 (Problematic):</strong> Swift (240s), Bun variants (256s+)</li>
</ul>

<p><strong>Key Observations:</strong></p>
<ul>
<li>C++ maintains ~5% advantage over C in most tests</li>
<li>Zig achieves near-C performance while being safer/more modern</li>
<li>Rust delivers 90-95% of C performance with memory safety</li>
<li>Crystal significantly outperforms other GC languages</li>
<li>JVM languages show competitive performance (65-70% of C++)</li>
<li>TypeScript runtimes are 3-5x slower than native languages</li>
</ul>

<hr>

<h2>2. Memory Usage Analysis</h2>
<p><strong>Memory Efficiency Ranking (Average MB):</strong></p>
<ol>
<li><strong>C++/G++</strong> - 120.5 MB (Most efficient)</li>
<li><strong>C/Gcc</strong> - 128.1 MB</li>
<li><strong>Zig</strong> - 137.7 MB</li>
<li><strong>Rust</strong> - 136.4 MB</li>
<li><strong>Crystal</strong> - 162.1 MB</li>
<li><strong>Go</strong> - 216.6 MB</li>
<li><strong>C#/JIT</strong> - 266.8 MB</li>
<li><strong>TypeScript/Node</strong> - 477.5 MB</li>
<li><strong>Swift</strong> - 488.9 MB</li>
<li><strong>Java/OpenJDK</strong> - 534.2 MB</li>
<li><strong>Kotlin/JVM</strong> - 552.6 MB</li>
</ol>

<p><strong>Memory Consumption Patterns:</strong></p>
<ul>
<li>Native languages use 120-140 MB (3-4x less than JVM)</li>
<li>JVM languages have high baseline (500+ MB) due to runtime overhead</li>
<li>Go shows good balance (217 MB) for a GC language</li>
<li>Swift uses surprisingly high memory (489 MB) despite poor performance</li>
<li>TypeScript runtimes are memory-heavy without performance benefits</li>
</ul>

<hr>

<h2>3. Wins/Losses Analysis</h2>
<p><strong>Individual Test Wins:</strong></p>
<ul>
<li><strong>C/Gcc</strong> - 12 wins (Most dominant)</li>
<li><strong>C++/G++</strong> - 8 wins</li>
<li><strong>Zig</strong> - 4 wins</li>
<li><strong>Rust</strong> - 5 wins</li>
<li><strong>C#, Java, Go, Crystal, Kotlin</strong> - 1-2 wins each</li>
<li><strong>TypeScript, Swift</strong> - 0 wins</li>
</ul>

<p><strong>Last Place Finishes:</strong></p>
<ul>
<li><strong>TypeScript variants</strong> - 20+ last places</li>
<li><strong>Swift</strong> - 13 last places</li>
<li><strong>GraalVM Native variants</strong> - Multiple last places</li>
<li><strong>C, C++, Zig, Rust</strong> - 0 last places</li>
</ul>

<p><strong>Competitiveness Score:</strong></p>
<ul>
<li><strong>Always Competitive:</strong> C, C++, Zig, Rust (never last)</li>
<li><strong>Specialized Winners:</strong> Managed languages win specific tests (JSON, Regex)</li>
<li><strong>Struggling:</strong> TypeScript and Swift consistently underperform</li>
</ul>

<hr>

<h2>4. Compile Time Analysis</h2>
<p><strong>Compilation Speed Ranking:</strong></p>
<ol>
<li><strong>Go</strong> - 0.91s (Instantaneous)</li>
<li><strong>C/Gcc</strong> - 1.90s</li>
<li><strong>TypeScript/Node</strong> - 15.44s</li>
<li><strong>C#/JIT</strong> - 7.74s</li>
<li><strong>C++/G++</strong> - 7.59s</li>
<li><strong>Rust</strong> - 12.53s</li>
<li><strong>Swift</strong> - 17.10s</li>
<li><strong>Java/OpenJDK</strong> - 22.83s</li>
<li><strong>Crystal</strong> - 22.43s</li>
<li><strong>Zig</strong> - 90.69s (Very slow)</li>
<li><strong>Kotlin/JVM</strong> - 128.0s (Slowest)</li>
</ol>

<p><strong>Compilation Memory Usage:</strong></p>
<ul>
<li><strong>Highest:</strong> C++/G++ (733 MB) - extreme memory usage</li>
<li><strong>Lowest:</strong> C/Gcc (69.88 MB) - very efficient</li>
<li><strong>Best Balance:</strong> Go (0.91s, 79 MB) - excellent</li>
</ul>

<p><strong>Binary Size:</strong></p>
<ul>
<li><strong>Smallest:</strong> C#/JIT (0.109 MB), Java (0.191 MB)</li>
<li><strong>Largest:</strong> Go (3.59 MB), TypeScript/Deno (4.14 MB)</li>
</ul>

<hr>

<h2>5. Language Expressiveness Analysis</h2>
<p><strong>Expressiveness Ranking (% better than average):</strong></p>
<ol>
<li><strong>Crystal</strong> +52.0% (Most expressive)</li>
<li><strong>Go</strong> +34.6%</li>
<li><strong>Swift</strong> +30.8%</li>
<li><strong>Kotlin</strong> +29.4%</li>
<li><strong>Java</strong> +11.4%</li>
<li><strong>TypeScript</strong> +16.7%</li>
<li><strong>C#</strong> -3.1%</li>
<li><strong>Rust</strong> -18.4%</li>
<li><strong>C</strong> -106.0% (Least expressive)</li>
<li><strong>Zig</strong> -134.5% (Most verbose)</li>
</ol>

<p><strong>Key Trade-offs:</strong></p>
<ul>
<li>Crystal offers best expressiveness with good performance</li>
<li>Go balances expressiveness, compilation speed, and performance</li>
<li>C/Zig sacrifice expressiveness for maximum control/performance</li>
<li>Modern languages (C#, Kotlin) offer decent expressiveness</li>
</ul>

<hr>

<h2>6. Notable Anomalies and Outliers</h2>
<p><strong>Major Performance Anomalies:</strong></p>
<ul>
<li><strong>Swift's Poor Performance:</strong> Exceptionally slow in Pidigits (27.25s vs C's 0.63s) and JsonGenerate (74.14s vs Rust's 0.47s)</li>
<li><strong>Bun JIT Catastrophe:</strong> 258.0s total runtime, worst in Knucleotide (110.1s vs C's 0.13s)</li>
<li><strong>GraalVM Native Regressions:</strong> Often slower than JIT versions (Java/Kotlin)</li>
<li><strong>Crystal Multi-threading Failure:</strong> Multi-threaded Matmul slower than single-threaded</li>
</ul>

<p><strong>Memory Anomalies:</strong></p>
<ul>
<li><strong>Kotlin GraalVM JIT:</strong> 1695 MB compilation memory (10x typical)</li>
<li><strong>Swift High Memory:</strong> 489 MB average despite poor performance</li>
<li><strong>JVM High Baseline:</strong> 500+ MB regardless of workload</li>
</ul>

<hr>

<h2>7. Multi-threaded Matmul Analysis (8-core CPU)</h2>
<p><strong>Single-threaded Matmul Baseline:</strong></p>
<ul>
<li>Fastest: C/Gcc, C++/G++, Swift - 5.98s</li>
<li>Typical: Rust, Go, Java, Zig - 6.07-6.70s</li>
<li>Slowest: TypeScript variants - 6.27-6.30s</li>
</ul>

<p><strong>Scaling Analysis (4T, 8T, 16T - same matrix sizes):</strong></p>
<table>
<tr><th>Language</th><th>Matmul (1T)</th><th>Matmul4T</th><th>Matmul8T</th><th>Matmul16T</th><th>16T Speedup</th><th>Scaling Efficiency</th></tr>
<tr><td><strong>C++/G++</strong></td><td>5.98s</td><td>1.57s (3.8x)</td><td>0.855s (7.0x)</td><td>0.51s (11.7x)</td><td>11.7x</td><td>Excellent</td></tr>
<tr><td><strong>C/Gcc</strong></td><td>5.98s</td><td>1.55s (3.9x)</td><td>0.831s (7.2x)</td><td>0.479s (12.5x)</td><td>12.5x</td><td>Excellent</td></tr>
<tr><td><strong>Zig</strong></td><td>6.70s</td><td>1.69s (4.0x)</td><td>0.95s (7.1x)</td><td>0.634s (10.6x)</td><td>10.6x</td><td>Very Good</td></tr>
<tr><td><strong>Rust</strong></td><td>6.07s</td><td>1.58s (3.8x)</td><td>0.851s (7.1x)</td><td>0.614s (9.9x)</td><td>9.9x</td><td>Good</td></tr>
<tr><td><strong>Go</strong></td><td>6.56s</td><td>2.29s (2.9x)</td><td>1.44s (4.6x)</td><td>0.957s (6.9x)</td><td>6.9x</td><td>Moderate</td></tr>
<tr><td><strong>Java/OpenJDK</strong></td><td>6.76s</td><td>2.10s (3.2x)</td><td>0.981s (6.9x)</td><td>0.717s (9.4x)</td><td>9.4x</td><td>Good</td></tr>
<tr><td><strong>Swift</strong></td><td>5.98s</td><td>1.59s (3.8x)</td><td>0.87s (6.9x)</td><td>0.51s (11.7x)</td><td>11.7x</td><td>Excellent</td></tr>
<tr><td><strong>Crystal</strong></td><td>6.08s</td><td>6.12s (0.99x)</td><td>6.11s (0.99x)</td><td>6.12s (0.99x)</td><td>0.99x</td><td>No Scaling</td></tr>
<tr><td><strong>C#/JIT</strong></td><td>6.04s</td><td>1.64s (3.7x)</td><td>0.945s (6.4x)</td><td>0.677s (8.9x)</td><td>8.9x</td><td>Good</td></tr>
</table>

<p><strong>Key Findings:</strong></p>
<ol>
<li><strong>Best Absolute Performance:</strong> C++/G++ and C/Gcc (0.48-0.51s) - fastest with 16 threads</li>
<li><strong>Best Scaling Efficiency:</strong> C/Gcc (12.5x speedup) and C++/G++ (11.7x) - excellent thread utilization on 8-core CPU</li>
<li><strong>Hyperthreading Benefits:</strong> Most languages show gains with 16T vs 8T (C/C++: 11.7-12.5x vs 7.0-7.2x), indicating good HT utilization</li>
<li><strong>Surprisingly Good:</strong> Swift shows excellent scaling (11.7x) despite poor performance in other tests</li>
<li><strong>Disappointing:</strong> Crystal shows NO multi-threading scaling (0.99x) - major limitation</li>
<li><strong>Moderate Scaling:</strong> Go shows only 6.9x speedup with 16 threads - less efficient threading</li>
<li><strong>Consistent Pattern:</strong> Most languages scale well to 4-8 threads, with diminishing returns at 16T (but still positive gains)</li>
<li><strong>Memory Bound?</strong> Scaling beyond 8 threads suggests computation is CPU-bound, not memory-bound</li>
</ol>

<p><strong>Performance at Each Thread Level:</strong></p>
<ul>
<li><strong>4 Threads (50% core utilization):</strong> Most languages achieve 3.2-4.0x speedup (64-80% efficiency)</li>
<li><strong>8 Threads (100% core utilization):</strong> 6.4-7.2x speedup (80-90% efficiency) for most</li>
<li><strong>16 Threads (200% with HT):</strong> 8.9-12.5x speedup (45-78% efficiency relative to physical cores)</li>
</ul>

<p><strong>Language-Specific Observations:</strong></p>
<ul>
<li><strong>C/C++:</strong> Excellent scaling shows mature threading implementations</li>
<li><strong>Rust:</strong> Good but not exceptional scaling (9.9x)</li>
<li><strong>Zig:</strong> Very good scaling (10.6x) for a newer language</li>
<li><strong>Go:</strong> Only moderate scaling (6.9x) despite being designed for concurrency</li>
<li><strong>Java/C#:</strong> Good scaling (8.9-9.4x) showing JIT optimization works well</li>
<li><strong>Swift:</strong> Excellent scaling (11.7x) contradicts its poor overall performance</li>
<li><strong>Crystal:</strong> Complete failure in multi-threading implementation</li>
</ul>
<hr>

<h2>8. Compiler Comparisons</h2>

<h3>Gcc vs Clang:</h3>
<ul>
<li><strong>C:</strong> Gcc (48.75s) faster than Clang (53.43s)</li>
<li><strong>C++:</strong> G++ (48.30s) faster than Clang++ (50.12s)</li>
<li><strong>Memory:</strong> Similar memory usage for both compilers</li>
<li><strong>Winner:</strong> Gcc/G++ consistently outperforms Clang in these benchmarks</li>
</ul>

<h3>OpenJDK vs GraalVM:</h3>
<ul>
<li><strong>Runtime:</strong> OpenJDK (80.33s) faster than GraalVM JIT (81.62s) and much faster than GraalVM Native (147.4s)</li>
<li><strong>Memory:</strong> GraalVM Native (63-66 MB) uses significantly less memory than OpenJDK (534 MB)</li>
<li><strong>Trade-off:</strong> OpenJDK better for performance, GraalVM Native better for memory/startup</li>
</ul>

<h3>Java vs Kotlin:</h3>
<ul>
<li><strong>Performance:</strong> Java (80.33s) slightly faster than Kotlin (84.97s)</li>
<li><strong>Memory:</strong> Similar high memory usage (530-550 MB range)</li>
<li><strong>Expressiveness:</strong> Kotlin more expressive (+29.4% vs +11.4%)</li>
<li><strong>Compilation:</strong> Kotlin much slower to compile (128.0s vs 22.83s)</li>
</ul>

<h3>C# JIT vs AOT:</h3>
<ul>
<li><strong>Performance:</strong> JIT (75.77s) faster than AOT (86.82s)</li>
<li><strong>Memory:</strong> AOT uses less memory (15.52 MB vs 45.37 MB for JIT)</li>
<li><strong>Startup:</strong> AOT has faster startup, JIT has better peak performance</li>
<li><strong>Binary Size:</strong> JIT tiny (0.109 MB), AOT larger but still reasonable</li>
</ul>

<h3>Node.js vs Bun vs Deno:</h3>
<ul>
<li><strong>Performance:</strong> Node (144.2s) > Deno (155.4s) > Bun (258.0s)</li>
<li><strong>Memory:</strong> All similar (450-480 MB average)</li>
<li><strong>Compilation:</strong> Bun JIT fastest (no compile), Deno compilation adds overhead</li>
<li><strong>Winner:</strong> Node.js offers best performance among JavaScript runtimes</li>
</ul>

<h3>Go vs GccGo:</h3>
<ul>
<li><strong>Runtime:</strong> Go (83.92s) vs GccGo/Opt (86.08s) - Go slightly faster</li>
<li><strong>Memory:</strong> Go (217 MB) more efficient than GccGo (varies)</li>
<li><strong>Matmul Performance:</strong> GccGo/Opt excels in multi-threaded (0.50s best)</li>
<li><strong>Compilation:</strong> Go much faster (0.91s vs 7.74s)</li>
</ul>

<hr>

<h2>9. Hacking Configurations Analysis</h2>
<p><strong>Most Impactful Optimizations:</strong></p>
<ul>
<li><strong>C/C++ MaxPerf-Hack:</strong> Shows what's possible with aggressive optimization (5-15% gains)</li>
<li><strong>C# AOT-EXTREME:</strong> AOT can approach JIT performance with right settings</li>
<li><strong>Rust MaxPerf/Unsafe:</strong> Minimal gains - safe Rust already optimal</li>
<li><strong>Java/Kotlin JVM tuning:</strong> Significant gains possible with proper JVM flags</li>
<li><strong>TypeScript optimization flags:</strong> Limited impact on V8 performance</li>
</ul>

<p><strong>Key Insights:</strong></p>
<ol>
<li>Compiler flags matter significantly for C/C++ (5-15% differences)</li>
<li>JVM tuning can yield 10-20% improvements</li>
<li>AOT compilation often sacrifices peak performance for startup time</li>
<li>Modern languages already well-optimized by default</li>
</ol>

<hr>

<h2>10. Overall Insights and Surprises</h2>

<p><strong>What I Expected:</strong></p>
<ul>
<li>C/C++ dominance in performance</li>
<li>Rust close to C performance</li>
<li>JVM languages slower than native</li>
<li>JavaScript runtimes slowest</li>
</ul>

<p><strong>What Surprised Me:</strong></p>
<ol>
<li><strong>Swift's Poor Performance:</strong> Consistently worst performer</li>
<li><strong>Bun's Performance:</strong> Much worse than Node/Deno</li>
<li><strong>Crystal's Strong Showing:</strong> Fastest GC language</li>
<li><strong>Zig's Performance:</strong> Near-C with modern features</li>
<li><strong>Rust's Multi-threading:</strong> Limited scaling in Matmul</li>
<li><strong>GraalVM Native Regression:</strong> Often slower than JIT</li>
<li><strong>C# JIT vs AOT:</strong> JIT faster than AOT</li>
</ol>

<hr>

<h2>11. Final Language Rankings</h2>

<table>
<tr><th>Rank</th><th>Language</th><th>Medal</th><th>Score</th><th>Strengths</th><th>Weaknesses</th></tr>
<tr><td>1</td><td>C++/G++</td><td>🥇</td><td>95/100</td><td>Performance, Scaling, Versatility</td><td>Complexity, Memory Safety</td></tr>
<tr><td>2</td><td>C/Gcc</td><td>🥈</td><td>94/100</td><td>Raw Performance, Control</td><td>Safety, Expressiveness</td></tr>
<tr><td>3</td><td>Zig</td><td>🥉</td><td>89/100</td><td>Performance, Memory Efficiency</td><td>Young Ecosystem</td></tr>
<tr><td>4</td><td>Rust</td><td>🏅</td><td>88/100</td><td>Safety/Performance Balance</td><td>Learning Curve</td></tr>
<tr><td>5</td><td>Crystal</td><td>🏅</td><td>83/100</td><td>Expressiveness, GC Performance</td><td>Multi-threading</td></tr>
<tr><td>6</td><td>Go</td><td>🏅</td><td>81/100</td><td>Concurrency, Compilation Speed</td><td>GC Pauses</td></tr>
<tr><td>7</td><td>C#/JIT</td><td>🏅</td><td>79/100</td><td>Ecosystem, Tooling</td><td>Platform Dependency</td></tr>
<tr><td>8</td><td>Java/OpenJDK</td><td>🏅</td><td>76/100</td><td>Ecosystem, Stability</td><td>Memory Usage</td></tr>
<tr><td>9</td><td>Kotlin/JVM</td><td>🏅</td><td>73/100</td><td>Expressiveness, Interop</td><td>Compilation Speed</td></tr>
<tr><td>10</td><td>TypeScript/Node</td><td>📜</td><td>66/100</td><td>Ecosystem, Productivity</td><td>Performance</td></tr>
<tr><td>11</td><td>Swift</td><td>⚠️</td><td>56/100</td><td>Apple Integration</td><td>Performance, Portability</td></tr>
</table>

<hr>

<h2>12. Practical Recommendations</h2>

<p><strong>Choose C++/G++ when:</strong></p>
<ul>
<li>Maximum performance is critical</li>
<li>You need fine-grained control</li>
<li>Working on performance-sensitive systems code</li>
<li>You have experienced developers</li>
</ul>

<p><strong>Choose Rust when:</strong></p>
<ul>
<li>You need C++-level performance with memory safety</li>
<li>Working on systems where crashes are unacceptable</li>
<li>Concurrency safety is important</li>
<li>Willing to invest in learning curve</li>
</ul>

<p><strong>Choose Zig when:</strong></p>
<ul>
<li>You want C performance with modern tooling</li>
<li>Cross-compilation is important</li>
<li>You value simplicity and explicit control</li>
<li>Working on embedded or systems programming</li>
</ul>

<p><strong>Choose Crystal when:</strong></p>
<ul>
<li>You want Ruby-like syntax with C-like performance</li>
<li>Single-threaded performance matters most</li>
<li>You value developer happiness and expressiveness</li>
<li>Working on web services or CLI tools</li>
</ul>

<p><strong>Choose Go when:</strong></p>
<ul>
<li>Concurrency is a primary concern</li>
<li>Fast compilation and deployment matter</li>
<li>You need simple, maintainable code</li>
<li>Working on microservices or network services</li>
</ul>

<p><strong>Choose C# when:</strong></p>
<ul>
<li>You need enterprise-level tooling</li>
<li>Working in Windows ecosystem</li>
<li>Game development (with Unity)</li>
<li>You want good performance with garbage collection</li>
</ul>

<p><strong>Choose Java/Kotlin when:</strong></p>
<ul>
<li>Enterprise stability is critical</li>
<li>You have existing JVM infrastructure</li>
<li>Android development (Kotlin)</li>
<li>Large team coordination is needed</li>
</ul>

<p><strong>Choose TypeScript/Node when:</strong></p>
<ul>
<li>Web development is primary focus</li>
<li>Developer availability matters</li>
<li>Rapid prototyping needed</li>
<li>Performance is not the primary concern</li>
</ul>

<p><strong>Avoid Swift for:</strong> General-purpose performance-sensitive applications (based on this data)</p>
<p><strong>Avoid Bun for:</strong> Performance-critical applications (use Node.js instead)</p>

<hr>

<h2>13. DeepSeek's Subjective Opinion</h2>
<p><em>This analysis reveals fascinating insights about the current state of programming languages. The most striking findings:</em></p>

<ol>
<li><strong>C++/G++ remains unbeatable</strong> for raw performance, showing that decades of optimization matter.</li>
<li><strong>Zig is the dark horse</strong> - achieving near-C performance with modern safety features is impressive.</li>
<li><strong>Crystal proves</strong> that expressive, high-level languages can be fast, though it needs multi-threading work.</li>
<li><strong>Rust's safety overhead</strong> is minimal (5-10%), making it a compelling choice for new systems projects.</li>
<li><strong>Go's compilation speed</strong> is revolutionary - 0.91s vs minutes for other languages.</li>
<li><strong>Swift's poor showing</strong> is concerning - either the benchmarks are unfair or Swift has serious optimization issues.</li>
<li><strong>Modern JITs (C#, Java)</strong> compete well with native code in many scenarios.</li>
<li><strong>TypeScript runtimes</strong> still have a 3-5x performance gap vs native languages.</li>
</ol>

<p><strong>My Takeaway:</strong> The "best" language depends completely on context. For maximum performance: C++/G++. For safety + performance: Rust. For rapid development: Go or Crystal. For web: TypeScript/Node. The benchmarks show that modern languages have closed much of the performance gap, but native compilation still wins for compute-intensive tasks.</p>

<p><strong>Unexpected Winner:</strong> Zig - it achieves what Rust promised (safety + performance) with less complexity.</p>
<p><strong>Biggest Disappointment:</strong> Swift - being slower than JavaScript runtimes is unacceptable for a compiled language.</p>
<p><strong>Most Promising:</strong> Crystal - if it fixes multi-threading, it could become the perfect high-level systems language.</p>

<hr>

<p><em>Disclaimer: This analysis represents DeepSeek's interpretation of the provided benchmark data. Results may vary based on specific use cases, compiler versions, optimization settings, and hardware configurations. Always test with your own workload before making technology decisions.</em></p>
</div>
    `);
}
