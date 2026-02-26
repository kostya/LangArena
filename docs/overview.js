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

.philosophy-list {
  list-style-type: none;
  padding-left: 0;
}

.philosophy-list li {
  background-color: #fafafa;
  padding: 0.8rem 1rem;
  margin-bottom: 0.5rem;
  border-left: 3px solid #888888;
  border-radius: 0;
}

.philosophy-list li strong {
  color: #000000;
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
</style>

<div class=overview>

<h1>LangArena: A Balanced Programming Language Benchmark Suite</h1>

<p><strong>LangArena</strong> is a collection of <span class="highlight">50+ diverse benchmarks</span> designed for a <span class="highlight">realistic, apples-to-apples comparison</span> of programming language performance. The goal is not to find the ultimate winner in micro-optimizations, but to evaluate how well each language's compiler or runtime optimizes clean and readable code.</p>

<h2>Origin & Approach</h2>

<p>The suite started with my original implementation in Crystal. AI tools assisted in translating it to other languages. Throughout this process, I reviewed and edited the implementation for semantic correctness and logical consistency to ensure idiomatic accuracy and fair benchmarking.</p>

<p>Not all algorithms could be implemented identically across all languages — simply because the languages are too different (this is particularly true for base64 and JSON tests). However, I made every effort to make the implementations as similar as possible to each other.</p>

<p><strong>Handling Library Differences</strong>: To address performance differences stemming from varying standard library implementations, I created a special tab in the results — Runtime Score. This metric normalizes execution times (seconds) into a 0–100 scoring system, where 50 represents the average performance across all languages. The overall Runtime Score is calculated as the average across all benchmarks. This approach reduces the impact of outliers and ensures a fair overall assessment: a language that excels in most tasks but struggles with one particular library implementation (like JSON parsing) isn't severely penalized. It reflects the real-world scenario where developers use a mix of algorithms and libraries.</p>

<p><strong>Sources:</strong> Benchmark ideas were taken from:</p>
<ul>
  <li><strong>The Computer Language Benchmarks Game</strong></li>
  <li><strong>My own collections:</strong> <a href="https://github.com/kostya/benchmarks">benchmarks</a>, <a href="https://github.com/kostya/jit-benchmarks">jit-benchmarks</a>, <a href="https://github.com/kostya/crystal-benchmarks-game">crystal-benchmarks-game</a>, <a href="https://github.com/kostya/crystal-metric">crystal-metric</a></li>
  <li><strong>Crystal code samples</strong></li>
</ul>

<h2>Core Philosophy</h2>

<ul class="philosophy-list">
  <li><strong>Clean Code:</strong> Benchmarks are written in a clear, idiomatic style that prioritizes readability and maintainability.</li>
  <li><strong>Algorithmic Consistency:</strong> The same core algorithm is implemented across all languages for each task to ensure a fair comparison.</li>
  <li><strong>No "Hacks":</strong> Low-level tricks, impractical compiler flags (e.g., bounds check disabling), or non-standard libraries are intentionally avoided.</li>
  <li><strong>Testing Language "Muscle":</strong> We measure the **cost of abstractions**. Can a language take clean, idiomatic code and optimize it to efficient machine code? Languages that can (like Rust, Java) prove their compilers are powerful. Languages that can't show the honest price of their abstractions. Benchmarks like matrix multiplication use **naive implementations** intentionally. We're not measuring how fast a language can call a C library (like BLAS via numpy), but how efficiently it handles fundamental computational patterns — because one day you'll have to write that loop yourself.</li>
  <li><strong>Pull Requests Welcome:</strong> While consistency is key, improvements that maintain the philosophy and fix suboptimal implementations are encouraged.</li>
</ul>

<h2>Benchmarking Methodology</h2>

<p>Each benchmark's execution time is measured in isolation, with data preparation excluded from timing. The suite includes a separate warmup phase for JIT-based languages (C#, Java, Julia, etc.) to allow compilation and optimization before measurements begin. This ensures fair comparisons by measuring steady-state performance where applicable, while still capturing cold-start characteristics for AOT-compiled languages. All benchmarks produce verifiable checksums to ensure algorithmic correctness across implementations.</p>

<h2>Benchmark Categories</h2>

<p>The benchmarks cover common practical tasks:</p>

<div class="category-list">
  <div class="category-item">
    <strong>JSON Processing:</strong> Parsing and generation
  </div>
  <div class="category-item">
    <strong>Data Encoding:</strong> Base64 encoding/decoding
  </div>
  <div class="category-item">
    <strong>Text Processing:</strong> Regex matching, string manipulation
  </div>
  <div class="category-item">
    <strong>Cryptography & Hashing:</strong> SHA-256, CRC32
  </div>
  <div class="category-item">
    <strong>Sorting Algorithms:</strong> Quick sort, merge sort
  </div>
  <div class="category-item">
    <strong>Graph Algorithms:</strong> BFS, DFS, Dijkstra, A* pathfinding
  </div>
  <div class="category-item">
    <strong>Mathematical Computations:</strong> Matrix multiplication, prime calculation, spectral norm
  </div>
  <div class="category-item">
    <strong>Simulations:</strong> N-body, Game of Life, neural network
  </div>
  <div class="category-item">
    <strong>Classic Benchmarks:</strong> Binary trees, Fannkuchredux, Mandelbrot (from Computer Language Benchmarks Game)
  </div>
</div>

<h2>Evaluated Languages</h2>

<p>The suite currently focuses on <strong>compiled and high-performance managed languages</strong>:</p>

<div class="languages">
  <span class="language-tag">C</span>
  <span class="language-tag">C++</span>
  <span class="language-tag">Crystal</span>
  <span class="language-tag">Rust</span>
  <span class="language-tag">Go</span>
  <span class="language-tag">Swift</span>
  <span class="language-tag">C#</span>
  <span class="language-tag">Java</span>
  <span class="language-tag">Kotlin</span>
  <span class="language-tag">TypeScript</span>
  <span class="language-tag">Zig</span>
  <span class="language-tag">D</span>
  <span class="language-tag">V</span>
  <span class="language-tag">Julia</span>
  <span class="language-tag">Nim</span>
  <span class="language-tag">F#</span>
  <span class="language-tag">Dart</span>
  <span class="language-tag">Python</span>
  <span class="language-tag">Odin</span>
  <span class="language-tag">Scala</span>
</div>

<p class="language-note">Languages like Python, Ruby, or PHP are intentionally excluded to maintain a focused comparison within a similar performance bracket.</p>

<h2>Beyond Just Ranking</h2>

<p>This suite is also a practical tool for:</p>

<div class="uses-list">
  <div class="use-card">
    <strong>Compiler Tracking</strong>
    Monitor performance regressions/improvements across compiler versions.
  </div>
  <div class="use-card">
    <strong>New Language Evaluation</strong>
    Get a standardized "score" to position a new language against established ones.
  </div>
</div>

<h2>Hardware</h2>

<p>AMD Ryzen 7 3800X 8-Core Processor 78GB (x86_64-linux-gnu)</p>

</div>
    `);
}