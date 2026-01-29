package benchmarks

import Benchmark

class BrainfuckRecursion : Benchmark() {
    private lateinit var text: String
    private var resultVal: UInt = 0u
    
    init {
        text = Helper.configS(name(), "program")
    }

    sealed interface Op {
        data class Inc(val value: Int) : Op
        data class Move(val value: Int) : Op
        object Print : Op
        data class Loop(val ops: List<Op>) : Op
    }

    class Tape {
        private val tape = mutableListOf<UByte>(0u)
        private var pos = 0

        fun get(): UByte {
            return tape[pos]
        }

        fun inc(x: Int) {
            tape[pos] = (tape[pos].toInt() + x).toUByte()
        }

        fun move(x: Int) {
            pos += x
            while (pos >= tape.size) {
                tape.add(0u)
            }
        }
    }

    class Program(private val code: String) {
        private val ops: List<Op>
        var result: Long = 0L
        
        init {
            ops = parse(code.iterator())
        }

        fun run() {
            run(ops, Tape())
        }

        private fun run(program: List<Op>, tape: Tape) {
            program.forEach { op ->
                when (op) {
                    is Op.Inc -> tape.inc(op.value)
                    is Op.Move -> tape.move(op.value)
                    is Op.Loop -> {
                        while (tape.get() != 0u.toUByte()) {
                            run(op.ops, tape)
                        }
                    }
                    Op.Print -> {
                        result = (result shl 2) + tape.get().toInt()
                    }
                }
            }
        }

        private fun parse(iterator: CharIterator): List<Op> {
            val res = mutableListOf<Op>()
            
            while (iterator.hasNext()) {
                val c = iterator.nextChar()
                val op = when (c) {
                    '+' -> Op.Inc(1)
                    '-' -> Op.Inc(-1)
                    '>' -> Op.Move(1)
                    '<' -> Op.Move(-1)
                    '.' -> Op.Print
                    '[' -> Op.Loop(parse(iterator))
                    ']' -> break
                    else -> null
                }
                op?.let { res.add(it) }
            }
            
            return res
        }
    }
    
    private fun runProgram(text: String): Long {
        val program = Program(text)
        program.run()
        return program.result
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
    
    override fun name(): String = "BrainfuckRecursion"
}