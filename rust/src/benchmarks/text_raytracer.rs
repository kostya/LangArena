use super::super::Benchmark;
use crate::config_i64;

#[derive(Clone, Copy)]
struct Vector {
    x: f64,
    y: f64,
    z: f64,
}

impl Vector {
    const fn new(x: f64, y: f64, z: f64) -> Self {
        Self { x, y, z }
    }

    fn scale(&self, s: f64) -> Self {
        Self::new(self.x * s, self.y * s, self.z * s)
    }

    fn add(&self, other: &Vector) -> Self {
        Self::new(self.x + other.x, self.y + other.y, self.z + other.z)
    }

    fn sub(&self, other: &Vector) -> Self {
        Self::new(self.x - other.x, self.y - other.y, self.z - other.z)
    }

    fn dot(&self, other: &Vector) -> f64 {
        self.x * other.x + self.y * other.y + self.z * other.z
    }

    fn magnitude(&self) -> f64 {
        self.dot(self).sqrt()
    }

    fn normalize(&self) -> Self {
        let mag = self.magnitude();
        self.scale(1.0 / mag)
    }
}

struct Ray {
    orig: Vector,
    dir: Vector,
}

impl Ray {
    fn new(orig: Vector, dir: Vector) -> Self {
        Self { orig, dir }
    }
}

#[derive(Clone, Copy)]
struct Color {
    r: f64,
    g: f64,
    b: f64,
}

impl Color {
    const fn new(r: f64, g: f64, b: f64) -> Self {
        Self { r, g, b }
    }

    fn scale(&self, s: f64) -> Self {
        Self::new(self.r * s, self.g * s, self.b * s)
    }

    fn add(&self, other: &Color) -> Self {
        Self::new(self.r + other.r, self.g + other.g, self.b + other.b)
    }
}

struct Sphere {
    center: Vector,
    radius: f64,
    color: Color,
}

impl Sphere {
    const fn new(center: Vector, radius: f64, color: Color) -> Self {
        Self { center, radius, color }
    }

    fn get_normal(&self, pt: &Vector) -> Vector {
        pt.sub(&self.center).normalize()
    }
}

struct Light {
    position: Vector,
    color: Color,
}

struct Hit {
    obj: Sphere,
    value: f64,
}

const WHITE: Color = Color::new(1.0, 1.0, 1.0);
const RED: Color = Color::new(1.0, 0.0, 0.0);
const GREEN: Color = Color::new(0.0, 1.0, 0.0);
const BLUE: Color = Color::new(0.0, 0.0, 1.0);

const LIGHT1: Light = Light {
    position: Vector::new(0.7, -1.0, 1.7),
    color: WHITE,
};

const LUT: [char; 6] = ['.', '-', '+', '*', 'X', 'M'];

const SCENE: [Sphere; 3] = [
    Sphere::new(Vector::new(-1.0, 0.0, 3.0), 0.3, RED),
    Sphere::new(Vector::new(0.0, 0.0, 3.0), 0.8, GREEN),
    Sphere::new(Vector::new(1.0, 0.0, 3.0), 0.4, BLUE),
];

pub struct TextRaytracer {
    w: i32,
    h: i32,
    result_val: u32,
}

impl TextRaytracer {
    fn shade_pixel(&self, ray: &Ray, obj: &Sphere, tval: f64) -> usize {
        let scale_dir = ray.dir.scale(tval);
        let pi = ray.orig.add(&scale_dir);
        let color = self.diffuse_shading(&pi, obj, &LIGHT1);
        let col = (color.r + color.g + color.b) / 3.0;
        (col * 6.0).floor() as usize
    }

    fn intersect_sphere(&self, ray: &Ray, center: &Vector, radius: f64) -> Option<f64> {
        let l = center.sub(&ray.orig);
        let tca = l.dot(&ray.dir);
        if tca < 0.0 {
            return None;
        }

        let d2 = l.dot(&l) - tca * tca;
        let r2 = radius * radius;
        if d2 > r2 {
            return None;
        }

        let thc = (r2 - d2).sqrt();
        let t0 = tca - thc;
        if t0 > 10000.0 {
            return None;
        }

        Some(t0)
    }

    fn clamp(&self, x: f64, a: f64, b: f64) -> f64 {
        if x < a {
            a
        } else if x > b {
            b
        } else {
            x
        }
    }

    fn diffuse_shading(&self, pi: &Vector, obj: &Sphere, light: &Light) -> Color {
        let n = obj.get_normal(pi);
        let light_dir = light.position.sub(pi).normalize();
        let lam1 = light_dir.dot(&n);
        let lam2 = self.clamp(lam1, 0.0, 1.0);
        let light_color = light.color.scale(lam2 * 0.5);
        let obj_color = obj.color.scale(0.3);
        light_color.add(&obj_color)
    }

    pub fn new() -> Self {
        let w = config_i64("TextRaytracer", "w") as i32;
        let h = config_i64("TextRaytracer", "h") as i32;

        Self {
            w,
            h,
            result_val: 0,
        }
    }
}

impl Benchmark for TextRaytracer {
    fn name(&self) -> String {
        "TextRaytracer".to_string()
    }

    fn run(&mut self, _iteration_id: i64) {
        let fw = self.w as f64;
        let fh = self.h as f64;

        for j in 0..self.h {
            for i in 0..self.w {
                let fi = i as f64;
                let fj = j as f64;

                let ray = Ray::new(
                    Vector::new(0.0, 0.0, 0.0),
                    Vector::new((fi - fw / 2.0) / fw, (fj - fh / 2.0) / fh, 1.0).normalize(),
                );

                let mut hit: Option<Hit> = None;

                for obj in &SCENE {
                    if let Some(tval) = self.intersect_sphere(&ray, &obj.center, obj.radius) {
                        hit = Some(Hit {
                            obj: Sphere::new(obj.center, obj.radius, obj.color),
                            value: tval,
                        });
                        break;
                    }
                }

                let pixel = if let Some(hit) = hit {
                    let idx = self.shade_pixel(&ray, &hit.obj, hit.value);
                    if idx < LUT.len() {
                        LUT[idx]
                    } else {
                        ' '
                    }
                } else {
                    ' '
                };

                self.result_val = self.result_val.wrapping_add(pixel as u32);
            }
        }
    }

    fn checksum(&self) -> u32 {
        self.result_val
    }
}