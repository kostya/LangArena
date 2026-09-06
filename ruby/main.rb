require "base64"
require "json"
require "csv"
require "stringio"

puts("start: #{(Time.now.to_f * 1000).to_i}")

module Helper
  IM = 139968
  IA = 3877
  IC = 29573
  INIT = 42

  @last = INIT

  RAW_CONFIG = begin
    JSON.parse(File.read(ARGV[0] || "../run.js"))
  end

  CONFIG = begin
    hash = {}
    RAW_CONFIG.each do |cfg|
      name = cfg["name"]
      hash[name] = cfg
    end

    hash
  end

  class << self
    attr_accessor :last

    def reset
      @last = INIT
    end

    def next_int(max)
      Helper.last = (Helper.last * IA + IC) % IM
      (Helper.last.to_f / IM * max).to_i
    end

    def next_int_range(from, to)
      next_int(to - from + 1) + from
    end

    def next_float(max = 1.0)
      Helper.last = (Helper.last * IA + IC) % IM
      max * Helper.last.to_f / IM
    end

    def checksum(v)
      hash = 5381
      if v.is_a?(String)
        v.each_byte do |byte|
          hash = (((hash << 5) + hash) + byte) & 0xFFFFFFFF
        end
      elsif v.is_a?(Array)
        v.each do |byte|
          hash = (((hash << 5) + hash) + byte) & 0xFFFFFFFF
        end
      end

      hash & 0xFFFFFFFF
    end

    def checksum_f64(v)
      Helper.checksum("%.7f" % v)
    end

    def config_i64(class_name, field_name)
      if cfg = CONFIG[class_name]
        value = cfg[field_name]
        if value
          value.to_i
        else
          raise "Config for #{class_name}, not found i64 field: #{field_name} in #{cfg.inspect}"
        end
      else
        raise "Config not found class #{class_name}"
      end
    end

    def config_s(class_name, field_name)
      if cfg = CONFIG[class_name]
        value = cfg[field_name]
        if value
          value.to_s
        else
          raise "Config for #{class_name}, not found string field: #{field_name} in #{cfg.inspect}"
        end
      else
        raise "Config not found class #{class_name}"
      end
    end
  end
end

class Benchmark
  def run(iteration_id)
    raise NotImplementedError
  end

  def checksum
    raise NotImplementedError
  end

  def prepare
  end

  def self.bench_name
    self.name
  end

  def warmup_iterations
    if cfg = Helper::CONFIG[self.class.bench_name]
      if wi = cfg["warmup_iterations"]
        return wi.to_i
      end
    end

    [(iterations * 0.2).to_i, 1].max
  end

  def warmup
    warmup_iterations.times { |i| run(i) }
  end

  def run_all
    iterations.times { |i| run(i) }
  end

  def config_val(field_name)
    Helper.config_i64(self.class.bench_name, field_name)
  end

  def iterations
    Helper.config_i64(self.class.bench_name, "iterations").to_i
  end

  def expected_checksum
    Helper.config_i64(self.class.bench_name, "checksum")
  end

  def self.run(available_benches, single_bench = nil)
    summary_time = 0.0
    ok = 0
    fails = 0
    single_bench = single_bench.downcase if single_bench

    order = Helper::RAW_CONFIG.map { |cfg| cfg["name"] }
    order.each do |bname|
      next if single_bench && !bname.downcase.include?(single_bench)

      if bench_class = available_benches[bname]
        print("#{bname}: ")

        bench = bench_class.new

        Helper.reset
        bench.prepare
        bench.warmup
        GC.start

        Helper.reset

        t = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        bench.run_all
        time_delta = Process.clock_gettime(Process::CLOCK_MONOTONIC) - t

        GC.start
        sleep(0)
        GC.start

        check = bench.checksum.to_i & 0xFFFFFFFF
        expect = bench.expected_checksum.to_i & 0xFFFFFFFF
        if check == expect
          print("OK ")
          ok += 1
        else
          print("ERR[actual=#{check.inspect}, expected=#{expect.inspect}] ")
          fails += 1
        end

        print("in %.3fs\n" % time_delta)
        summary_time += time_delta
      end
    end

    puts("Summary: %.4fs, %d, %d, %d" % [summary_time, ok + fails, ok, fails])
    exit(1) if fails > 0
  end
end

module Binarytrees
  class Obj < Benchmark
    class TreeNode
      attr_accessor :left, :right, :item

      def initialize(item, depth = 0)
        @item = item
        if depth > 0
          @left = TreeNode.new(item - (2 ** (depth - 1)), depth - 1)
          @right = TreeNode.new(item + (2 ** (depth - 1)), depth - 1)
        end
      end

      def sum
        total = @item + 1
        total += @left.sum if @left
        total += @right.sum if @right
        total
      end
    end

    def initialize(n = config_val("depth"))
      @n = n
      @result = 0
    end

    def run(iteration_id)
      node = TreeNode.new(0, @n)
      @result += node.sum
    end

    def checksum
      @result & 0xFFFFFFFF
    end
  end

  class Arena < Benchmark
    TreeNode = Struct.new(:item, :left, :right)

    def build_tree(item, depth)
      idx = @arena.size
      node = TreeNode.new(item, -1, -1)
      @arena << node

      if depth > 0
        node.left = build_tree(item - (2 ** (depth - 1)), depth - 1)
        node.right = build_tree(item + (2 ** (depth - 1)), depth - 1)
      end

      idx
    end

    def sum(idx)
      node = @arena[idx]
      total = node.item + 1
      total += sum(node.left) if node.left >= 0
      total += sum(node.right) if node.right >= 0
      total
    end

    def initialize(n = config_val("depth"))
      @n = n
      @result = 0
      @arena = []
    end

    def run(iteration_id)
      @arena = []
      build_tree(0, @n)
      @result += sum(0)
    end

    def checksum
      @result & 0xFFFFFFFF
    end
  end
end

module Brainfuck
  class Tape
    attr_accessor :pos

    def initialize
      @tape = ::Array.new(30000, 0)
      @pos = 0
    end

    def get
      @tape[@pos]
    end

    def inc
      @tape[@pos] = (@tape[@pos] + 1) & 0xFF
    end

    def dec
      @tape[@pos] = (@tape[@pos] - 1) & 0xFF
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

  class Array < Benchmark
    def initialize
      @program_text = Helper.config_s(self.class.bench_name, "program")
      @warmup_text = Helper.config_s(self.class.bench_name, "warmup_program")
      @result_val = 0
    end

    def warmup
      prepare_iters = warmup_iterations
      prepare_iters.times { run_program(@warmup_text) }
    end

    def run(iteration_id)
      if result = run_program(@program_text)
        @result_val = (@result_val + result) & 0xFFFFFFFF
      end
    end

    def checksum
      @result_val & 0xFFFFFFFF
    end

    private

    def run_program(source)
      commands = parse_commands(source)
      return nil unless commands

      jumps = build_jump_array(commands)
      return nil unless jumps

      _run(commands, jumps)
    end

    def parse_commands(source)
      source.chars.select do |c|
        c.ascii_only? && "+-<>[].,".include?(c)
      end
    end

    def build_jump_array(commands)
      jumps = ::Array.new(commands.size, 0)
      stack = []

      commands.each_with_index do |cmd, i|
        case cmd
        when "["
          stack << i
        when "]"
          start = stack.pop
          return nil unless start
          jumps[start] = i
          jumps[i] = start
        end
      end

      stack.empty? ? jumps : nil
    end

    def _run(commands, jumps)
      tape = Tape.new
      pc = 0
      result = 0

      while pc < commands.size
        case commands[pc]
        when "+"
          tape.inc
        when "-"
          tape.dec
        when ">"
          tape.adv
        when "<"
          tape.dev
        when "["
          if tape.get == 0
            pc = jumps[pc]
            pc += 1
            next
          end

        when "]"
          if tape.get != 0
            pc = jumps[pc]
            pc += 1
            next
          end

        when "."
          result = (result << 2) & 0xFFFFFFFF
          result = (result + tape.get) & 0xFFFFFFFF
        end

        pc += 1
      end

      result
    rescue
      nil
    end
  end

  class Recursion < Benchmark
    Inc = 1
    Dec = 2
    Advance = 3
    Devance = 4
    Print = 5

    class Program
      attr_reader :result

      def initialize(code)
        it = code.each_char
        @ops = parse(it)
        @result = 0
      end

      def run
        tape = Tape.new
        run_ops(@ops, tape)
      end

      def run_ops(ops, tape)
        ops.each do |op|
          case op
          when Inc
            tape.inc
          when Dec
            tape.dec
          when Advance
            tape.adv
          when Devance
            tape.dev
          when Print
            @result = ((@result << 2) + tape.get) & 0xFFFFFFFFFFFFFFFF
          else
            while tape.get != 0
              run_ops(op, tape)
            end
          end
        end
      end

      private

      def parse(it)
        ops = []
        loop do
          c = it.next
          case c
          when "+"
            ops << Inc
          when "-"
            ops << Dec
          when ">"
            ops << Advance
          when "<"
            ops << Devance
          when "."
            ops << Print
          when "["
            ops << parse(it)
          when "]"
            break
          end
        end

        ops
      rescue StopIteration
        ops
      end
    end

    def initialize
      @text = Helper.config_s(self.class.bench_name, "program")
      @result = 0
    end

    def warmup
      warmup_iterations.times do
        run_text(Helper.config_s(self.class.bench_name, "warmup_program"))
      end
    end

    def run_text(text)
      prog = Program.new(text)
      prog.run
      prog.result
    end

    def run(iteration_id)
      @result = (@result + run_text(@text).to_i) & 0xFFFFFFFF
    end

    def checksum
      @result & 0xFFFFFFFF
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

    def initialize(n = config_val("n"))
      @n = n
      @result = 0
      @a = Matmul.matgen(@n, 1.0)
      @b = Matmul.matgen(@n, 1.0)
    end

    def run(iteration_id)
      c = matmul(@n, @a, @b)
      v = c[@n >> 1][@n >> 1]
      @result = (@result + Helper.checksum_f64(v)) & 0xFFFFFFFF
    end

    def checksum
      @result & 0xFFFFFFFF
    end
  end

  class T4 < Single
    def initialize(n = config_val("n"))
      super(n)
      @num_threads = num_threads
    end

    def matmul_parallel(n, threads, a, b)
      t = Array.new(n) { Array.new(n, 0.0) }
      n.times do |i|
        n.times do |j|
          t[j][i] = b[i][j]
        end
      end

      c = Array.new(n) { Array.new(n, 0.0) }
      rows_per_worker = (n + threads - 1) / threads

      threads
        .times
        .map do |worker_id|
          Thread.new do
            start_row = worker_id * rows_per_worker
            end_row = [start_row + rows_per_worker, n].min

            (start_row...end_row).each do |i|
              ai = a[i]
              ci = c[i]

              t.each_with_index do |tj, j|
                s = 0.0
                ai.zip(tj) { |av, tv| s += av * tv }
                ci[j] = s
              end
            end
          end
        end
        .each(&:join)

      c
    end

    def num_threads
      4
    end

    def run(iteration_id)
      c = matmul_parallel(@n, num_threads, @a, @b)
      v = c[@n >> 1][@n >> 1]
      @result = (@result + Helper.checksum_f64(v)) & 0xFFFFFFFF
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
    def initialize(n = config_val("size"))
      @n = n
      @str = String.new
      @str2 = String.new
      @result = 0
    end

    def prepare
      @str = "a" * @n
      @str2 = Base64.strict_encode64(@str)
    end

    def run(iteration_id)
      @str2 = Base64.strict_encode64(@str)
      @result = (@result + @str2.bytesize) & 0xFFFFFFFF
    end

    def checksum
      Helper.checksum("encode #{@str[0..3]}... to #{@str2[0..3]}...: #{@result}")
    end
  end

  class Decode < Benchmark
    def initialize(n = config_val("size"))
      @n = n
      @str2 = ""
      @str3 = ""
      @result = 0
    end

    def prepare
      str = "a" * @n
      @str2 = Base64.strict_encode64(str)
      @str3 = Base64.strict_decode64(@str2)
    end

    def run(iteration_id)
      @str3 = Base64.strict_decode64(@str2)
      @result = (@result + @str3.bytesize) & 0xFFFFFFFF
    end

    def checksum
      Helper.checksum("decode #{@str2[0..3]}... to #{@str3[0..3]}...: #{@result}")
    end
  end
