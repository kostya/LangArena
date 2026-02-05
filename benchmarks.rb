# Run all benchmarks and store results to ./results/
#
# `docker compose build` should be done before use this script
#
# Run all `ruby benchmarks.rb`
# Run only Lang Regex `ruby benchmarks.rb C++`
# Run only Lang Regex and Test Regex `ruby benchmarks.rb C++ Primes`
# Run Prod configs exclude Hack `PROD=1 ruby benchmarks.rb`
# Run test configs - just to check (faster finished) `TEST=1 ruby benchmarks.rb`

IS_VERBOSE = ENV["VERBOSE"] == "1" # show docker commands
IS_RUN_PROD = ENV["PROD"] == "1" # use only prod runs
IS_RUN_TEST = ENV["TEST"] == "1" # use test.js for testing, faster
IS_LOG_CRASH = ENV["LOG_CRASH"] == "1" # log instead of crash
IS_ONE_RUN_PER_LANG = ENV["BY_LANG"] == "1" # run only one run for each language
IS_NO_BUILD = ENV["NO_BUILD"] == "1" # not test build stage
IS_NO_DEPS = ENV["NO_DEPS"] == "1" # not test deps stage
IS_NO_VERSION = ENV["NO_VERSION"] == "1" # not test versions
IS_CLEAR_COMMENTS = ENV["CLEAR_COMMENTS"] == "1" # start special mode to clear comments

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

RECOMPILE_MARKER_0 = "RECOMPILE_MARKER_0"
RECOMPILE_MARKER_1 = "RECOMPILE_MARKER_1"
RECOMPILE_MARKER_FILES = {}

LANG_MASKS = {
  'c' => ['./c', ['.c', '.h'], ['target', 'deps']],
  'cpp' => ['./cpp', ['.cpp', '.hpp', '.h', '.cc', '.cxx'], ['target', 'deps']],
  'golang' => ['./golang', ['.go'], ['target']],
  'crystal' => ['./crystal', ['.cr'], ['target']],
  'rust' => ['./rust', ['.rs'], ['target']],
  'csharp' => ['./csharp', ['.cs'], ['obj', 'bin']],
  'swift' => ['./swift', ['.swift'], ['.build', 'Package.swift']],
  'java' => ['./java', ['.java'], ['target']],
  'kotlin' => ['./kotlin', ['.kt'], ['build', '.gradle', 'gradle']],
  'typescript' => ['./typescript', ['.ts', '.tsx'], ['node_modules', 'target']],
  'zig' => ['./zig', ['.zig'], ['.zig-cache']],
  'd' => ['./d', ['.d'], []],
  'v' => ['./v', ['.v'], ['target']],
  'julia' => ['./julia', ['.jl'], ['target']],
  'nim' => ['./nim', ['.nim'], ['target']],
  'fsharp' => ['./fsharp', ['.fs'], ['bin', 'obj']],
}

def check_source_files(verbose = false)
  #!/usr/bin/env ruby
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
        RECOMPILE_MARKER_FILES[lang] = full_path if data.include?(RECOMPILE_MARKER_0) && !RECOMPILE_MARKER_FILES[lang]
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

