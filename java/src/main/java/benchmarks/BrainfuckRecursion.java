package benchmarks;

import java.util.*;

public class BrainfuckRecursion extends Benchmark {

    interface Op {
        void execute(Tape tape, long[] result);
    }

    record Dec() implements Op {
        @Override
        public void execute(Tape tape, long[] result) {
            tape.inc(-1);
        }
    }

    record Inc() implements Op {
        @Override
        public void execute(Tape tape, long[] result) {
            tape.inc(1);
        }
    }

    record Prev() implements Op {
        @Override
        public void execute(Tape tape, long[] result) {
            tape.prev();
        }
    }

    record Next() implements Op {
        @Override
        public void execute(Tape tape, long[] result) {
            tape.next();
        }
    }

    record Print() implements Op {
        @Override
        public void execute(Tape tape, long[] result) {
            result[0] = (result[0] << 2) + (tape.get() & 0xFF);
        }
    }

    static class Loop implements Op {
        private final Op[] body;

        Loop(Op[] body) {
            this.body = body;
        }

        @Override
        public void execute(Tape tape, long[] result) {
            while (tape.get() != 0) {
                for (Op op : body) {
                    op.execute(tape, result);
                }
            }
        }
    }

    static class Tape {
        private byte[] tape;
        private int pos;

        Tape() {
            this.tape = new byte[1];  
            this.pos = 0;
        }

        byte get() {
            return tape[pos];
        }

        void inc(int x) {
            tape[pos] += x;  
        }

        void prev() {
            pos--;
        }

        void next() {
            pos++;
            if (pos >= tape.length) {

                int newSize = pos * 2;
                byte[] newTape = new byte[newSize];
                System.arraycopy(tape, 0, newTape, 0, tape.length);
                tape = newTape;
            }
        }
    }

    static class Program {
        private final Op[] ops;

        Program(String code) {
            int[] pos = {0};  
            List<Op> opsList = new ArrayList<>(code.length() / 2);
            this.ops = parse(opsList, code, pos).toArray(new Op[0]);
        }

        private List<Op> parse(List<Op> ops, String code, int[] pos) {
            while (pos[0] < code.length()) {
                char c = code.charAt(pos[0]++);

                switch (c) {
                    case '-': ops.add(new Dec()); break;
                    case '+': ops.add(new Inc()); break;
                    case '<': ops.add(new Prev()); break;
                    case '>': ops.add(new Next()); break;
                    case '.': ops.add(new Print()); break;
                    case '[':
                        List<Op> loopOps = new ArrayList<>();
                        parse(loopOps, code, pos);
                        ops.add(new Loop(loopOps.toArray(new Op[0])));
                        break;
                    case ']': return ops;
                    default: 
                }
            }
            return ops;
        }

        long run() {
            Tape tape = new Tape();
            long[] result = {0L};

            for (Op op : ops) {
                op.execute(tape, result);
            }

            return result[0];
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
        Program program = new Program(programText);
        return program.run();
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