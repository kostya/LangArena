namespace Benchmarks

open System

module Constants =
    [<Literal>]
    let SOLAR_MASS = 4.0 * Math.PI * Math.PI

    [<Literal>]
    let DAYS_PER_YEAR = 365.24

open Constants

type Planet(x: double, y: double, z: double, vx: double, vy: double, vz: double, mass: double) =
    let mutable xPos = x
    let mutable yPos = y
    let mutable zPos = z
    let mutable vxVel = vx * DAYS_PER_YEAR
    let mutable vyVel = vy * DAYS_PER_YEAR
    let mutable vzVel = vz * DAYS_PER_YEAR
    let massVal = mass * SOLAR_MASS

    member _.X with get() = xPos and set(v) = xPos <- v
    member _.Y with get() = yPos and set(v) = yPos <- v
    member _.Z with get() = zPos and set(v) = zPos <- v
    member _.Vx with get() = vxVel and set(v) = vxVel <- v
    member _.Vy with get() = vyVel and set(v) = vyVel <- v
    member _.Vz with get() = vzVel and set(v) = vzVel <- v
    member _.Mass = massVal

    member this.MoveFromI(bodies: Planet[], dt: double, i: int) =
        let mutable idx = i
        while idx < bodies.Length do
            let b2 = bodies.[idx]
            let dx = this.X - b2.X
            let dy = this.Y - b2.Y
            let dz = this.Z - b2.Z

            let distance = Math.Sqrt(dx * dx + dy * dy + dz * dz)
            let mag = dt / (distance * distance * distance)
            let b_mass_mag = this.Mass * mag
            let b2_mass_mag = b2.Mass * mag

            this.Vx <- this.Vx - dx * b2_mass_mag
            this.Vy <- this.Vy - dy * b2_mass_mag
            this.Vz <- this.Vz - dz * b2_mass_mag

            b2.Vx <- b2.Vx + dx * b_mass_mag
            b2.Vy <- b2.Vy + dy * b_mass_mag
            b2.Vz <- b2.Vz + dz * b_mass_mag

            idx <- idx + 1

        this.X <- this.X + dt * this.Vx
        this.Y <- this.Y + dt * this.Vy
        this.Z <- this.Z + dt * this.Vz

type Nbody() =
    inherit Benchmark()

    let planetData = [|
        {| X = 0.0; Y = 0.0; Z = 0.0; Vx = 0.0; Vy = 0.0; Vz = 0.0; Mass = 1.0 |}
        {| X = 4.84143144246472090e+00; Y = -1.16032004402742839e+00; Z = -1.03622044471123109e-01; Vx = 1.66007664274403694e-03; Vy = 7.69901118419740425e-03; Vz = -6.90460016972063023e-05; Mass = 9.54791938424326609e-04 |}
        {| X = 8.34336671824457987e+00; Y = 4.12479856412430479e+00; Z = -4.03523417114321381e-01; Vx = -2.76742510726862411e-03; Vy = 4.99852801234917238e-03; Vz = 2.30417297573763929e-05; Mass = 2.85885980666130812e-04 |}
        {| X = 1.28943695621391310e+01; Y = -1.51111514016986312e+01; Z = -2.23307578892655734e-01; Vx = 2.96460137564761618e-03; Vy = 2.37847173959480950e-03; Vz = -2.96589568540237556e-05; Mass = 4.36624404335156298e-05 |}
        {| X = 1.53796971148509165e+01; Y = -2.59193146099879641e+01; Z = 1.79258772950371181e-01; Vx = 2.68067772490389322e-03; Vy = 1.62824170038242295e-03; Vz = -9.51592254519715870e-05; Mass = 5.15138902046611451e-05 |}
    |]

    let mutable bodies = Array.empty<Planet>
    let mutable v1 = 0.0

    let offsetMomentum() =
        let mutable px = 0.0
        let mutable py = 0.0
        let mutable pz = 0.0

        for b in bodies do
            px <- px + b.Vx * b.Mass
            py <- py + b.Vy * b.Mass
            pz <- pz + b.Vz * b.Mass

        let b0 = bodies.[0]
        b0.Vx <- -px / SOLAR_MASS
        b0.Vy <- -py / SOLAR_MASS
        b0.Vz <- -pz / SOLAR_MASS

    let energy() =
        let mutable e = 0.0
        let nbodies = bodies.Length

        for i = 0 to nbodies - 1 do
            let b = bodies.[i]
            e <- e + 0.5 * b.Mass * (b.Vx * b.Vx + b.Vy * b.Vy + b.Vz * b.Vz)

            for j = i + 1 to nbodies - 1 do
                let b2 = bodies.[j]
                let dx = b.X - b2.X
                let dy = b.Y - b2.Y
                let dz = b.Z - b2.Z
                let distance = Math.Sqrt(dx * dx + dy * dy + dz * dz)
                e <- e - (b.Mass * b2.Mass) / distance

        e

    override this.Checksum =
        let v2 = energy()
        (Helper.Checksum(v1) <<< 5) &&& Helper.Checksum(v2)

    override this.Prepare() =
        bodies <- Array.init planetData.Length (fun i ->
            let data = planetData.[i]
            Planet(data.X, data.Y, data.Z, data.Vx, data.Vy, data.Vz, data.Mass))

        offsetMomentum()
        v1 <- energy()

    override this.Run(_: int64) =
        for т in 1 .. 1000 do
            bodies |> Array.iteri (fun i body ->
                body.MoveFromI(bodies, 0.01, i + 1)
            )