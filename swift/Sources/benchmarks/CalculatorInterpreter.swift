import Foundation

final class CalculatorInterpreter: BenchmarkProtocol {
  private class Interpreter {
    private var variables: [String: Int64] = [:]

    private func simpleDiv(_ a: Int64, _ b: Int64) -> Int64 {
      if b == 0 { return 0 }
      if (a >= 0 && b > 0) || (a < 0 && b < 0) {
        return a / b
      } else {
        return -Int64(abs(Int(a)) / abs(Int(b)))
      }
    }

    private func simpleMod(_ a: Int64, _ b: Int64) -> Int64 {
      if b == 0 { return 0 }
      return a - simpleDiv(a, b) * b
    }

    private func evaluate(_ node: CalculatorAst.Node) -> Int64 {
      switch node {
      case .number(let value):
        return value
      case .variable(let name):
        return variables[name] ?? 0
      case .binaryOp(let op, let leftNode, let rightNode):
        let left = evaluate(leftNode)
        let right = evaluate(rightNode)
        switch op {
        case "+": return left &+ right
        case "-": return left &- right
        case "*": return left &* right
        case "/": return simpleDiv(left, right)
        case "%": return simpleMod(left, right)
        default: return 0
        }
      case .assignment(let variable, let expr):
        let value = evaluate(expr)
        variables[variable] = value
        return value
      }
    }

    func run(_ expressions: [CalculatorAst.Node]) -> Int64 {
      var result: Int64 = 0
      for expr in expressions {
        result = evaluate(expr)
      }
      return result
    }
  }

  private var n: Int64 = 0
  private var resultVal: UInt32 = 0
  private var ast: CalculatorAst?

  init() {
    n = configValue("operations") ?? 0
  }

  func prepare() {
    ast = CalculatorAst()
    ast?.n = n
    ast?.prepare()
    ast?.run(iterationId: 0)
  }

  func run(iterationId: Int) {
    guard let ast = ast else { return }
    let interpreter = Interpreter()
    let result = interpreter.run(ast.expressions)

    let truncated = UInt32(truncatingIfNeeded: result)
    resultVal &+= truncated
  }

  var checksum: UInt32 {
    return resultVal
  }
}
