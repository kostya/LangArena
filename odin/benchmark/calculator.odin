package benchmark

import "core:fmt"
import "core:strconv"
import "core:strings"
import "core:mem"
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

Parser :: struct {
    input:         string,
    pos:           int,
    current_char:  u8,  
    expressions:   [dynamic]^CalcNode,
}

parser_init :: proc(p: ^Parser, input_str: string) {
    p.input = input_str
    p.pos = 0
    p.expressions = make([dynamic]^CalcNode)

    if len(p.input) == 0 {
        p.current_char = 0
    } else {
        p.current_char = p.input[0]  
    }
}

parser_destroy :: proc(p: ^Parser) {
    delete(p.expressions)
}

parser_advance :: proc(p: ^Parser) {
    p.pos += 1
    if p.pos >= len(p.input) {
        p.current_char = 0
    } else {
        p.current_char = p.input[p.pos]  
    }
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

    node := new(CalcNode)
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

        node := new(CalcNode)
        assign := new(Assignment)
        assign.var = strings.clone(var_name)  
        assign.expr = expr
        node.data = assign
        return node
    }

    node := new(CalcNode)
    node.data = Variable{name = strings.clone(var_name)}
    return node
}

parser_parse_factor :: proc(p: ^Parser) -> ^CalcNode {
    parser_skip_whitespace(p)
    if p.current_char == 0 {
        node := new(CalcNode)
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

    node := new(CalcNode)
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

            new_node := new(CalcNode)
            binop := new(BinaryOp)
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

            new_node := new(CalcNode)
            binop := new(BinaryOp)
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

node_clone :: proc(node: ^CalcNode) -> ^CalcNode {
    if node == nil do return nil

    new_node := new(CalcNode)

    #partial switch &data in node.data {
    case Number:
        new_node.data = data
    case Variable:
        new_node.data = Variable{name = strings.clone(data.name)}
    case ^BinaryOp:
        new_binop := new(BinaryOp)
        new_binop.op = data.op
        new_binop.left = node_clone(data.left)
        new_binop.right = node_clone(data.right)
        new_node.data = new_binop
    case ^Assignment:
        new_assign := new(Assignment)
        new_assign.var = strings.clone(data.var)
        new_assign.expr = node_clone(data.expr)
        new_node.data = new_assign
    }

    return new_node
}

node_cleanup :: proc(node: ^CalcNode) {
    if node == nil do return

    #partial switch &data in node.data {
    case Variable:
        delete(data.name)
    case ^BinaryOp:
        node_cleanup(data.left)
        node_cleanup(data.right)
        free(data)
    case ^Assignment:
        delete(data.var)
        node_cleanup(data.expr)
        free(data)
    case:
    }

    free(node)
}

generate_random_program :: proc(n: i64 = 1000) -> string {
    builder := strings.builder_make()
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

    temp_result := strings.to_string(builder)
    result := strings.clone(temp_result)

    return result
}

CalculatorAst :: struct {
    using base: Benchmark,
    result_val: u32,
    text:       string,
    n:          i64,
    expressions: [dynamic]^CalcNode,
}

calculatorast_prepare :: proc(bench: ^Benchmark) {
    ca := cast(^CalculatorAst)bench
    ca.n = config_i64("CalculatorAst", "operations")

    ca.text = generate_random_program(ca.n)

    ca.result_val = 0
    ca.expressions = make([dynamic]^CalcNode)
}

calculatorast_run :: proc(bench: ^Benchmark, iteration_id: int) {
    ca := cast(^CalculatorAst)bench

    for expr in ca.expressions {
        node_cleanup(expr)
    }
    clear(&ca.expressions)

    parser: Parser
    parser_init(&parser, ca.text)
    defer parser_destroy(&parser)

    parser_parse(&parser)

    for expr in parser.expressions {
        append(&ca.expressions, node_clone(expr))
    }

    ca.result_val = ca.result_val + u32(len(ca.expressions))

    if len(ca.expressions) > 0 {
        if assign, ok := ca.expressions[len(ca.expressions)-1].data.(^Assignment); ok {
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

    for expr in ca.expressions {
        node_cleanup(expr)
    }
    delete(ca.expressions)

    if ca.text != "" {
        delete(ca.text)
    }
}

create_calculatorast :: proc() -> ^Benchmark {
    bench := new(CalculatorAst)
    bench.name = "CalculatorAst"
    bench.vtable = default_vtable()

    bench.vtable.run = calculatorast_run
    bench.vtable.checksum = calculatorast_checksum
    bench.vtable.prepare = calculatorast_prepare
    bench.vtable.cleanup = calculatorast_cleanup

    return cast(^Benchmark)bench
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

CalculatorInterpreter :: struct {
    using base: Benchmark,
    result_val: u32,
    n:          i64,
    ast:        [dynamic]^CalcNode,
}

calculatorinterpreter_prepare :: proc(bench: ^Benchmark) {
    ci := cast(^CalculatorInterpreter)bench
    ci.n = config_i64("CalculatorInterpreter", "operations")
    ci.result_val = 0

    for expr in ci.ast {
        node_cleanup(expr)
    }
    delete(ci.ast)
    ci.ast = make([dynamic]^CalcNode)

    program := generate_random_program(ci.n)
    defer delete(program)

    parser: Parser
    parser_init(&parser, program)
    defer parser_destroy(&parser)

    parser_parse(&parser)

    for expr in parser.expressions {
        append(&ci.ast, node_clone(expr))
    }
}

calculatorinterpreter_run :: proc(bench: ^Benchmark, iteration_id: int) {
    ci := cast(^CalculatorInterpreter)bench

    evaluator := Evaluator{variables = make(map[string]i64)}
    defer delete(evaluator.variables)

    result: i64 = 0
    for expr in ci.ast {
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

    for expr in ci.ast {
        node_cleanup(expr)
    }
    delete(ci.ast)
}

create_calculatorinterpreter :: proc() -> ^Benchmark {
    bench := new(CalculatorInterpreter)
    bench.name = "CalculatorInterpreter"
    bench.vtable = default_vtable()

    bench.vtable.run = calculatorinterpreter_run
    bench.vtable.checksum = calculatorinterpreter_checksum
    bench.vtable.prepare = calculatorinterpreter_prepare
    bench.vtable.cleanup = calculatorinterpreter_cleanup

    return cast(^Benchmark)bench
}