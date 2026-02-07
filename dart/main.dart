import 'dart:io';
import 'dart:math';
import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';
import 'dart:isolate';
import 'dart:async';
import 'dart:collection';

bool get isDartVM => true;

class Performance {
  static final Stopwatch _stopwatch = Stopwatch()..start();

  static double now() {
    return _stopwatch.elapsedMicroseconds / 1000.0; 
  }
}

class Helper {
  static const int IM = 139968;
  static const int IA = 3877;
  static const int IC = 29573;
  static const int INIT = 42;

  static int lastValue = INIT;
  static final Map<String, String> inputMap = {};
  static final Map<String, BigInt> expectMap = {};
  static Map<String, dynamic>? _config;

  static void reset() {
    lastValue = INIT;
  }

  static int get last => lastValue;
  static set last(int value) => lastValue = value;

  static int nextInt(int max) {
    last = (last * IA + IC) % IM;
    return (last / IM * max).floor();
  }

  static int nextIntRange(int from, int to) {
    return nextInt(to - from + 1) + from;
  }

  static double nextFloat([double max = 1.0]) {
    last = (last * IA + IC) % IM;
    return max * last / IM;
  }

  static void debug(String message) {

    const debugEnv = String.fromEnvironment('DEBUG');
    if (debugEnv == '1' || Platform.environment['DEBUG'] == '1') {
      print('DEBUG: $message');
    }
  }

  static int checksumString(String str) {
    int hash = 5381;
    for (int i = 0; i < str.length; i++) {
      final byte = str.codeUnitAt(i);
      hash = ((hash << 5) + hash) + byte;
      hash = hash & 0xFFFFFFFF;
    }
    return hash >>> 0;
  }

  static int checksumBytes(List<int> bytes) {
    int hash = 5381;
    for (final byte in bytes) {
      hash = ((hash << 5) + hash) + byte;
      hash = hash & 0xFFFFFFFF;
    }
    return hash >>> 0;
  }

  static int checksumFloat(double value) {
    return checksumString(value.toStringAsFixed(7));
  }

  static Future<void> loadConfig([String configFile = '../test.json']) async {
    try {
      String content;

      final file = File(configFile);
      if (await file.exists()) {
        content = await file.readAsString();
      } else {

        final cwd = Directory.current;
        final absolutePath = '${cwd.path}/${configFile.replaceAll('../', '')}';
        final absoluteFile = File(absolutePath);

        if (await absoluteFile.exists()) {
          content = await absoluteFile.readAsString();
        } else {
          throw Exception('Config file not found: $configFile');
        }
      }

      _config = jsonDecode(content) as Map<String, dynamic>;

    } catch (error) {
      print('❌ Error loading config file $configFile: $error');
      exit(1);
    }
  }

  static BigInt configI64(String className, String fieldName) {
    if (_config == null || _config![className] == null) {
      throw Exception('Config not found for class $className');
    }

    final value = _config![className][fieldName];
    if (value is BigInt) {
      return value;
    } else if (value is int) {
      return BigInt.from(value);
    } else if (value is String) {
      return BigInt.parse(value);
    } else {
      throw Exception(
        'Config for $className, not found i64 field: $fieldName in $_config'
      );
    }
  }

  static String configS(String className, String fieldName) {
    if (_config == null || _config![className] == null) {
      throw Exception('Config not found for class $className');
    }

    final value = _config![className][fieldName];
    if (value is String) {
      return value;
    } else {
      throw Exception(
        'Config for $className, not found string field: $fieldName in $_config'
      );
    }
  }
}

abstract class Benchmark {

  FutureOr<void> runBenchmark(int iterationId);
  int checksum();

  void prepare() {}

  Map<String, dynamic> get config {
    final config = Helper._config;
    final className = runtimeType.toString().split('.').last;
    if (config != null && config[className] != null) {
      return config[className] as Map<String, dynamic>;
    }
    return {};
  }

  int get warmupIterations {
    final config = Helper._config;
    if (config != null && config['warmup_iterations'] != null) {
      return int.parse(config['warmup_iterations'].toString());
    }
    return max((iterations * 0.2).floor(), 1);
  }

  FutureOr<void> warmup() async {
    for (int i = 0; i < warmupIterations; i++) {
      final result = runBenchmark(i);
      if (result is Future) {
        await result;
      }
    }
  }

  FutureOr<void> runAll() async {
    for (int i = 0; i < iterations; i++) {
      final result = runBenchmark(i);
      if (result is Future) {
        await result;
      }
    }
  }

  int get iterations {
    try {
      final className = runtimeType.toString().split('.').last;
      return Helper.configI64(className, 'iterations').toInt();
    } catch (_) {
      return 1;
    }
  }

  BigInt get expectedChecksum {
    try {
      final className = runtimeType.toString().split('.').last;
      return Helper.configI64(className, 'checksum');
    } catch (_) {
      return BigInt.zero;
    }
  }

  static String _getBenchmarkName(Function() constructor) {
    final instance = constructor();
    final fullName = instance.runtimeType.toString();
    return fullName.split('.').last;
  }

  static Future<void> run([String? singleBench]) async {
    final results = <String, double>{};
    double summaryTime = 0;
    int ok = 0;
    int fails = 0;

    final benchmarkClasses = _getBenchmarkClasses();

    for (final benchmarkClass in benchmarkClasses) {
      final benchInstance = benchmarkClass();
      final className = benchInstance.runtimeType.toString().split('.').last;

      if (singleBench != null && 
          !className.toLowerCase().contains(singleBench.toLowerCase())) {
        continue;
      }

      if (className == 'SortBenchmark' || 
          className == 'BufferHashBenchmark' || 
          className == 'GraphPathBenchmark') {
        continue;
      }

      stdout.write('$className: ');

      final bench = benchmarkClass();
      Helper.reset();
      bench.prepare();

      final warmupResult = bench.warmup();
      if (warmupResult is Future) {
        await warmupResult;
      }

      Helper.reset();

      final startTime = Performance.now();

      final runAllResult = bench.runAll();
      if (runAllResult is Future) {
        await runAllResult;
      }

      final endTime = Performance.now();
      final timeDelta = (endTime - startTime) / 1000.0;

      results[className] = timeDelta;

      final actualResult = BigInt.from(bench.checksum());
      final expectedResult = bench.expectedChecksum;

      if (actualResult == expectedResult) {
        stdout.write('OK ');
        ok++;
      } else {
        final errorMsg = 'ERR[actual=$actualResult, expected=$expectedResult] ';
        stdout.write(errorMsg);
        fails++;
      }

      print('in ${timeDelta.toStringAsFixed(3)}s');
      summaryTime += timeDelta;
    }

    try {
      final resultsFile = File('/tmp/results.dart.json');
      resultsFile.writeAsStringSync(jsonEncode(results));
    } catch (_) {}

    print('Summary: ${summaryTime.toStringAsFixed(4)}s, ${ok + fails}, $ok, $fails');

    if (fails > 0) {
      exit(1);
    }
  }

  static List<Benchmark Function()> _getBenchmarkClasses() {
    return _benchmarkClasses;
  }

  static void registerBenchmark<T extends Benchmark>(T Function() constructor) {
    _benchmarkClasses.add(constructor);
  }

  static final List<Benchmark Function()> _benchmarkClasses = [];
}

class TreeNode {
  final int item;
  TreeNode? left;
  TreeNode? right;

  TreeNode(this.item, [int depth = 0]) {
    if (depth > 0) {
      left = TreeNode(2 * item - 1, depth - 1);
      right = TreeNode(2 * item, depth - 1);
    }
  }

  static TreeNode create(int item, int depth) {
    return TreeNode(item, depth - 1);
  }

  int check() {
    if (left == null || right == null) {
      return item;
    }
    return left!.check() - right!.check() + item;
  }
}

class Binarytrees extends Benchmark {
  late int n;
  int result = 0;

  Binarytrees() {
    final className = runtimeType.toString().split('.').last;
    n = Helper.configI64(className, 'depth').toInt();
  }

  @override
  void runBenchmark(int iterationId) {
    final minDepth = 4;
    final maxDepth = max(minDepth + 2, n);
    final stretchDepth = maxDepth + 1;

    final stretchTree = TreeNode.create(0, stretchDepth);
    result += stretchTree.check();

    for (int depth = minDepth; depth <= maxDepth; depth += 2) {
      final iterations = 1 << (maxDepth - depth + minDepth);

      for (int i = 1; i <= iterations; i++) {
        final tree1 = TreeNode.create(i, depth);
        final tree2 = TreeNode.create(-i, depth);

        result += tree1.check();
        result += tree2.check();
      }
    }
  }

  @override
  int checksum() {
    return result & 0xFFFFFFFF;
  }
}

class Tape {
  final Uint8List _tape = Uint8List(30000);
  int _pos = 0;

  int get() => _tape[_pos];

  void inc() {
    _tape[_pos] = (_tape[_pos] + 1) & 0xFF;
  }

  void dec() {
    _tape[_pos] = (_tape[_pos] - 1) & 0xFF;
  }

  void advance() {
    _pos++;
    if (_pos >= _tape.length) {
      _pos = _tape.length - 1;
    }
  }

  void devance() {
    _pos--;
    if (_pos < 0) {
      _pos = 0;
    }
  }
}

class BrainfuckProgram {
  final String _commands;
  final List<int> _jumps;

  BrainfuckProgram(String text) : 
    _commands = _filterCommands(text),
    _jumps = List.filled(_filterCommands(text).length, 0) {
    _buildJumps();
  }

  static String _filterCommands(String text) {
    final buffer = StringBuffer();
    for (final char in text.runes) {
      final ch = String.fromCharCode(char);
      if ('[]<>+-,.'.contains(ch)) {
        buffer.write(ch);
      }
    }
    return buffer.toString();
  }

  void _buildJumps() {
    final stack = <int>[];

    for (int i = 0; i < _commands.length; i++) {
      final cmd = _commands[i];
      if (cmd == '[') {
        stack.add(i);
      } else if (cmd == ']' && stack.isNotEmpty) {
        final start = stack.removeLast();
        _jumps[start] = i;
        _jumps[i] = start;
      }
    }
  }

  int run() {
    int result = 0;
    final tape = Tape();
    int pc = 0;

    while (pc < _commands.length) {
      final cmd = _commands[pc];

      switch (cmd) {
        case '+':
          tape.inc();
          break;
        case '-':
          tape.dec();
          break;
        case '>':
          tape.advance();
          break;
        case '<':
          tape.devance();
          break;
        case '[':
          if (tape.get() == 0) {
            pc = _jumps[pc];
          }
          break;
        case ']':
          if (tape.get() != 0) {
            pc = _jumps[pc];
          }
          break;
        case '.':
          result = ((result << 2) + tape.get()) & 0xFFFFFFFF;
          break;
      }

      pc++;
    }

    return result;
  }
}

class BrainfuckArray extends Benchmark {
  late String _programText;
  late String _warmupText;
  int _resultValue = 0;

  @override
  void prepare() {
    final className = runtimeType.toString().split('.').last;
    _programText = Helper.configS(className, "program");
    _warmupText = Helper.configS(className, "warmup_program");
  }

  @override
  void warmup() {
    final prepareIters = warmupIterations;
    for (int i = 0; i < prepareIters; i++) {
      BrainfuckProgram(_warmupText).run();
    }
  }

  @override
  void runBenchmark(int iterationId) {
    final result = BrainfuckProgram(_programText).run();
    _resultValue = (_resultValue + result) & 0xFFFFFFFF;
  }

  @override
  int checksum() {
    return _resultValue & 0xFFFFFFFF;
  }
}

abstract class Op {}

class IncOp extends Op {
  final int value;
  IncOp(this.value);
}

class MoveOp extends Op {
  final int value;
  MoveOp(this.value);
}

class PrintOp extends Op {}

class LoopOp extends Op {
  final List<Op> ops;
  LoopOp(this.ops);
}

class Tape2 {
  static const int INITIAL_SIZE = 1024;
  Uint8List _tape;
  int _pos = 0;

  Tape2() : _tape = Uint8List(INITIAL_SIZE);

  int get() => _tape[_pos];

  void inc(int x) {
    _tape[_pos] = (_tape[_pos] + x) & 0xFF;
  }

  void move(int x) {
    _pos += x;

    if (_pos >= _tape.length) {
      final newLength = (_tape.length * 2).clamp(_pos + 1, 1 << 30);
      final newTape = Uint8List(newLength);
      newTape.setRange(0, _tape.length, _tape);
      _tape = newTape;
    }

    if (_pos < 0) {
      _pos = 0;
    }
  }
}

class BrainfuckProgram2 {
  final List<Op> _ops;
  int _resultValue = 0;

  BrainfuckProgram2(String code) : _ops = _parse(code);

  int run() {
    _resultValue = 0;
    _runOps(_ops, Tape2());
    return _resultValue;
  }

  void _runOps(List<Op> program, Tape2 tape) {
    for (final op in program) {
      if (op is LoopOp) {
        while (tape.get() != 0) {
          _runOps(op.ops, tape);
        }
      } else if (op is IncOp) {
        tape.inc(op.value);
      } else if (op is MoveOp) {
        tape.move(op.value);
      } else if (op is PrintOp) {
        _resultValue = ((_resultValue << 2) + tape.get()) & 0xFFFFFFFF;
      }
    }
  }

  static List<Op> _parse(String code) {
    final chars = code.runes.toList();
    final parseResult = _parseSequence(chars, 0);
    return parseResult.ops;
  }

  static ParseResult _parseSequence(List<int> chars, int index) {
    final result = <Op>[];
    int i = index;

    while (i < chars.length) {
      final c = String.fromCharCode(chars[i]);
      i++;

      Op? op;

      switch (c) {
        case '+':
          op = IncOp(1);
          break;
        case '-':
          op = IncOp(-1);
          break;
        case '>':
          op = MoveOp(1);
          break;
        case '<':
          op = MoveOp(-1);
          break;
        case '.':
          op = PrintOp();
          break;
        case '[':
          final parseResult = _parseSequence(chars, i);
          result.add(LoopOp(parseResult.ops));
          i = parseResult.index;
          break;
        case ']':
          return ParseResult(result, i);
        default:
          continue;
      }

      if (op != null) {
        result.add(op);
      }
    }

    return ParseResult(result, i);
  }
}

class ParseResult {
  final List<Op> ops;
  final int index;

  ParseResult(this.ops, this.index);
}

class BrainfuckRecursion extends Benchmark {
  late String _text;
  int _resultValue = 0;

  @override
  void prepare() {
    final className = runtimeType.toString().split('.').last;
    _text = Helper.configS(className, "program");
  }

  @override
  void warmup() {
    final warmupProgram = Helper.configS(runtimeType.toString().split('.').last, "warmup_program");
    for (int i = 0; i < warmupIterations; i++) {
      final program = BrainfuckProgram2(warmupProgram);
      program.run();
    }
  }

  @override
  void runBenchmark(int iterationId) {
    final program = BrainfuckProgram2(_text);
    _resultValue = (_resultValue + program.run()) & 0xFFFFFFFF;
  }

  @override
  int checksum() {
    return _resultValue & 0xFFFFFFFF;
  }
}

