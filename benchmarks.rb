# Run all benchmarks and store results to ./results/
#
# `docker compose build` should be called before use this script
#
# Run all `ruby benchmarks.rb`
# Run only Lang Regex `ruby benchmarks.rb C++`
# Run only Lang Regex and Test Regex `ruby benchmarks.rb C++ Primes`
# Run Prod configs exclude Hack `PROD=1 ruby benchmarks.rb`
# Run test configs - just to check (faster finished) `TEST=1 ruby benchmarks.rb`

IS_VERBOSE = ENV["VERBOSE"] == "1"
IS_RUN_PROD = ENV["PROD"] == "1"
IS_RUN_TEST = ENV["TEST"] == "1"

require 'json'
require 'timeout'
require "fileutils"
FileUtils.mkdir_p("./results")
IS_MACOS = RUBY_PLATFORM =~ /darwin/
START_TIME = Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond)

def dotnet_runtime
  # .NET сам знает свою платформу
  output = `docker compose run --rm -q dotnet dotnet --info | grep RID`.strip
  if output =~ /RID:\s*(\S+)/
    $1  # например: osx-x64, linux-x64
  else
    # fallback
    "linux-x64"
  end
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

def check_source_files(verbose = false)
  #!/usr/bin/env ruby
  require 'find'
  require 'zlib'
  require 'json'

  lang_masks = {
    'c' => ['./c', ['.c', '.h'], ['target', 'deps']],
    'cpp' => ['./cpp', ['.cpp', '.hpp', '.h', '.cc', '.cxx'], ['target', 'deps']],
    'golang' => ['./golang', ['.go'], ['target']],
    'crystal' => ['./crystal', ['.cr'], ['target']],
    'rust' => ['./rust', ['.rs'], ['target']],
    'csharp' => ['./csharp', ['.cs'], ['obj', 'bin']],
    'swift' => ['./swift', ['.swift'], ['.build']],
    'java' => ['./java', ['.java'], ['target']],
    'kotlin' => ['./kotlin', ['.kt'], ['build', '.gradle', 'gradle']],
    'typescript' => ['./typescript', ['.ts', '.tsx'], ['node_modules', 'target']],
    'zig' => ['./zig', ['.zig'], ['.zig-cache']]
  }

  results = {}

  lang_masks.each do |lang, (path, exts, exclude_dirs)|
    unless Dir.exist?(path)
      results[lang] = {"error" => "no dir", "files" => [], "source_kb" => 0, "gzip_kb" => 0}
      next
    end
    
    files = []
    Find.find(path) do |file_path|
      next unless File.file?(file_path)
      
      # Проверяем расширение файла
      ext = File.extname(file_path).downcase
      next unless exts.include?(ext)
      
      # Проверяем исключения
      skip = false
      exclude_dirs.each do |exclude|
        if file_path.include?(exclude)
          skip = true
          break
        end
      end
      next if skip
      
      # Получаем относительный путь
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
    
    # Считаем размеры
    total_bytes = 0
    content = ''
    
    files.each do |file|
      full_path = File.join(path, file)
      begin
        data = File.read(full_path, mode: 'rb')
        total_bytes += data.bytesize
        content << data
      rescue => e
        # Игнорируем ошибки чтения файлов
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
    
    puts "Language: #{lang}, Files: #{files.size}, Source: #{source_kb.round(1)}KB, Gzip: #{gzip_kb.round(1)}KB"
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
    @group = group # :prod or :hack
    @deps_cmd = deps_cmd
    if @group == :hack
      @name += "-Hack"
    end
  end

  def dcr
    "docker compose run --rm -q --remove-orphans #{@container} "
  end

  def rss_prefix
    "/usr/bin/time -f 'MaxRSS(%M)KB' 2>&1 "
  end

  def run(cmd, debug = false)
    cmd = "#{dcr}#{rss_prefix}#{cmd}"
    if debug
      print "`#{cmd}`"
    end
    stdout = `#{cmd}`    
    exitstatus = $?.exitstatus
    if exitstatus != 0
      raise "Failed to build `#{cmd}`, exitstatus: #{exitstatus}"
    end
    stdout =~ /MaxRSS\(([0-9]*?)\)KB\n/
    rss = $1.to_i
    {out: stdout.sub(/MaxRSS\(([0-9]*?)\)KB\n/, ""), rss: rss}
  end

  def deps
    cmd = "sh -c '#{@deps_cmd}'"
    run(cmd, IS_VERBOSE)
  rescue => ex
    p "Error #{ex.inspect}"
  end

  def version
    v = `#{dcr} #{@version_cmd}`.strip
    v.gsub("\n", " | ")
  end
end

