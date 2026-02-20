import std/[strutils, sequtils, strformat, algorithm]
import ../benchmark
import ../helper

type
  OpInc = object
  OpDec = object
  OpRight = object
  OpLeft = object
  OpPrint = object
  OpLoop = object
    ops: seq[Op]

  Op = object
    case kind: range[0..5]
    of 0: incOp: OpInc
    of 1: decOp: OpDec
    of 2: rightOp: OpRight
    of 3: leftOp: OpLeft
    of 4: printOp: OpPrint
    of 5: loopOp: OpLoop

  Tape = object
    tape: seq[uint8]
    pos: int

  Program = object
    ops: seq[Op]
    resultVal: int64

proc newTape(initialSize: int = 30000): Tape =
  result = Tape(tape: newSeq[uint8](initialSize), pos: 0)

proc get(self: var Tape): uint8 = self.tape[self.pos]

proc inc(self: var Tape) =
  self.tape[self.pos] += 1

proc dec(self: var Tape) =
  self.tape[self.pos] -= 1

proc right(self: var Tape) =
  self.pos += 1
  if self.pos >= self.tape.len:
    self.tape.add(0)

proc left(self: var Tape) =
  if self.pos > 0:
    self.pos -= 1

proc parse(it: var int, code: string): seq[Op]

proc parseOp(it: var int, code: string): Op =
  let c = code[it]
  inc it

  case c
  of '+':
    result = Op(kind: 0, incOp: OpInc())
  of '-':
    result = Op(kind: 1, decOp: OpDec())
  of '>':
    result = Op(kind: 2, rightOp: OpRight())
  of '<':
    result = Op(kind: 3, leftOp: OpLeft())
  of '.':
    result = Op(kind: 4, printOp: OpPrint())
  of '[':
    let loopOps = parse(it, code)
    result = Op(kind: 5, loopOp: OpLoop(ops: loopOps))
  of ']':
    return Op(kind: 5, loopOp: OpLoop(ops: @[]))
  else:
    result = Op(kind: 4, printOp: OpPrint())

proc parse(it: var int, code: string): seq[Op] =
  var res: seq[Op]
  while it < code.len:
    let op = parseOp(it, code)
    if op.kind == 5 and op.loopOp.ops.len == 0:
      return res
    res.add(op)
  return res

proc newProgram(code: string): Program =
  var it = 0
  let ops = parse(it, code)
  result = Program(ops: ops, resultVal: 0)

proc executeOp(program: var Program, op: Op, tape: var Tape)

proc executeLoop(program: var Program, loop: OpLoop, tape: var Tape) =
  while tape.get != 0:
    for innerOp in loop.ops:
      executeOp(program, innerOp, tape)

proc executeOp(program: var Program, op: Op, tape: var Tape) =
  case op.kind
  of 0:
    tape.inc()
  of 1:
    tape.dec()
  of 2:
    tape.right()
  of 3:
    tape.left()
  of 4:
    program.resultVal = (program.resultVal shl 2) + tape.get().int64
  of 5:
    executeLoop(program, op.loopOp, tape)

proc run(self: var Program): int64 =
  var tape = newTape()
  for op in self.ops:
    executeOp(self, op, tape)
  result = self.resultVal

type
  BrainfuckRecursion* = ref object of Benchmark
    text: string
    resultVal: uint32

proc newBrainfuckRecursion(): Benchmark =
  BrainfuckRecursion()

method name(self: BrainfuckRecursion): string = "BrainfuckRecursion"

method prepare(self: BrainfuckRecursion) =
  self.text = config_s(self.name, "program")
  self.resultVal = 0

proc runProgram(text: string): int64 =
  var program = newProgram(text)
  program.run()

method warmup(self: BrainfuckRecursion) =
  let prepare_iters = self.warmup_iterations
  let warmup_program = config_s(self.name, "warmup_program")
  for i in 0..<prepare_iters:
    discard runProgram(warmup_program)

method run(self: BrainfuckRecursion, iteration_id: int) =
  let run_result = runProgram(self.text)
  self.resultVal = self.resultVal + run_result.uint32

method checksum(self: BrainfuckRecursion): uint32 =
  self.resultVal

registerBenchmark("BrainfuckRecursion", newBrainfuckRecursion)
