use super::super::{Benchmark, helper};
use crate::config_s;

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
    
    fn run_program(&self, source: &str) -> Option<u32> {
        // 1. Парсим команды высокоуровневым способом
        let commands = Self::parse_commands(source)?;
        
        // 2. Строим таблицу прыжков через массив (ключевое отличие!)
        let jumps = Self::build_jump_array(&commands)?;
        
        // 3. Интерпретируем
        Self::interpret(&commands, &jumps).ok()
    }
    
    // Высокоуровневый парсинг с использованием итераторов
    fn parse_commands(source: &str) -> Option<Vec<u8>> {
        // Фильтруем только валидные BF команды
        Some(source
            .bytes()
            .filter(|c| c.is_ascii())
            .filter(|&c| matches!(c, 
                b'+' | b'-' | b'>' | b'<' | b'[' | b']' | b'.' | b','
            ))
            .collect())
    }
    
    // Строим массив прыжков (вместо HashMap)
    fn build_jump_array(commands: &[u8]) -> Option<Vec<usize>> {
        // Создаем массив такой же длины как команды
        let mut jumps = vec![0; commands.len()];
        let mut stack = Vec::new();
        
        // Заполняем массив соответствиями скобок
        for (i, &cmd) in commands.iter().enumerate() {
            match cmd {
                b'[' => stack.push(i),
                b']' => {
                    let start = stack.pop()?;  // Если стек пуст - ошибка
                    jumps[start] = i;
                    jumps[i] = start;
                }
                _ => {}
            }
        }
        
        // Проверяем корректность скобок
        if stack.is_empty() {
            Some(jumps)
        } else {
            None
        }
    }
    
    // Интерпретатор с безопасным доступом к массиву
    fn interpret(commands: &[u8], jumps: &[usize]) -> Result<u32, &'static str> {
        // Инициализируем ленту
        let mut tape = vec![0u8; 30000];
        let mut tape_ptr = 0;
        let mut pc = 0;
        let mut result = 0u32;
        
        // Основной цикл интерпретации
        while let Some(&cmd) = commands.get(pc) {
            match cmd {
                b'+' => {
                    // Безопасный доступ с проверкой границ
                    tape[tape_ptr] = tape[tape_ptr].wrapping_add(1);
                }
                b'-' => {
                    tape[tape_ptr] = tape[tape_ptr].wrapping_sub(1);
                }
                b'>' => {
                    tape_ptr += 1;
                    if tape_ptr >= tape.len() {
                        tape.push(0);  // Динамическое расширение
                    }
                }
                b'<' => {
                    // Используем checked_sub для безопасности
                    tape_ptr = tape_ptr.checked_sub(1).unwrap_or(0);
                }
                b'[' => {
                    if tape[tape_ptr] == 0 {
                        // Прыжок через массив jumps
                        pc = *jumps.get(pc).ok_or("Jump index out of bounds")?;
                    }
                }
                b']' => {
                    if tape[tape_ptr] != 0 {
                        pc = *jumps.get(pc).ok_or("Jump index out of bounds")?;
                    }
                }
                b'.' => {
                    // Вычисляем результат с проверкой переполнения
                    result = result
                        .checked_shl(2)
                        .and_then(|r| r.checked_add(tape[tape_ptr] as u32))
                        .ok_or("Result overflow")?;
                }
                _ => return Err("Invalid command encountered"),
            }
            pc += 1;
        }
        
        Ok(result)
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
