package benchmark

import "core:fmt"
import "core:strings"
import "core:mem"

OpType :: union {
    OpInc,
    OpDec,
    OpRight,
    OpLeft,
    OpPrint,
    OpLoop,
}

OpInc :: struct {}    
OpDec :: struct {}    
OpRight :: struct {}  
OpLeft :: struct {}   
OpPrint :: struct {}  
OpLoop :: struct {    
    ops: [dynamic]OpType,
}

Recursion_Tape :: struct {
    tape: [dynamic]u8,
    pos: int,
}

recursion_tape_init :: proc(tape: ^Recursion_Tape, initial_size: int = 30000) {
    tape.tape = make([dynamic]u8, initial_size)
    tape.pos = 0
}

recursion_tape_destroy :: proc(tape: ^Recursion_Tape) {
    delete(tape.tape)
}

recursion_tape_get :: proc(tape: ^Recursion_Tape) -> u8 {
    return tape.tape[tape.pos]
}

recursion_tape_inc :: proc(tape: ^Recursion_Tape) {
    tape.tape[tape.pos] += 1
}

recursion_tape_dec :: proc(tape: ^Recursion_Tape) {
    tape.tape[tape.pos] -= 1
}

recursion_tape_right :: proc(tape: ^Recursion_Tape) {
    tape.pos += 1
    if tape.pos >= len(tape.tape) {
        append(&tape.tape, 0)
    }
}

recursion_tape_left :: proc(tape: ^Recursion_Tape) {
    if tape.pos > 0 {
        tape.pos -= 1
    }
}

Recursion_Program :: struct {
    ops: [dynamic]OpType,
    result_val: i64,
}

recursion_program_init :: proc(program: ^Recursion_Program, code: string) {
    program.ops = make([dynamic]OpType)
    program.result_val = 0

    it := 0
    program.ops = recursion_parse(&it, code)
}

recursion_parse :: proc(it: ^int, code: string) -> [dynamic]OpType {
    ops := make([dynamic]OpType)

    for it^ < len(code) {
        c := code[it^]
        it^ += 1

        switch c {
        case '+':
            append(&ops, OpInc{})
        case '-':
            append(&ops, OpDec{})
        case '>':
            append(&ops, OpRight{})
        case '<':
            append(&ops, OpLeft{})
        case '.':
            append(&ops, OpPrint{})
        case '[':
            loop_ops := recursion_parse(it, code)
            append(&ops, OpLoop{ops = loop_ops})
        case ']':
            return ops
        }
    }

    return ops
}

recursion_program_destroy :: proc(program: ^Recursion_Program) {
    recursion_destroy_ops(program.ops[:])
    delete(program.ops)
}

recursion_destroy_ops :: proc(ops: []OpType) {
    for op in ops {
        switch &v in op {
        case OpLoop:
            recursion_destroy_ops(v.ops[:])
            delete(v.ops)
        case OpInc, OpDec, OpRight, OpLeft, OpPrint:

        }
    }
}

recursion_run_ops :: proc(program: ^Recursion_Program, ops: []OpType, tape: ^Recursion_Tape) {
    for op in ops {
        switch &v in op {
        case OpInc:
            recursion_tape_inc(tape)
        case OpDec:
            recursion_tape_dec(tape)
        case OpRight:
            recursion_tape_right(tape)
        case OpLeft:
            recursion_tape_left(tape)
        case OpPrint:
            program.result_val = (program.result_val << 2) + i64(recursion_tape_get(tape))
        case OpLoop:
            for recursion_tape_get(tape) != 0 {
                recursion_run_ops(program, v.ops[:], tape)
            }
        }
    }
}

recursion_program_run :: proc(program: ^Recursion_Program) -> i64 {
    program.result_val = 0

    tape: Recursion_Tape
    recursion_tape_init(&tape, 30000)
    defer recursion_tape_destroy(&tape)

    recursion_run_ops(program, program.ops[:], &tape)

    return program.result_val
}

BrainfuckRecursion :: struct {
    using base: Benchmark,
    program_text: string,
    warmup_text: string,
    result_val: u32,
}

brainfuckrecursion_run :: proc(bench: ^Benchmark, iteration_id: int) {
    bf := cast(^BrainfuckRecursion)bench

    program: Recursion_Program
    recursion_program_init(&program, bf.program_text)
    defer recursion_program_destroy(&program)

    result := recursion_program_run(&program)
    bf.result_val = u32((u64(bf.result_val) + u64(result)) & 0xFFFFFFFF)
}

brainfuckrecursion_checksum :: proc(bench: ^Benchmark) -> u32 {
    bf := cast(^BrainfuckRecursion)bench
    return bf.result_val
}

brainfuckrecursion_prepare :: proc(bench: ^Benchmark) {
    bf := cast(^BrainfuckRecursion)bench
    bf.program_text = config_string("BrainfuckRecursion", "program")
    bf.warmup_text = config_string("BrainfuckRecursion", "warmup_program")
    bf.result_val = 0
}

brainfuckrecursion_warmup :: proc(bench: ^Benchmark) {
    bf := cast(^BrainfuckRecursion)bench
    wi := warmup_iterations(bench)

    for i in 0..<wi {
        program: Recursion_Program
        recursion_program_init(&program, bf.warmup_text)
        recursion_program_run(&program)
        recursion_program_destroy(&program)
    }
}

brainfuckrecursion_cleanup :: proc(bench: ^Benchmark) {
    bf := cast(^BrainfuckRecursion)bench
    delete(bf.program_text)
    delete(bf.warmup_text)
}

create_brainfuckrecursion :: proc() -> ^Benchmark {
    bf := new(BrainfuckRecursion)
    bf.name = "BrainfuckRecursion"

    vtable := default_vtable()
    vtable.run = brainfuckrecursion_run
    vtable.checksum = brainfuckrecursion_checksum
    vtable.prepare = brainfuckrecursion_prepare
    vtable.warmup = brainfuckrecursion_warmup
    vtable.cleanup = brainfuckrecursion_cleanup

    bf.vtable = vtable
    bf.program_text = config_string("BrainfuckRecursion", "program")
    bf.warmup_text = config_string("BrainfuckRecursion", "warmup_program")
    bf.result_val = 0

    return cast(^Benchmark)bf
}