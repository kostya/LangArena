namespace template;

import std;
import dictionary;
import bench;
import helper;
import regex;

let FIRST_NAMES = ["John", "Jane", "Bob", "Alice", "Charlie", "Diana", "Sarah", "Mike"];
let LAST_NAMES = ["Smith", "Johnson", "Brown", "Taylor", "Wilson", "Davis", "Miller", "Jones"];
let CITIES = ["New York", "Los Angeles", "Chicago", "Houston", "Phoenix", "San Francisco"];
let LOREM = "Lorem {ipsum} dolor {sit} amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore {et} dolore magna aliqua. ";

type Vars = dictionary<const u8[:], const u8[:]>;

struct TemplateBase {
    count: i64,
    checksum: u32,
    text: u8[>..]&,
    keys: u8[>..]&,
    vars: Vars&,
    rendered: u8[>..],
}

fn new_base(count: i64, text: u8[>..]&, keys: u8[>..]&, vars: Vars&) -> TemplateBase {
    TemplateBase { count: count, checksum: 0, text: text, keys: keys, vars: vars, rendered: [] }
}

fn key(keys: u8[>..]&, prefix: u8[:], i: i64) -> const u8[:] {
    let start = keys.len;
    format(keys, prefix, i);
    return keys[start..];
}

fn prepare(base: TemplateBase&) {
    let text = base.text;
    let keys = base.keys;
    let vars = base.vars;
    vars.clear();
    text.append("<html><body>");
    text.append("<h1>{{TITLE}}</h1>");
    vars.insert("TITLE", "Template title");
    text.append("<p>");
    text.append(LOREM);
    text.append("</p>");
    text.append("<table>");
    for i in base.count {
        if i % 3 == 0 { text.append("<!-- {comment} -->"); }
        text.append("<tr>");
        format(text, "<td>{{ FIRST_NAME", i, " }}</td>");
        format(text, "<td>{{LAST_NAME", i, "}}</td>");
        format(text, "<td>{{  CITY", i, "  }}</td>");
        vars.insert(key(keys, "FIRST_NAME", i), FIRST_NAMES[i % FIRST_NAMES.len]);
        vars.insert(key(keys, "LAST_NAME", i), LAST_NAMES[i % LAST_NAMES.len]);
        vars.insert(key(keys, "CITY", i), CITIES[i % CITIES.len]);
        format(text, "<td>{balance: ", i % 100, "}</td>");
        text.append("</tr>\n");
    }
    text.append("</table>");
    text.append("</body></html>");
}

fn base_checksum(base: TemplateBase&) -> u32 { base.checksum + checksum_str(base.rendered) }

let TEMPLATE_REGEX = regex::compile("""\{\{(.*?)\}\}""");

struct TemplateRegex { base: TemplateBase }

fn new_template_regex(text: u8[>..]&, keys: u8[>..]&, vars: Vars&) -> TemplateRegex {
    TemplateRegex { base: new_base(config_i64("Template::Regex", "count"), text, keys, vars) }
}

fn prepare(s: TemplateRegex&) { s.base.prepare(); }

fn run(s: TemplateRegex&, iteration_id: i64) {
    var rendered: u8[>..] = [];
    regex::format_replaced(rendered, TEMPLATE_REGEX, s.base.text) { caps =>
        let value = s.base.vars.get(trim(regex::group(caps, 1)));
        if value { value } else { "" }
    };

    s.base.rendered = copy(rendered);
    s.base.checksum += s.base.rendered.len as! u32;
}

fn checksum(s: TemplateRegex&) -> u32 { s.base.base_checksum() }

fn execute_regex(b: Bench&) -> u32 {
    var text: u8[>..] = [];
    var keys: u8[>..] = [];
    var vars = Vars {};
    var s = new_template_regex(text, keys, vars);
    return execute(b, s, prepare, run, checksum);
}

struct TemplateParse { base: TemplateBase }

fn new_template_parse(text: u8[>..]&, keys: u8[>..]&, vars: Vars&) -> TemplateParse {
    TemplateParse { base: new_base(config_i64("Template::Parse", "count"), text, keys, vars) }
}

fn prepare(s: TemplateParse&) { s.base.prepare(); }

fn run(s: TemplateParse&, iteration_id: i64) {
    let text = s.base.text;
    let len = text.len;
    let vars = s.base.vars;
    var rendered: u8[>..] = [];
    var i = 0;
    while i < len {
        if i + 1 < len && text[i] == '{' && text[i + 1] == '{' {
            var j = i + 2;
            while j + 1 < len {
                if text[j] == '}' && text[j + 1] == '}' { break; }
                j++;
            }
            if j + 1 < len {
                let value = vars.get(trim(text[i + 2..j]));
                if value { rendered.append(value); }
                i = j + 2;
                continue;
            }
        }
        rendered.push(text[i]);
        i++;
    }

    s.base.rendered = copy(rendered);
    s.base.checksum += s.base.rendered.len as! u32;
}

fn checksum(s: TemplateParse&) -> u32 { s.base.base_checksum() }

fn execute_parse(b: Bench&) -> u32 {
    var text: u8[>..] = [];
    var keys: u8[>..] = [];
    var vars = Vars {};
    var s = new_template_parse(text, keys, vars);
    return execute(b, s, prepare, run, checksum);
}