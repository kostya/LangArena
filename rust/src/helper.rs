use std::sync::atomic::{AtomicI32, Ordering};

pub const IM: i32 = 139968;
pub const IA: i32 = 3877;
pub const IC: i32 = 29573;
pub const INIT: i32 = 42;

static LAST: AtomicI32 = AtomicI32::new(INIT);

pub fn reset() {
    LAST.store(INIT, Ordering::SeqCst);
}

#[inline(always)]
pub fn last() -> i32 {
    LAST.load(Ordering::SeqCst)
}

#[inline(always)]
pub fn set_last(x: i32) {
    LAST.store(x, Ordering::SeqCst);
}

pub fn next_int(max: i32) -> i32 {
    let new_last = (last().wrapping_mul(IA).wrapping_add(IC)) % IM;
    set_last(new_last);
    (new_last as f64 / IM as f64 * max as f64) as i32
}

pub fn next_float(max: f64) -> f64 {
    let new_last = (last().wrapping_mul(IA).wrapping_add(IC)) % IM;
    set_last(new_last);
    max * new_last as f64 / IM as f64
}

pub fn checksum_str(v: &str) -> u32 {

    let mut hash: u32 = 5381;
    for &byte in v.as_bytes() {
        hash = ((hash << 5).wrapping_add(hash)).wrapping_add(byte as u32);
    }
    hash
}

pub fn checksum_bytes(v: &Vec<u8>) -> u32 {

    let mut hash: u32 = 5381;
    for &byte in v {
        hash = ((hash << 5).wrapping_add(hash)).wrapping_add(byte as u32);
    }
    hash
}

pub fn checksum_f64(v: f64) -> u32 {
    checksum_str(&format!("{:.7}", v))
}

#[inline(always)]
pub fn debug_print(msg: &str) {
    #[cfg(debug_assertions)]
    {
        if std::env::var("DEBUG") == Ok("1".to_string()) {
            println!("{}", msg);
        }
    }

}