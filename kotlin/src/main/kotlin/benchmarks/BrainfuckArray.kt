package benchmarks

import Benchmark

class BrainfuckArray : Benchmark() {
    private lateinit var programText: String
    private lateinit var warmupText: String
    private var resultVal: UInt = 0u

    init {
        programText = Helper.configS(name(), "program")
        warmupText = Helper.configS(name(), "warmup_program")
    }

    class Tape {
        private var tape = ByteArray(30000)
        private var pos = 0

        private fun ensureCapacity() {
            if (pos >= tape.size) {
                tape = tape.copyOf(tape.size + 1)  
            }
        }

        fun get(): Byte = tape[pos]

        fun inc() {
            tape[pos] = (tape[pos] + 1).toByte()
        }

        fun dec() {
            tape[pos] = (tape[pos] - 1).toByte()
        }

        fun advance() {
            pos++
            ensureCapacity()
        }

        fun devance() {
            if (pos > 0) pos--
        }
    }

    class Program(private val text: String) {
        private val commands: ByteArray
        private val jumps: IntArray

        init {

            val cmdList = mutableListOf<Byte>()
            for (c in text) {
                if (c in "[]<>+-,.") {
                    cmdList.add(c.code.toByte())
                }
            }
            commands = cmdList.toByteArray()

            jumps = IntArray(commands.size)
            val stack = IntArray(commands.size)  
            var sp = 0  

            for (i in commands.indices) {
                when (commands[i].toInt().toChar()) {
                    '[' -> {
                        stack[sp++] = i  
                    }
                    ']' -> {
                        if (sp > 0) {
                            val start = stack[--sp]  
                            jumps[start] = i
                            jumps[i] = start
                        }
                    }
                }
            }
        }

        fun run(): Long {
            var result = 0L
            val tape = Tape()
            var pc = 0
            val cmds = commands  
            val jmps = jumps

            while (pc < cmds.size) {
                when (val cmd = cmds[pc].toInt().toChar()) {
                    '+' -> tape.inc()
                    '-' -> tape.dec()
                    '>' -> tape.advance()
                    '<' -> tape.devance()
                    '[' -> if (tape.get() == 0.toByte()) pc = jmps[pc]
                    ']' -> if (tape.get() != 0.toByte()) pc = jmps[pc]
                    '.' -> result = (result shl 2) + (tape.get().toUByte().toLong())
                }
                pc++
            }
            return result
        }
    }

    private fun runProgram(text: String): Long = Program(text).run()

    override fun warmup() {
        repeat(warmupIterations().toInt()) {
            runProgram(warmupText)
        }
    }

    override fun run(iterationId: Int) {
        resultVal += runProgram(programText).toUInt()
    }

    override fun checksum(): UInt = resultVal
    override fun name(): String = "BrainfuckArray"
}