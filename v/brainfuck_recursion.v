module brainfuck_recursion

import benchmark
import helper

struct IncOp {}

struct DecOp {}

struct NextOp {}

struct PrevOp {}

struct PrintOp {}

struct LoopOp {
	ops []Op
}

type Op = IncOp | DecOp | NextOp | PrevOp | PrintOp | LoopOp

struct ParseResult {
	ops []Op
	pos int
}

fn parse_program(pos int, runes []rune) ParseResult {
	mut res := []Op{}
	mut current_pos := pos

	for current_pos < runes.len {
		c := runes[current_pos]
		current_pos++

		match c {
			`+` {
				res << IncOp{}
			}
			`-` {
				res << DecOp{}
			}
			`>` {
				res << NextOp{}
			}
			`<` {
				res << PrevOp{}
			}
			`.` {
				res << PrintOp{}
			}
			`[` {
				inner := parse_program(current_pos, runes)
				res << LoopOp{
					ops: inner.ops
				}
				current_pos = inner.pos
			}
			`]` {
				return ParseResult{res, current_pos}
			}
			else {}
		}
	}
	return ParseResult{res, current_pos}
}

struct Program {
mut:
	ops    []Op
	result i64
}

fn new_program(code string) Program {
	runes := code.runes()
	parse_result := parse_program(0, runes)
	return Program{
		ops:    parse_result.ops
		result: 0
	}
}

struct Tape {
mut:
	data []u8
	pos  int
}

fn (t Tape) get() u8 {
	return t.data[t.pos]
}

fn (mut t Tape) inc() {
	t.data[t.pos]++
}

fn (mut t Tape) dec() {
	t.data[t.pos]--
}

fn (mut t Tape) next() {
	t.pos++
	if t.pos >= t.data.len {
		t.data << 0
	}
}

fn (mut t Tape) prev() {
	if t.pos > 0 {
		t.pos--
	}
}

fn (mut p Program) run_ops(ops []Op, mut tape Tape) {
	for op in ops {
		match op {
			IncOp {
				tape.inc()
			}
			DecOp {
				tape.dec()
			}
			NextOp {
				tape.next()
			}
			PrevOp {
				tape.prev()
			}
			PrintOp {
				p.result = (p.result << 2) + i64(tape.get())
			}
			LoopOp {
				for tape.get() != 0 {
					p.run_ops(op.ops, mut tape)
				}
			}
		}
	}
}

fn (mut p Program) run() {
	mut tape := Tape{
		data: [u8(0)]
		pos:  0
	}
	p.run_ops(p.ops, mut tape)
}

pub struct BrainfuckRecursion {
	benchmark.BaseBenchmark
mut:
	text       string
	result_val u32
}

pub fn new_brainfuck_recursion() &benchmark.IBenchmark {
	return &BrainfuckRecursion{
		BaseBenchmark: benchmark.new_base_benchmark('BrainfuckRecursion')
		text:          ''
		result_val:    0
	}
}

pub fn (b BrainfuckRecursion) name() string {
	return 'BrainfuckRecursion'
}

pub fn (mut b BrainfuckRecursion) prepare() {
	b.text = helper.config_string('BrainfuckRecursion', 'program')
	b.result_val = 0
}

fn run_bf_program(text string) i64 {
	mut prog := new_program(text)
	prog.run()
	return prog.result
}

pub fn (mut b BrainfuckRecursion) run(iteration_id int) {
	result := run_bf_program(b.text)
	b.result_val += u32(result)
}

pub fn (b BrainfuckRecursion) checksum() u32 {
	return b.result_val
}

pub fn (mut b BrainfuckRecursion) warmup(mut bench benchmark.IBenchmark) {
	warmup_program := helper.config_string('BrainfuckRecursion', 'warmup_program')
	wi := b.warmup_iterations()
	for _ in 0 .. wi {
		run_bf_program(warmup_program)
	}
}
