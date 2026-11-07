module nbody;

import benchmark;
import helper;
import std::io;
import std::math;

const M_PI          = 3.14159265358979323846;
const SOLAR_MASS    = 4 * M_PI * M_PI;
const DAYS_PER_YEAR = 365.24;

struct NbodyPlanet
{
	double x, y, z;
	double vx, vy, vz;
	double mass;
}

struct NbodyData
{
	long iterations;
	NbodyPlanet* bodies;
	long nbodies;
	double energy_before;
}

fn void nbody_planet_init(NbodyPlanet* p, double x, double y, double z, double vx, double vy, double vz, double mass)
{
	p.x = x;
	p.y = y;
	p.z = z;
	p.vx = vx * DAYS_PER_YEAR;
	p.vy = vy * DAYS_PER_YEAR;
	p.vz = vz * DAYS_PER_YEAR;
	p.mass = mass * SOLAR_MASS;
}

fn double nbody_energy(NbodyPlanet* bodies, long nbodies)
{
	double e = 0.0;

	for (long i = 0; i < nbodies; i++)
	{
		NbodyPlanet* b = &bodies[i];
		e += 0.5 * b.mass * (b.vx * b.vx + b.vy * b.vy + b.vz * b.vz);

		for (long j = i + 1; j < nbodies; j++)
		{
			NbodyPlanet* b2 = &bodies[j];
			double dx       = b.x - b2.x;
			double dy       = b.y - b2.y;
			double dz       = b.z - b2.z;
			double distance = math::sqrt(dx * dx + dy * dy + dz * dz);
			e -= (b.mass * b2.mass) / distance;
		}
	}
	return e;
}

fn void nbody_offset_momentum(NbodyPlanet* bodies, long nbodies)
{
	double px = 0.0;
	double py = 0.0;
	double pz = 0.0;

	for (long i = 0; i < nbodies; i++)
	{
		NbodyPlanet* b = &bodies[i];
		px += b.vx * b.mass;
		py += b.vy * b.mass;
		pz += b.vz * b.mass;
	}

	NbodyPlanet* b = &bodies[0];
	b.vx = -px / SOLAR_MASS;
	b.vy = -py / SOLAR_MASS;
	b.vz = -pz / SOLAR_MASS;
}

fn void nbody_planet_move_from_i(NbodyPlanet* bodies, long nbodies, double dt, long start)
{
	NbodyPlanet* b1 = &bodies[start - 1];

	for (long j = start; j < nbodies; j++)
	{
		NbodyPlanet* b2 = &bodies[j];
		double dx       = b1.x - b2.x;
		double dy       = b1.y - b2.y;
		double dz       = b1.z - b2.z;

		double distance_sq = dx * dx + dy * dy + dz * dz;
		double distance    = math::sqrt(distance_sq);
		double mag         = dt / (distance * distance * distance);
		double b1_mass_mag = b1.mass * mag;
		double b2_mass_mag = b2.mass * mag;

		b1.vx -= dx * b2_mass_mag;
		b1.vy -= dy * b2_mass_mag;
		b1.vz -= dz * b2_mass_mag;
		b2.vx += dx * b1_mass_mag;
		b2.vy += dy * b1_mass_mag;
		b2.vz += dz * b1_mass_mag;
	}

	b1.x += dt * b1.vx;
	b1.y += dt * b1.vy;
	b1.z += dt * b1.vz;
}

fn void nbody_prepare(Benchmark* self)
{
	NbodyData* data = (NbodyData*)self.data;

	if (!data.bodies)
	{
		data.nbodies = 5;
		data.bodies = mem::new_array(NbodyPlanet, (usz)data.nbodies);

		nbody_planet_init(&data.bodies[0], 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0);

		nbody_planet_init(
			&data.bodies[1],
			4.84143144246472090e+00,
			-1.16032004402742839e+00,
			-1.03622044471123109e-01,
			1.66007664274403694e-03,
			7.69901118419740425e-03,
			-6.90460016972063023e-05,
			9.54791938424326609e-04
		);

		nbody_planet_init(
			&data.bodies[2],
			8.34336671824457987e+00,
			4.12479856412430479e+00,
			-4.03523417114321381e-01,
			-2.76742510726862411e-03,
			4.99852801234917238e-03,
			2.30417297573763929e-05,
			2.85885980666130812e-04
		);

		nbody_planet_init(
			&data.bodies[3],
			1.28943695621391310e+01,
			-1.51111514016986312e+01,
			-2.23307578892655734e-01,
			2.96460137564761618e-03,
			2.37847173959480950e-03,
			-2.96589568540237556e-05,
			4.36624404335156298e-05
		);

		nbody_planet_init(
			&data.bodies[4],
			1.53796971148509165e+01,
			-2.59193146099879641e+01,
			1.79258772950371181e-01,
			2.68067772490389322e-03,
			1.62824170038242295e-03,
			-9.51592254519715870e-05,
			5.15138902046611451e-05
		);
	}

	nbody_offset_momentum(data.bodies, data.nbodies);
	data.energy_before = nbody_energy(data.bodies, data.nbodies);
}

fn void nbody_run(Benchmark* self, int iteration_id)
{
	NbodyData* data = (NbodyData*)self.data;

	double dt   = 0.01;
	int nbodies = (int)data.nbodies;

	for (int n = 0; n < 1000; n++)
	{
		for (int i = 0; i < nbodies; i++)
		{
			nbody_planet_move_from_i(data.bodies, data.nbodies, dt, (long)(i + 1));
		}
	}
}

fn uint nbody_checksum(Benchmark* self)
{
	NbodyData* data = (NbodyData*)self.data;

	double energy_after = nbody_energy(data.bodies, data.nbodies);

	uint checksum_before = helper::helper_checksum_f64(data.energy_before);
	uint checksum_after  = helper::helper_checksum_f64(energy_after);

	return (uint)(((long)checksum_before << 5) & (long)checksum_after);
}

fn void nbody_cleanup(Benchmark* self)
{
	NbodyData* data = (NbodyData*)self.data;
	if (data)
	{
		free(data.bodies);
		data.bodies = null;
	}
}

fn Benchmark* nbody_create() @cname("Nbody_create") @export
{
	Benchmark* bench = benchmark::benchmark_create("CLBG::Nbody");

	NbodyData* data = mem::new(NbodyData);

	bench.data = data;
	bench.prepare = (PrepareFn)&nbody_prepare;
	bench.run = (RunFn)&nbody_run;
	bench.checksum = (ChecksumFn)&nbody_checksum;
	bench.cleanup = (CleanupFn)&nbody_cleanup;

	return bench;
}