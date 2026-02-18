package benchmark

import "core:fmt"
import "core:strings"

Tape :: struct {
    tape: [dynamic]u8,
    pos:  int,
}

tape_init :: proc(tape: ^Tape, initial_size: int = 30000) {
    tape.tape = make([dynamic]u8, initial_size)
    tape.pos = 0
}

tape_destroy :: proc(tape: ^Tape) {
    delete(tape.tape)
}

tape_get :: proc(tape: ^Tape) -> u8 {
    return tape.tape[tape.pos]
}

tape_inc :: proc(tape: ^Tape) {
    tape.tape[tape.pos] = tape.tape[tape.pos] + 1
}

tape_dec :: proc(tape: ^Tape) {
    tape.tape[tape.pos] = tape.tape[tape.pos] - 1
}

tape_advance :: proc(tape: ^Tape) {
    tape.pos += 1
    if tape.pos >= len(tape.tape) {
        append(&tape.tape, 0)
    }
}

tape_devance :: proc(tape: ^Tape) {
    if tape.pos > 0 {
        tape.pos -= 1
    }
}

Program :: struct {
    commands: string,
    jumps:    []int,
}

program_init :: proc(program: ^Program, text: string) {

    builder: strings.Builder
    strings.builder_init(&builder)
    defer strings.builder_destroy(&builder)

    for char in text {
        switch char {
        case '[', ']', '<', '>', '+', '-', ',', '.':
            strings.write_rune(&builder, char)
        }
    }

    program.commands = strings.clone(strings.to_string(builder))

    program.jumps = make([]int, len(program.commands))

    stack: [dynamic]int
    defer delete(stack)

    for i in 0..<len(program.commands) {
        cmd := program.commands[i]

        if cmd == '[' {
            append(&stack, i)
        } else if cmd == ']' && len(stack) > 0 {
            start := pop(&stack)
            program.jumps[start] = i
            program.jumps[i] = start
        }
    }
}

program_destroy :: proc(program: ^Program) {
    delete(program.commands)
    delete(program.jumps)
}

program_run :: proc(program: ^Program) -> u32 {
    tape: Tape
    tape_init(&tape)
    defer tape_destroy(&tape)

    result: u32 = 0
    pc := 0

    for pc < len(program.commands) {
        cmd := program.commands[pc]

        switch cmd {
        case '+':
            tape_inc(&tape)
        case '-':
            tape_dec(&tape)
        case '>':
            tape_advance(&tape)
        case '<':
            tape_devance(&tape)
        case '[':
            if tape_get(&tape) == 0 {
                pc = program.jumps[pc]
            }
        case ']':
            if tape_get(&tape) != 0 {
                pc = program.jumps[pc]
            }
        case '.':

            result = ((result << 2) + u32(tape_get(&tape))) & 0xFFFFFFFF
        case ',':

        }

        pc += 1
    }

    return result
}

BrainfuckArray :: struct {
    using base: Benchmark,
    program_text: string,
    warmup_text:  string,
    result_value: u32,
}

brainfuckarray_run :: proc(bench: ^Benchmark, iteration_id: int) {
    bf := cast(^BrainfuckArray)bench

    program: Program
    program_init(&program, bf.program_text)
    defer program_destroy(&program)

    result := program_run(&program)
    bf.result_value = (bf.result_value + result) & 0xFFFFFFFF
}

brainfuckarray_checksum :: proc(bench: ^Benchmark) -> u32 {
    bf := cast(^BrainfuckArray)bench
    return bf.result_value
}

brainfuckarray_warmup :: proc(bench: ^Benchmark) {
    bf := cast(^BrainfuckArray)bench
    wi := warmup_iterations(bench)
    for i in 0..<wi {
        program: Program
        program_init(&program, bf.warmup_text)
        program_run(&program)
        program_destroy(&program)
    }
}

brainfuckarray_prepare :: proc(bench: ^Benchmark) {
}

brainfuckarray_cleanup :: proc(bench: ^Benchmark) {
    bf := cast(^BrainfuckArray)bench
    delete(bf.program_text)
    delete(bf.warmup_text)
    free(bf.vtable)
    free(bf)
}

create_brainfuckarray :: proc() -> ^Benchmark {
    bf := new(BrainfuckArray)
    bf.name = "BrainfuckArray"
    bf.vtable = default_vtable()
    bf.vtable.run = brainfuckarray_run    
    bf.vtable.checksum = brainfuckarray_checksum
    bf.vtable.prepare = brainfuckarray_prepare
    bf.vtable.warmup = brainfuckarray_warmup

    bf.program_text = config_string(bf.name, "program")
    bf.warmup_text = config_string(bf.name, "warmup_program")
    return cast(^Benchmark)bf
}