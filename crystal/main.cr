require "big"
require "base64"
require "json"
require "complex"

puts "start: #{Time.local.to_unix_ms}"
Benchmark.run(ARGV[1]?)

module Helper
  IM   = 139968
  IA   =   3877
  IC   =  29573
  INIT =     42

  @[AlwaysInline]
  def self.last
    @@last ||= INIT
  end

  @[AlwaysInline]
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
      if (!single_bench || ({{kl.stringify}}.downcase.includes?(single_bench))) && ({{kl.stringify}} != "SortBenchmark") && ({{kl.stringify}} != "BufferHashBenchmark") && ({{kl.stringify}} != "GraphPathBenchmark")
        print "{{kl}}: "

        bench = {{kl.id}}.new
        Helper.reset
        bench.prepare
        bench.warmup

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

class Pidigits < Benchmark
  def initialize(@nn : Int32 = config_val("amount").to_i32)
    @result = IO::Memory.new
  end

  def run(iteration_id)
    i = 0
    k = 0
    ns = 0.to_big_i
    a = 0.to_big_i
    t = 0
    u = 0.to_big_i
    k1 = 1
    n = 1.to_big_i
    d = 1.to_big_i

    while true
      k += 1
      t = n << 1
      n *= k
      k1 += 2
      a = (a + t) * k1
      d *= k1
      if a >= n
        t, u = (n * 3 + a).divmod(d)
        u += n
        if d > u
          ns = ns * 10 + t
          i += 1
          if i % 10 == 0
            @result << "%010d\t:%d\n" % {ns.to_u64, i}
            ns = 0
          end
          break if i >= @nn

          a = (a - (d * t)) * 10
          n *= 10
        end
      end
    end
  end

  def checksum : UInt32
    Helper.checksum(@result.to_s)
  end
end

class Binarytrees < Benchmark
  class TreeNode
    property left : TreeNode?
    property right : TreeNode?
    property item : Int32

    def self.create(item, depth) : TreeNode
      TreeNode.new item, depth - 1
    end

    def initialize(@item, depth = 0)
      if depth > 0
        self.left = TreeNode.new 2 * item - 1, depth - 1
        self.right = TreeNode.new 2 * item, depth - 1
      end
    end

    def check
      return item if (lft = left).nil?
      return item if (rgt = right).nil?
      lft.check - rgt.check + item
    end
  end

  def initialize(@n : Int64 = config_val("depth"))
    @result = 0_u32
  end

  def run(iteration_id)
    min_depth = 4
    max_depth = Math.max min_depth + 2, @n
    stretch_depth = max_depth + 1
    @result &+= TreeNode.create(0, stretch_depth).check

    min_depth.step(to: max_depth, by: 2) do |depth|
      iterations = 1 << (max_depth - depth + min_depth)
      1.upto(iterations) do |i|
        @result &+= TreeNode.create(i, depth).check
        @result &+= TreeNode.create(-i, depth).check
      end
    end
  end

  def checksum : UInt32
    @result
  end
end

class BrainfuckArray < Benchmark
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

  private def parse_commands(source : String) : Array(Char)?
    source.chars
      .select(&.ascii?)
      .select { |c| "+-<>[].,".includes?(c) }
      .to_a
  end

  private def build_jump_array(commands : Array(Char)) : Array(Int32)?
    jumps = Array.new(commands.size, 0)
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
    getter tape = Array(UInt8).new(30000, 0_u8)
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

  private def _run(commands : Array(Char), jumps : Array(Int32)) : UInt32?
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

class BrainfuckRecursion < Benchmark
  record Inc
  record Dec
  record Advance
  record Devance
  record Print
  alias Op = Inc | Dec | Advance | Devance | Print | Array(Op)

  struct Tape
    def initialize
      @tape = Array(UInt8).new(30000, 0_u8)
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
    @ops : Array(Op)
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

    def run_ops(ops : Array(Op), tape)
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
        when Array(Op)
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
    @text = Helper.config_s("BrainfuckRecursion", "program")
    @result = 0_u32
  end

  def warmup
    warmup_iterations.times do
      run_text(Helper.config_s("BrainfuckRecursion", "warmup_program"))
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

