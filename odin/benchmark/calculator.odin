package benchmark

import "core:fmt"
import "core:strconv"
import "core:strings"
import "core:mem"
import "core:mem/virtual"
import "core:slice"

Number :: struct {
    value: i64,
}

Variable :: struct {
    name: string,
}

BinaryOp :: struct {
    op:    u8,  
    left:  ^CalcNode,
    right: ^CalcNode,
}

Assignment :: struct {
    var:  string,
    expr: ^CalcNode,
}

Node_Data :: union {
    Number,
    Variable,
    ^BinaryOp,
    ^Assignment,
}

CalcNode :: struct {
    data: Node_Data,
}

AST :: struct {
    nodes:       [dynamic]^CalcNode,
    arena:       virtual.Arena,
}

ast_create :: proc() -> AST {
    ast: AST
    err := virtual.arena_init_growing(&ast.arena)
    if err != nil {
        fmt.println("ERROR: failed to initialize arena")
    }
    ast.nodes = make([dynamic]^CalcNode)
    return ast
}

ast_destroy :: proc(ast: ^AST) {
    virtual.arena_destroy(&ast.arena)
    delete(ast.nodes)
}

ast_reset :: proc(ast: ^AST) {
    virtual.arena_free_all(&ast.arena)
    clear(&ast.nodes)
}

ast_allocator :: proc(ast: ^AST) -> mem.Allocator {
    return virtual.arena_allocator(&ast.arena)
}

ast_new_node :: proc(ast: ^AST) -> ^CalcNode {
    return new(CalcNode, ast_allocator(ast))
}

ast_new_binary_op :: proc(ast: ^AST) -> ^BinaryOp {
    return new(BinaryOp, ast_allocator(ast))
}

ast_new_assignment :: proc(ast: ^AST) -> ^Assignment {
    return new(Assignment, ast_allocator(ast))
}

Parser :: struct {
    input:        string,
    pos:          int,
    current_char: u8,
    expressions:  [dynamic]^CalcNode,
    ast:          ^AST,
}

parser_init :: proc(p: ^Parser, input_str: string, ast: ^AST) {
    p.input = input_str
    p.pos = 0
    p.ast = ast
    p.expressions = make([dynamic]^CalcNode)
    p.current_char = len(p.input) > 0 ? p.input[0] : 0
}

parser_destroy :: proc(p: ^Parser) {
    delete(p.expressions)
}

parser_advance :: proc(p: ^Parser) {
    p.pos += 1
    p.current_char = p.pos < len(p.input) ? p.input[p.pos] : 0
}

parser_skip_whitespace :: proc(p: ^Parser) {
    for p.current_char != 0 && (p.current_char == ' ' || 
                                 p.current_char == '\t' || 
                                 p.current_char == '\n' || 
                                 p.current_char == '\r') {
        parser_advance(p)
    }
}

parser_parse_number :: proc(p: ^Parser) -> ^CalcNode {
    v: i64 = 0
    for p.current_char != 0 && p.current_char >= '0' && p.current_char <= '9' {
        v = v * 10 + i64(p.current_char - '0')
        parser_advance(p)
    }

    node := ast_new_node(p.ast)
    node.data = Number{value = v}
    return node
}

parser_parse_variable :: proc(p: ^Parser) -> ^CalcNode {
    start := p.pos
    for p.current_char != 0 && 
        ((p.current_char >= 'a' && p.current_char <= 'z') ||
         (p.current_char >= 'A' && p.current_char <= 'Z') ||
         (p.current_char >= '0' && p.current_char <= '9')) {
        parser_advance(p)
    }

    var_name := p.input[start:p.pos]

    parser_skip_whitespace(p)
    if p.current_char == '=' {
        parser_advance(p)
        parser_skip_whitespace(p)
        expr := parser_parse_expression(p)

        node := ast_new_node(p.ast)
        assign := ast_new_assignment(p.ast)
        assign.var = strings.clone(var_name, ast_allocator(p.ast))
        assign.expr = expr
        node.data = assign
        return node
    }

    node := ast_new_node(p.ast)
    node.data = Variable{name = strings.clone(var_name, ast_allocator(p.ast))}
    return node
}

parser_parse_factor :: proc(p: ^Parser) -> ^CalcNode {
    parser_skip_whitespace(p)
    if p.current_char == 0 {
        node := ast_new_node(p.ast)
        node.data = Number{value = 0}
        return node
    }

    if p.current_char >= '0' && p.current_char <= '9' {
        return parser_parse_number(p)
    }

    if (p.current_char >= 'a' && p.current_char <= 'z') ||
       (p.current_char >= 'A' && p.current_char <= 'Z') {
        return parser_parse_variable(p)
    }

    if p.current_char == '(' {
        parser_advance(p)
        node := parser_parse_expression(p)
        parser_skip_whitespace(p)
        if p.current_char == ')' {
            parser_advance(p)
        }
        return node
    }

    node := ast_new_node(p.ast)
    node.data = Number{value = 0}
    return node
}

