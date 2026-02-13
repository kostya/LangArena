package benchmarks

class BrainfuckRecursion extends Benchmark:
  private val text: String = Helper.configS(name(), "program")
  private val warmupProgram: String = Helper.configS(name(), "warmup_program")
  private var resultVal: Long = 0L

  override def name(): String = "BrainfuckRecursion"

  trait Op:
    def execute(tape: Tape, result: Array[Long]): Unit

  class Dec extends Op:
    override def execute(tape: Tape, result: Array[Long]): Unit = tape.inc(-1)

  class Inc extends Op:
    override def execute(tape: Tape, result: Array[Long]): Unit = tape.inc(1)

  class Prev extends Op:
    override def execute(tape: Tape, result: Array[Long]): Unit = tape.prev()

  class Next extends Op:
    override def execute(tape: Tape, result: Array[Long]): Unit = tape.next()

  class Print extends Op:
    override def execute(tape: Tape, result: Array[Long]): Unit =
      result(0) = (result(0) << 2) + (tape.get() & 0xFF)

  class Loop(val body: Array[Op]) extends Op:
    override def execute(tape: Tape, result: Array[Long]): Unit =
      while tape.get() != 0 do
        var i = 0
        while i < body.length do
          body(i).execute(tape, result)
          i += 1

  class Tape:
    private var tape: Array[Byte] = new Array[Byte](1)
    private var pos: Int = 0

    def get(): Byte = tape(pos)

    def inc(x: Int): Unit = tape(pos) = (tape(pos) + x).toByte

    def prev(): Unit = pos -= 1

    def next(): Unit =
      pos += 1
      if pos >= tape.length then
        val newSize = pos * 2
        val newTape = new Array[Byte](newSize)
        System.arraycopy(tape, 0, newTape, 0, tape.length)
        tape = newTape

  class Program(code: String):
    private val ops: Array[Op] =
      val pos = Array(0)
      val opsList = new java.util.ArrayList[Op]()
      parse(opsList, code, pos).toArray(Array.empty[Op])

    private def parse(ops: java.util.List[Op], code: String, pos: Array[Int]): java.util.List[Op] =
      while pos(0) < code.length do
        val c = code.charAt(pos(0))
        pos(0) += 1

        c match
          case '-' => ops.add(new Dec())
          case '+' => ops.add(new Inc())
          case '<' => ops.add(new Prev())
          case '>' => ops.add(new Next())
          case '.' => ops.add(new Print())
          case '[' =>
            val loopOps = new java.util.ArrayList[Op]()
            parse(loopOps, code, pos)
            ops.add(new Loop(loopOps.toArray(Array.empty[Op])))
          case ']' => return ops
          case _ =>
      ops

    def run(): Long =
      val tape = Tape()
      val result = Array(0L)

      var i = 0
      while i < ops.length do
        ops(i).execute(tape, result)
        i += 1

      result(0)

  private def runProgram(programText: String): Long =
    Program(programText).run()

  override def warmup(): Unit =
    val prepareIters = warmupIterations()
    var i = 0L
    while i < prepareIters do
      runProgram(warmupProgram)
      i += 1

  override def run(iterationId: Int): Unit =
    resultVal += runProgram(text)

  override def checksum(): Long = resultVal & 0xFFFFFFFFL