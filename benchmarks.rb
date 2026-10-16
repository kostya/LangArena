# Run all benchmarks and store results to ./results/
#
# `docker compose build` should be done before use this script
#
# Run all `ruby benchmarks.rb`
# Run only Lang Regex `ruby benchmarks.rb C++`
# Run only Lang Regex and Test Regex `ruby benchmarks.rb C++ JSON`
# Run Prod configs exclude Hack `PROD=1 ruby benchmarks.rb`
# Run test configs - just to check (faster finished) `TEST=1 ruby benchmarks.rb`

IS_VERBOSE = ENV["VERBOSE"] == "1" # show docker commands
IS_RUN_PROD = ENV["PROD"] == "1" # use only prod runs
IS_RUN_TEST = ENV["TEST"] == "1" # use test.js for testing, faster
IS_LOG_CRASH = true # ENV["LOG_CRASH"] == "1" # log instead of crash
IS_ONE_RUN_PER_LANG = ENV["BY_LANG"] == "1" # run only one run for each language
IS_NO_BUILD = ENV["NO_BUILD"] == "1" # not test build stage
IS_NO_DEPS = ENV["NO_DEPS"] == "1" # not test deps stage
IS_NO_VERSION = ENV["NO_VERSION"] == "1" # not test versions
APPEND_RESULTS = (ENV["APPEND"] && ENV["APPEND"] != "") ? ENV["APPEND"] : nil

require 'json'
require 'timeout'
require "fileutils"
FileUtils.mkdir_p("./results")
IS_MACOS = RUBY_PLATFORM =~ /darwin/
START_TIME = Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond)

def dotnet_runtime
  image_exists = system("docker image inspect langarena:dotnet > /dev/null 2>&1")  
  return "linux-x64" unless image_exists
  output = `docker compose run --rm -q dotnet dotnet --info | grep RID`.strip
  output =~ /RID:\s*(\S+)/ ? $1 : "linux-x64"
end

DOTNET_RUNTIME = dotnet_runtime
puts "Dotnet runtime: #{DOTNET_RUNTIME}"

PC = `docker compose run --rm -q base python3 pc_specs.py`.strip
puts "PC: #{PC}"

def measure
  t1 = Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond)
  yield
  t2 = Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond)
  ((t2 - t1) / 1e9)
end

RECOMPILE_MARKER_0 = "RECOMPILE_MARKER_0"
RECOMPILE_MARKER_1 = "RECOMPILE_MARKER_1"
RECOMPILE_MARKER_FILES = {}

LANG_MASKS = {
  'c' => ['./c', ['.c', '.h'], ['target', 'deps']],
  'c3' => ['./c3', ['.c3'], ['build']],
  'cpp' => ['./cpp', ['.cpp', '.hpp', '.h', '.cc', '.cxx'], ['target', 'deps']],
  'golang' => ['./golang', ['.go'], ['target']],
  'crystal' => ['./crystal', ['.cr'], ['target', 'lib']],
  'ruby' => ['./ruby', ['.rb'], []],
  'rust' => ['./rust', ['.rs'], ['target']],
  'csharp' => ['./csharp', ['.cs'], ['obj', 'bin']],
  'swift' => ['./swift', ['.swift'], ['.build', 'Package.swift']],
  'java' => ['./java', ['.java'], ['target']],
  'kotlin' => ['./kotlin', ['.kt'], ['build', '.gradle', 'gradle']],
  'typescript' => ['./typescript', ['.ts', '.tsx'], ['node_modules', 'target']],
  'zig' => ['./zig', ['.zig'], ['.zig-cache', 'zig-pkg']],
  'd' => ['./d', ['.d'], []],
  'v' => ['./v', ['.v'], ['target']],
  'julia' => ['./julia', ['.jl'], ['target']],
  'nim' => ['./nim', ['.nim'], ['target']],
  'fsharp' => ['./fsharp', ['.fs'], ['bin', 'obj']],
  'dart' => ['./dart', ['.dart'], ['target']],
  'python' => ['./python', ['.py'], ['__pycache__']],
  'odin' => ['./odin', ['.odin'], ['target']],
  'scala' => ['./scala', ['.scala'], ['target', 'project']],
  'php' => ['./php', ['.php'], []],
  'mojo' => ['./mojo', ['.mojo'], ['.pixi', 'target']],
  'gossamer' => ['./gossamer', ['.gos'], ['target', '.gos-cache']],
  'goose' => ['./goose', ['.goose'], ['target']],
  'javascript' => ['./javascript', ['.js'], []],
}

