using System.Text;

public class CalculatorAst : Benchmark
{
    public abstract class Node { }

    public class Number : Node
    {
        public long Value { get; }
        public Number(long value) => Value = value;
    }

    public class Variable : Node
    {
        public string Name { get; }
        public Variable(string name) => Name = name;
    }

    public class BinaryOp : Node
    {
        public char Op { get; }
        public Node Left { get; }
        public Node Right { get; }
        public BinaryOp(char op, Node left, Node right)
        {
            Op = op;
            Left = left;
            Right = right;
        }
    }

    public class Assignment : Node
    {
        public string Var { get; }
        public Node Expr { get; }
        public Assignment(string var, Node expr)
        {
            Var = var;
            Expr = expr;
        }
    }

    public long _n;
    private string _text = "";
    private uint _result;
    public List<Node> Expressions = new();

    public CalculatorAst()
    {
        _result = 0;
        _n = ConfigVal("operations");
    }

    private string GenerateRandomProgram(long n = 1000)
    {
        var sb = new StringBuilder();
        sb.AppendLine("v0 = 1");

        for (int i = 0; i < 10; i++)
        {
            int v = i + 1;
            sb.AppendLine($"v{v} = v{v - 1} + {v}");
        }

        for (long i = 0; i < n; i++)
        {
            int v = (int)(i + 10);
            sb.Append($"v{v} = v{v - 1} + ");

            switch (Helper.NextInt(10))
            {
                case 0: sb.Append($"(v{v - 1} / 3) * 4 - {i} / (3 + (18 - v{v - 2})) % v{v - 3} + 2 * ((9 - v{v - 6}) * (v{v - 5} + 7))"); break;
                case 1: sb.Append($"v{v - 1} + (v{v - 2} + v{v - 3}) * v{v - 4} - (v{v - 5} / v{v - 6})"); break;
                case 2: sb.Append($"(3789 - (((v{v - 7})))) + 1"); break;
                case 3: sb.Append($"4/2 * (1-3) + v{v - 9}/v{v - 5}"); break;
                case 4: sb.Append($"1+2+3+4+5+6+v{v - 1}"); break;
                case 5: sb.Append($"(99999 / v{v - 3})"); break;
                case 6: sb.Append($"0 + 0 - v{v - 8}"); break;
                case 7: sb.Append($"((((((((((v{v - 6})))))))))) * 2"); break;
                case 8: sb.Append($"{i} * (v{v - 1}%6)%7"); break;
                case 9: sb.Append($"(1)/(0-v{v - 5}) + (v{v - 7})"); break;
            }
            sb.AppendLine();
        }

        return sb.ToString();
    }

    public override void Prepare() => _text = GenerateRandomProgram(_n);

    private class Parser
    {
        private readonly string _input;
        private int _pos;
        private char _currentChar;
        private readonly char[] _chars;

        public List<Node> Expressions { get; } = new();

        public Parser(string input)
        {
            _input = input;
            _pos = 0;
            _chars = input.ToCharArray();
            _currentChar = _chars.Length > 0 ? _chars[0] : '\0';
        }

        public List<Node> Parse()
        {
            while (_pos < _input.Length)
            {
                SkipWhitespace();
                if (_pos >= _input.Length) break;

                var expr = ParseExpression();
                if (expr != null) Expressions.Add(expr);
            }
            return Expressions;
        }

        private Node ParseExpression()
        {
            var node = ParseTerm();

            while (_pos < _input.Length)
            {
                SkipWhitespace();
                if (_pos >= _input.Length) break;

                if (_currentChar == '+' || _currentChar == '-')
                {
                    char op = _currentChar;
                    Advance();
                    var right = ParseTerm();
                    node = new BinaryOp(op, node, right);
                }
                else break;
            }

            return node;
        }

        private Node ParseTerm()
        {
            var node = ParseFactor();

            while (_pos < _input.Length)
            {
                SkipWhitespace();
                if (_pos >= _input.Length) break;

                if (_currentChar == '*' || _currentChar == '/' || _currentChar == '%')
                {
                    char op = _currentChar;
                    Advance();
                    var right = ParseFactor();
                    node = new BinaryOp(op, node, right);
                }
                else break;
            }

            return node;
        }

        private Node ParseFactor()
        {
            SkipWhitespace();
            if (_pos >= _input.Length) return new Number(0);

            switch (_currentChar)
            {
                case >= '0' and <= '9': return ParseNumber();
                case >= 'a' and <= 'z': return ParseVariable();
                case '(':
                    Advance();
                    var node = ParseExpression();
                    SkipWhitespace();
                    if (_currentChar == ')') Advance();
                    return node;
                default: return new Number(0);
            }
        }

        private Node ParseNumber()
        {
            long value = 0;

            while (_pos < _input.Length && char.IsDigit(_currentChar))
            {
                value = value * 10 + (_currentChar - '0');
                Advance();
            }

            return new Number(value);
        }

        private Node ParseVariable()
        {
            int start = _pos;

            while (_pos < _input.Length && 
                  (char.IsLetterOrDigit(_currentChar) || _currentChar == '_'))
            {
                Advance();
            }

            string varName = _input[start.._pos];

            SkipWhitespace();
            if (_currentChar == '=')
            {
                Advance();
                var expr = ParseExpression();
                return new Assignment(varName, expr);
            }

            return new Variable(varName);
        }

        private void Advance()
        {
            _pos++;
            if (_pos >= _input.Length) _currentChar = '\0';
            else _currentChar = _chars[_pos];
        }

        private void SkipWhitespace()
        {
            while (_pos < _input.Length && char.IsWhiteSpace(_currentChar)) Advance();
        }
    }

    public override void Run(long IterationId)
    {
        var parser = new Parser(_text);
        Expressions = parser.Parse();
        _result += (uint)Expressions.Count;

        if (Expressions.Count > 0 && Expressions[^1] is Assignment assign)
        {
            _result += Helper.Checksum(assign.Var);
        }
    }

    public override uint Checksum => _result;
}