package benchmarks

import scala.collection.mutable
import scala.collection.mutable.ArrayBuffer

class BrainfuckArray extends Benchmark:
  private val programText: String = Helper.configS(name(), "program")
  private val warmupText: String = Helper.configS(name(), "warmup_program")
  private var resultVal: Long = 0L

  override def name(): String = "BrainfuckArray"

  private def runProgram(programText: String): Long =
    BrainfuckArray.Program(programText).run()

  override def warmup(): Unit =
    val prepareIters = warmupIterations()
    for i <- 0L until prepareIters do
      runProgram(warmupText)

  override def run(iterationId: Int): Unit =
    resultVal += runProgram(programText)

  override def checksum(): Long = resultVal

object BrainfuckArray:
  class Tape:
    private var tape: Array[Byte] = new Array[Byte](30000)
    private var pos: Int = 0

    def get(): Byte = tape(pos)

    def inc(): Unit = tape(pos) = (tape(pos) + 1).toByte

    def dec(): Unit = tape(pos) = (tape(pos) - 1).toByte

    def advance(): Unit =
      pos += 1
      if pos >= tape.length then
        val newTape = new Array[Byte](tape.length * 2)
        Array.copy(tape, 0, newTape, 0, tape.length)
        tape = newTape

    def devance(): Unit =
      if pos > 0 then pos -= 1

  class Program(text: String):
    private val commands: Array[Byte] =
      text.toCharArray
        .filter(c => "[]<>+-,.".indexOf(c) != -1)
        .map(_.toByte)
        .toArray

    private val jumps: Array[Int] =
      val arr = new Array[Int](commands.length)
      val stack = mutable.ArrayDeque.empty[Int]

      for i <- commands.indices do
        commands(i).toChar match
          case '[' => stack.prepend(i)
          case ']' if stack.nonEmpty =>
            val start = stack.removeHead()
            arr(start) = i
            arr(i) = start
          case _ =>
      arr

    def run(): Long =
      var result: Long = 0L
      val tape = Tape()
      var pc = 0

      while pc < commands.length do
        commands(pc).toChar match
          case '+' => tape.inc()
          case '-' => tape.dec()
          case '>' => tape.advance()
          case '<' => tape.devance()
          case '[' =>
            if tape.get() == 0 then pc = jumps(pc)
          case ']' =>
            if tape.get() != 0 then pc = jumps(pc)
          case '.' =>
            result = (result << 2) + (tape.get() & 0xFF)
          case _ =>
        pc += 1
      result