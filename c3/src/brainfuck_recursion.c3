module brainfuck_rec;

import benchmark;
import helper;
import std::io;

enum OpType
{
	INC,
	DEC,
	RIGHT,
	LEFT,
	PRINT,
	LOOP,
}

struct Op
{
	OpType type;
	Op* loop_ops;
	int loop_size;
}

struct TapeRec
{
	char* data;
	int size;
	int pos;
}

fn TapeRec* tape_new()
{
	TapeRec* self = mem::new(TapeRec);
	self.size = 30000;
	self.data = mem::new_array(char, self.size);
	self.pos = 0;
	return self;
}

fn char tape_get(TapeRec* self)
{
	return self.data[self.pos];
}

fn void tape_inc(TapeRec* self)
{
	self.data[self.pos]++;
}

fn void tape_dec(TapeRec* self)
{
	self.data[self.pos]--;
}

fn void tape_right(TapeRec* self)
{
	self.pos++;
	if (self.pos >= self.size)
	{
		self.size++;
		self.data = mem::realloc(self.data, (usz)self.size);
		self.data[self.size - 1] = 0;
	}
}

fn void tape_left(TapeRec* self)
{
	if (self.pos > 0) self.pos--;
}

fn void tape_free(TapeRec* self)
{
	free(self.data);
	free(self);
}

fn Op[] parse_ops(ZString* code, int* ops_count)
{
	int capacity = 16;
	Op* ops      = mem::alloc_array(Op, capacity);
	int count    = 0;

	while ((*code)[0])
	{
		if (count >= capacity)
		{
			capacity *= 2;
			ops = (Op*)mem::realloc(ops, Op::size * capacity);
		}

		switch ((*code)[0])
		{
			case '+':
				ops[count].type = INC;
				ops[count].loop_ops = null;
				ops[count].loop_size = 0;
				count++;
				break;
			case '-':
				ops[count].type = DEC;
				ops[count].loop_ops = null;
				ops[count].loop_size = 0;
				count++;
				break;
			case '>':
				ops[count].type = RIGHT;
				ops[count].loop_ops = null;
				ops[count].loop_size = 0;
				count++;
				break;
			case '<':
				ops[count].type = LEFT;
				ops[count].loop_ops = null;
				ops[count].loop_size = 0;
				count++;
				break;
			case '.':
				ops[count].type = PRINT;
				ops[count].loop_ops = null;
				ops[count].loop_size = 0;
				count++;
				break;
			case '[':
				(*code)++;
				ops[count].type = LOOP;
				int loop_ops_count = 0;
				Op* loop_body = parse_ops(code, &loop_ops_count);
				ops[count].loop_ops = loop_body;
				ops[count].loop_size = loop_ops_count;
				count++;
				continue;
			case ']':
				*ops_count = count;
				(*code)++;
				return ops[:count];
			default:
				break;
		}
		(*code)++;
	}

	*ops_count = count;
	return ops[:count];
}

fn void free_ops(Op[] ops)
{
	foreach (&op : ops)
	{
		if (op.type == LOOP && op.loop_ops)
		{
			free_ops(op.loop_ops[:op.loop_size]);
		}
	}
	free(ops);
}

fn void run_ops(Op[] ops, TapeRec* tape, uint* result)
{
	foreach (&op : ops)
	{
		switch (op.type)
		{
			case INC:
				tape_inc(tape);
				break;
			case DEC:
				tape_dec(tape);
				break;
			case RIGHT:
				tape_right(tape);
				break;
			case LEFT:
				tape_left(tape);
				break;
			case PRINT:
				*result = (*result << 2) + (uint)tape_get(tape);
				break;
			case LOOP:
				while (tape_get(tape) != 0)
				{
					run_ops(op.loop_ops[:op.loop_size], tape, result);
				}
				break;
		}
	}
}

fn uint run_program(String code)
{
	if (code.len == 0) return 0;

	int ops_count    = 0;
	ZString code_ptr = (ZString)code;
	Op[] ops         = parse_ops(&code_ptr, &ops_count);

	if (ops.len == 0) return 0;

	TapeRec* tape = tape_new();
	defer tape_free(tape);

	uint result = 0;
	run_ops(ops, tape, &result);

	free_ops(ops);

	return result;
}

struct BrainfuckRecursionData
{
	String program;
	String warmup_program;
	uint result_val;
}

fn void brainfuck_rec_prepare(Benchmark* self)
{
	BrainfuckRecursionData* data = (BrainfuckRecursionData*)self.data;
	data.program = helper::helper_config_s(self.name, "program");
	data.warmup_program = helper::helper_config_s(self.name, "warmup_program");
}

fn void brainfuck_rec_warmup(Benchmark* self)
{
	BrainfuckRecursionData* data = (BrainfuckRecursionData*)self.data;

	long warmup_iters = helper::helper_config_i64(self.name, "warmup_iterations");
	if (warmup_iters == 0)
	{
		warmup_iters = self.iterations(self);
		warmup_iters = (long)(warmup_iters * 0.2);
		if (warmup_iters < 1) warmup_iters = 1;
	}

	for (long i = 0; i < warmup_iters; i++)
	{
		run_program(data.warmup_program);
	}
}

fn void brainfuck_rec_run(Benchmark* self, int iteration_id)
{
	BrainfuckRecursionData* data = (BrainfuckRecursionData*)self.data;

	if (iteration_id == 0) data.result_val = 0;

	uint run_result = run_program(data.program);
	data.result_val += run_result;
}

fn uint brainfuck_rec_checksum(Benchmark* self)
{
	BrainfuckRecursionData* data = (BrainfuckRecursionData*)self.data;
	return data.result_val;
}

fn void brainfuck_rec_cleanup(Benchmark* self)
{
}

fn Benchmark* brainfuck_recursion_create() @cname("BrainfuckRecursion_create") @export
{
	Benchmark* bench = benchmark::benchmark_create("Brainfuck::Recursion");

	BrainfuckRecursionData* data = mem::new(BrainfuckRecursionData);

	bench.data = data;
	bench.prepare = (PrepareFn)&brainfuck_rec_prepare;
	bench.warmup = (WarmupFn)&brainfuck_rec_warmup;
	bench.run = (RunFn)&brainfuck_rec_run;
	bench.checksum = (ChecksumFn)&brainfuck_rec_checksum;
	bench.cleanup = (CleanupFn)&brainfuck_rec_cleanup;

	return bench;
}