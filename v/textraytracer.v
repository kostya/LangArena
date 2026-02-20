module textraytracer

import benchmark
import helper
import math

pub struct TextRaytracer {
	benchmark.BaseBenchmark
	w i64
	h i64
mut:
	result_val u32
}

pub fn new_textraytracer() &benchmark.IBenchmark {
	mut bench := &TextRaytracer{
		BaseBenchmark: benchmark.new_base_benchmark('TextRaytracer')
		w:             helper.config_i64('TextRaytracer', 'w')
		h:             helper.config_i64('TextRaytracer', 'h')
		result_val:    0
	}
	return bench
}

pub fn (b TextRaytracer) name() string {
	return 'TextRaytracer'
}

struct Vector {
	x f64
	y f64
	z f64
}

fn (v Vector) scale(s f64) Vector {
	return Vector{v.x * s, v.y * s, v.z * s}
}

fn (v Vector) add(other Vector) Vector {
	return Vector{v.x + other.x, v.y + other.y, v.z + other.z}
}

fn (v Vector) sub(other Vector) Vector {
	return Vector{v.x - other.x, v.y - other.y, v.z - other.z}
}

fn (v Vector) dot(other Vector) f64 {
	return v.x * other.x + v.y * other.y + v.z * other.z
}

fn (v Vector) magnitude() f64 {
	return math.sqrt(v.dot(v))
}

fn (v Vector) normalize() Vector {
	mag := v.magnitude()
	if mag == 0.0 {
		return Vector{0.0, 0.0, 0.0}
	}
	return v.scale(1.0 / mag)
}

struct Ray {
	orig Vector
	dir  Vector
}

struct Color {
	r f64
	g f64
	b f64
}

fn (c Color) scale(s f64) Color {
	return Color{c.r * s, c.g * s, c.b * s}
}

fn (c Color) add(other Color) Color {
	return Color{c.r + other.r, c.g + other.g, c.b + other.b}
}

struct Sphere {
	center Vector
	radius f64
	color  Color
}

fn (s Sphere) get_normal(pt Vector) Vector {
	return pt.sub(s.center).normalize()
}

struct Light {
	position Vector
	color    Color
}

const white = Color{1.0, 1.0, 1.0}
const red = Color{1.0, 0.0, 0.0}
const green = Color{0.0, 1.0, 0.0}
const blue = Color{0.0, 0.0, 1.0}

const light1 = Light{Vector{0.7, -1.0, 1.7}, white}
const lut = [`.`, `-`, `+`, `*`, `X`, `M`]

const scene = [
	Sphere{Vector{-1.0, 0.0, 3.0}, 0.3, red},
	Sphere{Vector{0.0, 0.0, 3.0}, 0.8, green},
	Sphere{Vector{1.0, 0.0, 3.0}, 0.4, blue},
]

fn shade_pixel(ray Ray, obj Sphere, tval f64) int {
	pi := ray.orig.add(ray.dir.scale(tval))
	color := diffuse_shading(pi, obj, light1)
	col := (color.r + color.g + color.b) / 3.0
	mut idx := int(col * 6.0)
	if idx < 0 {
		idx = 0
	}
	if idx >= lut.len {
		idx = lut.len - 1
	}
	return idx
}

fn intersect_sphere(ray Ray, center Vector, radius f64) ?f64 {
	l := center.sub(ray.orig)
	tca := l.dot(ray.dir)
	if tca < 0.0 {
		return none
	}

	d2 := l.dot(l) - tca * tca
	r2 := radius * radius
	if d2 > r2 {
		return none
	}

	thc := math.sqrt(r2 - d2)
	t0 := tca - thc
	if t0 > 10000.0 {
		return none
	}

	return t0
}

fn clamp(x f64, a f64, b f64) f64 {
	if x < a {
		return a
	}
	if x > b {
		return b
	}
	return x
}

fn diffuse_shading(pi Vector, obj Sphere, light Light) Color {
	n := obj.get_normal(pi)
	light_dir := light.position.sub(pi).normalize()
	lam1 := light_dir.dot(n)
	lam2 := clamp(lam1, 0.0, 1.0)
	return light.color.scale(lam2 * 0.5).add(obj.color.scale(0.3))
}

pub fn (mut t TextRaytracer) run(iteration_id int) {
	w := int(t.w)
	h := int(t.h)
	fw := f64(w)
	fh := f64(h)

	for j in 0 .. h {
		fj := f64(j)
		for i in 0 .. w {
			fi := f64(i)

			ray := Ray{
				orig: Vector{0.0, 0.0, 0.0}
				dir:  Vector{(fi - fw / 2.0) / fw, (fj - fh / 2.0) / fh, 1.0}.normalize()
			}

			mut hit_obj := Sphere{}
			mut hit_tval := f64(0.0)
			mut found := false

			for obj in scene {
				tval := intersect_sphere(ray, obj.center, obj.radius) or { continue }
				hit_obj = obj
				hit_tval = tval
				found = true
				break
			}

			mut pixel := ` `
			if found {
				idx := shade_pixel(ray, hit_obj, hit_tval)
				pixel = lut[idx]
			}

			t.result_val += u32(pixel)
		}
	}
}

pub fn (t TextRaytracer) checksum() u32 {
	return t.result_val
}

pub fn (mut t TextRaytracer) prepare() {
	t.result_val = 0
}
