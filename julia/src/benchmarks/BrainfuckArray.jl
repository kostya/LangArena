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

        data = Vector{UInt8}(undef, 30000)
        fill!(data, 0x00)

        new(data, 1)
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
    commands::Vector{UInt8}
    jumps::Vector{Int}

    function Program(text::String)

        len = length(text)
        temp = Vector{UInt8}(undef, len)
        count = 0

        for c in text
            if c in "[]<>+-,."
                count += 1
                temp[count] = UInt8(c)
            end
        end

        commands = Vector{UInt8}(undef, count)
        copyto!(commands, 1, temp, 1, count)

        jumps = zeros(Int, count)
        stack = Vector{Int}(undef, count)
        sp = 0

        for i = 1:count
            cmd = commands[i]
            if cmd == UInt8('[')
                sp += 1
                stack[sp] = i
            elseif cmd == UInt8(']')
                if sp > 0
                    start_idx = stack[sp]
                    sp -= 1
                    jumps[start_idx] = i
                    jumps[i] = start_idx
                end
            end
        end

        new(commands, jumps)
    end
end

function run(prog::Program)::Int64
    result = Int64(0)
    tape = Tape()
    pc = 1
    cmds = prog.commands
    jmps = prog.jumps

    while pc <= length(cmds)
        cmd = cmds[pc]

        if cmd == UInt8('+')
            inc!(tape)
        elseif cmd == UInt8('-')
            dec!(tape)
        elseif cmd == UInt8('>')
            advance!(tape)
        elseif cmd == UInt8('<')
            devance!(tape)
        elseif cmd == UInt8('[')
            if get(tape) == 0x00
                pc = jmps[pc]
                continue
            end
        elseif cmd == UInt8(']')
            if get(tape) != 0x00
                pc = jmps[pc]
                continue
            end
        elseif cmd == UInt8('.')
            result = (result << 2) + Int64(get(tape))
        end

        pc += 1
    end

    return result
end

function _run(text::String)::Int64
    return run(Program(text))
end

function warmup(b::BrainfuckArray)
    warmup_iters = warmup_iterations(b)
    for _ = 1:warmup_iters
        _run(b.warmup_text)
    end
end

function run(b::BrainfuckArray, iteration_id::Int64)
    run_result = _run(b.program_text)
    b.result += Helper.to_u32(run_result)
end

checksum(b::BrainfuckArray)::UInt32 = b.result
