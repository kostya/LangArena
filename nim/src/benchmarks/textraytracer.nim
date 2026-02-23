import std/[math]
import ../benchmark
import ../helper

type
  Vector = object
    x, y, z: float

  Ray = object
    orig, dir: Vector

  Color = object
    r, g, b: float

  Sphere = object
    center: Vector
    radius: float
    color: Color

  Light = object

  TextRaytracer* = ref object of Benchmark
    w, h: int32
    resultVal: uint32

proc newTextRaytracer(): Benchmark =
  TextRaytracer()

method name(self: TextRaytracer): string = "Etc::TextRaytracer"

proc scale(v: Vector, s: float): Vector =
  Vector(x: v.x * s, y: v.y * s, z: v.z * s)

proc add(a, b: Vector): Vector =
  Vector(x: a.x + b.x, y: a.y + b.y, z: a.z + b.z)

proc sub(a, b: Vector): Vector =
  Vector(x: a.x - b.x, y: a.y - b.y, z: a.z - b.z)

proc dot(a, b: Vector): float =
  a.x * b.x + a.y * b.y + a.z * b.z

proc magnitude(v: Vector): float =
  sqrt(v.dot(v))

proc normalize(v: Vector): Vector =
  let mag = v.magnitude()
  if mag == 0.0:
    return Vector(x: 0, y: 0, z: 0)
  v.scale(1.0 / mag)

proc scale(c: Color, s: float): Color =
  Color(r: c.r * s, g: c.g * s, b: c.b * s)

proc add(a, b: Color): Color =
  Color(r: a.r + b.r, g: a.g + b.g, b: a.b + b.b)

proc getNormal(sphere: Sphere, pt: Vector): Vector =
  pt.sub(sphere.center).normalize()

const
  WHITE = Color(r: 1.0, g: 1.0, b: 1.0)
  RED = Color(r: 1.0, g: 0.0, b: 0.0)
  GREEN = Color(r: 0.0, g: 1.0, b: 0.0)
  BLUE = Color(r: 0.0, g: 0.0, b: 1.0)

  LIGHT1 = (position: Vector(x: 0.7, y: -1.0, z: 1.7), color: WHITE)
  LUT = ['.', '-', '+', '*', 'X', 'M']

method prepare(self: TextRaytracer) =
  self.w = int32(self.config_val("w"))
  self.h = int32(self.config_val("h"))
  self.resultVal = 0

proc intersectSphere(ray: Ray, center: Vector, radius: float): float =
  let l = center.sub(ray.orig)
  let tca = l.dot(ray.dir)
  if tca < 0.0:
    return -1.0

  let d2 = l.dot(l) - tca * tca
  let r2 = radius * radius
  if d2 > r2:
    return -1.0

  let thc = sqrt(r2 - d2)
  let t0 = tca - thc
  if t0 > 10000.0:
    return -1.0

  t0

proc clamp(x, a, b: float): float =
  if x < a: a
  elif x > b: b
  else: x

proc diffuseShading(pi: Vector, obj: Sphere, lightPos: Vector,
    lightColor: Color): Color =
  let n = obj.getNormal(pi)
  let lightDir = lightPos.sub(pi).normalize()
  let lam1 = lightDir.dot(n)
  let lam2 = clamp(lam1, 0.0, 1.0)
  lightColor.scale(lam2 * 0.5).add(obj.color.scale(0.3))

method run(self: TextRaytracer, iteration_id: int) =
  let SCENE = [
    Sphere(center: Vector(x: -1.0, y: 0.0, z: 3.0), radius: 0.3, color: RED),
    Sphere(center: Vector(x: 0.0, y: 0.0, z: 3.0), radius: 0.8, color: GREEN),
    Sphere(center: Vector(x: 1.0, y: 0.0, z: 3.0), radius: 0.4, color: BLUE)
  ]

  for j in 0..<self.h:
    for i in 0..<self.w:
      let fw = float(self.w)
      let fi = float(i)
      let fj = float(j)
      let fh = float(self.h)

      let ray = Ray(
        orig: Vector(x: 0.0, y: 0.0, z: 0.0),
        dir: normalize(Vector(
          x: (fi - fw/2.0)/fw,
          y: (fj - fh/2.0)/fh,
          z: 1.0
        ))
      )

      var tval = -1.0
      var hitObj: Sphere
      var hit = false

      for obj in SCENE:
        let intersect = intersectSphere(ray, obj.center, obj.radius)
        if intersect >= 0.0:
          tval = intersect
          hitObj = obj
          hit = true
          break

      var pixel = ' '
      if hit:
        let pi = ray.orig.add(ray.dir.scale(tval))
        let color = diffuseShading(pi, hitObj, LIGHT1.position, LIGHT1.color)
        let col = (color.r + color.g + color.b) / 3.0
        var idx = int(col * 6.0)
        if idx < 0: idx = 0
        if idx >= 6: idx = 5
        pixel = LUT[idx]

      self.resultVal += uint8(pixel)

method checksum(self: TextRaytracer): uint32 =
  self.resultVal

registerBenchmark("Etc::TextRaytracer", newTextRaytracer)
