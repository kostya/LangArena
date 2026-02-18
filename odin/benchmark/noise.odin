package benchmark

import "core:math"
import "core:slice"

Vec2 :: struct {
    x, y: f64,
}

Noise2DContext :: struct {
    rgradients: []Vec2,
    permutations: []int,
    size_val: int,
}

SYM_VALUES :: [6]rune{' ', '░', '▒', '▓', '█', '█'}

create_noise_context :: proc(size: int) -> ^Noise2DContext {
    ctx := new(Noise2DContext)
    ctx.size_val = size
    ctx.rgradients = make([]Vec2, size)
    ctx.permutations = make([]int, size)

    for i in 0..<size {
        v := next_float() * math.PI * 2.0
        ctx.rgradients[i] = Vec2{math.cos(v), math.sin(v)}
        ctx.permutations[i] = i
    }

    for i in 0..<size {
        a := next_int(size)
        b := next_int(size)
        ctx.permutations[a], ctx.permutations[b] = ctx.permutations[b], ctx.permutations[a]
    }

    return ctx
}

destroy_noise_context :: proc(ctx: ^Noise2DContext) {
    delete(ctx.rgradients)
    delete(ctx.permutations)
    free(ctx)
}

get_gradient :: proc(ctx: ^Noise2DContext, x, y: int) -> Vec2 {
    idx := ctx.permutations[x & (ctx.size_val - 1)] + 
           ctx.permutations[y & (ctx.size_val - 1)]
    return ctx.rgradients[idx & (ctx.size_val - 1)]
}

lerp :: proc(a, b, v: f64) -> f64 {
    return a * (1.0 - v) + b * v
}

smooth :: proc(v: f64) -> f64 {
    return v * v * (3.0 - 2.0 * v)
}

gradient :: proc(orig, grad, p: Vec2) -> f64 {
    sp := Vec2{p.x - orig.x, p.y - orig.y}
    return grad.x * sp.x + grad.y * sp.y
}

noise_get :: proc(ctx: ^Noise2DContext, x, y: f64) -> f64 {
    x0f := math.floor(x)
    y0f := math.floor(y)
    x0 := int(x0f)
    y0 := int(y0f)
    x1 := x0 + 1
    y1 := y0 + 1

    gradients := [4]Vec2{
        get_gradient(ctx, x0, y0),
        get_gradient(ctx, x1, y0),
        get_gradient(ctx, x0, y1),
        get_gradient(ctx, x1, y1),
    }

    origins := [4]Vec2{
        {x0f + 0.0, y0f + 0.0},
        {x0f + 1.0, y0f + 0.0},
        {x0f + 0.0, y0f + 1.0},
        {x0f + 1.0, y0f + 1.0},
    }

    p := Vec2{x, y}
    v0 := gradient(origins[0], gradients[0], p)
    v1 := gradient(origins[1], gradients[1], p)
    v2 := gradient(origins[2], gradients[2], p)
    v3 := gradient(origins[3], gradients[3], p)

    fx := smooth(x - origins[0].x)
    vx0 := lerp(v0, v1, fx)
    vx1 := lerp(v2, v3, fx)

    fy := smooth(y - origins[0].y)
    return lerp(vx0, vx1, fy)
}

Noise :: struct {
    using base: Benchmark,
    size_val: int,
    result_val: u32,
    ctx: ^Noise2DContext,
}

noise_prepare :: proc(bench: ^Benchmark) {
    n := cast(^Noise)bench
    n.size_val = int(config_i64("Noise", "size"))
    n.ctx = create_noise_context(n.size_val)
}

noise_run :: proc(bench: ^Benchmark, iteration_id: int) {
    n := cast(^Noise)bench

    sym := SYM_VALUES

    for y in 0..<n.size_val {
        for x in 0..<n.size_val {
            v := noise_get(n.ctx, f64(x) * 0.1, f64(y + (iteration_id * 128)) * 0.1) * 0.5 + 0.5
            idx := int(v / 0.2)
            if idx >= 6 {
                idx = 5
            }
            n.result_val += u32(sym[idx])
        }
    }
}

noise_checksum :: proc(bench: ^Benchmark) -> u32 {
    n := cast(^Noise)bench
    return n.result_val
}

noise_cleanup :: proc(bench: ^Benchmark) {
    n := cast(^Noise)bench
    if n.ctx != nil {
        destroy_noise_context(n.ctx)
    }
}

create_noise :: proc() -> ^Benchmark {
    n := new(Noise)
    n.name = "Noise"
    n.vtable = default_vtable()

    n.vtable.run = noise_run
    n.vtable.checksum = noise_checksum
    n.vtable.prepare = noise_prepare
    n.vtable.cleanup = noise_cleanup

    return cast(^Benchmark)n
}