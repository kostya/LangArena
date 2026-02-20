package benchmarks;

import java.lang.reflect.Field;
import java.util.*;

public class CalculatorInterpreter extends Benchmark {

    private static class Interpreter {
        private final Map<String, Long> variables = new HashMap<>();

        private long simpleDiv(long a, long b) {
            if (b == 0L) return 0L;

            if ((a >= 0 && b > 0) || (a < 0 && b < 0)) {
                return a / b;
            } else {
                return -Math.abs(a) / Math.abs(b);
            }
        }

        private long simpleMod(long a, long b) {
            if (b == 0L) return 0L;
            return a - simpleDiv(a, b) * b;
        }

        private long evaluate(CalculatorAst.Node node) {
            if (node instanceof CalculatorAst.Number) {
                return ((CalculatorAst.Number) node).value;
            } else if (node instanceof CalculatorAst.Variable) {
                return variables.getOrDefault(((CalculatorAst.Variable) node).name, 0L);
            } else if (node instanceof CalculatorAst.BinaryOp) {
                CalculatorAst.BinaryOp op = (CalculatorAst.BinaryOp) node;
                long left = evaluate(op.left);
                long right = evaluate(op.right);

                switch (op.op) {
                case '+':
                    return left + right;
                case '-':
                    return left - right;
                case '*':
                    return left * right;
                case '/':
                    return simpleDiv(left, right);
                case '%':
                    return simpleMod(left, right);
                default:
                    return 0L;
                }
            } else if (node instanceof CalculatorAst.Assignment) {
                CalculatorAst.Assignment assign = (CalculatorAst.Assignment) node;
                long value = evaluate(assign.expr);
                variables.put(assign.variable, value);
                return value;
            } else {
                return 0L;
            }
        }

        long run(List<CalculatorAst.Node> expressions) {
            long result = 0L;
            for (CalculatorAst.Node expr : expressions) {
                result = evaluate(expr);
            }
            return result;
        }

        void clear() {
            variables.clear();
        }
    }

    private long resultVal;
    private List<CalculatorAst.Node> ast;
    private long n;

    public CalculatorInterpreter() {
        n = configVal("operations");
        resultVal = 0L;
    }

    @Override
    public String name() {
        return "CalculatorInterpreter";
    }

    @Override
    public void prepare() {
        CalculatorAst calculator = new CalculatorAst();
        calculator.n = n;
        calculator.prepare();
        calculator.run(0);
        ast = calculator.getExpressions();
    }

    @Override
    public void run(int iterationId) {
        Interpreter interpreter = new Interpreter();
        long res = interpreter.run(ast);
        resultVal += res;
        interpreter.clear();
    }

    @Override
    public long checksum() {
        return resultVal;
    }
}