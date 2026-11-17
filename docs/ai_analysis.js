function ai_analys($results) {
    $results.append(`
<div class="benchmark-analysis">
<h1>🔍 Comprehensive AI Analysis: Programming Language Benchmarks 2026-11-04</h1>

<p><strong>Test Environment:</strong> AMD Ryzen 7 3800X (8-core/16-thread) | 78GB RAM | x86_64-linux-gnu<br>
<strong>Scope:</strong> 27 languages · 50 benchmarks · 31 production configurations · 115 configurations including hacks</p>

<p><strong>How to read this:</strong></p>
<ul>
<li>All numbers are for the <strong>production (safe release) configuration</strong> of each language unless stated otherwise. "Best config" means the fastest production configuration of a language.</li>
<li>25 languages have a production config and are ranked. JavaScript and PHP have only "hack" configs, so they are unranked but still discussed.</li>
<li><strong>Total</strong> = the sum of all 50 runtimes. <strong>Geomean</strong> = the geometric mean of "time ÷ fastest time" over the 50 tests (1.00 = fastest everywhere). Geomean is not dominated by one slow test. Total is.</li>
<li>8 of the 50 tests measure <strong>libraries</strong> (Base64, JSON, CSV, regex). The other 42 are <strong>pure algorithms</strong>. The two groups tell different stories.</li>
<li>Cross-language comparisons are approximate. Comparing compilers and runtimes <em>of the same language</em> is the fairest test in this suite.</li>
</ul>

<hr>

<h2>📊 The Big Picture</h2>

<ul>
<li><strong>A newcomer took the crown.</strong> Goose/Clang finishes the suite in <strong>38.3s</strong>, 30% faster than the next language, and wins 24 of 50 benchmarks.</li>
<li><strong>Rust is the fastest of the "classic" systems languages:</strong> 54.53s vs C/Clang 55.01s and C++/Clang++ 59.07s. In practice the three are tied.</li>
<li><strong>The middle class got much faster since March:</strong> Swift −38%, Odin −32%, Julia −27%, Go −26%, D −21%, Bun −19%, Zig −15%.</li>
<li><strong>One notable regression:</strong> Nim +24%, entirely from regex-heavy tests.</li>
<li><strong>Eight library tests decide the middle of the table.</strong> On pure algorithms, Kotlin and Java sit level with Zig.</li>
</ul>

<h3>Runtime Performance Clusters (Total Seconds, best config)</h3>
<pre>
🚀 TIER 0 (The Outlier)               38s        Goose
🏁 TIER 1 (The Speed Demons)          54-60s     Rust, C, C++, Gossamer
🏁 TIER 2 (The Systems Contenders)    63-80s     Zig, Odin, C3, D, Java/GraalVM, Crystal, Mojo
🏁 TIER 3 (The Managed Contenders)    81-108s    Kotlin, C#, Go, Julia, Scala, F#, V, Nim
🏁 TIER 4 (The JIT Challengers)       120-205s   TypeScript, JavaScript, Dart, Swift
🏁 TIER 5 (The Specialized)           297-505s   Ruby/Spinel, Python/PyPy, PHP
</pre>

<p><strong>The Gap:</strong> The field is remarkably compressed: 20 of 25 ranked languages finish within 2× of Rust. Python/PyPy (301s) is 5.5× slower than Rust and 7.9× slower than Goose.</p>

<h3>The Full Table</h3>

<p>Total runtime is easy to read, but it is fragile: a single slow test can add 20 seconds. This table adds robust measures. <strong>Top</strong> = number of tests within 1.25× of the fastest. <strong>&gt;5×</strong> = number of tests more than 5× slower than the fastest (blow-ups).</p>

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

<p>Split the suite into the 42 algorithmic tests and the 8 library tests (Base64 ×2, JSON ×3, CSV::Parse, Etc::LogParser, Template::Regex), and the middle of the table reshuffles. Ranks are among all 27 languages (lower is better).</p>

<table>
<tr><th>#</th><th>Language</th><th>Config</th><th>Total, s</th><th>Algorithms (42), s</th><th>Alg rank</th><th>Libraries (8), s</th><th>Lib rank</th><th>Library share</th></tr>
<tr><td>1</td><td><strong>Goose</strong></td><td>Goose/Clang</td><td>38.31</td><td>34.84</td><td>1</td><td>3.47</td><td>1</td><td>9%</td></tr>
<tr><td>2</td><td><strong>Rust</strong></td><td>Rust</td><td>54.53</td><td>46.55</td><td>2</td><td>7.99</td><td>4</td><td>15%</td></tr>
<tr><td>3</td><td><strong>C</strong></td><td>C/Clang</td><td>55.01</td><td>49.77</td><td>3</td><td>5.23</td><td>2</td><td>10%</td></tr>
<tr><td>4</td><td><strong>C++</strong></td><td>C++/Clang++</td><td>59.07</td><td>49.81</td><td>4</td><td>9.26</td><td>7</td><td>16%</td></tr>
<tr><td>5</td><td><strong>Gossamer</strong></td><td>Gossamer</td><td>60.00</td><td>52.95</td><td>5</td><td>7.05</td><td>3</td><td>12%</td></tr>
<tr><td>6</td><td><strong>Zig</strong></td><td>Zig</td><td>63.81</td><td>53.48</td><td>6</td><td>10.33</td><td>8</td><td>16%</td></tr>
<tr><td>7</td><td><strong>Odin</strong></td><td>Odin/Default</td><td>70.04</td><td>57.01</td><td>10</td><td>13.02</td><td>9</td><td>19%</td></tr>
<tr><td>8</td><td><strong>C3</strong></td><td>C3</td><td>71.89</td><td>56.37</td><td>9</td><td>15.52</td><td>12</td><td>22%</td></tr>
<tr><td>9</td><td><strong>D</strong></td><td>D/LDC</td><td>75.86</td><td>59.25</td><td>12</td><td>16.61</td><td>13</td><td>22%</td></tr>
<tr><td>10</td><td><strong>Java</strong></td><td>Java/GraalVM/JIT</td><td>76.61</td><td>54.61</td><td>8</td><td>22.00</td><td>17</td><td>29%</td></tr>
<tr><td>11</td><td><strong>Crystal</strong></td><td>Crystal</td><td>78.51</td><td>65.19</td><td>17</td><td>13.32</td><td>10</td><td>17%</td></tr>
<tr><td>12</td><td><strong>Mojo</strong></td><td>Mojo</td><td>79.50</td><td>64.81</td><td>16</td><td>14.69</td><td>11</td><td>18%</td></tr>
<tr><td>13</td><td><strong>Kotlin</strong></td><td>Kotlin/JVM/Default</td><td>81.92</td><td>53.77</td><td>7</td><td>28.16</td><td>19</td><td>34%</td></tr>
<tr><td>14</td><td><strong>C#</strong></td><td>C#/JIT</td><td>82.71</td><td>62.88</td><td>14</td><td>19.83</td><td>14</td><td>24%</td></tr>
<tr><td>15</td><td><strong>Go</strong></td><td>Go</td><td>85.07</td><td>57.92</td><td>11</td><td>27.15</td><td>18</td><td>32%</td></tr>
<tr><td>16</td><td><strong>Julia</strong></td><td>Julia/Default</td><td>90.18</td><td>69.62</td><td>19</td><td>20.55</td><td>15</td><td>23%</td></tr>
<tr><td>17</td><td><strong>Scala</strong></td><td>Scala/JVM/Default</td><td>90.25</td><td>61.62</td><td>13</td><td>28.63</td><td>20</td><td>32%</td></tr>
<tr><td>18</td><td><strong>F#</strong></td><td>F#/JIT</td><td>92.18</td><td>70.68</td><td>20</td><td>21.49</td><td>16</td><td>23%</td></tr>
<tr><td>19</td><td><strong>V</strong></td><td>V/Clang</td><td>98.32</td><td>66.04</td><td>18</td><td>32.28</td><td>22</td><td>33%</td></tr>
<tr><td>20</td><td><strong>Nim</strong></td><td>Nim/Clang</td><td>107.5</td><td>62.96</td><td>15</td><td>44.57</td><td>25</td><td>41%</td></tr>
<tr><td>21</td><td><strong>TypeScript</strong></td><td>TypeScript/Bun/JIT</td><td>120.4</td><td>111.3</td><td>22</td><td>9.07</td><td>5</td><td>8%</td></tr>
<tr><td>—</td><td><strong>JavaScript <em>(unranked)</em></strong></td><td>JS/Bun/JIT</td><td>121.8</td><td>112.7</td><td>23</td><td>9.08</td><td>6</td><td>7%</td></tr>
<tr><td>22</td><td><strong>Dart</strong></td><td>Dart/JIT</td><td>177.2</td><td>120.5</td><td>24</td><td>56.67</td><td>26</td><td>32%</td></tr>
<tr><td>23</td><td><strong>Swift</strong></td><td>Swift</td><td>204.8</td><td>95.21</td><td>21</td><td>109.6</td><td>27</td><td>54%</td></tr>
<tr><td>24</td><td><strong>Ruby</strong></td><td>Ruby/Spinel/Clang</td><td>297.5</td><td>264.0</td><td>26</td><td>33.48</td><td>23</td><td>11%</td></tr>
<tr><td>25</td><td><strong>Python</strong></td><td>Python/PYPY</td><td>301.0</td><td>263.1</td><td>25</td><td>37.88</td><td>24</td><td>13%</td></tr>
<tr><td>—</td><td><strong>PHP <em>(unranked)</em></strong></td><td>PHP</td><td>505.4</td><td>476.5</td><td>27</td><td>28.81</td><td>21</td><td>6%</td></tr>
</table>

<ul>
<li><strong>On pure algorithms the JVM is Tier 1.5.</strong> Kotlin (53.77s, #7) and Java (54.61s, #8) sit next to Zig (53.48s) and ahead of C3, Odin, Go and D. Their totals are pulled down by JVM regex (Etc::LogParser: Kotlin 14.8s, Java 8.6s) and CSV parsing (~6s).</li>
<li><strong>Swift spends more than half its time in 8 tests.</strong> CSV::Parse alone takes 45.7s, 97× slower than the fastest. Its 42 algorithmic tests take 95.2s (#21), between F# and TypeScript. Its libraries are last (#27).</li>
<li><strong>Bun's libraries are elite.</strong> TypeScript and JavaScript on Bun rank #5 and #6 on libraries, ahead of C++. Their slowness is entirely in the JIT-compiled algorithmic code (#22–23).</li>
<li><strong>PHP is the extreme case.</strong> Its algorithms are the slowest in the table (#27). Its C-implemented built-ins rank #21, ahead of V, Ruby, Python, Nim, Dart and Swift.</li>
<li><strong>Go and Nim lose a third or more of their total to libraries.</strong> Go's Template::Regex takes 10.8s and Json::ParseDom 3.7s. Without Template::Regex, Go finishes in 74.2s. Nim's pure-Nim regex costs 33.5s in two tests. Without them, Nim finishes in 74.0s, and its algorithms already rank #15.</li>
<li><strong>Crystal and Mojo are the reverse:</strong> better libraries (#10, #11) than algorithms (#17, #16).</li>
<li><strong>The C and C++ library wins are library wins.</strong> C uses yyjson and a SIMD Base64 library. C++ uses simdjson, RE2 and the same Base64 library. Rust's serde_json DOM parse (1.70s) is 20× slower than yyjson (0.086s). That is a crate choice, not a language property.</li>
</ul>

<hr>

<h2>🪿 Goose: The Newcomer That Rewrote the Leaderboard</h2>

<p><strong>Goose/Clang: 38.3s · Runtime score 96.8 · geomean 1.18 · 26.5MB memory · 24 wins · 0 last places · +37% expressiveness</strong></p>

<p>No language has ever dominated this suite like this. Goose wins almost half of all benchmarks, 19 of them by 10% or more. It never finishes last and uses less memory than Rust (only C uses less). It is also one of the most concise languages in the suite (+37%, #5 overall). Its only weak axis is the build: Goose compiles to C and builds the whole program with <code>cc -O2</code>, which takes 4.44s every time.</p>

<p>The breadth of the lead is even more striking than its size. Goose's median test is within 1% of the fastest language, and it is within 1.25× of the best on 40 of 50 tests. It is more than 3× slower than the leader on only one test (Base64::Decode, 0.79s vs 0.128s). C, the next most consistent language, is within 1.25× on 23 tests.</p>

<p><strong>But look at where the big wins come from.</strong> The biggest margins are on allocation-heavy tests:</p>
<ul>
<li><strong>Binarytrees::Obj:</strong> 0.229s vs C 2.47s, Rust 2.59s (10× faster)</li>
<li><strong>Compress::LZWDecode:</strong> 0.117s vs C 0.553s (4.7× ahead of 2nd place)</li>
<li><strong>Calculator::Ast:</strong> 0.135s vs C 1.05s, Rust 0.612s</li>
<li><strong>Graph::AStar:</strong> 0.414s vs C 1.79s, Rust 1.97s</li>
<li><strong>CSV::Parse:</strong> 0.473s vs Zig 0.946s</li>
</ul>
<p>One big win is not about allocation: <strong>Hash::SHA256</strong> runs in 0.268s vs C 1.02s and Rust 0.999s. That is the same simple loop as in C, so this one is pure code generation.</p>

<p>The Goose source shows why the allocation-heavy wins happen. Its value-oriented data model makes the natural way to build a tree to <strong>push nodes into a growable array and hold references into it</strong>. Its LZW keeps all dictionary strings in a single byte buffer and uses slices into it. So Binarytrees::Obj in Goose is effectively an arena: Goose's Obj (0.229s) is as fast as its Arena (0.240s), while C pays 6× for per-node <code>malloc</code> (2.47s vs 0.424s). That is idiomatic Goose, and it is exactly what this suite wants to measure ("the actual cost of language abstractions"). But it means a share of those 38 seconds is a <strong>data-layout advantage</strong> that other languages could also get by writing different code, not just better code generation. On pure compute tests (Matmul, Mandelbrot, Spectralnorm, Fannkuch, Sort::Quick) Goose lands right next to C and Rust, not far ahead.</p>

<p>The backend matters too. Goose/GCC runs 44.96s (17% slower than Clang), and the alternative Goose.go implementation (Goose/Go) runs 67.89s, 1.8× slower.</p>

<p><strong>Verdict:</strong> A genuinely impressive result and the headline of this update. The fair reading is: "a language whose default memory model leads to cache-friendly layouts beats languages whose default is one heap allocation per object." That is a real and valuable lesson about language design. Goose is also a young language, and this suite measures nothing about its tooling, ecosystem or stability. It is worth watching closely.</p>

<hr>

<h2>🏆 The Unsung Heroes: Achievements That Deserve Recognition</h2>

<h3>🌱 Gossamer: The Quiet All-Rounder</h3>

<p><strong>Gossamer: 60.0s · 39.5MB · 1.23s cold compile · +27% expressiveness · 0 last places · 0 tests worse than 10×</strong></p>

<p>Gossamer is the other big newcomer story. It sits in Tier 1 alongside C and C++ (60.0s), compiles the whole suite in 1.23 seconds (#3 overall), uses under 40MB, and is as concise as Go and Python. It never wins outright, but it is 2nd on Etc::Words, Etc::LogParser and Distance::NGram, and its libraries rank #3 in the suite. Its worst test is Compress::LZWDecode (9.6× the leader). No other language in the dataset combines Tier-1 speed with sub-2-second compiles <em>and</em> top-third expressiveness.</p>

<h3>🦀 Rust: Fastest Safe Language, Now Faster Than C</h3>

<p><strong>Rust: 54.53s · C/Clang: 55.01s · C/Gcc: 56.14s · C++/Clang++: 59.07s</strong></p>

<p>In March Rust trailed C/C++ by 1.3%. Now, with rustc 1.99, it is ahead of both, with bounds checks on and safe idiomatic code. Rust also improved its incremental compile time from 1.72s to 1.11s. It wins only one test (Compress::BWTEncode) but is rarely far behind. Its two weak spots are libraries: Json::ParseDom 1.70s (serde_json) and Template::Regex 3.61s. Without them it would finish in 49.2s.</p>

<h3>🐹 Go: The Regex Problem Got (Half) Fixed</h3>

<p><strong>Go: 85.07s (was 115.6s in March) · 0.79s cold compile · 0.31s incremental · 10.2× scaling</strong></p>

<p>In March Go was dragged down by two regex benchmarks. Switching both to <code>coregex</code> took Etc::LogParser from 30.8s to <strong>0.795s</strong>, 39× faster. But the same switch made Template::Regex 21% slower (8.98s → 10.84s, now 13× behind the leader). Excluding Template::Regex, Go would finish in about 74s, between C3 and D. The other library outlier is Json::ParseDom (3.73s, 43× the leader). Go switched to json/v2 after this run, so that number should change next time. Go remains the fastest compiler in the suite by a wide margin, has the lowest boilerplate ratio of any language, and its 16-thread scaling jumped from 6.5× to 10.2×.</p>

<h3>🍎 Swift on Linux: From Disaster to Merely Slow</h3>

<p><strong>Swift: 332.98s → 204.8s (−38%) · 65.1MB · 11.5× scaling</strong></p>

<p>Swift 6.4 is the most improved language since March, but it is two languages in one. Numeric Swift is competitive: 2nd on Hash::SHA256 (0.972s), close to C on matmul, and it scales 11.5×. String-processing Swift on Linux is the weakest in the suite. It still has 7 last places: CSV::Parse (45.7s), Template::Regex (19.0s), Template::Parse (11.8s), Compress::HuffDecode (9.6s), Json::ParseMapping (7.3s), Json::ParseDom (7.1s) and Etc::Words (5.5s). Etc::LogParser (13.3s) and Json::Generate (10.2s) are also slow. Swift's string, regex and JSON handling on Linux remains its Achilles' heel. <code>-Ounchecked</code> removes 13s from CSV::Parse alone, so part of the cost is runtime checks inside string code.</p>

<h3>☕ The JVM: Still Getting Faster After 30 Years</h3>

<p><strong>Java/GraalVM: 76.61s · Kotlin: 81.92s · Java/OpenJDK: 83.57s · Scala: 90.25s</strong></p>

<p>Every JVM language improved 6–14% since March. GraalVM/JIT is now <strong>8% faster than OpenJDK</strong> (in March they were tied), and Kotlin/GraalVM (76.16s) and Scala/GraalVM (83.09s) benefit similarly. On the 42 algorithmic tests, Kotlin and Java are level with Zig. The JVM's bump allocator beats C's <code>malloc</code> 5× on Binarytrees::Obj (Kotlin 0.477s vs 2.47s), and the JVM holds the Sort::Self podium together with Julia (0.187s vs C 1.99s).</p>

<h3>🔬 Julia: The Type-Specialized Winner</h3>

<p><strong>Julia: 90.18s (was 122.8s) · Sort::Self 0.118s (17× faster than C) · CLBG::Mandelbrot win</strong></p>

<p>Julia still wins Sort::Self, because its standard <code>sort</code> chooses a specialized algorithm for integer arrays at runtime. That is a library win, not raw execution speed. Julia 1.13 brought a 27% overall improvement. Its weak spots are Base64 (4.38s encode) and Json::Generate (4.43s). Memory (480MB) remains the price.</p>

<h3>💎 Ruby/Spinel: Ahead-of-Time Ruby Is Real</h3>

<p><strong>Ruby/Spinel: 297.5s (519s two weeks ago) · CRuby 4/YJIT: 2410.7s · TruffleRuby: 329.9s</strong></p>

<p>Spinel, an AOT compiler for Ruby, is <strong>8× faster than CRuby with YJIT</strong>. It already beats TruffleRuby and Python/PyPy, and it uses 6× less memory than TruffleRuby (254.5MB vs 1486MB). It improved 43% in just two weeks. Its geomean (7.18) is clearly better than PyPy's (9.21). Its remaining outliers are Etc::TextRaytracer (62.7s) and Compress::BWTEncode (27.4s). Ruby is also the #3 most expressive language (+39.9%).</p>

<h3>🔥 Mojo: Halved in Two Weeks</h3>

<p><strong>Mojo: 157.4s (1.2.0-dev) → 79.5s (1.2.0)</strong></p>

<p>The Mojo 1.2.0 release fixed regex (Etc::LogParser 13.3s → 0.26s, Template::Regex 16.6s → 1.27s), JSON, CSV and matmul. It now wins CLBG::Nbody and Hash::CRC32 and is 2nd on Etc::TextRaytracer, Graph::AStar and CLBG::Mandelbrot. Its matmul speedup ratio is the best of any production config (14.9×), but it starts from a slow single-threaded baseline (8.18s vs ~5s for most languages). At 16 threads it is slower than C, Kotlin or Java. Base64::Decode (8.73s, 68× C) is its biggest remaining hole. Its compiler is the most memory-hungry in the dataset (2.9GB) and the 2nd-slowest (28.9s cold).</p>

<hr>

<h2>🔎 The Rest of the Field</h2>

<h3>⚙️ C: The Baseline</h3>
<p><strong>55.01s · geomean 1.75 · 23.3MB (lowest) · 2.69s cold / 0.05s incremental · −126.8% expressiveness · 7 wins</strong></p>
<p>C has the lowest memory, the fastest incremental build, the best absolute 16-thread matmul (0.351s), and 7 wins. Most of the wins come from libraries (Base64 ×2, Json::ParseDom) or from simple loops (Sort::Quick, Graph::DFS, Distance::Jaro). Its weak spots are <code>qsort</code> in Sort::Self (1.99s, 17× Julia), per-node <code>malloc</code> in Binarytrees::Obj (2.47s), and string-heavy code (Etc::Words 1.98s, Distance::NGram 1.81s). The price is the 2nd-most verbose code in the suite.</p>

<h3>⚙️ C++: The Workhorse</h3>
<p><strong>59.07s · geomean 1.83 · 30.6MB · 5.98s cold / 0.73s incremental · +1.0% expressiveness · 4 wins · 0 tests worse than 10×</strong></p>
<p>C++ is as fast as C and Rust, has average expressiveness, and never blows up past 10×. Its slowest tests are Template::Regex (4.96s, even with RE2) and Brainfuck::Recursion (2.64s). Among the three classic Tier-1 languages it has the best balance of speed and conciseness.</p>

<h3>⚡ Zig</h3>
<p><strong>63.81s · 31.2MB · 20.37s compile (19.7s incremental) · −169.0% expressiveness (last) · 1 win (Template::Regex)</strong></p>
<p>Zig is fast and lean, and its algorithms rank #6. Its library weak spot is Base64 (2.73s encode, 27× C). Its costs are the most verbose code in the suite (279KB of source) and a whole-program build that takes 20 seconds even after a one-line change. Its <strong>ReleaseSafe</strong> checks cost 20% (see the safety section).</p>

<h3>🔷 Odin</h3>
<p><strong>70.03s · median 1.50 · 42.3MB · 7.64s compile · −37.4% expressiveness</strong></p>
<p>Odin is excellent on typical code (5th-best median) but has 6 tests worse than 10×. The worst is Sort::Self (4.23s, 36× Julia), and JSON is slow (~2–2.7s per test). It is 2nd on Compress::LZWEncode and Template::Regex.</p>

<h3>🔶 C3</h3>
<p><strong>71.89s · 28.1MB · 1.01s compile · −115.5% expressiveness · 1 win (Compress::BWTDecode)</strong></p>
<p>C3 is the fastest-compiling native systems language (1.01s, 2nd overall after Go) and has the 3rd-lowest memory. Its library tests (JSON ~2.5s each, CSV 3.5s) cost it a place in Tier 1.</p>

<h3>🅳 D</h3>
<p><strong>D/LDC: 75.86s · 66.6MB · 37.17s cold compile (slowest) / 2.6GB compiler RSS · 2 wins</strong></p>
<p>D wins Brainfuck::Array and Matmul::T4 and is 2nd on Matmul::Single and Compress::HuffDecode. Its build is the slowest in the suite. The backend matters a lot: DMD runs 118.55s, 56% slower than LDC.</p>

<h3>💎 Crystal</h3>
<p><strong>78.51s · 66.2MB · 22.82s compile · +44.0% expressiveness (#1) · 2.46× matmul scaling</strong></p>
<p>Crystal is the most concise language in the suite. It is consistent, with only 2 tests worse than 10×, but rarely excels: only 4 tests are within 1.25× of the best. Its weaknesses are a 23-second build on every change and poor threading (1.7× on 4 threads, no gain past 8).</p>

<h3>🟪 .NET: C# and F#</h3>
<p><strong>C#/JIT: 82.71s · 108.6MB · 2.18s compile · +5.5% · F#/JIT: 92.18s · 120.7MB · 4.45s · +22.5%</strong></p>
<p>Both have 0 last places, and both are hurt by the same libraries: Template::Regex (C# 8.19s, F# 8.92s) and CSV::Parse (~6s). C#'s other outlier is Binarytrees::Obj (4.58s, 20× the leader). C# has the best balance of runtime, memory and compile time among the managed runtimes.</p>

<h3>🟦 V</h3>
<p><strong>V/Clang: 98.32s · 70.4MB · 5.10s compile · −5.7% · 2 wins (CLBG::Fannkuchredux, CLBG::Spectralnorm)</strong></p>
<p>V is very good at tight numeric loops, but 8 tests are more than 10× slower than the best. CSV::Parse (7.8s), Maze::AStar (6.8s) and Etc::LogParser (5.9s) cost it about 20 seconds.</p>

<h3>👑 Nim</h3>
<p><strong>Nim/Clang: 107.5s (74.0s without the two regex tests) · 50.3MB · 2.46s compile · +38.1% · 1 win (Brainfuck::Recursion)</strong></p>
<p>Nim is the clearest example of a language held back by one library. Its pure-Nim regex package costs 33.5 seconds in two tests and gives it its only last place (Etc::LogParser 23.4s, 119× the leader). Without regex, Nim would sit in Tier 2 next to Odin and C3, combined with fast compiles, low memory and top-4 conciseness. Its release build also stops scaling after 8 threads (T8 0.93s, T16 0.95s), while the <code>-d:danger</code> build scales 14.8×.</p>

<h3>📜 TypeScript / JavaScript</h3>
<p><strong>TypeScript/Bun: 120.4s · JS/Bun: 121.8s · 219.7MB · single-threaded</strong></p>
<p>Bun's libraries are first-class (8 library tests in 9.07s). Its algorithmic code is about 2× slower than the JVM's. There is no worker parallelism in these implementations, so matmul does not scale at all.</p>

<h3>🎯 Dart</h3>
<p><strong>Dart/JIT: 177.2s · 325.9MB · 5 last places</strong></p>
<p>Dart is moderately slow almost everywhere (only 2 tests within 1.25× of the best) and very slow on Base64 (9.7s / 8.9s, last on both). The JIT VM never uses less than 279MB.</p>

<h3>🐍 Python</h3>
<p><strong>Python/PyPy: 301.0s · geomean 9.21 · 216.8MB · 21 last places</strong></p>
<p>PyPy is about 11× slower than the leader on its median test. Threads make it slower, not faster: Matmul::T4 takes 23.9s against 13.5s single-threaded, because the GIL serializes the work. Its closest result is CLBG::Mandelbrot (1.22× the leader).</p>

<h3>🐘 PHP (unranked)</h3>
<p><strong>PHP 8.5: 505.4s · 131.1MB</strong></p>
<p>Pure-PHP algorithms are the slowest code in the suite apart from CRuby (476.5s for the 42 algorithmic tests). PHP's C-implemented built-ins, however, are top-tier: Base64 encode and decode (0.104s / 0.118s) match C's SIMD library (0.102s / 0.128s).</p>

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

<p><strong>C3's surprise:</strong> 28MB, in Rust/C territory. <strong>Goose</strong> at 26.5MB is the lowest of any non-C language.</p>

<p><strong>WASM tax:</strong> Rust/WASM/Node uses 101MB vs 29.5MB for native Rust, the cost of running inside V8. That is still 2.7× less than TypeScript/Node (270.5MB). WasmEdge needs 76.7MB.</p>

<p><strong>Runtime floors decide the upper tiers.</strong> On the smallest test, native languages use 2.5–7.5MB. The managed runtimes never go below their floor: Julia 389MB, Dart/JIT 279MB, Java/GraalVM 187MB, Python/PyPy 89MB, Kotlin 62MB. For small workloads these languages pay mostly for the runtime, not for the data.</p>

<p><strong>Configuration matters as much as language:</strong></p>
<ul>
<li><strong>Java/OpenJDK with Serial GC:</strong> 167.9MB at 83.41s, vs 335.6MB at 83.57s with the default GC. Same speed, half the memory. On GraalVM, Serial GC is both faster (75.30s) and lighter (322.8MB).</li>
<li><strong>Dart AOT</strong> uses 109.5MB vs 325.9MB for JIT. <strong>C# AOT</strong> uses 84.4MB vs 108.6MB for JIT.</li>
<li><strong>Nim ARC</strong> uses 38.0MB vs 50.3MB for the default ORC, and is 3% faster.</li>
</ul>

<hr>

<h2>⚡ Scaling: Who Actually Uses Your 16 Cores?</h2>

<p>Matmul::Single vs Matmul::T16 on an 8-core/16-thread CPU (ideal: 12–16×). The table is sorted by <strong>absolute 16-thread time</strong>, because a high speedup from a slow single-threaded baseline is not a win.</p>

<table>
<tr><th>Language</th><th>1 thread, s</th><th>16 threads, s</th><th>Speedup</th><th>Verdict</th></tr>
<tr><td><strong>C/Clang</strong></td><td>4.94</td><td><strong>0.351</strong></td><td>14.07×</td><td>🏆 Fastest and near-ideal</td></tr>
<tr><td><strong>Kotlin/JVM</strong></td><td>4.94</td><td>0.373</td><td>13.23×</td><td>✅ Excellent</td></tr>
<tr><td>Java/GraalVM</td><td>4.97</td><td>0.396</td><td>12.55×</td><td>✅ Excellent</td></tr>
<tr><td>C++/Clang++</td><td>4.93</td><td>0.404</td><td>12.21×</td><td>✅ Excellent</td></tr>
<tr><td>Swift</td><td>4.98</td><td>0.434</td><td>11.47×</td><td>✅ Very good</td></tr>
<tr><td>Goose</td><td>4.95</td><td>0.456</td><td>10.86×</td><td>✅ Good</td></tr>
<tr><td><strong>Go</strong></td><td>5.02</td><td>0.492</td><td>10.20×</td><td>✅ Good, up from 6.51× in March</td></tr>
<tr><td>Scala, F#, Odin, C3, Rust, V, D</td><td>4.9–5.2</td><td>0.48–0.53</td><td>9.3–10.2×</td><td>✅ Good</td></tr>
<tr><td><strong>Mojo</strong></td><td>8.18</td><td>0.549</td><td>14.89×</td><td>🟡 Best ratio, but from a slow 1-thread baseline</td></tr>
<tr><td>Gossamer, C#, Zig</td><td>5.0–5.2</td><td>0.58–0.65</td><td>7.8–8.8×</td><td>🟡 Decent</td></tr>
<tr><td>Ruby/Spinel, Nim, Julia</td><td>6.1–6.9</td><td>0.91–0.99</td><td>6.5–7.0×</td><td>🟡 Mediocre, flat after 8 threads</td></tr>
<tr><td>Crystal</td><td>5.04</td><td>2.05</td><td>2.46×</td><td>🔴 Poor: 1.7× on 4 threads (3.02s), flat after 8</td></tr>
<tr><td>Dart/JIT</td><td>5.01</td><td>2.46</td><td>2.04×</td><td>🔴 Poor: 16 threads slower than 8 (1.81s)</td></tr>
<tr><td>TypeScript, JavaScript, Rust/WASM</td><td>~5.1</td><td>~5.1</td><td>~1.0×</td><td>⚫ Single-threaded</td></tr>
<tr><td>Python/PyPy</td><td>13.53</td><td>13.85</td><td>~1.0×</td><td>⚫ GIL: 4 threads take 23.9s</td></tr>
</table>

<p>Matmul::Single itself is now a near tie: 26 of 31 production configurations finish between 4.89s and 5.25s. Single-threaded numeric code is a solved problem. Threading is where languages still differ.</p>

<hr>

<h2>📦 Compile Times: The Developer Experience Tax</h2>

<h3>Cold Compile (whole suite, wall time, seconds)</h3>
<pre>
⚡ INSTANT (&lt;1.5s)        Go (0.79), C3 (1.01), Gossamer (1.23), TypeScript/Node tsc (1.46)
🚀 FAST (2-5s)            C# (2.18), Nim (2.46), C/Clang (2.69), Java (4.33), Goose (4.44), F# (4.45)
⏱️ MODERATE (5-11s)       V (5.10), C++/Clang++ (5.98), Rust (7.03), Odin (7.64), C/Gcc (8.03), Ruby/Spinel (9.49), Scala (10.74)
🐢 SLOW (17-25s)          Kotlin (17.37), C++/G++ (17.39), Zig (20.37), Crystal (22.82), Swift (24.11)
🦥 VERY SLOW (28s+)       Mojo (28.9), D/LDC (37.17)
</pre>
<p><em>No build step: Julia, TypeScript/Bun, Dart/JIT, Python/PyPy.</em></p>

<h3>Incremental Compile (one file changed)</h3>
<p>Languages with real separate compilation shine here: C (0.05s), Go (0.31s), C++ (0.73s) and Rust (1.11s). C3 (1.01s) and Gossamer (1.23s) rebuild everything but are fast enough that it doesn't matter. Swift, D and Scala roughly halve their build time. Whole-program compilers pay full price every time: Zig (19.7s), Crystal (22.9s), Mojo (27.8s), and Kotlin (17.4s).</p>

<ul>
<li><strong>Wall time hides CPU cost.</strong> Rust's 7.03s cold build burns 54s of CPU time, and Kotlin, Scala and Mojo each burn over 60s. On a laptop with fewer cores these builds get much slower.</li>
<li><strong>Compiler memory:</strong> Mojo needs 2.9GB, D/LDC 2.6GB, Kotlin 1.3GB and Scala 1.2GB of RAM to build the suite. Go builds it in 117MB.</li>
<li><strong>Binary size:</strong> Goose (0.44MB) and C (0.48MB) produce the smallest native binaries. Swift (10.9MB) produces the largest, and Go, Zig and Gossamer produce 4.6–5.8MB.</li>
</ul>

<p><strong>Crystal's Dilemma persists:</strong> #1 expressiveness (+44.0%), 78.5s runtime, but 22.8s on every rebuild.</p>

<p><strong>C3's Sweet Spot:</strong> 1.01s compiles, 28MB memory, 71.9s runtime. It is the fastest-compiling native systems language here.</p>

<hr>

<h2>✍️ Expressiveness: The Code You Don't Write</h2>

<p>Expressiveness score = (boilerplate vs average) × (lines vs average)<sup>1.5</sup>, where boilerplate = source size ÷ gzip size. It measures <strong>conciseness</strong>, not clarity.</p>

<h3>Expressiveness vs Average Language (%)</h3>
<pre>
🎯 TIER S (Elite)         Crystal (+44.0%), Scala (+41.7%), Ruby (+39.9%), Nim (+38.1%), Goose (+37.0%)
📝 TIER A (Expressive)    Kotlin (+28.0%), Python (+27.2%), Gossamer (+27.0%), Go (+26.8%), F# (+22.5%), Dart (+21.0%), Swift (+19.6%)
📄 TIER B (Average)       Julia (+12.6%), JavaScript (+11.0%), C# (+5.5%), TypeScript (+1.8%), C++ (+1.0%), Java (−1.3%), Mojo (−2.0%), V (−5.7%)
📜 TIER C (Verbose)       PHP (−16.4%), Rust (−24.6%), D (−33.7%), Odin (−37.4%)
📚 TIER D (Very Verbose)  C3 (−115.5%), C (−126.8%), Zig (−169.0%)
</pre>

<ul>
<li><strong>Rust got more concise:</strong> 6,541 → 6,308 lines, and its score moved from −29.0% to −24.6%.</li>
<li><strong>Kotlin</strong> cut 6.7% of its lines and jumped from +22% to +28%.</li>
<li><strong>C</strong> dropped from −119.8% to −126.8%. Only part of that is its own code (+0.7% lines). The rest is because the scores are relative to the average language, and the average got 2% shorter as the new languages joined. C now has more lines than Zig (9,167 vs 9,116), though Zig still has far more bytes (279KB vs 231KB).</li>
<li><strong>Least boilerplate:</strong> Go (3.99). Its lines are average in number but carry the most information per byte. <strong>Most boilerplate:</strong> Zig (6.54), PHP (5.73), Mojo (5.59).</li>
<li><strong>Types cost lines:</strong> TypeScript has 4.5% more lines than the same code in JavaScript (5,608 vs 5,366). The difference shows in expressiveness (+1.8% vs +11.0%) but not in runtime.</li>
</ul>

<p><strong>Goose and Gossamer</strong> prove that the top of the speed table and the top of the expressiveness table are no longer disjoint sets.</p>

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

<h2>🏆 Wins &amp; Losses</h2>

<h3>Most Benchmarks Won (out of 50, per language; in brackets, wins by a margin of 10% or more)</h3>
<ol>
<li><strong>Goose</strong>: 24 (19) 🥇</li>
<li><strong>C</strong>: 7 (3) 🥈</li>
<li><strong>C++</strong>: 4 (2) 🥉</li>
<li>D, Mojo, Kotlin, Julia, V: 2 each</li>
<li>Rust, Zig, C3, Scala, Nim: 1 each</li>
</ol>

<p>In March C/C++/Rust shared 29 wins. Now Goose alone has 24, and Rust, the fastest language overall after Goose, has just one: it is rarely first but never far behind. Many wins outside Goose's are photo finishes. Scala's Matmul::Single (4.907s vs D's 4.931s), Mojo's Hash::CRC32 (0.2179s vs Zig's 0.218s) and Julia's Mandelbrot (0.888s vs Mojo's 0.891s) are effectively ties.</p>

<h3>Most Last Places</h3>
<ol>
<li><strong>Python/PyPy</strong>: 21 💀</li>
<li><strong>Ruby/Spinel</strong>: 10</li>
<li><strong>Swift</strong>: 7</li>
<li><strong>Dart/JIT</strong>: 5</li>
<li><strong>TypeScript/Bun</strong>: 3</li>
<li>Scala: 2. Java/GraalVM, Nim: 1 each.</li>
</ol>

<p><strong>The Zero Club (never last):</strong> Goose, Rust, C, C++, Gossamer, Zig, Odin, C3, D, Crystal, Mojo, Kotlin, C#, Go, Julia, F#, V. That is 17 of 25 production languages.</p>

<p>Being "last" is a weak signal by itself. Java's last place on Mandelbrot is 1.18s vs 0.89s, because every language is within 1.33× on that test. Nim's last place on Etc::LogParser is 119× the leader. The <strong>Top</strong> and <strong>&gt;5×</strong> columns in the full table say more.</p>

<ul>
<li><strong>Widest spread (slowest ÷ fastest):</strong> Etc::LogParser 119×, CSV::Parse 97×, Base64::Encode 96×, Compress::LZWDecode 87×, Json::ParseDom 83×. Four of the five are library tests.</li>
<li><strong>Narrowest:</strong> CLBG::Mandelbrot 1.3×, Sort::Quick 2.4×, Matmul::Single 2.8×, CLBG::Fannkuchredux 3.0×.</li>
</ul>

<hr>

<h2>🛡️ The Safety Revelation, Revisited</h2>

<p>In March Rust was within 1.3% of C. Now:</p>

<p><strong>Rust: 54.53s · C/Clang: 55.01s · C++/Clang++: 59.07s</strong></p>

<p>Safe Rust is faster than safe-flag C and C++. What the hacks tell us about headroom:</p>
<ul>
<li><strong>C/Clang/Unsafe:</strong> 47.89s, 13% faster than C/Clang</li>
<li><strong>C++/Clang++/Unsafe:</strong> 50.42s, 15% faster than C++/Clang++</li>
<li><strong>Zig/Unchecked:</strong> 51.09s, 20% faster than Zig</li>
<li><strong>Rust/MaxPerf/Unsafe:</strong> 53.55s, only 1.8% faster than Rust</li>
</ul>

<p><strong>But the C/C++ gain is mostly not about safety.</strong> The unsafe C/C++ builds add <code>-ffast-math</code>, which lets the compiler reorder the floating-point reduction in matmul and vectorize it. Matmul::Single drops from 4.94s to 0.80s, a 6× win on one kernel that changes floating-point semantics. Most of C/C++'s gain comes from the four matmul tests. Leave them out and the picture changes:</p>

<pre>
                 production    unsafe/unchecked    gain
Rust             46.84s        45.85s (MaxPerf)    2.1%
C/Clang          47.74s        46.53s              2.5%
C++/Clang++      51.75s        49.02s              5.3%
C3               64.30s        56.62s              12%
Zig              55.61s        43.56s              21.7%
</pre>

<ul>
<li><strong>Rust's safety tax is about 2%.</strong> Rust's safe code is 98% of its unsafe peak. Without matmul, safe Rust (46.84s) is level with C compiled with <code>-ffast-math</code> and no stack protector (46.53s).</li>
<li><strong>Zig's ReleaseSafe checks cost about 20%.</strong> That is a real safety cost, spread across the whole suite rather than concentrated in one kernel. Without the checks, Zig would be the fastest classic language on the non-matmul tests.</li>
</ul>

<p>The conclusion from March holds, with a sharper number: <strong>the safety tax in Rust is about 2%</strong>. In languages not designed around it, it can be 10–20%.</p>

<hr>

<h2>🔧 Compiler &amp; Runtime Wars</h2>

<h3>GCC vs Clang</h3>
<ul>
<li><strong>C:</strong> Clang 2.0% faster (55.01 vs 56.14), reversed since March</li>
<li><strong>C++:</strong> tie (59.07 vs 59.26). G++ led by 7% in March.</li>
<li><strong>Nim:</strong> GCC 5% faster (101.9 vs 107.5)</li>
<li><strong>V:</strong> Clang 2% faster (98.32 vs 100.3)</li>
<li><strong>Goose:</strong> Clang 17% faster (38.30 vs 44.96)</li>
</ul>
<p><strong>Verdict:</strong> Clang 23 has closed the gap. GCC compiles C/C++ 3× slower cold (8.0s vs 2.7s, 17.4s vs 6.0s). Note that the GCC here is an experimental 16.0.1 trunk snapshot.</p>

<h3>Alternative C Compilers</h3>
<p><strong>mycc/LLVM: 55.43s</strong>. A hobby C compiler with an LLVM backend lands within 1% of Clang. With the QBE backend it runs 76.57s, and cproc/QBE runs 87.35s. The backend is everything.</p>

<h3>Other Backends</h3>
<ul>
<li><strong>D:</strong> LDC 75.86s vs DMD 118.55s. The LLVM backend is 1.56× faster.</li>
<li><strong>Nim:</strong> NLVM 93.67s · GCC 101.88s · Clang 107.53s · C++ backend 135.78s (GCC) / 153.34s (Clang). The non-default backends are faster, and the C++ backend is much slower.</li>
<li><strong>Goose:</strong> Clang 38.30s · GCC 44.96s · Goose.go 67.89s. Same source, 1.8× spread.</li>
<li><strong>Crystal:</strong> GCRY 77.08s · default 78.51s · <code>-O3</code> 263.89s. Use <code>--release</code>.</li>
</ul>

<h3>OpenJDK vs GraalVM</h3>
<p>Java: 83.57s vs <strong>76.61s</strong> · Kotlin: 81.92s vs <strong>76.16s</strong> · Scala: 90.25s vs <strong>83.09s</strong>. GraalVM's JIT is now 7–9% faster across all JVM languages, at a cost of 60–70MB more memory. OpenJDK EA (81.92s) sits in between.</p>

<h3>C# JIT vs AOT</h3>
<p>SC-JIT 81.33s · JIT 82.71s · AOT 100.9s (22% slower) · R2R 101.6s. Memory: JIT 108.6MB, AOT 84.4MB. AOT loses most on Template::Regex (+3.5s) and Etc::TextRaytracer (+3.2s). <strong>Verdict:</strong> the JIT still wins throughput. AOT is for startup, memory and containers.</p>

<h3>Node vs Bun vs Deno</h3>
<p>TypeScript: Bun 120.4s &lt; Node 135.6s &lt; Deno 168.8s. JavaScript: Bun 121.8s &lt; Node 134.4s &lt; Deno 157.7s. <strong>On Bun and Node, TypeScript and plain JavaScript perform within about 1%</strong>, so types cost nothing at runtime. Deno is the exception, where TypeScript is 7% slower. Bun is the fastest and also the leanest (219.7MB vs Node 270.5MB).</p>

<h3>WASM Runtimes (Rust)</h3>
<p>Node 71.98s · WasmEdge 73.06s · Wasmer 91.88s · Wasmtime 102.9s. Rust/WASM/Node is <strong>1.9× faster than TypeScript/Node</strong>. It is faster than native D, Java, Crystal, Mojo and Go, and within 3% of native Odin and C3.</p>
<p><strong>WASM is cheaper than it looks.</strong> Rust/WASM in Node is 32% slower than native Rust in total. But WASM here is single-threaded, and the four matmul tests account for 12.5 of the 17.5 seconds of difference. On the other 46 tests it is only <strong>11% slower than native</strong>. It is even faster than native on Binarytrees::Obj (1.04s vs 2.59s), Graph::AStar (0.70s vs 1.97s) and Json::ParseDom (0.81s vs 1.70s). All three are allocation-heavy, which points at the native allocator rather than rustc.</p>

<h3>Ruby Implementations</h3>
<p>Spinel (AOT) 297.5s · TruffleRuby 329.9s · CRuby 4/YJIT 2410.7s. For CPU-bound code, Ruby implementation choice is an 8× decision.</p>

<h3>Dart JIT vs AOT</h3>
<p>JIT 177.2s · AOT 196.1s. The JIT is 10% faster, so it is the production config, but AOT uses 3× less memory (109.5MB vs 325.9MB).</p>

<hr>

<h2>🔬 JVM Ecosystem: Java, Kotlin, Scala</h2>

<table>
<tr><th>Metric</th><th>Java (GraalVM)</th><th>Kotlin</th><th>Scala</th><th>Winner</th></tr>
<tr><td>Runtime (s)</td><td>76.61</td><td>81.92</td><td>90.25</td><td>Java 🥇</td></tr>
<tr><td>Algorithms only, 42 tests (s)</td><td>54.61</td><td>53.77</td><td>61.62</td><td>Kotlin 🥇</td></tr>
<tr><td>Geomean</td><td>2.45</td><td>2.43</td><td>2.75</td><td>Kotlin 🥇</td></tr>
<tr><td>Memory (MB)</td><td>407.6 (OpenJDK 335.6)</td><td>328.1</td><td>379.5</td><td>Kotlin 🥇</td></tr>
<tr><td>Cold compile (s)</td><td>4.40</td><td>17.37</td><td>10.74</td><td>Java 🥇</td></tr>
<tr><td>Expressiveness</td><td>−1.3%</td><td>+28.0%</td><td>+41.7%</td><td>Scala 🥇</td></tr>
<tr><td>Scaling (16T)</td><td>12.55× (0.396s)</td><td>13.23× (0.373s)</td><td>10.16× (0.483s)</td><td>Kotlin 🥇</td></tr>
<tr><td>Wins / Last places</td><td>0 / 1</td><td>2 / 0</td><td>1 / 2</td><td>Kotlin 🥇</td></tr>
</table>

<p><strong>The Trade-off Triangle is unchanged:</strong> Java = speed and compile time, Scala = expressiveness, Kotlin = scaling and balance. On pure algorithms, Kotlin is the best of the three.</p>

<hr>

<h2>💀 The Hacking Section</h2>

<table>
<tr><th>Hack</th><th>Total, s</th><th>vs production</th><th>Where the gain comes from</th></tr>
<tr><td>Zig/Unchecked (ReleaseFast)</td><td>51.09</td><td><strong>−19.9%</strong></td><td>Spread across tests: Base64 −2.4s, LZWEncode −1.0s, Graph::AStar −0.9s</td></tr>
<tr><td>C3/Unsafe</td><td>58.36</td><td>−18.8%</td><td>5.9s of the 13.5s from matmul (vectorized), the rest spread out</td></tr>
<tr><td>Nim/Clang/Danger</td><td>91.10</td><td>−15.3%</td><td>Mostly regex: LogParser −4.1s, Template::Regex −2.1s, Brainfuck::Array −2.1s</td></tr>
<tr><td>C++/Clang++/Unsafe</td><td>50.42</td><td>−14.6%</td><td><strong>5.9s of the 8.6s from matmul</strong> (<code>-ffast-math</code>)</td></tr>
<tr><td>C/Gcc/Unsafe</td><td>48.72</td><td>−13.2%</td><td><strong>5.4s of the 7.4s from matmul</strong></td></tr>
<tr><td>C/Clang/Unsafe</td><td>47.89</td><td>−12.9%</td><td><strong>5.9s of the 7.1s from matmul</strong> (Matmul::Single 4.94s → 0.80s)</td></tr>
<tr><td>Swift/Unchecked</td><td>184.7</td><td>−9.8%</td><td>CSV::Parse alone −13.1s</td></tr>
<tr><td>Rust/PGO</td><td>52.11</td><td>−4.4%</td><td>Graph::AStar −0.85s, Brainfuck::Array −0.41s. PGO beats unsafe for Rust.</td></tr>
<tr><td>Rust/MaxPerf/Unsafe</td><td>53.55</td><td>−1.8%</td><td>Small gains everywhere</td></tr>
<tr><td>Odin/MaxPerf (no bounds checks)</td><td>68.97</td><td>−1.5%</td><td>Small gains everywhere</td></tr>
<tr><td>Goose/Clang/Fast (<code>-O3</code>)</td><td>38.20</td><td>−0.3%</td><td>No gain</td></tr>
<tr><td>D/LDC/MaxPerf</td><td>76.15</td><td>+0.4%</td><td>No gain</td></tr>
<tr><td>Kotlin, Scala "Max" heap flags</td><td>82.79 · 91.48</td><td>+1.1% · +1.4%</td><td>No gain, at 4.5–4.6GB of memory</td></tr>
<tr><td>C/Clang/PGO · C++/Clang++/PGO</td><td>57.00 · 61.49</td><td>+3.6% · +4.1%</td><td>PGO made Clang builds slower</td></tr>
<tr><td>C/Clang/Fast (<code>-O3 -march=native</code>)</td><td>59.35</td><td>+7.9%</td><td>Matmul::Single 4.94s → 8.24s</td></tr>
<tr><td>Crystal/O3</td><td>263.9</td><td>+236%</td><td>3.4× slower: plain <code>-O3</code> is not <code>--release</code></td></tr>
</table>

<p><strong>Lesson:</strong> Removing bounds checks is still worth 10–20% for languages that rely on them (Zig, C3, Nim, Swift), and about 2% for Rust. The big C/C++ "unsafe" number is mostly <code>-ffast-math</code> on one kernel. Other exotic flags (<code>-O3 -march=native</code> in C, <code>-O3</code> in Crystal, PGO in Clang, JVM heap tuning) were neutral or harmful. Default release mode remains the sweet spot.</p>

<hr>

<h2>📈 Historical Trends (March 9 → November 4)</h2>

<p><em>Compared on the same 50 tests (CLBG::Pidigits was dropped since March).</em></p>

<h3>Biggest Improvements</h3>
<ul>
<li><strong>Swift:</strong> 333.0s → 204.8s (−38.5%), Swift 6.2 → 6.4</li>
<li><strong>Odin:</strong> 103.1s → 70.0s (−32.0%), mostly JSON and Base64 fixes (Json::ParseMapping −7.7s, Base64 −7.7s)</li>
<li><strong>Julia:</strong> 122.8s → 90.2s (−26.6%), Julia 1.12 → 1.13</li>
<li><strong>Go:</strong> 115.6s → 85.1s (−26.4%), coregex for Etc::LogParser</li>
<li><strong>D/LDC:</strong> 96.4s → 75.9s (−21.3%)</li>
<li><strong>TypeScript/Bun:</strong> 149.2s → 120.4s (−19.3%)</li>
<li><strong>Zig:</strong> 75.1s → 63.8s (−15.1%), Zig 0.15 → 0.17</li>
<li><strong>Java/GraalVM:</strong> 88.9s → 76.6s (−13.8%)</li>
<li><strong>Kotlin:</strong> 93.7s → 81.9s (−12.5%)</li>
</ul>

<h3>Regressions</h3>
<ul>
<li><strong>Nim/Clang:</strong> 86.9s → 107.5s (+23.7%). The switch to the pure-Nim <code>regex</code> package took Etc::LogParser from 0.65s to 23.4s (last place) and Template::Regex from 1.8s to 10.2s. Outside regex, Nim actually got 12% faster (84.4s → 74.0s), led by Matmul::Single (11.5s → 6.1s).</li>
<li><strong>Crystal:</strong> 75.1s → 78.5s (+4.5%)</li>
<li><strong>C++/G++:</strong> 57.1s → 59.3s (+3.8%)</li>
</ul>

<h3>Last Two Weeks (Oct 21 → Nov 4)</h3>
<p>Mojo 1.2.0 (157.4s → 79.5s) and Ruby/Spinel (519s → 297.5s) halved their times. Go dropped 26% when it switched to coregex in this window, Odin dropped 12%, and Java/GraalVM 8%. Everything else moved by less than 4%.</p>

<hr>

<h2>🎯 AI Tool's Final Rankings (Multi-Factor)</h2>

<p>Weighted: Runtime 30% | Memory 20% | Expressiveness 15% | Cold Compile Time 15% | Scaling 10% | Wins 10%. Best production config per language.</p>
<ul>
<li><strong>Runtime, memory and compile time</strong> are scored on a log scale between the best and the worst language. JIT languages without a compile step get a neutral 50 for compile time.</li>
<li><strong>Expressiveness and scaling</strong> (the 1 → 16-thread matmul speedup ratio) are scaled linearly between the best and the worst language.</li>
<li><strong>Wins</strong> are scored as log(1 + wins).</li>
</ul>

<table>
<tr><th>Rank</th><th>Language</th><th>Score</th><th>Medal</th><th>Archetype</th></tr>
<tr><td>1</td><td><strong>Goose</strong></td><td>89.0</td><td>🥇 GOLD</td><td>The Disruptor: 38.3s, 24 wins, 26.5MB, +37% expressiveness</td></tr>
<tr><td>2</td><td><strong>C++</strong></td><td>74.1</td><td>🥈 SILVER</td><td>The Workhorse: 59.1s, 12.2× scaling, 0 last places</td></tr>
<tr><td>3</td><td><strong>C</strong></td><td>73.8</td><td>🥉 BRONZE</td><td>The Veteran: lowest memory (23.3MB), 7 wins, 14× scaling, but −127% expressiveness</td></tr>
<tr><td>4</td><td><strong>Gossamer</strong></td><td>72.7</td><td>🏅</td><td>The All-Rounder: 60.0s, 1.23s compile, +27% expressiveness</td></tr>
<tr><td>5</td><td><strong>Rust</strong></td><td>68.5</td><td>🏅</td><td>The Safe Speedster: fastest classic language (54.5s), ~2% safety tax, but only 1 win</td></tr>
<tr><td>6</td><td><strong>Go</strong></td><td>66.8</td><td>🏅</td><td>The Productivity King: 0.79s compiles, +27% expressiveness, scaling fixed</td></tr>
<tr><td>7</td><td><strong>C3</strong></td><td>65.9</td><td>🏅</td><td>The Lean Native: 1.01s compiles, 28MB, but very verbose</td></tr>
<tr><td>8</td><td><strong>Nim</strong></td><td>61.1</td><td>🏅</td><td>The Expressive Native: +38%, 2.5s compiles, held back by its regex library</td></tr>
<tr><td>9</td><td><strong>Mojo</strong></td><td>59.7</td><td>🔥</td><td>The Rising Star: 79.5s, best scaling ratio (14.9×), heaviest compiler</td></tr>
<tr><td>10</td><td><strong>Odin</strong></td><td>59.0</td><td>⚙️</td><td>The Improver: 70.0s (−32%), 42MB</td></tr>
<tr><td>11</td><td><strong>V</strong></td><td>57.9</td><td>🆕</td><td>The Steady One: 98.3s, 2 wins, 0 last places</td></tr>
<tr><td>12</td><td><strong>C#</strong></td><td>56.8</td><td>🏅</td><td>The Balanced .NET: 82.7s, 2.2s compiles, 0 last places</td></tr>
<tr><td>13</td><td><strong>F#</strong></td><td>54.5</td><td>🧮</td><td>The Functional .NET: 92.2s, +22.5% expressiveness</td></tr>
<tr><td>14</td><td><strong>D</strong></td><td>52.1</td><td>🏅</td><td>The Comeback: 75.9s (−21%), but slowest compiler (37s)</td></tr>
<tr><td>15</td><td><strong>Crystal</strong></td><td>50.6</td><td>💎</td><td>The Paradox: #1 expressiveness, 78.5s, but 23s compiles and poor scaling</td></tr>
<tr><td>16</td><td><strong>Kotlin</strong></td><td>50.5</td><td>🏅</td><td>The Scaling Star: 13.2×, +28%, best JVM on algorithms, but 328MB and 17s compiles</td></tr>
<tr><td>17</td><td><strong>Zig</strong></td><td>50.3</td><td>🏅</td><td>The Fast but Wordy: 63.8s, 31MB, but −169% expressiveness and 20s compiles</td></tr>
<tr><td>18</td><td><strong>Java</strong></td><td>49.4</td><td>🏅</td><td>The Enterprise: 76.6s on GraalVM, but 400MB</td></tr>
<tr><td>19</td><td><strong>Scala</strong></td><td>47.5</td><td>🧮</td><td>The Expressive JVM: +41.7%, 90.3s</td></tr>
<tr><td>20</td><td><strong>Julia</strong></td><td>45.6</td><td>🔬</td><td>The Scientist: 90.2s, Sort::Self champion, 480MB</td></tr>
<tr><td>21</td><td><strong>Swift</strong></td><td>41.3</td><td>🍎</td><td>The Most Improved: −38%, good numerics, but still 7 last places</td></tr>
<tr><td>22</td><td><strong>TypeScript</strong></td><td>38.0</td><td>📜</td><td>The Web Native: 120.4s on Bun, elite libraries, single-threaded</td></tr>
<tr><td>23</td><td><strong>Dart</strong></td><td>31.9</td><td>🎯</td><td>The UI Specialist: 177.2s, 5 last places</td></tr>
<tr><td>24</td><td><strong>Ruby</strong></td><td>28.5</td><td>💎</td><td>The AOT Experiment: Spinel 8× faster than CRuby, +40% expressiveness</td></tr>
<tr><td>25</td><td><strong>Python</strong></td><td>26.6</td><td>🐍</td><td>The Ecosystem King: 301s, 21 last places</td></tr>
</table>

<p><em>JavaScript and PHP have no production configuration and are not ranked. JS/Bun (121.8s) would sit next to TypeScript, and PHP (505.4s) would be last.</em></p>

<h3>Same Data, Different Priorities</h3>

<p>Any single ranking is only as good as its weights. Here are three use-case profiles built from the same component scores, without Wins (which double-counts runtime):</p>

<table>
<tr><th>Profile</th><th>Weights</th><th>Top 5</th></tr>
<tr><td>🖥️ Systems / HPC</td><td>Runtime 50 · Scaling 25 · Memory 25</td><td>Goose 91.7 · C 89.8 · C++ 82.4 · Rust 80.5 · Mojo 75.0</td></tr>
<tr><td>☁️ Cloud services</td><td>Runtime 25 · Memory 25 · Compile 30 · Expressiveness 20</td><td>Gossamer 85.1 · Goose 84.8 · Go 79.9 · C3 73.9 · C++ 72.7</td></tr>
<tr><td>🧑‍💻 Productivity</td><td>Expressiveness 40 · Compile 30 · Runtime 30</td><td>Gossamer 86.8 · Goose 85.2 · Go 85.2 · Nim 75.0 · C# 73.7</td></tr>
</table>

<p>The robust conclusions are the ones that survive reweighting. Goose and Gossamer are top-2 in both developer-facing profiles, and Go is 3rd in both. Zig goes from 8th (systems) to last (productivity), and C from 2nd to 19th. Mojo's 5th place in Systems comes from its speedup ratio. On absolute 16-thread time it would rank lower.</p>

<hr>

<h2>💡 Strategic Recommendations</h2>

<h3>🔹 For Systems Programming</h3>
<ul>
<li><strong>Choose Rust</strong> for safety at about a 2% speed cost. It is faster than C and C++ in this suite and has real incremental builds.</li>
<li><strong>Choose C or C++</strong> when you need the lowest memory or the best threading and can supply safety yourself.</li>
<li><strong>Choose C3 or Odin</strong> for C-like control with fast or simple builds (C3: 1s) and tiny memory.</li>
<li><strong>Choose Zig</strong> if you want explicit control and can afford 20s compiles and verbose code. Know that ReleaseSafe costs about 20%.</li>
<li><strong>Watch Goose.</strong> If its results hold as it matures, it is the most interesting new option in the dataset.</li>
</ul>

<h3>🔹 For Web Services / Microservices</h3>
<ul>
<li><strong>Choose Go</strong> for sub-second compiles, low memory and now-good scaling (10.2×). Benchmark its regex and JSON against your workload.</li>
<li><strong>Choose Java/Kotlin on GraalVM</strong> for raw JVM throughput (76s). Try Serial GC before buying more RAM.</li>
<li><strong>Choose C#</strong> for the best balance of runtime, memory and compile time among managed runtimes. Stay on the JIT unless startup matters.</li>
<li><strong>Choose Bun</strong> if you are in JS/TS land: it is the fastest and leanest of the three runtimes, with excellent built-ins.</li>
</ul>

<h3>🔹 For Developer Productivity</h3>
<ul>
<li><strong>Choose Gossamer</strong> for Tier-1 speed, 1.2s compiles and +27% expressiveness.</li>
<li><strong>Choose Crystal or Ruby/Spinel</strong> for maximum concision. Pick Crystal if you need speed and can live with 23s builds.</li>
<li><strong>Choose Nim</strong> for concise native code, but bring your own regex if you need speed there.</li>
</ul>

<h3>🔹 For Parallel Compute</h3>
<ul>
<li><strong>Choose C, Kotlin, Java, C++ or Swift</strong>, the fastest at 16 threads (0.35–0.43s).</li>
<li><strong>Avoid Crystal, Dart and single-threaded runtimes</strong> (TypeScript, Python, WASM) for CPU-bound parallel work.</li>
</ul>

<h3>🔹 For Memory-Constrained Environments</h3>
<ul>
<li><strong>Choose C, Goose, C3, Rust, C++ or Zig</strong> (23–31MB average).</li>
<li><strong>Avoid Julia and Dart/JIT</strong> (runtime floors of 389MB and 279MB before any data) and <strong>the JVM with default GC</strong> (330–410MB on average). Java with Serial GC halves that, and Dart AOT cuts it to a third.</li>
</ul>

<hr>

<h2>🎲 Q&amp;A: "Show me 10 random facts from the results that will surprise me"</h2>

<ol>
<li><strong>One test can outweigh a whole suite.</strong> Swift spends 45.7s on CSV::Parse, more than Goose needs for all 50 tests (38.3s). Ruby/Spinel spends 62.7s on Etc::TextRaytracer, more than C needs for all 50 (55.0s).</li>
<li><strong>A single CRuby test takes longer than all of PyPy.</strong> CRuby 4 + YJIT needs 318s for Matmul::Single, while PyPy finishes the entire suite in 301s. CRuby's four matmul tests take 22 minutes, 55% of its total. Because of the GVL, the 4-, 8- and 16-thread versions are all <em>slower</em> than the single-threaded one.</li>
<li><strong>PyPy parses JSON into a DOM faster than Rust, Go and Zig.</strong> Json::ParseDom: PyPy 0.77s, Rust (serde_json) 1.70s, Zig 1.82s, Odin 2.05s, C3 2.51s, Go 3.73s.</li>
<li><strong>The JVM finishes behind PyPy on three tests.</strong> On Distance::NGram the four slowest production configs are all JVM (Scala 2.43s vs PyPy 1.41s). Scala is last on Graph::BFS (3.93s vs PyPy 2.40s). Java/GraalVM is last on CLBG::Mandelbrot (1.18s), behind PyPy (1.09s) and Ruby/Spinel (0.94s).</li>
<li><strong>Goose compiled to Go beats hand-written Go.</strong> Goose/Go runs 67.9s vs Go's 85.1s, and it is faster on 32 of 50 tests. This is not only libraries: on the 42 algorithmic tests it still wins, 52.8s vs 57.9s.</li>
<li><strong>Superlinear scaling exists.</strong> Nim/NLVM/Danger runs matmul 16.1× faster on 16 threads of an 8-core CPU. D/LDC gets 4.7× on just 4 threads, which is how it wins Matmul::T4 by 20%.</li>
<li><strong>Julia's smallest test uses 3× more memory than C's largest.</strong> Julia never drops below 389MB, while C's hungriest test (Maze::AStar) peaks at 130MB.</li>
<li><strong>Giving the JVM more memory made it slower.</strong> Kotlin's "Max" heap configuration averages 4.5GB per test, 14× the default's 328MB, and runs 1% slower.</li>
<li><strong>The regex podium belongs to the three youngest languages.</strong> On Etc::LogParser: Goose 0.196s, Gossamer 0.215s, Mojo 0.261s. Rust's famous regex crate is 4th (0.304s), and C with PCRE2 needs 0.488s.</li>
<li><strong>SHA-256 runs faster in WASM than natively.</strong> Rust compiled to WASM and run in Node takes 0.938s on Hash::SHA256, 2nd only to Goose and ahead of native Rust (0.999s) and C (1.015s). Meanwhile TypeScript on Bun is <em>last</em> on the same test (4.76s), behind PyPy (3.71s), and 1.7× slower than TypeScript on Node.</li>
</ol>

<hr>

<h2>🤯 What Shocked Me</h2>

<ul>
<li><strong>A brand-new language beat C by 30%.</strong> Goose's lead is real, and the source shows it comes largely from an arena-like default memory layout. It is a reminder that "how the language makes you lay out data" can matter more than the compiler backend.</li>
<li><strong>Goose's consistency, more than its speed.</strong> 40 of 50 tests within 1.25× of the best, and only one test worse than 3×. Outliers usually win big on a few tests. Goose wins small on almost all of them.</li>
<li><strong>Rust passed C.</strong> 54.53s vs 55.01s, with bounds checks on. In March it was 1.3% behind. By geomean C is still slightly ahead, so call it a tie.</li>
<li><strong>The "unsafe C" speedup is mostly <code>-ffast-math</code> on one kernel.</strong> Without matmul, C's unsafe build gains 2.5%.</li>
<li><strong>Swift cut its runtime by more than a third since March</strong>, but it is still last on 7 tests, 6 of them string, text or JSON. The problem is string/Foundation handling on Linux, not the compiler.</li>
<li><strong>Mojo and Spinel halved their times in two weeks.</strong> Young toolchains move fast, and any snapshot of them is out of date quickly.</li>
<li><strong>Eight library tests decide the middle of the table.</strong> On pure algorithms Kotlin and Java sit with Zig, and Swift spends 54% of its time in those eight tests.</li>
<li><strong>A hobby C compiler (mycc/LLVM) is within 1% of Clang.</strong> LLVM is still the great equalizer.</li>
<li><strong>JIT beats AOT inside the same language:</strong> C# by 22%, Dart by 11%.</li>
<li><strong>TypeScript = JavaScript</strong> to within about 1% on Bun and Node. Types are free.</li>
<li><strong>One library choice cost Nim 20 seconds since March.</strong> Two regex benchmarks out of 50 turned Nim from a Tier-2 language into a Tier-3 one.</li>
</ul>

<p><strong>What I got wrong in March:</strong> I called Go's goroutines "overhyped for compute", and Go now scales 10.2×. I said GraalVM's JIT offers no advantage, and it is now 8% faster than OpenJDK. I said Nim was "the best balanced language", and a regex library change dropped it 24%. I said C leaves 20% on the table unless you cheat. That number is now 13%, and most of it is <code>-ffast-math</code> on matmul rather than removed safety.</p>

<hr>

<h2>🔮 Final Thoughts</h2>

<p><strong>1. Data layout beats codegen.</strong> Goose's biggest wins are allocation-heavy tests where its natural code is arena-shaped. The same pattern shows elsewhere: the JVM's bump allocator beats <code>malloc</code> 5× on Binarytrees::Obj, and Rust/WASM beats native Rust on three allocation-heavy tests. Arena-friendly defaults can give an order of magnitude, where compiler tuning gives percent.</p>

<p><strong>2. The safety tax is nearly gone.</strong> Rust is tied with C and C++, and its unsafe mode buys about 2%. Safety costs real time only where the language wasn't designed around it (Zig's ReleaseSafe: about 20%).</p>

<p><strong>3. The field is compressing.</strong> 20 of 25 languages finish within 2× of Rust, and Matmul::Single is a 26-way tie.</p>

<p><strong>4. Libraries move the needle more than compilers.</strong> Go (coregex), Nim (regex), Odin (JSON), Mojo (regex/JSON): the biggest swings since March came from library changes, not compiler releases. Regex alone decides whether Nim is Tier 2 or Tier 3, and JSON and CSV decide most of Swift's ranking.</p>

<p><strong>5. The toolchain is a language-sized decision.</strong> CRuby vs Spinel is 8×, DMD vs LDC 1.56×, QBE vs LLVM up to 1.6×, C# JIT vs AOT 1.22×. Choosing a language is only half the choice.</p>

<p><strong>6. New languages are viable.</strong> Goose, Gossamer and C3 all have 0 last places and sit in the top half of the ranking.</p>

<p><strong>7. Compile time is still the great divider.</strong> Go, C3 and Gossamer compile in about 1s. D, Mojo, Swift, Crystal and Zig take 20–37s, and most of them pay it again on every change.</p>

<p><strong>8. Single-threaded numerics are solved. Threading mostly is too, on native and JVM runtimes.</strong> The outliers are Crystal and Dart, and the single-threaded runtimes don't play at all.</p>

<hr>

<p><em>This analysis represents AI Tool's interpretation of the benchmark data from 2026-11-04: one machine, one run per configuration, implementations ported from a Crystal original with LLM assistance and human review. The ranking formula is stated above and is one of many reasonable weightings. Young toolchains (Goose, Gossamer, Mojo, Spinel) change quickly. Always test with your specific use case.</em></p>

<p><em>— AI Tool, November 2026</em></p>
</div>
`);
}
