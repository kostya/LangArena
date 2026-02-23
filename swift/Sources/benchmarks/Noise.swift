import Foundation

final class Noise: BenchmarkProtocol {
  private struct Vec2 {
    let x: Double
    let y: Double
  }

  private class Noise2DContext {
    private var rgradients: [Vec2]
    private var permutations: [Int]
    private var sizeVal: Int

    init(size: Int) {
      sizeVal = size
      rgradients = [Vec2](repeating: Vec2(x: 0, y: 0), count: size)
      permutations = [Int](0..<size)

      for i in 0..<size {
        let v = Helper.nextFloat() * .pi * 2.0
        rgradients[i] = Vec2(x: cos(v), y: sin(v))
      }

      for i in 0..<size {
        let a = Helper.nextInt(max: size)
        let b = Helper.nextInt(max: size)
        permutations.swapAt(a, b)
      }
    }

    private func getGradient(_ x: Int, _ y: Int) -> Vec2 {
      let idx = permutations[x & (sizeVal - 1)] + permutations[y & (sizeVal - 1)]
      return rgradients[idx & (sizeVal - 1)]
    }

    func get(_ x: Double, _ y: Double) -> Double {
      let x0f = floor(x)
      let y0f = floor(y)
      let x0 = Int(x0f)
      let y0 = Int(y0f)

      let gradients = [
        getGradient(x0, y0),
        getGradient(x0 + 1, y0),
        getGradient(x0, y0 + 1),
        getGradient(x0 + 1, y0 + 1),
      ]

      let origins = [
        Vec2(x: x0f + 0.0, y: y0f + 0.0),
        Vec2(x: x0f + 1.0, y: y0f + 0.0),
        Vec2(x: x0f + 0.0, y: y0f + 1.0),
        Vec2(x: x0f + 1.0, y: y0f + 1.0),
      ]

      let p = Vec2(x: x, y: y)

      func gradient(_ orig: Vec2, _ grad: Vec2, _ p: Vec2) -> Double {
        let sp = Vec2(x: p.x - orig.x, y: p.y - orig.y)
        return grad.x * sp.x + grad.y * sp.y
      }

      func lerp(_ a: Double, _ b: Double, _ v: Double) -> Double {
        return a * (1.0 - v) + b * v
      }

      func smooth(_ v: Double) -> Double {
        return v * v * (3.0 - 2.0 * v)
      }

      let v0 = gradient(origins[0], gradients[0], p)
      let v1 = gradient(origins[1], gradients[1], p)
      let v2 = gradient(origins[2], gradients[2], p)
      let v3 = gradient(origins[3], gradients[3], p)

      let fx = smooth(x - origins[0].x)
      let vx0 = lerp(v0, v1, fx)
      let vx1 = lerp(v2, v3, fx)
      let fy = smooth(y - origins[0].y)

      return lerp(vx0, vx1, fy)
    }
  }

  private static let SYM: [Character] = [" ", "░", "▒", "▓", "█", "█"]
  private var sizeVal: Int64 = 0
  private var resultVal: UInt32 = 0
  private var n2d: Noise2DContext!

  init() {
    sizeVal = configValue("size") ?? 0
    n2d = Noise2DContext(size: Int(sizeVal))
  }

  func run(iterationId: Int) {
    for y in 0..<Int(sizeVal) {
      for x in 0..<Int(sizeVal) {
        let v = n2d.get(Double(x) * 0.1, Double(y + (iterationId * 128)) * 0.1) * 0.5 + 0.5
        let idx = Int(v / 0.2)
        let clampedIdx = min(idx, 5)
        let sym = Noise.SYM[clampedIdx]
        let codePoint = sym.unicodeScalars.first!.value
        resultVal &+= UInt32(codePoint)
      }
    }
  }

  var checksum: UInt32 {
    return resultVal
  }

  func prepare() {}

  func name() -> String {
    return "Etc::Noise"
  }
}
