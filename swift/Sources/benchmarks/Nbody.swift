import Foundation

final class Nbody: BenchmarkProtocol {
    private var n: Int = 0
    private var resultValue: Int64 = 0
    
    private static let SOLAR_MASS = 4.0 * .pi * .pi
    private static let DAYS_PER_YEAR = 365.24
    
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
    }
    
    // Исходные данные
    private static let PLANET_DATA: [[Double]] = [
        // sun
        [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0],
        // jupiter
        [4.84143144246472090e+00, -1.16032004402742839e+00, -1.03622044471123109e-01,
         1.66007664274403694e-03, 7.69901118419740425e-03, -6.90460016972063023e-05,
         9.54791938424326609e-04],
        // saturn
        [8.34336671824457987e+00, 4.12479856412430479e+00, -4.03523417114321381e-01,
         -2.76742510726862411e-03, 4.99852801234917238e-03, 2.30417297573763929e-05,
         2.85885980666130812e-04],
        // uranus
        [1.28943695621391310e+01, -1.51111514016986312e+01, -2.23307578892655734e-01,
         2.96460137564761618e-03, 2.37847173959480950e-03, -2.96589568540237556e-05,
         4.36624404335156298e-05],
        // neptune
        [1.53796971148509165e+01, -2.59193146099879641e+01, 1.79258772950371181e-01,
         2.68067772490389322e-03, 1.62824170038242295e-03, -9.51592254519715870e-05,
         5.15138902046611451e-05]
    ]
    
    init() {
        n = iterations
    }
    
    private func energy(_ bodies: [Planet]) -> Double {
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
    
    private func offsetMomentum(_ bodies: [Planet]) {
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
    
    private func advance(_ bodies: [Planet], dt: Double) {
        let nbodies = bodies.count
        
        for i in 0..<nbodies {
            let b = bodies[i]
            
            var idx = i + 1
            while idx < nbodies {
                let b2 = bodies[idx]
                let dx = b.x - b2.x
                let dy = b.y - b2.y
                let dz = b.z - b2.z
                
                let distance = sqrt(dx * dx + dy * dy + dz * dz)
                let mag = dt / (distance * distance * distance)
                let bMassMag = b.mass * mag
                let b2MassMag = b2.mass * mag
                
                b.vx -= dx * b2MassMag
                b.vy -= dy * b2MassMag
                b.vz -= dz * b2MassMag
                b2.vx += dx * bMassMag
                b2.vy += dy * bMassMag
                b2.vz += dz * bMassMag
                
                idx += 1
            }
        }
        
        // Обновляем позиции после вычисления всех сил
        for b in bodies {
            b.x += dt * b.vx
            b.y += dt * b.vy
            b.z += dt * b.vz
        }
    }
    
    func run() {
        // Создаем планеты
        let bodies = Nbody.PLANET_DATA.map { data in
            Planet(
                x: data[0], y: data[1], z: data[2],
                vx: data[3], vy: data[4], vz: data[5],
                mass: data[6]
            )
        }
        
        offsetMomentum(bodies)
        
        let v1 = energy(bodies)
        let dt = 0.01
        
        for _ in 0..<n {
            advance(bodies, dt: dt)
        }
        
        let v2 = energy(bodies)
        
        let checksum1 = Helper.checksumF64(v1)
        let checksum2 = Helper.checksumF64(v2)
        resultValue = (Int64(checksum1) << 5) & Int64(checksum2)
    }
    
    var result: Int64 {
        return resultValue
    }
    
    func prepare() {}
}