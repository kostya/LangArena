#include "json.hpp"
#include <algorithm>
#include <array>
#include <barrier>
#include <bitset>
#include <chrono>
#include <cmath>
#include <complex>
#include <coroutine>
#include <cstdint>
#include <cstring>
#include <deque>
#include <filesystem>
#include <fstream>
#include <functional>
#include <future>
#include <iomanip>
#include <iostream>
#include <latch>
#include <list>
#include <map>
#include <memory>
#include <optional>
#include <queue>
#include <random>
#include <ranges>
#include <regex>
#include <semaphore>
#include <sstream>
#include <stack>
#include <string>
#include <thread>
#include <unordered_map>
#include <unordered_set>
#include <variant>
#include <vector>

#include "simdjson.h"
#include <re2/re2.h>

namespace fs = std::filesystem;
using json = nlohmann::json;

json CONFIG;

void load_config(const std::string &filename = "../test.js") {
  std::ifstream file(filename);
  if (!file.is_open()) {
    std::cerr << "Cannot open config file: " << filename << std::endl;
    return;
  }

  try {
    file >> CONFIG;
  } catch (const std::exception &e) {
    std::cerr << "Error parsing JSON config: " << e.what() << std::endl;
    CONFIG = json::object();
  }
}

class Helper {
private:
  static const int64_t IM = 139968;
  static const int64_t IA = 3877;
  static const int64_t IC = 29573;

  static thread_local int64_t last;

public:
  static void reset() { last = 42; }

  static int32_t next_int(int32_t max) {
    last = (last * IA + IC) % IM;
    return static_cast<int32_t>((last * max) / IM);
  }

  static int32_t next_int(int32_t from, int32_t to) {
    return next_int(to - from + 1) + from;
  }

  static double next_float(double max = 1.0) {
    last = (last * IA + IC) % IM;
    return max * static_cast<double>(last) / IM;
  }

  static uint32_t checksum(const std::string &v) {
    uint32_t hash = 5381;
    for (char c : v) {
      hash = ((hash << 5) + hash) + static_cast<uint8_t>(c);
    }
    return hash;
  }

  static uint32_t checksum(const std::vector<uint8_t> &v) {
    uint32_t hash = 5381;
    for (uint8_t byte : v) {
      hash = ((hash << 5) + hash) + byte;
    }
    return hash;
  }

  static uint32_t checksum_f64(double v) {
    std::ostringstream oss;
    oss << std::fixed << std::setprecision(7) << v;
    return Helper::checksum(oss.str());
  }

  static int64_t config_i64(const std::string &class_name,
                            const std::string &field_name) {
    try {
      if (CONFIG.contains(class_name) &&
          CONFIG[class_name].contains(field_name)) {
        return CONFIG[class_name][field_name].get<int64_t>();
      } else {
        throw std::runtime_error("Config not found for " + class_name +
                                 ", field: " + field_name);
      }
    } catch (const std::exception &e) {
      std::cerr << e.what() << std::endl;
      return 0;
    }
  }

  static std::string config_s(const std::string &class_name,
                              const std::string &field_name) {
    try {
      if (CONFIG.contains(class_name) &&
          CONFIG[class_name].contains(field_name)) {
        return CONFIG[class_name][field_name].get<std::string>();
      } else {
        throw std::runtime_error("Config not found for " + class_name +
                                 ", field: " + field_name);
      }
    } catch (const std::exception &e) {
      std::cerr << e.what() << std::endl;
      return "";
    }
  }
};

thread_local int64_t Helper::last = 42;

class Benchmark {
public:
  virtual ~Benchmark() = default;
  virtual void run(int iteration_id) = 0;
  virtual uint32_t checksum() = 0;

  virtual void prepare() {}
  virtual std::string name() const = 0;

  int64_t warmup_iterations() {
    if (CONFIG.contains(name()) &&
        CONFIG[name()].contains("warmup_iterations")) {
      return CONFIG[name()]["warmup_iterations"].get<int64_t>();
    } else {
      int64_t iters = iterations();
      return std::max<int64_t>(static_cast<int64_t>(iters * 0.2), 1LL);
    }
  }

  virtual void warmup() {
    int64_t prepare_iters = warmup_iterations();
    for (int64_t i = 0; i < prepare_iters; i++) {
      this->run(i);
    }
  }

  void run_all() {
    int64_t iters = iterations();
    for (int64_t i = 0; i < iters; i++) {
      this->run(i);
    }
  }

  int64_t config_val(const std::string &field_name) const {
    return Helper::config_i64(this->name(), field_name);
  }

  int64_t iterations() const { return config_val("iterations"); }

  int64_t expected_checksum() const { return config_val("checksum"); }

  static void all(const std::string &single_bench = "");
};

double custom_round(double value, int32_t precision) {
  if (std::isnan(value) || std::isinf(value)) {
    return value;
  }

  double factor = std::pow(10.0, precision);
  double scaled = value * factor;

  double fraction = scaled - std::floor(scaled);

  if (std::abs(fraction) < 0.5) {
    return std::floor(scaled) / factor;
  } else if (std::abs(fraction) > 0.5) {
    return std::ceil(scaled) / factor;
  } else {

    return (std::round(scaled / 2.0) * 2.0) / factor;
  }
}

#include <gmpxx.h>

class Pidigits : public Benchmark {
private:
  int32_t nn;
  std::ostringstream result_stream;

public:
  Pidigits() : nn(static_cast<int32_t>(config_val("amount"))) {
    result_stream.str("");
    result_stream.clear();
  }

  std::string name() const override { return "CLBG::Pidigits"; }

  void run(int iteration_id) override {
    int i = 0;
    int k = 0;
    mpz_class ns = 0;
    mpz_class a = 0;
    mpz_class t = 0;
    mpz_class u = 0;
    int k1 = 1;
    mpz_class n = 1;
    mpz_class d = 1;

    while (true) {
      k += 1;
      t = n * 2;
      n *= k;
      k1 += 2;
      a = (a + t) * k1;
      d *= k1;

      if (a >= n) {
        mpz_class temp = n * 3 + a;
        mpz_class q = temp / d;
        u = temp % d;
        u += n;

        if (d > u) {
          ns = ns * 10 + q;
          i += 1;

          if (i % 10 == 0) {
            std::string ns_str = ns.get_str();
            if (ns_str.size() < 10) {
              ns_str = std::string(10 - ns_str.size(), '0') + ns_str;
            }
            result_stream << ns_str << "\t:" << i << "\n";
            ns = 0;
          }

          if (i >= nn)
            break;

          a = (a - (d * q)) * 10;
          n *= 10;
        }
      }
    }
  }

  uint32_t checksum() override { return Helper::checksum(result_stream.str()); }
};

class BinarytreesObj : public Benchmark {
private:
  struct TreeNode {
    std::unique_ptr<TreeNode> left;
    std::unique_ptr<TreeNode> right;
    int item;

    TreeNode(int item, int depth = 0) : item(item) {
      if (depth > 0) {

        left = std::make_unique<TreeNode>(item - (1 << (depth - 1)), depth - 1);
        right =
            std::make_unique<TreeNode>(item + (1 << (depth - 1)), depth - 1);
      }
    }

    uint32_t sum() const {
      uint32_t total = static_cast<uint32_t>(item) + 1;
      if (left)
        total += left->sum();
      if (right)
        total += right->sum();
      return total;
    }
  };

  int64_t n;
  uint32_t result_val;

public:
  BinarytreesObj() : n(config_val("depth")), result_val(0) {}

  std::string name() const override { return "Binarytrees::Obj"; }

  void run(int iteration_id) override {
    TreeNode root(0, n);
    result_val += root.sum();
  }

  uint32_t checksum() override { return result_val; }
};

class BinarytreesArena : public Benchmark {
private:
  struct TreeNode {
    int32_t item;
    int32_t left;
    int32_t right;

    TreeNode(int32_t item) : item(item), left(-1), right(-1) {}
  };

  std::vector<TreeNode> arena;
  int64_t n;
  uint32_t result_val;

  int32_t build_tree(int32_t item, int32_t depth) {
    int32_t idx = static_cast<int32_t>(arena.size());
    arena.emplace_back(item);

    if (depth > 0) {
      int32_t left_idx = build_tree(item - (1 << (depth - 1)), depth - 1);
      int32_t right_idx = build_tree(item + (1 << (depth - 1)), depth - 1);
      auto &node = arena[idx];
      node.left = left_idx;
      node.right = right_idx;
    }

    return idx;
  }

  uint32_t sum(int32_t idx) const {
    const auto &node = arena[idx];
    uint32_t total = static_cast<uint32_t>(node.item) + 1;

    if (node.left >= 0) {
      total += sum(node.left);
    }
    if (node.right >= 0) {
      total += sum(node.right);
    }

    return total;
  }

public:
  BinarytreesArena() : n(config_val("depth")), result_val(0) {}

  std::string name() const override { return "Binarytrees::Arena"; }

  void run(int iteration_id) override {
    arena = std::vector<TreeNode>();
    build_tree(0, static_cast<int32_t>(n));
    result_val += sum(0);
  }

  uint32_t checksum() override { return result_val; }
};

class BrainfuckArray : public Benchmark {
private:
  class Tape {
  private:
    std::vector<uint8_t> tape;
    size_t pos;

  public:
    Tape() : tape(30000, 0), pos(0) {}

    uint8_t get() const { return tape[pos]; }
    void inc() { tape[pos]++; }
    void dec() { tape[pos]--; }
    void advance() {
      pos++;
      if (pos >= tape.size()) {
        tape.push_back(0);
      }
    }
    void devance() {
      if (pos > 0)
        pos--;
    }
  };

  class Program {
  private:
    std::vector<uint8_t> commands;
    std::vector<size_t> jumps;

  public:
    Program(const std::string &text) {

      for (char c : text) {
        if (std::string("[]<>+-,.").find(c) != std::string::npos) {
          commands.push_back(static_cast<uint8_t>(c));
        }
      }

      jumps.resize(commands.size(), 0);
      std::vector<size_t> stack;

      for (size_t i = 0; i < commands.size(); ++i) {
        uint8_t cmd = commands[i];
        if (cmd == '[') {
          stack.push_back(i);
        } else if (cmd == ']' && !stack.empty()) {
          size_t start = stack.back();
          stack.pop_back();
          jumps[start] = i;
          jumps[i] = start;
        }
      }
    }

    int64_t run() {
      int64_t result = 0;
      Tape tape;
      size_t pc = 0;

      while (pc < commands.size()) {
        uint8_t cmd = commands[pc];
        switch (cmd) {
        case '+':
          tape.inc();
          break;
        case '-':
          tape.dec();
          break;
        case '>':
          tape.advance();
          break;
        case '<':
          tape.devance();
          break;
        case '[':
          if (tape.get() == 0) {
            pc = jumps[pc];
            continue;
          }
          break;
        case ']':
          if (tape.get() != 0) {
            pc = jumps[pc];
            continue;
          }
          break;
        case '.':
          result = (result << 2) + static_cast<int64_t>(tape.get());
          break;
        }
        pc++;
      }
      return result;
    }
  };

  std::string program_text;
  std::string warmup_text;
  uint32_t result_val;

  int64_t _run(const std::string &text) {
    Program program(text);
    return program.run();
  }

public:
  BrainfuckArray() : result_val(0) {
    program_text = Helper::config_s(name(), "program");
    warmup_text = Helper::config_s(name(), "warmup_program");
  }

  std::string name() const override { return "Brainfuck::Array"; }

  void warmup() override {
    int64_t prepare_iters = warmup_iterations();
    for (int64_t i = 0; i < prepare_iters; i++) {
      _run(warmup_text);
    }
  }

  void run(int iteration_id) override {
    int64_t run_result = _run(program_text);
    result_val += static_cast<uint32_t>(run_result);
  }

  uint32_t checksum() override { return result_val; }
};

class BrainfuckRecursion : public Benchmark {
private:
  struct OpInc {};
  struct OpDec {};
  struct OpAdvance {};
  struct OpDevance {};
  struct OpPrint {};
  struct OpLoop;

  using Op = std::variant<OpInc, OpDec, OpAdvance, OpDevance, OpPrint, OpLoop>;

  struct OpLoop {
    std::vector<Op> ops;
  };

  class Tape {
  private:
    std::vector<uint8_t> tape;
    size_t pos = 0;

  public:
    Tape() : tape(30000, 0) {}

    uint8_t get() const { return tape[pos]; }

    void inc() { tape[pos]++; }

    void dec() { tape[pos]--; }

    void advance() {
      pos++;
      if (pos >= tape.size()) {
        tape.push_back(0);
      }
    }

    void devance() {
      if (pos > 0) {
        pos--;
      }
    }
  };

  class Program {
  private:
    std::vector<Op> ops;

    std::vector<Op> parse(std::string::const_iterator &it,
                          const std::string::const_iterator &end) {
      std::vector<Op> res;
      res.reserve(128);

      while (it != end) {
        char c = *it++;
        switch (c) {
        case '+':
          res.emplace_back(OpInc{});
          break;
        case '-':
          res.emplace_back(OpDec{});
          break;
        case '>':
          res.emplace_back(OpAdvance{});
          break;
        case '<':
          res.emplace_back(OpDevance{});
          break;
        case '.':
          res.emplace_back(OpPrint{});
          break;
        case '[': {
          auto loop_ops = parse(it, end);
          res.emplace_back(OpLoop{std::move(loop_ops)});
          break;
        }
        case ']':
          return res;
        default:
          break;
        }
      }
      return res;
    }

    struct Visitor {
      Tape &tape;
      int64_t &result;

      void operator()(const OpInc &) const { tape.inc(); }
      void operator()(const OpDec &) const { tape.dec(); }
      void operator()(const OpAdvance &) const { tape.advance(); }
      void operator()(const OpDevance &) const { tape.devance(); }
      void operator()(const OpPrint &) const {
        result = (result << 2) + tape.get();
      }
      void operator()(const OpLoop &loop) const {
        while (tape.get() != 0) {
          for (const auto &op : loop.ops) {
            std::visit(*this, op);
          }
        }
      }
    };

  public:
    explicit Program(const std::string &code) {
      auto it = code.begin();
      ops = parse(it, code.end());
    }

    int64_t run() {
      Tape tape;
      int64_t result = 0;
      Visitor visitor{tape, result};

      for (const auto &op : ops) {
        std::visit(visitor, op);
      }
      return result;
    }
  };

  std::string text;
  uint32_t result_val;

public:
  BrainfuckRecursion() : result_val(0) {
    text = Helper::config_s(name(), "program");
  }

  std::string name() const override { return "Brainfuck::Recursion"; }

  void warmup() override {
    int64_t prepare_iters = warmup_iterations();
    std::string warmup_program = Helper::config_s(name(), "warmup_program");
    for (int64_t i = 0; i < prepare_iters; i++) {
      Program(warmup_program).run();
    }
  }

  void run(int iteration_id) override { result_val += Program(text).run(); }

  uint32_t checksum() override { return result_val; }
};

class Fannkuchredux : public Benchmark {
private:
  int64_t n;
  uint32_t result_val;

  std::pair<int, int> fannkuchredux(int n) {
    int perm1[32];
    int perm[32];
    int count[32];

    if (n > 32)
      n = 32;

    std::iota(perm1, perm1 + n, 0);

    int maxFlipsCount = 0, permCount = 0, checksum = 0;
    int r = n;

    while (true) {
      while (r > 1) {
        count[r - 1] = r;
        r--;
      }

      std::copy(perm1, perm1 + n, perm);

      int flipsCount = 0;
      int k = perm[0];

      while (k != 0) {
        std::reverse(perm, perm + k + 1);
        flipsCount++;
        k = perm[0];
      }

      maxFlipsCount = std::max(maxFlipsCount, flipsCount);
      checksum += (permCount % 2 == 0) ? flipsCount : -flipsCount;

      while (true) {
        if (r == n)
          return {checksum, maxFlipsCount};

        std::rotate(perm1, perm1 + 1, perm1 + r + 1);

        count[r]--;
        if (count[r] > 0)
          break;
        r++;
      }
      permCount++;
    }
  }

public:
  Fannkuchredux() : n(config_val("n")), result_val(0) {}

  std::string name() const override { return "CLBG::Fannkuchredux"; }

  void run(int iteration_id) override {
    auto [a, b] = fannkuchredux(static_cast<int>(n));
    result_val += a * 100 + b;
  }

  uint32_t checksum() override { return result_val; }
};

class Fasta : public Benchmark {
private:
  struct Gene {
    char c;
    double prob;
  };

  static constexpr int LINE_LENGTH = 60;
  std::string result_str;

  char select_random(const std::vector<Gene> &genelist) {
    double r = Helper::next_float();
    if (r < genelist[0].prob)
      return genelist[0].c;

    int lo = 0, hi = genelist.size() - 1;
    while (hi > lo + 1) {
      int i = (hi + lo) / 2;
      if (r < genelist[i].prob)
        hi = i;
      else
        lo = i;
    }
    return genelist[hi].c;
  }

