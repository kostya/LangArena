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

abstract type AbstractOp end

struct OpInc <: AbstractOp end
struct OpDec <: AbstractOp end
struct OpNext <: AbstractOp end
struct OpPrev <: AbstractOp end
struct OpPrint <: AbstractOp end
struct OpLoop <: AbstractOp
    ops::Vector{AbstractOp}
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

function parse_program(code::String)::Vector{AbstractOp}
    ops_stack = Vector{Vector{AbstractOp}}()
    current_ops = AbstractOp[]
    i = 1

    while i <= length(code)
        c = code[i]
        i += 1

        if c == '+'
            push!(current_ops, OpInc())
        elseif c == '-'
            push!(current_ops, OpDec())
        elseif c == '>'
            push!(current_ops, OpNext())
        elseif c == '<'
            push!(current_ops, OpPrev())
        elseif c == '.'
            push!(current_ops, OpPrint())
        elseif c == '['
            push!(ops_stack, current_ops)
            current_ops = AbstractOp[]
        elseif c == ']'
            loop_ops = current_ops
            current_ops = pop!(ops_stack)
            push!(current_ops, OpLoop(loop_ops))
        end
    end

    return current_ops
end

function run_ops(ops::Vector{AbstractOp}, tape::RTape)::Int64
    result = Int64(0)

    execute(op::OpInc) = inc!(tape)
    execute(op::OpDec) = dec!(tape)
    execute(op::OpNext) = next!(tape)
    execute(op::OpPrev) = prev!(tape)
    execute(op::OpPrint) = result = (result << 2) + Int64(get(tape))
    
    function execute(op::OpLoop)
        while get(tape) != 0x00
            for inner_op in op.ops
                execute(inner_op)
            end
        end
    end

    for op in ops
        execute(op)
    end

    return result
end

function _run2(text::String)::Int64
    ops = parse_program(text)
    tape = RTape()
    return run_ops(ops, tape)
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
