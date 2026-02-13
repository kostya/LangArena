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
        case inc      
        case dec      
        case next     
        case prev     
        case print    
        case loop([Op]) 
    }

    struct Tape {  
        private var tape: [UInt8]  
        private var pos: Int

        init() {
            tape = [UInt8](repeating: 0, count: 30000)
            pos = 0
        }

        mutating func get() -> UInt8 {  
            return tape[pos]
        }

        mutating func inc() {
            tape[pos] &+= 1
        }

        mutating func dec() {
            tape[pos] &-= 1
        }

        mutating func next() {
            pos += 1
            if pos >= tape.count {
                tape.append(0)
            }
        }

        mutating func prev() {
            if pos > 0 {
                pos -= 1
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
            var tape = Tape()  
            run(ops, &tape)    
        }

        private func run(_ program: [Op], _ tape: inout Tape) {
            for op in program {
                switch op {
                case .inc:
                    tape.inc()
                case .dec:
                    tape.dec()
                case .next:
                    tape.next()
                case .prev:
                    tape.prev()
                case .print:
                    resultVal = (resultVal << 2) + Int64(tape.get())
                case .loop(let innerOps):
                    while tape.get() != 0 {
                        run(innerOps, &tape)
                    }
                }
            }
        }

        private static func parse(_ iterator: inout String.Iterator) -> [Op] {
            var result: [Op] = []
            while let char = iterator.next() {
                let op: Op?
                switch char {
                case "+":
                    op = .inc
                case "-":
                    op = .dec
                case ">":
                    op = .next
                case "<":
                    op = .prev
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