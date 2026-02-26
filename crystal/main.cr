require "base64"
require "cryyjson"
require "json"
require "complex"
require "mut_gmp"

puts "start: #{Time.local.to_unix_ms}"
Benchmark.run(ARGV[1]?)

module Helper
  IM   = 139968
  IA   =   3877
  IC   =  29573
  INIT =     42

  def self.last
    @@last ||= INIT
  end

  def self.last=(x)
    @@last = x
  end

  def self.reset
    @@last = INIT
  end

  def self.next_int(max : Int)
    Helper.last = (Helper.last * IA + IC) % IM
    (Helper.last / IM.to_f64 * max).to_i32
  end

  def self.next_int(from : Int, to : Int)
    next_int(to - from + 1) + from
  end

  def self.next_float(max : Float64 = 1.0)
    Helper.last = (Helper.last * IA &+ IC) % IM
    max * Helper.last / IM.to_f64
  end

  def self.debug(&)
    {% unless flag?(:release) %}
      if ENV["DEBUG"]? == "1"
        puts yield
      end
    {% end %}
  end

  def self.checksum(v : String) : UInt32
    hash = 5381_u32
    v.each_byte do |byte|
      hash = ((hash << 5) &+ hash) &+ byte
    end
    hash
  end

  def self.checksum(v : Bytes) : UInt32
    hash = 5381_u32
    v.each do |byte|
      hash = ((hash << 5) &+ hash) &+ byte
    end
    hash
  end

  def self.checksum_f64(v : Float) : UInt32
    Helper.checksum("%.7f" % {v})
  end

  CONFIG = begin
    Hash(String, Hash(String, String | Int64)).from_json(File.read(ARGV[0]? || "../test.js"))
  end

  def self.config_i64(class_name, field_name) : Int64
    if cfg = CONFIG[class_name]?
      case i = cfg[field_name]?
      when Int64
        i
      else
        raise "Config for #{class_name}, not found i64 field: #{field_name} in #{cfg.inspect}"
      end
    else
      raise "Config not found class #{class_name}"
    end
  end

  def self.config_s(class_name, field_name) : String
    if cfg = CONFIG[class_name]?
      case s = cfg[field_name]?
      when String
        s
      else
        raise "Config for #{class_name}, not found string field: #{field_name} in #{cfg.inspect}"
      end
    else
      raise "Config not found class #{class_name}"
    end
  end
end

abstract class Benchmark
  abstract def run(iteration_id)
  abstract def checksum : UInt32

  def prepare
  end

  def warmup_iterations
    case wi = Helper::CONFIG["warmup_iterations"]?
    when Int64
      wi.to_i32
    else
      {(iterations * 0.2).to_i, 1}.max
    end
  end

  def warmup
    warmup_iterations.times { |i| self.run(i) }
  end

  def run_all
    iterations.times { |i| self.run(i) }
  end

  def config_val(field_name)
    Helper.config_i64(self.class.name.to_s, field_name)
  end

  def iterations
    config_val("iterations")
  end

  def expected_checksum
    config_val("checksum")
  end

  def self.run(single_bench : String? = nil)
    results = {} of String => Float64

    summary_time = 0.0
    ok = 0
    fails = 0
    single_bench = single_bench.downcase if single_bench

    {% for kl in @type.all_subclasses %}
      if (!single_bench || ({{kl.stringify}}.downcase.includes?(single_bench))) && ({{kl.stringify}} != "Sort::SortBenchmark") && ({{kl.stringify}} != "Hash::BufferHashBenchmark") && ({{kl.stringify}} != "Graph::GraphPathBenchmark")
        print "{{kl}}: "

        bench = {{kl.id}}.new

        Helper.reset
        bench.prepare
        bench.warmup
        GC.collect

        Helper.reset

        t = Time.instant
        bench.run_all
        time_delta = (Time.instant - t).to_f

        results["{{kl.id}}"] = time_delta

        GC.collect
        sleep 0.seconds
        GC.collect

        chks = bench.checksum
        if chks.to_i64 == bench.expected_checksum.to_i64
          print "OK "
          ok += 1
        else
          print "ERR[actual=#{chks.inspect}, expected=#{bench.expected_checksum.inspect}] "
          fails += 1
        end

        print "in %.3fs\n" % {time_delta}
        summary_time += time_delta
      end
    {% end %}

    File.open("/tmp/results.js", "w") { |f| results.to_json(f) }
    puts "Summary: %.4fs, %d, %d, %d" % {summary_time, ok + fails, ok, fails}
    exit 1 if fails > 0
  end
end

module Binarytrees
  class Obj < Benchmark
    class TreeNode
      property left : TreeNode?
      property right : TreeNode?
      property item : Int32

      def initialize(@item, depth = 0)
        if depth > 0
          self.left = TreeNode.new(@item - (2**(depth - 1)), depth - 1)
          self.right = TreeNode.new(@item + (2**(depth - 1)), depth - 1)
        end
      end

      def sum
        total = @item &+ 1
        if l = @left
          total &+= l.sum
        end
        if r = @right
          total &+= r.sum
        end
        total
      end
    end

    def initialize(@n : Int64 = config_val("depth"))
      @result = 0_u32
    end

    def run(iteration_id)
      node = TreeNode.new(0, @n)
      @result &+= node.sum
    end

    def checksum : UInt32
      @result
    end
  end

  class Arena < Benchmark
    record TreeNode, item : Int32, left : Int32 = -1, right : Int32 = -1

    def build_tree(item, depth)
      idx = @arena.size
      @arena << TreeNode.new(item, -1, -1)

      if depth > 0
        left_idx = build_tree(item - (2**(depth - 1)), depth - 1)
        right_idx = build_tree(item + (2**(depth - 1)), depth - 1)
        @arena[idx] = TreeNode.new(item, left_idx, right_idx)
      end

      idx
    end

    def sum(idx)
      node = @arena[idx]
      total = node.item &+ 1
      total &+= sum(node.left) if node.left >= 0
      total &+= sum(node.right) if node.right >= 0
      total
    end

    def initialize(@n : Int64 = config_val("depth"))
      @result = 0_u32
      @arena = Array(TreeNode).new
    end

    def run(iteration_id)
      @arena = Array(TreeNode).new
      build_tree(0, @n)
      @result &+= sum(0)
    end

    def checksum : UInt32
      @result
    end
  end
end

module Brainfuck
  class Array < Benchmark
    @program_text : String
    @warmup_text : String
    @result_val = 0u32

    def initialize
      @program_text = Helper.config_s(self.class.name.to_s, "program")
      @warmup_text = Helper.config_s(self.class.name.to_s, "warmup_program")
    end

    def warmup
      prepare_iters = warmup_iterations
      prepare_iters.times do
        run_program(@warmup_text)
      end
    end

    def run(iteration_id)
      if result = run_program(@program_text)
        @result_val &+= result.to_u32
      end
    end

    def checksum : UInt32
      @result_val
    end

    private def run_program(source : String) : UInt32?
      commands = parse_commands(source)
      return nil unless commands

      jumps = build_jump_array(commands)
      return nil unless jumps

      _run(commands, jumps)
    end

    private def parse_commands(source : String) : ::Array(Char)?
      source.chars
        .select(&.ascii?)
        .select { |c| "+-<>[].,".includes?(c) }
        .to_a
    end

    private def build_jump_array(commands : ::Array(Char)) : ::Array(Int32)?
      jumps = ::Array.new(commands.size, 0)
      stack = [] of Int32

      commands.each_with_index do |cmd, i|
        case cmd
        when '['
          stack << i
        when ']'
          start = stack.pop?
          return nil unless start
          jumps[start] = i
          jumps[i] = start
        end
      end

      stack.empty? ? jumps : nil
    end

    struct Tape
      getter tape = ::Array(UInt8).new(30000, 0_u8)
      property pos = 0

      def get
        @tape[@pos]
      end

      def inc
        @tape[@pos] &+= 1
      end

      def dec
        @tape[@pos] &-= 1
      end

      def adv
        @pos += 1
        @tape << 0 if @pos >= @tape.size
      end

      def dev
        @pos -= 1
        @pos = 0 if @pos < 0
      end
    end

    private def _run(commands : ::Array(Char), jumps : ::Array(Int32)) : UInt32?
      tape = Tape.new
      pc = 0
      result = 0_u32

      while pc < commands.size
        case commands[pc]
        when '+'; tape.inc
        when '-'; tape.dec
        when '>'; tape.adv
        when '<'; tape.dev
        when '['
          if tape.get == 0
            pc = jumps[pc]
            next
          end
        when ']'
          if tape.get != 0
            pc = jumps[pc]
            next
          end
        when '.'
          result <<= 2
          result &+= tape.get
        end
        pc += 1
      end
      result
    rescue
      nil
    end
  end

  class Recursion < Benchmark
    record Inc
    record Dec
    record Advance
    record Devance
    record Print
    alias Op = Inc | Dec | Advance | Devance | Print | ::Array(Op)

    struct Tape
      def initialize
        @tape = ::Array(UInt8).new(30000, 0_u8)
        @pos = 0
      end

      def get : UInt8
        @tape[@pos]
      end

      def inc
        @tape[@pos] &+= 1
      end

      def dec
        @tape[@pos] &-= 1
      end

      def advance
        @pos += 1
        if @pos >= @tape.size
          @tape << 0_u8
        end
      end

      def devance
        if @pos > 0
          @pos -= 1
        end
      end
    end

    class Program
      @ops : ::Array(Op)
      @result : Int64

      def initialize(code : String)
        it = code.each_char
        @ops = parse(it)
        @result = 0_i64
      end

      def result
        @result
      end

      def run
        tape = Tape.new
        run_ops(@ops, tape)
      end

      def run_ops(ops : ::Array(Op), tape)
        ops.each do |op|
          case op
          when Inc
            tape.inc
          when Dec
            tape.dec
          when Advance
            tape.advance
          when Devance
            tape.devance
          when Print
            @result = (@result << 2) + tape.get
          when ::Array(Op)
            while tape.get != 0
              run_ops(op, tape)
            end
          end
        end
      end

      private def parse(it : Iterator(Char))
        ops = [] of Op
        it.each do |c|
          case c
          when '+'; ops << Inc.new
          when '-'; ops << Dec.new
          when '>'; ops << Advance.new
          when '<'; ops << Devance.new
          when '.'; ops << Print.new
          when '['; ops << parse(it)
          when ']'; break
          end
        end
        ops
      end
    end

    @text : String
    @result : UInt32

    def initialize
      @text = Helper.config_s("Brainfuck::Recursion", "program")
      @result = 0_u32
    end

    def warmup
      warmup_iterations.times do
        run_text(Helper.config_s("Brainfuck::Recursion", "warmup_program"))
      end
    end

    private def run_text(text : String)
      prog = Program.new(text)
      prog.run
      prog.result
    end

    def run(iteration_id)
      @result &+= run_text(@text).to_u32!
    end

    def checksum : UInt32
      @result
    end
  end
end

module Matmul
  def self.matgen(n, seed = 1.0)
    tmp = seed / n / n
    Array.new(n) { |i| Array.new(n) { |j| tmp * (i - j) * (i + j) } }
  end

  class Single < Benchmark
    def matmul(n, a, b)
      t = Array.new(n) { Array.new(n, 0.0) }
      (0...n).each do |i|
        (0...n).each do |j|
          t[j][i] = b[i][j]
        end
      end

      c = Array.new(n) { Array.new(n, 0.0) }

      c.each_with_index do |ci, i|
        ai = a[i]
        t.each_with_index do |tj, j|
          s = 0.0
          ai.zip(tj) do |av, tv|
            s += av * tv
          end
          ci[j] = s
        end
      end
      c
    end

    @a : Array(Array(Float64))
    @b : Array(Array(Float64))

    def initialize(@n : Int64 = config_val("n"))
      @result = 0_u32
      @a = Matmul.matgen(@n, 1.0)
      @b = Matmul.matgen(@n, 1.0)
    end

    def run(iteration_id)
      c = matmul(@n, @a, @b)
      v = c[@n >> 1][@n >> 1]
      @result &+= Helper.checksum_f64(v)
    end

    def checksum : UInt32
      @result
    end
  end

  class T4 < Single
    def matmul_parallel(n, threads, a, b)
      t = Array.new(n) { Array.new(n, 0.0) }
      n.times do |i|
        n.times do |j|
          t[j][i] = b[i][j]
        end
      end

      c = Array.new(n) { Array.new(n, 0.0) }
      channel = Channel(Nil).new
      rows_per_worker = (n + threads - 1) // threads

      threads.times do |worker_id|
        spawn do
          start_row = worker_id * rows_per_worker
          end_row = Math.min(start_row + rows_per_worker, n)

          (start_row...end_row).each do |i|
            ai = a[i]
            ci = c[i]

            t.each_with_index do |tj, j|
              s = 0.0
              ai.zip(tj) { |av, tv| s += av * tv }
              ci[j] = s
            end
          end

          channel.send(nil)
        end
      end

      threads.times { channel.receive }
      c
    end

    def num_threads
      4
    end

    def run(iteration_id)
      c = matmul_parallel(@n, num_threads, @a, @b)
      v = c[@n >> 1][@n >> 1]
      @result &+= Helper.checksum_f64(v)
    end
  end

  class T8 < T4
    def num_threads
      8
    end
  end

  class T16 < T4
    def num_threads
      16
    end
  end
