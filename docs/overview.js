function overview_tab($results) {
    $results.append(`
<style>
.langclash-overview {
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif;
  line-height: 1.6;
  color: #333;
  max-width: 1000px;
  margin: 0 auto;
  padding: 20px;
}

.langclash-overview .title {
  font-size: 2rem;
  font-weight: 700;
  color: #2c3e50;
  margin-bottom: 1.5rem;
  border-bottom: 3px solid #3498db;
  padding-bottom: 0.5rem;
}

.langclash-overview .intro {
  font-size: 1.1rem;
  margin-bottom: 2rem;
  color: #444;
}

.langclash-overview .section {
  margin-bottom: 2rem;
  background: #f8f9fa;
  border-radius: 8px;
  padding: 1.5rem;
  border-left: 4px solid #3498db;
}

.langclash-overview .section-title {
  font-size: 1.4rem;
  font-weight: 600;
  color: #2c3e50;
  margin-bottom: 1rem;
  display: flex;
  align-items: center;
  gap: 10px;
}

.langclash-overview .subsection {
  margin-top: 1rem;
}

.langclash-overview ul {
  padding-left: 1.5rem;
  margin: 0.75rem 0;
}

.langclash-overview li {
  margin-bottom: 0.5rem;
}

.langclash-overview .philosophy-list li {
  background: #e8f4fc;
  padding: 8px 12px;
  border-radius: 4px;
  margin-bottom: 8px;
  border-left: 3px solid #2980b9;
}

.langclash-overview .category-list {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(250px, 1fr));
  gap: 10px;
  margin-top: 1rem;
}

.langclash-overview .category-item {
  background: white;
  padding: 12px;
  border-radius: 6px;
  border: 1px solid #ddd;
  box-shadow: 0 2px 4px rgba(0,0,0,0.05);
}

.langclash-overview .category-item strong {
  color: #2c3e50;
  display: block;
  margin-bottom: 5px;
}

.langclash-overview .languages {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  margin: 1rem 0;
}

.langclash-overview .language-tag {
  background: #2c3e50;
  color: white;
  padding: 6px 12px;
  border-radius: 20px;
  font-family: 'Courier New', monospace;
  font-size: 0.9rem;
  font-weight: 500;
}

.langclash-overview .language-note {
  font-style: italic;
  color: #7f8c8d;
  margin-top: 0.5rem;
  padding-left: 1rem;
  border-left: 3px solid #bdc3c7;
}

.langclash-overview .uses-list {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
  gap: 15px;
  margin-top: 1rem;
}

.langclash-overview .use-card {
  background: white;
  padding: 15px;
  border-radius: 8px;
  border: 1px solid #e0e0e0;
}

.langclash-overview .use-card strong {
  color: #27ae60;
  display: block;
  margin-bottom: 8px;
  font-size: 1.1rem;
}

.langclash-overview .highlight {
  background: linear-gradient(120deg, #a1c4fd 0%, #c2e9fb 100%);
  padding: 3px 6px;
  border-radius: 4px;
  font-weight: 600;
}

.langclash-overview .code {
  font-family: 'Courier New', monospace;
  background: #2c3e50;
  color: #ecf0f1;
  padding: 2px 6px;
  border-radius: 4px;
  font-size: 0.9em;
}
</style>

<div class="langclash-overview">
  <h1 class="title">LangArena: A Balanced Programming Language Benchmark Suite</h1>
  
  <div class="intro">
    <strong>LangArena</strong> is a collection of <span class="highlight">41 diverse benchmarks</span> designed for a <span class="highlight">realistic, apples-to-apples comparison</span> of programming language performance. The goal is not to find the ultimate winner in micro-optimizations, but to evaluate how well each language's compiler or runtime optimizes clean, idiomatic, production-style code.
  </div>
  
  <div class="section">
    <h2 class="section-title">🔧 Origin & Approach</h2>
    <p>The suite started with my original implementation in Crystal. AI tools assisted in translating it to other languages. Throughout this process, I reviewed and edited the implementation for semantic correctness and logical consistency to ensure idiomatic accuracy and fair benchmarking.</p>
    <p>Not all algorithms could be implemented identically across all languages — simply because the languages are too different (this is particularly true for base64 and JSON tests). However, I made every effort to make the implementations as similar as possible to each other.</p>
    <p><strong>Handling Library Differences</strong>: To address performance differences stemming from varying standard library implementations, I created a special tab in the results — Runtime Score. This metric normalizes execution times (seconds) into a 0–100 scoring system, where 50 represents the average performance across all languages. The overall Runtime Score is calculated as the average across all benchmarks. This approach reduces the impact of outliers and ensures a fair overall assessment: a language that excels in most tasks but struggles with one particular library implementation (like JSON parsing) isn't severely penalized. It reflects the real-world scenario where developers use a mix of algorithms and libraries.</p>

    <div class="subsection">
      <p><strong>Sources:</strong> Benchmark ideas were taken from:</p>
      <ul>
        <li><strong>The Computer Language Benchmarks Game</strong></li>
        <li><strong>My own collections:</strong> <a href="https://github.com/kostya/benchmarks">benchmarks</a>, <a href="https://github.com/kostya/jit-benchmarks">jit-benchmarks</a>, <a href="https://github.com/kostya/crystal-benchmarks-game">crystal-benchmarks-game</a>, <a href="https://github.com/kostya/crystal-metric">crystal-metric</a></li>
        <li><strong>Crystal code samples</strong></li>
      </ul>
    </div>
  </div>
  
  <div class="section">
    <h2 class="section-title">🎯 Core Philosophy</h2>
    <ul class="philosophy-list">
      <li><strong>Realistic Code:</strong> Benchmarks reflect how an average developer would solve a problem, using standard libraries and idiomatic constructs.</li>
      <li><strong>Algorithmic Consistency:</strong> The same core algorithm is implemented across all languages for each task to ensure a fair comparison.</li>
      <li><strong>No "Hacks":</strong> Low-level tricks, impractical compiler flags (e.g., bounds check disabling), or non-standard libraries are intentionally avoided.</li>
      <li><strong>Pull Requests Welcome:</strong> While consistency is key, improvements that maintain the philosophy and fix suboptimal implementations are encouraged.</li>
    </ul>
  </div>
  
  <div class="section">
    <h2 class="section-title">🔬 Benchmarking Methodology</h2>
    <p>Each benchmark's execution time is measured in isolation, with data preparation excluded from timing. The suite includes a separate warmup phase for JIT-based languages (C#, Java, Julia, etc.) to allow compilation and optimization before measurements begin. This ensures fair comparisons by measuring steady-state performance where applicable, while still capturing cold-start characteristics for AOT-compiled languages. All benchmarks produce verifiable checksums to ensure algorithmic correctness across implementations.</p>
  </div>

  <div class="section">
    <h2 class="section-title">📊 Benchmark Categories</h2>
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
  </div>
  
  <div class="section">
    <h2 class="section-title">🌍 Evaluated Languages</h2>
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
    </div>
    <p class="language-note">Languages like Python, Ruby, or PHP are intentionally excluded to maintain a focused comparison within a similar performance bracket.</p>
  </div>
  
  <div class="section">
    <h2 class="section-title">🚀 Beyond Just Ranking</h2>
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
  </div>
</div>
    `);
}