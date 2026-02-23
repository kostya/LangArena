use super::super::Benchmark;
use crate::benchmarks::calculator_ast::{CalculatorAst, Node};
use crate::config_i64;
use std::collections::HashMap;

pub struct CalculatorInterpreter {
    n: i64,
    ast: Vec<Node>,
    result_val: u32,
}

impl CalculatorInterpreter {
    pub fn new() -> Self {
        let n = config_i64("Calculator::Interpreter", "operations");

        Self {
            n,
            ast: Vec::new(),
            result_val: 0,
        }
    }

    fn simple_div(a: i64, b: i64) -> i64 {
        if b == 0 {
            return 0;
        }

        if (a >= 0 && b > 0) || (a < 0 && b < 0) {
            a / b
        } else {
            -(a.abs() / b.abs())
        }
    }

    fn simple_mod(a: i64, b: i64) -> i64 {
        if b == 0 {
            return 0;
        }
        a - Self::simple_div(a, b) * b
    }
}

impl Benchmark for CalculatorInterpreter {
    fn name(&self) -> String {
        "Calculator::Interpreter".to_string()
    }

    fn prepare(&mut self) {
        let mut ast_bench = CalculatorAst::new();
        ast_bench.n = self.n;
        ast_bench.prepare();
        ast_bench.run(0);
        self.ast = ast_bench.expressions().to_vec();
    }

    fn run(&mut self, _iteration_id: i64) {
        struct Interpreter {
            variables: HashMap<String, i64>,
        }

        impl Interpreter {
            fn new() -> Self {
                Self {
                    variables: HashMap::new(),
                }
            }

            fn evaluate(&mut self, node: &Node) -> i64 {
                match node {
                    Node::Number(n) => *n,
                    Node::Variable(name) => *self.variables.get(name).unwrap_or(&0),
                    Node::BinaryOp(op, left, right) => {
                        let left_val = self.evaluate(left);
                        let right_val = self.evaluate(right);

                        match op {
                            '+' => left_val.wrapping_add(right_val),
                            '-' => left_val.wrapping_sub(right_val),
                            '*' => left_val.wrapping_mul(right_val),
                            '/' => CalculatorInterpreter::simple_div(left_val, right_val),
                            '%' => CalculatorInterpreter::simple_mod(left_val, right_val),
                            _ => 0,
                        }
                    }
                    Node::Assignment(var, expr) => {
                        let value = self.evaluate(expr);
                        self.variables.insert(var.clone(), value);
                        value
                    }
                }
            }

            fn run(&mut self, expressions: &[Node]) -> i64 {
                let mut result = 0;
                for expr in expressions {
                    result = self.evaluate(expr);
                }
                result
            }
        }

        let mut interpreter = Interpreter::new();
        let result = interpreter.run(&self.ast);
        self.result_val = self.result_val.wrapping_add(result as u32);
    }

    fn checksum(&self) -> u32 {
        self.result_val
    }
}