class Fannkuchredux < Benchmark
  def fannkuchredux(n : Int32)
    perm1 = StaticArray(Int32, 32).new { |i| i }
    perm = StaticArray(Int32, 32).new(0)
    count = StaticArray(Int32, 32).new(0)
    maxFlipsCount = permCount = checksum = 0
    n = 32 if n > 32
    r = n

    while true
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

      while true
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

class Matmul1T < Benchmark
  def matmul(a, b)
    m = a.size
    n = a[0].size
    p = b[0].size

    b2 = Array.new(n) { Array.new(p, 0.0) }
    (0...n).each do |i|
      (0...p).each do |j|
        b2[j][i] = b[i][j]
      end
    end

    c = Array.new(m) { Array.new(p, 0.0) }
    c.each_with_index do |ci, i|
      ai = a[i]
      b2.each_with_index do |b2j, j|
        s = 0.0
        b2j.each_with_index do |b2jv, k|
          s += ai[k] * b2jv
        end
        ci[j] = s
      end
    end
    c
  end

  def matgen(n)
    tmp = 1.0 / n / n
    a = Array.new(n) { Array.new(n, 0.0) }
    (0...n).each do |i|
      (0...n).each do |j|
        a[i][j] = tmp * (i - j) * (i + j)
      end
    end
    a
  end

  def initialize(@n : Int64 = config_val("n"))
    @result = 0_u32
  end

  def run(iteration_id)
    a = matgen(@n)
    b = matgen(@n)
    c = matmul(a, b)
    @result &+= Helper.checksum_f64(c[@n >> 1][@n >> 1])
  end

  def checksum : UInt32
    @result
  end
end

class Matmul4T < Benchmark
  @n : Int64
  @result : UInt32

  def initialize(@n = config_val("n"))
    @result = 0_u32
  end

  def num_workers
    4
  end

  def matgen(n : Int64) : Array(Array(Float64))
    tmp = 1.0 / n / n
    Array.new(n) do |i|
      Array.new(n) do |j|
        tmp * (i - j) * (i + j)
      end
    end
  end

  def matmul_parallel(a : Array(Array(Float64)), b : Array(Array(Float64))) : Array(Array(Float64))
    size = a.size

    b_t = Array.new(size) { Array.new(size, 0.0) }
    size.times do |i|
      size.times do |j|
        b_t[j][i] = b[i][j]
      end
    end

    c = Array.new(size) { Array.new(size, 0.0) }

    channel = Channel(Nil).new
    rows_per_worker = (size + num_workers - 1) // num_workers

    num_workers.times do |worker_id|
      spawn do
        start_row = worker_id * rows_per_worker
        end_row = Math.min(start_row + rows_per_worker, size)

        (start_row...end_row).each do |i|
          ai = a[i]
          ci = c[i]

          size.times do |j|
            sum = 0.0
            b_tj = b_t[j]

            size.times do |k|
              sum += ai[k] * b_tj[k]
            end

            ci[j] = sum
          end
        end

        channel.send(nil)
      end
    end

    num_workers.times { channel.receive }

    c
  end

  def run(iteration_id)
    a = matgen(@n)
    b = matgen(@n)
    c = matmul_parallel(a, b)

    @result &+= Helper.checksum_f64(c[@n >> 1][@n >> 1])
  end

  def checksum : UInt32
    @result
  end
end

class Matmul8T < Matmul4T
  def num_workers
    8
  end
end

class Matmul16T < Matmul4T
  def num_workers
    16
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

class Base64Encode < Benchmark
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

class Base64Decode < Benchmark
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

class JsonGenerate < Benchmark
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

