module benchmarks.brainfuckrecursion;

import std.stdio;
import std.string;
import std.array;
import std.algorithm;
import std.conv;
import std.typecons;
import benchmark;
import helper;

class BrainfuckRecursion : Benchmark
{
private:
    static struct Op
    {
        enum Type
        {
            inc,
            dec,
            right,
            left,
            print,
            loop
        }

        Type type;
        Op[] loopOps;
    }

    static struct Tape
    {
        private ubyte[] tape;
        private size_t pos = 0;

        this(size_t size)
        {
            tape.length = size;
            tape[] = 0;
        }

        ubyte get() const
        {
            return tape[pos];
        }

        void inc()
        {
            tape[pos]++;
        }

        void dec()
        {
            tape[pos]--;
        }

        void right()
        {
            pos++;
            if (pos >= tape.length)
            {
                tape ~= 0;
            }
        }

        void left()
        {
            if (pos > 0)
            {
                pos--;
            }
        }
    }

    static struct Program
    {
        Op[] ops;
        long resultVal;

        private Op[] parse(ref const(char)[] code)
        {
            Op[] res;

            while (!code.empty)
            {
                char c = code[0];
                code = code[1 .. $];

                switch (c)
                {
                case '+':
                    res ~= Op(Op.Type.inc);
                    break;
                case '-':
                    res ~= Op(Op.Type.dec);
                    break;
                case '>':
                    res ~= Op(Op.Type.right);
                    break;
                case '<':
                    res ~= Op(Op.Type.left);
                    break;
                case '.':
                    res ~= Op(Op.Type.print);
                    break;
                case '[':
                    auto loopOps = parse(code);
                    res ~= Op(Op.Type.loop, loopOps);
                    break;
                case ']':
                    return res;
                default:
                    break;
                }
            }

            return res;
        }

        this(string code)
        {
            const(char)[] codeSlice = code;
            ops = parse(codeSlice);
            resultVal = 0;
        }

        private void runOp(const ref Op op, ref Tape tape)
        {
            final switch (op.type)
            {
            case Op.Type.inc:
                tape.inc();
                break;
            case Op.Type.dec:
                tape.dec();
                break;
            case Op.Type.right:
                tape.right();
                break;
            case Op.Type.left:
                tape.left();
                break;
            case Op.Type.print:
                resultVal = (resultVal << 2) + tape.get();
                break;
            case Op.Type.loop:
                while (tape.get() != 0)
                {
                    foreach (innerOp; op.loopOps)
                    {
                        runOp(innerOp, tape);
                    }
                }
                break;
            }
        }

        long run()
        {
            resultVal = 0;
            auto tape = Tape(30000);
            foreach (op; ops)
            {
                runOp(op, tape);
            }
            return resultVal;
        }
    }

    string text;
    uint resultVal;

protected:
    override string className() const
    {
        return "BrainfuckRecursion";
    }

public:
    this()
    {
        resultVal = 0;
        text = configStr("program");
    }

    override void warmup()
    {
        int prepareIters = warmupIterations();
        string warmupProgram = configStr("warmup_program");
        foreach (i; 0 .. prepareIters)
        {
            auto program = Program(warmupProgram);
            program.run();
        }
    }

    override void run(int iterationId)
    {
        auto program = Program(text);
        resultVal += cast(uint) program.run();
    }

    override uint checksum()
    {
        return resultVal;
    }
}
