import std;
import os;
import json;
import helper;

var cfg_text: u8[>..];
var cfg_doc: json::Node[>..];
var cfg_decoded: u8[>..];

fn load_config(path: const u8[:]) {
    if !read_file(path, cfg_text) { abort(str("cannot read config ", path)); }
    let root, err = json::parse(cfg_text, cfg_doc, cfg_decoded);
    guard root else { abort(err); }
}

fn config_entry(bench: u8[:]) -> json::Node? {
    json::each(cfg_doc[0]) { entry =>
        let name, ok = json::as_string(json::member(entry, "name"));
        if ok && name == bench { return entry; }
    };
    return null;
}

fn config_i64(bench: u8[:], key: u8[:]) -> i64 {
    let v, ok = json::as_i64(json::member(config_entry(bench), key));
    if !ok { print("Config not found for ", bench, ", field: ", key); return 0; }
    return v;
}

fn config_s(bench: u8[:], key: u8[:]) -> const u8[:] {
    let v, ok = json::as_string(json::member(config_entry(bench), key));
    if !ok { print("Config not found for ", bench, ", field: ", key); return ""; }
    return v;
}

struct Bench { name: const u8[:], iterations: i64, warmup: i64, time: f64 }

fn make_bench(name: const u8[:]) -> Bench {
    let iterations = config_i64(name, "iterations");
    let w, has_warmup = json::as_i64(json::member(config_entry(name), "warmup_iterations"));
    let warmup = if has_warmup { w } else { max((iterations * 0.2) as! i64, 1) };
    return Bench { name: name, iterations: iterations, warmup: warmup, time: 0.0 };
}

fn execute<P, R, C, B>(b: Bench&, s: B&) -> u32 {
    fn warmup(t: B&, iterations: i64) { for i in iterations { R(t, i); } }
    return execute_with_warmup(b, s, P, warmup, R, C);
}

fn execute_with_warmup<P, W, R, C, B>(b: Bench&, s: B&) -> u32 {
    reset();
    P(s);
    W(s, b.warmup);
    reset();
    let t0 = clock();
    for i in b.iterations { R(s, i); }
    b.time = clock() - t0;
    return C(s);
}

fn lower(s: u8[:]) -> u8[>..] {
    var r: u8[>..] = [];
    r.append(s);
    to_lower(r);
    return r;
}

fn run_main<D>() {
    print("start: ", (time() * 1000.0) as! i64);
    let args = args();
    let config: const u8[:] = if args.len > 1 { args[1] } else { "../run.js" };
    let single: const u8[:] = if args.len > 2 { args[2] } else { "" };
    load_config(config);
    let filter = lower(single);
    var summary = 0.0;
    var ok = 0;
    var fails = 0;
    json::each(cfg_doc[0]) { entry =>
        let name, named = json::as_string(json::member(entry, "name"));
        if named && (filter.len == 0 || find(lower(name), filter) >= 0) {
            var b = make_bench(name);
            reset();
            let sum, found = D(b);
            if !found {
                print("Warning: Benchmark '", name, "' defined in config but not found in code");
            } else {
                let expected = config_i64(name, "checksum") as! u32;
                var line: u8[>..] = [];
                format(line, name, ": ");
                if sum == expected {
                    line.append("OK ");
                    ok++;
                } else {
                    format(line, "ERR[actual=", sum, ", expected=", expected, "] ");
                    fails++;
                }
                line.append("in ");
                format_flt(line, b.time, 3);
                line.append("s");
                print(line);
                summary += b.time;
            }
        }
    };
    var line: u8[>..] = [];
    line.append("Summary: ");
    format_flt(line, summary, 4);
    format(line, "s, ", ok + fails, ", ", ok, ", ", fails);
    print(line);
    write_file("/tmp/recompile_marker", "RECOMPILE_MARKER_0");
    if fails > 0 { exit(1); }
}