use super::super::{helper, Benchmark};
use crate::benchmarks::fasta::Fasta;
use crate::config_i64;
use regex::Regex;

pub struct RegexDna {
    seq: String,
    ilen: usize,
    clen: usize,
    result_str: String,
    n: i64,
}

impl RegexDna {
    pub fn new() -> Self {
        let n = config_i64("RegexDna", "n");

        Self {
            n,
            seq: String::new(),
            ilen: 0,
            clen: 0,
            result_str: String::new(),
        }
    }
}

impl Benchmark for RegexDna {
    fn name(&self) -> String {
        "RegexDna".to_string()
    }

    fn prepare(&mut self) {
        let mut fasta = Fasta::new();
        fasta.n = self.n;
        fasta.run(0);
        let res = fasta.get_result();

        let mut seq_buf = String::new();
        self.ilen = 0;

        for line in res.lines() {
            self.ilen += line.len() + 1;
            if !line.starts_with('>') {
                seq_buf.push_str(line.trim());
            }
        }

        self.seq = seq_buf;
        self.clen = self.seq.len();
    }

    fn run(&mut self, _iteration_id: i64) {
        let patterns = [
            (r"agggtaaa|tttaccct", "agggtaaa|tttaccct"),
            (r"[cgt]gggtaaa|tttaccc[acg]", "[cgt]gggtaaa|tttaccc[acg]"),
            (r"a[act]ggtaaa|tttacc[agt]t", "a[act]ggtaaa|tttacc[agt]t"),
            (r"ag[act]gtaaa|tttac[agt]ct", "ag[act]gtaaa|tttac[agt]ct"),
            (r"agg[act]taaa|ttta[agt]cct", "agg[act]taaa|ttta[agt]cct"),
            (r"aggg[acg]aaa|ttt[cgt]ccct", "aggg[acg]aaa|ttt[cgt]ccct"),
            (r"agggt[cgt]aa|tt[acg]accct", "agggt[cgt]aa|tt[acg]accct"),
            (r"agggta[cgt]a|t[acg]taccct", "agggta[cgt]a|t[acg]taccct"),
            (r"agggtaa[cgt]|[acg]ttaccct", "agggtaa[cgt]|[acg]ttaccct"),
        ];

        for (pattern, display) in &patterns {
            let re = Regex::new(pattern).unwrap();
            let count = re.find_iter(&self.seq).count();
            self.result_str
                .push_str(&format!("{} {}\n", display, count));
        }

        let replacements = [
            ("B", "(c|g|t)"),
            ("D", "(a|g|t)"),
            ("H", "(a|c|t)"),
            ("K", "(g|t)"),
            ("M", "(a|c)"),
            ("N", "(a|c|g|t)"),
            ("R", "(a|g)"),
            ("S", "(c|t)"),
            ("V", "(a|c|g)"),
            ("W", "(a|t)"),
            ("Y", "(c|t)"),
        ];

        let mut seq = self.seq.clone();
        for (from, to) in &replacements {
            let re = Regex::new(from).unwrap();
            seq = re.replace_all(&seq, *to).to_string();
        }

        self.result_str.push('\n');
        self.result_str.push_str(&format!("{}\n", self.ilen));
        self.result_str.push_str(&format!("{}\n", self.clen));
        self.result_str.push_str(&format!("{}\n", seq.len()));
    }

    fn checksum(&self) -> u32 {
        helper::checksum_str(&self.result_str)
    }
}
