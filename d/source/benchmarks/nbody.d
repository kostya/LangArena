module benchmarks.nbody;

import std.stdio;
import std.string;
import std.conv;
import std.array;
import std.algorithm;
import std.math;
import benchmark;
import helper;

class Nbody : Benchmark {
private:
    enum SOLAR_MASS = 4 * PI * PI;
    enum DAYS_PER_YEAR = 365.24;

    static struct Planet {
        double x, y, z;
        double vx, vy, vz;
        double mass;

        this(double x, double y, double z, double vx, double vy, double vz, double mass) {
            this.x = x;
            this.y = y;
            this.z = z;
            this.vx = vx * DAYS_PER_YEAR;
            this.vy = vy * DAYS_PER_YEAR;
            this.vz = vz * DAYS_PER_YEAR;
            this.mass = mass * SOLAR_MASS;
        }

        void moveFromI(ref Planet[] bodies, int nbodies, double dt, int start) {
            for (int i = start; i < nbodies; i++) {
                auto b2 = &bodies[i];
                double dx = x - b2.x;
                double dy = y - b2.y;
                double dz = z - b2.z;

                double distance = sqrt(dx * dx + dy * dy + dz * dz);
                double mag = dt / (distance * distance * distance);
                double b_mass_mag = mass * mag;
                double b2_mass_mag = b2.mass * mag;

                vx -= dx * b2_mass_mag;
                vy -= dy * b2_mass_mag;
                vz -= dz * b2_mass_mag;
                b2.vx += dx * b_mass_mag;
                b2.vy += dy * b_mass_mag;
                b2.vz += dz * b_mass_mag;
            }

            x += dt * vx;
            y += dt * vy;
            z += dt * vz;
        }
    }

    uint resultVal;
    Planet[] bodies;
    double v1;

    double energy() {
        double e = 0.0;
        int nbodies = cast(int)bodies.length;

        for (int i = 0; i < nbodies; i++) {
            auto b = &bodies[i];
            e += 0.5 * b.mass * (b.vx * b.vx + b.vy * b.vy + b.vz * b.vz);
            for (int j = i + 1; j < nbodies; j++) {
                auto b2 = &bodies[j];
                double dx = b.x - b2.x;
                double dy = b.y - b2.y;
                double dz = b.z - b2.z;
                double distance = sqrt(dx * dx + dy * dy + dz * dz);
                e -= (b.mass * b2.mass) / distance;
            }
        }
        return e;
    }

    void offsetMomentum() {
        double px = 0.0, py = 0.0, pz = 0.0;

        foreach (ref b; bodies) {
            px += b.vx * b.mass;
            py += b.vy * b.mass;
            pz += b.vz * b.mass;
        }

        auto b = &bodies[0];
        b.vx = -px / SOLAR_MASS;
        b.vy = -py / SOLAR_MASS;
        b.vz = -pz / SOLAR_MASS;
    }

protected:
    override string className() const { return "Nbody"; }

public:
    this() {
        resultVal = 0;
        v1 = 0.0;

        bodies = [
            Planet(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0),
            Planet(4.84143144246472090e+00, -1.16032004402742839e+00, -1.03622044471123109e-01,
                   1.66007664274403694e-03, 7.69901118419740425e-03, -6.90460016972063023e-05,
                   9.54791938424326609e-04),
            Planet(8.34336671824457987e+00, 4.12479856412430479e+00, -4.03523417114321381e-01,
                   -2.76742510726862411e-03, 4.99852801234917238e-03, 2.30417297573763929e-05,
                   2.85885980666130812e-04),
            Planet(1.28943695621391310e+01, -1.51111514016986312e+01, -2.23307578892655734e-01,
                   2.96460137564761618e-03, 2.37847173959480950e-03, -2.96589568540237556e-05,
                   4.36624404335156298e-05),
            Planet(1.53796971148509165e+01, -2.59193146099879641e+01, 1.79258772950371181e-01,
                   2.68067772490389322e-03, 1.62824170038242295e-03, -9.51592254519715870e-05,
                   5.15138902046611451e-05)
        ];
    }

    override void prepare() {
        offsetMomentum();
        v1 = energy();
    }

    override void run(int iterationId) {
        int nbodies = cast(int)bodies.length;
        double dt = 0.01;

        for (int i = 0; i < nbodies; i++) {
            auto b = &bodies[i];
            b.moveFromI(bodies, nbodies, dt, i + 1);
        }
    }

    override uint checksum() {
        double v2 = energy();
        return (Helper.checksumF64(v1) << 5) & Helper.checksumF64(v2);
    }
}