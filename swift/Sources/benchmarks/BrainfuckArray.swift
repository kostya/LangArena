import Foundation

struct Tape {
  private var tape: ContiguousArray<UInt8>
  private var pos: Int

  init(initialSize: Int = 30000) {
    self.tape = ContiguousArray<UInt8>(repeating: 0, count: initialSize)
    self.pos = 0
  }

  mutating func get() -> UInt8 {
    return tape[pos]
  }

  mutating func inc() {
    tape[pos] = tape[pos] &+ 1
  }

  mutating func dec() {
    tape[pos] = tape[pos] &- 1
  }

  mutating func advance() {
    pos += 1
    if pos >= tape.count {
      tape.append(0)
    }
  }

  mutating func devance() {
    if pos > 0 {
      pos -= 1
    }
  }
}

extension UInt8 {
  static let plus = UInt8(ascii: "+")
  static let minus = UInt8(ascii: "-")
  static let left = UInt8(ascii: "<")
  static let right = UInt8(ascii: ">")
  static let open = UInt8(ascii: "[")
  static let close = UInt8(ascii: "]")
  static let output = UInt8(ascii: ".")
  static let input = UInt8(ascii: ",")
}

struct Program {
  private let commands: [UInt8]
  private let jumps: [Int]

  init?(text: String) {
    guard let commands = Self.parseCommands(text),
      let jumps = Self.buildJumpArray(commands)
    else {
      return nil
    }

    self.commands = commands
    self.jumps = jumps
  }

  private static func parseCommands(_ source: String) -> [UInt8]? {
    let validCommands: Set<UInt8> = [
      .plus, .minus, .left, .right,
      .open, .close, .output, .input,
    ]

    var commands: [UInt8] = []
    commands.reserveCapacity(source.utf8.count)

    for ascii in source.utf8 {
      if validCommands.contains(ascii) {
        commands.append(ascii)
      }
    }

    return commands.isEmpty ? nil : commands
  }

  private static func buildJumpArray(_ commands: [UInt8]) -> [Int]? {
    var jumps = [Int](repeating: 0, count: commands.count)
    var stack: [Int] = []

    for (i, cmd) in commands.enumerated() {
      if cmd == .open {
        stack.append(i)
      } else if cmd == .close {
        guard let start = stack.popLast() else {
          return nil
        }
        jumps[start] = i
        jumps[i] = start
      }
    }

    return stack.isEmpty ? jumps : nil
  }

  func run() -> UInt32? {
    var tape = Tape()
    var pc = 0
    var result: UInt32 = 0

    while pc < commands.count {
      let cmd = commands[pc]

      switch cmd {
      case .plus:
        tape.inc()

      case .minus:
        tape.dec()

      case .right:
        tape.advance()

      case .left:
        tape.devance()

      case .open:
        if tape.get() == 0 {
          pc = jumps[pc]
        }

      case .close:
        if tape.get() != 0 {
          pc = jumps[pc]
        }

      case .output:
        result = result &<< 2
        result = result &+ UInt32(tape.get())

      case .input:
        break

      default:
        break
      }

      pc += 1
    }

    return result
  }
}

class BrainfuckArray: BenchmarkProtocol {
  private var programText: String
  private var warmupText: String
  private var resultVal: UInt32 = 0

  init() {
    programText = ""
    warmupText = ""
  }

  func prepare() {
    programText = configValue("program") ?? ""
    warmupText = configValue("warmup_program") ?? programText
  }

  func run(iterationId: Int) {
    if let result = runProgram(programText) {
      resultVal &+= result
    }
  }

  func warmup() {
    let prepareIters = warmupIterations
    for _ in 0..<prepareIters {
      _ = runProgram(warmupText)
    }
  }

  var checksum: UInt32 {
    return resultVal
  }

  private func runProgram(_ source: String) -> UInt32? {
    guard let program = Program(text: source) else {
      return nil
    }
    return program.run()
  }
  func name() -> String {
    return "Brainfuck::Array"
  }
}
