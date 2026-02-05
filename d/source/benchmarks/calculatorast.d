module benchmarks.calculatorast;

import std.stdio;
import std.conv;
import std.array;
import std.algorithm;
import std.string;
import std.range;
import std.typecons;
import std.exception;
import benchmark;
import helper;

class CalculatorAst : Benchmark {
public:

    struct Number {
        long value;
        this(long v) { value = v; }
    }

    struct Variable {
        string name;
        this(string n) { name = n; }
    }

    class BinaryOp {
        char op;
        Node left;
        Node right;

        this(char o, Node l, Node r) {
            op = o;
            left = l;
            right = r;
        }
    }

    class Assignment {
        string var;
        Node expr;

        this(string v, Node e) {
            var = v;
            expr = e;
        }
    }

    abstract class ASTNode {

        abstract string toText() const;
    }

    class NumberNode : ASTNode {
        Number value;
        this(Number n) { value = n; }
        override string toText() const {
            return to!string(value.value);
        }
    }

    class VariableNode : ASTNode {
        Variable variable;
        this(Variable v) { variable = v; }
        override string toText() const {
            return variable.name;
        }
    }

    class BinaryOpNode : ASTNode {
        BinaryOp operation;
        this(BinaryOp b) { operation = b; }
        override string toText() const {
            return format("(%s %s %s)", 
                operation.left.toText(), 
                operation.op, 
                operation.right.toText());
        }
    }

    class AssignmentNode : ASTNode {
        Assignment assignment;
        this(Assignment a) { assignment = a; }
        override string toText() const {
            return format("%s = %s", 
                assignment.var, 
                assignment.expr.toText());
        }
    }

    class Node {
    private:
        ASTNode node;

    public:
        this(Number n) { node = new NumberNode(n); }
        this(Variable v) { node = new VariableNode(v); }
        this(BinaryOp b) { node = new BinaryOpNode(b); }
        this(Assignment a) { node = new AssignmentNode(a); }

        bool isNumber() const { return cast(NumberNode)node !is null; }
        bool isVariable() const { return cast(VariableNode)node !is null; }
        bool isBinaryOp() const { return cast(BinaryOpNode)node !is null; }
        bool isAssignment() const { return cast(AssignmentNode)node !is null; }

        Number getNumber() const { 
            auto n = cast(NumberNode)node;
            return n ? n.value : Number(0);
        }

        Variable getVariable() const { 
            auto v = cast(VariableNode)node;
            return v ? v.variable : Variable("");
        }

        BinaryOp getBinaryOp() const { 
            auto b = cast(BinaryOpNode)node;
            return b ? b.operation : null;
        }

        Assignment getAssignment() const { 
            auto a = cast(AssignmentNode)node;
            return a ? a.assignment : null;
        }

        string toText() const {
            return node.toText();
        }
    }

private:
    class Parser {
    private:
        string input;
        size_t pos;
        char currentChar;
        char[] chars;
        Node[] expressions;

        void advance() {
            pos += 1;
            if (pos >= chars.length) {
                currentChar = '\0';
            } else {
                currentChar = chars[pos];
            }
        }

        void skipWhitespace() {
            while (currentChar != '\0' && isWhite(currentChar)) {
                advance();
            }
        }

        bool isWhite(char c) {
            return c == ' ' || c == '\t' || c == '\n' || c == '\r';
        }

        bool isDigit(char c) {
            return c >= '0' && c <= '9';
        }

        bool isAlpha(char c) {
            return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_';
        }

        Node parseNumber() {
            long v = 0;
            while (currentChar != '\0' && isDigit(currentChar)) {
                v = v * 10 + (currentChar - '0');
                advance();
            }
            return new Node(Number(v));
        }

        Node parseVariable() {
            size_t start = pos;
            while (currentChar != '\0' && 
                   (isAlpha(currentChar) || isDigit(currentChar))) {
                advance();
            }
            string varName = input[start .. pos];

            skipWhitespace();
            if (currentChar == '=') {
                advance();
                auto expr = parseExpression();
                return new Node(new Assignment(varName, expr));
            }

            return new Node(Variable(varName));
        }

