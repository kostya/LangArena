use super::super::{helper, Benchmark};
use crate::config_i64;

const SYM: [char; 6] = [' ', '░', '▒', '▓', '█', '█'];

#[derive(Clone, Copy)]
struct Vec2 {
    x: f64,
    y: f64,
}

impl Vec2 {
    fn new(x: f64, y: f64) -> Self {
        Self { x, y }
    }
}

struct Noise2DContext {
    rgradients: Vec<Vec2>,
    permutations: Vec<i32>,
    size_val: i64,
}

impl Noise2DContext {
    fn new(size: i64) -> Self {
        let size = size as usize;
        let mut rgradients = vec![Vec2::new(0.0, 0.0); size];
        let mut permutations = vec![0i32; size];

        for i in 0..size {
            let v = helper::next_float(1.0) * std::f64::consts::PI * 2.0;
            rgradients[i] = Vec2::new(v.cos(), v.sin());
            permutations[i] = i as i32;
        }

        for _ in 0..size {
            let a = helper::next_int(size as i32) as usize;
            let b = helper::next_int(size as i32) as usize;
            permutations.swap(a, b);
        }

        Self {
            rgradients,
            permutations,
            size_val: size as i64,
        }
    }

    fn get_gradient(&self, x: i32, y: i32) -> Vec2 {
        let idx = self.permutations[(x as usize) & (self.size_val as usize - 1)]
            + self.permutations[(y as usize) & (self.size_val as usize - 1)];
        self.rgradients[(idx as usize) & (self.size_val as usize - 1)]
    }

    fn get(&self, x: f64, y: f64) -> f64 {
        let x0f = x.floor();
        let y0f = y.floor();
        let x0 = x0f as i32;
        let y0 = y0f as i32;
        let x1 = x0 + 1;
        let y1 = y0 + 1;

        let gradients = [
            self.get_gradient(x0, y0),
            self.get_gradient(x1, y0),
            self.get_gradient(x0, y1),
            self.get_gradient(x1, y1),
        ];

        let origins = [
            Vec2::new(x0f, y0f),
            Vec2::new(x0f + 1.0, y0f),
            Vec2::new(x0f, y0f + 1.0),
            Vec2::new(x0f + 1.0, y0f + 1.0),
        ];

        let p = Vec2::new(x, y);

        let gradient = |orig: Vec2, grad: Vec2, p: Vec2| -> f64 {
            let sp = Vec2::new(p.x - orig.x, p.y - orig.y);
            grad.x * sp.x + grad.y * sp.y
        };

        let v0 = gradient(origins[0], gradients[0], p);
        let v1 = gradient(origins[1], gradients[1], p);
        let v2 = gradient(origins[2], gradients[2], p);
        let v3 = gradient(origins[3], gradients[3], p);

        let lerp = |a: f64, b: f64, v: f64| a * (1.0 - v) + b * v;
        let smooth = |v: f64| v * v * (3.0 - 2.0 * v);

        let fx = smooth(x - origins[0].x);
        let vx0 = lerp(v0, v1, fx);
        let vx1 = lerp(v2, v3, fx);

        let fy = smooth(y - origins[0].y);
        lerp(vx0, vx1, fy)
    }
}

pub struct Noise {
    size_val: i64,
    result_val: u32,
    n2d: Noise2DContext,
}

impl Noise {
    pub fn new() -> Self {
        let size_val = config_i64("Noise", "size");
        let n2d = Noise2DContext::new(size_val);

        Self {
            size_val,
            result_val: 0,
            n2d,
        }
    }
}

impl Benchmark for Noise {
    fn name(&self) -> String {
        "Noise".to_string()
    }

    fn run(&mut self, iteration_id: i64) {
        for y in 0..self.size_val {
            for x in 0..self.size_val {
                let v = self
                    .n2d
                    .get(x as f64 * 0.1, (y + (iteration_id * 128)) as f64 * 0.1)
                    * 0.5
                    + 0.5;
                let idx = (v / 0.2) as usize;
                let idx = if idx < SYM.len() { idx } else { SYM.len() - 1 };
                self.result_val = self.result_val.wrapping_add(SYM[idx] as u32);
            }
        }
    }

    fn checksum(&self) -> u32 {
        self.result_val
    }
}
