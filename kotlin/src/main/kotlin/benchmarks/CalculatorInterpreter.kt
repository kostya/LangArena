package benchmarks
import Benchmark

class CalculatorInterpreter : Benchmark() {  // Benchmark импортируется автоматически
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
    
    private var n: Int = 0
    private var _result: Long = 0L
    private lateinit var ast: List<CalculatorAst.Node>
    
    init {
        n = iterations  // iterations наследуется от Benchmark
    }
    
    override fun prepare() {
        // Получаем CalculatorAst через рефлексию
        val calculator = CalculatorAst()
        
        // Устанавливаем n через рефлексию
        val nField = CalculatorAst::class.java.getDeclaredField("n")
        nField.isAccessible = true
        nField.setInt(calculator, n)
        
        // Вызываем prepare через рефлексию
        val prepareMethod = CalculatorAst::class.java.getDeclaredMethod("prepare")
        prepareMethod.isAccessible = true
        prepareMethod.invoke(calculator)
        
        // Вызываем run через рефлексию
        val runMethod = CalculatorAst::class.java.getDeclaredMethod("run")
        runMethod.isAccessible = true
        runMethod.invoke(calculator)
        
        // Получаем expressions через рефлексию
        val expressionsField = CalculatorAst::class.java.getDeclaredField("expressions")
        expressionsField.isAccessible = true
        @Suppress("UNCHECKED_CAST")
        ast = expressionsField.get(calculator) as List<CalculatorAst.Node>
    }
    
    override fun run() {
        var total: Long = 0L
        repeat(100) {
            val interpreter = Interpreter()
            val result = interpreter.run(ast)
            total += result
        }
        _result = total
    }
    
    override val result: Long
        get() = _result
}