C_FLAGS_PROD = " -O2 -march=native -flto=auto -DNDEBUG -fstack-protector-strong -fno-omit-frame-pointer -Wall -Wextra -Wpedantic -Werror=return-type -Werror=address"
LD_FLAGS_PROD = " -flto=auto #{IS_MACOS ? "" : "-Wl,-z,relro,-z,now -Wl,--gc-sections"}"
C_FLAGS_ENH = " -O3 -march=native -mtune=native -DNDEBUG -pipe -fstack-protector -ftree-vectorize -funroll-loops -fno-semantic-interposition"
LD_FLAGS_ENH = " -flto=thin #{IS_MACOS ? "-Wl,-dead_strip" : "-Wl,-O1 -Wl,--gc-sections"}"
C_FLAGS_MAX = " -Ofast -march=native -DNDEBUG -pipe -fno-stack-protector -fomit-frame-pointer -ffast-math -funroll-all-loops -fvisibility=hidden -fno-plt -fno-common -fstrict-overflow -fno-trapping-math"
LD_FLAGS_MAX = " -flto=full #{IS_MACOS ? "-Wl,-dead_strip -Wl,-S" : "-Wl,-O3 -Wl,--strip-all -static"}"

CXXFLAGS_PROD = C_FLAGS_PROD + " -std=c++20 -Wold-style-cast -Woverloaded-virtual"
CXXFLAGS_ENH = C_FLAGS_ENH + " -std=c++20 -Wsuggest-override -Wduplicated-cond"
CXXFLAGS_MAX = C_FLAGS_MAX + " -std=c++20" # ⚠️ Опасные флаги! -fno-rtti -fno-exception

C_INCLUDE_FLAGS = " -Ideps/base64/include/ -I/usr/include/ -Ideps/cJSON -L/opt/homebrew/lib -I/opt/homebrew/include/"
C_LINK_FLAGS = " -lgmp target/cJSON.o target/libbase64.o -lm -lpcre2-8 -lpthread"

CXX_INCLUDE_FLAGS = " -Ideps/base64/include -Wl,-rpath,/opt/homebrew/opt/llvm/lib/c++ -L/opt/homebrew/opt/llvm/lib/c++ -L/opt/homebrew/lib -I/opt/homebrew/include/ -Ideps/simdjson"
CXX_LINK_FLAGS = " target/libbase64.o target/simdjson.o -lgmp -lre2 -lpthread"

