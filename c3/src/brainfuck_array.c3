module brainfuck;

import benchmark;
import helper;
import std::io;

struct Tape
{
	char* data;
	usz size;
	usz pos;
}

fn void tape_init(Tape* tape)
{
	tape.size = 30000;
	tape.data = mem::new_array(char, (sz)tape.size);
	tape.pos = 0;
}

fn void tape_destroy(Tape* tape)
{
	if (tape && tape.data)
	{
		free(tape.data);
		tape.data = null;
		tape.size = 0;
		tape.pos = 0;
	}
}

fn char tape_get(Tape* tape)
{
	return tape.data[tape.pos];
}

fn void tape_inc(Tape* tape)
{
	tape.data[tape.pos]++;
}

fn void tape_dec(Tape* tape)
{
	tape.data[tape.pos]--;
}

fn void tape_advance(Tape* tape)
{
	tape.pos++;
	if (tape.pos >= tape.size)
	{
		usz new_size   = tape.size + 1;
		char* new_tape = mem::realloc(tape.data, (sz)new_size);
		if (new_tape)
		{
			new_tape[tape.size] = 0;
			tape.data = new_tape;
			tape.size = new_size;
		}
	}
}

fn void tape_devance(Tape* tape)
{
	if (tape.pos > 0) tape.pos--;
}

fn char[] filter_commands(String input)
{
	if (input.len == 0) return { };

	sz count = 0;
	foreach (c : input)
	{
		switch (c)
		{
			case '[':
			case ']':
			case '<':
			case '>':
			case '+':
			case '-':
			case ',':
			case '.':
				count++;
			default:
				continue;
		}
	}

	if (count == 0) return { };

	char[] program = mem::alloc_array(char, count);
	usz pos        = 0;
	foreach (c : input)
	{
		switch (c)
		{
			case '[':
			case ']':
			case '<':
			case '>':
			case '+':
			case '-':
			case ',':
			case '.':
				program[pos++] = (char)c;
			default:
				continue;
		}
	}

	return program;
}

fn int[] build_jumps(char[] program)
{
	if (program.len == 0) return { };

	int[] jumps   =  mem::new_array(int, program.len);
	int[] stack   =  mem::alloc_array(int, program.len / 2 + 1);
	int stack_top = -1;

	for (int pc = 0; pc < (int)program.len; pc++)
	{
		char c = program[pc];
		if (c == '[')
		{
			stack[++stack_top] = pc;
		}
		else if (c == ']')
		{
			if (stack_top >= 0)
			{
				int left = stack[stack_top--];
				jumps[left] = pc;
				jumps[pc] = left;
			}
		}
	}

	free(stack);
	return jumps;
}

fn uint execute_program(char[] program, int[] jumps)
{
	if (program.len == 0 || jumps.len == 0) return 0;

	Tape tape;
	tape_init(&tape);
	defer tape_destroy(&tape);

	int pc      = 0;
	uint result = 0;

	while (pc < (int)program.len)
	{
		char c = program[pc];
		switch (c)
		{
			case '+':
				tape_inc(&tape);
				break;
			case '-':
				tape_dec(&tape);
				break;
			case '>':
				tape_advance(&tape);
				break;
			case '<':
				tape_devance(&tape);
				break;
			case '[':
				if (tape_get(&tape) == 0) pc = jumps[pc];
				break;
			case ']':
				if (tape_get(&tape) != 0) pc = jumps[pc];
				break;
			case '.':
				result = (result << 2) + (uint)tape_get(&tape);
				break;
			default:
				break;
		}
		pc++;
	}

	return result;
}

struct BrainfuckArrayData
{
	char[] program;
	char[] warmup_program;
	int[] jumps;
	int[] warmup_jumps;
	uint result_val;
}

fn void brainfuck_array_prepare(Benchmark* self)
{
	BrainfuckArrayData* data = (BrainfuckArrayData*)self.data;

	String program_text = helper::helper_config_s(self.name, "program");
	String warmup_text  = helper::helper_config_s(self.name, "warmup_program");

	data.program = filter_commands(program_text);
	data.jumps = build_jumps(data.program);

	data.warmup_program = filter_commands(warmup_text);
	data.warmup_jumps = build_jumps(data.warmup_program);
}

fn void brainfuck_array_warmup(Benchmark* self)
{
	BrainfuckArrayData* data = (BrainfuckArrayData*)self.data;

	if (data.warmup_program.len == 0) return;

	long warmup_iters = helper::helper_config_i64(self.name, "warmup_iterations");
	if (warmup_iters == 0)
	{
		warmup_iters = self.iterations(self) / 5;
		if (warmup_iters < 1) warmup_iters = 1;
	}

	for (long i = 0; i < warmup_iters; i++)
	{
		execute_program(data.warmup_program, data.warmup_jumps);
	}
}

fn void brainfuck_array_run(Benchmark* self, int iteration_id)
{
	BrainfuckArrayData* data = (BrainfuckArrayData*)self.data;

	if (iteration_id == 0) data.result_val = 0;

	if (data.program.len > 0)
	{
		uint run_result = execute_program(data.program, data.jumps);
		data.result_val += run_result;
	}
}

fn uint brainfuck_array_checksum(Benchmark* self)
{
	BrainfuckArrayData* data = (BrainfuckArrayData*)self.data;
	return data.result_val;
}

fn void brainfuck_array_cleanup(Benchmark* self)
{
	if (!self || !self.data) return;

	BrainfuckArrayData* data = (BrainfuckArrayData*)self.data;

	free(data.program);
	free(data.jumps);
	free(data.warmup_program);
	free(data.warmup_jumps);

	free(self.data);
	self.data = null;
}

fn Benchmark* brainfuck_array_create() @cname("BrainfuckArray_create") @export
{
	Benchmark* bench = benchmark::benchmark_create("Brainfuck::Array");

	BrainfuckArrayData* data = mem::new(BrainfuckArrayData);

	bench.data = data;
	bench.prepare = (PrepareFn)&brainfuck_array_prepare;
	bench.warmup = (WarmupFn)&brainfuck_array_warmup;
	bench.run = (RunFn)&brainfuck_array_run;
	bench.checksum = (ChecksumFn)&brainfuck_array_checksum;
	bench.cleanup = (CleanupFn)&brainfuck_array_cleanup;

	return bench;
}