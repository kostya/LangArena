import std/[math, random]
import ../benchmark
import ../helper

type
  Vec2 = object
    x, y: float

  Noise2DContext = object
    rgradients: seq[Vec2]
    permutations: seq[int]
    sizeVal: int

  Noise* = ref object of Benchmark
    sizeVal: int64
    resultVal: uint32
    n2d: Noise2DContext

proc newNoise(): Benchmark =
  Noise()

method name(self: Noise): string = "Noise"

proc randomGradient(): Vec2 =
  let v = nextFloat() * PI * 2.0
  Vec2(x: cos(v), y: sin(v))

proc lerp(a, b, v: float): float =
  a * (1.0 - v) + b * v

proc smooth(v: float): float =
  v * v * (3.0 - 2.0 * v)

proc gradient(orig, grad, p: Vec2): float =
  let sp = Vec2(x: p.x - orig.x, y: p.y - orig.y)
  grad.x * sp.x + grad.y * sp.y

proc newNoise2DContext(size: int): Noise2DContext =
  result.sizeVal = size
  result.rgradients = newSeq[Vec2](size)
  result.permutations = newSeq[int](size)

  for i in 0..<size:
    result.rgradients[i] = randomGradient()
    result.permutations[i] = i

  for i in 0..<size:
    let a = nextInt(int32(size))
    let b = nextInt(int32(size))
    swap(result.permutations[a], result.permutations[b])

proc getGradient(ctx: Noise2DContext, x, y: int): Vec2 =
  let idx = ctx.permutations[x and (ctx.sizeVal - 1)] +
            ctx.permutations[y and (ctx.sizeVal - 1)]
  ctx.rgradients[idx and (ctx.sizeVal - 1)]

proc get(ctx: Noise2DContext, x, y: float): float =
  let p = Vec2(x: x, y: y)
  let x0f = floor(x)
  let y0f = floor(y)
  let x0 = int(x0f)
  let y0 = int(y0f)
  let x1 = x0 + 1
  let y1 = y0 + 1

  let gradients = [
    ctx.getGradient(x0, y0),
    ctx.getGradient(x1, y0),
    ctx.getGradient(x0, y1),
    ctx.getGradient(x1, y1)
  ]

  let origins = [
    Vec2(x: x0f + 0.0, y: y0f + 0.0),
    Vec2(x: x0f + 1.0, y: y0f + 0.0),
    Vec2(x: x0f + 0.0, y: y0f + 1.0),
    Vec2(x: x0f + 1.0, y: y0f + 1.0)
  ]

  let v0 = gradient(origins[0], gradients[0], p)
  let v1 = gradient(origins[1], gradients[1], p)
  let v2 = gradient(origins[2], gradients[2], p)
  let v3 = gradient(origins[3], gradients[3], p)

  let fx = smooth(x - origins[0].x)
  let vx0 = lerp(v0, v1, fx)
  let vx1 = lerp(v2, v3, fx)

  let fy = smooth(y - origins[0].y)
  lerp(vx0, vx1, fy)

method prepare(self: Noise) =
  self.sizeVal = self.config_val("size")
  reset()
  self.n2d = newNoise2DContext(self.sizeVal.int)
  self.resultVal = 0

method run(self: Noise, iteration_id: int) =
  const SYM_CODES: array[6, uint32] = [
      32'u32,
      9617'u32,
      9618'u32,
      9619'u32,
      9608'u32,
      9608'u32
  ]

  for y in 0..<self.sizeVal:
    for x in 0..<self.sizeVal:
      let v = self.n2d.get(float(x) * 0.1,
                          float(y + iteration_id * 128) * 0.1) * 0.5 + 0.5
      var idx = int(v / 0.2)
      if idx >= 6:
        idx = 5
      self.resultVal += SYM_CODES[idx]

method checksum(self: Noise): uint32 =
  self.resultVal

registerBenchmark("Noise", newNoise)