parser_parse_term :: proc(p: ^Parser) -> ^CalcNode {
    node := parser_parse_factor(p)

    for {
        parser_skip_whitespace(p)
        if p.current_char == 0 do break

        if p.current_char == '*' || p.current_char == '/' || p.current_char == '%' {
            op := p.current_char
            parser_advance(p)
            parser_skip_whitespace(p)
            right := parser_parse_factor(p)

            new_node := ast_new_node(p.ast)
            binop := ast_new_binary_op(p.ast)
            binop.op = op
            binop.left = node
            binop.right = right
            new_node.data = binop

            node = new_node
        } else {
            break
        }
    }

    return node
}

parser_parse_expression :: proc(p: ^Parser) -> ^CalcNode {
    node := parser_parse_term(p)

    for {
        parser_skip_whitespace(p)
        if p.current_char == 0 do break

        if p.current_char == '+' || p.current_char == '-' {
            op := p.current_char
            parser_advance(p)
            parser_skip_whitespace(p)
            right := parser_parse_term(p)

            new_node := ast_new_node(p.ast)
            binop := ast_new_binary_op(p.ast)
            binop.op = op
            binop.left = node
            binop.right = right
            new_node.data = binop

            node = new_node
        } else {
            break
        }
    }

    return node
}

parser_parse :: proc(p: ^Parser) {
    clear(&p.expressions)

    for p.current_char != 0 {
        parser_skip_whitespace(p)
        if p.current_char == 0 do break

        append(&p.expressions, parser_parse_expression(p))

        parser_skip_whitespace(p)
        for p.current_char != 0 && (p.current_char == '\n' || p.current_char == ';') {
            parser_advance(p)
            parser_skip_whitespace(p)
        }
    }
}

generate_random_program :: proc(n: i64 = 1000, allocator := context.allocator) -> string {
    builder := strings.builder_make(allocator)
    defer strings.builder_destroy(&builder)

    fmt.sbprintf(&builder, "v0 = 1\n")
    for i in 0..<10 {
        v := i + 1
        fmt.sbprintf(&builder, "v%d = v%d + %d\n", v, v - 1, v)
    }

    for i in 0..<n {
        v := int(i) + 10
        fmt.sbprintf(&builder, "v%d = v%d + ", v, v - 1)

        switch next_int(10) {
        case 0:
            fmt.sbprintf(&builder, "(v%d / 3) * 4 - %d / (3 + (18 - v%d)) %% v%d + 2 * ((9 - v%d) * (v%d + 7))", 
                v - 1, i, v - 2, v - 3, v - 6, v - 5)
        case 1:
            fmt.sbprintf(&builder, "v%d + (v%d + v%d) * v%d - (v%d / v%d)", 
                v - 1, v - 2, v - 3, v - 4, v - 5, v - 6)
        case 2:
            fmt.sbprintf(&builder, "(3789 - (((v%d)))) + 1", v - 7)
        case 3:
            fmt.sbprintf(&builder, "4/2 * (1-3) + v%d/v%d", v - 9, v - 5)
        case 4:
            fmt.sbprintf(&builder, "1+2+3+4+5+6+v%d", v - 1)
        case 5:
            fmt.sbprintf(&builder, "(99999 / v%d)", v - 3)
        case 6:
            fmt.sbprintf(&builder, "0 + 0 - v%d", v - 8)
        case 7:
            fmt.sbprintf(&builder, "((((((((((v%d)))))))))) * 2", v - 6)
        case 8:
            fmt.sbprintf(&builder, "%d * (v%d%%6)%%7", i, v - 1)
        case 9:
            fmt.sbprintf(&builder, "(1)/(0-v%d) + (v%d)", v - 5, v - 7)
        }

        fmt.sbprintln(&builder)
    }

    return strings.clone(strings.to_string(builder), allocator)
}

simple_div :: proc(a, b: i64) -> i64 {
    if b == 0 do return 0
    if (a >= 0 && b > 0) || (a < 0 && b < 0) {
        return a / b
    } else {
        return -(abs(a) / abs(b))
    }
}

simple_mod :: proc(a, b: i64) -> i64 {
    if b == 0 do return 0
    return a - simple_div(a, b) * b
}

Evaluator :: struct {
    variables: map[string]i64,
}

