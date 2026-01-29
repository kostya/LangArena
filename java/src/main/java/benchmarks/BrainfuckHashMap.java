package benchmarks;

import java.util.*;

public class BrainfuckHashMap extends Benchmark {
    
    static class Tape {
        private final List<Integer> tape = new ArrayList<>();
        private int pos = 0;
        
        Tape() {
            tape.add(0);
        }
        
        int get() {
            return tape.get(pos);
        }
        
        void inc() {
            tape.set(pos, tape.get(pos) + 1);
        }
        
        void dec() {
            tape.set(pos, tape.get(pos) - 1);
        }
        
        void advance() {
            pos++;
            if (pos >= tape.size()) {
                tape.add(0);
            }
        }
        
        void devance() {
            if (pos > 0) {
                pos--;
            }
        }
    }
    
    static class Program {
        private final char[] chars;
        private final Map<Integer, Integer> bracketMap = new HashMap<>();
        
        Program(String text) {
            List<Character> charList = new ArrayList<>();
            Deque<Integer> leftStack = new ArrayDeque<>();
            int pc = 0;
            
            for (char c : text.toCharArray()) {
                if ("[]<>+-,.".indexOf(c) != -1) {
                    charList.add(c);
                    if (c == '[') {
                        leftStack.push(pc);
                    } else if (c == ']' && !leftStack.isEmpty()) {
                        int left = leftStack.pop();
                        int right = pc;
                        bracketMap.put(left, right);
                        bracketMap.put(right, left);
                    }
                    pc++;
                }
            }
            
            chars = new char[charList.size()];
            for (int i = 0; i < charList.size(); i++) {
                chars[i] = charList.get(i);
            }
        }
        
        long run() {
            long result = 0L;
            Tape tape = new Tape();
            int pc = 0;
            
            while (pc < chars.length) {
                switch (chars[pc]) {
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
                    case '[':
                        if (tape.get() == 0) {
                            pc = bracketMap.get(pc);
                        }
                        break;
                    case ']':
                        if (tape.get() != 0) {
                            pc = bracketMap.get(pc);
                        }
                        break;
                    case '.':
                        int value = tape.get() & 0xFF;
                        result = (result << 2) + value;
                        break;
                    }
                pc++;
            }
            
            return result;
        }
    }
    
    private String text;
    private long resultVal;
    private String warmupProgram;
    
    public BrainfuckHashMap() {
        text = Helper.configS(name(), "program");
        warmupProgram = Helper.configS(name(), "warmup_program");
        resultVal = 0L;
    }
    
    @Override
    public String name() {
        return "BrainfuckHashMap";
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