class Pidigits extends Benchmark {
  late int nn;
  final List<String> _resultBuffer = [];
  String _resultStr = '';

  @override
  void prepare() {
    final className = runtimeType.toString().split('.').last;
    nn = Helper.configI64(className, "amount").toInt();
  }

  @override
  void runBenchmark(int iterationId) {
    int i = 0;
    int k = 0;
    BigInt ns = BigInt.zero;
    BigInt a = BigInt.zero;
    BigInt t, u;
    int k1 = 1;
    BigInt n = BigInt.one;
    BigInt d = BigInt.one;

    while (true) {
      k += 1;
      t = n << 1;
      n *= BigInt.from(k);
      k1 += 2;
      a = (a + t) * BigInt.from(k1);
      d *= BigInt.from(k1);

      if (a >= n) {
        final temp = n * BigInt.from(3) + a;
        t = temp ~/ d;  
        u = temp % d;
        u += n;

        if (d > u) {
          final digit = t.toInt();
          ns = ns * BigInt.from(10) + BigInt.from(digit);
          i += 1;

          if (i % 10 == 0) {
            final line = ns.toString().padLeft(10, '0') + '\t:${i}\n';
            _resultBuffer.add(line);
            ns = BigInt.zero;
          }

          if (i >= nn) {
            break;
          }

          a = (a - d * t) * BigInt.from(10);
          n *= BigInt.from(10);
        }
      }
    }

    if (ns != BigInt.zero && _resultBuffer.isNotEmpty) {
      final remainingDigits = nn % 10 == 0 ? 10 : nn % 10;
      final line = ns.toString().padLeft(remainingDigits, '0') + '\t:${i}\n';
      _resultBuffer.add(line);
    }

    _resultStr = _resultBuffer.join();
  }

  @override
  int checksum() {
    return Helper.checksumString(_resultStr);
  }
}

class Fannkuchredux extends Benchmark {
  late int n;
  int _resultValue = 0;

  @override
  void prepare() {
    final className = runtimeType.toString().split('.').last;
    n = Helper.configI64(className, "n").toInt();
  }

  (int, int) _fannkuchredux(int n) {
    final perm1 = List<int>.generate(n, (i) => i);
    final perm = List<int>.filled(n, 0);
    final count = List<int>.filled(n, 0);

    int maxFlipsCount = 0;
    int permCount = 0;
    int checksum = 0;
    int r = n;

    while (true) {
      while (r > 1) {
        count[r - 1] = r;
        r -= 1;
      }

      for (int i = 0; i < n; i++) {
        perm[i] = perm1[i];
      }

      int flipsCount = 0;
      int k = perm[0];

      while (k != 0) {
        final k2 = (k + 1) ~/ 2;

        for (int i = 0; i < k2; i++) {
          final j = k - i;
          final temp = perm[i];
          perm[i] = perm[j];
          perm[j] = temp;
        }

        flipsCount += 1;
        k = perm[0];
      }

      if (flipsCount > maxFlipsCount) {
        maxFlipsCount = flipsCount;
      }

      checksum += (permCount % 2 == 0) ? flipsCount : -flipsCount;

      while (true) {
        if (r == n) {
          return (checksum, maxFlipsCount);
        }

        final perm0 = perm1[0];
        for (int i = 0; i < r; i++) {
          final j = i + 1;
          final temp = perm1[i];
          perm1[i] = perm1[j];
          perm1[j] = temp;
        }

        perm1[r] = perm0;
        count[r] -= 1;
        final cntr = count[r];

        if (cntr > 0) {
          break;
        }

        r += 1;
      }

      permCount += 1;
    }
  }

  @override
  void runBenchmark(int iterationId) {
    final (checksum, maxFlipsCount) = _fannkuchredux(n);
    _resultValue += checksum * 100 + maxFlipsCount;
  }

  @override
  int checksum() {
    return _resultValue;
  }
}

class Gene {
  final String char;
  final double prob;

  Gene(this.char, this.prob);
}

class Fasta extends Benchmark {
  static const int LINE_LENGTH = 60;

  static final List<Gene> IUB = [
    Gene('a', 0.27), Gene('c', 0.39), Gene('g', 0.51),
    Gene('t', 0.78), Gene('B', 0.8), Gene('D', 0.8200000000000001),
    Gene('H', 0.8400000000000001), Gene('K', 0.8600000000000001),
    Gene('M', 0.8800000000000001), Gene('N', 0.9000000000000001),
    Gene('R', 0.9200000000000002), Gene('S', 0.9400000000000002),
    Gene('V', 0.9600000000000002), Gene('W', 0.9800000000000002),
    Gene('Y', 1.0000000000000002),
  ];

  static final List<Gene> HOMO = [
    Gene('a', 0.302954942668), Gene('c', 0.5009432431601),
    Gene('g', 0.6984905497992), Gene('t', 1.0),
  ];

  static const String ALU = "GGCCGGGCGCGGTGGCTCACGCCTGTAATCCCAGCACTTTGGGAGGCCGAGGCGGGCGGATCACCTGAGGTCAGGAGTTCGAGACCAGCCTGGCCAACATGGTGAAACCCCGTCTCTACTAAAAATACAAAAATTAGCCGGGCGTGGTGGCGCGCGCCTGTAATCCCAGCTACTCGGGAGGCTGAGGCAGGAGAATCGCTTGAACCCGGGAGGCGGAGGTTGCAGTGAGCCGAGATCGCGCCACTGCACTCCAGCCTGGGCGACAGAGCGAGACTCCGTCTCAAAAA";

  late int n;
  late StringBuffer resultBuffer;

  Fasta() {
    final className = runtimeType.toString().split('.').last;
    n = Helper.configI64(className, "n").toInt();
  }

  void setIterations(int count) {
    n = count;
  }

  String _selectRandom(List<Gene> genelist) {
    final r = Helper.nextFloat();

    if (r < genelist[0].prob) {
      return genelist[0].char;
    }

    var lo = 0;
    var hi = genelist.length - 1;

    while (hi > lo + 1) {
      final i = (hi + lo) ~/ 2;
      if (r < genelist[i].prob) {
        hi = i;
      } else {
        lo = i;
      }
    }
    return genelist[hi].char;
  }

  void _makeRandomFasta(String id, String desc, List<Gene> genelist, int n) {
    resultBuffer.write('>$id $desc\n');

    var todo = n;
    final buffer = StringBuffer();

    while (todo > 0) {
      final m = todo < LINE_LENGTH ? todo : LINE_LENGTH;
      buffer.clear();

      for (int i = 0; i < m; i++) {
        buffer.write(_selectRandom(genelist));
      }

      resultBuffer.write(buffer);
      resultBuffer.write('\n');
      todo -= LINE_LENGTH;
    }
  }

  void _makeRepeatFasta(String id, String desc, String s, int n) {
    resultBuffer.write('>$id $desc\n');

    var todo = n;
    var k = 0;
    final kn = s.length;

    while (todo > 0) {
      final m = todo < LINE_LENGTH ? todo : LINE_LENGTH;
      var remaining = m;

      while (remaining >= kn - k) {
        resultBuffer.write(s.substring(k));
        remaining -= kn - k;
        k = 0;
      }

      if (remaining > 0) {
        resultBuffer.write(s.substring(k, k + remaining));
        k += remaining;
      }

      resultBuffer.write('\n');
      todo -= LINE_LENGTH;
    }
  }

  @override
  void prepare() {
    resultBuffer = StringBuffer();
  }

  @override
  void runBenchmark(int iterationId) {    
    _makeRepeatFasta("ONE", "Homo sapiens alu", ALU, n * 2);
    _makeRandomFasta("TWO", "IUB ambiguity codes", IUB, n * 3);
    _makeRandomFasta("THREE", "Homo sapiens frequency", HOMO, n * 5);
  }

  String getResult() {
    return resultBuffer.toString();
  }

  @override
  int checksum() {
    return Helper.checksumString(resultBuffer.toString());
  }
}

class Knuckeotide extends Benchmark {
  String _seq = '';
  String _resultStr = '';

  Map<String, int> _frequency(String seq, int length) {
    final n = seq.length - length + 1;
    final table = <String, int>{};

    for (int i = 0; i < n; i++) {
      final key = seq.substring(i, i + length);
      table[key] = (table[key] ?? 0) + 1;
    }

    return table;
  }

  void _sortByFreq(String seq, int length) {
    final table = _frequency(seq, length);
    final n = seq.length - length + 1;

    final sorted = table.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    for (final entry in sorted) {
      final freq = (entry.value * 100) / n;
      _resultStr += '${entry.key.toUpperCase()} ${freq.toStringAsFixed(3)}\n';
    }

    _resultStr += '\n';
  }

  void _findSeq(String seq, String s) {
    final table = _frequency(seq, s.length);
    final count = table[s.toLowerCase()] ?? 0;
    _resultStr += '$count\t${s.toUpperCase()}\n';
  }

  @override
  void prepare() {
    final className = runtimeType.toString().split('.').last;
    final n = Helper.configI64(className, "n").toInt();

    final fasta = Fasta();
    fasta.setIterations(n);
    fasta.prepare();
    fasta.runBenchmark(0);

    final fastaOutput = fasta.getResult();

    var seq = '';
    var afterThree = false;

    final lines = fastaOutput.split('\n');
    for (final line in lines) {
      if (line.startsWith('>THREE')) {
        afterThree = true;
        continue;
      }

      if (afterThree) {
        if (line.startsWith('>')) {
          break;
        }
        seq += line.trim();
      }
    }

    _seq = seq;
  }

  @override
  void runBenchmark(int iterationId) {
    for (int i = 1; i <= 2; i++) {
      _sortByFreq(_seq, i);
    }

    final sequences = ['ggt', 'ggta', 'ggtatt', 'ggtattttaatt', 'ggtattttaatttatagt'];
    for (final s in sequences) {
      _findSeq(_seq, s);
    }
  }

  @override
  int checksum() {
    return Helper.checksumString(_resultStr);
  }
}

class Mandelbrot extends Benchmark {
  static const int ITER = 50;
  static const double LIMIT = 2.0;

  late int w;
  late int h;
  final List<int> _resultBytes = [];

  @override
  void prepare() {
    final className = runtimeType.toString().split('.').last;
    w = Helper.configI64(className, "w").toInt();
    h = Helper.configI64(className, "h").toInt();
  }

  @override
  void runBenchmark(int iterationId) {
    final header = 'P4\n$w $h\n';
    _resultBytes.addAll(header.codeUnits);

    int bitNum = 0;
    int byteAcc = 0;

    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        double zr = 0.0;
        double zi = 0.0;
        double tr = 0.0;
        double ti = 0.0;

        final cr = (2.0 * x / w - 1.5);
        final ci = (2.0 * y / h - 1.0);

        int i = 0;
        while (i < ITER && (tr + ti) <= LIMIT * LIMIT) {
          zi = 2.0 * zr * zi + ci;
          zr = tr - ti + cr;
          tr = zr * zr;
          ti = zi * zi;
          i++;
        }

        byteAcc <<= 1;
        if (tr + ti <= LIMIT * LIMIT) {
          byteAcc |= 0x01;
        }
        bitNum++;

        if (bitNum == 8) {
          _resultBytes.add(byteAcc);
          byteAcc = 0;
          bitNum = 0;
        } else if (x == w - 1) {
          byteAcc <<= (8 - (w % 8));
          _resultBytes.add(byteAcc);
          byteAcc = 0;
          bitNum = 0;
        }
      }
    }
  }

  @override
  int checksum() {
    return Helper.checksumBytes(_resultBytes);
  }
}

abstract class MatmulBase extends Benchmark {
  late int n;
  int _resultValue = 0;

  @override
  void prepare() {
    final className = runtimeType.toString().split('.').last;
    n = Helper.configI64(className, "n").toInt();
  }

  List<List<double>> _matgen(int n) {
    final tmp = 1.0 / n / n;
    final a = List<List<double>>.generate(
      n, 
      (_) => List<double>.filled(n, 0.0)
    );

    for (int i = 0; i < n; i++) {
      for (int j = 0; j < n; j++) {
        a[i][j] = tmp * (i - j) * (i + j);
      }
    }

    return a;
  }

  List<List<double>> _matmulSync(List<List<double>> a, List<List<double>> b) {
    final size = a.length;

    final bT = List<List<double>>.generate(
      size,
      (_) => List<double>.filled(size, 0.0)
    );

    for (int i = 0; i < size; i++) {
      for (int j = 0; j < size; j++) {
        bT[j][i] = b[i][j];
      }
    }

    final c = List<List<double>>.generate(
      size,
      (_) => List<double>.filled(size, 0.0)
    );

    for (int i = 0; i < size; i++) {
      final ai = a[i];
      final ci = c[i];

      for (int j = 0; j < size; j++) {
        final bTj = bT[j];
        double sum = 0.0;

        for (int k = 0; k < size; k++) {
          sum += ai[k] * bTj[k];
        }

        ci[j] = sum;
      }
    }

    return c;
  }

  Future<List<List<double>>> _matmulParallel(
    List<List<double>> a, 
    List<List<double>> b,
    int numThreads
  ) async {
    final size = a.length;

    final bT = List<List<double>>.generate(
      size,
      (_) => List<double>.filled(size, 0.0)
    );

    for (int i = 0; i < size; i++) {
      for (int j = 0; j < size; j++) {
        bT[j][i] = b[i][j];
      }
    }

    final rowsPerThread = (size + numThreads - 1) ~/ numThreads;

    final futures = List.generate(numThreads, (thread) async {
      return await Isolate.run(() {
        final start = thread * rowsPerThread;
        final end = (start + rowsPerThread) < size ? start + rowsPerThread : size;

        final localResult = List.generate(end - start, (_) => List.filled(size, 0.0));

        for (int localI = 0; localI < end - start; localI++) {
          final i = start + localI;
          final ai = a[i];
          final ci = localResult[localI];

          for (int j = 0; j < size; j++) {
            final bTj = bT[j];
            double sum = 0.0;

            for (int k = 0; k < size; k++) {
              sum += ai[k] * bTj[k];
            }

            ci[j] = sum;
          }
        }

        return (start, localResult);
      });
    });

    final results = await Future.wait(futures);
    final c = List.generate(size, (_) => List.filled(size, 0.0));

    for (final result in results) {
      final (start, rows) = result;
      for (int i = 0; i < rows.length; i++) {
        c[start + i] = rows[i];
      }
    }

    return c;
  }

  @override
  int checksum() {
    return _resultValue & 0xFFFFFFFF;
  }
}

class Matmul1T extends MatmulBase {
  @override
  Future<void> runBenchmark(int iterationId) async {
    final a = _matgen(n);
    final b = _matgen(n);
    final c = _matmulSync(a, b);
    final value = c[n >> 1][n >> 1];

    _resultValue = (_resultValue + Helper.checksumFloat(value)) & 0xFFFFFFFF;
  }
}

class Matmul4T extends MatmulBase {
  @override
  Future<void> runBenchmark(int iterationId) async {
    final a = _matgen(n);
    final b = _matgen(n);
    final c = await _matmulParallel(a, b, 4);
    final value = c[n >> 1][n >> 1];

    _resultValue = (_resultValue + Helper.checksumFloat(value)) & 0xFFFFFFFF;
  }
}

