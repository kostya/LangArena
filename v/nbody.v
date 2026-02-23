module nbody

import benchmark
import helper
import math

pub struct Nbody {
	benchmark.BaseBenchmark
mut:
	result_val u32
	v1         f64
	bodies     []&Planet
}

struct Planet {
mut:
	x    f64
	y    f64
	z    f64
	vx   f64
	vy   f64
	vz   f64
	mass f64
}

const solar_mass = 4.0 * math.pi * math.pi
const days_per_year = 365.24

pub fn new_nbody() &benchmark.IBenchmark {
	mut bench := &Nbody{
		BaseBenchmark: benchmark.new_base_benchmark('CLBG::Nbody')
		result_val:    0
		v1:            0.0
	}
	bench.initialize_bodies()
	return bench
}

pub fn (b Nbody) name() string {
	return 'CLBG::Nbody'
}

fn new_planet(x f64, y f64, z f64, vx f64, vy f64, vz f64, mass f64) &Planet {
	return &Planet{
		x:    x
		y:    y
		z:    z
		vx:   vx * days_per_year
		vy:   vy * days_per_year
		vz:   vz * days_per_year
		mass: mass * solar_mass
	}
}

fn (mut b Nbody) initialize_bodies() {
	b.bodies = [
		new_planet(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0),
		new_planet(4.84143144246472090e+00, -1.16032004402742839e+00, -1.03622044471123109e-01,
			1.66007664274403694e-03, 7.69901118419740425e-03, -6.90460016972063023e-05,
			9.54791938424326609e-04),
		new_planet(8.34336671824457987e+00, 4.12479856412430479e+00, -4.03523417114321381e-01,
			-2.76742510726862411e-03, 4.99852801234917238e-03, 2.30417297573763929e-05,
			2.85885980666130812e-04),
		new_planet(1.28943695621391310e+01, -1.51111514016986312e+01, -2.23307578892655734e-01,
			2.96460137564761618e-03, 2.37847173959480950e-03, -2.96589568540237556e-05,
			4.36624404335156298e-05),
		new_planet(1.53796971148509165e+01, -2.59193146099879641e+01, 1.79258772950371181e-01,
			2.68067772490389322e-03, 1.62824170038242295e-03, -9.51592254519715870e-05,
			5.15138902046611451e-05),
	]
}

fn (mut p Planet) move_from_i(mut bodies []&Planet, nbodies int, dt f64, start int) {
	for mut b2 in bodies[start..nbodies] {
		dx := p.x - b2.x
		dy := p.y - b2.y
		dz := p.z - b2.z

		distance := math.sqrt(dx * dx + dy * dy + dz * dz)
		mag := dt / (distance * distance * distance)
		b_mass_mag := p.mass * mag
		b2_mass_mag := b2.mass * mag

		p.vx -= dx * b2_mass_mag
		p.vy -= dy * b2_mass_mag
		p.vz -= dz * b2_mass_mag
		b2.vx += dx * b_mass_mag
		b2.vy += dy * b_mass_mag
		b2.vz += dz * b_mass_mag
	}

	p.x += dt * p.vx
	p.y += dt * p.vy
	p.z += dt * p.vz
}

fn (b Nbody) energy() f64 {
	mut e := 0.0
	nbodies := b.bodies.len

	for i in 0 .. nbodies {
		planet_i := b.bodies[i]
		e += 0.5 * planet_i.mass * (planet_i.vx * planet_i.vx + planet_i.vy * planet_i.vy +
			planet_i.vz * planet_i.vz)

		for j in i + 1 .. nbodies {
			planet_j := b.bodies[j]
			dx := planet_i.x - planet_j.x
			dy := planet_i.y - planet_j.y
			dz := planet_i.z - planet_j.z
			distance := math.sqrt(dx * dx + dy * dy + dz * dz)
			e -= (planet_i.mass * planet_j.mass) / distance
		}
	}
	return e
}

fn (mut b Nbody) offset_momentum() {
	mut px := 0.0
	mut py := 0.0
	mut pz := 0.0

	for i in 0 .. b.bodies.len {
		planet := b.bodies[i]
		px += planet.vx * planet.mass
		py += planet.vy * planet.mass
		pz += planet.vz * planet.mass
	}

	mut sun := b.bodies[0]
	sun.vx = -px / solar_mass
	sun.vy = -py / solar_mass
	sun.vz = -pz / solar_mass
}

pub fn (mut b Nbody) prepare() {
	b.offset_momentum()
	b.v1 = b.energy()
}

pub fn (mut b Nbody) run(iteration_id int) {
	dt := 0.01

	mut j := 0
	for j < 1000 {
		for i, mut planet in b.bodies {
			planet.move_from_i(mut b.bodies, b.bodies.len, dt, i + 1)
		}
		j++
	}
}

pub fn (b Nbody) checksum() u32 {
	v2 := b.energy()
	hash1 := helper.checksum_f64(b.v1)
	hash2 := helper.checksum_f64(v2)
	return (hash1 << 5) & hash2
}
