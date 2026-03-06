package benchmark

import "core:c"
import "core:fmt"
import "core:mem"
import "core:strings"

FIRST_NAMES := [?]string{"John", "Jane", "Bob", "Alice", "Charlie", "Diana", "Sarah", "Mike"}
LAST_NAMES := [?]string {
	"Smith",
	"Johnson",
	"Brown",
	"Taylor",
	"Wilson",
	"Davis",
	"Miller",
	"Jones",
}
CITIES := [?]string{"New York", "Los Angeles", "Chicago", "Houston", "Phoenix", "San Francisco"}
LOREM :: "Lorem {ipsum} dolor {sit} amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore {et} dolore magna aliqua. "

TemplateBase :: struct {
	count:    int,
	checksum: u32,
	text:     string,
	rendered: string,
	vars:     map[string]string,
}

TemplateRegex :: struct {
	using base: Benchmark,
	template:   TemplateBase,
	re:         ^PCRE2_CODE,
	md:         ^PCRE2_MATCH_DATA,
}

TemplateParse :: struct {
	using base: Benchmark,
	template:   TemplateBase,
}

template_prepare_base :: proc(t: ^TemplateBase, count: int) {
	t.count = count
	t.checksum = 0
	clear(&t.vars)

	sb := strings.builder_make(0, t.count * 200)
	defer strings.builder_destroy(&sb)

	strings.write_string(&sb, "<html><body>")
	strings.write_string(&sb, "<h1>{{TITLE}}</h1>")
	t.vars["TITLE"] = "Template title"
	strings.write_string(&sb, "<p>")
	strings.write_string(&sb, LOREM)
	strings.write_string(&sb, "</p>")
	strings.write_string(&sb, "<table>")

	for i in 0 ..< t.count {
		if i % 3 == 0 {
			strings.write_string(&sb, "<!-- {comment} -->")
		}
		strings.write_string(&sb, "<tr>")

		fmt.sbprintf(&sb, "<td>{{{{ FIRST_NAME%d }}}}</td>", i)
		fmt.sbprintf(&sb, "<td>{{{{LAST_NAME%d}}}</td>", i)
		fmt.sbprintf(&sb, "<td>{{{{  CITY%d  }}}</td>", i)

		t.vars[fmt.tprintf("FIRST_NAME%d", i)] = FIRST_NAMES[i % len(FIRST_NAMES)]
		t.vars[fmt.tprintf("LAST_NAME%d", i)] = LAST_NAMES[i % len(LAST_NAMES)]
		t.vars[fmt.tprintf("CITY%d", i)] = CITIES[i % len(CITIES)]

		fmt.sbprintf(&sb, "<td>{{balance: %d}}</td>", i % 100)
		strings.write_string(&sb, "</tr>\n")
	}

	strings.write_string(&sb, "</table>")
	strings.write_string(&sb, "</body></html>")

	t.text = strings.clone(strings.to_string(sb))
}

template_regex_prepare :: proc(bench: ^Benchmark) {
	t := cast(^TemplateRegex)bench
	count := int(config_i64(t.name, "count"))
	template_prepare_base(&t.template, count)

	error_number: c.int
	error_offset: c.size_t
	pattern := "{{(.*?)}}"
	c_pattern := strings.clone_to_cstring(pattern)
	defer delete(c_pattern)

	t.re = pcre2_compile_8(
		c_pattern,
		c.size_t(len(pattern)),
		PCRE2_UTF | PCRE2_NO_UTF_CHECK,
		&error_number,
		&error_offset,
		nil,
	)

	if t.re != nil {
		pcre2_jit_compile_8(t.re, PCRE2_JIT_COMPLETE)
		t.md = pcre2_match_data_create_from_pattern_8(t.re, nil)
	}
}