class Matmul8T extends MatmulBase {
  @override
  Future<void> runBenchmark(int iterationId) async {
    final a = _matgen(n);
    final b = _matgen(n);
    final c = await _matmulParallel(a, b, 8);
    final value = c[n >> 1][n >> 1];

    _resultValue = (_resultValue + Helper.checksumFloat(value)) & 0xFFFFFFFF;
  }
}

class Matmul16T extends MatmulBase {
  @override
  Future<void> runBenchmark(int iterationId) async {
    final a = _matgen(n);
    final b = _matgen(n);
    final c = await _matmulParallel(a, b, 16);
    final value = c[n >> 1][n >> 1];

    _resultValue = (_resultValue + Helper.checksumFloat(value)) & 0xFFFFFFFF;
  }
}

const SOLAR_MASS = 4 * pi * pi;
const DAYS_PER_YEAR = 365.24;

class Planet {
  double x, y, z;
  double vx, vy, vz;
  double mass;

  Planet(
    double x, double y, double z,
    double vx, double vy, double vz,
    double mass
  ) : x = x,
      y = y,
      z = z,
      vx = vx * DAYS_PER_YEAR,
      vy = vy * DAYS_PER_YEAR,
      vz = vz * DAYS_PER_YEAR,
      mass = mass * SOLAR_MASS;

  void moveFromI(List<Planet> bodies, int nbodies, double dt, int i) {
    while (i < nbodies) {
      final b2 = bodies[i];
      final dx = x - b2.x;
      final dy = y - b2.y;
      final dz = z - b2.z;

      final distance = sqrt(dx * dx + dy * dy + dz * dz);
      final mag = dt / (distance * distance * distance);
      final bMassMag = mass * mag;
      final b2MassMag = b2.mass * mag;

      vx -= dx * b2MassMag;
      vy -= dy * b2MassMag;
      vz -= dz * b2MassMag;
      b2.vx += dx * bMassMag;
      b2.vy += dy * bMassMag;
      b2.vz += dz * bMassMag;
      i++;
    }

    x += dt * vx;
    y += dt * vy;
    z += dt * vz;
  }
}

class Nbody extends Benchmark {
  static const solarMass = SOLAR_MASS;
  static const daysPerYear = DAYS_PER_YEAR;

  static final _initialBodies = [
    Planet(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0),

    Planet(
      4.84143144246472090e+00,
      -1.16032004402742839e+00,
      -1.03622044471123109e-01,
      1.66007664274403694e-03,
      7.69901118419740425e-03,
      -6.90460016972063023e-05,
      9.54791938424326609e-04,
    ),

    Planet(
      8.34336671824457987e+00,
      4.12479856412430479e+00,
      -4.03523417114321381e-01,
      -2.76742510726862411e-03,
      4.99852801234917238e-03,
      2.30417297573763929e-05,
      2.85885980666130812e-04,
    ),

    Planet(
      1.28943695621391310e+01,
      -1.51111514016986312e+01,
      -2.23307578892655734e-01,
      2.96460137564761618e-03,
      2.37847173959480950e-03,
      -2.96589568540237556e-05,
      4.36624404335156298e-05,
    ),

    Planet(
      1.53796971148509165e+01,
      -2.59193146099879641e+01,
      1.79258772950371181e-01,
      2.68067772490389322e-03,
      1.62824170038242295e-03,
      -9.51592254519715870e-05,
      5.15138902046611451e-05,
    ),
  ];

  late List<Planet> bodies;
  int _resultValue = 0;
  late double _v1;

  @override
  void prepare() {
    final className = runtimeType.toString().split('.').last;
    final iterations = Helper.configI64(className, "iterations").toInt();

    bodies = _initialBodies.map((p) => Planet(
      p.x, p.y, p.z,
      p.vx / DAYS_PER_YEAR,
      p.vy / DAYS_PER_YEAR,
      p.vz / DAYS_PER_YEAR,
      p.mass / SOLAR_MASS,
    )).toList();

    _offsetMomentum(bodies);
    _v1 = _energy(bodies);
  }

  double _energy(List<Planet> bodies) {
    double e = 0.0;
    final nbodies = bodies.length;

    for (int i = 0; i < nbodies; i++) {
      final b = bodies[i];
      e += 0.5 * b.mass * (b.vx * b.vx + b.vy * b.vy + b.vz * b.vz);

      for (int j = i + 1; j < nbodies; j++) {
        final b2 = bodies[j];
        final dx = b.x - b2.x;
        final dy = b.y - b2.y;
        final dz = b.z - b2.z;
        final distance = sqrt(dx * dx + dy * dy + dz * dz);
        e -= (b.mass * b2.mass) / distance;
      }
    }

    return e;
  }

  void _offsetMomentum(List<Planet> bodies) {
    double px = 0.0, py = 0.0, pz = 0.0;

    for (final b in bodies) {
      final m = b.mass;
      px += b.vx * m;
      py += b.vy * m;
      pz += b.vz * m;
    }

    final b = bodies[0];
    b.vx = -px / SOLAR_MASS;
    b.vy = -py / SOLAR_MASS;
    b.vz = -pz / SOLAR_MASS;
  }

  @override
  void runBenchmark(int iterationId) {
    final nbodies = bodies.length;
    const dt = 0.01;

    int i = 0;
    while (i < nbodies) {
      final b = bodies[i];
      b.moveFromI(bodies, nbodies, dt, i + 1);
      i++;
    }
  }

  @override
  int checksum() {
    final v2 = _energy(bodies);
    final checksum1 = Helper.checksumFloat(_v1);
    final checksum2 = Helper.checksumFloat(v2);

    return ((checksum1 << 5) & checksum2) & 0xFFFFFFFF;
  }
}

class RegexDna extends Benchmark {
  String seq = '';
  int ilen = 0;
  int clen = 0;
  String resultStr = '';
  late int n;

  RegexDna() {
    final className = runtimeType.toString().split('.').last;
    n = Helper.configI64(className, "n").toInt();
  }

  @override
  void prepare() {

    final fasta = Fasta();

    fasta.setIterations(n);

    fasta.prepare();
    fasta.runBenchmark(0);

    final fastaOutput = fasta.getResult();

    final buffer = StringBuffer();
    final lines = fastaOutput.split('\n');

    for (final line in lines) {
      if (line.isNotEmpty && !line.startsWith('>')) {
        buffer.write(line.trim());
      }
    }

    seq = buffer.toString();

    ilen = utf8.encode(fastaOutput).length;

    clen = utf8.encode(seq).length;
  }

  @override
  void runBenchmark(int iterationId) {
    final patterns = [
      RegExp(r'agggtaaa|tttaccct', caseSensitive: false),
      RegExp(r'[cgt]gggtaaa|tttaccc[acg]', caseSensitive: false),
      RegExp(r'a[act]ggtaaa|tttacc[agt]t', caseSensitive: false),
      RegExp(r'ag[act]gtaaa|tttac[agt]ct', caseSensitive: false),
      RegExp(r'agg[act]taaa|ttta[agt]cct', caseSensitive: false),
      RegExp(r'aggg[acg]aaa|ttt[cgt]ccct', caseSensitive: false),
      RegExp(r'agggt[cgt]aa|tt[acg]accct', caseSensitive: false),
      RegExp(r'agggta[cgt]a|t[acg]taccct', caseSensitive: false),
      RegExp(r'agggtaa[cgt]|[acg]ttaccct', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final matches = pattern.allMatches(seq).length;
      resultStr += '${pattern.pattern} $matches\n';
    }

    final replacements = {
      'B': '(c|g|t)',
      'D': '(a|g|t)',
      'H': '(a|c|t)',
      'K': '(g|t)',
      'M': '(a|c)',
      'N': '(a|c|g|t)',
      'R': '(a|g)',
      'S': '(c|t)',
      'V': '(a|c|g)',
      'W': '(a|t)',
      'Y': '(c|t)',
    };

    String modifiedSeq = seq;
    for (final entry in replacements.entries) {
      modifiedSeq = modifiedSeq.replaceAll(
        RegExp(entry.key, caseSensitive: false),
        entry.value,
      );
    }

    resultStr += '\n$ilen\n$clen\n${utf8.encode(modifiedSeq).length}\n';
  }

  @override
  int checksum() {
    return Helper.checksumString(resultStr);
  }
}

class Revcomp extends Benchmark {
  String input = '';
  int resultValue = 0;

  static Uint8List? _lookupTable;

  static const FROM = "wsatugcyrkmbdhvnATUGCYRKMBDHVN";
  static const TO = "WSTAACGRYMKVHDBNTAACGRYMKVHDBN";

  @override
  void prepare() {
    final n = Helper.configI64(runtimeType.toString().split('.').last, "n").toInt();

    final fasta = Fasta();
    fasta.n = n;
    fasta.prepare();
    fasta.runBenchmark(0);

    final fastaOutput = fasta.getResult();

    final lines = fastaOutput.split('\n');
    final seqParts = <String>[];
    var partCount = 0;

    for (final line in lines) {
      if (line.startsWith('>')) {

        seqParts.add("\n---\n");
      } else if (line.trim().isNotEmpty) {
        seqParts.add(line.trim());
      }
    }

    input = seqParts.join('');

  }

  static Uint8List _initLookupTable() {
    if (_lookupTable != null) return _lookupTable!;

    final lookup = Uint8List(256);
    for (int i = 0; i < 256; i++) lookup[i] = i;

    for (int i = 0; i < FROM.length; i++) {
      final fromChar = FROM.codeUnitAt(i);
      final toChar = TO.codeUnitAt(i);
      lookup[fromChar] = toChar;
    }

    _lookupTable = lookup;
    return lookup;
  }

  String _revcompGoStyle(String seq) {
    final len = seq.length;
    final lookup = _initLookupTable();

    const lineLength = 60;
    final numLines = (len + lineLength - 1) ~/ lineLength;

    final resultBytes = Uint8List(len + numLines);

    int writePos = 0;
    int readPos = len - 1;

    for (int line = 0; line < numLines; line++) {
      final charsInLine = min(lineLength, readPos + 1);

      for (int i = 0; i < charsInLine; i++) {
        final charCode = seq.codeUnitAt(readPos--);
        resultBytes[writePos++] = lookup[charCode];
      }

      resultBytes[writePos++] = 10; 
    }

    return String.fromCharCodes(resultBytes.sublist(0, writePos));
  }

  @override
  void runBenchmark(int iterationId) {
    final v = Helper.checksumString(_revcompGoStyle(input));
    resultValue = (resultValue + v) & 0xFFFFFFFF;
  }

  @override
  int checksum() {
    return resultValue & 0xFFFFFFFF;
  }
}

class Spectralnorm extends Benchmark {
  late int size;
  late List<double> u;
  late List<double> v;

  @override
  void prepare() {
    final className = runtimeType.toString().split('.').last;
    size = Helper.configI64(className, "size").toInt();
    u = List.filled(size, 1.0);
    v = List.filled(size, 1.0);
  }

  double _evalA(int i, int j) {
    return 1.0 / ((i + j) * (i + j + 1) / 2.0 + i + 1.0);
  }

  List<double> _evalATimesU(List<double> uVec) {
    final n = uVec.length;
    final result = List.filled(n, 0.0);

    for (int i = 0; i < n; i++) {
      double sum = 0.0;
      for (int j = 0; j < n; j++) {
        sum += _evalA(i, j) * uVec[j];
      }
      result[i] = sum;
    }

    return result;
  }

  List<double> _evalAtTimesU(List<double> uVec) {
    final n = uVec.length;
    final result = List.filled(n, 0.0);

    for (int i = 0; i < n; i++) {
      double sum = 0.0;
      for (int j = 0; j < n; j++) {
        sum += _evalA(j, i) * uVec[j];
      }
      result[i] = sum;
    }

    return result;
  }

  List<double> _evalAtATimesU(List<double> uVec) {
    return _evalAtTimesU(_evalATimesU(uVec));
  }

  @override
  void runBenchmark(int iterationId) {
    v = _evalAtATimesU(u);
    u = _evalAtATimesU(v);
  }

  @override
  int checksum() {
    double vBv = 0.0;
    double vv = 0.0;

    for (int i = 0; i < size; i++) {
      vBv += u[i] * v[i];
      vv += v[i] * v[i];
    }

    final result = sqrt(vBv / vv);
    return Helper.checksumFloat(result);
  }
}

class Base64Encode extends Benchmark {
  late int n;
  late String _str;
  late Uint8List _bytes;
  late String _str2;
  int _resultValue = 0;

  @override
  void prepare() {
    final className = runtimeType.toString().split('.').last;
    n = Helper.configI64(className, "size").toInt();

    _str = 'a' * n;
    _bytes = Uint8List(n); 
    for (int i = 0; i < n; i++) {
      _bytes[i] = 0x61;
    }

    _str2 = base64Encode(_bytes);
  }

  @override
  void runBenchmark(int iterationId) {

    _str2 = base64Encode(_bytes);
    _resultValue = (_resultValue + _str2.length) & 0xFFFFFFFF;
  }

  @override
  int checksum() {
    final output = 'encode ${_str.substring(0, min(4, _str.length))}... '
                  'to ${_str2.substring(0, min(4, _str2.length))}...: $_resultValue';
    return Helper.checksumString(output);
  }
}

class Base64Decode extends Benchmark {
  late int n;
  late String _str2;
  late Uint8List _bytes;
  int _resultValue = 0;

  @override
  void prepare() {
    final className = runtimeType.toString().split('.').last;
    n = Helper.configI64(className, "size").toInt();

    final bytes = Uint8List(n);
    for (int i = 0; i < n; i++) {
      bytes[i] = 0x61; 
    }

    _str2 = base64Encode(bytes);
    _bytes = base64Decode(_str2);
  }

  @override
  void runBenchmark(int iterationId) {

    _bytes = base64Decode(_str2);
    _resultValue = (_resultValue + _bytes.length) & 0xFFFFFFFF;
  }

  @override
  int checksum() {

    final str3 = String.fromCharCodes(_bytes);
    final output = 'decode ${_str2.substring(0, min(4, _str2.length))}... '
                  'to ${str3.substring(0, min(4, str3.length))}...: $_resultValue';
    return Helper.checksumString(output);
  }
}

class JsonGenerate extends Benchmark {
  int n = 0;
  List<Map<String, dynamic>> data = [];
  String text = '';
  int result = 0;

  JsonGenerate() {
    final className = runtimeType.toString().split('.').last;
    n = Helper.configI64(className, "coords").toInt();
  }

  @override
  void prepare() {
    Helper.reset();
    data = [];

    for (int i = 0; i < n; i++) {
      data.add({
        'x': double.parse(Helper.nextFloat().toStringAsFixed(8)),
        'y': double.parse(Helper.nextFloat().toStringAsFixed(8)),
        'z': double.parse(Helper.nextFloat().toStringAsFixed(8)),
        'name': '${Helper.nextFloat().toStringAsFixed(7)} ${Helper.nextInt(10000)}',
        'opts': {
          '1': [1, true],
        },
      });
    }
  }

