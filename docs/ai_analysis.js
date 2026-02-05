function ai_analys($results) {
    $results.append(`
<div class="benchmark-analysis">
<h1>Comprehensive Benchmark Analysis</h1>
<p><strong>Test Environment:</strong> 2026-02-04 | x86_64 | AMD Ryzen 7 3800X 8-Core | 78GB RAM</p>
<p><strong>Scope:</strong> 15 languages, 41 benchmarks, 25 configurations</p>

<h2>1. Runtime Performance Analysis</h2>
<p><strong>Overall Performance Ranking (Total Runtime):</strong></p>
<ol>
<li><strong>C++/G++</strong> - 66.72s (Fastest overall, 9 wins)</li>
<li><strong>C/Gcc</strong> - 86.88s (Most wins - 10)</li>
<li><strong>Rust</strong> - 91.04s (Excellent modern alternative)</li>
<li><strong>D/LDC</strong> - 102.00s (Strong showing for D)</li>
<li><strong>Zig</strong> - 105.10s (2 wins)</li>
<li><strong>Crystal</strong> - 106.20s (0 wins but competitive)</li>
<li><strong>Java/OpenJDK</strong> - 121.90s</li>
<li><strong>Kotlin/JVM/Default</strong> - 121.30s</li>
<li><strong>C#/JIT</strong> - 137.00s</li>
<li><strong>Nim/Clang</strong> - 137.70s (New entry)</li>
<li><strong>Go</strong> - 149.70s</li>
<li><strong>TypeScript/Node/Default</strong> - 160.30s</li>
<li><strong>V/GCC</strong> - 169.20s (Improved from 206.5s)</li>
<li><strong>Julia/Default</strong> - 188.60s (New entry)</li>
<li><strong>Swift</strong> - 568.30s (Massive outlier)</li>
</ol>

<p><strong>Performance Tiers:</strong></p>
<ul>
<li><strong>Tier 1 (Native Elite):</strong> C++, C (67-87s)</li>
<li><strong>Tier 2 (Modern Native):</strong> Rust, D/LDC, Zig, Crystal (91-107s)</li>
<li><strong>Tier 3 (Managed/JVM):</strong> Java, Kotlin, C#, Nim, Go (122-151s)</li>
<li><strong>Tier 4 (Scripting/Runtime):</strong> TypeScript (160s), V (169s), Julia (189s)</li>
<li><strong>Tier 5 (Problematic):</strong> Swift (568s)</li>
</ul>

<hr>

<h2>2. Memory Usage Analysis</h2>
<p><strong>Memory Efficiency Ranking (Average MB):</strong></p>
<ol>
<li><strong>Zig</strong> - 22.74 MB (Most efficient)</li>
<li><strong>C/Gcc</strong> - 23.88 MB</li>
<li><strong>C++/G++</strong> - 23.55 MB</li>
<li><strong>Rust</strong> - 30.21 MB</li>
<li><strong>Crystal</strong> - 43.37 MB</li>
<li><strong>Nim/Clang</strong> - 42.84 MB</li>
<li><strong>D/LDC</strong> - 49.11 MB</li>
<li><strong>Go</strong> - 125.40 MB</li>
<li><strong>Swift</strong> - 74.83 MB</li>
<li><strong>V/GCC</strong> - 102.40 MB</li>
<li><strong>C#/JIT</strong> - 199.80 MB</li>
<li><strong>TypeScript/Node/Default</strong> - 194.30 MB</li>
<li><strong>Java/OpenJDK</strong> - 327.60 MB</li>
<li><strong>Julia/Default</strong> - 432.70 MB</li>
<li><strong>Kotlin/JVM/Default</strong> - 399.30 MB</li>
</ol>

<hr>

<h2>3. Wins/Losses Analysis</h2>
<p><strong>Individual Test Wins:</strong></p>
<ul>
<li><strong>C/Gcc</strong> - 10 wins (Most dominant)</li>
<li><strong>C++/G++</strong> - 9 wins</li>
<li><strong>Rust</strong> - 4 wins</li>
<li><strong>Zig</strong> - 2 wins</li>
<li><strong>D/LDC</strong> - 2 wins</li>
<li><strong>Swift</strong> - 3 wins (despite terrible overall)</li>
<li><strong>Java/OpenJDK</strong> - 3 wins</li>
<li><strong>Crystal, Nim, Go</strong> - 0-1 wins (but competitive)</li>
</ul>

<p><strong>Last Place Finishes:</strong></p>
<ul>
<li><strong>Swift</strong> - 11 last places</li>
<li><strong>TypeScript variants</strong> - 17 last places</li>
<li><strong>Java/GraalVM/JIT</strong> - 1 last place</li>
<li><strong>V/GCC</strong> - 3 last places</li>
<li><strong>Julia/Default</strong> - 2 last places</li>
</ul>

<hr>

<h2>4. Compile Time Analysis</h2>
<p><strong>Compilation Speed Ranking (Incremental):</strong></p>
<ol>
<li><strong>Julia/Default</strong> - 0.39s (Fastest)</li>
<li><strong>Go</strong> - 0.78s</li>
<li><strong>C/Gcc</strong> - 1.79s</li>
<li><strong>Rust</strong> - 1.84s</li>
<li><strong>TypeScript/Node/Default</strong> - 1.97s</li>
<li><strong>Nim/Clang</strong> - 1.58s</li>
<li><strong>Java/OpenJDK</strong> - 2.93s</li>
<li><strong>C#/JIT</strong> - 4.46s</li>
<li><strong>Swift</strong> - 8.69s</li>
<li><strong>C++/G++</strong> - 8.62s</li>
<li><strong>V/GCC</strong> - 8.70s</li>
<li><strong>D/LDC</strong> - 10.33s</li>
<li><strong>Kotlin/JVM/Default</strong> - 17.91s</li>
<li><strong>Crystal</strong> - 22.42s</li>
<li><strong>Zig</strong> - 37.92s (Slowest)</li>
</ol>

<hr>

<h2>5. Language Expressiveness Analysis</h2>
<p><strong>Expressiveness Ranking (% better than average):</strong></p>
<ol>
<li><strong>Crystal</strong> +48.2% (Most expressive)</li>
<li><strong>Nim/Clang</strong> +42.5%</li>
<li><strong>Go</strong> +29.5%</li>
<li><strong>Kotlin</strong> +22.6%</li>
<li><strong>Swift</strong> +23.8%</li>
<li><strong>C#</strong> +13.5%</li>
<li><strong>TypeScript</strong> +11.9%</li>
<li><strong>Java</strong> +11.0%</li>
<li><strong>D/LDC</strong> +4.4%</li>
<li><strong>V</strong> -0.4%</li>
<li><strong>Rust</strong> -10.9%</li>
<li><strong>C</strong> -137.7%</li>
<li><strong>Zig</strong> -178.4% (Most verbose)</li>
</ol>

<hr>

<h2>6. Notable Anomalies and Outliers</h2>
<ul>
<li><strong>Swift Catastrophe:</strong> 568.3s total - remains huge outlier</li>
<li><strong>V Language Improved:</strong> 169.2s vs 206.5s previously - 18% improvement</li>
<li><strong>Julia Architecture Issue:</strong> Poor matmul performance on Ryzen (excellent on M1)</li>
<li><strong>Crystal Threading Failure:</strong> Zero multi-threading scaling in matmul tests</li>
<li><strong>Nim Strong Debut:</strong> 137.7s - competitive with JVM languages</li>
<li><strong>Go/GccGo/Opt Anomaly:</strong> 190.6s total - worse than standard Go compiler</li>
</ul>

<hr>

<h2>7. Multi-threaded Matmul Analysis (8-core CPU)</h2>
<table>
<tr><th>Language</th><th>Matmul1T</th><th>Matmul4T</th><th>Matmul8T</th><th>Matmul16T</th><th>16T Speedup</th><th>Efficiency Tier</th></tr>
<tr><td><strong>C/Gcc</strong></td><td>5.10s</td><td>1.39s</td><td>0.721s</td><td><strong>0.389s</strong></td><td>13.1x</td><td>🏆 Elite</td></tr>
<tr><td><strong>C++/G++</strong></td><td>5.10s</td><td>1.40s</td><td>0.785s</td><td>0.523s</td><td>9.8x</td><td>🥈 Excellent</td></tr>
<tr><td><strong>Java/OpenJDK</strong></td><td>4.95s</td><td>1.33s</td><td>0.718s</td><td>0.427s</td><td>11.6x</td><td>🏆 Elite</td></tr>
<tr><td><strong>Rust</strong></td><td>5.24s</td><td>1.37s</td><td>0.748s</td><td>0.556s</td><td>9.4x</td><td>🥉 Very Good</td></tr>
<tr><td><strong>D/LDC</strong></td><td>5.11s</td><td>1.20s</td><td>0.883s</td><td>0.669s</td><td>7.6x</td><td>Good</td></tr>
<tr><td><strong>Zig</strong></td><td>5.30s</td><td>1.52s</td><td>0.901s</td><td>0.761s</td><td>7.0x</td><td>Good</td></tr>
<tr><td><strong>Nim/Clang</strong></td><td>11.58s</td><td>1.89s</td><td>0.990s</td><td>0.981s</td><td>11.8x*</td><td>Good*</td></tr>
<tr><td><strong>Go</strong></td><td>5.15s</td><td>2.24s</td><td>1.15s</td><td>0.846s</td><td>6.1x</td><td>Fair</td></tr>
<tr><td><strong>C#/JIT</strong></td><td>5.18s</td><td>1.48s</td><td>0.860s</td><td>0.767s</td><td>6.8x</td><td>Fair</td></tr>
<tr><td><strong>Kotlin/JVM</strong></td><td>4.95s</td><td>1.30s</td><td>0.704s</td><td>0.492s</td><td>10.1x</td><td>Excellent</td></tr>
<tr><td><strong>V/GCC</strong></td><td>5.15s</td><td>1.37s</td><td>0.762s</td><td>0.786s</td><td>6.6x</td><td>Fair</td></tr>
<tr><td><strong>Swift</strong></td><td>5.14s</td><td>1.44s</td><td>0.837s</td><td>0.533s</td><td>9.6x</td><td>Very Good</td></tr>
<tr><td><strong>Julia/Default</strong></td><td>10.62s</td><td>2.54s</td><td>1.38s</td><td>3.29s</td><td>3.2x</td><td>Poor</td></tr>
<tr><td><strong>Crystal</strong></td><td>5.08s</td><td>5.10s</td><td>5.16s</td><td>5.13s</td><td>0.99x</td><td>❌ Failed</td></tr>
<tr><td><strong>TypeScript/Node</strong></td><td>5.23s</td><td>5.23s</td><td>5.23s</td><td>5.23s</td><td>1.0x</td><td>❌ Failed</td></tr>
</table>

<p><strong>Key Observations:</strong></p>
<ol>
<li><strong>Elite Scalers (10x+):</strong> C/Gcc (13.1x), Java (11.6x), Nim* (11.8x), Kotlin (10.1x)</li>
<li><strong>Very Good (9-10x):</strong> C++ (9.8x), Rust (9.4x), Swift (9.6x)</li>
<li><strong>Good (7-8x):</strong> D/LDC (7.6x), Zig (7.0x)</li>
<li><strong>Fair (6-7x):</strong> C# (6.8x), V (6.6x), Go (6.1x)</li>
<li><strong>Poor:</strong> Julia (3.2x) - architecture optimization issue</li>
<li><strong>Failed:</strong> Crystal, TypeScript - no threading implementation</li>
</ol>

<p><strong>Notable Insights:</strong></p>
<ul>
<li><strong>JVM Excellence:</strong> Java and Kotlin show exceptional threading performance</li>
<li><strong>Nim Anomaly:</strong> Poor single-thread but excellent scaling (base time misleading)</li>
<li><strong>Swift Strong:</strong> Surprisingly good threading despite overall poor performance</li>
<li><strong>Go Disappointment:</strong> Poor scaling despite concurrency focus</li>
<li><strong>Hyper-Threading Benefit:</strong> C, Java, Kotlin get >10x speedup on 8-core/16-thread CPU</li>
<li><strong>Architecture Matters:</strong> Julia's poor showing specific to AMD Ryzen</li>
</ul>

<p><em>*Nim note: High base time suggests different algorithm or optimization level</em></p>
<hr>

<h2>8. GCC vs Clang Comparison</h2>
<ul>
<li><strong>C:</strong> Gcc (86.88s) vs Clang (88.64s) - GCC 2.0% faster</li>
<li><strong>C++:</strong> G++ (66.72s) vs Clang++ (70.66s) - GCC 5.9% faster</li>
<li><strong>Nim:</strong> Nim/GCC (138.7s) vs Nim/Clang (137.7s) - Clang 0.7% faster</li>
<li><strong>V:</strong> V/GCC (169.2s) vs V/Clang (179.9s) - GCC 6.3% faster</li>
<li><strong>Conclusion:</strong> GCC generally superior for raw performance</li>
</ul>

<hr>

<h2>9. OpenJDK vs GraalVM</h2>
<ul>
<li><strong>Runtime:</strong> OpenJDK (121.9s) < GraalVM/JIT (125.8s)</li>
<li><strong>Memory:</strong> Similar (328-356 MB)</li>
<li><strong>Wins:</strong> OpenJDK 3 wins, GraalVM 0 wins</li>
<li><strong>Insight:</strong> GraalVM JIT slightly slower in compute tasks</li>
</ul>

<hr>
<h2>10. Java vs Kotlin</h2>
<ul>
<li><strong>Runtime:</strong> Java (121.9s) vs Kotlin (121.3s) - essentially equal</li>
<li><strong>Memory:</strong> Java (327.6 MB) better than Kotlin (399.3 MB)</li>
<li><strong>Compilation:</strong> Java (2.93s) massively faster than Kotlin (17.91s)</li>
<li><strong>Expressiveness:</strong> Kotlin (22.6%) much better than Java (11.0%)</li>
</ul>

<hr>
<h2>11. C# JIT vs AOT</h2>
<ul>
<li><strong>Runtime:</strong> JIT (137.0s) faster than AOT (159.4s) - AOT 16% slower</li>
<li><strong>Memory:</strong> JIT (199.8 MB) vs AOT (202.7 MB) similar</li>
<li><strong>Compilation:</strong> JIT (4.46s) vs AOT (8.09s)</li>
<li><strong>Conclusion:</strong> JIT better for performance, AOT for startup/containers</li>
</ul>

<hr>
<h2>12. Node vs Bun vs Deno</h2>
<ul>
<li><strong>Runtime:</strong> Node (160.3s) < Bun/JIT (177.3s) < Deno (184.6s)</li>
<li><strong>Memory:</strong> Node (194.3 MB) < Bun (171.5 MB) < Deno (214.7 MB)</li>
<li><strong>Winner:</strong> Node.js still fastest runtime</li>
<li><strong>Trade-off:</strong> Bun faster startup, Node better sustained performance</li>
</ul>

<hr>
<h2>13. Go vs GccGo</h2>
<ul>
<li><strong>Runtime:</strong> Go (149.7s) faster than GccGo/Opt (190.6s) - 27% slower</li>
<li><strong>Memory:</strong> Go (125.4 MB) better than GccGo (183.8 MB)</li>
<li><strong>Compilation:</strong> Go (0.78s) massively faster than GccGo (8.71s)</li>
<li><strong>Conclusion:</strong> Standard Go compiler superior in every metric</li>
</ul>

<hr>
<h2>14. D Compilers: GDC vs LDC vs DMD</h2>
<ul>
<li><strong>Runtime:</strong> LDC (102.0s) << GDC (188.4s) < DMD (192.3s)</li>
<li><strong>Memory:</strong> LDC (49.1 MB) << GDC (188.4 MB) < DMD (192.3 MB)</li>
<li><strong>Clear Winner:</strong> LDC by huge margin (2x faster, 4x less memory)</li>
</ul>

<hr>
<h2>15. V GCC vs V Clang</h2>
<ul>
<li><strong>Runtime:</strong> V/GCC (169.2s) faster than V/Clang (179.9s) - 6% difference</li>
<li><strong>Memory:</strong> Similar (102-106 MB)</li>
<li><strong>Compilation:</strong> Similar (8.70s vs 8.10s)</li>
<li><strong>Conclusion:</strong> GCC backend consistently better for V</li>
</ul>

<hr>

<h2>16. Hacking Configurations Insights</h2>
<ul>
<li><strong>C/C++ MaxPerf-Hack:</strong> Up to 15% improvement with Ofast/aggressive opts</li>
<li><strong>Java Tuning:</strong> JVM flags can improve 5-10%</li>
<li><strong>Rust WMO/Unchecked:</strong> Minimal gains - safe Rust already optimal</li>
<li><strong>Swift Unchecked:</strong> Significant gains in some tests</li>
<li><strong>C# AOT-Extreme:</strong> Can approach JIT performance but not exceed</li>
<li><strong>Julia Optimized:</strong> Compiler flags help but architecture issues remain</li>
<li><strong>Key Finding:</strong> Most "hacked" configs show modest gains; compiler defaults are good</li>
</ul>

<hr>

<h2>17. Overall Insights & Final Rankings</h2>
<p><strong>Updated Surprising Findings:</strong></p>
<ol>
<li><strong>V Language Improvement:</strong> 18% faster than previous run</li>
<li><strong>Nim Strong Performance:</strong> Competitive with JVM languages</li>
<li><strong>Julia Ryzen Issues:</strong> Architecture-specific performance problems</li>
<li><strong>Crystal's Fatal Flaw:</strong> No multi-threading kills performance scaling</li>
<li><strong>Go's Concurrency Myth:</strong> Poor threading scaling despite reputation</li>
</ol>

<p><strong>Final Language Rankings (Updated):</strong></p>
<table>
<tr><th>Rank</th><th>Language</th><th>Medal</th><th>Score</th><th>Verdict</th></tr>
<tr><td>1</td><td>C++/G++</td><td>🥇</td><td>97/100</td><td>Performance King</td></tr>
<tr><td>2</td><td>C/Gcc</td><td>🥈</td><td>96/100</td><td>Raw Speed Dominance</td></tr>
<tr><td>3</td><td>Rust</td><td>🥉</td><td>93/100</td><td>Modern Safety Champion</td></tr>
<tr><td>4</td><td>D/LDC</td><td>🏅</td><td>90/100</td><td>Underrated Performer</td></tr>
<tr><td>5</td><td>Zig</td><td>🏅</td><td>87/100</td><td>Memory Efficiency Leader</td></tr>
<tr><td>6</td><td>Nim/Clang</td><td>✨</td><td>86/100</td><td>Surprise Contender</td></tr>
<tr><td>7</td><td>Crystal</td><td>💎</td><td>85/100</td><td>Expressive Single-thread</td></tr>
<tr><td>8</td><td>Java/OpenJDK</td><td>☕</td><td>84/100</td><td>Enterprise Workhorse</td></tr>
<tr><td>9</td><td>Kotlin/JVM</td><td>⚡</td><td>82/100</td><td>Modern Java Successor</td></tr>
<tr><td>10</td><td>Go</td><td>🐹</td><td>81/100</td><td>Concurrency Simplicity</td></tr>
<tr><td>11</td><td>C#/JIT</td><td>#️⃣</td><td>80/100</td><td>.NET Powerhouse</td></tr>
<tr><td>12</td><td>TypeScript/Node</td><td>📜</td><td>76/100</td><td>Web Dominance</td></tr>
<tr><td>13</td><td>V/GCC</td><td>🆕</td><td>69/100</td><td>Improving Rapidly</td></tr>
<tr><td>14</td><td>Julia/Default</td><td>🔬</td><td>63/100</td><td>Niche Performer</td></tr>
<tr><td>15</td><td>Swift</td><td>🍎</td><td>45/100</td><td>Apple-only Performance</td></tr>
</table>

<hr>

<h2>18. Practical Recommendations</h2>
<p><strong>For Maximum Performance:</strong> C++/G++ or C/Gcc</p>
<p><strong>For Safe Systems Programming:</strong> Rust or Zig</p>
<p><strong>For Scientific Computing:</strong> Julia (but test on your hardware)</p>
<p><strong>For Productivity + Performance:</strong> Nim or D/LDC</p>
<p><strong>For Web Services:</strong> Go or Node.js with TypeScript</p>
<p><strong>For Enterprise/Android:</strong> Java or Kotlin (choose based on team preference)</p>
<p><strong>For Windows/.NET:</strong> C# with JIT</p>
<p><strong>For Scripting with Performance:</strong> Crystal (if single-threaded)</p>
<p><strong>For Learning/Experimental:</strong> V (watch for improvements)</p>
<p><strong>For Apple Ecosystem Only:</strong> Swift (accept performance trade-offs)</p>

<hr>

<h2>Updated Subjective Opinion</h2>
<p><em>The February 4 update brings new insights and confirms some patterns:</em></p>

<ol>
<li><strong>V Language is improving</strong> - 18% speedup is significant progress.</li>
<li><strong>Nim is the real surprise</strong> - competitive performance with excellent expressiveness.</li>
<li><strong>Julia's architecture sensitivity</strong> is concerning for cross-platform work.</li>
<li><strong>Crystal needs threading urgently</strong> - otherwise niche-bound.</li>
<li><strong>GCC dominance continues</strong> - Clang needs to catch up on AMD optimization.</li>
<li><strong>Java's threading excellence</strong> remains underappreciated.</li>
<li><strong>Go's goroutines ≠ threads</strong> - don't expect C++-level scaling.</li>
</ol>

<p><strong>Most Impressive:</strong> Nim - balances performance, safety, and expressiveness beautifully.</p>
<p><strong>Most Improved:</strong> V - showing rapid development progress.</p>
<p><strong>Most Concerning:</strong> Swift - such poor performance on non-Apple hardware raises questions.</p>
<p><strong>Practical Winner:</strong> Still Rust - best overall package.</p>
<p><strong>Dark Horse:</strong> D/LDC - if it had Rust's ecosystem, it would be a top contender.</p>

<p><em>Final Thought: No language wins everywhere. Choose based on your specific needs, team skills, and ecosystem requirements. Benchmarks guide, but don't dictate.</em></p>

<p><em>Disclaimer: This analysis represents AI Tool interpretation of benchmark data from February 4, 2026. Performance characteristics evolve. Test with your specific workload and environment.</em></p>
</div>
    `);
}
