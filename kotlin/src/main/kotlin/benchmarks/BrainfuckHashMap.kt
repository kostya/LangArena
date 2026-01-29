package benchmarks

import Benchmark

class BrainfuckHashMap : Benchmark() {
    private lateinit var text: String
    private var resultVal: UInt = 0u
    
    init {
        text = Helper.configS(name(), "program")
    }
    
    class Tape {
        private val tape = mutableListOf(0)
        private var pos = 0
        
        fun get(): Int {
            return tape[pos]
        }
        
        fun inc() {
            tape[pos] = tape[pos] + 1
        }
        
        fun dec() {
            tape[pos] = tape[pos] - 1
        }
        
        fun advance() {
            pos += 1
            if (pos >= tape.size) {
                tape.add(0)
            }
        }
        
        fun devance() {
            if (pos > 0) {
                pos -= 1
            }
        }
    }
    
    class Program(private val text: String) {
        private val chars = mutableListOf<Char>()
        private val bracketMap = mutableMapOf<Int, Int>()
        
        init {
            val leftStack = mutableListOf<Int>()
            var pc = 0
            
            text.forEach { char ->
                if ("[]<>+-,.".contains(char)) {
                    chars.add(char)
                    
                    when (char) {
                        '[' -> leftStack.add(pc)
                        ']' -> {
                            if (leftStack.isNotEmpty()) {
                                val left = leftStack.removeAt(leftStack.size - 1)
                                val right = pc
                                bracketMap[left] = right
                                bracketMap[right] = left
                            }
                        }
                    }
                    
                    pc += 1
                }
            }
        }
        
        fun run(): Long {
            var result = 0L
            val tape = Tape()
            var pc = 0
            
            while (pc < chars.size) {
                when (chars[pc]) {
                    '+' -> tape.inc()
                    '-' -> tape.dec()
                    '>' -> tape.advance()
                    '<' -> tape.devance()
                    '[' -> {
                        if (tape.get() == 0) {
                            pc = bracketMap[pc] ?: pc
                        }
                    }
                    ']' -> {
                        if (tape.get() != 0) {
                            pc = bracketMap[pc] ?: pc
                        }
                    }
                    '.' -> {
                        result = (result shl 2) + tape.get().toChar().code
                    }
                }
                pc += 1
            }
            
            return result
        }
    }
    
    private fun runProgram(text: String): Long {
        return Program(text).run()
    }
    
    override fun warmup() {
        val prepareIters = warmupIterations()
        val warmupProgram = Helper.configS(name(), "warmup_program")
        for (i in 0 until prepareIters) {
            runProgram(warmupProgram)
        }
    }
    
    override fun run(iterationId: Int) {
        resultVal += runProgram(text).toUInt()  // &+= эквивалент
    }
    
    override fun checksum(): UInt = resultVal
    
    override fun name(): String = "BrainfuckHashMap"
}