use super::super::{Benchmark, helper};
use crate::config_s;

// ================ Tape ================
struct Tape {
    cells: Vec<i32>,
    ptr: usize,
}

impl Tape {
    fn new() -> Self {
        Self {
            cells: vec![0; 30000],
            ptr: 0,
        }
    }
    
    #[inline(always)]
    fn current(&self) -> i32 {
        unsafe { *self.cells.get_unchecked(self.ptr) }
    }
    
    #[inline(always)]
    fn inc(&mut self) {
        unsafe {
            let cell = self.cells.get_unchecked_mut(self.ptr);
            *cell = cell.wrapping_add(1);
        }
    }
    
    #[inline(always)]
    fn dec(&mut self) {
        unsafe {
            let cell = self.cells.get_unchecked_mut(self.ptr);
            *cell = cell.wrapping_sub(1);
        }
    }
    
    #[inline(always)]
    fn advance(&mut self) {
        self.ptr += 1;
        if self.ptr >= self.cells.len() {
            self.cells.push(0);
        }
    }
    
    #[inline(always)]
    fn retreat(&mut self) {
        if self.ptr > 0 {
            self.ptr -= 1;
        }
    }
}

// ================ Program ================
struct Program {
    commands: Box<[u8]>,
    jumps: Box<[usize]>,
}

impl Program {
    fn new(source: &str) -> Self {
        // Фильтруем только BF команды
        let mut commands = Vec::with_capacity(source.len());
        for c in source.bytes() {
            if b"+-<>[].,".contains(&c) {
                commands.push(c);
            }
        }
        
        // Строим таблицу прыжков
        let mut jumps = vec![0; commands.len()];
        let mut stack = Vec::new();
        
        for (pc, &cmd) in commands.iter().enumerate() {
            match cmd {
                b'[' => stack.push(pc),
                b']' => {
                    if let Some(start) = stack.pop() {
                        jumps[start] = pc;
                        jumps[pc] = start;
                    }
                }
                _ => {}
            }
        }
        
        Self {
            commands: commands.into_boxed_slice(),
            jumps: jumps.into_boxed_slice(),
        }
    }
    
    fn run(&self) -> i64 {
        let mut tape = Tape::new();
        let mut pc = 0;
        let mut result = 0i64;
        
        while pc < self.commands.len() {
            unsafe {
                match *self.commands.get_unchecked(pc) {
                    b'+' => tape.inc(),
                    b'-' => tape.dec(),
                    b'>' => tape.advance(),
                    b'<' => tape.retreat(),
                    b'[' => {
                        if tape.current() == 0 {
                            pc = *self.jumps.get_unchecked(pc);
                        }
                    }
                    b']' => {
                        if tape.current() != 0 {
                            pc = *self.jumps.get_unchecked(pc);
                        }
                    }
                    b'.' => {
                        let cell = tape.current() as u8;
                        result = result.wrapping_shl(2).wrapping_add(cell as i64);
                    }
                    _ => unreachable!(),
                }
            }
            pc += 1;
        }
        
        result
    }
}

// ================ Benchmark ================
pub struct BrainfuckArray {
    program_text: String,
    warmup_text: String,
    result_val: u32,
}

impl BrainfuckArray {
    pub fn new() -> Self {
        Self {
            program_text: config_s("BrainfuckArray", "program"),
            warmup_text: config_s("BrainfuckArray", "warmup_program"),
            result_val: 0,
        }
    }
    
    fn run_program(&self, source: &str) -> i64 {
        let program = Program::new(source);
        program.run()
    }
}

impl Benchmark for BrainfuckArray {
    fn name(&self) -> String {
        "BrainfuckArray".to_string()
    }
    
    fn warmup(&mut self) {
        let iters = self.warmup_iterations();
        for _ in 0..iters {
            self.run_program(&self.warmup_text);
        }
    }
    
    fn run(&mut self, _iteration_id: i64) {
        let result = self.run_program(&self.program_text);
        self.result_val = self.result_val.wrapping_add(result as u32);
    }
    
    fn checksum(&self) -> u32 {
        self.result_val
    }
}