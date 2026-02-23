module benchmarks.calculatorast;

import std.stdio;
import std.conv;
import std.array;
import std.algorithm;
import std.string;
import std.range;
import benchmark;
import helper;

class CalculatorAst : Benchmark
{

    abstract class Node
    {

    }

    class Number : Node
    {
        long value;
        this(long v)
        {
            value = v;
        }
    }

    class Variable : Node
    {
        string name;
        this(string n)
        {
            name = n;
        }
    }

    class BinaryOp : Node
    {
        char op;
        Node left;
        Node right;

        this(char o, Node l, Node r)
        {
            op = o;
            left = l;
            right = r;
        }
    }

    class Assignment : Node
    {
        string var;
        Node expr;

        this(string v, Node e)
        {
            var = v;
            expr = e;
        }
    }

private:
    class Parser
    {
    private:
        string input;
        size_t pos;
        char currentChar;
        Node[] expressions;

        void advance()
        {
            pos++;
            if (pos >= input.length)
            {
                currentChar = '\0';
            }
            else
            {
                currentChar = input[pos];
            }
        }

        void skipWhitespace()
        {
            while (currentChar != '\0' && (currentChar == ' '
                    || currentChar == '\t' || currentChar == '\n' || currentChar == '\r'))
            {
                advance();
            }
        }

        Node parseNumber()
        {
            long v = 0;
            while (currentChar != '\0' && currentChar >= '0' && currentChar <= '9')
            {
                v = v * 10 + (currentChar - '0');
                advance();
            }
            return new Number(v);
        }

        Node parseVariable()
        {
            size_t start = pos;
            while (currentChar != '\0' && ((currentChar >= 'a' && currentChar <= 'z')
                    || (currentChar >= 'A' && currentChar <= 'Z')
                    || (currentChar >= '0' && currentChar <= '9') || currentChar == '_'))
            {
                advance();
            }

            string varName = input[start .. pos];

            skipWhitespace();
            if (currentChar == '=')
            {
                advance();
                auto expr = parseExpression();
                return new Assignment(varName, expr);
            }

            return new Variable(varName);
        }

        Node parseFactor()
        {
            skipWhitespace();
            if (currentChar == '\0')
            {
                return new Number(0);
            }

            if (currentChar >= '0' && currentChar <= '9')
            {
                return parseNumber();
            }

            if ((currentChar >= 'a' && currentChar <= 'z') || (currentChar >= 'A'
                    && currentChar <= 'Z') || currentChar == '_')
            {
                return parseVariable();
            }

            if (currentChar == '(')
            {
                advance();
                auto node = parseExpression();
                skipWhitespace();
                if (currentChar == ')')
                {
                    advance();
                }
                return node;
            }

            return new Number(0);
        }

        Node parseTerm()
        {
            auto node = parseFactor();

            while (true)
            {
                skipWhitespace();
                if (currentChar == '\0')
                    break;

                if (currentChar == '*' || currentChar == '/' || currentChar == '%')
                {
                    char op = currentChar;
                    advance();
                    auto right = parseFactor();
                    node = new BinaryOp(op, node, right);
                }
                else
                {
                    break;
                }
            }

            return node;
        }

        Node parseExpression()
        {
            auto node = parseTerm();

            while (true)
            {
                skipWhitespace();
                if (currentChar == '\0')
                    break;

                if (currentChar == '+' || currentChar == '-')
                {
                    char op = currentChar;
                    advance();
                    auto right = parseTerm();
                    node = new BinaryOp(op, node, right);
                }
                else
                {
                    break;
                }
            }

            return node;
        }

    public:
        this(string inputStr)
        {
            input = inputStr;
            pos = 0;
            currentChar = input.length > 0 ? input[0] : '\0';
        }

        Node[] parse()
        {
            expressions = [];
            while (currentChar != '\0')
            {
                skipWhitespace();
                if (currentChar == '\0')
                    break;
                expressions ~= parseExpression();
            }
            return expressions;
        }
    }

    uint resultVal;
    string text;
    public Node[] expressions;

    string generateRandomProgram(long programSize)
    {
        import std.format : format;

        auto app = appender!string();
        app.put("v0 = 1\n");

        for (int i = 0; i < 10; i++)
        {
            int v = i + 1;
            app.put(format("v%d = v%d + %d\n", v, v - 1, v));
        }

        for (long i = 0; i < programSize; i++)
        {
            int v = cast(int)(i + 10);
            app.put(format("v%d = v%d + ", v, v - 1));

            switch (Helper.nextInt(10))
            {
            case 0:
                app.put(format("(v%d / 3) * 4 - %d / (3 + (18 - v%d)) %% v%d + 2 * ((9 - v%d) * (v%d + 7))",
                        v - 1, i, v - 2, v - 3, v - 6, v - 5));
                break;
            case 1:
                app.put(format("v%d + (v%d + v%d) * v%d - (v%d / v%d)", v - 1,
                        v - 2, v - 3, v - 4, v - 5, v - 6));
                break;
            case 2:
                app.put(format("(3789 - (((v%d)))) + 1", v - 7));
                break;
            case 3:
                app.put(format("4/2 * (1-3) + v%d/v%d", v - 9, v - 5));
                break;
            case 4:
                app.put(format("1+2+3+4+5+6+v%d", v - 1));
                break;
            case 5:
                app.put(format("(99999 / v%d)", v - 3));
                break;
            case 6:
                app.put(format("0 + 0 - v%d", v - 8));
                break;
            case 7:
                app.put(format("((((((((((v%d)))))))))) * 2", v - 6));
                break;
            case 8:
                app.put(format("%d * (v%d%%6)%%7", i, v - 1));
                break;
            case 9:
                app.put(format("(1)/(0-v%d) + (v%d)", v - 5, v - 7));
                break;
            default:
                break;
            }
            app.put("\n");
        }
        return app.data;
    }

protected:
    override string className() const
    {
        return "Calculator::Ast";
    }

public:
    this()
    {
        resultVal = 0;
        n = configVal("operations");
    }

    long n;

    override void prepare()
    {
        text = generateRandomProgram(n);
    }

    override void run(int iterationId)
    {
        auto parser = new Parser(text);
        expressions = parser.parse();
        resultVal += cast(uint) expressions.length;

        if (!expressions.empty)
        {

            if (auto assign = cast(Assignment) expressions[$ - 1])
            {
                resultVal += Helper.checksum(assign.var);
            }
        }
    }

    override uint checksum()
    {
        return resultVal;
    }
}