end

module Base64
  class Encode < Benchmark
    @str : String
    @str2 : String

    def initialize(@n : Int64 = config_val("size"))
      @str = ""
      @str2 = ""
      @result = 0_u32
    end

    def prepare
      @str = "a" * @n
      @str2 = Base64.strict_encode(@str)
    end

    def run(iteration_id)
      @str2 = Base64.strict_encode(@str)
      @result &+= @str2.bytesize
    end

    def checksum : UInt32
      Helper.checksum("encode #{@str[0..3]}... to #{@str2[0..3]}...: #{@result}")
    end
  end

  class Decode < Benchmark
    @str2 : String
    @str3 : String

    def initialize(@n : Int64 = config_val("size"))
      @str2 = ""
      @str3 = ""
      @result = 0_u32
    end

    def prepare
      str = "a" * @n
      @str2 = Base64.strict_encode(str)
      @str3 = Base64.decode_string(@str2)
    end

    def run(iteration_id)
      @str3 = Base64.decode_string(@str2)
      @result &+= @str3.bytesize
    end

    def checksum : UInt32
      Helper.checksum "decode #{@str2[0..3]}... to #{@str3[0..3]}...: #{@result}"
    end
  end
end

module Json
  class Generate < Benchmark
    struct Coordinate
      include JSON::Serializable

      def initialize(@x : Float64, @y : Float64, @z : Float64, @name : String, @opts : Hash(String, Tuple(Int32, Bool)))
      end
    end

    def initialize(@n : Int64 = config_val("coords"))
      @text = IO::Memory.new
      @data = Array(Coordinate).new
      @n.times do
        @data << Coordinate.new(
          Helper.next_float.round(8),
          Helper.next_float.round(8),
          Helper.next_float.round(8),
          "%.7f %d" % {Helper.next_float, Helper.next_int(10_000)},
          {"1" => {1, true}},
        )
      end
      @result = 0_u32
    end

    def run(iteration_id)
      @text.rewind
      {"coordinates": @data,
       "info":        "some info"}.to_json(@text)
      if @text.to_slice[0..14] == Bytes[123, 34, 99, 111, 111, 114, 100, 105, 110, 97, 116, 101, 115, 34, 58]
        @result += 1
      end
      true
    end

    getter text

    def checksum : UInt32
      @result
    end
  end

  class ParseDom < Benchmark
    def calc(text)
      jobj = Cryyjson.parse(text)
      coordinates = jobj["coordinates"].as_a
      len = coordinates.size.to_f
      x = y = z = 0.0

      coordinates.each do |coord|
        x += coord["x"].as_f
        y += coord["y"].as_f
        z += coord["z"].as_f
      end

      {x / len, y / len, z / len}
    end

    @text : String

    def initialize
      @text = ""
      @result = 0_u32
    end

    def prepare
      j = Generate.new(config_val("coords"))
      j.run(0)
      @text = j.text.to_s
    end

    def run(iteration_id)
      x, y, z = calc(@text)
      @result &+= Helper.checksum_f64(x) &+ Helper.checksum_f64(y) &+ Helper.checksum_f64(z)
    end

    def checksum : UInt32
      @result
    end
  end

  class ParseMapping < Benchmark
    struct Coordinate
      include JSON::Serializable

      property x : Float64
      property y : Float64
      property z : Float64

      def initialize(@x, @y, @z)
      end
    end

    class Coordinates
      include JSON::Serializable
      property coordinates : Array(Coordinate)
    end

    def calc(text)
      coordinates = Coordinates.from_json(text).coordinates
      len = coordinates.size.to_f
      x = y = z = 0.0

      coordinates.each do |e|
        x += e.x
        y += e.y
        z += e.z
      end

      Coordinate.new(x / len, y / len, z / len)
    end

    @text : String

    def initialize
      @text = ""
      @result = 0_u32
    end

    def prepare
      j = Generate.new(config_val("coords"))
      j.run(0)
      @text = j.text.to_s
    end

    def run(iteration_id)
      coord = calc(@text)
      @result &+= Helper.checksum_f64(coord.x) &+ Helper.checksum_f64(coord.y) &+ Helper.checksum_f64(coord.z)
    end

    def checksum : UInt32
      @result
    end
  end
end

