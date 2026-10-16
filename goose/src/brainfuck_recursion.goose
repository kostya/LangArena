namespace brainfuck_recursion;

import std;
import bench;

enum Op { Dec, Inc, Prev, Next, Print, Loop { body: Op[:] } }

struct Tape { pos: i64, tape: u8[>..] }

fn new_tape() -> Tape { Tape { pos: 0, tape: [0] } }

fn current_cell(t: Tape&) -> u8 { t.tape[t.pos] }

fn inc(t: Tape&) { t.tape[t.pos] += 1; }

fn dec(t: Tape&) { t.tape[t.pos] -= 1; }

fn prev(t: Tape&) {
    if t.pos > 0 { t.pos--; }
}

fn next(t: Tape&) {
    t.pos++;
    if t.pos >= t.tape.len { t.tape.resize(t.pos + 1, 0); }
}

struct Program { ops: Op[:] }

fn new_program(code: const u8[:], op_pool: Op[>..]&, pending: Op[>..<]&) -> Program {
    var pos = 0;
    return Program { ops: parse(code, pos, op_pool, pending) };
}

recursive fn parse(code: const u8[:], pos: i64&, op_pool: Op[>..]&, pending: Op[>..<]&) -> Op[:] {
    let mark = pending.len;
    while pos < code.len {
        let byte = code[pos];
        pos++;
        match byte {
            '-' => { pending.push(Op.Dec); },
            '+' => { pending.push(Op.Inc); },
            '<' => { pending.push(Op.Prev); },
            '>' => { pending.push(Op.Next); },
            '.' => { pending.push(Op.Print); },
            '[' => { pending.push(Op.Loop { body: parse(code, pos, op_pool, pending) }); },
            ']' => { break; },
            _ => { continue; },
        }
    }
    let start = op_pool.len;
    op_pool.append(pending[mark..]);
    pending.resize(mark);
    return op_pool[start..];
}

fn run(p: Program&) -> i64 {
    var tape = new_tape();
    var result: i64 = 0;
    p.execute(p.ops, tape, result);
    return result;
}

recursive fn execute(p: Program&, program: Op[:], tape: Tape&, result: i64&) {
    for op in program {
        match op {
            Dec => { tape.dec(); },
            Inc => { tape.inc(); },
            Prev => { tape.prev(); },
            Next => { tape.next(); },
            Print => { result = (result << 2) + tape.current_cell(); },
            Loop inner => {
                while tape.current_cell() != 0 { p.execute(inner.body, tape, result); }
            },
        }
    }
}

fn run_text(text: const u8[:]) -> i64 {
    var op_pool: Op[>..] = [];
    var pending: Op[>..<] = [];
    let program = new_program(text, op_pool, pending);
    return program.run();
}

struct BrainfuckRecursion { text: const u8[:], warmup_text: const u8[:], result_val: u32 }

fn new_brainfuck_recursion() -> BrainfuckRecursion {
    BrainfuckRecursion {
        text: config_s("Brainfuck::Recursion", "program"),
        warmup_text: config_s("Brainfuck::Recursion", "warmup_program"),
        result_val: 0,
    }
}

fn prepare(s: BrainfuckRecursion&) {}

fn warmup(s: BrainfuckRecursion&, iterations: i64) {
    for i in iterations { run_text(s.warmup_text); }
}

fn run(s: BrainfuckRecursion&, iteration_id: i64) {
    s.result_val += run_text(s.text) as! u32;
}

fn checksum(s: BrainfuckRecursion&) -> u32 { s.result_val }