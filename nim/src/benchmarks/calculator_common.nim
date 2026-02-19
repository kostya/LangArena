import std/[strutils, strformat, parseutils, hashes, tables]
import ../benchmark
import ../helper

type
  NodeKind* = enum
    nkNumber, nkVariable, nkBinaryOp, nkAssignment

  Node* = ref object
    case kind*: NodeKind
    of nkNumber:
      numberVal*: int64
    of nkVariable:
      varName*: string
    of nkBinaryOp:
      op*: char
      left*: Node
      right*: Node
    of nkAssignment:
      assignVar*: string
      assignExpr*: Node

proc newNodeNumber*(val: int64): Node =
  Node(kind: nkNumber, numberVal: val)

proc newNodeVariable*(name: string): Node =
  Node(kind: nkVariable, varName: name)

proc newNodeBinaryOp*(op: char, left, right: Node): Node =
  Node(kind: nkBinaryOp, op: op, left: left, right: right)

proc newNodeAssignment*(variable: string, expr: Node): Node =
  Node(kind: nkAssignment, assignVar: variable, assignExpr: expr)

proc generateRandomProgram*(n: int64): string =
  result = "v0 = 1\n"
  for i in 0..<10:
    let vNum = i + 1
    result.add(&"v{vNum} = v{vNum-1} + {vNum}\n")

  for i in 0..<n:
    let vNum = int(i + 10)
    result.add(&"v{vNum} = v{vNum-1} + ")

    case nextInt(10):
    of 0:
      result.add(&"(v{vNum-1} / 3) * 4 - {i} / (3 + (18 - v{vNum-2})) % v{vNum-3} + 2 * ((9 - v{vNum-6}) * (v{vNum-5} + 7))")
    of 1:
      result.add(&"v{vNum-1} + (v{vNum-2} + v{vNum-3}) * v{vNum-4} - (v{vNum-5} / v{vNum-6})")
    of 2:
      result.add(&"(3789 - (((v{vNum-7})))) + 1")
    of 3:
      result.add(&"4/2 * (1-3) + v{vNum-9}/v{vNum-5}")
    of 4:
      result.add(&"1+2+3+4+5+6+v{vNum-1}")
    of 5:
      result.add(&"(99999 / v{vNum-3})")
    of 6:
      result.add(&"0 + 0 - v{vNum-8}")
    of 7:
      result.add(&"((((((((((v{vNum-6})))))))))) * 2")
    of 8:
      result.add(&"{i} * (v{vNum-1} %6)%7")
    of 9:
      result.add(&"(1)/(0-v{vNum-5}) + (v{vNum-7})")
    else:
      discard

    result.add("\n")
