module calculator;

import benchmark;
import helper;
import std::io;
import std::collections::map;

const char CHAR_EOF     = 0;
const char CHAR_PLUS    = '+';
const char CHAR_MINUS   = '-';
const char CHAR_STAR    = '*';
const char CHAR_SLASH   = '/';
const char CHAR_PERCENT = '%';
const char CHAR_LPAREN  = '(';
const char CHAR_RPAREN  = ')';
const char CHAR_EQUALS  = '=';
const char CHAR_ZERO    = '0';
const char CHAR_NINE    = '9';
const char CHAR_A_LOWER = 'a';
const char CHAR_Z_LOWER = 'z';
const char CHAR_A_UPPER = 'A';
const char CHAR_Z_UPPER = 'Z';
const char CHAR_SPACE   = ' ';
const char CHAR_TAB     = '\t';
const char CHAR_NEWLINE = '\n';
const char CHAR_CR      = '\r';

enum AstNodeType
{
	AST_NUMBER,
	AST_VARIABLE,
	AST_BINARY_OP,
	AST_ASSIGNMENT,
}

struct AstBinaryOp
{
	char op;
	AstNode* left;
	AstNode* right;
}

struct AstAssignment
{
	String var_name;
	AstNode* expr;
}

struct AstNode
{
	AstNodeType type;
	union
	{
		long number_value;
		String variable_name;
		AstBinaryOp* binary_op;
		AstAssignment* assignment;
	}
}

fn AstNode* ast_node_new_number(long value)
{
	AstNode* node = mem::new(AstNode);
	node.type = AST_NUMBER;
	node.number_value = value;
	return node;
}

fn AstNode* ast_node_new_variable(String name)
{
	AstNode* node = mem::new(AstNode);
	node.type = AST_VARIABLE;
	node.variable_name = name;
	return node;
}

fn AstNode* ast_node_new_binary_op(char op, AstNode* left, AstNode* right)
{
	AstBinaryOp* binary_op = mem::new(AstBinaryOp);
	binary_op.op = op;
	binary_op.left = left;
	binary_op.right = right;

	AstNode* node = mem::new(AstNode);
	node.type = AST_BINARY_OP;
	node.binary_op = binary_op;
	return node;
}

fn AstNode* ast_node_new_assignment(String var_name, AstNode* expr)
{
	AstAssignment* assignment = mem::new(AstAssignment);
	assignment.var_name = var_name;
	assignment.expr = expr;

	AstNode* node = mem::new(AstNode);
	node.type = AST_ASSIGNMENT;
	node.assignment = assignment;
	return node;
}

fn void ast_node_free(AstNode* node)
{
	if (!node) return;

	switch (node.type)
	{
		case AST_BINARY_OP:
			if (node.binary_op)
			{
				ast_node_free(node.binary_op.left);
				ast_node_free(node.binary_op.right);
				free(node.binary_op);
			}
			break;
		case AST_ASSIGNMENT:
			if (node.assignment)
			{
				ast_node_free(node.assignment.expr);
				free(node.assignment);
			}
			break;
		default:
			break;
	}
	free(node);
}

struct CalculatorAstParser
{
	String input;
	usz pos;
	usz len;
	char current_char;
}

fn void parser_init(CalculatorAstParser* parser, String input)
{
	parser.input = input;
	parser.pos = 0;
	parser.len = input.len;
	parser.current_char = parser.len > 0 ? input[0] : CHAR_EOF;
}

fn bool is_digit(char c)
{
	return c >= CHAR_ZERO && c <= CHAR_NINE;
}

fn bool is_letter(char c)
{
	return (c >= CHAR_A_LOWER && c <= CHAR_Z_LOWER) || (c >= CHAR_A_UPPER && c <= CHAR_Z_UPPER);
}

fn bool is_whitespace(char c)
{
	return c == CHAR_SPACE || c == CHAR_TAB || c == CHAR_NEWLINE || c == CHAR_CR;
}

fn void parser_advance(CalculatorAstParser* parser)
{
	parser.pos++;
	if (parser.pos >= parser.len)
	{
		parser.current_char = CHAR_EOF;
	}
	else
	{
		parser.current_char = parser.input[parser.pos];
	}
}

