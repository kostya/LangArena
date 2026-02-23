const std = @import("std");
const Benchmark = @import("benchmark.zig").Benchmark;
const Helper = @import("helper.zig").Helper;

pub const Nbody = struct {
    allocator: std.mem.Allocator,
    helper: *Helper,
    bodies: [5]Planet,
    v1: f64,
    result_val: u32,

    const SOLAR_MASS: f64 = 4.0 * std.math.pi * std.math.pi;
    const DAYS_PER_YEAR: f64 = 365.24;

    const Planet = struct {
        x: f64,
        y: f64,
        z: f64,
        vx: f64,
        vy: f64,
        vz: f64,
        mass: f64,

        fn init(x: f64, y: f64, z: f64, vx: f64, vy: f64, vz: f64, mass: f64) Planet {
            return Planet{
                .x = x,
                .y = y,
                .z = z,
                .vx = vx * DAYS_PER_YEAR,
                .vy = vy * DAYS_PER_YEAR,
                .vz = vz * DAYS_PER_YEAR,
                .mass = mass * SOLAR_MASS,
            };
        }

        fn moveFromI(self: *Planet, bodies: []Planet, nbodies: usize, dt: f64, start: usize) void {
            var i = start;
            while (i < nbodies) : (i += 1) {
                var b2 = &bodies[i];
                const dx = self.x - b2.x;
                const dy = self.y - b2.y;
                const dz = self.z - b2.z;

                const distance = @sqrt(dx * dx + dy * dy + dz * dz);
                const mag = dt / (distance * distance * distance);
                const b_mass_mag = self.mass * mag;
                const b2_mass_mag = b2.mass * mag;

                self.vx -= dx * b2_mass_mag;
                self.vy -= dy * b2_mass_mag;
                self.vz -= dz * b2_mass_mag;
                b2.vx += dx * b_mass_mag;
                b2.vy += dy * b_mass_mag;
                b2.vz += dz * b_mass_mag;
            }

            self.x += dt * self.vx;
            self.y += dt * self.vy;
            self.z += dt * self.vz;
        }
    };

    const vtable = Benchmark.VTable{
        .run = runImpl,
        .checksum = resultImpl,
        .deinit = deinitImpl,
        .prepare = prepareImpl,
    };

    pub fn init(allocator: std.mem.Allocator, helper: *Helper) !*Nbody {
        const self = try allocator.create(Nbody);
        errdefer allocator.destroy(self);

        var bodies: [5]Planet = undefined;
        bodies[0] = Planet.init(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0);
        bodies[1] = Planet.init(4.84143144246472090e+00, -1.16032004402742839e+00, -1.03622044471123109e-01, 1.66007664274403694e-03, 7.69901118419740425e-03, -6.90460016972063023e-05, 9.54791938424326609e-04);
        bodies[2] = Planet.init(8.34336671824457987e+00, 4.12479856412430479e+00, -4.03523417114321381e-01, -2.76742510726862411e-03, 4.99852801234917238e-03, 2.30417297573763929e-05, 2.85885980666130812e-04);
        bodies[3] = Planet.init(1.28943695621391310e+01, -1.51111514016986312e+01, -2.23307578892655734e-01, 2.96460137564761618e-03, 2.37847173959480950e-03, -2.96589568540237556e-05, 4.36624404335156298e-05);
        bodies[4] = Planet.init(1.53796971148509165e+01, -2.59193146099879641e+01, 1.79258772950371181e-01, 2.68067772490389322e-03, 1.62824170038242295e-03, -9.51592254519715870e-05, 5.15138902046611451e-05);

        self.* = Nbody{
            .allocator = allocator,
            .helper = helper,
            .bodies = bodies,
            .v1 = 0.0,
            .result_val = 0,
        };

        return self;
    }

    pub fn deinit(self: *Nbody) void {
        self.allocator.destroy(self);
    }

    pub fn asBenchmark(self: *Nbody) Benchmark {
        return Benchmark.init(self, &vtable, self.helper, "CLBG::Nbody");
    }

    fn energy(bodies: []const Planet) f64 {
        var e: f64 = 0.0;
        const nbodies = bodies.len;

        for (0..nbodies) |i| {
            const b = bodies[i];
            e += 0.5 * b.mass * (b.vx * b.vx + b.vy * b.vy + b.vz * b.vz);

            var j = i + 1;
            while (j < nbodies) : (j += 1) {
                const b2 = bodies[j];
                const dx = b.x - b2.x;
                const dy = b.y - b2.y;
                const dz = b.z - b2.z;
                const distance = @sqrt(dx * dx + dy * dy + dz * dz);
                e -= (b.mass * b2.mass) / distance;
            }
        }
        return e;
    }

    fn offsetMomentum(bodies: []Planet) void {
        var px: f64 = 0.0;
        var py: f64 = 0.0;
        var pz: f64 = 0.0;

        for (bodies) |*b| {
            px += b.vx * b.mass;
            py += b.vy * b.mass;
            pz += b.vz * b.mass;
        }

        var sun = &bodies[0];
        sun.vx = -px / SOLAR_MASS;
        sun.vy = -py / SOLAR_MASS;
        sun.vz = -pz / SOLAR_MASS;
    }

    fn prepareImpl(ptr: *anyopaque) void {
        const self: *Nbody = @ptrCast(@alignCast(ptr));
        offsetMomentum(&self.bodies);
        self.v1 = energy(&self.bodies);
    }

    fn runImpl(ptr: *anyopaque, iteration_id: i64) void {
        _ = iteration_id;
        const self: *Nbody = @ptrCast(@alignCast(ptr));

        const nbodies = self.bodies.len;
        const dt: f64 = 0.01;

        var n: usize = 0;
        while (n < 1000) {
            var i: usize = 0;
            while (i < nbodies) : (i += 1) {
                self.bodies[i].moveFromI(&self.bodies, nbodies, dt, i + 1);
            }
            n += 1;
        }
    }

    fn resultImpl(ptr: *anyopaque) u32 {
        const self: *Nbody = @ptrCast(@alignCast(ptr));
        const v2 = energy(&self.bodies);
        const checksum1 = self.helper.checksumFloat(self.v1);
        const checksum2 = self.helper.checksumFloat(v2);
        return (checksum1 << 5) & checksum2;
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *Nbody = @ptrCast(@alignCast(ptr));
        self.deinit();
    }
};
