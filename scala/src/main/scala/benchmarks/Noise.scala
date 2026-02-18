package benchmarks

class Noise extends Benchmark:
  private var sizeVal: Long = 0L
  private var resultVal: Long = 0L
  private var n2d: Noise2DContext = _

  override def name(): String = "Noise"

  override def prepare(): Unit =
    sizeVal = configVal("size")
    n2d = Noise2DContext(sizeVal.toInt)

  private class Vec2(val x: Double, val y: Double)

  private class Noise2DContext(size: Int):
    private val rgradients = new Array[Vec2](size)
    private val permutations = new Array[Int](size)
    private val sizeVal = size

    var i = 0
    while i < size do
      rgradients(i) = randomGradient()
      permutations(i) = i
      i += 1

    i = 0
    while i < size do
      val a = Helper.nextInt(size)
      val b = Helper.nextInt(size)
      val temp = permutations(a)
      permutations(a) = permutations(b)
      permutations(b) = temp
      i += 1

    private def randomGradient(): Vec2 =
      val v = Helper.nextFloat() * math.Pi * 2.0
      Vec2(math.cos(v), math.sin(v))

    private def getGradient(x: Int, y: Int): Vec2 =
      val idx = permutations(x & (sizeVal - 1)) + permutations(y & (sizeVal - 1))
      rgradients(idx & (sizeVal - 1))

    private def getGradients(x: Double, y: Double): (Array[Vec2], Array[Vec2]) =
      val x0f = math.floor(x)
      val y0f = math.floor(y)
      val x0 = x0f.toInt
      val y0 = y0f.toInt

      val gradients = Array(
        getGradient(x0, y0),
        getGradient(x0 + 1, y0),
        getGradient(x0, y0 + 1),
        getGradient(x0 + 1, y0 + 1)
      )

      val origins = Array(
        Vec2(x0f + 0.0, y0f + 0.0),
        Vec2(x0f + 1.0, y0f + 0.0),
        Vec2(x0f + 0.0, y0f + 1.0),
        Vec2(x0f + 1.0, y0f + 1.0)
      )

      (gradients, origins)

    def get(x: Double, y: Double): Double =
      val p = Vec2(x, y)
      val (gradients, origins) = getGradients(x, y)

      val v0 = gradient(origins(0), gradients(0), p)
      val v1 = gradient(origins(1), gradients(1), p)
      val v2 = gradient(origins(2), gradients(2), p)
      val v3 = gradient(origins(3), gradients(3), p)

      val fx = smooth(x - origins(0).x)
      val vx0 = lerp(v0, v1, fx)
      val vx1 = lerp(v2, v3, fx)

      val fy = smooth(y - origins(0).y)
      lerp(vx0, vx1, fy)

    private def gradient(orig: Vec2, grad: Vec2, p: Vec2): Double =
      val sp = Vec2(p.x - orig.x, p.y - orig.y)
      grad.x * sp.x + grad.y * sp.y

    private def lerp(a: Double, b: Double, v: Double): Double =
      a * (1.0 - v) + b * v

    private def smooth(v: Double): Double =
      v * v * (3.0 - 2.0 * v)

  private val SYM = Array(' ', '░', '▒', '▓', '█', '█')

  override def run(iterationId: Int): Unit =
    var y = 0L
    while y < sizeVal do
      var x = 0L
      while x < sizeVal do
        val v = n2d.get(x * 0.1, (y + (iterationId * 128)) * 0.1) * 0.5 + 0.5
        var idx = (v / 0.2).toInt
        if idx >= 6 then idx = 5
        resultVal += SYM(idx).toLong
        x += 1
      y += 1

  override def checksum(): Long = resultVal