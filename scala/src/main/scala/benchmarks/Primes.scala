package benchmarks

import scala.collection.mutable
import java.{util => ju}

class Primes extends Benchmark:
  private var resultVal: Long = 5432L
  private var n: Long = 0L
  private var prefix: Long = 0L

  override def name(): String = "Etc::Primes"

  override def prepare(): Unit =
    n = configVal("limit")
    prefix = configVal("prefix")

  private class Node:
    val children = new Array[Node](10)
    var terminal = false

  private def generatePrimes(limit: Int): mutable.Buffer[Int] =
    if limit < 2 then return mutable.Buffer.empty

    val isPrime = new Array[Boolean](limit + 1)
    ju.Arrays.fill(isPrime, true)
    isPrime(0) = false
    isPrime(1) = false

    val sqrtLimit = math.sqrt(limit).toInt

    var p = 2
    while p <= sqrtLimit do
      if isPrime(p) then
        var multiple = p * p
        while multiple <= limit do
          isPrime(multiple) = false
          multiple += p
      p += 1

    val primes = mutable.ArrayBuffer.empty[Int]
    var i = 2
    while i <= limit do
      if isPrime(i) then primes += i
      i += 1

    primes

  private def buildTrie(primes: mutable.Buffer[Int]): Node =
    val root = Node()

    primes.foreach { prime =>
      var current = root
      val digits = prime.toString

      var j = 0
      while j < digits.length do
        val digit = digits.charAt(j) - '0'
        if current.children(digit) == null then current.children(digit) = Node()
        current = current.children(digit)
        j += 1
      current.terminal = true
    }

    root

  private def findPrimesWithPrefix(root: Node, prefix: Int): List[Int] =
    val prefixStr = prefix.toString
    var current = root

    var i = 0
    while i < prefixStr.length do
      val digit = prefixStr.charAt(i) - '0'
      if current.children(digit) == null then return List.empty
      current = current.children(digit)
      i += 1

    val queue = mutable.Queue.empty[(Node, Int)]
    queue.enqueue((current, prefix))
    val results = mutable.ArrayBuffer.empty[Int]

    while queue.nonEmpty do
      val (node, number) = queue.dequeue()
      if node.terminal then results += number

      var digit = 0
      while digit < 10 do
        if node.children(digit) != null then queue.enqueue((node.children(digit), number * 10 + digit))
        digit += 1

    results.sortInPlace().toList

  override def run(iterationId: Int): Unit =
    val primes = generatePrimes(n.toInt)
    val trie = buildTrie(primes)
    val results = findPrimesWithPrefix(trie, prefix.toInt)

    resultVal += results.size
    results.foreach(resultVal += _)

  override def checksum(): Long = resultVal
