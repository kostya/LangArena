use super::super::{helper, Benchmark};
use crate::config_i64;
use once_cell::sync::Lazy;
use regex::Regex;

pub struct LogParser {
    lines_count: usize,
    log: String,
    checksum_val: u32,
}

static PATTERNS: Lazy<Vec<(&'static str, Regex)>> = Lazy::new(|| {
    vec![
        ("errors", Regex::new(" [5][0-9]{2} ").unwrap()),
        ("bots", Regex::new("(?i)bot|crawler|scanner").unwrap()),
        (
            "suspicious",
            Regex::new("(?i)etc/passwd|wp-admin|\\.\\./").unwrap(),
        ),
        (
            "ips",
            Regex::new("\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.35").unwrap(),
        ),
        ("api_calls", Regex::new("/api/[^ \"]+").unwrap()),
        ("post_requests", Regex::new("POST [^ ]* HTTP").unwrap()),
        ("auth_attempts", Regex::new("(?i)/login|/signin").unwrap()),
        ("methods", Regex::new("(?i)get|post").unwrap()),
    ]
});

static IPS: Lazy<Vec<String>> =
    Lazy::new(|| (1..=255).map(|i| format!("192.168.1.{}", i)).collect());

static METHODS: [&str; 4] = ["GET", "POST", "PUT", "DELETE"];
static PATHS: [&str; 7] = [
    "/index.html",
    "/api/users",
    "/login",
    "/admin",
    "/images/logo.png",
    "/etc/passwd",
    "/wp-admin/setup.php",
];
static STATUSES: [i32; 11] = [200, 201, 301, 302, 400, 401, 403, 404, 500, 502, 503];
static AGENTS: [&str; 4] = ["Mozilla/5.0", "Googlebot/2.1", "curl/7.68.0", "scanner/2.0"];

impl LogParser {
    pub fn new() -> Self {
        let lines_count = config_i64("Etc::LogParser", "lines_count") as usize;

        Self {
            lines_count,
            log: String::new(),
            checksum_val: 0,
        }
    }

    fn generate_log_line(&self, i: usize) -> String {
        format!(
            "{0} - - [{1}/Oct/2023:13:55:36 +0000] \"{2} {3} HTTP/1.0\" {4} 2326 \"-\" \"{5}\"\n",
            IPS[i % IPS.len()],
            i % 31,
            METHODS[i % METHODS.len()],
            PATHS[i % PATHS.len()],
            STATUSES[i % STATUSES.len()],
            AGENTS[i % AGENTS.len()]
        )
    }
}

impl Benchmark for LogParser {
    fn name(&self) -> String {
        "Etc::LogParser".to_string()
    }

    fn prepare(&mut self) {
        let mut log_buf = String::with_capacity(self.lines_count * 150);
        for i in 0..self.lines_count {
            log_buf.push_str(&self.generate_log_line(i));
        }
        self.log = log_buf;
    }

    fn run(&mut self, _iteration_id: i64) {
        let mut matches = std::collections::HashMap::new();

        for (name, regex) in PATTERNS.iter() {
            let count = regex.find_iter(&self.log).count();
            matches.insert(*name, count);
        }

        let total: u32 = matches.values().sum::<usize>() as u32;
        self.checksum_val = self.checksum_val.wrapping_add(total);
    }

    fn checksum(&self) -> u32 {
        self.checksum_val
    }
}
