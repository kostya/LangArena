module benchmarks.brainfuckrecursion;

import std.stdio;
import std.string;
import std.array;
import std.algorithm;
import std.conv;
import std.typecons;
import benchmark;
import helper;

class BrainfuckRecursion : Benchmark {
private:
    static struct Op {
        enum Type { inc, move, print, loop }
        Type type;
        int val;  
        Op[] loopOps;  
    }

    static struct Tape {
        private ubyte[] tape;
        private size_t pos = 0;

        this(size_t size) {
            tape.length = size;
            tape[] = 0;
        }

        ubyte get() const { return tape[pos]; }

        void inc(int x) {
            tape[pos] += cast(ubyte)x;
        }

        void move(int x) {
            if (x >= 0) {
                pos += cast(size_t)x;
                if (pos >= tape.length) {
                    tape.length = max(tape.length * 2, pos + 1);
                }
            } else {
                int moveLeft = -x;
                if (cast(size_t)moveLeft > pos) {
                    size_t needed = cast(size_t)moveLeft - pos;
                    ubyte[] newTape = new ubyte[tape.length + needed];
                    newTape[needed .. $] = tape;
                    tape = newTape;
                    pos = needed;
                } else {
                    pos -= cast(size_t)moveLeft;
                }
            }
        }
    }

    static struct Program {
        Op[] ops;
        long resultVal;

        private Op[] parse(ref const(char)[] code) {
            Op[] res;

            while (!code.empty) {
                char c = code[0];
                code = code[1 .. $];

                switch (c) {
                    case '+':
                        res ~= Op(Op.Type.inc, 1);
                        break;
                    case '-':
                        res ~= Op(Op.Type.inc, -1);
                        break;
                    case '>':
                        res ~= Op(Op.Type.move, 1);
                        break;
                    case '<':
                        res ~= Op(Op.Type.move, -1);
                        break;
                    case '.':
                        res ~= Op(Op.Type.print);
                        break;
                    case '[':
                        auto loopOps = parse(code);
                        res ~= Op(Op.Type.loop, 0, loopOps);
                        break;
                    case ']':
                        return res;
                    default:
                        break;
                }
            }

            return res;
        }

        this(string code) {
            const(char)[] codeSlice = code;
            ops = parse(codeSlice);
            resultVal = 0;
        }

        private void runOp(const ref Op op, ref Tape tape) {
            switch (op.type) {
                case Op.Type.inc:
                    tape.inc(op.val);
                    break;
                case Op.Type.move:
                    tape.move(op.val);
                    break;
                case Op.Type.print:
                    resultVal = (resultVal << 2) + tape.get;
                    break;
                case Op.Type.loop:
                    while (tape.get != 0) {
                        foreach (innerOp; op.loopOps) {
                            runOp(innerOp, tape);
                        }
                    }
                    break;
                default:
                    assert(0, "Unknown operation type");
            }
        }

        long run() {
            resultVal = 0;
            auto tape = Tape(1024);
            foreach (op; ops) {
                runOp(op, tape);
            }
            return resultVal;
        }
    }

    string text;
    uint resultVal;

protected:

    override string className() const { return "BrainfuckRecursion"; }

public:
    this() {
        resultVal = 0;
        text = configStr("program");
    }

    override void warmup() {
        int prepareIters = warmupIterations();
        string warmupProgram = configStr("warmup_program");
        foreach (i; 0 .. prepareIters) {
            auto program = Program(warmupProgram);
            program.run();
        }
    }

    override void run(int iterationId) {
        auto program = Program(text);
        resultVal += cast(uint)program.run();
    }

    override uint checksum() {
        return resultVal;
    }
}