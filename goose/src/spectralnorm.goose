namespace spectralnorm;

import std;
import math;
import bench;
import helper;

fn eval_a(i: i64, j: i64) -> f64 {
    let ij = (i + j) as f64;
    return 1.0 / (ij * (ij + 1.0) / 2.0 + i + 1.0);
}

fn eval_a_times_u(u: f64[:]) -> f64[>..] {
    let n = u.len;
    var result: f64[>..] = [];
    result.resize(n, 0.0);
    for &r, i in result {
        var sum = 0.0;
        for uu, j in u { sum += eval_a(i, j) * uu; }
        r = sum;
    }
    return result;
}

fn eval_at_times_u(u: f64[:]) -> f64[>..] {
    let n = u.len;
    var result: f64[>..] = [];
    result.resize(n, 0.0);
    for &r, i in result {
        var sum = 0.0;
        for uu, j in u { sum += eval_a(j, i) * uu; }
        r = sum;
    }
    return result;
}

fn eval_ata_times_u(u: f64[:]) -> f64[>..] {
    let temp = eval_a_times_u(u);
    return eval_at_times_u(temp);
}

struct Spectralnorm { size_val: i64, v: f64[>..<]&, u: f64[>..] }

fn new_spectralnorm(v: f64[>..<]&) -> Spectralnorm {
    let size_val = config_i64("CLBG::Spectralnorm", "size");
    var s = Spectralnorm { size_val: size_val, v: v, u: [] };
    s.u.resize(size_val, 1.0);
    s.v.resize(size_val, 1.0);
    return s;
}

fn prepare(s: Spectralnorm&) {}

fn run(s: Spectralnorm&, iteration_id: i64) {
    s.v = eval_ata_times_u(s.u);
    s.u = eval_ata_times_u(s.v);
}

fn checksum(s: Spectralnorm&) -> u32 {
    var vbv = 0.0;
    var vv = 0.0;
    for i in s.size_val {
        let vi = s.v[i];
        vbv += s.u[i] * vi;
        vv += vi * vi;
    }
    let result_value = sqrt(vbv / vv);
    return checksum_f64(result_value);
}