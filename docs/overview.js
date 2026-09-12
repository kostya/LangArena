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

.category-list, .uses-list {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
  gap: 1rem;
  margin: 1.5rem 0;
}

.category-item, .use-card {
  background-color: #fafafa;
  padding: 1rem;
  border: 1px solid #e0e0e0;
  border-radius: 0;
  box-shadow: none;
}

.category-item strong, .use-card strong {
  display: block;
  margin-bottom: 0.4rem;
  font-weight: 600;
  color: #111111;
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

.why-list {
  list-style-type: none;
  padding-left: 0;
}

.why-list li {
  padding: 0.5rem 0;
  padding-left: 1.5rem;
  position: relative;
  border-bottom: 1px solid #f0f0f0;
}

.why-list li::before {
  content: "•";
  position: absolute;
  left: 0;
  color: #888888;
  font-weight: bold;
}
</style>

<div class="overview">

<h1>LangArena: Programming Language Benchmark Suite</h1>

<h2>What is it?</h2>

<p>A collection of 50 tasks across 26 languages - complex, non-synthetic, and inspired by real-world problems (JSON, Base64, CSV, neural networks, compression, maze A*, graph algorithms, sorting, hashing, interpreters, parallel matmul, and more). Where possible, the same core algorithm is implemented across all languages using idiomatic constructs; for library-based (JSON, Base64, CSV), I use the best practical option for each language. Checksums verify correctness and prevent dead-code elimination. The suite runs monthly with full history, so you can watch compiler performance evolve over time. The goal is not to crown a micro-optimization champion, but to see how well each language's compiler or runtime optimizes clean, readable, idiomatic code. The results include runtime, Runtime Score, memory usage, compile time, and expressiveness.</p>

<p><strong>Contenders:</strong> <span class="language-tag">C</span> <span class="language-tag">C++</span> <span class="language-tag">Crystal</span> <span class="language-tag">Rust</span> <span class="language-tag">Go</span> <span class="language-tag">Swift</span> <span class="language-tag">C#</span> <span class="language-tag">Java</span> <span class="language-tag">Kotlin</span> <span class="language-tag">TypeScript</span> <span class="language-tag">Zig</span> <span class="language-tag">D</span> <span class="language-tag">V</span> <span class="language-tag">Julia</span> <span class="language-tag">Nim</span> <span class="language-tag">F#</span> <span class="language-tag">Dart</span> <span class="language-tag">Python</span> <span class="language-tag">Odin</span> <span class="language-tag">Scala</span> <span class="language-tag">C3</span> <span class="language-tag">Ruby</span><span class="language-tag">PHP</span> <span class="language-tag">Mojo</span><span class="language-tag">Javascript</span><span class="language-tag">Gossamer</span></p>

<p class="language-note"><strong>Note on Mojo:</strong> this is a young language, and many tests use Python interop instead of native implementations, simply because I can't compile libraries for JSON, Regex, or implement certain tasks better due to missing language features. Performance is still very raw.</p>

<h2>Why?</h2>

<p>Most existing benchmarks suffer from the same problems: they measure micro-optimizations or synthetic loops, mix multiple concepts so it's unclear what's being measured, and often degenerate into assembly or parallelism competitions rather than clean code. The same algorithm is rarely preserved across implementations. They measure code that nobody runs in production - where you use standard language constructs, not hand-tuned assembly - and they rely on unsafe flags (<code>--no-bounds-check</code>) that no one enables in real projects. On top of that, there's no history: I'd love to see how Clang improved over time on a simple graph, but most suites are one-off runs.</p>

<h2>Origin &amp; Approach</h2>

<p>The suite began with my original implementation in Crystal. AI tools assisted in translating it to other languages, but this was far from a one-shot process. Many implementations went through multiple iterations - fixing incorrect checksums, correcting algorithms, rewriting code I didn't like, or investigating unexpected slowness. Others were fine from the start. Either way, every implementation was reviewed for semantic correctness and idiomatic accuracy to ensure fair benchmarking.</p>

<h2>Core Philosophy</h2>

<ul class="philosophy-list">
  <li><strong>Code for Humans:</strong> Benchmarks are written in a clear, idiomatic style that prioritizes readability and maintainability. No bit hacks, no arcane optimizations, no clever tricks - just code you'd actually want to maintain in production. All the optimizations should be done by the compiler - you should be able to wake up at 3 AM 5 years from now and still understand this code.</li>
  <li><strong>Algorithmic Consistency:</strong> The same core algorithm is used across all languages for each task (exceptions possible).</li>
  <li><strong>Standard vs Unsafe Modes:</strong> All benchmarks use standard production compiler flags (safe mode by default). A separate <strong>"Hacking" section</strong> explores unsafe optimizations - disabling bounds checks, runtime checks, and other trade-offs that prioritize speed over safety.</li>
  <li><strong>Testing Language "Muscle":</strong> We measure the cost of abstractions. Can a language optimize clean, idiomatic code to efficient machine code? Languages that can (like Rust, Java) prove their compilers are powerful. Those that can't reveal the honest price of their abstractions. Benchmarks like matrix multiplication use <strong>naive implementations</strong> intentionally - not to measure C library calls (e.g., BLAS via numpy), but to see how efficiently the language handles fundamental computational patterns. Because one day, you'll have to write that loop yourself.</li>
  <li><strong>Pull Requests Welcome:</strong> Improvements that maintain this philosophy and fix suboptimal implementations are encouraged.</li>
</ul>

<h2>Benchmarking Methodology</h2>

<p>Each benchmark runs in isolation, with data preparation excluded from timing. JIT-based languages (C#, Java, Julia, etc.) receive a separate warmup phase to reach steady-state performance before measurements begin. This ensures fair comparisons. Checksums verify algorithmic correctness across all implementations.</p>

<h2>Disclaimer: This Is a Subjective Benchmark</h2>

<p>LangArena is not an objective, peer-reviewed, or industry-standard benchmark suite. It represents my personal vision of what "clean", "idiomatic" code looks like across many languages.</p>

<p>The rules, library choices, implementation styles, and even which optimizations I consider "fair" - all of these live in my head. They are not formalized, not voted on, and not guaranteed to be "correct" by any external standard.</p>

<h3>Think I'm wrong?</h3>

<ul>
  <li>If you disagree with a library choice or implementation - you're probably right.</li>
  <li>You are welcome to open an issue or a PR with suggestions.</li>
  <li>However, whether I accept or reject your change depends solely on my subjective judgment - not on community consensus, not on "popularity", not on objective metrics. I prioritize maintaining the benchmark's philosophy over chasing better numbers.</li>
</ul>

<h3>Runtime Score: Reducing the Impact of Subjectivity</h3>

<p>The Runtime Score is a normalized 0–100 metric based on four reference points: <strong>100</strong> (best result), <strong>90</strong> (average of the fastest languages), <strong>50</strong> (overall average), and <strong>0</strong> (worst result). This normalization is applied per test, so each test contributes equally to the final score - regardless of its absolute runtime. The per-benchmark scores are then averaged across all 50 tests to produce the final Runtime Score for each language.</p>

<p><strong>Why this removes subjectivity:</strong></p>

<ul>
  <li>One "bad" implementation affects one benchmark out of 50 - just 2% of the final score.</li>
  <li>To significantly hurt a language's ranking, it would have to underperform consistently across many different tests.</li>
  <li>One lucky benchmark can't carry a language that's slow everywhere else.</li>
  <li>Even if I pick a "wrong" JSON library for some language, it affects only 3 tests - just 6% of the final score.</li>
</ul>

<p>The result: subjective choices - libraries, implementation details, even human errors - get smoothed out by the numbers. The final ranking reflects average performance across 50 diverse real-world tasks, not my pick for a single test.</p>

<h2>Does it make sense if it's subjective?</h2>

<p>It depends.</p>

<ul>
  <li><strong>Comparing languages by raw runtime in seconds?</strong> Fun to watch, useful per benchmark, but misleading as an overall ranking. One slow test can skew the entire picture.</li>
  <li><strong>Comparing languages by Runtime Score?</strong> Robust. It gives a holistic view across 50 diverse tests - smoothing out outliers and reducing the impact of any single decision. To score high in this metric is genuinely hard - a language has to be consistently strong across the board.</li>
  <li><strong>Comparing memory usage, compile time, and expressiveness?</strong> Solid. These depend less on implementation details and benefit from better averaging across benchmarks.</li>
  <li><strong>Comparing compilers/runtimes for the same language?</strong> Perfect. The code is identical - you can clearly see the difference between TypeScript/Node vs TypeScript/Bun, Java vs GraalVM, Clang vs GCC, CRuby vs Spinel, etc.</li>
  <li><strong>Tracking history over time?</strong> Monthly runs let you watch performance regressions and improvements as compilers mature.</li>
  <li><strong>Comparing different flags (safe vs unsafe)?</strong> Check the Hacking section for that.</li>
</ul>

<h2>Sources</h2>

<p>Benchmark ideas were taken from:</p>

<ul>
  <li>The Computer Language Benchmarks Game</li>
  <li>My own collections: <a href="https://github.com/kostya/benchmarks">benchmarks</a>, <a href="https://github.com/kostya/jit-benchmarks">jit-benchmarks</a>, <a href="https://github.com/kostya/crystal-benchmarks-game">crystal-benchmarks-game</a>, <a href="https://github.com/kostya/crystal-metric">crystal-metric</a></li>
  <li>Crystal code samples</li>
</ul>

<h2>Beyond Just Ranking</h2>

<p>This suite is also a practical tool for:</p>

<ul>
  <li><strong>Compiler Tracking</strong> - monitor performance regressions and improvements across compiler versions.</li>
  <li><strong>New Language Evaluation</strong> - get a standardized score to position a new language against established ones.</li>
</ul>

<h2>Hardware</h2>

<p>AMD Ryzen 7 3800X 8-Core, 78GB RAM (x86_64-linux-gnu)</p>

</div>
    `);
}