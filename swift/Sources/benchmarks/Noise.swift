import Foundation
final class Noise: BenchmarkProtocol {
    private static let SIZE = 64
    private static let SYM: [Character] = [" ", "░", "▒", "▓", "█", "█"]
    private struct Vec2 {
        let x: Double
        let y: Double
    }
    private static func lerp(_ a: Double, _ b: Double, _ v: Double) -> Double {
        return a * (1.0 - v) + b * v
    }
    private static func smooth(_ v: Double) -> Double {
        return v * v * (3.0 - 2.0 * v)
    }
    private static func randomGradient() -> Vec2 {
        let v = Helper.nextFloat() * .pi * 2.0
        return Vec2(x: cos(v), y: sin(v))
    }
    private static func gradient(_ orig: Vec2, _ grad: Vec2, _ p: Vec2) -> Double {
        let sp = Vec2(x: p.x - orig.x, y: p.y - orig.y)
        return grad.x * sp.x + grad.y * sp.y
    }
    private class Noise2DContext {
        private let rgradients: [Vec2]
        private var permutations: [Int]
        init() {
            // Инициализация градиентов
            rgradients = (0..<Noise.SIZE).map { _ in Noise.randomGradient() }
            // Инициализация перестановок
            permutations = Array(0..<Noise.SIZE)
            // Перемешивание
            for _ in 0..<Noise.SIZE {
                let a = Helper.nextInt(max: Noise.SIZE)
                let b = Helper.nextInt(max: Noise.SIZE)
                permutations.swapAt(a, b)
            }
        }
        private func getGradient(_ x: Int, _ y: Int) -> Vec2 {
            let idx = permutations[x & (Noise.SIZE - 1)] + permutations[y & (Noise.SIZE - 1)]
            return rgradients[idx & (Noise.SIZE - 1)]
        }
        private func getGradients(_ x: Double, _ y: Double) -> (gradients: [Vec2], origins: [Vec2]) {
            let x0f = floor(x)
            let y0f = floor(y)
            let x0 = Int(x0f)
            let y0 = Int(y0f)
            let gradients = [
                getGradient(x0, y0),
                getGradient(x0 + 1, y0),
                getGradient(x0, y0 + 1),
                getGradient(x0 + 1, y0 + 1)
            ]
            let origins = [
                Vec2(x: x0f + 0.0, y: y0f + 0.0),
                Vec2(x: x0f + 1.0, y: y0f + 0.0),
                Vec2(x: x0f + 0.0, y: y0f + 1.0),
                Vec2(x: x0f + 1.0, y: y0f + 1.0)
            ]
            return (gradients, origins)
        }
        func get(_ x: Double, _ y: Double) -> Double {
            let p = Vec2(x: x, y: y)
            let (gradients, origins) = getGradients(x, y)
            let v0 = Noise.gradient(origins[0], gradients[0], p)
            let v1 = Noise.gradient(origins[1], gradients[1], p)
            let v2 = Noise.gradient(origins[2], gradients[2], p)
            let v3 = Noise.gradient(origins[3], gradients[3], p)
            let fx = Noise.smooth(x - origins[0].x)
            let vx0 = Noise.lerp(v0, v1, fx)
            let vx1 = Noise.lerp(v2, v3, fx)
            let fy = Noise.smooth(y - origins[0].y)
            return Noise.lerp(vx0, vx1, fy)
        }
    }
    private var n: Int = 0
    private var _result: UInt64 = 0
    init() {
        n = iterations
    }
    // Полный исправленный метод noise():
    private func noise() -> UInt64 {
        var pixels = Array(repeating: Array(repeating: 0.0, count: Noise.SIZE), count: Noise.SIZE)
        let n2d = Noise2DContext()
        
        for i in 0..<100 {
            for y in 0..<Noise.SIZE {
                for x in 0..<Noise.SIZE {
                    let v = n2d.get(Double(x) * 0.1, Double(y + (i * 128)) * 0.1) * 0.5 + 0.5
                    pixels[y][x] = v
                }
            }
        }
        
        var res: UInt64 = 0
        
        for y in 0..<Noise.SIZE {
            for x in 0..<Noise.SIZE {
                let v = pixels[y][x]
                let idx = Int(v / 0.2)
                let clampedIdx = min(idx, 5)
                let sym = Noise.SYM[clampedIdx]
                
                // КЛЮЧЕВОЕ ИСПРАВЛЕНИЕ:
                // Используем unicode scalar value как в Kotlin .code
                let codePoint = sym.unicodeScalars.first!.value
                res &+= UInt64(codePoint)
            }
        }
        
        return res
    }
    func run() {
        for _ in 0..<n {
            let v = noise()
            _result &+= v
        }
    }
    var result: Int64 {
        return Int64(bitPattern: _result)
    }
    func prepare() {}
}