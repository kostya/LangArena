use super::super::{helper, Benchmark};
use crate::config_i64;

#[derive(Clone)]
pub enum Node {
    Number(i64),
    Variable(String),
    BinaryOp(char, Box<Node>, Box<Node>),
    Assignment(String, Box<Node>),
}

pub struct CalculatorAst {
    pub(crate) n: i64,
    result_val: u32,
    text: String,
    expressions: Vec<Node>,
}

impl CalculatorAst {
    pub fn new() -> Self {
        let n = config_i64("Calculator::Ast", "operations");

        Self {
            n,
            result_val: 0,
            text: String::new(),
            expressions: Vec::new(),
        }
    }

    pub fn expressions(&self) -> &[Node] {
        &self.expressions
    }

    fn generate_random_program(&self, n: i64) -> String {
        let mut result = String::new();
        result.push_str("v0 = 1\n");

        for i in 0..10 {
            let v = i + 1;
            result.push_str(&format!("v{} = v{} + {}\n", v, v - 1, v));
        }

        for i in 0..n {
            let v = i + 10;
            result.push_str(&format!("v{} = v{} + ", v, v - 1));

            match helper::next_int(10) {
                0 => {
                    result.push_str(&format!(
                        "(v{} / 3) * 4 - {} / (3 + (18 - v{})) % v{} + 2 * ((9 - v{}) * (v{} + 7))",
                        v - 1,
                        i,
                        v - 2,
                        v - 3,
                        v - 6,
                        v - 5
                    ));
                }
                1 => {
                    result.push_str(&format!(
                        "v{} + (v{} + v{}) * v{} - (v{} / v{})",
                        v - 1,
                        v - 2,
                        v - 3,
                        v - 4,
                        v - 5,
                        v - 6
                    ));
                }
                2 => {
                    result.push_str(&format!("(3789 - (((v{})))) + 1", v - 7));
                }
                3 => {
                    result.push_str(&format!("4/2 * (1-3) + v{}/v{}", v - 9, v - 5));
                }
                4 => {
                    result.push_str(&format!("1+2+3+4+5+6+v{}", v - 1));
                }
                5 => {
                    result.push_str(&format!("(99999 / v{})", v - 3));
                }
                6 => {
                    result.push_str(&format!("0 + 0 - v{}", v - 8));
                }
                7 => {
                    result.push_str(&format!("((((((((((v{})))))))))) * 2", v - 6));
                }
                8 => {
                    result.push_str(&format!("{} * (v{}%6)%7", i, v - 1));
                }
                9 => {
                    result.push_str(&format!("(1)/(0-v{}) + (v{})", v - 5, v - 7));
                }
                _ => unreachable!(),
            }

            result.push('\n');
        }

        result
    }
}

impl Benchmark for CalculatorAst {
    fn name(&self) -> String {
        "Calculator::Ast".to_string()
    }

    fn prepare(&mut self) {
        self.text = self.generate_random_program(self.n);
    }

    fn run(&mut self, _iteration_id: i64) {
        let mut parser = Parser::new(&self.text);
        parser.parse();
        self.expressions = parser.expressions;
        self.result_val = self.result_val.wrapping_add(self.expressions.len() as u32);

        if let Some(Node::Assignment(var, _)) = self.expressions.last() {
            self.result_val = self.result_val.wrapping_add(helper::checksum_str(var));
        }
    }

    fn checksum(&self) -> u32 {
        self.result_val
    }
}

struct Parser {
    chars: Vec<char>,
    pos: usize,
    current_char: char,
    expressions: Vec<Node>,
}

impl Parser {
    fn new(input: &str) -> Self {
        let chars: Vec<char> = input.chars().collect();
        let current_char = if chars.is_empty() { '\0' } else { chars[0] };

        Self {
            chars,
            pos: 0,
            current_char,
            expressions: Vec::new(),
        }
    }

    fn parse(&mut self) -> Vec<Node> {
        while self.pos < self.chars.len() {
            self.skip_whitespace();
            if self.pos >= self.chars.len() {
                break;
            }

            let expr = self.parse_expression();
            self.expressions.push(expr);

            self.skip_whitespace();

            while self.pos < self.chars.len()
                && (self.current_char == '\n' || self.current_char == ';')
            {
                self.advance();
                self.skip_whitespace();
            }
        }

        self.expressions.clone()
    }

    fn parse_expression(&mut self) -> Node {
        let node = self.parse_term();
        self.parse_expression_rest(node)
    }

    fn parse_expression_rest(&mut self, left_node: Node) -> Node {
        let mut current_node = left_node;

        while self.pos < self.chars.len() {
            self.skip_whitespace();
            if self.pos >= self.chars.len() {
                break;
            }

            if self.current_char == '+' || self.current_char == '-' {
                let op = self.current_char;
                self.advance();
                let right = self.parse_term();
                current_node = Node::BinaryOp(op, Box::new(current_node), Box::new(right));
            } else {
                break;
            }
        }

        current_node
    }

    fn parse_term(&mut self) -> Node {
        let node = self.parse_factor();
        self.parse_term_rest(node)
    }

    fn parse_term_rest(&mut self, left_node: Node) -> Node {
        let mut current_node = left_node;

        while self.pos < self.chars.len() {
            self.skip_whitespace();
            if self.pos >= self.chars.len() {
                break;
            }

            if self.current_char == '*' || self.current_char == '/' || self.current_char == '%' {
                let op = self.current_char;
                self.advance();
                let right = self.parse_factor();
                current_node = Node::BinaryOp(op, Box::new(current_node), Box::new(right));
            } else {
                break;
            }
        }

        current_node
    }

    fn parse_factor(&mut self) -> Node {
        self.skip_whitespace();
        if self.pos >= self.chars.len() {
            return Node::Number(0);
        }

        match self.current_char {
            '0'..='9' => self.parse_number(),
            'a'..='z' => self.parse_variable(),
            '(' => {
                self.advance();
                let node = self.parse_expression();
                self.skip_whitespace();
                if self.current_char == ')' {
                    self.advance();
                }
                node
            }
            _ => Node::Number(0),
        }
    }

    fn parse_number(&mut self) -> Node {
        let start = self.pos;
        while self.pos < self.chars.len() && self.current_char.is_ascii_digit() {
            self.advance();
        }

        let num_str: String = self.chars[start..self.pos].iter().collect();
        match num_str.parse::<i64>() {
            Ok(n) => Node::Number(n),
            Err(_) => Node::Number(0),
        }
    }

    fn parse_variable(&mut self) -> Node {
        let start = self.pos;
        while self.pos < self.chars.len()
            && (self.current_char.is_ascii_lowercase() || self.current_char.is_ascii_digit())
        {
            self.advance();
        }

        let var_name: String = self.chars[start..self.pos].iter().collect();

        self.skip_whitespace();
        if self.current_char == '=' {
            self.advance();
            let expr = self.parse_expression();
            return Node::Assignment(var_name, Box::new(expr));
        }

        Node::Variable(var_name)
    }

    fn advance(&mut self) {
        self.pos += 1;
        if self.pos >= self.chars.len() {
            self.current_char = '\0';
        } else {
            self.current_char = self.chars[self.pos];
        }
    }

    fn skip_whitespace(&mut self) {
        while self.pos < self.chars.len() && self.current_char.is_ascii_whitespace() {
            self.advance();
        }
    }
}
