package benchmarks

class TextRaytracer extends Benchmark:
  private var w: Int = 0
  private var h: Int = 0
  private var resultVal: Long = 0L

  override def name(): String = "TextRaytracer"

  override def prepare(): Unit =
    w = configVal("w").toInt
    h = configVal("h").toInt

  private class Vector(val x: Double, val y: Double, val z: Double):
    def scale(s: Double): Vector = new Vector(x * s, y * s, z * s)
    def add(other: Vector): Vector = new Vector(x + other.x, y + other.y, z + other.z)
    def sub(other: Vector): Vector = new Vector(x - other.x, y - other.y, z - other.z)
    def dot(other: Vector): Double = x * other.x + y * other.y + z * other.z
    def magnitude: Double = math.sqrt(dot(this))
    def normalize: Vector = scale(1.0 / magnitude)

  private class Ray(val orig: Vector, val dir: Vector)

  private class Color(val r: Double, val g: Double, val b: Double):
    def scale(s: Double): Color = new Color(r * s, g * s, b * s)
    def add(other: Color): Color = new Color(r + other.r, g + other.g, b + other.b)

  private class Sphere(val center: Vector, val radius: Double, val color: Color):
    def getNormal(pt: Vector): Vector = pt.sub(center).normalize

  private class Light(val position: Vector, val color: Color)
  private class Hit(val obj: Sphere, val value: Double)

  private val WHITE = new Color(1.0, 1.0, 1.0)
  private val RED = new Color(1.0, 0.0, 0.0)
  private val GREEN = new Color(0.0, 1.0, 0.0)
  private val BLUE = new Color(0.0, 0.0, 1.0)
  private val LIGHT1 = new Light(new Vector(0.7, -1.0, 1.7), WHITE)
  private val LUT = Array('.', '-', '+', '*', 'X', 'M')

  private val SCENE = Array(
    new Sphere(new Vector(-1.0, 0.0, 3.0), 0.3, RED),
    new Sphere(new Vector(0.0, 0.0, 3.0), 0.8, GREEN),
    new Sphere(new Vector(1.0, 0.0, 3.0), 0.4, BLUE)
  )

  private def shadePixel(ray: Ray, obj: Sphere, tval: Double): Int =
    val pi = ray.orig.add(ray.dir.scale(tval))
    val color = diffuseShading(pi, obj, LIGHT1)
    val col = (color.r + color.g + color.b) / 3.0
    (col * 6.0).toInt

  private def intersectSphere(ray: Ray, center: Vector, radius: Double): Double =
    val l = center.sub(ray.orig)
    val tca = l.dot(ray.dir)
    if tca < 0.0 then return -1.0

    val d2 = l.dot(l) - tca * tca
    val r2 = radius * radius
    if d2 > r2 then return -1.0

    val thc = math.sqrt(r2 - d2)
    val t0 = tca - thc
    if t0 > 10000 then -1.0 else t0

  private def clamp(x: Double, a: Double, b: Double): Double =
    if x < a then a else if x > b then b else x

  private def diffuseShading(pi: Vector, obj: Sphere, light: Light): Color =
    val n = obj.getNormal(pi)
    val lam1 = light.position.sub(pi).normalize.dot(n)
    val lam2 = clamp(lam1, 0.0, 1.0)
    light.color.scale(lam2 * 0.5).add(obj.color.scale(0.3))

  override def run(iterationId: Int): Unit =
    val fw = w.toDouble
    val fh = h.toDouble

    var j = 0
    while j < h do
      var i = 0
      while i < w do
        val fi = i.toDouble
        val fj = j.toDouble

        val ray = new Ray(
          new Vector(0.0, 0.0, 0.0),
          new Vector((fi - fw / 2.0) / fw, (fj - fh / 2.0) / fh, 1.0).normalize
        )

        var hit: Hit = null
        var idx = 0
        while idx < SCENE.length && hit == null do
          val obj = SCENE(idx)
          val t = intersectSphere(ray, obj.center, obj.radius)
          if t >= 0.0 then
            hit = new Hit(obj, t)
          idx += 1

        val pixel = 
          if hit != null then
            var shade = shadePixel(ray, hit.obj, hit.value)
            if shade < 0 then shade = 0
            if shade >= LUT.length then shade = LUT.length - 1
            LUT(shade)
          else
            ' '

        resultVal += pixel.toLong
        i += 1
      j += 1

  override def checksum(): Long = resultVal & 0xFFFFFFFFL