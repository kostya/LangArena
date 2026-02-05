module noise

import benchmark
import helper
import math

pub struct Noise {
	benchmark.BaseBenchmark
	size_val i64
mut:
	ctx        &Noise2DContext
	result_val u32
}

pub fn new_noise() &benchmark.IBenchmark {
	size_val := helper.config_i64('Noise', 'size')
	mut bench := &Noise{
		BaseBenchmark: benchmark.new_base_benchmark('Noise')
		size_val:      size_val
		ctx:           unsafe { nil }
		result_val:    0
	}
	bench.ctx = new_noise2d_context(int(size_val))
	return bench
}

pub fn (b Noise) name() string {
	return 'Noise'
}

struct Vec2 {
	x f64
	y f64
}

struct GradientSet {
mut:
	gradients [4]Vec2
	origins   [4]Vec2
}

@[heap]
struct Noise2DContext {
mut:
	rgradients   []Vec2
	permutations []int
	size_val     int
}

fn new_noise2d_context(size int) &Noise2DContext {
	mut ctx := &Noise2DContext{
		rgradients:   []Vec2{len: size}
		permutations: []int{len: size}
		size_val:     size
	}

	for i in 0 .. size {
		ctx.rgradients[i] = random_gradient()
		ctx.permutations[i] = i
	}

	for _ in 0 .. size {
		a := helper.next_int(size)
		b := helper.next_int(size)
		ctx.permutations[a], ctx.permutations[b] = ctx.permutations[b], ctx.permutations[a]
	}

	return ctx
}

fn random_gradient() Vec2 {
	v := helper.next_float(1.0) * math.pi * 2.0
	return Vec2{math.cos(v), math.sin(v)}
}

fn lerp(a f64, b f64, v f64) f64 {
	return a * (1.0 - v) + b * v
}

fn smooth(v f64) f64 {
	return v * v * (3.0 - 2.0 * v)
}

fn gradient(orig Vec2, grad Vec2, p Vec2) f64 {
	sp := Vec2{p.x - orig.x, p.y - orig.y}
	return grad.x * sp.x + grad.y * sp.y
}

fn (ctx &Noise2DContext) get_gradient(x int, y int) Vec2 {
	idx := ctx.permutations[x & (ctx.size_val - 1)] + ctx.permutations[y & (ctx.size_val - 1)]
	return ctx.rgradients[idx & (ctx.size_val - 1)]
}

fn (ctx &Noise2DContext) get_gradients(x f64, y f64) GradientSet {
	x0f := math.floor(x)
	y0f := math.floor(y)
	x0 := int(x0f)
	y0 := int(y0f)
	x1 := x0 + 1
	y1 := y0 + 1

	mut gs := GradientSet{}

	gs.gradients[0] = ctx.get_gradient(x0, y0)
	gs.gradients[1] = ctx.get_gradient(x1, y0)
	gs.gradients[2] = ctx.get_gradient(x0, y1)
	gs.gradients[3] = ctx.get_gradient(x1, y1)

	gs.origins[0] = Vec2{x0f + 0.0, y0f + 0.0}
	gs.origins[1] = Vec2{x0f + 1.0, y0f + 0.0}
	gs.origins[2] = Vec2{x0f + 0.0, y0f + 1.0}
	gs.origins[3] = Vec2{x0f + 1.0, y0f + 1.0}

	return gs
}

fn (ctx &Noise2DContext) get(x f64, y f64) f64 {
	p := Vec2{x, y}
	gs := ctx.get_gradients(x, y)

	v0 := gradient(gs.origins[0], gs.gradients[0], p)
	v1 := gradient(gs.origins[1], gs.gradients[1], p)
	v2 := gradient(gs.origins[2], gs.gradients[2], p)
	v3 := gradient(gs.origins[3], gs.gradients[3], p)

	fx := smooth(x - gs.origins[0].x)
	vx0 := lerp(v0, v1, fx)
	vx1 := lerp(v2, v3, fx)

	fy := smooth(y - gs.origins[0].y)
	return lerp(vx0, vx1, fy)
}

const syms = [` `, `░`, `▒`, `▓`, `█`, `█`]

pub fn (mut n Noise) run(iteration_id int) {
	ctx := n.ctx
	size := int(n.size_val)

	for y in 0 .. size {
		for x in 0 .. size {

			v := ctx.get(f64(x) * 0.1, f64(y + (iteration_id * 128)) * 0.1) * 0.5 + 0.5

			mut idx := int(v / 0.2)
			if idx >= syms.len {
				idx = syms.len - 1
			}

			n.result_val += u32(syms[idx])
		}
	}
}

pub fn (n Noise) checksum() u32 {
	return n.result_val
}

pub fn (mut n Noise) prepare() {
	n.result_val = 0
}