from std.math import sqrt
from helper import Helper
from benchmark import Benchmark, Config


struct _Vec3(ImplicitlyCopyable):
    var x: Float64
    var y: Float64
    var z: Float64

    def __init__(out self, x: Float64, y: Float64, z: Float64):
        self.x = x
        self.y = y
        self.z = z

    def scale(self, s: Float64) -> Self:
        return Self(self.x * s, self.y * s, self.z * s)

    def __add__(self, other: Self) -> Self:
        return Self(self.x + other.x, self.y + other.y, self.z + other.z)

    def __sub__(self, other: Self) -> Self:
        return Self(self.x - other.x, self.y - other.y, self.z - other.z)

    def dot(self, other: Self) -> Float64:
        return self.x * other.x + self.y * other.y + self.z * other.z

    def magnitude(self) -> Float64:
        return sqrt(self.dot(self))

    def normalize(self) -> Self:
        var mag = self.magnitude()
        if mag == 0.0:
            return Self(0.0, 0.0, 0.0)
        return self.scale(1.0 / mag)


struct _Color(ImplicitlyCopyable):
    var r: Float64
    var g: Float64
    var b: Float64

    def __init__(out self, r: Float64, g: Float64, b: Float64):
        self.r = r
        self.g = g
        self.b = b

    def scale(self, s: Float64) -> Self:
        return Self(self.r * s, self.g * s, self.b * s)

    def __add__(self, other: Self) -> Self:
        return Self(self.r + other.r, self.g + other.g, self.b + other.b)


struct _Sphere(ImplicitlyCopyable):
    var center: _Vec3
    var radius: Float64
    var color: _Color

    def __init__(out self, center: _Vec3, radius: Float64, color: _Color):
        self.center = center
        self.radius = radius
        self.color = color

    def get_normal(self, pt: _Vec3) -> _Vec3:
        return (pt - self.center).normalize()


struct _Light(ImplicitlyCopyable):
    var position: _Vec3
    var color: _Color

    def __init__(out self, position: _Vec3, color: _Color):
        self.position = position
        self.color = color


struct TextRaytracer(Benchmark):
    var w: Int
    var h: Int
    var result: UInt32
    var lut: Array[Int, 6]
    var light1: _Light
    var scene: List[_Sphere]

    def __init__(out self, config: Config) raises:
        self.w = config.get_i64("Etc::TextRaytracer", "w")
        self.h = config.get_i64("Etc::TextRaytracer", "h")
        self.result = 0
        self.lut = [46, 45, 43, 42, 88, 77]

        self.light1 = _Light(_Vec3(0.7, -1.0, 1.7), _Color(1.0, 1.0, 1.0))

        self.scene = [
            _Sphere(_Vec3(-1.0, 0.0, 3.0), 0.3, _Color(1.0, 0.0, 0.0)),
            _Sphere(_Vec3(0.0, 0.0, 3.0), 0.8, _Color(0.0, 1.0, 0.0)),
            _Sphere(_Vec3(1.0, 0.0, 3.0), 0.4, _Color(0.0, 0.0, 1.0)),
        ]

    def class_name(self) -> String:
        return "Etc::TextRaytracer"

    def run(mut self, iteration_id: Int, mut helper: Helper) raises:
        var res: Int = 0

        for j in range(self.h):
            for i in range(self.w):
                var fw = Float64(self.w)
                var fi = Float64(i)
                var fj = Float64(j)
                var fh = Float64(self.h)

                var ray_orig = _Vec3(0.0, 0.0, 0.0)
                var ray_dir = _Vec3(
                    (fi - fw / 2.0) / fw,
                    (fj - fh / 2.0) / fh,
                    1.0,
                ).normalize()

                var hit_obj: Optional[_Sphere] = None
                var hit_val: Float64 = 0.0

                for obj in self.scene:
                    var t = Self._intersect_sphere(
                        ray_orig, ray_dir, obj.center, obj.radius
                    )
                    if t >= 0.0 and t < 10000.0:
                        hit_obj = obj
                        hit_val = t
                        break

                if hit_obj:
                    var idx = Self._shade_pixel(
                        ray_orig, ray_dir, hit_obj[], hit_val, self.light1
                    )
                    res += self.lut[idx]
                else:
                    res += 32

        self.result += UInt32(res)

    def checksum(self) -> UInt32:
        return self.result

    @staticmethod
    def _intersect_sphere(
        ray_orig: _Vec3, ray_dir: _Vec3, center: _Vec3, radius: Float64
    ) -> Float64:
        var l = center - ray_orig
        var tca = l.dot(ray_dir)
        if tca < 0.0:
            return -1.0

        var d2 = l.dot(l) - tca * tca
        var r2 = radius * radius
        if d2 > r2:
            return -1.0

        var thc = sqrt(r2 - d2)
        var t0 = tca - thc

        if t0 > 10000.0:
            return -1.0

        return t0

    @staticmethod
    def _shade_pixel(
        ray_orig: _Vec3,
        ray_dir: _Vec3,
        obj: _Sphere,
        tval: Float64,
        light: _Light,
    ) -> Int:
        var pi = ray_orig + ray_dir.scale(tval)
        var color = Self._diffuse_shading(pi, obj, light)
        var col = (color.r + color.g + color.b) / 3.0
        var idx = Int(col * 6.0)
        if idx < 0:
            idx = 0
        if idx >= 6:
            idx = 5
        return idx

    @staticmethod
    def _diffuse_shading(pi: _Vec3, obj: _Sphere, light: _Light) -> _Color:
        var n = obj.get_normal(pi)
        var light_dir = (light.position - pi).normalize()
        var lam1 = light_dir.dot(n)
        var lam2: Float64
        if lam1 < 0.0:
            lam2 = 0.0
        elif lam1 > 1.0:
            lam2 = 1.0
        else:
            lam2 = lam1
        return light.color.scale(lam2 * 0.5) + obj.color.scale(0.3)
