from std.memory import Pointer
from std.memory.alloc import unsafe_alloc
from helper import Helper
from benchmark import Benchmark, Config

comptime CHAR_EOF = Byte(0)
comptime CHAR_PLUS = Byte(ord("+"))
comptime CHAR_MINUS = Byte(ord("-"))
comptime CHAR_STAR = Byte(ord("*"))
comptime CHAR_SLASH = Byte(ord("/"))
comptime CHAR_PERCENT = Byte(ord("%"))
comptime CHAR_LPAREN = Byte(ord("("))
comptime CHAR_RPAREN = Byte(ord(")"))
comptime CHAR_EQUALS = Byte(ord("="))
comptime CHAR_ZERO = Byte(ord("0"))
comptime CHAR_NINE = Byte(ord("9"))
comptime CHAR_A_LOWER = Byte(ord("a"))
comptime CHAR_Z_LOWER = Byte(ord("z"))
comptime CHAR_A_UPPER = Byte(ord("A"))
comptime CHAR_Z_UPPER = Byte(ord("Z"))
comptime CHAR_SPACE = Byte(ord(" "))
comptime CHAR_TAB = Byte(ord("\t"))
comptime CHAR_NEWLINE = Byte(ord("\n"))
comptime CHAR_CR = Byte(ord("\r"))

comptime CALC_NUMBER = 0
comptime CALC_VARIABLE = 1
comptime CALC_BINARY = 2
comptime CALC_ASSIGN = 3


struct _CalcNode:
    comptime _NodePointer = Optional[Pointer[_CalcNode, MutUntrackedOrigin]]

    var kind: Int
    var value: Int
    var name: String
    var op: Byte
    var left: Self._NodePointer
    var right: Self._NodePointer

    def __init__(out self, kind: Int):
        self.kind = kind
        self.value = 0
        self.name = ""
        self.op = 0
        self.left = Self._NodePointer()
        self.right = Self._NodePointer()

    def __deinit__(deinit self):
        if self.left:
            var nn = self.left.value()
            nn.unsafe_deinit_pointee()
            nn.unsafe_free()
        if self.right:
            var nn = self.right.value()
            nn.unsafe_deinit_pointee()
            nn.unsafe_free()


