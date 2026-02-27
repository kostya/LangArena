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
      print('Error loading config file $configFile: $error');
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
        'Config for $className, not found i64 field: $fieldName in $_config',
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
        'Config for $className, not found string field: $fieldName in $_config',
      );
    }
  }
}

class _NamedBenchmarkFactory {
  final String name;
  final Benchmark Function() constructor;

  _NamedBenchmarkFactory(this.name, this.constructor);
}

abstract class Benchmark {
  String get benchmarkName => runtimeType.toString().split('.').last;
  FutureOr<void> runBenchmark(int iterationId);
  int checksum();

  void prepare() {}

  Map<String, dynamic> get config {
    final config = Helper._config;
    if (config != null && config[benchmarkName] != null) {
      return config[benchmarkName] as Map<String, dynamic>;
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
      return Helper.configI64(benchmarkName, 'iterations').toInt();
    } catch (_) {
      return 1;
    }
  }

  BigInt get expectedChecksum {
    try {
      return Helper.configI64(benchmarkName, 'checksum');
    } catch (_) {
      return BigInt.zero;
    }
  }

  static final List<_NamedBenchmarkFactory> _benchmarkFactories = [];

  static void registerBenchmark(String name, Benchmark Function() constructor) {
    if (_benchmarkFactories.any((factory) => factory.name == name)) {
      print(
        'Warning: Benchmark with name "$name" already registered. Skipping.',
      );
      return;
    }
    _benchmarkFactories.add(_NamedBenchmarkFactory(name, constructor));
  }

  static Future<void> run([String? singleBench]) async {
    final results = <String, double>{};
    double summaryTime = 0;
    int ok = 0;
    int fails = 0;

    final skipBenchmarks = {
      'SortBenchmark',
      'BufferHashBenchmark',
      'GraphPathBenchmark',
    };

    for (final factoryInfo in _benchmarkFactories) {
      final benchName = factoryInfo.name;

      if (singleBench != null &&
          !benchName.toLowerCase().contains(singleBench.toLowerCase())) {
        continue;
      }

      if (skipBenchmarks.contains(benchName)) {
        continue;
      }

      final config = Helper._config;
      if (config == null || config[benchName] == null) {
        print('\n[$benchName]: SKIP - no config entry');
        continue;
      }

      stdout.write('$benchName: ');

      final bench = factoryInfo.constructor();

      Helper.reset();
      bench.prepare();

      final warmupResult = bench.warmup();
      if (warmupResult is Future) {
        await warmupResult;
      }

      Helper.reset();

      final startTime = DateTime.now().millisecondsSinceEpoch;

      final runAllResult = bench.runAll();
      if (runAllResult is Future) {
        await runAllResult;
      }

      final endTime = DateTime.now().millisecondsSinceEpoch;
      final timeDelta = (endTime - startTime) / 1000.0;

      results[benchName] = timeDelta;

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

    print(
      'Summary: ${summaryTime.toStringAsFixed(4)}s, ${ok + fails}, $ok, $fails',
    );

    if (fails > 0) {
      exit(1);
    }
  }
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

class BinarytreesObj extends Benchmark {
  late int n;
  int result = 0;

  BinarytreesObj() {
    n = Helper.configI64(benchmarkName, 'depth').toInt();
  }

  @override
  String get benchmarkName => 'Binarytrees::Obj';

  @override
  void runBenchmark(int iterationId) {
    final root = TreeNodeObj(0, n);
    result += root.sum() & 0xFFFFFFFF;
  }

  @override
  int checksum() {
    return result & 0xFFFFFFFF;
  }
}

class TreeNodeObj {
  TreeNodeObj? left;
  TreeNodeObj? right;
  int item;

  TreeNodeObj(this.item, int depth) {
    if (depth > 0) {
      final shift = 1 << (depth - 1);
      left = TreeNodeObj(item - shift, depth - 1);
      right = TreeNodeObj(item + shift, depth - 1);
    }
  }

  int sum() {
    int total = item + 1;

    if (left != null) {
      total += left!.sum();
    }
    if (right != null) {
      total += right!.sum();
    }

    return total & 0xFFFFFFFF;
  }
}

class BinarytreesArena extends Benchmark {
  late int n;
  int result = 0;

  BinarytreesArena() {
    n = Helper.configI64(benchmarkName, 'depth').toInt();
  }

  @override
  String get benchmarkName => 'Binarytrees::Arena';

  @override
  void runBenchmark(int iterationId) {
    TreeArena _arena = TreeArena();
    final rootIdx = _arena.build(0, n);
    result += _arena.sum(rootIdx) & 0xFFFFFFFF;
  }

  @override
  int checksum() {
    return result & 0xFFFFFFFF;
  }
}

class TreeNodeArena {
  int item;
  int left = -1;
  int right = -1;

  TreeNodeArena(this.item);
}

class TreeArena {
  final List<TreeNodeArena> _nodes = [];

  int build(int item, int depth) {
    final idx = _nodes.length;
    _nodes.add(TreeNodeArena(item));

    if (depth > 0) {
      final shift = 1 << (depth - 1);
      final leftIdx = build(item - shift, depth - 1);
      final rightIdx = build(item + shift, depth - 1);
      _nodes[idx].left = leftIdx;
      _nodes[idx].right = rightIdx;
    }

    return idx;
  }

  int sum(int idx) {
    final node = _nodes[idx];
    int total = node.item + 1;

    if (node.left >= 0) {
      total += sum(node.left);
    }
    if (node.right >= 0) {
      total += sum(node.right);
    }

    return total & 0xFFFFFFFF;
  }
}

class Tape {
  Uint8List _tape = Uint8List(30000);
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
      final newTape = Uint8List(_tape.length + 1);
      newTape.setAll(0, _tape);
      newTape[_tape.length] = 0;
      _tape = newTape;
    }
  }

  void devance() {
    if (_pos > 0) {
      _pos--;
    }
  }
}

class BrainfuckProgram {
  final Uint8List _commands;
  final List<int> _jumps;

  BrainfuckProgram(String text)
    : _commands = _filterCommands(text),
      _jumps = List.filled(_filterCommands(text).length, 0) {
    _buildJumps();
  }

  static Uint8List _filterCommands(String text) {
    final buffer = <int>[];
    for (final char in text.runes) {
      if ('[]<>+-,.'.contains(String.fromCharCode(char))) {
        buffer.add(char);
      }
    }
    return Uint8List.fromList(buffer);
  }

