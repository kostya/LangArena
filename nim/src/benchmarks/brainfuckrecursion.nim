import std/[strutils, sequtils, strformat, algorithm]
import ../benchmark
import ../helper  

type
  OpInc = object
    val: int32

  OpMove = object
    val: int32

  OpPrint = object

  OpLoop = object
    ops: seq[Op]

  Op = object
    case kind: range[0..3]
    of 0: incOp: OpInc
    of 1: moveOp: OpMove
    of 2: printOp: OpPrint
    of 3: loopOp: OpLoop

  Tape = object
    tape: seq[uint8]
    pos: int

  Program = object
    ops: seq[Op]
    resultVal: int64

proc newTape(): Tape =
  result = Tape(tape: newSeq[uint8](1024), pos: 0)

proc get(self: var Tape): uint8 = self.tape[self.pos]

proc inc(self: var Tape, x: int32) =
  self.tape[self.pos] = (self.tape[self.pos].int32 + x).uint8

proc move(self: var Tape, x: int32) =
  if x >= 0:
    self.pos += x.int
    if self.pos >= self.tape.len:
      let newSize = max(self.tape.len * 2, self.pos + 1)
      self.tape.setLen(newSize)
  else:
    let moveLeft = -x
    if moveLeft.int > self.pos:
      let needed = moveLeft.int - self.pos
      var newTape = newSeq[uint8](self.tape.len + needed)
      for i in 0..<self.tape.len:
        newTape[i + needed] = self.tape[i]
      self.tape = newTape
      self.pos = needed
    else:
      self.pos -= moveLeft.int

proc parse(it: var int, code: string): seq[Op]

proc parseOp(it: var int, code: string): Op =
  let c = code[it]
  inc it

  case c
  of '+':
    result = Op(kind: 0, incOp: OpInc(val: 1))
  of '-':
    result = Op(kind: 0, incOp: OpInc(val: -1))
  of '>':
    result = Op(kind: 1, moveOp: OpMove(val: 1))
  of '<':
    result = Op(kind: 1, moveOp: OpMove(val: -1))
  of '.':
    result = Op(kind: 2, printOp: OpPrint())
  of '[':
    let loopOps = parse(it, code)
    result = Op(kind: 3, loopOp: OpLoop(ops: loopOps))
  of ']':
    result = Op(kind: 3, loopOp: OpLoop(ops: @[]))  
  else:
    result = Op(kind: 2, printOp: OpPrint())  

proc parse(it: var int, code: string): seq[Op] =
  var res: seq[Op]
  while it < code.len:
    let op = parseOp(it, code)
    if op.kind == 3 and op.loopOp.ops.len == 0:  
      return res
    res.add(op)
  return res

proc newProgram(code: string): Program =
  var it = 0
  let ops = parse(it, code)
  result = Program(ops: ops, resultVal: 0)

proc runOps(program: var Program, ops: seq[Op], tape: var Tape)

proc executeOp(program: var Program, op: Op, tape: var Tape)

proc executeLoop(program: var Program, loop: OpLoop, tape: var Tape) =
  while tape.get != 0:
    for innerOp in loop.ops:
      executeOp(program, innerOp, tape)

proc executeOp(program: var Program, op: Op, tape: var Tape) =
  case op.kind
  of 0:  
    tape.inc(op.incOp.val)
  of 1:  
    tape.move(op.moveOp.val)
  of 2:  
    program.resultVal = (program.resultVal shl 2) + tape.get.int64
  of 3:  
    executeLoop(program, op.loopOp, tape)

proc runOps(program: var Program, ops: seq[Op], tape: var Tape) =
  for op in ops:
    executeOp(program, op, tape)

proc run(self: var Program): int64 =
  var tape = newTape()
  runOps(self, self.ops, tape)
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