  @override
  void runBenchmark(int iterationId) {
    final jsonData = {
      'coordinates': data,
      'info': 'some info',
    };

    text = jsonEncode(jsonData);

    if (text.startsWith('{"coordinates":')) {
      result++;
    }
  }

  String getText() => text;

  @override
  int checksum() {
    return result & 0xFFFFFFFF;
  }
}

class JsonParseDom extends Benchmark {
  String text = '';
  int resultValue = 0;

  @override
  void prepare() {
    final jsonGen = JsonGenerate();
    final className = runtimeType.toString().split('.').last;
    jsonGen.n = Helper.configI64(className, "coords").toInt();
    jsonGen.prepare();
    jsonGen.runBenchmark(0);
    text = jsonGen.getText();
  }

  (double, double, double) _calc(String text) {
    final json = jsonDecode(text) as Map<String, dynamic>;
    final coordinates = (json['coordinates'] as List).cast<Map<String, dynamic>>();
    final len = coordinates.length.toDouble();

    double x = 0, y = 0, z = 0;

    for (final coord in coordinates) {
      x += (coord['x'] as num).toDouble();
      y += (coord['y'] as num).toDouble();
      z += (coord['z'] as num).toDouble();
    }

    return (x / len, y / len, z / len);
  }

  @override
  void runBenchmark(int iterationId) {
    final (x, y, z) = _calc(text);

    resultValue = (resultValue + Helper.checksumFloat(x)) & 0xFFFFFFFF;
    resultValue = (resultValue + Helper.checksumFloat(y)) & 0xFFFFFFFF;
    resultValue = (resultValue + Helper.checksumFloat(z)) & 0xFFFFFFFF;
  }

  @override
  int checksum() {
    return resultValue & 0xFFFFFFFF;
  }
}

class JsonParseMapping extends Benchmark {
  String text = '';
  int resultValue = 0;

  @override
  void prepare() {
    final jsonGen = JsonGenerate();
    final className = runtimeType.toString().split('.').last;
    jsonGen.n = Helper.configI64(className, "coords").toInt();
    jsonGen.prepare();
    jsonGen.runBenchmark(0);
    text = jsonGen.getText();
  }

  ({double x, double y, double z}) _calc(String text) {
    final json = jsonDecode(text) as Map<String, dynamic>;
    final coordinates = (json['coordinates'] as List).cast<Map<String, dynamic>>();
    final len = coordinates.length.toDouble();

    double x = 0, y = 0, z = 0;

    for (final coord in coordinates) {
      x += (coord['x'] as num).toDouble();
      y += (coord['y'] as num).toDouble();
      z += (coord['z'] as num).toDouble();
    }

    return (x: x / len, y: y / len, z: z / len);
  }

  @override
  void runBenchmark(int iterationId) {
    final coord = _calc(text);

    resultValue = (resultValue + Helper.checksumFloat(coord.x)) & 0xFFFFFFFF;
    resultValue = (resultValue + Helper.checksumFloat(coord.y)) & 0xFFFFFFFF;
    resultValue = (resultValue + Helper.checksumFloat(coord.z)) & 0xFFFFFFFF;
  }

  @override
  int checksum() {
    return resultValue & 0xFFFFFFFF;
  }
}

class PrimesNode {
  final List<PrimesNode?> children = List.filled(10, null);
  bool terminal = false;
}

class Primes extends Benchmark {
  late BigInt n;
  late BigInt prefix;
  int _resultValue = 5432;

  @override
  void prepare() {
    final className = runtimeType.toString().split('.').last;
    n = Helper.configI64(className, "limit");
    prefix = Helper.configI64(className, "prefix");
  }

  List<int> _generatePrimes(int limit) {
    if (limit < 2) return [];

    final isPrime = List<bool>.filled(limit + 1, true);
    isPrime[0] = isPrime[1] = false;

    final sqrtLimit = sqrt(limit).floor();

    for (int p = 2; p <= sqrtLimit; p++) {
      if (isPrime[p]) {
        for (int multiple = p * p; multiple <= limit; multiple += p) {
          isPrime[multiple] = false;
        }
      }
    }

    final estimatedSize = (limit / (log(limit) - 1.1)).floor();
    final primes = List<int>.filled(estimatedSize, 0);
    var count = 0;

    for (int i = 2; i <= limit; i++) {
      if (isPrime[i]) {
        primes[count++] = i;
      }
    }

    return primes.sublist(0, count);
  }

  PrimesNode _buildTrie(List<int> numbers) {
    final root = PrimesNode();

    for (final num in numbers) {
      var current = root;
      final str = num.toString();

      for (int i = 0; i < str.length; i++) {
        final digit = str.codeUnitAt(i) - 48;

        if (current.children[digit] == null) {
          current.children[digit] = PrimesNode();
        }
        current = current.children[digit]!;
      }
      current.terminal = true;
    }

    return root;
  }

  List<int> _findPrimesWithPrefix(PrimesNode root, int prefix) {
    final prefixStr = prefix.toString();
    var current = root;

    for (int i = 0; i < prefixStr.length; i++) {
      final digit = prefixStr.codeUnitAt(i) - 48;
      final next = current.children[digit];
      if (next == null) {
        return [];
      }
      current = next;
    }

    final results = <int>[];
    final queue = Queue<(PrimesNode, int)>();
    queue.add((current, prefix));

    while (queue.isNotEmpty) {
      final (node, number) = queue.removeFirst();

      if (node.terminal) {
        results.add(number);
      }

      for (int digit = 0; digit < 10; digit++) {
        final child = node.children[digit];
        if (child != null) {
          queue.add((child, number * 10 + digit));
        }
      }
    }

    results.sort();
    return results;
  }

  @override
  void runBenchmark(int iterationId) {
    final primes = _generatePrimes(n.toInt());
    final trie = _buildTrie(primes);
    final results = _findPrimesWithPrefix(trie, prefix.toInt());

    _resultValue = (_resultValue + results.length) & 0xFFFFFFFF;
    for (final num in results) {
      _resultValue = (_resultValue + num) & 0xFFFFFFFF;
    }
  }

  @override
  int checksum() {
    return _resultValue;
  }
}

class NoiseVec2 {
  final double x, y;

  NoiseVec2(this.x, this.y);
}

class Noise2DContext {
  final int size;
  final int mask;
  final List<NoiseVec2> _rgradients;
  final List<int> _permutations;

  Noise2DContext(this.size) : 
    mask = size - 1,
    _rgradients = List.generate(size, (_) {
      final v = Helper.nextFloat() * pi * 2.0;
      return NoiseVec2(cos(v), sin(v));
    }),
    _permutations = List.generate(size, (i) => i) {

    for (int i = 0; i < size; i++) {
      final a = Helper.nextInt(size);
      final b = Helper.nextInt(size);
      final temp = _permutations[a];
      _permutations[a] = _permutations[b];
      _permutations[b] = temp;
    }
  }

  double _gradient(double ox, double oy, NoiseVec2 grad, double px, double py) {
    return grad.x * (px - ox) + grad.y * (py - oy);
  }

  double _lerp(double a, double b, double v) => a + (b - a) * v;

  double _smooth(double v) => v * v * (3.0 - 2.0 * v);

  NoiseVec2 _getGradient(int x, int y) {
    final idx = _permutations[x & mask] + _permutations[y & mask];
    return _rgradients[idx & mask];
  }

  double get(double x, double y) {
    final x0f = x.floorToDouble();  
    final y0f = y.floorToDouble();
    final x0 = x0f.toInt();
    final y0 = y0f.toInt();

    final g00 = _getGradient(x0, y0);
    final g10 = _getGradient(x0 + 1, y0);
    final g01 = _getGradient(x0, y0 + 1);
    final g11 = _getGradient(x0 + 1, y0 + 1);

    final v0 = _gradient(x0f, y0f, g00, x, y);
    final v1 = _gradient(x0f + 1.0, y0f, g10, x, y);
    final v2 = _gradient(x0f, y0f + 1.0, g01, x, y);
    final v3 = _gradient(x0f + 1.0, y0f + 1.0, g11, x, y);

    final fx = _smooth(x - x0f);
    final vx0 = _lerp(v0, v1, fx);
    final vx1 = _lerp(v2, v3, fx);

    final fy = _smooth(y - y0f);
    return _lerp(vx0, vx1, fy);
  }
}

class Noise extends Benchmark {
  static const _sym = [' ', '░', '▒', '▓', '█', '█'];

  late int size;
  late Noise2DContext _n2d;
  int _resultValue = 0;

  @override
  void prepare() {
    final className = runtimeType.toString().split('.').last;
    size = Helper.configI64(className, "size").toInt();
    _n2d = Noise2DContext(size);
  }

  @override
  void runBenchmark(int iterationId) {
    for (int y = 0; y < size; y++) {
      for (int x = 0; x < size; x++) {
        final v = _n2d.get(x * 0.1, (y + (iterationId * 128)) * 0.1) * 0.5 + 0.5;
        final idx = (v / 0.2).floor();
        final charIdx = idx.clamp(0, _sym.length - 1);
        _resultValue = (_resultValue + _sym[charIdx].codeUnitAt(0)) & 0xFFFFFFFF;
      }
    }
  }

  @override
  int checksum() {
    return _resultValue;
  }
}

class TextRaytracer extends Benchmark {
  static final _white = TextRaytracerColor(1.0, 1.0, 1.0);
  static final _red = TextRaytracerColor(1.0, 0.0, 0.0);
  static final _green = TextRaytracerColor(0.0, 1.0, 0.0);
  static final _blue = TextRaytracerColor(0.0, 0.0, 1.0);

  static final _light1 = TextRaytracerLight(
    TextRaytracerVector(0.7, -1.0, 1.7),
    _white,
  );

  static final _scene = [
    TextRaytracerSphere(TextRaytracerVector(-1.0, 0.0, 3.0), 0.3, _red),
    TextRaytracerSphere(TextRaytracerVector(0.0, 0.0, 3.0), 0.8, _green),
    TextRaytracerSphere(TextRaytracerVector(1.0, 0.0, 3.0), 0.4, _blue),
  ];

  static const _lut = ['.', '-', '+', '*', 'X', 'M'];

  late int w, h;
  int _resultValue = 0;

  @override
  void prepare() {
    final className = runtimeType.toString().split('.').last;
    w = Helper.configI64(className, "w").toInt();
    h = Helper.configI64(className, "h").toInt();
  }

  @pragma('vm:prefer-inline')
  int _shadePixel(TextRaytracerRay ray, TextRaytracerSphere obj, double tval) {
    final pi = ray.orig.add(ray.dir.scale(tval));
    final color = _diffuseShading(pi, obj, _light1);
    final col = (color.r + color.g + color.b) / 3.0;
    return (col * 6.0).floor();
  }

  @pragma('vm:prefer-inline')
  double? _intersectSphere(
    TextRaytracerRay ray, 
    TextRaytracerVector center, 
    double radius
  ) {
    final l = center.subtract(ray.orig);
    final tca = l.dot(ray.dir);

    if (tca < 0.0) return null;

    final d2 = l.dot(l) - tca * tca;
    final r2 = radius * radius;

    if (d2 > r2) return null;

    final thc = sqrt(r2 - d2);
    final t0 = tca - thc;

    if (t0 > 10000) return null;

    return t0;
  }

  @pragma('vm:prefer-inline')
  double _clamp(double x, double a, double b) => x < a ? a : (x > b ? b : x);

  @pragma('vm:prefer-inline')
  TextRaytracerColor _diffuseShading(
    TextRaytracerVector pi,
    TextRaytracerSphere obj,
    TextRaytracerLight light,
  ) {
    final n = obj.getNormal(pi);
    final lam1 = light.position.subtract(pi).normalize().dot(n);
    final lam2 = _clamp(lam1, 0.0, 1.0);
    return light.color.scale(lam2 * 0.5).add(obj.color.scale(0.3));
  }

  @pragma('vm:prefer-inline')
  TextRaytracerVector _createRayDir(int i, int j, double fw, double fh) {
    return TextRaytracerVector(
      (i - fw / 2.0) / fw,
      (j - fh / 2.0) / fh,
      1.0,
    ).normalize();
  }

  @override
  void runBenchmark(int iterationId) {
    var res = 0;
    final fw = w.toDouble();
    final fh = h.toDouble();

    for (int j = 0; j < h; j++) {
      for (int i = 0; i < w; i++) {
        final ray = TextRaytracerRay(
          TextRaytracerVector(0.0, 0.0, 0.0),
          _createRayDir(i, j, fw, fh),
        );

        TextRaytracerSphere? hitObj;
        double? tval;

        for (final obj in _scene) {
          final ret = _intersectSphere(ray, obj.center, obj.radius);
          if (ret != null) {
            hitObj = obj;
            tval = ret;
            break;
          }
        }

        final pixel = hitObj != null 
            ? _lut[_shadePixel(ray, hitObj, tval!).clamp(0, _lut.length - 1)]
            : ' ';

        res += pixel.codeUnitAt(0);
      }
    }

    _resultValue = (_resultValue + res) & 0xFFFFFFFF;
  }

  @override
  int checksum() {
    return _resultValue;
  }
}

class TextRaytracerVector {
  final double x, y, z;

  TextRaytracerVector(this.x, this.y, this.z);

  @pragma('vm:prefer-inline')
  TextRaytracerVector scale(double s) => 
    TextRaytracerVector(x * s, y * s, z * s);

  @pragma('vm:prefer-inline')
  TextRaytracerVector add(TextRaytracerVector other) =>
    TextRaytracerVector(x + other.x, y + other.y, z + other.z);

  @pragma('vm:prefer-inline')
  TextRaytracerVector subtract(TextRaytracerVector other) =>
    TextRaytracerVector(x - other.x, y - other.y, z - other.z);

  @pragma('vm:prefer-inline')
  double dot(TextRaytracerVector other) =>
    x * other.x + y * other.y + z * other.z;

  double magnitude() => sqrt(dot(this));

  TextRaytracerVector normalize() => scale(1.0 / magnitude());
}

class TextRaytracerRay {
  final TextRaytracerVector orig, dir;

  TextRaytracerRay(this.orig, this.dir);
}

class TextRaytracerColor {
  final double r, g, b;

  TextRaytracerColor(this.r, this.g, this.b);

  @pragma('vm:prefer-inline')
  TextRaytracerColor scale(double s) =>
    TextRaytracerColor(r * s, g * s, b * s);

  @pragma('vm:prefer-inline')
  TextRaytracerColor add(TextRaytracerColor other) =>
    TextRaytracerColor(r + other.r, g + other.g, b + other.b);
}

class TextRaytracerSphere {
  final TextRaytracerVector center;
  final double radius;
  final TextRaytracerColor color;

  TextRaytracerSphere(this.center, this.radius, this.color);

  TextRaytracerVector getNormal(TextRaytracerVector pt) =>
    pt.subtract(center).normalize();
}

class TextRaytracerLight {
  final TextRaytracerVector position;
  final TextRaytracerColor color;