struct _CalcParser:
    var input: String
    var pos: Int
    var length: Int
    var current_byte: Byte
    var expressions: List[Pointer[_CalcNode, MutUntrackedOrigin]]

    def __init__(out self, text: String):
        self.input = text
        self.pos = 0
        self.length = text.byte_length()
        self.expressions = List[Pointer[_CalcNode, MutUntrackedOrigin]]()

        self.current_byte = (
            self.input.as_bytes()[0] if self.length > 0 else CHAR_EOF
        )

    def __deinit__(deinit self):
        for i in range(len(self.expressions)):
            var node = self.expressions[i]
            node.unsafe_deinit_pointee()
            node.unsafe_free()

    def parse(mut self):
        while self.current_byte != CHAR_EOF:
            self._skip_whitespace()
            if self.current_byte == CHAR_EOF:
                break
            self.expressions.append(self._parse_expression())
            self._skip_whitespace()
            while self.current_byte == CHAR_NEWLINE:
                self._advance()
                self._skip_whitespace()

    def _parse_expression(mut self) -> Pointer[_CalcNode, MutUntrackedOrigin]:
        var node = self._parse_term()
        return self._parse_expression_rest(node)

    def _parse_expression_rest(
        mut self, node: Pointer[_CalcNode, MutUntrackedOrigin]
    ) -> Pointer[_CalcNode, MutUntrackedOrigin]:
        var current_node = node

        while True:
            self._skip_whitespace()

            if (
                self.current_byte == CHAR_PLUS
                or self.current_byte == CHAR_MINUS
            ):
                var op = self.current_byte
                self._advance()
                var right = self._parse_term()
                var new_node = unsafe_alloc[_CalcNode](1)
                new_node.unsafe_write(_CalcNode(CALC_BINARY))
                new_node[].op = op
                new_node[].left = current_node
                new_node[].right = right
                current_node = new_node
            else:
                break

        return current_node

    def _parse_term(mut self) -> Pointer[_CalcNode, MutUntrackedOrigin]:
        var node = self._parse_factor()
        return self._parse_term_rest(node)

    def _parse_term_rest(
        mut self, node: Pointer[_CalcNode, MutUntrackedOrigin]
    ) -> Pointer[_CalcNode, MutUntrackedOrigin]:
        var current_node = node

        while True:
            self._skip_whitespace()

            if (
                self.current_byte == CHAR_STAR
                or self.current_byte == CHAR_SLASH
                or self.current_byte == CHAR_PERCENT
            ):
                var op = self.current_byte
                self._advance()
                var right = self._parse_factor()
                var new_node = unsafe_alloc[_CalcNode](1)
                new_node.unsafe_write(_CalcNode(CALC_BINARY))
                new_node[].op = op
                new_node[].left = current_node
                new_node[].right = right
                current_node = new_node
            else:
                break

        return current_node

    def _parse_factor(mut self) -> Pointer[_CalcNode, MutUntrackedOrigin]:
        self._skip_whitespace()

        if self._is_digit(self.current_byte):
            return self._parse_number()
        elif self._is_letter(self.current_byte):
            return self._parse_variable()
        elif self.current_byte == CHAR_LPAREN:
            self._advance()
            var node = self._parse_expression()
            self._skip_whitespace()
            if self.current_byte == CHAR_RPAREN:
                self._advance()
            return node

        self._advance()
        return self._add_number(0)

    def _parse_number(mut self) -> Pointer[_CalcNode, MutUntrackedOrigin]:
        var v: Int = 0
        while self._is_digit(self.current_byte):
            v = v * 10 + Int(self.current_byte - CHAR_ZERO)
            self._advance()
        return self._add_number(v)

    def _parse_variable(mut self) -> Pointer[_CalcNode, MutUntrackedOrigin]:
        var start = self.pos
        while self._is_letter(self.current_byte) or self._is_digit(
            self.current_byte
        ):
            self._advance()

        var var_name = String(self.input[byte = start : self.pos])

        self._skip_whitespace()
        if self.current_byte == CHAR_EQUALS:
            self._advance()
            var expr = self._parse_expression()
            var node = unsafe_alloc[_CalcNode](1)
            node.unsafe_write(_CalcNode(CALC_ASSIGN))
            node[].name = var_name
            node[].left = expr
            return node

        var node = unsafe_alloc[_CalcNode](1)
        node.unsafe_write(_CalcNode(CALC_VARIABLE))
        node[].name = var_name
        return node

    def _add_number(mut self, v: Int) -> Pointer[_CalcNode, MutUntrackedOrigin]:
        var node = unsafe_alloc[_CalcNode](1)
        node.unsafe_write(_CalcNode(CALC_NUMBER))
        node[].value = v
        return node

    def _advance(mut self):
        self.pos += 1
        if self.pos >= self.length:
            self.current_byte = CHAR_EOF
        else:
            self.current_byte = self.input.as_bytes()[self.pos]

    def _skip_whitespace(mut self):
        while self._is_whitespace(self.current_byte):
            self._advance()

    @staticmethod
    def _is_digit(byte: Byte) -> Bool:
        return byte >= CHAR_ZERO and byte <= CHAR_NINE

    @staticmethod
    def _is_letter(byte: Byte) -> Bool:
        return (byte >= CHAR_A_LOWER and byte <= CHAR_Z_LOWER) or (
            byte >= CHAR_A_UPPER and byte <= CHAR_Z_UPPER
        )

    @staticmethod
    def _is_whitespace(byte: Byte) -> Bool:
        return (
            byte == CHAR_SPACE
            or byte == CHAR_TAB
            or byte == CHAR_NEWLINE
            or byte == CHAR_CR
        )


