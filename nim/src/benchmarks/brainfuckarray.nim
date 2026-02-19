import std/[strutils, sequtils]
import ../benchmark
import ../helper

type
  Tape = object
    tape: seq[uint8]
    pos: int

  Program = object
    commands: seq[uint8]
    jumps: seq[int]

proc newTape(): Tape =
  result = Tape(tape: newSeq[uint8](30000), pos: 0)

proc get(self: Tape): uint8 = self.tape[self.pos]
proc inc(self: var Tape) = self.tape[self.pos].inc
proc dec(self: var Tape) = self.tape[self.pos].dec

proc advance(self: var Tape) =
  self.pos.inc
  if self.pos >= self.tape.len:
    self.tape.add(0)

proc devance(self: var Tape) =
  if self.pos > 0:
    self.pos.dec

proc newProgram(text: string): Program =
  var commands: seq[uint8] = @[]
  for c in text:
    if c in "[]<>+-.,":
      commands.add(c.uint8)

  var jumps = newSeq[int](commands.len)
  var stack: seq[int] = @[]

  for i, cmd in commands:
    if cmd == '['.uint8:
      stack.add(i)
    elif cmd == ']'.uint8 and stack.len > 0:
      let start = stack.pop()
      jumps[start] = i
      jumps[i] = start

  Program(commands: commands, jumps: jumps)

proc run(self: Program): int64 =
  var tape = newTape()
  var pc = 0
  result = 0

  while pc < self.commands.len:
    let cmd = self.commands[pc]
    if cmd == '+'.uint8:
      tape.inc()
    elif cmd == '-'.uint8:
      tape.dec()
    elif cmd == '>'.uint8:
      tape.advance()
    elif cmd == '<'.uint8:
      tape.devance()
    elif cmd == '['.uint8:
      if tape.get == 0:
        pc = self.jumps[pc]
        continue
    elif cmd == ']'.uint8:
      if tape.get != 0:
        pc = self.jumps[pc]
        continue
    elif cmd == '.'.uint8:
      result = (result shl 2) + tape.get.int64
    pc.inc

type
  BrainfuckArray* = ref object of Benchmark
    programText: string
    warmupText: string
    resultVal: uint32

proc newBrainfuckArray(): Benchmark =
  BrainfuckArray()

method name(self: BrainfuckArray): string = "BrainfuckArray"

method prepare(self: BrainfuckArray) =
  self.programText = config_s(self.name, "program")
  self.warmupText = config_s(self.name, "warmup_program")
  self.resultVal = 0

proc runProgram(text: string): int64 =
  let program = newProgram(text)
  program.run()

method warmup(self: BrainfuckArray) =
  let prepare_iters = self.warmup_iterations
  for _ in 0..<prepare_iters:
    discard runProgram(self.warmupText)

method run(self: BrainfuckArray, iteration_id: int) =
  let run_result = runProgram(self.programText)
  self.resultVal += run_result.uint32

method checksum(self: BrainfuckArray): uint32 =
  self.resultVal

registerBenchmark("BrainfuckArray", newBrainfuckArray)