  TextRaytracerLight(this.position, this.color);
}

class NeuralNetSynapse {
  late double weight;
  late double prevWeight;
  final NeuralNetNeuron sourceNeuron;
  final NeuralNetNeuron destNeuron;

  NeuralNetSynapse(this.sourceNeuron, this.destNeuron) {

    final randomWeight = Helper.nextFloat() * 2 - 1;
    prevWeight = randomWeight;
    weight = randomWeight;
  }
}

class NeuralNetNeuron {
  static const learningRate = 1.0;
  static const momentum = 0.3;

  final synapsesIn = <NeuralNetSynapse>[];
  final synapsesOut = <NeuralNetSynapse>[];
  late double threshold;
  late double prevThreshold;
  double error = 0;
  double output = 0;

  NeuralNetNeuron() {

    final randomThreshold = Helper.nextFloat() * 2 - 1;
    prevThreshold = randomThreshold;
    threshold = randomThreshold;
  }

  void calculateOutput() {
    var activation = 0.0;
    for (final synapse in synapsesIn) {
      activation += synapse.weight * synapse.sourceNeuron.output;
    }
    activation -= threshold;

    output = 1.0 / (1.0 + exp(-activation));
  }

  double derivative() => output * (1 - output);

  void outputTrain(double rate, double target) {
    error = (target - output) * derivative();
    _updateWeights(rate);
  }

  void hiddenTrain(double rate) {
    error = 0.0;  
    for (final synapse in synapsesOut) {
      error += synapse.prevWeight * synapse.destNeuron.error;
    }
    error *= derivative();
    _updateWeights(rate);
  }

  void _updateWeights(double rate) {
    for (final synapse in synapsesIn) {
      final tempWeight = synapse.weight;
      synapse.weight += (rate * learningRate * error * synapse.sourceNeuron.output) +
                       (momentum * (synapse.weight - synapse.prevWeight));
      synapse.prevWeight = tempWeight;
    }

    final tempThreshold = threshold;
    threshold += (rate * learningRate * error * -1) +
                (momentum * (threshold - prevThreshold));
    prevThreshold = tempThreshold;
  }
}

class NeuralNetNetwork {
  final inputLayer = <NeuralNetNeuron>[];
  final hiddenLayer = <NeuralNetNeuron>[];
  final outputLayer = <NeuralNetNeuron>[];

  NeuralNetNetwork(int inputs, int hidden, int outputs) {
    inputLayer.addAll(List.generate(inputs, (_) => NeuralNetNeuron()));
    hiddenLayer.addAll(List.generate(hidden, (_) => NeuralNetNeuron()));
    outputLayer.addAll(List.generate(outputs, (_) => NeuralNetNeuron()));

    for (final source in inputLayer) {
      for (final dest in hiddenLayer) {
        final synapse = NeuralNetSynapse(source, dest);
        source.synapsesOut.add(synapse);
        dest.synapsesIn.add(synapse);
      }
    }

    for (final source in hiddenLayer) {
      for (final dest in outputLayer) {
        final synapse = NeuralNetSynapse(source, dest);
        source.synapsesOut.add(synapse);
        dest.synapsesIn.add(synapse);
      }
    }
  }

  void train(List<double> inputs, List<double> targets) {
    feedForward(inputs);

    for (int i = 0; i < outputLayer.length; i++) {
      outputLayer[i].outputTrain(0.3, targets[i]);
    }

    for (final neuron in hiddenLayer) {
      neuron.hiddenTrain(0.3);
    }
  }

  void feedForward(List<double> inputs) {
    for (int i = 0; i < inputLayer.length; i++) {
      inputLayer[i].output = inputs[i];
    }

    for (final neuron in hiddenLayer) {
      neuron.calculateOutput();
    }

    for (final neuron in outputLayer) {
      neuron.calculateOutput();
    }
  }

  List<double> currentOutputs() => 
    outputLayer.map((neuron) => neuron.output).toList();

  double getWeightSum() {
    double sum = 0;
    for (final neuron in [...inputLayer, ...hiddenLayer, ...outputLayer]) {
      sum += neuron.threshold;
      for (final synapse in neuron.synapsesOut) {
        sum += synapse.weight;
      }
    }
    return sum;
  }
}

class NeuralNet extends Benchmark {
  late NeuralNetNetwork xor;

  @override
  void prepare() {
    Helper.reset();  
    xor = NeuralNetNetwork(2, 10, 1);
  }

  @override
  void runBenchmark(int iterationId) {
    xor.train([0, 0], [0]);
    xor.train([1, 0], [1]);
    xor.train([0, 1], [1]);
    xor.train([1, 1], [0]);
  }

  @override
  int checksum() {
    final results = <double>[];

    xor.feedForward([0, 0]);
    results.addAll(xor.currentOutputs());

    xor.feedForward([0, 1]);
    results.addAll(xor.currentOutputs());

    xor.feedForward([1, 0]);
    results.addAll(xor.currentOutputs());

    xor.feedForward([1, 1]);
    results.addAll(xor.currentOutputs());

    final sum = results.fold(0.0, (a, b) => a + b);
    final checksumValue = Helper.checksumFloat(sum);

    return checksumValue;
  }
}

abstract class SortBenchmark extends Benchmark {
  late List<int> _data;
  late int size;
  int _resultValue = 0;

  @override
  void prepare() {
    final className = runtimeType.toString().split('.').last;
    size = Helper.configI64(className, "size").toInt();

    Helper.reset();
    _data = [];
    for (int i = 0; i < size; i++) {
      _data.add(Helper.nextInt(1000000));
    }
  }

  List<int> test();

  @override
  void runBenchmark(int iterationId) {
    _resultValue = (_resultValue + _data[Helper.nextInt(size)]) & 0xFFFFFFFF;
    final t = test();
    _resultValue = (_resultValue + t[Helper.nextInt(size)]) & 0xFFFFFFFF;
  }

  @override
  int checksum() {
    return _resultValue;
  }
}

class SortQuick extends SortBenchmark {
  @override
  List<int> test() {
    final arr = List<int>.from(_data);
    _quickSort(arr, 0, arr.length - 1);
    return arr;
  }

  void _quickSort(List<int> arr, int low, int high) {
    if (low >= high) return;

    final pivot = arr[(low + high) ~/ 2];
    var i = low;
    var j = high;

    while (i <= j) {
      while (arr[i] < pivot) i++;
      while (arr[j] > pivot) j--;

      if (i <= j) {
        final temp = arr[i];
        arr[i] = arr[j];
        arr[j] = temp;
        i++;
        j--;
      }
    }

    _quickSort(arr, low, j);
    _quickSort(arr, i, high);
  }
}

class SortMerge extends SortBenchmark {
  @override
  List<int> test() {
    final arr = List<int>.from(_data);
    _mergeSortInplace(arr);
    return arr;
  }

  void _mergeSortInplace(List<int> arr) {
    final temp = List<int>.filled(arr.length, 0);
    _mergeSortHelper(arr, temp, 0, arr.length - 1);
  }

  void _mergeSortHelper(List<int> arr, List<int> temp, int left, int right) {
    if (left >= right) return;

    final mid = (left + right) ~/ 2;
    _mergeSortHelper(arr, temp, left, mid);
    _mergeSortHelper(arr, temp, mid + 1, right);
    _merge(arr, temp, left, mid, right);
  }

  void _merge(List<int> arr, List<int> temp, int left, int mid, int right) {
    for (int i = left; i <= right; i++) {
      temp[i] = arr[i];
    }

    var i = left;
    var j = mid + 1;
    var k = left;

    while (i <= mid && j <= right) {
      if (temp[i] <= temp[j]) {
        arr[k] = temp[i];
        i++;
      } else {
        arr[k] = temp[j];
        j++;
      }
      k++;
    }

    while (i <= mid) {
      arr[k] = temp[i];
      i++;
      k++;
    }
  }
}

class SortSelf extends SortBenchmark {
  @override
  List<int> test() {
    final arr = List<int>.from(_data);
    arr.sort();
    return arr;
  }
}

class GraphPathGraph {
  final int vertices;
  final List<List<int>> _adj;
  final int components;

  GraphPathGraph(this.vertices, [int components = 10])
    : components = max(10, min(components, vertices ~/ 10000)),
      _adj = List.generate(vertices, (_) => []);

  void addEdge(int u, int v) {
    _adj[u].add(v);
    _adj[v].add(u);
  }

  void generateRandom() {
    final componentSize = vertices ~/ components;

    for (int c = 0; c < components; c++) {
      final startIdx = c * componentSize;
      final endIdx = c == components - 1 ? vertices : (c + 1) * componentSize;

      for (int i = startIdx + 1; i < endIdx; i++) {
        final parent = startIdx + Helper.nextInt(i - startIdx);
        addEdge(i, parent);
      }

      for (int i = 0; i < componentSize * 2; i++) {
        final u = startIdx + Helper.nextInt(endIdx - startIdx);
        final v = startIdx + Helper.nextInt(endIdx - startIdx);
        if (u != v) {
          addEdge(u, v);
        }
      }
    }
  }

  List<List<int>> getAdjacency() => _adj;

  int getVertices() => vertices;
}

abstract class GraphPathBenchmark extends Benchmark {
  late GraphPathGraph _graph;
  late List<(int, int)> _pairs;
  late int _nPairs;
  int _resultValue = 0;

  @override
  void prepare() {
    final className = runtimeType.toString().split('.').last;
    final vertices = Helper.configI64(className, "vertices").toInt();
    _nPairs = Helper.configI64(className, "pairs").toInt();

    _graph = GraphPathGraph(vertices, max(10, vertices ~/ 10000));
    _graph.generateRandom();
    _pairs = _generatePairs(_nPairs);
  }

  List<(int, int)> _generatePairs(int n) {
    final pairs = <(int, int)>[];
    final componentSize = _graph.getVertices() ~/ 10;

    for (int i = 0; i < n; i++) {
      if (Helper.nextInt(100) < 70) {

        final component = Helper.nextInt(10);
        final start = component * componentSize + Helper.nextInt(componentSize);
        int end;
        do {
          end = component * componentSize + Helper.nextInt(componentSize);
        } while (end == start);
        pairs.add((start, end));
      } else {

        int c1 = Helper.nextInt(10);
        int c2;
        do {
          c2 = Helper.nextInt(10);
        } while (c2 == c1);
        final start = c1 * componentSize + Helper.nextInt(componentSize);
        final end = c2 * componentSize + Helper.nextInt(componentSize);
        pairs.add((start, end));
      }
    }

    return pairs;
  }

  @override
  int checksum() {
    return _resultValue & 0xFFFFFFFF;
  }
}

class GraphPathBFS extends GraphPathBenchmark {
  @override
  void runBenchmark(int iterationId) {
    for (final (start, end) in _pairs) {
      final length = _bfsShortestPath(start, end);
      _resultValue = (_resultValue + length) & 0xFFFFFFFF;
    }
  }

  int _bfsShortestPath(int start, int target) {
    if (start == target) return 0;

    final visited = Uint8List(_graph.getVertices());
    final queue = Queue<(int, int)>();
    queue.add((start, 0));
    visited[start] = 1;

    while (queue.isNotEmpty) {
      final (v, dist) = queue.removeFirst();

      for (final neighbor in _graph.getAdjacency()[v]) {
        if (neighbor == target) {
          return dist + 1;
        }

        if (visited[neighbor] == 0) {
          visited[neighbor] = 1;
          queue.add((neighbor, dist + 1));
        }
      }
    }

    return -1;
  }
}

class GraphPathDFS extends GraphPathBenchmark {
  @override
  void runBenchmark(int iterationId) {
    for (final (start, end) in _pairs) {
      final length = _dfsFindPath(start, end);
      _resultValue = (_resultValue + length) & 0xFFFFFFFF;
    }
  }

  int _dfsFindPath(int start, int target) {
    if (start == target) return 0;

    final visited = Uint8List(_graph.getVertices());
    final stack = <(int, int)>[(start, 0)];
    var bestPath = 0x7FFFFFFFFFFFFFFF; 

    while (stack.isNotEmpty) {
      final (v, dist) = stack.removeLast();

      if (visited[v] == 1 || dist >= bestPath) continue;
      visited[v] = 1;

      for (final neighbor in _graph.getAdjacency()[v]) {
        if (neighbor == target) {
          if (dist + 1 < bestPath) {
            bestPath = dist + 1;
          }
        } else if (visited[neighbor] == 0) {
          stack.add((neighbor, dist + 1));
        }
      }
    }

    return bestPath == 0x7FFFFFFFFFFFFFFF ? -1 : bestPath.toInt();
  }
}

class GraphPathDijkstra extends GraphPathBenchmark {
  static const int _inf = 0x7FFFFFFF; 

  @override
  void runBenchmark(int iterationId) {
    for (final (start, end) in _pairs) {
      final length = _dijkstraShortestPath(start, end);
      _resultValue = (_resultValue + length) & 0xFFFFFFFF;
    }
  }

  int _dijkstraShortestPath(int start, int target) {
    if (start == target) return 0;

    final vertices = _graph.getVertices();
    final dist = List<int>.filled(vertices, _inf);
    final visited = Uint8List(vertices);

    dist[start] = 0;
    final maxIterations = vertices;

    for (int iteration = 0; iteration < maxIterations; iteration++) {
      int u = -1;
      int minDist = _inf;

      for (int v = 0; v < vertices; v++) {
        if (visited[v] == 0 && dist[v] < minDist) {
          minDist = dist[v];
          u = v;
        }
      }

      if (u == -1 || minDist == _inf || u == target) {
        return u == target ? minDist : -1;
      }

      visited[u] = 1;

      for (final v in _graph.getAdjacency()[u]) {
        if (dist[u] + 1 < dist[v]) {
          dist[v] = dist[u] + 1;
        }
      }
    }

    return -1;
  }
}

abstract class BufferHashBenchmark extends Benchmark {
  late Uint8List _data;
  late int _n;
  int _result = 0;

  @override
  void prepare() {
    final className = runtimeType.toString().split('.').last;
    _n = Helper.configI64(className, "size").toInt();

    _data = Uint8List(_n);

    for (int i = 0; i < _data.length; i++) {
      _data[i] = Helper.nextInt(256);
    }
  }

  int test();

  @override
  void runBenchmark(int iterationId) {

    final hash = test();
    _result = (_result + hash) & 0xFFFFFFFF;
  }

