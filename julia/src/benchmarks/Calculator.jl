using ..BenchmarkFramework

abstract type CalcNode end

struct NumberCalcNode <: CalcNode
    value::Int64
    function NumberCalcNode(value::Int64)
        new(value)
    end
end

struct VariableCalcNode <: CalcNode
    name::String
    function VariableCalcNode(name::String)
        new(name)
    end
end

struct BinaryOpCalcNode <: CalcNode
    op::Char
    left::CalcNode
    right::CalcNode
    function BinaryOpCalcNode(op::Char, left::CalcNode, right::CalcNode)
        new(op, left, right)
    end
end

struct AssignmentCalcNode <: CalcNode
    var::String
    expr::CalcNode
    function AssignmentCalcNode(var::String, expr::CalcNode)
        new(var, expr)
    end
end

mutable struct CalculatorAst <: AbstractBenchmark
    n::Int64
    result::UInt32
    text::String
    expressions::Vector{CalcNode}

    function CalculatorAst()
        n_val = Helper.config_i64("CalculatorAst", "operations")
        new(n_val, UInt32(0), "", CalcNode[])
    end
end

name(b::CalculatorAst)::String = "CalculatorAst"

function generate_random_program(n::Int64 = 1000)::String
    io = IOBuffer()

    write(io, "v0 = 1\n")
    for i in 0:9
        v = i + 1
        write(io, "v$v = v$(v-1) + $v\n")
    end

    for i in 0:n-1
        v = i + 10
        write(io, "v$v = v$(v-1) + ")

        r = Helper.next_int(10)
        if r == 0
            write(io, "(v$(v-1) / 3) * 4 - $i / (3 + (18 - v$(v-2))) % v$(v-3) + 2 * ((9 - v$(v-6)) * (v$(v-5) + 7))")
        elseif r == 1
            write(io, "v$(v-1) + (v$(v-2) + v$(v-3)) * v$(v-4) - (v$(v-5) /  v$(v-6))")
        elseif r == 2
            write(io, "(3789 - (((v$(v-7))))) + 1")
        elseif r == 3
            write(io, "4/2 * (1-3) + v$(v-9)/v$(v-5)")
        elseif r == 4
            write(io, "1+2+3+4+5+6+v$(v-1)")
        elseif r == 5
            write(io, "(99999 / v$(v-3))")
        elseif r == 6
            write(io, "0 + 0 - v$(v-8)")
        elseif r == 7
            write(io, "((((((((((v$(v-6)))))))))) * 2")
        elseif r == 8
            write(io, "$i * (v$(v-1)%6)%7")
        else 
            write(io, "(1)/(0-v$(v-5)) + (v$(v-7))")
        end
        write(io, "\n")
    end

    return String(take!(io))
end

function prepare(b::CalculatorAst)
    b.text = generate_random_program(b.n)
end

mutable struct Parser
    input::String
    pos::Int
    chars::Vector{Char}
    current_char::Char
    expressions::Vector{CalcNode}

    function Parser(input::String)
        chars = collect(input)
        current_char = length(chars) > 0 ? chars[1] : '\0'
        new(input, 1, chars, current_char, CalcNode[])
    end
end

function parse(p::Parser)
    while p.pos <= length(p.chars)
        node = parse_expression(p)
        if node !== nothing
            push!(p.expressions, node)
        end
    end
end

function parse_expression(p::Parser)::CalcNode
    node = parse_term(p)

    while p.pos <= length(p.chars)
        skip_whitespace(p)
        p.pos > length(p.chars) && break

        if p.current_char == '+' || p.current_char == '-'
            op = p.current_char
            advance(p)
            right = parse_term(p)
            node = BinaryOpCalcNode(op, node, right)
        else
            break
        end
    end

    return node
end

function parse_term(p::Parser)::CalcNode
    node = parse_factor(p)

    while p.pos <= length(p.chars)
        skip_whitespace(p)
        p.pos > length(p.chars) && break

        if p.current_char == '*' || p.current_char == '/' || p.current_char == '%'
            op = p.current_char
            advance(p)
            right = parse_factor(p)
            node = BinaryOpCalcNode(op, node, right)
        else
            break
        end
    end

    return node
end

