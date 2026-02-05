package benchmarks

import Benchmark
import kotlin.math.sqrt

class Nbody : Benchmark() {
    private var resultVal: UInt = 0u
    private val bodies: List<Planet>
    private var v1: Double = 0.0

    companion object {
        private const val SOLAR_MASS = 4.0 * Math.PI * Math.PI
        private const val DAYS_PER_YEAR = 365.24

        class Planet(
            x: Double, y: Double, z: Double,
            vx: Double, vy: Double, vz: Double,
            mass: Double
        ) {
            var x: Double = x
            var y: Double = y
            var z: Double = z
            var vx: Double = vx * DAYS_PER_YEAR
            var vy: Double = vy * DAYS_PER_YEAR
            var vz: Double = vz * DAYS_PER_YEAR
            var mass: Double = mass * SOLAR_MASS

            fun moveFromI(bodies: List<Planet>, nbodies: Int, dt: Double, i: Int) {
                var idx = i
                while (idx < nbodies) {
                    val b2 = bodies[idx]
                    val dx = x - b2.x
                    val dy = y - b2.y
                    val dz = z - b2.z

                    val distance = sqrt(dx * dx + dy * dy + dz * dz)
                    val mag = dt / (distance * distance * distance)
                    val bMassMag = mass * mag
                    val b2MassMag = b2.mass * mag

                    vx -= dx * b2MassMag
                    vy -= dy * b2MassMag
                    vz -= dz * b2MassMag
                    b2.vx += dx * bMassMag
                    b2.vy += dy * bMassMag
                    b2.vz += dz * bMassMag

                    idx += 1
                }

                x += dt * vx
                y += dt * vy
                z += dt * vz
            }
        }

        private val PLANET_DATA = listOf(

            listOf(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0),

            listOf(
                4.84143144246472090e+00,
                -1.16032004402742839e+00,
                -1.03622044471123109e-01,
                1.66007664274403694e-03,
                7.69901118419740425e-03,
                -6.90460016972063023e-05,
                9.54791938424326609e-04
            ),

            listOf(
                8.34336671824457987e+00,
                4.12479856412430479e+00,
                -4.03523417114321381e-01,
                -2.76742510726862411e-03,
                4.99852801234917238e-03,
                2.30417297573763929e-05,
                2.85885980666130812e-04
            ),

            listOf(
                1.28943695621391310e+01,
                -1.51111514016986312e+01,
                -2.23307578892655734e-01,
                2.96460137564761618e-03,
                2.37847173959480950e-03,
                -2.96589568540237556e-05,
                4.36624404335156298e-05
            ),

            listOf(
                1.53796971148509165e+01,
                -2.59193146099879641e+01,
                1.79258772950371181e-01,
                2.68067772490389322e-03,
                1.62824170038242295e-03,
                -9.51592254519715870e-05,
                5.15138902046611451e-05
            )
        )
    }

    init {
        bodies = PLANET_DATA.map { data ->
            Planet(
                data[0], data[1], data[2],  
                data[3], data[4], data[5],  
                data[6]                     
            )
        }
    }

    private fun energy(bodies: List<Planet>): Double {
        var e = 0.0
        val nbodies = bodies.size

        for (i in 0 until nbodies) {
            val b = bodies[i]
            e += 0.5 * b.mass * (b.vx * b.vx + b.vy * b.vy + b.vz * b.vz)
            for (j in i + 1 until nbodies) {
                val b2 = bodies[j]
                val dx = b.x - b2.x
                val dy = b.y - b2.y
                val dz = b.z - b2.z
                val distance = sqrt(dx * dx + dy * dy + dz * dz)
                e -= (b.mass * b2.mass) / distance
            }
        }
        return e
    }

    private fun offsetMomentum(bodies: List<Planet>) {
        var px = 0.0
        var py = 0.0
        var pz = 0.0

        for (b in bodies) {
            px += b.vx * b.mass
            py += b.vy * b.mass
            pz += b.vz * b.mass
        }

        val b = bodies[0]
        b.vx = -px / SOLAR_MASS
        b.vy = -py / SOLAR_MASS
        b.vz = -pz / SOLAR_MASS
    }

    override fun prepare() {
        offsetMomentum(bodies)
        v1 = energy(bodies)
    }

    override fun run(iterationId: Int) {
        val nbodies = bodies.size
        val dt = 0.01

        var i = 0
        while (i < nbodies) {
            val b = bodies[i]
            b.moveFromI(bodies, nbodies, dt, i + 1)
            i++
        }
    }

    override fun checksum(): UInt {
        val v2 = energy(bodies)
        return (Helper.checksumF64(v1) shl 5) and Helper.checksumF64(v2)
    }

    override fun name(): String = "Nbody"
}