  @override
  int checksum() {
    return _result & 0xFFFFFFFF;
  }
}

class BufferHashCRC32 extends BufferHashBenchmark {
  @override
  int test() {

    int crc = 0xFFFFFFFF;

    for (int i = 0; i < _data.length; i++) {
      final byte = _data[i];

      crc ^= byte;

      for (int j = 0; j < 8; j++) {

        if ((crc & 1) != 0) {

          crc = (crc >>> 1) ^ 0xEDB88320;
        } else {

          crc = crc >>> 1;
        }
      }
    }

    return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF;
  }
}

class BufferHashSHA256 extends BufferHashBenchmark {
  @override
  int test() {

    final hashes = Uint32List(8);
    hashes[0] = 0x6a09e667;
    hashes[1] = 0xbb67ae85;
    hashes[2] = 0x3c6ef372;
    hashes[3] = 0xa54ff53a;
    hashes[4] = 0x510e527f;
    hashes[5] = 0x9b05688c;
    hashes[6] = 0x1f83d9ab;
    hashes[7] = 0x5be0cd19;

    for (int i = 0; i < _data.length; i++) {
      final hashIdx = i % 8;

      int hash = hashes[hashIdx];

      final b = _data[i];

      hash = (((hash << 5) + hash) + (b & 0xFF)) & 0xFFFFFFFF;

      hash = ((hash + (hash << 10)) & 0xFFFFFFFF) ^ (hash >>> 6);
      hash = hash & 0xFFFFFFFF;

      hashes[hashIdx] = hash;
    }

    final result = Uint8List(32);

    for (int i = 0; i < 8; i++) {

      final hash = hashes[i];

      result[i * 4] = (hash >> 24) & 0xFF;
      result[i * 4 + 1] = (hash >> 16) & 0xFF;
      result[i * 4 + 2] = (hash >> 8) & 0xFF;
      result[i * 4 + 3] = hash & 0xFF;
    }

    return (result[0] & 0xFF) |
           ((result[1] & 0xFF) << 8) |
           ((result[2] & 0xFF) << 16) |
           ((result[3] & 0xFF) << 24);
  }
}

class FastLRUCache<K, V> {
  final int capacity;
  final Map<K, _Node<K, V>> _cache;
  int _size = 0;
  _Node<K, V>? _head;
  _Node<K, V>? _tail;

  FastLRUCache(this.capacity) : _cache = {};

  @pragma('vm:prefer-inline')
  V? get(K key) {
    final node = _cache[key];
    if (node == null) return null;

    _moveToFront(node);
    return node.value;
  }

  @pragma('vm:prefer-inline')
  void put(K key, V value) {
    var node = _cache[key];
    if (node != null) {
      node.value = value;
      _moveToFront(node);
      return;
    }

    if (_size >= capacity) {
      _removeOldest();
    }

    node = _Node<K, V>(key, value);
    _cache[key] = node;
    _addToFront(node);
    _size++;
  }

  int size() => _size;

  @pragma('vm:prefer-inline')
  void _moveToFront(_Node<K, V> node) {
    if (node == _head) return;

    if (node.prev != null) node.prev!.next = node.next;
    if (node.next != null) node.next!.prev = node.prev;

    if (node == _tail) {
      _tail = node.prev;
    }

    node.prev = null;
    node.next = _head;
    if (_head != null) _head!.prev = node;
    _head = node;

    if (_tail == null) _tail = node;
  }

  @pragma('vm:prefer-inline')
  void _addToFront(_Node<K, V> node) {
    node.next = _head;
    if (_head != null) _head!.prev = node;
    _head = node;
    if (_tail == null) _tail = node;
  }

  @pragma('vm:prefer-inline')
  void _removeOldest() {
    if (_tail == null) return;

    final oldest = _tail!;
    _cache.remove(oldest.key);

    if (oldest.prev != null) {
      oldest.prev!.next = null;
      _tail = oldest.prev;
    } else {
      _head = null;
      _tail = null;
    }

    _size--;
  }
}

class _Node<K, V> {
  final K key;
  V value;
  _Node<K, V>? prev;
  _Node<K, V>? next;

  _Node(this.key, this.value);
}

class CacheSimulation extends Benchmark {
  late int _valuesSize;
  late int _cacheSize;
  late FastLRUCache<String, String> _cache;
  int _hits = 0;
  int _misses = 0;
  static const _initialResult = 5432;

  @override
  void prepare() {
    final className = runtimeType.toString().split('.').last;
    _valuesSize = Helper.configI64(className, "values").toInt();
    _cacheSize = Helper.configI64(className, "size").toInt();
    _cache = FastLRUCache(_cacheSize);

    _hits = 0;
    _misses = 0;
    Helper.reset();
  }

  @override
  void runBenchmark(int iterationId) {
    final key = 'item_${Helper.nextInt(_valuesSize)}';

    if (_cache.get(key) != null) {
      _hits++;
      _cache.put(key, 'updated_$iterations');
    } else {
      _misses++;
      _cache.put(key, 'new_$iterations');
    }
  }

  @override
  int checksum() {
    var result = _initialResult;
    result = ((result << 5) + _hits) & 0xFFFFFFFF;
    result = ((result << 5) + _misses) & 0xFFFFFFFF;
    result = ((result << 5) + _cache.size()) & 0xFFFFFFFF;
    return result;
  }
}

abstract class Node2 {}

class NumberNode extends Node2 {
  final int value;
  NumberNode(this.value);
}

class VariableNode extends Node2 {
  final String name;
  VariableNode(this.name);
}

class BinaryOpNode extends Node2 {
  final String op;
  final Node2 left;
  final Node2 right;

  BinaryOpNode(this.op, this.left, this.right);
}

class AssignmentNode extends Node2 {
  final String varName;
  final Node2 expr;

  AssignmentNode(this.varName, this.expr);
}

class Parser2 {
  final String input;
  int pos = 0;
  late List<String> chars;
  String currentChar = '\0';
  final expressions = <Node2>[];

  Parser2(this.input) {
    chars = input.split('');
    currentChar = chars.isNotEmpty ? chars[0] : '\0';
  }

  void parse() {
    while (pos < chars.length) {
      skipWhitespace();
      if (pos >= chars.length) break;

      final expr = parseExpression();
      expressions.add(expr);
    }
  }

  Node2 parseExpression() {
    var node = parseTerm();

    while (pos < chars.length) {
      skipWhitespace();
      if (pos >= chars.length) break;

      if (currentChar == '+' || currentChar == '-') {
        final op = currentChar;
        advance();
        final right = parseTerm();
        node = BinaryOpNode(op, node, right);
      } else {
        break;
      }
    }

    return node;
  }

  Node2 parseTerm() {
    var node = parseFactor();

    while (pos < chars.length) {
      skipWhitespace();
      if (pos >= chars.length) break;

      if (currentChar == '*' || currentChar == '/' || currentChar == '%') {
        final op = currentChar;
        advance();
        final right = parseFactor();
        node = BinaryOpNode(op, node, right);
      } else {
        break;
      }
    }

    return node;
  }

  Node2 parseFactor() {
    skipWhitespace();
    if (pos >= chars.length) {
      return NumberNode(0);
    }

    final char = currentChar;

    if (isDigit(char)) {
      return parseNumber();
    } else if (isLetter(char)) {
      return parseVariable();
    } else if (char == '(') {
      advance();
      final node = parseExpression();
      skipWhitespace();
      if (currentChar == ')') {
        advance();
      }
      return node;
    } else {
      return NumberNode(0);
    }
  }

  NumberNode parseNumber() {
    var value = 0;
    while (pos < chars.length && isDigit(currentChar)) {
      final digit = currentChar.codeUnitAt(0) - '0'.codeUnitAt(0);
      value = value * 10 + digit;
      advance();
    }
    return NumberNode(value);
  }

  Node2 parseVariable() {
    final start = pos;
    while (pos < chars.length && 
          (isLetter(currentChar) || isDigit(currentChar))) {
      advance();
    }

    final varName = input.substring(start, pos);

    skipWhitespace();
    if (currentChar == '=') {
      advance();
      final expr = parseExpression();
      return AssignmentNode(varName, expr);
    }

    return VariableNode(varName);
  }

  void advance() {
    pos++;
    if (pos >= chars.length) {
      currentChar = '\0';
    } else {
      currentChar = chars[pos];
    }
  }

  void skipWhitespace() {
    while (pos < chars.length && isWhitespace(currentChar)) {
      advance();
    }
  }

  bool isDigit(String ch) => ch.codeUnitAt(0) >= 48 && ch.codeUnitAt(0) <= 57;

  bool isLetter(String ch) {
    final code = ch.codeUnitAt(0);
    return (code >= 65 && code <= 90) || (code >= 97 && code <= 122);
  }

  bool isWhitespace(String ch) => 
      ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r';
}

class CalculatorAst extends Benchmark {
  late int n;
  String _text = '';
  final _expressions = <Node2>[];
  int _resultValue = 0;

  @override
  void prepare() {
    final className = runtimeType.toString().split('.').last;
    n = Helper.configI64(className, "operations").toInt();
    _text = _generateRandomProgram(n);
  }

  String _generateRandomProgram(int n) {
    final buffer = StringBuffer();
    buffer.writeln('v0 = 1');

    for (int i = 0; i < 10; i++) {
      final v = i + 1;
      buffer.writeln('v$v = v${v - 1} + $v');
    }

    for (int i = 0; i < n; i++) {
      final v = i + 10;
      buffer.write('v$v = v${v - 1} + ');

      switch (Helper.nextInt(10)) {
        case 0:
          buffer.write('(v${v - 1} / 3) * 4 - $i / (3 + (18 - v${v - 2})) % v${v - 3} + 2 * ((9 - v${v - 6}) * (v${v - 5} + 7))');
          break;
        case 1:
          buffer.write('v${v - 1} + (v${v - 2} + v${v - 3}) * v${v - 4} - (v${v - 5} / v${v - 6})');
          break;
        case 2:
          buffer.write('(3789 - (((v${v - 7})))) + 1');
          break;
        case 3:
          buffer.write('4/2 * (1-3) + v${v - 9}/v${v - 5}');
          break;
        case 4:
          buffer.write('1+2+3+4+5+6+v${v - 1}');
          break;
        case 5:
          buffer.write('(99999 / v${v - 3})');
          break;
        case 6:
          buffer.write('0 + 0 - v${v - 8}');
          break;
        case 7:
          buffer.write('((((((((((v${v - 6})))))))))) * 2');
          break;
        case 8:
          buffer.write('$i * (v${v - 1} % 6) % 7');
          break;
        case 9:
          buffer.write('(1)/(0-v${v - 5}) + (v${v - 7})');
          break;
      }
      buffer.writeln();
    }

    return buffer.toString();
  }

  @override
  void runBenchmark(int iterationId) {
    final parser = Parser2(_text);
    parser.parse();
    _expressions.clear();
    _expressions.addAll(parser.expressions);

    _resultValue = (_resultValue + _expressions.length) & 0xFFFFFFFF;

    if (_expressions.isNotEmpty) {
      final lastExpr = _expressions.last;
      if (lastExpr is AssignmentNode) {
        _resultValue = (_resultValue + Helper.checksumString(lastExpr.varName)) & 0xFFFFFFFF;
      }
    }
  }

  List<Node2> getExpressions() => _expressions;

  @override
  int checksum() {
    return _resultValue;
  }
}

class Interpreter2 {
  final variables = <String, int>{};

  int evaluate(Node2 node) {
    if (node is NumberNode) {
      return node.value;
    } else if (node is VariableNode) {
      return variables[node.name] ?? 0;
    } else if (node is BinaryOpNode) {
      final left = evaluate(node.left);
      final right = evaluate(node.right);

      switch (node.op) {
        case '+': return left + right;
        case '-': return left - right;
        case '*': return left * right;
        case '/': return _simpleDiv(left, right);
        case '%': return _simpleMod(left, right);
        default: return 0;
      }
    } else if (node is AssignmentNode) {
      final value = evaluate(node.expr);
      variables[node.varName] = value;
      return value;
    }

    return 0;
  }

  int _simpleDiv(int a, int b) {
    if (b == 0) return 0;
    if ((a >= 0 && b > 0) || (a < 0 && b < 0)) {
      return a ~/ b;
    } else {
      return -(a.abs() ~/ b.abs());
    }
  }

  int _simpleMod(int a, int b) {
    if (b == 0) return 0;
    return a - _simpleDiv(a, b) * b;
  }

  int run(List<Node2> expressions) {
    var result = 0;
    for (final expr in expressions) {
      result = evaluate(expr);
    }
    return result;
  }

  void clear() {
    variables.clear();
  }
}

class CalculatorInterpreter extends Benchmark {
  final _ast = <Node2>[];
  int _resultValue = 0;

  @override
  void prepare() {
    final className = runtimeType.toString().split('.').last;
    final operations = Helper.configI64(className, "operations").toInt();

    final text = CalculatorAst()._generateRandomProgram(operations);
    final parser = Parser2(text);
    parser.parse();
    _ast.clear();
    _ast.addAll(parser.expressions);
  }

  @override
  void runBenchmark(int iterationId) {
    final interpreter = Interpreter2();
    final result = interpreter.run(_ast);
    _resultValue = (_resultValue + result) & 0xFFFFFFFF;
  }

  @override
  int checksum() {
    return _resultValue;
  }
}

enum Cell {
  Dead,
  Alive,
}

class GameOfLifeGrid {
  late int width;
  late int height;
  late Uint8List cells;
  late Uint8List buffer;

  GameOfLifeGrid(int width, int height) {
    this.width = width;
    this.height = height;
    final size = width * height;
    cells = Uint8List(size);
    buffer = Uint8List(size);
  }

  GameOfLifeGrid._fromBuffers(int width, int height, Uint8List cells, Uint8List buffer) {
    this.width = width;
    this.height = height;
    this.cells = cells;
    this.buffer = buffer;
  }

  factory GameOfLifeGrid.fromBuffers(int width, int height, Uint8List cells, Uint8List buffer) {
    return GameOfLifeGrid._fromBuffers(width, height, cells, buffer);
  }

  int _index(int x, int y) {
    return y * width + x;
  }

  Cell get(int x, int y) {
    final idx = _index(x, y);
    return cells[idx] == 1 ? Cell.Alive : Cell.Dead;
  }

  void setCell(int x, int y, Cell cell) {
    final idx = _index(x, y);
    cells[idx] = cell == Cell.Alive ? 1 : 0;
  }

  int _countNeighbors(int x, int y, Uint8List cells) {
    final yPrev = y == 0 ? height - 1 : y - 1;
    final yNext = y == height - 1 ? 0 : y + 1;
    final xPrev = x == 0 ? width - 1 : x - 1;
    final xNext = x == width - 1 ? 0 : x + 1;

    int count = 0;

    int idx = yPrev * width;
    if (cells[idx + xPrev] == 1) count++;
    if (cells[idx + x] == 1) count++;
    if (cells[idx + xNext] == 1) count++;

    idx = y * width;
    if (cells[idx + xPrev] == 1) count++;
    if (cells[idx + xNext] == 1) count++;

    idx = yNext * width;
    if (cells[idx + xPrev] == 1) count++;
    if (cells[idx + x] == 1) count++;
    if (cells[idx + xNext] == 1) count++;

    return count;
  }

  GameOfLifeGrid nextGeneration() {
    final cells = this.cells;
    final buffer = this.buffer;

    for (int y = 0; y < height; y++) {
      final yIdx = y * width;

      for (int x = 0; x < width; x++) {
        final idx = yIdx + x;

        final neighbors = _countNeighbors(x, y, cells);

        final current = cells[idx];
        int nextState = 0;

        if (current == 1) {
          nextState = (neighbors == 2 || neighbors == 3) ? 1 : 0;
        } else {
          nextState = neighbors == 3 ? 1 : 0;
        }

        buffer[idx] = nextState;
      }
    }

    return GameOfLifeGrid.fromBuffers(width, height, buffer, cells);
  }