class JsonParseDom < Benchmark
  def calc(text)
    jobj = JSON.parse(text)
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
    j = JsonGenerate.new(config_val("coords"))
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

class JsonParseMapping < Benchmark
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
    j = JsonGenerate.new(config_val("coords"))
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

  @[AlwaysInline]
  def self.lerp(a, b, v)
    a * (1.0 - v) + b * v
  end

  @[AlwaysInline]
  def self.smooth(v)
    v * v * (3.0 - 2.0 * v)
  end

  @[AlwaysInline]
  def self.random_gradient
    v = Helper.next_float * Math::PI * 2.0
    Vec2.new(Math.cos(v), Math.sin(v))
  end

  @[AlwaysInline]
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

    @[AlwaysInline]
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
    @[AlwaysInline]
    def scale(s)
      Vector.new(x * s, y * s, z * s)
    end

    @[AlwaysInline]
    def +(other)
      Vector.new(x + other.x, y + other.y, z + other.z)
    end

    @[AlwaysInline]
    def -(other)
      Vector.new(x - other.x, y - other.y, z - other.z)
    end

    @[AlwaysInline]
    def dot(other)
      x*other.x + y*other.y + z*other.z
    end

    @[AlwaysInline]
    def magnitude
      Math.sqrt self.dot(self)
    end

    @[AlwaysInline]
    def normalize
      scale(1.0 / magnitude)
    end
  end

  record Ray, orig : Vector, dir : Vector

  record Color, r : Float64, g : Float64, b : Float64 do
    @[AlwaysInline]
    def scale(s)
      Color.new(r * s, g * s, b * s)
    end

    @[AlwaysInline]
    def +(other)
      Color.new(r + other.r, g + other.g, b + other.b)
    end
  end

  record Sphere, center : Vector, radius : Float64, color : Color do
    @[AlwaysInline]
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

class SortQuick < SortBenchmark
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

class SortMerge < SortBenchmark
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

class SortSelf < SortBenchmark
  def test : Array(Int32)
    arr = @data.dup
    arr.sort!
    arr
  end
end

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

class GraphPathBFS < GraphPathBenchmark
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

class GraphPathDFS < GraphPathBenchmark
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

class GraphPathAStar < GraphPathBenchmark
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

class BufferHashSHA256 < BufferHashBenchmark
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

class BufferHashCRC32 < BufferHashBenchmark
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
    key = "item_#{Helper.next_int(@values_size)}"
    if @cache.get(key)
      @hits += 1
      @cache.put(key, "updated_#{iteration_id}")
    else
      @misses += 1
      @cache.put(key, "new_#{iteration_id}")
    end
  end

  def checksum : UInt32
    @result = (@result << 5) &+ @hits
    @result = (@result << 5) &+ @misses
    @result = (@result << 5) &+ @cache.size
    @result
  end
end

class CalculatorAst < Benchmark
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

class CalculatorInterpreter < Benchmark
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

    def evaluate(node : CalculatorAst::Node) : Int64
      case node
      when CalculatorAst::Number
        node.value.to_i64
      when CalculatorAst::Variable
        @variables[node.name]? || 0_i64
      when CalculatorAst::BinaryOp
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
      when CalculatorAst::Assignment
        value = evaluate(node.expr)
        @variables[node.var] = value
        value
      else
        0_i64
      end
    end

    def run(expressions : Array(CalculatorAst::Node)) : Int64
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
    @ast = Array(CalculatorAst::Node).new
    @result = 0_u32
  end

  getter expressions

  def prepare
    c = CalculatorAst.new(@n)
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
    "GameOfLife"
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

