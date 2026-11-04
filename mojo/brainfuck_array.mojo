from helper import Helper
from benchmark import Benchmark, Config

comptime CHAR_PLUS = UInt8(ord("+"))
comptime CHAR_MINUS = UInt8(ord("-"))
comptime CHAR_LESS = UInt8(ord("<"))
comptime CHAR_GREATER = UInt8(ord(">"))
comptime CHAR_LEFT_BRACKET = UInt8(ord("["))
comptime CHAR_RIGHT_BRACKET = UInt8(ord("]"))
comptime CHAR_DOT = UInt8(ord("."))
comptime CHAR_COMMA = UInt8(ord(","))


struct _Tape:
    var tape: List[UInt8]
    var pos: Int

    def __init__(out self):
        self.tape = List[UInt8](length=30000, fill=0)
        self.pos = 0

    def get(self) -> UInt8:
        return self.tape[self.pos]

    def inc(mut self):
        self.tape[self.pos] = (self.tape[self.pos] + 1) & 0xFF

    def dec(mut self):
        self.tape[self.pos] = (self.tape[self.pos] - 1) & 0xFF

    def advance(mut self):
        self.pos += 1
        if self.pos >= len(self.tape):
            self.tape.append(0)

    def devance(mut self):
        if self.pos > 0:
            self.pos -= 1


struct BrainfuckArray(Benchmark):
    var program_text: String
    var warmup_text: String
    var result_val: UInt32

    def __init__(out self, config: Config) raises:
        self.program_text = config.get_s("Brainfuck::Array", "program")
        self.warmup_text = config.get_s("Brainfuck::Array", "warmup_program")
        self.result_val = 0

    def class_name(self) -> String:
        return "Brainfuck::Array"

    def run(mut self, iteration_id: Int, mut helper: Helper) raises:
        var result = self._run_program(self.program_text)
        self.result_val = self.result_val + result

    def warmup(mut self, warmup_iters: Int, mut helper: Helper) raises:
        for _ in range(warmup_iters):
            _ = self._run_program(self.warmup_text)

    def checksum(self) -> UInt32:
        return self.result_val

    def _run_program(self, source: String) -> UInt32:
        var commands = Self._parse_commands(source)
        var jumps = Self._build_jump_array(commands)
        return Self._execute(commands^, jumps^)

    @staticmethod
    def _parse_commands(source: String) -> List[UInt8]:
        return [
            b
            for b in source.as_bytes()
            if b == CHAR_PLUS
            or b == CHAR_MINUS
            or b == CHAR_LESS
            or b == CHAR_GREATER
            or b == CHAR_LEFT_BRACKET
            or b == CHAR_RIGHT_BRACKET
            or b == CHAR_DOT
            or b == CHAR_COMMA
        ]

    @staticmethod
    def _build_jump_array(commands: List[UInt8]) -> List[Int]:
        var jumps = List[Int](length=len(commands), fill=0)
        var stack = List[Int]()

        for i in range(len(commands)):
            var cmd = commands[i]
            if cmd == CHAR_LEFT_BRACKET:
                stack.append(i)
            elif cmd == CHAR_RIGHT_BRACKET:
                if len(stack) == 0:
                    return List[Int]()
                var start = stack.pop()
                jumps[start] = i
                jumps[i] = start

        if len(stack) != 0:
            return List[Int]()
        return jumps^

    @staticmethod
    def _execute(var commands: List[UInt8], var jumps: List[Int]) -> UInt32:
        var tape = _Tape()
        var pc: Int = 0
        var result: UInt32 = 0

        while pc < len(commands):
            var cmd = commands[pc]

            if cmd == CHAR_PLUS:
                tape.inc()
            elif cmd == CHAR_MINUS:
                tape.dec()
            elif cmd == CHAR_GREATER:
                tape.advance()
            elif cmd == CHAR_LESS:
                tape.devance()
            elif cmd == CHAR_LEFT_BRACKET:
                if tape.get() == 0:
                    pc = jumps[pc]
            elif cmd == CHAR_RIGHT_BRACKET:
                if tape.get() != 0:
                    pc = jumps[pc]
            elif cmd == CHAR_DOT:
                result = (result << 2) + UInt32(tape.get())

            pc += 1

        return result