module ClearComments
  def self.remove_comments(filepath, lang)
    content = File.read(filepath, encoding: 'utf-8')
    
    case lang
    when 'c', 'cpp', 'golang', 'rust', 'csharp', 'swift', 'java', 'kotlin', 'd', 'v', 'fsharp'
      # Обычные C-подобные языки
      content.gsub!(/\/\*[\s\S]*?\*\//m, '')
      content.gsub!(/\/\/[^\n]*/, '')
      
    when 'typescript'
      # TypeScript - специальная обработка для @ts-ignore
      # Удаляем многострочные комментарии
      content.gsub!(/\/\*[\s\S]*?\*\//m, '')
      
      # Обрабатываем строки с @ts-ignore
      content.gsub!(/(\/\/\s*@ts-ignore)[^\n]*/) do |match|
        # Оставляем только // @ts-ignore
        "#{$1}"
      end
      
      # Удаляем все остальные однострочные комментарии
      content.gsub!(/\/\/[^\n]*/) do |match|
        # Пропускаем строки, которые уже начинаются с @ts-ignore
        match.start_with?('// @ts-ignore') ? match : ''
      end
      
    when 'crystal'
      content.gsub!(/^\s*#[^\n]*/, '')
      content.gsub!(/^=begin[\s\S]*?^=end/m, '')
      
    when 'julia'
      content.gsub!(/#[^\n]*/, '')
      content.gsub!(/#=[\s\S]*?=#/m, '')
      
    when 'nim'
      content.gsub!(/#[^\n]*/, '')
      content.gsub!(/#\[[\s\S]*?\]\#/m, '')
    end
    
    # Убираем пробелы/табы в полностью пустых строках
    content.gsub!(/^[ \t]+$/, '')
    
    # Удаляем множественные пустые строки подряд, оставляя максимум одну
    while content.gsub!(/\n\n\n+/, "\n\n")
    end
    
    # Удаляем пустую строку в начале файла
    content.sub!(/\A\n+/, '')
    
    # Удаляем пустую строку в конце файла
    content.sub!(/\n+\z/, '')
    
    File.write(filepath, content, encoding: 'utf-8')
    puts "Обработан: #{filepath}"
  end
  
  # Функция для обработки всех файлов
  def self.process_all_files(lang_masks)
    lang_masks.each do |lang, config|
      dir, exts, excludes = config
      
      puts "Обрабатываю язык: #{lang}"
      
      # Находим все файлы с нужными расширениями
      pattern = "#{dir}/**/*{#{exts.join(',')}}"
      files = Dir.glob(pattern, File::FNM_DOTMATCH)
      
      # Исключаем директории из excludes
      files.reject! do |file|
        excludes.any? { |exclude| file.include?(exclude) }
      end
      
      files.each do |file|
        begin
          remove_comments(file, lang)
          puts "  ✓ #{file}"
        rescue => e
          puts "  ✗ Ошибка в #{file}: #{e.message}"
        end
      end
    end
  end
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

  def lang
    @dir.gsub("/src/", "")
  end

  def dcr
    "docker compose run --rm -q --remove-orphans #{@container} "
  end

  def rss_prefix
    "/usr/bin/time -f 'MaxRSS(%M)KB' 2>&1 "
  end

  def run(cmd, debug = false, measure_start_time = false)
    if measure_start_time
      cmd = %Q|#{dcr}#{rss_prefix} sh -c 'echo "start0: $(date +%s%3N)"; #{cmd}'|
    else
      cmd = %Q|#{dcr}#{rss_prefix} #{cmd}|
    end
    if debug
      print cmd
    end
    stdout = `#{cmd}`    
    exitstatus = $?.exitstatus
    if exitstatus != 0
      if IS_LOG_CRASH
        puts "Failed `#{cmd}`, exitstatus: #{exitstatus}"
        File.open("/tmp/log_crash.txt", "a") { |f| f.puts "#{Time.now}: Failed `#{cmd}`, exitstatus: #{exitstatus}" }
      else
        raise "Failed to build `#{cmd}`, exitstatus: #{exitstatus}"
      end
    end
    stdout =~ /MaxRSS\(([0-9]*?)\)KB\n/
    rss = $1.to_i

    stdout =~ /start0: ([0-9]+?)$/
    start0_ts = $1.to_i
    start0 = Time.at(start0_ts / 1000.0)

    stdout =~ /start: ([0-9]+?)$/
    start_ts = $1.to_i
    start = Time.at(start_ts / 1000.0)

    h = {out: stdout.sub(/MaxRSS\(([0-9]*?)\)KB\n/, ""), rss: rss, start_duration: (start - start0).to_f}
    h
  end

  def deps
    cmd = "sh -c '#{@deps_cmd}'"
    run(cmd, IS_VERBOSE)
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

CXX_INCLUDE_FLAGS = " -Ideps -Ideps/base64/include -Wl,-rpath,/opt/homebrew/opt/llvm/lib/c++ -L/opt/homebrew/opt/llvm/lib/c++ -L/opt/homebrew/lib -I/opt/homebrew/include/ -Ideps/simdjson"
CXX_LINK_FLAGS = " target/libbase64.o target/simdjson.o -lgmp -lre2 -lpthread"

RUNS = [

  # ======================================= C ======================================================
  # No Effect
  # Run.new(
  #   name: "C/Clang/Default", 
  #   build_cmd: "sh -c 'sh build-deps.sh; gcc #{C_INCLUDE_FLAGS} -O2 main.c -o target/bin_c_clang_def #{C_LINK_FLAGS}'",
  #   binary_name: "./target/bin_c_clang_def",
  #   run_cmd: "./target/bin_c_clang_def", 
  #   version_cmd: "gcc --version | head -n 1",
  #   dir: "/src/c",
  #   container: "clang_c",
  #   group: :hack,
  #   deps_cmd: "sh fetch-deps.sh",
  # ),
  
  # No Effect 
  # Run.new(
  #   name: "C/Gcc/Default", 
  #   build_cmd: "sh -c 'sh build-deps.sh; gcc #{C_INCLUDE_FLAGS} -O2 main.c -o target/bin_c_gcc_def #{C_LINK_FLAGS}'",
  #   binary_name: "./target/bin_c_gcc_def",
  #   run_cmd: "./target/bin_c_gcc_def", 
  #   version_cmd: "gcc --version | head -n 1",
  #   dir: "/src/c",
  #   container: "gcc_c",
  #   group: :hack,
  #   deps_cmd: "sh fetch-deps.sh",
  # ),
  
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
  # No Effect
  # Run.new(
  #   name: "C++/Clang++/Default", 
  #   build_cmd: "sh -c 'sh build-deps.sh; g++ #{CXX_INCLUDE_FLAGS} -O2 -std=c++20 main.cpp -o target/bin_cpp_clang_def #{CXX_LINK_FLAGS}'",
  #   binary_name: "./target/bin_cpp_clang_def",
  #   run_cmd: "./target/bin_cpp_clang_def", 
  #   version_cmd: "g++ --version | head -n 1",
  #   dir: "/src/cpp",
  #   container: "clang_cpp",
  #   group: :hack,
  #   deps_cmd: "sh fetch-deps.sh",
  # ),

  # No Effect
  # Run.new(
  #   name: "C++/G++/Default", 
  #   build_cmd: "sh -c 'sh build-deps.sh; g++ #{CXX_INCLUDE_FLAGS} -O2 -std=c++20 main.cpp -o target/bin_cpp_gcc_def #{CXX_LINK_FLAGS}'",
  #   binary_name: "./target/bin_cpp_gcc_def",
  #   run_cmd: "./target/bin_cpp_gcc_def", 
  #   version_cmd: "g++ --version | head -n 1",
  #   dir: "/src/cpp",
  #   container: "gcc_cpp",
  #   group: :hack,
  #   deps_cmd: "sh fetch-deps.sh",
  # ),

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

  # ======================================= D ======================================================

  # Release сборки (базовые оптимизации)
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

  # Perf сборки (оптимальный баланс)
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

  Run.new(
    name: "D/GDC",
    build_cmd: "dub build --compiler=gdc -c release-gdc --build=release",
    binary_name: "./target/release/d_benchmarks_gdc_release",
    run_cmd: "./target/release/d_benchmarks_gdc_release",
    version_cmd: "gdc --version | head -n 1",
    dir: "/src/d",
    container: "gdc",
    group: :prod,
    deps_cmd: "dub fetch",
  ),

  Run.new(
    name: "D/GDC/Perf",
    build_cmd: "dub build --compiler=gdc -c perf-gdc --build=release",
    binary_name: "./target/release/d_benchmarks_gdc_perf",
    run_cmd: "./target/release/d_benchmarks_gdc_perf",
    version_cmd: "gdc --version | head -n 1",
    dir: "/src/d",
    container: "gdc",
    group: :hack,
    deps_cmd: "dub fetch",
  ),

  Run.new(
    name: "D/GDC/MaxPerf",
    build_cmd: "dub build --compiler=gdc -c maxperf-gdc --build=release",
    binary_name: "./target/release/d_benchmarks_gdc_maxperf",
    run_cmd: "./target/release/d_benchmarks_gdc_maxperf",
    version_cmd: "gdc --version | head -n 1",
    dir: "/src/d",
    container: "gdc",
    group: :hack,
    deps_cmd: "dub fetch",
  ),

  # ======================================= V ======================================================

  # ==================== GCC BACKEND ====================
  # 1. GCC Release (стандартный прод)
  Run.new(
    name: "V/GCC", 
    build_cmd: "v -enable-globals -cc gcc -prod -o target/v_gcc .",
    binary_name: "./target/v_gcc",
    run_cmd: "./target/v_gcc", 
    version_cmd: "v version",
    dir: "/src/v",
    container: "v_gcc",
    group: :prod,
    deps_cmd: "v install",
  ),

  # 2. GCC Perf (оптимизации)
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
  # # 3. GCC MaxPerf (все оптимизации)
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
  # # 4. GCC Autofree (альтернативная память)
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

  # ==================== CLANG BACKEND ====================

  # 5. Clang Release (стандартный прод)
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

  # 6. Clang Perf (оптимизации)
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
  # # 7. Clang MaxPerf (все оптимизации)
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
  # # 8. Clang Autofree (альтернативная память)
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

  # ======================================= F# ======================================================
  # Базовый JIT (для разработки) - БЫСТРЫЙ СТАРТ, СРЕДНЯЯ ПРОИЗВОДИТЕЛЬНОСТЬ
  Run.new(
    name: "F#/JIT", 
    build_cmd: "dotnet build -c Release",
    binary_name: "./bin/Release/net10.0/MyFirstFSharpApp.dll",
    run_cmd: "dotnet ./bin/Release/net10.0/MyFirstFSharpApp.dll", 
    version_cmd: "dotnet --version",
    dir: "/src/fsharp",
    container: "fsharp",   
    group: :prod, 
    deps_cmd: "dotnet restore",
  ),

  # AOT Native (максимальная скорость выполнения) - ИСПРАВЛЕННЫЙ
  Run.new(
    name: "F#/AOT",
    build_cmd: "dotnet publish -c Release -p:PublishAOT=true -p:InvariantGlobalization=true -o ./bin/aot",
    binary_name: "./bin/aot/MyFirstFSharpApp",
    run_cmd: "./bin/aot/MyFirstFSharpApp", 
    version_cmd: "dotnet --version",
    dir: "/src/fsharp",
    container: "fsharp",
    group: :hack,        
    deps_cmd: "dotnet restore",
  ),

  # ======================================= Nim ======================================================

  # Nim/GCC - дефолтный релиз (стандартный прод) - ОДИН ИЗ 2 PROD
  Run.new(
    name: "Nim/GCC", 
    build_cmd: "nim c --threads:on -d:release --cc:gcc --opt:speed --out:target/bin_benchmarks_gcc src/benchmarks.nim",
    binary_name: "./target/bin_benchmarks_gcc",
    run_cmd: "./target/bin_benchmarks_gcc", 
    version_cmd: "nim --version | head -n 1",
    dir: "/src/nim",
    container: "nim_gcc",
    group: :prod,
    deps_cmd: "nimble refresh",
  ),

  # Nim/GCC с оптимизациями (аналог ENH)
  Run.new(
    name: "Nim/GCC/Perf", 
    build_cmd: "nim c --threads:on -d:release -d:danger --cc:gcc --opt:speed --passC:'-O3 -march=native' --passL:'-flto' --out:target/bin_benchmarks_gcc_perf src/benchmarks.nim",
    binary_name: "./target/bin_benchmarks_gcc_perf",
    run_cmd: "./target/bin_benchmarks_gcc_perf", 
    version_cmd: "nim --version | head -n 1",
    dir: "/src/nim",
    container: "nim_gcc",
    group: :hack,
    deps_cmd: "sh deps.sh",
  ),

  # Nim/GCC максимальные оптимизации (аналог MaxPerf)
  Run.new(
    name: "Nim/GCC/MaxPerf", 
    build_cmd: "nim c --threads:on -d:release -d:danger --cc:gcc --opt:speed --boundChecks:off --passC:'-Ofast -march=native' --passL:'-flto -static' --out:target/bin_benchmarks_gcc_max src/benchmarks.nim",
    binary_name: "./target/bin_benchmarks_gcc_max",
    run_cmd: "./target/bin_benchmarks_gcc_max", 
    version_cmd: "nim --version | head -n 1",
    dir: "/src/nim",
    container: "nim_gcc",
    group: :hack,
    deps_cmd: "sh deps.sh",
  ),

  # Nim/GCC прод сборка с ARC GC
  Run.new(
    name: "Nim/GCC/ARC", 
    build_cmd: "nim c --threads:on -d:release --cc:gcc --gc:arc --opt:speed --out:target/bin_benchmarks_gcc_arc src/benchmarks.nim",
    binary_name: "./target/bin_benchmarks_gcc_arc",
    run_cmd: "./target/bin_benchmarks_gcc_arc", 
    version_cmd: "nim --version | head -n 1",
    dir: "/src/nim",
    container: "nim_gcc",
    group: :hack,
    deps_cmd: "sh deps.sh",
  ),

  # Default is ORC?
  # # Nim/GCC прод сборка с ORC GC
  # Run.new(
  #   name: "Nim/GCC/ORC", 
  #   build_cmd: "nim c --threads:on -d:release --cc:gcc --gc:orc --opt:speed --out:target/bin_benchmarks_gcc_orc src/benchmarks.nim",
  #   binary_name: "./target/bin_benchmarks_gcc_orc",
  #   run_cmd: "./target/bin_benchmarks_gcc_orc", 
  #   version_cmd: "nim --version | head -n 1",
  #   dir: "/src/nim",
  #   container: "nim_gcc",
  #   group: :hack,
  #   deps_cmd: "sh deps.sh",
  # ),

  # Nim/Clang - дефолтный релиз (стандартный прод) - ВТОРОЙ ИЗ 2 PROD
  Run.new(
    name: "Nim/Clang", 
    build_cmd: "nim c --threads:on -d:release --cc:clang --opt:speed --out:target/bin_benchmarks_clang src/benchmarks.nim",
    binary_name: "./target/bin_benchmarks_clang",
    run_cmd: "./target/bin_benchmarks_clang", 
    version_cmd: "nim --version | head -n 1",
    dir: "/src/nim",
    container: "nim_clang",
    group: :prod,
    deps_cmd: "sh deps.sh",
  ),

  # Nim/Clang с оптимизации (аналог ENH)
  Run.new(
    name: "Nim/Clang/Perf", 
    build_cmd: "nim c --threads:on -d:release -d:danger --cc:clang --opt:speed --passC:'-O3 -march=native' --passL:'-flto=thin' --out:target/bin_benchmarks_clang_perf src/benchmarks.nim",
    binary_name: "./target/bin_benchmarks_clang_perf",
    run_cmd: "./target/bin_benchmarks_clang_perf", 
    version_cmd: "nim --version | head -n 1",
    dir: "/src/nim",
    container: "nim_clang",
    group: :hack,
    deps_cmd: "sh deps.sh",
  ),

  # Nim/Clang максимальные оптимизации (аналог MaxPerf)
  Run.new(
    name: "Nim/Clang/MaxPerf", 
    build_cmd: "nim c --threads:on -d:release -d:danger --cc:clang --opt:speed --boundChecks:off --passC:'-Ofast -march=native' --passL:'-flto=full -static' --out:target/bin_benchmarks_clang_max src/benchmarks.nim",
    binary_name: "./target/bin_benchmarks_clang_max",
    run_cmd: "./target/bin_benchmarks_clang_max", 
    version_cmd: "nim --version | head -n 1",
    dir: "/src/nim",
    container: "nim_clang",
    group: :hack,
    deps_cmd: "sh deps.sh",
  ),

  # Nim/Clang прод сборка с ARC GC
  Run.new(
    name: "Nim/Clang/ARC", 
    build_cmd: "nim c --threads:on -d:release --cc:clang --gc:arc --opt:speed --out:target/bin_benchmarks_clang_arc src/benchmarks.nim",
    binary_name: "./target/bin_benchmarks_clang_arc",
    run_cmd: "./target/bin_benchmarks_clang_arc", 
    version_cmd: "nim --version | head -n 1",
    dir: "/src/nim",
    container: "nim_clang",
    group: :hack,
    deps_cmd: "sh deps.sh",
  ),

  # Default is ORC?
  # # Nim/Clang прод сборка с ORC GC
  # Run.new(
  #   name: "Nim/Clang/ORC", 
  #   build_cmd: "nim c --threads:on -d:release --cc:clang --gc:orc --opt:speed --out:target/bin_benchmarks_clang_orc src/benchmarks.nim",
  #   binary_name: "./target/bin_benchmarks_clang_orc",
  #   run_cmd: "./target/bin_benchmarks_clang_orc", 
  #   version_cmd: "nim --version | head -n 1",
  #   dir: "/src/nim",
  #   container: "nim_clang",
  #   group: :hack,
  #   deps_cmd: "sh deps.sh",
  # ),

  # ======================================= Julia ======================================================
  
  # Julia - базовый (стандартные оптимизации)
  Run.new(
    name: "Julia/Default", 
    build_cmd: "true",  # Julia не требует сборки
    binary_name: "benchmark.jl",
    run_cmd: "julia --project=. --threads=16 benchmark.jl", 
    version_cmd: "julia --version | head -n 1",
    dir: "/src/julia",
    container: "julia",
    group: :prod,
    deps_cmd: "julia --project=. -e \"using Pkg; Pkg.instantiate()\"",
  ),
  
  # Julia с оптимизациями компиляции
  Run.new(
    name: "Julia/Opt", 
    build_cmd: "true",
    binary_name: "benchmark.jl",
    run_cmd: "julia --project=. --threads=16 -O3 --check-bounds=no benchmark.jl", 
    version_cmd: "julia --version | head -n 1",
    dir: "/src/julia",
    container: "julia",
    group: :hack,
    deps_cmd: "julia --project=. -e \"using Pkg; Pkg.instantiate()\"",
  ),
  
  # Julia с максимальными оптимизациями
  Run.new(
    name: "Julia/Max", 
    build_cmd: "true",
    binary_name: "benchmark.jl",
    run_cmd: "julia --project=. --threads=16 -O3 --check-bounds=no --math-mode=fast --inline=yes benchmark.jl", 
    version_cmd: "julia --version | head -n 1",
    dir: "/src/julia",
    container: "julia",
    group: :hack,
    deps_cmd: "julia --project=. -e \"using Pkg; Pkg.instantiate()\"",
  ),
  
  # Julia с PackageCompiler (системный образ)
  Run.new(
    name: "Julia/AOT", 
    build_cmd: <<~CMD.chomp,
      julia --project=. -e '
        using PackageCompiler;
        create_sysimage([:BenchmarkFramework];
            sysimage_path="target/sysimage.so",
            precompile_execution_file="./benchmark.jl")
        '
    CMD
    binary_name: "target/sysimage.so",
    run_cmd: "julia --project=. --sysimage=target/sysimage.so --threads=16 benchmark.jl", 
    version_cmd: "julia --version | head -n 1",
    dir: "/src/julia",
    container: "julia",
    group: :hack,
    deps_cmd: "mkdir -p target; julia --project=. -e \"using Pkg; Pkg.instantiate()\"",
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
  
  # Swift too slow, minimize configs
  # # WMO (лучшая безопасная оптимизация)
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
  
  # Swift too slow, minimize configs
  # # WMO + Unchecked (максимум без LLVM оптимизаций)
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
  # # MaxPerf (исправленный)
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
    group: :hack,
    deps_cmd: "mvn dependency:resolve; mvn dependency:resolve-plugins",
  ),

  # No effect
  # # Дополнительный вариант: GraalVM Native с максимальными оптимизациями
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
    group: :hack,
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
    group: :hack,
    deps_cmd: "./gradlew --no-daemon dependencies",
  ),

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
  # # Опционально: с разными уровнями оптимизаций
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

  # No effect
  # # TypeScript с максимальными оптимизациями (проверенные флаги)
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
  # # TypeScript с турбофан оптимизациями
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
    group: :hack,
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
    group: :hack,
    deps_cmd: "deno cache --quiet src/index.ts",
  ),

  # No effect
  # # Deno с оптимизациями V8
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
  # # Deno с максимальными оптимизациями V8
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
tests = JSON.parse(test_txt).keys
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
RESULTS["compile-memory-cold"] = {}
RESULTS["compile-memory-incremental"] = {}
RESULTS["compile-time-cold"] = {}
RESULTS["compile-time-incremental"] = {}
RESULTS["version"] = {}
RESULTS["start-duration"] = {}

def write_results
  unless ARGV[0]
    # write result on every step, because it can crash somewhere
    File.write("./results/#{RESULTS["date"]}-#{RESULTS["uname-name"]}.js", JSON.pretty_generate(RESULTS))  
  end
end

if IS_CLEAR_COMMENTS
  ClearComments.process_all_files(LANG_MASKS)
  exit
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
  stats = nil
  delta = measure do
    stats = run.run(run.build_cmd, verbose)
  end
  fsize_stats = run.run("sh -c 'du -k #{run.binary_name} | cut -f1'", verbose)
  RESULTS["binary-size-kb"][run.name] = fsize_stats[:out].split("\n").last.to_i
  RESULTS["build-cmd"][run.name] = run.build_cmd
  RESULTS["run-cmd"][run.name] = run.run_cmd
  RESULTS["compile-time-cold"][run.name] = delta.to_f  
  RESULTS["compile-memory-cold"][run.name] = stats[:rss] / 1024.0
  print " cold in #{delta.to_f.round(2)}s"
  
  if test_incremental && (marker_file = RECOMPILE_MARKER_FILES[run.lang])
    begin
      File.write(marker_file, File.read(marker_file).gsub(RECOMPILE_MARKER_0, RECOMPILE_MARKER_1))
      delta = measure do
        stats = run.run(run.build_cmd, verbose)
      end
      RESULTS["compile-time-incremental"][run.name] = delta.to_f  
      RESULTS["compile-memory-incremental"][run.name] = stats[:rss] / 1024.0
      print ", incremental in #{delta.round(2)}s"
    ensure
      File.write(marker_file, File.read(marker_file).gsub(RECOMPILE_MARKER_1, RECOMPILE_MARKER_0))
    end
  else
    print ", warning no marker for #{run.name}"
  end

  RESULTS["version"][run.name] = run.version  
  puts
  delta
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
  run.run(run.build_cmd, false) # build still neded because swift, java, kotlin, typescript all use same binary

  summary = 0.0
  memory = 0.0

  puts "Running #{run.name} (#{index} from #{RUNS.size})"
  TESTS.each_with_index do |test_name, index|
    print "#{index}. #{test_name}"
    RESULTS[test_name+"-runtime"] ||= {}
    RESULTS[test_name+"-mem-mb"] ||= {}
  
    stats = run.run("#{run.run_cmd} #{CFG} #{test_name}", IS_VERBOSE, true)
    mem = stats[:rss] / 1024.0
    memory += mem
    RESULTS[test_name+"-mem-mb"][run.name] = mem

    RESULTS[test_name+"-mem-mb"][run.name]

    RESULTS["start-duration"][run.name] ||= 0.0
    RESULTS["start-duration"][run.name] += stats[:start_duration]
    
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

p RESULTS["start-duration"]

RESULTS["start-duration"].each do |run, v|
  RESULTS["start-duration"][run] = v / TESTS.size # averaging
end

p RESULTS["start-duration"]

end_t = Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond)
puts "----------- FINISHED in #{((end_t - START_TIME).to_f / 1e9).round(2)}s-------------"
write_results
