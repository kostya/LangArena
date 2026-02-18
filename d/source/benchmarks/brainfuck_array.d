module benchmarks.brainfuckarray;

import std.stdio;
import std.string;
import std.array;
import std.algorithm;
import std.conv;
import benchmark;
import helper;

class BrainfuckArray : Benchmark {
private:
    static struct Tape {
        private ubyte[] tape;
        private size_t pos;

        this(size_t size) {
            tape = new ubyte[size];
            pos = 0;
        }

    @trusted:
        @property ubyte get() const { return tape[pos]; }
        void inc() { tape[pos]++; }
        void dec() { tape[pos]--; }

        void advance() {
            pos++;
            if (pos >= tape.length) {
                tape.length = tape.length + 1;
            }
        }

        void devance() {
            if (pos > 0) pos--;
        }
    }

    static struct Program {
        private ubyte[] commands;
        private size_t[] jumps;

        this(string text) {

            commands.length = 0;
            foreach (c; text) {
                if ("[]<>+-,.".indexOf(c) != -1) {
                    commands ~= cast(ubyte)c;
                }
            }

            jumps.length = commands.length;
            jumps[] = 0;
            size_t[] stack;

            foreach (i, cmd; commands) {
                if (cmd == '[') {
                    stack ~= i;
                } else if (cmd == ']' && !stack.empty) {
                    size_t start = stack.back;
                    stack.popBack;
                    jumps[start] = i;
                    jumps[i] = start;
                }
            }
        }

        long _run(const ubyte[] commands, const size_t[] jumps) {
            long result = 0;
            auto tape = Tape(30000);  
            size_t pc = 0;

            while (pc < commands.length) {
                ubyte cmd = commands[pc];
                switch (cmd) {
                    case '+': tape.inc(); break;
                    case '-': tape.dec(); break;
                    case '>': tape.advance(); break;
                    case '<': tape.devance(); break;
                    case '[': 
                        if (tape.get == 0) {
                            pc = jumps[pc];
                            continue;
                        }
                        break;
                    case ']': 
                        if (tape.get != 0) {
                            pc = jumps[pc];
                            continue;
                        }
                        break;
                    case '.': 
                        result = (result << 2) + tape.get;
                        break;
                    default: break;
                }
                pc++;
            }
            return result;
        }

        long run() {
            return _run(commands, jumps);
        }
    }

    string programText;
    string warmupText;
    uint resultVal;

    long _run(string text) {
        auto program = Program(text);
        return program.run();
    }

protected:
    override string className() const { return "BrainfuckArray"; }

public:
    this() {
        resultVal = 0;
        programText = configStr("program");
        warmupText = configStr("warmup_program");
    }

    override void warmup() {
        int prepareIters = warmupIterations();
        foreach (i; 0 .. prepareIters) {
            _run(warmupText);
        }
    }

    override void run(int iterationId) {
        long runResult = _run(programText);
        resultVal += cast(uint)runResult;
    }

    override uint checksum() {
        return resultVal;
    }
}