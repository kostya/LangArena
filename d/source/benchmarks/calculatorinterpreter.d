module benchmarks.calculatorinterpreter;

import std.stdio;
import std.conv;
import std.array;
import std.algorithm;
import benchmark;
import helper;
import benchmarks.calculatorast;

class CalculatorInterpreter : Benchmark {
private:
    class Interpreter {
    private:
        long[string] variables;

        static long simpleDiv(long a, long b) {
            if (b == 0) return 0;
            if ((a >= 0 && b > 0) || (a < 0 && b < 0)) {
                return a / b;
            } else {
                long absA = a >= 0 ? a : (a == long.min ? long.max : -a);
                long absB = b >= 0 ? b : (b == long.min ? long.max : -b);
                return -(absA / absB);
            }
        }

        static long simpleMod(long a, long b) {
            if (b == 0) return 0;
            return a - simpleDiv(a, b) * b;
        }

        long evaluate(CalculatorAst.Node node) {
            if (auto num = cast(CalculatorAst.Number)node) {
                return num.value;
            }
            else if (auto var = cast(CalculatorAst.Variable)node) {
                return var.name in variables ? variables[var.name] : 0;
            }
            else if (auto binop = cast(CalculatorAst.BinaryOp)node) {
                long left = evaluate(binop.left);
                long right = evaluate(binop.right);

                switch (binop.op) {
                    case '+': return left + right;
                    case '-': return left - right;
                    case '*': return left * right;
                    case '/': return simpleDiv(left, right);
                    case '%': return simpleMod(left, right);
                    default: return 0;
                }
            }
            else if (auto assign = cast(CalculatorAst.Assignment)node) {
                long value = evaluate(assign.expr);
                variables[assign.var] = value;
                return value;
            }

            return 0;
        }

    public:
        long run(CalculatorAst.Node[] expressions) {
            long result = 0;
            variables.clear();
            foreach (expr; expressions) {
                result = evaluate(expr);
            }
            return result;
        }
    }

    long n;
    uint resultVal;
    CalculatorAst.Node[] ast;

protected:
    override string className() const { return "CalculatorInterpreter"; }

public:
    this() {
        resultVal = 0;
        n = configVal("operations");
    }

    override void prepare() {
        auto ca = new CalculatorAst();
        ca.n = n;
        ca.prepare();
        ca.run(0);
        ast = ca.expressions;
    }

    override void run(int iterationId) {
        auto interpreter = new Interpreter();
        long result = interpreter.run(ast);
        resultVal += cast(uint)result;
    }

    override uint checksum() {
        return resultVal;
    }
}