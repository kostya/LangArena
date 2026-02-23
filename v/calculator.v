module calculator

import benchmark
import helper
import strings
import math

pub enum NodeType {
	number
	variable
	binary_op
	assignment
}

pub struct Number {
pub:
	value i64
}

pub struct Variable {
pub:
	name string
}

pub struct BinaryOp {
pub:
	op    string
	left  &AstNode = unsafe { nil }
	right &AstNode = unsafe { nil }
}

pub struct Assignment {
pub:
	var  string
	expr &AstNode = unsafe { nil }
}

pub struct AstNode {
pub:
	typ NodeType
pub mut:
	number     Number
	variable   Variable
	binary_op  BinaryOp
	assignment Assignment
}

pub struct CalculatorAst {
	benchmark.BaseBenchmark
mut:
	result_val  u32
	n           i64
	text        string
	expressions []&AstNode
}

pub fn new_calculatorast() &benchmark.IBenchmark {
	mut bench := &CalculatorAst{
		BaseBenchmark: benchmark.new_base_benchmark('Calculator::Ast')
		result_val:    0
		n:             int(helper.config_i64('Calculator::Ast', 'operations'))
	}
	return bench
}

pub fn (b CalculatorAst) name() string {
	return 'Calculator::Ast'
}

struct Parser {
	input string
mut:
	pos          int
	current_char u8
	chars        []u8
	expressions  []&AstNode
}

fn new_parser(input_str string) Parser {
	mut chars := []u8{cap: input_str.len}
	for c in input_str {
		chars << u8(c)
	}

	mut current_char := u8(0)
	if chars.len > 0 {
		current_char = chars[0]
	}

	return Parser{
		input:        input_str
		pos:          0
		current_char: current_char
		chars:        chars
	}
}

fn (mut p Parser) advance() {
	p.pos += 1
	if p.pos >= p.chars.len {
		p.current_char = 0
	} else {
		p.current_char = p.chars[p.pos]
	}
}

fn (mut p Parser) skip_whitespace() {
	for p.current_char != 0 && (p.current_char == 32 || p.current_char == 9
		|| p.current_char == 10 || p.current_char == 13) {
		p.advance()
	}
}

fn (mut p Parser) parse_number() &AstNode {
	mut v := i64(0)
	for p.current_char != 0 && p.current_char >= `0` && p.current_char <= `9` {
		v = v * 10 + i64(p.current_char - `0`)
		p.advance()
	}
	return &AstNode{
		typ:    .number
		number: Number{v}
	}
}

fn (mut p Parser) parse_variable() &AstNode {
	start := p.pos
	for p.current_char != 0 && ((p.current_char >= `a` && p.current_char <= `z`)
		|| (p.current_char >= `A` && p.current_char <= `Z`)
		|| (p.current_char >= `0` && p.current_char <= `9`)) {
		p.advance()
	}

	var_name := p.input.substr(start, p.pos)

	p.skip_whitespace()
	if p.current_char == `=` {
		p.advance()
		expr := p.parse_expression()
		return &AstNode{
			typ:        .assignment
			assignment: Assignment{
				var:  var_name
				expr: expr
			}
		}
	}

	return &AstNode{
		typ:      .variable
		variable: Variable{var_name}
	}
}

fn (mut p Parser) parse_factor() &AstNode {
	p.skip_whitespace()
	if p.current_char == 0 {
		return &AstNode{
			typ:    .number
			number: Number{0}
		}
	}

	if p.current_char >= `0` && p.current_char <= `9` {
		return p.parse_number()
	}

	if (p.current_char >= `a` && p.current_char <= `z`)
		|| (p.current_char >= `A` && p.current_char <= `Z`) {
		return p.parse_variable()
	}

	if p.current_char == `(` {
		p.advance()
		node := p.parse_expression()
		p.skip_whitespace()
		if p.current_char == `)` {
			p.advance()
		}
		return node
	}

	return &AstNode{
		typ:    .number
		number: Number{0}
	}
}

fn (mut p Parser) parse_term() &AstNode {
	mut node := p.parse_factor()

	for {
		p.skip_whitespace()
		if p.current_char == 0 {
			break
		}

		if p.current_char == `*` || p.current_char == `/` || p.current_char == `%` {
			op := p.current_char.ascii_str()
			p.advance()
			right := p.parse_factor()
			node = &AstNode{
				typ:       .binary_op
				binary_op: BinaryOp{
					op:    op
					left:  node
					right: right
				}
			}
		} else {
			break
		}
	}

	return node
}

fn (mut p Parser) parse_expression() &AstNode {
	mut node := p.parse_term()

	for {
		p.skip_whitespace()
		if p.current_char == 0 {
			break
		}

		if p.current_char == `+` || p.current_char == `-` {
			op := p.current_char.ascii_str()
			p.advance()
			right := p.parse_term()
			node = &AstNode{
				typ:       .binary_op
				binary_op: BinaryOp{
					op:    op
					left:  node
					right: right
				}
			}
		} else {
			break
		}
	}

	return node
}

fn (mut p Parser) parse() []&AstNode {
	p.expressions.clear()
	for p.current_char != 0 {
		p.skip_whitespace()
		if p.current_char == 0 {
			break
		}
		p.expressions << p.parse_expression()
	}
	return p.expressions.clone()
}

