using System.Text;

public class Nbody : Benchmark
{
    private const double SOLAR_MASS = 4 * Math.PI * Math.PI;
    private const double DAYS_PER_YEAR = 365.24;

    private uint _result;
    private double _v1;
    private Planet[] _bodies;

    private class PlanetData
    {
        public double X, Y, Z, Vx, Vy, Vz, Mass;

        public PlanetData(double x, double y, double z, double vx, double vy, double vz, double mass)
        {
            X = x; Y = y; Z = z;
            Vx = vx; Vy = vy; Vz = vz;
            Mass = mass;
        }
    }

    private static readonly PlanetData[] PLANET_DATA = new PlanetData[]
    {
        new PlanetData(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0),
        new PlanetData(4.84143144246472090e+00, -1.16032004402742839e+00, -1.03622044471123109e-01, 1.66007664274403694e-03, 7.69901118419740425e-03, -6.90460016972063023e-05, 9.54791938424326609e-04),
        new PlanetData(8.34336671824457987e+00, 4.12479856412430479e+00, -4.03523417114321381e-01, -2.76742510726862411e-03, 4.99852801234917238e-03, 2.30417297573763929e-05, 2.85885980666130812e-04),
        new PlanetData(1.28943695621391310e+01, -1.51111514016986312e+01, -2.23307578892655734e-01, 2.96460137564761618e-03, 2.37847173959480950e-03, -2.96589568540237556e-05, 4.36624404335156298e-05),
        new PlanetData(1.53796971148509165e+01, -2.59193146099879641e+01, 1.79258772950371181e-01, 2.68067772490389322e-03, 1.62824170038242295e-03, -9.51592254519715870e-05, 5.15138902046611451e-05),
    };

    private class Planet
    {
        public double X, Y, Z;
        public double Vx, Vy, Vz;
        public double Mass;

        public Planet(double x, double y, double z, double vx, double vy, double vz, double mass)
        {
            X = x;
            Y = y;
            Z = z;
            Vx = vx * DAYS_PER_YEAR;
            Vy = vy * DAYS_PER_YEAR;
            Vz = vz * DAYS_PER_YEAR;
            Mass = mass * SOLAR_MASS;
        }

        public void MoveFromI(Planet[] bodies, int nbodies, double dt, int i)
        {
            while (i < nbodies)
            {
                Planet b2 = bodies[i];
                double dx = X - b2.X;
                double dy = Y - b2.Y;
                double dz = Z - b2.Z;

                double distance = Math.Sqrt(dx * dx + dy * dy + dz * dz);
                double mag = dt / (distance * distance * distance);
                double b_mass_mag = Mass * mag;
                double b2_mass_mag = b2.Mass * mag;

                Vx -= dx * b2_mass_mag;
                Vy -= dy * b2_mass_mag;
                Vz -= dz * b2_mass_mag;

                b2.Vx += dx * b_mass_mag;
                b2.Vy += dy * b_mass_mag;
                b2.Vz += dz * b_mass_mag;

                i++;
            }

            X += dt * Vx;
            Y += dt * Vy;
            Z += dt * Vz;
        }
    }

    public Nbody()
    {
        _bodies = new Planet[PLANET_DATA.Length];
        for (int i = 0; i < PLANET_DATA.Length; i++)
        {
            var data = PLANET_DATA[i];
            _bodies[i] = new Planet(data.X, data.Y, data.Z, data.Vx, data.Vy, data.Vz, data.Mass);
        }
        OffsetMomentum();
        _v1 = Energy();
    }

    private double Energy()
    {
        double e = 0.0;
        int nbodies = _bodies.Length;

        for (int i = 0; i < nbodies; i++)
        {
            Planet b = _bodies[i];
            e += 0.5 * b.Mass * (b.Vx * b.Vx + b.Vy * b.Vy + b.Vz * b.Vz);

            for (int j = i + 1; j < nbodies; j++)
            {
                Planet b2 = _bodies[j];
                double dx = b.X - b2.X;
                double dy = b.Y - b2.Y;
                double dz = b.Z - b2.Z;
                double distance = Math.Sqrt(dx * dx + dy * dy + dz * dz);
                e -= (b.Mass * b2.Mass) / distance;
            }
        }

        return e;
    }

    private void OffsetMomentum()
    {
        double px = 0.0, py = 0.0, pz = 0.0;

        foreach (var b in _bodies)
        {
            px += b.Vx * b.Mass;
            py += b.Vy * b.Mass;
            pz += b.Vz * b.Mass;
        }

        Planet b0 = _bodies[0];
        b0.Vx = -px / SOLAR_MASS;
        b0.Vy = -py / SOLAR_MASS;
        b0.Vz = -pz / SOLAR_MASS;
    }

    public override void Run(long IterationId)
    {
        int nbodies = _bodies.Length;
        double dt = 0.01;

        int i = 0;
        while (i < nbodies)
        {
            _bodies[i].MoveFromI(_bodies, nbodies, dt, i + 1);
            i++;
        }
    }

    public override uint Checksum
    {
        get
        {
            double v2 = Energy();
            return (Helper.Checksum(_v1) << 5) & Helper.Checksum(v2);
        }
    }
}