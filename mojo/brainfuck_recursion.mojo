from helper import Helper
from benchmark import Benchmark, Config

comptime BF_INC = 0
comptime BF_DEC = 1
comptime BF_PREV = 2
comptime BF_NEXT = 3
comptime BF_PRINT = 4
comptime BF_LOOP = 5


struct _BFOp(Copyable):
    var kind: Int
    var loop_ops: List[_BFOp]

    def __init__(out self, kind: Int):
        self.kind = kind
        self.loop_ops = List[_BFOp]()

    def __init__(out self, kind: Int, var loop_ops: List[_BFOp]):
        self.kind = kind
        self.loop_ops = loop_ops^

    def __deinit__(deinit self):
        pass


struct _BFTape:
    var pos: Int
    var tape: List[UInt8]

    def __init__(out self):
        self.pos = 0
        self.tape = [0]

    def get(self) -> UInt8:
        return self.tape[self.pos]

    def inc(mut self):
        ref cell = self.tape[self.pos]
        cell = (cell + 1) & 0xFF

    def dec(mut self):
        ref cell = self.tape[self.pos]
        cell = (cell - 1) & 0xFF

    def prev(mut self):
        if self.pos > 0:
            self.pos -= 1

    def next(mut self):
        self.pos += 1
        if self.pos >= len(self.tape):
            self.tape.append(0)


struct _BFProgram:
    var ops: List[_BFOp]

    def __init__(out self, code: String):
        self.ops = Self._parse(code)

    @staticmethod
    def _parse(code: String) -> List[_BFOp]:
        var pos = 0
        return _BFProgram._parse_ops(code.as_bytes(), pos)

    @staticmethod
    def _parse_ops(chars: Span[Byte, _], mut pos: Int) -> List[_BFOp]:
        var buf = List[_BFOp]()
        while pos < len(chars):
            var byte = chars[pos]
            pos += 1

            if byte == 45:
                buf.append(_BFOp(BF_DEC))
            elif byte == 43:
                buf.append(_BFOp(BF_INC))
            elif byte == 60:
                buf.append(_BFOp(BF_PREV))
            elif byte == 62:
                buf.append(_BFOp(BF_NEXT))
            elif byte == 46:
                buf.append(_BFOp(BF_PRINT))
            elif byte == 91:
                var inner = _BFProgram._parse_ops(chars, pos)
                buf.append(_BFOp(BF_LOOP, inner^))
            elif byte == 93:
                break
        return buf^

    def run(self) -> Int:
        var tape = _BFTape()
        var result: Int = 0
        Self._execute(self.ops, tape, result)
        return result

    @staticmethod
    def _execute(ops: List[_BFOp], mut tape: _BFTape, mut result: Int):
        for op in ops:
            if op.kind == BF_DEC:
                tape.dec()
            elif op.kind == BF_INC:
                tape.inc()
            elif op.kind == BF_PREV:
                tape.prev()
            elif op.kind == BF_NEXT:
                tape.next()
            elif op.kind == BF_PRINT:
                result = (result << 2) + Int(tape.get())
            elif op.kind == BF_LOOP:
                while tape.get() != 0:
                    _BFProgram._execute(op.loop_ops, tape, result)


struct BrainfuckRecursion(Benchmark):
    var program_text: String
    var warmup_text: String
    var result_val: UInt32

    def __init__(out self, config: Config) raises:
        self.program_text = config.get_s("Brainfuck::Recursion", "program")
        self.warmup_text = config.get_s(
            "Brainfuck::Recursion", "warmup_program"
        )
        self.result_val = 0

    def class_name(self) -> String:
        return "Brainfuck::Recursion"

    def run(mut self, iteration_id: Int, mut helper: Helper) raises:
        var result = self._run(self.program_text)
        self.result_val = self.result_val + UInt32(result)

    def warmup(mut self, warmup_iters: Int, mut helper: Helper) raises:
        for _ in range(warmup_iters):
            _ = self._run(self.warmup_text)

    def checksum(self) -> UInt32:
        return self.result_val

    def _run(self, text: String) -> Int:
        return _BFProgram(text).run()
