package benchmark

import "core:fmt"
import "core:os"
import "core:mem"
import "base:runtime"
import "core:strings"
import "core:strconv"
import "core:encoding/json"

IM :: 139968
IA :: 3877
IC :: 29573
INIT :: 42

Helper_State :: struct {
    last_value: int,
    config:     map[string]json.Object,
}

_state: Helper_State

helper_init :: proc() {
    _state.last_value = INIT
    _state.config = make(map[string]json.Object)
}

reset :: proc() {
    _state.last_value = INIT
}

next_int :: proc(max: int) -> int {
    _state.last_value = (_state.last_value * IA + IC) % IM
    return int((f64(_state.last_value) / f64(IM)) * f64(max))
}

next_float :: proc(max: f64 = 1.0) -> f64 {
    _state.last_value = (_state.last_value * IA + IC) % IM
    return max * f64(_state.last_value) / f64(IM)
}

checksum_string :: proc(str: string) -> u32 {
    hash: u32 = 5381
    for c in str {
        hash = ((hash << 5) + hash) + u32(c)
    }
    return hash
}

checksum_bytes :: proc(bytes: []u8) -> u32 {
    hash: u32 = 5381
    for b in bytes {
        hash = ((hash << 5) + hash) + u32(b)
    }
    return hash
}

checksum_f64 :: proc(v: f64) -> u32 {

    str := fmt.tprintf("%.7f", v)

    return checksum_string(str)
}

load_config :: proc(config_file: string = "../test.json") -> bool {
    data, ok := os.read_entire_file(config_file)
    defer delete(data)

    if !ok {
        fmt.eprintf("Error loading config: %s\n", config_file)
        return false
    }

    result: json.Value
    err := json.unmarshal(data, &result)
    if err != nil {
        fmt.eprintf("JSON parse error: %v\n", err)
        return false
    }

    if obj, ok := result.(json.Object); ok {
        clear_map(&_state.config)

        for key, val in obj {

            if inner_obj, inner_ok := val.(json.Object); inner_ok {
                _state.config[key] = inner_obj
            }
        }
        return true
    }

    return false
}

config_i64 :: proc(className, fieldName: string) -> i64 {
    if className not_in _state.config {
        return 0
    }

    class_obj := _state.config[className]

    val, exists := class_obj[fieldName]
    if !exists {
        return 0
    }

    #partial switch v in val {
    case i64:
        return v
    case f64:
        return i64(v)
    case string:

        n, ok := strconv.parse_i64(v)
        if ok {
            return n
        }
        return 0
    case bool:
        if v {
            return 1
        }
        return 0
    case:
        return 0
    }
}

config_string :: proc(className, fieldName: string) -> string {
    if className not_in _state.config {
        return ""
    }

    class_obj := _state.config[className]

    val, exists := class_obj[fieldName]
    if !exists {
        return ""
    }

    #partial switch v in val {
    case string:
        return v
    case i64:
        return fmt.tprintf("%d", v)
    case f64:
        return fmt.tprintf("%f", v)
    case bool:
        if v {
            return "true"
        }
        return "false"
    case:
        return ""
    }
}

helper_cleanup :: proc() {
    delete(_state.config)
}