module Etc
  class Primes < Benchmark
    class Node
      property children : Array(Node | Nil)
      property terminal : Bool

      def initialize
        @children = Array(Node | Nil).new(10, nil)
        @terminal = false
      end

      def [](digit : Int) : Node | Nil
        @children[digit]
      end

      def []=(digit : Int, node : Node)
        @children[digit] = node
      end
    end

    class Sieve
      @limit : Int32
      @prime : Array(Bool)

      def initialize(@limit : Int32)
        @prime = Array.new(@limit + 1, true)
        @prime[0] = @prime[1] = false if @limit >= 1
      end

      def calculate : self
        sqrt_limit = Math.sqrt(@limit).to_i

        (2..sqrt_limit).each do |p|
          if @prime[p]
            start = p * p
            (start..@limit).step(p) do |multiple|
              @prime[multiple] = false
            end
          end
        end
        self
      end

      def to_list : Array(Int32)
        capacity = (@limit / Math.log(@limit)).to_i rescue @limit // 10
        result = Array(Int32).new(capacity)

        result << 2 if @limit >= 2

        3.step(to: @limit, by: 2) do |p|
          result << p if @prime[p]
        end

        result
      end
    end

    private def generate_trie(primes : Array(Int32)) : Node
      root = Node.new

      primes.each do |prime|
        node = root

        temp = prime
        digits = uninitialized Int8[12]
        digit_count = 0

        while temp > 0
          digits[digit_count] = (temp % 10).to_i8
          temp //= 10
          digit_count += 1
        end

        (digit_count - 1).downto(0) do |i|
          digit = digits[i]
          child = node[digit]

          unless child
            child = Node.new
            node[digit] = child
          end

          node = child.as(Node)
        end

        node.terminal = true
      end

      root
    end

    private def find_primes_with_prefix(trie : Node, prefix : Int32) : Array(Int32)
      node = trie
      prefix_value = 0
      temp_prefix = prefix

      prefix_digits = uninitialized Int8[12]
      prefix_len = 0

      while temp_prefix > 0
        prefix_digits[prefix_len] = (temp_prefix % 10).to_i8
        temp_prefix //= 10
        prefix_len += 1
      end

      (prefix_len - 1).downto(0) do |i|
        digit = prefix_digits[i]
        prefix_value = prefix_value * 10 + digit

        child = node[digit]
        return [] of Int32 unless child
        node = child.as(Node)
      end

      results = [] of Int32

      queue = Array(Tuple(Node, Int32)).new(10000)
      queue.push({node, prefix_value})

      index = 0
      while index < queue.size
        current_node, current_number = queue[index]
        index += 1

        results << current_number if current_node.terminal

        10.times do |digit|
          child = current_node[digit]
          if child
            queue.push({child.as(Node), current_number * 10 + digit})
          end
        end
      end

      results.sort!
      results
    end

    def initialize
      @n = config_val("limit")
      @result = 5432_u32
      @prefix = config_val("prefix")
    end

    def run(iteration_id)
      primes = Sieve.new(@n.to_i32).calculate.to_list

      trie = generate_trie(primes)

      results = find_primes_with_prefix(trie, @prefix.to_i32)

      @result &+= results.size.to_u32
      results.each do |prime|
        @result &+= prime.to_u32
      end
    end

    getter n : Int64
    getter prefix : Int64

    def checksum : UInt32
      @result
    end
  end

  class Noise < Benchmark
    record Vec2, x : Float64, y : Float64

    def self.lerp(a, b, v)
      a * (1.0 - v) + b * v
    end

    def self.smooth(v)
      v * v * (3.0 - 2.0 * v)
    end

    def self.random_gradient
      v = Helper.next_float * Math::PI * 2.0
      Vec2.new(Math.cos(v), Math.sin(v))
    end

    def self.gradient(orig, grad, p)
      sp = Vec2.new(p.x - orig.x, p.y - orig.y)
      grad.x * sp.x + grad.y * sp.y
    end

    struct Noise2DContext
      def initialize(@size : Int32)
        @rgradients = Array(Vec2).new(@size) { Noise.random_gradient }
        @permutations = Array(Int32).new(@size) { |i| i }
        @size.times do
          a = Helper.next_int(@size)
          b = Helper.next_int(@size)
          @permutations.swap a, b
        end
      end

      def get_gradient(x, y)
        idx = @permutations[x & (@size - 1)] + @permutations[y & (@size - 1)]
        @rgradients[idx & (@size - 1)]
      end

      def get_gradients(x, y)
        x0f = x.floor
        y0f = y.floor
        x0 = x0f.to_i
        y0 = y0f.to_i
        x1 = x0 + 1
        y1 = y0 + 1

        {
          {
            get_gradient(x0, y0),
            get_gradient(x1, y0),
            get_gradient(x0, y1),
            get_gradient(x1, y1),
          },
          {
            Vec2.new(x0f + 0.0, y0f + 0.0),
            Vec2.new(x0f + 1.0, y0f + 0.0),
            Vec2.new(x0f + 0.0, y0f + 1.0),
            Vec2.new(x0f + 1.0, y0f + 1.0),
          },
        }
      end

      def get(x, y)
        p = Vec2.new(x, y)
        gradients, origins = get_gradients(x, y)
        v0 = Noise.gradient(origins[0], gradients[0], p)
        v1 = Noise.gradient(origins[1], gradients[1], p)
        v2 = Noise.gradient(origins[2], gradients[2], p)
        v3 = Noise.gradient(origins[3], gradients[3], p)
        fx = Noise.smooth(x - origins[0].x)
        vx0 = Noise.lerp(v0, v1, fx)
        vx1 = Noise.lerp(v2, v3, fx)
        fy = Noise.smooth(y - origins[0].y)
        Noise.lerp(vx0, vx1, fy)
      end
    end

    SYM = [' ', '░', '▒', '▓', '█', '█']

    @size : Int64

    def initialize
      @result = 0_u32
      @size = config_val("size")
      @n2d = Noise2DContext.new(@size.to_i32)
    end

    def run(iteration_id)
      @size.times do |y|
        @size.times do |x|
          v = @n2d.get(x * 0.1, (y + (iteration_id * 128)) * 0.1) * 0.5 + 0.5
          @result &+= SYM[(v / 0.2).to_i].ord
        end
      end
    end

    def checksum : UInt32
      @result
    end
  end

  class TextRaytracer < Benchmark
    record Vector, x : Float64, y : Float64, z : Float64 do
      def scale(s)
        Vector.new(x * s, y * s, z * s)
      end

      def +(other)
        Vector.new(x + other.x, y + other.y, z + other.z)
      end

      def -(other)
        Vector.new(x - other.x, y - other.y, z - other.z)
      end

      def dot(other)
        x*other.x + y*other.y + z*other.z
      end

      def magnitude
        Math.sqrt self.dot(self)
      end

      def normalize
        scale(1.0 / magnitude)
      end
    end

    record Ray, orig : Vector, dir : Vector

    record Color, r : Float64, g : Float64, b : Float64 do
      def scale(s)
        Color.new(r * s, g * s, b * s)
      end

      def +(other)
        Color.new(r + other.r, g + other.g, b + other.b)
      end
    end

    record Sphere, center : Vector, radius : Float64, color : Color do
      def get_normal(pt)
        (pt - center).normalize
      end
    end

    record Light, position : Vector, color : Color

    record Hit, obj : Sphere, value : Float64

    WHITE = Color.new(1.0, 1.0, 1.0)
    RED   = Color.new(1.0, 0.0, 0.0)
    GREEN = Color.new(0.0, 1.0, 0.0)
    BLUE  = Color.new(0.0, 0.0, 1.0)

    LIGHT1 = Light.new(Vector.new(0.7, -1.0, 1.7), WHITE)

    def shade_pixel(ray, obj, tval)
      pi = ray.orig + ray.dir.scale(tval)
      color = diffuse_shading pi, obj, LIGHT1
      col = (color.r + color.g + color.b) / 3.0
      (col * 6.0).to_i
    end

    def intersect_sphere(ray, center, radius)
      l = center - ray.orig
      tca = l.dot(ray.dir)
      if tca < 0.0
        return nil
      end

      d2 = l.dot(l) - tca*tca
      r2 = radius*radius
      if d2 > r2
        return nil
      end

      thc = Math.sqrt(r2 - d2)
      t0 = tca - thc

      if t0 > 10_000
        return nil
      end

      t0
    end

    def clamp(x, a, b)
      return a if x < a
      return b if x > b
      x
    end

    def diffuse_shading(pi, obj, light)
      n = obj.get_normal(pi)
      lam1 = (light.position - pi).normalize.dot(n)
      lam2 = clamp lam1, 0.0, 1.0
      light.color.scale(lam2*0.5) + obj.color.scale(0.3)
    end

    LUT = ['.', '-', '+', '*', 'X', 'M']

    SCENE = [
      Sphere.new(Vector.new(-1.0, 0.0, 3.0), 0.3, RED),
      Sphere.new(Vector.new(0.0, 0.0, 3.0), 0.8, GREEN),
      Sphere.new(Vector.new(1.0, 0.0, 3.0), 0.4, BLUE),
    ]

    def initialize(@w : Int32 = config_val("w").to_i32, @h : Int32 = config_val("h").to_i32)
      @res = 0_u32
    end

    def run(iteration_id)
      res = 0_u64
      (0...@h).each do |j|
        (0...@w).each do |i|
          fw, fi, fj, fh = @w.to_f, i.to_f, j.to_f, @h.to_f

          ray = Ray.new(
            Vector.new(0.0, 0.0, 0.0),
            Vector.new((fi - fw/2.0)/fw, (fj - fh/2.0)/fh, 1.0).normalize
          )

          hit = nil

          SCENE.each do |obj|
            ret = intersect_sphere(ray, obj.center, obj.radius)
            if ret
              hit = Hit.new obj, ret

              break
            end
          end

          if hit
            pixel = LUT[shade_pixel(ray, hit.obj, hit.value)]
          else
            pixel = ' '
          end

          res &+= pixel.ord
        end
      end
      @res &+= res
    end

    def checksum : UInt32
      @res
    end
  end

  class NeuralNet < Benchmark
    class Synapse
      property weight : Float64
      property prev_weight : Float64
      property :source_neuron
      property :dest_neuron

      def initialize(@source_neuron : Neuron, @dest_neuron : Neuron)
        @prev_weight = @weight = Helper.next_float * 2 - 1
      end
    end

    class Neuron
      LEARNING_RATE = 1.0
      MOMENTUM      = 0.3

      property :synapses_in
      property :synapses_out
      property threshold : Float64
      property prev_threshold : Float64
      property :error
      property :output

      def initialize
        @prev_threshold = @threshold = Helper.next_float * 2 - 1
        @synapses_in = [] of Synapse
        @synapses_out = [] of Synapse
        @output = 0.0
        @error = 0.0
      end

      def calculate_output
        activation = synapses_in.reduce(0.0) do |sum, synapse|
          sum + synapse.weight * synapse.source_neuron.output
        end
        activation -= threshold

        @output = 1.0 / (1.0 + Math.exp(-activation))
      end

      def derivative
        output * (1 - output)
      end

      def output_train(rate, target)
        @error = (target - output) * derivative
        update_weights(rate)
      end

      def hidden_train(rate)
        @error = synapses_out.reduce(0.0) do |sum, synapse|
          sum + synapse.prev_weight * synapse.dest_neuron.error
        end * derivative
        update_weights(rate)
      end

      def update_weights(rate)
        synapses_in.each do |synapse|
          temp_weight = synapse.weight
          synapse.weight += (rate * LEARNING_RATE * error * synapse.source_neuron.output) + (MOMENTUM * (synapse.weight - synapse.prev_weight))
          synapse.prev_weight = temp_weight
        end
        temp_threshold = threshold
        @threshold += (rate * LEARNING_RATE * error * -1) + (MOMENTUM * (threshold - prev_threshold))
        @prev_threshold = temp_threshold
      end
    end

    class NeuralNetwork
      @input_layer : Array(Neuron)
      @hidden_layer : Array(Neuron)
      @output_layer : Array(Neuron)

      def initialize(inputs, hidden, outputs)
        @input_layer = (1..inputs).map { Neuron.new }
        @hidden_layer = (1..hidden).map { Neuron.new }
        @output_layer = (1..outputs).map { Neuron.new }

        @input_layer.each_cartesian(@hidden_layer) do |source, dest|
          synapse = Synapse.new(source, dest)
          source.synapses_out << synapse
          dest.synapses_in << synapse
        end
        @hidden_layer.each_cartesian(@output_layer) do |source, dest|
          synapse = Synapse.new(source, dest)
          source.synapses_out << synapse
          dest.synapses_in << synapse
        end
      end

      def train(inputs, targets)
        feed_forward(inputs)

        @output_layer.zip(targets) do |neuron, target|
          neuron.output_train(0.3, target)
        end
        @hidden_layer.each do |neuron|
          neuron.hidden_train(0.3)
        end
      end

      def feed_forward(inputs)
        @input_layer.zip(inputs) do |neuron, input|
          neuron.output = input.to_f64
        end
        @hidden_layer.each do |neuron|
          neuron.calculate_output if neuron
        end
        @output_layer.each do |neuron|
          neuron.calculate_output if neuron
        end
      end

      def current_outputs : Array(Float64)
        @output_layer.map do |neuron|
          neuron.output
        end
      end
    end

    def initialize
      @res = [] of Float64
      @xor = NeuralNetwork.new(0, 0, 0)
    end

    def prepare
      @xor = NeuralNetwork.new(2, 10, 1)
    end

    def run(iteration_id)
      xor = @xor
      xor.train([0, 0], [0])
      xor.train([1, 0], [1])
      xor.train([0, 1], [1])
      xor.train([1, 1], [0])
    end

    def checksum : UInt32
      @xor.feed_forward([0, 0])
      @res += @xor.current_outputs
      @xor.feed_forward([0, 1])
      @res += @xor.current_outputs
      @xor.feed_forward([1, 0])
      @res += @xor.current_outputs
      @xor.feed_forward([1, 1])
      @res += @xor.current_outputs
      Helper.checksum_f64(@res.sum)
    end
  end

  class CacheSimulation < Benchmark
    class LRUCache(K, V)
      private class Node(K, V)
        property key : K
        property value : V
        property prev : Node(K, V) | Nil
        property next : Node(K, V) | Nil

        def initialize(@key, @value, @prev = nil, @next = nil)
        end
      end

      @capacity : Int32
      @cache = {} of K => Node(K, V)
      @head : Node(K, V) | Nil = nil
      @tail : Node(K, V) | Nil = nil
      @size = 0

      def initialize(@capacity)
      end

      def get(key : K) : V?
        node = @cache[key]?
        return unless node

        move_to_front(node)
        node.value
      end

      def put(key : K, value : V)
        if node = @cache[key]?
          node.value = value
          move_to_front(node)
          return
        end

        if @size >= @capacity
          remove_oldest
        end

        node = Node(K, V).new(key, value)

        @cache[key] = node

        add_to_front(node)

        @size += 1
      end

      def size
        @size
      end

      private def move_to_front(node : Node(K, V))
        return if node == @head

        if node.prev
          node.prev.try &.next = node.next
        end
        if node.next
          node.next.try &.prev = node.prev
        end

        if node == @tail
          @tail = node.prev
        end

        node.prev = nil
        node.next = @head
        @head.try &.prev = node
        @head = node

        @tail = node unless @tail
      end

      private def add_to_front(node : Node(K, V))
        node.next = @head
        @head.try &.prev = node
        @head = node
        @tail = node unless @tail
      end

      private def remove_oldest
        return unless @tail

        oldest = @tail.as(Node(K, V))

        @cache.delete(oldest.key)

        if oldest.prev
          oldest.prev.try &.next = nil
        end
        @tail = oldest.prev

        @head = nil if @head == oldest

        @size -= 1
      end
    end

    @values_size : Int32

    def initialize
      @result = 5432_u32
      @values_size = config_val("values").to_i32
      @cache = LRUCache(String, String).new(config_val("size").to_i32)
      @hits = 0
      @misses = 0
    end

    def run(iteration_id)
      1000.times do
        key = "item_#{Helper.next_int(@values_size)}"
        if @cache.get(key)
          @hits += 1
          @cache.put(key, "updated_#{iteration_id}")
        else
          @misses += 1
          @cache.put(key, "new_#{iteration_id}")
        end
      end
    end

    def checksum : UInt32
      @result = (@result << 5) &+ @hits
      @result = (@result << 5) &+ @misses
      @result = (@result << 5) &+ @cache.size
      @result
    end
  end

  class GameOfLife < Benchmark
    class Cell
      property alive : Bool
      property neighbors : Array(Cell)
      @next_state : Bool

      def initialize(@alive = false)
        @neighbors = [] of Cell
        @next_state = false
      end

      def add_neighbor(cell : Cell)
        @neighbors << cell
      end

      def compute_next_state
        alive_neighbors = @neighbors.count(&.alive)

        @next_state = if @alive
                        alive_neighbors == 2 || alive_neighbors == 3
                      else
                        alive_neighbors == 3
                      end
      end

      def update
        @alive = @next_state
      end
    end

    class Grid
      getter width : Int32
      getter height : Int32
      getter cells : Array(Array(Cell))

      def initialize(@width : Int32, @height : Int32)
        @cells = Array.new(@height) { Array.new(@width) { Cell.new } }
        link_neighbors
      end

      private def link_neighbors
        @cells.each_with_index do |column, y|
          column.each_with_index do |cell, x|
            (-1..1).each do |dy|
              (-1..1).each do |dx|
                next if dx == 0 && dy == 0

                ny = (y + dy + @height) % @height
                nx = (x + dx + @width) % @width

                cell.add_neighbor(@cells[ny][nx])
              end
            end
          end
        end
      end

      def next_generation
        @cells.each &.each &.compute_next_state
        @cells.each &.each &.update
      end

      def count_alive : Int32
        count = 0
        cells.each &.each { |cell| count += 1 if cell.alive }
        count
      end

      def compute_hash : UInt32
        _FNV_OFFSET_BASIS = 2166136261_u32
        _FNV_PRIME = 16777619_u32
        hash = _FNV_OFFSET_BASIS

        cells.each &.each do |cell|
          alive = cell.alive ? 1_u32 : 0_u32
          hash = (hash ^ alive) &* _FNV_PRIME
        end

        hash
      end
    end

    @width : Int32
    @height : Int32
    @grid : Grid

    def initialize
      @width = config_val("w").to_i32
      @height = config_val("h").to_i32
      @grid = Grid.new(@width, @height)
    end

    def name : String
      "Etc::GameOfLife"
    end

    def prepare
      @grid.cells.each &.each { |cell| cell.alive = true if Helper.next_float(1.0) < 0.1 }
    end

    def run(iteration_id)
      @grid.next_generation
    end

    def checksum : UInt32
      @grid.compute_hash + @grid.count_alive.to_u32
    end
  end
end