  void make_random_fasta(const std::string &id, const std::string &desc,
                         const std::vector<Gene> &genelist, int n_iter) {
    result_str += ">" + id + " " + desc + "\n";
    int todo = n_iter;

    while (todo > 0) {
      int m = (todo < LINE_LENGTH) ? todo : LINE_LENGTH;
      std::string buffer(m, ' ');
      for (int i = 0; i < m; i++) {
        buffer[i] = select_random(genelist);
      }
      result_str += buffer + "\n";
      todo -= LINE_LENGTH;
    }
  }

  void make_repeat_fasta(const std::string &id, const std::string &desc,
                         const std::string &s, int n_iter) {
    result_str += ">" + id + " " + desc + "\n";
    int todo = n_iter;
    size_t k = 0;
    size_t kn = s.size();

    while (todo > 0) {
      int m = (todo < LINE_LENGTH) ? todo : LINE_LENGTH;

      while (m >= static_cast<int>(kn - k)) {
        result_str += s.substr(k);
        m -= (kn - k);
        k = 0;
      }

      result_str += s.substr(k, m) + "\n";
      k += m;
      todo -= LINE_LENGTH;
    }
  }

public:
  int64_t n;

  Fasta() : n(config_val("n")) {}

  std::string name() const override { return "CLBG::Fasta"; }

  void run(int iteration_id) override {
    std::vector<Gene> IUB = {{'a', 0.27},
                             {'c', 0.39},
                             {'g', 0.51},
                             {'t', 0.78},
                             {'B', 0.8},
                             {'D', 0.8200000000000001},
                             {'H', 0.8400000000000001},
                             {'K', 0.8600000000000001},
                             {'M', 0.8800000000000001},
                             {'N', 0.9000000000000001},
                             {'R', 0.9200000000000002},
                             {'S', 0.9400000000000002},
                             {'V', 0.9600000000000002},
                             {'W', 0.9800000000000002},
                             {'Y', 1.0000000000000002}};

    std::vector<Gene> HOMO = {{'a', 0.302954942668},
                              {'c', 0.5009432431601},
                              {'g', 0.6984905497992},
                              {'t', 1.0}};

    std::string ALU =
        "GGCCGGGCGCGGTGGCTCACGCCTGTAATCCCAGCACTTTGGGAGGCCGAGGCGGGCGGATCACCTGAGG"
        "TCAGGAGTTCGAGACCAGCCTGGCCAACATGGTGAAACCCCGTCTCTACTAAAAATACAAAAATTAGCCG"
        "GGCGTGGTGGCGCGCGCCTGTAATCCCAGCTACTCGGGAGGCTGAGGCAGGAGAATCGCTTGAACCCGGG"
        "AGGCGGAGGTTGCAGTGAGCCGAGATCGCGCCACTGCACTCCAGCCTGGGCGACAGAGCGAGACTCCGTC"
        "TCAAAAA";

    make_repeat_fasta("ONE", "Homo sapiens alu", ALU, static_cast<int>(n * 2));
    make_random_fasta("TWO", "IUB ambiguity codes", IUB,
                      static_cast<int>(n * 3));
    make_random_fasta("THREE", "Homo sapiens frequency", HOMO,
                      static_cast<int>(n * 5));
  }

  uint32_t checksum() override { return Helper::checksum(result_str); }

  const std::string &get_result() const { return result_str; }
};

class Knuckeotide : public Benchmark {
private:
  std::string seq;
  std::string result_str;

  std::pair<int, std::unordered_map<std::string, int>>
  frequency(const std::string &seq, int length) {
    int n = seq.size() - length + 1;
    std::unordered_map<std::string, int> table;

    for (int i = 0; i < n; i++) {
      std::string sub = seq.substr(i, length);
      table[sub]++;
    }
    return {n, table};
  }

  void sort_by_freq(const std::string &seq, int length) {
    auto [n, table] = frequency(seq, length);

    std::vector<std::pair<std::string, int>> pairs(table.begin(), table.end());
    std::sort(pairs.begin(), pairs.end(), [](const auto &a, const auto &b) {
      if (a.second == b.second)
        return a.first < b.first;
      return a.second > b.second;
    });

    for (const auto &[key, value] : pairs) {
      double percent = (value * 100.0) / n;
      std::ostringstream ss;
      std::string key_upper = key;
      std::transform(key_upper.begin(), key_upper.end(), key_upper.begin(),
                     ::toupper);
      ss << key_upper << " " << std::fixed << std::setprecision(3) << percent
         << "\n";
      result_str += ss.str();
    }
    result_str += "\n";
  }

  void find_seq(const std::string &seq, const std::string &s) {
    auto [n, table] = frequency(seq, static_cast<int>(s.size()));
    std::string s_lower = s;
    std::transform(s_lower.begin(), s_lower.end(), s_lower.begin(), ::tolower);
    int count = table[s_lower];

    std::string s_upper = s;
    std::transform(s_upper.begin(), s_upper.end(), s_upper.begin(), ::toupper);
    result_str += std::to_string(count) + "\t" + s_upper + "\n";
  }

public:
  Knuckeotide() {}

  std::string name() const override { return "CLBG::Knuckeotide"; }

  void prepare() override {
    Fasta fasta;
    fasta.n = config_val("n");
    fasta.run(0);
    std::string res = fasta.get_result();

    std::istringstream iss(res);
    std::string line;
    bool three = false;
    seq.clear();

    while (std::getline(iss, line)) {
      if (line.starts_with(">THREE")) {
        three = true;
        continue;
      }
      if (three) {
        seq += line;
      }
    }
  }

  void run(int iteration_id) override {
    for (int i = 1; i <= 2; i++) {
      sort_by_freq(seq, i);
    }

    std::vector<std::string> searches = {"ggt", "ggta", "ggtatt",
                                         "ggtattttaatt", "ggtattttaatttatagt"};
    for (const auto &s : searches) {
      find_seq(seq, s);
    }
  }

  uint32_t checksum() override { return Helper::checksum(result_str); }
};

class Mandelbrot : public Benchmark {
private:
  static constexpr int ITER = 50;
  static constexpr double LIMIT = 2.0;

  int64_t w, h;
  std::vector<uint8_t> result_bin;

public:
  Mandelbrot() {
    w = config_val("w");
    h = config_val("h");
  }

  std::string name() const override { return "CLBG::Mandelbrot"; }

  void run(int iteration_id) override {
    std::ostringstream header;
    header << "P4\n" << w << " " << h << "\n";
    std::string header_str = header.str();
    result_bin.insert(result_bin.end(), header_str.begin(), header_str.end());

    int bit_num = 0;
    uint8_t byte_acc = 0;

    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        double tmp_x = static_cast<double>(x);
        double tmp_y = static_cast<double>(y);
        volatile double tmp_w = static_cast<double>(w);
        double tmp_h = static_cast<double>(h);

        double cr = 2.0 * tmp_x / tmp_w - 1.5;
        double ci = 2.0 * tmp_y / tmp_h - 1.0;

        double zr = 0.0, zi = 0.0;
        double tr = 0.0, ti = 0.0;

        int i = 0;
        while (i < ITER && tr + ti <= LIMIT * LIMIT) {
          zi = 2.0 * zr * zi + ci;
          zr = tr - ti + cr;
          tr = zr * zr;
          ti = zi * zi;
          i++;
        }

        byte_acc <<= 1;
        if (tr + ti <= LIMIT * LIMIT) {
          byte_acc |= 0x01;
        }
        bit_num++;

        if (bit_num == 8) {
          result_bin.push_back(byte_acc);
          byte_acc = 0;
          bit_num = 0;
        } else if (x == w - 1) {
          byte_acc <<= (8 - (w % 8));
          result_bin.push_back(byte_acc);
          byte_acc = 0;
          bit_num = 0;
        }
      }
    }
  }

  uint32_t checksum() override { return Helper::checksum(result_bin); }
};

class Matmul1T : public Benchmark {
protected:
  uint32_t result_val;
  std::vector<std::vector<double>> a, b;

  std::vector<std::vector<double>> matgen(int n) {
    double tmp = 1.0 / n / n;
    std::vector<std::vector<double>> a(n, std::vector<double>(n));
    for (int i = 0; i < n; i++) {
      for (int j = 0; j < n; j++) {
        a[i][j] = tmp * (i - j) * (i + j);
      }
    }
    return a;
  }

  std::vector<std::vector<double>>
  matmul(int n, const std::vector<std::vector<double>> &a,
         const std::vector<std::vector<double>> &b) {

    std::vector<std::vector<double>> b_t(n, std::vector<double>(n));
    for (int i = 0; i < n; i++) {
      for (int j = 0; j < n; j++) {
        b_t[j][i] = b[i][j];
      }
    }

    std::vector<std::vector<double>> c(n, std::vector<double>(n));
    for (int i = 0; i < n; i++) {
      const auto &ai = a[i];
      auto &ci = c[i];
      for (int j = 0; j < n; j++) {
        double s = 0.0;
        const auto &b_tj = b_t[j];
        for (int k = 0; k < n; k++) {
          s += ai[k] * b_tj[k];
        }
        ci[j] = s;
      }
    }
    return c;
  }

public:
  Matmul1T() : result_val(0) {}

  std::string name() const override { return "Matmul::Single"; }

  void prepare() override {
    int n = static_cast<int>(config_val("n"));
    a = matgen(n);
    b = matgen(n);
  }

  void run(int) override {
    int n = static_cast<int>(a.size());
    auto c = matmul(n, a, b);
    result_val += Helper::checksum_f64(c[n >> 1][n >> 1]);
  }

  uint32_t checksum() override { return result_val; }
};

class Matmul4T : public Matmul1T {
protected:
  virtual int get_num_threads() const { return 4; }

  std::vector<std::vector<double>>
  matmul_parallel(int n, const std::vector<std::vector<double>> &a,
                  const std::vector<std::vector<double>> &b) {
    int num_threads = get_num_threads();

    std::vector<std::vector<double>> b_t(n, std::vector<double>(n));
    for (int i = 0; i < n; i++) {
      for (int j = 0; j < n; j++) {
        b_t[j][i] = b[i][j];
      }
    }

    std::vector<std::vector<double>> c(n, std::vector<double>(n));
    std::vector<std::thread> threads;
    threads.reserve(num_threads);

    int rows_per_thread = (n + num_threads - 1) / num_threads;

    for (int t = 0; t < num_threads; t++) {
      int start = t * rows_per_thread;
      int end = std::min(start + rows_per_thread, n);

      threads.emplace_back([&, start, end]() {
        for (int i = start; i < end; i++) {
          const auto &ai = a[i];
          auto &ci = c[i];
          for (int j = 0; j < n; j++) {
            double sum = 0.0;
            const auto &b_tj = b_t[j];
            for (int k = 0; k < n; k++) {
              sum += ai[k] * b_tj[k];
            }
            ci[j] = sum;
          }
        }
      });
    }

    for (auto &thread : threads) {
      thread.join();
    }
    return c;
  }

public:
  Matmul4T() = default;

  std::string name() const override { return "Matmul::T4"; }

  void run(int) override {
    int n = static_cast<int>(a.size());
    auto c = matmul_parallel(n, a, b);
    result_val += Helper::checksum_f64(c[n >> 1][n >> 1]);
  }
};

class Matmul8T : public Matmul4T {
protected:
  int get_num_threads() const override { return 8; }

public:
  Matmul8T() = default;
  std::string name() const override { return "Matmul::T8"; }
};

class Matmul16T : public Matmul4T {
protected:
  int get_num_threads() const override { return 16; }

public:
  Matmul16T() = default;
  std::string name() const override { return "Matmul::T16"; }
};

class Nbody : public Benchmark {
private:
  static constexpr double SOLAR_MASS = 4 * M_PI * M_PI;
  static constexpr double DAYS_PER_YEAR = 365.24;

  struct Planet {
    double x, y, z;
    double vx, vy, vz;
    double mass;

    Planet(double x, double y, double z, double vx, double vy, double vz,
           double mass)
        : x(x), y(y), z(z), vx(vx * DAYS_PER_YEAR), vy(vy * DAYS_PER_YEAR),
          vz(vz * DAYS_PER_YEAR), mass(mass * SOLAR_MASS) {}

    void move_from_i(std::vector<Planet> &bodies, int nbodies, double dt,
                     int start) {
      for (int i = start; i < nbodies; i++) {
        Planet &b2 = bodies[i];
        double dx = x - b2.x;
        double dy = y - b2.y;
        double dz = z - b2.z;

        double distance = std::sqrt(dx * dx + dy * dy + dz * dz);
        double mag = dt / (distance * distance * distance);
        double b_mass_mag = mass * mag;
        double b2_mass_mag = b2.mass * mag;

        vx -= dx * b2_mass_mag;
        vy -= dy * b2_mass_mag;
        vz -= dz * b2_mass_mag;
        b2.vx += dx * b_mass_mag;
        b2.vy += dy * b_mass_mag;
        b2.vz += dz * b_mass_mag;
      }

      x += dt * vx;
      y += dt * vy;
      z += dt * vz;
    }
  };

  uint32_t result_val;
  std::vector<Planet> bodies;
  double v1;

  double energy() {
    double e = 0.0;
    int nbodies = static_cast<int>(bodies.size());

    for (int i = 0; i < nbodies; i++) {
      Planet &b = bodies[i];
      e += 0.5 * b.mass * (b.vx * b.vx + b.vy * b.vy + b.vz * b.vz);
      for (int j = i + 1; j < nbodies; j++) {
        Planet &b2 = bodies[j];
        double dx = b.x - b2.x;
        double dy = b.y - b2.y;
        double dz = b.z - b2.z;
        double distance = std::sqrt(dx * dx + dy * dy + dz * dz);
        e -= (b.mass * b2.mass) / distance;
      }
    }
    return e;
  }

  void offset_momentum() {
    double px = 0.0, py = 0.0, pz = 0.0;

    for (auto &b : bodies) {
      px += b.vx * b.mass;
      py += b.vy * b.mass;
      pz += b.vz * b.mass;
    }

    Planet &b = bodies[0];
    b.vx = -px / SOLAR_MASS;
    b.vy = -py / SOLAR_MASS;
    b.vz = -pz / SOLAR_MASS;
  }

public:
  Nbody() : result_val(0), v1(0.0) {
    bodies = {Planet(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0),
              Planet(4.84143144246472090e+00, -1.16032004402742839e+00,
                     -1.03622044471123109e-01, 1.66007664274403694e-03,
                     7.69901118419740425e-03, -6.90460016972063023e-05,
                     9.54791938424326609e-04),
              Planet(8.34336671824457987e+00, 4.12479856412430479e+00,
                     -4.03523417114321381e-01, -2.76742510726862411e-03,
                     4.99852801234917238e-03, 2.30417297573763929e-05,
                     2.85885980666130812e-04),
              Planet(1.28943695621391310e+01, -1.51111514016986312e+01,
                     -2.23307578892655734e-01, 2.96460137564761618e-03,
                     2.37847173959480950e-03, -2.96589568540237556e-05,
                     4.36624404335156298e-05),
              Planet(1.53796971148509165e+01, -2.59193146099879641e+01,
                     1.79258772950371181e-01, 2.68067772490389322e-03,
                     1.62824170038242295e-03, -9.51592254519715870e-05,
                     5.15138902046611451e-05)};
  }

  std::string name() const override { return "CLBG::Nbody"; }

  void prepare() override {
    offset_momentum();
    v1 = energy();
  }

  void run(int iteration_id) override {
    int nbodies = static_cast<int>(bodies.size());
    double dt = 0.01;

    for (int n = 0; n < 1000; n++) {
      int i = 0;
      while (i < nbodies) {
        Planet &b = bodies[i];
        b.move_from_i(bodies, nbodies, dt, i + 1);
        i++;
      }
    }
  }

  uint32_t checksum() override {
    double v2 = energy();
    return (Helper::checksum_f64(v1) << 5) & Helper::checksum_f64(v2);
  }
};

class RegexDna : public Benchmark {
private:
  std::string seq;
  int ilen, clen;
  std::string result_str;

  std::vector<std::unique_ptr<re2::RE2>> compiled_patterns;

  static constexpr std::array<const char *, 9> PATTERNS = {
      "agggtaaa|tttaccct",         "[cgt]gggtaaa|tttaccc[acg]",
      "a[act]ggtaaa|tttacc[agt]t", "ag[act]gtaaa|tttac[agt]ct",
      "agg[act]taaa|ttta[agt]cct", "aggg[acg]aaa|ttt[cgt]ccct",
      "agggt[cgt]aa|tt[acg]accct", "agggta[cgt]a|t[acg]taccct",
      "agggtaa[cgt]|[acg]ttaccct"};

