mutable struct TextRaytracer <: AbstractBenchmark
    w::Int64
    h::Int64
    result::UInt64

    function TextRaytracer()
        w = Helper.config_i64("Etc::TextRaytracer", "w")
        h = Helper.config_i64("Etc::TextRaytracer", "h")
        new(w, h, UInt64(0))
    end
end

name(b::TextRaytracer)::String = "Etc::TextRaytracer"

struct Vector3D
    x::Float64
    y::Float64
    z::Float64
end

Base.:+(a::Vector3D, b::Vector3D) = Vector3D(a.x + b.x, a.y + b.y, a.z + b.z)
Base.:-(a::Vector3D, b::Vector3D) = Vector3D(a.x - b.x, a.y - b.y, a.z - b.z)
Base.:*(a::Vector3D, s::Float64) = Vector3D(a.x * s, a.y * s, a.z * s)
Base.:*(s::Float64, a::Vector3D) = a * s

dot(a::Vector3D, b::Vector3D) = a.x * b.x + a.y * b.y + a.z * b.z
norm(a::Vector3D) = sqrt(dot(a, a))
normalize(a::Vector3D) = a * (1.0 / norm(a))

struct Ray
    orig::Vector3D
    dir::Vector3D
end

struct Color
    r::Float64
    g::Float64
    b::Float64
end

Base.:+(a::Color, b::Color) = Color(a.r + b.r, a.g + b.g, a.b + b.b)
Base.:*(a::Color, s::Float64) = Color(a.r * s, a.g * s, a.b * s)
Base.:*(s::Float64, a::Color) = a * s

struct Sphere
    center::Vector3D
    radius::Float64
    color::Color
end

get_normal(sphere::Sphere, pt::Vector3D) = normalize(pt - sphere.center)

struct Light
    position::Vector3D
    color::Color
end

const WHITE = Color(1.0, 1.0, 1.0)
const RED = Color(1.0, 0.0, 0.0)
const GREEN = Color(0.0, 1.0, 0.0)
const BLUE = Color(0.0, 0.0, 1.0)

const LIGHT1 = Light(Vector3D(0.7, -1.0, 1.7), WHITE)

const SCENE = [
    Sphere(Vector3D(-1.0, 0.0, 3.0), 0.3, RED),
    Sphere(Vector3D(0.0, 0.0, 3.0), 0.8, GREEN),
    Sphere(Vector3D(1.0, 0.0, 3.0), 0.4, BLUE),
]

const LUT = ['.', '-', '+', '*', 'X', 'M']

function intersect_sphere(ray::Ray, sphere::Sphere)::Union{Float64,Nothing}
    l = sphere.center - ray.orig
    tca = dot(l, ray.dir)

    if tca < 0.0
        return nothing
    end

    d2 = dot(l, l) - tca * tca
    r2 = sphere.radius * sphere.radius

    if d2 > r2
        return nothing
    end

    thc = sqrt(r2 - d2)
    t0 = tca - thc

    if t0 > 10000.0
        return nothing
    end

    return t0
end

clamp(x::Float64, a::Float64, b::Float64) = max(a, min(b, x))
clamp(x::Int64, a::Int64, b::Int64) = max(a, min(b, x))

function diffuse_shading(pi::Vector3D, sphere::Sphere, light::Light)::Color
    n = get_normal(sphere, pi)
    to_light = normalize(light.position - pi)
    lam1 = dot(to_light, n)
    lam2 = clamp(lam1, 0.0, 1.0)
    return light.color * (lam2 * 0.5) + sphere.color * 0.3
end

function run(b::TextRaytracer, iteration_id::Int64)
    total = UInt64(0)
    w = Float64(b.w)
    h = Float64(b.h)

    for y = 0:(b.h-1)
        fy = Float64(y)
        for x = 0:(b.w-1)
            fx = Float64(x)

            ray = Ray(
                Vector3D(0.0, 0.0, 0.0),
                normalize(Vector3D((fx / w) - 0.5, (fy / h) - 0.5, 1.0)),
            )

            hit_t = nothing
            hit_sphere = nothing

            for sphere in SCENE
                t = intersect_sphere(ray, sphere)
                if t !== nothing
                    hit_t = t
                    hit_sphere = sphere
                    break
                end
            end

            if hit_t !== nothing && hit_sphere !== nothing
                idx = shade_pixel(ray, hit_sphere, hit_t)

                idx = max(0, min(5, idx))
                pixel = LUT[idx+1]
            else
                pixel = ' '
            end

            total += UInt64(pixel)
        end
    end

    b.result = (b.result + total) & 0xffffffffffffffff
end

function shade_pixel(ray::Ray, sphere::Sphere, tval::Float64)::Int
    pi = ray.orig + ray.dir * tval
    color = diffuse_shading(pi, sphere, LIGHT1)
    col = (color.r + color.g + color.b) / 3.0

    return Int(trunc(col * 6.0))
end

function checksum(b::TextRaytracer)::UInt32
    return UInt32(b.result & 0xffffffff)
end
