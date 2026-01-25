use super::super::{Benchmark, INPUT, helper};

const SIZE: usize = 64;

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

fn lerp(a: f64, b: f64, v: f64) -> f64 {
    a * (1.0 - v) + b * v
}

fn smooth(v: f64) -> f64 {
    v * v * (3.0 - 2.0 * v)
}

fn random_gradient() -> Vec2 {
    let v = helper::next_float(1.0) * std::f64::consts::PI * 2.0;
    Vec2::new(v.cos(), v.sin())
}

fn gradient(orig: Vec2, grad: Vec2, p: Vec2) -> f64 {
    let sp = Vec2::new(p.x - orig.x, p.y - orig.y);
    grad.x * sp.x + grad.y * sp.y
}

struct Noise2DContext {
    rgradients: [Vec2; SIZE],
    permutations: [i32; SIZE],
}

impl Noise2DContext {
    fn new() -> Self {
        let mut rgradients = [Vec2::new(0.0, 0.0); SIZE];
        let mut permutations = [0i32; SIZE];
        
        for i in 0..SIZE {
            rgradients[i] = random_gradient();
            permutations[i] = i as i32;
        }
        
        for _ in 0..SIZE {
            let a = helper::next_int(SIZE as i32) as usize;
            let b = helper::next_int(SIZE as i32) as usize;
            permutations.swap(a, b);
        }
        
        Self {
            rgradients,
            permutations,
        }
    }

    fn get_gradient(&self, x: i32, y: i32) -> Vec2 {
        let idx = self.permutations[(x as usize) & (SIZE - 1)] + self.permutations[(y as usize) & (SIZE - 1)];
        self.rgradients[(idx as usize) & (SIZE - 1)]
    }

    fn get_gradients(&self, x: f64, y: f64) -> ([Vec2; 4], [Vec2; 4]) {
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

        (gradients, origins)
    }

    fn get(&self, x: f64, y: f64) -> f64 {
        let p = Vec2::new(x, y);
        let (gradients, origins) = self.get_gradients(x, y);
        
        let v0 = gradient(origins[0], gradients[0], p);
        let v1 = gradient(origins[1], gradients[1], p);
        let v2 = gradient(origins[2], gradients[2], p);
        let v3 = gradient(origins[3], gradients[3], p);
        
        let fx = smooth(x - origins[0].x);
        let vx0 = lerp(v0, v1, fx);
        let vx1 = lerp(v2, v3, fx);
        
        let fy = smooth(y - origins[0].y);
        lerp(vx0, vx1, fy)
    }
}

pub struct Noise {
    n: i32,
    result: u64,
}

impl Noise {
    const SYM: [char; 6] = [' ', '░', '▒', '▓', '█', '█'];
    
    fn noise_generation(&self) -> u64 {
        let mut pixels = vec![vec![0.0; SIZE]; SIZE];
        let n2d = Noise2DContext::new();
        
        for i in 0..100 {
            for y in 0..SIZE {
                for x in 0..SIZE {
                    let v = n2d.get(x as f64 * 0.1, (y + (i * 128)) as f64 * 0.1) * 0.5 + 0.5;
                    pixels[y][x] = v;
                }
            }
        }
        
        let mut res = 0u64;
        for y in 0..SIZE {
            for x in 0..SIZE {
                let v = pixels[y][x];
                let idx = (v / 0.2) as usize;
                let idx = if idx < Self::SYM.len() { idx } else { Self::SYM.len() - 1 };
                res = res.wrapping_add(Self::SYM[idx] as u64);
            }
        }
        res
    }
    
    pub fn new() -> Self {
        let name = "Noise".to_string();
        let iterations: i32 = INPUT.get()
            .unwrap()
            .get(&name)
            .and_then(|s| s.parse().ok())
            .unwrap_or(0);
        
        Self {
            n: iterations,
            result: 0,
        }
    }
}

impl Benchmark for Noise {
    fn name(&self) -> String {
        "Noise".to_string()
    }
    
    fn iterations(&self) -> i32 {
        self.n
    }
    
    fn run(&mut self) {
        for _ in 0..self.n {
            self.result = self.result.wrapping_add(self.noise_generation());
        }
    }
    
    fn result(&self) -> i64 {
        self.result as i64
    }
}