import std/[math, strutils, deques, algorithm]
import ../benchmark
import ../helper

type
  Node = ref object
    children: array[10, Node]
    isTerminal: bool

  Primes* = ref object of Benchmark
    n: int64
    prefix: int64
    resultVal: uint32

proc newPrimes(): Benchmark =
  Primes()

method name(self: Primes): string = "Etc::Primes"

method prepare(self: Primes) =
  self.n = self.config_val("limit")
  self.prefix = self.config_val("prefix")
  self.resultVal = 5432'u32

proc generatePrimes(limit: int): seq[int] =
  if limit < 2:
    return @[]

  var isPrime = newSeq[bool](limit + 1)
  for i in 2..limit:
    isPrime[i] = true

  let sqrtLimit = int(sqrt(float(limit)))

  for p in 2..sqrtLimit:
    if isPrime[p]:
      var multiple = p * p
      while multiple <= limit:
        isPrime[multiple] = false
        multiple += p

  result = newSeqOfCap[int](limit div max(1, int(ln(float(limit)) - 1.1)))

  for i in 2..limit:
    if isPrime[i]:
      result.add(i)

proc buildTrie(primes: seq[int]): Node =
  result = Node()

  for prime in primes:
    var current = result
    let digits = $prime

    for digitChar in digits:
      let digit = int(digitChar) - int('0')

      if current.children[digit] == nil:
        current.children[digit] = Node()

      current = current.children[digit]

    current.isTerminal = true

proc findPrimesWithPrefix(trieRoot: Node, prefix: int): seq[int] =
  let prefixStr = $prefix
  var current = trieRoot

  for digitChar in prefixStr:
    let digit = int(digitChar) - int('0')

    if current.children[digit] == nil:
      return @[]

    current = current.children[digit]

  type QueueItem = tuple[node: Node, number: int]
  var queue = initDeque[QueueItem]()
  queue.addLast((current, prefix))

  while queue.len > 0:
    let (node, number) = queue.popFirst()

    if node.isTerminal:
      result.add(number)

    for digit in 0..9:
      if node.children[digit] != nil:
        queue.addLast((node.children[digit], number * 10 + digit))

  result.sort()

method run(self: Primes, iteration_id: int) =
  let primes = generatePrimes(self.n.int)
  let trie = buildTrie(primes)
  let results = findPrimesWithPrefix(trie, self.prefix.int)

  self.resultVal += uint32(results.len)
  for prime in results:
    self.resultVal += uint32(prime)

method checksum(self: Primes): uint32 =
  self.resultVal

registerBenchmark("Etc::Primes", newPrimes)
