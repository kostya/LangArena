import std/[strutils, strformat, parseutils, hashes, tables]
import ../benchmark
import ../helper
import calculator_common

type
  Parser = object
    input: string
    pos: int
    currentChar: char
    chars: seq[char]
    expressions: seq[Node]

  CalculatorAst* = ref object of Benchmark
    n*: int64
    resultVal*: uint32
    expressions*: seq[Node]
    text*: string

proc newParser*(input: string): Parser =
  result = Parser(
    input: input,
    pos: 0,
    chars: newSeq[char](),
    expressions: @[]
  )
  for c in input:
    result.chars.add(c)
  if result.chars.len > 0:
    result.currentChar = result.chars[0]
  else:
    result.currentChar = '\0'

proc advance(p: var Parser) =
  inc p.pos
  if p.pos >= p.chars.len:
    p.currentChar = '\0'
  else:
    p.currentChar = p.chars[p.pos]

proc skipWhitespace(p: var Parser) =
  while p.currentChar != '\0' and p.currentChar in {' ', '\t', '\n', '\r'}:
    p.advance()

proc parseNumber(p: var Parser): Node

proc parseVariable(p: var Parser): Node

proc parseFactor(p: var Parser): Node

proc parseTerm(p: var Parser): Node

proc parseExpression(p: var Parser): Node

proc parseNumber(p: var Parser): Node =
  var v: int64 = 0
  while p.currentChar != '\0' and p.currentChar in '0'..'9':
    v = v * 10 + (int(p.currentChar) - int('0'))
    p.advance()
  newNodeNumber(v)

proc parseVariable(p: var Parser): Node =
  let startPos = p.pos

  while p.currentChar != '\0' and (
    (p.currentChar in 'a'..'z') or 
    (p.currentChar in 'A'..'Z') or 
    (p.currentChar in '0'..'9')):
    p.advance()

  let varName = p.input.substr(startPos, p.pos - 1)

  p.skipWhitespace()
  if p.currentChar == '=':
    p.advance()
    let expr = p.parseExpression()
    return newNodeAssignment(varName, expr)

  newNodeVariable(varName)

proc parseFactor(p: var Parser): Node =
  p.skipWhitespace()
  if p.currentChar == '\0':
    return newNodeNumber(0)

  if p.currentChar in '0'..'9':
    return p.parseNumber()

  if (p.currentChar in 'a'..'z') or (p.currentChar in 'A'..'Z'):
    return p.parseVariable()

  if p.currentChar == '(':
    p.advance()
    let node = p.parseExpression()
    p.skipWhitespace()
    if p.currentChar == ')':
      p.advance()
    return node

  newNodeNumber(0)

proc parseTerm(p: var Parser): Node =
  var node = p.parseFactor()

  while true:
    p.skipWhitespace()
    if p.currentChar == '\0':
      break

    if p.currentChar in {'*', '/', '%'}:
      let op = p.currentChar
      p.advance()
      let right = p.parseFactor()
      node = newNodeBinaryOp(op, node, right)
    else:
      break

  node

proc parseExpression(p: var Parser): Node =
  var node = p.parseTerm()

  while true:
    p.skipWhitespace()
    if p.currentChar == '\0':
      break

    if p.currentChar in {'+', '-'}:
      let op = p.currentChar
      p.advance()
      let right = p.parseTerm()
      node = newNodeBinaryOp(op, node, right)
    else:
      break

  node

proc parse*(p: var Parser): seq[Node] =
  p.expressions = @[]

  while p.currentChar != '\0':
    p.skipWhitespace()
    if p.currentChar == '\0':
      break

    let expr = p.parseExpression()
    p.expressions.add(expr)

  p.expressions

proc newCalculatorAst(): Benchmark =
  CalculatorAst()

method name(self: CalculatorAst): string = "CalculatorAst"

method prepare(self: CalculatorAst) =
  self.n = config_i64("CalculatorAst", "operations")
  self.text = generateRandomProgram(self.n)
  self.resultVal = 0
  self.expressions = @[]

method run(self: CalculatorAst, iteration_id: int) =
  var parser = newParser(self.text)
  self.expressions = parser.parse()
  self.resultVal = self.resultVal + uint32(self.expressions.len)

  if self.expressions.len > 0:
    let lastExpr = self.expressions[^1]
    if lastExpr.kind == nkAssignment:

      self.resultVal = self.resultVal + checksum(lastExpr.assignVar)

method checksum(self: CalculatorAst): uint32 =
  self.resultVal

registerBenchmark("CalculatorAst", newCalculatorAst)