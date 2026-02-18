package benchmarks

import Benchmark

class BrainfuckRecursion : Benchmark() {
    private lateinit var programText: String
    private lateinit var warmupText: String
    private var resultVal: UInt = 0u

    init {
        programText = Helper.configS(name(), "program")
        warmupText = Helper.configS(name(), "warmup_program")
    }

    sealed class Op {
        object Inc : Op()      
        object Dec : Op()      
        object Next : Op()     
        object Prev : Op()     
        object Print : Op()    
        data class Loop(val ops: Array<Op>) : Op()  
    }

    class Tape {
        private var pos = 0
        private var tape = ByteArray(30000)

        fun currentCell(): Byte = tape[pos]

        fun inc() {  
            tape[pos] = (tape[pos] + 1).toByte()
        }

        fun dec() {  
            tape[pos] = (tape[pos] - 1).toByte()
        }

        fun next() {  
            pos++
            if (pos >= tape.size) {
                tape = tape.copyOf(tape.size + 1)  
            }
        }

        fun prev() {  
            if (pos > 0) pos--
        }
    }

    class Program(private val code: String) {
        private val ops: Array<Op>
        var result: Long = 0L

        init {
            ops = parse(code.iterator())
        }

        private fun parse(iter: CharIterator): Array<Op> {
            val buf = mutableListOf<Op>()
            while (iter.hasNext()) {
                val c = iter.nextChar()
                val op = when (c) {
                    '+' -> Op.Inc
                    '-' -> Op.Dec
                    '>' -> Op.Next
                    '<' -> Op.Prev
                    '.' -> Op.Print
                    '[' -> Op.Loop(parse(iter))
                    ']' -> break
                    else -> continue
                }
                buf.add(op)
            }
            return buf.toTypedArray()
        }

        fun run(): Long {
            val tape = Tape()
            result = 0
            execute(ops, tape)
            return result
        }

        private fun execute(program: Array<Op>, tape: Tape) {
            for (op in program) {
                when (op) {
                    is Op.Inc -> tape.inc()
                    is Op.Dec -> tape.dec()
                    is Op.Next -> tape.next()
                    is Op.Prev -> tape.prev()
                    is Op.Print -> {
                        val cell = tape.currentCell().toInt() and 0xFF
                        result = (result shl 2) + cell
                    }
                    is Op.Loop -> {
                        while (tape.currentCell() != 0.toByte()) {
                            execute(op.ops, tape)
                        }
                    }
                }
            }
        }
    }

    private fun runProgram(text: String): Long {
        val program = Program(text)
        return program.run()
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

    override fun name(): String = "BrainfuckRecursion"
}