  void _buildJumps() {
    final stack = <int>[];

    for (int i = 0; i < _commands.length; i++) {
      final cmd = _commands[i];
      if (cmd == 91) {
        stack.add(i);
      } else if (cmd == 93 && stack.isNotEmpty) {
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
    final commands = _commands;
    final jumps = _jumps;

    while (pc < commands.length) {
      final cmd = commands[pc];

      switch (cmd) {
        case 43:
          tape.inc();
          break;
        case 45:
          tape.dec();
          break;
        case 62:
          tape.advance();
          break;
        case 60:
          tape.devance();
          break;
        case 91:
          if (tape.get() == 0) {
            pc = jumps[pc];
          }
          break;
        case 93:
          if (tape.get() != 0) {
            pc = jumps[pc];
          }
          break;
        case 46:
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
    _programText = Helper.configS(benchmarkName, "program");
    _warmupText = Helper.configS(benchmarkName, "warmup_program");
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

  @override
  String get benchmarkName => 'Brainfuck::Array';
}

abstract class Op {}

class IncOp extends Op {}

class DecOp extends Op {}

class NextOp extends Op {}

class PrevOp extends Op {}

class PrintOp extends Op {}

class LoopOp extends Op {
  final List<Op> ops;
  LoopOp(this.ops);
}

class Tape2 {
  static const int INITIAL_SIZE = 30000;
  Uint8List _tape;
  int _pos = 0;

  Tape2() : _tape = Uint8List(INITIAL_SIZE);

  int get() => _tape[_pos];

  void inc() {
    _tape[_pos] = (_tape[_pos] + 1) & 0xFF;
  }

  void dec() {
    _tape[_pos] = (_tape[_pos] - 1) & 0xFF;
  }

  void next() {
    _pos++;
    if (_pos >= _tape.length) {
      final newTape = Uint8List(_tape.length + 1);
      newTape.setRange(0, _tape.length, _tape);
      _tape = newTape;
    }
  }

  void prev() {
    if (_pos > 0) {
      _pos--;
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
        tape.inc();
      } else if (op is DecOp) {
        tape.dec();
      } else if (op is NextOp) {
        tape.next();
      } else if (op is PrevOp) {
        tape.prev();
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
          op = IncOp();
          break;
        case '-':
          op = DecOp();
          break;
        case '>':
          op = NextOp();
          break;
        case '<':
          op = PrevOp();
          break;
        case '.':
          op = PrintOp();
          break;
        case '[':
          final parseResult = _parseSequence(chars, i);
          result.add(LoopOp(parseResult.ops));
          i = parseResult.index;
          continue;
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
    _text = Helper.configS(benchmarkName, "program");
  }

  @override
  void warmup() {
    final warmupProgram = Helper.configS(benchmarkName, "warmup_program");
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

  @override
  String get benchmarkName => 'Brainfuck::Recursion';
}

class Pidigits extends Benchmark {
  late int nn;
  final StringBuffer _resultBuffer = StringBuffer();

  @override
  void prepare() {
    nn = Helper.configI64(benchmarkName, "amount").toInt();
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
            _resultBuffer.write(line);
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
      _resultBuffer.write(line);
    }
  }

  @override
  int checksum() {
    return Helper.checksumString(_resultBuffer.toString());
  }

  @override
  String get benchmarkName => 'CLBG::Pidigits';
}

class Fannkuchredux extends Benchmark {
  late int n;
  int _resultValue = 0;

  @override
  void prepare() {
    n = Helper.configI64(benchmarkName, "n").toInt();
  }

  (int, int) _fannkuchredux(int n) {
    final perm1 = Int32List(n)..setAll(0, List.generate(n, (i) => i));
    final perm = Int32List(n);
    final count = Int32List(n);

    int maxFlipsCount = 0;
    int permCount = 0;
    int checksum = 0;
    int r = n;

    while (true) {
      while (r > 1) {
        count[r - 1] = r;
        r -= 1;
      }

      perm.setAll(0, perm1);

      int flipsCount = 0;
      int k = perm[0];

      while (k != 0) {
        var i = 0;
        var j = k;
        while (i < j) {
          final temp = perm[i];
          perm[i] = perm[j];
          perm[j] = temp;
          i++;
          j--;
        }

        flipsCount++;
        k = perm[0];
      }

      maxFlipsCount = max(maxFlipsCount, flipsCount);
      checksum += (permCount & 1) == 0 ? flipsCount : -flipsCount;

      while (true) {
        if (r == n) {
          return (checksum, maxFlipsCount);
        }

        final first = perm1[0];
        for (var i = 0; i < r; i++) {
          perm1[i] = perm1[i + 1];
        }
        perm1[r] = first;

        count[r] -= 1;
        if (count[r] > 0) break;
        r++;
      }

      permCount++;
    }
  }

  @override
  void runBenchmark(int iterationId) {
    final (checksum, maxFlipsCount) = _fannkuchredux(n);
    _resultValue += checksum * 100 + maxFlipsCount;
  }

  @override
  int checksum() => _resultValue;

  @override
  String get benchmarkName => 'CLBG::Fannkuchredux';
}

class Gene {
  final String char;
  final double prob;

  Gene(this.char, this.prob);
}

class Fasta extends Benchmark {
  static const int LINE_LENGTH = 60;

  static final List<Gene> IUB = [
    Gene('a', 0.27),
    Gene('c', 0.39),
    Gene('g', 0.51),
    Gene('t', 0.78),
    Gene('B', 0.8),
    Gene('D', 0.8200000000000001),
    Gene('H', 0.8400000000000001),
    Gene('K', 0.8600000000000001),
    Gene('M', 0.8800000000000001),
    Gene('N', 0.9000000000000001),
    Gene('R', 0.9200000000000002),
    Gene('S', 0.9400000000000002),
    Gene('V', 0.9600000000000002),
    Gene('W', 0.9800000000000002),
    Gene('Y', 1.0000000000000002),
  ];

  static final List<Gene> HOMO = [
    Gene('a', 0.302954942668),
    Gene('c', 0.5009432431601),
    Gene('g', 0.6984905497992),
    Gene('t', 1.0),
  ];

  static const String ALU =
      "GGCCGGGCGCGGTGGCTCACGCCTGTAATCCCAGCACTTTGGGAGGCCGAGGCGGGCGGATCACCTGAGGTCAGGAGTTCGAGACCAGCCTGGCCAACATGGTGAAACCCCGTCTCTACTAAAAATACAAAAATTAGCCGGGCGTGGTGGCGCGCGCCTGTAATCCCAGCTACTCGGGAGGCTGAGGCAGGAGAATCGCTTGAACCCGGGAGGCGGAGGTTGCAGTGAGCCGAGATCGCGCCACTGCACTCCAGCCTGGGCGACAGAGCGAGACTCCGTCTCAAAAA";

  late int n;
  late StringBuffer resultBuffer;

  Fasta() {
    n = Helper.configI64(benchmarkName, "n").toInt();
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

  @override
  String get benchmarkName => 'CLBG::Fasta';
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
    final n = Helper.configI64(benchmarkName, "n").toInt();

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

    final sequences = [
      'ggt',
      'ggta',
      'ggtatt',
      'ggtattttaatt',
      'ggtattttaatttatagt',
    ];
    for (final s in sequences) {
      _findSeq(_seq, s);
    }
  }

  @override
  int checksum() {
    return Helper.checksumString(_resultStr);
  }

  @override
  String get benchmarkName => 'CLBG::Knuckeotide';
}

class Mandelbrot extends Benchmark {
  static const int ITER = 50;
  static const double LIMIT = 2.0;

  late int w;
  late int h;
  final BytesBuilder _builder = BytesBuilder();

  @override
  void prepare() {
    w = Helper.configI64(benchmarkName, "w").toInt();
    h = Helper.configI64(benchmarkName, "h").toInt();
  }

  @override
  void runBenchmark(int iterationId) {
    final header = 'P4\n$w $h\n';
    _builder.add(header.codeUnits);

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
          _builder.addByte(byteAcc);
          byteAcc = 0;
          bitNum = 0;
        } else if (x == w - 1) {
          byteAcc <<= (8 - (w % 8));
          _builder.addByte(byteAcc);
          byteAcc = 0;
          bitNum = 0;
        }
      }
    }
  }

  @override
  int checksum() {
    return Helper.checksumBytes(_builder.toBytes());
  }

  @override
  String get benchmarkName => 'CLBG::Mandelbrot';
}

abstract class MatmulBase extends Benchmark {
  late int n;
  int _resultValue = 0;
  late List<Float64List> a;
  late List<Float64List> b;

  @override
  void prepare() {
    n = Helper.configI64(benchmarkName, "n").toInt();
    a = _matgen(n);
    b = _matgen(n);
  }

  List<Float64List> _matgen(int n) {
    final tmp = 1.0 / n / n;
    final a = List<Float64List>.generate(n, (_) => Float64List(n));

    for (int i = 0; i < n; i++) {
      for (int j = 0; j < n; j++) {
        a[i][j] = tmp * (i - j) * (i + j);
      }
    }

    return a;
  }

  List<Float64List> _transpose(List<Float64List> b) {
    final n = b.length;
    final bT = List<Float64List>.generate(n, (_) => Float64List(n));

    for (int i = 0; i < n; i++) {
      for (int j = 0; j < n; j++) {
        bT[j][i] = b[i][j];
      }
    }

    return bT;
  }

  List<Float64List> _matmulSync(List<Float64List> a, List<Float64List> b) {
    final n = a.length;
    final bT = _transpose(b);
    final c = List<Float64List>.generate(n, (_) => Float64List(n));

    for (int i = 0; i < n; i++) {
      final ai = a[i];
      final ci = c[i];

      for (int j = 0; j < n; j++) {
        final bTj = bT[j];
        double sum = 0.0;

        for (int k = 0; k < n; k++) {
          sum += ai[k] * bTj[k];
        }

        ci[j] = sum;
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
    final c = _matmulSync(a, b);
    final value = c[n >> 1][n >> 1];

    _resultValue = (_resultValue + Helper.checksumFloat(value)) & 0xFFFFFFFF;
  }

  @override
  String get benchmarkName => 'Matmul::Single';
}

class Matmul4T extends MatmulBase {
  @override
  Future<void> runBenchmark(int iterationId) async {
    final c = await _matmulParallel(a, b, 4);
    final value = c[n >> 1][n >> 1];

    _resultValue = (_resultValue + Helper.checksumFloat(value)) & 0xFFFFFFFF;
  }

  @override
  String get benchmarkName => 'Matmul::T4';
}

class Matmul8T extends MatmulBase {
  @override
  Future<void> runBenchmark(int iterationId) async {
    final c = await _matmulParallel(a, b, 8);
    final value = c[n >> 1][n >> 1];

    _resultValue = (_resultValue + Helper.checksumFloat(value)) & 0xFFFFFFFF;
  }

  @override
  String get benchmarkName => 'Matmul::T8';
}

class Matmul16T extends MatmulBase {
  @override
  Future<void> runBenchmark(int iterationId) async {
    final c = await _matmulParallel(a, b, 16);
    final value = c[n >> 1][n >> 1];

    _resultValue = (_resultValue + Helper.checksumFloat(value)) & 0xFFFFFFFF;
  }

  @override
  String get benchmarkName => 'Matmul::T16';
}

extension on MatmulBase {
  Future<List<Float64List>> _matmulParallel(
    List<Float64List> a,
    List<Float64List> b,
    int numThreads,
  ) async {
    final n = a.length;
    final bT = _transpose(b);

    final rowsPerThread = (n + numThreads - 1) ~/ numThreads;

    final futures = List.generate(numThreads, (thread) async {
      return await Isolate.run(() {
        final start = thread * rowsPerThread;
        final end = start + rowsPerThread < n ? start + rowsPerThread : n;
        final localResult = List<Float64List>.generate(
          end - start,
          (_) => Float64List(n),
        );

        for (int localI = 0; localI < end - start; localI++) {
          final i = start + localI;
          final ai = a[i];
          final ci = localResult[localI];

          for (int j = 0; j < n; j++) {
            final bTj = bT[j];
            double sum = 0.0;

            for (int k = 0; k < n; k++) {
              sum += ai[k] * bTj[k];
            }

            ci[j] = sum;
          }
        }

        return (start, localResult);
      });
    });

    final results = await Future.wait(futures);
    final c = List<Float64List>.generate(n, (_) => Float64List(n));

    for (final result in results) {
      final (start, rows) = result;
      for (int i = 0; i < rows.length; i++) {
        c[start + i] = rows[i];
      }
    }

    return c;
  }
}

const SOLAR_MASS = 4 * pi * pi;
const DAYS_PER_YEAR = 365.24;

class Planet {
  double x, y, z;
  double vx, vy, vz;
  double mass;

  Planet(
    double x,
    double y,
    double z,
    double vx,
    double vy,
    double vz,
    double mass,
  ) : x = x,
      y = y,
      z = z,
      vx = vx * DAYS_PER_YEAR,
      vy = vy * DAYS_PER_YEAR,
      vz = vz * DAYS_PER_YEAR,
      mass = mass * SOLAR_MASS;

  void moveFromI(List<Planet> bodies, double dt, int i) {
    while (i < bodies.length) {
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
    final iterations = Helper.configI64(benchmarkName, "iterations").toInt();

    bodies = _initialBodies
        .map(
          (p) => Planet(
            p.x,
            p.y,
            p.z,
            p.vx / DAYS_PER_YEAR,
            p.vy / DAYS_PER_YEAR,
            p.vz / DAYS_PER_YEAR,
            p.mass / SOLAR_MASS,
          ),
        )
        .toList();

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
    for (int n = 0; n < 1000; n++) {
      int i = 0;
      for (var b in bodies) {
        b.moveFromI(bodies, 0.01, i + 1);
        i++;
      }
    }
  }

  @override
  int checksum() {
    final v2 = _energy(bodies);
    final checksum1 = Helper.checksumFloat(_v1);
    final checksum2 = Helper.checksumFloat(v2);

    return ((checksum1 << 5) & checksum2) & 0xFFFFFFFF;
  }

  @override
  String get benchmarkName => 'CLBG::Nbody';
}

class RegexDna extends Benchmark {
  String seq = '';
  int ilen = 0;
  int clen = 0;
  String resultStr = '';
  late int n;

  RegexDna() {
    n = Helper.configI64(benchmarkName, "n").toInt();
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

  @override
  String get benchmarkName => 'CLBG::RegexDna';
}

class Revcomp extends Benchmark {
  String input = '';
  int resultValue = 0;

  static Uint8List? _lookupTable;

  static const FROM = "wsatugcyrkmbdhvnATUGCYRKMBDHVN";
  static const TO = "WSTAACGRYMKVHDBNTAACGRYMKVHDBN";

  @override
  void prepare() {
    final n = Helper.configI64(benchmarkName, "n").toInt();

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

  @override
  String get benchmarkName => 'CLBG::Revcomp';
}

class Spectralnorm extends Benchmark {
  late int size;
  late Float64List u;
  late Float64List v;
  int _resultValue = 0;

  @override
  void prepare() {
    size = Helper.configI64(benchmarkName, "size").toInt();

    u = Float64List(size)..fillRange(0, size, 1.0);
    v = Float64List(size)..fillRange(0, size, 1.0);
  }

  double _evalA(int i, int j) {
    return 1.0 / ((i + j) * (i + j + 1) / 2.0 + i + 1.0);
  }

  Float64List _evalATimesU(Float64List uVec) {
    final n = uVec.length;
    final result = Float64List(n);

    for (int i = 0; i < n; i++) {
      double sum = 0.0;
      for (int j = 0; j < n; j++) {
        sum += _evalA(i, j) * uVec[j];
      }
      result[i] = sum;
    }

    return result;
  }

  Float64List _evalAtTimesU(Float64List uVec) {
    final n = uVec.length;
    final result = Float64List(n);

    for (int i = 0; i < n; i++) {
      double sum = 0.0;
      for (int j = 0; j < n; j++) {
        sum += _evalA(j, i) * uVec[j];
      }
      result[i] = sum;
    }

    return result;
  }

  Float64List _evalAtATimesU(Float64List uVec) {
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

  @override
  String get benchmarkName => 'CLBG::Spectralnorm';
}

class Base64Encode extends Benchmark {
  late int n;
  late Uint8List _bytes;
  late String _str2;
  int _resultValue = 0;

  @override
  void prepare() {
    n = Helper.configI64(benchmarkName, "size").toInt();

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
    final _str = 'a' * n;
    final output =
        'encode ${_str.substring(0, min(4, _str.length))}... '
        'to ${_str2.substring(0, min(4, _str2.length))}...: $_resultValue';
    return Helper.checksumString(output);
  }

  @override
  String get benchmarkName => 'Base64::Encode';
}

class Base64Decode extends Benchmark {
  late int n;
  late String _str2;
  late Uint8List _bytes;
  int _resultValue = 0;

  @override
  void prepare() {
    n = Helper.configI64(benchmarkName, "size").toInt();

    _bytes = Uint8List(n);
    for (int i = 0; i < n; i++) {
      _bytes[i] = 0x61;
    }
    _str2 = base64Encode(_bytes);
  }

  @override
  void runBenchmark(int iterationId) {
    _bytes = base64Decode(_str2);
    _resultValue = (_resultValue + _bytes.length) & 0xFFFFFFFF;
  }

  @override
  int checksum() {
    final str3 = String.fromCharCodes(_bytes);
    final output =
        'decode ${_str2.substring(0, min(4, _str2.length))}... '
        'to ${str3.substring(0, min(4, str3.length))}...: $_resultValue';
    return Helper.checksumString(output);
  }

  @override
  String get benchmarkName => 'Base64::Decode';
}

class JsonGenerate extends Benchmark {
  int n = 0;
  List<Map<String, dynamic>> data = [];
  String text = '';
  int result = 0;

  JsonGenerate() {
    n = Helper.configI64(benchmarkName, "coords").toInt();
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
        'name':
            '${Helper.nextFloat().toStringAsFixed(7)} ${Helper.nextInt(10000)}',
        'opts': {
          '1': [1, true],
        },
      });
    }
  }

  @override
  void runBenchmark(int iterationId) {
    final jsonData = {'coordinates': data, 'info': 'some info'};

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

  @override
  String get benchmarkName => 'Json::Generate';
}

class JsonParseDom extends Benchmark {
  String text = '';
  int resultValue = 0;

  @override
  void prepare() {
    final jsonGen = JsonGenerate();
    jsonGen.n = Helper.configI64(benchmarkName, "coords").toInt();
    jsonGen.prepare();
    jsonGen.runBenchmark(0);
    text = jsonGen.getText();
  }

  (double, double, double) _calc(String text) {
    final json = jsonDecode(text) as Map<String, dynamic>;
    final coordinates = (json['coordinates'] as List)
        .cast<Map<String, dynamic>>();
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

  @override
  String get benchmarkName => 'Json::ParseDom';
}

class JsonParseMapping extends Benchmark {
  String text = '';
  int resultValue = 0;

  @override
  void prepare() {
    final jsonGen = JsonGenerate();
    jsonGen.n = Helper.configI64(benchmarkName, "coords").toInt();
    jsonGen.prepare();
    jsonGen.runBenchmark(0);
    text = jsonGen.getText();
  }

  ({double x, double y, double z}) _calc(String text) {
    final json = jsonDecode(text) as Map<String, dynamic>;
    final coordinates = (json['coordinates'] as List)
        .cast<Map<String, dynamic>>();
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

  @override
  String get benchmarkName => 'Json::ParseMapping';
}

class Sieve extends Benchmark {
  late BigInt limit;
  int _checksum = 0;

  @override
  void prepare() {
    limit = Helper.configI64(benchmarkName, "limit");
  }

  @override
  void runBenchmark(int iterationId) {
    int lim = limit.toInt();

    final primes = Uint8List(lim + 1);
    for (int i = 0; i <= lim; i++) primes[i] = 1;
    primes[0] = 0;
    primes[1] = 0;

    int sqrtLimit = sqrt(lim).floor();

    for (int p = 2; p <= sqrtLimit; p++) {
      if (primes[p] == 1) {
        for (int multiple = p * p; multiple <= lim; multiple += p) {
          primes[multiple] = 0;
        }
      }
    }

    int lastPrime = 2;
    int count = 1;

    for (int n = 3; n <= lim; n += 2) {
      if (primes[n] == 1) {
        lastPrime = n;
        count++;
      }
    }

    _checksum = (_checksum + lastPrime + count) & 0xFFFFFFFF;
  }

  @override
  int checksum() {
    return _checksum;
  }

  @override
  String get benchmarkName => 'Etc::Sieve';
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
    w = Helper.configI64(benchmarkName, "w").toInt();
    h = Helper.configI64(benchmarkName, "h").toInt();
  }

  int _shadePixel(TextRaytracerRay ray, TextRaytracerSphere obj, double tval) {
    final pi = ray.orig.add(ray.dir.scale(tval));
    final color = _diffuseShading(pi, obj, _light1);
    final col = (color.r + color.g + color.b) / 3.0;
    return (col * 6.0).floor();
  }

  double? _intersectSphere(
    TextRaytracerRay ray,
    TextRaytracerVector center,
    double radius,
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

  double _clamp(double x, double a, double b) => x < a ? a : (x > b ? b : x);

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

  @override
  String get benchmarkName => 'Etc::TextRaytracer';
}

class TextRaytracerVector {
  final double x, y, z;

  TextRaytracerVector(this.x, this.y, this.z);

  TextRaytracerVector scale(double s) =>
      TextRaytracerVector(x * s, y * s, z * s);

  TextRaytracerVector add(TextRaytracerVector other) =>
      TextRaytracerVector(x + other.x, y + other.y, z + other.z);

  TextRaytracerVector subtract(TextRaytracerVector other) =>
      TextRaytracerVector(x - other.x, y - other.y, z - other.z);

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

  TextRaytracerColor scale(double s) => TextRaytracerColor(r * s, g * s, b * s);

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
    weight = Helper.nextFloat() * 2 - 1;
    prevWeight = weight;
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
    threshold = Helper.nextFloat() * 2 - 1;
    prevThreshold = threshold;
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
      synapse.weight +=
          (rate * learningRate * error * synapse.sourceNeuron.output) +
          (momentum * (synapse.weight - synapse.prevWeight));
      synapse.prevWeight = tempWeight;
    }

    final tempThreshold = threshold;
    threshold +=
        (rate * learningRate * error * -1) +
        (momentum * (threshold - prevThreshold));
    prevThreshold = tempThreshold;
  }
}

class NeuralNetNetwork {
  final List<NeuralNetNeuron> inputLayer;
  final List<NeuralNetNeuron> hiddenLayer;
  final List<NeuralNetNeuron> outputLayer;

  NeuralNetNetwork(int inputs, int hidden, int outputs)
    : inputLayer = List.generate(inputs, (_) => NeuralNetNeuron()),
      hiddenLayer = List.generate(hidden, (_) => NeuralNetNeuron()),
      outputLayer = List.generate(outputs, (_) => NeuralNetNeuron()) {
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

  void train(Float64List inputs, Float64List targets) {
    feedForward(inputs);

    for (int i = 0; i < outputLayer.length; i++) {
      outputLayer[i].outputTrain(0.3, targets[i]);
    }

    for (final neuron in hiddenLayer) {
      neuron.hiddenTrain(0.3);
    }
  }

  void feedForward(Float64List inputs) {
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

  Float64List currentOutputs() {
    final outputs = Float64List(outputLayer.length);
    for (int i = 0; i < outputLayer.length; i++) {
      outputs[i] = outputLayer[i].output;
    }
    return outputs;
  }
}

class NeuralNet extends Benchmark {
  static final INPUT_00 = Float64List.fromList([0, 0]);
  static final INPUT_01 = Float64List.fromList([0, 1]);
  static final INPUT_10 = Float64List.fromList([1, 0]);
  static final INPUT_11 = Float64List.fromList([1, 1]);
  static final TARGET_0 = Float64List.fromList([0]);
  static final TARGET_1 = Float64List.fromList([1]);

  late NeuralNetNetwork xor;

  @override
  void prepare() {
    Helper.reset();
    xor = NeuralNetNetwork(2, 10, 1);
  }

  @override
  void runBenchmark(int iterationId) {
    for (int iter = 0; iter < 1000; iter++) {
      xor.train(INPUT_00, TARGET_0);
      xor.train(INPUT_10, TARGET_1);
      xor.train(INPUT_01, TARGET_1);
      xor.train(INPUT_11, TARGET_0);
    }
  }

  @override
  int checksum() {
    final results = Float64List(4);

    xor.feedForward(INPUT_00);
    results[0] = xor.currentOutputs()[0];

    xor.feedForward(INPUT_01);
    results[1] = xor.currentOutputs()[0];

    xor.feedForward(INPUT_10);
    results[2] = xor.currentOutputs()[0];

    xor.feedForward(INPUT_11);
    results[3] = xor.currentOutputs()[0];

    final sum = results.fold(0.0, (a, b) => a + b);
    return Helper.checksumFloat(sum);
  }

  @override
  String get benchmarkName => 'Etc::NeuralNet';
}

abstract class SortBenchmark extends Benchmark {
  late List<int> _data;
  late int size;
  int _resultValue = 0;

  @override
  void prepare() {
    size = Helper.configI64(benchmarkName, "size").toInt();

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

  @override
  String get benchmarkName => 'Sort::Quick';
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

  @override
  String get benchmarkName => 'Sort::Merge';
}

class SortSelf extends SortBenchmark {
  @override
  List<int> test() {
    final arr = List<int>.from(_data);
    arr.sort();
    return arr;
  }

  @override
  String get benchmarkName => 'Sort::Self';
}

class GraphPathGraph {
  final int vertices;
  final int jumps;
  final int jumpLen;
  final List<List<int>> adj;

  GraphPathGraph(this.vertices, {this.jumps = 3, this.jumpLen = 100})
    : adj = List.generate(vertices, (_) => []);

  void addEdge(int u, int v) {
    adj[u].add(v);
    adj[v].add(u);
  }

  void generateRandom() {
    for (int i = 1; i < vertices; i++) {
      addEdge(i, i - 1);
    }

    for (int v = 0; v < vertices; v++) {
      int numJumps = Helper.nextInt(jumps);
      for (int j = 0; j < numJumps; j++) {
        int offset = Helper.nextInt(jumpLen) - jumpLen ~/ 2;
        int u = v + offset;

        if (u >= 0 && u < vertices && u != v) {
          addEdge(v, u);
        }
      }
    }
  }
}

abstract class GraphPathBenchmark extends Benchmark {
  late GraphPathGraph _graph;
  int _resultValue = 0;

  @override
  void prepare() {
    final vertices = Helper.configI64(benchmarkName, "vertices").toInt();
    final jumps = Helper.configI64(benchmarkName, "jumps").toInt();
    final jumpLen = Helper.configI64(benchmarkName, "jump_len").toInt();

    _graph = GraphPathGraph(vertices, jumps: jumps, jumpLen: jumpLen);
    _graph.generateRandom();
  }

  @override
  void runBenchmark(int iterationId) {
    _resultValue = (_resultValue + test()) & 0xFFFFFFFF;
  }

  @override
  int checksum() {
    return _resultValue & 0xFFFFFFFF;
  }

  int test();
}

class GraphPathBFS extends GraphPathBenchmark {
  @override
  int test() {
    return _bfsShortestPath(0, _graph.vertices - 1);
  }

  int _bfsShortestPath(int start, int target) {
    if (start == target) return 0;

    final visited = Uint8List(_graph.vertices);
    final queue = Queue<(int, int)>();
    queue.add((start, 0));
    visited[start] = 1;

    while (queue.isNotEmpty) {
      final (v, dist) = queue.removeFirst();

      for (final neighbor in _graph.adj[v]) {
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

  @override
  String get benchmarkName => 'Graph::BFS';
}

class GraphPathDFS extends GraphPathBenchmark {
  @override
  int test() {
    return _dfsFindPath(0, _graph.vertices - 1);
  }

  int _dfsFindPath(int start, int target) {
    if (start == target) return 0;

    final visited = Uint8List(_graph.vertices);
    final stack = <(int, int)>[(start, 0)];
    var bestPath = 0x7FFFFFFFFFFFFFFF;

    while (stack.isNotEmpty) {
      final (v, dist) = stack.removeLast();

      if (visited[v] == 1 || dist >= bestPath) continue;
      visited[v] = 1;

      for (final neighbor in _graph.adj[v]) {
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

  @override
  String get benchmarkName => 'Graph::DFS';
}

class PriorityQueueItem implements Comparable<PriorityQueueItem> {
  final int vertex;
  final int priority;
  PriorityQueueItem(this.vertex, this.priority);

  @override
  int compareTo(PriorityQueueItem other) {
    return priority.compareTo(other.priority);
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

class GraphPathAStar extends GraphPathBenchmark {
  @override
  int test() {
    return _aStarShortestPath(0, _graph.vertices - 1);
  }

  int _heuristic(int v, int target) => target - v;

  int _aStarShortestPath(int start, int target) {
    if (start == target) return 0;

    final gScore = List<int>.filled(_graph.vertices, 0x7FFFFFFF);
    final fScore = List<int>.filled(_graph.vertices, 0x7FFFFFFF);
    final closed = Uint8List(_graph.vertices);

    gScore[start] = 0;
    fScore[start] = _heuristic(start, target);

    final openSet = PriorityQueue<PriorityQueueItem>();
    final inOpenSet = Uint8List(_graph.vertices);

    openSet.add(PriorityQueueItem(start, fScore[start]));
    inOpenSet[start] = 1;

    while (openSet.isNotEmpty) {
      final current = openSet.removeFirst();
      inOpenSet[current.vertex] = 0;

      if (current.vertex == target) {
        return gScore[current.vertex];
      }

      closed[current.vertex] = 1;

      for (final neighbor in _graph.adj[current.vertex]) {
        if (closed[neighbor] == 1) continue;

        final tentativeG = gScore[current.vertex] + 1;

        if (tentativeG < gScore[neighbor]) {
          gScore[neighbor] = tentativeG;
          fScore[neighbor] = tentativeG + _heuristic(neighbor, target);

          if (inOpenSet[neighbor] == 0) {
            openSet.add(PriorityQueueItem(neighbor, fScore[neighbor]));
            inOpenSet[neighbor] = 1;
          }
        }
      }
    }

    return -1;
  }

  @override
  String get benchmarkName => 'Graph::AStar';
}

abstract class BufferHashBenchmark extends Benchmark {
  late Uint8List _data;
  late int _n;
  int _result = 0;

  @override
  void prepare() {
    _n = Helper.configI64(benchmarkName, "size").toInt();

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

    for (final byte in _data) {
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

  @override
  String get benchmarkName => 'Hash::CRC32';
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

  @override
  String get benchmarkName => 'Hash::SHA256';
}

class FastLRUCache<K, V> {
  final int capacity;
  final Map<K, _Node<K, V>> _cache;
  int _size = 0;
  _Node<K, V>? _head;
  _Node<K, V>? _tail;

  FastLRUCache(this.capacity) : _cache = {};

  V? get(K key) {
    final node = _cache[key];
    if (node == null) return null;

    _moveToFront(node);
    return node.value;
  }

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

  void _addToFront(_Node<K, V> node) {
    node.next = _head;
    if (_head != null) _head!.prev = node;
    _head = node;
    if (_tail == null) _tail = node;
  }

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
    _valuesSize = Helper.configI64(benchmarkName, "values").toInt();
    _cacheSize = Helper.configI64(benchmarkName, "size").toInt();
    _cache = FastLRUCache(_cacheSize);

    _hits = 0;
    _misses = 0;
    Helper.reset();
  }

  @override
  void runBenchmark(int iterationId) {
    for (int n = 0; n < 1000; n++) {
      final key = 'item_${Helper.nextInt(_valuesSize)}';

      if (_cache.get(key) != null) {
        _hits++;
        _cache.put(key, 'updated_$iterations');
      } else {
        _misses++;
        _cache.put(key, 'new_$iterations');
      }
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

  @override
  String get benchmarkName => 'Etc::CacheSimulation';
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
  late String currentChar;
  final expressions = <Node2>[];

  Parser2(this.input) {
    currentChar = input.isNotEmpty ? input[0] : '\0';
  }

  void parse() {
    while (pos < input.length) {
      skipWhitespace();
      if (pos >= input.length) break;

      final expr = parseExpression();
      expressions.add(expr);
    }
  }

  Node2 parseExpression() {
    var node = parseTerm();

    while (pos < input.length) {
      skipWhitespace();
      if (pos >= input.length) break;

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

    while (pos < input.length) {
      skipWhitespace();
      if (pos >= input.length) break;

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
    if (pos >= input.length) {
      return NumberNode(0);
    }

    final char = currentChar;

    if (_isDigit(char)) {
      return parseNumber();
    } else if (_isLetter(char)) {
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
    while (pos < input.length && _isDigit(currentChar)) {
      value = value * 10 + (currentChar.codeUnitAt(0) - 48);
      advance();
    }
    return NumberNode(value);
  }

  Node2 parseVariable() {
    final start = pos;
    while (pos < input.length &&
        (_isLetter(currentChar) || _isDigit(currentChar))) {
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
    if (pos >= input.length) {
      currentChar = '\0';
    } else {
      currentChar = input[pos];
    }
  }

  void skipWhitespace() {
    while (pos < input.length && _isWhitespace(currentChar)) {
      advance();
    }
  }

  bool _isDigit(String ch) => ch.codeUnitAt(0) >= 48 && ch.codeUnitAt(0) <= 57;

  bool _isLetter(String ch) {
    final code = ch.codeUnitAt(0);
    return (code >= 65 && code <= 90) || (code >= 97 && code <= 122);
  }

  bool _isWhitespace(String ch) =>
      ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r';
}

class CalculatorAst extends Benchmark {
  late int n;
  String _text = '';
  final _expressions = <Node2>[];
  int _resultValue = 0;

  @override
  void prepare() {
    n = Helper.configI64(benchmarkName, "operations").toInt();
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
          buffer.write(
            '(v${v - 1} / 3) * 4 - $i / (3 + (18 - v${v - 2})) % v${v - 3} + 2 * ((9 - v${v - 6}) * (v${v - 5} + 7))',
          );
          break;
        case 1:
          buffer.write(
            'v${v - 1} + (v${v - 2} + v${v - 3}) * v${v - 4} - (v${v - 5} / v${v - 6})',
          );
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
        _resultValue =
            (_resultValue + Helper.checksumString(lastExpr.varName)) &
            0xFFFFFFFF;
      }
    }
  }

  List<Node2> getExpressions() => _expressions;

  @override
  int checksum() {
    return _resultValue;
  }

  @override
  String get benchmarkName => 'Calculator::Ast';
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
        case '+':
          return left + right;
        case '-':
          return left - right;
        case '*':
          return left * right;
        case '/':
          return _simpleDiv(left, right);
        case '%':
          return _simpleMod(left, right);
        default:
          return 0;
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
    final operations = Helper.configI64(benchmarkName, "operations").toInt();

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

  @override
  String get benchmarkName => 'Calculator::Interpreter';
}

class CellObj {
  bool alive = false;
  bool nextState = false;
  final neighbors = List<CellObj?>.filled(8, null);
  int neighborCount = 0;

  void addNeighbor(CellObj neighbor) {
    neighbors[neighborCount++] = neighbor;
  }

  void computeNextState() {
    int aliveNeighbors = 0;
    for (int i = 0; i < neighborCount; i++) {
      if (neighbors[i]!.alive) aliveNeighbors++;
    }

    if (alive) {
      nextState = aliveNeighbors == 2 || aliveNeighbors == 3;
    } else {
      nextState = aliveNeighbors == 3;
    }
  }

  void update() {
    alive = nextState;
  }
}

class GameOfLifeGrid {
  late int width;
  late int height;
  late List<List<CellObj>> cells;

  GameOfLifeGrid(int width, int height) {
    this.width = width;
    this.height = height;

    cells = List.generate(
      height,
      (_) => List.generate(width, (_) => CellObj()),
    );

    _linkNeighbors();
  }

  void _linkNeighbors() {
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final cell = cells[y][x];

        for (int dy = -1; dy <= 1; dy++) {
          for (int dx = -1; dx <= 1; dx++) {
            if (dx == 0 && dy == 0) continue;

            final ny = (y + dy + height) % height;
            final nx = (x + dx + width) % width;

            cell.addNeighbor(cells[ny][nx]);
          }
        }
      }
    }
  }

  void nextGeneration() {
    for (final row in cells) {
      for (final cell in row) {
        cell.computeNextState();
      }
    }

    for (final row in cells) {
      for (final cell in row) {
        cell.update();
      }
    }
  }

  int countAlive() {
    int count = 0;
    for (final row in cells) {
      for (final cell in row) {
        if (cell.alive) count++;
      }
    }
    return count;
  }

  int computeHash() {
    const int FNV_OFFSET_BASIS = 2166136261;
    const int FNV_PRIME = 16777619;

    int hasher = FNV_OFFSET_BASIS;

    for (final row in cells) {
      for (final cell in row) {
        final alive = cell.alive ? 1 : 0;
        hasher = (hasher ^ alive) & 0xFFFFFFFF;
        hasher = (hasher * FNV_PRIME) & 0xFFFFFFFF;
      }
    }

    return hasher & 0xFFFFFFFF;
  }

  List<List<CellObj>> getCells() => cells;
}

class GameOfLife extends Benchmark {
  late int width;
  late int height;
  late GameOfLifeGrid grid;

  GameOfLife() {
    width = Helper.configI64(benchmarkName, "w").toInt();
    height = Helper.configI64(benchmarkName, "h").toInt();
    grid = GameOfLifeGrid(width, height);
  }

  @override
  void prepare() {
    for (final row in grid.getCells()) {
      for (final cell in row) {
        if (Helper.nextFloat() < 0.1) {
          cell.alive = true;
        }
      }
    }
  }

  @override
  void runBenchmark(int iterationId) {
    grid.nextGeneration();
  }

  @override
  int checksum() {
    final alive = grid.countAlive();
    return (grid.computeHash() + alive) & 0xFFFFFFFF;
  }

  @override
  String get benchmarkName => 'Etc::GameOfLife';
}

enum CellKind {
  wall(0),
  space(1),
  start(2),
  finish(3),
  border(4),
  path(5);

  const CellKind(this.value);
  final int value;
}

class Cell {
  CellKind kind;
  List<Cell> neighbors;
  int x;
  int y;

  Cell(this.x, this.y) : kind = CellKind.wall, neighbors = [];

  bool isWalkable() {
    return kind == CellKind.space ||
        kind == CellKind.start ||
        kind == CellKind.finish;
  }

  void dig() {
    int walkableNeighbors = 0;
    for (int i = 0; i < neighbors.length; i++) {
      if (neighbors[i].isWalkable()) walkableNeighbors++;
    }
    if (walkableNeighbors != 1) return;

    kind = CellKind.space;

    for (int i = 0; i < neighbors.length; i++) {
      if (neighbors[i].kind == CellKind.wall) {
        neighbors[i].dig();
      }
    }
  }

  void ensureOpenFinish() {
    kind = CellKind.space;

    int walkableNeighbors = 0;
    for (int i = 0; i < neighbors.length; i++) {
      if (neighbors[i].isWalkable()) walkableNeighbors++;
    }
    if (walkableNeighbors > 1) return;

    for (int i = 0; i < neighbors.length; i++) {
      if (neighbors[i].kind == CellKind.wall) {
        neighbors[i].ensureOpenFinish();
      }
    }
  }

  void reset() {
    if (kind == CellKind.space) {
      kind = CellKind.wall;
    }
  }
}

enum MazeCellKind {
  wall(0),
  space(1),
  start(2),
  finish(3),
  border(4),
  path(5);

  const MazeCellKind(this.value);
  final int value;

  bool get isWalkable =>
      this == MazeCellKind.space ||
      this == MazeCellKind.start ||
      this == MazeCellKind.finish;
}

class MazeCell {
  MazeCellKind kind;
  final List<MazeCell> neighbors;
  final int x, y;

  MazeCell(this.x, this.y) : kind = MazeCellKind.wall, neighbors = [];

  void addNeighbor(MazeCell cell) => neighbors.add(cell);

  void reset() {
    if (kind == MazeCellKind.space) {
      kind = MazeCellKind.wall;
    }
  }
}

class Maze {
  final int width;
  final int height;
  final List<List<MazeCell>> cells;
  late final MazeCell start;
  late final MazeCell finish;

  Maze(int w, int h)
    : width = max(w, 5),
      height = max(h, 5),
      cells = List.generate(
        max(h, 5),
        (y) => List.generate(max(w, 5), (x) => MazeCell(x, y)),
      ) {
    start = cells[1][1];
    finish = cells[height - 2][width - 2];
    start.kind = MazeCellKind.start;
    finish.kind = MazeCellKind.finish;
    updateNeighbors();
  }

  void updateNeighbors() {
    for (var row in cells) {
      for (var cell in row) {
        cell.neighbors.clear();
      }
    }

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        var cell = cells[y][x];

        if (x > 0 && y > 0 && x < width - 1 && y < height - 1) {
          cell.addNeighbor(cells[y - 1][x]);
          cell.addNeighbor(cells[y + 1][x]);
          cell.addNeighbor(cells[y][x + 1]);
          cell.addNeighbor(cells[y][x - 1]);

          for (int t = 0; t < 4; t++) {
            int i = Helper.nextInt(4);
            int j = Helper.nextInt(4);
            if (i != j) {
              var temp = cell.neighbors[i];
              cell.neighbors[i] = cell.neighbors[j];
              cell.neighbors[j] = temp;
            }
          }
        } else {
          cell.kind = MazeCellKind.border;
        }
      }
    }
  }

  void reset() {
    for (var row in cells) {
      for (var cell in row) {
        cell.reset();
      }
    }
    start.kind = MazeCellKind.start;
    finish.kind = MazeCellKind.finish;
  }

  void dig(MazeCell startCell) {
    List<MazeCell> stack = [];
    stack.add(startCell);

    while (stack.isNotEmpty) {
      var cell = stack.removeLast();

      int walkable = 0;
      for (var n in cell.neighbors) {
        if (n.kind.isWalkable) walkable++;
      }

      if (walkable != 1) continue;

      cell.kind = MazeCellKind.space;

      for (var n in cell.neighbors) {
        if (n.kind == MazeCellKind.wall) {
          stack.add(n);
        }
      }
    }
  }

  void ensureOpenFinish(MazeCell startCell) {
    List<MazeCell> stack = [];
    stack.add(startCell);

    while (stack.isNotEmpty) {
      var cell = stack.removeLast();

      cell.kind = MazeCellKind.space;

      int walkable = 0;
      for (var n in cell.neighbors) {
        if (n.kind.isWalkable) walkable++;
      }

      if (walkable > 1) continue;

      for (var n in cell.neighbors) {
        if (n.kind == MazeCellKind.wall) {
          stack.add(n);
        }
      }
    }
  }

  void generate() {
    for (var n in start.neighbors) {
      if (n.kind == MazeCellKind.wall) {
        dig(n);
      }
    }

    for (var n in finish.neighbors) {
      if (n.kind == MazeCellKind.wall) {
        ensureOpenFinish(n);
      }
    }
  }

  MazeCell getStart() => start;
  MazeCell getFinish() => finish;
  MazeCell middleCell() => cells[height ~/ 2][width ~/ 2];

  int checksum() {
    int hasher = 2166136261 & 0xFFFFFFFF;
    const int prime = 16777619;

    for (var row in cells) {
      for (var cell in row) {
        if (cell.kind == MazeCellKind.space) {
          int val = (cell.x * cell.y) & 0xFFFFFFFF;
          hasher = ((hasher ^ val) * prime) & 0xFFFFFFFF;
        }
      }
    }
    return hasher;
  }

  void printToConsole() {
    for (var row in cells) {
      for (var cell in row) {
        switch (cell.kind) {
          case MazeCellKind.space:
            stdout.write(' ');
            break;
          case MazeCellKind.wall:
            stdout.write('\u001B[34m#\u001B[0m');
            break;
          case MazeCellKind.border:
            stdout.write('\u001B[31mO\u001B[0m');
            break;
          case MazeCellKind.start:
            stdout.write('\u001B[32m>\u001B[0m');
            break;
          case MazeCellKind.finish:
            stdout.write('\u001B[32m<\u001B[0m');
            break;
          case MazeCellKind.path:
            stdout.write('\u001B[33m.\u001B[0m');
            break;
        }
      }
      stdout.writeln();
    }
    stdout.writeln();
  }
}

class _BfsPathNode {
  final MazeCell cell;
  final int parent;
  _BfsPathNode(this.cell, this.parent);
}

class _AStarItem implements Comparable<_AStarItem> {
  final int priority;
  final int vertex;

  _AStarItem(this.priority, this.vertex);

  @override
  int compareTo(_AStarItem other) {
    if (priority != other.priority) {
      return priority.compareTo(other.priority);
    }
    return vertex.compareTo(other.vertex);
  }
}

class MazeGenerator extends Benchmark {
  late final int width;
  late final int height;
  late Maze maze;
  int resultVal = 0;

  MazeGenerator() {
    width = Helper.configI64("Maze::Generator", "w").toInt();
    height = Helper.configI64("Maze::Generator", "h").toInt();
    maze = Maze(width, height);
  }

  @override
  String get benchmarkName => 'Maze::Generator';

  @override
  void prepare() {}

  @override
  void runBenchmark(int iterationId) {
    maze.reset();
    maze.generate();
    resultVal = (resultVal + maze.middleCell().kind.value) & 0xFFFFFFFF;
  }

  @override
  int checksum() {
    return (resultVal + maze.checksum()) & 0xFFFFFFFF;
  }
}

class MazeBFS extends Benchmark {
  late final int width;
  late final int height;
  late Maze maze;
  int resultVal = 0;
  List<MazeCell> path = [];

  MazeBFS() {
    width = Helper.configI64("Maze::BFS", "w").toInt();
    height = Helper.configI64("Maze::BFS", "h").toInt();
    maze = Maze(width, height);
  }

  @override
  String get benchmarkName => 'Maze::BFS';

  @override
  void prepare() {
    maze.generate();
  }

  List<MazeCell> bfs(MazeCell start, MazeCell target) {
    if (start == target) return [start];

    var queue = Queue<int>();
    var visited = List.generate(height, (_) => List<bool>.filled(width, false));
    var pathNodes = <_BfsPathNode>[];

    visited[start.y][start.x] = true;
    pathNodes.add(_BfsPathNode(start, -1));
    queue.add(0);

    while (queue.isNotEmpty) {
      int pathId = queue.removeFirst();
      var cell = pathNodes[pathId].cell;

      for (var neighbor in cell.neighbors) {
        if (neighbor == target) {
          var result = [target];
          int current = pathId;
          while (current >= 0) {
            result.add(pathNodes[current].cell);
            current = pathNodes[current].parent;
          }
          return result.reversed.toList();
        }

        if (neighbor.kind.isWalkable && !visited[neighbor.y][neighbor.x]) {
          visited[neighbor.y][neighbor.x] = true;
          pathNodes.add(_BfsPathNode(neighbor, pathId));
          queue.add(pathNodes.length - 1);
        }
      }
    }
    return [];
  }

  int midCellChecksum(List<MazeCell> p) {
    if (p.isEmpty) return 0;
    var cell = p[p.length ~/ 2];
    return (cell.x * cell.y) & 0xFFFFFFFF;
  }

  @override
  void runBenchmark(int iterationId) {
    path = bfs(maze.getStart(), maze.getFinish());
    resultVal = (resultVal + path.length) & 0xFFFFFFFF;
  }

  @override
  int checksum() {
    return (resultVal + midCellChecksum(path)) & 0xFFFFFFFF;
  }
}

class MazeAStar extends Benchmark {
  late final int width;
  late final int height;
  late Maze maze;
  int resultVal = 0;
  List<MazeCell> path = [];

  MazeAStar() {
    width = Helper.configI64("Maze::AStar", "w").toInt();
    height = Helper.configI64("Maze::AStar", "h").toInt();
    maze = Maze(width, height);
  }

  @override
  String get benchmarkName => 'Maze::AStar';

  @override
  void prepare() {
    maze.generate();
  }

  int heuristic(MazeCell a, MazeCell b) {
    return (a.x - b.x).abs() + (a.y - b.y).abs();
  }

  int idx(int y, int x) => y * width + x;

  List<MazeCell> astar(MazeCell start, MazeCell target) {
    if (start == target) return [start];

    int size = width * height;

    var cameFrom = List<int>.filled(size, -1);
    var gScore = List<int>.filled(size, 1 << 30);
    var bestF = List<int>.filled(size, 1 << 30);

    int startIdx = idx(start.y, start.x);
    int targetIdx = idx(target.y, target.x);

    var openSet = PriorityQueue<_AStarItem>();
    var inOpen = List<bool>.filled(size, false);

    gScore[startIdx] = 0;
    int fStart = heuristic(start, target);
    openSet.add(_AStarItem(fStart, startIdx));
    bestF[startIdx] = fStart;
    inOpen[startIdx] = true;

    while (openSet.isNotEmpty) {
      var current = openSet.removeFirst();
      int currentIdx = current.vertex;
      inOpen[currentIdx] = false;

      if (currentIdx == targetIdx) {
        var result = <MazeCell>[];
        int cur = currentIdx;
        while (cur != -1) {
          int y = cur ~/ width;
          int x = cur % width;
          result.add(maze.cells[y][x]);
          cur = cameFrom[cur];
        }
        return result.reversed.toList();
      }

      int currentY = currentIdx ~/ width;
      int currentX = currentIdx % width;
      var currentCell = maze.cells[currentY][currentX];
      int currentG = gScore[currentIdx];

      for (var neighbor in currentCell.neighbors) {
        if (!neighbor.kind.isWalkable) continue;

        int neighborIdx = idx(neighbor.y, neighbor.x);
        int tentativeG = currentG + 1;

        if (tentativeG < gScore[neighborIdx]) {
          cameFrom[neighborIdx] = currentIdx;
          gScore[neighborIdx] = tentativeG;
          int fNew = tentativeG + heuristic(neighbor, target);

          if (fNew < bestF[neighborIdx]) {
            bestF[neighborIdx] = fNew;
            openSet.add(_AStarItem(fNew, neighborIdx));
            inOpen[neighborIdx] = true;
          }
        }
      }
    }
    return [];
  }

  int midCellChecksum(List<MazeCell> p) {
    if (p.isEmpty) return 0;
    var cell = p[p.length ~/ 2];
    return (cell.x * cell.y) & 0xFFFFFFFF;
  }

  @override
  void runBenchmark(int iterationId) {
    path = astar(maze.getStart(), maze.getFinish());
    resultVal = (resultVal + path.length) & 0xFFFFFFFF;
  }

  @override
  int checksum() {
    return (resultVal + midCellChecksum(path)) & 0xFFFFFFFF;
  }
}

Uint8List generateTestData(int size) {
  const pattern = 'ABRACADABRA';
  var data = Uint8List(size);
  for (int i = 0; i < size; i++) {
    data[i] = pattern.codeUnitAt(i % pattern.length);
  }
  return data;
}

class BWTResult {
  final Uint8List transformed;
  final int originalIdx;

  BWTResult(this.transformed, this.originalIdx);
}

class BWTEncode extends Benchmark {
  BWTResult bwtTransform(Uint8List input) {
    int n = input.length;
    if (n == 0) return BWTResult(Uint8List(0), 0);

    List<int> counts = List<int>.filled(256, 0);
    for (int i = 0; i < n; i++) {
      counts[input[i]]++;
    }

    List<int> positions = List<int>.filled(256, 0);
    int total = 0;
    for (int i = 0; i < 256; i++) {
      positions[i] = total;
      total += counts[i];
      counts[i] = 0;
    }

    List<int> sa = List<int>.filled(n, 0);
    for (int i = 0; i < n; i++) {
      int byteVal = input[i];
      int pos = positions[byteVal] + counts[byteVal];
      sa[pos] = i;
      counts[byteVal]++;
    }

    if (n > 1) {
      List<int> rank = List<int>.filled(n, 0);
      int currentRank = 0;
      int prevChar = input[sa[0]];

      for (int i = 0; i < n; i++) {
        int idx = sa[i];
        int currChar = input[idx];
        if (currChar != prevChar) {
          currentRank++;
          prevChar = currChar;
        }
        rank[idx] = currentRank;
      }

      int k = 1;
      while (k < n) {
        sa.sort((a, b) {
          int ra = rank[a];
          int rb = rank[b];
          if (ra != rb) return ra - rb;
          int rak = rank[(a + k) % n];
          int rbk = rank[(b + k) % n];
          return rak - rbk;
        });

        List<int> newRank = List<int>.filled(n, 0);
        newRank[sa[0]] = 0;
        for (int i = 1; i < n; i++) {
          int prevIdx = sa[i - 1];
          int currIdx = sa[i];
          newRank[currIdx] =
              newRank[prevIdx] +
              ((rank[prevIdx] != rank[currIdx] ||
                      rank[(prevIdx + k) % n] != rank[(currIdx + k) % n])
                  ? 1
                  : 0);
        }

        rank = newRank;
        k *= 2;
      }
    }

    Uint8List transformed = Uint8List(n);
    int originalIdx = 0;

    for (int i = 0; i < n; i++) {
      int suffix = sa[i];
      if (suffix == 0) {
        transformed[i] = input[n - 1];
        originalIdx = i;
      } else {
        transformed[i] = input[suffix - 1];
      }
    }

    return BWTResult(transformed, originalIdx);
  }

  late int sizeVal;
  late Uint8List testData;
  late BWTResult bwtResult;
  int resultVal = 0;

  BWTEncode() {
    sizeVal = Helper.configI64(benchmarkName, 'size').toInt();
  }

  @override
  String get benchmarkName => 'Compress::BWTEncode';

  @override
  void prepare() {
    testData = generateTestData(sizeVal);
    resultVal = 0;
  }

  @override
  void runBenchmark(int iterationId) {
    bwtResult = bwtTransform(testData);
    resultVal += bwtResult.transformed.length;
  }

  @override
  int checksum() => resultVal & 0xFFFFFFFF;
}

class BWTDecode extends Benchmark {
  late int sizeVal;
  late Uint8List testData;
  late Uint8List inverted;
  late BWTResult bwtResult;
  int resultVal = 0;

  BWTDecode() {
    sizeVal = Helper.configI64(benchmarkName, 'size').toInt();
  }

  @override
  String get benchmarkName => 'Compress::BWTDecode';

  Uint8List bwtInverse(BWTResult bwtResult) {
    Uint8List bwt = bwtResult.transformed;
    int n = bwt.length;
    if (n == 0) return Uint8List(0);

    List<int> counts = List<int>.filled(256, 0);
    for (int byte in bwt) counts[byte]++;

    List<int> positions = List<int>.filled(256, 0);
    int total = 0;
    for (int i = 0; i < 256; i++) {
      positions[i] = total;
      total += counts[i];
    }

    List<int> next = List<int>.filled(n, 0);
    List<int> tempCounts = List<int>.filled(256, 0);

    for (int i = 0; i < n; i++) {
      int byteIdx = bwt[i];
      int pos = positions[byteIdx] + tempCounts[byteIdx];
      next[pos] = i;
      tempCounts[byteIdx]++;
    }

    Uint8List result = Uint8List(n);
    int idx = bwtResult.originalIdx;

    for (int i = 0; i < n; i++) {
      idx = next[idx];
      result[i] = bwt[idx];
    }

    return result;
  }

  @override
  void prepare() {
    var encoder = BWTEncode();
    encoder.sizeVal = sizeVal;
    encoder.prepare();
    encoder.runBenchmark(0);
    testData = encoder.testData;
    bwtResult = encoder.bwtResult;
    resultVal = 0;
  }

  @override
  void runBenchmark(int iterationId) {
    inverted = bwtInverse(bwtResult);
    resultVal += inverted.length;
  }

  @override
  int checksum() {
    int res = resultVal;
    if (listEquals(inverted, testData)) res += 100000;
    return res & 0xFFFFFFFF;
  }
}

class HuffmanNode {
  int frequency;
  int byteVal;
  bool isLeaf;
  HuffmanNode? left;
  HuffmanNode? right;

  HuffmanNode(this.frequency, [this.byteVal = 0, this.isLeaf = true])
    : left = null,
      right = null;
}

class HuffmanCodes {
  final List<int> codeLengths = List<int>.filled(256, 0);
  final List<int> codes = List<int>.filled(256, 0);
}

class EncodedResult {
  final Uint8List data;
  final int bitCount;
  final List<int> frequencies;

  EncodedResult(this.data, this.bitCount, this.frequencies);
}

HuffmanNode buildHuffmanTree(List<int> frequencies) {
  var nodes = <HuffmanNode>[];
  for (int i = 0; i < 256; i++) {
    if (frequencies[i] > 0) {
      nodes.add(HuffmanNode(frequencies[i], i));
    }
  }

  nodes.sort((a, b) => a.frequency - b.frequency);

  if (nodes.length == 1) {
    var node = nodes[0];
    var root = HuffmanNode(node.frequency, 0, false);
    root.left = node;
    root.right = HuffmanNode(0, 0);
    return root;
  }

  while (nodes.length > 1) {
    var left = nodes.removeAt(0);
    var right = nodes.removeAt(0);

    var parent = HuffmanNode(left.frequency + right.frequency, 0, false);
    parent.left = left;
    parent.right = right;

    int pos = 0;
    while (pos < nodes.length && nodes[pos].frequency < parent.frequency) {
      pos++;
    }
    nodes.insert(pos, parent);
  }

  return nodes[0];
}

void buildHuffmanCodes(
  HuffmanNode node,
  int code,
  int length,
  HuffmanCodes codes,
) {
  if (node.isLeaf) {
    if (length > 0 || node.byteVal != 0) {
      int idx = node.byteVal;
      codes.codeLengths[idx] = length;
      codes.codes[idx] = code;
    }
  } else {
    if (node.left != null) {
      buildHuffmanCodes(node.left!, code << 1, length + 1, codes);
    }
    if (node.right != null) {
      buildHuffmanCodes(node.right!, (code << 1) | 1, length + 1, codes);
    }
  }
}

EncodedResult huffmanEncode(
  Uint8List data,
  HuffmanCodes codes,
  List<int> frequencies,
) {
  var result = <int>[];
  int currentByte = 0;
  int bitPos = 0;
  int totalBits = 0;

  for (int byte in data) {
    int idx = byte;
    int code = codes.codes[idx];
    int length = codes.codeLengths[idx];

    for (int i = length - 1; i >= 0; i--) {
      if ((code & (1 << i)) != 0) {
        currentByte |= 1 << (7 - bitPos);
      }
      bitPos++;
      totalBits++;

      if (bitPos == 8) {
        result.add(currentByte);
        currentByte = 0;
        bitPos = 0;
      }
    }
  }

  if (bitPos > 0) {
    result.add(currentByte);
  }

  return EncodedResult(Uint8List.fromList(result), totalBits, frequencies);
}

Uint8List huffmanDecode(Uint8List encoded, HuffmanNode root, int bitCount) {
  var result = Uint8List(bitCount);

  var currentNode = root;
  int bitsProcessed = 0;
  int byteIndex = 0;
  int resultSize = 0;

  while (bitsProcessed < bitCount && byteIndex < encoded.length) {
    int byteVal = encoded[byteIndex++];

    for (int bitPos = 7; bitPos >= 0; bitPos--) {
      if (bitsProcessed >= bitCount) break;

      int bit = (byteVal >> bitPos) & 1;
      bitsProcessed++;

      currentNode = bit == 1 ? currentNode.right! : currentNode.left!;

      if (currentNode.isLeaf) {
        result[resultSize++] = currentNode.byteVal;
        currentNode = root;
      }
    }
  }

  if (resultSize < bitCount) {
    return Uint8List.sublistView(result, 0, resultSize);
  }

  return result;
}

class HuffEncode extends Benchmark {
  late int sizeVal;
  late Uint8List testData;
  late EncodedResult encoded;
  int resultVal = 0;

  HuffEncode() {
    sizeVal = Helper.configI64(benchmarkName, "size").toInt();
  }

  @override
  String get benchmarkName => 'Compress::HuffEncode';

  @override
  void prepare() {
    testData = generateTestData(sizeVal);
    resultVal = 0;
  }

  @override
  void runBenchmark(int iterationId) {
    var frequencies = List<int>.filled(256, 0);
    for (int byte in testData) {
      frequencies[byte]++;
    }

    var tree = buildHuffmanTree(frequencies);

    var codes = HuffmanCodes();
    buildHuffmanCodes(tree, 0, 0, codes);

    encoded = huffmanEncode(testData, codes, frequencies);
    resultVal += encoded.data.length;
  }

  @override
  int checksum() {
    return resultVal & 0xFFFFFFFF;
  }
}

class HuffDecode extends Benchmark {
  late int sizeVal;
  late Uint8List testData;
  late Uint8List decoded;
  late EncodedResult encoded;
  int resultVal = 0;

  HuffDecode() {
    sizeVal = Helper.configI64(benchmarkName, "size").toInt();
  }

  @override
  String get benchmarkName => 'Compress::HuffDecode';

  @override
  void prepare() {
    testData = generateTestData(sizeVal);

    var encoder = HuffEncode();
    encoder.sizeVal = sizeVal;
    encoder.prepare();
    encoder.runBenchmark(0);
    encoded = encoder.encoded;
    resultVal = 0;
  }

  @override
  void runBenchmark(int iterationId) {
    var tree = buildHuffmanTree(encoded.frequencies);
    decoded = huffmanDecode(encoded.data, tree, encoded.bitCount);
    resultVal += decoded.length;
  }

  @override
  int checksum() {
    int res = resultVal;
    if (decoded.length == testData.length) {
      bool equal = true;
      for (int i = 0; i < decoded.length; i++) {
        if (decoded[i] != testData[i]) {
          equal = false;
          break;
        }
      }
      if (equal) {
        res += 100000;
      }
    }
    return res & 0xFFFFFFFF;
  }
}

class ArithEncodedResult {
  final Uint8List data;
  final int bitCount;
  final List<int> frequencies;

  ArithEncodedResult(this.data, this.bitCount, this.frequencies);
}

class ArithFreqTable {
  int total = 0;
  List<int> low = List<int>.filled(256, 0);
  List<int> high = List<int>.filled(256, 0);

  ArithFreqTable(List<int> frequencies) {
    total = frequencies.reduce((a, b) => a + b);

    int cum = 0;
    for (int i = 0; i < 256; i++) {
      low[i] = cum;
      cum += frequencies[i];
      high[i] = cum;
    }
  }
}

class BitOutputStream {
  int buffer = 0;
  int bitPos = 0;
  List<int> bytes = [];
  int bitsWritten = 0;

  void writeBit(int bit) {
    buffer = (buffer << 1) | (bit & 1);
    bitPos++;
    bitsWritten++;

    if (bitPos == 8) {
      bytes.add(buffer);
      buffer = 0;
      bitPos = 0;
    }
  }

  Uint8List flush() {
    if (bitPos > 0) {
      buffer <<= (8 - bitPos);
      bytes.add(buffer);
    }
    return Uint8List.fromList(bytes);
  }
}

class ArithEncode extends Benchmark {
  ArithEncodedResult arithEncode(Uint8List data) {
    var frequencies = List<int>.filled(256, 0);
    for (int byte in data) frequencies[byte]++;

    var freqTable = ArithFreqTable(frequencies);

    int low = 0;
    int high = 0xFFFFFFFF;
    int pending = 0;
    var output = BitOutputStream();

    for (int byte in data) {
      int idx = byte;
      int range = high - low + 1;

      high = low + ((range * freqTable.high[idx]) ~/ freqTable.total) - 1;
      low = low + ((range * freqTable.low[idx]) ~/ freqTable.total);

      while (true) {
        if (high < 0x80000000) {
          output.writeBit(0);
          for (int i = 0; i < pending; i++) output.writeBit(1);
          pending = 0;
        } else if (low >= 0x80000000) {
          output.writeBit(1);
          for (int i = 0; i < pending; i++) output.writeBit(0);
          pending = 0;
          low -= 0x80000000;
          high -= 0x80000000;
        } else if (low >= 0x40000000 && high < 0xC0000000) {
          pending++;
          low -= 0x40000000;
          high -= 0x40000000;
        } else {
          break;
        }

        low <<= 1;
        high = (high << 1) | 1;
        high &= 0xFFFFFFFF;
      }
    }

    pending++;
    if (low < 0x40000000) {
      output.writeBit(0);
      for (int i = 0; i < pending; i++) output.writeBit(1);
    } else {
      output.writeBit(1);
      for (int i = 0; i < pending; i++) output.writeBit(0);
    }

    return ArithEncodedResult(output.flush(), output.bitsWritten, frequencies);
  }

  late int sizeVal;
  late Uint8List testData;
  late ArithEncodedResult encoded;
  int resultVal = 0;

  ArithEncode() {
    sizeVal = Helper.configI64(benchmarkName, 'size').toInt();
  }

  @override
  String get benchmarkName => 'Compress::ArithEncode';

  @override
  void prepare() {
    testData = generateTestData(sizeVal);
    resultVal = 0;
  }

  @override
  void runBenchmark(int iterationId) {
    encoded = arithEncode(testData);
    resultVal += encoded.data.length;
  }

  @override
  int checksum() => resultVal & 0xFFFFFFFF;
}

class BitInputStream {
  final Uint8List bytes;
  int bytePos = 0;
  int bitPos = 0;
  int currentByte;

  BitInputStream(this.bytes) : currentByte = bytes.isNotEmpty ? bytes[0] : 0;

  int readBit() {
    if (bitPos == 8) {
      bytePos++;
      bitPos = 0;
      currentByte = bytePos < bytes.length ? bytes[bytePos] : 0;
    }

    int bit = (currentByte >> (7 - bitPos)) & 1;
    bitPos++;
    return bit;
  }
}

class ArithDecode extends Benchmark {
  Uint8List arithDecode(ArithEncodedResult encoded) {
    var frequencies = encoded.frequencies;
    int total = frequencies.reduce((a, b) => a + b);
    int dataSize = total;

    var lowTable = List<int>.filled(256, 0);
    var highTable = List<int>.filled(256, 0);
    int cum = 0;
    for (int i = 0; i < 256; i++) {
      lowTable[i] = cum;
      cum += frequencies[i];
      highTable[i] = cum;
    }

    var result = Uint8List(dataSize);
    var input = BitInputStream(encoded.data);

    int value = 0;
    for (int i = 0; i < 32; i++) {
      value = (value << 1) | input.readBit();
    }

    int low = 0;
    int high = 0xFFFFFFFF;

    for (int j = 0; j < dataSize; j++) {
      int range = high - low + 1;
      int scaled = ((value - low + 1) * total - 1) ~/ range;

      int symbol = 0;
      while (symbol < 255 && highTable[symbol] <= scaled) {
        symbol++;
      }

      result[j] = symbol;

      high = low + ((range * highTable[symbol]) ~/ total) - 1;
      low = low + ((range * lowTable[symbol]) ~/ total);

      while (true) {
        if (high < 0x80000000) {
        } else if (low >= 0x80000000) {
          value -= 0x80000000;
          low -= 0x80000000;
          high -= 0x80000000;
        } else if (low >= 0x40000000 && high < 0xC0000000) {
          value -= 0x40000000;
          low -= 0x40000000;
          high -= 0x40000000;
        } else {
          break;
        }

        low <<= 1;
        high = (high << 1) | 1;
        value = (value << 1) | input.readBit();
      }
    }

    return result;
  }

  late int sizeVal;
  late Uint8List testData;
  late Uint8List decoded;
  late ArithEncodedResult encoded;
  int resultVal = 0;

  ArithDecode() {
    sizeVal = Helper.configI64(benchmarkName, 'size').toInt();
  }

  @override
  String get benchmarkName => 'Compress::ArithDecode';

  @override
  void prepare() {
    var encoder = ArithEncode();
    encoder.sizeVal = sizeVal;
    encoder.prepare();
    encoder.runBenchmark(0);
    testData = encoder.testData;
    encoded = encoder.encoded;
    resultVal = 0;
  }

  @override
  void runBenchmark(int iterationId) {
    decoded = arithDecode(encoded);
    resultVal += decoded.length;
  }

  @override
  int checksum() {
    int res = resultVal;
    if (listEquals(decoded, testData)) res += 100000;
    return res & 0xFFFFFFFF;
  }
}

class LZWResult {
  final Uint8List data;
  final int dictSize;

  LZWResult(this.data, this.dictSize);
}

class LZWEncode extends Benchmark {
  LZWResult lzwEncode(Uint8List input) {
    if (input.isEmpty) return LZWResult(Uint8List(0), 256);

    var dict = HashMap<String, int>();
    for (int i = 0; i < 256; i++) {
      dict[String.fromCharCode(i)] = i;
    }

    int nextCode = 256;
    var result = <int>[];

    String current = String.fromCharCode(input[0]);

    for (int i = 1; i < input.length; i++) {
      String nextChar = String.fromCharCode(input[i]);
      String newStr = current + nextChar;

      if (dict.containsKey(newStr)) {
        current = newStr;
      } else {
        int code = dict[current]!;
        result.add((code >> 8) & 0xFF);
        result.add(code & 0xFF);

        dict[newStr] = nextCode++;
        current = nextChar;
      }
    }

    int lastCode = dict[current]!;
    result.add((lastCode >> 8) & 0xFF);
    result.add(lastCode & 0xFF);

    return LZWResult(Uint8List.fromList(result), nextCode);
  }

  late int sizeVal;
  late Uint8List testData;
  late LZWResult encoded;
  int resultVal = 0;

  LZWEncode() {
    sizeVal = Helper.configI64(benchmarkName, 'size').toInt();
  }

  @override
  String get benchmarkName => 'Compress::LZWEncode';

  @override
  void prepare() {
    testData = generateTestData(sizeVal);
    resultVal = 0;
  }

  @override
  void runBenchmark(int iterationId) {
    encoded = lzwEncode(testData);
    resultVal += encoded.data.length;
  }

  @override
  int checksum() => resultVal & 0xFFFFFFFF;
}

class LZWDecode extends Benchmark {
  Uint8List lzwDecode(LZWResult encoded) {
    if (encoded.data.isEmpty) return Uint8List(0);

    var dict = <String>[];
    dict.length = 0;

    for (int i = 0; i < 256; i++) {
      dict.add(String.fromCharCode(i));
    }

    var result = BytesBuilder(copy: false);
    var data = encoded.data;
    int pos = 0;

    int high = data[pos];
    int low = data[pos + 1];
    int oldCode = (high << 8) | low;
    pos += 2;

    String oldStr = dict[oldCode];
    result.add(oldStr.codeUnits);

    int nextCode = 256;

    while (pos < data.length) {
      high = data[pos];
      low = data[pos + 1];
      int newCode = (high << 8) | low;
      pos += 2;

      String newStr;
      if (newCode < dict.length) {
        newStr = dict[newCode];
      } else if (newCode == nextCode) {
        newStr = oldStr + oldStr[0];
      } else {
        throw Exception("Error decode");
      }

      result.add(newStr.codeUnits);

      dict.add(oldStr + newStr[0]);
      nextCode++;

      oldStr = newStr;
    }

    return result.toBytes();
  }

  late int sizeVal;
  late Uint8List testData;
  late Uint8List decoded;
  late LZWResult encoded;
  int resultVal = 0;

  LZWDecode() {
    sizeVal = Helper.configI64(benchmarkName, 'size').toInt();
  }

  @override
  String get benchmarkName => 'Compress::LZWDecode';

  @override
  void prepare() {
    var encoder = LZWEncode();
    encoder.sizeVal = sizeVal;
    encoder.prepare();
    encoder.runBenchmark(0);
    testData = encoder.testData;
    encoded = encoder.encoded;
    resultVal = 0;
  }

  @override
  void runBenchmark(int iterationId) {
    decoded = lzwDecode(encoded);
    resultVal += decoded.length;
  }

  @override
  int checksum() {
    int res = resultVal;
    if (listEquals(decoded, testData)) res += 100000;
    return res & 0xFFFFFFFF;
  }
}

List<(String, String)> generatePairStrings(int n, int m) {
  var pairs = <(String, String)>[];
  var chars = 'abcdefghij';

  for (int i = 0; i < n; i++) {
    int len1 = Helper.nextInt(m) + 4;
    int len2 = Helper.nextInt(m) + 4;

    var str1 = StringBuffer();
    var str2 = StringBuffer();

    for (int j = 0; j < len1; j++) {
      str1.write(chars[Helper.nextInt(10)]);
    }
    for (int j = 0; j < len2; j++) {
      str2.write(chars[Helper.nextInt(10)]);
    }

    pairs.add((str1.toString(), str2.toString()));
  }

  return pairs;
}

class Jaro extends Benchmark {
  late int count;
  late int size;
  late List<(String, String)> pairs;
  int resultVal = 0;

  Jaro() {
    count = Helper.configI64(benchmarkName, 'count').toInt();
    size = Helper.configI64(benchmarkName, 'size').toInt();
  }

  @override
  String get benchmarkName => 'Distance::Jaro';

  @override
  void prepare() {
    pairs = generatePairStrings(count, size);
    resultVal = 0;
  }

  double jaro(String s1, String s2) {
    final bytes1 = s1.codeUnits;
    final bytes2 = s2.codeUnits;

    int len1 = bytes1.length;
    int len2 = bytes2.length;

    if (len1 == 0 || len2 == 0) return 0.0;

    int matchDist = (len1 > len2 ? len1 : len2) ~/ 2 - 1;
    if (matchDist < 0) matchDist = 0;

    var s1Matches = List<bool>.filled(len1, false);
    var s2Matches = List<bool>.filled(len2, false);

    int matches = 0;
    for (int i = 0; i < len1; i++) {
      int start = i > matchDist ? i - matchDist : 0;
      int end = (len2 - 1) < (i + matchDist) ? len2 - 1 : i + matchDist;

      for (int j = start; j <= end; j++) {
        if (!s2Matches[j] && bytes1[i] == bytes2[j]) {
          s1Matches[i] = true;
          s2Matches[j] = true;
          matches++;
          break;
        }
      }
    }

    if (matches == 0) return 0.0;

    int transpositions = 0;
    int k = 0;
    for (int i = 0; i < len1; i++) {
      if (s1Matches[i]) {
        while (k < len2 && !s2Matches[k]) {
          k++;
        }
        if (k < len2) {
          if (bytes1[i] != bytes2[k]) {
            transpositions++;
          }
          k++;
        }
      }
    }
    transpositions = transpositions ~/ 2;

    double m = matches.toDouble();
    return (m / len1 + m / len2 + (m - transpositions) / m) / 3.0;
  }

  @override
  void runBenchmark(int iterationId) {
    for (var pair in pairs) {
      resultVal =
          (resultVal + (jaro(pair.$1, pair.$2) * 1000).toInt()) & 0xFFFFFFFF;
    }
  }

  @override
  int checksum() {
    return resultVal;
  }
}

class NGram extends Benchmark {
  late int count;
  late int size;
  late List<(String, String)> pairs;
  int resultVal = 0;
  static const int N = 4;

  NGram() {
    count = Helper.configI64(benchmarkName, 'count').toInt();
    size = Helper.configI64(benchmarkName, 'size').toInt();
  }

  @override
  String get benchmarkName => 'Distance::NGram';

  @override
  void prepare() {
    pairs = generatePairStrings(count, size);
    resultVal = 0;
  }

  double ngram(String s1, String s2) {
    if (s1.length < N || s2.length < N) return 0.0;

    final bytes1 = s1.codeUnits;
    final bytes2 = s2.codeUnits;

    var grams1 = <int, int>{};

    for (int i = 0; i <= bytes1.length - N; i++) {
      int gram =
          (bytes1[i] << 24) |
          (bytes1[i + 1] << 16) |
          (bytes1[i + 2] << 8) |
          bytes1[i + 3];

      grams1[gram] = (grams1[gram] ?? 0) + 1;
    }

    var grams2 = <int, int>{};
    int intersection = 0;

    for (int i = 0; i <= bytes2.length - N; i++) {
      int gram =
          (bytes2[i] << 24) |
          (bytes2[i + 1] << 16) |
          (bytes2[i + 2] << 8) |
          bytes2[i + 3];

      grams2[gram] = (grams2[gram] ?? 0) + 1;

      var count1 = grams1[gram];
      if (count1 != null && grams2[gram]! <= count1) {
        intersection++;
      }
    }

    int total = grams1.length + grams2.length;
    return total > 0 ? intersection / total : 0.0;
  }

  @override
  void runBenchmark(int iterationId) {
    for (var pair in pairs) {
      resultVal =
          (resultVal + (ngram(pair.$1, pair.$2) * 1000).toInt()) & 0xFFFFFFFF;
    }
  }

  @override
  int checksum() {
    return resultVal;
  }
}

class Words extends Benchmark {
  late int words;
  late int wordLen;
  late String text;
  int checksumVal = 0;

  @override
  void prepare() {
    words = Helper.configI64(benchmarkName, "words").toInt();
    wordLen = Helper.configI64(benchmarkName, "word_len").toInt();

    const chars = 'abcdefghijklmnopqrstuvwxyz';
    final wordsList = <String>[];

    for (int i = 0; i < words; i++) {
      final len = Helper.nextInt(wordLen) + Helper.nextInt(3) + 3;
      final wordChars = List.generate(
        len,
        (_) => chars[Helper.nextInt(chars.length)],
      );
      wordsList.add(wordChars.join());
    }

    text = wordsList.join(' ');
  }

  @override
  void runBenchmark(int iterationId) {
    final frequencies = HashMap<String, int>();

    for (final word in text.split(' ')) {
      if (word.isEmpty) continue;
      frequencies[word] = (frequencies[word] ?? 0) + 1;
    }

    String maxWord = '';
    int maxCount = 0;

    frequencies.forEach((word, count) {
      if (count > maxCount) {
        maxCount = count;
        maxWord = word;
      }
    });

    final freqSize = frequencies.length;
    final wordChecksum = Helper.checksumString(maxWord);

    checksumVal =
        (checksumVal + maxCount + wordChecksum + freqSize) & 0xFFFFFFFF;
  }

  @override
  int checksum() {
    return checksumVal & 0xFFFFFFFF;
  }

  @override
  String get benchmarkName => 'Etc::Words';
}

bool listEquals(List? a, List? b) {
  if (a == null) return b == null;
  if (b == null || a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

void registerBenchmarks() {
  Benchmark.registerBenchmark('CLBG::Pidigits', () => Pidigits());
  Benchmark.registerBenchmark('Binarytrees::Obj', () => BinarytreesObj());
  Benchmark.registerBenchmark('Binarytrees::Arena', () => BinarytreesArena());
  Benchmark.registerBenchmark('Brainfuck::Array', () => BrainfuckArray());
  Benchmark.registerBenchmark(
    'Brainfuck::Recursion',
    () => BrainfuckRecursion(),
  );
  Benchmark.registerBenchmark('CLBG::Fannkuchredux', () => Fannkuchredux());
  Benchmark.registerBenchmark('CLBG::Fasta', () => Fasta());
  Benchmark.registerBenchmark('CLBG::Knuckeotide', () => Knuckeotide());
  Benchmark.registerBenchmark('CLBG::Mandelbrot', () => Mandelbrot());
  Benchmark.registerBenchmark('Matmul::Single', () => Matmul1T());
  Benchmark.registerBenchmark('Matmul::T4', () => Matmul4T());
  Benchmark.registerBenchmark('Matmul::T8', () => Matmul8T());
  Benchmark.registerBenchmark('Matmul::T16', () => Matmul16T());
  Benchmark.registerBenchmark('CLBG::Nbody', () => Nbody());
  Benchmark.registerBenchmark('CLBG::RegexDna', () => RegexDna());
  Benchmark.registerBenchmark('CLBG::Revcomp', () => Revcomp());
  Benchmark.registerBenchmark('CLBG::Spectralnorm', () => Spectralnorm());
  Benchmark.registerBenchmark('Base64::Encode', () => Base64Encode());
  Benchmark.registerBenchmark('Base64::Decode', () => Base64Decode());
  Benchmark.registerBenchmark('Json::Generate', () => JsonGenerate());
  Benchmark.registerBenchmark('Json::ParseDom', () => JsonParseDom());
  Benchmark.registerBenchmark('Json::ParseMapping', () => JsonParseMapping());
  Benchmark.registerBenchmark('Etc::Sieve', () => Sieve());
  Benchmark.registerBenchmark('Etc::TextRaytracer', () => TextRaytracer());
  Benchmark.registerBenchmark('Etc::NeuralNet', () => NeuralNet());
  Benchmark.registerBenchmark('Sort::Quick', () => SortQuick());
  Benchmark.registerBenchmark('Sort::Merge', () => SortMerge());
  Benchmark.registerBenchmark('Sort::Self', () => SortSelf());
  Benchmark.registerBenchmark('Graph::BFS', () => GraphPathBFS());
  Benchmark.registerBenchmark('Graph::DFS', () => GraphPathDFS());
  Benchmark.registerBenchmark('Graph::AStar', () => GraphPathAStar());
  Benchmark.registerBenchmark('Hash::SHA256', () => BufferHashSHA256());
  Benchmark.registerBenchmark('Hash::CRC32', () => BufferHashCRC32());
  Benchmark.registerBenchmark('Etc::CacheSimulation', () => CacheSimulation());
  Benchmark.registerBenchmark('Calculator::Ast', () => CalculatorAst());
  Benchmark.registerBenchmark(
    'Calculator::Interpreter',
    () => CalculatorInterpreter(),
  );
  Benchmark.registerBenchmark('Etc::GameOfLife', () => GameOfLife());
  Benchmark.registerBenchmark('Maze::Generator', () => MazeGenerator());
  Benchmark.registerBenchmark('Maze::BFS', () => MazeBFS());
  Benchmark.registerBenchmark('Maze::AStar', () => MazeAStar());
  Benchmark.registerBenchmark('Compress::BWTEncode', () => BWTEncode());
  Benchmark.registerBenchmark('Compress::BWTDecode', () => BWTDecode());
  Benchmark.registerBenchmark('Compress::HuffEncode', () => HuffEncode());
  Benchmark.registerBenchmark('Compress::HuffDecode', () => HuffDecode());
  Benchmark.registerBenchmark('Compress::ArithEncode', () => ArithEncode());
  Benchmark.registerBenchmark('Compress::ArithDecode', () => ArithDecode());
  Benchmark.registerBenchmark('Compress::LZWEncode', () => LZWEncode());
  Benchmark.registerBenchmark('Compress::LZWDecode', () => LZWDecode());
  Benchmark.registerBenchmark('Distance::Jaro', () => Jaro());
  Benchmark.registerBenchmark('Distance::NGram', () => NGram());
  Benchmark.registerBenchmark('Etc::Words', () => Words());
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

  final file = File('/tmp/recompile_marker');
  file.writeAsStringSync('RECOMPILE_MARKER_0');
}