  struct Replacement {
    char from;
    const char *to;
    size_t len;
  };

  static constexpr std::array<Replacement, 11> REPLACEMENTS = {
      {{'B', "(c|g|t)", 7},
       {'D', "(a|g|t)", 7},
       {'H', "(a|c|t)", 7},
       {'K', "(g|t)", 5},
       {'M', "(a|c)", 5},
       {'N', "(a|c|g|t)", 9},
       {'R', "(a|g)", 5},
       {'S', "(c|t)", 5},
       {'V', "(a|c|g)", 7},
       {'W', "(a|t)", 5},
       {'Y', "(c|t)", 5}}};

  size_t count_pattern(size_t pattern_idx) {
    if (!compiled_patterns[pattern_idx])
      return 0;

    re2::StringPiece input(seq);
    size_t count = 0;

    re2::StringPiece match;
    const re2::RE2 &pattern = *compiled_patterns[pattern_idx];

    while (pattern.Match(input, 0, input.size(), re2::RE2::UNANCHORED, &match,
                         1)) {
      count++;
      input.remove_prefix(match.data() - input.data() + match.size());
    }

    return count;
  }

public:
  RegexDna() : ilen(0), clen(0) { result_str.reserve(4096); }

  std::string name() const override { return "CLBG::RegexDna"; }

  void prepare() override {
    Fasta fasta;
    fasta.n = config_val("n");
    fasta.run(0);
    std::string res = fasta.get_result();

    std::istringstream iss(res);
    std::string line;
    seq.clear();
    ilen = 0;

    while (std::getline(iss, line)) {
      ilen += static_cast<int>(line.size()) + 1;
      if (!line.empty() && line[0] != '>') {
        seq += line;
      }
    }
    clen = static_cast<int>(seq.size());

    compiled_patterns.clear();
    compiled_patterns.reserve(PATTERNS.size());

    for (const char *pattern : PATTERNS) {
      auto re = std::make_unique<re2::RE2>(pattern);
      if (!re->ok()) {
        std::cerr << "RE2 error for " << pattern << ": " << re->error()
                  << std::endl;
      }
      compiled_patterns.push_back(std::move(re));
    }
  }

  void run(int iteration_id) override {

    for (size_t i = 0; i < PATTERNS.size(); ++i) {
      size_t count = count_pattern(i);

      result_str += PATTERNS[i];
      result_str += ' ';
      result_str += std::to_string(count);
      result_str += '\n';
    }

    std::string seq2;
    seq2.reserve(seq.size() * 9);

    for (char c : seq) {
      bool replaced = false;
      for (const auto &repl : REPLACEMENTS) {
        if (c == repl.from) {
          seq2.append(repl.to, repl.len);
          replaced = true;
          break;
        }
      }
      if (!replaced) {
        seq2.push_back(c);
      }
    }

    result_str += '\n';
    result_str += std::to_string(ilen);
    result_str += '\n';
    result_str += std::to_string(clen);
    result_str += '\n';
    result_str += std::to_string(seq2.size());
    result_str += '\n';
  }

  uint32_t checksum() override { return Helper::checksum(result_str); }
};

class Revcomp : public Benchmark {
private:
  std::string input;
  uint32_t _checksum;

  std::string revcomp(const std::string &seq) {

    std::string reversed = seq;

    std::reverse(reversed.begin(), reversed.end());

    static std::array<char, 256> lookup;
    static std::once_flag flag;

    std::call_once(flag, []() {
      for (int i = 0; i < 256; i++) {
        lookup[i] = static_cast<char>(i);
      }

      static constexpr std::string_view from = "wsatugcyrkmbdhvnATUGCYRKMBDHVN";
      static constexpr std::string_view to = "WSTAACGRYMKVHDBNTAACGRYMKVHDBN";

      for (size_t i = 0; i < from.size(); i++) {
        lookup[static_cast<unsigned char>(from[i])] = to[i];
      }
    });

    for (char &c : reversed) {
      c = lookup[static_cast<unsigned char>(c)];
    }

    std::string result;
    result.reserve(reversed.size() + (reversed.size() / 60) + 1);

    for (size_t i = 0; i < reversed.size(); i += 60) {
      size_t end = std::min(i + 60, reversed.size());
      result.append(reversed, i, end - i);
      result += '\n';
    }

    return result;
  }

public:
  Revcomp() : _checksum(0) {}

  std::string name() const override { return "CLBG::Revcomp"; }

  void prepare() override {
    Fasta fasta;
    fasta.n = config_val("n");
    fasta.run(0);
    std::string fasta_result = fasta.get_result();

    std::istringstream iss(fasta_result);
    std::string line;
    std::string seq;

    while (std::getline(iss, line)) {
      if (line.starts_with('>')) {
        seq += "\n---\n";
      } else {
        seq += line;
      }
    }
    input = seq;
  }

  void run(int iteration_id) override {
    auto result_str = revcomp(input);
    _checksum += Helper::checksum(result_str);
  }

  uint32_t checksum() override { return _checksum; }
};

class Spectralnorm : public Benchmark {
private:
  int64_t size_val;
  std::vector<double> u;
  std::vector<double> v;

  double eval_A(int i, int j) {
    return 1.0 / ((i + j) * (i + j + 1.0) / 2.0 + i + 1.0);
  }

  std::vector<double> eval_A_times_u(const std::vector<double> &u) {
    std::vector<double> v(u.size());
    for (size_t i = 0; i < u.size(); i++) {
      double sum = 0.0;
      for (size_t j = 0; j < u.size(); j++) {
        sum += eval_A(static_cast<int>(i), static_cast<int>(j)) * u[j];
      }
      v[i] = sum;
    }
    return v;
  }

  std::vector<double> eval_At_times_u(const std::vector<double> &u) {
    std::vector<double> v(u.size());
    for (size_t i = 0; i < u.size(); i++) {
      double sum = 0.0;
      for (size_t j = 0; j < u.size(); j++) {
        sum += eval_A(static_cast<int>(j), static_cast<int>(i)) * u[j];
      }
      v[i] = sum;
    }
    return v;
  }

  std::vector<double> eval_AtA_times_u(const std::vector<double> &u) {
    return eval_At_times_u(eval_A_times_u(u));
  }

public:
  Spectralnorm() {
    size_val = config_val("size");
    u = std::vector<double>(size_val, 1.0);
    v = std::vector<double>(size_val, 1.0);
  }

  std::string name() const override { return "CLBG::Spectralnorm"; }

  void run(int iteration_id) override {
    v = eval_AtA_times_u(u);
    u = eval_AtA_times_u(v);
  }

  uint32_t checksum() override {
    double vBv = 0.0, vv = 0.0;
    for (int i = 0; i < size_val; i++) {
      vBv += u[i] * v[i];
      vv += v[i] * v[i];
    }
    return Helper::checksum_f64(sqrt(vBv / vv));
  }
};

extern "C" {
#include "libbase64.h"
}

class Base64Encode : public Benchmark {
private:
  std::string str;
  std::string str2;
  uint32_t result_val;

  static size_t encode_size(size_t size) {
    return (size_t)(size * 4 / 3.0) + 6;
  }

  static size_t b64_encode(char *dst, const char *src, size_t src_size) {
    size_t encoded_size;
    base64_encode(src, src_size, dst, &encoded_size, 0);
    return encoded_size;
  }

public:
  Base64Encode() : result_val(0) {
    int64_t n = config_val("size");
    str = std::string(static_cast<size_t>(n), 'a');
    str2 = base64_encode_simple(str);
  }

  std::string name() const override { return "Base64::Encode"; }

  void run(int iteration_id) override {
    str2 = base64_encode_simple(str);
    result_val += str2.size();
  }

  uint32_t checksum() override {
    std::ostringstream ss;
    ss << "encode " << (str.size() > 4 ? str.substr(0, 4) + "..." : str)
       << " to " << (str2.size() > 4 ? str2.substr(0, 4) + "..." : str2) << ": "
       << result_val;
    return Helper::checksum(ss.str());
  }

private:
  std::string base64_encode_simple(const std::string &input) {
    size_t encoded_len = encode_size(input.size());
    std::string result;
    result.resize(encoded_len);
    size_t actual_len = 0;
    base64_encode(input.data(), input.size(), &result[0], &actual_len, 0);
    result.resize(actual_len);
    return result;
  }
};

class Base64Decode : public Benchmark {
private:
  std::string str2;
  std::string str3;
  uint32_t result_val;

  static size_t decode_size(size_t size) {
    return (size_t)(size * 3 / 4.0) + 6;
  }

  static size_t b64_decode(char *dst, const char *src, size_t src_size) {
    size_t decoded_size;
    if (base64_decode(src, src_size, dst, &decoded_size, 0) != 1) {
      return 0;
    }
    return decoded_size;
  }

public:
  Base64Decode() : result_val(0) {
    int64_t n = config_val("size");
    std::string str = std::string(static_cast<size_t>(n), 'a');

    size_t encoded_size = encode_size(str.size());
    str2.resize(encoded_size);
    size_t actual_encoded = 0;
    base64_encode(str.data(), str.size(), &str2[0], &actual_encoded, 0);
    str2.resize(actual_encoded);

    str3 = base64_decode_simple(str2);
  }

  std::string name() const override { return "Base64::Decode"; }

  void run(int iteration_id) override {
    str3 = base64_decode_simple(str2);
    result_val += str3.size();
  }

  uint32_t checksum() override {
    std::ostringstream ss;
    ss << "decode " << (str2.size() > 4 ? str2.substr(0, 4) + "..." : str2)
       << " to " << (str3.size() > 4 ? str3.substr(0, 4) + "..." : str3) << ": "
       << result_val;
    return Helper::checksum(ss.str());
  }

private:
  std::string base64_decode_simple(const std::string &input) {
    size_t decoded_size = decode_size(input.size());
    std::string result;
    result.resize(decoded_size);
    size_t actual_len = b64_decode(&result[0], input.data(), input.size());
    result.resize(actual_len);
    return result;
  }

  static size_t encode_size(size_t size) {
    return (size_t)(size * 4 / 3.0) + 6;
  }
};

class JsonGenerate : public Benchmark {
private:
  struct Coordinate {
    double x, y, z;
    std::string name;
    std::unordered_map<std::string, std::pair<int, bool>> opts;

    Coordinate(
        double x, double y, double z, const std::string &name,
        const std::unordered_map<std::string, std::pair<int, bool>> &opts)
        : x(x), y(y), z(z), name(name), opts(opts) {}
  };

  std::vector<Coordinate> data;
  std::string _result;
  uint32_t result;

public:
  int64_t n;

  JsonGenerate() : n(config_val("coords")), result(0) {
    data.reserve(static_cast<size_t>(n));
  }

  std::string name() const override { return "Json::Generate"; }

  void prepare() override {
    for (int64_t i = 0; i < n; i++) {
      double x = custom_round(Helper::next_float(), 8);
      double y = custom_round(Helper::next_float(), 8);
      double z = custom_round(Helper::next_float(), 8);

      std::ostringstream name;
      name << std::fixed << std::setprecision(7) << Helper::next_float() << " "
           << Helper::next_int(10000);

      std::unordered_map<std::string, std::pair<int, bool>> opts = {
          {"1", {1, true}}};

      data.emplace_back(x, y, z, name.str(), opts);
    }
  }

  void run(int iteration_id) override {
    simdjson::builder::string_builder sb;

    sb.start_object();
    sb.escape_and_append_with_quotes("coordinates");
    sb.append_colon();
    sb.start_array();

    for (size_t i = 0; i < data.size(); ++i) {
      const auto &coord = data[i];

      sb.start_object();

      sb.append_key_value<"x">(coord.x);
      sb.append_comma();
      sb.append_key_value<"y">(coord.y);
      sb.append_comma();
      sb.append_key_value<"z">(coord.z);
      sb.append_comma();
      sb.append_key_value<"name">(coord.name);
      sb.append_comma();

      sb.escape_and_append_with_quotes("opts");
      sb.append_colon();
      sb.start_object();
      for (const auto &[key, value] : coord.opts) {
        sb.escape_and_append_with_quotes(key);
        sb.append_colon();
        sb.start_array();
        sb.append(value.first);
        sb.append_comma();
        sb.append(value.second);
        sb.end_array();
      }
      sb.end_object();

      sb.end_object();

      if (i < data.size() - 1) {
        sb.append_comma();
      }
    }

    sb.end_array();

    sb.append_comma();
    sb.append_key_value<"info">("some info");

    sb.end_object();

    auto view = sb.view();
    if (view.error()) {
      throw std::runtime_error("JSON generation failed");
    }
    _result = std::string(view.value_unsafe());

    if (_result.size() >= 15 &&
        _result.compare(0, 15, "{\"coordinates\":") == 0) {
      result++;
    }
  }

  uint32_t checksum() override { return result; }

  const std::string &get_result() const { return _result; }
};

class JsonParseDom : public Benchmark {
private:
  struct Coordinate {
    double x, y, z;
  };

  std::string text;
  uint32_t result_val;

public:
  JsonParseDom() : result_val(0) {}

  std::string name() const override { return "Json::ParseDom"; }

  void prepare() override {
    JsonGenerate jg;
    jg.n = config_val("coords");
    jg.prepare();
    jg.run(0);
    text = jg.get_result();
  }

  void run(int iteration_id) override {
    auto padded = simdjson::padded_string(text);
    simdjson::dom::parser parser;
    simdjson::dom::element doc = parser.parse(padded);

    double x_sum = 0.0, y_sum = 0.0, z_sum = 0.0;
    size_t len = 0;

    for (auto coord : doc["coordinates"]) {
      Coordinate c{coord["x"], coord["y"], coord["z"]};
      x_sum += c.x;
      y_sum += c.y;
      z_sum += c.z;
      len++;
    }

    double x = x_sum / len;
    double y = y_sum / len;
    double z = z_sum / len;

    result_val += Helper::checksum_f64(x) + Helper::checksum_f64(y) +
                  Helper::checksum_f64(z);
  }

  uint32_t checksum() override { return result_val; }
};

class JsonParseMapping : public Benchmark {
private:
  struct Coordinate {
    double x, y, z;
  };

  std::string text;
  uint32_t result_val;

public:
  JsonParseMapping() : result_val(0) {}

  std::string name() const override { return "Json::ParseMapping"; }

  void prepare() override {
    JsonGenerate jg;
    jg.n = config_val("coords");
    jg.prepare();
    jg.run(0);
    text = jg.get_result();
  }

  void run(int iteration_id) override {
    simdjson::ondemand::parser parser;
    auto padded = simdjson::padded_string(text);
    auto doc = parser.iterate(padded);

    double x_sum = 0.0, y_sum = 0.0, z_sum = 0.0;
    size_t len = 0;

    for (auto coord : doc["coordinates"]) {
      Coordinate c{coord["x"], coord["y"], coord["z"]};

      x_sum += c.x;
      y_sum += c.y;
      z_sum += c.z;
      len++;
    }

    Coordinate avg{x_sum / len, y_sum / len, z_sum / len};
    result_val += Helper::checksum_f64(avg.x) + Helper::checksum_f64(avg.y) +
                  Helper::checksum_f64(avg.z);
  }

  uint32_t checksum() override { return result_val; }
};

class Sieve : public Benchmark {
private:
  int64_t limit;
  uint32_t checksum_val;

public:
  Sieve() : limit(config_val("limit")), checksum_val(0) {}

  std::string name() const override { return "Etc::Sieve"; }

  void run(int iteration_id) override {
    size_t sz = static_cast<size_t>(limit);
    std::vector<uint8_t> primes(sz + 1, 1);
    primes[0] = 0;
    primes[1] = 0;

    size_t sqrt_limit =
        static_cast<size_t>(std::sqrt(static_cast<double>(limit)));

    for (size_t p = 2; p <= sqrt_limit; ++p) {
      if (primes[p] == 1) {
        for (size_t multiple = p * p; multiple <= sz; multiple += p) {
          primes[multiple] = 0;
        }
      }
    }

    int last_prime = 2;
    int count = 1;

    for (size_t n = 3; n <= sz; n += 2) {
      if (primes[n] == 1) {
        last_prime = static_cast<int>(n);
        count++;
      }
    }

    checksum_val += static_cast<uint32_t>(last_prime + count);
  }

  uint32_t checksum() override { return checksum_val; }
};

class TextRaytracer : public Benchmark {
private:
  struct Vector {
    double x, y, z;

    Vector scale(double s) const { return {x * s, y * s, z * s}; }
    Vector add(const Vector &other) const {
      return {x + other.x, y + other.y, z + other.z};
    }
    Vector sub(const Vector &other) const {
      return {x - other.x, y - other.y, z - other.z};
    }
    double dot(const Vector &other) const {
      return x * other.x + y * other.y + z * other.z;
    }
    double magnitude() const { return std::sqrt(dot(*this)); }
    Vector normalize() const {
      double mag = magnitude();
      if (mag == 0.0)
        return {0, 0, 0};
      return scale(1.0 / mag);
    }
  };

