package benchmarks

import Benchmark

class BrainfuckArray : Benchmark() {
    private val programText = configStr("program")
    private val warmupText = configStr("warmup_program")
    private var resultVal: UInt = 0u

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

    class Program(
        text: String,
    ) {
        private val commands = text.filter { it in "[]<>+-,." }.toCharArray()
        private val jumps = IntArray(commands.size)

        init {
            val stack = IntArray(commands.size)
            var sp = 0

            for (i in commands.indices) {
                when (commands[i]) {
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
            val cmds = commands
            val jmps = jumps
            var pc = 0

            while (pc < cmds.size) {
                when (cmds[pc]) {
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

    override fun name(): String = "Brainfuck::Array"
}
