import Foundation

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

        guard let commands = parseCommands(source) else {
            return nil
        }

        guard let jumps = buildJumpArray(commands) else {
            return nil
        }

        return interpret(commands, jumps)
    }

    private func parseCommands(_ source: String) -> [UInt8]? {

        let validCommands: Set<UInt8> = [43, 45, 60, 62, 91, 93, 46, 44]

        var commands: [UInt8] = []
        commands.reserveCapacity(source.utf8.count)

        for ascii in source.utf8 {
            if validCommands.contains(ascii) {
                commands.append(ascii)
            }
        }

        return commands.isEmpty ? nil : commands
    }

    private func buildJumpArray(_ commands: [UInt8]) -> [Int]? {
        var jumps = [Int](repeating: 0, count: commands.count)
        var stack: [Int] = []

        for (i, cmd) in commands.enumerated() {
            if cmd == 91 { 
                stack.append(i)
            } else if cmd == 93 { 
                guard let start = stack.popLast() else {
                    return nil 
                }
                jumps[start] = i
                jumps[i] = start
            }
        }

        return stack.isEmpty ? jumps : nil
    }

    private func interpret(_ commands: [UInt8], _ jumps: [Int]) -> UInt32? {

        var tape = [UInt8](repeating: 0, count: 30000)
        var tapePtr = 0
        var pc = 0
        var result: UInt32 = 0

        while pc < commands.count {
            let cmd = commands[pc]

            switch cmd {
            case 43: 
                tape[tapePtr] = tape[tapePtr] &+ 1

            case 45: 
                tape[tapePtr] = tape[tapePtr] &- 1

            case 62: 
                tapePtr += 1
                if tapePtr >= tape.count {
                    tape.append(0)
                }

            case 60: 
                if tapePtr > 0 {
                    tapePtr -= 1
                }

            case 91: 
                if tape[tapePtr] == 0 {

                    guard jumps.indices.contains(pc) else { return nil }
                    pc = jumps[pc]
                }

            case 93: 
                if tape[tapePtr] != 0 {

                    guard jumps.indices.contains(pc) else { return nil }
                    pc = jumps[pc]
                }

            case 46: 

                result = result &<< 2
                result = result &+ UInt32(tape[tapePtr])

            case 44: 
                break

            default:

                break
            }

            pc += 1
        }

        return result
    }
}