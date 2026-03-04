module helper

import os
import json

const im = 139968
const ia = 3877
const ic = 29573

type ConfigValue = i64 | string

struct Globals {
mut:
	last   int = 42
	config map[string]map[string]ConfigValue
	order  []string
}

__global (
	g Globals
)

pub fn reset() {
	g.last = 42
}

pub fn next_int(max int) int {
	g.last = (g.last * ia + ic) % im
	return int((i64(g.last) * i64(max)) / im)
}

pub fn next_int_range(from int, to int) int {
	return next_int(to - from + 1) + from
}

pub fn next_float(max f64) f64 {
	g.last = (g.last * ia + ic) % im
	return max * f64(g.last) / f64(im)
}

pub fn checksum_str(v string) u32 {
	mut hash := u32(5381)
	for c in v {
		hash = ((hash << 5) + hash) + u32(c)
	}
	return hash
}

pub fn checksum_bytes(v []u8) u32 {
	mut hash := u32(5381)
	for byte in v {
		hash = ((hash << 5) + hash) + u32(byte)
	}
	return hash
}

pub fn checksum_f64(v f64) u32 {
	str := '${v:.7f}'
	return checksum_str(str)
}

pub fn load_config(filename string) {
	content := os.read_file(filename) or {
		println('Cannot open config file: ${filename}')
		g.config = map[string]map[string]ConfigValue{}
		g.order = []
		return
	}

	data := json.decode([]map[string]ConfigValue, content) or {
		g.config = map[string]map[string]ConfigValue{}
		g.order = []
		return
	}

	mut config_map := map[string]map[string]ConfigValue{}
	mut order_list := []string{}

	for item in data {
		name_val := item['name'] or { continue }
		name := if name_val is string { name_val } else { continue
		 }

		mut inner_map := map[string]ConfigValue{}
		for k, v in item {
			if k != 'name' {
				inner_map[k] = v
			}
		}

		config_map[name] = inner_map.clone()
		order_list << name
	}

	g.config = config_map.clone()
	g.order = order_list.clone()
}

pub fn get_order() []string {
	return g.order
}

pub fn config_i64(class_name string, field_name string) i64 {
	if class_name in g.config && field_name in g.config[class_name] {
		val := g.config[class_name][field_name] or { return 0 }
		if val is i64 {
			return val
		}
	}
	return 0
}

pub fn config_string(class_name string, field_name string) string {
	if class_name in g.config && field_name in g.config[class_name] {
		val := g.config[class_name][field_name] or { return '' }
		if val is string {
			return val
		} else if val is i64 {
			return val.str()
		}
	}
	return ''
}
