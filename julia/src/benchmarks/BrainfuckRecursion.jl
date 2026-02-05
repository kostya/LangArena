mutable struct BrainfuckRecursion <: AbstractBenchmark
    text::String
    warmup_text::String
    result::UInt32

    function BrainfuckRecursion()
        text = Helper.config_s("BrainfuckRecursion", "program")
        warmup_text = Helper.config_s("BrainfuckRecursion", "warmup_program")
        new(text, warmup_text, UInt32(0))
    end
end

name(b::BrainfuckRecursion)::String = "BrainfuckRecursion"

abstract type AbstractOp end

struct OpInc <: AbstractOp
    val::Int8
end

struct OpMove <: AbstractOp
    val::Int8
end

struct OpPrint <: AbstractOp end

struct OpLoop <: AbstractOp
    ops::Vector{AbstractOp}
end

mutable struct RTape
    data::Vector{UInt8}
    pos::Int

    function RTape()
        new(zeros(UInt8, 1024), 1)
    end
end

@inline function get(tape::RTape)::UInt8
    @inbounds return tape.data[tape.pos]
end

@inline function inc!(tape::RTape, x::Int8)
    @inbounds tape.data[tape.pos] += x % UInt8
end

@inline function move!(tape::RTape, x::Int8)
    tape.pos += x

    if tape.pos < 1
        needed = 1 - tape.pos
        new_data = zeros(UInt8, length(tape.data) + needed)
        @inbounds copyto!(new_data, needed + 1, tape.data, 1, length(tape.data))
        tape.data = new_data
        tape.pos = needed
    elseif tape.pos > length(tape.data)
        new_size = max(length(tape.data) * 2, tape.pos + 1)
        resize!(tape.data, new_size)
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
            push!(current_ops, OpInc(Int8(1)))
        elseif c == '-'
            push!(current_ops, OpInc(Int8(-1)))
        elseif c == '>'
            push!(current_ops, OpMove(Int8(1)))
        elseif c == '<'
            push!(current_ops, OpMove(Int8(-1)))
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

    function execute(op::AbstractOp)
        if op isa OpInc
            inc!(tape, op.val)
        elseif op isa OpMove
            move!(tape, op.val)
        elseif op isa OpPrint
            result = (result << 2) + Int64(get(tape))
        elseif op isa OpLoop
            while get(tape) != 0x00
                for inner_op in op.ops
                    execute(inner_op)
                end
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
    for i in 1:warmup_iters
        _run2(b.warmup_text)
    end
end

function run(b::BrainfuckRecursion, iteration_id::Int64)
    run_result = _run2(b.text)
    b.result += Helper.to_u32(run_result)
end

checksum(b::BrainfuckRecursion)::UInt32 = b.result