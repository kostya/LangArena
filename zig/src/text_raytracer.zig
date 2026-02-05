const std = @import("std");
const Benchmark = @import("benchmark.zig").Benchmark;
const Helper = @import("helper.zig").Helper;
const math = std.math;

pub const TextRaytracer = struct {
    allocator: std.mem.Allocator,
    helper: *Helper,
    w: i32,
    h: i32,
    result_val: u32, // Изменено на u32

    const Vector = struct {
        x: f64,
        y: f64,
        z: f64,

        fn scale(self: Vector, s: f64) Vector {
            return Vector{
                .x = self.x * s,
                .y = self.y * s,
                .z = self.z * s,
            };
        }

        fn add(self: Vector, other: Vector) Vector {
            return Vector{
                .x = self.x + other.x,
                .y = self.y + other.y,
                .z = self.z + other.z,
            };
        }

        fn sub(self: Vector, other: Vector) Vector {
            return Vector{
                .x = self.x - other.x,
                .y = self.y - other.y,
                .z = self.z - other.z,
            };
        }

        fn dot(self: Vector, other: Vector) f64 {
            return self.x * other.x + self.y * other.y + self.z * other.z;
        }

        fn magnitude(self: Vector) f64 {
            return @sqrt(self.dot(self));
        }

        fn normalize(self: Vector) Vector {
            const mag = self.magnitude();
            if (mag == 0.0) {
                return Vector{ .x = 0.0, .y = 0.0, .z = 0.0 };
            }
            return self.scale(1.0 / mag);
        }
    };

    const Ray = struct {
        orig: Vector,
        dir: Vector,
    };

    const Color = struct {
        r: f64,
        g: f64,
        b: f64,

        fn scale(self: Color, s: f64) Color {
            return Color{
                .r = self.r * s,
                .g = self.g * s,
                .b = self.b * s,
            };
        }

        fn add(self: Color, other: Color) Color {
            return Color{
                .r = self.r + other.r,
                .g = self.g + other.g,
                .b = self.b + other.b,
            };
        }
    };

    const Sphere = struct {
        center: Vector,
        radius: f64,
        color: Color,

        fn getNormal(self: Sphere, pt: Vector) Vector {
            return pt.sub(self.center).normalize();
        }
    };

    const Light = struct {
        position: Vector,
        color: Color,
    };

    const WHITE = Color{ .r = 1.0, .g = 1.0, .b = 1.0 };
    const RED = Color{ .r = 1.0, .g = 0.0, .b = 0.0 };
    const GREEN = Color{ .r = 0.0, .g = 1.0, .b = 0.0 };
    const BLUE = Color{ .r = 0.0, .g = 0.0, .b = 1.0 };

    const LIGHT1 = Light{
        .position = Vector{ .x = 0.7, .y = -1.0, .z = 1.7 },
        .color = WHITE,
    };

    const LUT = [_]u8{ '.', '-', '+', '*', 'X', 'M' };

    const SCENE = [_]Sphere{
        Sphere{
            .center = Vector{ .x = -1.0, .y = 0.0, .z = 3.0 },
            .radius = 0.3,
            .color = RED,
        },
        Sphere{
            .center = Vector{ .x = 0.0, .y = 0.0, .z = 3.0 },
            .radius = 0.8,
            .color = GREEN,
        },
        Sphere{
            .center = Vector{ .x = 1.0, .y = 0.0, .z = 3.0 },
            .radius = 0.4,
            .color = BLUE,
        },
    };

    const vtable = Benchmark.VTable{
        .run = runImpl,
        .checksum = checksumImpl,
        .deinit = deinitImpl,
    };

    pub fn init(allocator: std.mem.Allocator, helper: *Helper) !*TextRaytracer {
        const w = helper.config_i64("TextRaytracer", "w");
        const h = helper.config_i64("TextRaytracer", "h");

        const self = try allocator.create(TextRaytracer);
        errdefer allocator.destroy(self);

        self.* = TextRaytracer{
            .allocator = allocator,
            .helper = helper,
            .w = @as(i32, @intCast(w)),
            .h = @as(i32, @intCast(h)),
            .result_val = 0,
        };

        return self;
    }

    pub fn deinit(self: *TextRaytracer) void {
        self.allocator.destroy(self);
    }

    pub fn asBenchmark(self: *TextRaytracer) Benchmark {
        return Benchmark.init(self, &vtable, self.helper, "TextRaytracer");
    }

    fn shadePixel(ray: Ray, obj: Sphere, tval: f64) usize {
        const pi = ray.orig.add(ray.dir.scale(tval));
        const color = diffuseShading(pi, obj, LIGHT1);
        const col = (color.r + color.g + color.b) / 3.0;
        var idx = @as(usize, @intFromFloat(col * 6.0));

        if (idx >= LUT.len) idx = LUT.len - 1;
        return idx;
    }

    fn intersectSphere(ray: Ray, center: Vector, radius: f64) ?f64 {
        const l = center.sub(ray.orig);
        const tca = l.dot(ray.dir);

        if (tca < 0.0) return null;

        const d2 = l.dot(l) - tca * tca;
        const r2 = radius * radius;

        if (d2 > r2) return null;

        const thc = @sqrt(r2 - d2);
        const t0 = tca - thc;

        if (t0 > 10000.0) return null;

        return t0;
    }

    fn clamp(x: f64, a: f64, b: f64) f64 {
        if (x < a) return a;
        if (x > b) return b;
        return x;
    }

    fn diffuseShading(pi: Vector, obj: Sphere, light: Light) Color {
        const n = obj.getNormal(pi);
        const light_dir = light.position.sub(pi).normalize();
        const lam1 = light_dir.dot(n);
        const lam2 = clamp(lam1, 0.0, 1.0);

        return light.color.scale(lam2 * 0.5).add(obj.color.scale(0.3));
    }

    fn runImpl(ptr: *anyopaque, iteration_id: i64) void {
        const self: *TextRaytracer = @ptrCast(@alignCast(ptr));
        _ = iteration_id;

        const w_f64 = @as(f64, @floatFromInt(self.w));
        const h_f64 = @as(f64, @floatFromInt(self.h));

        for (0..@as(usize, @intCast(self.h))) |j| {
            for (0..@as(usize, @intCast(self.w))) |i| {
                const fi = @as(f64, @floatFromInt(i));
                const fj = @as(f64, @floatFromInt(j));

                const dir = Vector{
                    .x = (fi - w_f64 / 2.0) / w_f64,
                    .y = (fj - h_f64 / 2.0) / h_f64,
                    .z = 1.0,
                };

                const ray = Ray{
                    .orig = Vector{ .x = 0.0, .y = 0.0, .z = 0.0 },
                    .dir = dir.normalize(),
                };

                var hit_tval: ?f64 = null;
                var hit_obj: ?Sphere = null;

                for (SCENE) |obj| {
                    if (intersectSphere(ray, obj.center, obj.radius)) |tval| {
                        hit_tval = tval;
                        hit_obj = obj;
                        break;
                    }
                }

                var pixel: u8 = ' ';
                if (hit_tval != null and hit_obj != null) {
                    const idx = shadePixel(ray, hit_obj.?, hit_tval.?);
                    pixel = LUT[idx];
                }

                self.result_val +%= pixel; // &+= эквивалент как в C++
            }
        }
    }

    fn checksumImpl(ptr: *anyopaque) u32 {
        const self: *TextRaytracer = @ptrCast(@alignCast(ptr));
        return self.result_val;
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *TextRaytracer = @ptrCast(@alignCast(ptr));
        self.deinit();
    }
};