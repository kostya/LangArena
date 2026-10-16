namespace brainfuck_array;

import std;
import bench;

struct Tape { pos: i64, tape: u8[>..] }

fn new_tape() -> Tape { Tape { pos: 0, tape: [0; 30000] } }

fn get(t: Tape&) -> u8 { t.tape[t.pos] }

fn inc(t: Tape&) { t.tape[t.pos] += 1; }

fn dec(t: Tape&) { t.tape[t.pos] -= 1; }

fn advance(t: Tape&) {
    t.pos++;
    if t.pos >= t.tape.len { t.tape.push(0); }
}

fn devance(t: Tape&) {
    if t.pos > 0 { t.pos--; }
}

struct Program { commands: u8[], jumps: i64[>..] }

fn new_program(text: const u8[:]) -> Program, bool {
    var program = Program {
        commands: text.filter() { c =>
            match c { '+', '-', '>', '<', '[', ']', '.', ',' => true, _ => false }
        },
        jumps: [],
    };
    if program.commands.len == 0 { return program, false; }

    program.jumps.resize(program.commands.len, 0);
    var stack: i64[>..<] = [];
    for cmd, i in program.commands {
        match cmd {
            '[' => { stack.push(i); },
            ']' => {
                if stack.len == 0 { return program, false; }
                let start = stack.pop();
                program.jumps[start] = i;
                program.jumps[i] = start;
            },
            _ => {},
        }
    }
    return program, stack.len == 0;
}

fn run(p: Program&) -> u32, bool {
    var tape = new_tape();
    var pc = 0;
    var result: u32 = 0;
    while pc < p.commands.len {
        match p.commands[pc] {
            '+' => { tape.inc(); },
            '-' => { tape.dec(); },
            '>' => { tape.advance(); },
            '<' => { tape.devance(); },
            '[' => { if tape.get() == 0 { pc = p.jumps[pc]; } },
            ']' => { if tape.get() != 0 { pc = p.jumps[pc]; } },
            '.' => { result = (result << 2) + tape.get(); },
            _ => { return 0, false; },
        }
        pc++;
    }
    return result, true;
}

fn run_program(source: const u8[:]) -> u32, bool {
    let program, ok = new_program(source);
    if !ok { return 0, false; }
    return program.run();
}

struct BrainfuckArray { program_text: const u8[:], warmup_text: const u8[:], result_val: u32 }

fn new_brainfuck_array() -> BrainfuckArray {
    BrainfuckArray {
        program_text: config_s("Brainfuck::Array", "program"),
        warmup_text: config_s("Brainfuck::Array", "warmup_program"),
        result_val: 0,
    }
}

fn prepare(s: BrainfuckArray&) {}

fn warmup(s: BrainfuckArray&, iterations: i64) {
    for i in iterations { run_program(s.warmup_text); }
}

fn run(s: BrainfuckArray&, iteration_id: i64) {
    let result, ok = run_program(s.program_text);
    if ok { s.result_val += result; }
}

fn checksum(s: BrainfuckArray&) -> u32 { s.result_val }