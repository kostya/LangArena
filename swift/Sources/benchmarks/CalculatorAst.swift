import Foundation

final class CalculatorAst: BenchmarkProtocol {
  indirect enum Node {
    case number(Int64)
    case variable(String)
    case binaryOp(Character, Node, Node)
    case assignment(String, Node)
  }

  private var resultVal: UInt32 = 0
  private var text: String = ""
  public var expressions: [Node] = []
  public var n: Int64 = 0

  init() {
    n = configValue("operations") ?? 0
  }

  private func generateRandomProgram(_ n: Int64 = 1000) -> String {
    var result = "v0 = 1\n"
    for i in 0..<10 {
      let v = i + 1
      result += "v\(v) = v\(v - 1) + \(v)\n"
    }
    for i in 0..<Int(n) {
      let v = i + 10
      result += "v\(v) = v\(v - 1) + "
      let rand = Helper.nextInt(max: 10)
      switch rand {
      case 0:
        result +=
          "(v\(v - 1) / 3) * 4 - \(i) / (3 + (18 - v\(v - 2))) % v\(v - 3) + 2 * ((9 - v\(v - 6)) * (v\(v - 5) + 7))"
      case 1:
        result += "v\(v - 1) + (v\(v - 2) + v\(v - 3)) * v\(v - 4) - (v\(v - 5) / v\(v - 6))"
      case 2:
        result += "(3789 - (((v\(v - 7))))) + 1"
      case 3:
        result += "4/2 * (1-3) + v\(v - 9)/v\(v - 5)"
      case 4:
        result += "1+2+3+4+5+6+v\(v - 1)"
      case 5:
        result += "(99999 / v\(v - 3))"
      case 6:
        result += "0 + 0 - v\(v - 8)"
      case 7:
        result += "((((((((((v\(v - 6)))))))))) * 2"
      case 8:
        result += "\(i) * (v\(v - 1)%6)%7"
      case 9:
        result += "(1)/(0-v\(v - 5)) + (v\(v - 7))"
      default:
        result += "0"
      }
      result += "\n"
    }
    return result
  }

  private class Parser {
    private let input: String
    private var pos: String.Index
    var expressions: [Node] = []

    init(_ input: String) {
      self.input = input
      self.pos = input.startIndex
    }

    func parse() -> [Node] {
      while pos < input.endIndex {
        skipWhitespace()
        if pos >= input.endIndex { break }
        expressions.append(parseExpression())
      }
      return expressions
    }

    private func parseExpression() -> Node {
      var node = parseTerm()
      while pos < input.endIndex {
        skipWhitespace()
        guard pos < input.endIndex else { break }
        let ch = currentChar()
        if ch == "+" || ch == "-" {
          let op = ch
          advance()
          let right = parseTerm()
          node = .binaryOp(op, node, right)
        } else {
          break
        }
      }
      return node
    }

    private func parseTerm() -> Node {
      var node = parseFactor()
      while pos < input.endIndex {
        skipWhitespace()
        guard pos < input.endIndex else { break }
        let ch = currentChar()
        if ch == "*" || ch == "/" || ch == "%" {
          let op = ch
          advance()
          let right = parseFactor()
          node = .binaryOp(op, node, right)
        } else {
          break
        }
      }
      return node
    }

    private func parseFactor() -> Node {
      skipWhitespace()
      guard pos < input.endIndex else { return .number(0) }
      let ch = currentChar()
      switch ch {
      case "0"..."9":
        return parseNumber()
      case "a"..."z":
        return parseVariable()
      case "(":
        advance()
        let node = parseExpression()
        skipWhitespace()
        if currentChar() == ")" {
          advance()
        }
        return node
      default:
        return .number(0)
      }
    }

    private func parseNumber() -> Node {
      var value: Int64 = 0
      while pos < input.endIndex {
        let ch = currentChar()
        guard ch.isNumber else { break }
        value = value * 10 + Int64(ch.wholeNumberValue ?? 0)
        advance()
      }
      return .number(value)
    }

    private func parseVariable() -> Node {
      let start = pos
      while pos < input.endIndex {
        let ch = currentChar()
        guard ch.isLetter || ch.isNumber else { break }
        advance()
      }
      let varName = String(input[start..<pos])
      skipWhitespace()
      if pos < input.endIndex && currentChar() == "=" {
        advance()
        let expr = parseExpression()
        return .assignment(varName, expr)
      }
      return .variable(varName)
    }

    private func currentChar() -> Character {
      guard pos < input.endIndex else { return "\0" }
      return input[pos]
    }

    private func advance() {
      guard pos < input.endIndex else { return }
      pos = input.index(after: pos)
    }

    private func skipWhitespace() {
      while pos < input.endIndex && input[pos].isWhitespace {
        advance()
      }
    }
  }

  func prepare() {
    text = generateRandomProgram(n)
  }

  func run(iterationId: Int) {
    let parser = Parser(text)
    expressions = parser.parse()
    resultVal &+= UInt32(expressions.count)

    if !expressions.isEmpty,
      case .assignment(let varName, _) = expressions.last!
    {
      resultVal &+= Helper.checksum(varName)
    }
  }

  var checksum: UInt32 {
    return resultVal
  }
}
