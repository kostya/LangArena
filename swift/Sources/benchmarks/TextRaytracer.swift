import Foundation

final class TextRaytracer: BenchmarkProtocol {
    private struct Vector {
        let x: Double
        let y: Double
        let z: Double

        func scale(_ s: Double) -> Vector {
            Vector(x: x * s, y: y * s, z: z * s)
        }

        static func + (_ lhs: Vector, _ rhs: Vector) -> Vector {
            Vector(x: lhs.x + rhs.x, y: lhs.y + rhs.y, z: lhs.z + rhs.z)
        }

        static func - (_ lhs: Vector, _ rhs: Vector) -> Vector {
            Vector(x: lhs.x - rhs.x, y: lhs.y - rhs.y, z: lhs.z - rhs.z)
        }

        func dot(_ other: Vector) -> Double {
            x * other.x + y * other.y + z * other.z
        }

        func magnitude() -> Double {
            let d = dot(self)
            return d > 0.0 ? sqrt(d) : 0.0
        }

        func normalize() -> Vector {
            let mag = magnitude()
            return mag == 0.0 ? Vector(x: 0, y: 0, z: 0) : scale(1.0 / mag)
        }
    }

    private struct Ray {
        let orig: Vector
        let dir: Vector
    }

    private struct Color {
        let r: Double
        let g: Double
        let b: Double

        func scale(_ s: Double) -> Color {
            Color(r: r * s, g: g * s, b: b * s)
        }

        static func + (_ lhs: Color, _ rhs: Color) -> Color {
            Color(r: lhs.r + rhs.r, g: lhs.g + rhs.g, b: lhs.b + rhs.b)
        }
    }

    private struct Sphere {
        let center: Vector
        let radius: Double
        let color: Color

        func getNormal(_ pt: Vector) -> Vector {
            (pt - center).normalize()
        }
    }

    private struct Light {
        let position: Vector
        let color: Color
    }

    private static let WHITE = Color(r: 1.0, g: 1.0, b: 1.0)
    private static let RED = Color(r: 1.0, g: 0.0, b: 0.0)
    private static let GREEN = Color(r: 0.0, g: 1.0, b: 0.0)
    private static let BLUE = Color(r: 0.0, g: 0.0, b: 1.0)
    private static let LIGHT1 = Light(
        position: Vector(x: 0.7, y: -1.0, z: 1.7),
        color: WHITE
    )
    private static let LUT: [Character] = [".", "-", "+", "*", "X", "M"]
    private static let SCENE = [
        Sphere(center: Vector(x: -1.0, y: 0.0, z: 3.0), radius: 0.3, color: RED),
        Sphere(center: Vector(x: 0.0, y: 0.0, z: 3.0), radius: 0.8, color: GREEN),
        Sphere(center: Vector(x: 1.0, y: 0.0, z: 3.0), radius: 0.4, color: BLUE)
    ]

    private var w: Int32 = 0
    private var h: Int32 = 0
    private var resultVal: UInt32 = 0

    init() {
        w = Int32(configValue("w") ?? 0)
        h = Int32(configValue("h") ?? 0)
    }

    private func shadePixel(_ ray: Ray, _ obj: Sphere, _ tval: Double) -> Int {
        let pi = ray.orig + ray.dir.scale(tval)
        let color = diffuseShading(pi, obj, TextRaytracer.LIGHT1)
        let col = (color.r + color.g + color.b) / 3.0
        var idx = Int(col * 6.0)
        if idx < 0 { idx = 0 }
        if idx >= 6 { idx = 5 }
        return idx
    }

    private func intersectSphere(_ ray: Ray, _ center: Vector, _ radius: Double) -> Double? {
        let l = center - ray.orig
        let tca = l.dot(ray.dir)
        if tca < 0.0 { return nil }
        let d2 = l.dot(l) - tca * tca
        let r2 = radius * radius
        if d2 > r2 { return nil }
        let thc = sqrt(r2 - d2)
        let t0 = tca - thc
        if t0 > 10000.0 { return nil }
        return t0
    }

    private func clamp(_ x: Double, _ a: Double, _ b: Double) -> Double {
        if x < a { return a }
        if x > b { return b }
        return x
    }

    private func diffuseShading(_ pi: Vector, _ obj: Sphere, _ light: Light) -> Color {
        let n = obj.getNormal(pi)
        let lam1 = (light.position - pi).normalize().dot(n)
        let lam2 = clamp(lam1, 0.0, 1.0)
        return light.color.scale(lam2 * 0.5) + obj.color.scale(0.3)
    }

    func run(iterationId: Int) {
        let fw = Double(w)
        let fh = Double(h)

        for j in 0..<Int(h) {
            for i in 0..<Int(w) {
                let fi = Double(i)
                let fj = Double(j)
                let ray = Ray(
                    orig: Vector(x: 0.0, y: 0.0, z: 0.0),
                    dir: Vector(
                        x: (fi - fw / 2.0) / fw,
                        y: (fj - fh / 2.0) / fh,
                        z: 1.0
                    ).normalize()
                )

                var hitObj: Sphere? = nil
                var tval: Double? = nil

                for obj in TextRaytracer.SCENE {
                    if let ret = intersectSphere(ray, obj.center, obj.radius) {
                        hitObj = obj
                        tval = ret
                        break
                    }
                }

                let pixel: Character
                if let hitObj = hitObj, let tval = tval {
                    let shade = shadePixel(ray, hitObj, tval)
                    pixel = TextRaytracer.LUT[shade]
                } else {
                    pixel = " "
                }
                resultVal &+= UInt32(pixel.asciiValue ?? 0)
            }
        }
    }

    var checksum: UInt32 {
        return resultVal
    }

    func prepare() {}
}