RUNS = [

  # ======================================= C ======================================================
  Run.new(
    name: "C/Clang/Default", 
    build_cmd: "sh -c 'sh build-deps.sh; gcc #{C_INCLUDE_FLAGS} -O2 main.c -o target/bin_c_clang_def #{C_LINK_FLAGS}'",
    binary_name: "./target/bin_c_clang_def",
    run_cmd: "./target/bin_c_clang_def", 
    version_cmd: "gcc --version | head -n 1",
    dir: "/src/c",
    container: "clang_c",
    group: :hack,
    deps_cmd: "sh fetch-deps.sh",
  ),
  
  Run.new(
    name: "C/Gcc/Default", 
    build_cmd: "sh -c 'sh build-deps.sh; gcc #{C_INCLUDE_FLAGS} -O2 main.c -o target/bin_c_gcc_def #{C_LINK_FLAGS}'",
    binary_name: "./target/bin_c_gcc_def",
    run_cmd: "./target/bin_c_gcc_def", 
    version_cmd: "gcc --version | head -n 1",
    dir: "/src/c",
    container: "gcc_c",
    group: :hack,
    deps_cmd: "sh fetch-deps.sh",
  ),
  
  Run.new(
    name: "C/Clang", 
    build_cmd: "sh -c 'sh build-deps.sh; gcc #{C_INCLUDE_FLAGS} #{C_FLAGS_PROD} main.c -o target/bin_c_clang #{LD_FLAGS_PROD} #{C_LINK_FLAGS}'",
    binary_name: "./target/bin_c_clang",
    run_cmd: "./target/bin_c_clang", 
    version_cmd: "gcc --version | head -n 1",
    dir: "/src/c",
    container: "clang_c",
    group: :prod,
    deps_cmd: "sh fetch-deps.sh",
  ),
  
  Run.new(
    name: "C/Gcc", 
    build_cmd: "sh -c 'sh build-deps.sh; gcc #{C_INCLUDE_FLAGS} #{C_FLAGS_PROD} main.c -o target/bin_c_gcc #{LD_FLAGS_PROD} #{C_LINK_FLAGS}'",
    binary_name: "./target/bin_c_gcc",
    run_cmd: "./target/bin_c_gcc", 
    version_cmd: "gcc --version | head -n 1",
    dir: "/src/c",
    container: "gcc_c",
    group: :prod,
    deps_cmd: "sh fetch-deps.sh",
  ),
  
  Run.new(
    name: "C/Clang/ENH", 
    build_cmd: "sh -c 'sh build-deps.sh; gcc #{C_INCLUDE_FLAGS} #{C_FLAGS_ENH} main.c -o target/bin_c_clang_enh #{LD_FLAGS_ENH} #{C_LINK_FLAGS}'",
    binary_name: "./target/bin_c_clang_enh",
    run_cmd: "./target/bin_c_clang_enh", 
    version_cmd: "gcc --version | head -n 1",
    dir: "/src/c",
    container: "clang_c",
    group: :hack,
    deps_cmd: "sh fetch-deps.sh",
  ),
  
  Run.new(
    name: "C/Gcc/ENH", 
    build_cmd: "sh -c 'sh build-deps.sh; gcc #{C_INCLUDE_FLAGS} #{C_FLAGS_ENH} main.c -o target/bin_c_gcc_enh #{LD_FLAGS_ENH.gsub("-flto=thin", "-flto").gsub("-flto=full", "-flto")} #{C_LINK_FLAGS}'",
    binary_name: "./target/bin_c_gcc_enh",
    run_cmd: "./target/bin_c_gcc_enh", 
    version_cmd: "gcc --version | head -n 1",
    dir: "/src/c",
    container: "gcc_c",
    group: :hack,
    deps_cmd: "sh fetch-deps.sh",
  ),
  
  Run.new(
    name: "C/Clang/MaxPerf", 
    build_cmd: "sh -c 'sh build-deps.sh; gcc #{C_INCLUDE_FLAGS} #{C_FLAGS_MAX} main.c -o target/bin_c_clang_max #{LD_FLAGS_MAX} #{C_LINK_FLAGS}'",
    binary_name: "./target/bin_c_clang_max",
    run_cmd: "./target/bin_c_clang_max", 
    version_cmd: "gcc --version | head -n 1",
    dir: "/src/c",
    container: "clang_c",
    group: :hack,
    deps_cmd: "sh fetch-deps.sh",
  ),
  
  Run.new(
    name: "C/Gcc/MaxPerf", 
    build_cmd: "sh -c 'sh build-deps.sh; gcc #{C_INCLUDE_FLAGS} #{C_FLAGS_MAX} main.c -o target/bin_c_gcc_max #{LD_FLAGS_MAX.gsub("-flto=thin", "-flto").gsub("-flto=full", "-flto")} #{C_LINK_FLAGS}'",
    binary_name: "./target/bin_c_gcc_max",
    run_cmd: "./target/bin_c_gcc_max", 
    version_cmd: "gcc --version | head -n 1",
    dir: "/src/c",
    container: "gcc_c",
    group: :hack,
    deps_cmd: "sh fetch-deps.sh",
  ),

  # ======================================= С++ ======================================================
  Run.new(
    name: "C++/Clang++/Default", 
    build_cmd: "sh -c 'sh build-deps.sh; g++ #{CXX_INCLUDE_FLAGS} -O2 -std=c++20 main.cpp -o target/bin_cpp_clang_def #{CXX_LINK_FLAGS}'",
    binary_name: "./target/bin_cpp_clang_def",
    run_cmd: "./target/bin_cpp_clang_def", 
    version_cmd: "g++ --version | head -n 1",
    dir: "/src/cpp",
    container: "clang_cpp",
    group: :hack,
    deps_cmd: "sh fetch-deps.sh",
  ),

  Run.new(
    name: "C++/G++/Default", 
    build_cmd: "sh -c 'sh build-deps.sh; g++ #{CXX_INCLUDE_FLAGS} -O2 -std=c++20 main.cpp -o target/bin_cpp_gcc_def #{CXX_LINK_FLAGS}'",
    binary_name: "./target/bin_cpp_gcc_def",
    run_cmd: "./target/bin_cpp_gcc_def", 
    version_cmd: "g++ --version | head -n 1",
    dir: "/src/cpp",
    container: "gcc_cpp",
    group: :hack,
    deps_cmd: "sh fetch-deps.sh",
  ),

  Run.new(
    name: "C++/Clang++", 
    build_cmd: "sh -c 'sh build-deps.sh; g++ #{CXX_INCLUDE_FLAGS} #{CXXFLAGS_PROD} main.cpp -o target/bin_cpp_clang #{LD_FLAGS_PROD} #{CXX_LINK_FLAGS}'",
    binary_name: "./target/bin_cpp_clang",
    run_cmd: "./target/bin_cpp_clang", 
    version_cmd: "g++ --version | head -n 1",
    dir: "/src/cpp",
    container: "clang_cpp",
    group: :prod,
    deps_cmd: "sh fetch-deps.sh",
  ),

  Run.new(
    name: "C++/G++", 
    build_cmd: "sh -c 'sh build-deps.sh; g++ #{CXX_INCLUDE_FLAGS} #{CXXFLAGS_PROD} main.cpp -o target/bin_cpp_gcc #{LD_FLAGS_PROD} #{CXX_LINK_FLAGS}'",
    binary_name: "./target/bin_cpp_gcc",
    run_cmd: "./target/bin_cpp_gcc", 
    version_cmd: "g++ --version | head -n 1",
    dir: "/src/cpp",
    container: "gcc_cpp",
    group: :prod,
    deps_cmd: "sh fetch-deps.sh",
  ),

  Run.new(
    name: "C++/Clang++/ENH", 
    build_cmd: "sh -c 'sh build-deps.sh; g++ #{CXX_INCLUDE_FLAGS} #{CXXFLAGS_ENH} main.cpp -o target/bin_cpp_clang_enh #{LD_FLAGS_ENH} #{CXX_LINK_FLAGS}'",
    binary_name: "./target/bin_cpp_clang_enh",
    run_cmd: "./target/bin_cpp_clang_enh", 
    version_cmd: "g++ --version | head -n 1",
    dir: "/src/cpp",
    container: "clang_cpp",
    group: :hack,
    deps_cmd: "sh fetch-deps.sh",
  ),

  Run.new(
    name: "C++/G++/ENH", 
    build_cmd: "sh -c 'sh build-deps.sh; g++ #{CXX_INCLUDE_FLAGS} #{CXXFLAGS_ENH} main.cpp -o target/bin_cpp_gcc_enh #{LD_FLAGS_ENH.gsub("-flto=thin", "-flto").gsub("-flto=full", "-flto")} #{CXX_LINK_FLAGS}'",
    binary_name: "./target/bin_cpp_gcc_enh",
    run_cmd: "./target/bin_cpp_gcc_enh", 
    version_cmd: "g++ --version | head -n 1",
    dir: "/src/cpp",
    container: "gcc_cpp",
    group: :hack,
    deps_cmd: "sh fetch-deps.sh",
  ),

  Run.new(
    name: "C++/Clang++/MaxPerf", 
    build_cmd: "sh -c 'sh build-deps.sh; g++ #{CXX_INCLUDE_FLAGS} #{CXXFLAGS_MAX} main.cpp -o target/bin_cpp_clang_max #{LD_FLAGS_MAX} #{CXX_LINK_FLAGS}'",
    binary_name: "./target/bin_cpp_clang_max",
    run_cmd: "./target/bin_cpp_clang_max", 
    version_cmd: "g++ --version | head -n 1",
    dir: "/src/cpp",
    container: "clang_cpp",
    group: :hack,
    deps_cmd: "sh fetch-deps.sh",
  ),

  Run.new(
    name: "C++/G++/MaxPerf", 
    build_cmd: "sh -c 'sh build-deps.sh; g++ #{CXX_INCLUDE_FLAGS} #{CXXFLAGS_MAX} main.cpp -o target/bin_cpp_gcc_max #{LD_FLAGS_MAX.gsub("-flto=thin", "-flto").gsub("-flto=full", "-flto")} #{CXX_LINK_FLAGS}'",
    binary_name: "./target/bin_cpp_gcc_max",
    run_cmd: "./target/bin_cpp_gcc_max", 
    version_cmd: "g++ --version | head -n 1",
    dir: "/src/cpp",
    container: "gcc_cpp",
    group: :hack,
    deps_cmd: "sh fetch-deps.sh",
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
    deps_cmd: "zig libc",
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
    deps_cmd: "zig libc",
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
    deps_cmd: "mkdir -p target",
  ),

  # ======================================= Go ======================================================
  Run.new(
    name: "Go", 
    build_cmd: "go build -o target/bin_go main.go", 
    binary_name: "./target/bin_go", 
    run_cmd: "./target/bin_go", 
    version_cmd: "go version",
    dir: "/src/golang",
    container: "golang",
    group: :prod,
    deps_cmd: "mkdir -p target", # go mod download
  ),
  Run.new(
    name: "Go/Opt", 
    build_cmd: "go build -a -trimpath -ldflags=\"-s -w -extldflags '-static'\" -tags=\"osusergo,netgo\" -o target/bin_go_opts main.go", 
    binary_name: "./target/bin_go_opts", 
    run_cmd: "./target/bin_go_opts", 
    version_cmd: "go version",
    dir: "/src/golang",
    container: "golang",
    group: :hack,
    deps_cmd: "mkdir -p target",
  ),
  Run.new(
    name: "Go/GccGo", 
    build_cmd: "gccgo -O2 main.go -o ./target/bin_gccgo", 
    binary_name: "./target/bin_gccgo", 
    run_cmd: "./target/bin_gccgo", 
    version_cmd: "gccgo --version | head -n 1",
    dir: "/src/golang",
    container: "gccgo",
    group: :hack,
    deps_cmd: "mkdir -p target",
  ),

  Run.new(
    name: "Go/GccGo/Opt", 
    build_cmd: "gccgo -O3 -march=native -flto -fuse-linker-plugin -funroll-loops -fgo-optimize-allocs -static-libgo -s -w -fomit-frame-pointer -fno-semantic-interposition -fno-common -Bstatic main.go -o ./target/bin_gccgo_opt", 
    binary_name: "./target/bin_gccgo_opt", 
    run_cmd: "./target/bin_gccgo_opt", 
    version_cmd: "gccgo --version | head -n 1",
    dir: "/src/golang",
    container: "gccgo",
    group: :prod,
    deps_cmd: "mkdir -p target",
  ),

  # ======================================= C# ======================================================
  # Базовый JIT (для разработки) - БЫСТРЫЙ СТАРТ, СРЕДНЯЯ ПРОИЗВОДИТЕЛЬНОСТЬ
  Run.new(
    name: "C#/JIT", 
    build_cmd: "dotnet build -c Release",
    binary_name: "./bin/Release/net10.0/Benchmark.dll",
    run_cmd: "dotnet ./bin/Release/net10.0/Benchmark.dll", 
    version_cmd: "dotnet --version",
    dir: "/src/csharp",
    container: "dotnet",   
    group: :prod, 
    deps_cmd: "dotnet restore",
  ),

  # AOT Native (максимальная скорость выполнения) - ИСПРАВЛЕННЫЙ
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
    group: :prod,        
    deps_cmd: "dotnet restore",
  ),

  # Self-Contained JIT (портируемый) - ДОЛГО ЗАПУСКАЕТСЯ
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

  # Self-Contained AOT (максимум всего) - САМЫЙ МЕДЛЕННЫЙ СТАРТ, САМЫЙ БЫСТРЫЙ ВЫПОЛНЕНИЕ
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

  # ReadyToRun (компромисс) - ХОРОШИЙ БАЛАНС
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

  # Экстремальный AOT профиль
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

  # ======================================= Swift ======================================================
  # Базовый (стандартный релиз)
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
  
  # WMO (лучшая безопасная оптимизация)
  Run.new(
    name: "Swift/WMO", 
    build_cmd: "swift build -c release -Xswiftc -O -Xswiftc -whole-module-optimization",
    binary_name: "./.build/release/Benchmarks",
    run_cmd: "./.build/release/Benchmarks", 
    version_cmd: "swift -version | head -n 1",
    dir: "/src/swift",
    container: "swift",
    group: :hack,
    deps_cmd: "swift package resolve",
  ),
  
  # Unchecked (без проверок безопасности)
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
  
  # WMO + Unchecked (максимум без LLVM оптимизаций)
  Run.new(
    name: "Swift/WMO+Unchecked", 
    build_cmd: "swift build -c release -Xswiftc -O -Xswiftc -whole-module-optimization -Xswiftc -enforce-exclusivity=unchecked",
    binary_name: "./.build/release/Benchmarks",
    run_cmd: "./.build/release/Benchmarks", 
    version_cmd: "swift -version | head -n 1",
    dir: "/src/swift",
    container: "swift",
    group: :hack,
    deps_cmd: "swift package resolve",
  ),
  
  # MaxPerf (исправленный)
  Run.new(
    name: "Swift/MaxPerf", 
    build_cmd: "swift build -c release -Xswiftc -Ounchecked -Xswiftc -whole-module-optimization -Xswiftc -enforce-exclusivity=unchecked -Xswiftc -cross-module-optimization",
    binary_name: "./.build/release/Benchmarks",
    run_cmd: "./.build/release/Benchmarks", 
    version_cmd: "swift -version | head -n 1",
    dir: "/src/swift",
    container: "swift",
    group: :hack,
    deps_cmd: "swift package resolve",
  ),
    
  # ======================================= Java ======================================================
  # Java - базовый (без оптимизаций)
  Run.new(
    name: "Java/OpenJDK",
    build_cmd: <<~CMD.chomp,
      mvn compile package -Pjava-plain \
        -DskipTests \
        -Dmaven.test.skip=true \
        -q
    CMD
    binary_name: "./target/java-benchmarks-1.0-SNAPSHOT.jar",
    run_cmd: <<~CMD.chomp,
      java \
        -Xmx8g \
        -Dfile.encoding=UTF-8 \
        -jar ./target/java-benchmarks-1.0-SNAPSHOT.jar
    CMD
    version_cmd: "java --version",
    dir: "/src/java",
    container: "java",
    group: :prod,
    deps_cmd: "mvn dependency:resolve; mvn dependency:resolve-plugins",
  ),

  # Java с максимальными оптимизациями
  Run.new(
    name: "Java/OpenJDK/Opt",
    build_cmd: <<~CMD.chomp,
      mvn compile package -Pjava-optimized \
        -DskipTests \
        -Dmaven.test.skip=true \
        -q
    CMD
    binary_name: "./target/java-benchmarks-1.0-SNAPSHOT.jar",
    run_cmd: <<~CMD.chomp,
      java \
        -Dfile.encoding=UTF-8 \
        -XX:+UseParallelGC \
        -XX:+UseLargePages \
        -XX:+AlwaysPreTouch \
        -XX:+UseNUMA \
        -XX:+UseCompressedOops \
        -XX:+OptimizeStringConcat \
        -XX:+UseStringDeduplication \
        -XX:+DisableExplicitGC \
        -XX:+UseCountedLoopSafepoints \
        -Xmx8g \
        -jar ./target/java-benchmarks-1.0-SNAPSHOT.jar
    CMD
    version_cmd: "java --version",
    dir: "/src/java",
    container: "java",
    group: :hack,
    deps_cmd: "mvn dependency:resolve; mvn dependency:resolve-plugins",
  ),

  # GraalVM JIT с оптимизациями
  Run.new(
    name: "Java/GraalVM/JIT",
    build_cmd: <<~CMD.chomp,
      mvn compile package -Pgraalvm-jit \
        -DskipTests \
        -Dmaven.test.skip=true \
        -q
    CMD
    binary_name: "./target/java-benchmarks-1.0-SNAPSHOT.jar",
    run_cmd: <<~CMD.chomp,
      java \
        -Dfile.encoding=UTF-8 \
        -XX:+UseG1GC \
        -XX:+EnableJVMCI \
        -XX:+UseJVMCICompiler \
        -Djvmci.Compiler=graal \
        -XX:-TieredCompilation \
        -Xmx8g \
        -jar ./target/java-benchmarks-1.0-SNAPSHOT.jar
    CMD
    version_cmd: "java --version",
    dir: "/src/java",
    container: "graalvm",
    group: :prod,
    deps_cmd: "mvn dependency:resolve; mvn dependency:resolve-plugins",
  ),

  # GraalVM Native Image (AOT)
  Run.new(
    name: "Java/GraalVM/Native",
    build_cmd: <<~CMD.chomp,
      mvn package -Pgraalvm-native \
        -DskipTests \
        -Dmaven.test.skip=true \
        -Dnative.buildArgs="--no-fallback --gc=serial -O3"
    CMD
    binary_name: "./target/benchmarks-native",
    run_cmd: <<~CMD.chomp,
      ./target/benchmarks-native -Xmx12g
    CMD
    version_cmd: "native-image --version",
    dir: "/src/java",
    container: "graalvm",
    group: :prod,
    deps_cmd: "mvn dependency:resolve; mvn dependency:resolve-plugins",
  ),

  # Дополнительный вариант: GraalVM Native с максимальными оптимизациями
  Run.new(
    name: "Java/GraalVM/Native/Max",
    build_cmd: <<~CMD.chomp,
      mvn package -Pgraalvm-native \
        -DskipTests \
        -Dmaven.test.skip=true \
        -Dnative.buildArgs="--gc=serial \
          --enable-url-protocols=http,https \
          --initialize-at-build-time=org.json \
          --no-fallback \
          -O3 \
          -march=native \
          -mtune=native \
          -H:MaxHeapSize=16g \
          -H:MaxNewSize=8g \
          -H:+StripDebugInfo \
          -H:+ReportExceptionStackTraces \
          -H:+EnableJVMCI" \
        -q
    CMD
    binary_name: "./target/benchmarks-native",
    run_cmd: <<~CMD.chomp,
      ./target/benchmarks-native \
        -Xmx12g
    CMD
    version_cmd: "native-image --version",
    dir: "/src/java",
    container: "graalvm",
    group: :hack,
    deps_cmd: "mvn dependency:resolve; mvn dependency:resolve-plugins",
  ),

  # ======================================= Kotlin ======================================================

  # Kotlin - базовый (минимальные оптимизации)
  Run.new(
    name: "Kotlin/JVM/Default",
    build_cmd: "./gradlew fatJar --no-daemon -q",
    binary_name: "/src/kotlin/build/libs/benchmarks.jar",
    run_cmd: "java -Xmx8g -jar /src/kotlin/build/libs/benchmarks.jar",
    version_cmd: "kotlin -version",
    dir: "/src/kotlin",
    container: "kotlin",
    group: :prod,
    deps_cmd: "./gradlew --no-daemon dependencies",
  ),

  # Kotlin - агрессивные оптимизации
  Run.new(
    name: "Kotlin/JVM/Opt",
    build_cmd: "./gradlew fatJar --no-daemon -q",
    binary_name: "/src/kotlin/build/libs/benchmarks.jar",
    run_cmd: <<~CMD.chomp,
      java \
        -server \
        -XX:+UseG1GC \
        -Xms2g \
        -Xmx2g \
        -XX:+AlwaysPreTouch \
        -XX:+UseNUMA \
        -XX:+OptimizeStringConcat \
        -XX:+UseCompressedOops \
        -Xmx8g \
        -jar /src/kotlin/build/libs/benchmarks.jar
    CMD
    version_cmd: "kotlin -version",
    dir: "/src/kotlin",
    container: "kotlin",
    group: :hack,
    deps_cmd: "./gradlew --no-daemon dependencies",
  ),

  # Kotlin - максимальные оптимизации
  Run.new(
    name: "Kotlin/JVM/Max",
    build_cmd: "./gradlew fatJar --no-daemon -q",
    binary_name: "/src/kotlin/build/libs/benchmarks.jar",
    run_cmd: <<~CMD.chomp,
      java \
        -server \
        -XX:+UseParallelGC \
        -Xms4g \
        -Xmx8g \
        -XX:+AlwaysPreTouch \
        -XX:+UseNUMA \
        -XX:+UseLargePages \
        -XX:+DisableExplicitGC \
        -Djava.security.egd=file:/dev/./urandom \
        -jar /src/kotlin/build/libs/benchmarks.jar
    CMD
    version_cmd: "kotlin -version",
    dir: "/src/kotlin",
    container: "kotlin",
    group: :hack,
    deps_cmd: "./gradlew --no-daemon dependencies",
  ),

  # Kotlin + GraalVM JIT
  Run.new(
    name: "Kotlin/GraalVM/JIT",
    build_cmd: "./gradlew fatJar --no-daemon -q",
    binary_name: "/src/kotlin/build/libs/benchmarks.jar",
    run_cmd: <<~CMD.chomp,
      java \
        -XX:+UseG1GC \
        -XX:+EnableJVMCI \
        -XX:+UseJVMCICompiler \
        -Djvmci.Compiler=graal \
        -XX:-TieredCompilation \
        -Xmx8g \
        -jar /src/kotlin/build/libs/benchmarks.jar
    CMD
    version_cmd: "kotlin -version",
    dir: "/src/kotlin",
    container: "kotlin-graalvm",
    group: :prod,
    deps_cmd: "./gradlew --no-daemon dependencies",
  ),

  # =============== KOTLIN + GRAALVM NATIVE ===============

  Run.new(
    name: "Kotlin/GraalVM/Native",
    build_cmd: "/src/kotlin/build-kotlin-native.sh",
    binary_name: "/src/kotlin/build/native/benchmarks",
    run_cmd: "/src/kotlin/build/native/benchmarks -Xmx8g",
    version_cmd: "kotlin -version",
    dir: "/src/kotlin",
    container: "kotlin-graalvm",
    group: :prod,
    deps_cmd: "./gradlew --no-daemon dependencies",
  ),

  Run.new(
    name: "Kotlin/GraalVM/Native/Max",
    build_cmd: "/src/kotlin/build-kotlin-native-max.sh",
    binary_name: "/src/kotlin/build/native/benchmarks-max",
    run_cmd: "/src/kotlin/build/native/benchmarks-max -Xmx8g",
    version_cmd: "kotlin -version",
    dir: "/src/kotlin",
    container: "kotlin-graalvm",
    group: :hack,
    deps_cmd: "./gradlew --no-daemon dependencies",
  ),

  # Опционально: с разными уровнями оптимизаций
  Run.new(
    name: "Kotlin/GraalVM/Native/Fast",
    build_cmd: "/src/kotlin/build-kotlin-native.sh '-O2' benchmarks-fast",
    binary_name: "/src/kotlin/build/native/benchmarks-fast",
    run_cmd: "/src/kotlin/build/native/benchmarks-fast -Xmx8g",
    version_cmd: "kotlin -version",
    dir: "/src/kotlin",
    container: "kotlin-graalvm",
    group: :hack,
    deps_cmd: "./gradlew --no-daemon dependencies",
  ),

  # ======================================= TypeScript ======================================================

  # TypeScript - дефолтная компиляция
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

  # TypeScript с оптимизациями Node.js (исправленный)
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

  # TypeScript с максимальными оптимизациями (проверенные флаги)
  Run.new(
    name: "TypeScript/Node/Max",
    build_cmd: "sh -c 'npm ci --silent && npm run build:run --silent'",
    binary_name: "/src/typescript/target/dist/index.js",
    run_cmd: <<~CMD.chomp,
      node \
        --max-old-space-size=8192 \
        --max-semi-space-size=512 \
        --optimize-for-size \
        --no-concurrent-sweeping \
        --single-threaded-gc \
        /src/typescript/target/dist/index.js
    CMD
    version_cmd: "/bin/bash -c 'echo \"TCS $(tsc --version), Node $(node --version)\"'",
    dir: "/src/typescript",
    container: "typescript",
    group: :hack,
    deps_cmd: "npm ci",
  ),

  # TypeScript с турбофан оптимизациями
  Run.new(
    name: "TypeScript/Node/Turbo",
    build_cmd: "sh -c 'npm ci --silent && npm run build:run --silent'",
    binary_name: "/src/typescript/target/dist/index.js",
    run_cmd: <<~CMD.chomp,
      node \
        --max-old-space-size=4096 \
        --max-semi-space-size=128 \
        --optimize-for-size \
        --concurrent-recompilation \
        /src/typescript/target/dist/index.js
    CMD
    version_cmd: "/bin/bash -c 'echo \"TCS $(tsc --version), Node $(node --version)\"'",
    dir: "/src/typescript",
    container: "typescript",
    group: :hack,
    deps_cmd: "npm ci",
  ),

  # TypeScript с Bun (компиляция на лету)
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

  # TypeScript с Bun (скомпилированный)
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
    group: :prod,
    deps_cmd: "bun install",
  ),

  # Deno - дефолтный запуск с кэшированием зависимостей
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

  # Deno с AOT компиляцией (оптимизированный)
  Run.new(
    name: "TypeScript/Deno/Compiled",
    build_cmd: <<~CMD.chomp,
      deno compile \
        --allow-all \
        --no-check \
        --output=target/dist-deno/index \
        src/index.ts
    CMD
    binary_name: "/src/typescript/target/dist-deno/index",
    run_cmd: "/src/typescript/target/dist-deno/index",
    version_cmd: "deno --version",
    dir: "/src/typescript",
    container: "typescript-deno",
    group: :prod,
    deps_cmd: "deno cache --quiet src/index.ts",
  ),

  # Deno с оптимизациями V8
  Run.new(
    name: "TypeScript/Deno/Opt",
    build_cmd: "true",
    binary_name: "/src/typescript/src/index.ts",
    run_cmd: <<~CMD.chomp,
      deno run \
        --allow-all \
        --v8-flags="--max-old-space-size=4096,--max-semi-space-size=256,--optimize-for-size" \
        /src/typescript/src/index.ts
    CMD
    version_cmd: "deno --version",
    dir: "/src/typescript",
    container: "typescript-deno",
    group: :hack,
    deps_cmd: "deno cache --quiet src/index.ts",
  ),

  # Deno с максимальными оптимизациями V8
  Run.new(
    name: "TypeScript/Deno/Max",
    build_cmd: "true",
    binary_name: "/src/typescript/src/index.ts",
    run_cmd: <<~CMD.chomp,
      deno run \
        --allow-all \
        --v8-flags="--max-old-space-size=8192,--max-semi-space-size=512,--optimize-for-size,--no-concurrent-sweeping" \
        --no-check \
        /src/typescript/src/index.ts
    CMD
    version_cmd: "deno --version",
    dir: "/src/typescript",
    container: "typescript-deno",
    group: :hack,
    deps_cmd: "deno cache --quiet src/index.ts",
  ),

  # Deno с JIT-оптимизациями и кэшированием кода
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