fn void parser_skip_whitespace(CalculatorAstParser* parser)
{
	while (is_whitespace(parser.current_char))
	{
		parser_advance(parser);
	}
}

fn AstNode* parser_parse_number(CalculatorAstParser* parser)
{
	long value = 0;
	while (is_digit(parser.current_char))
	{
		value = value * 10 + (long)(parser.current_char - CHAR_ZERO);
		parser_advance(parser);
	}
	return ast_node_new_number(value);
}

fn AstNode* parser_parse_variable(CalculatorAstParser* parser)
{
	usz start = parser.pos;
	while (is_letter(parser.current_char) || is_digit(parser.current_char))
	{
		parser_advance(parser);
	}

	usz len         = parser.pos - start;
	String var_name = parser.input[start:len];

	parser_skip_whitespace(parser);

	if (parser.current_char == CHAR_EQUALS)
	{
		parser_advance(parser);
		AstNode* expr = parser_parse_expression(parser);
		return ast_node_new_assignment(var_name, expr);
	}

	return ast_node_new_variable(var_name);
}

fn AstNode* parser_parse_expression(CalculatorAstParser* parser)
{
	AstNode* node = parser_parse_term(parser);

	while (true)
	{
		parser_skip_whitespace(parser);

		if (parser.current_char == CHAR_PLUS || parser.current_char == CHAR_MINUS)
		{
			char op = parser.current_char;
			parser_advance(parser);
			AstNode* right = parser_parse_term(parser);
			node = ast_node_new_binary_op(op, node, right);
		}
		else
		{
			break;
		}
	}

	return node;
}

fn AstNode* parser_parse_factor(CalculatorAstParser* parser)
{
	parser_skip_whitespace(parser);

	if (is_digit(parser.current_char))
	{
		return parser_parse_number(parser);
	}
	if (is_letter(parser.current_char))
	{
		return parser_parse_variable(parser);
	}

	if (parser.current_char == CHAR_LPAREN)
	{
		parser_advance(parser);
		AstNode* node = parser_parse_expression(parser);
		parser_skip_whitespace(parser);
		if (parser.current_char == CHAR_RPAREN)
		{
			parser_advance(parser);
		}
		return node;
	}

	parser_advance(parser);
	return ast_node_new_number(0);
}

fn AstNode* parser_parse_term(CalculatorAstParser* parser)
{
	AstNode* node = parser_parse_factor(parser);

	while (true)
	{
		parser_skip_whitespace(parser);

		if (parser.current_char == CHAR_STAR || parser.current_char == CHAR_SLASH
			|| parser.current_char == CHAR_PERCENT)
		{
			char op = parser.current_char;
			parser_advance(parser);
			AstNode* right = parser_parse_factor(parser);
			node = ast_node_new_binary_op(op, node, right);
		}
		else
		{
			break;
		}
	}

	return node;
}

fn void parser_parse_all(CalculatorAstParser* parser, CalculatorAstData* data)
{
	while (parser.current_char != CHAR_EOF)
	{
		parser_skip_whitespace(parser);
		if (parser.current_char == CHAR_EOF) break;

		if (data.expressions_count >= data.expressions_capacity)
		{
			data.expressions_capacity = data.expressions_capacity ? data.expressions_capacity * 2 : 16;
			data.expressions = mem::realloc(data.expressions, data.expressions_capacity * void*::size);
		}

		data.expressions[data.expressions_count] = parser_parse_expression(parser);
		data.expressions_count++;

		parser_skip_whitespace(parser);
		while (parser.current_char == CHAR_NEWLINE)
		{
			parser_advance(parser);
			parser_skip_whitespace(parser);
		}
	}
}

