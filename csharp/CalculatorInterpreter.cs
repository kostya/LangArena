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
            
            if ((a >= 0 && b > 0) || (a < 0 && b < 0))
                return a / b;
            else
            {
                // Безопасный Abs для long.MinValue
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
                case CalculatorAst.Number number:
                    return number.Value;
                    
                case CalculatorAst.Variable variable:
                    return _variables.GetValueOrDefault(variable.Name, 0);
                    
                case CalculatorAst.BinaryOp binaryOp:
                    long left = Evaluate(binaryOp.Left);
                    long right = Evaluate(binaryOp.Right);
                    
                    // C++ не использует unchecked, но на практике wrap-around
                    return binaryOp.Op switch
                    {
                        '+' => left + right,  // без unchecked
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
                    
                default:
                    return 0;
            }
        }       
        public long Run(List<CalculatorAst.Node> expressions)
        {
            long result = 0;
            foreach (var expr in expressions)
            {
                result = Evaluate(expr);
            }
            return result;
        }
        
        public void Clear()
        {
            _variables.Clear();
        }
    }
    
    private int _n;
    private List<CalculatorAst.Node> _ast = new();
    private long _result;
    
    public override long Result => _result;
    
    public CalculatorInterpreter()
    {
        _result = 0;
    }
    
    public override void Prepare()
    {
        _n = Iterations;
        var calculator = new CalculatorAst();
        calculator._n = Iterations;
        calculator.Prepare();
        calculator.Run();
        _ast = calculator.GetExpressions();
    }
    
    public override void Run()
    {
        long v = 0;
        
        for (int i = 0; i < 100; i++)
        {
            var interpreter = new Interpreter();
            long result = interpreter.Run(_ast);
            v += result;  // без unchecked
        }
        
        _result = v;
    }
}