fn generate_random_program(n i64) string {
	mut sb := strings.new_builder(1000)
	sb.write_string('v0 = 1\n')

	for i in 0 .. 10 {
		v := i + 1
		sb.write_string('v${v} = v${v - 1} + ${v}\n')
	}

	for i in 0 .. n {
		v := int(i) + 10
		sb.write_string('v${v} = v${v - 1} + ')

		match helper.next_int(10) {
			0 {
				sb.write_string('(v${v - 1} / 3) * 4 - ${i} / (3 + (18 - v${v - 2})) % v${v - 3} + 2 * ((9 - v${v - 6}) * (v${v - 5} + 7))')
			}
			1 {
				sb.write_string('v${v - 1} + (v${v - 2} + v${v - 3}) * v${v - 4} - (v${v - 5} / v${v - 6})')
			}
			2 {
				sb.write_string('(3789 - (((v${v - 7})))) + 1')
			}
			3 {
				sb.write_string('4/2 * (1-3) + v${v - 9}/v${v - 5}')
			}
			4 {
				sb.write_string('1+2+3+4+5+6+v${v - 1}')
			}
			5 {
				sb.write_string('(99999 / v${v - 3})')
			}
			6 {
				sb.write_string('0 + 0 - v${v - 8}')
			}
			7 {
				sb.write_string('((((((((((v${v - 6})))))))))) * 2')
			}
			8 {
				sb.write_string('${i} * (v${v - 1}%6)%7')
			}
			9 {
				sb.write_string('(1)/(0-v${v - 5}) + (v${v - 7})')
			}
			else {
				sb.write_string('0')
			}
		}
		sb.write_string('\n')
	}

	return sb.str()
}

pub fn (mut b CalculatorAst) prepare() {
	b.text = generate_random_program(b.n)
}

pub fn (mut b CalculatorAst) run(iteration_id int) {
	mut parser := new_parser(b.text)
	b.expressions = parser.parse()
	b.result_val += u32(b.expressions.len)

	if b.expressions.len > 0 {
		node := b.expressions[b.expressions.len - 1]
		if node.typ == .assignment {
			b.result_val += helper.checksum_str(node.assignment.var)
		}
	}
}

pub fn (b CalculatorAst) checksum() u32 {
	return b.result_val
}

pub struct CalculatorInterpreter {
	benchmark.BaseBenchmark
mut:
	result_val u32
	n          i64
	ast        []&AstNode
}

pub fn new_calculatorinterpreter() &benchmark.IBenchmark {
	mut bench := &CalculatorInterpreter{
		BaseBenchmark: benchmark.new_base_benchmark('Calculator::Interpreter')
		result_val:    0
		n:             0
	}
	return bench
}

pub fn (b CalculatorInterpreter) name() string {
	return 'Calculator::Interpreter'
}

struct Interpreter {
mut:
	variables map[string]i64
}

fn simple_div(a i64, b i64) i64 {
	if b == 0 {
		return 0
	}
	if (a >= 0 && b > 0) || (a < 0 && b < 0) {
		return a / b
	} else {
		return -(i64(math.abs(a)) / i64(math.abs(b)))
	}
}

fn simple_mod(a i64, b i64) i64 {
	if b == 0 {
		return 0
	}
	return a - simple_div(a, b) * b
}

fn evaluate_node(node &AstNode, mut variables map[string]i64) i64 {
	match node.typ {
		.number {
			return node.number.value
		}
		.variable {
			return variables[node.variable.name] or { 0 }
		}
		.binary_op {
			left := evaluate_node(node.binary_op.left, mut variables)
			right := evaluate_node(node.binary_op.right, mut variables)

			match node.binary_op.op {
				'+' {
					return left + right
				}
				'-' {
					return left - right
				}
				'*' {
					return left * right
				}
				'/' {
					return simple_div(left, right)
				}
				'%' {
					return simple_mod(left, right)
				}
				else {
					return 0
				}
			}
		}
		.assignment {
			value := evaluate_node(node.assignment.expr, mut variables)
			variables[node.assignment.var] = value
			return value
		}
	}
}

fn (mut interpreter Interpreter) run(expressions []&AstNode) i64 {
	mut result := i64(0)

	for expr in expressions {
		result = evaluate_node(expr, mut interpreter.variables)
	}

	return result
}

fn (mut interpreter Interpreter) clear() {
	interpreter.variables.clear()
}

pub fn (mut b CalculatorInterpreter) prepare() {
	b.n = int(helper.config_i64('Calculator::Interpreter', 'operations'))

	mut ca := CalculatorAst{
		BaseBenchmark: benchmark.new_base_benchmark('Calculator::Ast')
		n:             b.n
	}
	ca.prepare()
	ca.run(0)
	b.ast = ca.expressions
}

pub fn (mut b CalculatorInterpreter) run(iteration_id int) {
	mut interpreter := Interpreter{
		variables: map[string]i64{}
	}
	result := interpreter.run(b.ast)
	b.result_val += u32(result)
}

pub fn (b CalculatorInterpreter) checksum() u32 {
	return b.result_val
}