  int computeHash() {
    const int FNV_OFFSET_BASIS = 2166136261;
    const int FNV_PRIME = 16777619;

    int hasher = FNV_OFFSET_BASIS;

    for (int i = 0; i < cells.length; i++) {
      final alive = cells[i];
      hasher = (hasher ^ alive) & 0xFFFFFFFF;
      hasher = (hasher * FNV_PRIME) & 0xFFFFFFFF;
    }

    return hasher & 0xFFFFFFFF;
  }
}

class GameOfLife extends Benchmark {
  late int width;
  late int height;
  late GameOfLifeGrid grid;

  GameOfLife() {
    final className = runtimeType.toString().split('.').last;
    width = Helper.configI64(className, "w").toInt();
    height = Helper.configI64(className, "h").toInt();
    grid = GameOfLifeGrid(width, height);
  }

  @override
  void prepare() {

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        if (Helper.nextFloat() < 0.1) {
          grid.setCell(x, y, Cell.Alive);
        }
      }
    }
  }

  @override
  void runBenchmark(int iterationId) {
    grid = grid.nextGeneration();
  }

  @override
  int checksum() {
    return grid.computeHash() & 0xFFFFFFFF;
  }
}

enum MazeCell { Wall, Path }

class MazeGeneratorClass {
  final int width;
  final int height;
  final List<List<MazeCell>> cells;

  MazeGeneratorClass(int width, int height)
      : width = max(width, 5),
        height = max(height, 5),
        cells = List.generate(
          max(height, 5),
          (_) => List.filled(max(width, 5), MazeCell.Wall),
        );

  MazeCell get(int x, int y) => cells[y][x];
  void setCell(int x, int y, MazeCell cell) => cells[y][x] = cell;

  void _divide(int x1, int y1, int x2, int y2) {
    final w = x2 - x1;
    final h = y2 - y1;

    if (w < 2 || h < 2) return;

    final wWall = w - 2;
    final hWall = h - 2;
    final wHole = w - 1;
    final hHole = h - 1;

    if (wWall <= 0 || hWall <= 0 || wHole <= 0 || hHole <= 0) return;

    if (w > h) {

      final wallRange = max(wWall ~/ 2, 1);
      final wallX = x1 + 2 + (wallRange > 0 ? Helper.nextInt(wallRange) * 2 : 0);

      final holeRange = max(hHole ~/ 2, 1);
      final holeY = y1 + 1 + (holeRange > 0 ? Helper.nextInt(holeRange) * 2 : 0);

      if (wallX <= x2 && holeY <= y2) {
        for (int y = y1; y <= y2; y++) {
          if (y != holeY) cells[y][wallX] = MazeCell.Wall;
        }

        if (wallX > x1 + 1) _divide(x1, y1, wallX - 1, y2);
        if (wallX + 1 < x2) _divide(wallX + 1, y1, x2, y2);
      }
    } else {

      final wallRange = max(hWall ~/ 2, 1);
      final wallY = y1 + 2 + (wallRange > 0 ? Helper.nextInt(wallRange) * 2 : 0);

      final holeRange = max(wHole ~/ 2, 1);
      final holeX = x1 + 1 + (holeRange > 0 ? Helper.nextInt(holeRange) * 2 : 0);

      if (wallY <= y2 && holeX <= x2) {
        for (int x = x1; x <= x2; x++) {
          if (x != holeX) cells[wallY][x] = MazeCell.Wall;
        }

        if (wallY > y1 + 1) _divide(x1, y1, x2, wallY - 1);
        if (wallY + 1 < y2) _divide(x1, wallY + 1, x2, y2);
      }
    }
  }

  void _addRandomPaths() {
    final numExtraPaths = (width * height) ~/ 20;
    final w = width;
    final h = height;
    final cells = this.cells;

    for (int i = 0; i < numExtraPaths; i++) {
      final x = Helper.nextInt(w - 2) + 1;
      final y = Helper.nextInt(h - 2) + 1;

      if (cells[y][x] == MazeCell.Wall &&
          cells[y][x - 1] == MazeCell.Wall &&
          cells[y][x + 1] == MazeCell.Wall &&
          cells[y - 1][x] == MazeCell.Wall &&
          cells[y + 1][x] == MazeCell.Wall) {
        cells[y][x] = MazeCell.Path;
      }
    }
  }

  bool _isConnectedImpl(int startX, int startY, int goalX, int goalY) {
    if (startX >= width || startY >= height ||
        goalX >= width || goalY >= height) {
      return false;
    }

    final visited = List.generate(height, (_) => List<bool>.filled(width, false));
    final queue = Queue<(int, int)>();

    visited[startY][startX] = true;
    queue.add((startX, startY));

    final cells = this.cells;
    final w = width;
    final h = height;

    while (queue.isNotEmpty) {
      final (x, y) = queue.removeFirst();

      if (x == goalX && y == goalY) return true;

      if (y > 0 && cells[y - 1][x] == MazeCell.Path && !visited[y - 1][x]) {
        visited[y - 1][x] = true;
        queue.add((x, y - 1));
      }
      if (x + 1 < w && cells[y][x + 1] == MazeCell.Path && !visited[y][x + 1]) {
        visited[y][x + 1] = true;
        queue.add((x + 1, y));
      }
      if (y + 1 < h && cells[y + 1][x] == MazeCell.Path && !visited[y + 1][x]) {
        visited[y + 1][x] = true;
        queue.add((x, y + 1));
      }
      if (x > 0 && cells[y][x - 1] == MazeCell.Path && !visited[y][x - 1]) {
        visited[y][x - 1] = true;
        queue.add((x - 1, y));
      }
    }

    return false;
  }

  void generate() {
    if (width < 5 || height < 5) {
      final midY = height ~/ 2;
      final row = cells[midY];
      for (int x = 0; x < width; x++) {
        row[x] = MazeCell.Path;
      }
      return;
    }

    _divide(0, 0, width - 1, height - 1);
    _addRandomPaths();
  }

  List<List<bool>> toBoolGrid() {
    final result = List<List<bool>>.generate(height, (_) => List<bool>.filled(width, false));

    for (int y = 0; y < height; y++) {
      final srcRow = cells[y];
      final dstRow = result[y];
      for (int x = 0; x < width; x++) {
        dstRow[x] = srcRow[x] == MazeCell.Path;
      }
    }
    return result;
  }

  bool isConnected(int startX, int startY, int goalX, int goalY) {
    return _isConnectedImpl(startX, startY, goalX, goalY);
  }

  static List<List<bool>> generateWalkableMaze(int width, int height) {
    final maze = MazeGeneratorClass(width, height);
    maze.generate();

    final startX = 1;
    final startY = 1;
    final goalX = width - 2;
    final goalY = height - 2;

    if (!maze.isConnected(startX, startY, goalX, goalY)) {
      final w = width;
      final h = height;
      final cells = maze.cells;

      for (int x = 0; x < w; x++) {
        for (int y = 0; y < h; y++) {
          if (x == 1 || y == 1 || x == w - 2 || y == h - 2) {
            cells[y][x] = MazeCell.Path;
          }
        }
      }
    }

    return maze.toBoolGrid();
  }
}

class MazeGenerator extends Benchmark {
  late final int width;
  late final int height;
  List<List<bool>> boolGrid = [];

  MazeGenerator() {
    final className = runtimeType.toString().split('.').last;
    width = Helper.configI64(className, "w").toInt();
    height = Helper.configI64(className, "h").toInt();
  }

  @override
  void prepare() {
    Helper.reset();
  }

  @override
  void runBenchmark(int iterationId) {
    boolGrid = MazeGeneratorClass.generateWalkableMaze(width, height);
  }

  int _gridChecksum(List<List<bool>> grid) {
    int hasher = 2166136261 & 0xFFFFFFFF;
    const int prime = 16777619 & 0xFFFFFFFF;

    for (int i = 0; i < grid.length; i++) {
      final row = grid[i];
      for (int j = 0; j < row.length; j++) {
        if (row[j]) {
          final jSquared = (j * j) & 0xFFFFFFFF;
          hasher = ((hasher ^ jSquared) * prime) & 0xFFFFFFFF;
        }
      }
    }
    return hasher;
  }

  @override
  int checksum() {
    return _gridChecksum(boolGrid);
  }
}

class AStarNode implements Comparable<AStarNode> {
  final int x;
  final int y;
  final int fScore;

  AStarNode(this.x, this.y, this.fScore);

  @override
  int compareTo(AStarNode other) {
    if (fScore != other.fScore) {
      return fScore - other.fScore;
    }
    if (y != other.y) {
      return y - other.y;
    }
    return x - other.x;
  }
}

class AStarBinaryHeap {
  final List<AStarNode> _data = [];

  void push(AStarNode item) {
    _data.add(item);
    _siftUp(_data.length - 1);
  }

  AStarNode pop() {
    final result = _data[0];
    final last = _data.removeLast();

    if (_data.isNotEmpty) {
      _data[0] = last;
      _siftDown(0);
    }

    return result;
  }

  bool isEmpty() => _data.isEmpty;

  void _siftUp(int index) {
    final node = _data[index];

    while (index > 0) {
      final parent = (index - 1) >> 1;
      final parentNode = _data[parent];

      if (node.compareTo(parentNode) >= 0) break;

      _data[index] = parentNode;
      _data[parent] = node;
      index = parent;
    }
  }

  void _siftDown(int index) {
    final size = _data.length;
    final node = _data[index];

    while (true) {
      final left = (index << 1) + 1;
      final right = left + 1;
      var smallest = index;

      if (left < size) {
        final leftNode = _data[left];
        if (leftNode.compareTo(_data[smallest]) < 0) {
          smallest = left;
        }
      }

      if (right < size) {
        final rightNode = _data[right];
        if (rightNode.compareTo(_data[smallest]) < 0) {
          smallest = right;
        }
      }

      if (smallest == index) break;

      _data[index] = _data[smallest];
      _data[smallest] = node;
      index = smallest;
    }
  }
}

class AStarPathfinder extends Benchmark {
  int resultVal = 0;
  late int startX;
  late int startY;
  late int goalX;
  late int goalY;
  late int width;
  late int height;
  List<List<bool>> mazeGrid = [];

  late Int32List gScoresCache;
  late Int32List cameFromCache;

  static const directions = [
    [0, -1], [1, 0], [0, 1], [-1, 0]
  ];
  static const straightCost = 1000;
  static const int inf = 0x7FFFFFFF;

  AStarPathfinder() {
    final className = runtimeType.toString().split('.').last;
    width = Helper.configI64(className, "w").toInt();
    height = Helper.configI64(className, "h").toInt();
    startX = 1;
    startY = 1;
    goalX = width - 2;
    goalY = height - 2;

    final size = width * height;
    gScoresCache = Int32List(size);
    cameFromCache = Int32List(size);
  }

  int _distance(int aX, int aY, int bX, int bY) {
    return (aX - bX).abs() + (aY - bY).abs();
  }

  int _packCoords(int x, int y) {
    return y * width + x;
  }

  (int, int) _unpackCoords(int packed) {
    return (packed % width, packed ~/ width);
  }

  (List<(int, int)>, int) _findPath() {
    final grid = mazeGrid;
    final gScores = gScoresCache;
    final cameFrom = cameFromCache;

    gScores.fillRange(0, gScores.length, inf);
    cameFrom.fillRange(0, cameFrom.length, -1);

    final openSet = AStarBinaryHeap();

    final startIdx = _packCoords(startX, startY);
    gScores[startIdx] = 0;
    openSet.push(AStarNode(
      startX,
      startY,
      _distance(startX, startY, goalX, goalY),
    ));

    var nodesExplored = 0;

    while (!openSet.isEmpty()) {
      final current = openSet.pop();
      nodesExplored++;

      if (current.x == goalX && current.y == goalY) {
        final path = <(int, int)>[];
        var x = current.x;
        var y = current.y;

        while (x != startX || y != startY) {
          path.add((x, y));
          final idx = _packCoords(x, y);
          final packed = cameFrom[idx];
          if (packed == -1) break;

          final (newX, newY) = _unpackCoords(packed);
          x = newX;
          y = newY;
        }

        path.add((startX, startY));
        return (path.reversed.toList(), nodesExplored);
      }

      final currentIdx = _packCoords(current.x, current.y);
      final currentG = gScores[currentIdx];

      for (final dir in directions) {
        final nx = current.x + dir[0];
        final ny = current.y + dir[1];

        if (nx < 0 || nx >= width || ny < 0 || ny >= height) continue;
        if (!grid[ny][nx]) continue;

        final tentativeG = currentG + straightCost;
        final neighborIdx = _packCoords(nx, ny);

        if (tentativeG < gScores[neighborIdx]) {
          cameFrom[neighborIdx] = currentIdx;
          gScores[neighborIdx] = tentativeG;

          final fScore = tentativeG + _distance(nx, ny, goalX, goalY);
          openSet.push(AStarNode(nx, ny, fScore));
        }
      }
    }

    return ([], nodesExplored);
  }

  @override
  void prepare() {
    mazeGrid = MazeGeneratorClass.generateWalkableMaze(width, height);
  }

  @override
  void runBenchmark(int iterationId) {
    final (path, nodesExplored) = _findPath();

    var localResult = 0;

    localResult = path.length;
    localResult = ((localResult << 5) + nodesExplored) & 0xFFFFFFFF;
    resultVal = (resultVal + localResult) & 0xFFFFFFFF;
  }

  @override
  int checksum() {
    return resultVal & 0xFFFFFFFF;
  }
}

class CompressionBWTResult {
  final Uint8List transformed;
  final int originalIdx;

  CompressionBWTResult(this.transformed, this.originalIdx);
}

class CompressionHuffmanNode implements Comparable<CompressionHuffmanNode> {
  final int frequency;
  final int? byteVal;
  final bool isLeaf;
  final CompressionHuffmanNode? left;
  final CompressionHuffmanNode? right;

  CompressionHuffmanNode({
    required this.frequency,
    this.byteVal,
    this.isLeaf = true,
    this.left,
    this.right,
  });

  @override
  int compareTo(CompressionHuffmanNode other) {
    return frequency - other.frequency;
  }
}

class CompressionHuffmanCodes {
  final List<int> codeLengths = List.filled(256, 0);
  final List<int> codes = List.filled(256, 0);
}

class CompressionEncodedResult {
  final Uint8List data;
  final int bitCount;

  CompressionEncodedResult(this.data, this.bitCount);
}

class CompressionCompressedData {
  final CompressionBWTResult bwtResult;
  final List<int> frequencies;
  final Uint8List encodedBits;
  final int originalBitCount;

  CompressionCompressedData(
    this.bwtResult,
    this.frequencies,
    this.encodedBits,
    this.originalBitCount,
  );
}

class BWTHuffEncode extends Benchmark {
  int result = 0;
  late Uint8List testData;
  late int size;

  BWTHuffEncode() {
    final className = runtimeType.toString().split('.').last;
    size = Helper.configI64(className, "size").toInt();
  }

