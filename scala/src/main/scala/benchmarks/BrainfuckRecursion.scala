package benchmarks

class BrainfuckRecursion extends Benchmark:
  private val text: String = Helper.configS(name(), "program")
  private val warmupProgram: String = Helper.configS(name(), "warmup_program")
  private var resultVal: Long = 0L

  override def name(): String = "Brainfuck::Recursion"

  sealed trait Op
  case object Inc extends Op
  case object Dec extends Op
  case object Next extends Op
  case object Prev extends Op
  case object Print extends Op
  case class Loop(body: Array[Op]) extends Op

  class Tape:
    private var tape: Array[Byte] = new Array[Byte](30000)
    private var pos: Int = 0

    def get(): Byte = tape(pos)
    def inc(): Unit = tape(pos) = (tape(pos) + 1).toByte
    def dec(): Unit = tape(pos) = (tape(pos) - 1).toByte
    def prev(): Unit = if pos > 0 then pos -= 1
    def next(): Unit =
      pos += 1
      if pos >= tape.length then
        val newTape = new Array[Byte](tape.length + 1)
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
          case '-' => ops.add(Dec)
          case '+' => ops.add(Inc)
          case '<' => ops.add(Prev)
          case '>' => ops.add(Next)
          case '.' => ops.add(Print)
          case '[' =>
            val loopOps = new java.util.ArrayList[Op]()
            parse(loopOps, code, pos)
            ops.add(Loop(loopOps.toArray(Array.empty[Op])))
          case ']' => return ops
          case _   =>
      ops

    def run(): Long =
      val tape = Tape()
      var result = 0L

      def exec(op: Op): Unit = op match
        case Inc        => tape.inc()
        case Dec        => tape.dec()
        case Next       => tape.next()
        case Prev       => tape.prev()
        case Print      => result = (result << 2) + (tape.get() & 0xff)
        case Loop(body) =>
          while tape.get() != 0 do
            var i = 0
            while i < body.length do
              exec(body(i))
              i += 1

      var i = 0
      while i < ops.length do
        exec(ops(i))
        i += 1

      result & 0xffffffffL

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

  override def checksum(): Long = resultVal & 0xffffffffL
