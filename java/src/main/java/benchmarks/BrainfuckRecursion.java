package benchmarks;

import java.util.*;

public class BrainfuckRecursion extends Benchmark {
    
    // Интерфейс остается - это идиоматично для Java
    interface Op {
        void execute(Tape tape, long[] result);  // long[] для мутабельного результата
    }
    
    // Record classes (Java 14+) - immutable value types
    record Inc(int val) implements Op {
        @Override
        public void execute(Tape tape, long[] result) {
            tape.inc(val);
        }
    }
    
    record Move(int val) implements Op {
        @Override
        public void execute(Tape tape, long[] result) {
            tape.move(val);
        }
    }
    
    record Print() implements Op {
        @Override
        public void execute(Tape tape, long[] result) {
            result[0] = (result[0] << 2) + (tape.get() & 0xFF);
        }
    }
    
    // Loop как обычный класс (может быть record с List<Op>)
    static class Loop implements Op {
        private final Op[] body;  // Массив вместо List для производительности
        
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
    
    // Оптимизированная лента с массивом примитивов
    static class Tape {
        private byte[] tape;
        private int pos;
        
        Tape() {
            this.tape = new byte[1024];  // Начальный размер
            this.pos = 0;
        }
        
        byte get() {
            if (pos < 0 || pos >= tape.length) {
                return 0;
            }
            return tape[pos];
        }
        
        void inc(int x) {
            if (pos >= 0 && pos < tape.length) {
                tape[pos] += x;
            }
        }
        
        void move(int x) {
            pos += x;
            
            // Оптимизированное расширение как во второй версии
            if (pos < 0) {
                // Расширяем в начале
                int needed = -pos;
                byte[] newTape = new byte[tape.length + needed];
                System.arraycopy(tape, 0, newTape, needed, tape.length);
                tape = newTape;
                pos = 0;
            } else if (pos >= tape.length) {
                // Удваиваем размер
                int newSize = Math.max(tape.length * 2, pos + 1);
                byte[] newTape = new byte[newSize];
                System.arraycopy(tape, 0, newTape, 0, tape.length);
                tape = newTape;
            }
        }
    }
    
    static class Program {
        private final Op[] ops;  // Массив вместо List
        private long result;
        
        Program(String code) {
            int[] pos = {0};  // mutable int для рекурсивного парсинга
            List<Op> opsList = new ArrayList<>(code.length() / 2);  // Предварительное выделение
            parse(opsList, code, pos);
            this.ops = opsList.toArray(new Op[0]);
            this.result = 0L;
        }
        
        private void parse(List<Op> ops, String code, int[] pos) {
            while (pos[0] < code.length()) {
                char c = code.charAt(pos[0]++);
                
                switch (c) {
                    case '+': ops.add(new Inc(1)); break;
                    case '-': ops.add(new Inc(-1)); break;
                    case '>': ops.add(new Move(1)); break;
                    case '<': ops.add(new Move(-1)); break;
                    case '.': ops.add(new Print()); break;
                    case '[':
                        List<Op> loopOps = new ArrayList<>();
                        parse(loopOps, code, pos);
                        ops.add(new Loop(loopOps.toArray(new Op[0])));
                        break;
                    case ']': return;
                    default: // игнорируем другие символы
                }
            }
        }
        
        long run() {
            Tape tape = new Tape();
            long[] resultRef = {0L};  // mutable reference для лямбд
            
            for (Op op : ops) {
                op.execute(tape, resultRef);
            }
            
            this.result = resultRef[0];
            return this.result;
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
        program.run();
        return program.run();  // В C++ возвращаем prog.result
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