end

module Json
  class Coordinate
    attr_accessor :x, :y, :z, :name, :opts

    def initialize(x, y, z, name, opts)
      @x = x
      @y = y
      @z = z
      @name = name
      @opts = opts
    end

    def to_json(*args)
      {
        x: @x,
        y: @y,
        z: @z,
        name: @name,
        opts: @opts
      }.to_json(*args)
    end
  end

  class Generate < Benchmark
    def initialize(n = config_val("coords"))
      @n = n
      @text = ""
      @data = []
      @n.times do
        @data <<
          Coordinate.new(
            Helper.next_float.round(8),
            Helper.next_float.round(8),
            Helper.next_float.round(8),
            "%.7f %d" % [Helper.next_float, Helper.next_int(10_000)],
            {"1" => [1, true]}
          )
      end

      @result = 0
    end

    def run(iteration_id)
      json_data = {
        coordinates: @data,
        info: "some info"
      }
      @text = JSON.generate(json_data)
      if @text.start_with?("{\"coordinates\":")
        @result += 1
      end

      true
    end

    def text
      @text
    end

    def checksum
      @result & 0xFFFFFFFF
    end
  end

  class ParseDom < Benchmark
    def calc(text)
      jobj = JSON.parse(text)
      coordinates = jobj["coordinates"]
      len = coordinates.size.to_f
      x = y = z = 0.0

      coordinates.each do |coord|
        x += coord["x"]
        y += coord["y"]
        z += coord["z"]
      end

      [x / len, y / len, z / len]
    end

    def initialize
      @text = ""
      @result = 0
    end

    def prepare
      j = Generate.new(config_val("coords"))
      j.run(0)
      @text = j.text
    end

    def run(iteration_id)
      x, y, z = calc(@text)
      @result = (@result + Helper.checksum_f64(x) + Helper.checksum_f64(y) + Helper.checksum_f64(z)) & 0xFFFFFFFF
    end

    def checksum
      @result & 0xFFFFFFFF
    end
  end

  class ParseMapping < ParseDom
    def calc(text)
      jobj = JSON.parse(text)
      coordinates = jobj["coordinates"]
      len = coordinates.size.to_f
      x = y = z = 0.0

      coords = []
      coordinates.each do |coord|
        coords << Coordinate.new(coord["x"], coord["y"], coord["z"], nil, nil)
      end

      coords.each do |coord|
        x += coord.x
        y += coord.y
        z += coord.z
      end

      [x / len, y / len, z / len]
    end
  end
end

