import std/[math]
import ../benchmark
import ../helper

type
  Planet = object
    x, y, z: float
    vx, vy, vz: float
    mass: float

  Nbody* = ref object of Benchmark
    resultVal: uint32
    bodies: seq[Planet]
    v1: float

const
  SOLAR_MASS = 4.0 * PI * PI
  DAYS_PER_YEAR = 365.24

proc newPlanet(x, y, z, vx, vy, vz, mass: float): Planet =
  Planet(
    x: x, y: y, z: z,
    vx: vx * DAYS_PER_YEAR,
    vy: vy * DAYS_PER_YEAR,
    vz: vz * DAYS_PER_YEAR,
    mass: mass * SOLAR_MASS
  )

proc moveFromI(bodies: var seq[Planet], dt: float, start: int) =
  let b = bodies[start]
  for i in start+1..<bodies.len:
    let b2 = bodies[i]
    let dx = b.x - b2.x
    let dy = b.y - b2.y
    let dz = b.z - b2.z

    let distance = sqrt(dx*dx + dy*dy + dz*dz)
    let mag = dt / (distance * distance * distance)
    let bMassMag = b.mass * mag
    let b2MassMag = b2.mass * mag

    bodies[start].vx -= dx * b2MassMag
    bodies[start].vy -= dy * b2MassMag
    bodies[start].vz -= dz * b2MassMag
    bodies[i].vx += dx * bMassMag
    bodies[i].vy += dy * bMassMag
    bodies[i].vz += dz * bMassMag

  bodies[start].x += dt * bodies[start].vx
  bodies[start].y += dt * bodies[start].vy
  bodies[start].z += dt * bodies[start].vz

proc newNbody(): Benchmark =
  Nbody(resultVal: 0, v1: 0.0)

method name(self: Nbody): string = "CLBG::Nbody"

method prepare(self: Nbody) =

  self.bodies = @[
    newPlanet(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0),
    newPlanet(4.84143144246472090e+00, -1.16032004402742839e+00, -1.03622044471123109e-01,
              1.66007664274403694e-03, 7.69901118419740425e-03,
              -6.90460016972063023e-05,
              9.54791938424326609e-04),
    newPlanet(8.34336671824457987e+00, 4.12479856412430479e+00, -4.03523417114321381e-01,
              -2.76742510726862411e-03, 4.99852801234917238e-03,
              2.30417297573763929e-05,
              2.85885980666130812e-04),
    newPlanet(1.28943695621391310e+01, -1.51111514016986312e+01, -2.23307578892655734e-01,
              2.96460137564761618e-03, 2.37847173959480950e-03,
              -2.96589568540237556e-05,
              4.36624404335156298e-05),
    newPlanet(1.53796971148509165e+01, -2.59193146099879641e+01, 1.79258772950371181e-01,
              2.68067772490389322e-03, 1.62824170038242295e-03,
              -9.51592254519715870e-05,
              5.15138902046611451e-05)
  ]

  var px, py, pz = 0.0
  for b in self.bodies:
    px += b.vx * b.mass
    py += b.vy * b.mass
    pz += b.vz * b.mass

  self.bodies[0].vx = -px / SOLAR_MASS
  self.bodies[0].vy = -py / SOLAR_MASS
  self.bodies[0].vz = -pz / SOLAR_MASS

  var e = 0.0
  let nbodies = self.bodies.len
  for i in 0..<nbodies:
    let b = self.bodies[i]
    e += 0.5 * b.mass * (b.vx*b.vx + b.vy*b.vy + b.vz*b.vz)
    for j in i+1..<nbodies:
      let b2 = self.bodies[j]
      let dx = b.x - b2.x
      let dy = b.y - b2.y
      let dz = b.z - b2.z
      let distance = sqrt(dx*dx + dy*dy + dz*dz)
      e -= (b.mass * b2.mass) / distance

  self.v1 = e

method run(self: Nbody, iteration_id: int) =
  for j in 0..<1000:
    for i in 0..<self.bodies.len:
      self.bodies.moveFromI(0.01, i)

method checksum(self: Nbody): uint32 =

  var e = 0.0
  let nbodies = self.bodies.len
  for i in 0..<nbodies:
    let b = self.bodies[i]
    e += 0.5 * b.mass * (b.vx*b.vx + b.vy*b.vy + b.vz*b.vz)
    for j in i+1..<nbodies:
      let b2 = self.bodies[j]
      let dx = b.x - b2.x
      let dy = b.y - b2.y
      let dz = b.z - b2.z
      let distance = sqrt(dx*dx + dy*dy + dz*dz)
      e -= (b.mass * b2.mass) / distance

  let v2 = e
  let checksum1 = checksumF64(self.v1)
  let checksum2 = checksumF64(v2)
  (checksum1 shl 5) and checksum2

registerBenchmark("CLBG::Nbody", newNbody)
