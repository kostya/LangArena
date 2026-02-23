public class CalculatorInterpreter : Benchmark
{
    private class Interpreter
    {
        private readonly Dictionary<string, long> _variables = new();

        private static long SafeAbs(long x)
        {
            if (x >= 0) return x;
            if (x == long.MinValue) return long.MaxValue;
            return -x;
        }

        private static long SimpleDiv(long a, long b)
        {
            if (b == 0) return 0;

            if ((a >= 0 && b > 0) || (a < 0 && b < 0)) return a / b;
            else
            {
                long absA = SafeAbs(a);
                long absB = SafeAbs(b);
                return -(absA / absB);
            }
        }

        private static long SimpleMod(long a, long b)
        {
            if (b == 0) return 0;
            return a - SimpleDiv(a, b) * b;
        }

        private long Evaluate(CalculatorAst.Node node)
        {
            switch (node)
            {
                case CalculatorAst.Number number: return number.Value;
                case CalculatorAst.Variable variable: return _variables.GetValueOrDefault(variable.Name, 0);
                case CalculatorAst.BinaryOp binaryOp:
                    long left = Evaluate(binaryOp.Left);
                    long right = Evaluate(binaryOp.Right);

                    return binaryOp.Op switch
                    {
                        '+' => left + right,
                        '-' => left - right,
                        '*' => left * right,
                        '/' => SimpleDiv(left, right),
                        '%' => SimpleMod(left, right),
                        _ => 0
                    };
                case CalculatorAst.Assignment assignment:
                    long value = Evaluate(assignment.Expr);
                    _variables[assignment.Var] = value;
                    return value;
                default: return 0;
            }
        }

        public long Run(List<CalculatorAst.Node> expressions)
        {
            long result = 0;
            foreach (var expr in expressions) result = Evaluate(expr);
            return result;
        }
    }

    private long _n;
    private uint _result;
    private List<CalculatorAst.Node> _ast = new();

    public CalculatorInterpreter()
    {
        _result = 0;
        _n = ConfigVal("operations");
    }

    public override void Prepare()
    {
        var calculator = new CalculatorAst();
        calculator._n = _n;
        calculator.Prepare();
        calculator.Run(0);
        _ast = calculator.Expressions;
    }

    public override void Run(long IterationId)
    {
        var interpreter = new Interpreter();
        long result = interpreter.Run(_ast);
        _result += (uint)result;
    }

    public override uint Checksum => _result;
    public override string TypeName => "Calculator::Interpreter";
}