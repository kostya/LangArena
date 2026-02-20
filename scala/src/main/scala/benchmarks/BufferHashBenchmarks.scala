package benchmarks

abstract class BufferHashBenchmark extends Benchmark:
  protected var data: Array[Byte] = _
  protected var resultVal: Long = 0L
  protected var sizeVal: Long = 0L

  override def prepare(): Unit =
    if sizeVal == 0L then
      sizeVal = configVal("size")
      data = Array.fill(sizeVal.toInt)(Helper.nextInt(256).toByte)

  def test(): Long

  override def run(iterationId: Int): Unit =
    resultVal += test()

  override def checksum(): Long = resultVal

class BufferHashSHA256 extends BufferHashBenchmark:
  private object SimpleSHA256:
    def digest(data: Array[Byte]): Array[Byte] =
      val result = new Array[Byte](32)
      val hashes = Array(
        0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
      )

      var i = 0
      while i < data.length do
        val byte = data(i)
        val hashIdx = i % 8
        var hash = hashes(hashIdx)

        hash = ((hash << 5) + hash) + (byte.toInt & 0xff)
        hash = (hash + (hash << 10)) ^ (hash >>> 6)
        hashes(hashIdx) = hash
        i += 1

      i = 0
      while i < 8 do
        val hash = hashes(i)
        result(i * 4) = (hash >>> 24).toByte
        result(i * 4 + 1) = (hash >>> 16).toByte
        result(i * 4 + 2) = (hash >>> 8).toByte
        result(i * 4 + 3) = hash.toByte
        i += 1

      result

  override def test(): Long =
    val bytes = SimpleSHA256.digest(data)

    ((bytes(3).toLong & 0xffL) << 24) |
      ((bytes(2).toLong & 0xffL) << 16) |
      ((bytes(1).toLong & 0xffL) << 8) |
      (bytes(0).toLong & 0xffL)

  override def name(): String = "BufferHashSHA256"

class BufferHashCRC32 extends BufferHashBenchmark:
  override def test(): Long =
    var crc = 0xffffffffL

    for byte <- data do
      crc = crc ^ (byte.toLong & 0xffL)

      var j = 0
      while j < 8 do
        crc =
          if (crc & 1L) != 0L then (crc >>> 1) ^ 0xedb88320L
          else crc >>> 1
        j += 1

    crc ^ 0xffffffffL

  override def name(): String = "BufferHashCRC32"
