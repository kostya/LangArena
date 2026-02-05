import Foundation

final class Nbody: BenchmarkProtocol {
    private static let SOLAR_MASS = 4.0 * .pi * .pi
    private static let DAYS_PER_YEAR = 365.24
    private var v1: Double = 0.0
    private var resultVal: UInt32 = 0

    private class Planet {
        var x: Double
        var y: Double
        var z: Double
        var vx: Double
        var vy: Double
        var vz: Double
        var mass: Double

        init(x: Double, y: Double, z: Double,
             vx: Double, vy: Double, vz: Double,
             mass: Double) {
            self.x = x
            self.y = y
            self.z = z
            self.vx = vx * Nbody.DAYS_PER_YEAR
            self.vy = vy * Nbody.DAYS_PER_YEAR
            self.vz = vz * Nbody.DAYS_PER_YEAR
            self.mass = mass * Nbody.SOLAR_MASS
        }

        func moveFromI(_ bodies: [Planet], _ nbodies: Int, _ dt: Double, _ startIdx: Int) {
            var i = startIdx
            while i < nbodies {
                let b2 = bodies[i]
                let dx = self.x - b2.x
                let dy = self.y - b2.y
                let dz = self.z - b2.z

                let distance = sqrt(dx * dx + dy * dy + dz * dz)
                let mag = dt / (distance * distance * distance)
                let bMassMag = self.mass * mag
                let b2MassMag = b2.mass * mag

                self.vx -= dx * b2MassMag
                self.vy -= dy * b2MassMag
                self.vz -= dz * b2MassMag
                b2.vx += dx * bMassMag
                b2.vy += dy * bMassMag
                b2.vz += dz * bMassMag

                i += 1
            }

            self.x += dt * self.vx
            self.y += dt * self.vy
            self.z += dt * self.vz
        }
    }

    private static let PLANET_DATA: [[Double]] = [
        [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0],
        [4.84143144246472090e+00, -1.16032004402742839e+00, -1.03622044471123109e-01,
         1.66007664274403694e-03, 7.69901118419740425e-03, -6.90460016972063023e-05,
         9.54791938424326609e-04],
        [8.34336671824457987e+00, 4.12479856412430479e+00, -4.03523417114321381e-01,
         -2.76742510726862411e-03, 4.99852801234917238e-03, 2.30417297573763929e-05,
         2.85885980666130812e-04],
        [1.28943695621391310e+01, -1.51111514016986312e+01, -2.23307578892655734e-01,
         2.96460137564761618e-03, 2.37847173959480950e-03, -2.96589568540237556e-05,
         4.36624404335156298e-05],
        [1.53796971148509165e+01, -2.59193146099879641e+01, 1.79258772950371181e-01,
         2.68067772490389322e-03, 1.62824170038242295e-03, -9.51592254519715870e-05,
         5.15138902046611451e-05]
    ]

    private var bodies: [Planet] = []

    init() {
        bodies = Nbody.PLANET_DATA.map { data in
            Planet(
                x: data[0], y: data[1], z: data[2],
                vx: data[3], vy: data[4], vz: data[5],
                mass: data[6]
            )
        }
    }

    private func energy() -> Double {
        var e = 0.0
        let nbodies = bodies.count

        for i in 0..<nbodies {
            let b = bodies[i]
            e += 0.5 * b.mass * (b.vx * b.vx + b.vy * b.vy + b.vz * b.vz)
            for j in (i + 1)..<nbodies {
                let b2 = bodies[j]
                let dx = b.x - b2.x
                let dy = b.y - b2.y
                let dz = b.z - b2.z
                let distance = sqrt(dx * dx + dy * dy + dz * dz)
                e -= (b.mass * b2.mass) / distance
            }
        }
        return e
    }

    private func offsetMomentum() {
        var px = 0.0
        var py = 0.0
        var pz = 0.0

        for b in bodies {
            px += b.vx * b.mass
            py += b.vy * b.mass
            pz += b.vz * b.mass
        }

        let b = bodies[0]
        b.vx = -px / Nbody.SOLAR_MASS
        b.vy = -py / Nbody.SOLAR_MASS
        b.vz = -pz / Nbody.SOLAR_MASS
    }

    func prepare() {
        offsetMomentum()
        v1 = energy()
    }

    func run(iterationId: Int) {
        let nbodies = bodies.count
        let dt = 0.01

        var i = 0
        while i < nbodies {
            let b = bodies[i]
            b.moveFromI(bodies, nbodies, dt, i + 1)
            i += 1
        }
    }

    var checksum: UInt32 {
        let v2 = energy()
        return (Helper.checksumF64(v1) << 5) & Helper.checksumF64(v2)
    }
}