  struct Ray {
    Vector orig, dir;
  };

  struct Color {
    double r, g, b;

    Color scale(double s) const { return {r * s, g * s, b * s}; }
    Color add(const Color &other) const {
      return {r + other.r, g + other.g, b + other.b};
    }
  };

  struct Sphere {
    Vector center;
    double radius;
    Color color;

    Vector get_normal(const Vector &pt) const {
      return pt.sub(center).normalize();
    }
  };

  struct Light {
    Vector position;
    Color color;
  };

  static constexpr Color WHITE = {1.0, 1.0, 1.0};
  static constexpr Color RED = {1.0, 0.0, 0.0};
  static constexpr Color GREEN = {0.0, 1.0, 0.0};
  static constexpr Color BLUE = {0.0, 0.0, 1.0};

  static constexpr Light LIGHT1 = {{0.7, -1.0, 1.7}, WHITE};
  static constexpr char LUT[6] = {'.', '-', '+', '*', 'X', 'M'};

  std::vector<Sphere> SCENE = {{{-1.0, 0.0, 3.0}, 0.3, RED},
                               {{0.0, 0.0, 3.0}, 0.8, GREEN},
                               {{1.0, 0.0, 3.0}, 0.4, BLUE}};

  int32_t w, h;
  uint32_t result_val;

  int shade_pixel(const Ray &ray, const Sphere &obj, double tval) {
    Vector pi = ray.orig.add(ray.dir.scale(tval));
    Color color = diffuse_shading(pi, obj, LIGHT1);
    double col = (color.r + color.g + color.b) / 3.0;
    int idx = static_cast<int>(col * 6.0);
    if (idx < 0)
      idx = 0;
    if (idx >= 6)
      idx = 5;
    return idx;
  }

  std::optional<double> intersect_sphere(const Ray &ray, const Vector &center,
                                         double radius) {
    Vector l = center.sub(ray.orig);
    double tca = l.dot(ray.dir);
    if (tca < 0.0)
      return std::nullopt;

    double d2 = l.dot(l) - tca * tca;
    double r2 = radius * radius;
    if (d2 > r2)
      return std::nullopt;

    double thc = std::sqrt(r2 - d2);
    double t0 = tca - thc;
    if (t0 > 10000.0)
      return std::nullopt;

    return t0;
  }

  double clamp(double x, double a, double b) {
    if (x < a)
      return a;
    if (x > b)
      return b;
    return x;
  }

  Color diffuse_shading(const Vector &pi, const Sphere &obj,
                        const Light &light) {
    Vector n = obj.get_normal(pi);
    Vector light_dir = light.position.sub(pi).normalize();
    double lam1 = light_dir.dot(n);
    double lam2 = clamp(lam1, 0.0, 1.0);
    return light.color.scale(lam2 * 0.5).add(obj.color.scale(0.3));
  }

public:
  TextRaytracer() : result_val(0) {
    w = static_cast<int32_t>(config_val("w"));
    h = static_cast<int32_t>(config_val("h"));
  }

  std::string name() const override { return "Etc::TextRaytracer"; }

  void run(int iteration_id) override {
    for (int j = 0; j < h; j++) {
      for (int i = 0; i < w; i++) {
        double fw = w, fi = i, fj = j, fh = h;

        Ray ray{{0.0, 0.0, 0.0},
                Vector{(fi - fw / 2.0) / fw, (fj - fh / 2.0) / fh, 1.0}
                    .normalize()};

        std::optional<double> tval;
        const Sphere *hit_obj = nullptr;

        for (const auto &obj : SCENE) {
          auto intersect = intersect_sphere(ray, obj.center, obj.radius);
          if (intersect) {
            tval = intersect;
            hit_obj = &obj;
            break;
          }
        }

        char pixel = ' ';
        if (hit_obj && tval) {
          pixel = LUT[shade_pixel(ray, *hit_obj, *tval)];
        }
        result_val += static_cast<uint8_t>(pixel);
      }
    }
  }

  uint32_t checksum() override { return result_val; }
};

class NeuralNet : public Benchmark {
private:
  class Neuron;

  class Synapse {
  public:
    double weight;
    double prev_weight;
    Neuron *source_neuron;
    Neuron *dest_neuron;

    Synapse(Neuron *source, Neuron *dest)
        : source_neuron(source), dest_neuron(dest) {
      weight = prev_weight = Helper::next_float() * 2 - 1;
    }
  };

  class Neuron {
  private:
    static constexpr double LEARNING_RATE = 1.0;
    static constexpr double MOMENTUM = 0.3;

    std::vector<Synapse *> synapses_in;
    std::vector<Synapse *> synapses_out;
    double threshold;
    double prev_threshold;
    double error;
    double output;

  public:
    Neuron() {
      threshold = prev_threshold = Helper::next_float() * 2 - 1;
      output = 0.0;
      error = 0.0;
    }

    void calculate_output() {
      double activation = 0.0;
      for (auto synapse : synapses_in) {
        activation += synapse->weight * synapse->source_neuron->output;
      }
      activation -= threshold;
      output = 1.0 / (1.0 + std::exp(-activation));
    }

    double derivative() const { return output * (1 - output); }

    void output_train(double rate, double target) {
      error = (target - output) * derivative();
      update_weights(rate);
    }

    void hidden_train(double rate) {
      double sum = 0.0;
      for (auto synapse : synapses_out) {
        sum += synapse->prev_weight * synapse->dest_neuron->error;
      }
      error = sum * derivative();
      update_weights(rate);
    }

    void update_weights(double rate) {
      for (auto synapse : synapses_in) {
        double temp_weight = synapse->weight;
        synapse->weight +=
            (rate * LEARNING_RATE * error * synapse->source_neuron->output) +
            (MOMENTUM * (synapse->weight - synapse->prev_weight));
        synapse->prev_weight = temp_weight;
      }

      double temp_threshold = threshold;
      threshold += (rate * LEARNING_RATE * error * -1) +
                   (MOMENTUM * (threshold - prev_threshold));
      prev_threshold = temp_threshold;
    }

    void add_synapse_in(Synapse *synapse) { synapses_in.push_back(synapse); }
    void add_synapse_out(Synapse *synapse) { synapses_out.push_back(synapse); }
    void set_output(double val) { output = val; }
    double get_output() const { return output; }
  };

  class NeuralNetwork {
  private:
    std::vector<Neuron> input_layer;
    std::vector<Neuron> hidden_layer;
    std::vector<Neuron> output_layer;
    std::vector<std::unique_ptr<Synapse>> synapses;

  public:
    NeuralNetwork(int inputs, int hidden, int outputs)
        : input_layer(inputs), hidden_layer(hidden), output_layer(outputs) {

      for (auto &source : input_layer) {
        for (auto &dest : hidden_layer) {
          auto synapse = std::make_unique<Synapse>(&source, &dest);
          source.add_synapse_out(synapse.get());
          dest.add_synapse_in(synapse.get());
          synapses.push_back(std::move(synapse));
        }
      }

      for (auto &source : hidden_layer) {
        for (auto &dest : output_layer) {
          auto synapse = std::make_unique<Synapse>(&source, &dest);
          source.add_synapse_out(synapse.get());
          dest.add_synapse_in(synapse.get());
          synapses.push_back(std::move(synapse));
        }
      }
    }

    void train(const std::vector<double> &inputs,
               const std::vector<double> &targets) {
      feed_forward(inputs);

      for (size_t i = 0; i < output_layer.size(); i++) {
        output_layer[i].output_train(0.3, targets[i]);
      }

      for (auto &neuron : hidden_layer) {
        neuron.hidden_train(0.3);
      }
    }

    void feed_forward(const std::vector<double> &inputs) {
      for (size_t i = 0; i < input_layer.size(); i++) {
        input_layer[i].set_output(inputs[i]);
      }

      for (auto &neuron : hidden_layer) {
        neuron.calculate_output();
      }

      for (auto &neuron : output_layer) {
        neuron.calculate_output();
      }
    }

    std::vector<double> current_outputs() {
      std::vector<double> outputs;
      outputs.reserve(output_layer.size());
      for (const auto &neuron : output_layer) {
        outputs.push_back(neuron.get_output());
      }
      return outputs;
    }
  };

  std::unique_ptr<NeuralNetwork> xor_net;

public:
  NeuralNet() { xor_net = std::make_unique<NeuralNetwork>(0, 0, 0); }

  std::string name() const override { return "Etc::NeuralNet"; }

  void prepare() override {
    xor_net = std::make_unique<NeuralNetwork>(2, 10, 1);
  }

  void run(int iteration_id) override {
    NeuralNetwork &xor_ref = *xor_net;

    static const std::vector<double> INPUT_00 = {0, 0};
    static const std::vector<double> INPUT_01 = {0, 1};
    static const std::vector<double> INPUT_10 = {1, 0};
    static const std::vector<double> INPUT_11 = {1, 1};
    static const std::vector<double> TARGET_0 = {0};
    static const std::vector<double> TARGET_1 = {1};

    for (int iter = 0; iter < 1000; iter++) {
      xor_ref.train(INPUT_00, TARGET_0);
      xor_ref.train(INPUT_10, TARGET_1);
      xor_ref.train(INPUT_01, TARGET_1);
      xor_ref.train(INPUT_11, TARGET_0);
    }
  }

  uint32_t checksum() override {
    xor_net->feed_forward({0, 0});
    auto outputs1 = xor_net->current_outputs();

    xor_net->feed_forward({0, 1});
    auto outputs2 = xor_net->current_outputs();

    xor_net->feed_forward({1, 0});
    auto outputs3 = xor_net->current_outputs();

    xor_net->feed_forward({1, 1});
    auto outputs4 = xor_net->current_outputs();

    std::vector<double> all_outputs;
    all_outputs.insert(all_outputs.end(), outputs1.begin(), outputs1.end());
    all_outputs.insert(all_outputs.end(), outputs2.begin(), outputs2.end());
    all_outputs.insert(all_outputs.end(), outputs3.begin(), outputs3.end());
    all_outputs.insert(all_outputs.end(), outputs4.begin(), outputs4.end());

    double sum = 0.0;
    for (double v : all_outputs) {
      sum += v;
    }
    return Helper::checksum_f64(sum);
  }
};

class SortBenchmark : public Benchmark {
protected:
  std::vector<int32_t> data;
  int64_t size_val;
  uint32_t result_val;

  SortBenchmark() : result_val(0), size_val(0) {}

public:
  virtual std::vector<int32_t> test() = 0;

  void prepare() override {
    if (size_val == 0) {
      size_val = config_val("size");
      data.reserve(static_cast<size_t>(size_val));
      for (int64_t i = 0; i < size_val; i++) {
        data.push_back(Helper::next_int(1'000'000));
      }
    }
  }

  void run(int iteration_id) override {

    result_val += data[Helper::next_int(static_cast<int32_t>(size_val))];
    std::vector<int32_t> t = test();
    result_val += t[Helper::next_int(static_cast<int32_t>(size_val))];
  }

  uint32_t checksum() override { return result_val; }
};

class SortQuick : public SortBenchmark {
private:
  void quick_sort(std::vector<int32_t> &arr, int low, int high) {
    if (low >= high)
      return;

    int pivot = arr[(low + high) / 2];
    int i = low, j = high;

    while (i <= j) {
      while (arr[i] < pivot)
        i++;
      while (arr[j] > pivot)
        j--;
      if (i <= j) {
        std::swap(arr[i], arr[j]);
        i++;
        j--;
      }
    }

    quick_sort(arr, low, j);
    quick_sort(arr, i, high);
  }

public:
  SortQuick() = default;

  std::string name() const override { return "Sort::Quick"; }

  std::vector<int32_t> test() override {
    std::vector<int32_t> arr = data;
    quick_sort(arr, 0, static_cast<int>(arr.size() - 1));
    return arr;
  }
};

class SortMerge : public SortBenchmark {
private:
  void merge_sort_inplace(std::vector<int32_t> &arr) {
    std::vector<int32_t> temp(arr.size());
    merge_sort_helper(arr, temp, 0, static_cast<int>(arr.size() - 1));
  }

  void merge_sort_helper(std::vector<int32_t> &arr, std::vector<int32_t> &temp,
                         int left, int right) {
    if (left >= right)
      return;

    int mid = (left + right) / 2;
    merge_sort_helper(arr, temp, left, mid);
    merge_sort_helper(arr, temp, mid + 1, right);
    merge(arr, temp, left, mid, right);
  }

  void merge(std::vector<int32_t> &arr, std::vector<int32_t> &temp, int left,
             int mid, int right) {
    for (int i = left; i <= right; i++) {
      temp[i] = arr[i];
    }

    int i = left;
    int j = mid + 1;
    int k = left;

    while (i <= mid && j <= right) {
      if (temp[i] <= temp[j]) {
        arr[k] = temp[i];
        i++;
      } else {
        arr[k] = temp[j];
        j++;
      }
      k++;
    }

    while (i <= mid) {
      arr[k] = temp[i];
      i++;
      k++;
    }
  }

public:
  SortMerge() = default;

  std::string name() const override { return "Sort::Merge"; }

  std::vector<int32_t> test() override {
    std::vector<int32_t> arr = data;
    merge_sort_inplace(arr);
    return arr;
  }
};

class SortSelf : public SortBenchmark {
public:
  SortSelf() = default;

  std::string name() const override { return "Sort::Self"; }

  std::vector<int32_t> test() override {
    std::vector<int32_t> arr = data;
    std::sort(arr.begin(), arr.end());
    return arr;
  }
};

class GraphPathBenchmark : public Benchmark {
protected:
  class Graph {
  public:
    int vertices;
    int jumps;
    int jump_len;
    std::vector<std::vector<int>> adj;

    Graph(int vertices, int jumps = 3, int jump_len = 100)
        : vertices(vertices), jumps(jumps), jump_len(jump_len), adj(vertices) {}

    void add_edge(int u, int v) {
      adj[u].push_back(v);
      adj[v].push_back(u);
    }

    void generate_random() {
      for (int i = 1; i < vertices; i++) {
        add_edge(i, i - 1);
      }

      for (int v = 0; v < vertices; v++) {
        int num_jumps = Helper::next_int(jumps);
        for (int j = 0; j < num_jumps; j++) {
          int offset = Helper::next_int(jump_len) - jump_len / 2;
          int u = v + offset;

          if (u >= 0 && u < vertices && u != v) {
            add_edge(v, u);
          }
        }
      }
    }
  };

  std::unique_ptr<Graph> graph;
  uint32_t result_val;

public:
  GraphPathBenchmark() : result_val(0) {}

  void prepare() override {
    int vertices = static_cast<int>(config_val("vertices"));
    int jumps = static_cast<int>(config_val("jumps"));
    int jump_len = static_cast<int>(config_val("jump_len"));
    graph = std::make_unique<Graph>(vertices, jumps, jump_len);
    graph->generate_random();
  }

  virtual int64_t test() = 0;

  void run(int iteration_id) override { result_val += test(); }

  uint32_t checksum() override { return result_val; }
};

class GraphPathBFS : public GraphPathBenchmark {
private:
  int bfs_shortest_path(int start, int target) {
    if (start == target)
      return 0;

    std::vector<uint8_t> visited(graph->vertices, 0);
    std::queue<std::pair<int, int>> queue;

    visited[start] = 1;
    queue.push({start, 0});

    while (!queue.empty()) {
      auto [v, dist] = queue.front();
      queue.pop();

      for (int neighbor : graph->adj[v]) {
        if (neighbor == target) {
          return dist + 1;
        }

        if (visited[neighbor] == 0) {
          visited[neighbor] = 1;
          queue.push({neighbor, dist + 1});
        }
      }
    }

    return -1;
  }

public:
  GraphPathBFS() = default;

  std::string name() const override { return "Graph::BFS"; }

  int64_t test() override { return bfs_shortest_path(0, graph->vertices - 1); }
};

class GraphPathDFS : public GraphPathBenchmark {
private:
  int dfs_shortest_path(int start, int target) {
    if (start == target)
      return 0;

    std::vector<uint8_t> visited(graph->vertices, 0);
    std::stack<std::pair<int, int>> stack;
    int best_path = INT_MAX;

    stack.push({start, 0});

    while (!stack.empty()) {
      auto [v, dist] = stack.top();
      stack.pop();

      if (visited[v] == 1 || dist >= best_path)
        continue;
      visited[v] = 1;

      for (int neighbor : graph->adj[v]) {
        if (neighbor == target) {
          if (dist + 1 < best_path) {
            best_path = dist + 1;
          }
        } else if (visited[neighbor] == 0) {
          stack.push({neighbor, dist + 1});
        }
      }
    }

    return (best_path == INT_MAX) ? -1 : best_path;
  }

public:
  GraphPathDFS() = default;

  std::string name() const override { return "Graph::DFS"; }

