from std.math import sqrt, pi
from helper import Helper
from benchmark import Benchmark, Config

comptime SOLAR_MASS = 4.0 * pi * pi
comptime DAYS_PER_YEAR = 365.24


struct _Planet(ImplicitlyCopyable):
    var x: Float64
    var y: Float64
    var z: Float64
    var vx: Float64
    var vy: Float64
    var vz: Float64
    var mass: Float64

    def __init__(
        out self,
        x: Float64,
        y: Float64,
        z: Float64,
        vx: Float64,
        vy: Float64,
        vz: Float64,
        mass: Float64,
    ):
        self.x = x
        self.y = y
        self.z = z
        self.vx = vx * DAYS_PER_YEAR
        self.vy = vy * DAYS_PER_YEAR
        self.vz = vz * DAYS_PER_YEAR
        self.mass = mass * SOLAR_MASS


struct Nbody(Benchmark):
    var bodies: List[_Planet]
    var v1: Float64
    var result: UInt32

    def __init__(out self, config: Config) raises:
        self.bodies = Self._init_bodies()
        self.v1 = 0.0
        self.result = 0

    def class_name(self) -> String:
        return "CLBG::Nbody"

    def prepare(mut self, mut helper: Helper) raises:
        Self._offset_momentum(self.bodies)
        self.v1 = Self._energy(self.bodies)

    def run(mut self, iteration_id: Int, mut helper: Helper) raises:
        var nbodies = len(self.bodies)
        var dt = 0.01

        for _ in range(1000):
            for i in range(nbodies):
                Self._move_from_i(self.bodies, i, dt)

    def checksum(self) -> UInt32:
        var v2 = Self._energy(self.bodies)
        return (Helper.checksum_f64(self.v1) << 5) & Helper.checksum_f64(v2)

    @staticmethod
    def _init_bodies() -> List[_Planet]:
        return [
            _Planet(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0),
            _Planet(
                4.84143144246472090e00,
                -1.16032004402742839e00,
                -1.03622044471123109e-01,
                1.66007664274403694e-03,
                7.69901118419740425e-03,
                -6.90460016972063023e-05,
                9.54791938424326609e-04,
            ),
            _Planet(
                8.34336671824457987e00,
                4.12479856412430479e00,
                -4.03523417114321381e-01,
                -2.76742510726862411e-03,
                4.99852801234917238e-03,
                2.30417297573763929e-05,
                2.85885980666130812e-04,
            ),
            _Planet(
                1.28943695621391310e01,
                -1.51111514016986312e01,
                -2.23307578892655734e-01,
                2.96460137564761618e-03,
                2.37847173959480950e-03,
                -2.96589568540237556e-05,
                4.36624404335156298e-05,
            ),
            _Planet(
                1.53796971148509165e01,
                -2.59193146099879641e01,
                1.79258772950371181e-01,
                2.68067772490389322e-03,
                1.62824170038242295e-03,
                -9.51592254519715870e-05,
                5.15138902046611451e-05,
            ),
        ]

    @staticmethod
    def _move_from_i(mut bodies: List[_Planet], idx: Int, dt: Float64):
        var b = bodies[idx]
        var i = idx + 1
        var nbodies = len(bodies)

        while i < nbodies:
            var b2 = bodies[i]
            var dx = b.x - b2.x
            var dy = b.y - b2.y
            var dz = b.z - b2.z

            var distance = sqrt(dx * dx + dy * dy + dz * dz)
            var mag = dt / (distance * distance * distance)
            var b_mass_mag = b.mass * mag
            var b2_mass_mag = b2.mass * mag

            b.vx -= dx * b2_mass_mag
            b.vy -= dy * b2_mass_mag
            b.vz -= dz * b2_mass_mag
            b2.vx += dx * b_mass_mag
            b2.vy += dy * b_mass_mag
            b2.vz += dz * b_mass_mag

            bodies[i] = b2
            i += 1

        b.x += dt * b.vx
        b.y += dt * b.vy
        b.z += dt * b.vz
        bodies[idx] = b

    @staticmethod
    def _energy(bodies: List[_Planet]) -> Float64:
        var e: Float64 = 0.0
        var nbodies = len(bodies)

        for i in range(nbodies):
            var b = bodies[i]
            e += 0.5 * b.mass * (b.vx * b.vx + b.vy * b.vy + b.vz * b.vz)
            for j in range(i + 1, nbodies):
                var b2 = bodies[j]
                var dx = b.x - b2.x
                var dy = b.y - b2.y
                var dz = b.z - b2.z
                var distance = sqrt(dx * dx + dy * dy + dz * dz)
                e -= (b.mass * b2.mass) / distance
        return e

    @staticmethod
    def _offset_momentum(mut bodies: List[_Planet]):
        var px: Float64 = 0.0
        var py: Float64 = 0.0
        var pz: Float64 = 0.0

        for i in range(len(bodies)):
            var b = bodies[i]
            px += b.vx * b.mass
            py += b.vy * b.mass
            pz += b.vz * b.mass

        var sun = bodies[0]
        sun.vx = -px / SOLAR_MASS
        sun.vy = -py / SOLAR_MASS
        sun.vz = -pz / SOLAR_MASS
        bodies[0] = sun
