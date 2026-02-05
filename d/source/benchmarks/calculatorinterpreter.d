module benchmarks.calculatorinterpreter;

import std.stdio;
import std.conv;
import std.array;
import std.algorithm;
import std.string;
import std.math;  
import std.typecons;
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
                return -((a >= 0 ? a : -a) / (b >= 0 ? b : -b));  
            }
        }

        static long simpleMod(long a, long b) {
            if (b == 0) return 0;
            return a - simpleDiv(a, b) * b;
        }

        long evaluate(ref CalculatorAst.Node node) {
            if (node.isNumber()) {
                return node.getNumber().value;
            } 
            else if (node.isVariable()) {
                auto varName = node.getVariable().name;

                if (varName in variables) {
                    return variables[varName];
                } else {
                    return 0;
                }
            }
            else if (node.isBinaryOp()) {
                auto binop = node.getBinaryOp();
                if (binop is null) return 0;

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
            else if (node.isAssignment()) {
                auto assign = node.getAssignment();
                if (assign is null) return 0;

                long value = evaluate(assign.expr);
                variables[assign.var] = value;  
                return value;
            }

            return 0;
        }

    public:
        long run(CalculatorAst.Node[] expressions) {
            long result = 0;
            variables = null;  

            foreach (ref expr; expressions) {
                result = evaluate(expr);
            }
            return result;
        }

        void clear() {
            variables = null;
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
        ast = ca.expressions.dup;  
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