  int64_t test() override { return dfs_shortest_path(0, graph->vertices - 1); }
};

class GraphPathAStar : public GraphPathBenchmark {
private:
  struct Node {
    int vertex;
    int f_score;

    bool operator>(const Node &other) const { return f_score > other.f_score; }
  };

  int heuristic(int v, int target) const { return target - v; }

  int astar_shortest_path(int start, int target) {
    if (start == target)
      return 0;

    std::vector<int> g_score(graph->vertices, INT_MAX);
    g_score[start] = 0;

    using QueueType =
        std::priority_queue<Node, std::vector<Node>, std::greater<Node>>;
    QueueType open_set;
    open_set.push({start, heuristic(start, target)});

    std::vector<bool> in_open_set(graph->vertices, false);
    in_open_set[start] = true;

    std::vector<bool> closed(graph->vertices, false);

    while (!open_set.empty()) {
      Node current = open_set.top();
      open_set.pop();

      if (closed[current.vertex])
        continue;
      closed[current.vertex] = true;
      in_open_set[current.vertex] = false;

      if (current.vertex == target) {
        return g_score[current.vertex];
      }

      for (int neighbor : graph->adj[current.vertex]) {
        if (closed[neighbor])
          continue;

        int tentative_g = g_score[current.vertex] + 1;

        if (tentative_g < g_score[neighbor]) {
          g_score[neighbor] = tentative_g;
          int f = tentative_g + heuristic(neighbor, target);

          if (!in_open_set[neighbor]) {
            open_set.push({neighbor, f});
            in_open_set[neighbor] = true;
          }
        }
      }
    }

    return -1;
  }

public:
  GraphPathAStar() = default;

  std::string name() const override { return "Graph::AStar"; }

  int64_t test() override {
    return astar_shortest_path(0, graph->vertices - 1);
  }
};

class BufferHashBenchmark : public Benchmark {
protected:
  std::vector<uint8_t> data;
  int64_t size_val;
  uint32_t result_val;

  BufferHashBenchmark() : result_val(0), size_val(0) {}

public:
  virtual uint32_t test() = 0;

  void prepare() override {
    if (size_val == 0) {
      size_val = config_val("size");
      data.resize(static_cast<size_t>(size_val));
      for (size_t i = 0; i < static_cast<size_t>(size_val); i++) {
        data[i] = static_cast<uint8_t>(Helper::next_int(256));
      }
    }
  }

  void run(int iteration_id) override { result_val += test(); }

  uint32_t checksum() override { return result_val; }
};

class BufferHashSHA256 : public BufferHashBenchmark {
private:
  struct SimpleSHA256 {
    static std::vector<uint8_t> digest(const std::vector<uint8_t> &data) {
      std::vector<uint8_t> result(32);

      uint32_t hashes[8] = {0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
                            0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19};

      for (size_t i = 0; i < data.size(); i++) {
        uint32_t hash_idx = i & 7;
        uint32_t &hash = hashes[hash_idx];
        hash = ((hash << 5) + hash) + data[i];
        hash = (hash + (hash << 10)) ^ (hash >> 6);
      }

      for (int i = 0; i < 8; i++) {
        result[i * 4] = static_cast<uint8_t>(hashes[i] >> 24);
        result[i * 4 + 1] = static_cast<uint8_t>(hashes[i] >> 16);
        result[i * 4 + 2] = static_cast<uint8_t>(hashes[i] >> 8);
        result[i * 4 + 3] = static_cast<uint8_t>(hashes[i]);
      }

      return result;
    }
  };

public:
  BufferHashSHA256() = default;

  std::string name() const override { return "Hash::SHA256"; }

  uint32_t test() override {
    auto bytes = SimpleSHA256::digest(data);
    return *reinterpret_cast<uint32_t *>(bytes.data());
  }
};

class BufferHashCRC32 : public BufferHashBenchmark {
private:
  uint32_t crc32(const std::vector<uint8_t> &data) {
    uint32_t crc = 0xFFFFFFFFu;

    for (uint8_t byte : data) {
      crc = crc ^ byte;
      for (int j = 0; j < 8; j++) {
        if (crc & 1) {
          crc = (crc >> 1) ^ 0xEDB88320u;
        } else {
          crc = crc >> 1;
        }
      }
    }
    return crc ^ 0xFFFFFFFFu;
  }

public:
  BufferHashCRC32() = default;

  std::string name() const override { return "Hash::CRC32"; }

  uint32_t test() override { return crc32(data); }
};

class CacheSimulation : public Benchmark {
  template <typename K, typename V> class LRUCache {
  private:
    struct Node {
      K key;
      V value;
      Node *prev;
      Node *next;

      Node(const K &k, const V &v)
          : key(k), value(v), prev(nullptr), next(nullptr) {}
    };

    int capacity_;
    std::unordered_map<K, Node *> cache_;
    Node *head_;
    Node *tail_;
    int size_;

    void move_to_front(Node *node) {
      if (node == head_)
        return;

      if (node->prev) {
        node->prev->next = node->next;
      }
      if (node->next) {
        node->next->prev = node->prev;
      }

      if (node == tail_) {
        tail_ = node->prev;
      }

      node->prev = nullptr;
      node->next = head_;
      if (head_) {
        head_->prev = node;
      }
      head_ = node;

      if (!tail_) {
        tail_ = node;
      }
    }

    void add_to_front(Node *node) {
      node->next = head_;
      if (head_) {
        head_->prev = node;
      }
      head_ = node;
      if (!tail_) {
        tail_ = node;
      }
    }

    void remove_oldest() {
      if (!tail_)
        return;

      Node *oldest = tail_;
      cache_.erase(oldest->key);

      if (oldest->prev) {
        oldest->prev->next = nullptr;
      }
      tail_ = oldest->prev;

      if (head_ == oldest) {
        head_ = nullptr;
      }

      delete oldest;
      size_--;
    }

  public:
    LRUCache(int capacity)
        : capacity_(capacity), head_(nullptr), tail_(nullptr), size_(0) {}

    ~LRUCache() {
      Node *current = head_;
      while (current) {
        Node *next = current->next;
        delete current;
        current = next;
      }
    }

    std::optional<V> get(const K &key) {
      auto it = cache_.find(key);
      if (it == cache_.end()) {
        return std::nullopt;
      }

      Node *node = it->second;
      move_to_front(node);
      return node->value;
    }

    void put(const K &key, const V &value) {
      auto it = cache_.find(key);
      if (it != cache_.end()) {
        Node *node = it->second;
        node->value = value;
        move_to_front(node);
        return;
      }

      if (size_ >= capacity_) {
        remove_oldest();
      }

      Node *node = new Node(key, value);
      cache_[key] = node;
      add_to_front(node);
      size_++;
    }

    int size() const { return size_; }
  };

private:
  uint32_t result_val;
  int values_size;
  LRUCache<std::string, std::string> cache;
  int hits;
  int misses;

public:
  CacheSimulation()
      : result_val(5432), values_size(config_val("values")),
        cache(config_val("size")), hits(0), misses(0) {}

  std::string name() const override { return "Etc::CacheSimulation"; }

  void run(int iteration_id) {
    for (int i = 0; i < 1000; i++) {

      char key_buf[32];
      snprintf(key_buf, sizeof(key_buf), "item_%d",
               Helper::next_int(values_size));
      std::string key(key_buf);

      auto value = cache.get(key);
      if (value.has_value()) {
        hits++;

        char val_buf[32];
        snprintf(val_buf, sizeof(val_buf), "updated_%d", iteration_id);
        cache.put(key, std::string(val_buf));
      } else {
        misses++;

        char val_buf[32];
        snprintf(val_buf, sizeof(val_buf), "new_%d", iteration_id);
        cache.put(key, std::string(val_buf));
      }
    }
  }

  uint32_t checksum() {
    uint32_t result = result_val;
    result = (result << 5) + hits;
    result = (result << 5) + misses;
    result = (result << 5) + static_cast<uint32_t>(cache.size());
    return result;
  }
};

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
    const std::string input;
    size_t pos;
    char current_char;
    std::vector<char> chars;
    std::vector<Node> expressions;

    void advance() {
      pos += 1;
      if (pos >= chars.size()) {
        current_char = '\0';
      } else {
        current_char = chars[pos];
      }
    }

    void skip_whitespace() {
      while (current_char != '\0' &&
             std::isspace(static_cast<unsigned char>(current_char))) {
        advance();
      }
    }

    Node parse_number() {
      int64_t v = 0;
      while (current_char != '\0' &&
             std::isdigit(static_cast<unsigned char>(current_char))) {
        v = v * 10 + (current_char - '0');
        advance();
      }
      return Node(Number{v});
    }

    Node parse_variable() {
      size_t start = pos;
      while (current_char != '\0' &&
             (std::isalpha(static_cast<unsigned char>(current_char)) ||
              std::isdigit(static_cast<unsigned char>(current_char)))) {
        advance();
      }
      std::string var_name = input.substr(start, pos - start);

      skip_whitespace();
      if (current_char == '=') {
        advance();
        auto expr = parse_expression();
        return Node(std::make_unique<Assignment>(var_name, std::move(expr)));
      }

      return Node(Variable{var_name});
    }

    Node parse_factor() {
      skip_whitespace();
      if (current_char == '\0') {
        return Node(Number{0});
      }

      if (std::isdigit(static_cast<unsigned char>(current_char))) {
        return parse_number();
      }

      if (std::isalpha(static_cast<unsigned char>(current_char))) {
        return parse_variable();
      }

      if (current_char == '(') {
        advance();
        auto node = parse_expression();
        skip_whitespace();
        if (current_char == ')') {
          advance();
        }
        return node;
      }

      return Node(Number{0});
    }

    Node parse_term() {
      auto node = parse_factor();

      while (true) {
        skip_whitespace();
        if (current_char == '\0')
          break;

        if (current_char == '*' || current_char == '/' || current_char == '%') {
          char op = current_char;
          advance();
          auto right = parse_factor();
          node = Node(std::make_unique<BinaryOp>(op, std::move(node),
                                                 std::move(right)));
        } else {
          break;
        }
      }

      return node;
    }

    Node parse_expression() {
      auto node = parse_term();

      while (true) {
        skip_whitespace();
        if (current_char == '\0')
          break;

        if (current_char == '+' || current_char == '-') {
          char op = current_char;
          advance();
          auto right = parse_term();
          node = Node(std::make_unique<BinaryOp>(op, std::move(node),
                                                 std::move(right)));
        } else {
          break;
        }
      }

      return node;
    }

  public:
    Parser(const std::string &input_str) : input(input_str), pos(0) {
      for (char c : input_str) {
        chars.push_back(c);
      }
      if (chars.empty()) {
        current_char = '\0';
      } else {
        current_char = chars[0];
      }
    }

    std::vector<Node> parse() {
      expressions.clear();
      while (current_char != '\0') {
        skip_whitespace();
        if (current_char == '\0')
          break;
        expressions.push_back(parse_expression());
      }
      return std::move(expressions);
    }
  };

  uint32_t result_val;
  std::string text;

  std::string generate_random_program(int64_t n = 1000) {
    std::ostringstream os;
    os << "v0 = 1\n";
    for (int i = 0; i < 10; i++) {
      int v = i + 1;
      os << "v" << v << " = v" << (v - 1) << " + " << v << "\n";
    }
    for (int64_t i = 0; i < n; i++) {
      int v = static_cast<int>(i + 10);
      os << "v" << v << " = v" << (v - 1) << " + ";

      switch (Helper::next_int(10)) {
      case 0:
        os << "(v" << (v - 1) << " / 3) * 4 - " << i << " / (3 + (18 - v"
           << (v - 2) << ")) % v" << (v - 3) << " + 2 * ((9 - v" << (v - 6)
           << ") * (v" << (v - 5) << " + 7))";
        break;
      case 1:
        os << "v" << (v - 1) << " + (v" << (v - 2) << " + v" << (v - 3)
           << ") * v" << (v - 4) << " - (v" << (v - 5) << " / v" << (v - 6)
           << ")";
        break;
      case 2:
        os << "(3789 - (((v" << (v - 7) << ")))) + 1";
        break;
      case 3:
        os << "4/2 * (1-3) + v" << (v - 9) << "/v" << (v - 5);
        break;
      case 4:
        os << "1+2+3+4+5+6+v" << (v - 1);
        break;
      case 5:
        os << "(99999 / v" << (v - 3) << ")";
        break;
      case 6:
        os << "0 + 0 - v" << (v - 8);
        break;
      case 7:
        os << "((((((((((v" << (v - 6) << ")))))))))) * 2";
        break;
      case 8:
        os << i << " * (v" << (v - 1) << "%6)%7";
        break;
      case 9:
        os << "(1)/(0-v" << (v - 5) << ") + (v" << (v - 7) << ")";
        break;
      }
      os << "\n";
    }
    return os.str();
  }

public:
  int64_t n;
  CalculatorAst() : result_val(0), n(config_val("operations")) {}

  std::string name() const override { return "Calculator::Ast"; }
  std::vector<Node> expressions;

  void prepare() override { text = generate_random_program(n); }

  void run(int iteration_id) override {
    Parser parser(text);
    expressions = parser.parse();
    result_val += expressions.size();
    if (!expressions.empty() &&
        std::holds_alternative<std::unique_ptr<Assignment>>(
            expressions.back().data)) {
      auto &assign =
          *std::get<std::unique_ptr<Assignment>>(expressions.back().data);
      result_val += Helper::checksum(assign.var);
    }
  }

  uint32_t checksum() override { return result_val; }

  std::vector<Node> take_ast() { return std::move(expressions); }
};

class CalculatorInterpreter : public Benchmark {
private:
  class Interpreter {
  private:
    std::unordered_map<std::string, int64_t> variables;

    static int64_t simple_div(int64_t a, int64_t b) {
      if (b == 0)
        return 0;
      if ((a >= 0 && b > 0) || (a < 0 && b < 0)) {
        return a / b;
      } else {
        return -(std::abs(a) / std::abs(b));
      }
    }

    static int64_t simple_mod(int64_t a, int64_t b) {
      if (b == 0)
        return 0;
      return a - simple_div(a, b) * b;
    }

    struct Evaluator {
      std::unordered_map<std::string, int64_t> &variables;

      Evaluator(std::unordered_map<std::string, int64_t> &vars)
          : variables(vars) {}

      int64_t operator()(const CalculatorAst::Number &n) const {
        return n.value;
      }

      int64_t operator()(const CalculatorAst::Variable &v) const {
        auto it = variables.find(v.name);
        return (it != variables.end()) ? it->second : 0;
      }

      int64_t
      operator()(const std::unique_ptr<CalculatorAst::BinaryOp> &binop) const {
        int64_t left = std::visit(*this, binop->left.data);
        int64_t right = std::visit(*this, binop->right.data);

        switch (binop->op) {
        case '+':
          return left + right;
        case '-':
          return left - right;
        case '*':
          return left * right;
        case '/':
          return simple_div(left, right);
        case '%':
          return simple_mod(left, right);
        default:
          return 0;
        }
      }

      int64_t operator()(
          const std::unique_ptr<CalculatorAst::Assignment> &assign) const {
        int64_t value = std::visit(*this, assign->expr.data);
        variables[assign->var] = value;
        return value;
      }
    };

  public:
    int64_t run(const std::vector<CalculatorAst::Node> &expressions) {
      int64_t result = 0;
      Evaluator evaluator(variables);

      for (const auto &expr : expressions) {
        result = std::visit(evaluator, expr.data);
      }
      return result;
    }

    void clear() { variables.clear(); }
  };

  int64_t n;
  uint32_t result_val;
  std::vector<CalculatorAst::Node> ast;

public:
  CalculatorInterpreter() : result_val(0) { n = config_val("operations"); }

  std::string name() const override { return "Calculator::Interpreter"; }

  void prepare() override {
    CalculatorAst ca;
    ca.n = n;
    ca.prepare();
    ca.run(0);
    ast = ca.take_ast();
  }

  void run(int iteration_id) override {
    Interpreter interpreter;
    int64_t result = interpreter.run(ast);
    result_val += result;
  }

  uint32_t checksum() override { return result_val; }
};

class GameOfLife : public Benchmark {
private:
  class Cell {
  private:
    bool alive;
    bool next_state;
    std::vector<Cell *> neighbors;

  public:
    Cell(bool alive = false) : alive(alive), next_state(false) {}

    void add_neighbor(Cell *cell) { neighbors.push_back(cell); }

    void compute_next_state() {
      int alive_neighbors = 0;
      for (Cell *neighbor : neighbors) {
        if (neighbor->alive)
          alive_neighbors++;
      }

      if (alive) {
        next_state = (alive_neighbors == 2 || alive_neighbors == 3);
      } else {
        next_state = (alive_neighbors == 3);
      }
    }

    void update() { alive = next_state; }