module Sort
  class SortBenchmark < Benchmark
    @data : Array(Int32)

    def test : Array(Int32)
      Array(Int32).new
    end

    def initialize(@size : Int64 = config_val("size"))
      @result = 0_u32
      @data = Array(Int32).new
    end

    def prepare
      @size.times { @data << Helper.next_int(1_000_000) }
    end

    def run(iteration_id)
      @result &+= @data[Helper.next_int(@size)]
      t = test
      @result &+= t[Helper.next_int(@size)]
    end

    def checksum : UInt32
      @result
    end
  end

  class Quick < SortBenchmark
    def test : Array(Int32)
      arr = @data.dup
      quick_sort(arr, 0, arr.size - 1)
      arr
    end

    private def quick_sort(arr, low, high)
      return if low >= high

      pivot = arr[(low + high) // 2]
      i, j = low, high

      while i <= j
        while arr[i] < pivot
          i += 1
        end
        while arr[j] > pivot
          j -= 1
        end
        if i <= j
          arr[i], arr[j] = arr[j], arr[i]
          i += 1
          j -= 1
        end
      end

      quick_sort(arr, low, j)
      quick_sort(arr, i, high)
    end
  end

  class Merge < SortBenchmark
    def test : Array(Int32)
      arr = @data.dup
      merge_sort_inplace(arr)
      arr
    end

    private def merge_sort_inplace(arr : Array(Int32))
      temp = Array(Int32).new(arr.size, 0)
      merge_sort_helper(arr, temp, 0, arr.size - 1)
    end

    private def merge_sort_helper(arr, temp, left, right)
      return if left >= right

      mid = (left + right) // 2
      merge_sort_helper(arr, temp, left, mid)
      merge_sort_helper(arr, temp, mid + 1, right)
      merge(arr, temp, left, mid, right)
    end

    private def merge(arr, temp, left, mid, right)
      (left..right).each do |i|
        temp[i] = arr[i]
      end

      i = left
      j = mid + 1
      k = left

      while i <= mid && j <= right
        if temp[i] <= temp[j]
          arr[k] = temp[i]
          i += 1
        else
          arr[k] = temp[j]
          j += 1
        end
        k += 1
      end

      while i <= mid
        arr[k] = temp[i]
        i += 1
        k += 1
      end
    end
  end

  class Self < SortBenchmark
    def test : Array(Int32)
      arr = @data.dup
      arr.sort!
      arr
    end
  end
end

module Graph
  class GraphPathBenchmark < Benchmark
    class Graph
      property vertices : Int32
      property jumps : Int32
      property jump_len : Int32
      property adj : Array(Array(Int32))

      def initialize(@vertices : Int32, @jumps : Int32 = 3, @jump_len : Int32 = 100)
        @adj = Array.new(@vertices) { [] of Int32 }
      end

      def add_edge(u, v)
        @adj[u] << v
        @adj[v] << u
      end

      def generate_random
        (1...@vertices).each do |i|
          add_edge(i, i - 1)
        end

        @vertices.times do |v|
          Helper.next_int(@jumps).times do
            offset = Helper.next_int(@jump_len) - @jump_len // 2
            u = v + offset

            if u >= 0 && u < @vertices && u != v
              add_edge(v, u)
            end
          end
        end
      end
    end

    @graph : Graph
    @result = 0_u32

    def initialize
      vertices = config_val("vertices").to_i32
      jumps = config_val("jumps").to_i32
      jump_len = config_val("jump_len").to_i32
      @graph = Graph.new(vertices, jumps, jump_len)
    end

    def prepare
      @graph.generate_random
      total_edges = @graph.adj.sum(&.size) // 2
    end

    def test : Int64
      0_i64
    end

    def run(iteration_id)
      @result &+= test
    end

    def checksum : UInt32
      @result
    end
  end

  class BFS < GraphPathBenchmark
    def test : Int64
      length = bfs_shortest_path(0, @graph.vertices - 1)
      length.to_i64
    end

    private def bfs_shortest_path(start, target)
      return 0 if start == target

      visited = Bytes.new(@graph.vertices)
      queue = Deque({Int32, Int32}).new

      visited[start] = 1
      queue.push({start, 0})

      while !queue.empty?
        v, dist = queue.shift

        @graph.adj[v].each do |neighbor|
          if neighbor == target
            return dist + 1
          end

          if visited[neighbor] == 0
            visited[neighbor] = 1
            queue.push({neighbor, dist + 1})
          end
        end
      end

      -1
    end
  end

  class DFS < GraphPathBenchmark
    def test : Int64
      length = dfs_shortest_path(0, @graph.vertices - 1)
      length.to_i64
    end

    private def dfs_shortest_path(start, target)
      return 0 if start == target

      visited = Bytes.new(@graph.vertices)
      stack = [{start, 0}]
      best_path = Int32::MAX

      while !stack.empty?
        v, dist = stack.pop

        next if visited[v] == 1 || dist >= best_path
        visited[v] = 1

        @graph.adj[v].each do |neighbor|
          if neighbor == target
            if dist + 1 < best_path
              best_path = dist + 1
            end
          elsif visited[neighbor] == 0
            stack << {neighbor, dist + 1}
          end
        end
      end

      best_path == Int32::MAX ? -1 : best_path
    end
  end

  class AStar < GraphPathBenchmark
    private class PriorityQueue
      @heap = Array({Int32, Int32}).new
      @size : Int32 = 0

      def empty?
        @size == 0
      end

      def push(vertex, priority)
        if @size >= @heap.size
          @heap << {vertex, priority}
        else
          @heap[@size] = {vertex, priority}
        end

        i = @size
        @size += 1

        while i > 0
          parent = (i - 1) // 2
          break if @heap[parent][1] <= priority
          @heap[i] = @heap[parent]
          i = parent
        end
        @heap[i] = {vertex, priority}
      end

      def pop
        min = @heap[0]
        @size -= 1

        if @size > 0
          last = @heap[@size]
          i = 0

          while true
            left = 2*i + 1
            right = 2*i + 2
            smallest = i

            if left < @size && @heap[left][1] < @heap[smallest][1]
              smallest = left
            end
            if right < @size && @heap[right][1] < @heap[smallest][1]
              smallest = right
            end

            break if smallest == i

            @heap[i] = @heap[smallest]
            i = smallest
          end

          @heap[i] = last
        end

        min
      end
    end

    def test : Int64
      astar_shortest_path(0, @graph.vertices - 1).to_i64
    end

    private def heuristic(v, target)
      target - v
    end

    private def astar_shortest_path(start, target)
      return 0 if start == target

      g_score = Array.new(@graph.vertices, Int32::MAX)
      g_score[start] = 0

      open_set = PriorityQueue.new
      open_set.push(start, heuristic(start, target))

      in_open_set = Array.new(@graph.vertices, false)
      in_open_set[start] = true

      closed = Array.new(@graph.vertices, false)

      while !open_set.empty?
        current, _ = open_set.pop
        closed[current] = true
        in_open_set[current] = false

        return g_score[current] if current == target

        @graph.adj[current].each do |neighbor|
          next if closed[neighbor]

          tentative_g = g_score[current] + 1

          if tentative_g < g_score[neighbor]
            g_score[neighbor] = tentative_g
            f = tentative_g + heuristic(neighbor, target)

            unless in_open_set[neighbor]
              open_set.push(neighbor, f)
              in_open_set[neighbor] = true
            end
          end
        end
      end

      -1
    end
  end
end

class Hash
  class BufferHashBenchmark < Benchmark
    def test : UInt32
      0_u32
    end

    @data : Bytes

    def initialize(@size : Int64 = config_val("size"))
      @data = Bytes.new(@size)
      @result = 0_u32
    end

    def prepare
      @data.size.times { |i| @data[i] = Helper.next_int(256).to_u8 }
    end

    def run(iteration_id)
      @result &+= test
    end

    def checksum : UInt32
      @result
    end
  end

  class SHA256 < BufferHashBenchmark
    struct SimpleSHA256
      def self.digest(data : Bytes) : Bytes
        result = Bytes.new(32)

        hashes = StaticArray[
          0x6a09e667u32, 0xbb67ae85u32, 0x3c6ef372u32, 0xa54ff53au32,
          0x510e527fu32, 0x9b05688cu32, 0x1f83d9abu32, 0x5be0cd19u32,
        ]

        data.each_with_index do |byte, i|
          hash_idx = i & 7
          hash = hashes[hash_idx]
          hash = ((hash << 5) &+ hash) &+ byte
          hash = (hash &+ (hash << 10)) ^ (hash >> 6)
          hashes[hash_idx] = hash
        end

        8.times do |i|
          hash = hashes[i]
          result[i * 4] = (hash >> 24).to_u8!
          result[i * 4 + 1] = (hash >> 16).to_u8!
          result[i * 4 + 2] = (hash >> 8).to_u8!
          result[i * 4 + 3] = hash.to_u8!
        end

        result
      end
    end

    def test : UInt32
      bytes = SimpleSHA256.digest(@data)
      ptr = bytes.to_unsafe.as(Pointer(UInt32))
      ptr.value
    end
  end

  class CRC32 < BufferHashBenchmark
    def test : UInt32
      crc = 0xFFFFFFFFu32

      @data.each do |byte|
        crc = crc ^ byte
        8.times do
          if (crc & 1) != 0
            crc = (crc >> 1) ^ 0xEDB88320u32
          else
            crc = crc >> 1
          end
        end
      end

      crc ^ 0xFFFFFFFFu32
    end
  end
end

module Calculator
  class Ast < Benchmark
    class Node
    end

    class Number < Node
      getter value : Int64

      def initialize(@value); end
    end

    class Variable < Node
      getter name : String

      def initialize(@name); end
    end

    class BinaryOp < Node
      getter op : Char
      getter left : Node
      getter right : Node

      def initialize(@op, @left, @right); end
    end

    class Assignment < Node
      getter var : String
      getter expr : Node

      def initialize(@var, @expr); end
    end

    def initialize(@n : Int64 = config_val("operations"))
      @result = 0_u32
      @text = ""
      @expressions = Array(Node).new
    end

    getter expressions

    def generate_random_program(n = 1000)
      String.build do |io|
        io << "v0 = 1\n"
        10.times do |i|
          v = i + 1
          io << "v#{v} = v#{v - 1} + #{v}\n"
        end
        n.times do |i|
          v = i + 10
          io << "v#{v} = v#{v - 1} + "
          case Helper.next_int(10)
          when 0
            io << "(v#{v - 1} / 3) * 4 - #{i} / (3 + (18 - v#{v - 2})) % v#{v - 3} + 2 * ((9 - v#{v - 6}) * (v#{v - 5} + 7))"
          when 1
            io << "v#{v - 1} + (v#{v - 2} + v#{v - 3}) * v#{v - 4} - (v#{v - 5} /  v#{v - 6})"
          when 2
            io << "(3789 - (((v#{v - 7})))) + 1"
          when 3
            io << "4/2 * (1-3) + v#{v - 9}/v#{v - 5}"
          when 4
            io << "1+2+3+4+5+6+v#{v - 1}"
          when 5
            io << "(99999 / v#{v - 3})"
          when 6
            io << "0 + 0 - v#{v - 8}"
          when 7
            io << "((((((((((v#{v - 6})))))))))) * 2"
          when 8
            io << "#{i} * (v#{v - 1}%6)%7"
          when 9
            io << "(1)/(0-v#{v - 5}) + (v#{v - 7})"
          end
          io << "\n"
        end
      end
    end

    def prepare
      @text = generate_random_program(@n)
    end

    def run(iteration_id)
      parser = Parser.new(@text)
      parser.parse
      @expressions = parser.expressions
      @result &+= @expressions.size
      @result &+= Helper.checksum(@expressions[-1].as(Assignment).var)
    end

    class Parser
      @input : String
      @pos : Int32
      @len : Int32
      getter current_char : Char
      @chars : Array(Char)

      getter expressions

      def initialize(@input)
        @pos = 0
        @chars = @input.chars
        @current_char = @chars.size > 0 ? @chars[0] : '\0'
        @len = @input.size
        @expressions = Array(Node).new
      end

      def parse
        while @pos < @len
          @expressions << parse_expression
        end
      end

      def parse_expression : Node
        node = parse_term

        while @pos < @len
          skip_whitespace
          break if @pos >= @len

          if current_char == '+' || current_char == '-'
            op = current_char
            advance
            right = parse_term
            node = BinaryOp.new(op, node, right)
          else
            break
          end
        end

        node
      end

      def parse_term : Node
        node = parse_factor

        while @pos < @len
          skip_whitespace
          break if @pos >= @len

          if current_char == '*' || current_char == '/' || current_char == '%'
            op = current_char
            advance
            right = parse_factor
            node = BinaryOp.new(op, node, right)
          else
            break
          end
        end

        node
      end

      def parse_factor : Node
        skip_whitespace
        return Number.new(0) if @pos >= @len

        case current_char
        when '0'..'9'
          parse_number
        when 'a'..'z'
          parse_variable
        when '('
          advance
          node = parse_expression
          skip_whitespace
          if current_char == ')'
            advance
          end
          node
        else
          Number.new(0)
        end
      end

      def parse_number : Node
        start = @pos
        v = 0_i64
        while @pos < @len && current_char.ascii_number?
          v = v &* 10 &+ @current_char.to_i64
          advance
        end
        Number.new(v)
      end

      def parse_variable : Node
        start = @pos
        while @pos < @len && (current_char.ascii_letter? || current_char.ascii_number?)
          advance
        end
        var_name = @input[start...@pos]

        skip_whitespace
        if current_char == '='
          advance
          expr = parse_expression
          return Assignment.new(var_name, expr)
        end

        Variable.new(var_name)
      end

      def advance
        @pos += 1
        if @pos >= @len
          @current_char = '\0'
        else
          @current_char = @chars[@pos]
        end
      end

      def skip_whitespace
        while @pos < @len && current_char.ascii_whitespace?
          advance
        end
      end
    end

    def checksum : UInt32
      @result
    end
  end

  class Interpreter < Benchmark
    class Interpreter
      def initialize
        @variables = Hash(String, Int64).new(0)
      end

      def simple_div(a : Int64, b : Int64) : Int64
        return 0_i64 if b == 0

        if (a >= 0 && b > 0) || (a < 0 && b < 0)
          a // b
        else
          -(a.abs // b.abs)
        end
      end

      def simple_mod(a : Int64, b : Int64) : Int64
        return 0_i64 if b == 0
        a - simple_div(a, b) * b
      end

      def evaluate(node : Ast::Node) : Int64
        case node
        when Ast::Number
          node.value.to_i64
        when Ast::Variable
          @variables[node.name]? || 0_i64
        when Ast::BinaryOp
          left = evaluate(node.left)
          right = evaluate(node.right)

          res = case node.op
                when '+' then left &+ right
                when '-' then left &- right
                when '*' then left &* right
                when '/' then simple_div(left, right)
                when '%' then simple_mod(left, right)
                else
                  0_i64
                end
          res
        when Ast::Assignment
          value = evaluate(node.expr)
          @variables[node.var] = value
          value
        else
          0_i64
        end
      end

      def run(expressions : Array(Ast::Node)) : Int64
        result = 0_i64
        expressions.each do |expr|
          result = evaluate(expr)
        end
        result
      end

      def clear
        @variables.clear
      end
    end

    def initialize(@n : Int64 = config_val("operations"))
      @ast = Array(Ast::Node).new
      @result = 0_u32
    end

    getter expressions

    def prepare
      c = Ast.new(@n)
      c.prepare
      c.run(0)
      @ast = c.expressions
    end

    def run(iteration_id)
      interpreter = Interpreter.new
      @result &+= interpreter.run(@ast)
    end

    def checksum : UInt32
      @result
    end
  end
end

module Maze
  class Generator < Benchmark
    class Cell
      enum Kind
        Wall   = 0
        Space
        Start
        Finish
        Border
        Path

        def walkable?
          case self
          when Space, Start, Finish
            true
          else
            false
          end
        end
      end

      property kind : Kind = :wall
      property neighbors = Array(Cell).new(initial_capacity: 4)
      property x : Int32
      property y : Int32

      def initialize(@x, @y)
      end

      def reset
        @kind = :wall if @kind.space?
      end
    end

    class Maze
      property cells : Array(Array(Cell))
      property start : Cell
      property finish : Cell

      def initialize(@w : Int32, @h : Int32)
        @cells = Array(Array(Cell)).new(@h) { |y| Array(Cell).new(@w) { |x| Cell.new(x, y) } }
        @start = @cells[1][1]
        @finish = @cells[@h - 2][@w - 2]
        @start.kind = :start
        @finish.kind = :finish
        update_neighbors
      end

      def update_neighbors
        @cells.each_with_index do |row, y|
          row.each_with_index do |cell, x|
            if x > 0 && y > 0 && x < @w - 1 && y < @h - 1
              cell.neighbors << @cells[y - 1][x]
              cell.neighbors << @cells[y + 1][x]
              cell.neighbors << @cells[y][x + 1]
              cell.neighbors << @cells[y][x - 1]

              4.times do
                i = Helper.next_int(4)
                j = Helper.next_int(4)
                cell.neighbors.swap(i, j) if i != j
              end
            else
              cell.kind = :border
            end
          end
        end
      end

      def reset
        @cells.each &.each &.reset
        @start.kind = :start
        @finish.kind = :finish
      end

      def dig(start : Cell)
        q = Array(Cell).new
        q << start
        while cell = q.pop?
          if cell.neighbors.count(&.kind.walkable?) == 1
            cell.kind = :space
            cell.neighbors.each { |n| q << n if n.kind.wall? }
          end
        end
      end

      def ensure_open_finish(cell : Cell)
        cell.kind = :space
        return if cell.neighbors.count(&.kind.walkable?) > 1
        cell.neighbors.each { |n| ensure_open_finish(n) if n.kind.wall? }
      end

      def generate
        @start.neighbors.each { |n| dig(n) if n.kind.wall? }
        @finish.neighbors.each { |n| ensure_open_finish(n) if n.kind.wall? }
      end

      def middle_cell
        @cells[@h >> 1][@w >> 1]
      end

      def checksum : UInt32
        hasher = 2166136261_u32
        prime = 16777619_u32

        @cells.each_with_index do |row, y|
          row.each_with_index do |cell, x|
            if cell.kind.space?
              j_squared = x.to_u32 &* y.to_u32
              hasher = (hasher ^ j_squared) &* prime
            end
          end
        end

        hasher
      end

      def print_to_console
        @cells.each do |row|
          row.each do |cell|
            sym = case cell.kind
                  when Cell::Kind::Space ; " "
                  when Cell::Kind::Wall  ; "\u001B[34m#\u001B[0m"
                  when Cell::Kind::Border; "\u001B[31mO\u001B[0m"
                  when Cell::Kind::Start ; "\u001B[32m>\u001B[0m"
                  when Cell::Kind::Finish; "\u001B[32m<\u001B[0m"
                  when Cell::Kind::Path  ; "\u001B[33m.\u001B[0m"
                  else                     "?"
                  end
            print(sym)
          end
          puts
        end
        puts
      end
    end

    getter width : Int32
    getter height : Int32

    def initialize
      @result = 0_u32
      @width = config_val("w").to_i32
      @height = config_val("h").to_i32
      @maze = Maze.new(@width, @height)
    end

    def run(iteration_id)
      @maze.reset
      @maze.generate

      @result &+= @maze.middle_cell.kind.value
    end

    def checksum : UInt32
      @result &+ @maze.checksum
    end
  end

  class BFS < Benchmark
    getter result : UInt32
    getter width : Int32
    getter height : Int32

    def initialize
      @result = 0_u32
      @width = config_val("w").to_i32
      @height = config_val("h").to_i32
      @maze = Generator::Maze.new(@width, @height)
      @path = [] of Generator::Cell
    end

    def prepare
      @maze.generate
    end

    def bfs(start : Generator::Cell, target : Generator::Cell) : Array(Generator::Cell)
      return [start] if start == target

      queue = Deque(Int32).new
      visited = Array.new(@height) { Array.new(@width) { false } }
      path = Array({Generator::Cell, Int32}).new

      visited[start.y][start.x] = true
      path << {start, -1}
      queue << 0

      while path_id = queue.shift?
        cell, _ = path[path_id]

        cell.neighbors.each do |neighbor|
          if neighbor == target
            res = [target]
            current = path_id
            while current >= 0
              cell, prev_id = path[current]
              res << cell
              current = prev_id
            end
            res.reverse!
            return res
          end

          if neighbor.kind.walkable? && !visited[neighbor.y][neighbor.x]
            visited[neighbor.y][neighbor.x] = true
            path << {neighbor, path_id}
            queue << path.size - 1
          end
        end
      end

      [] of Generator::Cell
    end

    def run(iteration_id)
      @path = bfs(@maze.start, @maze.finish)
      @result &+= @path.size
    end

    def show_path(path : Array(Generator::Cell))
      path.each { |cell| cell.kind = :path }
      @maze.print_to_console
    end

    def checksum : UInt32
      v = @path[@path.size >> 1]
      @result &+ (v.x &* v.y)
    end
  end

  class AStar < Benchmark
    private class PriorityQueue
      @heap = Array({Int32, Int32}).new
      @size : Int32 = 0
      @best_priority : Array(Int32)

      def initialize(size)
        @best_priority = Array.new(size, Int32::MAX)
      end

      def empty?
        @size == 0
      end

      def push(vertex : Int32, priority : Int32)
        return if priority >= @best_priority[vertex]

        @best_priority[vertex] = priority

        if @size >= @heap.size
          @heap << {vertex, priority}
        else
          @heap[@size] = {vertex, priority}
        end

        i = @size
        @size += 1

        while i > 0
          parent = (i - 1) // 2
          break if @heap[parent][1] <= priority
          @heap[i] = @heap[parent]
          i = parent
        end
        @heap[i] = {vertex, priority}
      end

      def pop
        min = @heap[0]
        @size -= 1

        if @size > 0
          last = @heap[@size]
          i = 0

          while true
            left = 2*i + 1
            right = 2*i + 2
            smallest = i

            if left < @size && @heap[left][1] < @heap[smallest][1]
              smallest = left
            end
            if right < @size && @heap[right][1] < @heap[smallest][1]
              smallest = right
            end

            break if smallest == i

            @heap[i] = @heap[smallest]
            i = smallest
          end

          @heap[i] = last
        end

        min
      end
    end

    getter result : UInt32
    getter width : Int32
    getter height : Int32

    def initialize
      @result = 0_u32
      @width = config_val("w").to_i32
      @height = config_val("h").to_i32
      @maze = Generator::Maze.new(@width, @height)
      @path = [] of Generator::Cell
    end

    def prepare
      @maze.generate
    end

    private def heuristic(a : Generator::Cell, b : Generator::Cell) : Int32
      (a.x - b.x).abs + (a.y - b.y).abs
    end

    def astar(start : Generator::Cell, target : Generator::Cell) : Array(Generator::Cell)
      return [start] if start == target

      width, height = @width, @height
      size = width * height

      start_idx = start.y * width + start.x
      target_idx = target.y * width + target.x

      came_from = Array(Int32).new(size, -1)
      g_score = Array(Int32).new(size, Int32::MAX)
      f_score = Array(Int32).new(size, Int32::MAX)

      open_set = PriorityQueue.new(size)

      g_score[start_idx] = 0
      f_score[start_idx] = heuristic(start, target)
      open_set.push(start_idx, f_score[start_idx])

      while !open_set.empty?
        current_idx, _ = open_set.pop

        if current_idx == target_idx
          return reconstruct_path(came_from, current_idx)
        end

        current_y = current_idx // width
        current_x = current_idx % width
        current = @maze.cells[current_y][current_x]

        current_g = g_score[current_idx]

        current.neighbors.each do |neighbor|
          next unless neighbor.kind.walkable?

          neighbor_idx = neighbor.y * width + neighbor.x
          tentative_g = current_g + 1

          if tentative_g < g_score[neighbor_idx]
            came_from[neighbor_idx] = current_idx
            g_score[neighbor_idx] = tentative_g
            new_f = tentative_g + heuristic(neighbor, target)
            f_score[neighbor_idx] = new_f

            open_set.push(neighbor_idx, new_f)
          end
        end
      end

      [] of Generator::Cell
    end

    private def reconstruct_path(came_from, current_idx)
      path = [] of Generator::Cell

      while current_idx != -1
        y = current_idx // @width
        x = current_idx % @width
        path << @maze.cells[y][x]
        current_idx = came_from[current_idx]
      end

      path.reverse
    end

    def run(iteration_id)
      @path = astar(@maze.start, @maze.finish)
      @result &+= @path.size
    end

    def show_path(path : Array(Generator::Cell))
      path.each { |cell| cell.kind = :path }
      @maze.print_to_console
    end

    def checksum : UInt32
      v = @path[@path.size >> 1]
      @result &+ (v.x &* v.y)
    end
  end
end

module CLBG
  class Pidigits < Benchmark
    def initialize(@nn : Int32 = config_val("amount").to_i32)
      @result = IO::Memory.new
    end

    def run(iteration_id)
      i = 0
      k = 0
      ns = MutGMP::MpZ.new(0)
      a = MutGMP::MpZ.new(0)
      t = MutGMP::MpZ.new(0)
      u = MutGMP::MpZ.new(0)
      k1 = 1
      n = MutGMP::MpZ.new(1)
      d = MutGMP::MpZ.new(1)

      tmp1 = MutGMP::MpZ.new(0)
      tmp2 = MutGMP::MpZ.new(0)

      loop do
        k += 1

        tmp1.set!(n)
        tmp1.shl!(1)
        t.set!(tmp1)

        n.mul!(k)

        k1 += 2

        tmp1.set!(a)
        tmp1.add!(t)
        tmp1.mul!(k1)
        a.set!(tmp1)

        d.mul!(k1)

        if a >= n
          tmp1.set!(n)
          tmp1.mul!(3)
          tmp1.add!(a)

          LibGMP.fdiv_qr(t.to_unsafe, u.to_unsafe, tmp1.to_unsafe, d.to_unsafe)

          u.add!(n)

          if d >= u
            ns.mul!(10)
            ns.add!(t)

            i += 1
            if i % 10 == 0
              @result << "%010d\t:%d\n" % {ns.to_u64, i}
              ns.set!(0)
            end
            break if i >= @nn

            tmp1.set!(d)
            tmp1.mul!(t)
            a.sub!(tmp1)
            a.mul!(10)

            n.mul!(10)
          end
        end
      end
    end

    def checksum : UInt32
      Helper.checksum(@result.to_s)
    end
  end

  class Fannkuchredux < Benchmark
    def fannkuchredux(n : Int32)
      perm1 = StaticArray(Int32, 32).new { |i| i }
      perm = StaticArray(Int32, 32).new(0)
      count = StaticArray(Int32, 32).new(0)
      maxFlipsCount = permCount = checksum = 0
      n = 32 if n > 32
      r = n

      loop do
        while r > 1
          count[r - 1] = r
          r -= 1
        end

        n.times { |i| perm[i] = perm1[i] }
        flipsCount = 0

        while !((k = perm[0]) == 0)
          k2 = (k + 1) >> 1
          (0...k2).each do |i|
            j = k - i
            perm.swap(i, j)
          end
          flipsCount += 1
        end

        maxFlipsCount = flipsCount if flipsCount > maxFlipsCount
        checksum += (permCount % 2 == 0) ? flipsCount : -flipsCount

        loop do
          return {checksum, maxFlipsCount} if r == n

          perm0 = perm1[0]
          (0...r).each do |i|
            j = i + 1
            perm1.swap(i, j)
          end

          perm1[r] = perm0
          cntr = count[r] -= 1
          break if cntr > 0
          r += 1
        end
        permCount += 1
      end
    end

    def initialize(@n : Int64 = config_val("n"))
      @result = 0_u32
    end

    def run(iteration_id)
      a, b = fannkuchredux(@n.to_i32)
      @result &+= a.to_i64 * 100 &+ b
    end

    def checksum : UInt32
      @result
    end
  end

  class Fasta < Benchmark
    def select_random(genelist)
      r = Helper.next_float
      return genelist[0][0] if r < genelist[0][1]

      lo = 0
      hi = genelist.size - 1

      while hi > lo + 1
        i = (hi + lo) // 2
        if r < genelist[i][1]
          hi = i
        else
          lo = i
        end
      end
      genelist[hi][0]
    end

    LINE_LENGTH = 60

    def make_random_fasta(id, desc, genelist, n)
      todo = n
      @result << ">#{id} #{desc}"
      @result << "\n"

      while todo > 0
        m = (todo < LINE_LENGTH) ? todo : LINE_LENGTH
        pick = String.new(m) do |buffer|
          m.times { |i| buffer[i] = select_random(genelist).ord.to_u8 }
          {m, m}
        end
        @result << pick
        @result << "\n"
        todo -= LINE_LENGTH
      end
    end

    def make_repeat_fasta(id, desc, s, n)
      todo = n
      k = 0
      kn = s.size

      @result << ">#{id} #{desc}"
      @result << "\n"
      while todo > 0
        m = (todo < LINE_LENGTH) ? todo : LINE_LENGTH

        while m >= kn - k
          @result << s[k..-1]
          m -= kn - k
          k = 0
        end

        @result << s[k...k + m]
        @result << "\n"
        k += m

        todo -= LINE_LENGTH
      end
    end

    IUB = [{'a', 0.27}, {'c', 0.39}, {'g', 0.51}, {'t', 0.78}, {'B', 0.8}, {'D', 0.8200000000000001},
           {'H', 0.8400000000000001}, {'K', 0.8600000000000001}, {'M', 0.8800000000000001},
           {'N', 0.9000000000000001}, {'R', 0.9200000000000002}, {'S', 0.9400000000000002},
           {'V', 0.9600000000000002}, {'W', 0.9800000000000002}, {'Y', 1.0000000000000002}]
    HOMO = [{'a', 0.302954942668}, {'c', 0.5009432431601}, {'g', 0.6984905497992}, {'t', 1.0}]
    ALU  = "GGCCGGGCGCGGTGGCTCACGCCTGTAATCCCAGCACTTTGGGAGGCCGAGGCGGGCGGATCACCTGAGGTCAGGAGTTCGAGACCAGCCTGGCCAACATGGTGAAACCCCGTCTCTACTAAAAATACAAAAATTAGCCGGGCGTGGTGGCGCGCGCCTGTAATCCCAGCTACTCGGGAGGCTGAGGCAGGAGAATCGCTTGAACCCGGGAGGCGGAGGTTGCAGTGAGCCGAGATCGCGCCACTGCACTCCAGCCTGGGCGACAGAGCGAGACTCCGTCTCAAAAA"

    def initialize(@n : Int64 = config_val("n"))
      @result = IO::Memory.new
    end

    def run(iteration_id)
      make_repeat_fasta("ONE", "Homo sapiens alu", ALU, @n * 2)
      make_random_fasta("TWO", "IUB ambiguity codes", IUB, @n * 3)
      make_random_fasta("THREE", "Homo sapiens frequency", HOMO, @n * 5)
    end

    def checksum : UInt32
      Helper.checksum(@result.to_s)
    end
  end

  class Knuckeotide < Benchmark
    def frecuency(seq, length)
      n = seq.size - length + 1
      table = Hash(String, Int32).new { 0 }
      (0...n).each do |f|
        table[seq.byte_slice(f, length)] += 1
      end
      {n, table}
    end

    def sort_by_freq(seq, length)
      n, table = frecuency(seq, length)
      table.to_a.sort { |a, b| b[1] <=> a[1] }.each do |v|
        @result << "%s %.3f\n" % {v[0].upcase, ((v[1] * 100).to_f / n)}
      end
      @result << "\n"
    end

    def find_seq(seq, s)
      n, table = frecuency(seq, s.size)
      @result << "#{table[s].to_s}\t#{s.upcase}\n"
    end

    def initialize
      @seq = ""
      @result = IO::Memory.new
    end

    def prepare
      f = Fasta.new(config_val("n"))
      f.run(0)
      res = f.@result.to_s

      three = false
      seqio = IO::Memory.new

      res.each_line do |line|
        if line.starts_with?(">THREE")
          three = true
          next
        end
        seqio << line.chomp if three
      end
      @seq = seqio.to_s
    end

    def run(iteration_id)
      (1..2).each { |i| sort_by_freq(@seq, i) }
      %w(ggt ggta ggtatt ggtattttaatt ggtattttaatttatagt).each { |s| find_seq(@seq, s) }
    end

    def checksum : UInt32
      Helper.checksum(@result.to_s)
    end
  end

  class RegexDna < Benchmark
    @seq : String
    @ilen : Int32
    @clen : Int32

    def initialize
      @result = IO::Memory.new
      @ilen = 0
      @clen = 0
      @seq = ""
    end

    def prepare
      f = Fasta.new(config_val("n"))
      f.run(0)
      res = f.@result.to_s

      seq = IO::Memory.new

      @ilen = 0
      res.each_line do |line|
        @ilen += line.bytesize + 1
        seq << line.chomp unless line.starts_with? '>'
      end

      @seq = seq.to_s
      @clen = seq.bytesize
    end

    def run(iteration_id)
      [
        /agggtaaa|tttaccct/,
        /[cgt]gggtaaa|tttaccc[acg]/,
        /a[act]ggtaaa|tttacc[agt]t/,
        /ag[act]gtaaa|tttac[agt]ct/,
        /agg[act]taaa|ttta[agt]cct/,
        /aggg[acg]aaa|ttt[cgt]ccct/,
        /agggt[cgt]aa|tt[acg]accct/,
        /agggta[cgt]a|t[acg]taccct/,
        /agggtaa[cgt]|[acg]ttaccct/,
      ].each { |f| @result << "#{f.source} #{@seq.scan(f).size}\n" }

      hash = {
        "B" => "(c|g|t)",
        "D" => "(a|g|t)",
        "H" => "(a|c|t)",
        "K" => "(g|t)",
        "M" => "(a|c)",
        "N" => "(a|c|g|t)",
        "R" => "(a|g)",
        "S" => "(c|t)",
        "V" => "(a|c|g)",
        "W" => "(a|t)",
        "Y" => "(c|t)",
      }

      @seq = @seq.gsub(/B|D|H|K|M|N|R|S|V|W|Y/, hash)

      @result << "\n"
      @result << "#{@ilen}\n"
      @result << "#{@clen}\n"
      @result << "#{@seq.size}\n"
    end

    def checksum : UInt32
      Helper.checksum(@result.to_s)
    end
  end

  class Revcomp < Benchmark
    @input : String

    COMPLEMENT_LOOKUP = begin
      table = StaticArray(UInt8, 256).new(0_u8)
      256.times { |i| table[i] = i.to_u8 }

      from = "wsatugcyrkmbdhvnATUGCYRKMBDHVN"
      to = "WSTAACGRYMKVHDBNTAACGRYMKVHDBN"
      from.to_slice.each_with_index do |byte, i|
        table[byte] = to.unsafe_byte_at(i)
      end
      table
    end

    def revcomp(seq)
      bytesize = seq.bytesize
      chunk_count = (bytesize + 59) // 60

      @result.clear

      bytesize.step(to: 1, by: -60) do |end_pos|
        start_pos = Math.max(end_pos - 60, 0)

        (end_pos - 1).downto(start_pos) do |i|
          @result.write_byte(COMPLEMENT_LOOKUP[seq.unsafe_byte_at(i)])
        end

        @result << "\n"
      end
    end

    def initialize
      @result = IO::Memory.new
      @input = ""
      @checksum = 0_u32
    end

    def prepare
      f = Fasta.new(config_val("n"))
      f.run(0)
      input = f.@result.to_s
      seq = IO::Memory.new

      input.each_line do |line|
        if line.starts_with? '>'
          seq << "\n---\n"
        else
          seq << line.chomp
        end
      end
      @input = seq.to_s
    end

    def run(iteration_id)
      @result.clear
      revcomp(@input)
      @checksum &+= Helper.checksum(@result.to_s)
    end

    def checksum : UInt32
      @checksum
    end
  end

  class Mandelbrot < Benchmark
    ITER  =  50
    LIMIT = 2.0

    def initialize(@n : Int32 = iterations.to_i32)
      @result = IO::Memory.new
    end

    def run(iteration_id)
      w = config_val("w")
      h = config_val("h")
      @result << "P4\n#{w} #{h}\n"

      bit_num = 0
      byte_acc = 0_u8

      h.times do |y|
        w.times do |x|
          zr = zi = tr = ti = 0.0
          cr = (2.0 * x / w - 1.5)
          ci = (2.0 * y / h - 1.0)

          i = 0
          while (i < ITER) && (tr + ti <= LIMIT * LIMIT)
            zi = 2.0 * zr * zi + ci
            zr = tr - ti + cr
            tr = zr * zr
            ti = zi * zi
            i += 1
          end

          byte_acc <<= 1
          byte_acc |= 0x01 if tr + ti <= LIMIT * LIMIT
          bit_num += 1

          if bit_num == 8
            @result.write_byte byte_acc
            byte_acc = 0_u8
            bit_num = 0
          elsif x == w - 1
            byte_acc <<= 8 - w % 8
            @result.write_byte byte_acc
            byte_acc = 0_u8
            bit_num = 0
          end
        end
      end
    end

    def checksum : UInt32
      Helper.checksum(@result.to_slice)
    end
  end

  class Nbody < Benchmark
    SOLAR_MASS    = 4 * Math::PI**2
    DAYS_PER_YEAR = 365.24

    class Planet
      def_clone

      property x : Float64
      property y : Float64
      property z : Float64
      property vx : Float64
      property vy : Float64
      property vz : Float64
      property mass : Float64

      def initialize(@x, @y, @z, vx, vy, vz, mass)
        @vx, @vy, @vz = vx * DAYS_PER_YEAR, vy * DAYS_PER_YEAR, vz * DAYS_PER_YEAR
        @mass = mass * SOLAR_MASS
      end

      def move_from_i(bodies, dt, i)
        while i < bodies.size
          b2 = bodies[i]
          dx = @x - b2.x
          dy = @y - b2.y
          dz = @z - b2.z

          distance = Math.sqrt(dx * dx + dy * dy + dz * dz)
          mag = dt / (distance * distance * distance)
          b_mass_mag, b2_mass_mag = @mass * mag, b2.mass * mag

          @vx -= dx * b2_mass_mag
          @vy -= dy * b2_mass_mag
          @vz -= dz * b2_mass_mag
          b2.vx += dx * b_mass_mag
          b2.vy += dy * b_mass_mag
          b2.vz += dz * b_mass_mag
          i += 1
        end

        @x += dt * @vx
        @y += dt * @vy
        @z += dt * @vz
      end
    end

    def energy(bodies)
      e = 0.0
      nbodies = bodies.size

      0.upto(nbodies - 1) do |i|
        b = bodies[i]
        e += 0.5 * b.mass * (b.vx * b.vx + b.vy * b.vy + b.vz * b.vz)
        (i + 1).upto(nbodies - 1) do |j|
          b2 = bodies[j]
          dx = b.x - b2.x
          dy = b.y - b2.y
          dz = b.z - b2.z
          distance = Math.sqrt(dx * dx + dy * dy + dz * dz)
          e -= (b.mass * b2.mass) / distance
        end
      end
      e
    end

    def offset_momentum(bodies)
      px, py, pz = 0.0, 0.0, 0.0

      bodies.each do |b|
        m = b.mass
        px += b.vx * m
        py += b.vy * m
        pz += b.vz * m
      end

      b = bodies[0]
      b.vx = -px / SOLAR_MASS
      b.vy = -py / SOLAR_MASS
      b.vz = -pz / SOLAR_MASS
    end

    BODIES = [

      Planet.new(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0),

      Planet.new(
        4.84143144246472090e+00,
        -1.16032004402742839e+00,
        -1.03622044471123109e-01,
        1.66007664274403694e-03,
        7.69901118419740425e-03,
        -6.90460016972063023e-05,
        9.54791938424326609e-04),

      Planet.new(
        8.34336671824457987e+00,
        4.12479856412430479e+00,
        -4.03523417114321381e-01,
        -2.76742510726862411e-03,
        4.99852801234917238e-03,
        2.30417297573763929e-05,
        2.85885980666130812e-04),

      Planet.new(
        1.28943695621391310e+01,
        -1.51111514016986312e+01,
        -2.23307578892655734e-01,
        2.96460137564761618e-03,
        2.37847173959480950e-03,
        -2.96589568540237556e-05,
        4.36624404335156298e-05),

      Planet.new(
        1.53796971148509165e+01,
        -2.59193146099879641e+01,
        1.79258772950371181e-01,
        2.68067772490389322e-03,
        1.62824170038242295e-03,
        -9.51592254519715870e-05,
        5.15138902046611451e-05),
    ]

    def initialize
      @result = 0_u32
      @bodies = BODIES
      @v1 = 0_f64
    end

    def prepare
      offset_momentum(@bodies)
      @v1 = energy(@bodies)
    end

    def run(iteration_id)
      1000.times do
        @bodies.each_with_index do |b, i|
          b.move_from_i(@bodies, 0.01, i + 1)
        end
      end
    end

    def checksum : UInt32
      v2 = energy(@bodies)
      (Helper.checksum_f64(@v1) << 5) & Helper.checksum_f64(v2)
    end
  end

  class Spectralnorm < Benchmark
    def eval_A(i, j)
      1.0_f64 / ((i + j) * (i + j + 1.0) / 2.0 + i + 1.0)
    end

    def eval_A_times_u(u)
      (0...u.size).map do |i|
        v = 0.0_f64
        u.each_with_index do |uu, j|
          v += eval_A(i, j) * uu
        end
        v
      end
    end

    def eval_At_times_u(u)
      (0...u.size).map do |i|
        v = 0.0_f64
        u.each_with_index do |uu, j|
          v += eval_A(j, i) * uu
        end
        v
      end
    end

    def eval_AtA_times_u(u)
      eval_At_times_u(eval_A_times_u(u))
    end

    def initialize(@size : Int64 = config_val("size"))
      @result = 0_u32
      @u = Array(Float64).new(@size, 1.0_f64)
      @v = Array(Float64).new(@size, 1.0_f64)
    end

    def run(iteration_id)
      @v = eval_AtA_times_u(@u)
      @u = eval_AtA_times_u(@v)
    end

    def checksum : UInt32
      vBv = vv = 0.0_f64
      (0...@size).each do |i|
        vBv += @u[i] * @v[i]
        vv += @v[i] * @v[i]
      end
      Helper.checksum_f64(Math.sqrt(vBv / vv))
    end
  end
end

module Compress
  def self.generate_test_data(size : Int64) : Bytes
    pattern = "ABRACADABRA"
    data = Bytes.new(size)

    size.times do |i|
      data[i] = pattern[i % pattern.bytesize].ord.to_u8
    end

    data
  end

  class BWTEncode < Benchmark
    struct BWTResult
      property transformed : Bytes
      property original_idx : Int32

      def initialize(@transformed : Bytes = Bytes.new(0), @original_idx : Int32 = 0)
      end
    end

    private def bwt_transform(input : Bytes) : BWTResult
      n = input.bytesize
      return BWTResult.new(Bytes.new(0), 0) if n == 0

      sa = Array.new(n) { |i| i }

      counts = Array.new(256, 0)
      input.each { |byte| counts[byte] += 1 }

      positions = Array.new(256, 0)
      total = 0
      256.times do |i|
        positions[i] = total
        total += counts[i]
      end

      temp_counts = Array.new(256, 0)
      sorted_sa = Array.new(n, 0)
      n.times do |i|
        idx = sa[i]
        byte = input[idx]
        pos = positions[byte] + temp_counts[byte]
        sorted_sa[pos] = idx
        temp_counts[byte] += 1
      end
      sa = sorted_sa

      if n > 1
        rank = Array.new(n, 0)
        current_rank = 0
        prev_char = input[sa[0]]

        sa.each_with_index do |idx, i|
          if input[idx] != prev_char
            current_rank += 1
            prev_char = input[idx]
          end
          rank[idx] = current_rank
        end

        k = 1
        while k < n
          pairs = Array.new(n) { |i| {rank[i], rank[(i + k) % n]} }

          sa.sort! do |a, b|
            pair_a = pairs[a]
            pair_b = pairs[b]
            if pair_a[0] != pair_b[0]
              pair_a[0] <=> pair_b[0]
            else
              pair_a[1] <=> pair_b[1]
            end
          end

          new_rank = Array.new(n, 0)
          new_rank[sa[0]] = 0
          (1...n).each do |i|
            prev_pair = pairs[sa[i - 1]]
            curr_pair = pairs[sa[i]]
            new_rank[sa[i]] = new_rank[sa[i - 1]] + (prev_pair != curr_pair ? 1 : 0)
          end

          rank = new_rank
          k *= 2
        end
      end

      transformed = Bytes.new(n)
      original_idx = 0

      sa.each_with_index do |suffix, i|
        if suffix == 0
          transformed[i] = input[n - 1]
          original_idx = i
        else
          transformed[i] = input[suffix - 1]
        end
      end

      BWTResult.new(transformed, original_idx)
    end

    property size : Int64
    property result : UInt32
    getter test_data : Bytes
    getter bwt_result : BWTResult

    def initialize
      @size = config_val("size")
      @result = 0_u32
      @test_data = Bytes.new(0)
      @bwt_result = BWTResult.new
    end

    def prepare
      @test_data = Compress.generate_test_data(@size)
    end

    def run(iteration_id)
      @bwt_result = bwt_transform(@test_data)
      @result &+= @bwt_result.transformed.bytesize.to_u32
    end

    def checksum : UInt32
      @result
    end
  end

  class BWTDecode < Benchmark
    private def bwt_inverse(bwt_result : BWTEncode::BWTResult) : Bytes
      bwt = bwt_result.transformed
      n = bwt.bytesize
      return Bytes.new(0) if n == 0

      counts = StaticArray(Int32, 256).new(0)
      bwt.each do |byte|
        counts[byte] += 1
      end

      positions = StaticArray(Int32, 256).new(0)
      total = 0
      counts.each_with_index do |count, i|
        positions[i] = total
        total += count
      end

      next_arr = Array.new(n, 0)
      temp_counts = StaticArray(Int32, 256).new(0)

      bwt.each_with_index do |byte, i|
        pos = positions[byte] + temp_counts[byte]
        next_arr[pos] = i
        temp_counts[byte] += 1
      end

      result = Bytes.new(n)
      idx = bwt_result.original_idx

      n.times do |i|
        idx = next_arr[idx]
        result[i] = bwt[idx]
      end

      Slice.new(result.to_unsafe, result.size)
    end

    property size : Int64
    property result : UInt32
    getter test_data : Bytes
    getter inverted : Bytes

    def initialize
      @size = config_val("size")
      @result = 0_u32
      @test_data = Bytes.new(0)
      @inverted = Bytes.new(0)
      @bwt_result = BWTEncode::BWTResult.new
    end

    def prepare
      encoder = BWTEncode.new
      encoder.size = @size
      encoder.prepare
      encoder.run(0)
      @test_data = encoder.test_data
      @bwt_result = encoder.bwt_result
    end

    def run(iteration_id)
      @inverted = bwt_inverse(@bwt_result)
      @result &+= @inverted.bytesize.to_u32
    end

    def checksum : UInt32
      if @inverted == @test_data
        @result &+= 100_000
      end
      @result
    end
  end

  class HuffEncode < Benchmark
    class HuffmanNode
      property frequency : Int32
      property byte_val : UInt8
      property is_leaf : Bool
      property left : HuffmanNode?
      property right : HuffmanNode?
      property index : Int32

      def initialize(@frequency : Int32 = 0, @byte_val : UInt8 = 0, @is_leaf : Bool = true)
        @index = 0
      end
    end

    class HuffmanCodes
      property code_lengths : Array(Int32)
      property codes : Array(Int32)

      def initialize
        @code_lengths = Array.new(256, 0)
        @codes = Array.new(256, 0)
      end
    end

    struct EncodedResult
      property frequencies : Array(Int32)
      property data : Bytes
      property bit_count : Int32

      def initialize(@data : Bytes = Bytes.new(0), @bit_count : Int32 = 0, @frequencies = Array(Int32).new)
      end
    end

    def self.build_huffman_tree(frequencies : Array(Int32)) : HuffmanNode
      nodes = [] of HuffmanNode
      frequencies.each_with_index do |freq, i|
        nodes << HuffmanNode.new(freq, i.to_u8) if freq > 0
      end

      nodes.sort_by! { |node| node.frequency }

      if nodes.size == 1
        node = nodes.first
        root = HuffmanNode.new(node.frequency, 0_u8, false)
        root.left = node
        root.right = HuffmanNode.new(0, 0_u8)
        return root
      end

      while nodes.size > 1
        left = nodes.shift
        right = nodes.shift

        parent = HuffmanNode.new(
          left.frequency + right.frequency,
          0_u8,
          false
        )
        parent.left = left
        parent.right = right

        insert_index = nodes.bsearch_index { |n| n.frequency >= parent.frequency }
        if insert_index
          nodes.insert(insert_index, parent)
        else
          nodes << parent
        end
      end

      nodes.first
    end

    private def build_huffman_codes(node : HuffmanNode, code : Int32, length : Int32, huffman_codes : HuffmanCodes)
      if node.is_leaf
        if length > 0 || node.byte_val != 0
          idx = node.byte_val
          huffman_codes.code_lengths[idx] = length
          huffman_codes.codes[idx] = code
        end
      else
        if left = node.left
          build_huffman_codes(left, code << 1, length + 1, huffman_codes)
        end
        if right = node.right
          build_huffman_codes(right, (code << 1) | 1, length + 1, huffman_codes)
        end
      end
    end

    private def huffman_encode(data : Bytes, huffman_codes : HuffmanCodes, frequencies) : EncodedResult
      result = Array(UInt8).new(initial_capacity: data.size * 2)
      current_byte = 0_u8
      bit_pos = 0
      byte_index = 0
      total_bits = 0

      codes = huffman_codes.codes
      code_lengths = huffman_codes.code_lengths

      data.each do |byte|
        code = codes[byte]
        length = code_lengths[byte]

        (length - 1).downto(0) do |i|
          if (code & (1 << i)) != 0
            current_byte |= 1 << (7 - bit_pos)
          end
          bit_pos += 1
          total_bits += 1

          if bit_pos == 8
            result << current_byte
            current_byte = 0_u8
            bit_pos = 0
          end
        end
      end

      if bit_pos > 0
        result << current_byte
      end
      EncodedResult.new(Slice.new(result.to_unsafe, result.size), total_bits, frequencies)
    end

    property size : Int64
    property result : UInt32
    getter test_data : Bytes
    getter encoded : EncodedResult

    def initialize
      @size = config_val("size")
      @result = 0_u32
      @test_data = Bytes.new(0)
      @encoded = EncodedResult.new(Bytes.new(0), 0)
    end

    def prepare
      @test_data = Compress.generate_test_data(@size)
    end

    def run(iteration_id)
      frequencies = Array.new(256, 0)
      @test_data.each do |byte|
        frequencies[byte] += 1
      end

      tree = HuffEncode.build_huffman_tree(frequencies)
      codes = HuffmanCodes.new
      build_huffman_codes(tree, 0, 0, codes)
      @encoded = huffman_encode(@test_data, codes, frequencies)
      @result &+= @encoded.data.bytesize.to_u32
    end

    def checksum : UInt32
      @result
    end
  end

  class HuffDecode < Benchmark
    private def huffman_decode(encoded : Bytes, root : HuffEncode::HuffmanNode, bit_count : Int32) : Bytes
      result = Bytes.new(bit_count)

      current_node = root
      bits_processed = 0
      byte_index = 0
      result_size = 0

      while bits_processed < bit_count && byte_index < encoded.size
        byte_val = encoded[byte_index]
        byte_index += 1

        7.downto(0) do |bit_pos|
          break if bits_processed >= bit_count

          bit = ((byte_val >> bit_pos) & 1) == 1
          bits_processed += 1

          current_node = bit ? current_node.right.not_nil! : current_node.left.not_nil!

          if current_node.is_leaf
            result[result_size] = current_node.byte_val
            result_size += 1
            current_node = root
          end
        end
      end

      result[0...result_size]
    end

    property size : Int64
    property result : UInt32
    getter test_data : Bytes
    getter decoded : Bytes
    private property encoded : HuffEncode::EncodedResult

    def initialize
      @size = config_val("size")
      @result = 0_u32
      @test_data = Bytes.new(0)
      @decoded = Bytes.new(0)
      @encoded = HuffEncode::EncodedResult.new
    end

    def prepare
      @test_data = Compress.generate_test_data(@size)
      encoder = HuffEncode.new
      encoder.size = @size
      encoder.prepare
      encoder.run(0)
      @encoded = encoder.encoded
    end

    def run(iteration_id)
      tree = HuffEncode.build_huffman_tree(@encoded.frequencies)
      @decoded = huffman_decode(@encoded.data, tree, @encoded.bit_count)
      @result &+= @decoded.bytesize.to_u32
    end

    def checksum : UInt32
      if @decoded == @test_data
        @result &+= 100_000
      end
      @result
    end
  end

  class ArithEncode < Benchmark
    struct ArithEncodedResult
      property data : Bytes
      property bit_count : Int32
      property frequencies : Array(Int32)

      def initialize(@data : Bytes = Bytes.new(0), @bit_count : Int32 = 0, @frequencies : Array(Int32) = Array(Int32).new)
      end
    end

    class ArithFreqTable
      property total : Int32
      property low : Array(Int32)
      property high : Array(Int32)

      def initialize(frequencies : Array(Int32))
        @total = frequencies.sum
        @low = Array.new(256, 0)
        @high = Array.new(256, 0)

        cum = 0
        256.times do |i|
          @low[i] = cum
          cum += frequencies[i]
          @high[i] = cum
        end
      end

      def initialize(@total : Int32, @low : Array(Int32), @high : Array(Int32))
      end
    end

    class BitOutputStream
      @buffer : UInt8 = 0_u8
      @bit_pos : Int32 = 0
      @bytes : Array(UInt8) = [] of UInt8
      @bits_written : Int32 = 0

      def write_bit(bit : Int32)
        @buffer <<= 1
        @buffer |= 1 if bit == 1
        @bit_pos += 1
        @bits_written += 1

        if @bit_pos == 8
          @bytes << @buffer
          @buffer = 0_u8
          @bit_pos = 0
        end
      end

      def flush : Bytes
        if @bit_pos > 0
          @buffer <<= (8 - @bit_pos)
          @bytes << @buffer
        end
        Bytes.new(@bytes.to_unsafe, @bytes.size)
      end

      def bits_written : Int32
        @bits_written
      end
    end

    private def arith_encode(data : Bytes) : ArithEncodedResult
      frequencies = Array.new(256, 0)
      data.each do |byte|
        frequencies[byte] += 1
      end

      freq_table = ArithFreqTable.new(frequencies)

      low = 0_u64
      high = 0xFFFFFFFF_u64
      pending = 0
      output = BitOutputStream.new

      ht = freq_table.high
      lt = freq_table.low
      data.each do |byte|
        range = (high - low + 1).to_u64

        high = low + (range * ht[byte] // freq_table.total) - 1
        low = low + (range * lt[byte] // freq_table.total)

        loop do
          if high < 0x80000000_u64
            output.write_bit(0)
            pending.times { output.write_bit(1) }
            pending = 0
          elsif low >= 0x80000000_u64
            output.write_bit(1)
            pending.times { output.write_bit(0) }
            pending = 0
            low -= 0x80000000_u64
            high -= 0x80000000_u64
          elsif low >= 0x40000000_u64 && high < 0xC0000000_u64
            pending += 1
            low -= 0x40000000_u64
            high -= 0x40000000_u64
          else
            break
          end

          low <<= 1
          high = (high << 1) | 1
          high &= 0xFFFFFFFF_u64
        end
      end

      pending += 1
      if low < 0x40000000_u64
        output.write_bit(0)
        pending.times { output.write_bit(1) }
      else
        output.write_bit(1)
        pending.times { output.write_bit(0) }
      end

      ArithEncodedResult.new(
        output.flush,
        output.bits_written,
        frequencies
      )
    end

    property size : Int64
    property result : UInt32
    getter test_data : Bytes
    getter encoded : ArithEncodedResult

    def initialize
      @size = config_val("size")
      @result = 0_u32
      @test_data = Bytes.new(0)
      @encoded = ArithEncodedResult.new
    end

    def prepare
      @test_data = Compress.generate_test_data(@size)
    end

    def run(iteration_id)
      @encoded = arith_encode(@test_data)
      @result &+= @encoded.data.size.to_u32
    end

    def checksum : UInt32
      @result
    end
  end

  class ArithDecode < Benchmark
    class BitInputStream
      @bytes : Bytes
      @byte_pos : Int32 = 0
      @bit_pos : Int32 = 0
      @current_byte : UInt8 = 0_u8

      def initialize(@bytes : Bytes)
        @current_byte = @bytes[0] if @bytes.size > 0
      end

      def read_bit : Int32
        if @bit_pos == 8
          @byte_pos += 1
          @bit_pos = 0
          @current_byte = @byte_pos < @bytes.size ? @bytes[@byte_pos] : 0_u8
        end

        bit = (@current_byte >> (7 - @bit_pos)) & 1
        @bit_pos += 1
        bit.to_i32
      end
    end

    property size : Int64
    property result : UInt32
    getter test_data : Bytes
    getter decoded : Bytes
    property encoded : ArithEncode::ArithEncodedResult

    def initialize
      @size = config_val("size")
      @result = 0_u32
      @test_data = Bytes.new(0)
      @decoded = Bytes.new(0)
      @encoded = ArithEncode::ArithEncodedResult.new
    end

    def prepare
      @test_data = Compress.generate_test_data(@size)

      encoder = ArithEncode.new
      encoder.size = @size
      encoder.prepare
      encoder.run(0)
      @encoded = encoder.encoded
    end

    def run(iteration_id)
      @decoded = arith_decode(@encoded)
      @result &+= @decoded.size.to_u32
    end

    def checksum : UInt32
      if @decoded == @test_data
        @result &+= 100_000
      end
      @result
    end

    private def arith_decode(encoded : ArithEncode::ArithEncodedResult) : Bytes
      frequencies = encoded.frequencies
      total = frequencies.sum
      data_size = total

      low_table = StaticArray(Int32, 256).new(0)
      high_table = StaticArray(Int32, 256).new(0)
      cum = 0
      256.times do |i|
        low_table[i] = cum
        cum += frequencies[i]
        high_table[i] = cum
      end

      result = Bytes.new(data_size)
      input = BitInputStream.new(encoded.data)

      value = 0_u64
      32.times do
        value = (value << 1) | input.read_bit.to_u64
      end

      low = 0_u64
      high = 0xFFFFFFFF_u64

      data_size.times do |j|
        range = (high - low + 1).to_u64
        scaled = ((value - low + 1) * total - 1) // range

        symbol = 0_u8
        while symbol < 255 && high_table[symbol] <= scaled
          symbol += 1_u8
        end

        result[j] = symbol

        high = low + (range * high_table[symbol] // total) - 1
        low = low + (range * low_table[symbol] // total)

        loop do
          if high < 0x80000000_u64
          elsif low >= 0x80000000_u64
            value -= 0x80000000_u64
            low -= 0x80000000_u64
            high -= 0x80000000_u64
          elsif low >= 0x40000000_u64 && high < 0xC0000000_u64
            value -= 0x40000000_u64
            low -= 0x40000000_u64
            high -= 0x40000000_u64
          else
            break
          end

          low <<= 1
          high = (high << 1) | 1
          value = (value << 1) | input.read_bit.to_u64
        end
      end

      result
    end
  end

  class LZWEncode < Benchmark
    struct LZWResult
      property data : Bytes
      property dict_size : Int32

      def initialize(@data = Bytes.new(0), @dict_size = 0)
      end
    end

    def lzw_encode(input : Bytes) : LZWResult
      return LZWResult.new(Bytes.new(0), 256) if input.empty?

      dict = Hash(String, Int32).new(initial_capacity: 4096)
      256.times do |i|
        dict[i.chr.to_s] = i
      end

      next_code = 256
      result = IO::Memory.new(input.size * 2)

      current = input[0].chr.to_s

      (1...input.size).each do |i|
        next_char = input[i].chr
        new_str = current + next_char

        if dict.has_key?(new_str)
          current = new_str
        else
          code = dict[current]
          result.write_byte((code >> 8).to_u8)
          result.write_byte((code & 0xFF).to_u8)

          dict[new_str] = next_code
          next_code += 1
          current = next_char.to_s
        end
      end

      code = dict[current]
      result.write_byte((code >> 8).to_u8)
      result.write_byte((code & 0xFF).to_u8)

      LZWResult.new(result.to_slice, next_code)
    end

    property size : Int64
    property result : UInt32
    getter test_data : Bytes
    getter encoded : LZWResult

    def initialize
      @size = config_val("size")
      @result = 0_u32
      @test_data = Bytes.new(0)
      @encoded = LZWResult.new
    end

    def prepare
      @test_data = Compress.generate_test_data(@size)
    end

    def run(iteration_id)
      @encoded = lzw_encode(@test_data)
      @result &+= @encoded.data.size.to_u32
    end

    def checksum : UInt32
      @result
    end
  end

  class LZWDecode < Benchmark
    def lzw_decode(encoded : LZWEncode::LZWResult) : Bytes
      return Bytes.new(0) if encoded.data.empty?

      dict = Array(String).new(4096)

      256.times do |i|
        dict << i.chr.to_s
      end

      result = IO::Memory.new(encoded.data.bytesize * 2)
      data = encoded.data
      pos = 0

      high = data[pos].to_u16
      low = data[pos + 1].to_u16
      old_code = (high << 8) | low
      pos += 2

      old_str = dict[old_code]
      result.write(old_str.to_slice)

      next_code = 256

      while pos < data.size
        high = data[pos].to_u16
        low = data[pos + 1].to_u16
        new_code = (high << 8) | low
        pos += 2

        if new_code < dict.size
          new_str = dict[new_code]
        elsif new_code == next_code
          new_str = old_str + old_str[0]
        else
          raise "Error decode"
        end

        result.write(new_str.to_slice)

        dict << old_str + new_str[0]
        next_code += 1

        old_str = new_str
      end

      result.to_slice
    end

    property size : Int64
    property result : UInt32
    getter test_data : Bytes
    getter decoded : Bytes
    private property encoded : LZWEncode::LZWResult

    def initialize
      @size = config_val("size")
      @result = 0_u32
      @test_data = Bytes.new(0)
      @decoded = Bytes.new(0)
      @encoded = LZWEncode::LZWResult.new
    end

    def prepare
      @test_data = Compress.generate_test_data(@size)
      encoder = LZWEncode.new
      encoder.size = @size
      encoder.prepare
      encoder.run(0)
      @encoded = encoder.encoded
    end

    def run(iteration_id)
      @decoded = lzw_decode(@encoded)
      @result &+= @decoded.bytesize.to_u32
    end

    def checksum : UInt32
      if @decoded == @test_data
        @result &+= 100_000
      end
      @result
    end
  end
end

module Distance
  def self.generate_pair_strings(n, m)
    pairs = [] of Tuple(String, String)
    chars = ('a'..'j').to_a

    n.times do
      len1 = Helper.next_int(m) + 4
      len2 = Helper.next_int(m) + 4

      str1 = String.build(len1) { |io| len1.times { io << chars[Helper.next_int(10)] } }
      str2 = String.build(len2) { |io| len2.times { io << chars[Helper.next_int(10)] } }

      pairs << {str1, str2}
    end

    pairs
  end

  class Jaro < Benchmark
    @count : Int64
    @size : Int64
    @pairs : Array(Tuple(String, String))
    @result : UInt32

    def initialize
      @pairs = [] of Tuple(String, String)
      @result = 0_u32
      @count = config_val("count").to_i64
      @size = config_val("size").to_i64
    end

    def prepare
      @pairs = Distance.generate_pair_strings(@count, @size)
    end

    def jaro(s1 : String, s2 : String) : Float64
      s1 = s1.bytes
      s2 = s2.bytes
      len1 = s1.size
      len2 = s2.size

      return 0.0 if len1 == 0 || len2 == 0

      match_dist = {len1, len2}.max // 2 - 1
      match_dist = 0 if match_dist < 0

      s1_matches = Array(Bool).new(len1, false)
      s2_matches = Array(Bool).new(len2, false)

      matches = 0
      len1.times do |i|
        start = {0, i - match_dist}.max
        fin = {len2 - 1, i + match_dist}.min

        (start..fin).each do |j|
          if !s2_matches[j] && s1[i] == s2[j]
            s1_matches[i] = true
            s2_matches[j] = true
            matches += 1
            break
          end
        end
      end

      return 0.0 if matches == 0

      k = 0
      transpositions = 0
      len1.times do |i|
        if s1_matches[i]
          while k < len2 && !s2_matches[k]
            k += 1
          end
          if k < len2
            transpositions += 1 if s1[i] != s2[k]
            k += 1
          end
        end
      end
      transpositions //= 2

      m = matches.to_f
      (m/len1 + m/len2 + (m - transpositions)/m) / 3.0
    end

    def run(iteration_id)
      @pairs.each do |(s1, s2)|
        @result &+= (jaro(s1, s2) * 1000).to_u32
      end
    end

    def checksum : UInt32
      @result
    end
  end

  class NGram < Benchmark
    @count : Int64
    @size : Int64
    @pairs : Array(Tuple(String, String))
    @result : UInt32

    def initialize
      @pairs = [] of Tuple(String, String)
      @result = 0_u32
      @count = config_val("count").to_i64
      @size = config_val("size").to_i64
    end

    def prepare
      @pairs = Distance.generate_pair_strings(@count, @size)
    end

    def ngram(s1 : String, s2 : String) : Float64
      bytes1 = s1.bytes
      bytes2 = s2.bytes
      len1 = bytes1.size
      len2 = bytes2.size

      grams1 = Hash(UInt32, Int32).new(initial_capacity: len1) { 0 }

      (0..len1 - 4).each do |i|
        gram = (bytes1[i].to_u32 << 24) |
               (bytes1[i + 1].to_u32 << 16) |
               (bytes1[i + 2].to_u32 << 8) |
               bytes1[i + 3].to_u32
        grams1.update(gram, &.+(1))
      end

      grams2 = Hash(UInt32, Int32).new(initial_capacity: len2) { 0 }
      intersection = 0

      (0..len2 - 4).each do |i|
        gram = (bytes2[i].to_u32 << 24) |
               (bytes2[i + 1].to_u32 << 16) |
               (bytes2[i + 2].to_u32 << 8) |
               bytes2[i + 3].to_u32
        grams2.update(gram, &.+(1))

        if (v = grams1[gram]?) && grams2[gram] <= v
          intersection += 1
        end
      end

      total = grams1.size + grams2.size
      total > 0 ? intersection.to_f / total : 0.0
    end

    def run(iteration_id)
      @pairs.each do |(s1, s2)|
        @result &+= (ngram(s1, s2) * 1000).to_u32
      end
    end

    def checksum : UInt32
      @result
    end
  end
end

File.write("/tmp/recompile_marker", "RECOMPILE_MARKER_0")
