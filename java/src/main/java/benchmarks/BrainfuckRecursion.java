package benchmarks;

import java.util.*;

public class BrainfuckRecursion extends Benchmark {

    interface Op {}

    static class Inc implements Op {}
    static class Dec implements Op {}
    static class Next implements Op {}
    static class Prev implements Op {}
    static class Print implements Op {}
    static class Loop implements Op {
        Op[] body;
        Loop(Op[] body) {
            this.body = body;
        }
    }

    static class Tape {
        private byte[] tape = new byte[30000];
        private int pos = 0;

        byte get() {
            return tape[pos];
        }
        void inc() {
            tape[pos]++;
        }
        void dec() {
            tape[pos]--;
        }

        void next() {
            pos++;
            if (pos >= tape.length) {
                byte[] newTape = new byte[tape.length + 1];
                System.arraycopy(tape, 0, newTape, 0, tape.length);
                tape = newTape;
            }
        }

        void prev() {
            if (pos > 0) pos--;
        }
    }

    static class Program {
        private final Op[] ops;
        private long result = 0;

        Program(String code) {
            int[] pos = {0};
            List<Op> opsList = parse(code, pos);
            this.ops = opsList.toArray(new Op[0]);
        }

        private List<Op> parse(String code, int[] pos) {
            List<Op> list = new ArrayList<>();

            while (pos[0] < code.length()) {
                char c = code.charAt(pos[0]++);
                switch (c) {
                case '+':
                    list.add(new Inc());
                    break;
                case '-':
                    list.add(new Dec());
                    break;
                case '>':
                    list.add(new Next());
                    break;
                case '<':
                    list.add(new Prev());
                    break;
                case '.':
                    list.add(new Print());
                    break;
                case '[':
                    List<Op> loopList = parse(code, pos);
                    list.add(new Loop(loopList.toArray(new Op[0])));
                    break;
                case ']':
                    return list;
                }
            }
            return list;
        }

        long run() {
            Tape tape = new Tape();
            result = 0;
            execute(ops, tape);
            return result;
        }

        private void execute(Op[] program, Tape tape) {
            for (Op op : program) {
                if (op instanceof Inc) {
                    tape.inc();
                } else if (op instanceof Dec) {
                    tape.dec();
                } else if (op instanceof Next) {
                    tape.next();
                } else if (op instanceof Prev) {
                    tape.prev();
                } else if (op instanceof Print) {
                    result = (result << 2) + (tape.get() & 0xFF);
                } else if (op instanceof Loop) {
                    Loop loop = (Loop) op;
                    while (tape.get() != 0) {
                        execute(loop.body, tape);
                    }
                }
            }
        }
    }

    private String text;
    private long resultVal;
    private String warmupProgram;

    public BrainfuckRecursion() {
        text = Helper.configS(name(), "program");
        warmupProgram = Helper.configS(name(), "warmup_program");
        resultVal = 0L;
    }

    @Override
    public String name() {
        return "BrainfuckRecursion";
    }

    private long runProgram(String programText) {
        return new Program(programText).run();
    }

    @Override
    public void warmup() {
        long prepareIters = warmupIterations();
        for (long i = 0; i < prepareIters; i++) {
            runProgram(warmupProgram);
        }
    }

    @Override
    public void run(int iterationId) {
        resultVal += runProgram(text);
    }

    @Override
    public long checksum() {
        return resultVal;
    }
}