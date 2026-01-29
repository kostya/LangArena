use super::super::{Benchmark, helper};
use crate::config_s;
use std::collections::HashMap;

struct Tape {
    tape: Vec<i32>,
    pos: usize,
}

impl Tape {
    fn new() -> Self {
        Self {
            tape: vec![0],
            pos: 0,
        }
    }

    #[inline(always)]
    fn get(&self) -> i32 {
        self.tape[self.pos]
    }

    #[inline(always)]
    fn inc(&mut self) {
        self.tape[self.pos] = self.tape[self.pos].wrapping_add(1);
    }

    #[inline(always)]
    fn dec(&mut self) {
        self.tape[self.pos] = self.tape[self.pos].wrapping_sub(1);
    }

    #[inline(always)]
    fn advance(&mut self) {
        self.pos += 1;
        if self.pos >= self.tape.len() {
            self.tape.push(0);
        }
    }

    #[inline(always)]
    fn devance(&mut self) {
        if self.pos > 0 {
            self.pos -= 1;
        }
    }
}

struct Program {
    chars: Vec<char>,
    bracket_map: HashMap<usize, usize>,
}

impl Program {
    fn new(text: &str) -> Self {
        let mut chars = Vec::new();
        let mut bracket_map = HashMap::new();
        let mut leftstack = Vec::new();
        let mut pc = 0;
        
        for char in text.chars() {
            if "+-<>[].,".contains(char) {
                chars.push(char);
                
                match char {
                    '[' => {
                        leftstack.push(pc);
                    }
                    ']' => {
                        if let Some(left) = leftstack.pop() {
                            let right = pc;
                            bracket_map.insert(left, right);
                            bracket_map.insert(right, left);
                        }
                    }
                    _ => {}
                }
                
                pc += 1;
            }
        }
        
        Self { chars, bracket_map }
    }

    fn run(&self) -> i64 {
        let mut result = 0i64;
        let mut tape = Tape::new();
        let mut pc = 0;
        let chars_len = self.chars.len();
        
        while pc < chars_len {
            match self.chars[pc] {
                '+' => tape.inc(),
                '-' => tape.dec(),
                '>' => tape.advance(),
                '<' => tape.devance(),
                '[' => {
                    if tape.get() == 0 {
                        if let Some(&jump_to) = self.bracket_map.get(&pc) {
                            pc = jump_to;
                        }
                    }
                }
                ']' => {
                    if tape.get() != 0 {
                        if let Some(&jump_to) = self.bracket_map.get(&pc) {
                            pc = jump_to;
                        }
                    }
                }
                '.' => {
                    let cell = tape.get() as u8;
                    result = ((result << 2) as i64).wrapping_add(cell as i64);
                }
                _ => {}
            }
            pc += 1;
        }
        
        result
    }
}

pub struct BrainfuckHashMap {
    text: String,
    warmup_text: String,
    result_val: u32,
}

impl BrainfuckHashMap {
    pub fn new() -> Self {
        let text = config_s("BrainfuckHashMap", "program");
        let warmup_text = config_s("BrainfuckHashMap", "warmup_program");
        
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

impl Benchmark for BrainfuckHashMap {
    fn name(&self) -> String {
        "BrainfuckHashMap".to_string()
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