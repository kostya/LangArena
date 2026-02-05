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

        fun get(): Byte {
            return tape[pos]
        }

        fun inc() {
            tape[pos] = (tape[pos] + 1).toByte() 
        }

        fun dec() {
            tape[pos] = (tape[pos] - 1).toByte() 
        }

        fun advance() {
            pos += 1
            if (pos >= tape.size) {

                val newTape = ByteArray(tape.size * 2)
                tape.copyInto(newTape)
                tape = newTape
            }
        }

        fun devance() {
            if (pos > 0) {
                pos -= 1
            }
        }
    }

    class Program(private val text: String) {
        private val commands: ByteArray
        private val jumps: IntArray 

        init {

            val commandList = mutableListOf<Byte>()
            text.forEach { char ->
                if ("[]<>+-,.".contains(char)) {
                    commandList.add(char.code.toByte())
                }
            }

            commands = commandList.toByteArray()

            jumps = IntArray(commands.size)
            val stack = mutableListOf<Int>()

            commands.forEachIndexed { i, cmdByte ->
                val cmd = cmdByte.toInt().toChar() 
                when (cmd) {
                    '[' -> stack.add(i)
                    ']' -> {
                        if (stack.isNotEmpty()) {
                            val start = stack.removeAt(stack.size - 1)
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

            while (pc < commands.size) {
                val cmd = commands[pc].toInt().toChar() 
                when (cmd) {
                    '+' -> tape.inc()
                    '-' -> tape.dec()
                    '>' -> tape.advance()
                    '<' -> tape.devance()
                    '[' -> {
                        if (tape.get().toInt() == 0) {
                            pc = jumps[pc]
                            continue 
                        }
                    }
                    ']' -> {
                        if (tape.get().toInt() != 0) {
                            pc = jumps[pc]
                            continue 
                        }
                    }
                    '.' -> {

                        result = (result shl 2) + tape.get().toUByte().toLong()
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
        for (i in 0 until prepareIters) {
            runProgram(warmupText)
        }
    }

    override fun run(iterationId: Int) {
        resultVal = resultVal.plus(runProgram(programText).toUInt())
    }

    override fun checksum(): UInt = resultVal

    override fun name(): String = "BrainfuckArray"
}