class MazeGenerator < Benchmark
  enum Cell
    Wall
    Path
  end

  class Maze
    getter width : Int32
    getter height : Int32
    getter cells : Array(Array(Cell))

    def initialize(@width : Int32, @height : Int32)
      @width = @width > 5 ? @width : 5
      @height = @height > 5 ? @height : 5
      @cells = Array.new(@height) { Array.new(@width, Cell::Wall) }
    end

    def [](x, y) : Cell
      @cells[y][x]
    end

    def []=(x, y, value : Cell)
      @cells[y][x] = value
    end

    def generate
      if @width < 5 || @height < 5
        (0...@width).each do |x|
          self[x, @height // 2] = Cell::Path
        end
        return
      end

      divide(0, 0, @width - 1, @height - 1)
      add_random_paths
    end

    private def add_random_paths
      num_extra_paths = (@width * @height) // 20

      num_extra_paths.times do
        x = Helper.next_int(@width - 2) + 1
        y = Helper.next_int(@height - 2) + 1

        if self[x, y] == Cell::Wall &&
           [self[x - 1, y], self[x + 1, y], self[x, y - 1], self[x, y + 1]].all?(Cell::Wall)
          self[x, y] = Cell::Path
        end
      end
    end

    private def divide(x1 : Int32, y1 : Int32, x2 : Int32, y2 : Int32)
      width = x2 - x1
      height = y2 - y1

      return if width < 2 || height < 2

      width_for_wall = {width - 2, 0}.max
      height_for_wall = {height - 2, 0}.max
      width_for_hole = {width - 1, 0}.max
      height_for_hole = {height - 1, 0}.max

      return if width_for_wall == 0 || height_for_wall == 0 ||
                width_for_hole == 0 || height_for_hole == 0

      if width > height
        wall_range = {width_for_wall // 2, 1}.max
        wall_offset = wall_range > 0 ? (Helper.next_int(wall_range)) * 2 : 0
        wall_x = x1 + 2 + wall_offset

        hole_range = {height_for_hole // 2, 1}.max
        hole_offset = hole_range > 0 ? (Helper.next_int(hole_range)) * 2 : 0
        hole_y = y1 + 1 + hole_offset

        return if wall_x > x2 || hole_y > y2

        (y1..y2).each do |y|
          self[wall_x, y] = Cell::Wall if y != hole_y
        end

        divide(x1, y1, wall_x - 1, y2) if wall_x > x1 + 1
        divide(wall_x + 1, y1, x2, y2) if wall_x + 1 < x2
      else
        wall_range = {height_for_wall // 2, 1}.max
        wall_offset = wall_range > 0 ? (Helper.next_int(wall_range)) * 2 : 0
        wall_y = y1 + 2 + wall_offset

        hole_range = {width_for_hole // 2, 1}.max
        hole_offset = hole_range > 0 ? (Helper.next_int(hole_range)) * 2 : 0
        hole_x = x1 + 1 + hole_offset

        return if wall_y > y2 || hole_x > x2

        (x1..x2).each do |x|
          self[x, wall_y] = Cell::Wall if x != hole_x
        end

        divide(x1, y1, x2, wall_y - 1) if wall_y > y1 + 1
        divide(x1, wall_y + 1, x2, y2) if wall_y + 1 < y2
      end
    end

    def to_bool_grid : Array(Array(Bool))
      @cells.map do |row|
        row.map { |cell| cell == Cell::Path }
      end
    end

    def is_connected(start : Tuple(Int32, Int32), goal : Tuple(Int32, Int32)) : Bool
      return false if start[0] >= @width || start[1] >= @height ||
                      goal[0] >= @width || goal[1] >= @height

      visited = Array.new(@height) { Array.new(@width, false) }
      queue = Deque(Tuple(Int32, Int32)).new

      visited[start[1]][start[0]] = true
      queue << start

      while !queue.empty?
        x, y = queue.shift

        return true if {x, y} == goal

        if y > 0 && self[x, y - 1] == Cell::Path && !visited[y - 1][x]
          visited[y - 1][x] = true
          queue << {x, y - 1}
        end

        if x + 1 < @width && self[x + 1, y] == Cell::Path && !visited[y][x + 1]
          visited[y][x + 1] = true
          queue << {x + 1, y}
        end

        if y + 1 < @height && self[x, y + 1] == Cell::Path && !visited[y + 1][x]
          visited[y + 1][x] = true
          queue << {x, y + 1}
        end

        if x > 0 && self[x - 1, y] == Cell::Path && !visited[y][x - 1]
          visited[y][x - 1] = true
          queue << {x - 1, y}
        end
      end

      false
    end

    def self.generate_walkable_maze(width : Int32, height : Int32) : Array(Array(Bool))
      maze = Maze.new(width, height)
      maze.generate

      start = {1, 1}
      goal = {width - 2, height - 2}

      if !maze.is_connected(start, goal)
        (0...width).each do |x|
          (0...height).each do |y|
            if x < maze.width && y < maze.height
              if x == 1 || y == 1 || x == width - 2 || y == height - 2
                maze[x, y] = Cell::Path
              end
            end
          end
        end
      end

      maze.to_bool_grid
    end
  end

  getter result : Int64
  getter width : Int32
  getter height : Int32

  def initialize
    @result = 0_i64
    @width = config_val("w").to_i32
    @height = config_val("h").to_i32
    @bool_grid = Array(Array(Bool)).new
  end

  def run(iteration_id)
    @bool_grid = Maze.generate_walkable_maze(@width, @height)
  end

  def grid_checksum(grid)
    hasher = 2166136261_u32
    prime = 16777619_u32

    @bool_grid.each_with_index do |row, i|
      row.each_with_index do |cell, j|
        if cell
          j_squared = j.to_u32 &* j.to_u32
          hasher = (hasher ^ j_squared) &* prime
        end
      end
    end

    hasher
  end

  def checksum : UInt32
    grid_checksum(@bool_grid)
  end
end

class AStarPathfinder < Benchmark
  getter result : UInt32
  getter start_x : Int32
  getter start_y : Int32
  getter goal_x : Int32
  getter goal_y : Int32
  getter width : Int32
  getter height : Int32

  def distance(a_x : Int32, a_y : Int32, b_x : Int32, b_y : Int32) : Int32
    (a_x - b_x).abs + (a_y - b_y).abs
  end

  record Node, x : Int32, y : Int32, f_score : Int32 do
    include Comparable(Node)

    def <=>(other : Node) : Int32
      cmp = f_score <=> other.f_score
      return cmp unless cmp == 0

      cmp = y <=> other.y
      return cmp unless cmp == 0
      x <=> other.x
    end
  end

  class BinaryHeap(T)
    @data : Array(T)

    def initialize
      @data = [] of T
    end

    def push(item : T)
      @data << item
      sift_up(@data.size - 1)
    end

    def pop : T?
      return @data.pop? if @data.size <= 1

      result = @data[0]
      @data[0] = @data.pop
      sift_down(0)
      result
    end

    def empty? : Bool
      @data.empty?
    end

    private def sift_up(index : Int32)
      while index > 0
        parent = (index - 1) // 2
        break if @data[index] >= @data[parent]
        swap(index, parent)
        index = parent
      end
    end

    private def sift_down(index : Int32)
      size = @data.size
      loop do
        left = index * 2 + 1
        right = left + 1
        smallest = index

        if left < size && @data[left] < @data[smallest]
          smallest = left
        end

        if right < size && @data[right] < @data[smallest]
          smallest = right
        end

        break if smallest == index

        swap(index, smallest)
        index = smallest
      end
    end

    private def swap(i : Int32, j : Int32)
      @data[i], @data[j] = @data[j], @data[i]
    end
  end

  def initialize
    @result = 0_u32
    @width = config_val("w").to_i32
    @height = config_val("h").to_i32
    @start_x = 1
    @start_y = 1
    @goal_x = @width - 2
    @goal_y = @height - 2
    @maze_grid = Array(Array(Bool)).new

    size = @width * @height
    @g_scores_cache = Array(Int32).new(size, Int32::MAX)
    @came_from_cache = Array(Int32).new(size, -1)
  end

  private def pack_coords(x : Int32, y : Int32) : Int32
    y * @width + x
  end

  private def unpack_coords(packed : Int32) : Tuple(Int32, Int32)
    {packed % @width, packed // @width}
  end

  private def find_path : Tuple(Array({Int32, Int32})?, Int32)
    grid = @maze_grid
    width = @width
    height = @height

    g_scores = @g_scores_cache
    came_from = @came_from_cache

    size = width * height
    g_scores.fill(Int32::MAX)
    came_from.fill(-1)

    open_set = BinaryHeap(Node).new
    nodes_explored = 0

    start_idx = pack_coords(@start_x, @start_y)
    g_scores[start_idx] = 0
    open_set.push(Node.new(@start_x, @start_y, distance(@start_x, @start_y, @goal_x, @goal_y)))

    directions = { {0, -1}, {1, 0}, {0, 1}, {-1, 0} }

    until open_set.empty?
      current = open_set.pop.not_nil!
      nodes_explored += 1

      if current.x == @goal_x && current.y == @goal_y
        path = [] of {Int32, Int32}
        x = current.x
        y = current.y

        while x != @start_x || y != @start_y
          path << {x, y}
          idx = pack_coords(x, y)
          packed = came_from[idx]
          break if packed == -1
          x, y = unpack_coords(packed)
        end

        path << {@start_x, @start_y}
        return {path.reverse, nodes_explored}
      end

      current_idx = pack_coords(current.x, current.y)
      current_g = g_scores[current_idx]

      directions.each do |dx, dy|
        nx = current.x + dx
        ny = current.y + dy

        next if nx < 0 || nx >= width || ny < 0 || ny >= height
        next unless grid[ny][nx]

        tentative_g = current_g + 1000
        neighbor_idx = pack_coords(nx, ny)

        if tentative_g < g_scores[neighbor_idx]
          came_from[neighbor_idx] = current_idx
          g_scores[neighbor_idx] = tentative_g

          f_score = tentative_g + distance(nx, ny, @goal_x, @goal_y)
          open_set.push(Node.new(nx, ny, f_score))
        end
      end
    end

    {nil, nodes_explored}
  end

  def prepare
    @maze_grid = MazeGenerator::Maze.generate_walkable_maze(@width, @height)
  end

  def run(iteration_id)
    path, nodes_explored = find_path

    local_result = 0_u32

    local_result = (path.try(&.size) || 0).to_u32

    local_result = (local_result << 5) &+ nodes_explored.to_u32

    @result &+= local_result
  end

  def checksum : UInt32
    @result
  end
end

class BWTHuffEncode < Benchmark
  struct BWTResult
    property transformed : Bytes
    property original_idx : Int32

    def initialize(@transformed : Bytes, @original_idx : Int32)
    end
  end

  private def bwt_transform(input : Bytes) : BWTResult
    n = input.size
    return BWTResult.new(Bytes.new(0), 0) if n == 0

    sa = Array.new(n) { |i| i }

    buckets = Array.new(256) { [] of Int32 }
    sa.each do |idx|
      first_char = input[idx]
      buckets[first_char] << idx
    end

    pos = 0
    buckets.each do |bucket|
      bucket.each do |idx|
        sa[pos] = idx
        pos += 1
      end
    end

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

  private def bwt_inverse(bwt_result : BWTResult) : Bytes
    bwt = bwt_result.transformed
    n = bwt.size
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
      byte_idx = byte.to_i32
      pos = positions[byte_idx] + temp_counts[byte_idx]
      next_arr[pos] = i
      temp_counts[byte_idx] += 1
    end

    result = Bytes.new(n)
    idx = bwt_result.original_idx

    n.times do |i|
      idx = next_arr[idx]
      result[i] = bwt[idx]
    end

    result
  end

  class HuffmanNode
    property frequency : Int32
    property byte_val : UInt8?
    property is_leaf : Bool
    property left : HuffmanNode?
    property right : HuffmanNode?
    property index : Int32

    def initialize(@frequency : Int32, @byte_val : UInt8? = nil, @is_leaf : Bool = true)
      @index = 0
    end
  end

  class PriorityQueue
    @heap : Array(HuffmanNode)

    def initialize
      @heap = [] of HuffmanNode
    end

    def push(node : HuffmanNode)
      @heap << node
      node.index = @heap.size - 1
      sift_up(@heap.size - 1)
    end

    def pop : HuffmanNode
      return @heap.pop if @heap.size <= 1

      root = @heap[0]
      @heap[0] = @heap.pop
      @heap[0].index = 0
      sift_down(0)
      root
    end

    def size : Int32
      @heap.size
    end

    def empty? : Bool
      @heap.empty?
    end

    private def sift_up(index : Int32)
      while index > 0
        parent = (index - 1) // 2
        break if @heap[parent].frequency <= @heap[index].frequency
        swap(index, parent)
        index = parent
      end
    end

    private def sift_down(index : Int32)
      size = @heap.size
      while true
        left = index * 2 + 1
        right = index * 2 + 2
        smallest = index

        smallest = left if left < size && @heap[left].frequency < @heap[smallest].frequency
        smallest = right if right < size && @heap[right].frequency < @heap[smallest].frequency

        break if smallest == index

        swap(index, smallest)
        index = smallest
      end
    end

    private def swap(i : Int32, j : Int32)
      @heap[i], @heap[j] = @heap[j], @heap[i]
      @heap[i].index = i
      @heap[j].index = j
    end
  end

  private def build_huffman_tree(frequencies : Array(Int32)) : HuffmanNode
    heap = PriorityQueue.new

    frequencies.each_with_index do |freq, i|
      if freq > 0
        heap.push(HuffmanNode.new(freq, i.to_u8))
      end
    end

    if heap.size == 1
      node = heap.pop
      root = HuffmanNode.new(node.frequency, nil, false)
      root.left = node
      root.right = HuffmanNode.new(0, 0_u8)
      return root
    end

    while heap.size > 1
      left = heap.pop
      right = heap.pop

      parent = HuffmanNode.new(
        left.frequency + right.frequency,
        nil,
        false
      )
      parent.left = left
      parent.right = right

      heap.push(parent)
    end

    heap.pop
  end

  class HuffmanCodes
    property code_lengths : Array(Int32)
    property codes : Array(Int32)

    def initialize
      @code_lengths = Array.new(256, 0)
      @codes = Array.new(256, 0)
    end
  end

  private def build_huffman_codes(node : HuffmanNode, code : Int32, length : Int32, huffman_codes : HuffmanCodes)
    if node.is_leaf
      if length > 0 || node.byte_val != 0
        idx = node.byte_val.not_nil!
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

  struct EncodedResult
    property data : Bytes
    property bit_count : Int32

    def initialize(@data : Bytes, @bit_count : Int32)
    end
  end

  private def huffman_encode(data : Bytes, huffman_codes : HuffmanCodes) : EncodedResult
    result = Bytes.new(data.size * 2)
    current_byte = 0_u8
    bit_pos = 0
    byte_index = 0
    total_bits = 0

    data.each do |byte|
      idx = byte.to_i32
      code = huffman_codes.codes[idx]
      length = huffman_codes.code_lengths[idx]

      (length - 1).downto(0) do |i|
        if (code & (1 << i)) != 0
          current_byte |= 1 << (7 - bit_pos)
        end
        bit_pos += 1
        total_bits += 1

        if bit_pos == 8
          result[byte_index] = current_byte
          byte_index += 1
          current_byte = 0_u8
          bit_pos = 0
        end
      end
    end

    if bit_pos > 0
      result[byte_index] = current_byte
      byte_index += 1
    end

    EncodedResult.new(result[0, byte_index], total_bits)
  end

  private def huffman_decode(encoded : Bytes, root : HuffmanNode, bit_count : Int32) : Bytes
    result = Bytes.new(bit_count // 4 + 1)
    result_idx = 0
    current_node = root
    bits_processed = 0
    byte_index = 0

    while bits_processed < bit_count && byte_index < encoded.size
      byte_val = encoded[byte_index]
      byte_index += 1

      7.downto(0) do |bit_pos|
        break if bits_processed >= bit_count

        bit = ((byte_val >> bit_pos) & 1) == 1
        bits_processed += 1

        current_node = bit ? current_node.right.not_nil! : current_node.left.not_nil!

        if current_node.is_leaf
          if current_node.byte_val != 0
            if result_idx >= result.size
              new_size = result.size * 2
              new_result = Bytes.new(new_size)
              result.copy_to(new_result)
              result = new_result
            end
            result[result_idx] = current_node.byte_val.not_nil!
            result_idx += 1
          end
          current_node = root
        end
      end
    end

    result[0, result_idx]
  end

  struct CompressedData
    property bwt_result : BWTResult
    property frequencies : Array(Int32)
    property encoded_bits : Bytes
    property original_bit_count : Int32

    def initialize(@bwt_result : BWTResult, @frequencies : Array(Int32),
                   @encoded_bits : Bytes, @original_bit_count : Int32)
    end
  end

  private def compress(data : Bytes) : CompressedData
    bwt_result = bwt_transform(data)

    frequencies = Array.new(256, 0)
    bwt_result.transformed.each do |byte|
      frequencies[byte] += 1
    end

    huffman_tree = build_huffman_tree(frequencies)

    huffman_codes = HuffmanCodes.new
    build_huffman_codes(huffman_tree, 0, 0, huffman_codes)

    encoded = huffman_encode(bwt_result.transformed, huffman_codes)

    CompressedData.new(
      bwt_result,
      frequencies,
      encoded.data,
      encoded.bit_count
    )
  end

  private def decompress(compressed : CompressedData) : Bytes
    huffman_tree = build_huffman_tree(compressed.frequencies)

    decoded = huffman_decode(
      compressed.encoded_bits,
      huffman_tree,
      compressed.original_bit_count
    )

    bwt_result = BWTResult.new(
      decoded,
      compressed.bwt_result.original_idx
    )

    bwt_inverse(bwt_result)
  end

  property size : Int64
  property result : UInt32
  @test_data : Bytes?

  def initialize
    @size = config_val("size")
    @result = 0_u32
  end

  private def generate_test_data(size : Int64) : Bytes
    pattern = "ABRACADABRA"
    data = Bytes.new(size)

    size.times do |i|
      data[i] = pattern[i % pattern.size].ord.to_u8
    end

    data
  end

  def prepare
    @test_data = generate_test_data(@size)
  end

  def run(iteration_id)
    compressed = compress(@test_data.not_nil!)
    @result &+= compressed.encoded_bits.size.to_u32
  end

  def checksum : UInt32
    @result
  end
end

class BWTHuffDecode < BWTHuffEncode
  @compressed : CompressedData?
  @decompressed : Bytes?

  def prepare
    @test_data = generate_test_data(@size)
    @compressed = compress(@test_data.not_nil!)
  end

  def run(iteration_id)
    @decompressed = decompressed = decompress(@compressed.not_nil!)
    @result &+= decompressed.size.to_u32
  end

  def checksum : UInt32
    res = @result
    if @decompressed.not_nil! == @test_data.not_nil!
      res &+= 1000000
    end
    res
  end
end

File.write("/tmp/recompile_marker", "RECOMPILE_MARKER_0")