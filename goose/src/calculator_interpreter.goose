namespace calculator_interpreter;

import std;
import dictionary;
import bench;
import calculator_ast;

fn wrapping_add(a: i64, b: i64) -> i64 { (a as! u64 + b as! u64) as! i64 }
fn wrapping_sub(a: i64, b: i64) -> i64 { (a as! u64 - b as! u64) as! i64 }
fn wrapping_mul(a: i64, b: i64) -> i64 { (a as! u64 * b as! u64) as! i64 }

fn simple_div(a: i64, b: i64) -> i64 {
    if b == 0 { return 0; }
    if (a >= 0 && b > 0) || (a < 0 && b < 0) { return a / b; }
    return -(abs(a) / abs(b));
}

fn simple_mod(a: i64, b: i64) -> i64 {
    if b == 0 { return 0; }
    return a - simple_div(a, b) * b;
}

struct Interpreter { variables: dictionary<const u8[:], i64> }

fn new_interpreter() -> Interpreter {
    return Interpreter { variables: dictionary<const u8[:], i64> {} };
}

recursive fn evaluate(interp: Interpreter&, node: calculator_ast::Node..&) -> i64 {
    match node {
        Number &n => n.value,
        Variable &v => {
            let value = interp.variables.get(v.name);
            if value { value } else { 0 }
        },
        BinaryOp &op => {
            let left_val = interp.evaluate(op.left);
            let right_val = interp.evaluate(op.right);
            match op.op {
                '+' => wrapping_add(left_val, right_val),
                '-' => wrapping_sub(left_val, right_val),
                '*' => wrapping_mul(left_val, right_val),
                '/' => simple_div(left_val, right_val),
                '%' => simple_mod(left_val, right_val),
                _ => 0,
            }
        },
        Assignment &a => {
            let value = interp.evaluate(a.expr);
            interp.variables.insert(a.name, value);
            value
        },
    }
}

fn run(interp: Interpreter&, expressions: (calculator_ast::Node..&)[:]) -> i64 {
    var result = 0;
    for expr in expressions { result = interp.evaluate(expr); }
    return result;
}

struct CalculatorInterpreter {
    n: i64,
    result_val: u32,
    text: u8[>..]&,
    nodes: calculator_ast::Node..[>..]&,
    ast: (calculator_ast::Node..&)[>..],
}

fn new_calculator_interpreter(text: u8[>..]&, nodes: calculator_ast::Node..[>..]&) -> CalculatorInterpreter {
    CalculatorInterpreter { n: config_i64("Calculator::Interpreter", "operations"), result_val: 0,
                            text: text, nodes: nodes, ast: [] }
}

fn prepare(s: CalculatorInterpreter&) {
    var ast_bench = calculator_ast::new_calculator_ast(s.text, s.nodes);
    ast_bench.n = s.n;
    calculator_ast::prepare(ast_bench);
    s.ast = [];
    calculator_ast::run(ast_bench, 0);
    s.ast = copy(ast_bench.expressions);
}

fn run(s: CalculatorInterpreter&, iteration_id: i64) {
    var interpreter = new_interpreter();
    let result = interpreter.run(s.ast);
    s.result_val += result as! u32;
}

fn checksum(s: CalculatorInterpreter&) -> u32 { s.result_val }