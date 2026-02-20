package benchmarks;

import java.util.*;

public class BrainfuckArray extends Benchmark {

    static class Tape {
        private byte[] tape;
        private int pos = 0;

        Tape() {
            tape = new byte[30000];
        }

        byte get() {
            return tape[pos];
        }

        void inc() {
            tape[pos] = (byte)(tape[pos] + 1);
        }

        void dec() {
            tape[pos] = (byte)(tape[pos] - 1);
        }

        void advance() {
            pos++;
            if (pos >= tape.length) {

                byte[] newTape = new byte[tape.length + 1];
                System.arraycopy(tape, 0, newTape, 0, tape.length);
                tape = newTape;
            }
        }

        void devance() {
            if (pos > 0) {
                pos--;
            }
        }
    }

    static class Program {
        private final byte[] commands;
        private final int[] jumps;

        Program(String text) {

            int cmdCount = 0;
            for (int i = 0; i < text.length(); i++) {
                char c = text.charAt(i);
                if ("[]<>+-,.".indexOf(c) != -1) {
                    cmdCount++;
                }
            }

            commands = new byte[cmdCount];
            int idx = 0;
            for (int i = 0; i < text.length(); i++) {
                char c = text.charAt(i);
                if ("[]<>+-,.".indexOf(c) != -1) {
                    commands[idx++] = (byte)c;
                }
            }

            jumps = new int[commands.length];
            int[] stack = new int[commands.length];
            int sp = 0;

            for (int i = 0; i < commands.length; i++) {
                byte cmd = commands[i];
                if (cmd == '[') {
                    stack[sp++] = i;
                } else if (cmd == ']') {
                    if (sp > 0) {
                        int start = stack[--sp];
                        jumps[start] = i;
                        jumps[i] = start;
                    }
                }
            }
        }

        long run() {
            long result = 0L;
            Tape tape = new Tape();
            byte[] cmds = commands;
            int[] jmps = jumps;
            int pc = 0;

            while (pc < cmds.length) {
                byte cmd = cmds[pc];

                if (cmd == '[') {
                    if (tape.get() == 0) {
                        pc = jmps[pc];
                        continue;
                    }
                } else if (cmd == ']') {
                    if (tape.get() != 0) {
                        pc = jmps[pc];
                        continue;
                    }
                } else {
                    switch (cmd) {
                    case '+':
                        tape.inc();
                        break;
                    case '-':
                        tape.dec();
                        break;
                    case '>':
                        tape.advance();
                        break;
                    case '<':
                        tape.devance();
                        break;
                    case '.':
                        result = (result << 2) + (tape.get() & 0xFF);
                        break;
                    }
                }
                pc++;
            }

            return result;
        }
    }

    private String programText;
    private String warmupText;
    private long resultVal;

    public BrainfuckArray() {
        programText = Helper.configS(name(), "program");
        warmupText = Helper.configS(name(), "warmup_program");
        resultVal = 0L;
    }

    @Override
    public String name() {
        return "BrainfuckArray";
    }

    private long runProgram(String programText) {
        return new Program(programText).run();
    }

    @Override
    public void warmup() {
        long prepareIters = warmupIterations();
        for (long i = 0; i < prepareIters; i++) {
            runProgram(warmupText);
        }
    }

    @Override
    public void run(int iterationId) {
        resultVal += runProgram(programText);
    }

    @Override
    public long checksum() {
        return resultVal;
    }
}