    void set_alive(bool state) { alive = state; }

    bool is_alive() const { return alive; }
  };

  class Grid {
  private:
    int width;
    int height;
    std::vector<std::vector<Cell>> cells;

  public:
    Grid(int w, int h) : width(w), height(h) {
      cells.resize(height);
      for (int y = 0; y < height; ++y) {
        cells[y].reserve(width);
        for (int x = 0; x < width; ++x) {
          cells[y].emplace_back(false);
        }
      }
      link_neighbors();
    }

  private:
    void link_neighbors() {
      for (int y = 0; y < height; ++y) {
        for (int x = 0; x < width; ++x) {
          Cell &cell = cells[y][x];
          for (int dy = -1; dy <= 1; ++dy) {
            for (int dx = -1; dx <= 1; ++dx) {
              if (dx == 0 && dy == 0)
                continue;

              int ny = (y + dy + height) % height;
              int nx = (x + dx + width) % width;

              cell.add_neighbor(&cells[ny][nx]);
            }
          }
        }
      }
    }

  public:
    void next_generation() {
      for (auto &row : cells) {
        for (auto &cell : row) {
          cell.compute_next_state();
        }
      }
      for (auto &row : cells) {
        for (auto &cell : row) {
          cell.update();
        }
      }
    }

    std::vector<std::vector<Cell>> &get_cells() { return cells; }

    int count_alive() const {
      int count = 0;
      for (const auto &row : cells) {
        for (const auto &cell : row) {
          if (cell.is_alive())
            count++;
        }
      }
      return count;
    }

    uint32_t compute_hash() const {
      constexpr uint32_t FNV_OFFSET_BASIS = 2166136261UL;
      constexpr uint32_t FNV_PRIME = 16777619UL;
      uint32_t hash = FNV_OFFSET_BASIS;
      for (const auto &row : cells) {
        for (const auto &cell : row) {
          uint32_t alive = cell.is_alive() ? 1U : 0U;
          hash = (hash ^ alive) * FNV_PRIME;
        }
      }
      return hash;
    }
  };

  int32_t width;
  int32_t height;
  Grid grid;

public:
  GameOfLife()
      : width(static_cast<int32_t>(config_val("w"))),
        height(static_cast<int32_t>(config_val("h"))), grid(width, height) {}

  std::string name() const override { return "Etc::GameOfLife"; }

  void prepare() override {
    for (auto &row : grid.get_cells()) {
      for (auto &cell : row) {
        if (Helper::next_float(1.0) < 0.1) {
          cell.set_alive(true);
        }
      }
    }
  }

  void run(int iteration_id) override { grid.next_generation(); }

  uint32_t checksum() override {
    uint32_t alive = static_cast<uint32_t>(grid.count_alive());
    return grid.compute_hash() + alive;
  }
};

class MazeGenerator : public Benchmark {
public:
  enum class CellKind : uint8_t {
    Wall = 0,
    Space,
    Start,
    Finish,
    Border,
    Path
  };

  class Cell {
  public:
    CellKind kind;
    std::vector<Cell *> neighbors;
    int x;
    int y;

    Cell(int x, int y) : kind(CellKind::Wall), x(x), y(y) {
      neighbors.reserve(4);
    }

    bool is_walkable() const {
      return kind == CellKind::Space || kind == CellKind::Start ||
             kind == CellKind::Finish;
    }

    void reset() {
      if (kind == CellKind::Space) {
        kind = CellKind::Wall;
      }
    }

    uint32_t value() const { return static_cast<uint32_t>(kind); }
  };

  class Maze {
  private:
    int w;
    int h;
    std::vector<std::vector<Cell>> cells;
    Cell *start;
    Cell *finish;

  public:
    Maze(int width, int height) : w(width), h(height) {
      cells.reserve(h);
      for (int y = 0; y < h; ++y) {
        auto &row = cells.emplace_back();
        row.reserve(w);
        for (int x = 0; x < w; ++x) {
          row.emplace_back(x, y);
        }
      }

      start = &cells[1][1];
      finish = &cells[h - 2][w - 2];
      start->kind = CellKind::Start;
      finish->kind = CellKind::Finish;

      update_neighbors();
    }

    void update_neighbors() {
      for (int y = 0; y < h; ++y) {
        for (int x = 0; x < w; ++x) {
          auto &cell = cells[y][x];

          if (x > 0 && y > 0 && x < w - 1 && y < h - 1) {
            cell.neighbors = {&cells[y - 1][x], &cells[y + 1][x],
                              &cells[y][x + 1], &cells[y][x - 1]};

            for (int t = 0; t < 4; ++t) {
              int i = Helper::next_int(4);
              int j = Helper::next_int(4);
              if (i != j) {
                std::swap(cell.neighbors[i], cell.neighbors[j]);
              }
            }
          } else {
            cell.kind = CellKind::Border;
          }
        }
      }
    }

    void reset() {
      for (auto &row : cells) {
        for (auto &cell : row) {
          cell.reset();
        }
      }
      start->kind = CellKind::Start;
      finish->kind = CellKind::Finish;
    }

    void dig(Cell *start_cell) {
      if (!start_cell)
        return;

      std::vector<Cell *> stack;

      stack.push_back(start_cell);

      while (!stack.empty()) {
        auto *cell = stack.back();
        stack.pop_back();

        int walkable = 0;
        for (auto *n : cell->neighbors) {
          if (n->is_walkable())
            ++walkable;
        }

        if (walkable != 1)
          continue;

        cell->kind = CellKind::Space;

        for (auto *n : cell->neighbors) {
          if (n->kind == CellKind::Wall) {
            stack.push_back(n);
          }
        }
      }
    }

    void ensure_open_finish(Cell *start_cell) {
      if (!start_cell)
        return;

      std::vector<Cell *> stack;
      stack.push_back(start_cell);

      while (!stack.empty()) {
        auto *cell = stack.back();
        stack.pop_back();

        cell->kind = CellKind::Space;

        int walkable = 0;
        for (auto *n : cell->neighbors) {
          if (n->is_walkable())
            ++walkable;
        }

        if (walkable > 1)
          continue;

        for (auto *n : cell->neighbors) {
          if (n->kind == CellKind::Wall) {
            stack.push_back(n);
          }
        }
      }
    }

    void generate() {
      for (auto *n : start->neighbors) {
        if (n->kind == CellKind::Wall) {
          dig(n);
        }
      }

      for (auto *n : finish->neighbors) {
        if (n->kind == CellKind::Wall) {
          ensure_open_finish(n);
        }
      }
    }

    Cell *middle_cell() { return &cells[h / 2][w / 2]; }

    Cell *get_start() { return start; }
    Cell *get_finish() { return finish; }

    Cell *get_cell(int x, int y) {
      if (x >= 0 && x < w && y >= 0 && y < h) {
        return &cells[y][x];
      }
      return nullptr;
    }

    uint32_t checksum() const {
      uint32_t hasher = 2166136261UL;
      uint32_t prime = 16777619UL;

      for (int y = 0; y < h; ++y) {
        for (int x = 0; x < w; ++x) {
          if (cells[y][x].kind == CellKind::Space) {
            uint32_t val = static_cast<uint32_t>(x * y);
            hasher = (hasher ^ val) * prime;
          }
        }
      }
      return hasher;
    }

    void print_to_console() const {
      for (int y = 0; y < h; ++y) {
        for (int x = 0; x < w; ++x) {
          switch (cells[y][x].kind) {
          case CellKind::Space:
            std::cout << ' ';
            break;
          case CellKind::Wall:
            std::cout << "\033[34m#\033[0m";
            break;
          case CellKind::Border:
            std::cout << "\033[31mO\033[0m";
            break;
          case CellKind::Start:
            std::cout << "\033[32m>\033[0m";
            break;
          case CellKind::Finish:
            std::cout << "\033[32m<\033[0m";
            break;
          case CellKind::Path:
            std::cout << "\033[33m.\033[0m";
            break;
          }
        }
        std::cout << '\n';
      }
      std::cout << '\n';
    }
  };

private:
  uint32_t result_val;
  int32_t width;
  int32_t height;
  std::unique_ptr<Maze> maze;

public:
  MazeGenerator() : result_val(0) {
    width = static_cast<int32_t>(config_val("w"));
    height = static_cast<int32_t>(config_val("h"));
    maze = std::make_unique<Maze>(width, height);
  }

  std::string name() const override { return "Maze::Generator"; }

  void prepare() override {}

  void run(int) override {
    maze->reset();
    maze->generate();
    result_val += maze->middle_cell()->value();
  }

  uint32_t checksum() override { return result_val + maze->checksum(); }
};

class MazeBFS : public Benchmark {
private:
  uint32_t result_val;
  int32_t width;
  int32_t height;
  std::unique_ptr<MazeGenerator::Maze> maze;
  std::vector<MazeGenerator::Cell *> path;

  std::vector<MazeGenerator::Cell *> bfs(MazeGenerator::Cell *start,
                                         MazeGenerator::Cell *target) {
    if (start == target)
      return {start};

    struct PathNode {
      MazeGenerator::Cell *cell;
      int parent;
    };

    std::deque<int> queue;
    std::vector<std::vector<bool>> visited(height,
                                           std::vector<bool>(width, false));
    std::vector<PathNode> path_nodes;

    visited[start->y][start->x] = true;
    path_nodes.push_back({start, -1});
    queue.push_back(0);

    while (!queue.empty()) {
      int path_id = queue.front();
      queue.pop_front();

      auto *cell = path_nodes[path_id].cell;

      for (auto *neighbor : cell->neighbors) {
        if (neighbor == target) {
          std::vector<MazeGenerator::Cell *> result = {target};
          int current = path_id;
          while (current >= 0) {
            result.push_back(path_nodes[current].cell);
            current = path_nodes[current].parent;
          }
          std::reverse(result.begin(), result.end());
          return result;
        }

        if (neighbor->is_walkable() && !visited[neighbor->y][neighbor->x]) {
          visited[neighbor->y][neighbor->x] = true;
          path_nodes.push_back({neighbor, path_id});
          queue.push_back(path_nodes.size() - 1);
        }
      }
    }

    return {};
  }

  uint32_t mid_cell_checksum(const std::vector<MazeGenerator::Cell *> &p) {
    if (p.empty())
      return 0;
    size_t mid = p.size() / 2;
    auto *cell = p[mid];
    return static_cast<uint32_t>(cell->x * cell->y);
  }

public:
  MazeBFS() : result_val(0) {
    width = static_cast<int32_t>(config_val("w"));
    height = static_cast<int32_t>(config_val("h"));
    maze = std::make_unique<MazeGenerator::Maze>(width, height);
  }

  std::string name() const override { return "Maze::BFS"; }

  void prepare() override { maze->generate(); }

  void run(int) override {
    path = bfs(maze->get_start(), maze->get_finish());
    result_val += static_cast<uint32_t>(path.size());
  }

  uint32_t checksum() override { return result_val + mid_cell_checksum(path); }
};

class MazeAStar : public Benchmark {
private:
  struct Node {
    int f_score;
    int idx;

    bool operator>(const Node &other) const {
      if (f_score != other.f_score)
        return f_score > other.f_score;
      return idx > other.idx;
    }
  };

  uint32_t result_val;
  int32_t width;
  int32_t height;
  std::unique_ptr<MazeGenerator::Maze> maze;
  std::vector<MazeGenerator::Cell *> path;

  int heuristic(MazeGenerator::Cell *a, MazeGenerator::Cell *b) {
    return std::abs(a->x - b->x) + std::abs(a->y - b->y);
  }

  int idx(int y, int x) const { return y * width + x; }

  std::vector<MazeGenerator::Cell *> astar(MazeGenerator::Cell *start,
                                           MazeGenerator::Cell *target) {
    if (start == target)
      return {start};

    int size = width * height;

    std::vector<int> came_from(size, -1);
    std::vector<int> g_score(size, std::numeric_limits<int>::max());
    std::vector<int> best_f(size, std::numeric_limits<int>::max());

    int start_idx = idx(start->y, start->x);
    int target_idx = idx(target->y, target->x);

    std::priority_queue<Node, std::vector<Node>, std::greater<Node>> open_set;

    g_score[start_idx] = 0;
    int f_start = heuristic(start, target);
    open_set.push({f_start, start_idx});
    best_f[start_idx] = f_start;

    while (!open_set.empty()) {
      auto [f_val, current_idx] = open_set.top();
      open_set.pop();

      if (f_val != best_f[current_idx])
        continue;

      if (current_idx == target_idx) {
        std::vector<MazeGenerator::Cell *> result;
        int cur = current_idx;
        while (cur != -1) {
          int y = cur / width;
          int x = cur % width;
          result.push_back(maze->get_cell(x, y));
          cur = came_from[cur];
        }
        std::reverse(result.begin(), result.end());
        return result;
      }

      int current_y = current_idx / width;
      int current_x = current_idx % width;
      auto *current = maze->get_cell(current_x, current_y);
      int current_g = g_score[current_idx];

      for (auto *neighbor : current->neighbors) {
        if (!neighbor->is_walkable())
          continue;

        int neighbor_idx = idx(neighbor->y, neighbor->x);
        int tentative_g = current_g + 1;

        if (tentative_g < g_score[neighbor_idx]) {
          came_from[neighbor_idx] = current_idx;
          g_score[neighbor_idx] = tentative_g;
          int f_new = tentative_g + heuristic(neighbor, target);

          if (f_new < best_f[neighbor_idx]) {
            best_f[neighbor_idx] = f_new;
            open_set.push({f_new, neighbor_idx});
          }
        }
      }
    }

    return {};
  }

  uint32_t mid_cell_checksum(const std::vector<MazeGenerator::Cell *> &p) {
    if (p.empty())
      return 0;
    size_t mid = p.size() / 2;
    auto *cell = p[mid];
    return static_cast<uint32_t>(cell->x * cell->y);
  }

public:
  MazeAStar() : result_val(0) {
    width = static_cast<int32_t>(config_val("w"));
    height = static_cast<int32_t>(config_val("h"));
    maze = std::make_unique<MazeGenerator::Maze>(width, height);
  }

  std::string name() const override { return "Maze::AStar"; }

  void prepare() override { maze->generate(); }

  void run(int) override {
    path = astar(maze->get_start(), maze->get_finish());
    result_val += static_cast<uint32_t>(path.size());
  }

  uint32_t checksum() override { return result_val + mid_cell_checksum(path); }
};

std::vector<uint8_t> generate_test_data(int64_t size) {
  const char *pattern = "ABRACADABRA";
  size_t pattern_len = strlen(pattern);
  std::vector<uint8_t> data(static_cast<size_t>(size));

  for (int64_t i = 0; i < size; i++) {
    data[static_cast<size_t>(i)] = pattern[i % pattern_len];
  }

  return data;
}

class BWTEncode : public Benchmark {
public:
  struct BWTResult {
    std::vector<uint8_t> transformed;
    int32_t original_idx;

    BWTResult(std::vector<uint8_t> t, int32_t idx)
        : transformed(std::move(t)), original_idx(idx) {}
  };

private:
  BWTResult bwt_transform(const std::vector<uint8_t> &input) {
    size_t n = input.size();
    if (n == 0)
      return BWTResult({}, 0);

    int32_t counts[256] = {0};
    for (uint8_t byte : input) {
      counts[byte]++;
    }

    int32_t positions[256] = {0};
    int32_t total = 0;
    for (int i = 0; i < 256; i++) {
      positions[i] = total;
      total += counts[i];
    }

    std::vector<size_t> sa(n);
    int32_t temp_counts[256] = {0};
    for (size_t i = 0; i < n; i++) {
      uint8_t byte = input[i];
      size_t pos = positions[byte] + temp_counts[byte];
      sa[pos] = i;
      temp_counts[byte]++;
    }

    if (n > 1) {
      std::vector<int32_t> rank(n, 0);
      int32_t current_rank = 0;
      uint8_t prev_char = input[sa[0]];

      for (size_t i = 0; i < n; i++) {
        size_t idx = sa[i];
        uint8_t curr_char = input[idx];
        if (curr_char != prev_char) {
          current_rank++;
          prev_char = curr_char;
        }
        rank[idx] = current_rank;
      }

      size_t k = 1;
      while (k < n) {
        std::vector<std::pair<int32_t, int32_t>> pairs(n);
        for (size_t i = 0; i < n; i++) {
          pairs[i] = {rank[i], rank[(i + k) % n]};
        }

        std::sort(sa.begin(), sa.end(), [&pairs](size_t a, size_t b) {
          const auto &pa = pairs[a];
          const auto &pb = pairs[b];
          return pa.first != pb.first ? pa.first < pb.first
                                      : pa.second < pb.second;
        });

        std::vector<int32_t> new_rank(n, 0);
        new_rank[sa[0]] = 0;
        for (size_t i = 1; i < n; i++) {
          new_rank[sa[i]] =
              new_rank[sa[i - 1]] + (pairs[sa[i - 1]] != pairs[sa[i]] ? 1 : 0);
        }

        rank = std::move(new_rank);
        k *= 2;
      }
    }

    std::vector<uint8_t> transformed(n);
    int32_t original_idx = 0;

    for (size_t i = 0; i < n; i++) {
      size_t suffix = sa[i];
      if (suffix == 0) {
        transformed[i] = input[n - 1];
        original_idx = static_cast<int32_t>(i);
      } else {
        transformed[i] = input[suffix - 1];
      }
    }

    return BWTResult(std::move(transformed), original_idx);
  }

public:
  int64_t size_val;
  std::vector<uint8_t> test_data;
  BWTResult bwt_result;
  uint32_t result_val;

