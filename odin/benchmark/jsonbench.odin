package benchmark

import "core:fmt"
import "core:strconv"
import "core:strings"
import "core:encoding/json"
import "base:runtime"
import "core:mem"
import "core:math"

Coordinate :: struct {
    x, y, z: f64,
    name:    string,
    opts:    map[string][2]json.Value, 
}

custom_round :: proc(value: f64, decimals: int) -> f64 {
    multiplier := math.pow_f64(10.0, f64(decimals))
    return math.round(value * multiplier) / multiplier
}

JsonGenerate :: struct {
    using base:   Benchmark,
    size_val:     i64,
    result_val:   u32,
    json_data:    string,            
    coordinates:  [dynamic]Coordinate, 
}

destroy_coordinate :: proc(coord: Coordinate) {
    delete(coord.name)
    delete(coord.opts) 
}

jsongenerate_run :: proc(bench: ^Benchmark, iteration_id: int) {
    jg := cast(^JsonGenerate)bench

    delete(jg.json_data)
    jg.json_data = ""

    JsonDoc :: struct {
        coordinates: [dynamic]Coordinate,
        info:        string,
    }

    doc := JsonDoc{
        coordinates = jg.coordinates,
        info        = "some info",
    }

    data, marshal_err := json.marshal(doc, json.Marshal_Options{spec = .JSON})
    if marshal_err == nil {
        jg.json_data = string(data)

        if len(jg.json_data) >= 15 && jg.json_data[:15] == "{\"coordinates\":" {
            jg.result_val += 1
        }
    }
}

jsongenerate_checksum :: proc(bench: ^Benchmark) -> u32 {
    jg := cast(^JsonGenerate)bench
    return jg.result_val
}

jsongenerate_prepare :: proc(bench: ^Benchmark) {
    jg := cast(^JsonGenerate)bench
    jg.result_val = 0
    jg.json_data = ""

    for coord in jg.coordinates {
        destroy_coordinate(coord)
    }
    clear(&jg.coordinates)

    for i in 0 ..< jg.size_val {
        coord: Coordinate

        coord.x = custom_round(next_float(), 8)
        coord.y = custom_round(next_float(), 8)
        coord.z = custom_round(next_float(), 8)

        name_builder := strings.builder_make()
        defer strings.builder_destroy(&name_builder)
        v1 := next_float()
        v2 := next_int(10000)
        fmt.sbprintf(&name_builder, "%.7f %d", v1, v2)
        coord.name = strings.clone(strings.to_string(name_builder))

        arr: [2]json.Value
        arr[0] = i64(1)
        arr[1] = json.Value(true)
        coord.opts["opts"] = arr

        append(&jg.coordinates, coord)
    }
}

jsongenerate_cleanup :: proc(bench: ^Benchmark) {
    jg := cast(^JsonGenerate)bench

    for coord in jg.coordinates {
        destroy_coordinate(coord)
    }
    delete(jg.coordinates) 
    delete(jg.json_data)
}

jsongenerate_get_json :: proc(bench: ^JsonGenerate) -> string {
    if bench == nil do return ""
    return bench.json_data
}

create_jsongenerate :: proc() -> ^Benchmark {
    bench := new(JsonGenerate)
    bench.name = "Json::Generate"
    bench.vtable = default_vtable()

    bench.vtable.run = jsongenerate_run
    bench.vtable.checksum = jsongenerate_checksum
    bench.vtable.prepare = jsongenerate_prepare
    bench.vtable.cleanup = jsongenerate_cleanup

    bench.size_val = config_i64(bench.name, "coords")

    return cast(^Benchmark)bench
}

JsonParseDom :: struct {
    using base:     Benchmark,
    result_val:     u32,
    size_val:       i64,
    json_text:      string,
}

jsonparsedom_run :: proc(bench: ^Benchmark, iteration_id: int) {
    jp := cast(^JsonParseDom)bench

    value, parse_err := json.parse(transmute([]u8)jp.json_text, .JSON)
    if parse_err != .None {
        return
    }
    defer json.destroy_value(value)  

    x_sum, y_sum, z_sum: f64 = 0, 0, 0
    len := 0

    if root_map, ok := value.(json.Object); ok {
        if coords_val, exists := root_map["coordinates"]; exists {
            if coords_arr, ok_arr := coords_val.(json.Array); ok_arr {
                for elem in coords_arr {
                    if coord_map, ok_map := elem.(json.Object); ok_map {

                        if x_val, x_ok := coord_map["x"]; x_ok {
                            if x_f64, ok := value_to_f64(x_val); ok {
                                x_sum += x_f64
                            }
                        }
                        if y_val, y_ok := coord_map["y"]; y_ok {
                            if y_f64, ok := value_to_f64(y_val); ok {
                                y_sum += y_f64
                            }
                        }
                        if z_val, z_ok := coord_map["z"]; z_ok {
                            if z_f64, ok := value_to_f64(z_val); ok {
                                z_sum += z_f64
                            }
                        }
                        len += 1
                    }
                }
            }
        }
    }

    if len > 0 {
        x_avg := x_sum / f64(len)
        y_avg := y_sum / f64(len)
        z_avg := z_sum / f64(len)
        jp.result_val += checksum_f64(x_avg) + checksum_f64(y_avg) + checksum_f64(z_avg)
    }
}