  CompressionBWTResult bwtTransform(Uint8List input) {
    final n = input.length;
    if (n == 0) {
      return CompressionBWTResult(Uint8List(0), 0);
    }

    final doubled = Uint8List(n * 2);
    doubled.setAll(0, input);
    doubled.setAll(n, input);

    var sa = List<int>.generate(n, (i) => i);

    final buckets = List<List<int>>.generate(256, (_) => []);

    for (final idx in sa) {
      final firstChar = input[idx];
      buckets[firstChar].add(idx);
    }

    var pos = 0;
    for (final bucket in buckets) {
      for (final idx in bucket) {
        sa[pos++] = idx;
      }
    }

    if (n > 1) {
      final rank = List<int>.filled(n, 0);
      var currentRank = 0;
      var prevChar = input[sa[0]];

      for (int i = 0; i < n; i++) {
        final idx = sa[i];
        final currChar = input[idx];
        if (currChar != prevChar) {
          currentRank++;
          prevChar = currChar;
        }
        rank[idx] = currentRank;
      }

      var k = 1;
      while (k < n) {
        final pairs = List<(int, int)>.generate(n, (i) => (rank[i], rank[(i + k) % n]));

        sa.sort((a, b) {
          final pairA = pairs[a];
          final pairB = pairs[b];
          if (pairA.$1 != pairB.$1) {
            return pairA.$1 - pairB.$1;
          }
          return pairA.$2 - pairB.$2;
        });

        final newRank = List<int>.filled(n, 0);
        newRank[sa[0]] = 0;
        for (int i = 1; i < n; i++) {
          final prevPair = pairs[sa[i - 1]];
          final currPair = pairs[sa[i]];
          newRank[sa[i]] = newRank[sa[i - 1]] +
              ((prevPair.$1 != currPair.$1 || prevPair.$2 != currPair.$2) ? 1 : 0);
        }

        for (int i = 0; i < n; i++) {
          rank[i] = newRank[i];
        }
        k *= 2;
      }
    }

    final transformed = Uint8List(n);
    var originalIdx = 0;

    for (int i = 0; i < n; i++) {
      final suffix = sa[i];
      if (suffix == 0) {
        transformed[i] = input[n - 1];
        originalIdx = i;
      } else {
        transformed[i] = input[suffix - 1];
      }
    }

    return CompressionBWTResult(transformed, originalIdx);
  }

  Uint8List bwtInverse(CompressionBWTResult bwtResult) {
    final bwt = bwtResult.transformed;
    final n = bwt.length;
    if (n == 0) {
      return Uint8List(0);
    }

    final counts = List<int>.filled(256, 0);
    for (final byte in bwt) {
      counts[byte]++;
    }

    final positions = List<int>.filled(256, 0);
    var total = 0;
    for (int i = 0; i < 256; i++) {
      positions[i] = total;
      total += counts[i];
    }

    final next = List<int>.filled(n, 0);
    final tempCounts = List<int>.filled(256, 0);

    for (int i = 0; i < n; i++) {
      final byteIdx = bwt[i];
      final pos = positions[byteIdx] + tempCounts[byteIdx];
      next[pos] = i;
      tempCounts[byteIdx]++;
    }

    final result = Uint8List(n);
    var idx = bwtResult.originalIdx;

    for (int i = 0; i < n; i++) {
      idx = next[idx];
      result[i] = bwt[idx];
    }

    return result;
  }

  CompressionHuffmanNode buildHuffmanTree(List<int> frequencies) {
    final heap = PriorityQueue<CompressionHuffmanNode>();

    for (int i = 0; i < frequencies.length; i++) {
      if (frequencies[i] > 0) {
        heap.add(CompressionHuffmanNode(frequency: frequencies[i], byteVal: i));
      }
    }

    if (heap.isEmpty) {
      return CompressionHuffmanNode(frequency: 0, byteVal: 0);
    }

    if (heap.length == 1) {
      final node = heap.removeFirst();
      return CompressionHuffmanNode(
        frequency: node.frequency,
        byteVal: null,
        isLeaf: false,
        left: node,
        right: CompressionHuffmanNode(frequency: 0, byteVal: 0),
      );
    }

    while (heap.length > 1) {
      final left = heap.removeFirst();
      final right = heap.removeFirst();

      final parent = CompressionHuffmanNode(
        frequency: left.frequency + right.frequency,
        byteVal: null,
        isLeaf: false,
        left: left,
        right: right,
      );

      heap.add(parent);
    }

    return heap.removeFirst();
  }

  CompressionHuffmanCodes buildHuffmanCodes(
    CompressionHuffmanNode node, {
    int code = 0,
    int length = 0,
    CompressionHuffmanCodes? huffmanCodes,
  }) {
    final codes = huffmanCodes ?? CompressionHuffmanCodes();

    if (node.isLeaf) {
      if (length > 0 || node.byteVal != 0) {
        final idx = node.byteVal!;
        codes.codeLengths[idx] = length;
        codes.codes[idx] = code;
      }
    } else {
      if (node.left != null) {
        buildHuffmanCodes(node.left!, code: code << 1, length: length + 1, huffmanCodes: codes);
      }
      if (node.right != null) {
        buildHuffmanCodes(node.right!, code: (code << 1) | 1, length: length + 1, huffmanCodes: codes);
      }
    }
    return codes;
  }

  CompressionEncodedResult huffmanEncode(Uint8List data, CompressionHuffmanCodes huffmanCodes) {
    final result = Uint8List(data.length * 2);
    var currentByte = 0;
    var bitPos = 0;
    var byteIndex = 0;
    var totalBits = 0;

    for (final byte in data) {
      final idx = byte;
      final code = huffmanCodes.codes[idx];
      final length = huffmanCodes.codeLengths[idx];

      for (int i = length - 1; i >= 0; i--) {
        if ((code & (1 << i)) != 0) {
          currentByte |= 1 << (7 - bitPos);
        }
        bitPos++;
        totalBits++;

        if (bitPos == 8) {
          result[byteIndex++] = currentByte;
          currentByte = 0;
          bitPos = 0;
        }
      }
    }

    if (bitPos > 0) {
      result[byteIndex++] = currentByte;
    }

    return CompressionEncodedResult(result.sublist(0, byteIndex), totalBits);
  }

  Uint8List huffmanDecode(
    Uint8List encoded,
    CompressionHuffmanNode root,
    int bitCount,
  ) {
    final result = <int>[];

    var currentNode = root;
    var bitsProcessed = 0;
    var byteIndex = 0;

    while (bitsProcessed < bitCount && byteIndex < encoded.length) {
      final byteVal = encoded[byteIndex++];

      for (int bitPos = 7; bitPos >= 0 && bitsProcessed < bitCount; bitPos--) {
        final bit = ((byteVal >> bitPos) & 1) == 1;
        bitsProcessed++;

        currentNode = bit ? currentNode.right! : currentNode.left!;

        if (currentNode.isLeaf) {
          if (currentNode.byteVal != 0) {
            result.add(currentNode.byteVal!);
          }
          currentNode = root;
        }
      }
    }

    return Uint8List.fromList(result);
  }

  CompressionCompressedData compress(Uint8List data) {
    final bwtResult = bwtTransform(data);

    final frequencies = List<int>.filled(256, 0);
    for (final byte in bwtResult.transformed) {
      frequencies[byte]++;
    }

    final huffmanTree = buildHuffmanTree(frequencies);
    final huffmanCodes = buildHuffmanCodes(huffmanTree);
    final encoded = huffmanEncode(bwtResult.transformed, huffmanCodes);

    return CompressionCompressedData(
      bwtResult,
      frequencies,
      encoded.data,
      encoded.bitCount,
    );
  }

  Uint8List decompress(CompressionCompressedData compressed) {
    final huffmanTree = buildHuffmanTree(compressed.frequencies);
    final decoded = huffmanDecode(
      compressed.encodedBits,
      huffmanTree,
      compressed.originalBitCount,
    );
    final bwtResult = CompressionBWTResult(decoded, compressed.bwtResult.originalIdx);
    return bwtInverse(bwtResult);
  }

  Uint8List generateTestData(int size) {
    const pattern = "ABRACADABRA";
    final patternBytes = utf8.encode(pattern);
    final data = Uint8List(size);
    final patternLength = patternBytes.length;

    for (int i = 0; i < size; i++) {
      data[i] = patternBytes[i % patternLength];
    }

    return data;
  }

  @override
  void prepare() {
    testData = generateTestData(size);
    result = 0;
  }

  @override
  void runBenchmark(int iterationId) {
    final compressed = compress(testData);
    result = (result + compressed.encodedBits.length) & 0xFFFFFFFF;
  }

  @override
  int checksum() {
    return result & 0xFFFFFFFF;
  }
}

class BWTHuffDecode extends BWTHuffEncode {
  CompressionCompressedData? compressed;
  late Uint8List decompressed;

  @override
  void prepare() {
    testData = generateTestData(size);
    compressed = compress(testData);
    result = 0;
  }

  @override
  void runBenchmark(int iterationId) {
    decompressed = decompress(compressed!);
    result += decompressed.length;
  }

  @override
  int checksum() {
    var res = result;

    if (decompressed.length == testData.length) {
      var equal = true;
      for (int i = 0; i < decompressed.length; i++) {
        if (decompressed[i] != testData[i]) {
          equal = false;
          break;
        }
      }
      if (equal) {
        res += 1000000;
      }
    }
    return res & 0xFFFFFFFF;
  }
}

class PriorityQueue<E extends Comparable<E>> {
  final List<E> _heap = [];

  int get length => _heap.length;
  bool get isEmpty => _heap.isEmpty;
  bool get isNotEmpty => _heap.isNotEmpty;

  void add(E element) {
    _heap.add(element);
    _siftUp(_heap.length - 1);
  }

  E removeFirst() {
    if (_heap.isEmpty) {
      throw StateError("Cannot remove from empty priority queue");
    }
    final result = _heap[0];
    final last = _heap.removeLast();
    if (_heap.isNotEmpty) {
      _heap[0] = last;
      _siftDown(0);
    }
    return result;
  }

  void _siftUp(int index) {
    final element = _heap[index];
    while (index > 0) {
      final parent = (index - 1) ~/ 2;
      if (element.compareTo(_heap[parent]) >= 0) break;
      _heap[index] = _heap[parent];
      _heap[parent] = element;
      index = parent;
    }
  }

  void _siftDown(int index) {
    final size = _heap.length;
    final element = _heap[index];
    while (true) {
      final left = 2 * index + 1;
      final right = left + 1;
      var smallest = index;

      if (left < size && _heap[left].compareTo(_heap[smallest]) < 0) {
        smallest = left;
      }
      if (right < size && _heap[right].compareTo(_heap[smallest]) < 0) {
        smallest = right;
      }
      if (smallest == index) break;

      _heap[index] = _heap[smallest];
      _heap[smallest] = element;
      index = smallest;
    }
  }
}

CompressionHuffmanNode buildHuffmanTree(List<int> frequencies) {
  final heap = PriorityQueue<CompressionHuffmanNode>();

  for (int i = 0; i < frequencies.length; i++) {
    if (frequencies[i] > 0) {
      heap.add(CompressionHuffmanNode(frequency: frequencies[i], byteVal: i));
    }
  }

  if (heap.isEmpty) {
    return CompressionHuffmanNode(frequency: 0, byteVal: 0);
  }

  if (heap.length == 1) {
    final node = heap.removeFirst();
    return CompressionHuffmanNode(
      frequency: node.frequency,
      byteVal: null,
      isLeaf: false,
      left: node,
      right: CompressionHuffmanNode(frequency: 0, byteVal: 0),
    );
  }

  while (heap.length > 1) {
    final left = heap.removeFirst();
    final right = heap.removeFirst();

    final parent = CompressionHuffmanNode(
      frequency: left.frequency + right.frequency,
      byteVal: null,
      isLeaf: false,
      left: left,
      right: right,
    );

    heap.add(parent);
  }

  return heap.removeFirst();
}

void registerBenchmarks() {
  Benchmark.registerBenchmark(() => Pidigits());
  Benchmark.registerBenchmark(() => Binarytrees());
  Benchmark.registerBenchmark(() => BrainfuckArray());
  Benchmark.registerBenchmark(() => BrainfuckRecursion());
  Benchmark.registerBenchmark(() => Fannkuchredux());
  Benchmark.registerBenchmark(() => Fasta());
  Benchmark.registerBenchmark(() => Knuckeotide());
  Benchmark.registerBenchmark(() => Mandelbrot());
  Benchmark.registerBenchmark(() => Matmul1T());
  Benchmark.registerBenchmark(() => Matmul4T());
  Benchmark.registerBenchmark(() => Matmul8T());
  Benchmark.registerBenchmark(() => Matmul16T());
  Benchmark.registerBenchmark(() => Nbody());
  Benchmark.registerBenchmark(() => RegexDna());
  Benchmark.registerBenchmark(() => Revcomp());
  Benchmark.registerBenchmark(() => Spectralnorm());
  Benchmark.registerBenchmark(() => Base64Encode());
  Benchmark.registerBenchmark(() => Base64Decode());
  Benchmark.registerBenchmark(() => JsonGenerate());
  Benchmark.registerBenchmark(() => JsonParseDom());
  Benchmark.registerBenchmark(() => JsonParseMapping());
  Benchmark.registerBenchmark(() => Primes());
  Benchmark.registerBenchmark(() => Noise());
  Benchmark.registerBenchmark(() => TextRaytracer());
  Benchmark.registerBenchmark(() => NeuralNet());
  Benchmark.registerBenchmark(() => SortQuick());
  Benchmark.registerBenchmark(() => SortMerge());
  Benchmark.registerBenchmark(() => SortSelf());
  Benchmark.registerBenchmark(() => GraphPathBFS());
  Benchmark.registerBenchmark(() => GraphPathDFS());
  Benchmark.registerBenchmark(() => GraphPathDijkstra());
  Benchmark.registerBenchmark(() => BufferHashSHA256());
  Benchmark.registerBenchmark(() => BufferHashCRC32());
  Benchmark.registerBenchmark(() => CacheSimulation());
  Benchmark.registerBenchmark(() => CalculatorAst());
  Benchmark.registerBenchmark(() => CalculatorInterpreter());
  Benchmark.registerBenchmark(() => GameOfLife());
  Benchmark.registerBenchmark(() => MazeGenerator());
  Benchmark.registerBenchmark(() => AStarPathfinder());
  Benchmark.registerBenchmark(() => BWTHuffEncode());
  Benchmark.registerBenchmark(() => BWTHuffDecode());
}

Future<void> main(List<String> args) async {
  String configFile = '../test.json';
  String? testName;

  if (args.isNotEmpty) {
    if (args[0].contains('.txt') || 
        args[0].contains('.json') || 
        args[0].contains('.js') || 
        args[0].contains('.config')) {
      configFile = args[0];
      testName = args.length > 1 ? args[1] : null;
    } else {
      testName = args[0];
    }
  }

  print('start: ${DateTime.now().millisecondsSinceEpoch}');

  try {
    await Helper.loadConfig(configFile);
    registerBenchmarks();
    await Benchmark.run(testName);  
  } catch (error) {
    print('Failed to run benchmarks: $error');
    exit(1);
  }
}