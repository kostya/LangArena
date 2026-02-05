import std/[tables, math, strutils]
import ../benchmark
import ../helper
import calculator_common
import calculatorast

type
  Interpreter = object
    variables: Table[string, int64]

  CalculatorInterpreter* = ref object of Benchmark
    n: int64
    resultVal: uint32
    ast: seq[Node]

proc newCalculatorInterpreter(): Benchmark =
  CalculatorInterpreter()

method name(self: CalculatorInterpreter): string = "CalculatorInterpreter"

proc simpleDiv(a, b: int64): int64 =
  if b == 0:
    return 0
  if (a >= 0 and b > 0) or (a < 0 and b < 0):
    result = a div b
  else:
    result = -(abs(a) div abs(b))

proc simpleMod(a, b: int64): int64 =
  if b == 0:
    return 0
  return a - simpleDiv(a, b) * b

{.push overflowChecks: off.}
proc evaluate(interpreter: var Interpreter, node: Node): int64 =
  case node.kind:
  of nkNumber:
    node.numberVal
  of nkVariable:
    interpreter.variables.getOrDefault(node.varName, 0)
  of nkBinaryOp:
    let left = interpreter.evaluate(node.left)
    let right = interpreter.evaluate(node.right)

    case node.op:
    of '+': left + right
    of '-': left - right
    of '*': left * right
    of '/': simpleDiv(left, right)
    of '%': simpleMod(left, right)
    else: 0
  of nkAssignment:
    let value = interpreter.evaluate(node.assignExpr)
    interpreter.variables[node.assignVar] = value
    value
{.pop.}

proc run(interpreter: var Interpreter, expressions: seq[Node]): int64 =
  var resultVal: int64 = 0
  for expr in expressions:
    resultVal = interpreter.evaluate(expr)
  resultVal

method prepare(self: CalculatorInterpreter) =
  self.n = config_i64("CalculatorInterpreter", "operations")

  let text = generateRandomProgram(self.n)

  var parser = newParser(text)
  self.ast = parser.parse()

  self.resultVal = 0

method run(self: CalculatorInterpreter, iteration_id: int) =
  var interpreter = Interpreter(variables: initTable[string, int64]())
  let result = interpreter.run(self.ast)

  self.resultVal = self.resultVal + uint32(result)

method checksum(self: CalculatorInterpreter): uint32 =
  self.resultVal

registerBenchmark("CalculatorInterpreter", newCalculatorInterpreter)