value_to_f64 :: proc(v: json.Value) -> (result: f64, ok: bool) {
    #partial switch val in v {
    case i64:
        return f64(val), true
    case f64:
        return val, true
    }
    return 0, false
}

jsonparsedom_checksum :: proc(bench: ^Benchmark) -> u32 {
    jp := cast(^JsonParseDom)bench
    return jp.result_val
}

jsonparsedom_prepare :: proc(bench: ^Benchmark) {
    jp := cast(^JsonParseDom)bench
    jp.size_val = config_i64(jp.name, "coords")
    jp.result_val = 0

    gen_bench := create_jsongenerate()
    defer destroy_bench(gen_bench)

    gen := cast(^JsonGenerate)gen_bench
    gen.size_val = jp.size_val
    jsongenerate_prepare(gen_bench)
    jsongenerate_run(gen_bench, 0)

    jp.json_text = strings.clone(jsongenerate_get_json(gen))
}

jsonparsedom_cleanup :: proc(bench: ^Benchmark) {
    jp := cast(^JsonParseDom)bench
    delete(jp.json_text)
}

create_jsonparsedom :: proc() -> ^Benchmark {
    bench := new(JsonParseDom)
    bench.name = "Json::ParseDom"
    bench.vtable = default_vtable()

    bench.vtable.run = jsonparsedom_run
    bench.vtable.checksum = jsonparsedom_checksum
    bench.vtable.prepare = jsonparsedom_prepare
    bench.vtable.cleanup = jsonparsedom_cleanup

    return cast(^Benchmark)bench
}

ParsedCoordinate :: struct {
    x: f64 `json:"x"`,
    y: f64 `json:"y"`,
    z: f64 `json:"z"`,
}

ParsedRoot :: struct {
    coordinates: [dynamic]ParsedCoordinate `json:"coordinates"`,
}

JsonParseMapping :: struct {
    using base:   Benchmark,
    result_val:   u32,
    size_val:     i64,
    json_text:    string,
}

jsonparsemapping_run :: proc(bench: ^Benchmark, iteration_id: int) {
    jp := cast(^JsonParseMapping)bench

    root: ParsedRoot
    unmarshal_err := json.unmarshal(transmute([]u8)jp.json_text, &root)
    defer delete(root.coordinates)

    if unmarshal_err != nil {
        return
    }

    x_sum, y_sum, z_sum: f64 = 0, 0, 0
    for coord in root.coordinates {
        x_sum += coord.x
        y_sum += coord.y
        z_sum += coord.z
    }

    len := f64(len(root.coordinates))
    if len > 0 {
        x_avg := x_sum / len
        y_avg := y_sum / len
        z_avg := z_sum / len

        jp.result_val += checksum_f64(x_avg) + checksum_f64(y_avg) + checksum_f64(z_avg)
    }
}

jsonparsemapping_checksum :: proc(bench: ^Benchmark) -> u32 {
    jp := cast(^JsonParseMapping)bench
    return jp.result_val
}

jsonparsemapping_prepare :: proc(bench: ^Benchmark) {
    jp := cast(^JsonParseMapping)bench
    jp.size_val = config_i64(jp.name, "coords")
    jp.result_val = 0

    gen_bench := create_jsongenerate()
    defer destroy_bench(gen_bench)

    gen := cast(^JsonGenerate)gen_bench
    gen.size_val = jp.size_val
    jsongenerate_prepare(gen_bench)
    jsongenerate_run(gen_bench, 0)

    jp.json_text = strings.clone(jsongenerate_get_json(gen))
}

jsonparsemapping_cleanup :: proc(bench: ^Benchmark) {
    jp := cast(^JsonParseMapping)bench
    delete(jp.json_text)
}

create_jsonparsemapping :: proc() -> ^Benchmark {
    bench := new(JsonParseMapping)
    bench.name = "Json::ParseMapping"
    bench.vtable = default_vtable()

    bench.vtable.run = jsonparsemapping_run
    bench.vtable.checksum = jsonparsemapping_checksum
    bench.vtable.prepare = jsonparsemapping_prepare
    bench.vtable.cleanup = jsonparsemapping_cleanup

    return cast(^Benchmark)bench
}