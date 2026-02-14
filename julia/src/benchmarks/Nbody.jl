mutable struct Planet
    x::Float64
    y::Float64
    z::Float64
    vx::Float64
    vy::Float64
    vz::Float64
    mass::Float64

    function Planet(x, y, z, vx, vy, vz, mass)
        vx_scaled = vx * DAYS_PER_YEAR
        vy_scaled = vy * DAYS_PER_YEAR
        vz_scaled = vz * DAYS_PER_YEAR
        mass_scaled = mass * SOLAR_MASS
        new(x, y, z, vx_scaled, vy_scaled, vz_scaled, mass_scaled)
    end
end

mutable struct Nbody <: AbstractBenchmark
    bodies::Vector{Planet}
    v1::Float64
    result::UInt32

    function Nbody()
        bodies = [

            Planet(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0),

            Planet(
                4.84143144246472090e+00,
                -1.16032004402742839e+00,
                -1.03622044471123109e-01,
                1.66007664274403694e-03,
                7.69901118419740425e-03,
                -6.90460016972063023e-05,
                9.54791938424326609e-04),

            Planet(
                8.34336671824457987e+00,
                4.12479856412430479e+00,
                -4.03523417114321381e-01,
                -2.76742510726862411e-03,
                4.99852801234917238e-03,
                2.30417297573763929e-05,
                2.85885980666130812e-04),

            Planet(
                1.28943695621391310e+01,
                -1.51111514016986312e+01,
                -2.23307578892655734e-01,
                2.96460137564761618e-03,
                2.37847173959480950e-03,
                -2.96589568540237556e-05,
                4.36624404335156298e-05),

            Planet(
                1.53796971148509165e+01,
                -2.59193146099879641e+01,
                1.79258772950371181e-01,
                2.68067772490389322e-03,
                1.62824170038242295e-03,
                -9.51592254519715870e-05,
                5.15138902046611451e-05),
        ]
        new(bodies, 0.0, UInt32(0))
    end
end

name(b::Nbody)::String = "Nbody"

const SOLAR_MASS = 4 * π * π
const DAYS_PER_YEAR = 365.24

function move_from_i!(b1::Planet, bodies::Vector{Planet}, dt::Float64, i::Int)
    while i <= length(bodies)
        b2 = bodies[i]  

        dx = b1.x - b2.x
        dy = b1.y - b2.y
        dz = b1.z - b2.z

        distance_sq = dx*dx + dy*dy + dz*dz
        distance = sqrt(distance_sq)
        mag = dt / (distance * distance_sq)  

        b1_mass_mag = b1.mass * mag
        b2_mass_mag = b2.mass * mag

        b1.vx -= dx * b2_mass_mag
        b1.vy -= dy * b2_mass_mag
        b1.vz -= dz * b2_mass_mag

        b2.vx += dx * b1_mass_mag
        b2.vy += dy * b1_mass_mag
        b2.vz += dz * b1_mass_mag

        i += 1
    end

    b1.x += dt * b1.vx
    b1.y += dt * b1.vy
    b1.z += dt * b1.vz
end

function energy(bodies::Vector{Planet})
    e = 0.0
    nbodies = length(bodies)

    @inbounds for i in 1:nbodies
        b = bodies[i]
        e += 0.5 * b.mass * (b.vx*b.vx + b.vy*b.vy + b.vz*b.vz)

        for j in i+1:nbodies
            b2 = bodies[j]
            dx = b.x - b2.x
            dy = b.y - b2.y
            dz = b.z - b2.z
            distance = sqrt(dx*dx + dy*dy + dz*dz)
            e -= (b.mass * b2.mass) / distance
        end
    end

    return e
end

function offset_momentum!(bodies::Vector{Planet})
    px = py = pz = 0.0

    @inbounds for b in bodies
        m = b.mass
        px += b.vx * m
        py += b.vy * m
        pz += b.vz * m
    end

    b = bodies[1]  
    b.vx = -px / SOLAR_MASS
    b.vy = -py / SOLAR_MASS
    b.vz = -pz / SOLAR_MASS
end

function prepare(b::Nbody)
    offset_momentum!(b.bodies)
    b.v1 = energy(b.bodies)
end

function run(b::Nbody, iteration_id::Int64)
    for n in 1:1000
        for (i, b1) in enumerate(b.bodies)
            move_from_i!(b1, b.bodies, 0.01, i+1)
        end
    end
end

function checksum(b::Nbody)::UInt32
    v2 = energy(b.bodies)

    checksum1 = Helper.checksum_f64(b.v1)
    checksum2 = Helper.checksum_f64(v2)
    return (checksum1 << 5) & checksum2
end