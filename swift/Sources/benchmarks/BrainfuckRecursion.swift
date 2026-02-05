import Foundation

final class BrainfuckRecursion: BenchmarkProtocol {
    private var text: String
    private var warmupProgram: String
    private var resultVal: UInt32 = 0

    init() {
        text = ""
        warmupProgram = ""
    }

    enum Op {
        case inc(Int)
        case move(Int)
        case print
        case loop([Op])
    }

    class Tape {
        private var tape: [UInt8]
        private var pos: Int

        init() {
            tape = [0]
            pos = 0
        }

        func get() -> UInt8 {
            return tape[pos]
        }

        func inc(_ x: Int) {
            let newValue = Int(tape[pos]) + x
            tape[pos] = UInt8(newValue & 255)
        }

        func move(_ x: Int) {
            pos += x
            while pos >= tape.count {
                tape.append(0)
            }
        }
    }

    class Program {
        private let ops: [Op]
        var resultVal: Int64 = 0

        init(_ code: String) {
            var iterator = code.makeIterator()
            ops = Self.parse(&iterator)
        }

        func run() {
            let tape = Tape()
            run(ops, tape)
        }

        private func run(_ program: [Op], _ tape: Tape) {
            for op in program {
                switch op {
                case .inc(let value):
                    tape.inc(value)
                case .move(let value):
                    tape.move(value)
                case .loop(let innerOps):
                    while tape.get() != 0 {
                        run(innerOps, tape)
                    }
                case .print:
                    resultVal = (resultVal << 2) + Int64(tape.get())
                }
            }
        }

        private static func parse(_ iterator: inout String.Iterator) -> [Op] {
            var result: [Op] = []
            while let char = iterator.next() {
                let op: Op?
                switch char {
                case "+":
                    op = .inc(1)
                case "-":
                    op = .inc(-1)
                case ">":
                    op = .move(1)
                case "<":
                    op = .move(-1)
                case ".":
                    op = .print
                case "[":
                    op = .loop(parse(&iterator))
                case "]":
                    return result
                default:
                    op = nil
                }
                if let op = op {
                    result.append(op)
                }
            }
            return result
        }
    }

    private func runProgram(_ programText: String) -> Int64 {
        let program = Program(programText)
        program.run()
        return program.resultVal
    }

    func warmup() {
        let prepareIters = warmupIterations
        for i in 0..<prepareIters {
            _ = runProgram(warmupProgram)
        }
    }

    func run(iterationId: Int) {
        let res = runProgram(text)
        let res32 = UInt32(truncatingIfNeeded: res)
        resultVal &+= res32
    }

    var checksum: UInt32 {
        return resultVal
    }

    func prepare() {
        text = configValue("program") ?? ""
        warmupProgram = configValue("warmup_program") ?? text        
    }
}