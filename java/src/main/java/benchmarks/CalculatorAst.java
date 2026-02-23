package benchmarks;

import java.util.*;

public class CalculatorAst extends Benchmark {

    interface Node {}

    static class Number implements Node {
        final long value;
        Number(long value) {
            this.value = value;
        }
    }

    static class Variable implements Node {
        final String name;
        Variable(String name) {
            this.name = name;
        }
    }

    static class BinaryOp implements Node {
        final char op;
        final Node left;
        final Node right;
        BinaryOp(char op, Node left, Node right) {
            this.op = op;
            this.left = left;
            this.right = right;
        }
    }

    static class Assignment implements Node {
        final String variable;
        final Node expr;
        Assignment(String variable, Node expr) {
            this.variable = variable;
            this.expr = expr;
        }
    }

    private long resultVal;
    private String text;
    public List<Node> expressions = new ArrayList<>();
    public long n;

    public CalculatorAst() {
        n = configVal("operations");
        resultVal = 0L;
    }

    @Override
    public String name() {
        return "Calculator::Ast";
    }

    private String generateRandomProgram(long lines) {
        StringBuilder sb = new StringBuilder();
        sb.append("v0 = 1\n");

        for (int i = 0; i < 10; i++) {
            int v = i + 1;
            sb.append("v").append(v).append(" = v").append(v - 1)
            .append(" + ").append(v).append("\n");
        }

        for (long i = 0; i < lines; i++) {
            int v = (int)(i + 10);
            sb.append("v").append(v).append(" = v").append(v - 1).append(" + ");

            switch (Helper.nextInt(10)) {
            case 0:
                sb.append("(v").append(v - 1).append(" / 3) * 4 - ").append(i)
                .append(" / (3 + (18 - v").append(v - 2).append(")) % v")
                .append(v - 3).append(" + 2 * ((9 - v").append(v - 6)
                .append(") * (v").append(v - 5).append(" + 7))");
                break;
            case 1:
                sb.append("v").append(v - 1).append(" + (v").append(v - 2)
                .append(" + v").append(v - 3).append(") * v").append(v - 4)
                .append(" - (v").append(v - 5).append(" /  v").append(v - 6).append(")");
                break;
            case 2:
                sb.append("(3789 - (((v").append(v - 7).append(")))) + 1");
                break;
            case 3:
                sb.append("4/2 * (1-3) + v").append(v - 9).append("/v").append(v - 5);
                break;
            case 4:
                sb.append("1+2+3+4+5+6+v").append(v - 1);
                break;
            case 5:
                sb.append("(99999 / v").append(v - 3).append(")");
                break;
            case 6:
                sb.append("0 + 0 - v").append(v - 8);
                break;
            case 7:
                sb.append("((((((((((v").append(v - 6).append(")))))))))) * 2");
                break;
            case 8:
                sb.append(i).append(" * (v").append(v - 1).append("%6)%7");
                break;
            case 9:
                sb.append("(1)/(0-v").append(v - 5).append(") + (v").append(v - 7).append(")");
                break;
            }
            sb.append("\n");
        }

        return sb.toString();
    }

    @Override
    public void prepare() {
        text = generateRandomProgram(n);
    }

    static class Parser {
        private final String input;
        private int pos;
        private final char[] chars;
        final List<Node> expressions = new ArrayList<>();

        Parser(String input) {
            this.input = input;
            this.chars = input.toCharArray();
        }

        void parse() {
            while (pos < chars.length) {
                expressions.add(parseExpression());
            }
        }

        private Node parseExpression() {
            Node node = parseTerm();

            while (pos < chars.length) {
                skipWhitespace();
                if (pos >= chars.length) break;

                char ch = chars[pos];
                if (ch == '+' || ch == '-') {
                    char op = ch;
                    advance();
                    Node right = parseTerm();
                    node = new BinaryOp(op, node, right);
                } else {
                    break;
                }
            }

            return node;
        }

        private Node parseTerm() {
            Node node = parseFactor();

            while (pos < chars.length) {
                skipWhitespace();
                if (pos >= chars.length) break;

                char ch = chars[pos];
                if (ch == '*' || ch == '/' || ch == '%') {
                    char op = ch;
                    advance();
                    Node right = parseFactor();
                    node = new BinaryOp(op, node, right);
                } else {
                    break;
                }
            }

            return node;
        }

        private Node parseFactor() {
            skipWhitespace();
            if (pos >= chars.length) return new Number(0);

            char ch = chars[pos];
            if (ch >= '0' && ch <= '9') {
                return parseNumber();
            } else if (ch >= 'a' && ch <= 'z') {
                return parseVariable();
            } else if (ch == '(') {
                advance();
                Node node = parseExpression();
                skipWhitespace();
                if (pos < chars.length && chars[pos] == ')') {
                    advance();
                }
                return node;
            } else {
                return new Number(0);
            }
        }

        private Node parseNumber() {
            long value = 0;
            while (pos < chars.length && chars[pos] >= '0' && chars[pos] <= '9') {
                value = value * 10 + (chars[pos] - '0');
                advance();
            }
            return new Number(value);
        }

        private Node parseVariable() {
            int start = pos;
            while (pos < chars.length &&
                    ((chars[pos] >= 'a' && chars[pos] <= 'z') ||
                     (chars[pos] >= '0' && chars[pos] <= '9'))) {
                advance();
            }
            String varName = input.substring(start, pos);

            skipWhitespace();
            if (pos < chars.length && chars[pos] == '=') {
                advance();
                Node expr = parseExpression();
                return new Assignment(varName, expr);
            }

            return new Variable(varName);
        }

        private void advance() {
            if (pos < chars.length) pos++;
        }

        private void skipWhitespace() {
            while (pos < chars.length && Character.isWhitespace(chars[pos])) {
                advance();
            }
        }
    }

    @Override
    public void run(int iterationId) {
        Parser parser = new Parser(text);
        parser.parse();
        expressions = parser.expressions;
        resultVal += expressions.size();

        if (!expressions.isEmpty() && expressions.get(expressions.size() - 1) instanceof Assignment) {
            Assignment assign = (Assignment) expressions.get(expressions.size() - 1);
            resultVal += Helper.checksum(assign.variable);
        }
    }

    @Override
    public long checksum() {
        return resultVal;
    }

    public List<Node> getExpressions() {
        return expressions;
    }
}