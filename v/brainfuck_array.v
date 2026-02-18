module brainfuck_array

import benchmark
import helper

struct BFTape {
mut:
	data []u8
	pos  int
}

fn new_tape() BFTape {
	return BFTape{
		data: []u8{len: 30000, cap: 30000, init: 0}
		pos:  0
	}
}

fn (mut t BFTape) get() u8 {
	return t.data[t.pos]
}

fn (mut t BFTape) inc() {
	t.data[t.pos]++
}

fn (mut t BFTape) dec() {
	t.data[t.pos]--
}

fn (mut t BFTape) advance() {
	t.pos++
	if t.pos >= t.data.len {
		t.data << 0
	}
}

fn (mut t BFTape) devance() {
	if t.pos > 0 {
		t.pos--
	}
}

struct BFProgram {
mut:
	commands []u8
	jumps    []int
}

fn new_program(code string) BFProgram {
	mut commands := []u8{}

	for c in code {
		match c {
			`[`, `]`, `<`, `>`, `+`, `-`, `,`, `.` {
				commands << u8(c)
			}
			else {}
		}
	}

	mut jumps := []int{len: commands.len, init: 0}
	mut stack := []int{}

	for i, cmd in commands {
		if cmd == `[` {
			stack << i
		} else if cmd == `]` && stack.len > 0 {
			start := stack.pop()
			jumps[start] = i
			jumps[i] = start
		}
	}

	return BFProgram{
		commands: commands
		jumps:    jumps
	}
}

fn (p BFProgram) run() u32 {
	mut tape := new_tape()
	mut result := u32(0)
	mut pc := 0
	cmds := p.commands
	jumps := p.jumps

	for pc < cmds.len {
		cmd := cmds[pc]

		match cmd {
			`+` {
				tape.inc()
			}
			`-` {
				tape.dec()
			}
			`>` {
				tape.advance()
			}
			`<` {
				tape.devance()
			}
			`[` {
				if tape.get() == 0 {
					pc = jumps[pc]
				}
			}
			`]` {
				if tape.get() != 0 {
					pc = jumps[pc]
				}
			}
			`.` {

				result = (result << 2) + u32(tape.get())
			}
			else {}
		}

		pc++
	}

	return result
}

pub struct BrainfuckArray {
	benchmark.BaseBenchmark
mut:
	program_text string
	warmup_text  string
	result_val   u32
}

pub fn new_brainfuck_array() &benchmark.IBenchmark {
	mut bench := &BrainfuckArray{
		BaseBenchmark: benchmark.new_base_benchmark('BrainfuckArray')
		program_text:  ''
		warmup_text:   ''
		result_val:    0
	}
	return bench
}

pub fn (b BrainfuckArray) name() string {
	return 'BrainfuckArray'
}

fn run_program_impl(text string) u64 {
	program := new_program(text)
	return program.run()
}

pub fn (mut b BrainfuckArray) run(iteration_id int) {
	_ = iteration_id
	result := run_program_impl(b.program_text)
	b.result_val += u32(result)
}

pub fn (b BrainfuckArray) checksum() u32 {
	return b.result_val
}

pub fn (mut b BrainfuckArray) prepare() {
	b.program_text = helper.config_string('BrainfuckArray', 'program')
	b.warmup_text = helper.config_string('BrainfuckArray', 'warmup_program')
	b.result_val = 0
}

pub fn (mut b BrainfuckArray) warmup(mut bench benchmark.IBenchmark) {
	warmup_iters := b.warmup_iterations()
	for _ in 0 .. warmup_iters {
		run_program_impl(b.warmup_text)
	}
}