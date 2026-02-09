package benchmark

import "core:math"

SOLAR_MASS :: 4.0 * math.PI * math.PI
DAYS_PER_YEAR :: 365.24

Planet :: struct {
    x, y, z: f64,
    vx, vy, vz: f64,
    mass: f64,
}

create_planet :: proc(x, y, z, vx, vy, vz, mass: f64) -> Planet {
    return Planet{
        x = x,
        y = y,
        z = z,
        vx = vx * DAYS_PER_YEAR,
        vy = vy * DAYS_PER_YEAR,
        vz = vz * DAYS_PER_YEAR,
        mass = mass * SOLAR_MASS,
    }
}

move_from_i :: proc(b: ^Planet, bodies: []Planet, dt: f64, start: int) {
    for i in start..<len(bodies) {
        b2 := &bodies[i]

        dx := b.x - b2.x
        dy := b.y - b2.y
        dz := b.z - b2.z

        distance := math.sqrt(dx * dx + dy * dy + dz * dz)
        mag := dt / (distance * distance * distance)
        b_mass_mag := b.mass * mag
        b2_mass_mag := b2.mass * mag

        b.vx -= dx * b2_mass_mag
        b.vy -= dy * b2_mass_mag
        b.vz -= dz * b2_mass_mag
        b2.vx += dx * b_mass_mag
        b2.vy += dy * b_mass_mag
        b2.vz += dz * b_mass_mag
    }

    b.x += dt * b.vx
    b.y += dt * b.vy
    b.z += dt * b.vz
}

energy :: proc(bodies: []Planet) -> f64 {
    e: f64 = 0.0
    nbodies := len(bodies)

    for i in 0..<nbodies {
        b := &bodies[i]
        e += 0.5 * b.mass * (b.vx * b.vx + b.vy * b.vy + b.vz * b.vz)

        for j in i + 1..<nbodies {
            b2 := &bodies[j]
            dx := b.x - b2.x
            dy := b.y - b2.y
            dz := b.z - b2.z
            distance := math.sqrt(dx * dx + dy * dy + dz * dz)
            e -= (b.mass * b2.mass) / distance
        }
    }
    return e
}

offset_momentum :: proc(bodies: []Planet) {
    px, py, pz: f64 = 0.0, 0.0, 0.0

    for b in bodies {
        px += b.vx * b.mass
        py += b.vy * b.mass
        pz += b.vz * b.mass
    }

    b := &bodies[0]
    b.vx = -px / SOLAR_MASS
    b.vy = -py / SOLAR_MASS
    b.vz = -pz / SOLAR_MASS
}

Nbody :: struct {
    using base: Benchmark,
    bodies: [5]Planet,  
    v1: f64,
    result_val: u32,
}

nbody_prepare :: proc(bench: ^Benchmark) {
    nb := cast(^Nbody)bench

    nb.bodies = [5]Planet{
        create_planet(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0),
        create_planet(4.84143144246472090e+00, -1.16032004402742839e+00, -1.03622044471123109e-01,
                      1.66007664274403694e-03, 7.69901118419740425e-03, -6.90460016972063023e-05,
                      9.54791938424326609e-04),
        create_planet(8.34336671824457987e+00, 4.12479856412430479e+00, -4.03523417114321381e-01,
                      -2.76742510726862411e-03, 4.99852801234917238e-03, 2.30417297573763929e-05,
                      2.85885980666130812e-04),
        create_planet(1.28943695621391310e+01, -1.51111514016986312e+01, -2.23307578892655734e-01,
                      2.96460137564761618e-03, 2.37847173959480950e-03, -2.96589568540237556e-05,
                      4.36624404335156298e-05),
        create_planet(1.53796971148509165e+01, -2.59193146099879641e+01, 1.79258772950371181e-01,
                      2.68067772490389322e-03, 1.62824170038242295e-03, -9.51592254519715870e-05,
                      5.15138902046611451e-05),
    }

    offset_momentum(nb.bodies[:])
    nb.v1 = energy(nb.bodies[:])
}

nbody_run :: proc(bench: ^Benchmark, iteration_id: int) {
    nb := cast(^Nbody)bench
    dt: f64 = 0.01

    i := 0
    nbodies := len(nb.bodies)

    for i < nbodies {
        b := &nb.bodies[i]
        move_from_i(b, nb.bodies[:], dt, i + 1)
        i += 1
    }
}

nbody_checksum :: proc(bench: ^Benchmark) -> u32 {
    nb := cast(^Nbody)bench

    v2 := energy(nb.bodies[:])

    hash1 := checksum_f64(nb.v1)
    hash2 := checksum_f64(v2)

    return (hash1 << 5) & hash2
}

create_nbody :: proc() -> ^Benchmark {
    nb := new(Nbody)
    nb.name = "Nbody"
    nb.vtable = default_vtable()

    nb.vtable.run = nbody_run
    nb.vtable.checksum = nbody_checksum
    nb.vtable.prepare = nbody_prepare

    return cast(^Benchmark)nb
}