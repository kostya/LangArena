package benchmarks

import scala.collection.mutable.{ArrayBuffer, Map}

class CalculatorAst extends Benchmark:
  sealed trait Node
  case class Number(value: Long) extends Node
  case class Variable(name: String) extends Node
  case class BinaryOp(op: Char, left: Node, right: Node) extends Node
  case class Assignment(variable: String, expr: Node) extends Node

  var n: Long = 0L
  private var resultVal: Long = 0L
  private var text: String = _
  var expressions: List[Node] = _

  n = configVal("operations")

  private def generateRandomProgram(lines: Long = 1000): String = {
    val sb = new StringBuilder()
    sb.append("v0 = 1\n")

    var i = 0
    while (i < 10) {
      val v = i + 1
      sb.append(s"v$v = v${v - 1} + $v\n")
      i += 1
    }

    i = 0
    while (i < lines) {
      val v = i + 10
      sb.append(s"v$v = v${v - 1} + ")
      Helper.nextInt(10) match {
        case 0 =>
          sb.append(
            s"(v${v - 1} / 3) * 4 - $i / (3 + (18 - v${v - 2})) % v${v - 3} + 2 * ((9 - v${v - 6}) * (v${v - 5} + 7))"
          )
        case 1 => sb.append(s"v${v - 1} + (v${v - 2} + v${v - 3}) * v${v - 4} - (v${v - 5} /  v${v - 6})")
        case 2 => sb.append(s"(3789 - (((v${v - 7})))) + 1")
        case 3 => sb.append(s"4/2 * (1-3) + v${v - 9}/v${v - 5}")
        case 4 => sb.append(s"1+2+3+4+5+6+v${v - 1}")
        case 5 => sb.append(s"(99999 / v${v - 3})")
        case 6 => sb.append(s"0 + 0 - v${v - 8}")
        case 7 => sb.append(s"((((((((((v${v - 6})))))))))) * 2")
        case 8 => sb.append(s"$i * (v${v - 1}%6)%7")
        case 9 => sb.append(s"(1)/(0-v${v - 5}) + (v${v - 7})")
      }
      sb.append("\n")
      i += 1
    }
    sb.toString()
  }

  override def prepare(): Unit = {
    text = generateRandomProgram(n)
  }

  private class Parser(val input: String) {
    private var pos = 0
    private val chars = input.toCharArray
    private val length = chars.length
    val expressions = ArrayBuffer.empty[Node]

    def parse(): List[Node] = {
      while (pos < length) {
        expressions.append(parseExpression())
      }
      expressions.toList
    }

    private def parseExpression(): Node = {
      var node = parseTerm()

      while (pos < length) {
        skipWhitespace()
        if (pos >= length) return node

        val ch = currentChar()
        if (ch == '+' || ch == '-') {
          val op = ch
          advance()
          val right = parseTerm()
          node = BinaryOp(op, node, right)
        } else {
          return node
        }
      }
      node
    }

    private def parseTerm(): Node = {
      var node = parseFactor()

      while (pos < length) {
        skipWhitespace()
        if (pos >= length) return node

        val ch = currentChar()
        if (ch == '*' || ch == '/' || ch == '%') {
          val op = ch
          advance()
          val right = parseFactor()
          node = BinaryOp(op, node, right)
        } else {
          return node
        }
      }
      node
    }

    private def parseFactor(): Node = {
      skipWhitespace()
      if (pos >= length) return Number(0)

      val ch = currentChar()
      if (ch >= '0' && ch <= '9') {
        parseNumber()
      } else if (ch >= 'a' && ch <= 'z') {
        parseVariable()
      } else if (ch == '(') {
        advance()
        val node = parseExpression()
        skipWhitespace()
        if (currentChar() == ')') advance()
        node
      } else {
        Number(0)
      }
    }

    private def parseNumber(): Node = {
      var value = 0L
      while (pos < length && chars(pos).isDigit) {
        value = value * 10 + (chars(pos) - '0')
        advance()
      }
      Number(value)
    }

    private def parseVariable(): Node = {
      val start = pos
      while (pos < length && chars(pos).isLetterOrDigit) {
        advance()
      }
      val varName = input.substring(start, pos)

      skipWhitespace()
      if (pos < length && currentChar() == '=') {
        advance()
        val expr = parseExpression()
        Assignment(varName, expr)
      } else {
        Variable(varName)
      }
    }

    private def currentChar(): Char = {
      if (pos < length) chars(pos) else '\u0000'
    }

    private def advance(): Unit = {
      if (pos < length) pos += 1
    }

    private def skipWhitespace(): Unit = {
      while (pos < length && chars(pos).isWhitespace) {
        advance()
      }
    }
  }

  override def run(iterationId: Int): Unit = {
    val parser = new Parser(text)
    expressions = parser.parse()
    resultVal += expressions.size.toLong
    if (expressions.nonEmpty && expressions.last.isInstanceOf[Assignment]) {
      val assign = expressions.last.asInstanceOf[Assignment]
      resultVal += Helper.checksum(assign.variable)
    }
  }

  override def checksum(): Long = resultVal & 0xffffffffL

  override def name(): String = "CalculatorAst"

class CalculatorInterpreter extends Benchmark:
  private var n: Long = 0L
  private var resultVal: Long = 0L
  private var ast: List[CalculatorAst#Node] = _

  override def name(): String = "CalculatorInterpreter"

  override def prepare(): Unit = {
    n = configVal("operations")
    val calculator = new CalculatorAst()
    calculator.n = n
    calculator.prepare()
    calculator.run(0)
    ast = calculator.expressions
  }

  private class Interpreter {
    private val variables = scala.collection.mutable.Map.empty[String, Long]

    private def simpleDiv(a: Long, b: Long): Long = {
      if (b == 0L) return 0L
      if ((a >= 0 && b > 0) || (a < 0 && b < 0)) {
        a / b
      } else {
        -math.abs(a) / math.abs(b)
      }
    }

    private def simpleMod(a: Long, b: Long): Long = {
      if (b == 0L) return 0L
      a - simpleDiv(a, b) * b
    }

    private def evaluate(node: CalculatorAst#Node): Long = {
      node match {
        case num: CalculatorAst#Number =>
          num.value
        case varNode: CalculatorAst#Variable =>
          variables.getOrElse(varNode.name, 0L)
        case binOp: CalculatorAst#BinaryOp =>
          val left = evaluate(binOp.left)
          val right = evaluate(binOp.right)
          binOp.op match {
            case '+' => left + right
            case '-' => left - right
            case '*' => left * right
            case '/' => simpleDiv(left, right)
            case '%' => simpleMod(left, right)
            case _   => 0L
          }
        case assign: CalculatorAst#Assignment =>
          val value = evaluate(assign.expr)
          variables(assign.variable) = value
          value
        case _ => 0L
      }
    }

    def run(expressions: List[CalculatorAst#Node]): Long = {
      var result = 0L
      for (expr <- expressions) {
        result = evaluate(expr)
      }
      result
    }
  }

  override def run(iterationId: Int): Unit = {
    val interpreter = new Interpreter()
    val result = interpreter.run(ast)
    resultVal += result
  }

  override def checksum(): Long = resultVal & 0xffffffffL
