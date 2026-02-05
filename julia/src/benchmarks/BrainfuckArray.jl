mutable struct BrainfuckArray <: AbstractBenchmark
    program_text::String
    warmup_text::String
    result::UInt32

    function BrainfuckArray()
        program_text = Helper.config_s("BrainfuckArray", "program")
        warmup_text = Helper.config_s("BrainfuckArray", "warmup_program")
        new(program_text, warmup_text, UInt32(0))
    end
end

name(b::BrainfuckArray)::String = "BrainfuckArray"

mutable struct Tape
    data::Vector{UInt8}
    pos::Int

    function Tape()
        new(zeros(UInt8, 30000), 1)  
    end
end

function get(tape::Tape)::UInt8
    return tape.data[tape.pos]
end

function inc!(tape::Tape)
    tape.data[tape.pos] += 0x01
end

function dec!(tape::Tape)
    tape.data[tape.pos] -= 0x01
end

function advance!(tape::Tape)
    tape.pos += 1
    if tape.pos > length(tape.data)
        push!(tape.data, 0x00)
    end
end

function devance!(tape::Tape)
    if tape.pos > 1
        tape.pos -= 1
    end
end

struct Program
    commands::Vector{Char}
    jumps::Vector{Int}

    function Program(text::String)

        valid_chars = Set("[]<>+-,.")
        commands = [c for c in text if c in valid_chars]

        jumps = zeros(Int, length(commands))
        stack = Int[]

        for (i, cmd) in enumerate(commands)
            if cmd == '['
                push!(stack, i)
            elseif cmd == ']' && !isempty(stack)
                start_idx = pop!(stack)
                jumps[start_idx] = i
                jumps[i] = start_idx
            end
        end

        new(commands, jumps)
    end
end

function run(prog::Program)::Int64
    result = Int64(0)
    tape = Tape()
    pc = 1  

    while pc <= length(prog.commands)
        cmd = prog.commands[pc]

        if cmd == '+'
            inc!(tape)
        elseif cmd == '-'
            dec!(tape)
        elseif cmd == '>'
            advance!(tape)
        elseif cmd == '<'
            devance!(tape)
        elseif cmd == '['
            if get(tape) == 0x00
                pc = prog.jumps[pc]
                continue  
            end
        elseif cmd == ']'
            if get(tape) != 0x00
                pc = prog.jumps[pc]
                continue  
            end
        elseif cmd == '.'
            result = (result << 2) + Int64(get(tape))
        end

        pc += 1
    end

    return result
end

function _run(text::String)::Int64
    prog = Program(text)
    return run(prog)
end

function warmup(b::BrainfuckArray)
    warmup_iters = warmup_iterations(b)
    for i in 1:warmup_iters
        _run(b.warmup_text)
    end
end

function run(b::BrainfuckArray, iteration_id::Int64)
    run_result = _run(b.program_text)
    b.result += Helper.to_u32(run_result)
end

checksum(b::BrainfuckArray)::UInt32 = b.result