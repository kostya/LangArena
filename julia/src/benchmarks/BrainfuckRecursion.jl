mutable struct BrainfuckRecursion <: AbstractBenchmark
    text::String
    warmup_text::String
    result::UInt32

    function BrainfuckRecursion()
        text = Helper.config_s("Brainfuck::Recursion", "program")
        warmup_text = Helper.config_s("Brainfuck::Recursion", "warmup_program")
        new(text, warmup_text, UInt32(0))
    end
end

name(b::BrainfuckRecursion)::String = "Brainfuck::Recursion"

@enum OpCode OpInc OpDec OpNext OpPrev OpPrint OpLoop

struct Op
    opcode::OpCode
    loop::Vector{Op}

    Op(opcode::OpCode, loop::Vector{Op}=Op[]) = new(opcode, loop)
end

mutable struct RTape
    data::Vector{UInt8}
    pos::Int

    function RTape()
        new(zeros(UInt8, 30000), 1)
    end
end

function get(tape::RTape)::UInt8
    return tape.data[tape.pos]
end

function inc!(tape::RTape)
    tape.data[tape.pos] += 0x01
end

function dec!(tape::RTape)
    tape.data[tape.pos] -= 0x01
end

function next!(tape::RTape)
    tape.pos += 1
    if tape.pos > length(tape.data)
        push!(tape.data, 0x00)
    end
end

function prev!(tape::RTape)
    if tape.pos > 1
        tape.pos -= 1
    end
end

function _parse_program(code::String, ind=1)
    ops = Op[]

    while checkbounds(Bool, code, ind)
        c = code[ind]
        if c == '+'
            push!(ops, Op(OpInc))
        elseif c == '-'
            push!(ops, Op(OpDec))
        elseif c == '>'
            push!(ops, Op(OpNext))
        elseif c == '<'
            push!(ops, Op(OpPrev))
        elseif c == '.'
            push!(ops, Op(OpPrint))
        elseif c == '['
            loop, nextind = _parse_program(code, ind + 1)
            push!(ops, Op(OpLoop, loop))
            ind = nextind
        elseif c == ']'
            return ops, ind
        end
        ind += 1
    end

    return ops, ind
end

parse_program(code) = _parse_program(code)[1]

function execute!(op::Op, tape::RTape, result::Int)
    if op.opcode == OpInc
        inc!(tape)
    elseif op.opcode == OpDec
        dec!(tape)
    elseif op.opcode == OpNext
        next!(tape)
    elseif op.opcode == OpPrev
        prev!(tape)
    elseif op.opcode == OpPrint
        result <<= 2
        result += get(tape)
    elseif op.opcode == OpLoop
        while !iszero(get(tape))
            result = execute!(op.loop, tape, result)
        end
    end
    return result
end

function execute!(ops::Vector{Op}, tape::RTape=RTape(), result::Int=0)
    for op in ops
        result = execute!(op, tape, result)
    end
    return result
end

function run_program(program::Vector{Op})
    return execute!(program)
end

function _run2(text::String)::Int64
    program = parse_program(text)
    return run_program(program)
end

function warmup(b::BrainfuckRecursion)
    warmup_iters = warmup_iterations(b)
    for i = 1:warmup_iters
        _run2(b.warmup_text)
    end
end

function run(b::BrainfuckRecursion, iteration_id::Int64)
    run_result = _run2(b.text)
    b.result += Helper.to_u32(run_result)
end

checksum(b::BrainfuckRecursion)::UInt32 = b.result
