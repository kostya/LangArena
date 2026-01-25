import Foundation
class BrainfuckHashMap: BenchmarkProtocol {
    private var text: String
    private var res: Int64 = 0
    init() {
        let className = String(describing: type(of: self))
        // Берем текст программы из input (как в Kotlin)
        text = Helper.getInput(className)
    }
    // Brainfuck всегда запускается 1 раз (iterations игнорируется)
    func run() {
        res = Program(text: text).run()
    }
    var result: Int64 {
        return res
    }
    // В Kotlin Brainfuck не использует iterations, но property есть
    // Мы оверрайдим чтобы всегда возвращать 1
    var iterations: Int {
        return 1
    }
    // Вложенные классы как в Kotlin
    class Tape {
        private var tape: [Int]
        private var pos: Int
        init() {
            tape = [0]
            pos = 0
        }
        func get() -> Int {
            return tape[pos]
        }
        func inc() {
            tape[pos] += 1
        }
        func dec() {
            tape[pos] -= 1
        }
        func advance() {
            pos += 1
            if pos >= tape.count {
                tape.append(0)
            }
        }
        func devance() {
            if pos > 0 {
                pos -= 1
            }
        }
    }
    class Program {
        private var chars: [Character] = []
        private var bracketMap: [Int: Int] = [:]
        init(text: String) {
            var leftStack: [Int] = []
            var pc = 0
            for char in text {
                if "[]<>+-,.".contains(char) {
                    chars.append(char)
                    switch char {
                    case "[":
                        leftStack.append(pc)
                    case "]":
                        if !leftStack.isEmpty {
                            let left = leftStack.removeLast()
                            let right = pc
                            bracketMap[left] = right
                            bracketMap[right] = left
                        }
                    default:
                        break
                    }
                    pc += 1
                }
            }
            if ProcessInfo.processInfo.environment["DEBUG"] == "1" {
                print("DEBUG Brainfuck Program:")
                print("  Filtered chars: \(chars.count)")
                print("  Bracket pairs: \(bracketMap.count / 2)")
            }
        }
        func run() -> Int64 {
            var result: Int64 = 0
            let tape = Tape()
            var pc = 0
            while pc < chars.count {
                switch chars[pc] {
                case "+":
                    tape.inc()
                case "-":
                    tape.dec()
                case ">":
                    tape.advance()
                case "<":
                    tape.devance()
                case "[":
                    if tape.get() == 0 {
                        pc = bracketMap[pc] ?? pc
                    }
                case "]":
                    if tape.get() != 0 {
                        pc = bracketMap[pc] ?? pc
                    }
                case ".":
                    // ТОЧНО как в Kotlin: (result shl 2) + tape.get().toChar().code
                    let charCode = tape.get() % 256  // Ensure ASCII range
                    result = (result << 2) + Int64(charCode)
                default:
                    break
                }
                pc += 1
            }
            return result
        }
    }
}