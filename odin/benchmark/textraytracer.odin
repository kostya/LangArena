package benchmark

import "core:math"

Vector :: struct {
    x, y, z: f64,
}

vector_scale :: proc(v: Vector, s: f64) -> Vector {
    return Vector{v.x * s, v.y * s, v.z * s}
}

vector_add :: proc(a, b: Vector) -> Vector {
    return Vector{a.x + b.x, a.y + b.y, a.z + b.z}
}

vector_sub :: proc(a, b: Vector) -> Vector {
    return Vector{a.x - b.x, a.y - b.y, a.z - b.z}
}

vector_dot :: proc(a, b: Vector) -> f64 {
    return a.x * b.x + a.y * b.y + a.z * b.z
}

vector_magnitude :: proc(v: Vector) -> f64 {
    return math.sqrt(vector_dot(v, v))
}

vector_normalize :: proc(v: Vector) -> Vector {
    mag := vector_magnitude(v)
    if mag == 0.0 {
        return Vector{0, 0, 0}
    }
    return vector_scale(v, 1.0 / mag)
}

Ray :: struct {
    orig, dir: Vector,
}

Color :: struct {
    r, g, b: f64,
}

color_scale :: proc(c: Color, s: f64) -> Color {
    return Color{c.r * s, c.g * s, c.b * s}
}

color_add :: proc(a, b: Color) -> Color {
    return Color{a.r + b.r, a.g + b.g, a.b + b.b}
}

Sphere :: struct {
    center: Vector,
    radius: f64,
    color: Color,
}

sphere_get_normal :: proc(s: ^Sphere, pt: Vector) -> Vector {
    return vector_normalize(vector_sub(pt, s.center))
}

Light :: struct {
    position: Vector,
    color: Color,
}

WHITE :: Color{1.0, 1.0, 1.0}
RED :: Color{1.0, 0.0, 0.0}
GREEN :: Color{0.0, 1.0, 0.0}
BLUE :: Color{0.0, 0.0, 1.0}

LIGHT1 :: Light{{0.7, -1.0, 1.7}, WHITE}

clamp :: proc(x, a, b: f64) -> f64 {
    if x < a {
        return a
    }
    if x > b {
        return b
    }
    return x
}

intersect_sphere :: proc(ray: Ray, center: Vector, radius: f64) -> (tval: f64, ok: bool) {
    l := vector_sub(center, ray.orig)
    tca := vector_dot(l, ray.dir)
    if tca < 0.0 {
        return 0.0, false
    }

    d2 := vector_dot(l, l) - tca * tca
    r2 := radius * radius
    if d2 > r2 {
        return 0.0, false
    }

    thc := math.sqrt(r2 - d2)
    t0 := tca - thc
    if t0 > 10000.0 {
        return 0.0, false
    }

    return t0, true
}

diffuse_shading :: proc(pi: Vector, obj: ^Sphere, light: Light) -> Color {
    n := sphere_get_normal(obj, pi)
    light_dir := vector_normalize(vector_sub(light.position, pi))
    lam1 := vector_dot(light_dir, n)
    lam2 := clamp(lam1, 0.0, 1.0)

    base_color := color_scale(light.color, lam2 * 0.5)
    obj_color := color_scale(obj.color, 0.3)
    return color_add(base_color, obj_color)
}

shade_pixel :: proc(ray: Ray, obj: ^Sphere, tval: f64) -> int {
    pi := vector_add(ray.orig, vector_scale(ray.dir, tval))
    color := diffuse_shading(pi, obj, LIGHT1)
    col := (color.r + color.g + color.b) / 3.0
    idx := int(col * 6.0)

    if idx < 0 {
        idx = 0
    }
    if idx >= 6 {
        idx = 5
    }
    return idx
}

TextRaytracer :: struct {
    using base: Benchmark,
    w, h: int,
    result_val: u32,

    scene: [3]Sphere,
}

textraytracer_prepare :: proc(bench: ^Benchmark) {
    tr := cast(^TextRaytracer)bench
    tr.w = int(config_i64("Etc::TextRaytracer", "w"))
    tr.h = int(config_i64("Etc::TextRaytracer", "h"))

    tr.scene = [3]Sphere{
        {Vector{-1.0, 0.0, 3.0}, 0.3, RED},
        {Vector{0.0, 0.0, 3.0}, 0.8, GREEN},
        {Vector{1.0, 0.0, 3.0}, 0.4, BLUE},
    }
}

textraytracer_run :: proc(bench: ^Benchmark, iteration_id: int) {
    tr := cast(^TextRaytracer)bench

    fw := f64(tr.w)
    fh := f64(tr.h)

    lut := [6]u8{'.', '-', '+', '*', 'X', 'M'}

    for j in 0..<tr.h {
        fj := f64(j)
        for i in 0..<tr.w {
            fi := f64(i)

            ray := Ray{
                orig = Vector{0.0, 0.0, 0.0},
                dir = vector_normalize(Vector{
                    (fi - fw/2.0) / fw,
                    (fj - fh/2.0) / fh,
                    1.0,
                }),
            }

            hit_tval: f64 = 0.0
            hit_obj: ^Sphere = nil

            for &sphere in &tr.scene {
                tval, ok := intersect_sphere(ray, sphere.center, sphere.radius)
                if ok {
                    hit_tval = tval
                    hit_obj = &sphere
                    break
                }
            }

            pixel: u8 = ' '
            if hit_obj != nil {
                idx := shade_pixel(ray, hit_obj, hit_tval)
                pixel = lut[idx]
            }
            tr.result_val += u32(pixel)
        }
    }
}

textraytracer_checksum :: proc(bench: ^Benchmark) -> u32 {
    tr := cast(^TextRaytracer)bench
    return tr.result_val
}

create_textraytracer :: proc() -> ^Benchmark {
    tr := new(TextRaytracer)
    tr.name = "Etc::TextRaytracer"
    tr.vtable = default_vtable()

    tr.vtable.run = textraytracer_run
    tr.vtable.checksum = textraytracer_checksum
    tr.vtable.prepare = textraytracer_prepare

    return cast(^Benchmark)tr
}