puts "Found runs: #{RUNS.size} #{RUNS.size < 10 ? RUNS.map(&:name).inspect : nil}"

langs = {}
RUNS.each do |run|
  lang = run.dir.gsub("/src/", "")
  langs[lang] = 1
end
LANGS = langs.keys
puts "Unique languages: #{LANGS.size} #{LANGS.inspect}"

test_txt = File.read("test.txt")
tests = test_txt.split("\n").map { |l| l.split("|").first }
TESTS = case ARGV[1]
when nil, ""
  tests
when "rand", "Rand", "r", "r"
  tests.sample(1)
else
  regx = /#{Regexp.escape ARGV[1]}/
  tests.select { |t| t =~ regx }
end
puts "All tests count: #{TESTS.size} (#{TESTS.join(", ")})"
puts

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
RESULTS["compile-mem-mb"] = {}
RESULTS["compile-time-cold"] = {}
RESULTS["compile-time-warm"] = {}
RESULTS["version"] = {}

check_source_files(IS_VERBOSE)

# # Show versions
# RUNS.group_by(&:container).each do |container, runs|
#   runs.group_by(&:version_cmd).each do |_, vcmds|
#     v = vcmds[0]
#     puts "Version #{container}: '#{v.version}'"
#   end
# end

# # prepare cache deps
# RUNS.group_by { |r| [r.container, r.deps_cmd] }.each do |_, runs|
#   run = runs[0]

