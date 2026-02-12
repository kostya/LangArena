use super::super::{Benchmark, helper};

const SOLAR_MASS: f64 = 4.0 * std::f64::consts::PI * std::f64::consts::PI;
const DAYS_PER_YEAR: f64 = 365.24;

#[derive(Clone)]
struct Planet {
    x: f64,
    y: f64,
    z: f64,
    vx: f64,
    vy: f64,
    vz: f64,
    mass: f64,
}

impl Planet {
    fn new(x: f64, y: f64, z: f64, vx: f64, vy: f64, vz: f64, mass: f64) -> Self {
        Self {
            x, y, z,
            vx: vx * DAYS_PER_YEAR,
            vy: vy * DAYS_PER_YEAR,
            vz: vz * DAYS_PER_YEAR,
            mass: mass * SOLAR_MASS,
        }
    }

    fn move_from_i(&mut self, bodies: &mut [Planet], nbodies: usize, dt: f64, i: usize) {
        let mut j = i;
        while j < nbodies {
            let b2 = &mut bodies[j];
            let dx = self.x - b2.x;
            let dy = self.y - b2.y;
            let dz = self.z - b2.z;

            let distance = (dx * dx + dy * dy + dz * dz).sqrt();
            let mag = dt / (distance * distance * distance);
            let b_mass_mag = self.mass * mag;
            let b2_mass_mag = b2.mass * mag;

            self.vx -= dx * b2_mass_mag;
            self.vy -= dy * b2_mass_mag;
            self.vz -= dz * b2_mass_mag;
            b2.vx += dx * b_mass_mag;
            b2.vy += dy * b_mass_mag;
            b2.vz += dz * b_mass_mag;
            j += 1;
        }

        self.x += dt * self.vx;
        self.y += dt * self.vy;
        self.z += dt * self.vz;
    }
}

fn energy(bodies: &[Planet]) -> f64 {
    let mut e = 0.0;
    let nbodies = bodies.len();

    for i in 0..nbodies {
        let b = &bodies[i];
        e += 0.5 * b.mass * (b.vx * b.vx + b.vy * b.vy + b.vz * b.vz);

        for j in i + 1..nbodies {
            let b2 = &bodies[j];
            let dx = b.x - b2.x;
            let dy = b.y - b2.y;
            let dz = b.z - b2.z;
            let distance = (dx * dx + dy * dy + dz * dz).sqrt();
            e -= (b.mass * b2.mass) / distance;
        }
    }
    e
}

fn offset_momentum(bodies: &mut [Planet]) {
    let mut px = 0.0;
    let mut py = 0.0;
    let mut pz = 0.0;

    for b in bodies.iter() {
        let m = b.mass;
        px += b.vx * m;
        py += b.vy * m;
        pz += b.vz * m;
    }

    if let Some(b) = bodies.first_mut() {
        b.vx = -px / SOLAR_MASS;
        b.vy = -py / SOLAR_MASS;
        b.vz = -pz / SOLAR_MASS;
    }
}

fn create_bodies() -> [Planet; 5] {
    [

        Planet::new(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0),

        Planet::new(
            4.84143144246472090e+00,
            -1.16032004402742839e+00,
            -1.03622044471123109e-01,
            1.66007664274403694e-03,
            7.69901118419740425e-03,
            -6.90460016972063023e-05,
            9.54791938424326609e-04,
        ),

        Planet::new(
            8.34336671824457987e+00,
            4.12479856412430479e+00,
            -4.03523417114321381e-01,
            -2.76742510726862411e-03,
            4.99852801234917238e-03,
            2.30417297573763929e-05,
            2.85885980666130812e-04,
        ),

        Planet::new(
            1.28943695621391310e+01,
            -1.51111514016986312e+01,
            -2.23307578892655734e-01,
            2.96460137564761618e-03,
            2.37847173959480950e-03,
            -2.96589568540237556e-05,
            4.36624404335156298e-05,
        ),

        Planet::new(
            1.53796971148509165e+01,
            -2.59193146099879641e+01,
            1.79258772950371181e-01,
            2.68067772490389322e-03,
            1.62824170038242295e-03,
            -9.51592254519715870e-05,
            5.15138902046611451e-05,
        ),
    ]
}

pub struct Nbody {
    bodies: [Planet; 5],
    v1: f64,
    result_val: u32,
}

impl Nbody {
    pub fn new() -> Self {
        Self {
            bodies: create_bodies(),
            v1: 0.0,
            result_val: 0,
        }
    }
}

impl Benchmark for Nbody {
    fn name(&self) -> String {
        "Nbody".to_string()
    }

    fn prepare(&mut self) {
        offset_momentum(&mut self.bodies);
        self.v1 = energy(&self.bodies);
    }

    fn run(&mut self, _iteration_id: i64) {
        let nbodies = self.bodies.len();
        let dt = 0.01;

        let mut i = 0;
        while i < nbodies {
            let mut b = self.bodies[i].clone();
            b.move_from_i(&mut self.bodies, nbodies, dt, i + 1);
            self.bodies[i] = b;
            i += 1;
        }
    }

    fn checksum(&self) -> u32 {
        let v2 = energy(&self.bodies);
        (helper::checksum_f64(self.v1) << 5) & helper::checksum_f64(v2)
    }
}