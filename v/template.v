module template

import benchmark
import helper
import strings
import srackham.pcre2

const first_names = ['John', 'Jane', 'Bob', 'Alice', 'Charlie', 'Diana', 'Sarah', 'Mike']
const last_names = ['Smith', 'Johnson', 'Brown', 'Taylor', 'Wilson', 'Davis', 'Miller', 'Jones']
const cities = ['New York', 'Los Angeles', 'Chicago', 'Houston', 'Phoenix', 'San Francisco']
const lorem = 'Lorem {ipsum} dolor {sit} amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore {et} dolore magna aliqua. '

struct TemplateData {
mut:
	count        int
	checksum_val u32
	text         string
	rendered     string
	vars         map[string]string
}

fn prepare_template_data(mut data TemplateData) {
	mut text_builder := strings.new_builder(data.count * 200)
	data.vars.clear()

	text_builder.write_string('<html><body>')
	text_builder.write_string('<h1>{{TITLE}}</h1>')
	data.vars['TITLE'] = 'Template title'
	text_builder.write_string('<p>')
	text_builder.write_string(lorem)
	text_builder.write_string('</p>')
	text_builder.write_string('<table>')

	for i in 0 .. data.count {
		if i % 3 == 0 {
			text_builder.write_string('<!-- {comment} -->')
		}
		text_builder.write_string('<tr>')
		text_builder.write_string('<td>{{ FIRST_NAME${i} }}</td>')
		text_builder.write_string('<td>{{LAST_NAME${i}}}</td>')
		text_builder.write_string('<td>{{  CITY${i}  }}</td>')

		data.vars['FIRST_NAME${i}'] = first_names[i % first_names.len]
		data.vars['LAST_NAME${i}'] = last_names[i % last_names.len]
		data.vars['CITY${i}'] = cities[i % cities.len]

		text_builder.write_string('<td>{balance: ${i % 100}}</td>')
		text_builder.write_string('</tr>\n')
	}

	text_builder.write_string('</table>')
	text_builder.write_string('</body></html>')

	data.text = text_builder.str()
}

pub struct TemplateRegex {
	benchmark.BaseBenchmark
mut:
	data TemplateData
	re   pcre2.Regex
}

pub fn new_template_regex() &benchmark.IBenchmark {
	re := pcre2.compile(r'{{(.*?)}}') or {
		println('Failed to compile regex: ${err}')
		return unsafe { nil }
	}

	count := int(helper.config_i64('Template::Regex', 'count'))
	mut bench := &TemplateRegex{
		BaseBenchmark: benchmark.new_base_benchmark('Template::Regex')
		data:          TemplateData{
			count:        count
			checksum_val: 0
			text:         ''
			rendered:     ''
			vars:         map[string]string{}
		}
		re:            re
	}
	return bench
}

pub fn (b TemplateRegex) name() string {
	return 'Template::Regex'
}

pub fn (mut t TemplateRegex) prepare() {
	prepare_template_data(mut t.data)
}

pub fn (mut t TemplateRegex) run(iteration_id int) {
	mut result := strings.new_builder(t.data.text.len)

	mut last_pos := 0

	matches := t.re.find_all(t.data.text)

	for i in 0 .. matches.len {
		match_str := matches[i]

		start_pos_opt := t.data.text.index_after(match_str, last_pos)
		if start_pos_opt == none {
			continue
		}
		start_pos := start_pos_opt or { 0 }

		if start_pos > last_pos {
			result.write_string(t.data.text[last_pos..start_pos])
		}

		key := match_str[2..match_str.len - 2].trim_space()
		if value := t.data.vars[key] {
			result.write_string(value)
		}

		last_pos = start_pos + match_str.len
	}

	if last_pos < t.data.text.len {
		result.write_string(t.data.text[last_pos..])
	}

	t.data.rendered = result.str()
	t.data.checksum_val += u32(t.data.rendered.len)
}

pub fn (mut t TemplateRegex) checksum() u32 {
	return t.data.checksum_val + helper.checksum_str(t.data.rendered)
}

pub struct TemplateParse {
	benchmark.BaseBenchmark
mut:
	data TemplateData
}

pub fn new_template_parse() &benchmark.IBenchmark {
	count := int(helper.config_i64('Template::Parse', 'count'))
	mut bench := &TemplateParse{
		BaseBenchmark: benchmark.new_base_benchmark('Template::Parse')
		data:          TemplateData{
			count:        count
			checksum_val: 0
			text:         ''
			rendered:     ''
			vars:         map[string]string{}
		}
	}
	return bench
}

pub fn (b TemplateParse) name() string {
	return 'Template::Parse'
}

pub fn (mut t TemplateParse) prepare() {
	prepare_template_data(mut t.data)
}

pub fn (mut t TemplateParse) run(iteration_id int) {
	len := t.data.text.len
	mut result := strings.new_builder(int(f64(len) * 1.5))

	mut i := 0
	for i < len {
		if i + 1 < len && t.data.text[i] == `{` && t.data.text[i + 1] == `{` {
			mut j := i + 2
			for j + 1 < len {
				if t.data.text[j] == `}` && t.data.text[j + 1] == `}` {
					break
				}
				j++
			}

			if j + 1 < len {
				key := t.data.text[i + 2..j].trim_space()
				if value := t.data.vars[key] {
					result.write_string(value)
				}
				i = j + 2
				continue
			}
		}

		result.write_byte(t.data.text[i])
		i++
	}

	t.data.rendered = result.str()
	t.data.checksum_val += u32(t.data.rendered.len)
}

pub fn (mut t TemplateParse) checksum() u32 {
	return t.data.checksum_val + helper.checksum_str(t.data.rendered)
}
