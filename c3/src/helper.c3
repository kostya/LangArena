module helper;

import std::io;
import std::io::file;
import std::encoding::json;
import std::collections::object;
import std::collections::list;
import std::os;

const IM   = 139968;
const IA   = 3877;
const IC   = 29573;
const INIT = 42;

uint helper_last = INIT;

List{String} global_order;

fn void helper_reset()
{
	helper_last = INIT;
}

fn uint helper_next_int(uint max)
{
	helper_last = (helper_last * IA + IC) % IM;
	return (uint)((helper_last * (long)max) / IM);
}

fn uint helper_next_int_range(uint from, uint to)
{
	return helper_next_int(to - from + 1) + from;
}

fn double helper_next_float(double max)
{
	helper_last = (helper_last * IA + IC) % IM;
	return max * helper_last / IM;
}

fn uint helper_checksum_string(String v)
{
	uint hash = 5381;
	foreach (c : v)
	{
		hash = ((hash << 5) + hash) + (uint)c;
	}
	return hash;
}

fn uint helper_checksum_bytes(char[] data)
{
	uint hash = 5381;
	foreach (b : data)
	{
		hash = ((hash << 5) + hash) + (uint)b;
	}
	return hash;
}

fn uint helper_checksum_f64(double v)
{
	@pool()
	{
		String s = string::tformat("%.7f", v);
		return helper_checksum_string(s);
	};
}

Object* global_config;
bool global_config_is_array;

fn void? helper_load_config(String filename)
{
	File fh = file::open(filename, "rb")!;
	defer (void)fh.close();

	fh.seek(0, FROM_END)!;
	sz len = fh.cursor()!;
	fh.seek(0, FROM_START)!;

	char[] json_data = mem::alloc_array(char, (usz)len + 1);
	sz read          = fh.read(json_data[:(usz)len])!;
	json_data[read] = 0;

	Object*? doc_opt = json::parse(mem, (String)json_data[:read]);
	free(json_data);

	if (catch err = doc_opt)
	{
		io::eprintfn("Error parsing JSON config");
		os::exit(1);
	}

	global_config = doc_opt;

	if (global_config.is_array())
	{
		global_config_is_array = true;

		global_order.init(mem);
		sz count = global_config.get_len();
		for (sz i = 0; i < count; i++)
		{
			Object* item = global_config.get_at(i);
			if (try name_val = item.get("name"))
			{
				if (name_val.is_string())
				{
					global_order.push(name_val.s.copy(mem));
				}
			}
		}
	}
	else
	{
		global_config_is_array = false;
	}

	return;
}

fn void helper_free_config()
{
	if (global_config)
	{
		global_config.free();
		global_config = null;
	}
	if (global_order.is_initialized())
	{
		foreach (s : global_order)
		{
			free(s);
		}
		global_order.free();
	}
}

fn Object* find_class_obj(String class_name)
{
	if (!global_config) return null;

	if (global_config_is_array)
	{
		sz count = global_config.get_len();
		for (sz i = 0; i < count; i++)
		{
			Object* item = global_config.get_at(i);
			if (try name_val = item.get("name"))
			{
				if (name_val.is_string() && name_val.s == class_name)
				{
					return item;
				}
			}
		}
		return null;
	}
	else
	{
		if (try val = global_config.get(class_name))
		{
			return val;
		}
		return null;
	}
}

fn long helper_config_i64(String class_name, String field_name)
{
	if (!global_config)
	{
		io::eprintfn("Config not loaded");
		return 0;
	}

	Object* class_obj = find_class_obj(class_name);
	if (!class_obj || !class_obj.is_map()) return 0;

	Object*? field_opt = class_obj.get(field_name);
	if (catch field_opt) return 0;

	if (field_opt.is_float())
	{
		return (long)field_opt.f;
	}
	else if (field_opt.is_int())
	{
		return (long)field_opt.i;
	}
	else if (field_opt.is_string())
	{
		return (long)(field_opt.s.to_long() ?? 0);
	}
	return 0;
}

fn String helper_config_s(String class_name, String field_name)
{
	if (!global_config)
	{
		io::eprintfn("Config not loaded");
		return "";
	}

	Object* class_obj = find_class_obj(class_name);
	if (!class_obj || !class_obj.is_map())
	{
		return "";
	}

	Object*? field_opt = class_obj.get(field_name);
	if (catch field_opt) return "";

	if (!field_opt.is_string())
	{
		return "";
	}

	return field_opt.s;
}