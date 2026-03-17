package benchmark

import "base:runtime"
import "core:encoding/json"
import "core:fmt"
import "core:mem"
import "core:os"
import "core:strconv"
import "core:strings"

IM :: 139968
IA :: 3877
IC :: 29573
INIT :: 42

Helper_State :: struct {
	last_value: int,
	config:     map[string]json.Object,
	order:      []string,
}

_state: Helper_State

helper_init :: proc() {
	_state.last_value = INIT
	_state.config = make(map[string]json.Object)
	_state.order = nil
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

	data, err := os.read_entire_file(config_file, context.allocator)
	if err != nil {
		fmt.eprintf("Error loading config: %s - %v\n", config_file, err)
		return false
	}
	defer delete(data, context.allocator)

	result: json.Value
	unmarshal_err := json.unmarshal(data, &result)
	if unmarshal_err != nil {
		fmt.eprintf("JSON parse error: %v\n", unmarshal_err)
		return false
	}

	if arr, ok := result.(json.Array); ok {
		clear_map(&_state.config)
		if _state.order != nil {
			delete(_state.order)
		}

		order := make([dynamic]string)

		for item in arr {
			if obj, obj_ok := item.(json.Object); obj_ok {
				if name_val, name_exists := obj["name"]; name_exists {
					if name_str, name_ok := name_val.(string); name_ok {
						_state.config[name_str] = obj
						append(&order, name_str)
					}
				}
			}
		}

		_state.order = order[:]
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
	if _state.order != nil {
		delete(_state.order)
	}
}