  BWTEncode() : result_val(0), bwt_result({}, 0) {
    size_val = config_val("size");
  }

  std::string name() const override { return "Compress::BWTEncode"; }

  void prepare() override { test_data = generate_test_data(size_val); }

  void run(int iteration_id) override {
    bwt_result = bwt_transform(test_data);
    result_val += static_cast<uint32_t>(bwt_result.transformed.size());
  }

  uint32_t checksum() override { return result_val; }
};

class BWTDecode : public Benchmark {
private:
  std::vector<uint8_t> bwt_inverse(const BWTEncode::BWTResult &bwt_result) {
    const auto &bwt = bwt_result.transformed;
    size_t n = bwt.size();
    if (n == 0)
      return {};

    int32_t counts[256] = {0};
    for (uint8_t byte : bwt)
      counts[byte]++;

    int32_t positions[256] = {0};
    int32_t total = 0;
    for (int i = 0; i < 256; i++) {
      positions[i] = total;
      total += counts[i];
    }

    std::vector<size_t> next(n, 0);
    int32_t temp_counts[256] = {0};

    for (size_t i = 0; i < n; i++) {
      uint8_t byte = bwt[i];
      size_t pos = static_cast<size_t>(positions[byte] + temp_counts[byte]);
      next[pos] = i;
      temp_counts[byte]++;
    }

    std::vector<uint8_t> result(n);
    size_t idx = static_cast<size_t>(bwt_result.original_idx);

    for (size_t i = 0; i < n; i++) {
      idx = next[idx];
      result[i] = bwt[idx];
    }

    return result;
  }

public:
  int64_t size_val;
  std::vector<uint8_t> test_data;
  std::vector<uint8_t> inverted;
  BWTEncode::BWTResult bwt_result;
  uint32_t result_val;

  BWTDecode() : result_val(0), bwt_result({}, 0) {
    size_val = config_val("size");
  }

  std::string name() const override { return "Compress::BWTDecode"; }

  void prepare() override {
    BWTEncode encoder;
    encoder.size_val = size_val;
    encoder.prepare();
    encoder.run(0);
    test_data = encoder.test_data;
    bwt_result = encoder.bwt_result;
  }

  void run(int iteration_id) override {
    inverted = bwt_inverse(bwt_result);
    result_val += static_cast<uint32_t>(inverted.size());
  }

  uint32_t checksum() override {
    if (inverted == test_data)
      result_val += 100000;
    return result_val;
  }
};

class HuffEncode : public Benchmark {
public:
  class HuffmanNode {
  public:
    int32_t frequency;
    uint8_t byte_val;
    bool is_leaf;
    std::shared_ptr<HuffmanNode> left;
    std::shared_ptr<HuffmanNode> right;

    HuffmanNode(int32_t freq, uint8_t byte = 0, bool leaf = true)
        : frequency(freq), byte_val(byte), is_leaf(leaf) {}
  };

  struct HuffmanCodes {
    std::vector<int32_t> code_lengths;
    std::vector<int32_t> codes;

    HuffmanCodes() : code_lengths(256, 0), codes(256, 0) {}
  };

  struct EncodedResult {
    std::vector<uint8_t> data;
    int32_t bit_count;
    std::vector<int32_t> frequencies;

    EncodedResult(std::vector<uint8_t> d, int32_t bc, std::vector<int32_t> f)
        : data(std::move(d)), bit_count(bc), frequencies(std::move(f)) {}
  };

public:
  static std::shared_ptr<HuffmanNode>
  build_huffman_tree(const std::vector<int32_t> &frequencies) {
    std::vector<std::shared_ptr<HuffmanNode>> nodes;
    for (int i = 0; i < 256; i++) {
      if (frequencies[i] > 0) {
        nodes.push_back(std::make_shared<HuffmanNode>(frequencies[i],
                                                      static_cast<uint8_t>(i)));
      }
    }

    std::sort(nodes.begin(), nodes.end(), [](const auto &a, const auto &b) {
      return a->frequency < b->frequency;
    });

    if (nodes.size() == 1) {
      auto node = nodes[0];
      auto root = std::make_shared<HuffmanNode>(node->frequency, 0, false);
      root->left = node;
      root->right = std::make_shared<HuffmanNode>(0, 0);
      return root;
    }

    while (nodes.size() > 1) {
      auto left = nodes[0];
      auto right = nodes[1];

      nodes.erase(nodes.begin());
      nodes.erase(nodes.begin());

      auto parent = std::make_shared<HuffmanNode>(
          left->frequency + right->frequency, 0, false);
      parent->left = left;
      parent->right = right;

      auto pos = std::lower_bound(nodes.begin(), nodes.end(), parent,
                                  [](const auto &n, const auto &p) {
                                    return n->frequency < p->frequency;
                                  });
      nodes.insert(pos, parent);
    }

    return nodes[0];
  }

  void build_huffman_codes(const std::shared_ptr<HuffmanNode> &node,
                           int32_t code, int32_t length, HuffmanCodes &codes) {
    if (node->is_leaf) {
      if (length > 0 || node->byte_val != 0) {
        int idx = node->byte_val;
        codes.code_lengths[idx] = length;
        codes.codes[idx] = code;
      }
    } else {
      if (node->left)
        build_huffman_codes(node->left, code << 1, length + 1, codes);
      if (node->right)
        build_huffman_codes(node->right, (code << 1) | 1, length + 1, codes);
    }
  }

  EncodedResult huffman_encode(const std::vector<uint8_t> &data,
                               const HuffmanCodes &codes,
                               const std::vector<int32_t> &frequencies) {
    std::vector<uint8_t> result;
    result.reserve(data.size() * 2);
    uint8_t current_byte = 0;
    int32_t bit_pos = 0;
    int32_t total_bits = 0;

    for (uint8_t byte : data) {
      int idx = byte;
      int32_t code = codes.codes[idx];
      int32_t length = codes.code_lengths[idx];

      for (int i = length - 1; i >= 0; i--) {
        if ((code & (1 << i)) != 0)
          current_byte |= 1 << (7 - bit_pos);
        bit_pos++;
        total_bits++;

        if (bit_pos == 8) {
          result.push_back(current_byte);
          current_byte = 0;
          bit_pos = 0;
        }
      }
    }

    if (bit_pos > 0) {
      result.push_back(current_byte);
    }

    return EncodedResult(std::move(result), total_bits, frequencies);
  }

public:
  int64_t size_val;
  std::vector<uint8_t> test_data;
  EncodedResult encoded;
  uint32_t result_val;

  HuffEncode() : result_val(0), encoded({}, 0, {}) {
    size_val = config_val("size");
  }

  std::string name() const override { return "Compress::HuffEncode"; }

  void prepare() override { test_data = generate_test_data(size_val); }

  void run(int iteration_id) override {
    std::vector<int32_t> frequencies(256, 0);
    for (uint8_t byte : test_data)
      frequencies[byte]++;

    auto tree = build_huffman_tree(frequencies);

    HuffmanCodes codes;
    build_huffman_codes(tree, 0, 0, codes);

    encoded = huffman_encode(test_data, codes, frequencies);
    result_val += static_cast<uint32_t>(encoded.data.size());
  }

  uint32_t checksum() override { return result_val; }
};

class HuffDecode : public Benchmark {
private:
  std::vector<uint8_t>
  huffman_decode(const std::vector<uint8_t> &encoded,
                 const std::shared_ptr<HuffEncode::HuffmanNode> &root,
                 int32_t bit_count) {

    std::vector<uint8_t> result(bit_count);
    size_t result_size = 0;

    const HuffEncode::HuffmanNode *current_node = root.get();
    int32_t bits_processed = 0;
    size_t byte_index = 0;

    while (bits_processed < bit_count && byte_index < encoded.size()) {
      uint8_t byte_val = encoded[byte_index++];

      for (int bit_pos = 7; bit_pos >= 0 && bits_processed < bit_count;
           bit_pos--) {
        bool bit = ((byte_val >> bit_pos) & 1) == 1;
        current_node =
            bit ? current_node->right.get() : current_node->left.get();
        bits_processed++;

        if (current_node->is_leaf) {
          result[result_size++] = current_node->byte_val;
          current_node = root.get();
        }
      }
    }

    result.resize(result_size);
    return result;
  }

public:
  int64_t size_val;
  std::vector<uint8_t> test_data;
  std::vector<uint8_t> decoded;
  HuffEncode::EncodedResult encoded;
  uint32_t result_val;

  HuffDecode() : result_val(0), encoded({}, 0, {}) {
    size_val = config_val("size");
  }

  std::string name() const override { return "Compress::HuffDecode"; }

  void prepare() override {
    test_data = generate_test_data(size_val);

    HuffEncode encoder;
    encoder.size_val = size_val;
    encoder.prepare();
    encoder.run(0);
    encoded = encoder.encoded;
  }

  void run(int iteration_id) override {
    auto tree = HuffEncode::build_huffman_tree(encoded.frequencies);
    decoded = huffman_decode(encoded.data, tree, encoded.bit_count);
    result_val += static_cast<uint32_t>(decoded.size());
  }

  uint32_t checksum() override {
    uint32_t res = result_val;
    if (decoded == test_data)
      res += 100000;
    return res;
  }
};

class ArithEncode : public Benchmark {
public:
  struct ArithEncodedResult {
    std::vector<uint8_t> data;
    int32_t bit_count;
    std::vector<int32_t> frequencies;

    ArithEncodedResult() : bit_count(0) {}
    ArithEncodedResult(std::vector<uint8_t> d, int32_t bc,
                       std::vector<int32_t> f)
        : data(std::move(d)), bit_count(bc), frequencies(std::move(f)) {}
  };

  class ArithFreqTable {
  public:
    int32_t total;
    std::vector<int32_t> low;
    std::vector<int32_t> high;

    ArithFreqTable(const std::vector<int32_t> &frequencies)
        : total(0), low(256, 0), high(256, 0) {
      for (int32_t f : frequencies)
        total += f;

      int32_t cum = 0;
      for (int i = 0; i < 256; i++) {
        low[i] = cum;
        cum += frequencies[i];
        high[i] = cum;
      }
    }

    ArithFreqTable(int32_t t, std::vector<int32_t> l, std::vector<int32_t> h)
        : total(t), low(std::move(l)), high(std::move(h)) {}
  };

  class BitOutputStream {
  private:
    uint8_t buffer = 0;
    int32_t bit_pos = 0;
    std::vector<uint8_t> bytes;
    int32_t bits_written = 0;

  public:
    void write_bit(int32_t bit) {
      buffer = (buffer << 1) | (bit & 1);
      bit_pos++;
      bits_written++;

      if (bit_pos == 8) {
        bytes.push_back(buffer);
        buffer = 0;
        bit_pos = 0;
      }
    }

    std::vector<uint8_t> flush() {
      if (bit_pos > 0) {
        buffer <<= (8 - bit_pos);
        bytes.push_back(buffer);
      }
      return bytes;
    }

    int32_t get_bits_written() const { return bits_written; }
    void clear() {
      buffer = 0;
      bit_pos = 0;
      bytes.clear();
      bits_written = 0;
    }
  };

private:
  ArithEncodedResult arith_encode(const std::vector<uint8_t> &data) {
    std::vector<int32_t> frequencies(256, 0);
    for (uint8_t byte : data) {
      frequencies[byte]++;
    }

    ArithFreqTable freq_table(frequencies);

    uint64_t low = 0;
    uint64_t high = 0xFFFFFFFF;
    int32_t pending = 0;
    BitOutputStream output;

    for (uint8_t byte : data) {
      int32_t idx = byte;
      uint64_t range = high - low + 1;

      high = low + (range * freq_table.high[idx] / freq_table.total) - 1;
      low = low + (range * freq_table.low[idx] / freq_table.total);

      while (true) {
        if (high < 0x80000000) {
          output.write_bit(0);
          for (int i = 0; i < pending; i++)
            output.write_bit(1);
          pending = 0;
        } else if (low >= 0x80000000) {
          output.write_bit(1);
          for (int i = 0; i < pending; i++)
            output.write_bit(0);
          pending = 0;
          low -= 0x80000000;
          high -= 0x80000000;
        } else if (low >= 0x40000000 && high < 0xC0000000) {
          pending++;
          low -= 0x40000000;
          high -= 0x40000000;
        } else {
          break;
        }

        low <<= 1;
        high = (high << 1) | 1;
        high &= 0xFFFFFFFF;
      }
    }

    pending++;
    if (low < 0x40000000) {
      output.write_bit(0);
      for (int i = 0; i < pending; i++)
        output.write_bit(1);
    } else {
      output.write_bit(1);
      for (int i = 0; i < pending; i++)
        output.write_bit(0);
    }

    return ArithEncodedResult(output.flush(), output.get_bits_written(),
                              frequencies);
  }

public:
  int64_t size_val = 0;
  uint32_t result_val = 0;
  std::vector<uint8_t> test_data;
  ArithEncodedResult encoded;

  ArithEncode() { size_val = config_val("size"); }

  std::string name() const override { return "Compress::ArithEncode"; }

  void prepare() override { test_data = generate_test_data(size_val); }

  void run(int iteration_id) override {
    encoded = arith_encode(test_data);
    result_val += static_cast<uint32_t>(encoded.data.size());
  }

  uint32_t checksum() override { return result_val; }
};

class ArithDecode : public Benchmark {
public:
  class BitInputStream {
  private:
    const std::vector<uint8_t> &bytes;
    size_t byte_pos = 0;
    int32_t bit_pos = 0;
    uint8_t current_byte = 0;

  public:
    BitInputStream(const std::vector<uint8_t> &b) : bytes(b) {
      if (!bytes.empty())
        current_byte = bytes[0];
    }

    int32_t read_bit() {
      if (bit_pos == 8) {
        byte_pos++;
        bit_pos = 0;
        current_byte = byte_pos < bytes.size() ? bytes[byte_pos] : 0;
      }

      int32_t bit = (current_byte >> (7 - bit_pos)) & 1;
      bit_pos++;
      return bit;
    }
  };

private:
  std::vector<uint8_t>
  arith_decode(const ArithEncode::ArithEncodedResult &encoded) {
    const auto &frequencies = encoded.frequencies;
    int32_t total = 0;
    for (int32_t f : frequencies)
      total += f;
    int32_t data_size = total;

    std::array<int32_t, 256> low_table = {0};
    std::array<int32_t, 256> high_table = {0};
    int32_t cum = 0;
    for (int i = 0; i < 256; i++) {
      low_table[i] = cum;
      cum += frequencies[i];
      high_table[i] = cum;
    }

    std::vector<uint8_t> result(data_size);
    BitInputStream input(encoded.data);

    uint64_t value = 0;
    for (int i = 0; i < 32; i++) {
      value = (value << 1) | input.read_bit();
    }

    uint64_t low = 0;
    uint64_t high = 0xFFFFFFFF;

    for (int32_t j = 0; j < data_size; j++) {
      uint64_t range = high - low + 1;
      uint64_t scaled = ((value - low + 1) * total - 1) / range;

      uint8_t symbol = 0;
      while (symbol < 255 && high_table[symbol] <= scaled) {
        symbol++;
      }

      result[j] = symbol;

      high = low + (range * high_table[symbol] / total) - 1;
      low = low + (range * low_table[symbol] / total);

      while (true) {
        if (high < 0x80000000) {

        } else if (low >= 0x80000000) {
          value -= 0x80000000;
          low -= 0x80000000;
          high -= 0x80000000;
        } else if (low >= 0x40000000 && high < 0xC0000000) {
          value -= 0x40000000;
          low -= 0x40000000;
          high -= 0x40000000;
        } else {
          break;
        }

        low <<= 1;
        high = (high << 1) | 1;
        value = (value << 1) | input.read_bit();
      }
    }

    return result;
  }

public:
  int64_t size_val = 0;
  uint32_t result_val = 0;
  std::vector<uint8_t> test_data;
  std::vector<uint8_t> decoded;
  ArithEncode::ArithEncodedResult encoded;

  ArithDecode() { size_val = config_val("size"); }

  std::string name() const override { return "Compress::ArithDecode"; }