def check_source_files(verbose = false)
  require 'find'
  require 'zlib'
  require 'json'

  results = {}

  LANG_MASKS.each do |lang, (path, exts, exclude_dirs)|
    unless Dir.exist?(path)
      results[lang] = {"error" => "no dir", "files" => [], "source_kb" => 0, "gzip_kb" => 0}
      next
    end
    
    files = []
    Find.find(path) do |file_path|
      next unless File.file?(file_path)
      
      ext = File.extname(file_path).downcase
      next unless exts.include?(ext)
      
      skip = false
      exclude_dirs.each do |exclude|
        if file_path.include?(exclude)
          skip = true
          break
        end
      end
      next if skip
      
      relative_path = file_path.gsub(/^#{Regexp.escape(path)}\/?/, '')
      files << relative_path
    end
    
    if files.empty?
      results[lang] = {"files" => [], "source_kb" => 0, "gzip_kb" => 0}
      next
    end
    
    if verbose
      puts "\n=== #{lang} (#{path}) ==="
      files.each { |f| puts "  #{f}" }
    end
    
    total_bytes = 0
    content = ''
    
    files.each do |file|
      full_path = File.join(path, file)
      begin
        data = File.read(full_path, mode: 'rb')
        RECOMPILE_MARKER_FILES[lang] = full_path if data.include?(RECOMPILE_MARKER_0) && !RECOMPILE_MARKER_FILES[lang]
        total_bytes += data.bytesize
        content << data
      rescue => e
      end
    end
    
    source_kb = total_bytes / 1024.0
    gzip_kb = if content.empty?
      0
    else
      Zlib.gzip(content).bytesize / 1024.0
    end
    
    results[lang] = {
      "files" => files,
      "source_kb" => source_kb.round(2),
      "gzip_kb" => gzip_kb.round(2),
      "lines" => content.split("\n").size
    }
    
    puts "Language: #{lang}, Files: #{files.size}, Source: #{source_kb.round(1)}KB, Gzip: #{gzip_kb.round(1)}KB, Boilerplace: #{(source_kb / gzip_kb).round(1)}, Lines: #{content.split("\n").size}"
  end

  RESULTS["source-size-kb"] = results.transform_values { |data| data["source_kb"] }
  RESULTS["source-gzip-size-kb"] = results.transform_values { |data| data["gzip_kb"] }
  RESULTS["source-lines-count"] = results.transform_values { |data| data["lines"] }
end

class Run
  attr_reader :name, :build_cmd, :binary_name, :run_cmd, :version_cmd, :container, :dir, :group, :deps_cmd
  def initialize(name:, build_cmd:, binary_name:, run_cmd:, version_cmd:, container:, dir:, group:, deps_cmd:)
    @name = name
    @dir = dir
    @container = container
    @build_cmd = build_cmd
    @binary_name = binary_name
    @run_cmd = run_cmd
    @version_cmd = version_cmd
    @group = group # ONLY :prod or :hack
    @deps_cmd = deps_cmd
  end

  def lang
    @dir.gsub("/src/", "")
  end

  def dcr
    "docker compose run --rm -q --remove-orphans #{@container} "
  end

  def rss_prefix
    "/usr/bin/time -f 'MaxRSS(%M)KB\nuser_time=%U\nsystem_time=%S\nwall_time=%e' 2>&1 "
  end

  def execute_cmd(cmd)
    require 'open3'
    stdout, stderr, status = Open3.capture3(cmd)
    [stdout, stderr, status.exitstatus]
  end

  def run(cmd, debug = false)
    cmd = %Q|#{dcr}#{rss_prefix} #{cmd}|
    
    if debug
      print cmd
    end
    
    stdout, stderr, exitstatus = execute_cmd(cmd)
    
    if exitstatus != 0
      if IS_LOG_CRASH
        msg = "Failed `#{cmd}`, exitstatus: #{exitstatus}, stderr: `#{stderr}`"
        puts msg
        File.open("/tmp/log_crash.txt", "a") { |f| f.puts "#{Time.now}: #{msg}" }
      else
        raise "Failed to build `#{cmd}`, exitstatus: #{exitstatus}"
      end
    end
    
    stdout =~ /MaxRSS\(([0-9]*?)\)KB\n/
    rss = $1.to_i
    
    stdout =~ /user_time=([\d.]+)\n/
    user_time = $1.to_f
    
    stdout =~ /system_time=([\d.]+)\n/
    system_time = $1.to_f
    
    stdout =~ /wall_time=([\d.]+)\n/
    wall_time = $1.to_f

    cleaned_stdout = stdout.sub(/MaxRSS\(([0-9]*?)\)KB\n/, "")
                        .sub(/user_time=[\d.]+\n/, "")
                        .sub(/system_time=[\d.]+\n/, "")
                        .sub(/wall_time=[\d.]+\n/, "")
    
    h = {
      out: cleaned_stdout,
      rss: rss,
      user_time: user_time,
      system_time: system_time,
      cpu_total: user_time + system_time,
      wall_time: wall_time,
    }
    
    h
  end

  def remove_binary
    execute_cmd("#{dcr} rm -f #{binary_name}")
  end

  def deps
    cmd = "sh -c '#{@deps_cmd}'"
    run(cmd, IS_VERBOSE)
  end

  def version
    s, _, _ = execute_cmd("#{dcr} #{@version_cmd}")
    v = s.strip
    v.gsub("\n", " | ")
  end
end

RUNS = [

  # ======================================= C ======================================================  
  Run.new(
    name: "C/Clang", 
    build_cmd: "make -j prod",
    binary_name: "./target/prod/benchmark",
    run_cmd: "./target/prod/benchmark", 
    version_cmd: "cc --version | head -n 1",
    dir: "/src/c",
    container: "clang_c",
    group: :prod,
    deps_cmd: "make deps",
  ),
  
  Run.new(
    name: "C/Gcc", 
    build_cmd: "make -j prod",
    binary_name: "./target/prod/benchmark",
    run_cmd: "./target/prod/benchmark", 
    version_cmd: "cc --version | head -n 1",
    dir: "/src/c",
    container: "gcc_c",
    group: :prod,
    deps_cmd: "make deps",
  ),
  
  Run.new(
    name: "C/Clang/Fast", 
    build_cmd: "make -j fast",
    binary_name: "./target/fast/benchmark",
    run_cmd: "./target/fast/benchmark", 
    version_cmd: "cc --version | head -n 1",
    dir: "/src/c",
    container: "clang_c",
    group: :hack,
    deps_cmd: "make deps",
  ),
  
  Run.new(
    name: "C/Gcc/Fast", 
    build_cmd: "make -j fast",
    binary_name: "./target/fast/benchmark",
    run_cmd: "./target/fast/benchmark", 
    version_cmd: "cc --version | head -n 1",
    dir: "/src/c",
    container: "gcc_c",
    group: :hack,
    deps_cmd: "make deps",
  ),
  
  Run.new(
    name: "C/Clang/Unsafe", 
    build_cmd: "make -j unsafe",
    binary_name: "./target/unsafe/benchmark",
    run_cmd: "./target/unsafe/benchmark", 
    version_cmd: "cc --version | head -n 1",
    dir: "/src/c",
    container: "clang_c",
    group: :hack,
    deps_cmd: "make deps",
  ),
  
  Run.new(
    name: "C/Gcc/Unsafe", 
    build_cmd: "make -j unsafe",
    binary_name: "./target/unsafe/benchmark",
    run_cmd: "./target/unsafe/benchmark", 
    version_cmd: "cc --version | head -n 1",
    dir: "/src/c",
    container: "gcc_c",
    group: :hack,
    deps_cmd: "make deps",
  ),

  # ======================================= C Mycc ======================================================

  Run.new(
    name: "C/mycc/LLVM/Default", 
    build_cmd: "make -f Makefile_mycc BACKEND=llvm -j",
    binary_name: "./target/mycc-llvm-default-gcc/benchmark",
    run_cmd: "./target/mycc-llvm-default-gcc/benchmark", 
    version_cmd: "mycc --backend llvm --version",
    dir: "/src/c",
    container: "mycc",
    group: :hack,
    deps_cmd: "make -f Makefile_mycc deps",
  ),

  Run.new(
    name: "C/mycc/QBE/Default", 
    build_cmd: "make -f Makefile_mycc BACKEND=qbe -j",
    binary_name: "./target/mycc-qbe-default-gcc/benchmark",
    run_cmd: "./target/mycc-qbe-default-gcc/benchmark", 
    version_cmd: "mycc --backend qbe --version",
    dir: "/src/c",
    container: "mycc",
    group: :hack,
    deps_cmd: "make -f Makefile_mycc deps",
  ),

  Run.new(
    name: "C/mycc/C-Clang", 
    build_cmd: "make -f Makefile_mycc BACKEND=c COMPILER=clang -j",
    binary_name: "./target/mycc-c-default-clang/benchmark",
    run_cmd: "./target/mycc-c-default-clang/benchmark", 
    version_cmd: "mycc --backend c --version",
    dir: "/src/c",
    container: "mycc",
    group: :hack,
    deps_cmd: "make -f Makefile_mycc deps",
  ),

  Run.new(
    name: "C/mycc/LLVM/Final", 
    build_cmd: "make -f Makefile_mycc BACKEND=llvm MODE=final -j",
    binary_name: "./target/mycc-llvm-final-gcc/benchmark",
    run_cmd: "./target/mycc-llvm-final-gcc/benchmark", 
    version_cmd: "mycc --backend llvm --version",
    dir: "/src/c",
    container: "mycc",
    group: :prod,
    deps_cmd: "make -f Makefile_mycc deps",
  ),

  Run.new(
    name: "C/mycc/QBE/Final", 
    build_cmd: "make -f Makefile_mycc BACKEND=qbe MODE=final -j",
    binary_name: "./target/mycc-qbe-final-gcc/benchmark",
    run_cmd: "./target/mycc-qbe-final-gcc/benchmark", 
    version_cmd: "mycc --backend qbe --version",
    dir: "/src/c",
    container: "mycc",
    group: :hack,
    deps_cmd: "make -f Makefile_mycc deps",
  ),

  Run.new(
    name: "C/mycc/C-Clang/Final", 
    build_cmd: "make -f Makefile_mycc BACKEND=c MODE=final COMPILER=clang -j",
    binary_name: "./target/mycc-c-final-clang/benchmark",
    run_cmd: "./target/mycc-c-final-clang/benchmark", 
    version_cmd: "mycc --backend c --version",
    dir: "/src/c",
    container: "mycc",
    group: :hack,
    deps_cmd: "make -f Makefile_mycc deps",
  ),

  Run.new(
    name: "C/cproc/QBE", 
    build_cmd: "make -f Makefile_cproc -j",
    binary_name: "./target/cproc/benchmark",
    run_cmd: "./target/cproc/benchmark", 
    version_cmd: "echo 'cproc d1c53dd, qbe e786f06'",
    dir: "/src/c",
    container: "cproc",
    group: :hack,
    deps_cmd: "make -f Makefile_cproc deps",
  ),

  # ======================================= C PGO ======================================================

  Run.new(
    name: "C/Clang/PGO/Gen", 
    build_cmd: "make -j pgo-clang-gen",
    binary_name: "./target/pgo-clang-gen/benchmark",
    run_cmd: "./target/pgo-clang-gen/benchmark", 
    version_cmd: "cc --version | head -n 1",
    dir: "/src/c",
    container: "clang_c",
    group: :pgo_gen,
    deps_cmd: "make deps",
  ),
  
  Run.new(
    name: "C/Clang/PGO", 
    build_cmd: "make -j pgo-clang",
    binary_name: "./target/pgo-clang/benchmark",
    run_cmd: "./target/pgo-clang/benchmark", 
    version_cmd: "cc --version | head -n 1",
    dir: "/src/c",
    container: "clang_c",
    group: :hack,
    deps_cmd: "make deps",
  ),

  Run.new(
    name: "C/Gcc/PGO/Gen", 
    build_cmd: "make -j pgo-gcc-gen",
    binary_name: "./target/pgo-gcc-gen/benchmark",
    run_cmd: "./target/pgo-gcc-gen/benchmark", 
    version_cmd: "cc --version | head -n 1",
    dir: "/src/c",
    container: "gcc_c",
    group: :pgo_gen,
    deps_cmd: "make deps",
  ),
  
  Run.new(
    name: "C/Gcc/PGO", 
    build_cmd: "make -j pgo-gcc",
    binary_name: "./target/pgo-gcc/benchmark",
    run_cmd: "./target/pgo-gcc/benchmark", 
    version_cmd: "cc --version | head -n 1",
    dir: "/src/c",
    container: "gcc_c",
    group: :hack,
    deps_cmd: "make deps",
  ),
  
  # ======================================= С++ ======================================================
  Run.new(
    name: "C++/Clang++", 
    build_cmd: "make -j prod",
    binary_name: "./target/prod/benchmark",
    run_cmd: "./target/prod/benchmark", 
    version_cmd: "g++ --version | head -n 1",
    dir: "/src/cpp",
    container: "clang_cpp",
    group: :prod,
    deps_cmd: "make deps",
  ),

  Run.new(
    name: "C++/G++", 
    build_cmd: "make -j prod",
    binary_name: "./target/prod/benchmark",
    run_cmd: "./target/prod/benchmark", 
    version_cmd: "g++ --version | head -n 1",
    dir: "/src/cpp",
    container: "gcc_cpp",
    group: :prod,
    deps_cmd: "make deps",
  ),

  Run.new(
    name: "C++/Clang++/Fast", 
    build_cmd: "make -j fast",
    binary_name: "./target/fast/benchmark",
    run_cmd: "./target/fast/benchmark", 
    version_cmd: "g++ --version | head -n 1",
    dir: "/src/cpp",
    container: "clang_cpp",
    group: :hack,
    deps_cmd: "make deps",
  ),

  Run.new(
    name: "C++/G++/Fast", 
    build_cmd: "make -j fast",
    binary_name: "./target/fast/benchmark",
    run_cmd: "./target/fast/benchmark", 
    version_cmd: "g++ --version | head -n 1",
    dir: "/src/cpp",
    container: "gcc_cpp",
    group: :hack,
    deps_cmd: "make deps",
  ),

  Run.new(
    name: "C++/Clang++/Unsafe", 
    build_cmd: "make -j unsafe",
    binary_name: "./target/unsafe/benchmark",
    run_cmd: "./target/unsafe/benchmark", 
    version_cmd: "g++ --version | head -n 1",
    dir: "/src/cpp",
    container: "clang_cpp",
    group: :hack,
    deps_cmd: "make deps",
  ),

  Run.new(
    name: "C++/G++/Unsafe", 
    build_cmd: "make -j unsafe",
    binary_name: "./target/unsafe/benchmark",
    run_cmd: "./target/unsafe/benchmark", 
    version_cmd: "g++ --version | head -n 1",
    dir: "/src/cpp",
    container: "gcc_cpp",
    group: :hack,
    deps_cmd: "make deps",
  ),

  # ======================================= C++ PGO ======================================================

  Run.new(
    name: "C++/Clang++/PGO/Gen", 
    build_cmd: "make -j pgo-clang-gen",
    binary_name: "./target/pgo-clang-gen/benchmark",
    run_cmd: "./target/pgo-clang-gen/benchmark", 
    version_cmd: "g++ --version | head -n 1",
    dir: "/src/cpp",
    container: "clang_cpp",
    group: :pgo_gen,
    deps_cmd: "make deps",
  ),

  Run.new(
    name: "C++/Clang++/PGO", 
    build_cmd: "make -j pgo-clang",
    binary_name: "./target/pgo-clang/benchmark",
    run_cmd: "./target/pgo-clang/benchmark", 
    version_cmd: "g++ --version | head -n 1",
    dir: "/src/cpp",
    container: "clang_cpp",
    group: :hack,
    deps_cmd: "make deps",
  ),

  Run.new(
    name: "C++/G++/PGO/Gen", 
    build_cmd: "make -j pgo-gcc-gen",
    binary_name: "./target/pgo-gcc-gen/benchmark",
    run_cmd: "./target/pgo-gcc-gen/benchmark", 
    version_cmd: "g++ --version | head -n 1",
    dir: "/src/cpp",
    container: "gcc_cpp",
    group: :pgo_gen,
    deps_cmd: "make deps",
  ),

  Run.new(
    name: "C++/G++/PGO", 
    build_cmd: "make -j pgo-gcc",
    binary_name: "./target/pgo-gcc/benchmark",
    run_cmd: "./target/pgo-gcc/benchmark", 
    version_cmd: "g++ --version | head -n 1",
    dir: "/src/cpp",
    container: "gcc_cpp",
    group: :hack,
    deps_cmd: "make deps",
  ),

  # ======================================= Rust ======================================================
  Run.new(
    name: "Rust", 
    build_cmd: "cargo build --release", 
    binary_name: "./target/release/benchmarks", 
    run_cmd: "./target/release/benchmarks", 
    version_cmd: "rustc --version  | head -n 1",
    dir: "/src/rust",
    container: "rust",
    group: :prod,
    deps_cmd: "cargo fetch",
  ),
  Run.new(
    name: "Rust/WMO", 
    build_cmd: "cargo build --profile wmo", 
    binary_name: "./target/wmo/benchmarks", 
    run_cmd: "./target/wmo/benchmarks", 
    version_cmd: "rustc --version  | head -n 1",
    dir: "/src/rust",
    container: "rust",
    group: :hack,
    deps_cmd: "cargo fetch",
  ),
  Run.new(
    name: "Rust/WMO/Unchecked", 
    build_cmd: "cargo build --profile no-checks", 
    binary_name: "./target/no-checks/benchmarks", 
    run_cmd: "./target/no-checks/benchmarks", 
    version_cmd: "rustc --version  | head -n 1",
    dir: "/src/rust",
    container: "rust",
    group: :hack,
    deps_cmd: "cargo fetch",
  ),
  Run.new(
    name: "Rust/MaxPerf/Unsafe", 
    build_cmd: "cargo build --profile max-perf", 
    binary_name: "./target/max-perf/benchmarks", 
    run_cmd: "./target/max-perf/benchmarks", 
    version_cmd: "rustc --version  | head -n 1",
    dir: "/src/rust",
    container: "rust",
    group: :hack,
    deps_cmd: "cargo fetch",
  ),

  # ======================================= Rust WASM ======================================================
  
  Run.new(
    name: "Rust/WASM/Node", 
    build_cmd: "sh -c 'cargo build --target wasm32-wasip1 --release; wasm-opt -O3 target/wasm32-wasip1/release/benchmarks.wasm -o target/wasm32-wasip1/release/benchmarks-opt.wasm'", 
    binary_name: "target/wasm32-wasip1/release/benchmarks-opt.wasm", 
    run_cmd: "node node-wasi-runner.js", 
    version_cmd: "/bin/bash -c 'echo \"Rust->WASM $(rustc --version  | head -n 1), Node $(node --version)\"'",
    dir: "/src/rust",
    container: "rust_wasm",
    group: :prod,
    deps_cmd: "cargo fetch",
  ),

  Run.new(
    name: "Rust/WASM/Wasmtime", 
    build_cmd: "sh -c 'cargo build --target wasm32-wasip1 --release; wasm-opt -O3 target/wasm32-wasip1/release/benchmarks.wasm -o target/wasm32-wasip1/release/benchmarks-opt.wasm'", 
    binary_name: "target/wasm32-wasip1/release/benchmarks-opt.wasm", 
    run_cmd: "wasmtime run target/wasm32-wasip1/release/benchmarks-opt.wasm", 
    version_cmd: "/bin/bash -c 'echo \"Rust->WASM $(rustc --version  | head -n 1), $(wasmtime --version)\"'",
    dir: "/src/rust",
    container: "rust_wasm",
    group: :hack,
    deps_cmd: "cargo fetch",
  ),

  Run.new(
    name: "Rust/WASM/Wasmer", 
    build_cmd: "sh -c 'cargo build --target wasm32-wasip1 --release; wasm-opt -O3 target/wasm32-wasip1/release/benchmarks.wasm -o target/wasm32-wasip1/release/benchmarks-opt.wasm'", 
    binary_name: "target/wasm32-wasip1/release/benchmarks-opt.wasm", 
    run_cmd: "wasmer run target/wasm32-wasip1/release/benchmarks-opt.wasm", 
    version_cmd: "/bin/bash -c 'echo \"Rust->WASM $(rustc --version  | head -n 1), $(wasmer --version)\"'",
    dir: "/src/rust",
    container: "rust_wasm",
    group: :hack,
    deps_cmd: "cargo fetch",
  ),

  Run.new(
    name: "Rust/WASM/WasmEdge", 
    build_cmd: "sh -c 'cargo build --target wasm32-wasip1 --release; wasm-opt -O3 target/wasm32-wasip1/release/benchmarks.wasm -o target/wasm32-wasip1/release/benchmarks-opt.wasm; wasmedge compile target/wasm32-wasip1/release/benchmarks-opt.wasm target/wasm32-wasip1/release/benchmarks-opt-aot.wasm'", 
    binary_name: "target/wasm32-wasip1/release/benchmarks-opt-aot.wasm", 
    run_cmd: "wasmedge --run-mode=aot --dir=. target/wasm32-wasip1/release/benchmarks-opt-aot.wasm", 
    version_cmd: "/bin/bash -c 'echo \"Rust->WASM $(rustc --version  | head -n 1), $(wasmedge --version | head -n 1)\"'",
    dir: "/src/rust",
    container: "rust_wasm",
    group: :hack,
    deps_cmd: "cargo fetch",
  ),

  # ======================================= Rust PGO ======================================================

  Run.new(
    name: "Rust/PGO/Gen",
    build_cmd: <<~CMD.chomp,
      sh -c '
        RUSTFLAGS="-Cprofile-generate=target/pgo-data" cargo build --release --target-dir=target/pgo-gen
      '
    CMD
    binary_name: "./target/pgo-gen/release/benchmarks",
    run_cmd: "./target/pgo-gen/release/benchmarks",
    version_cmd: "rustc --version | head -n 1",
    dir: "/src/rust",
    container: "rust",
    group: :pgo_gen,
    deps_cmd: "cargo fetch",
  ),

  Run.new(
    name: "Rust/PGO",
    build_cmd: <<~CMD.chomp,
      sh -c '
        if [ ! -d "target/pgo-data" ] || [ -z "$(ls -A target/pgo-data)" ]; then
          echo "Error: No PGO data found. Run Rust/PGO/Gen first.";
          exit 1;
        fi;
        llvm-profdata merge -o target/pgo-data/merged.profdata target/pgo-data;
        RUSTFLAGS="-Cprofile-use=/src/rust/target/pgo-data/merged.profdata -Cllvm-args=-pgo-warn-missing-function -Cllvm-args=--pgo-verify-bfi" cargo build --release --target-dir=target/pgo-use
      '
    CMD
    binary_name: "./target/pgo-use/release/benchmarks",
    run_cmd: "./target/pgo-use/release/benchmarks",
    version_cmd: "rustc --version | head -n 1",
    dir: "/src/rust",
    container: "rust",
    group: :hack,
    deps_cmd: "cargo fetch",
  ),

  # ======================================= Zig ======================================================

  Run.new(
    name: "Zig", 
    build_cmd: "zig build build-zig",
    binary_name: "./zig-out/bin/zig",
    run_cmd: "./zig-out/bin/zig", 
    version_cmd: "zig version",
    dir: "/src/zig",
    container: "zig",
    group: :prod,
    deps_cmd: "zig libc; zig build --fetch",
  ),

  Run.new(
    name: "Zig/Unchecked", 
    build_cmd: "zig build build-unchecked",
    binary_name: "./zig-out/bin/zig-unchecked",
    run_cmd: "./zig-out/bin/zig-unchecked", 
    version_cmd: "zig version",
    dir: "/src/zig",
    container: "zig",
    group: :hack,
    deps_cmd: "zig libc; zig build --fetch",
  ),

  # ======================================= crystal ======================================================
  Run.new(
    name: "Crystal", 
    build_cmd: "crystal build main.cr --release -o ./target/bin_crystal", 
    binary_name: "./target/bin_crystal", 
    run_cmd: "./target/bin_crystal", 
    version_cmd: "crystal --version | head -n 1",
    dir: "/src/crystal",
    container: "crystal",
    group: :prod,
    deps_cmd: "mkdir -p target ; shards install",
  ),

  Run.new(
    name: "Crystal/O3", 
    build_cmd: "crystal build main.cr -O3 -o ./target/bin_crystal_o3", 
    binary_name: "./target/bin_crystal_o3", 
    run_cmd: "./target/bin_crystal_o3", 
    version_cmd: "crystal --version | head -n 1",
    dir: "/src/crystal",
    container: "crystal",
    group: :hack,
    deps_cmd: "mkdir -p target ; shards install",
  ),

  # ======================================= Mojo ======================================================
  
  Run.new(
    name: "Mojo", 
    build_cmd: "pixi run mojo build -O3 main.mojo -o target/bin_mojo",
    binary_name: "./target/bin_mojo",
    run_cmd: "./target/bin_mojo",
    version_cmd: "pixi run mojo --version",
    dir: "/src/mojo",
    container: "mojo",
    group: :prod, 
    deps_cmd: "pixi install; mkdir -p target",
  ),

  # ======================================= D ======================================================

  Run.new(
    name: "D/DMD",
    build_cmd: "dub build --compiler=dmd -c release-dmd --build=release",
    binary_name: "./target/release/d_benchmarks_dmd_release",
    run_cmd: "./target/release/d_benchmarks_dmd_release",
    version_cmd: "dmd --version | head -n 1",
    dir: "/src/d",
    container: "dmd",
    group: :hack,
    deps_cmd: "dub fetch",
  ),

  Run.new(
    name: "D/DMD/Perf",
    build_cmd: "dub build --compiler=dmd -c perf-dmd --build=release",
    binary_name: "./target/release/d_benchmarks_dmd_perf",
    run_cmd: "./target/release/d_benchmarks_dmd_perf",
    version_cmd: "dmd --version | head -n 1",
    dir: "/src/d",
    container: "dmd",
    group: :hack,
    deps_cmd: "dub fetch",
  ),

  Run.new(
    name: "D/LDC",
    build_cmd: "dub build --compiler=ldc2 -c release-ldc --build=release",
    binary_name: "./target/release/d_benchmarks_ldc_release",
    run_cmd: "./target/release/d_benchmarks_ldc_release",
    version_cmd: "ldc2 --version | head -n 2",
    dir: "/src/d",
    container: "ldc",
    group: :prod,
    deps_cmd: "dub fetch",
  ),

  Run.new(
    name: "D/LDC/Perf",
    build_cmd: "dub build --compiler=ldc2 -c perf-ldc --build=release",
    binary_name: "./target/release/d_benchmarks_ldc_perf",
    run_cmd: "./target/release/d_benchmarks_ldc_perf",
    version_cmd: "ldc2 --version | head -n 2",
    dir: "/src/d",
    container: "ldc",
    group: :hack,
    deps_cmd: "dub fetch",
  ),

  Run.new(
    name: "D/LDC/MaxPerf",
    build_cmd: "dub build --compiler=ldc2 -c maxperf-ldc --build=release",
    binary_name: "./target/release/d_benchmarks_ldc_maxperf",
    run_cmd: "./target/release/d_benchmarks_ldc_maxperf",
    version_cmd: "ldc2 --version | head -n 2",
    dir: "/src/d",
    container: "ldc",
    group: :hack,
    deps_cmd: "dub fetch",
  ),

  # # GDC Slow and errors
  # Run.new(
  #   name: "D/GDC",
  #   build_cmd: "dub build --compiler=gdc -c release-gdc --build=release",
  #   binary_name: "./target/release/d_benchmarks_gdc_release",
  #   run_cmd: "./target/release/d_benchmarks_gdc_release",
  #   version_cmd: "gdc --version | head -n 1",
  #   dir: "/src/d",
  #   container: "gdc",
  #   group: :hack,
  #   deps_cmd: "dub fetch",
  # ),

  # # GDC Slow and errors
  # Run.new(
  #   name: "D/GDC/Perf",
  #   build_cmd: "dub build --compiler=gdc -c perf-gdc --build=release",
  #   binary_name: "./target/release/d_benchmarks_gdc_perf",
  #   run_cmd: "./target/release/d_benchmarks_gdc_perf",
  #   version_cmd: "gdc --version | head -n 1",
  #   dir: "/src/d",
  #   container: "gdc",
  #   group: :hack,
  #   deps_cmd: "dub fetch",
  # ),

  # # GDC Slow and errors
  # Run.new(
  #   name: "D/GDC/MaxPerf",
  #   build_cmd: "dub build --compiler=gdc -c maxperf-gdc --build=release",
  #   binary_name: "./target/release/d_benchmarks_gdc_maxperf",
  #   run_cmd: "./target/release/d_benchmarks_gdc_maxperf",
  #   version_cmd: "gdc --version | head -n 1",
  #   dir: "/src/d",
  #   container: "gdc",
  #   group: :hack,
  #   deps_cmd: "dub fetch",
  # ),

  # ======================================= Gossamer ======================================================

  Run.new(
    name: "Gossamer",
    build_cmd: "gos build --release",
    binary_name: "./target/release/gossamer",
    run_cmd: "./target/release/gossamer",
    version_cmd: "gos --version",
    dir: "/src/gossamer",
    container: "gossamer",
    group: :prod,
    deps_cmd: "true",
  ),

  # ======================================= Goose ======================================================

  Run.new(
    name: "Goose",
    build_cmd: "make prod",
    binary_name: "./target/benchmark",
    run_cmd: "./target/benchmark",
    version_cmd: "git -C /opt/goose log -1 --format='goose %h %cs'",
    dir: "/src/goose",
    container: "goose",
    group: :prod,
    deps_cmd: "mkdir -p target",
  ),

  # ======================================= V ======================================================

  Run.new(
    name: "V/GCC", 
    build_cmd: "v -enable-globals -cc gcc -prod -o target/v_gcc .",
    binary_name: "./target/v_gcc",
    run_cmd: "./target/v_gcc", 
    version_cmd: "v version",
    dir: "/src/v",
    container: "v_gcc",
    group: :hack,
    deps_cmd: "v install",
  ),

  Run.new(
    name: "V/GCC/Perf", 
    build_cmd: "v -enable-globals -cc gcc -prod -cflags '-O3 -march=native -flto' -o target/v_gcc_perf .",
    binary_name: "./target/v_gcc_perf",
    run_cmd: "./target/v_gcc_perf", 
    version_cmd: "v version",
    dir: "/src/v",
    container: "v_gcc",
    group: :hack,
    deps_cmd: "v install",
  ),

  # Many crashes
  # Run.new(
  #   name: "V/GCC/MaxPerf", 
  #   build_cmd: "v -enable-globals -cc gcc -prod -prealloc -cflags '-Ofast -march=native -flto -funroll-loops -ffast-math' -o target/v_gcc_max .", # -no-bounds-checking
  #   binary_name: "./target/v_gcc_max",
  #   run_cmd: "./target/v_gcc_max", 
  #   version_cmd: "v version",
  #   dir: "/src/v",
  #   container: "v_gcc",
  #   group: :hack,
  #   deps_cmd: "v install",
  # ),

  # Not compiles
  # Run.new(
  #   name: "V/GCC/Autofree", 
  #   build_cmd: "v -enable-globals -cc gcc -prod -autofree -o target/v_gcc_autofree .",
  #   binary_name: "./target/v_gcc_autofree",
  #   run_cmd: "./target/v_gcc_autofree", 
  #   version_cmd: "v version",
  #   dir: "/src/v",
  #   container: "v_gcc",
  #   group: :hack,
  #   deps_cmd: "v install",
  # ),

  Run.new(
    name: "V/Clang", 
    build_cmd: "v -enable-globals -cc clang -prod -o target/v_clang .",
    binary_name: "./target/v_clang",
    run_cmd: "./target/v_clang", 
    version_cmd: "v version",
    dir: "/src/v",
    container: "v_clang",
    group: :prod,
    deps_cmd: "v install",
  ),

  Run.new(
    name: "V/Clang/Perf", 
    build_cmd: "v -enable-globals -cc clang -prod -cflags '-O3 -march=native -flto' -o target/v_clang_perf .",
    binary_name: "./target/v_clang_perf",
    run_cmd: "./target/v_clang_perf", 
    version_cmd: "v version",
    dir: "/src/v",
    container: "v_clang",
    group: :hack,
    deps_cmd: "v install",
  ),

  # Many crashes
  # Run.new(
  #   name: "V/Clang/MaxPerf", 
  #   build_cmd: "v -enable-globals -cc clang -prod -prealloc -cflags '-Ofast -march=native -flto -funroll-loops -ffast-math' -o target/v_clang_max .",  # -no-bounds-checking
  #   binary_name: "./target/v_clang_max",
  #   run_cmd: "./target/v_clang_max", 
  #   version_cmd: "v version",
  #   dir: "/src/v",
  #   container: "v_clang",
  #   group: :hack,
  #   deps_cmd: "v install",
  # ),

  # Not compiles
  # Run.new(
  #   name: "V/Clang/Autofree", 
  #   build_cmd: "v -enable-globals -cc clang -prod -autofree -o target/v_clang_autofree .",
  #   binary_name: "./target/v_clang_autofree",
  #   run_cmd: "./target/v_clang_autofree", 
  #   version_cmd: "v version",
  #   dir: "/src/v",
  #   container: "v_clang",
  #   group: :hack,
  #   deps_cmd: "v install",
  # ),

  # ======================================= Go ======================================================
  
  Run.new(
    name: "Go", 
    build_cmd: "go build -buildvcs=false -o target/bin_go", 
    binary_name: "./target/bin_go", 
    run_cmd: "./target/bin_go", 
    version_cmd: "go version",
    dir: "/src/golang",
    container: "golang",
    group: :prod,
    deps_cmd: "mkdir -p target",
  ),
  Run.new(
    name: "Go/Opt", 
    build_cmd: "go build -buildvcs=false -a -trimpath -ldflags=\"-s -w -extldflags '-static'\" -tags=\"osusergo,netgo\" -o target/bin_go_opts", 
    binary_name: "./target/bin_go_opts", 
    run_cmd: "./target/bin_go_opts", 
    version_cmd: "go version",
    dir: "/src/golang",
    container: "golang",
    group: :hack,
    deps_cmd: "mkdir -p target",
  ),

  # cant compile 
  # Run.new(
  #   name: "Go/GccGo", 
  #   build_cmd: "sh -c 'gccgo -O2 *.go -o ./target/bin_gccgo'", 
  #   binary_name: "./target/bin_gccgo", 
  #   run_cmd: "./target/bin_gccgo", 
  #   version_cmd: "gccgo --version | head -n 1",
  #   dir: "/src/golang",
  #   container: "gccgo",
  #   group: :hack,
  #   deps_cmd: "mkdir -p target",
  # ),

  # cant compile 
  # Run.new(
  #   name: "Go/GccGo/Opt", 
  #   build_cmd: "sh -c 'gccgo -O3 -march=native -flto -fuse-linker-plugin -funroll-loops -fgo-optimize-allocs -static-libgo -s -w -fomit-frame-pointer -fno-semantic-interposition -fno-common -Bstatic *.go -o ./target/bin_gccgo_opt'", 
  #   binary_name: "./target/bin_gccgo_opt", 
  #   run_cmd: "./target/bin_gccgo_opt", 
  #   version_cmd: "gccgo --version | head -n 1",
  #   dir: "/src/golang",
  #   container: "gccgo",
  #   group: :hack,
  #   deps_cmd: "mkdir -p target",
  # ),

  # ======================================= C# ======================================================

  Run.new(
    name: "C#/JIT", 
    build_cmd: "dotnet build -c Release",
    binary_name: "./bin/Release/net11.0/Benchmark.dll",
    run_cmd: "dotnet ./bin/Release/net11.0/Benchmark.dll", 
    version_cmd: "dotnet --version",
    dir: "/src/csharp",
    container: "dotnet",   
    group: :prod, 
    deps_cmd: "dotnet restore",
  ),

  Run.new(
    name: "C#/AOT",
    build_cmd: <<~CMD.chomp,
      dotnet publish -c Release \
      -p:PublishAOT=true \
      -p:IlcOptimizationPreference=Speed \
      -p:IlcInstructionSet=native \
      -p:EnableCppCli=true \
      -p:InvariantGlobalization=true \
      -o ./bin/aot
    CMD
    binary_name: "./bin/aot/Benchmark",
    run_cmd: "./bin/aot/Benchmark", 
    version_cmd: "dotnet --version",
    dir: "/src/csharp",
    container: "dotnet",
    group: :hack,        
    deps_cmd: "dotnet restore",
  ),

  Run.new(
    name: "C#/SC-JIT",
    build_cmd: "dotnet publish -c Release --self-contained true --runtime #{DOTNET_RUNTIME} -p:PublishTrimmed=true -p:InvariantGlobalization=true -o ./bin/sc-jit",
    binary_name: "./bin/sc-jit/Benchmark",
    run_cmd: "./bin/sc-jit/Benchmark", 
    version_cmd: "dotnet --version",
    dir: "/src/csharp",
    container: "dotnet",  
    group: :hack,  
    deps_cmd: "dotnet restore",
  ),

  Run.new(
    name: "C#/SC-AOT",
    build_cmd: <<~CMD.chomp,
      dotnet publish -c Release \
      -p:PublishAOT=true \
      --self-contained true \
      --runtime linux-x64 \
      -p:IlcOptimizationPreference=Speed \
      -p:IlcInstructionSet=native \
      -p:EnableCppCli=true \
      -p:InvariantGlobalization=true \
      -p:IlcGenerateStackTraceData=false \
      -o ./bin/sc-aot
    CMD
    binary_name: "./bin/sc-aot/Benchmark",
    run_cmd: "./bin/sc-aot/Benchmark", 
    version_cmd: "dotnet --version",
    dir: "/src/csharp",
    container: "dotnet", 
    group: :hack, 
    deps_cmd: "dotnet restore",      
  ),

  Run.new(
    name: "C#/R2R",
    build_cmd: "dotnet publish -c Release -p:PublishReadyToRun=true -p:PublishTrimmed=true -p:InvariantGlobalization=true -o ./bin/r2r",
    binary_name: "./bin/r2r/Benchmark",
    run_cmd: "./bin/r2r/Benchmark", 
    version_cmd: "dotnet --version",
    dir: "/src/csharp",
    container: "dotnet",    
    group: :hack,   
    deps_cmd: "dotnet restore", 
  ),

  Run.new(
    name: "C#/AOT-EXTREME",
    build_cmd: <<~CMD.chomp,
      dotnet publish -c Release \
      -p:PublishAOT=true \
      -p:IlcOptimizationPreference=Speed \
      -p:IlcInstructionSet=native \
      -p:EnableCppCli=true \
      -p:InvariantGlobalization=true \
      -p:IlcGenerateStackTraceData=false \
      -p:IlcFoldIdenticalMethodBodies=true \
      -p:IlcGenerateCompleteTypeMetadata=false \
      -p:IlcMethodBodyLayout=HotCold \
      -p:IlcSingleMethodOptimization=aggressive \
      -o ./bin/aot-extreme
    CMD
    binary_name: "./bin/aot-extreme/Benchmark",
    run_cmd: "./bin/aot-extreme/Benchmark",
    version_cmd: "dotnet --version",
    dir: "/src/csharp",
    container: "dotnet", 
    group: :hack,   
    deps_cmd: "dotnet restore",
  ),  

  # ======================================= F# ======================================================
  
  Run.new(
    name: "F#/JIT", 
    build_cmd: "dotnet build -c Release",
    binary_name: "./bin/Release/net11.0/MyFirstFSharpApp.dll",
    run_cmd: "dotnet ./bin/Release/net11.0/MyFirstFSharpApp.dll", 
    version_cmd: "dotnet --version",
    dir: "/src/fsharp",
    container: "fsharp",   
    group: :prod, 
    deps_cmd: "dotnet restore",
  ),

  # JSON Bug run
  # Run.new(
  #   name: "F#/AOT",
  #   build_cmd: "dotnet publish -c Release -p:PublishAOT=true -p:InvariantGlobalization=true -o ./bin/aot",
  #   binary_name: "./bin/aot/MyFirstFSharpApp",
  #   run_cmd: "./bin/aot/MyFirstFSharpApp", 
  #   version_cmd: "dotnet --version",
  #   dir: "/src/fsharp",
  #   container: "fsharp",
  #   group: :hack,        
  #   deps_cmd: "dotnet restore",
  # ),

  # ======================================= Nim ======================================================

  Run.new(
    name: "Nim/GCC", 
    build_cmd: "nim c --threads:on -d:release --cc:gcc --out:target/bin_benchmarks_gcc src/benchmarks.nim",
    binary_name: "./target/bin_benchmarks_gcc",
    run_cmd: "./target/bin_benchmarks_gcc", 
    version_cmd: "nim --version | head -n 1",
    dir: "/src/nim",
    container: "nim_gcc",
    group: :hack,
    deps_cmd: "sh deps.sh",
  ),

  Run.new(
    name: "Nim/GCC/Danger", 
    build_cmd: "nim c --threads:on -d:danger --cc:gcc --out:target/bin_benchmarks_gcc_danger src/benchmarks.nim",
    binary_name: "./target/bin_benchmarks_gcc_danger",
    run_cmd: "./target/bin_benchmarks_gcc_danger", 
    version_cmd: "nim --version | head -n 1",
    dir: "/src/nim",
    container: "nim_gcc",
    group: :hack,
    deps_cmd: "sh deps.sh",
  ),

  Run.new(
    name: "Nim/GCC/Max", 
    build_cmd: "nim c --threads:on -d:danger --cc:gcc --opt:speed --boundChecks:off --passC:'-Ofast -march=native' --passL:'-flto' --out:target/bin_benchmarks_gcc_max src/benchmarks.nim",
    binary_name: "./target/bin_benchmarks_gcc_max",
    run_cmd: "./target/bin_benchmarks_gcc_max", 
    version_cmd: "nim --version | head -n 1",
    dir: "/src/nim",
    container: "nim_gcc",
    group: :hack,
    deps_cmd: "sh deps.sh",
  ),

  Run.new(
    name: "Nim/GCC/ARC", 
    build_cmd: "nim c --threads:on -d:release --cc:gcc --gc:arc --out:target/bin_benchmarks_gcc_arc src/benchmarks.nim",
    binary_name: "./target/bin_benchmarks_gcc_arc",
    run_cmd: "./target/bin_benchmarks_gcc_arc", 
    version_cmd: "nim --version | head -n 1",
    dir: "/src/nim",
    container: "nim_gcc",
    group: :hack,
    deps_cmd: "sh deps.sh",
  ),

  Run.new(
    name: "Nim/Clang", 
    build_cmd: "nim c --threads:on -d:release --cc:clang --out:target/bin_benchmarks_clang src/benchmarks.nim",
    binary_name: "./target/bin_benchmarks_clang",
    run_cmd: "./target/bin_benchmarks_clang", 
    version_cmd: "nim --version | head -n 1",
    dir: "/src/nim",
    container: "nim_clang",
    group: :prod,
    deps_cmd: "sh deps.sh",
  ),

  Run.new(
    name: "Nim/Clang/Danger", 
    build_cmd: "nim c --threads:on -d:danger --cc:clang --out:target/bin_benchmarks_clang_danger src/benchmarks.nim",
    binary_name: "./target/bin_benchmarks_clang_danger",
    run_cmd: "./target/bin_benchmarks_clang_danger", 
    version_cmd: "nim --version | head -n 1",
    dir: "/src/nim",
    container: "nim_clang",
    group: :hack,
    deps_cmd: "sh deps.sh",
  ),

  Run.new(
    name: "Nim/Clang/Max", 
    build_cmd: "nim c --threads:on -d:danger --cc:clang --opt:speed --boundChecks:off --passC:'-Ofast -march=native' --passL:'-flto=full' --out:target/bin_benchmarks_clang_max src/benchmarks.nim",
    binary_name: "./target/bin_benchmarks_clang_max",
    run_cmd: "./target/bin_benchmarks_clang_max", 
    version_cmd: "nim --version | head -n 1",
    dir: "/src/nim",
    container: "nim_clang",
    group: :hack,
    deps_cmd: "sh deps.sh",
  ),

  Run.new(
    name: "Nim/Clang/ARC", 
    build_cmd: "nim c --threads:on -d:release --cc:clang --gc:arc --out:target/bin_benchmarks_clang_arc src/benchmarks.nim",
    binary_name: "./target/bin_benchmarks_clang_arc",
    run_cmd: "./target/bin_benchmarks_clang_arc", 
    version_cmd: "nim --version | head -n 1",
    dir: "/src/nim",
    container: "nim_clang",
    group: :hack,
    deps_cmd: "sh deps.sh",
  ),

  Run.new(
    name: "Nim++/GCC", 
    build_cmd: "nim cpp --threads:on -d:release --cc:gcc --out:target/bin_benchmarks_gcc_cpp src/benchmarks.nim",
    binary_name: "./target/bin_benchmarks_gcc_cpp",
    run_cmd: "./target/bin_benchmarks_gcc_cpp", 
    version_cmd: "nim --version | head -n 1",
    dir: "/src/nim",
    container: "nim_gcc",
    group: :hack,
    deps_cmd: "nimble refresh",
  ),

  Run.new(
    name: "Nim++/GCC/Danger", 
    build_cmd: "nim cpp --threads:on -d:danger --cc:gcc --out:target/bin_benchmarks_gcc_cpp_danger src/benchmarks.nim",
    binary_name: "./target/bin_benchmarks_gcc_cpp_danger",
    run_cmd: "./target/bin_benchmarks_gcc_cpp_danger", 
    version_cmd: "nim --version | head -n 1",
    dir: "/src/nim",
    container: "nim_gcc",
    group: :hack,
    deps_cmd: "sh deps.sh",
  ),

  Run.new(
    name: "Nim++/Clang", 
    build_cmd: "nim cpp --threads:on -d:release --cc:clang --out:target/bin_benchmarks_clang_cpp src/benchmarks.nim",
    binary_name: "./target/bin_benchmarks_clang_cpp",
    run_cmd: "./target/bin_benchmarks_clang_cpp", 
    version_cmd: "nim --version | head -n 1",
    dir: "/src/nim",
    container: "nim_clang",
    group: :hack,
    deps_cmd: "sh deps.sh",
  ),

  Run.new(
    name: "Nim++/Clang/Danger", 
    build_cmd: "nim cpp --threads:on -d:danger --cc:clang --out:target/bin_benchmarks_clang_cpp_danger src/benchmarks.nim",
    binary_name: "./target/bin_benchmarks_clang_cpp_danger",
    run_cmd: "./target/bin_benchmarks_clang_cpp_danger", 
    version_cmd: "nim --version | head -n 1",
    dir: "/src/nim",
    container: "nim_clang",
    group: :hack,
    deps_cmd: "sh deps.sh",
  ),

  Run.new(
    name: "Nim/NLVM", 
    build_cmd: "nlvm c --threads:on -d:release --out:target/bin_benchmarks_nlvm src/benchmarks.nim",
    binary_name: "./target/bin_benchmarks_nlvm",
    run_cmd: "./target/bin_benchmarks_nlvm", 
    version_cmd: "nlvm --version | tail -n 3",
    dir: "/src/nim",
    container: "nim_nlvm",
    group: :hack,
    deps_cmd: "sh deps.sh",
  ),

  Run.new(
    name: "Nim/NLVM/Danger", 
    build_cmd: "nlvm c --threads:on -d:danger --out:target/bin_benchmarks_nlvm_danger src/benchmarks.nim",
    binary_name: "./target/bin_benchmarks_nlvm_danger",
    run_cmd: "./target/bin_benchmarks_nlvm_danger", 
    version_cmd: "nlvm --version | tail -n 3",
    dir: "/src/nim",
    container: "nim_nlvm",
    group: :hack,
    deps_cmd: "sh deps.sh",
  ),

  # ======================================= Nim PGO ======================================================

  # This is too slow, and weak effect
  # Run.new(
  #   name: "Nim/GCC/PGO/Gen",
  #   build_cmd: "nim c --threads:on -d:release --cc:gcc --passC:'-fprofile-generate' --passL:'-fprofile-generate' --out:target/bin_benchmarks_gcc_pgogen src/benchmarks.nim",
  #   binary_name: "./target/bin_benchmarks_gcc_pgogen",
  #   run_cmd: "./target/bin_benchmarks_gcc_pgogen",
  #   version_cmd: "nim --version | head -n 1",
  #   dir: "/src/nim",
  #   container: "nim_gcc",
  #   group: :pgo_gen,
  #   deps_cmd: "sh deps.sh",
  # ),

  # This is too slow, and weak effect
  # Run.new(
  #   name: "Nim/GCC/PGO",
  #   build_cmd: <<~CMD.chomp,
  #     sh -c '
  #       GCDA_DIR="/root/.cache/nim/benchmarks_r"
  #       if [ ! -d "$GCDA_DIR" ] || ! ls "$GCDA_DIR"/*.gcda 1> /dev/null 2>&1; then
  #         echo "Error: No .gcda files found in $GCDA_DIR"
  #         exit 1
  #       fi
  #       echo "Found .gcda files in: $GCDA_DIR"
  #       nim c --threads:on -d:release --cc:gcc \
  #         --passC:"-fprofile-use -fprofile-correction -fprofile-dir=$GCDA_DIR" \
  #         --passL:"-fprofile-use -fprofile-dir=$GCDA_DIR" \
  #         --out:target/bin_benchmarks_gcc_pgo src/benchmarks.nim
  #     '
  #   CMD
  #   binary_name: "./target/bin_benchmarks_gcc_pgo",
  #   run_cmd: "./target/bin_benchmarks_gcc_pgo",
  #   version_cmd: "nim --version | head -n 1",
  #   dir: "/src/nim",
  #   container: "nim_gcc",
  #   group: :pgo,
  #   deps_cmd: "sh deps.sh",
  # ),

  # This is too slow, and weak effect
  # Run.new(
  #   name: "Nim/Clang/PGO/Gen",
  #   build_cmd: "nim c --threads:on -d:release --cc:clang --passC:'-fprofile-instr-generate' --passL:'-fprofile-instr-generate' --out:target/bin_benchmarks_clang_pgogen src/benchmarks.nim",
  #   binary_name: "./target/bin_benchmarks_clang_pgogen",
  #   run_cmd: "./target/bin_benchmarks_clang_pgogen",
  #   version_cmd: "nim --version | head -n 1",
  #   dir: "/src/nim",
  #   container: "nim_clang",
  #   group: :pgo_gen,
  #   deps_cmd: "sh deps.sh",
  # ),

  # This is too slow, and weak effect
  # Run.new(
  #   name: "Nim/Clang/PGO",
  #   build_cmd: <<~CMD.chomp,
  #     sh -c '
  #       if [ ! -f "default.profraw" ]; then
  #         echo "Error: No default.profraw found. Run Nim/Clang/PGO/Gen first.";
  #         exit 1;
  #       fi
  #       llvm-profdata merge default.profraw -o target/default.profdata
  #       nim c --threads:on -d:release --cc:clang --passC:"-fprofile-instr-use=target/default.profdata" --passL:"-fprofile-instr-use=target/default.profdata" --out:target/bin_benchmarks_clang_pgo src/benchmarks.nim
  #     '
  #   CMD
  #   binary_name: "./target/bin_benchmarks_clang_pgo",
  #   run_cmd: "./target/bin_benchmarks_clang_pgo",
  #   version_cmd: "nim --version | head -n 1",
  #   dir: "/src/nim",
  #   container: "nim_clang",
  #   group: :pgo,
  #   deps_cmd: "sh deps.sh",
  # ),

  # ======================================= Julia ======================================================
  
  Run.new(
    name: "Julia/Default", 
    build_cmd: "true",
    binary_name: "benchmark.jl",
    run_cmd: "julia --project=. --threads=16 benchmark.jl", 
    version_cmd: "julia --version | head -n 1",
    dir: "/src/julia",
    container: "julia",
    group: :prod,
    deps_cmd: "sh deps.sh",
  ),

  # no effect  
  # Run.new(
  #   name: "Julia/Opt", 
  #   build_cmd: "true",
  #   binary_name: "benchmark.jl",
  #   run_cmd: "julia --project=. --threads=16 -O3 --check-bounds=no benchmark.jl", 
  #   version_cmd: "julia --version | head -n 1",
  #   dir: "/src/julia",
  #   container: "julia",
  #   group: :hack,
  #   deps_cmd: "sh deps.sh",
  # ),
  
  Run.new(
    name: "Julia/Max", 
    build_cmd: "true",
    binary_name: "benchmark.jl",
    run_cmd: "julia --project=. --threads=16 -O3 --check-bounds=no --math-mode=fast --inline=yes benchmark.jl", 
    version_cmd: "julia --version | head -n 1",
    dir: "/src/julia",
    container: "julia",
    group: :hack,
    deps_cmd: "sh deps.sh",
  ),

  # too slow compile  
  # Run.new(
  #   name: "Julia/AOT", 
  #   build_cmd: <<~CMD.chomp,
  #     julia --project=. -e '
  #       using PackageCompiler;
  #       create_sysimage([:BenchmarkFramework];
  #           sysimage_path="target/sysimage.so",
  #           precompile_execution_file="./benchmark.jl")
  #       '
  #   CMD
  #   binary_name: "target/sysimage.so",
  #   run_cmd: "julia --project=. --sysimage=target/sysimage.so --threads=16 benchmark.jl", 
  #   version_cmd: "julia --version | head -n 1",
  #   dir: "/src/julia",
  #   container: "julia",
  #   group: :hack,
  #   deps_cmd: "mkdir -p target; sh deps.sh",
  # ),

  # ======================================= Swift ======================================================

  Run.new(
    name: "Swift", 
    build_cmd: "swift build -c release -Xswiftc -O",
    binary_name: "./.build/release/Benchmarks",
    run_cmd: "./.build/release/Benchmarks", 
    version_cmd: "swift -version | head -n 1",
    dir: "/src/swift",
    container: "swift",
    group: :prod,
    deps_cmd: "swift package resolve",
  ),
  
  # Swift too slow, minimize configs
  # Run.new(
  #   name: "Swift/WMO", 
  #   build_cmd: "swift build -c release -Xswiftc -O -Xswiftc -whole-module-optimization",
  #   binary_name: "./.build/release/Benchmarks",
  #   run_cmd: "./.build/release/Benchmarks", 
  #   version_cmd: "swift -version | head -n 1",
  #   dir: "/src/swift",
  #   container: "swift",
  #   group: :hack,
  #   deps_cmd: "swift package resolve",
  # ),
  
  Run.new(
    name: "Swift/Unchecked", 
    build_cmd: "swift build -c release -Xswiftc -Ounchecked",
    binary_name: "./.build/release/Benchmarks", 
    run_cmd: "./.build/release/Benchmarks", 
    version_cmd: "swift -version | head -n 1",
    dir: "/src/swift",
    container: "swift",
    group: :hack,
    deps_cmd: "swift package resolve",
  ),
  
  # Swift too slow, minimize configs
  # Run.new(
  #   name: "Swift/WMO+Unchecked", 
  #   build_cmd: "swift build -c release -Xswiftc -O -Xswiftc -whole-module-optimization -Xswiftc -enforce-exclusivity=unchecked",
  #   binary_name: "./.build/release/Benchmarks",
  #   run_cmd: "./.build/release/Benchmarks", 
  #   version_cmd: "swift -version | head -n 1",
  #   dir: "/src/swift",
  #   container: "swift",
  #   group: :hack,
  #   deps_cmd: "swift package resolve",
  # ),
  
  # Swift too slow, minimize configs
  # Run.new(
  #   name: "Swift/MaxPerf", 
  #   build_cmd: "swift build -c release -Xswiftc -Ounchecked -Xswiftc -whole-module-optimization -Xswiftc -enforce-exclusivity=unchecked -Xswiftc -cross-module-optimization",
  #   binary_name: "./.build/release/Benchmarks",
  #   run_cmd: "./.build/release/Benchmarks", 
  #   version_cmd: "swift -version | head -n 1",
  #   dir: "/src/swift",
  #   container: "swift",
  #   group: :hack,
  #   deps_cmd: "swift package resolve",
  # ),

  # ======================================= Odin ======================================================

  Run.new(
    name: "Odin/Default", 
    build_cmd: <<-BUILD,
    odin build . \
      -o:speed \
      -out:target/bin_odin \
      -collection:benchmark=./benchmark
    BUILD
    binary_name: "target/bin_odin",
    run_cmd: "target/bin_odin", 
    version_cmd: "odin version",
    dir: "/src/odin",
    container: "odin",
    group: :prod,
    deps_cmd: "mkdir -p target",
  ),

  Run.new(
    name: "Odin/Opt", 
    build_cmd: <<-BUILD,
      odin build . \
        -o:speed \
        -out:target/bin_odin_optimized \
        -collection:benchmark=./benchmark \
        -microarch:native \
        -no-threaded-checker \
        -no-bounds-check
    BUILD
    binary_name: "target/bin_odin_optimized",
    run_cmd: "target/bin_odin_optimized", 
    version_cmd: "odin version",
    dir: "/src/odin",
    container: "odin",
    group: :hack,
    deps_cmd: "mkdir -p target",
  ),

  Run.new(
    name: "Odin/MaxPerf", 
    build_cmd: <<-BUILD,
      odin build . \
        -o:aggressive \
        -out:target/bin_odin_maxperf \
        -collection:benchmark=./benchmark \
        -microarch:native \
        -disable-assert \
        -no-bounds-check \
        -use-single-module
    BUILD
    binary_name: "target/bin_odin_maxperf",
    run_cmd: "target/bin_odin_maxperf", 
    version_cmd: "odin version",
    dir: "/src/odin",
    container: "odin",
    group: :hack,
    deps_cmd: "mkdir -p target",
  ),
    
  # ======================================= C3 ======================================================

  Run.new(
    name: "C3", 
    build_cmd: <<-BUILD,
      c3c build prod
    BUILD
    binary_name: "./build/prod",
    run_cmd: "./build/prod", 
    version_cmd: "c3c --version | sed -n '1p;5p'",
    dir: "/src/c3",
    container: "c3",
    group: :prod,
    deps_cmd: "true",
  ),

  Run.new(
    name: "C3/SingleModule", 
    build_cmd: <<-BUILD,
      c3c build prod_single_module
    BUILD
    binary_name: "./build/prod_single_module",
    run_cmd: "./build/prod_single_module", 
    version_cmd: "c3c --version | sed -n '1p;5p'",
    dir: "/src/c3",
    container: "c3",
    group: :hack,
    deps_cmd: "true",
  ),

  Run.new(
    name: "C3/Fast", 
    build_cmd: <<-BUILD,
      c3c build fast
    BUILD
    binary_name: "./build/fast",
    run_cmd: "./build/fast", 
    version_cmd: "c3c --version | sed -n '1p;5p'",
    dir: "/src/c3",
    container: "c3",
    group: :hack,
    deps_cmd: "true",
  ),

  Run.new(
    name: "C3/Fast/SingleModule", 
    build_cmd: <<-BUILD,
      c3c build fast_single_module
    BUILD
    binary_name: "./build/fast_single_module",
    run_cmd: "./build/fast_single_module", 
    version_cmd: "c3c --version | sed -n '1p;5p'",
    dir: "/src/c3",
    container: "c3",
    group: :hack,
    deps_cmd: "true",
  ),

  Run.new(
    name: "C3/Unsafe", 
    build_cmd: <<-BUILD,
      c3c build unsafe
    BUILD
    binary_name: "./build/unsafe",
    run_cmd: "./build/unsafe", 
    version_cmd: "c3c --version | sed -n '1p;5p'",
    dir: "/src/c3",
    container: "c3",
    group: :hack,
    deps_cmd: "true",
  ),

  # ======================================= Java ======================================================
  Run.new(
    name: "Java/OpenJDK",
    build_cmd: <<~CMD.chomp,
      mvn compile package -Pjava-plain -q
    CMD
    binary_name: "./target/java-benchmarks-1.0-SNAPSHOT.jar",
    run_cmd: <<~CMD.chomp,
      java \
        -Xmx2g \
        -jar ./target/java-benchmarks-1.0-SNAPSHOT.jar
    CMD
    version_cmd: "java --version",
    dir: "/src/java",
    container: "java",
    group: :prod,
    deps_cmd: "mvn dependency:resolve; mvn dependency:resolve-plugins",
  ),

  Run.new(
    name: "Java/OpenJDK/Serial",
    build_cmd: <<~CMD.chomp,
      mvn compile package -Pjava-plain -q
    CMD
    binary_name: "./target/java-benchmarks-1.0-SNAPSHOT.jar",
    run_cmd: <<~CMD.chomp,
      java \
        -Xmx512m \
        -XX:+UseSerialGC \
        -jar ./target/java-benchmarks-1.0-SNAPSHOT.jar
    CMD
    version_cmd: "java --version",
    dir: "/src/java",
    container: "java",
    group: :hack,
    deps_cmd: "mvn dependency:resolve; mvn dependency:resolve-plugins",
  ),

  Run.new(
    name: "Java/OpenJDK/Opt",
    build_cmd: <<~CMD.chomp,
      mvn compile package -Pjava-plain -q
    CMD
    binary_name: "./target/java-benchmarks-1.0-SNAPSHOT.jar",
    run_cmd: <<~CMD.chomp,
      java \
        -XX:+UseParallelGC \
        -XX:+UseLargePages \
        -XX:+AlwaysPreTouch \
        -XX:+UseCompressedOops \
        -XX:+OptimizeStringConcat \
        -XX:+UseStringDeduplication \
        -XX:+DisableExplicitGC \
        -XX:+UseCountedLoopSafepoints \
        -Xmx2g \
        -jar ./target/java-benchmarks-1.0-SNAPSHOT.jar
    CMD
    version_cmd: "java --version",
    dir: "/src/java",
    container: "java",
    group: :hack,
    deps_cmd: "mvn dependency:resolve; mvn dependency:resolve-plugins",
  ),

  Run.new(
    name: "Java/GraalVM/JIT",
    build_cmd: <<~CMD.chomp,
      mvn compile package -Pjava-plain -q
    CMD
    binary_name: "./target/java-benchmarks-1.0-SNAPSHOT.jar",
    run_cmd: <<~CMD.chomp,
      java \
        -Xmx2g \
        -jar ./target/java-benchmarks-1.0-SNAPSHOT.jar
    CMD
    version_cmd: "java --version",
    dir: "/src/java",
    container: "graalvm",
    group: :prod,
    deps_cmd: "mvn dependency:resolve; mvn dependency:resolve-plugins",
  ),
 
  Run.new(
    name: "Java/GraalVM/Serial",
    build_cmd: <<~CMD.chomp,
      mvn compile package -Pjava-plain -q
    CMD
    binary_name: "./target/java-benchmarks-1.0-SNAPSHOT.jar",
    run_cmd: <<~CMD.chomp,
      java \
        -XX:+UseSerialGC \
        -Xmx512m \
        -jar ./target/java-benchmarks-1.0-SNAPSHOT.jar
    CMD
    version_cmd: "java --version",
    dir: "/src/java",
    container: "graalvm",
    group: :hack,
    deps_cmd: "mvn dependency:resolve; mvn dependency:resolve-plugins",
  ),

  # Disable because of compile bug with fastjson2
  # Run.new(
  #   name: "Java/GraalVM/Native",
  #   build_cmd: <<~CMD.chomp,
  #     mvn package -Pgraalvm-native \
  #       -DskipTests \
  #       -Dmaven.test.skip=true \
  #       -Dnative.buildArgs="--no-fallback --gc=serial -O3"
  #   CMD
  #   binary_name: "./target/benchmarks-native",
  #   run_cmd: <<~CMD.chomp,
  #     ./target/benchmarks-native -Xmx12g
  #   CMD
  #   version_cmd: "native-image --version",
  #   dir: "/src/java",
  #   container: "graalvm",
  #   group: :hack,
  #   deps_cmd: "mvn dependency:resolve; mvn dependency:resolve-plugins",
  # ),

  # No effect
  # Run.new(
  #   name: "Java/GraalVM/Native/Max",
  #   build_cmd: <<~CMD.chomp,
  #     mvn package -Pgraalvm-native \
  #       -DskipTests \
  #       -Dmaven.test.skip=true \
  #       -Dnative.buildArgs="--gc=serial \
  #         --enable-url-protocols=http,https \
  #         --initialize-at-build-time=org.json \
  #         --no-fallback \
  #         -O3 \
  #         -march=native \
  #         -mtune=native \
  #         -H:MaxHeapSize=16g \
  #         -H:MaxNewSize=8g \
  #         -H:+StripDebugInfo \
  #         -H:+ReportExceptionStackTraces \
  #         -H:+EnableJVMCI" \
  #       -q
  #   CMD
  #   binary_name: "./target/benchmarks-native",
  #   run_cmd: <<~CMD.chomp,
  #     ./target/benchmarks-native \
  #       -Xmx12g
  #   CMD
  #   version_cmd: "native-image --version",
  #   dir: "/src/java",
  #   container: "graalvm",
  #   group: :hack,
  #   deps_cmd: "mvn dependency:resolve; mvn dependency:resolve-plugins",
  # ),

  # ======================================= Kotlin ======================================================

  Run.new(
    name: "Kotlin/JVM/Default",
    build_cmd: "./gradlew fatJar --no-daemon -q",
    binary_name: "/src/kotlin/build/libs/benchmarks.jar",
    run_cmd: "java -Xmx2g -jar /src/kotlin/build/libs/benchmarks.jar",
    version_cmd: "kotlin -version",
    dir: "/src/kotlin",
    container: "kotlin",
    group: :prod,
    deps_cmd: "./gradlew --no-daemon dependencies",
  ),

  Run.new(
    name: "Kotlin/JVM/Opt",
    build_cmd: "./gradlew fatJar --no-daemon -q",
    binary_name: "/src/kotlin/build/libs/benchmarks.jar",
    run_cmd: <<~CMD.chomp,
      java \
        -XX:+UseG1GC \
        -Xms2g \
        -XX:+AlwaysPreTouch \
        -XX:+OptimizeStringConcat \
        -XX:+UseCompressedOops \
        -Xmx2g \
        -jar /src/kotlin/build/libs/benchmarks.jar
    CMD
    version_cmd: "kotlin -version",
    dir: "/src/kotlin",
    container: "kotlin",
    group: :hack,
    deps_cmd: "./gradlew --no-daemon dependencies",
  ),

  Run.new(
    name: "Kotlin/JVM/Max",
    build_cmd: "./gradlew fatJar --no-daemon -q",
    binary_name: "/src/kotlin/build/libs/benchmarks.jar",
    run_cmd: <<~CMD.chomp,
      java \
        -XX:+UseParallelGC \
        -Xms4g \
        -Xmx8g \
        -XX:+AlwaysPreTouch \
        -XX:+UseLargePages \
        -XX:+DisableExplicitGC \
        -jar /src/kotlin/build/libs/benchmarks.jar
    CMD
    version_cmd: "kotlin -version",
    dir: "/src/kotlin",
    container: "kotlin",
    group: :hack,
    deps_cmd: "./gradlew --no-daemon dependencies",
  ),

  Run.new(
    name: "Kotlin/GraalVM/JIT",
    build_cmd: "./gradlew fatJar --no-daemon -q",
    binary_name: "/src/kotlin/build/libs/benchmarks.jar",
    run_cmd: <<~CMD.chomp,
      java \
        -Xmx2g \
        -jar /src/kotlin/build/libs/benchmarks.jar
    CMD
    version_cmd: "kotlin -version",
    dir: "/src/kotlin",
    container: "kotlin-graalvm",
    group: :hack,
    deps_cmd: "./gradlew --no-daemon dependencies",
  ),

  # =============== KOTLIN + GRAALVM NATIVE ===============

  # Disable because of compile bug with fastjson2
  # Run.new(
  #   name: "Kotlin/GraalVM/Native",
  #   build_cmd: "/src/kotlin/build-kotlin-native.sh",
  #   binary_name: "/src/kotlin/build/native/benchmarks",
  #   run_cmd: "/src/kotlin/build/native/benchmarks -Xmx8g",
  #   version_cmd: "kotlin -version",
  #   dir: "/src/kotlin",
  #   container: "kotlin-graalvm",
  #   group: :hack,
  #   deps_cmd: "./gradlew --no-daemon dependencies",
  # ),

  # No effect
  # Run.new(
  #   name: "Kotlin/GraalVM/Native/Max",
  #   build_cmd: "/src/kotlin/build-kotlin-native-max.sh",
  #   binary_name: "/src/kotlin/build/native/benchmarks-max",
  #   run_cmd: "/src/kotlin/build/native/benchmarks-max -Xmx8g",
  #   version_cmd: "kotlin -version",
  #   dir: "/src/kotlin",
  #   container: "kotlin-graalvm",
  #   group: :hack,
  #   deps_cmd: "./gradlew --no-daemon dependencies",
  # ),

  # No effect
  # Run.new(
  #   name: "Kotlin/GraalVM/Native/Fast",
  #   build_cmd: "/src/kotlin/build-kotlin-native.sh '-O2' benchmarks-fast",
  #   binary_name: "/src/kotlin/build/native/benchmarks-fast",
  #   run_cmd: "/src/kotlin/build/native/benchmarks-fast -Xmx8g",
  #   version_cmd: "kotlin -version",
  #   dir: "/src/kotlin",
  #   container: "kotlin-graalvm",
  #   group: :hack,
  #   deps_cmd: "./gradlew --no-daemon dependencies",
  # ),

  # ======================================= SCALA ======================================================

  Run.new(
    name: "Scala/JVM/Default",
    build_cmd: "sbt 'assembly'",
    binary_name: "/src/scala/target/benchmark.jar",
    run_cmd: "java -Xmx2g -jar /src/scala/target/benchmark.jar",
    version_cmd: "scala -version",
    dir: "/src/scala",
    container: "scala",
    group: :prod,
    deps_cmd: "sbt dependencyTree",
  ),

  Run.new(
    name: "Scala/JVM/Opt",
    build_cmd: "sbt 'assembly'",
    binary_name: "/src/scala/target/benchmark.jar",
    run_cmd: <<~CMD.chomp,
      java \
        -XX:+UseG1GC \
        -Xms2g \
        -Xmx2g \
        -XX:+AlwaysPreTouch \
        -XX:+OptimizeStringConcat \
        -XX:+UseCompressedOops \
        -jar /src/scala/target/benchmark.jar
    CMD
    version_cmd: "scala -version",
    dir: "/src/scala",
    container: "scala",
    group: :hack,
    deps_cmd: "sbt dependencyTree",
  ),

  Run.new(
    name: "Scala/JVM/Max",
    build_cmd: "sbt 'assembly'",
    binary_name: "/src/scala/target/benchmark.jar",
    run_cmd: <<~CMD.chomp,
      java \
        -XX:+UseParallelGC \
        -Xms4g \
        -Xmx8g \
        -XX:+AlwaysPreTouch \
        -XX:+UseLargePages \
        -XX:+DisableExplicitGC \
        -Djava.security.egd=file:/dev/./urandom \
        -jar /src/scala/target/benchmark.jar
    CMD
    version_cmd: "scala -version",
    dir: "/src/scala",
    container: "scala",
    group: :hack,
    deps_cmd: "sbt dependencyTree",
  ),

  Run.new(
    name: "Scala/GraalVM/JIT",
    build_cmd: "sbt 'assembly'",
    binary_name: "/src/scala/target/benchmark.jar",
    run_cmd: <<~CMD.chomp,
      java \
        -Xmx2g \
        -jar /src/scala/target/benchmark.jar
    CMD
    version_cmd: "scala -version",
    dir: "/src/scala",
    container: "scala-graalvm",
    group: :hack,
    deps_cmd: "sbt dependencyTree",
  ),

  # ======================================= Dart ======================================================
  
  Run.new(
    name: "Dart/AOT", 
    build_cmd: "dart compile exe main.dart -o target/dart_benchmark",
    binary_name: "target/dart_benchmark",
    run_cmd: "./target/dart_benchmark", 
    version_cmd: "dart --version",
    dir: "/src/dart",
    container: "dart",   
    group: :hack, 
    deps_cmd: "dart pub get",
  ),

  Run.new(
    name: "Dart/JIT", 
    build_cmd: "true",
    binary_name: "main.dart",
    run_cmd: "dart run main.dart", 
    version_cmd: "dart --version",
    dir: "/src/dart",
    container: "dart",   
    group: :prod, 
    deps_cmd: "dart pub get",
  ),

  # ======================================= TypeScript ======================================================

  Run.new(
    name: "TypeScript/Node/Default",
    build_cmd: <<~CMD.chomp,
      sh -c 'npm install; npm run build:run --silent'
    CMD
    binary_name: "/src/typescript/target/dist/index.js",
    run_cmd: "node --max-old-space-size=4096 /src/typescript/target/dist/index.js",
    version_cmd: "/bin/bash -c 'echo \"TCS $(tsc --version), Node $(node --version)\"'",
    dir: "/src/typescript",
    container: "typescript",
    group: :prod,
    deps_cmd: "npm ci",
  ),

  Run.new(
    name: "TypeScript/Node/Opt",
    build_cmd: "sh -c 'npm ci --silent && npm run build:run --silent'",
    binary_name: "/src/typescript/target/dist/index.js",
    run_cmd: <<~CMD.chomp,
      node \
        --max-old-space-size=4096 \
        --max-semi-space-size=256 \
        --optimize-for-size \
        /src/typescript/target/dist/index.js
    CMD
    version_cmd: "/bin/bash -c 'echo \"TCS $(tsc --version), Node $(node --version)\"'",
    dir: "/src/typescript",
    container: "typescript",
    group: :hack,
    deps_cmd: "npm ci",
  ),

  # No effect
  # Run.new(
  #   name: "TypeScript/Node/Max",
  #   build_cmd: "sh -c 'npm ci --silent && npm run build:run --silent'",
  #   binary_name: "/src/typescript/target/dist/index.js",
  #   run_cmd: <<~CMD.chomp,
  #     node \
  #       --max-old-space-size=8192 \
  #       --max-semi-space-size=512 \
  #       --optimize-for-size \
  #       --no-concurrent-sweeping \
  #       --single-threaded-gc \
  #       /src/typescript/target/dist/index.js
  #   CMD
  #   version_cmd: "/bin/bash -c 'echo \"TCS $(tsc --version), Node $(node --version)\"'",
  #   dir: "/src/typescript",
  #   container: "typescript",
  #   group: :hack,
  #   deps_cmd: "npm ci",
  # ),

  # No effect
  # Run.new(
  #   name: "TypeScript/Node/Turbo",
  #   build_cmd: "sh -c 'npm ci --silent && npm run build:run --silent'",
  #   binary_name: "/src/typescript/target/dist/index.js",
  #   run_cmd: <<~CMD.chomp,
  #     node \
  #       --max-old-space-size=4096 \
  #       --max-semi-space-size=128 \
  #       --optimize-for-size \
  #       --concurrent-recompilation \
  #       /src/typescript/target/dist/index.js
  #   CMD
  #   version_cmd: "/bin/bash -c 'echo \"TCS $(tsc --version), Node $(node --version)\"'",
  #   dir: "/src/typescript",
  #   container: "typescript",
  #   group: :hack,
  #   deps_cmd: "npm ci",
  # ),

  Run.new(
    name: "TypeScript/Bun/JIT",
    build_cmd: "true",
    binary_name: "/src/typescript/src/index.ts",
    run_cmd: "bun run /src/typescript/src/index.ts",
    version_cmd: "bun --version",
    dir: "/src/typescript",
    container: "typescript-bun",
    group: :prod,
    deps_cmd: "bun install",
  ),

  Run.new(
    name: "TypeScript/Bun/Compiled",
    build_cmd: <<~CMD.chomp,
      bun build --target=bun --outdir=target/dist-bun src/index.ts
    CMD
    binary_name: "/src/typescript/target/dist-bun/index.js",
    run_cmd: "bun run /src/typescript/target/dist-bun/index.js",
    version_cmd: "bun --version",
    dir: "/src/typescript",
    container: "typescript-bun",
    group: :hack,
    deps_cmd: "bun install",
  ),

  Run.new(
    name: "TypeScript/Deno/Default",
    build_cmd: "true",
    binary_name: "/src/typescript/src/index.ts",
    run_cmd: <<~CMD.chomp,
      deno run \
        --allow-all \
        --v8-flags=--max-old-space-size=4096 \
        /src/typescript/src/index.ts
    CMD
    version_cmd: "deno --version",
    dir: "/src/typescript",
    container: "typescript-deno",
    group: :prod,
    deps_cmd: "deno cache --quiet src/index.ts",
  ),

  # Not compiled
  # Run.new(
  #   name: "TypeScript/Deno/Compiled",
  #   build_cmd: <<~CMD.chomp,
  #     deno compile \
  #       --allow-all \
  #       --no-check \
  #       --output=target/dist-deno/index \
  #       src/index.ts
  #   CMD
  #   binary_name: "/src/typescript/target/dist-deno/index",
  #   run_cmd: "/src/typescript/target/dist-deno/index",
  #   version_cmd: "deno --version",
  #   dir: "/src/typescript",
  #   container: "typescript-deno",
  #   group: :hack,
  #   deps_cmd: "deno cache --quiet src/index.ts",
  # ),

  # No effect
  # Run.new(
  #   name: "TypeScript/Deno/Opt",
  #   build_cmd: "true",
  #   binary_name: "/src/typescript/src/index.ts",
  #   run_cmd: <<~CMD.chomp,
  #     deno run \
  #       --allow-all \
  #       --v8-flags="--max-old-space-size=4096,--max-semi-space-size=256,--optimize-for-size" \
  #       /src/typescript/src/index.ts
  #   CMD
  #   version_cmd: "deno --version",
  #   dir: "/src/typescript",
  #   container: "typescript-deno",
  #   group: :hack,
  #   deps_cmd: "deno cache --quiet src/index.ts",
  # ),

  # No effect
  # Run.new(
  #   name: "TypeScript/Deno/Max",
  #   build_cmd: "true",
  #   binary_name: "/src/typescript/src/index.ts",
  #   run_cmd: <<~CMD.chomp,
  #     deno run \
  #       --allow-all \
  #       --v8-flags="--max-old-space-size=8192,--max-semi-space-size=512,--optimize-for-size,--no-concurrent-sweeping" \
  #       --no-check \
  #       /src/typescript/src/index.ts
  #   CMD
  #   version_cmd: "deno --version",
  #   dir: "/src/typescript",
  #   container: "typescript-deno",
  #   group: :hack,
  #   deps_cmd: "deno cache --quiet src/index.ts",
  # ),

  Run.new(
    name: "TypeScript/Deno/Turbo",
    build_cmd: "true",
    binary_name: "/src/typescript/src/index.ts",
    run_cmd: <<~CMD.chomp,
      deno run \
        --allow-all \
        --v8-flags="--max-old-space-size=4096,--concurrent-recompilation" \
        --no-check \
        /src/typescript/src/index.ts
    CMD
    version_cmd: "deno --version",
    dir: "/src/typescript",
    container: "typescript-deno",
    group: :hack,
    deps_cmd: "deno cache --quiet src/index.ts",
  ),

  # ======================================= Python ======================================================

  Run.new(
    name: "Python/PYPY", 
    build_cmd: "true",
    binary_name: "main.py",
    run_cmd: "pypy3 main.py", 
    version_cmd: "pypy3 --version",
    dir: "/src/python",
    container: "pypy",   
    group: :prod, 
    deps_cmd: "true",
  ),

  # ======================================= Ruby ======================================================

  # too slow
  # Run.new(
  #   name: "Ruby/CRuby2/Default", 
  #   build_cmd: "true",
  #   binary_name: "main.rb",
  #   run_cmd: "ruby main.rb", 
  #   version_cmd: "ruby --version",
  #   dir: "/src/ruby",
  #   container: "ruby2",
  #   group: :hack, 
  #   deps_cmd: "true",
  # ),

  # too slow
  # Run.new(
  #   name: "Ruby/CRuby2/JIT", 
  #   build_cmd: "true",
  #   binary_name: "main.rb",
  #   run_cmd: "ruby --jit main.rb", 
  #   version_cmd: "ruby --version",
  #   dir: "/src/ruby",
  #   container: "ruby2",
  #   group: :hack, 
  #   deps_cmd: "true",
  # ),

  # too slow
  # Run.new(
  #   name: "Ruby/CRuby3/Default", 
  #   build_cmd: "true",
  #   binary_name: "main.rb",
  #   run_cmd: "ruby main.rb", 
  #   version_cmd: "ruby --version",
  #   dir: "/src/ruby",
  #   container: "ruby3",
  #   group: :hack, 
  #   deps_cmd: "true",
  # ),

  # too slow
  # Run.new(
  #   name: "Ruby/CRuby3/YJIT", 
  #   build_cmd: "true",
  #   binary_name: "main.rb",
  #   run_cmd: "ruby --yjit main.rb", 
  #   version_cmd: "ruby --version",
  #   dir: "/src/ruby",
  #   container: "ruby3",
  #   group: :hack, 
  #   deps_cmd: "true",
  # ),

  # too slow
  # Run.new(
  #   name: "Ruby/CRuby4/Default", 
  #   build_cmd: "true",
  #   binary_name: "main.rb",
  #   run_cmd: "ruby main.rb", 
  #   version_cmd: "ruby --version",
  #   dir: "/src/ruby",
  #   container: "ruby4",
  #   group: :hack, 
  #   deps_cmd: "true",
  # ),

  # too slow
  Run.new(
    name: "Ruby/CRuby4/YJIT", 
    build_cmd: "true",
    binary_name: "main.rb",
    run_cmd: "ruby --yjit main.rb", 
    version_cmd: "ruby --version",
    dir: "/src/ruby",
    container: "ruby4",
    group: :hack, 
    deps_cmd: "true",
  ),

  # too slow
  # Run.new(
  #   name: "Ruby/CRuby4/ZJIT", 
  #   build_cmd: "true",
  #   binary_name: "main.rb",
  #   run_cmd: "ruby --zjit main.rb", 
  #   version_cmd: "ruby --version",
  #   dir: "/src/ruby",
  #   container: "ruby4",
  #   group: :hack, 
  #   deps_cmd: "true",
  # ),

  # too slow
  # Run.new(
  #   name: "Ruby/Truffle/Native", 
  #   build_cmd: "true",
  #   binary_name: "main.rb",
  #   run_cmd: "ruby main.rb", 
  #   version_cmd: "ruby --version",
  #   dir: "/src/ruby",
  #   container: "truffleruby",
  #   group: :hack, 
  #   deps_cmd: "true",
  # ),

  Run.new(
    name: "Ruby/Truffle/JVM", 
    build_cmd: "true",
    binary_name: "main.rb",
    run_cmd: "ruby main.rb", 
    version_cmd: "ruby --version",
    dir: "/src/ruby",
    container: "truffleruby_jvm",
    group: :hack, 
    deps_cmd: "true",
  ),

  # too slow
  # Run.new(
  #   name: "Ruby/JRuby", 
  #   build_cmd: "true",
  #   binary_name: "main.rb",
  #   run_cmd: "ruby main.rb", 
  #   version_cmd: "ruby --version",
  #   dir: "/src/ruby",
  #   container: "jruby",
  #   group: :hack, 
  #   deps_cmd: "true",
  # ),

  Run.new(
    name: "Ruby/Spinel/Clang", 
    build_cmd: "spinel main.rb --int-overflow=wrap -o target/bin_spinel_clang",
    binary_name: "target/bin_spinel_clang",
    run_cmd: "target/bin_spinel_clang", 
    version_cmd: "spinel --version",
    dir: "/src/ruby",
    container: "spinel_clang",
    group: :hack, 
    deps_cmd: "mkdir -p target",
  ),

  # Run.new(
  #   name: "Ruby/Spinel/Gcc", 
  #   build_cmd: "spinel main.rb --int-overflow=wrap -o target/bin_spinel_gcc",
  #   binary_name: "target/bin_spinel_gcc",
  #   run_cmd: "target/bin_spinel_gcc", 
  #   version_cmd: "spinel --version",
  #   dir: "/src/ruby",
  #   container: "spinel_gcc",
  #   group: :hack, 
  #   deps_cmd: "mkdir -p target",
  # ),

  # ======================================= Php ======================================================
  
  Run.new(
    name: "PHP", 
    build_cmd: "true",
    binary_name: "main.php",
    run_cmd: "php -d opcache.enable=1 -d opcache.enable_cli=1 -d opcache.jit=tracing -d opcache.jit_buffer_size=256M -d memory_limit=-1 main.php",
    version_cmd: "php --version | head -n 1",
    dir: "/src/php",
    container: "php",
    group: :hack, 
    deps_cmd: "true",
  ),

  # ======================================= JavaScript ======================================================

  Run.new(
    name: "JS/Node/Default",
    build_cmd: "true",
    binary_name: "/src/javascript/index.js",
    run_cmd: "node /src/javascript/index.js",
    version_cmd: "node --version",
    dir: "/src/javascript",
    container: "typescript",
    group: :hack,
    deps_cmd: "true",
  ),

  Run.new(
    name: "JS/Bun/JIT",
    build_cmd: "true",
    binary_name: "/src/javascript/index.js",
    run_cmd: "bun run /src/javascript/index.js",
    version_cmd: "bun --version",
    dir: "/src/javascript",
    container: "typescript-bun",
    group: :hack,
    deps_cmd: "true",
  ),

  Run.new(
    name: "JS/Deno/Default",
    build_cmd: "true",
    binary_name: "/src/javascript/index.js",
    run_cmd: <<~CMD.chomp,
      deno run \
        --allow-all \
        --v8-flags=--max-old-space-size=4096 \
        /src/javascript/index.js
    CMD
    version_cmd: "deno --version",
    dir: "/src/javascript",
    container: "typescript-deno",
    group: :hack,
    deps_cmd: "true",
  ),
  
]

run_names = {}
RUNS.each do |run|
  if run_names[run.name]
    raise "Dublicate name #{run.name}, rename it!"
  else
    run_names[run.name] = run
  end
end

if ARGV[0] && ARGV[0] != ""
  regx = /#{Regexp.escape ARGV[0]}/
  puts "select with regex from #{RUNS.size} #{regx.inspect}"
  RUNS.select! { |run| run.name =~ regx }
end

if IS_RUN_PROD
  RUNS.select! { |run| run.group == :prod }
end

if IS_ONE_RUN_PER_LANG
  new_runs = []  
  RUNS.group_by(&:lang).each do |lang, runs| 
    r = runs[0]
    if r.group == :prod
      new_runs << r
    else
      if r = runs.find { |r| r.group == :prod }
        new_runs << r 
      else
        runs[0]
      end
    end
  end
  RUNS.clear
  new_runs.each { |r| RUNS << r }
  puts "Select one run per language: #{RUNS.size}"
end

puts "Found runs: #{RUNS.size} #{RUNS.size < 10 ? RUNS.map(&:name).inspect : nil}"

langs = {}
RUNS.each do |run|
  langs[run.lang] = 1
end
LANGS = langs.keys
puts "Unique languages: #{LANGS.size} #{LANGS.inspect}"

test_txt = File.read("test.js")
tests = JSON.parse(test_txt).map { |h| h["name"] } 
TESTS = case ARGV[1]
when nil, ""
  tests
when "rand", "Rand", "r", "R"
  tests.sample(1)
else
  regx = /#{Regexp.escape ARGV[1]}/
  tests.select { |t| t =~ regx }
end
puts "All tests count: #{TESTS.size} (#{TESTS.join(", ")})"
puts

if APPEND_RESULTS
  f = File.read(APPEND_RESULTS)
  puts "Use previous results: #{APPEND_RESULTS}"
  RESULTS = JSON.parse(f)
  RUNS.each { |run| RESULTS["runs"][run.name] = run.group }
else
  RESULTS = {}
  RESULTS["date"] = Time.now.strftime("%Y-%m-%d")
  RESULTS["arch"] = RUBY_PLATFORM
  RESULTS["pc"] = PC
  RESULTS["uname-name"] = `uname -n`.strip
  RESULTS["langs"] = LANGS.sort
  RESULTS["runs"] = {}
  RUNS.each { |run| RESULTS["runs"][run.name] = run.group }
  RESULTS["tests"] = TESTS
  RESULTS["build-cmd"] = {}
  RESULTS["run-cmd"] = {}
  RESULTS["binary-size-kb"] = {}
  RESULTS["compile-memory-cold"] = {}
  RESULTS["compile-memory-incremental"] = {}
  RESULTS["compile-time-cold"] = {}
  RESULTS["compile-usertime-cold"] = {}
  RESULTS["compile-systemtime-cold"] = {}
  RESULTS["compile-time-incremental"] = {}
  RESULTS["compile-usertime-incremental"] = {}
  RESULTS["compile-systemtime-incremental"] = {}
  RESULTS["version"] = {}
end

unless ARGV[0]
  File.open("/tmp/log_crash.txt", "w") { |f| f.puts "started #{Time.now}" }
end

def write_results
  if !ARGV[0] || APPEND_RESULTS
    File.write("./results/#{RESULTS["date"]}-#{RESULTS["uname-name"]}.js", JSON.pretty_generate(RESULTS))  
  end
end

check_source_files(IS_VERBOSE)
write_results

unless IS_NO_VERSION
  RUNS.group_by(&:container).each do |container, runs|
    runs.group_by(&:version_cmd).each do |_, vcmds|
      v = vcmds[0]
      puts "Version #{container}: '#{v.version}'"
    end
  end
end

unless IS_NO_DEPS
  RUNS.group_by { |r| [r.container, r.deps_cmd] }.each do |_, runs|
    run = runs[0]

    print "Prepare deps for #{run.name}: "
    delta = measure { run.deps }
    puts "in #{delta.round(2)}s"
  end
end

CFG = IS_RUN_TEST ? "../test.js" : "../run.js"

def build(run, verbose = true, test_incremental = false)
  print "building #{run.name} ..."
  stats = run.run(run.build_cmd, verbose)
  fsize_stats = run.run("sh -c 'du -k #{run.binary_name} | cut -f1'", verbose)
  RESULTS["binary-size-kb"][run.name] = fsize_stats[:out].split("\n").last.to_i
  RESULTS["build-cmd"][run.name] = run.build_cmd
  RESULTS["run-cmd"][run.name] = run.run_cmd
  RESULTS["compile-time-cold"][run.name] = stats[:wall_time]
  RESULTS["compile-usertime-cold"][run.name] = stats[:user_time]
  RESULTS["compile-systemtime-cold"][run.name] = stats[:system_time]
  RESULTS["compile-memory-cold"][run.name] = stats[:rss] / 1024.0
  print " cold wall in #{stats[:wall_time].round(2)}s, timetotal in #{stats[:cpu_total].round(2)}s"
  
  if test_incremental && (marker_file = RECOMPILE_MARKER_FILES[run.lang])
    begin
      File.write(marker_file, File.read(marker_file).gsub(RECOMPILE_MARKER_0, RECOMPILE_MARKER_1))
      stats = run.run(run.build_cmd, verbose)
      RESULTS["compile-time-incremental"][run.name] = stats[:wall_time]
      RESULTS["compile-usertime-incremental"][run.name] = stats[:user_time]
      RESULTS["compile-systemtime-incremental"][run.name] = stats[:system_time]
      RESULTS["compile-memory-incremental"][run.name] = stats[:rss] / 1024.0
      print ", inc wall in #{stats[:wall_time].round(2)}s, inc timetotal in #{stats[:cpu_total].round(2)}s"
    ensure
      File.write(marker_file, File.read(marker_file).gsub(RECOMPILE_MARKER_1, RECOMPILE_MARKER_0))
    end
  else
    print ", warning no marker for #{run.name}"
  end

  RESULTS["version"][run.name] = run.version  
  puts
end

write_results

unless IS_NO_BUILD
  delta = measure do
    RUNS.each do |run|
      build(run, IS_VERBOSE, true)
    end
  end
  puts "------------ Build all finished in #{delta.round(3)}s ----------------"
end

write_results

def run(run, index)
  # run.remove_binary
  run.run(run.build_cmd, false) # build still needed because swift, java, kotlin, typescript all use same binary

  summary = 0.0
  memory = 0.0

  puts "Running #{run.name} (#{index} from #{RUNS.size})"
  TESTS.each_with_index do |test_name, index|
    print "#{index}. #{test_name}"
    RESULTS[test_name+"-runtime"] ||= {}
    RESULTS[test_name+"-mem-mb"] ||= {}
  
    stats = run.run("#{run.run_cmd} #{CFG} #{test_name}", IS_VERBOSE)
    mem = stats[:rss] / 1024.0
    memory += mem
    RESULTS[test_name+"-mem-mb"][run.name] = mem

    if stats[:out] =~ /#{test_name}: OK in ([\d\.]+)s/      
      run_time = $1.to_f
      summary += run_time
      puts " - #{run_time}s, #{(mem).round(1)}Mb"
    else
      puts "Warning something wrong while running #{run.inspect}: #{stats.inspect}"
      run_time = "---(#{stats.inspect})"      
    end

    RESULTS[test_name+"-runtime"][run.name] = run_time
  end

  [summary, ((memory / TESTS.size) rescue 0)]
end

puts "---------- Run ----------"
RUNS.each_with_index do |run, index| 
  summary, memory = 0, 0
  delta = measure do
    summary, memory = run(run, index)
  end
  puts "Finished #{run.name} in #{delta.round(3)} (#{summary.round(3)}s, #{memory.round(3)}Mb)"
  write_results
end

end_t = Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond)
puts "----------- FINISHED in #{((end_t - START_TIME).to_f / 1e9).round(2)}s-------------"
write_results