fn char[] generate_random_program(long operations)
{
	DString result;
	result.init(mem, (usz)(operations * 100 + 256));

	result.append("v0 = 1\n");

	for (int i = 0; i < 10; i++)
	{
		result.appendf("v%d = v%d + %d\n", i + 1, i, i + 1);
	}

	for (long i = 0; i < operations; i++)
	{
		int v = (int)(i + 10);
		result.appendf("v%d = v%d + ", v, v - 1);

		switch ((int)helper::helper_next_int(10))
		{
			case 0:
				result.appendf(
					"(v%d / 3) * 4 - %d / (3 + (18 - v%d)) %% v%d + 2 * ((9 - v%d) * (v%d + 7))",
					v - 1,
					(int)i,
					v - 2,
					v - 3,
					v - 6,
					v - 5
				);
				break;
			case 1:
				result.appendf("v%d + (v%d + v%d) * v%d - (v%d / v%d)", v - 1, v - 2, v - 3, v - 4, v - 5, v - 6);
				break;
			case 2:
				result.appendf("(3789 - (((v%d)))) + 1", v - 7);
				break;
			case 3:
				result.appendf("4/2 * (1-3) + v%d/v%d", v - 9, v - 5);
				break;
			case 4:
				result.appendf("1+2+3+4+5+6+v%d", v - 1);
				break;
			case 5:
				result.appendf("(99999 / v%d)", v - 3);
				break;
			case 6:
				result.appendf("0 + 0 - v%d", v - 8);
				break;
			case 7:
				result.appendf("((((((((((v%d)))))))))) * 2", v - 6);
				break;
			case 8:
				result.appendf("%d * (v%d%%6)%%7", (int)i, v - 1);
				break;
			case 9:
				result.appendf("(1)/(0-v%d) + (v%d)", v - 5, v - 7);
				break;
		}
		result.append("\n");
	}

	return result.copy_str(mem);
}

struct CalculatorAstData
{
	AstNode** expressions;
	long expressions_count;
	long expressions_capacity;
	uint result_val;
	char[] text;
	long operations;
}

fn void calculator_ast_prepare(Benchmark* self)
{
	CalculatorAstData* data = (CalculatorAstData*)self.data;

	data.operations = helper::helper_config_i64(self.name, "operations");
	if (data.operations <= 0)
	{
		data.operations = 1000;
	}

	data.text = generate_random_program(data.operations);
}

fn void calculator_ast_run(Benchmark* self, int iteration_id)
{
	CalculatorAstData* data = (CalculatorAstData*)self.data;

	if (data.expressions)
	{
		for (long i = 0; i < data.expressions_count; i++)
		{
			ast_node_free(data.expressions[i]);
		}
		free(data.expressions);
		data.expressions = null;
		data.expressions_count = 0;
		data.expressions_capacity = 0;
	}

	CalculatorAstParser parser;
	parser_init(&parser, (String)data.text);
	parser_parse_all(&parser, data);

	uint iteration_result = (uint)data.expressions_count;

	if (data.expressions_count > 0 && data.expressions[data.expressions_count - 1].type == AST_ASSIGNMENT)
	{
		AstNode* last = data.expressions[data.expressions_count - 1];
		iteration_result += helper::helper_checksum_string(last.assignment.var_name);
	}

	data.result_val += iteration_result;
}

fn uint calculator_ast_checksum(Benchmark* self)
{
	return ((CalculatorAstData*)self.data).result_val;
}

fn void calculator_ast_cleanup(Benchmark* self)
{
	CalculatorAstData* data = (CalculatorAstData*)self.data;

	if (data.text.len > 0)
	{
		free(data.text);
		data.text = { };
	}

	if (data.expressions)
	{
		for (long i = 0; i < data.expressions_count; i++)
		{
			ast_node_free(data.expressions[i]);
		}
		free(data.expressions);
		data.expressions = null;
	}
}

fn Benchmark* calculator_ast_create() @cname("CalculatorAst_create") @export
{
	Benchmark* bench        = benchmark::benchmark_create("Calculator::Ast");
	CalculatorAstData* data = mem::new(CalculatorAstData);

	bench.data = data;
	bench.prepare = (PrepareFn)&calculator_ast_prepare;
	bench.run = (RunFn)&calculator_ast_run;
	bench.checksum = (ChecksumFn)&calculator_ast_checksum;
	bench.cleanup = (CleanupFn)&calculator_ast_cleanup;

	return bench;
}

alias VariableMap = HashMap{String, long};

struct CalculatorInterpreterContext
{
	VariableMap variables;
}

fn CalculatorInterpreterContext* interpreter_context_new()
{
	CalculatorInterpreterContext* ctx = mem::new(CalculatorInterpreterContext);
	ctx.variables.init(mem);
	return ctx;
}