  void prepare() override {
    test_data = generate_test_data(size_val);

    ArithEncode encoder;
    encoder.size_val = size_val;
    encoder.prepare();
    encoder.run(0);
    encoded = encoder.encoded;
  }

  void run(int iteration_id) override {
    decoded = arith_decode(encoded);
    result_val += static_cast<uint32_t>(decoded.size());
  }

  uint32_t checksum() override {
    if (decoded == test_data) {
      result_val += 100000;
    }
    return result_val;
  }
};

class LZWEncode : public Benchmark {
public:
  struct LZWResult {
    std::vector<uint8_t> data;
    int32_t dict_size;

    LZWResult() : dict_size(256) {}
    LZWResult(std::vector<uint8_t> d, int32_t ds)
        : data(std::move(d)), dict_size(ds) {}
  };

private:
  LZWResult lzw_encode(const std::vector<uint8_t> &input) {
    if (input.empty())
      return LZWResult();

    std::unordered_map<std::string, int32_t> dict;
    dict.reserve(4096);
    for (int i = 0; i < 256; i++) {
      dict[std::string(1, static_cast<char>(i))] = i;
    }

    int32_t next_code = 256;

    std::vector<uint8_t> result;
    result.reserve(input.size() * 2);

    std::string current(1, static_cast<char>(input[0]));

    for (size_t i = 1; i < input.size(); i++) {
      char next_char(static_cast<char>(input[i]));
      std::string new_str = current + next_char;

      if (dict.find(new_str) != dict.end()) {
        current = new_str;
      } else {
        int32_t code = dict[current];
        result.push_back((code >> 8) & 0xFF);
        result.push_back(code & 0xFF);

        dict[new_str] = next_code++;
        current = std::string(1, next_char);
      }
    }

    int32_t code = dict[current];
    result.push_back((code >> 8) & 0xFF);
    result.push_back(code & 0xFF);

    return LZWResult(result, next_code);
  }

public:
  int64_t size_val = 0;
  uint32_t result_val = 0;
  std::vector<uint8_t> test_data;
  LZWResult encoded;

  LZWEncode() { size_val = config_val("size"); }

  std::string name() const override { return "Compress::LZWEncode"; }

  void prepare() override { test_data = generate_test_data(size_val); }

  void run(int iteration_id) override {
    encoded = lzw_encode(test_data);
    result_val += static_cast<uint32_t>(encoded.data.size());
  }

  uint32_t checksum() override { return result_val; }
};

class LZWDecode : public Benchmark {
private:
  std::vector<uint8_t> lzw_decode(const LZWEncode::LZWResult &encoded) {
    if (encoded.data.empty())
      return std::vector<uint8_t>();

    std::vector<std::string> dict;
    dict.reserve(4096);
    for (int i = 0; i < 256; i++) {
      dict.emplace_back(1, static_cast<char>(i));
    }

    std::vector<uint8_t> result;
    result.reserve(encoded.data.size() * 2);

    const auto &data = encoded.data;
    size_t pos = 0;

    uint16_t high = data[pos];
    uint16_t low = data[pos + 1];
    int32_t old_code = (high << 8) | low;
    pos += 2;

    const std::string &old_str = dict[old_code];
    result.insert(result.end(), old_str.begin(), old_str.end());

    int32_t next_code = 256;

    while (pos < data.size()) {
      high = data[pos];
      low = data[pos + 1];
      int32_t new_code = (high << 8) | low;
      pos += 2;

      std::string new_str;
      if (new_code < static_cast<int32_t>(dict.size())) {
        new_str = dict[new_code];
      } else if (new_code == next_code) {
        new_str = dict[old_code] + dict[old_code][0];
      } else {
        throw std::runtime_error("Error decode");
      }

      result.insert(result.end(), new_str.begin(), new_str.end());

      dict.emplace_back(dict[old_code] + new_str[0]);
      next_code++;

      old_code = new_code;
    }

    return result;
  }

public:
  int64_t size_val = 0;
  uint32_t result_val = 0;
  std::vector<uint8_t> test_data;
  std::vector<uint8_t> decoded;
  LZWEncode::LZWResult encoded;

  LZWDecode() { size_val = config_val("size"); }

  std::string name() const override { return "Compress::LZWDecode"; }

  void prepare() override {
    test_data = generate_test_data(size_val);

    LZWEncode encoder;
    encoder.size_val = size_val;
    encoder.prepare();
    encoder.run(0);
    encoded = encoder.encoded;
  }

  void run(int iteration_id) override {
    decoded = lzw_decode(encoded);
    result_val += static_cast<uint32_t>(decoded.size());
  }

  uint32_t checksum() override {
    if (decoded == test_data) {
      result_val += 100000;
    }
    return result_val;
  }
};

namespace Distance {
std::vector<std::pair<std::string, std::string>>
generate_pair_strings(int64_t n, int64_t m) {
  std::vector<std::pair<std::string, std::string>> pairs;
  pairs.reserve(n);

  for (int64_t i = 0; i < n; ++i) {
    int len1 = Helper::next_int(m) + 4;
    int len2 = Helper::next_int(m) + 4;

    std::string str1, str2;
    str1.reserve(len1);
    str2.reserve(len2);

    for (int j = 0; j < len1; ++j) {
      str1 += 'a' + Helper::next_int(10);
    }
    for (int j = 0; j < len2; ++j) {
      str2 += 'a' + Helper::next_int(10);
    }

    pairs.emplace_back(std::move(str1), std::move(str2));
  }

  return pairs;
}

class Jaro : public Benchmark {
private:
  int64_t count;
  int64_t size;
  std::vector<std::pair<std::string, std::string>> pairs;
  uint32_t result_val;

public:
  Jaro()
      : count(config_val("count")), size(config_val("size")), result_val(0) {}

  void prepare() override { pairs = generate_pair_strings(count, size); }

  double jaro(const std::string &s1, const std::string &s2) {
    size_t len1 = s1.size();
    size_t len2 = s2.size();

    if (len1 == 0 || len2 == 0)
      return 0.0;

    int64_t match_dist = std::max(len1, len2) / 2 - 1;
    if (match_dist < 0)
      match_dist = 0;

    std::vector<bool> s1_matches(len1, false);
    std::vector<bool> s2_matches(len2, false);

    int matches = 0;
    for (size_t i = 0; i < len1; ++i) {
      size_t start = i > match_dist ? i - match_dist : 0;
      size_t end = std::min<size_t>(len2 - 1, i + match_dist);

      for (size_t j = start; j <= end; ++j) {
        if (!s2_matches[j] && s1[i] == s2[j]) {
          s1_matches[i] = true;
          s2_matches[j] = true;
          matches++;
          break;
        }
      }
    }

    if (matches == 0)
      return 0.0;

    int transpositions = 0;
    size_t k = 0;
    for (size_t i = 0; i < len1; ++i) {
      if (s1_matches[i]) {
        while (k < len2 && !s2_matches[k]) {
          k++;
        }
        if (k < len2) {
          if (s1[i] != s2[k]) {
            transpositions++;
          }
          k++;
        }
      }
    }
    transpositions /= 2;

    double m = static_cast<double>(matches);
    double jaro = (m / len1 + m / len2 + (m - transpositions) / m) / 3.0;
    return jaro;
  }

  void run(int iteration_id) override {
    for (const auto &pair : pairs) {
      result_val += static_cast<uint32_t>(jaro(pair.first, pair.second) * 1000);
    }
  }

  uint32_t checksum() override { return result_val; }

  std::string name() const override { return "Distance::Jaro"; }
};

class NGram : public Benchmark {
private:
  int64_t count;
  int64_t size;
  std::vector<std::pair<std::string, std::string>> pairs;
  uint32_t result_val;

public:
  NGram()
      : count(config_val("count")), size(config_val("size")), result_val(0) {}

  void prepare() override {
    pairs = Distance::generate_pair_strings(count, size);
  }

  double ngram(const std::string &_s1, const std::string &_s2) {
    const auto &s1 = _s1;
    const auto &s2 = _s2;

    std::unordered_map<uint32_t, int> grams1;
    grams1.reserve(s1.size());

    for (size_t i = 0; i <= s1.size() - 4; ++i) {
      uint32_t gram = (static_cast<uint8_t>(s1[i]) << 24) |
                      (static_cast<uint8_t>(s1[i + 1]) << 16) |
                      (static_cast<uint8_t>(s1[i + 2]) << 8) |
                      static_cast<uint8_t>(s1[i + 3]);

      auto [it, inserted] = grams1.try_emplace(gram, 0);
      it->second++;
    }

    std::unordered_map<uint32_t, int> grams2;
    grams2.reserve(s2.size());
    int intersection = 0;

    for (size_t i = 0; i <= s2.size() - 4; ++i) {
      uint32_t gram = (static_cast<uint8_t>(s2[i]) << 24) |
                      (static_cast<uint8_t>(s2[i + 1]) << 16) |
                      (static_cast<uint8_t>(s2[i + 2]) << 8) |
                      static_cast<uint8_t>(s2[i + 3]);

      auto [it2, inserted2] = grams2.try_emplace(gram, 0);
      it2->second++;

      auto it1 = grams1.find(gram);
      if (it1 != grams1.end() && it2->second <= it1->second) {
        intersection++;
      }
    }

    size_t total = grams1.size() + grams2.size();
    return total > 0 ? static_cast<double>(intersection) / total : 0.0;
  }

  void run(int iteration_id) override {
    for (const auto &pair : pairs) {
      result_val +=
          static_cast<uint32_t>(ngram(pair.first, pair.second) * 1000);
    }
  }

  uint32_t checksum() override { return result_val; }

  std::string name() const override { return "Distance::NGram"; }
};
} // namespace Distance

std::string to_lower(const std::string &str) {
  std::string result = str;
  std::transform(result.begin(), result.end(), result.begin(),
                 [](unsigned char c) { return std::tolower(c); });
  return result;
}

void Benchmark::all(const std::string &single_bench) {
  std::unordered_map<std::string, double> results;
  double summary_time = 0.0;
  int ok = 0;
  int fails = 0;

  std::vector<
      std::pair<std::string, std::function<std::unique_ptr<Benchmark>()>>>
      benchmarks = {
          {"CLBG::Pidigits", []() { return std::make_unique<Pidigits>(); }},
          {"Binarytrees::Obj",
           []() { return std::make_unique<BinarytreesObj>(); }},
          {"Binarytrees::Arena",
           []() { return std::make_unique<BinarytreesArena>(); }},
          {"Brainfuck::Array",
           []() { return std::make_unique<BrainfuckArray>(); }},
          {"Brainfuck::Recursion",
           []() { return std::make_unique<BrainfuckRecursion>(); }},
          {"CLBG::Fannkuchredux",
           []() { return std::make_unique<Fannkuchredux>(); }},
          {"CLBG::Fasta", []() { return std::make_unique<Fasta>(); }},
          {"CLBG::Knuckeotide",
           []() { return std::make_unique<Knuckeotide>(); }},
          {"CLBG::Mandelbrot", []() { return std::make_unique<Mandelbrot>(); }},
          {"Matmul::Single", []() { return std::make_unique<Matmul1T>(); }},
          {"Matmul::T4", []() { return std::make_unique<Matmul4T>(); }},
          {"Matmul::T8", []() { return std::make_unique<Matmul8T>(); }},
          {"Matmul::T16", []() { return std::make_unique<Matmul16T>(); }},
          {"CLBG::Nbody", []() { return std::make_unique<Nbody>(); }},
          {"CLBG::RegexDna", []() { return std::make_unique<RegexDna>(); }},
          {"CLBG::Revcomp", []() { return std::make_unique<Revcomp>(); }},
          {"CLBG::Spectralnorm",
           []() { return std::make_unique<Spectralnorm>(); }},
          {"Base64::Encode", []() { return std::make_unique<Base64Encode>(); }},
          {"Base64::Decode", []() { return std::make_unique<Base64Decode>(); }},
          {"Json::Generate", []() { return std::make_unique<JsonGenerate>(); }},
          {"Json::ParseDom", []() { return std::make_unique<JsonParseDom>(); }},
          {"Json::ParseMapping",
           []() { return std::make_unique<JsonParseMapping>(); }},
          {"Etc::Sieve", []() { return std::make_unique<Sieve>(); }},
          {"Etc::TextRaytracer",
           []() { return std::make_unique<TextRaytracer>(); }},
          {"Etc::NeuralNet", []() { return std::make_unique<NeuralNet>(); }},
          {"Sort::Quick", []() { return std::make_unique<SortQuick>(); }},
          {"Sort::Merge", []() { return std::make_unique<SortMerge>(); }},
          {"Sort::Self", []() { return std::make_unique<SortSelf>(); }},
          {"Graph::BFS", []() { return std::make_unique<GraphPathBFS>(); }},
          {"Graph::DFS", []() { return std::make_unique<GraphPathDFS>(); }},
          {"Graph::AStar", []() { return std::make_unique<GraphPathAStar>(); }},
          {"Hash::SHA256",
           []() { return std::make_unique<BufferHashSHA256>(); }},
          {"Hash::CRC32", []() { return std::make_unique<BufferHashCRC32>(); }},
          {"Etc::CacheSimulation",
           []() { return std::make_unique<CacheSimulation>(); }},
          {"Calculator::Ast",
           []() { return std::make_unique<CalculatorAst>(); }},
          {"Calculator::Interpreter",
           []() { return std::make_unique<CalculatorInterpreter>(); }},
          {"Etc::GameOfLife", []() { return std::make_unique<GameOfLife>(); }},
          {"Maze::Generator",
           []() { return std::make_unique<MazeGenerator>(); }},
          {"Maze::BFS", []() { return std::make_unique<MazeBFS>(); }},
          {"Maze::AStar", []() { return std::make_unique<MazeAStar>(); }},
          {"Compress::BWTEncode",
           []() { return std::make_unique<BWTEncode>(); }},
          {"Compress::BWTDecode",
           []() { return std::make_unique<BWTDecode>(); }},
          {"Compress::HuffEncode",
           []() { return std::make_unique<HuffEncode>(); }},
          {"Compress::HuffDecode",
           []() { return std::make_unique<HuffDecode>(); }},
          {"Compress::ArithEncode",
           []() { return std::make_unique<ArithEncode>(); }},
          {"Compress::ArithDecode",
           []() { return std::make_unique<ArithDecode>(); }},
          {"Compress::LZWEncode",
           []() { return std::make_unique<LZWEncode>(); }},
          {"Compress::LZWDecode",
           []() { return std::make_unique<LZWDecode>(); }},
          {"Distance::Jaro",
           []() { return std::make_unique<Distance::Jaro>(); }},
          {"Distance::NGram",
           []() { return std::make_unique<Distance::NGram>(); }},

      };

  for (auto &[name, create_benchmark] : benchmarks) {
    if (!single_bench.empty() &&
        to_lower(name).find(to_lower(single_bench)) == std::string::npos) {
      continue;
    }

    std::cout << name << ": ";
    std::cout.flush();

    auto bench = create_benchmark();
    Helper::reset();
    bench->prepare();

    bench->warmup();

    Helper::reset();

    auto start = std::chrono::steady_clock::now();
    bench->run_all();
    auto end = std::chrono::steady_clock::now();

    std::chrono::duration<double> duration = end - start;
    results[name] = duration.count();

    if (bench->checksum() == bench->expected_checksum()) {
      std::cout << "OK ";
      ok++;
    } else {
      std::cout << "ERR[actual=" << bench->checksum()
                << ", expected=" << bench->expected_checksum() << "] ";
      fails++;
    }

    std::cout << "in " << std::fixed << std::setprecision(3) << duration.count()
              << "s" << std::endl;

    summary_time += duration.count();

    bench.reset();
    std::this_thread::sleep_for(std::chrono::milliseconds(1));
  }

  std::ofstream results_file("/tmp/results.js");
  results_file << "{";
  bool first = true;
  for (const auto &[name, time] : results) {
    if (!first)
      results_file << ",";
    results_file << "\"" << name << "\":" << time;
    first = false;
  }
  results_file << "}";
  results_file.close();

  if (ok + fails > 0) {
    std::cout << "Summary: " << std::fixed << std::setprecision(4)
              << summary_time << "s, " << (ok + fails) << ", " << ok << ", "
              << fails << std::endl;
  }

  if (fails > 0) {
    std::exit(1);
  }
}

int main(int argc, char *argv[]) {
  auto now = std::chrono::duration_cast<std::chrono::milliseconds>(
                 std::chrono::system_clock::now().time_since_epoch())
                 .count();
  std::cout << "start: " << now << std::endl;

  if (argc > 1) {
    load_config(argv[1]);
  } else {
    load_config();
  }

  if (argc > 2) {
    Benchmark::all(argv[2]);
  } else {
    Benchmark::all();
  }

  std::ofstream file("/tmp/recompile_marker");
  if (file.is_open()) {
    file << "RECOMPILE_MARKER_0";
    file.close();
  }

  return 0;
}