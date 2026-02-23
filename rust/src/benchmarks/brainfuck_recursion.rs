use super::super::config_s;
use super::super::Benchmark;

enum Op {
    Dec,
    Inc,
    Prev,
    Next,
    Print,
    Loop(Vec<Op>),
}

struct Tape {
    pos: usize,
    tape: Vec<u8>,
}

impl Tape {
    fn new() -> Self {
        Self {
            pos: 0,
            tape: vec![0],
        }
    }

    fn current_cell(&self) -> u8 {
        self.tape[self.pos]
    }

    fn inc(&mut self) {
        self.tape[self.pos] = self.tape[self.pos].wrapping_add(1);
    }

    fn dec(&mut self) {
        self.tape[self.pos] = self.tape[self.pos].wrapping_sub(1);
    }

    fn prev(&mut self) {
        if self.pos > 0 {
            self.pos -= 1;
        }
    }

    fn next(&mut self) {
        self.pos += 1;
        if self.pos >= self.tape.len() {
            self.tape.resize(self.pos + 1, 0);
        }
    }
}

struct Program {
    ops: Vec<Op>,
}

impl Program {
    fn new(code: &str) -> Self {
        Self {
            ops: Self::parse(&mut code.bytes()),
        }
    }

    fn parse(iter: &mut impl Iterator<Item = u8>) -> Vec<Op> {
        let mut buf = Vec::new();
        while let Some(byte) = iter.next() {
            match byte {
                b'-' => buf.push(Op::Dec),
                b'+' => buf.push(Op::Inc),
                b'<' => buf.push(Op::Prev),
                b'>' => buf.push(Op::Next),
                b'.' => buf.push(Op::Print),
                b'[' => buf.push(Op::Loop(Self::parse(iter))),
                b']' => break,
                _ => continue,
            }
        }
        buf
    }

    fn run(&self) -> i64 {
        let mut tape = Tape::new();
        let mut result = 0i64;
        self.execute(&self.ops, &mut tape, &mut result);
        result
    }

    fn execute(&self, program: &[Op], tape: &mut Tape, result: &mut i64) {
        for op in program {
            match op {
                Op::Dec => tape.dec(),
                Op::Inc => tape.inc(),
                Op::Prev => tape.prev(),
                Op::Next => tape.next(),
                Op::Print => {
                    *result = ((*result << 2) as i64).wrapping_add(tape.current_cell() as i64);
                }
                Op::Loop(inner) => {
                    while tape.current_cell() != 0 {
                        self.execute(inner, tape, result);
                    }
                }
            }
        }
    }
}

pub struct BrainfuckRecursion {
    text: String,
    warmup_text: String,
    result_val: u32,
}

impl BrainfuckRecursion {
    pub fn new() -> Self {
        let text = config_s("Brainfuck::Recursion", "program");
        let warmup_text = config_s("Brainfuck::Recursion", "warmup_program");
        Self {
            text,
            warmup_text,
            result_val: 0,
        }
    }

    fn _run(&self, text: &str) -> i64 {
        Program::new(text).run()
    }
}

impl Benchmark for BrainfuckRecursion {
    fn name(&self) -> String {
        "Brainfuck::Recursion".to_string()
    }

    fn warmup(&mut self) {
        let prepare_iters = self.warmup_iterations();
        for _ in 0..prepare_iters {
            self._run(&self.warmup_text);
        }
    }

    fn run(&mut self, _iteration_id: i64) {
        let result = self._run(&self.text);
        self.result_val = self.result_val.wrapping_add(result as u32);
    }

    fn checksum(&self) -> u32 {
        self.result_val
    }
}