fn void interpreter_context_free(CalculatorInterpreterContext* ctx)
{
	ctx.variables.free();
	free(ctx);
}

fn long interpreter_simple_div(long a, long b)
{
	if (b == 0) return 0;
	if ((a >= 0 && b > 0) || (a < 0 && b < 0)) return a / b;
	long abs_a = a >= 0 ? a : -a;
	long abs_b = b >= 0 ? b : -b;
	return -(abs_a / abs_b);
}

fn long interpreter_simple_mod(long a, long b)
{
	if (b == 0) return 0;
	return a - interpreter_simple_div(a, b) * b;
}

fn long interpreter_evaluate(AstNode* node, CalculatorInterpreterContext* ctx)
{
	switch (node.type)
	{
		case AST_NUMBER:
			return node.number_value;

		case AST_VARIABLE:
			if (try val = ctx.variables.get(node.variable_name)) return val;
			return 0;

		case AST_BINARY_OP:
			AstBinaryOp* binop = node.binary_op;
			long left = interpreter_evaluate(binop.left, ctx);
			long right = interpreter_evaluate(binop.right, ctx);

			switch (binop.op)
			{
				case '+': return left + right;
				case '-': return left - right;
				case '*': return left * right;
				case '/': return interpreter_simple_div(left, right);
				case '%': return interpreter_simple_mod(left, right);
				default: return 0;
			}

		case AST_ASSIGNMENT:
			AstAssignment* assign = node.assignment;
			long value = interpreter_evaluate(assign.expr, ctx);
			ctx.variables.set(assign.var_name, value);
			return value;
	}
}

struct CalculatorInterpreterData
{
	CalculatorAstData ast_data;
	uint result_val;
}

fn void calculator_interpreter_prepare(Benchmark* self)
{
	CalculatorInterpreterData* data = (CalculatorInterpreterData*)self.data;

	data.ast_data.operations = helper::helper_config_i64(self.name, "operations");
	if (data.ast_data.operations <= 0)
	{
		data.ast_data.operations = 1000;
	}

	data.ast_data.text = generate_random_program(data.ast_data.operations);

	CalculatorAstParser parser;
	parser_init(&parser, (String)data.ast_data.text);
	parser_parse_all(&parser, &data.ast_data);
}

fn void calculator_interpreter_run(Benchmark* self, int iteration_id)
{
	CalculatorInterpreterData* data = (CalculatorInterpreterData*)self.data;

	CalculatorInterpreterContext* ctx = interpreter_context_new();
	long iteration_result             = 0;

	for (long i = 0; i < data.ast_data.expressions_count; i++)
	{
		iteration_result = interpreter_evaluate(data.ast_data.expressions[i], ctx);
	}

	interpreter_context_free(ctx);
	data.result_val += (uint)iteration_result;
}

fn uint calculator_interpreter_checksum(Benchmark* self)
{
	return ((CalculatorInterpreterData*)self.data).result_val;
}

fn void calculator_interpreter_cleanup(Benchmark* self)
{
	CalculatorInterpreterData* data = (CalculatorInterpreterData*)self.data;

	if (data.ast_data.text.len > 0)
	{
		free(data.ast_data.text);
		data.ast_data.text = { };
	}

	if (data.ast_data.expressions)
	{
		for (long i = 0; i < data.ast_data.expressions_count; i++)
		{
			ast_node_free(data.ast_data.expressions[i]);
		}
		free(data.ast_data.expressions);
		data.ast_data.expressions = null;
	}
}

fn Benchmark* calculator_interpreter_create() @cname("CalculatorInterpreter_create") @export
{
	Benchmark* bench                = benchmark::benchmark_create("Calculator::Interpreter");
	CalculatorInterpreterData* data = mem::new(CalculatorInterpreterData);

	bench.data = data;
	bench.prepare = (PrepareFn)&calculator_interpreter_prepare;
	bench.run = (RunFn)&calculator_interpreter_run;
	bench.checksum = (ChecksumFn)&calculator_interpreter_checksum;
	bench.cleanup = (CleanupFn)&calculator_interpreter_cleanup;

	return bench;
}