package benchmarks

import scala.collection.mutable.ArrayBuffer
import scala.math.sqrt

class Nbody extends Benchmark {
  private var resultVal: Long = 0L
  private val bodies: ArrayBuffer[Planet] = ArrayBuffer.empty[Planet]  
  private var v1: Double = 0.0

  private final val SOLAR_MASS = 4.0 * math.Pi * math.Pi
  private final val DAYS_PER_YEAR = 365.24

  class Planet(
    var x: Double, var y: Double, var z: Double,
    var vx: Double, var vy: Double, var vz: Double,
    var mass: Double
  ) {

    def this(
      x: Double, y: Double, z: Double,
      vx: Double, vy: Double, vz: Double,
      mass: Double, convert: Boolean
    ) = {
      this(
        x, y, z,
        vx * (if (convert) DAYS_PER_YEAR else 1.0),
        vy * (if (convert) DAYS_PER_YEAR else 1.0),
        vz * (if (convert) DAYS_PER_YEAR else 1.0),
        mass * (if (convert) SOLAR_MASS else 1.0)
      )
    }

    def moveFromI(bodies: ArrayBuffer[Planet], nbodies: Int, dt: Double, startIdx: Int): Unit = {
      var i = startIdx
      while (i < nbodies) {
        val b2 = bodies(i)
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

        i += 1
      }

      x += dt * vx
      y += dt * vy
      z += dt * vz
    }
  }

  private val PLANET_DATA = Array(
    Array(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0),
    Array(
      4.84143144246472090e+00,
      -1.16032004402742839e+00,
      -1.03622044471123109e-01,
      1.66007664274403694e-03,
      7.69901118419740425e-03,
      -6.90460016972063023e-05,
      9.54791938424326609e-04
    ),
    Array(
      8.34336671824457987e+00,
      4.12479856412430479e+00,
      -4.03523417114321381e-01,
      -2.76742510726862411e-03,
      4.99852801234917238e-03,
      2.30417297573763929e-05,
      2.85885980666130812e-04
    ),
    Array(
      1.28943695621391310e+01,
      -1.51111514016986312e+01,
      -2.23307578892655734e-01,
      2.96460137564761618e-03,
      2.37847173959480950e-03,
      -2.96589568540237556e-05,
      4.36624404335156298e-05
    ),
    Array(
      1.53796971148509165e+01,
      -2.59193146099879641e+01,
      1.79258772950371181e-01,
      2.68067772490389322e-03,
      1.62824170038242295e-03,
      -9.51592254519715870e-05,
      5.15138902046611451e-05
    )
  )

  PLANET_DATA.foreach { data =>
    bodies.append(new Planet(
      data(0), data(1), data(2),
      data(3), data(4), data(5),
      data(6), true
    ))
  }

  private def energy(bodies: ArrayBuffer[Planet]): Double = {
    var e = 0.0
    val nbodies = bodies.length

    var i = 0
    while (i < nbodies) {
      val b = bodies(i)
      e += 0.5 * b.mass * (b.vx * b.vx + b.vy * b.vy + b.vz * b.vz)

      var j = i + 1
      while (j < nbodies) {
        val b2 = bodies(j)
        val dx = b.x - b2.x
        val dy = b.y - b2.y
        val dz = b.z - b2.z
        val distance = sqrt(dx * dx + dy * dy + dz * dz)
        e -= (b.mass * b2.mass) / distance
        j += 1
      }
      i += 1
    }
    e
  }

  private def offsetMomentum(bodies: ArrayBuffer[Planet]): Unit = {
    var px = 0.0
    var py = 0.0
    var pz = 0.0

    var i = 0
    while (i < bodies.length) {
      val b = bodies(i)
      px += b.vx * b.mass
      py += b.vy * b.mass
      pz += b.vz * b.mass
      i += 1
    }

    val b = bodies(0)
    b.vx = -px / SOLAR_MASS
    b.vy = -py / SOLAR_MASS
    b.vz = -pz / SOLAR_MASS
  }

  override def prepare(): Unit = {
    offsetMomentum(bodies)
    v1 = energy(bodies)
  }

  override def run(iterationId: Int): Unit = {
    val nbodies = bodies.length

    var j = 0
    while (j < 1000) {
      var i = 0
      while (i < nbodies) {
        val b = bodies(i)
        b.moveFromI(bodies, nbodies, 0.01, i + 1)
        i += 1
      }
      j += 1
    }
  }

  override def checksum(): Long = {
    val v2 = energy(bodies)
    (Helper.checksumF64(v1) << 5) & Helper.checksumF64(v2)
  }

  override def name(): String = "Nbody"
}