struct CalculatorAst(Benchmark):
    var n: Int
    var text: String
    var parser: _CalcParser
    var result: UInt32

    def __init__(out self, config: Config) raises:
        self.n = config.get_i64("Calculator::Ast", "operations")
        self.text = ""
        self.parser = _CalcParser("")
        self.result = 0

    def class_name(self) -> String:
        return "Calculator::Ast"

    def prepare(mut self, mut helper: Helper) raises:
        self.text = Self._generate_random_program(self.n, helper)

    def run(mut self, iteration_id: Int, mut helper: Helper) raises:
        self.parser = _CalcParser(self.text)
        self.parser.parse()
        self.result += UInt32(len(self.parser.expressions))

        if len(self.parser.expressions) > 0:
            var last = self.parser.expressions[len(self.parser.expressions) - 1]
            ref last_node = last[]
            if last_node.kind == CALC_ASSIGN:
                self.result += Helper.checksum_string(last_node.name)

    def checksum(self) -> UInt32:
        return self.result

    @staticmethod
    def _generate_random_program(n: Int, mut helper: Helper) -> String:
        var result = "v0 = 1\n"

        for v in range(1, 11):
            result += String(t"v{v} = v{v - 1} + {v}\n")

        for i in range(n):
            var v = i + 10
            result += String(t"v{v} = v{v - 1} + ")

            var operation = helper.next_int(10)
            if operation == 0:
                result += String(
                    t"(v{v - 1} / 3) * 4 - {i}"
                    t" / (3 + (18 - v{v - 2})) % v{v - 3}"
                    t" + 2 * ((9 - v{v - 6}) * (v{v - 5} + 7))"
                )
            elif operation == 1:
                result += String(
                    t"v{v - 1} + (v{v - 2} + v{v - 3}) * v{v - 4}"
                    t" - (v{v - 5} /  v{v - 6})"
                )
            elif operation == 2:
                result += String(t"(3789 - (((v{v - 7})))) + 1")
            elif operation == 3:
                result += String(t"4/2 * (1-3) + v{v - 9}/v{v - 5}")
            elif operation == 4:
                result += String(t"1+2+3+4+5+6+v{v - 1}")
            elif operation == 5:
                result += String(t"(99999 / v{v - 3})")
            elif operation == 6:
                result += String(t"0 + 0 - v{v - 8}")
            elif operation == 7:
                result += String(t"((((((((((v{v - 6})))))))))) * 2")
            elif operation == 8:
                result += String(t"{i} * (v{v - 1}%6)%7")
            elif operation == 9:
                result += String(t"(1)/(0-v{v - 5}) + (v{v - 7})")

            result += "\n"

        return result


struct CalculatorInterpreter(Benchmark):
    var n: Int
    var parser: _CalcParser
    var result: UInt32

    def __init__(out self, config: Config) raises:
        self.n = config.get_i64("Calculator::Interpreter", "operations")
        self.parser = _CalcParser("")
        self.result = 0

    def class_name(self) -> String:
        return "Calculator::Interpreter"

    def prepare(mut self, mut helper: Helper) raises:
        var text = CalculatorAst._generate_random_program(self.n, helper)
        self.parser = _CalcParser(text)
        self.parser.parse()

    def run(mut self, iteration_id: Int, mut helper: Helper) raises:
        var variables = Dict[String, Int]()

        var result: Int = 0
        for i in range(len(self.parser.expressions)):
            result = self._evaluate(self.parser.expressions[i][], variables)

        self.result += UInt32(result)

    def checksum(self) -> UInt32:
        return self.result

    @staticmethod
    def _simple_div(a: Int, b: Int) -> Int:
        if b == 0:
            return 0
        if (a >= 0 and b > 0) or (a < 0 and b < 0):
            return a // b
        else:
            var abs_a = a if a >= 0 else -a
            var abs_b = b if b >= 0 else -b
            return -(abs_a // abs_b)

    @staticmethod
    def _simple_mod(a: Int, b: Int) -> Int:
        if b == 0:
            return 0
        return a - Self._simple_div(a, b) * b

    def _evaluate(
        mut self, node: _CalcNode, mut variables: Dict[String, Int]
    ) -> Int:
        if node.kind == CALC_NUMBER:
            return node.value
        elif node.kind == CALC_VARIABLE:
            return variables.get(node.name).or_else(0)
        elif node.kind == CALC_BINARY:
            var left = self._evaluate(node.left.value()[], variables)
            var right = self._evaluate(node.right.value()[], variables)
            if node.op == Byte(ord("+")):
                return left + right
            elif node.op == Byte(ord("-")):
                return left - right
            elif node.op == Byte(ord("*")):
                return left * right
            elif node.op == Byte(ord("/")):
                return Self._simple_div(left, right)
            elif node.op == Byte(ord("%")):
                return Self._simple_mod(left, right)
            return 0
        elif node.kind == CALC_ASSIGN:
            var value = self._evaluate(node.left.value()[], variables)
            variables[node.name] = value
            return value

        return 0