#   print "Prepare deps for #{run.name}: "
#   delta = measure { run.deps }
#   puts "in #{delta.round(2)}s"
# end

CFG = IS_RUN_TEST ? "../test.txt" : "../run.txt"

def build(run, verbose = true)
  print "building #{run.name} ..."
  stats = nil
  delta = measure do
    stats = run.run(run.build_cmd, verbose)
  end
  fsize_stats = run.run("sh -c 'du -k #{run.binary_name} | cut -f1'", verbose)
  RESULTS["binary-size-kb"][run.name] = fsize_stats[:out].split("\n").last.to_i
  RESULTS["build-cmd"][run.name] = run.build_cmd
  RESULTS["run-cmd"][run.name] = run.run_cmd
  RESULTS["compile-time-cold"][run.name] = delta.to_f  
  RESULTS["compile-mem-mb"][run.name] = stats[:rss] / 1024.0
  RESULTS["version"][run.name] = run.version
  puts " in #{delta.to_f.round(2)}s"
  delta
end

# build
RUNS.each do |run|
  build(run, IS_VERBOSE)
end

p RESULTS
exit

# exit

def run(run, index)
  puts "Building #{run.name} (#{index} from #{RUNS.size})"
  build(run, IS_VERBOSE)

  puts "Running #{run.name} (#{index} from #{RUNS.size})"
  TESTS.each_with_index do |test_name, index|
    print "#{index}. #{test_name}"
    RESULTS[test_name+"-runtime"] ||= {}
    RESULTS[test_name+"-mem-mb"] ||= {}
  
    stats = run.run("#{run.run_cmd} #{CFG} #{test_name}", IS_VERBOSE)
    mem = stats[:rss] / 1024.0
    RESULTS[test_name+"-mem-mb"][run.name] = mem

    if stats[:out] =~ /#{test_name}: OK in ([\d\.]+)s/      
      run_time = $1.to_f
      puts " - #{run_time}s, #{(mem).round(1)}Mb"
    else
      puts "Warning something wrong while running #{run.inspect}: #{stats.inspect}"
      run_time = "---(#{stats.inspect})"      
    end

    RESULTS[test_name+"-runtime"][run.name] = run_time
  end
end

def write_results
  unless ARGV[0]
    # write result on every step, because it can crash somewhere
    File.write("./results/#{RESULTS["date"]}-#{RESULTS["uname-name"]}.js", JSON.pretty_generate(RESULTS))  
  end
end

puts "---------- Run ----------"
RUNS.each_with_index do |run, index| 
  delta = measure do
    run(run, index)
  end
  puts "Finished #{run.name} in #{delta.round(3)}"
  write_results
end

end_t = Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond)
puts "----------- FINISHED in #{((end_t - START_TIME).to_f / 1e9).round(2)}s-------------"
write_results
