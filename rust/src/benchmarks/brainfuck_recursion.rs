use super::super::{Benchmark, helper};
use super::super::config_s;

#[derive(Clone)]
enum Op {
    Dec,
    Inc,
    Prev,
    Next,
    Print,
    Loop(Box<[Op]>),
}

struct Tape {
    pos: usize,
    tape: Vec<i32>,
}

impl Tape {
    fn new() -> Self {
        Self {
            pos: 0,
            tape: vec![0],
        }
    }

    fn current_cell(&self) -> i32 {
        self.tape[self.pos]
    }

    fn inc(&mut self, x: i32) {
        self.tape[self.pos] = self.tape[self.pos].wrapping_add(x);
    }

    fn prev(&mut self) {
        self.pos -= 1;
    }

    fn next(&mut self) {
        self.pos += 1;
        if self.pos >= self.tape.len() {
            self.tape.resize(self.pos * 2, 0);
        }
    }
}

struct Program {
    ops: Box<[Op]>,
}

impl Program {
    fn new(code: &str) -> Self {
        Self {
            ops: Self::parse(&mut code.bytes()),
        }
    }

    fn parse(iter: &mut impl Iterator<Item = u8>) -> Box<[Op]> {
        let mut buf = Vec::new();
        while let Some(byte) = iter.next() {
            let op = match byte {
                b'-' => Op::Dec,
                b'+' => Op::Inc,
                b'<' => Op::Prev,
                b'>' => Op::Next,
                b'.' => Op::Print,
                b'[' => Op::Loop(Self::parse(iter)),
                b']' => break,
                _ => continue,
            };
            buf.push(op);
        }
        buf.into_boxed_slice()
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
                Op::Dec => tape.inc(-1),
                Op::Inc => tape.inc(1),
                Op::Prev => tape.prev(),
                Op::Next => tape.next(),
                Op::Print => {
                    let cell = tape.current_cell() as u8;
                    *result = ((*result << 2) as i64).wrapping_add(cell as i64);
                }
                Op::Loop(inner_program) => {
                    while tape.current_cell() != 0 {
                        self.execute(inner_program, tape, result);
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
        let text = config_s("BrainfuckRecursion", "program");
        let warmup_text = config_s("BrainfuckRecursion", "warmup_program");

        Self {
            text,
            warmup_text,
            result_val: 0,
        }
    }

    fn _run(&self, text: &str) -> i64 {
        let program = Program::new(text);
        program.run()
    }
}

impl Benchmark for BrainfuckRecursion {
    fn name(&self) -> String {
        "BrainfuckRecursion".to_string()
    }

    fn warmup(&mut self) {
        let prepare_iters = self.warmup_iterations();
        for i in 0..prepare_iters {
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