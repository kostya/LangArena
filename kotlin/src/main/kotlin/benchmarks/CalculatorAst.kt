package benchmarks

import Benchmark

class CalculatorAst : Benchmark() {
    sealed class Node

    data class Number(
        val value: Long,
    ) : Node()

    data class Variable(
        val name: String,
    ) : Node()

    data class BinaryOp(
        val op: Char,
        val left: Node,
        val right: Node,
    ) : Node()

    data class Assignment(
        val variable: String,
        val expr: Node,
    ) : Node()

    var n: Long = 0
    private var resultVal: UInt = 0u
    private lateinit var text: String
    lateinit var expressions: List<Node>

    init {
        n = configVal("operations")
    }

    private fun generateRandomProgram(lines: Long = 1000): String =
        buildString {
            append("v0 = 1\n")
            for (i in 0 until 10) {
                val v = i + 1
                append("v$v = v${v - 1} + $v\n")
            }
            for (i in 0 until lines) {
                val v = i + 10
                append("v$v = v${v - 1} + ")
                when (Helper.nextInt(10)) {
                    0 -> append("(v${v - 1} / 3) * 4 - $i / (3 + (18 - v${v - 2})) % v${v - 3} + 2 * ((9 - v${v - 6}) * (v${v - 5} + 7))")
                    1 -> append("v${v - 1} + (v${v - 2} + v${v - 3}) * v${v - 4} - (v${v - 5} /  v${v - 6})")
                    2 -> append("(3789 - (((v${v - 7})))) + 1")
                    3 -> append("4/2 * (1-3) + v${v - 9}/v${v - 5}")
                    4 -> append("1+2+3+4+5+6+v${v - 1}")
                    5 -> append("(99999 / v${v - 3})")
                    6 -> append("0 + 0 - v${v - 8}")
                    7 -> append("((((((((((v${v - 6})))))))))) * 2")
                    8 -> append("$i * (v${v - 1}%6)%7")
                    9 -> append("(1)/(0-v${v - 5}) + (v${v - 7})")
                }
                append("\n")
            }
        }

    override fun prepare() {
        text = generateRandomProgram(n)
    }

    private class Parser(
        private val input: String,
    ) {
        private var pos = 0
        private val chars = input.toCharArray()
        private val length = chars.size
        val expressions = mutableListOf<Node>()

        fun parse(): List<Node> {
            while (pos < length) {
                expressions.add(parseExpression())
            }
            return expressions
        }

        private fun parseExpression(): Node {
            var node = parseTerm()

            while (pos < length) {
                skipWhitespace()
                if (pos >= length) break

                val ch = currentChar()
                if (ch == '+' || ch == '-') {
                    val op = ch
                    advance()
                    val right = parseTerm()
                    node = BinaryOp(op, node, right)
                } else {
                    break
                }
            }

            return node
        }

        private fun parseTerm(): Node {
            var node = parseFactor()

            while (pos < length) {
                skipWhitespace()
                if (pos >= length) break

                val ch = currentChar()
                if (ch == '*' || ch == '/' || ch == '%') {
                    val op = ch
                    advance()
                    val right = parseFactor()
                    node = BinaryOp(op, node, right)
                } else {
                    break
                }
            }

            return node
        }

        private fun parseFactor(): Node {
            skipWhitespace()
            if (pos >= length) return Number(0)

            return when (val ch = currentChar()) {
                in '0'..'9' -> {
                    parseNumber()
                }

                in 'a'..'z' -> {
                    parseVariable()
                }

                '(' -> {
                    advance()
                    val node = parseExpression()
                    skipWhitespace()
                    if (currentChar() == ')') {
                        advance()
                    }
                    node
                }

                else -> {
                    Number(0)
                }
            }
        }

        private fun parseNumber(): Node {
            var value = 0L
            while (pos < length && chars[pos].isDigit()) {
                value = value * 10 + (chars[pos] - '0')
                advance()
            }
            return Number(value)
        }

        private fun parseVariable(): Node {
            val start = pos
            while (pos < length && (chars[pos].isLetterOrDigit())) {
                advance()
            }
            val varName = input.substring(start, pos)

            skipWhitespace()
            if (pos < length && currentChar() == '=') {
                advance()
                val expr = parseExpression()
                return Assignment(varName, expr)
            }

            return Variable(varName)
        }

        private fun currentChar(): Char = if (pos < length) chars[pos] else '\u0000'

        private fun advance() {
            if (pos < length) pos++
        }

        private fun skipWhitespace() {
            while (pos < length && chars[pos].isWhitespace()) {
                advance()
            }
        }
    }

    override fun run(iterationId: Int) {
        val parser = Parser(text)
        expressions = parser.parse()
        resultVal += expressions.size.toUInt()
        if (expressions.isNotEmpty() && expressions.last() is Assignment) {
            val assign = expressions.last() as Assignment
            resultVal += Helper.checksum(assign.variable)
        }
    }

    override fun checksum(): UInt = resultVal

    override fun name(): String = "CalculatorAst"
}
