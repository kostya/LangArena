import Foundation
final class BrainfuckRecursion: BenchmarkProtocol {
    private let text: String
    private var _result: Int64 = 0
    init() {
        let className = String(describing: type(of: self))
        text = Helper.getInput(className)
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
        var result: Int64 = 0
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
                    result = (result << 2) + Int64(tape.get())
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
    func run() {
        let program = Program(text)
        program.run()
        _result = program.result
    }
    var result: Int64 {
        return _result
    }
    func prepare() {}
}