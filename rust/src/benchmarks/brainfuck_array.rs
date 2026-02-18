use super::super::Benchmark;
use crate::config_s;

pub struct BrainfuckArray {
    program_text: String,
    warmup_text: String,
    result_val: u32,
}

struct Tape {
    tape: Vec<u8>,
    pos: usize,
}

impl Tape {
    fn new() -> Self {
        Tape {
            tape: vec![0; 30000],
            pos: 0,
        }
    }

    fn get(&self) -> u8 {
        self.tape[self.pos]  
    }

    fn inc(&mut self) {
        self.tape[self.pos] = self.tape[self.pos].wrapping_add(1);
    }

    fn dec(&mut self) {
        self.tape[self.pos] = self.tape[self.pos].wrapping_sub(1);
    }

    fn advance(&mut self) {
        self.pos += 1;
        if self.pos >= self.tape.len() {
            self.tape.push(0);
        }
    }

    fn devance(&mut self) {
        if self.pos > 0 {
            self.pos -= 1;
        }
    }
}

struct Program {
    commands: Vec<u8>,
    jumps: Vec<usize>,
}

impl Program {
    fn new(text: &str) -> Option<Self> {
        let commands: Vec<u8> = text
            .bytes()
            .filter(|c| matches!(c, b'+' | b'-' | b'>' | b'<' | b'[' | b']' | b'.' | b','))
            .collect();

        if commands.is_empty() {
            return None;
        }

        let mut jumps = vec![0; commands.len()];
        let mut stack = Vec::new();

        for (i, &cmd) in commands.iter().enumerate() {
            match cmd {
                b'[' => stack.push(i),
                b']' => {
                    let start = stack.pop()?;
                    jumps[start] = i;
                    jumps[i] = start;
                }
                _ => {}
            }
        }

        if stack.is_empty() {
            Some(Program { commands, jumps })
        } else {
            None
        }
    }

    fn run(&self) -> Option<u32> {
        let mut tape = Tape::new();
        let mut pc = 0;
        let mut result = 0u32;

        while let Some(&cmd) = self.commands.get(pc) {
            match cmd {
                b'+' => tape.inc(),
                b'-' => tape.dec(),
                b'>' => tape.advance(),
                b'<' => tape.devance(),
                b'[' => if tape.get() == 0 { pc = self.jumps[pc]; },
                b']' => if tape.get() != 0 { pc = self.jumps[pc]; },
                b'.' => result = result.wrapping_shl(2).wrapping_add(tape.get() as u32),
                _ => return None,
            }
            pc += 1;
        }

        Some(result)
    }
}

impl BrainfuckArray {
    pub fn new() -> Self {
        Self {
            program_text: config_s("BrainfuckArray", "program"),
            warmup_text: config_s("BrainfuckArray", "warmup_program"),
            result_val: 0,
        }
    }

    fn run_program(&self, source: &str) -> Option<u32> {
        let program = Program::new(source)?;
        program.run()
    }
}

impl Benchmark for BrainfuckArray {
    fn name(&self) -> String {
        "BrainfuckArray".to_string()
    }

    fn warmup(&mut self) {
        let prepare_iters = self.warmup_iterations();
        for _ in 0..prepare_iters {
            let _ = self.run_program(&self.warmup_text);
        }
    }

    fn run(&mut self, _iteration_id: i64) {
        if let Some(result) = self.run_program(&self.program_text) {
            self.result_val = self.result_val.wrapping_add(result);
        }
    }

    fn checksum(&self) -> u32 {
        self.result_val
    }
}