function parse_factor(p::Parser)::CalcNode
    skip_whitespace(p)
    p.pos > length(p.chars) && return NumberCalcNode(0)

    if isdigit(p.current_char)
        return parse_number(p)
    elseif islowercase(p.current_char)
        return parse_variable(p)
    elseif p.current_char == '('
        advance(p)  
        node = parse_expression(p)
        skip_whitespace(p)
        if p.current_char == ')'
            advance(p)  
        end
        return node
    else
        return NumberCalcNode(0)
    end
end

function parse_number(p::Parser)::CalcNode
    v = Int64(0)
    while p.pos <= length(p.chars) && isdigit(p.current_char)
        v = v * 10 + Int64(p.current_char - '0')
        advance(p)
    end
    return NumberCalcNode(v)
end

function parse_variable(p::Parser)::CalcNode
    start = p.pos
    while p.pos <= length(p.chars) && (islowercase(p.current_char) || isdigit(p.current_char))
        advance(p)
    end
    var_name = p.input[start:p.pos-1]

    skip_whitespace(p)
    if p.pos <= length(p.chars) && p.current_char == '='
        advance(p)  
        expr = parse_expression(p)
        return AssignmentCalcNode(var_name, expr)
    end

    return VariableCalcNode(var_name)
end

function advance(p::Parser)
    p.pos += 1
    if p.pos > length(p.chars)
        p.current_char = '\0'
    else
        p.current_char = p.chars[p.pos]
    end
end

function skip_whitespace(p::Parser)
    while p.pos <= length(p.chars) && isspace(p.current_char)
        advance(p)
    end
end

function run(b::CalculatorAst, iteration_id::Int64)
    parser = Parser(b.text)
    parse(parser)
    b.expressions = parser.expressions
    b.result = (b.result + UInt32(length(b.expressions))) & 0xffffffff

    if !isempty(b.expressions)
        last_expr = b.expressions[end]
        if last_expr isa AssignmentCalcNode
            var_name = last_expr.var
            b.result = (b.result + Helper.checksum(var_name)) & 0xffffffff
        end
    end
end

function checksum(b::CalculatorAst)::UInt32
    return b.result
end

mutable struct Interpreter
    variables::Dict{String, Int64}

    function Interpreter()
        new(Dict{String, Int64}())
    end
end

function simple_div(a::Int64, b::Int64)::Int64
    b == 0 && return Int64(0)

    if (a >= 0 && b > 0) || (a < 0 && b < 0)
        div(a, b)  
    else
        -div(abs(a), abs(b))  
    end
end

function simple_mod(a::Int64, b::Int64)::Int64
    b == 0 && return Int64(0)
    a - simple_div(a, b) * b
end

function evaluate(interp::Interpreter, node::CalcNode)::Int64
    if node isa NumberCalcNode
        return node.value
    elseif node isa VariableCalcNode
        return interp.variables[node.name]
    elseif node isa BinaryOpCalcNode
        left = evaluate(interp, node.left)
        right = evaluate(interp, node.right)

        if node.op == '+'
            return left + right
        elseif node.op == '-'
            return left - right
        elseif node.op == '*'
            return left * right
        elseif node.op == '/'
            return simple_div(left, right)
        elseif node.op == '%'
            return simple_mod(left, right)
        else
            return Int64(0)
        end
    elseif node isa AssignmentCalcNode
        value = evaluate(interp, node.expr)
        interp.variables[node.var] = value
        return value
    else
        return Int64(0)
    end
end

function run_interpreter(interp::Interpreter, expressions::Vector{CalcNode})::Int64
    result = Int64(0)
    for expr in expressions
        result = evaluate(interp, expr)
    end
    return result
end

mutable struct CalculatorInterpreter <: AbstractBenchmark
    n::Int64
    ast::Vector{CalcNode}
    result::UInt32

    function CalculatorInterpreter()
        n_val = Helper.config_i64("CalculatorInterpreter", "operations")
        new(n_val, CalcNode[], UInt32(0))
    end
end

name(b::CalculatorInterpreter)::String = "CalculatorInterpreter"

function prepare(b::CalculatorInterpreter)

    calc = CalculatorAst()
    calc.n = b.n
    prepare(calc)
    run(calc, 0)
    b.ast = calc.expressions
end

function run(b::CalculatorInterpreter, iteration_id::Int64)
    interp = Interpreter()
    result = run_interpreter(interp, b.ast)
    b.result += Helper.to_u32(result)
end

function checksum(b::CalculatorInterpreter)::UInt32
    return b.result
end