module Etc
  class Sieve < Benchmark
    attr_accessor :limit
    attr_reader :list

    def initialize(limit = config_val("limit"))
      @limit = limit
      @checksum = 0
      @list = []
    end

    def run(iteration_id)
      primes = Array.new(@limit + 1, 1)
      primes[0] = primes[1] = 0

      limit = @limit
      sqrt_limit = Math.sqrt(limit).to_i

      2.upto(sqrt_limit) do |p|
        if primes[p] == 1
          start = p * p
          (start..limit).step(p) do |multiple|
            primes[multiple] = 0
          end
        end
      end

      last_prime = 2
      count = 1

      n = 3
      while n <= limit
        if primes[n] == 1
          last_prime = n
          count += 1
        end

        n += 2
      end

      @checksum = (@checksum + last_prime + count) & 0xFFFFFFFF
    end

    def checksum
      @checksum & 0xFFFFFFFF
    end
  end

  class TextRaytracer < Benchmark
    Vector = Struct.new(:x, :y, :z) do
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
        x * other.x + y * other.y + z * other.z
      end

      def magnitude
        Math.sqrt(dot(self))
      end

      def normalize
        scale(1.0 / magnitude)
      end
    end

    Ray = Struct.new(:orig, :dir)

    Color = Struct.new(:r, :g, :b) do
      def scale(s)
        Color.new(r * s, g * s, b * s)
      end

      def +(other)
        Color.new(r + other.r, g + other.g, b + other.b)
      end
    end

    Sphere = Struct.new(:center, :radius, :color) do
      def get_normal(pt)
        (pt - center).normalize
      end
    end

    Light = Struct.new(:position, :color)

    Hit = Struct.new(:obj, :value)

    WHITE = Color.new(1.0, 1.0, 1.0)
    RED = Color.new(1.0, 0.0, 0.0)
    GREEN = Color.new(0.0, 1.0, 0.0)
    BLUE = Color.new(0.0, 0.0, 1.0)

    LIGHT1 = Light.new(Vector.new(0.7, -1.0, 1.7), WHITE)

    def shade_pixel(ray, obj, tval)
      pi = ray.orig + ray.dir.scale(tval)
      color = diffuse_shading(pi, obj, LIGHT1)
      col = (color.r + color.g + color.b) / 3.0
      (col * 6.0).to_i
    end

    def intersect_sphere(ray, center, radius)
      l = center - ray.orig
      tca = l.dot(ray.dir)
      return nil if tca < 0.0

      d2 = l.dot(l) - tca * tca
      r2 = radius * radius
      return nil if d2 > r2

      thc = Math.sqrt(r2 - d2)
      t0 = tca - thc

      return nil if t0 > 10_000

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
      lam2 = clamp(lam1, 0.0, 1.0)
      light.color.scale(lam2 * 0.5) + obj.color.scale(0.3)
    end

    LUT = [".", "-", "+", "*", "X", "M"].map(&:ord)

    SCENE = [
      Sphere.new(Vector.new(-1.0, 0.0, 3.0), 0.3, RED),
      Sphere.new(Vector.new(0.0, 0.0, 3.0), 0.8, GREEN),
      Sphere.new(Vector.new(1.0, 0.0, 3.0), 0.4, BLUE)
    ]

    def initialize(w = config_val("w").to_i, h = config_val("h").to_i)
      @w = w
      @h = h
      @res = 0
    end

    def run(iteration_id)
      res = 0
      (0...@h).each do |j|
        (0...@w).each do |i|
          fw, fi, fj, fh = @w.to_f, i.to_f, j.to_f, @h.to_f

          ray = Ray.new(
            Vector.new(0.0, 0.0, 0.0),
            Vector.new((fi - fw / 2.0) / fw, (fj - fh / 2.0) / fh, 1.0).normalize
          )

          hit = nil

          SCENE.each do |obj|
            ret = intersect_sphere(ray, obj.center, obj.radius)
            if ret
              hit = Hit.new(obj, ret)
              break
            end
          end

          pixel = if hit
            LUT[shade_pixel(ray, hit.obj, hit.value)]
          else
            32
          end

          res = (res + pixel) & 0xFFFFFFFFFFFFFFFF
        end
      end

      @res = (@res + res) & 0xFFFFFFFF
    end

    def checksum
      @res & 0xFFFFFFFF
    end
  end

  class NeuralNet < Benchmark
    class Synapse
      attr_accessor :weight, :prev_weight, :source_neuron, :dest_neuron

      def initialize(source_neuron, dest_neuron)
        @source_neuron = source_neuron
        @dest_neuron = dest_neuron
        @prev_weight = @weight = Helper.next_float * 2 - 1
      end
    end

    class Neuron
      LEARNING_RATE = 1.0
      MOMENTUM = 0.3

      attr_accessor :synapses_in, :synapses_out, :threshold, :prev_threshold, :error, :output

      def initialize
        @prev_threshold = @threshold = Helper.next_float * 2 - 1
        @synapses_in = []
        @synapses_out = []
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
        end *
          derivative
        update_weights(rate)
      end

      def update_weights(rate)
        synapses_in.each do |synapse|
          temp_weight = synapse.weight
          synapse.weight += (rate * LEARNING_RATE * error * synapse.source_neuron.output) +
            (MOMENTUM * (synapse.weight - synapse.prev_weight))
          synapse.prev_weight = temp_weight
        end

        temp_threshold = threshold
        @threshold += (rate * LEARNING_RATE * error * -1) +
          (MOMENTUM * (threshold - prev_threshold))
        @prev_threshold = temp_threshold
      end
    end

    class NeuralNetwork
      def initialize(inputs, hidden, outputs)
        @input_layer = (1..inputs).map { Neuron.new }
        @hidden_layer = (1..hidden).map { Neuron.new }
        @output_layer = (1..outputs).map { Neuron.new }

        @input_layer.each do |source|
          @hidden_layer.each do |dest|
            synapse = Synapse.new(source, dest)
            source.synapses_out << synapse
            dest.synapses_in << synapse
          end
        end

        @hidden_layer.each do |source|
          @output_layer.each do |dest|
            synapse = Synapse.new(source, dest)
            source.synapses_out << synapse
            dest.synapses_in << synapse
          end
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
          neuron.output = input.to_f
        end

        @hidden_layer.each do |neuron|
          neuron.calculate_output if neuron
        end

        @output_layer.each do |neuron|
          neuron.calculate_output if neuron
        end
      end

      def current_outputs
        @output_layer.map(&:output)
      end
    end

    INPUT_00 = [0, 0]
    INPUT_01 = [0, 1]
    INPUT_10 = [1, 0]
    INPUT_11 = [1, 1]
    TARGET_0 = [0]
    TARGET_1 = [1]

    def initialize
      @res = []
      @xor = nil
    end

    def prepare
      @xor = NeuralNetwork.new(2, 10, 1)
    end

    def run(iteration_id)
      xor = @xor

      1000.times do
        xor.train(INPUT_00, TARGET_0)
        xor.train(INPUT_10, TARGET_1)
        xor.train(INPUT_01, TARGET_1)
        xor.train(INPUT_11, TARGET_0)
      end
    end

    def checksum
      @res = []
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
    class LRUCache
      class Node
        attr_accessor :key, :value, :prev, :next

        def initialize(key, value, prev = nil, next_node = nil)
          @key = key
          @value = value
          @prev = prev
          @next = next_node
        end
      end

      def initialize(capacity)
        @capacity = capacity
        @cache = {}
        @head = nil
        @tail = nil
        @size = 0
      end

      def get(key)
        node = @cache[key]
        return nil unless node

        move_to_front(node)
        node.value
      end

      def put(key, value)
        if node = @cache[key]
          node.value = value
          move_to_front(node)
          return
        end

        if @size >= @capacity
          remove_oldest
        end

        node = Node.new(key, value)
        @cache[key] = node
        add_to_front(node)
        @size += 1
      end

      def size
        @size
      end

      private

      def move_to_front(node)
        return if node == @head

        if node.prev
          node.prev.next = node.next
        end

        if node.next
          node.next.prev = node.prev
        end

        if node == @tail
          @tail = node.prev
        end

        node.prev = nil
        node.next = @head
        @head.prev = node if @head
        @head = node

        @tail = node unless @tail
      end

      def add_to_front(node)
        node.next = @head
        @head.prev = node if @head
        @head = node
        @tail = node unless @tail
      end

      def remove_oldest
        return unless @tail

        oldest = @tail
        @cache.delete(oldest.key)

        if oldest.prev
          oldest.prev.next = nil
        end

        @tail = oldest.prev

        @head = nil if @head == oldest

        @size -= 1
      end
    end

    def initialize
      @result = 5432
      @values_size = config_val("values").to_i
      @cache = LRUCache.new(config_val("size").to_i)
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

    def checksum
      @result = ((@result << 5) + @hits) & 0xFFFFFFFF
      @result = ((@result << 5) + @misses) & 0xFFFFFFFF
      @result = ((@result << 5) + @cache.size) & 0xFFFFFFFF
      @result
    end
  end

  class GameOfLife < Benchmark
    class Cell
      attr_accessor :alive, :neighbors

      def initialize(alive = false)
        @alive = alive
        @neighbors = []
        @next_state = false
      end

      def add_neighbor(cell)
        @neighbors << cell
      end

      def compute_next_state
        alive_neighbors = @neighbors.count(&:alive)

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
      attr_reader :width, :height, :cells

      def initialize(width, height)
        @width = width
        @height = height
        @cells = Array.new(@height) { Array.new(@width) { Cell.new } }
        link_neighbors
      end

      private

      def link_neighbors
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

      public

      def next_generation
        @cells.each { |row| row.each(&:compute_next_state) }
        @cells.each { |row| row.each(&:update) }
      end

      def count_alive
        count = 0
        cells.each { |row| row.each { |cell| count += 1 if cell.alive } }
        count
      end

      def compute_hash
        _FNV_OFFSET_BASIS = 2166136261
        _FNV_PRIME = 16777619
        hash = _FNV_OFFSET_BASIS

        cells.each do |row|
          row.each do |cell|
            alive = cell.alive ? 1 : 0
            hash = ((hash ^ alive) * _FNV_PRIME) & 0xFFFFFFFF
          end
        end

        hash
      end
    end

    def initialize
      @width = config_val("w").to_i
      @height = config_val("h").to_i
      @grid = Grid.new(@width, @height)
    end

    def prepare
      @grid.cells.each { |row| row.each { |cell| cell.alive = true if Helper.next_float(1.0) < 0.1 } }
    end

    def run(iteration_id)
      @grid.next_generation
    end

    def checksum
      (@grid.compute_hash + @grid.count_alive) & 0xFFFFFFFF
    end
  end

  class Words < Benchmark
    def initialize(words = config_val("words").to_i, word_len = config_val("word_len").to_i)
      @words = words
      @word_len = word_len
      @text = ""
      @checksum = 0
    end

    def prepare
      chars = ("a".."z").to_a
      @text = String.new
      @words.times do |i|
        word_len = Helper.next_int(@word_len) + Helper.next_int(3) + 3
        word_len.times { @text << chars[Helper.next_int(chars.size)] }
        @text << " " unless i == @words - 1
      end
    end

    def run(iteration_id)
      frequencies = Hash.new(0)
      @text.split(" ") { |w| frequencies[w] += 1 }
      max_word, max_count = frequencies.max_by { |_, v| v }

      @checksum = (@checksum + max_count + Helper.checksum(max_word) + frequencies.size) & 0xFFFFFFFF
    end

    def checksum
      @checksum & 0xFFFFFFFF
    end
  end

  class LogParser < Benchmark
    PATTERNS = {
      "errors" => / [5][0-9]{2} | [4][0-9]{2} /,
      "bots" => /bot|crawler|scanner|spider|indexing|crawl|robot|spider/i,
      "suspicious" => /etc\/passwd|wp-admin|\.\.\//i,
      "ips" => /\d+\.\d+\.\d+\.35/,
      "api_calls" => /\/api\/[^ "]+/,
      "post_requests" => /POST [^ ]* HTTP/,
      "auth_attempts" => /\/login|\/signin/i,
      "methods" => /get|post|put/i,
      "emails" => /[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/,
      "passwords" => /password=[^&\s"]+/,
      "tokens" => /token=[^&\s"]+|api[_-]?key=[^&\s"]+/,
      "sessions" => /session[_-]?id=[^&\s"]+/,
      "peak_hours" => /\[\d+\/\w+\/\d+:1[3-7]:\d+:\d+ [+\-]\d+\]/
    }

    def initialize(lines_count = config_val("lines_count").to_i)
      @lines_count = lines_count
      @checksum = 0
      @log = ""
    end

    IPS = (1..255).map { |i| "192.168.1.#{i}" }
    METHODS = ["GET", "POST", "PUT", "DELETE"]
    PATHS = [
      "/index.html",
      "/api/users",
      "/admin",
      "/images/logo.png",
      "/etc/passwd",
      "/wp-admin/setup.php"
    ]
    STATUSES = [200, 201, 301, 302, 400, 401, 403, 404, 500, 502, 503]
    AGENTS = ["Mozilla/5.0", "Googlebot/2.1", "curl/7.68.0", "scanner/2.0"]
    USERS = ["john", "jane", "alex", "sarah", "mike", "anna", "david", "elena"]
    DOMAINS = ["example.com", "gmail.com", "yahoo.com", "hotmail.com", "company.org", "mail.ru"]

    private

    def generate_log_line(str, i)
      str <<
        IPS[i % IPS.size] <<
        " - - [" <<
        (i % 31).to_s <<
        "/Oct/2023:" <<
        (i % 60).to_s <<
        ":55:36 +0000] \"" <<
        METHODS[i % METHODS.size] <<
        " "
      if i % 3 == 0
        str << "/login?email=" << USERS[i % USERS.size] << (i % 100).to_s << "@" << DOMAINS[i % DOMAINS.size]
        str << "&password=secret" << (i % 10000).to_s
      elsif i % 5 == 0
        str << "/api/data?token=" << ("abcdef123456" * ((i % 3) + 1))
      elsif i % 7 == 0
        str << "/user/profile?session_id=" << ("sess_" + (i * 12345).to_s(16))
      else
        str << PATHS[i % PATHS.size]
      end

      str <<
        " HTTP/1.1\" " <<
        STATUSES[i % STATUSES.size].to_s <<
        " 2326 \"http://" <<
        DOMAINS[i % DOMAINS.size] <<
        "\" \"" <<
        AGENTS[i % AGENTS.size] <<
        "\"\n"
    end

    public

    def prepare
      @log = String.new
      @lines_count.times { |i| generate_log_line(@log, i) }
    end

    def run(iteration_id)
      matches = Hash.new(0)
      PATTERNS.each do |name, regex|
        @log.scan(regex) { matches[name] += 1 }
      end

      @checksum = (@checksum + matches.values.sum) & 0xFFFFFFFF
    end

    def checksum
      @checksum & 0xFFFFFFFF
    end
  end
end

module Template
  class Regex < Benchmark
    FIRST_NAMES = ["John", "Jane", "Bob", "Alice", "Charlie", "Diana", "Sarah", "Mike"]
    LAST_NAMES = ["Smith", "Johnson", "Brown", "Taylor", "Wilson", "Davis", "Miller", "Jones"]
    CITIES = ["New York", "Los Angeles", "Chicago", "Houston", "Phoenix", "San Francisco"]

    LOREM = "Lorem {ipsum} dolor {sit} amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore {et} dolore magna aliqua. "

    def initialize(count = config_val("count").to_i)
      @count = count
      @checksum = 0
      @text = String.new
      @rendered = String.new
      @vars = {}
    end

    def prepare
      @text = String.new
      @text << "<html><body>"
      @text << "<h1>{{TITLE}}</h1>"
      @vars["TITLE"] = "Template title"
      @text << "<p>"
      @text << LOREM
      @text << "</p>"
      @text << "<table>"

      @count.times do |i|
        @text << "<!-- {comment} -->" if i % 3 == 0
        @text << "<tr>"
        @text << "<td>{{ FIRST_NAME#{i} }}</td>"
        @text << "<td>{{LAST_NAME#{i}}}</td>"
        @text << "<td>{{  CITY#{i}  }}</td>"
        @vars["FIRST_NAME#{i}"] = FIRST_NAMES[i % FIRST_NAMES.size]
        @vars["LAST_NAME#{i}"] = LAST_NAMES[i % LAST_NAMES.size]
        @vars["CITY#{i}"] = CITIES[i % CITIES.size]
        @text << "<td>{balance: #{i % 100}}</td>"
        @text << "</tr>\n"
      end

      @text << "</table>"
      @text << "</body></html>"
    end

    REGX = /{{(.*?)}}/

    def run(iteration_id)
      @rendered = @text.gsub(REGX) { @vars.fetch($1.strip, "") }
      @checksum = (@checksum + @rendered.bytesize) & 0xFFFFFFFF
    end

    def checksum
      (@checksum + Helper.checksum(@rendered)) & 0xFFFFFFFF
    end
  end

  class Parse < Regex
    def run(iteration_id)
      @rendered = String.new
      i = 0
      text = @text
      text_size = text.bytesize

      while i < text_size
        if i + 1 < text_size && text[i] == "{" && text[i + 1] == "{"
          j = i + 2
          while j + 1 < text_size
            if text[j] == "}" && text[j + 1] == "}"
              break
            end

            j += 1
          end

          if j + 1 < text_size
            key = text[(i + 2)...j].strip
            @rendered << @vars.fetch(key, "")
            i = j + 2
            next
          end
        end

        @rendered << text[i]
        i += 1
      end

      @checksum = (@checksum + @rendered.bytesize) & 0xFFFFFFFF
    end
  end
end

module Sort
  class SortBenchmark < Benchmark
    def test
      []
    end

    def initialize(size = config_val("size"))
      @size = size
      @result = 0
      @data = []
    end

    def prepare
      @size.times { @data << Helper.next_int(1_000_000) }
    end

    def run(iteration_id)
      @result = (@result + @data[Helper.next_int(@size)]) & 0xFFFFFFFF
      t = test
      @result = (@result + t[Helper.next_int(@size)]) & 0xFFFFFFFF
    end

    def checksum
      @result & 0xFFFFFFFF
    end
  end

  class Quick < SortBenchmark
    def test
      arr = @data.dup
      quick_sort(arr, 0, arr.size - 1)
      arr
    end

    private

    def quick_sort(arr, low, high)
      return if low >= high

      pivot = arr[(low + high) / 2]
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
    def test
      arr = @data.dup
      merge_sort_inplace(arr)
      arr
    end

    private

    def merge_sort_inplace(arr)
      temp = Array.new(arr.size, 0)
      merge_sort_helper(arr, temp, 0, arr.size - 1)
    end

    def merge_sort_helper(arr, temp, left, right)
      return if left >= right

      mid = (left + right) / 2
      merge_sort_helper(arr, temp, left, mid)
      merge_sort_helper(arr, temp, mid + 1, right)
      merge(arr, temp, left, mid, right)
    end

    def merge(arr, temp, left, mid, right)
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
    def test
      arr = @data.dup
      arr.sort!
      arr
    end
  end
end

module Graph
  class GraphPathBenchmark < Benchmark
    class Graph
      attr_accessor :vertices, :jumps, :jump_len, :adj

      def initialize(vertices, jumps = 3, jump_len = 100)
        @vertices = vertices
        @jumps = jumps
        @jump_len = jump_len
        @adj = Array.new(@vertices) { [] }
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
            offset = Helper.next_int(@jump_len) - @jump_len / 2
            u = v + offset

            if u >= 0 && u < @vertices && u != v
              add_edge(v, u)
            end
          end
        end
      end
    end

    def initialize
      vertices = config_val("vertices").to_i
      jumps = config_val("jumps").to_i
      jump_len = config_val("jump_len").to_i
      @graph = Graph.new(vertices, jumps, jump_len)
      @result = 0
    end

    def prepare
      @graph.generate_random
      total_edges = @graph.adj.sum(&:size) / 2
    end

    def test
      0
    end

    def run(iteration_id)
      @result = (@result + test) & 0xFFFFFFFF
    end

    def checksum
      @result & 0xFFFFFFFF
    end
  end

  class BFS < GraphPathBenchmark
    def test
      bfs_shortest_path(0, @graph.vertices - 1)
    end

    private

    def bfs_shortest_path(start, target)
      return 0 if start == target

      visited = Array.new(@graph.vertices, 0)
      queue = [[start, 0]]

      visited[start] = 1

      while !queue.empty?
        v, dist = queue.shift

        @graph.adj[v].each do |neighbor|
          if neighbor == target
            return dist + 1
          end

          if visited[neighbor] == 0
            visited[neighbor] = 1
            queue.push([neighbor, dist + 1])
          end
        end
      end

      -1
    end
  end

  class DFS < GraphPathBenchmark
    def test
      dfs_shortest_path(0, @graph.vertices - 1)
    end

    private

    MAX_INT = 2 ** 31 - 1

    def dfs_shortest_path(start, target)
      return 0 if start == target

      visited = Array.new(@graph.vertices, 0)
      stack = [[start, 0]]
      best_path = MAX_INT

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
            stack << [neighbor, dist + 1]
          end
        end
      end

      best_path == MAX_INT ? -1 : best_path
    end
  end

  class AStar < GraphPathBenchmark
    private

    class PriorityQueue
      def initialize
        @heap = []
        @size = 0
      end

      def empty?
        @size == 0
      end

      def push(vertex, priority)
        if @size >= @heap.size
          @heap << [vertex, priority]
        else
          @heap[@size] = [vertex, priority]
        end

        i = @size
        @size += 1

        while i > 0
          parent = (i - 1) / 2
          break if @heap[parent][1] <= priority
          @heap[i] = @heap[parent]
          i = parent
        end

        @heap[i] = [vertex, priority]
      end

      def pop
        min = @heap[0]
        @size -= 1

        if @size > 0
          last = @heap[@size]
          i = 0

          while true
            left = 2 * i + 1
            right = 2 * i + 2
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

    public

    def test
      astar_shortest_path(0, @graph.vertices - 1)
    end

    private

    def heuristic(v, target)
      target - v
    end

    def astar_shortest_path(start, target)
      return 0 if start == target

      g_score = Array.new(@graph.vertices, 2 ** 31 - 1)
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

module HashModule
  class BufferHashBenchmark < Benchmark
    def test
      0
    end

    def initialize(size = config_val("size"))
      @size = size
      @data = Array.new(@size, 0)
      @result = 0
    end

    def prepare
      @data.size.times { |i| @data[i] = Helper.next_int(256) }
    end

    def run(iteration_id)
      @result = (@result + test) & 0xFFFFFFFF
    end

    def checksum
      @result & 0xFFFFFFFF
    end
  end

  class SHA256 < BufferHashBenchmark
    class SimpleSHA256
      def self.digest(data)
        result = Array.new(32, 0)

        hashes = [
          0x6a09e667,
          0xbb67ae85,
          0x3c6ef372,
          0xa54ff53a,
          0x510e527f,
          0x9b05688c,
          0x1f83d9ab,
          0x5be0cd19
        ]

        data.each_with_index do |byte, i|
          hash_idx = i & 7
          hash = hashes[hash_idx]
          hash = ((hash << 5) + hash + byte) & 0xFFFFFFFF
          hash = ((hash + (hash << 10)) ^ (hash >> 6)) & 0xFFFFFFFF
          hashes[hash_idx] = hash
        end

        8.times do |i|
          hash = hashes[i]
          result[i * 4] = (hash >> 24) & 0xFF
          result[i * 4 + 1] = (hash >> 16) & 0xFF
          result[i * 4 + 2] = (hash >> 8) & 0xFF
          result[i * 4 + 3] = hash & 0xFF
        end

        result
      end
    end

    def self.bench_name
      "Hash::SHA256"
    end

    def test
      bytes = SimpleSHA256.digest(@data)

      result = bytes[0] | (bytes[1] << 8) | (bytes[2] << 16) | (bytes[3] << 24)
      result & 0xFFFFFFFF
    end
  end

  class CRC32 < BufferHashBenchmark
    def self.bench_name
      "Hash::CRC32"
    end

    def test
      crc = 0xFFFFFFFF

      @data.each do |byte|
        crc = (crc ^ byte) & 0xFFFFFFFF
        8.times do
          if (crc & 1) != 0
            crc = ((crc >> 1) ^ 0xEDB88320) & 0xFFFFFFFF
          else
            crc = (crc >> 1) & 0xFFFFFFFF
          end
        end
      end

      (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF
    end
  end
end

module Calculator
  class Int64
    MASK64 = 0xFFFFFFFFFFFFFFFF

    attr_reader :value

    def initialize(value = 0)
      if value.is_a?(Int64)
        @value = value.value
      else
        v = value.to_i
        @value = v & MASK64
        if @value & (1 << 63) != 0
          @value -= (1 << 64)
        end
      end
    end

    def +(other)
      Int64.new(@value + other.value)
    end

    def -(other)
      Int64.new(@value - other.value)
    end

    def *(other)
      Int64.new(@value * other.value)
    end

    def /(other)
      b = other.value
      return Int64.new(0) if b == 0

      a = @value
      if (a >= 0 && b > 0) || (a < 0 && b < 0)
        result = a / b
      else
        result = -(a.abs / b.abs)
      end

      Int64.new(result)
    end

    def %(other)
      b = other.value
      return Int64.new(0) if b == 0
      Int64.new(@value - (self / other).value * b)
    end

    def to_i
      @value
    end
  end

  class Ast < Benchmark
    Number = Struct.new(:value)
    Variable = Struct.new(:name)
    BinaryOp = Struct.new(:op, :left, :right)
    Assignment = Struct.new(:var, :expr)

    def initialize(n = config_val("operations"))
      super()
      @n = n
      @text = ""
      @expressions = []
      @result_value = 0
    end

    def prepare
      @text = generate_random_program(@n)
    end

    def generate_random_program(n)
      lines = []
      lines << "v0 = 1"

      (1..10).each do |i|
        lines << "v#{i} = v#{i - 1} + #{i}"
      end

      n.times do |i|
        v = i + 10
        expr = "v#{v - 1} + "

        choice = Helper.next_int(10)
        case choice
        when 0
          expr += "(v#{v - 1} / 3) * 4 - #{i} / (3 + (18 - v#{v - 2})) % v#{v - 3} + 2 * ((9 - v#{v - 6}) * (v#{v - 5} + 7))"
        when 1
          expr += "v#{v - 1} + (v#{v - 2} + v#{v - 3}) * v#{v - 4} - (v#{v - 5} / v#{v - 6})"
        when 2
          expr += "(3789 - (((v#{v - 7})))) + 1"
        when 3
          expr += "4/2 * (1-3) + v#{v - 9}/v#{v - 5}"
        when 4
          expr += "1+2+3+4+5+6+v#{v - 1}"
        when 5
          expr += "(99999 / v#{v - 3})"
        when 6
          expr += "0 + 0 - v#{v - 8}"
        when 7
          expr += "((((((((((v#{v - 6})))))))))) * 2"
        when 8
          expr += "#{i} * (v#{v - 1} % 6) % 7"
        when 9
          expr += "(1)/(0-v#{v - 5}) + (v#{v - 7})"
        end

        lines << "v#{v} = #{expr}"
      end

      lines.join("\n")
    end

    def run(iteration_id)
      parser = Parser.new(@text)
      parser.parse
      @expressions = parser.expressions

      @result_value = (@result_value + @expressions.size) & 0xFFFFFFFF

      if !@expressions.empty?
        last_expr = @expressions.last
        if last_expr.is_a?(Assignment)
          @result_value = (@result_value + Helper.checksum(last_expr.var)) & 0xFFFFFFFF
        end
      end
    end

    attr_reader :expressions

    class Parser
      attr_reader :expressions

      def initialize(input_str)
        @input = input_str
        @pos = 0
        @chars = @input.chars
        @len = @chars.length
        @current_char = @len > 0 ? @chars[0] : "\\0"
        @expressions = []
      end

      def advance
        @pos += 1
        @current_char = (@pos >= @len) ? "\\0" : @chars[@pos]
      end

      def skip_whitespace
        while @current_char != "\\0" &&
            (@current_char == " " ||
              @current_char == "\t" ||
              @current_char == "\n" ||
              @current_char == "\r")
          advance
        end
      end

      def parse_number
        v = 0
        while @current_char != "\\0" && @current_char >= "0" && @current_char <= "9"
          v = v * 10 + (@current_char.ord - "0".ord)
          advance
        end

        Ast::Number.new(v)
      end

      def parse_variable
        start = @pos
        while @current_char != "\\0" &&
            ((@current_char >= "a" && @current_char <= "z") ||
              (@current_char >= "A" && @current_char <= "Z") ||
              (@current_char >= "0" && @current_char <= "9"))
          advance
        end

        var_name = @input[start...@pos]

        skip_whitespace
        if @current_char == "="
          advance
          expr = parse_expression
          return Ast::Assignment.new(var_name, expr)
        end

        Ast::Variable.new(var_name)
      end

      def parse_factor
        skip_whitespace
        return Ast::Number.new(0) if @current_char == "\\0"

        if @current_char >= "0" && @current_char <= "9"
          return parse_number
        end

        if (@current_char >= "a" && @current_char <= "z") ||
            (@current_char >= "A" && @current_char <= "Z")
          return parse_variable
        end

        if @current_char == "("
          advance
          node = parse_expression
          skip_whitespace
          if @current_char == ")"
            advance
          end

          return node
        end

        advance
        Ast::Number.new(0)
      end

      def parse_term
        node = parse_factor

        while true
          skip_whitespace
          break if @current_char == "\\0"

          if @current_char == "*" || @current_char == "/" || @current_char == "%"
            op = @current_char
            advance
            right = parse_factor
            node = Ast::BinaryOp.new(op, node, right)
          else
            break
          end
        end

        node
      end

      def parse_expression
        node = parse_term

        while true
          skip_whitespace
          break if @current_char == "\\0"

          if @current_char == "+" || @current_char == "-"
            op = @current_char
            advance
            right = parse_term
            node = Ast::BinaryOp.new(op, node, right)
          else
            break
          end
        end

        node
      end

      def parse
        @expressions.clear
        while @current_char != "\\0"
          skip_whitespace
          break if @current_char == "\\0"
          @expressions << parse_expression
        end

        @expressions
      end
    end

    def checksum
      @result_value & 0xFFFFFFFF
    end
  end

  class Interpreter < Benchmark
    class Interpreter
      def initialize
        @variables = {}
      end

      def evaluate(node)
        case node
        when Calculator::Ast::Number
          Int64.new(node.value)
        when Calculator::Ast::Variable
          @variables[node.name] || Int64.new(0)
        when Calculator::Ast::BinaryOp
          left = evaluate(node.left)
          right = evaluate(node.right)

          case node.op
          when "+"
            left + right
          when "-"
            left - right
          when "*"
            left * right
          when "/"
            left / right
          when "%"
            left % right
          else
            Int64.new(0)
          end

        when Calculator::Ast::Assignment
          value = evaluate(node.expr)
          @variables[node.var] = value
          value
        else
          Int64.new(0)
        end
      end

      def run(expressions)
        result = Int64.new(0)
        expressions.each do |expr|
          result = evaluate(expr)
        end

        int_result = result.to_i & 0xFFFFFFFFFFFFFFFF
        if int_result & (1 << 63) != 0
          int_result -= (1 << 64)
        end

        int_result & 0xFFFFFFFF
      end

      def clear
        @variables.clear
      end
    end

    def initialize(n = config_val("operations"))
      super()
      @ast = []
      @result_value = 0
      @n = n
    end

    def prepare
      calculator_ast = Calculator::Ast.new(@n)
      calculator_ast.prepare
      calculator_ast.run(0)
      @ast = calculator_ast.expressions
    end

    def run(iteration_id)
      interpreter = Interpreter.new
      result = interpreter.run(@ast)
      @result_value = (@result_value + result) & 0xFFFFFFFF
    end

    def checksum
      @result_value & 0xFFFFFFFF
    end
  end
end

module Maze
  class Cell
    module Kind
      Wall = 0
      Space = 1
      Start = 2
      Finish = 3
      Border = 4
      Path = 5

      def self.walkable?(kind)
        kind == Space || kind == Start || kind == Finish
      end
    end

    attr_accessor :kind, :neighbors, :x, :y

    def initialize(x, y)
      @x = x
      @y = y
      @kind = Kind::Wall
      @neighbors = []
    end

    def reset
      @kind = Kind::Wall if @kind == Kind::Space
    end
  end

  class Generator < Benchmark
    class Maze
      attr_accessor :cells, :start, :finish

      def initialize(w, h)
        @w = w
        @h = h
        @cells = Array.new(@h) { |y| Array.new(@w) { |x| Cell.new(x, y) } }
        @start = @cells[1][1]
        @finish = @cells[@h - 2][@w - 2]
        @start.kind = Cell::Kind::Start
        @finish.kind = Cell::Kind::Finish
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
                if i != j
                  cell.neighbors[i], cell.neighbors[j] = cell.neighbors[j], cell.neighbors[i]
                end
              end
            else
              cell.kind = Cell::Kind::Border
            end
          end
        end
      end

      def reset
        @cells.each { |row| row.each(&:reset) }
        @start.kind = Cell::Kind::Start
        @finish.kind = Cell::Kind::Finish
      end

      def dig(start)
        q = []
        q << start
        while !q.empty?
          cell = q.pop
          if cell.neighbors.count { |n| Cell::Kind.walkable?(n.kind) } == 1
            cell.kind = Cell::Kind::Space
            cell.neighbors.each { |n| q << n if n.kind == Cell::Kind::Wall }
          end
        end
      end

      def ensure_open_finish(cell)
        cell.kind = Cell::Kind::Space
        return if cell.neighbors.count { |n| Cell::Kind.walkable?(n.kind) } > 1
        cell.neighbors.each { |n| ensure_open_finish(n) if n.kind == Cell::Kind::Wall }
      end

      def generate
        @start.neighbors.each { |n| dig(n) if n.kind == Cell::Kind::Wall }
        @finish.neighbors.each { |n| ensure_open_finish(n) if n.kind == Cell::Kind::Wall }
      end

      def middle_cell
        @cells[@h >> 1][@w >> 1]
      end

      def checksum
        hasher = 2166136261
        prime = 16777619

        @cells.each_with_index do |row, y|
          row.each_with_index do |cell, x|
            if cell.kind == Cell::Kind::Space
              j_squared = (x * y) & 0xFFFFFFFF
              hasher = ((hasher ^ j_squared) * prime) & 0xFFFFFFFF
            end
          end
        end

        hasher
      end

      def print_to_console
        @cells.each do |row|
          row.each do |cell|
            sym = case cell.kind
            when Cell::Kind::Space
              " "
            when Cell::Kind::Wall
              "\u001B[34m#\u001B[0m"
            when Cell::Kind::Border
              "\u001B[31mO\u001B[0m"
            when Cell::Kind::Start
              "\u001B[32m>\u001B[0m"
            when Cell::Kind::Finish
              "\u001B[32m<\u001B[0m"
            when Cell::Kind::Path
              "\u001B[33m.\u001B[0m"
            else
              "?"
            end

            print(sym)
          end

          puts
        end

        puts
      end
    end

    attr_reader :width, :height

    def initialize
      @result = 0
      @width = config_val("w").to_i
      @height = config_val("h").to_i
      @maze = Maze.new(@width, @height)
    end

    def run(iteration_id)
      @maze.reset
      @maze.generate
      @result = (@result + @maze.middle_cell.kind) & 0xFFFFFFFF
    end

    def checksum
      (@result + @maze.checksum) & 0xFFFFFFFF
    end
  end

  class BFS < Benchmark
    attr_reader :result, :width, :height

    def initialize
      @result = 0
      @width = config_val("w").to_i
      @height = config_val("h").to_i
      @maze = Generator::Maze.new(@width, @height)
      @path = []
    end

    def prepare
      @maze.generate
    end

    def bfs(start, target)
      return [start] if start == target

      queue = []
      visited = Array.new(@height) { Array.new(@width) { false } }
      path = []

      visited[start.y][start.x] = true
      path << [start, -1]
      queue << 0

      while !queue.empty?
        path_id = queue.shift
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

            return res.reverse
          end

          if Cell::Kind.walkable?(neighbor.kind) && !visited[neighbor.y][neighbor.x]
            visited[neighbor.y][neighbor.x] = true
            path << [neighbor, path_id]
            queue << path.size - 1
          end
        end
      end

      []
    end

    def run(iteration_id)
      @path = bfs(@maze.start, @maze.finish)
      @result = (@result + @path.size) & 0xFFFFFFFF
    end

    def show_path(path)
      path.each { |cell| cell.kind = Cell::Kind::Path }
      @maze.print_to_console
    end

    def checksum
      v = @path[@path.size >> 1]
      (@result + (v.x * v.y)) & 0xFFFFFFFF
    end
  end

  class AStar < Benchmark
    class PriorityQueue
      def initialize(size)
        @heap = []
        @size = 0
        @best_priority = Array.new(size, 2 ** 31 - 1)
      end

      def empty?
        @size == 0
      end

      def push(vertex, priority)
        return if priority >= @best_priority[vertex]

        @best_priority[vertex] = priority

        if @size >= @heap.size
          @heap << [vertex, priority]
        else
          @heap[@size] = [vertex, priority]
        end

        i = @size
        @size += 1

        while i > 0
          parent = (i - 1) / 2
          break if @heap[parent][1] <= priority
          @heap[i] = @heap[parent]
          i = parent
        end

        @heap[i] = [vertex, priority]
      end

      def pop
        min = @heap[0]
        @size -= 1

        if @size > 0
          last = @heap[@size]
          i = 0

          while true
            left = 2 * i + 1
            right = 2 * i + 2
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

    attr_reader :result, :width, :height

    def initialize
      @result = 0
      @width = config_val("w").to_i
      @height = config_val("h").to_i
      @maze = Generator::Maze.new(@width, @height)
      @path = []
    end

    def prepare
      @maze.generate
    end

    private

    def heuristic(a, b)
      (a.x - b.x).abs + (a.y - b.y).abs
    end

    def astar(start, target)
      return [start] if start == target

      width, height = @width, @height
      size = width * height

      start_idx = start.y * width + start.x
      target_idx = target.y * width + target.x

      max_int = 2 ** 31 - 1
      came_from = Array.new(size, -1)
      g_score = Array.new(size, max_int)
      f_score = Array.new(size, max_int)

      open_set = PriorityQueue.new(size)

      g_score[start_idx] = 0
      f_score[start_idx] = heuristic(start, target)
      open_set.push(start_idx, f_score[start_idx])

      while !open_set.empty?
        current_idx, _ = open_set.pop

        if current_idx == target_idx
          return reconstruct_path(came_from, current_idx)
        end

        current_y = current_idx / width
        current_x = current_idx % width
        current = @maze.cells[current_y][current_x]

        current_g = g_score[current_idx]

        current.neighbors.each do |neighbor|
          next unless Cell::Kind.walkable?(neighbor.kind)

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

      []
    end

    def reconstruct_path(came_from, current_idx)
      path = []

      while current_idx != -1
        y = current_idx / @width
        x = current_idx % @width
        path << @maze.cells[y][x]
        current_idx = came_from[current_idx]
      end

      path.reverse
    end

    public

    def run(iteration_id)
      @path = astar(@maze.start, @maze.finish)
      @result = (@result + @path.size) & 0xFFFFFFFF
    end

    def show_path(path)
      path.each { |cell| cell.kind = Cell::Kind::Path }
      @maze.print_to_console
    end

    def checksum
      v = @path[@path.size >> 1]
      (@result + (v.x * v.y)) & 0xFFFFFFFF
    end
  end
end

module CLBG
  class Fannkuchredux < Benchmark
    def fannkuchredux(n)
      perm1 = Array.new(32) { |i| i }
      perm = Array.new(32, 0)
      count = Array.new(32, 0)
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
            perm[i], perm[j] = perm[j], perm[i]
          end

          flipsCount += 1
        end

        maxFlipsCount = flipsCount if flipsCount > maxFlipsCount
        checksum += (permCount % 2 == 0) ? flipsCount : -flipsCount

        loop do
          return [checksum, maxFlipsCount] if r == n

          perm0 = perm1[0]
          (0...r).each do |i|
            j = i + 1
            perm1[i], perm1[j] = perm1[j], perm1[i]
          end

          perm1[r] = perm0
          cntr = count[r] -= 1
          break if cntr > 0
          r += 1
        end

        permCount += 1
      end
    end

    def initialize(n = config_val("n"))
      @n = n
      @result = 0
    end

    def run(iteration_id)
      a, b = fannkuchredux(@n.to_i)
      @result = (@result + a.to_i * 100 + b) & 0xFFFFFFFF
    end

    def checksum
      @result & 0xFFFFFFFF
    end
  end

  class Mandelbrot < Benchmark
    ITER = 50
    LIMIT = 2.0

    def initialize(n = iterations.to_i)
      @n = n
      @result = []
    end

    def run(iteration_id)
      w = config_val("w")
      h = config_val("h")
      "P4\n#{w} #{h}\n".each_byte { |byte| @result << byte }

      bit_num = 0
      byte_acc = 0

      h.times do |y|
        ci = (2.0 * y / h - 1.0)
        w.times do |x|
          zr = zi = tr = ti = 0.0
          cr = (2.0 * x / w - 1.5)

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
            @result << byte_acc
            byte_acc = 0
            bit_num = 0
          elsif x == w - 1
            byte_acc <<= 8 - w % 8
            @result << byte_acc
            byte_acc = 0
            bit_num = 0
          end
        end
      end
    end

    def checksum
      Helper.checksum(@result)
    end
  end

  class Nbody < Benchmark
    SOLAR_MASS = 4 * Math::PI ** 2
    DAYS_PER_YEAR = 365.24

    class Planet
      attr_accessor :x, :y, :z, :vx, :vy, :vz, :mass

      def initialize(x, y, z, vx, vy, vz, mass)
        @x = x
        @y = y
        @z = z
        @vx = vx * DAYS_PER_YEAR
        @vy = vy * DAYS_PER_YEAR
        @vz = vz * DAYS_PER_YEAR
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
        9.54791938424326609e-04
      ),

      Planet.new(
        8.34336671824457987e+00,
        4.12479856412430479e+00,
        -4.03523417114321381e-01,
        -2.76742510726862411e-03,
        4.99852801234917238e-03,
        2.30417297573763929e-05,
        2.85885980666130812e-04
      ),

      Planet.new(
        1.28943695621391310e+01,
        -1.51111514016986312e+01,
        -2.23307578892655734e-01,
        2.96460137564761618e-03,
        2.37847173959480950e-03,
        -2.96589568540237556e-05,
        4.36624404335156298e-05
      ),

      Planet.new(
        1.53796971148509165e+01,
        -2.59193146099879641e+01,
        1.79258772950371181e-01,
        2.68067772490389322e-03,
        1.62824170038242295e-03,
        -9.51592254519715870e-05,
        5.15138902046611451e-05
      )
    ]

    def initialize
      @result = 0
      @bodies = BODIES.map(&:dup)
      @v1 = 0.0
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

    def checksum
      v2 = energy(@bodies)
      ((Helper.checksum_f64(@v1) << 5) & Helper.checksum_f64(v2)) & 0xFFFFFFFF
    end
  end

  class Spectralnorm < Benchmark
    def eval_A(i, j)
      1.0 / ((i + j) * (i + j + 1.0) / 2.0 + i + 1.0)
    end

    def eval_A_times_u(u)
      (0...u.size).map do |i|
        v = 0.0
        u.each_with_index do |uu, j|
          v += eval_A(i, j) * uu
        end

        v
      end
    end

    def eval_At_times_u(u)
      (0...u.size).map do |i|
        v = 0.0
        u.each_with_index do |uu, j|
          v += eval_A(j, i) * uu
        end

        v
      end
    end

    def eval_AtA_times_u(u)
      eval_At_times_u(eval_A_times_u(u))
    end

    def initialize(size = config_val("size"))
      @size = size
      @result = 0
      @u = Array.new(@size, 1.0)
      @v = Array.new(@size, 1.0)
    end

    def run(iteration_id)
      @v = eval_AtA_times_u(@u)
      @u = eval_AtA_times_u(@v)
    end

    def checksum
      vBv = vv = 0.0
      (0...@size).each do |i|
        vBv += @u[i] * @v[i]
        vv += @v[i] * @v[i]
      end

      Helper.checksum_f64(Math.sqrt(vBv / vv))
    end
  end
end

module Compress
  def self.generate_test_data(size)
    pattern = "ABRACADABRA"
    data = Array.new(size, 0)

    size.times do |i|
      data[i] = pattern[i % pattern.bytesize].ord
    end

    data
  end

  class BWTEncode < Benchmark
    class BWTResult
      attr_accessor :transformed, :original_idx

      def initialize(transformed = [], original_idx = 0)
        @transformed = transformed
        @original_idx = original_idx
      end
    end

    private

    def bwt_transform(input)
      n = input.size
      return BWTResult.new([], 0) if n == 0

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
          pairs = Array.new(n) { |i| [rank[i], rank[(i + k) % n]] }

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

      transformed = Array.new(n, 0)
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

    public

    attr_accessor :size, :result
    attr_reader :test_data, :bwt_result

    def initialize
      @size = config_val("size")
      @result = 0
      @test_data = []
      @bwt_result = BWTResult.new
    end

    def prepare
      @test_data = Compress.generate_test_data(@size)
    end

    def run(iteration_id)
      @bwt_result = bwt_transform(@test_data)
      @result = (@result + @bwt_result.transformed.size) & 0xFFFFFFFF
    end

    def checksum
      @result & 0xFFFFFFFF
    end
  end

  class BWTDecode < Benchmark
    private

    def bwt_inverse(bwt_result)
      bwt = bwt_result.transformed
      n = bwt.size
      return [] if n == 0

      counts = Array.new(256, 0)
      bwt.each do |byte|
        counts[byte] += 1
      end

      positions = Array.new(256, 0)
      total = 0
      counts.each_with_index do |count, i|
        positions[i] = total
        total += count
      end

      next_arr = Array.new(n, 0)
      temp_counts = Array.new(256, 0)

      bwt.each_with_index do |byte, i|
        pos = positions[byte] + temp_counts[byte]
        next_arr[pos] = i
        temp_counts[byte] += 1
      end

      result = Array.new(n, 0)
      idx = bwt_result.original_idx

      n.times do |i|
        idx = next_arr[idx]
        result[i] = bwt[idx]
      end

      result
    end

    public

    attr_accessor :size, :result
    attr_reader :test_data, :inverted

    def initialize
      @size = config_val("size")
      @result = 0
      @test_data = []
      @inverted = []
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
      @result = (@result + @inverted.size) & 0xFFFFFFFF
    end

    def checksum
      if @inverted == @test_data
        @result = (@result + 100_000) & 0xFFFFFFFF
      end

      @result & 0xFFFFFFFF
    end
  end

  class HuffEncode < Benchmark
    class HuffmanNode
      attr_accessor :frequency, :byte_val, :is_leaf, :left, :right, :index

      def initialize(frequency = 0, byte_val = 0, is_leaf = true)
        @frequency = frequency
        @byte_val = byte_val
        @is_leaf = is_leaf
        @left = nil
        @right = nil
        @index = 0
      end
    end

    class HuffmanCodes
      attr_accessor :code_lengths, :codes

      def initialize
        @code_lengths = Array.new(256, 0)
        @codes = Array.new(256, 0)
      end
    end

    class EncodedResult
      attr_accessor :frequencies, :data, :bit_count

      def initialize(data = [], bit_count = 0, frequencies = [])
        @data = data
        @bit_count = bit_count
        @frequencies = frequencies
      end
    end

    def self.build_huffman_tree(frequencies)
      nodes = []
      frequencies.each_with_index do |freq, i|
        nodes << HuffmanNode.new(freq, i) if freq > 0
      end

      nodes.sort_by! { |node| node.frequency }

      if nodes.size == 1
        node = nodes.first
        root = HuffmanNode.new(node.frequency, 0, false)
        root.left = node
        root.right = HuffmanNode.new(0, 0)
        return root
      end

      while nodes.size > 1
        left = nodes.shift
        right = nodes.shift

        parent = HuffmanNode.new(
          left.frequency + right.frequency,
          0,
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

    private

    def build_huffman_codes(node, code, length, huffman_codes)
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

    def huffman_encode(data, huffman_codes, frequencies)
      result = []
      current_byte = 0
      bit_pos = 0
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
            current_byte = 0
            bit_pos = 0
          end
        end
      end

      if bit_pos > 0
        result << current_byte
      end

      EncodedResult.new(result, total_bits, frequencies)
    end

    public

    attr_accessor :size, :result
    attr_reader :test_data, :encoded

    def initialize
      @size = config_val("size")
      @result = 0
      @test_data = []
      @encoded = EncodedResult.new([], 0)
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
      @result = (@result + @encoded.data.size) & 0xFFFFFFFF
    end

    def checksum
      @result & 0xFFFFFFFF
    end
  end

  class HuffDecode < Benchmark
    private

    def huffman_decode(encoded, root, bit_count)
      result = Array.new(bit_count, 0)

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

          current_node = bit ? current_node.right : current_node.left

          if current_node.is_leaf
            result[result_size] = current_node.byte_val
            result_size += 1
            current_node = root
          end
        end
      end

      result[0...result_size]
    end

    public

    attr_accessor :size, :result
    attr_reader :test_data, :decoded

    def initialize
      @size = config_val("size")
      @result = 0
      @test_data = []
      @decoded = []
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
      @result = (@result + @decoded.size) & 0xFFFFFFFF
    end

    def checksum
      if @decoded == @test_data
        @result = (@result + 100_000) & 0xFFFFFFFF
      end

      @result & 0xFFFFFFFF
    end
  end

  class ArithEncode < Benchmark
    class ArithEncodedResult
      attr_accessor :data, :bit_count, :frequencies

      def initialize(data = [], bit_count = 0, frequencies = [])
        @data = data
        @bit_count = bit_count
        @frequencies = frequencies
      end
    end

    class ArithFreqTable
      attr_accessor :total, :low, :high

      def initialize(*args)
        if args.size == 1 && args[0].is_a?(Array)
          frequencies = args[0]
          @total = frequencies.sum
          @low = Array.new(256, 0)
          @high = Array.new(256, 0)

          cum = 0
          256.times do |i|
            @low[i] = cum
            cum += frequencies[i]
            @high[i] = cum
          end
        else
          @total = args[0]
          @low = args[1]
          @high = args[2]
        end
      end
    end

    class BitOutputStream
      def initialize
        @buffer = 0
        @bit_pos = 0
        @bytes = []
        @bits_written = 0
      end

      def write_bit(bit)
        @buffer <<= 1
        @buffer |= 1 if bit == 1
        @bit_pos += 1
        @bits_written += 1

        if @bit_pos == 8
          @bytes << @buffer
          @buffer = 0
          @bit_pos = 0
        end
      end

      def flush
        if @bit_pos > 0
          @buffer <<= (8 - @bit_pos)
          @bytes << @buffer
        end

        @bytes
      end

      def bits_written
        @bits_written
      end
    end

    private

    def arith_encode(data)
      frequencies = Array.new(256, 0)
      data.each do |byte|
        frequencies[byte] += 1
      end

      freq_table = ArithFreqTable.new(frequencies)

      low = 0
      high = 0xFFFFFFFF
      pending = 0
      output = BitOutputStream.new

      ht = freq_table.high
      lt = freq_table.low
      data.each do |byte|
        range = (high - low + 1)

        high = low + (range * ht[byte] / freq_table.total) - 1
        low = low + (range * lt[byte] / freq_table.total)

        loop do
          if high < 0x80000000
            output.write_bit(0)
            pending.times { output.write_bit(1) }
            pending = 0
          elsif low >= 0x80000000
            output.write_bit(1)
            pending.times { output.write_bit(0) }
            pending = 0
            low -= 0x80000000
            high -= 0x80000000
          elsif low >= 0x40000000 && high < 0xC0000000
            pending += 1
            low -= 0x40000000
            high -= 0x40000000
          else
            break
          end

          low <<= 1
          high = (high << 1) | 1
          high &= 0xFFFFFFFF
          low &= 0xFFFFFFFF
        end
      end

      pending += 1
      if low < 0x40000000
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

    public

    attr_accessor :size, :result
    attr_reader :test_data, :encoded

    def initialize
      @size = config_val("size")
      @result = 0
      @test_data = []
      @encoded = ArithEncodedResult.new
    end

    def prepare
      @test_data = Compress.generate_test_data(@size)
    end

    def run(iteration_id)
      @encoded = arith_encode(@test_data)
      @result = (@result + @encoded.data.size) & 0xFFFFFFFF
    end

    def checksum
      @result & 0xFFFFFFFF
    end
  end

  class ArithDecode < Benchmark
    class BitInputStream
      def initialize(bytes)
        @bytes = bytes
        @byte_pos = 0
        @bit_pos = 0
        @current_byte = @bytes.size > 0 ? @bytes[0] : 0
      end

      def read_bit
        if @bit_pos == 8
          @byte_pos += 1
          @bit_pos = 0
          @current_byte = @byte_pos < @bytes.size ? @bytes[@byte_pos] : 0
        end

        bit = (@current_byte >> (7 - @bit_pos)) & 1
        @bit_pos += 1
        bit
      end
    end

    attr_accessor :size, :result
    attr_reader :test_data, :decoded, :encoded

    def initialize
      @size = config_val("size")
      @result = 0
      @test_data = []
      @decoded = []
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
      @result = (@result + @decoded.size) & 0xFFFFFFFF
    end

    def checksum
      if @decoded == @test_data
        @result = (@result + 100_000) & 0xFFFFFFFF
      end

      @result & 0xFFFFFFFF
    end

    private

    def arith_decode(encoded)
      frequencies = encoded.frequencies
      total = frequencies.sum
      data_size = total

      low_table = Array.new(256, 0)
      high_table = Array.new(256, 0)
      cum = 0
      256.times do |i|
        low_table[i] = cum
        cum += frequencies[i]
        high_table[i] = cum
      end

      result = Array.new(data_size, 0)
      input = BitInputStream.new(encoded.data)

      value = 0
      32.times do
        value = (value << 1) | input.read_bit
      end

      low = 0
      high = 0xFFFFFFFF

      data_size.times do |j|
        range = (high - low + 1)
        scaled = ((value - low + 1) * total - 1) / range

        symbol = high_table.bsearch_index { |x| x > scaled }
        result[j] = symbol

        high = low + (range * high_table[symbol] / total) - 1
        low = low + (range * low_table[symbol] / total)

        loop do
          if high < 0x80000000
          elsif low >= 0x80000000
            value -= 0x80000000
            low -= 0x80000000
            high -= 0x80000000
          elsif low >= 0x40000000 && high < 0xC0000000
            value -= 0x40000000
            low -= 0x40000000
            high -= 0x40000000
          else
            break
          end

          low <<= 1
          high = (high << 1) | 1
          value = (value << 1) | input.read_bit

          low &= 0xFFFFFFFF
          high &= 0xFFFFFFFF
          value &= 0xFFFFFFFF
        end
      end

      result
    end
  end

  class LZWEncode < Benchmark
    class LZWResult
      attr_accessor :data, :dict_size

      def initialize(data = [], dict_size = 0)
        @data = data
        @dict_size = dict_size
      end
    end

    def lzw_encode(input)
      return LZWResult.new([], 256) if input.empty?

      dict = {}
      256.times do |i|
        dict[i.chr] = i
      end

      next_code = 256
      result = []

      current = input[0].chr

      (1...input.size).each do |i|
        next_char = input[i].chr
        new_str = current + next_char

        if dict.has_key?(new_str)
          current = new_str
        else
          code = dict[current]
          result << ((code >> 8) & 0xFF)
          result << (code & 0xFF)

          dict[new_str] = next_code
          next_code += 1
          current = next_char
        end
      end

      code = dict[current]
      result << ((code >> 8) & 0xFF)
      result << (code & 0xFF)

      LZWResult.new(result, next_code)
    end

    attr_accessor :size, :result
    attr_reader :test_data, :encoded

    def initialize
      @size = config_val("size")
      @result = 0
      @test_data = []
      @encoded = LZWResult.new
    end

    def prepare
      @test_data = Compress.generate_test_data(@size)
    end

    def run(iteration_id)
      @encoded = lzw_encode(@test_data)
      @result = (@result + @encoded.data.size) & 0xFFFFFFFF
    end

    def checksum
      @result & 0xFFFFFFFF
    end
  end

  class LZWDecode < Benchmark
    def lzw_decode(encoded)
      return [] if encoded.data.empty?

      dict = []
      256.times do |i|
        dict << i.chr
      end

      result = []
      data = encoded.data
      pos = 0

      high = data[pos]
      low = data[pos + 1]
      old_code = (high << 8) | low
      pos += 2

      old_str = dict[old_code]
      result.concat(old_str.bytes)

      next_code = 256

      while pos < data.size
        high = data[pos]
        low = data[pos + 1]
        new_code = (high << 8) | low
        pos += 2

        if new_code < dict.size
          new_str = dict[new_code]
        elsif new_code == next_code
          new_str = old_str + old_str[0]
        else
          raise "Error decode"
        end

        result.concat(new_str.bytes)

        dict << old_str + new_str[0]
        next_code += 1

        old_str = new_str
      end

      result
    end

    attr_accessor :size, :result
    attr_reader :test_data, :decoded

    def initialize
      @size = config_val("size")
      @result = 0
      @test_data = []
      @decoded = []
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
      @result = (@result + @decoded.size) & 0xFFFFFFFF
    end

    def checksum
      if @decoded == @test_data
        @result = (@result + 100_000) & 0xFFFFFFFF
      end

      @result & 0xFFFFFFFF
    end
  end
end

module Distance
  def self.generate_pair_strings(n, m)
    pairs = []
    chars = ("a".."j").to_a

    n.times do
      len1 = Helper.next_int(m) + 4
      len2 = Helper.next_int(m) + 4

      str1 = String.new
      len1.times { str1 << chars[Helper.next_int(10)] }

      str2 = String.new
      len2.times { str2 << chars[Helper.next_int(10)] }

      pairs << [str1, str2]
    end

    pairs
  end

  class Jaro < Benchmark
    def initialize
      @pairs = []
      @result = 0
      @count = config_val("count").to_i
      @size = config_val("size").to_i
    end

    def prepare
      @pairs = Distance.generate_pair_strings(@count, @size)
    end

    def jaro(s1, s2)
      bytes1 = s1.bytes
      bytes2 = s2.bytes
      len1 = bytes1.size
      len2 = bytes2.size

      return 0.0 if len1 == 0 || len2 == 0

      match_dist = [len1, len2].max / 2 - 1
      match_dist = 0 if match_dist < 0

      s1_matches = Array.new(len1, false)
      s2_matches = Array.new(len2, false)

      matches = 0
      len1.times do |i|
        start = [0, i - match_dist].max
        fin = [len2 - 1, i + match_dist].min

        (start..fin).each do |j|
          if !s2_matches[j] && bytes1[i] == bytes2[j]
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
            transpositions += 1 if bytes1[i] != bytes2[k]
            k += 1
          end
        end
      end

      transpositions /= 2

      m = matches.to_f
      (m / len1 + m / len2 + (m - transpositions) / m) / 3.0
    end

    def run(iteration_id)
      @pairs.each do |s1, s2|
        @result = (@result + (jaro(s1, s2) * 1000).to_i) & 0xFFFFFFFF
      end
    end

    def checksum
      @result & 0xFFFFFFFF
    end
  end

  class NGram < Benchmark
    def initialize
      @pairs = []
      @result = 0
      @count = config_val("count").to_i
      @size = config_val("size").to_i
    end

    def prepare
      @pairs = Distance.generate_pair_strings(@count, @size)
    end

    def ngram(s1, s2)
      bytes1 = s1.bytes
      bytes2 = s2.bytes
      len1 = bytes1.size
      len2 = bytes2.size

      grams1 = Hash.new(0)

      (0..len1 - 4).each do |i|
        gram = ((bytes1[i] << 24) |
          (bytes1[i + 1] << 16) |
          (bytes1[i + 2] << 8) |
          bytes1[i + 3]) &
          0xFFFFFFFF
        grams1[gram] += 1
      end

      grams2 = Hash.new(0)
      intersection = 0

      (0..len2 - 4).each do |i|
        gram = ((bytes2[i] << 24) |
          (bytes2[i + 1] << 16) |
          (bytes2[i + 2] << 8) |
          bytes2[i + 3]) &
          0xFFFFFFFF
        grams2[gram] += 1

        if grams1.key?(gram) && grams2[gram] <= grams1[gram]
          intersection += 1
        end
      end

      total = grams1.size + grams2.size
      total > 0 ? intersection.to_f / total : 0.0
    end

    def run(iteration_id)
      @pairs.each do |s1, s2|
        @result = (@result + (ngram(s1, s2) * 1000).to_i) & 0xFFFFFFFF
      end
    end

    def checksum
      @result & 0xFFFFFFFF
    end
  end
end

module CSVModule
  class Parse < Benchmark
    Point = Struct.new(:x, :y, :z)

    def initialize(rows = config_val("rows").to_i)
      @rows = rows
      @checksum = 0
      @data = String.new
    end

    def prepare
      @data = String.new
      @rows.times do |i|
        c = ("A".ord + i % 26).chr
        x = Helper.next_float
        z = Helper.next_float
        y = Helper.next_float

        @data << "\"" << "point " << c << "\\n, \"\"" << (i % 100).to_s << "\"\"\"" << ","
        @data << ("%.10f" % x) << "," << ","
        @data << ("%.10f" % z) << ","
        @data << "\"" << "[" << (i.even? ? "true" : "false") << "\\n, " << (i % 100).to_s << "]" << "\"" << ","
        @data << ("%.10f" % y) << "\n"
      end
    end

    def parse_points(csv_data)
      points = []

      CSV.parse(csv_data, quote_char: "\"", col_sep: ",") do |row|
        x = row[1].to_f
        z = row[3].to_f
        y = row[5].to_f
        points << Point.new(x, y, z)
      end

      points
    end

    def self.bench_name
      "CSV::Parse"
    end

    def run(iteration_id)
      points = parse_points(@data)

      return if points.empty?

      x_sum = y_sum = z_sum = 0.0
      points.each do |point|
        x_sum += point.x
        y_sum += point.y
        z_sum += point.z
      end

      x_avg = x_sum / points.size
      y_avg = y_sum / points.size
      z_avg = z_sum / points.size

      @checksum = (@checksum +
        Helper.checksum_f64(x_avg) +
        Helper.checksum_f64(y_avg) +
        Helper.checksum_f64(z_avg)) &
        0xFFFFFFFF
    end

    def checksum
      @checksum & 0xFFFFFFFF
    end
  end
end

File.write("/tmp/recompile_marker", "RECOMPILE_MARKER_0")

available_benches = {
  "Binarytrees::Obj" => Binarytrees::Obj,
  "Binarytrees::Arena" => Binarytrees::Arena,
  "Brainfuck::Array" => Brainfuck::Array,
  "Brainfuck::Recursion" => Brainfuck::Recursion,
  "Matmul::Single" => Matmul::Single,
  "Matmul::T4" => Matmul::T4,
  "Matmul::T8" => Matmul::T8,
  "Matmul::T16" => Matmul::T16,
  "Base64::Encode" => Base64::Encode,
  "Base64::Decode" => Base64::Decode,
  "Json::Generate" => Json::Generate,
  "Json::ParseDom" => Json::ParseDom,
  "Json::ParseMapping" => Json::ParseMapping,
  "Etc::Sieve" => Etc::Sieve,
  "Etc::TextRaytracer" => Etc::TextRaytracer,
  "Etc::NeuralNet" => Etc::NeuralNet,
  "Etc::CacheSimulation" => Etc::CacheSimulation,
  "Etc::GameOfLife" => Etc::GameOfLife,
  "Etc::Words" => Etc::Words,
  "Etc::LogParser" => Etc::LogParser,
  "Template::Regex" => Template::Regex,
  "Template::Parse" => Template::Parse,
  "Sort::Quick" => Sort::Quick,
  "Sort::Merge" => Sort::Merge,
  "Sort::Self" => Sort::Self,
  "Graph::BFS" => Graph::BFS,
  "Graph::DFS" => Graph::DFS,
  "Graph::AStar" => Graph::AStar,
  "Hash::SHA256" => HashModule::SHA256,
  "Hash::CRC32" => HashModule::CRC32,
  "Calculator::Ast" => Calculator::Ast,
  "Calculator::Interpreter" => Calculator::Interpreter,
  "Maze::Generator" => Maze::Generator,
  "Maze::BFS" => Maze::BFS,
  "Maze::AStar" => Maze::AStar,
  "CLBG::Fannkuchredux" => CLBG::Fannkuchredux,
  "CLBG::Mandelbrot" => CLBG::Mandelbrot,
  "CLBG::Nbody" => CLBG::Nbody,
  "CLBG::Spectralnorm" => CLBG::Spectralnorm,
  "Compress::BWTEncode" => Compress::BWTEncode,
  "Compress::BWTDecode" => Compress::BWTDecode,
  "Compress::HuffEncode" => Compress::HuffEncode,
  "Compress::HuffDecode" => Compress::HuffDecode,
  "Compress::ArithEncode" => Compress::ArithEncode,
  "Compress::ArithDecode" => Compress::ArithDecode,
  "Compress::LZWEncode" => Compress::LZWEncode,
  "Compress::LZWDecode" => Compress::LZWDecode,
  "Distance::Jaro" => Distance::Jaro,
  "Distance::NGram" => Distance::NGram,
  "CSV::Parse" => CSVModule::Parse
}
Benchmark.run(available_benches, ARGV[1])
