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
        private size_t pos = 0;

        this(size_t size) {
            tape = new ubyte[size];
            tape[] = 0;
        }

        ubyte get() const { return tape[pos]; }
        void inc() { tape[pos]++; }
        void dec() { tape[pos]--; }

        void advance() {
            pos++;
            if (pos >= tape.length) {
                tape ~= 0;
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

        long run() {
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
                        result = (result << 2) + cast(long)tape.get;
                        break;
                    default: break;
                }
                pc++;
            }
            return result;
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