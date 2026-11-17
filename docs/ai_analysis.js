function ai_analys($results) {
    $results.append(`
<div class="benchmark-analysis">
<h1>🔍 Comprehensive AI Analysis: Programming Language Benchmarks 2026-11-04</h1>

<p><strong>Test Environment:</strong> AMD Ryzen 7 3800X (8-core/16-thread) | 78GB RAM | x86_64-linux-gnu<br>
<strong>Scope:</strong> 27 languages · 50 benchmarks · 31 production configurations · 115 measured configurations including hacks</p>

<p><strong>How to read this:</strong></p>
<ul>
<li>All numbers are for the <strong>production (safe release) configuration</strong> unless stated otherwise. When a language has several production configs, its <strong>fastest</strong> one is used.</li>
<li>25 languages have a production config. JavaScript and PHP have only "hack" configs and are not ranked, but they are discussed.</li>
<li><strong>Total</strong> = the sum of all 50 runtimes. <strong>Geomean</strong> = the geometric mean of "time ÷ fastest time" over the 50 tests (1.00 = fastest everywhere). Geomean is not dominated by one slow test. Total is.</li>
<li>8 of the 50 tests measure <strong>libraries</strong> (Base64, JSON, CSV, regex). The other 42 are <strong>pure algorithms</strong>. The two groups tell different stories, and this analysis keeps them apart.</li>
<li>Cross-language comparisons are approximate. Comparing compilers and runtimes <em>of the same language</em> is the fairest test in this suite.</li>
</ul>

<hr>

<h2>📊 The Big Picture</h2>

<h3>Runtime Tiers (Total seconds, best production config)</h3>
<pre>
🚀 TIER 0 (The Outlier)               38s        Goose
🏁 TIER 1 (The Speed Demons)          54-60s     Rust, C, C++, Gossamer
🏁 TIER 2 (The Systems Contenders)    63-80s     Zig, Odin, C3, D, Java, Crystal, Mojo
🏁 TIER 3 (The Managed Middle)        81-108s    Kotlin, C#, Go, Julia, Scala, F#, V, Nim
🏁 TIER 4 (The JIT &amp; String Trouble)  120-205s   TypeScript, Dart, Swift
🏁 TIER 5 (The Dynamic Languages)     297-301s   Ruby (Spinel), Python (PyPy)
   unranked                                      JavaScript/Bun 121.8s · PHP 505.4s
</pre>

<p>The field is tight: <strong>20 of 25 languages finish within 2× of Rust</strong>. Python/PyPy is 5.5× slower than Rust and 7.9× slower than Goose.</p>

<h3>The Full Table</h3>

<p>Total runtime is easy to read, but it is fragile. A single slow test can add 20 seconds. This table adds three robust measures. <strong>Top</strong> = number of tests within 1.25× of the fastest. <strong>&gt;5×</strong> = number of tests more than 5× slower than the fastest (blow-ups).</p>

<table>
<tr><th>#</th><th>Language</th><th>Config</th><th>Total, s</th><th>Geomean</th><th>Median</th><th>Top</th><th>&gt;5×</th><th>Wins</th><th>Last</th></tr>
<tr><td>1</td><td><strong>Goose</strong></td><td>Goose/Clang</td><td>38.3</td><td>1.18</td><td>1.01</td><td>40</td><td>1</td><td>24</td><td>0</td></tr>
<tr><td>2</td><td><strong>Rust</strong></td><td>Rust</td><td>54.53</td><td>1.81</td><td>1.39</td><td>18</td><td>3</td><td>1</td><td>0</td></tr>
<tr><td>3</td><td><strong>C</strong></td><td>C/Clang</td><td>55.01</td><td>1.75</td><td>1.29</td><td>23</td><td>5</td><td>7</td><td>0</td></tr>
<tr><td>4</td><td><strong>C++</strong></td><td>C++/Clang++</td><td>59.07</td><td>1.83</td><td>1.38</td><td>19</td><td>5</td><td>4</td><td>0</td></tr>
<tr><td>5</td><td><strong>Gossamer</strong></td><td>Gossamer</td><td>60.0</td><td>2.08</td><td>1.77</td><td>12</td><td>5</td><td>0</td><td>0</td></tr>
<tr><td>6</td><td><strong>Zig</strong></td><td>Zig</td><td>63.81</td><td>2.28</td><td>1.85</td><td>9</td><td>7</td><td>1</td><td>0</td></tr>
<tr><td>7</td><td><strong>Odin</strong></td><td>Odin/Default</td><td>70.03</td><td>2.48</td><td>1.50</td><td>13</td><td>10</td><td>0</td><td>0</td></tr>
<tr><td>8</td><td><strong>C3</strong></td><td>C3</td><td>71.89</td><td>2.46</td><td>1.66</td><td>13</td><td>12</td><td>1</td><td>0</td></tr>
<tr><td>9</td><td><strong>D</strong></td><td>D/LDC</td><td>75.86</td><td>2.56</td><td>2.39</td><td>14</td><td>13</td><td>2</td><td>0</td></tr>
<tr><td>10</td><td><strong>Java</strong></td><td>Java/GraalVM/JIT</td><td>76.61</td><td>2.45</td><td>1.97</td><td>10</td><td>8</td><td>0</td><td>1</td></tr>
<tr><td>11</td><td><strong>Crystal</strong></td><td>Crystal</td><td>78.51</td><td>2.82</td><td>2.75</td><td>4</td><td>13</td><td>0</td><td>0</td></tr>
<tr><td>12</td><td><strong>Mojo</strong></td><td>Mojo</td><td>79.5</td><td>2.45</td><td>2.10</td><td>7</td><td>8</td><td>2</td><td>0</td></tr>
<tr><td>13</td><td><strong>Kotlin</strong></td><td>Kotlin/JVM/Default</td><td>81.92</td><td>2.43</td><td>2.00</td><td>10</td><td>7</td><td>2</td><td>0</td></tr>
<tr><td>14</td><td><strong>C#</strong></td><td>C#/JIT</td><td>82.71</td><td>2.75</td><td>1.97</td><td>7</td><td>11</td><td>0</td><td>0</td></tr>
<tr><td>15</td><td><strong>Go</strong></td><td>Go</td><td>85.07</td><td>2.80</td><td>2.09</td><td>8</td><td>12</td><td>0</td><td>0</td></tr>
<tr><td>16</td><td><strong>Julia</strong></td><td>Julia/Default</td><td>90.18</td><td>3.07</td><td>2.81</td><td>5</td><td>10</td><td>2</td><td>0</td></tr>
<tr><td>17</td><td><strong>Scala</strong></td><td>Scala/JVM/Default</td><td>90.25</td><td>2.75</td><td>2.15</td><td>9</td><td>9</td><td>1</td><td>2</td></tr>
<tr><td>18</td><td><strong>F#</strong></td><td>F#/JIT</td><td>92.18</td><td>3.00</td><td>2.25</td><td>9</td><td>14</td><td>0</td><td>0</td></tr>
<tr><td>19</td><td><strong>V</strong></td><td>V/Clang</td><td>98.32</td><td>3.04</td><td>2.66</td><td>11</td><td>15</td><td>2</td><td>0</td></tr>
<tr><td>20</td><td><strong>Nim</strong></td><td>Nim/Clang</td><td>107.5</td><td>2.99</td><td>2.16</td><td>9</td><td>12</td><td>1</td><td>1</td></tr>
<tr><td>21</td><td><strong>TypeScript</strong></td><td>TypeScript/Bun/JIT</td><td>120.4</td><td>3.82</td><td>3.48</td><td>2</td><td>16</td><td>0</td><td>3</td></tr>
<tr><td>22</td><td><strong>Dart</strong></td><td>Dart/JIT</td><td>177.2</td><td>5.66</td><td>4.59</td><td>2</td><td>24</td><td>0</td><td>5</td></tr>
<tr><td>23</td><td><strong>Swift</strong></td><td>Swift</td><td>204.8</td><td>4.55</td><td>3.04</td><td>8</td><td>19</td><td>0</td><td>7</td></tr>
<tr><td>24</td><td><strong>Ruby</strong></td><td>Ruby/Spinel/Clang</td><td>297.5</td><td>7.18</td><td>7.76</td><td>2</td><td>32</td><td>0</td><td>10</td></tr>
<tr><td>25</td><td><strong>Python</strong></td><td>Python/PYPY</td><td>301.0</td><td>9.21</td><td>10.97</td><td>1</td><td>33</td><td>0</td><td>21</td></tr>
</table>

<p><strong>What the robust columns show:</strong></p>
<ul>
<li><strong>Rust, C and C++ are a statistical tie.</strong> By total Rust leads (54.53 vs 55.01). By geomean C leads (1.75 vs 1.81). C++ trails by 8% on total but is within 5% on geomean.</li>
<li><strong>Kotlin is a better performer than its total suggests.</strong> Geomean 2.43 puts it 7th, ahead of Java, Mojo, C3, Odin and D. One regex test (Etc::LogParser, 14.8s) costs it about 14 seconds of total.</li>
<li><strong>Swift and Dart swap places.</strong> Swift has the worse total (204.8 vs 177.2) but the better geomean (4.55 vs 5.66). Swift is fast at most things and catastrophic at a few. Dart is moderately slow almost everywhere.</li>
<li><strong>Odin has the 5th-best median (1.50)</strong>, behind only Goose, C, C++ and Rust, but 10 blow-ups. It is excellent on typical code and weak on a handful of library-heavy tests.</li>
</ul>

<hr>

<h2>🔬 Algorithms vs Libraries: Two Different Races</h2>

<p>Split the suite into the 42 algorithmic tests and the 8 library tests (Base64 ×2, JSON ×3, CSV, Etc::LogParser, Template::Regex) and the middle of the table reshuffles:</p>

<table>
<tr><th>Language</th><th>Algorithms (42 tests), s</th><th>Libraries (8 tests), s</th><th>Library share of total</th></tr>
<tr><td>Goose</td><td>34.84</td><td>3.47</td><td>9%</td></tr>
<tr><td>Rust</td><td>46.55</td><td>7.99</td><td>15%</td></tr>
<tr><td>C</td><td>49.77</td><td>5.23</td><td>10%</td></tr>
<tr><td>C++</td><td>49.81</td><td>9.26</td><td>16%</td></tr>
<tr><td>Gossamer</td><td>52.95</td><td>7.05</td><td>12%</td></tr>
<tr><td>Zig</td><td>53.48</td><td>10.33</td><td>16%</td></tr>
<tr><td><strong>Kotlin</strong></td><td><strong>53.77</strong></td><td>28.15</td><td>34%</td></tr>
<tr><td><strong>Java (GraalVM)</strong></td><td><strong>54.61</strong></td><td>22.00</td><td>29%</td></tr>
<tr><td>Go</td><td>57.91</td><td>27.15</td><td>32%</td></tr>
<tr><td>Nim</td><td>62.96</td><td>44.57</td><td>41%</td></tr>
<tr><td><strong>Swift</strong></td><td>95.21</td><td><strong>109.56</strong></td><td><strong>54%</strong></td></tr>
<tr><td><strong>TypeScript (Bun)</strong></td><td>111.33</td><td><strong>9.07</strong></td><td>8%</td></tr>
<tr><td>Dart</td><td>120.52</td><td>56.67</td><td>32%</td></tr>
<tr><td>PHP (unranked)</td><td>476.54</td><td>28.81</td><td>6%</td></tr>
</table>

<ul>
<li><strong>On pure algorithms the JVM is Tier 1.5.</strong> Kotlin (53.77s) and Java (54.61s) are level with Zig (53.48s) and ahead of C3, Odin, Go and D. Their totals are pulled down by JVM regex (Etc::LogParser: Kotlin 14.8s, Java 8.6s) and CSV parsing (~6s).</li>
<li><strong>Swift spends more than half its time in 8 tests.</strong> CSV::Parse alone is 45.7s, 97× slower than the fastest. Template::Regex is 19.0s, Etc::LogParser 13.3s, and JSON parsing about 7s each. Its 42 algorithmic tests take 95s, between F# (70.7s) and TypeScript (111.3s).</li>
<li><strong>Bun's libraries are elite.</strong> TypeScript/Bun's library total (9.07s) is 5th-best in the suite, better than C++. Its slowness is entirely in the JIT-compiled algorithmic code.</li>
<li><strong>Go and Nim lose a third or more of their total to libraries.</strong> Go's Template::Regex is 10.8s and Json::ParseDom 3.7s. Without Template::Regex, Go finishes in 74.2s. Nim's pure-Nim regex costs 33.5s across two tests (Etc::LogParser 23.4s, last place; Template::Regex 10.2s). Without those two, Nim finishes in 74.0s.</li>
<li><strong>The C and C++ library wins are library wins.</strong> C uses yyjson and a SIMD Base64 library. C++ uses simdjson, RE2 and the same Base64 library. Rust's serde_json DOM parse (1.70s) is 20× slower than yyjson (0.086s). That is a crate choice, not a language property.</li>
</ul>

<hr>

<h2>🪿 Goose: The Outlier</h2>

<p><strong>Goose/Clang: 38.3s · geomean 1.18 · 24 wins · within 1.25× of the best on 40 of 50 tests · 26.5MB · +37.0% expressiveness</strong></p>

<p>Goose compiles to C and builds it with <code>cc -O2</code>. It is the fastest language in the suite by every measure. It wins 24 tests, 19 of them by 10% or more. Its median test is within 1% of the fastest. It is more than 3× slower than the leader on only one test (Base64::Decode, 0.79s vs 0.128s). No other language comes close to that consistency. C, the next most consistent, is within 1.25× on 23 tests.</p>

<p><strong>Where the margins come from.</strong> The biggest wins are allocation-heavy:</p>
<ul>
<li><strong>Compress::LZWDecode:</strong> 0.117s vs C 0.553s (4.7× ahead of 2nd place)</li>
<li><strong>Hash::SHA256:</strong> 0.268s vs Swift 0.972s, C 1.02s (3.6×; same algorithm as C, different generated code)</li>
<li><strong>Graph::AStar:</strong> 0.414s vs Mojo 0.882s, C 1.79s</li>
<li><strong>Calculator::Ast:</strong> 0.135s vs Java 0.286s, C 1.05s</li>
<li><strong>Binarytrees::Obj:</strong> 0.229s vs Kotlin 0.477s, C 2.47s, Rust 2.59s</li>
<li><strong>CSV::Parse:</strong> 0.473s vs Zig 0.946s</li>
</ul>

<p><strong>The fairness caveat.</strong> In the Goose source, Binarytrees::Obj builds the tree by pushing nodes into one growable array and holding references into it. Its LZW keeps all dictionary strings in a single byte buffer and uses slices into it. That is idiomatic Goose, because its value-oriented model makes it the natural way to write the code. But it is effectively an arena. Goose's Binarytrees::Obj (0.229s) is as fast as its Binarytrees::Arena (0.240s), while C pays 6× for per-node <code>malloc</code> (2.47s vs 0.424s). So part of Goose's lead is <strong>data layout encouraged by the language</strong>, not just better code generation. On pure compute (Matmul::Single, Mandelbrot, Spectralnorm, Fannkuch, Sort::Quick) Goose sits next to C and Rust, not far ahead of them.</p>

<p><strong>The backend matters too:</strong> Goose/GCC runs 44.96s (17% slower than Clang), and the Goose.go implementation runs 67.89s.</p>

<p><strong>Verdict:</strong> This is the result of the dataset. The honest reading is "a language whose default memory model produces cache-friendly layouts beats languages whose default is one heap allocation per object." That is a real lesson about language design. Goose is also young, and this suite measures nothing about its tooling, ecosystem or stability.</p>

<hr>

<h2>🏁 Tier 1: Rust, C, C++, Gossamer</h2>

<h3>🦀 Rust: The Fastest Classic Language</h3>
<p><strong>54.53s · geomean 1.81 · 29.5MB · 7.03s cold / 1.11s incremental compile · −24.6% expressiveness · 0 last places</strong></p>
<p>Rust has the lowest total of the established languages with safe, bounds-checked code. It wins only one test (Compress::BWTEncode) but is rarely far behind. Its two weak spots are libraries: Json::ParseDom 1.70s (serde_json) and Template::Regex 3.61s. Without them it would finish in 49.2s. Rust also has the cleanest PGO story in the suite (−4.4%). Its unsafe max-perf build gains only 1.8% (see the safety section).</p>

<h3>⚙️ C: The Baseline</h3>
<p><strong>55.01s · geomean 1.75 · 23.3MB (lowest) · 2.69s cold / 0.05s incremental · −126.8% expressiveness · 7 wins</strong></p>
<p>C has the lowest memory, the fastest incremental build, the best absolute 16-thread matmul (0.351s), and 7 wins. Most of them come from libraries (Base64 ×2, Json::ParseDom) or from simple loops (Sort::Quick, Graph::DFS, Distance::Jaro). Its weak spots are <code>qsort</code> in Sort::Self (1.99s, 17× Julia), per-node <code>malloc</code> in Binarytrees::Obj (2.47s), and string-heavy code (Etc::Words 1.98s, Distance::NGram 1.81s). The price is the 2nd-most verbose code in the suite.</p>

<h3>⚙️ C++: The Workhorse</h3>
<p><strong>59.07s · geomean 1.83 · 30.6MB · 5.98s cold / 0.73s incremental · +1.0% expressiveness · 4 wins · 0 tests worse than 10×</strong></p>
<p>C++ is as fast as C and Rust, has average expressiveness, and never blows up past 10×. Its slowest tests are Template::Regex (4.96s, even with RE2) and Brainfuck::Recursion (2.64s). Among the three classic Tier-1 languages it has the best balance of speed and conciseness.</p>

<h3>🌱 Gossamer: The All-Rounder</h3>
<p><strong>60.0s · geomean 2.08 · 39.5MB · 1.23s compile · +27.0% expressiveness · 0 last places · 0 tests worse than 10×</strong></p>
<p>Gossamer is the only language that combines Tier-1 speed, a sub-2-second build and top-third expressiveness. It never wins outright, but it is 2nd on Etc::Words, Etc::LogParser and Distance::NGram. Its worst test is Compress::LZWDecode (9.6× the leader). It compiles in a single step with no incremental mode (1.23s every time), and its binary is the largest of the native Tier-1 languages (4.6MB).</p>

<hr>

<h2>⚙️ Tier 2: The Systems Contenders</h2>

<h3>⚡ Zig</h3>
<p><strong>63.81s · 31.2MB · 20.37s compile (19.7s incremental) · −169.0% expressiveness (last)</strong></p>
<p>Zig is fast and lean. On the 42 algorithmic tests it is level with Kotlin and Java, and it wins Template::Regex. Its library weak spots are Base64 (2.73s encode, 27× C). Its costs are the most verbose code in the suite (279KB of source, 1.5× Crystal per unit of information) and a whole-program build that takes 20 seconds even after a one-line change. Its <strong>ReleaseSafe</strong> checks cost 20% (see the safety section).</p>

<h3>🔷 Odin</h3>
<p><strong>70.03s · median 1.50 · 42.3MB · 7.64s compile · −37.4% expressiveness</strong></p>
<p>Odin is excellent on typical code (5th-best median) but has 6 tests worse than 10×. The worst is Sort::Self (4.23s, 36× Julia), and JSON is slow (~2–2.7s per test). It is 2nd on Compress::LZWEncode and Template::Regex.</p>

<h3>🔶 C3</h3>
<p><strong>71.89s · 28.1MB · 1.01s compile · −115.5% expressiveness · 1 win (Compress::BWTDecode)</strong></p>
<p>C3 is the fastest-compiling native systems language (1.01s, 2nd overall after Go) and has the 3rd-lowest memory. It is on the speed–compile Pareto frontier. Its library tests (JSON ~2.5s each, CSV 3.5s) cost it a place in Tier 1.</p>

<h3>🅳 D</h3>
<p><strong>D/LDC: 75.86s · 66.6MB · 37.17s cold compile (slowest) / 2.6GB compiler RSS · 2 wins</strong></p>
<p>D wins Brainfuck::Array and Matmul::T4 and is 2nd on Matmul::Single and Compress::HuffDecode. Its build is the heaviest in the suite. The backend matters a lot: DMD runs 118.55s, 56% slower than LDC.</p>

<h3>💎 Crystal</h3>
<p><strong>78.51s · 66.2MB · 22.82s compile · +44.0% expressiveness (#1) · 2.46× matmul scaling</strong></p>
<p>Crystal is the most concise language in the suite and is on the speed–expressiveness Pareto frontier together with Goose. It is consistent, with only 2 tests worse than 10×. But it rarely excels: only 4 tests are within 1.25× of the best. Its weaknesses are a 23-second build on every change and poor threading (1.7× on 4 threads, no gain past 8).</p>

<h3>🔥 Mojo</h3>
<p><strong>79.5s · 56.0MB · 28.9s compile / 2.9GB compiler RSS · 2 wins (Hash::CRC32, CLBG::Nbody)</strong></p>
<p>Mojo is strong on numeric and parsing work: 2nd on Etc::TextRaytracer, Graph::AStar and CLBG::Mandelbrot, and 3rd on Etc::LogParser. Two outliers hurt it. Base64::Decode takes 8.73s (68× C), and Matmul::Single takes 8.18s when nearly everyone else is near 5s. Its compiler is the most memory-hungry in the suite.</p>

<hr>

<h2>☕ Tier 3: The Managed Middle (and Two Natives)</h2>

<h3>The JVM: Java, Kotlin, Scala</h3>
<table>
<tr><th>Metric</th><th>Java (GraalVM)</th><th>Kotlin</th><th>Scala</th></tr>
<tr><td>Total, s</td><td><strong>76.61</strong></td><td>81.92</td><td>90.25</td></tr>
<tr><td>Algorithms only (42), s</td><td>54.61</td><td><strong>53.77</strong></td><td>61.62</td></tr>
<tr><td>Geomean</td><td>2.45</td><td><strong>2.43</strong></td><td>2.75</td></tr>
<tr><td>Memory, MB</td><td>407.6 (OpenJDK 335.6)</td><td><strong>328.1</strong></td><td>379.5</td></tr>
<tr><td>Cold compile, s</td><td><strong>4.40</strong></td><td>17.37</td><td>10.74</td></tr>
<tr><td>Expressiveness</td><td>−1.3%</td><td>+28.0%</td><td><strong>+41.7%</strong></td></tr>
<tr><td>Matmul T16</td><td>0.396s (12.6×)</td><td><strong>0.373s (13.2×)</strong></td><td>0.483s (10.2×)</td></tr>
<tr><td>Wins / Last</td><td>0 / 1</td><td><strong>2 / 0</strong></td><td>1 / 2</td></tr>
</table>
<p>The JVM is strongest on allocation and dispatch. Kotlin and Scala are 2nd and 3rd on Binarytrees::Obj (0.477s, 5× faster than C's <code>malloc</code>) and on Sort::Self. Kotlin wins Etc::CacheSimulation and Matmul::T8, and is 2nd on Calculator::Interpreter. Its weak spots are regex (Etc::LogParser 8.6–14.8s) and CSV (~6s). GraalVM's JIT is 7–9% faster than OpenJDK for all three languages (Kotlin/GraalVM 76.16s, Scala/GraalVM 83.09s).</p>

<h3>.NET: C# and F#</h3>
<p><strong>C#/JIT: 82.71s · 108.6MB · 2.18s compile · +5.5% · F#/JIT: 92.18s · 120.7MB · 4.45s · +22.5%</strong></p>
<p>Both have 0 last places and both are hurt by the same libraries: Template::Regex (C# 8.19s, F# 8.92s) and CSV::Parse (~6s). C#'s other outlier is Binarytrees::Obj (4.58s, 20× the leader). C# has the best runtime/memory/compile balance among the managed runtimes.</p>

<h3>🐹 Go</h3>
<p><strong>85.07s (74.2s without Template::Regex) · 67.7MB · 0.79s cold / 0.31s incremental (fastest) · +26.8% · 10.2× scaling</strong></p>
<p>Go has the fastest compiler in the suite by a wide margin, good expressiveness (lowest boilerplate ratio of any language, 3.99) and solid parallel scaling. Its time is concentrated in libraries: Template::Regex 10.84s (13× the leader) and Json::ParseDom 3.73s (43×). Etc::LogParser is fast (0.80s). <em>Note: Go switched to json/v2 after this run, so its JSON results should change in the next one.</em></p>

<h3>🔬 Julia</h3>
<p><strong>90.18s · 479.6MB (highest) · no build step · 2 wins (Sort::Self, CLBG::Mandelbrot)</strong></p>
<p>Julia wins Sort::Self by a mile (0.118s vs C's 1.99s) because its standard <code>sort</code> picks a specialized algorithm for integer arrays. That is a library win, not raw execution speed. Its weak spots are Base64 (4.38s encode) and Json::Generate (4.43s). Memory is the price: Julia never uses less than 389MB, even on the smallest test.</p>

<h3>🟦 V</h3>
<p><strong>V/Clang: 98.32s · 70.4MB · 5.10s compile · −5.7% · 2 wins (CLBG::Fannkuchredux, CLBG::Spectralnorm)</strong></p>
<p>V is very good at tight numeric loops, but 8 tests are more than 10× slower than the best. CSV::Parse (7.8s), Maze::AStar (6.8s) and Etc::LogParser (5.9s) cost it about 20 seconds.</p>

<h3>👑 Nim</h3>
<p><strong>Nim/Clang: 107.5s (74.0s without the two regex tests) · 50.3MB · 2.46s compile · +38.1% · 1 win (Brainfuck::Recursion)</strong></p>
<p>Nim is the clearest example of a language held back by one library. Its pure-Nim regex package costs 33.5 seconds in two tests and gives it its only last place (Etc::LogParser, 119× slower than the leader). Without regex, Nim would sit in Tier 2 next to Odin and C3. It combines that with fast compiles, low memory and top-4 conciseness. Its release build also stops scaling after 8 threads (T8 0.93s, T16 0.95s). The <code>-d:danger</code> build scales 14.8×.</p>

<hr>

<h2>🐢 Tiers 4–5: JIT, Strings and Dynamic Languages</h2>

<h3>📜 TypeScript / JavaScript</h3>
<p><strong>TypeScript/Bun: 120.4s · JS/Bun: 121.8s · 219.7MB · single-threaded</strong></p>
<p>Bun's libraries are first-class (8 library tests in 9.07s). Its algorithmic code is about 2× slower than the JVM's. <strong>Types cost nothing at runtime:</strong> TypeScript and JavaScript are within about 1% on Bun and Node. Deno is the exception, where TypeScript is 7% slower. There is no worker parallelism here, so matmul does not scale at all.</p>

<h3>🎯 Dart</h3>
<p><strong>Dart/JIT: 177.2s · 325.9MB · 5 last places</strong></p>
<p>Dart is moderately slow almost everywhere (only 2 tests within 1.25× of the best) and very slow on Base64 (9.7s / 8.9s, last on both). Its JIT build is 11% faster than its AOT build (196.1s) but uses 3× the memory (AOT: 109.5MB). The JIT VM never uses less than 279MB.</p>

<h3>🍎 Swift</h3>
<p><strong>204.8s (95.2s on the 42 algorithmic tests) · 65.1MB · 24.11s compile · 7 last places · 11.5× scaling</strong></p>
<p>Swift is two languages in one. Numeric Swift is competitive: 2nd on Hash::SHA256 (0.972s), close to C on matmul, and it scales 11.5×. String-processing Swift on Linux is the weakest in the suite: CSV::Parse 45.7s, Template::Regex 19.0s, Etc::LogParser 13.3s, Template::Parse 11.8s, Json::Generate 10.2s. It is last on six string tests. <code>-Ounchecked</code> removes 13s from CSV::Parse alone, so part of the cost is runtime checks in string code.</p>

<h3>💎 Ruby</h3>
<p><strong>Ruby/Spinel: 297.5s · TruffleRuby: 329.9s · CRuby 4 + YJIT: 2410.7s</strong></p>
<p>Spinel, an ahead-of-time Ruby compiler, is <strong>8.1× faster than CRuby with YJIT</strong>, slightly ahead of TruffleRuby, and uses 6× less memory than TruffleRuby (254.5MB vs 1486MB). Its geomean (7.18) is clearly better than PyPy's (9.21). Its outliers are Etc::TextRaytracer (62.7s) and Compress::BWTEncode (27.4s). Ruby is the #3 most concise language (+39.9%).</p>

<h3>🐍 Python</h3>
<p><strong>Python/PyPy: 301.0s · geomean 9.21 · 216.8MB · 21 last places</strong></p>
<p>PyPy is about 11× slower than the leader on its median test. Threads make it slower, not faster: Matmul::T4 takes 23.9s against 13.5s single-threaded, because the GIL serializes the work. Its closest result is CLBG::Mandelbrot (1.22× the leader).</p>

<h3>🐘 PHP (unranked)</h3>
<p><strong>PHP 8.5: 505.4s · 131.1MB</strong></p>
<p>Pure-PHP algorithms are the slowest code in the suite apart from CRuby (476.5s for the 42 algorithmic tests). PHP's C-implemented built-ins, however, are top-tier. Base64 encode and decode (0.104s / 0.118s) match C's SIMD library, and its 8 library tests take 28.8s, less than Python's 37.9s.</p>

<hr>

<h2>🧠 Memory: The Hidden Tax</h2>

<p>Average peak RSS per test, best config:</p>
<pre>
💎 SUB-32MB CLUB        C (23.3), Goose (26.5), C3 (28.1), Rust (29.5), C++ (30.6), Zig (31.2)
📦 39-71MB ZONE         Gossamer (39.5), Odin (42.3), Nim (50.3), Mojo (56.0), Swift (65.1),
                        Crystal (66.2), D (66.6), Go (67.7), V (70.4)
🏛️ 108-121MB REALM      C# (108.6), F# (120.7)
🔥 216-480MB BEASTS      Python (216.8), TypeScript/Bun (219.7), Ruby/Spinel (254.5), Dart/JIT (325.9),
                        Kotlin (328.1), Scala (379.5), Java/GraalVM (407.6), Julia (479.6)
</pre>

<p><strong>Runtime floors decide the upper tiers.</strong> On the smallest test, native languages use 2.5–7.5MB. The managed runtimes never go below their floor: Julia 389MB, Dart/JIT 279MB, Java/GraalVM 187MB, Python/PyPy 89MB, Kotlin 62MB. For small workloads these languages pay mostly for the runtime, not for the data.</p>

<p><strong>Configuration matters more than language:</strong></p>
<ul>
<li><strong>Java/OpenJDK with Serial GC:</strong> 167.9MB at 83.41s, vs 335.6MB at 83.57s with the default GC. Same speed, half the memory. On GraalVM, Serial GC is both faster (75.30s) and lighter (322.8MB).</li>
<li><strong>Kotlin/Scala "Max" heap flags:</strong> 4.5GB of memory for no speed gain (±1.5%).</li>
<li><strong>Dart AOT</strong> uses 109.5MB vs 325.9MB for JIT. <strong>C# AOT</strong> uses 84.4MB vs 108.6MB for JIT.</li>
<li><strong>Nim ARC</strong> uses 38.0MB vs 50.3MB for the default ORC, and is 3% faster.</li>
<li><strong>Rust/WASM in Node</strong> uses 101MB (WasmEdge 76.7MB), vs 29.5MB native and 270.5MB for TypeScript on Node.</li>
</ul>

<hr>

<h2>⚡ Scaling: Who Actually Uses Your 16 Cores?</h2>

<p>Naive matrix multiplication on 1 and 16 threads (8 cores / 16 threads, so a realistic ideal is 12–16×). The table is sorted by <strong>absolute 16-thread time</strong>, because a high speedup from a slow single-threaded baseline is not a win.</p>

<table>
<tr><th>Language</th><th>1 thread, s</th><th>16 threads, s</th><th>Speedup</th><th>Verdict</th></tr>
<tr><td><strong>C/Clang</strong></td><td>4.94</td><td><strong>0.351</strong></td><td>14.1×</td><td>🏆 Fastest and near-ideal</td></tr>
<tr><td><strong>Kotlin</strong></td><td>4.94</td><td>0.373</td><td>13.2×</td><td>✅ Excellent</td></tr>
<tr><td>Java/GraalVM</td><td>4.97</td><td>0.396</td><td>12.6×</td><td>✅ Excellent</td></tr>
<tr><td>C++/Clang++</td><td>4.93</td><td>0.404</td><td>12.2×</td><td>✅ Excellent</td></tr>
<tr><td>Swift</td><td>4.98</td><td>0.434</td><td>11.5×</td><td>✅ Very good</td></tr>
<tr><td>Goose</td><td>4.95</td><td>0.456</td><td>10.9×</td><td>✅ Good</td></tr>
<tr><td>Scala, Go, F#, Odin, C3, Rust, V, D</td><td>4.9–5.2</td><td>0.48–0.53</td><td>9.3–10.2×</td><td>✅ Good</td></tr>
<tr><td>Mojo</td><td>8.18</td><td>0.549</td><td>14.9×</td><td>🟡 Highest ratio, but from a slow 1-thread baseline</td></tr>
<tr><td>Gossamer, C#, Zig</td><td>5.0–5.2</td><td>0.58–0.65</td><td>7.8–8.8×</td><td>🟡 Decent</td></tr>
<tr><td>Ruby/Spinel, Nim, Julia</td><td>6.1–6.9</td><td>0.91–0.99</td><td>6.5–7.0×</td><td>🟡 Stalls after 8 threads</td></tr>
<tr><td>Crystal</td><td>5.04</td><td>2.05</td><td>2.5×</td><td>🔴 1.7× on 4 threads (3.02s), flat after 8</td></tr>
<tr><td>Dart/JIT</td><td>5.01</td><td>2.46</td><td>2.0×</td><td>🔴 16 threads slower than 8 (1.81s)</td></tr>
<tr><td>TypeScript, JavaScript, Rust/WASM</td><td>~5.1</td><td>~5.1</td><td>1.0×</td><td>⚫ Single-threaded</td></tr>
<tr><td>Python/PyPy</td><td>13.53</td><td>13.85</td><td>1.0×</td><td>⚫ GIL. 4 threads take 23.9s</td></tr>
</table>

<p><strong>Single-threaded numeric code is a solved problem.</strong> 20 of the 25 production languages run Matmul::Single in 4.9–5.3s. Threading is where languages still differ.</p>

<hr>

<h2>📦 Compile Times: The Developer Experience Tax</h2>

<table>
<tr><th>Language</th><th>Cold, s</th><th>Incremental, s</th><th>Compiler RSS, MB</th><th>Binary, MB</th></tr>
<tr><td><strong>Go</strong></td><td><strong>0.79</strong></td><td>0.31</td><td>117</td><td>5.36</td></tr>
<tr><td>C3</td><td>1.01</td><td>1.01</td><td>372</td><td>1.71</td></tr>
<tr><td>Gossamer</td><td>1.23</td><td>1.23</td><td>146</td><td>4.63</td></tr>
<tr><td>C#</td><td>2.18</td><td>2.09</td><td>153</td><td>0.12 (IL)</td></tr>
<tr><td>Nim</td><td>2.46</td><td>1.69</td><td>148</td><td>1.02</td></tr>
<tr><td>C/Clang</td><td>2.69</td><td><strong>0.05</strong></td><td>123</td><td>0.48</td></tr>
<tr><td>Java</td><td>4.40</td><td>4.41</td><td>586</td><td>5.17 (jar)</td></tr>
<tr><td>Goose</td><td>4.44</td><td>4.44</td><td>167</td><td><strong>0.44</strong></td></tr>
<tr><td>F#</td><td>4.45</td><td>4.41</td><td>153</td><td>0.17 (IL)</td></tr>
<tr><td>V</td><td>5.10</td><td>5.10</td><td>146</td><td>0.64</td></tr>
<tr><td>C++/Clang++</td><td>5.98</td><td>0.73</td><td>290</td><td>1.02</td></tr>
<tr><td>Rust</td><td>7.03</td><td>1.11</td><td>618</td><td>3.57</td></tr>
<tr><td>Odin</td><td>7.64</td><td>7.65</td><td>417</td><td>0.73</td></tr>
<tr><td>Ruby/Spinel</td><td>9.49</td><td>9.48</td><td>186</td><td>1.93</td></tr>
<tr><td>Scala</td><td>10.74</td><td>5.95</td><td>1216</td><td>12.47 (jar)</td></tr>
<tr><td>Kotlin</td><td>17.37</td><td>17.41</td><td>1308</td><td>12.14 (jar)</td></tr>
<tr><td>Zig</td><td>20.37</td><td>19.68</td><td>596</td><td>5.75</td></tr>
<tr><td>Crystal</td><td>22.82</td><td>22.85</td><td>589</td><td>3.50</td></tr>
<tr><td>Swift</td><td>24.11</td><td>11.62</td><td>554</td><td>10.88</td></tr>
<tr><td>Mojo</td><td>28.90</td><td>27.76</td><td><strong>2919</strong></td><td>0.96</td></tr>
<tr><td>D/LDC</td><td><strong>37.17</strong></td><td>12.31</td><td>2624</td><td>2.67</td></tr>
</table>
<p><em>No build step: Julia, TypeScript/Bun, Dart/JIT, Python/PyPy. TypeScript on Node needs <code>tsc</code> (1.46s).</em></p>

<ul>
<li><strong>Only Go, C, C++ and Rust get a big win from incremental builds</strong> (0.05–1.11s after a one-file change). Swift, D and Scala roughly halve their build time. Most others rebuild the whole program every time. That is cheap for C3 and Gossamer (~1s) and painful for Zig (19.7s), Crystal (22.9s) and Mojo (27.8s).</li>
<li><strong>Wall time hides CPU cost.</strong> Rust's 7.03s cold build burns 54s of CPU time, and Kotlin, Scala and Mojo each burn over 60s. On a laptop with fewer cores these builds get much slower.</li>
<li><strong>GCC compiles 3× slower than Clang</strong> for both C (8.03s vs 2.69s) and C++ (17.39s vs 5.98s) and produces no faster code (next section).</li>
</ul>

<hr>

<h2>✍️ Expressiveness: The Code You Don't Write</h2>

<p>Expressiveness score = (boilerplate vs average) × (lines vs average)<sup>1.5</sup>, where boilerplate = source size ÷ gzip size. It measures <strong>conciseness</strong>, not clarity.</p>

<pre>
🎯 TIER S (Elite)         Crystal (+44.0%), Scala (+41.7%), Ruby (+39.9%), Nim (+38.1%), Goose (+37.0%)
📝 TIER A (Expressive)    Kotlin (+28.0%), Python (+27.2%), Gossamer (+27.0%), Go (+26.8%), F# (+22.5%), Dart (+21.0%), Swift (+19.6%)
📄 TIER B (Average)       Julia (+12.6%), JavaScript (+11.0%), C# (+5.5%), TypeScript (+1.8%), C++ (+1.0%), Java (−1.3%), Mojo (−2.0%), V (−5.7%)
📜 TIER C (Verbose)       PHP (−16.4%), Rust (−24.6%), D (−33.7%), Odin (−37.4%)
📚 TIER D (Very Verbose)  C3 (−115.5%), C (−126.8%), Zig (−169.0%)
</pre>

<ul>
<li><strong>Fewest lines:</strong> Crystal (4,224). <strong>Most lines:</strong> C3 (9,262), C (9,167), Zig (9,116). The low-level languages need more than twice the code of the concise ones.</li>
<li><strong>Least boilerplate:</strong> Go (3.99). Go's lines are average-length but carry the most information per byte. <strong>Most boilerplate:</strong> Zig (6.54), PHP (5.73), Mojo (5.59).</li>
<li><strong>Types cost lines:</strong> TypeScript has 4.5% more lines than the same code in JavaScript (5,608 vs 5,366). The difference shows in expressiveness (+1.8% vs +11.0%) but not in runtime.</li>
</ul>

<hr>

<h2>📐 The Trade-off Map (Pareto Frontiers)</h2>

<p>A language is on a frontier if no other language beats it on <em>both</em> axes at once:</p>
<ul>
<li><strong>Speed × Conciseness:</strong> only <strong>Goose</strong> and <strong>Crystal</strong>. Every other language is both slower and more verbose than one of them.</li>
<li><strong>Speed × Memory:</strong> only <strong>Goose</strong> and <strong>C</strong>.</li>
<li><strong>Speed × Cold compile:</strong> <strong>Goose → C → Gossamer → C3 → Go</strong>. Each step buys faster builds with slower code.</li>
<li><strong>Speed × Incremental compile:</strong> <strong>Goose → Rust → C</strong>.</li>
</ul>

<p>Rust appears on only one frontier (speed × incremental build), but it is near the top of almost all of them.</p>

<hr>

<h2>🔧 Same Language, Different Toolchain (the Fairest Tests)</h2>

<table>
<tr><th>Language</th><th>Results (total, s)</th><th>Takeaway</th></tr>
<tr><td>C</td><td>Clang 55.01 · GCC 56.14 · mycc/LLVM 55.43 · mycc/QBE 76.57 · cproc/QBE 87.35</td><td>A hobby compiler on LLVM matches Clang within 1%. QBE costs 38–59%. The backend is everything.</td></tr>
<tr><td>C++</td><td>Clang++ 59.07 · G++ 59.26</td><td>Tie. Clang compiles 3× faster.</td></tr>
<tr><td>Goose</td><td>Clang 38.30 · GCC 44.96 · Goose.go 67.89</td><td>Same source, 1.8× spread.</td></tr>
<tr><td>D</td><td>LDC 75.86 · DMD 118.55</td><td>LLVM backend 1.56× faster.</td></tr>
<tr><td>Nim</td><td>NLVM 93.67 · GCC 101.88 · Clang 107.53 · C++ backend 135.78 (GCC) / 153.34 (Clang)</td><td>The non-default backends are faster. The C++ backend is much slower.</td></tr>
<tr><td>V</td><td>Clang 98.32 · GCC 100.25</td><td>Tie.</td></tr>
<tr><td>Java</td><td>GraalVM 76.61 · OpenJDK EA 81.92 · OpenJDK 83.57</td><td>GraalVM's JIT is 9% faster.</td></tr>
<tr><td>Kotlin / Scala</td><td>GraalVM 76.16 / 83.09 · JVM 81.92 / 90.25</td><td>Same 7–9% GraalVM gain.</td></tr>
<tr><td>C#</td><td>SC-JIT 81.33 · JIT 82.71 · AOT 100.87 · R2R 101.56</td><td><strong>JIT beats AOT by 22%.</strong> AOT loses most on Template::Regex (+3.5s) and Etc::TextRaytracer (+3.2s).</td></tr>
<tr><td>Dart</td><td>JIT 177.19 · AOT 196.11</td><td>JIT 11% faster, AOT 3× leaner.</td></tr>
<tr><td>TypeScript / JS</td><td>Bun 120.40 / 121.78 · Node 135.60 / 134.37 · Deno 168.78 / 157.69</td><td>Bun is fastest and leanest. Types are free on Bun and Node.</td></tr>
<tr><td>Rust → WASM</td><td>Node 71.98 · WasmEdge 73.06 · Wasmer 91.88 · Wasmtime 102.90 (native 54.53)</td><td>See below.</td></tr>
<tr><td>Ruby</td><td>Spinel 297.52 · TruffleRuby 329.85 · CRuby 4 + YJIT 2410.74</td><td>Implementation choice is an 8× decision.</td></tr>
<tr><td>Crystal</td><td>GCRY 77.08 · default 78.51 · <code>-O3</code> 263.89</td><td>Use <code>--release</code>. Plain <code>-O3</code> is 3.4× slower.</td></tr>
</table>

<p><strong>WASM is cheaper than it looks.</strong> Rust/WASM in Node is 32% slower than native Rust in total. But WASM here is single-threaded, and the four matmul tests account for 12.5 of the 17.5 seconds of difference. On the other 46 tests it is only <strong>11% slower than native</strong>. It is even faster than native on Binarytrees::Obj (1.04s vs 2.59s), Graph::AStar (0.70s vs 1.97s) and Json::ParseDom (0.81s vs 1.70s). All three are allocation-heavy, which suggests the native allocator, not rustc, is Rust's bottleneck on them.</p>

<hr>

<h2>🛡️ Safety and Unsafe Flags: What the Hacks Really Buy</h2>

<table>
<tr><th>Hack</th><th>Total, s</th><th>vs production</th><th>Where the gain comes from</th></tr>
<tr><td>Zig/Unchecked (ReleaseFast)</td><td>51.09</td><td><strong>−19.9%</strong></td><td>Spread across tests: Base64 −2.4s, LZWEncode −1.0s, Graph::AStar −0.9s</td></tr>
<tr><td>C3/Unsafe</td><td>58.36</td><td>−18.8%</td><td>5.9s of the 13.5s from matmul (vectorized), the rest spread out</td></tr>
<tr><td>Nim/Clang/Danger</td><td>91.10</td><td>−15.3%</td><td>Mostly regex: LogParser −4.1s, Template::Regex −2.1s, Brainfuck::Array −2.1s</td></tr>
<tr><td>C++/Clang++/Unsafe</td><td>50.42</td><td>−14.6%</td><td><strong>5.9s of the 8.6s from matmul</strong> (<code>-ffast-math</code>)</td></tr>
<tr><td>C/Gcc/Unsafe</td><td>48.72</td><td>−13.2%</td><td><strong>5.4s of the 7.4s from matmul</strong></td></tr>
<tr><td>C/Clang/Unsafe</td><td>47.89</td><td>−12.9%</td><td><strong>5.9s of the 7.1s from matmul</strong> (Matmul::Single 4.94s → 0.80s)</td></tr>
<tr><td>Swift/Unchecked</td><td>184.74</td><td>−9.8%</td><td>CSV::Parse alone −13.1s</td></tr>
<tr><td>Rust/PGO</td><td>52.11</td><td>−4.4%</td><td>Graph::AStar −0.85s, Brainfuck::Array −0.41s</td></tr>
<tr><td>Rust/MaxPerf/Unsafe</td><td>53.55</td><td>−1.8%</td><td>Small gains everywhere</td></tr>
<tr><td>Odin/MaxPerf (no bounds checks)</td><td>68.97</td><td>−1.5%</td><td>Small gains everywhere</td></tr>
<tr><td>Goose/Clang/Fast (<code>-O3</code>)</td><td>38.20</td><td>−0.3%</td><td>Nothing</td></tr>
<tr><td>D/LDC/MaxPerf</td><td>76.15</td><td>+0.4%</td><td>Nothing</td></tr>
<tr><td>C/Clang/PGO · C++/Clang++/PGO</td><td>57.00 · 61.49</td><td>+3.6% · +4.1%</td><td>PGO made Clang builds slower</td></tr>
<tr><td>C/Clang/Fast</td><td>59.35</td><td>+7.9%</td><td>Matmul::Single 4.94s → 8.24s</td></tr>
<tr><td>Crystal/O3</td><td>263.89</td><td>+236%</td><td>Wrong flag (see above)</td></tr>
</table>

<p><strong>The C/C++ "unsafe" gain is mostly not about safety.</strong> The unsafe builds add <code>-ffast-math</code>, which lets the compiler reorder the floating-point reduction in matmul and vectorize it. That is a 6× win on one kernel that changes floating-point semantics. Leaving out the four matmul tests:</p>

<pre>
                 production    unsafe/unchecked    gain
Rust             46.84s        45.85s (MaxPerf)    2.1%
C/Clang          47.74s        46.53s              2.5%
C++/Clang++      51.75s        49.02s              5.3%
C3               64.30s        56.62s              12%
Zig              55.61s        43.56s              21.7%
</pre>

<p><strong>Conclusions:</strong></p>
<ul>
<li><strong>Rust's safety tax is about 2%.</strong> Safe Rust (46.84s without matmul) is level with C compiled with <code>-ffast-math</code> and no stack protector (46.53s).</li>
<li><strong>Zig's ReleaseSafe checks cost about 20%.</strong> This is a real safety cost, and it is spread across the suite rather than concentrated in one kernel. Without them Zig would be the fastest classic language on the non-matmul tests.</li>
<li><strong>PGO is unreliable.</strong> It helps Rust (−4.4%) and G++ (−1.9%) and hurts Clang C and C++.</li>
<li><strong>Default release mode is the sweet spot</strong> for nearly everyone. Exotic flags (<code>-O3 -march=native</code> in C, <code>-O3</code> in Crystal, JVM heap tuning) were neutral or harmful.</li>
</ul>

<hr>

<h2>🏆 Wins and Last Places</h2>

<h3>Wins (out of 50; in brackets, wins by a margin of 10% or more)</h3>
<ol>
<li><strong>Goose</strong>: 24 (19) 🥇</li>
<li><strong>C</strong>: 7 (3) 🥈</li>
<li><strong>C++</strong>: 4 (2) 🥉</li>
<li>D, Mojo, Kotlin, Julia, V: 2 each</li>
<li>Rust, Zig, C3, Scala, Nim: 1 each</li>
</ol>
<p>Many wins outside Goose's are photo finishes. Scala's Matmul::Single (4.907s vs D's 4.931s), Mojo's Hash::CRC32 (0.2179s vs Zig's 0.218s) and Julia's Mandelbrot (0.888s vs Mojo's 0.891s) are effectively ties.</p>

<h3>Last places</h3>
<p>Python/PyPy 21 · Ruby/Spinel 10 · Swift 7 · Dart 5 · TypeScript 3 · Scala 2 (Graph::BFS, Distance::NGram) · Java 1 (CLBG::Mandelbrot) · Nim 1 (Etc::LogParser).</p>

<p>Being "last" is a weak signal by itself. Java's last place on Mandelbrot is 1.18s vs 0.89s, because every language is within 1.33× on that test. Nim's last place on Etc::LogParser is 119× the leader. The <strong>Top</strong> and <strong>&gt;5×</strong> columns in the main table say more.</p>

<h3>Widest and narrowest tests</h3>
<ul>
<li><strong>Widest spread (slowest ÷ fastest):</strong> Etc::LogParser 119×, CSV::Parse 97×, Base64::Encode 96×, Compress::LZWDecode 87×, Json::ParseDom 83×. Four of the five are library tests.</li>
<li><strong>Narrowest:</strong> CLBG::Mandelbrot 1.3×, Sort::Quick 2.4×, Matmul::Single 2.8×, CLBG::Fannkuchredux 3.0×.</li>
</ul>

<hr>

<h2>🎯 Rankings</h2>

<p>A single ranking is only as good as its weights, so here is one general ranking plus three use-case profiles. All inputs are log- or min-max-scaled to 0–100 within this dataset:</p>
<ul>
<li><strong>Speed</strong> = geomean ratio (log scale)</li>
<li><strong>Memory</strong> = average RSS (log scale)</li>
<li><strong>Compile</strong> = cold build time (log scale). Languages with no build step get a neutral 50.</li>
<li><strong>Expressiveness</strong> = min-max scaled</li>
<li><strong>Parallel</strong> = absolute Matmul::T16 time (log scale)</li>
</ul>
<p>"Wins" is not used, because it double-counts speed.</p>

<h3>General: Speed 35% · Memory 20% · Compile 15% · Expressiveness 15% · Parallel 15%</h3>
<table>
<tr><th>Rank</th><th>Language</th><th>Score</th><th>Archetype</th></tr>
<tr><td>1</td><td><strong>Goose</strong></td><td>90.9</td><td>🥇 The Outlier: fastest, lean, concise</td></tr>
<tr><td>2</td><td><strong>Gossamer</strong></td><td>81.9</td><td>🥈 The All-Rounder: Tier-1 speed, 1.2s builds, +27%</td></tr>
<tr><td>3</td><td><strong>C++</strong></td><td>79.2</td><td>🥉 The Workhorse: fast, average conciseness, no blow-ups</td></tr>
<tr><td>4</td><td><strong>C</strong></td><td>76.5</td><td>The Baseline: lowest memory, best threading, most verbose</td></tr>
<tr><td>5</td><td><strong>Rust</strong></td><td>76.2</td><td>The Safe Speedster: fastest classic language, ~2% safety tax</td></tr>
<tr><td>6</td><td><strong>Go</strong></td><td>75.7</td><td>The Productivity Engine: 0.8s builds, concise, held back by regex/JSON</td></tr>
<tr><td>7</td><td><strong>C3</strong></td><td>72.5</td><td>The Lean Native: 1s builds, 28MB, very verbose</td></tr>
<tr><td>8</td><td><strong>Nim</strong></td><td>70.2</td><td>The Expressive Native: Tier 2 without its regex library</td></tr>
<tr><td>9</td><td><strong>Odin</strong></td><td>67.3</td><td>The Solid Native: great median, a few deep holes</td></tr>
<tr><td>10</td><td><strong>C#</strong></td><td>66.3</td><td>The Balanced Managed Runtime</td></tr>
<tr><td>11</td><td><strong>V</strong></td><td>64.2</td><td>The Numeric Specialist: 2 wins, 8 deep holes</td></tr>
<tr><td>12</td><td><strong>F#</strong></td><td>63.5</td><td>The Functional .NET</td></tr>
<tr><td>13</td><td><strong>Mojo</strong></td><td>62.6</td><td>The Numeric Newcomer: fast kernels, heavy compiler</td></tr>
<tr><td>14</td><td><strong>Java</strong></td><td>58.2</td><td>The Enterprise JIT: Tier 1.5 on algorithms, 400MB</td></tr>
<tr><td>15</td><td><strong>Crystal</strong></td><td>57.9</td><td>The Poet: #1 conciseness, slow builds, poor threading</td></tr>
<tr><td>16</td><td><strong>D</strong></td><td>57.7</td><td>The Heavy Builder: fast code, slowest compiler</td></tr>
<tr><td>17</td><td><strong>Kotlin</strong></td><td>56.8</td><td>The Scaling Star: best managed geomean, 328MB, 17s builds</td></tr>
<tr><td>18</td><td><strong>Zig</strong></td><td>56.7</td><td>The Explicit One: fast, lean, most verbose, 20s builds</td></tr>
<tr><td>19</td><td><strong>Scala</strong></td><td>55.5</td><td>The Expressive JVM</td></tr>
<tr><td>20</td><td><strong>Swift</strong></td><td>54.3</td><td>The Split Personality: good numerics, worst strings</td></tr>
<tr><td>21</td><td><strong>Julia</strong></td><td>49.8</td><td>The Scientist: smart stdlib, 480MB</td></tr>
<tr><td>22</td><td><strong>TypeScript</strong></td><td>43.8</td><td>The Web Native: elite libraries, slow loops, one thread</td></tr>
<tr><td>23</td><td><strong>Ruby</strong></td><td>39.6</td><td>The AOT Experiment: Spinel 8× faster than CRuby</td></tr>
<tr><td>24</td><td><strong>Dart</strong></td><td>38.8</td><td>The UI Specialist</td></tr>
<tr><td>25</td><td><strong>Python</strong></td><td>26.6</td><td>The Ecosystem King: slowest, GIL-bound</td></tr>
</table>

<h3>Use-case profiles (top 5)</h3>
<table>
<tr><th>Profile</th><th>Weights</th><th>Top 5</th></tr>
<tr><td>🖥️ Systems / HPC</td><td>Speed 50 · Parallel 25 · Memory 25</td><td>Goose 97.1 · C 90.5 · C++ 86.1 · Rust 84.9 · Gossamer 78.4</td></tr>
<tr><td>☁️ Cloud services</td><td>Speed 25 · Memory 25 · Compile 30 · Expressiveness 20</td><td>Goose 84.8 · Gossamer 83.7 · Go 79.1 · Nim 72.9 · C3 / C++ 72.6</td></tr>
<tr><td>🧑‍💻 Productivity</td><td>Expressiveness 40 · Compile 30 · Speed 30</td><td>Goose 85.2 · Gossamer 85.1 · Go 84.2 · Nim 76.5 · C# 72.5</td></tr>
</table>

<p>Goose tops every profile. Gossamer is top-5 in all three. Go is top-3 in both developer-facing profiles. Zig drops to last under the productivity profile, and C to 20th.</p>

<hr>

<h2>💡 Strategic Recommendations</h2>

<h3>🔹 Systems Programming</h3>
<ul>
<li><strong>Rust</strong> for safety at about a 2% runtime cost, with real incremental builds.</li>
<li><strong>C or C++</strong> when you need the lowest memory or the best threading, and can supply safety yourself.</li>
<li><strong>C3 or Odin</strong> for C-like control with simpler builds (C3: 1s).</li>
<li><strong>Zig</strong> if you want explicit control and accept 20s rebuilds and the most verbose code. Know that ReleaseSafe costs about 20%.</li>
<li><strong>Goose</strong> if you can adopt a young language. Nothing in this data is faster.</li>
</ul>

<h3>🔹 Web Services / Microservices</h3>
<ul>
<li><strong>Go</strong> for 0.8s builds, low memory and good scaling. Benchmark its regex and JSON against your workload.</li>
<li><strong>Java or Kotlin on GraalVM</strong> for raw JVM throughput. Try Serial GC before buying more RAM.</li>
<li><strong>C#</strong> for the best balance among managed runtimes. Stay on the JIT unless startup time matters.</li>
<li><strong>Bun</strong> in JS/TS land: the fastest and leanest of the three runtimes, with excellent built-ins.</li>
</ul>

<h3>🔹 Developer Productivity</h3>
<ul>
<li><strong>Gossamer</strong> for Tier-1 speed, 1.2s builds and +27% conciseness.</li>
<li><strong>Crystal</strong> for maximum conciseness with Tier-2 speed, if you can live with 23s builds.</li>
<li><strong>Nim</strong> for concise native code. Bring your own regex if it matters.</li>
</ul>

<h3>🔹 Parallel Compute</h3>
<ul>
<li><strong>C, Kotlin, Java, C++, Swift</strong> are the fastest at 16 threads (0.35–0.43s).</li>
<li><strong>Avoid Crystal, Dart and single-threaded runtimes</strong> (TypeScript, Python, WASM) for CPU-bound parallel work.</li>
</ul>

<h3>🔹 Memory-Constrained Environments</h3>
<ul>
<li><strong>C, Goose, C3, Rust, C++, Zig</strong> (23–31MB average).</li>
<li><strong>Avoid Julia and Dart/JIT</strong> (runtime floors of 389MB and 279MB before any data) and <strong>the JVM with default GC</strong> (330–410MB on average). Java with Serial GC halves that, and Dart AOT cuts it to a third.</li>
</ul>

<hr>

<h2>🤯 What Surprised Me</h2>

<ul>
<li><strong>Goose's consistency, more than its speed.</strong> 40 of 50 tests within 1.25× of the best, and only one test worse than 3×. Outliers usually win big on a few tests. Goose wins small on almost all of them.</li>
<li><strong>The "unsafe C" speedup is mostly <code>-ffast-math</code> on one kernel.</strong> Without matmul, C's unsafe build gains 2.5%.</li>
<li><strong>Eight library tests decide the middle of the table.</strong> On pure algorithms Kotlin and Java sit with Zig. Swift spends 54% of its time in eight tests.</li>
<li><strong>Rust compiled to WASM beats native Rust</strong> on three allocation-heavy tests, and is only 11% slower on everything single-threaded.</li>
<li><strong>Same speed, half the memory.</strong> Java's Serial GC halves RSS at no runtime cost in this suite.</li>
<li><strong>JIT beats AOT inside the same language:</strong> C# by 22%, Dart by 11%.</li>
<li><strong>PHP's Base64 matches C's SIMD library.</strong> When PHP calls C, it is as fast as C.</li>
<li><strong>Threads make PyPy slower.</strong> Four threads take 77% longer than one.</li>
<li><strong>A hobby C compiler (mycc) on LLVM is within 1% of Clang.</strong> LLVM is still the great equalizer.</li>
</ul>

<hr>

<h2>🔮 Final Thoughts</h2>

<p><strong>1. Data layout beats codegen.</strong> Goose's largest wins come from allocation-heavy tests where its natural code is arena-shaped. The same pattern shows elsewhere: the JVM's bump allocator beats <code>malloc</code> 5× on Binarytrees::Obj, and Rust/WASM beats native Rust on three allocation-heavy tests. Arena-friendly defaults buy multiples. Compiler flags buy percent.</p>

<p><strong>2. Rust, C and C++ are tied.</strong> Which one "wins" depends on whether you sum or average. They are within 8% on total and 5% on geomean.</p>

<p><strong>3. Libraries move the needle more than compilers.</strong> Regex alone decides whether Nim is Tier 2 or Tier 3, whether Go is at 74s or 85s, and whether Kotlin is 7th or 13th. JSON and CSV decide most of Swift's ranking.</p>

<p><strong>4. Safety is cheap where the language is designed for it.</strong> Rust's checks cost about 2%. Zig's ReleaseSafe costs about 20%. C's "unsafe" gains are mostly fast-math, not removed checks.</p>

<p><strong>5. The toolchain is a language-sized decision.</strong> CRuby vs Spinel is 8×, DMD vs LDC 1.56×, QBE vs LLVM up to 1.6×, C# JIT vs AOT 1.22×. Choosing a language is only half the choice.</p>

<p><strong>6. Compile time is the great divider.</strong> Go, C3 and Gossamer build in about 1s. D, Mojo, Swift, Crystal and Zig take 20–37s, and most of them pay it again on every change.</p>

<p><strong>7. Single-threaded numerics are solved. Threading is not.</strong> 20 languages tie on Matmul::Single. At 16 threads the spread is 0.35s to 2.5s among languages that thread at all.</p>

<hr>

<p><em>This analysis represents AI Tool's interpretation of the benchmark data from 2026-11-04: one machine, one run per configuration, implementations ported from a Crystal original with LLM assistance and human review. The ranking weights are stated above and are one reasonable choice among many. Young toolchains (Goose, Gossamer, Mojo, Spinel) change quickly. Always test with your own workload.</em></p>

<p><em>— AI Tool, November 2026</em></p>
</div>
`);
}
