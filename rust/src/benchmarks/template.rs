use super::super::{helper, Benchmark};
use crate::config_i64;
use once_cell::sync::Lazy;
use regex::Regex;
use std::collections::HashMap;

static FIRST_NAMES: Lazy<Vec<String>> = Lazy::new(|| {
    [
        "John", "Jane", "Bob", "Alice", "Charlie", "Diana", "Sarah", "Mike",
    ]
    .iter()
    .map(|&s| s.to_string())
    .collect()
});

static LAST_NAMES: Lazy<Vec<String>> = Lazy::new(|| {
    [
        "Smith", "Johnson", "Brown", "Taylor", "Wilson", "Davis", "Miller", "Jones",
    ]
    .iter()
    .map(|&s| s.to_string())
    .collect()
});

static CITIES: Lazy<Vec<String>> = Lazy::new(|| {
    [
        "New York",
        "Los Angeles",
        "Chicago",
        "Houston",
        "Phoenix",
        "San Francisco",
    ]
    .iter()
    .map(|&s| s.to_string())
    .collect()
});

static LOREM: &str = "Lorem {ipsum} dolor {sit} amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore {et} dolore magna aliqua. ";

struct TemplateBase {
    count: usize,
    checksum: u32,
    text: String,
    rendered: String,
    vars: HashMap<String, String>,
}

impl TemplateBase {
    fn new(count: usize) -> Self {
        Self {
            count,
            checksum: 0,
            text: String::new(),
            rendered: String::new(),
            vars: HashMap::new(),
        }
    }

    fn prepare(&mut self) {
        let mut text = String::new();
        self.vars.clear();

        text.push_str("<html><body>");
        text.push_str("<h1>{{TITLE}}</h1>");
        self.vars
            .insert("TITLE".to_string(), "Template title".to_string());
        text.push_str("<p>");
        text.push_str(LOREM);
        text.push_str("</p>");
        text.push_str("<table>");

        for i in 0..self.count {
            if i % 3 == 0 {
                text.push_str("<!-- {comment} -->");
            }
            text.push_str("<tr>");
            text.push_str(&format!("<td>{{{{ FIRST_NAME{} }}}}</td>", i));
            text.push_str(&format!("<td>{{{{LAST_NAME{}}}}}</td>", i));
            text.push_str(&format!("<td>{{{{  CITY{}  }}}}</td>", i));

            self.vars.insert(
                format!("FIRST_NAME{}", i),
                FIRST_NAMES[i % FIRST_NAMES.len()].clone(),
            );
            self.vars.insert(
                format!("LAST_NAME{}", i),
                LAST_NAMES[i % LAST_NAMES.len()].clone(),
            );
            self.vars
                .insert(format!("CITY{}", i), CITIES[i % CITIES.len()].clone());

            text.push_str(&format!("<td>{{balance: {}}}</td>", i % 100));
            text.push_str("</tr>\n");
        }

        text.push_str("</table>");
        text.push_str("</body></html>");

        self.text = text;
    }

    fn base_checksum(&self) -> u32 {
        self.checksum
            .wrapping_add(helper::checksum_str(&self.rendered))
    }
}

pub struct TemplateRegex {
    base: TemplateBase,
}

static TEMPLATE_REGEX: Lazy<Regex> = Lazy::new(|| Regex::new(r"\{\{(.*?)\}\}").unwrap());

impl TemplateRegex {
    pub fn new() -> Self {
        let count = config_i64("Template::Regex", "count") as usize;
        Self {
            base: TemplateBase::new(count),
        }
    }
}

impl Benchmark for TemplateRegex {
    fn name(&self) -> String {
        "Template::Regex".to_string()
    }

    fn prepare(&mut self) {
        self.base.prepare();
    }

    fn run(&mut self, _iteration_id: i64) {
        let rendered = TEMPLATE_REGEX.replace_all(&self.base.text, |caps: &regex::Captures| {
            let key = caps.get(1).unwrap().as_str().trim();
            self.base.vars.get(key).map(|s| s.as_str()).unwrap_or("")
        });

        self.base.rendered = rendered.to_string();
        self.base.checksum = self
            .base
            .checksum
            .wrapping_add(self.base.rendered.len() as u32);
    }

    fn checksum(&self) -> u32 {
        self.base.base_checksum()
    }
}

pub struct TemplateParse {
    base: TemplateBase,
}

impl TemplateParse {
    pub fn new() -> Self {
        let count = config_i64("Template::Parse", "count") as usize;
        Self {
            base: TemplateBase::new(count),
        }
    }
}

impl Benchmark for TemplateParse {
    fn name(&self) -> String {
        "Template::Parse".to_string()
    }

    fn prepare(&mut self) {
        self.base.prepare();
    }

    fn run(&mut self, _iteration_id: i64) {
        let text = &self.base.text;
        let bytes = text.as_bytes();
        let len = bytes.len();
        let vars = &self.base.vars;

        let mut rendered = String::with_capacity((len as f64 * 1.5) as usize);
        let mut i = 0;

        while i < len {
            if i + 1 < len && bytes[i] == b'{' && bytes[i + 1] == b'{' {
                let mut j = i + 2;
                while j + 1 < len {
                    if bytes[j] == b'}' && bytes[j + 1] == b'}' {
                        break;
                    }
                    j += 1;
                }

                if j + 1 < len {
                    let key = std::str::from_utf8(&bytes[i + 2..j]).unwrap_or("").trim();
                    if let Some(value) = vars.get(key) {
                        rendered.push_str(value);
                    }
                    i = j + 2;
                    continue;
                }
            }

            rendered.push(bytes[i] as char);
            i += 1;
        }

        self.base.rendered = rendered;
        self.base.checksum = self
            .base
            .checksum
            .wrapping_add(self.base.rendered.len() as u32);
    }

    fn checksum(&self) -> u32 {
        self.base.base_checksum()
    }
}