template_regex_run :: proc(bench: ^Benchmark, iteration_id: int) {
	t := cast(^TemplateRegex)bench
	template := &t.template

	if t.re == nil || t.md == nil {
		return
	}

	result := strings.builder_make(0, len(template.text))
	defer strings.builder_destroy(&result)

	last_pos: int
	start_offset: c.size_t
	subject := strings.clone_to_cstring(template.text)
	defer delete(subject)
	subject_length := c.size_t(len(template.text))

	for {
		rc := pcre2_jit_match_8(t.re, subject, subject_length, start_offset, 0, t.md, nil)

		if rc < 0 {
			if rc == PCRE2_ERROR_NOMATCH do break
			break
		}

		ovector := pcre2_get_ovector_pointer_8(t.md)
		match_start := int(ovector[0])
		match_end := int(ovector[1])

		if match_start > last_pos {
			strings.write_string(&result, template.text[last_pos:match_start])
		}

		key_start := int(ovector[2])
		key_end := int(ovector[3])

		if key_end > key_start {
			key := template.text[key_start:key_end]
			trimmed := strings.trim_space(key)

			if value, ok := template.vars[trimmed]; ok {
				strings.write_string(&result, value)
			}
		}

		last_pos = match_end
		start_offset = c.size_t(match_end)
	}

	if last_pos < len(template.text) {
		strings.write_string(&result, template.text[last_pos:])
	}

	delete(template.rendered)
	template.rendered = strings.clone(strings.to_string(result))
	template.checksum += u32(len(template.rendered))
}

template_regex_checksum :: proc(bench: ^Benchmark) -> u32 {
	t := cast(^TemplateRegex)bench
	return t.template.checksum + checksum_string(t.template.rendered)
}

template_regex_cleanup :: proc(bench: ^Benchmark) {
	t := cast(^TemplateRegex)bench

	if t.md != nil {
		pcre2_match_data_free_8(t.md)
	}
	if t.re != nil {
		pcre2_code_free_8(t.re)
	}

	delete(t.template.text)
	delete(t.template.rendered)
	delete(t.template.vars)
}

create_template_regex :: proc() -> ^Benchmark {
	bench := new(TemplateRegex)
	bench.name = "Template::Regex"
	bench.vtable = default_vtable()
	bench.template.vars = make(map[string]string)

	bench.vtable.prepare = template_regex_prepare
	bench.vtable.run = template_regex_run
	bench.vtable.checksum = template_regex_checksum
	bench.vtable.cleanup = template_regex_cleanup

	return cast(^Benchmark)bench
}

template_parse_prepare :: proc(bench: ^Benchmark) {
	t := cast(^TemplateParse)bench
	count := int(config_i64(t.name, "count"))
	template_prepare_base(&t.template, count)
}

template_parse_run :: proc(bench: ^Benchmark, iteration_id: int) {
	t := cast(^TemplateParse)bench
	template := &t.template

	result := strings.builder_make(0, int(f64(len(template.text)) * 1.5))
	defer strings.builder_destroy(&result)

	i := 0
	text := template.text
	n := len(text)

	for i < n {
		if i + 1 < n && text[i] == '{' && text[i + 1] == '{' {
			j := i + 2
			for j + 1 < n {
				if text[j] == '}' && text[j + 1] == '}' {
					break
				}
				j += 1
			}

			if j + 1 < n {
				key := text[i + 2:j]
				trimmed := strings.trim_space(key)

				if value, ok := template.vars[trimmed]; ok {
					strings.write_string(&result, value)
				}
				i = j + 2
				continue
			}
		}

		strings.write_byte(&result, text[i])
		i += 1
	}

	delete(template.rendered)
	template.rendered = strings.clone(strings.to_string(result))
	template.checksum += u32(len(template.rendered))
}

template_parse_checksum :: proc(bench: ^Benchmark) -> u32 {
	t := cast(^TemplateParse)bench
	return t.template.checksum + checksum_string(t.template.rendered)
}

template_parse_cleanup :: proc(bench: ^Benchmark) {
	t := cast(^TemplateParse)bench
	delete(t.template.text)
	delete(t.template.rendered)
	delete(t.template.vars)
}

create_template_parse :: proc() -> ^Benchmark {
	bench := new(TemplateParse)
	bench.name = "Template::Parse"
	bench.vtable = default_vtable()
	bench.template.vars = make(map[string]string)

	bench.vtable.prepare = template_parse_prepare
	bench.vtable.run = template_parse_run
	bench.vtable.checksum = template_parse_checksum
	bench.vtable.cleanup = template_parse_cleanup

	return cast(^Benchmark)bench
}
