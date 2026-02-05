package benchmarks
import Benchmark

class CalculatorInterpreter : Benchmark() {
    private class Interpreter {
        private val variables = mutableMapOf<String, Long>()

        private fun simpleDiv(a: Long, b: Long): Long {
            if (b == 0L) return 0L
            return if ((a >= 0 && b > 0) || (a < 0 && b < 0)) {
                a / b
            } else {
                -Math.abs(a) / Math.abs(b)
            }
        }

        private fun simpleMod(a: Long, b: Long): Long {
            if (b == 0L) return 0L
            return a - simpleDiv(a, b) * b
        }

        private fun evaluate(node: CalculatorAst.Node): Long {
            return when (node) {
                is CalculatorAst.Number -> node.value
                is CalculatorAst.Variable -> variables[node.name] ?: 0L
                is CalculatorAst.BinaryOp -> {
                    val left = evaluate(node.left)
                    val right = evaluate(node.right)

                    when (node.op) {
                        '+' -> left + right
                        '-' -> left - right
                        '*' -> left * right
                        '/' -> simpleDiv(left, right)
                        '%' -> simpleMod(left, right)
                        else -> 0L
                    }
                }
                is CalculatorAst.Assignment -> {
                    val value = evaluate(node.expr)
                    variables[node.variable] = value
                    value
                }
                else -> 0L
            }
        }

        fun run(expressions: List<CalculatorAst.Node>): Long {
            var result = 0L
            for (expr in expressions) {
                result = evaluate(expr)
            }
            return result
        }
    }

    private var n: Long = 0
    private var resultVal: UInt = 0u
    private lateinit var ast: List<CalculatorAst.Node>

    init {
        n = configVal("operations")
    }

    override fun prepare() {
        val calculator = CalculatorAst()
        calculator.n = n.toLong()
        calculator.prepare()
        calculator.run(0)
        ast = calculator.expressions
    }

    override fun run(iterationId: Int) {
        val interpreter = Interpreter()
        val result = interpreter.run(ast)
        resultVal += result.toUInt()  
    }

    override fun checksum(): UInt = resultVal

    override fun name(): String = "CalculatorInterpreter"
}