        Node parseFactor() {
            skipWhitespace();
            if (currentChar == '\0') {
                return new Node(Number(0));
            }

            if (isDigit(currentChar)) {
                return parseNumber();
            }

            if (isAlpha(currentChar)) {
                return parseVariable();
            }

            if (currentChar == '(') {
                advance();
                auto node = parseExpression();
                skipWhitespace();
                if (currentChar == ')') {
                    advance();
                }
                return node;
            }

            return new Node(Number(0));
        }

        Node parseTerm() {
            auto node = parseFactor();

            while (true) {
                skipWhitespace();
                if (currentChar == '\0') break;

                if (currentChar == '*' || currentChar == '/' || currentChar == '%') {
                    char op = currentChar;
                    advance();
                    auto right = parseFactor();
                    node = new Node(new BinaryOp(op, node, right));
                } else {
                    break;
                }
            }

            return node;
        }

        Node parseExpression() {
            auto node = parseTerm();

            while (true) {
                skipWhitespace();
                if (currentChar == '\0') break;

                if (currentChar == '+' || currentChar == '-') {
                    char op = currentChar;
                    advance();
                    auto right = parseTerm();
                    node = new Node(new BinaryOp(op, node, right));
                } else {
                    break;
                }
            }

            return node;
        }

    public:
        this(string inputStr) {
            input = inputStr;
            pos = 0;
            chars = cast(char[])inputStr;
            if (chars.empty) {
                currentChar = '\0';
            } else {
                currentChar = chars[0];
            }
        }

        Node[] parse() {
            expressions = [];
            while (currentChar != '\0') {
                skipWhitespace();
                if (currentChar == '\0') break;
                expressions ~= parseExpression();
            }
            return expressions;
        }
    }

    uint resultVal;
    string text;
public:
    long n;
private:
    string generateRandomProgram(long programSize = 1000) {
        auto app = appender!string();
        app.put("v0 = 1\n");
        for (int i = 0; i < 10; i++) {
            int v = i + 1;
            app.put(format("v%s = v%s + %s\n", v, v - 1, v));
        }
        for (long i = 0; i < programSize; i++) {
            int v = cast(int)(i + 10);
            app.put(format("v%s = v%s + ", v, v - 1));

            switch (Helper.nextInt(10)) {
                case 0:
                    app.put(format("(v%s / 3) * 4 - %s / (3 + (18 - v%s)) %% v%s + 2 * ((9 - v%s) * (v%s + 7))", 
                        v - 1, i, v - 2, v - 3, v - 6, v - 5));
                    break;
                case 1:
                    app.put(format("v%s + (v%s + v%s) * v%s - (v%s / v%s)", 
                        v - 1, v - 2, v - 3, v - 4, v - 5, v - 6));
                    break;
                case 2:
                    app.put(format("(3789 - (((v%s)))) + 1", v - 7));
                    break;
                case 3:
                    app.put(format("4/2 * (1-3) + v%s/v%s", v - 9, v - 5));
                    break;
                case 4:
                    app.put(format("1+2+3+4+5+6+v%s", v - 1));
                    break;
                case 5:
                    app.put(format("(99999 / v%s)", v - 3));
                    break;
                case 6:
                    app.put(format("0 + 0 - v%s", v - 8));
                    break;
                case 7:
                    app.put(format("((((((((((v%s)))))))))) * 2", v - 6));
                    break;
                case 8:
                    app.put(format("%s * (v%s%%6)%%7", i, v - 1));
                    break;
                case 9:
                    app.put(format("(1)/(0-v%s) + (v%s)", v - 5, v - 7));
                    break;
                default:
                    break;
            }
            app.put("\n");
        }
        return app.data;
    }

protected:
    override string className() const { return "CalculatorAst"; }

public:
    this() {
        resultVal = 0;
        n = configVal("operations");
    }

    Node[] expressions;

    override void prepare() {
        text = generateRandomProgram(n);
    }

    override void run(int iterationId) {
        auto parser = new Parser(text);
        expressions = parser.parse();
        resultVal += cast(uint)expressions.length;
        if (!expressions.empty && expressions[$-1].isAssignment()) {
            auto assign = expressions[$-1].getAssignment();
            if (assign !is null) {
                resultVal += Helper.checksum(assign.var);
            }
        }
    }

    override uint checksum() {
        return resultVal;
    }
}