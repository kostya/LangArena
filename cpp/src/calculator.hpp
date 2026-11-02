#pragma once

#include "benchmark.hpp"
#include <cstdint>
#include <memory>
#include <string>
#include <unordered_map>
#include <variant>
#include <vector>

class CalculatorAst : public Benchmark {
public:
  struct Number {
    int64_t value;
    Number(int64_t v) : value(v) {}
  };

  struct Variable {
    std::string name;
    Variable(const std::string &n) : name(n) {}
  };

  struct BinaryOp;
  struct Assignment;

  struct Node {
    std::variant<Number, Variable, std::unique_ptr<BinaryOp>,
                 std::unique_ptr<Assignment>>
        data;

    Node(Number n) : data(std::move(n)) {}
    Node(Variable v) : data(std::move(v)) {}
    Node(std::unique_ptr<BinaryOp> b) : data(std::move(b)) {}
    Node(std::unique_ptr<Assignment> a) : data(std::move(a)) {}

    Node(const Node &) = delete;
    Node &operator=(const Node &) = delete;
    Node(Node &&) = default;
    Node &operator=(Node &&) = default;
  };

  struct BinaryOp {
    char op;
    Node left;
    Node right;

    BinaryOp(char o, Node l, Node r)
        : op(o), left(std::move(l)), right(std::move(r)) {}
  };

  struct Assignment {
    std::string var;
    Node expr;

    Assignment(const std::string &v, Node e) : var(v), expr(std::move(e)) {}
  };

private:
  class Parser {
  private:
    static constexpr char CHAR_EOF = '\0';
    static constexpr char CHAR_PLUS = '+';
    static constexpr char CHAR_MINUS = '-';
    static constexpr char CHAR_STAR = '*';
    static constexpr char CHAR_SLASH = '/';
    static constexpr char CHAR_PERCENT = '%';
    static constexpr char CHAR_LPAREN = '(';
    static constexpr char CHAR_RPAREN = ')';
    static constexpr char CHAR_EQUALS = '=';
    static constexpr char CHAR_ZERO = '0';
    static constexpr char CHAR_NINE = '9';
    static constexpr char CHAR_A_LOWER = 'a';
    static constexpr char CHAR_Z_LOWER = 'z';
    static constexpr char CHAR_A_UPPER = 'A';
    static constexpr char CHAR_Z_UPPER = 'Z';
    static constexpr char CHAR_SPACE = ' ';
    static constexpr char CHAR_TAB = '\t';
    static constexpr char CHAR_NEWLINE = '\n';
    static constexpr char CHAR_CR = '\r';

    const std::string &input;
    size_t pos;
    size_t len;
    char current_char;
    std::vector<Node> expressions;

    void advance();
    void skip_whitespace();
    Node parse_number();
    Node parse_variable();
    Node parse_factor();
    Node parse_term();
    Node parse_expression();

    bool is_digit(char c) const { return c >= CHAR_ZERO && c <= CHAR_NINE; }

    bool is_letter(char c) const {
      return (c >= CHAR_A_LOWER && c <= CHAR_Z_LOWER) ||
             (c >= CHAR_A_UPPER && c <= CHAR_Z_UPPER);
    }

    bool is_whitespace(char c) const {
      return c == CHAR_SPACE || c == CHAR_TAB || c == CHAR_NEWLINE ||
             c == CHAR_CR;
    }

  public:
    Parser(const std::string &input_str);
    std::vector<Node> parse();
  };

  uint32_t result_val;
  std::string text;

  std::string generate_random_program(int64_t n = 1000);

public:
  int64_t n;
  CalculatorAst();

  std::string name() const override;
  std::vector<Node> expressions;

  void prepare() override;
  void run(int) override;
  uint32_t checksum() override;

  std::vector<Node> take_ast() { return std::move(expressions); }
};

class CalculatorInterpreter : public Benchmark {
private:
  class Interpreter {
  private:
    std::unordered_map<std::string, int64_t> variables;

    static int64_t simple_div(int64_t a, int64_t b);
    static int64_t simple_mod(int64_t a, int64_t b);

    struct Evaluator {
      std::unordered_map<std::string, int64_t> &variables;

      Evaluator(std::unordered_map<std::string, int64_t> &vars)
          : variables(vars) {}

      int64_t operator()(const CalculatorAst::Number &n) const;
      int64_t operator()(const CalculatorAst::Variable &v) const;
      int64_t
      operator()(const std::unique_ptr<CalculatorAst::BinaryOp> &binop) const;
      int64_t operator()(
          const std::unique_ptr<CalculatorAst::Assignment> &assign) const;
    };

  public:
    int64_t run(const std::vector<CalculatorAst::Node> &expressions);
    void clear() { variables.clear(); }
  };

  int64_t n;
  uint32_t result_val;
  std::vector<CalculatorAst::Node> ast;

public:
  CalculatorInterpreter();

  std::string name() const override;
  void prepare() override;
  void run(int) override;
  uint32_t checksum() override;
};