evaluator_eval :: proc(e: ^Evaluator, node: ^CalcNode) -> i64 {
    if node == nil do return 0

    #partial switch &data in node.data {
    case Number:
        return data.value
    case Variable:
        value, exists := e.variables[data.name]
        return exists ? value : 0
    case ^BinaryOp:
        left := evaluator_eval(e, data.left)
        right := evaluator_eval(e, data.right)

        switch data.op {
        case '+': return left + right
        case '-': return left - right
        case '*': return left * right
        case '/': return simple_div(left, right)
        case '%': return simple_mod(left, right)
        case: return 0
        }
    case ^Assignment:
        value := evaluator_eval(e, data.expr)
        e.variables[data.var] = value
        return value
    }

    return 0
}

CalculatorAst :: struct {
    using base: Benchmark,
    result_val: u32,
    text:       string,
    n:          i64,
    ast:        AST,
}

calculatorast_prepare :: proc(bench: ^Benchmark) {
    ca := cast(^CalculatorAst)bench
    ca.n = config_i64("Calculator::Ast", "operations")
    ca.text = generate_random_program(ca.n, context.allocator)
    ca.result_val = 0

    ca.ast = ast_create()
}

calculatorast_run :: proc(bench: ^Benchmark, iteration_id: int) {
    ca := cast(^CalculatorAst)bench

    ast_reset(&ca.ast)

    parser: Parser
    parser_init(&parser, ca.text, &ca.ast)
    defer parser_destroy(&parser)

    parser_parse(&parser)

    for expr in parser.expressions {
        append(&ca.ast.nodes, expr)
    }

    ca.result_val = ca.result_val + u32(len(ca.ast.nodes))

    if len(ca.ast.nodes) > 0 {
        if assign, ok := ca.ast.nodes[len(ca.ast.nodes)-1].data.(^Assignment); ok {
            ca.result_val = ca.result_val + checksum_string(assign.var)
        }
    }
}

calculatorast_checksum :: proc(bench: ^Benchmark) -> u32 {
    ca := cast(^CalculatorAst)bench
    return ca.result_val
}

calculatorast_cleanup :: proc(bench: ^Benchmark) {
    ca := cast(^CalculatorAst)bench

    ast_destroy(&ca.ast)

    if ca.text != "" {
        delete(ca.text)
    }
}

create_calculatorast :: proc() -> ^Benchmark {
    bench := new(CalculatorAst)
    bench.name = "Calculator::Ast"
    bench.vtable = default_vtable()

    bench.vtable.prepare = calculatorast_prepare
    bench.vtable.run = calculatorast_run
    bench.vtable.checksum = calculatorast_checksum
    bench.vtable.cleanup = calculatorast_cleanup

    return cast(^Benchmark)bench
}

CalculatorInterpreter :: struct {
    using base: Benchmark,
    result_val: u32,
    n:          i64,
    program:    string,
    ast:        AST,
}

calculatorinterpreter_prepare :: proc(bench: ^Benchmark) {
    ci := cast(^CalculatorInterpreter)bench
    ci.n = config_i64("Calculator::Interpreter", "operations")
    ci.program = generate_random_program(ci.n, context.allocator)
    ci.result_val = 0

    ci.ast = ast_create()

    parser: Parser
    parser_init(&parser, ci.program, &ci.ast)
    defer parser_destroy(&parser)

    parser_parse(&parser)

    for expr in parser.expressions {
        append(&ci.ast.nodes, expr)
    }
}

calculatorinterpreter_run :: proc(bench: ^Benchmark, iteration_id: int) {
    ci := cast(^CalculatorInterpreter)bench

    evaluator := Evaluator{variables = make(map[string]i64)}
    defer delete(evaluator.variables)

    result: i64 = 0
    for expr in ci.ast.nodes {
        result = evaluator_eval(&evaluator, expr)
    }

    ci.result_val = ci.result_val + u32(result & 0xFFFFFFFF)
}

calculatorinterpreter_checksum :: proc(bench: ^Benchmark) -> u32 {
    ci := cast(^CalculatorInterpreter)bench
    return ci.result_val
}

calculatorinterpreter_cleanup :: proc(bench: ^Benchmark) {
    ci := cast(^CalculatorInterpreter)bench

    ast_destroy(&ci.ast)

    if ci.program != "" {
        delete(ci.program)
    }
}

create_calculatorinterpreter :: proc() -> ^Benchmark {
    bench := new(CalculatorInterpreter)
    bench.name = "Calculator::Interpreter"
    bench.vtable = default_vtable()

    bench.vtable.prepare = calculatorinterpreter_prepare
    bench.vtable.run = calculatorinterpreter_run
    bench.vtable.checksum = calculatorinterpreter_checksum
    bench.vtable.cleanup = calculatorinterpreter_cleanup

    return cast(^Benchmark)bench
}