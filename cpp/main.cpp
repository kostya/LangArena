#include <iostream>
#include <fstream>
#include <string>
#include <unordered_map>
#include <vector>
#include <memory>
#include <chrono>
#include <cmath>
#include <thread>
#include <cstdint>
#include <functional>
#include <algorithm>
#include <sstream>
#include <iomanip> 
#include <variant>
#include <optional>
#include <map>
#include <queue>
#include <stack>
#include <complex>
#include <random>
#include <array>
#include <deque>
#include <bitset>
#include <cstring>
#include <filesystem>
#include <barrier>
#include <latch>
#include <semaphore>
#include <coroutine>
#include <future>
#include <regex>
#include <list>
#include <fstream>
#include <ranges>
#include "json.hpp"

#include "simdjson.h"
#include <re2/re2.h>

namespace fs = std::filesystem;
using json = nlohmann::json;

json CONFIG;

void load_config(const std::string& filename = "../test.js") {
    std::ifstream file(filename);
    if (!file.is_open()) {
        std::cerr << "Cannot open config file: " << filename << std::endl;
        return;
    }

    try {
        file >> CONFIG;
    } catch (const std::exception& e) {
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
    static void reset() {
        last = 42;
    }

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

    static uint32_t checksum(const std::string& v) {
        uint32_t hash = 5381;
        for (char c : v) {
            hash = ((hash << 5) + hash) + static_cast<uint8_t>(c);
        }
        return hash;
    }

    static uint32_t checksum(const std::vector<uint8_t>& v) {
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

    static int64_t config_i64(const std::string& class_name, const std::string& field_name) {
        try {
            if (CONFIG.contains(class_name) && CONFIG[class_name].contains(field_name)) {
                return CONFIG[class_name][field_name].get<int64_t>();
            } else {
                throw std::runtime_error("Config not found for " + class_name + ", field: " + field_name);
            }
        } catch (const std::exception& e) {
            std::cerr << e.what() << std::endl;
            return 0;
        }
    }

    static std::string config_s(const std::string& class_name, const std::string& field_name) {
        try {
            if (CONFIG.contains(class_name) && CONFIG[class_name].contains(field_name)) {
                return CONFIG[class_name][field_name].get<std::string>();
            } else {
                throw std::runtime_error("Config not found for " + class_name + ", field: " + field_name);
            }
        } catch (const std::exception& e) {
            std::cerr << e.what() << std::endl;
            return "";
        }
    }

};

thread_local int64_t Helper::last = 42;

class Benchmark {
protected:
    double time_delta = 0.0;

public:
    virtual ~Benchmark() = default;
    virtual void run(int iteration_id) = 0;
    virtual uint32_t checksum() = 0;

    virtual void prepare() {}
    virtual std::string name() const = 0;

    int64_t warmup_iterations() {
        if (CONFIG.contains(name()) && CONFIG[name()].contains("warmup_iterations")) {
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

    int64_t config_val(const std::string& field_name) const {
        return Helper::config_i64(this->name(), field_name);
    }

    int64_t iterations() const {
        return config_val("iterations");
    }

    int64_t expected_checksum() const {
        return config_val("checksum");
    }

    void set_time_delta(double delta) { time_delta = delta; }

    static void all(const std::string& single_bench = "");
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

    std::string name() const override { return "Pidigits"; }

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

                    if (i >= nn) break;

                    a = (a - (d * q)) * 10;
                    n *= 10;
                }
            }
        }
    }

    uint32_t checksum() override {
        return Helper::checksum(result_stream.str());
    }
};

class Binarytrees : public Benchmark {
private:
    struct TreeNode {
        std::unique_ptr<TreeNode> left;
        std::unique_ptr<TreeNode> right;
        int item;

        TreeNode(int item, int depth = 0) : item(item) {
            if (depth > 0) {
                left = std::make_unique<TreeNode>(2 * item - 1, depth - 1);
                right = std::make_unique<TreeNode>(2 * item, depth - 1);
            }
        }

        int check() const {
            if (!left || !right) return item;
            return left->check() - right->check() + item;
        }
    };

    int64_t n;
    uint32_t result_val;

public:
    Binarytrees() : n(config_val("depth")), result_val(0) {}

    std::string name() const override { return "Binarytrees"; }    

    void run(int iteration_id) override {
        int min_depth = 4;
        int max_depth = std::max(min_depth + 2, static_cast<int>(n));
        int stretch_depth = max_depth + 1;

        TreeNode stretch_tree(0, stretch_depth);
        result_val += stretch_tree.check();

        for (int depth = min_depth; depth <= max_depth; depth += 2) {
            int iterations = 1 << (max_depth - depth + min_depth);
            for (int i = 1; i <= iterations; i++) {
                TreeNode tree1(i, depth);
                TreeNode tree2(-i, depth);
                result_val += tree1.check();
                result_val += tree2.check();
            }
        }
    }

    uint32_t checksum() override {
        return result_val;
    }
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
            if (pos > 0) pos--;
        }
    };

    class Program {
    private:
        std::vector<uint8_t> commands;
        std::vector<size_t> jumps;

    public:
        Program(const std::string& text) {

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
                    case '+': tape.inc(); break;
                    case '-': tape.dec(); break;
                    case '>': tape.advance(); break;
                    case '<': tape.devance(); break;
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

    int64_t _run(const std::string& text) {
        Program program(text);
        return program.run();
    }

public:
    BrainfuckArray() : result_val(0) {
        program_text = Helper::config_s(name(), "program");
        warmup_text = Helper::config_s(name(), "warmup_program");
    }

    std::string name() const override { return "BrainfuckArray"; }    

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

    uint32_t checksum() override {
        return result_val;
    }
};

class BrainfuckRecursion : public Benchmark {
private:
    struct OpInc { 
        int32_t val; 
        explicit OpInc(int32_t v) : val(v) {}
    };

    struct OpMove { 
        int32_t val; 
        explicit OpMove(int32_t v) : val(v) {}
    };

    struct OpPrint {};

    struct OpLoop {
        std::vector<std::variant<OpInc, OpMove, OpPrint, OpLoop>> ops;
    };

    using Op = std::variant<OpInc, OpMove, OpPrint, OpLoop>;

    template<class... Ts>
    struct overloaded : Ts... { using Ts::operator()...; };

    template<class... Ts>
    overloaded(Ts...) -> overloaded<Ts...>;

    class Tape {
    private:
        std::vector<uint8_t> tape;
        size_t pos = 0;

    public:
        Tape() : tape(1024, 0) {}

        uint8_t get() { return tape[pos]; }
        const uint8_t& get() const { return tape[pos]; }

        void inc(int32_t x) { 
            tape[pos] += x;
        }

        void move(int32_t x) {
            if (x >= 0) {
                pos += static_cast<size_t>(x);
                if (pos >= tape.size()) {
                    size_t new_size = std::max(tape.size() * 2, pos + 1);
                    tape.resize(new_size, 0);
                }
            } else {
                int32_t move_left = -x;
                if (static_cast<size_t>(move_left) > pos) {
                    size_t needed = static_cast<size_t>(move_left) - pos;
                    std::vector<uint8_t> new_tape(tape.size() + needed, 0);
                    std::copy(tape.begin(), tape.end(), new_tape.begin() + needed);
                    tape = std::move(new_tape);
                    pos = needed;
                } else {
                    pos -= static_cast<size_t>(move_left);
                }
            }
        }
    };

    class Program {
    private:
        std::vector<Op> ops;
        int64_t result_val = 0;

        std::vector<Op> parse(std::string::const_iterator& it, 
                             const std::string::const_iterator& end) {
            std::vector<Op> res;
            res.reserve(128);

            while (it != end) {
                char c = *it++;

                switch (c) {
                    case '+':
                        res.emplace_back(OpInc{1});
                        break;
                    case '-':
                        res.emplace_back(OpInc{-1});
                        break;
                    case '>':
                        res.emplace_back(OpMove{1});
                        break;
                    case '<':
                        res.emplace_back(OpMove{-1});
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

        void run_ops(const std::vector<Op>& program, Tape& tape) {
            std::function<void(const Op&)> execute;

            struct OpVisitor {
                Tape& tape;
                int64_t& result_val;
                std::function<void(const Op&)>& execute_ref;

                void operator()(const OpInc& inc) const {
                    tape.inc(inc.val);
                }

                void operator()(const OpMove& move) const {
                    tape.move(move.val);
                }

                void operator()(const OpPrint&) const {
                    result_val = (result_val << 2) + tape.get();
                }

                void operator()(const OpLoop& loop) const {
                    while (tape.get() != 0) {
                        for (const Op& inner_op : loop.ops) {
                            std::visit(*this, inner_op);
                        }
                    }
                }
            };

            OpVisitor visitor{tape, result_val, execute};

            execute = [&visitor](const Op& op) {
                std::visit(visitor, op);
            };

            for (const Op& op : program) {
                execute(op);
            }
        }        

    public:
        explicit Program(const std::string& code) {
            auto it = code.begin();
            auto end = code.end();
            ops = parse(it, end);
        }

        int64_t run() {
            result_val = 0;
            Tape tape;
            run_ops(ops, tape);
            return result_val;
        }
    };

    std::string text;
    uint32_t result_val;

    int64_t _run(const std::string& text) {
        Program program(text);
        program.run();
        return program.run();  
    }

public:
    BrainfuckRecursion() : result_val(0) {
        text = Helper::config_s(name(), "program");
    }

    std::string name() const override { return "BrainfuckRecursion"; }    

    void warmup() override {
        int64_t prepare_iters = warmup_iterations();
        std::string warmup_program = Helper::config_s(name(), "warmup_program");
        for (int64_t i = 0; i < prepare_iters; i++) {
            _run(warmup_program);
        }
    }

    void run(int iteration_id) override {
        result_val += _run(text);  
    }

    uint32_t checksum() override {
        return result_val;
    }
};

class Fannkuchredux : public Benchmark {
private:
    int64_t n;
    uint32_t result_val;

    std::pair<int, int> fannkuchredux(int n) {
        std::vector<int> perm1(n);
        for (int i = 0; i < n; i++) perm1[i] = i;

        std::vector<int> perm(n);
        std::vector<int> count(n);
        int maxFlipsCount = 0, permCount = 0, checksum = 0;
        int r = n;

        while (true) {
            while (r > 1) {
                count[r - 1] = r;
                r--;
            }

            std::copy(perm1.begin(), perm1.end(), perm.begin());
            int flipsCount = 0;

            int k = perm[0];
            while (k != 0) {
                int k2 = (k + 1) >> 1;
                for (int i = 0; i < k2; i++) {
                    int j = k - i;
                    std::swap(perm[i], perm[j]);
                }
                flipsCount++;
                k = perm[0];
            }

            if (flipsCount > maxFlipsCount) maxFlipsCount = flipsCount;
            checksum += (permCount % 2 == 0) ? flipsCount : -flipsCount;

            while (true) {
                if (r == n) return {checksum, maxFlipsCount};

                int perm0 = perm1[0];
                for (int i = 0; i < r; i++) {
                    perm1[i] = perm1[i + 1];
                }
                perm1[r] = perm0;

                count[r]--;
                if (count[r] > 0) break;
                r++;
            }
            permCount++;
        }
    }

public:
    Fannkuchredux() : n(config_val("n")), result_val(0) {}

    std::string name() const override { return "Fannkuchredux"; }        

    void run(int iteration_id) override {
        auto [a, b] = fannkuchredux(static_cast<int>(n));
        result_val += a * 100 + b;  
    }

    uint32_t checksum() override {
        return result_val;
    }
};

class Fasta : public Benchmark {
private:
    struct Gene {
        char c;
        double prob;
    };

    static constexpr int LINE_LENGTH = 60;
    std::string result_str;

    char select_random(const std::vector<Gene>& genelist) {
        double r = Helper::next_float();
        if (r < genelist[0].prob) return genelist[0].c;

        int lo = 0, hi = genelist.size() - 1;
        while (hi > lo + 1) {
            int i = (hi + lo) / 2;
            if (r < genelist[i].prob) hi = i;
            else lo = i;
        }
        return genelist[hi].c;
    }

    void make_random_fasta(const std::string& id, const std::string& desc, 
                          const std::vector<Gene>& genelist, int n_iter) {
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

    void make_repeat_fasta(const std::string& id, const std::string& desc,
                          const std::string& s, int n_iter) {
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

    std::string name() const override { return "Fasta"; }    

    void run(int iteration_id) override {
        std::vector<Gene> IUB = {
            {'a', 0.27}, {'c', 0.39}, {'g', 0.51}, {'t', 0.78}, {'B', 0.8}, {'D', 0.8200000000000001},
            {'H', 0.8400000000000001}, {'K', 0.8600000000000001}, {'M', 0.8800000000000001},
            {'N', 0.9000000000000001}, {'R', 0.9200000000000002}, {'S', 0.9400000000000002},
            {'V', 0.9600000000000002}, {'W', 0.9800000000000002}, {'Y', 1.0000000000000002}
        };

        std::vector<Gene> HOMO = {
            {'a', 0.302954942668}, {'c', 0.5009432431601}, {'g', 0.6984905497992}, {'t', 1.0}
        };

        std::string ALU = "GGCCGGGCGCGGTGGCTCACGCCTGTAATCCCAGCACTTTGGGAGGCCGAGGCGGGCGGATCACCTGAGGTCAGGAGTTCGAGACCAGCCTGGCCAACATGGTGAAACCCCGTCTCTACTAAAAATACAAAAATTAGCCGGGCGTGGTGGCGCGCGCCTGTAATCCCAGCTACTCGGGAGGCTGAGGCAGGAGAATCGCTTGAACCCGGGAGGCGGAGGTTGCAGTGAGCCGAGATCGCGCCACTGCACTCCAGCCTGGGCGACAGAGCGAGACTCCGTCTCAAAAA";

        make_repeat_fasta("ONE", "Homo sapiens alu", ALU, static_cast<int>(n * 2));
        make_random_fasta("TWO", "IUB ambiguity codes", IUB, static_cast<int>(n * 3));
        make_random_fasta("THREE", "Homo sapiens frequency", HOMO, static_cast<int>(n * 5));
    }

    uint32_t checksum() override {
        return Helper::checksum(result_str);
    }

    const std::string& get_result() const { return result_str; }
};

class Knuckeotide : public Benchmark {
private:
    std::string seq;
    std::string result_str;

    std::pair<int, std::unordered_map<std::string, int>> frequency(const std::string& seq, int length) {
        int n = seq.size() - length + 1;
        std::unordered_map<std::string, int> table;

        for (int i = 0; i < n; i++) {
            std::string sub = seq.substr(i, length);
            table[sub]++;
        }
        return {n, table};
    }

    void sort_by_freq(const std::string& seq, int length) {
        auto [n, table] = frequency(seq, length);

        std::vector<std::pair<std::string, int>> pairs(table.begin(), table.end());
        std::sort(pairs.begin(), pairs.end(), 
                 [](const auto& a, const auto& b) {
                     if (a.second == b.second) return a.first < b.first;
                     return a.second > b.second;
                 });

        for (const auto& [key, value] : pairs) {
            double percent = (value * 100.0) / n;
            std::ostringstream ss;
            std::string key_upper = key;
            std::transform(key_upper.begin(), key_upper.end(), key_upper.begin(), ::toupper);
            ss << key_upper << " " << std::fixed << std::setprecision(3) << percent << "\n";
            result_str += ss.str();
        }
        result_str += "\n";
    }

    void find_seq(const std::string& seq, const std::string& s) {
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

    std::string name() const override { return "Knuckeotide"; }    

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

        std::vector<std::string> searches = {"ggt", "ggta", "ggtatt", "ggtattttaatt", "ggtattttaatttatagt"};
        for (const auto& s : searches) {
            find_seq(seq, s);
        }
    }

    uint32_t checksum() override {
        return Helper::checksum(result_str);
    }
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

    std::string name() const override { return "Mandelbrot"; }    

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

    uint32_t checksum() override {
        return Helper::checksum(result_bin);
    }
};

class Matmul1T : public Benchmark {
private:
    int64_t n;
    uint32_t result_val;

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

    std::vector<std::vector<double>> matmul(const std::vector<std::vector<double>>& a, 
                                           const std::vector<std::vector<double>>& b) {
        int m = static_cast<int>(a.size());
        int n = static_cast<int>(a[0].size());
        int p = static_cast<int>(b[0].size());

        std::vector<std::vector<double>> b2(p, std::vector<double>(n));
        for (int i = 0; i < n; i++) {
            for (int j = 0; j < p; j++) {
                b2[j][i] = b[i][j];
            }
        }

        std::vector<std::vector<double>> c(m, std::vector<double>(p));
        for (int i = 0; i < m; i++) {
            const auto& ai = a[i];
            for (int j = 0; j < p; j++) {
                double s = 0.0;
                const auto& b2j = b2[j];
                for (int k = 0; k < n; k++) {
                    s += ai[k] * b2j[k];
                }
                c[i][j] = s;
            }
        }
        return c;
    }

public:
    Matmul1T() : n(config_val("n")), result_val(0) {}

    std::string name() const override { return "Matmul1T"; }    

    void run(int iteration_id) override {
        auto a = matgen(static_cast<int>(n));
        auto b = matgen(static_cast<int>(n));
        auto c = matmul(a, b);
        result_val += Helper::checksum_f64(c[n >> 1][n >> 1]);  
    }

    uint32_t checksum() override {
        return result_val;
    }
};

class Matmul4T : public Benchmark {
protected:
    int64_t n;
    uint32_t result_val;

    virtual int get_num_threads() const { return 4; }

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

    std::vector<std::vector<double>> matmul_parallel(const std::vector<std::vector<double>>& a, 
                                                    const std::vector<std::vector<double>>& b) {
        int num_threads = get_num_threads();
        int size = static_cast<int>(a.size());

        std::vector<std::vector<double>> b_t(size, std::vector<double>(size));
        for (int i = 0; i < size; i++) {
            for (int j = 0; j < size; j++) {
                b_t[j][i] = b[i][j];
            }
        }

        std::vector<std::vector<double>> c(size, std::vector<double>(size));
        std::vector<std::thread> threads;
        threads.reserve(num_threads);

        for (int t = 0; t < num_threads; t++) {
            threads.emplace_back([&, t, num_threads, size]() {
                for (int i = t; i < size; i += num_threads) {
                    const auto& ai = a[i];
                    auto& ci = c[i];

                    for (int j = 0; j < size; j++) {
                        double sum = 0.0;
                        const auto& b_tj = b_t[j];

                        for (int k = 0; k < size; k++) {
                            sum += ai[k] * b_tj[k];
                        }

                        ci[j] = sum;
                    }
                }
            });
        }

        for (auto& thread : threads) {
            thread.join();
        }

        return c;
    }    

public:
    Matmul4T() : n(config_val("n")), result_val(0) {}

    std::string name() const override { return "Matmul4T"; }    

    void run(int iteration_id) override {
        auto a = matgen(static_cast<int>(n));
        auto b = matgen(static_cast<int>(n));
        auto c = matmul_parallel(a, b);
        result_val += Helper::checksum_f64(c[n >> 1][n >> 1]);  
    }

    uint32_t checksum() override {
        return result_val;
    }
};

class Matmul8T : public Matmul4T {
protected:
    int get_num_threads() const override { return 8; }

public:
    Matmul8T() { n = config_val("n"); }

    std::string name() const override { return "Matmul8T"; }
};

class Matmul16T : public Matmul4T {
protected:
    int get_num_threads() const override { return 16; }

public:
    Matmul16T() { n = config_val("n"); }

    std::string name() const override { return "Matmul16T"; }
};

class Nbody : public Benchmark {
private:
    static constexpr double SOLAR_MASS = 4 * M_PI * M_PI;
    static constexpr double DAYS_PER_YEAR = 365.24;

    struct Planet {
        double x, y, z;
        double vx, vy, vz;
        double mass;

        Planet(double x, double y, double z, double vx, double vy, double vz, double mass)
            : x(x), y(y), z(z), vx(vx * DAYS_PER_YEAR), vy(vy * DAYS_PER_YEAR), 
              vz(vz * DAYS_PER_YEAR), mass(mass * SOLAR_MASS) {}

        void move_from_i(std::vector<Planet>& bodies, int nbodies, double dt, int start) {
            for (int i = start; i < nbodies; i++) {
                Planet& b2 = bodies[i];
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
            Planet& b = bodies[i];
            e += 0.5 * b.mass * (b.vx * b.vx + b.vy * b.vy + b.vz * b.vz);
            for (int j = i + 1; j < nbodies; j++) {
                Planet& b2 = bodies[j];
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

        for (auto& b : bodies) {
            px += b.vx * b.mass;
            py += b.vy * b.mass;
            pz += b.vz * b.mass;
        }

        Planet& b = bodies[0];
        b.vx = -px / SOLAR_MASS;
        b.vy = -py / SOLAR_MASS;
        b.vz = -pz / SOLAR_MASS;
    }

public:
    Nbody() : result_val(0), v1(0.0) {
        bodies = {
            Planet(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0),
            Planet(4.84143144246472090e+00, -1.16032004402742839e+00, -1.03622044471123109e-01,
                   1.66007664274403694e-03, 7.69901118419740425e-03, -6.90460016972063023e-05,
                   9.54791938424326609e-04),
            Planet(8.34336671824457987e+00, 4.12479856412430479e+00, -4.03523417114321381e-01,
                   -2.76742510726862411e-03, 4.99852801234917238e-03, 2.30417297573763929e-05,
                   2.85885980666130812e-04),
            Planet(1.28943695621391310e+01, -1.51111514016986312e+01, -2.23307578892655734e-01,
                   2.96460137564761618e-03, 2.37847173959480950e-03, -2.96589568540237556e-05,
                   4.36624404335156298e-05),
            Planet(1.53796971148509165e+01, -2.59193146099879641e+01, 1.79258772950371181e-01,
                   2.68067772490389322e-03, 1.62824170038242295e-03, -9.51592254519715870e-05,
                   5.15138902046611451e-05)
        };
    }

    std::string name() const override { return "Nbody"; }    

    void prepare() override {
        offset_momentum();
        v1 = energy();
    }

    void run(int iteration_id) override {
        int nbodies = static_cast<int>(bodies.size());
        double dt = 0.01;

        int i = 0;
        while (i < nbodies) {
            Planet& b = bodies[i];
            b.move_from_i(bodies, nbodies, dt, i + 1);
            i++;
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

    static constexpr std::array<const char*, 9> PATTERNS = {
        "agggtaaa|tttaccct",
        "[cgt]gggtaaa|tttaccc[acg]",
        "a[act]ggtaaa|tttacc[agt]t",
        "ag[act]gtaaa|tttac[agt]ct",
        "agg[act]taaa|ttta[agt]cct",
        "aggg[acg]aaa|ttt[cgt]ccct",
        "agggt[cgt]aa|tt[acg]accct",
        "agggta[cgt]a|t[acg]taccct",
        "agggtaa[cgt]|[acg]ttaccct"
    };

    struct Replacement {
        char from;
        const char* to;
        size_t len;
    };

    static constexpr std::array<Replacement, 11> REPLACEMENTS = {{
        {'B', "(c|g|t)", 7},
        {'D', "(a|g|t)", 7},
        {'H', "(a|c|t)", 7},
        {'K', "(g|t)", 5},
        {'M', "(a|c)", 5},
        {'N', "(a|c|g|t)", 9},
        {'R', "(a|g)", 5},
        {'S', "(c|t)", 5},
        {'V', "(a|c|g)", 7},
        {'W', "(a|t)", 5},
        {'Y', "(c|t)", 5}
    }};

    size_t count_pattern(size_t pattern_idx) {
        if (!compiled_patterns[pattern_idx]) return 0;

        re2::StringPiece input(seq);
        size_t count = 0;

        re2::StringPiece match;
        const re2::RE2& pattern = *compiled_patterns[pattern_idx];

        while (pattern.Match(input, 0, input.size(), re2::RE2::UNANCHORED, &match, 1)) {
            count++;
            input.remove_prefix(match.data() - input.data() + match.size());
        }

        return count;
    }

public:
    RegexDna() : ilen(0), clen(0) {
        result_str.reserve(4096);
    }

    std::string name() const override { return "RegexDna"; }    

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

        for (const char* pattern : PATTERNS) {
            auto re = std::make_unique<re2::RE2>(pattern);
            if (!re->ok()) {
                std::cerr << "RE2 error for " << pattern << ": " << re->error() << std::endl;
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
            for (const auto& repl : REPLACEMENTS) {
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

    uint32_t checksum() override {
        return Helper::checksum(result_str);
    }
};

class Revcomp : public Benchmark {
private:
    std::string input;
    uint32_t _checksum;

    std::string revcomp(const std::string& seq) {

        std::string reversed = seq;

        std::reverse(reversed.begin(), reversed.end());

        static std::array<char, 256> lookup;
        static std::once_flag flag;

        std::call_once(flag, []() {
            for (int i = 0; i < 256; i++) {
                lookup[i] = static_cast<char>(i);
            }

            static constexpr std::string_view from = "wsatugcyrkmbdhvnATUGCYRKMBDHVN";
            static constexpr std::string_view to   = "WSTAACGRYMKVHDBNTAACGRYMKVHDBN";

            for (size_t i = 0; i < from.size(); i++) {
                lookup[static_cast<unsigned char>(from[i])] = to[i];
            }
        });

        for (char& c : reversed) {
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
    Revcomp(): _checksum(0) {}

    std::string name() const override { return "Revcomp"; }    

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

    uint32_t checksum() override {
        return _checksum;
    }
};

class Spectralnorm : public Benchmark {
private:
    int64_t size_val;
    std::vector<double> u;
    std::vector<double> v;

    double eval_A(int i, int j) {
        return 1.0 / ((i + j) * (i + j + 1.0) / 2.0 + i + 1.0);
    }

    std::vector<double> eval_A_times_u(const std::vector<double>& u) {
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

    std::vector<double> eval_At_times_u(const std::vector<double>& u) {
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

    std::vector<double> eval_AtA_times_u(const std::vector<double>& u) {
        return eval_At_times_u(eval_A_times_u(u));
    }

public:
    Spectralnorm() {
        size_val = config_val("size");
        u = std::vector<double>(size_val, 1.0);
        v = std::vector<double>(size_val, 1.0);
    }

    std::string name() const override { return "Spectralnorm"; }    

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

    static size_t b64_encode(char* dst, const char* src, size_t src_size) {
        size_t encoded_size;
        base64_encode(src, src_size, dst, &encoded_size, 0);
        return encoded_size;
    }

public:
    Base64Encode() : result_val(0) {
        int64_t n = config_val("size");
        str = std::string(static_cast<size_t>(n), 'a');

        size_t encoded_len = encode_size(str.size());
        str2.resize(encoded_len);
        size_t actual_len = 0;
        base64_encode(str.data(), str.size(), &str2[0], &actual_len, 0);
        str2.resize(actual_len);
    }

    std::string name() const override { return "Base64Encode"; }    

    void run(int iteration_id) override {

        str2 = base64_encode_simple(str);
        result_val += str2.size();  
    }

    uint32_t checksum() override {
        std::ostringstream ss;
        ss << "encode " << (str.size() > 4 ? str.substr(0, 4) + "..." : str) 
           << " to " << (str2.size() > 4 ? str2.substr(0, 4) + "..." : str2) 
           << ": " << result_val;
        return Helper::checksum(ss.str());
    }

private:
    std::string base64_encode_simple(const std::string& input) {
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

    static size_t b64_decode(char* dst, const char* src, size_t src_size) {
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

        size_t decoded_size = decode_size(str2.size());
        str3.resize(decoded_size);
        size_t actual_decoded = b64_decode(&str3[0], str2.data(), str2.size());
        str3.resize(actual_decoded);
    }

    std::string name() const override { return "Base64Decode"; }    

    void run(int iteration_id) override {

        str3 = base64_decode_simple(str2);
        result_val += str3.size();  
    }

    uint32_t checksum() override {
        std::ostringstream ss;
        ss << "decode " << (str2.size() > 4 ? str2.substr(0, 4) + "..." : str2) 
           << " to " << (str3.size() > 4 ? str3.substr(0, 4) + "..." : str3) 
           << ": " << result_val;
        return Helper::checksum(ss.str());
    }

private:
    std::string base64_decode_simple(const std::string& input) {
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

        Coordinate(double x, double y, double z, 
                   const std::string& name,
                   const std::unordered_map<std::string, std::pair<int, bool>>& opts)
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

    std::string name() const override { return "JsonGenerate"; }    

    void prepare() override {
        for (int64_t i = 0; i < n; i++) {
            double x = custom_round(Helper::next_float(), 8);
            double y = custom_round(Helper::next_float(), 8);
            double z = custom_round(Helper::next_float(), 8);

            std::ostringstream name;
            name << std::fixed << std::setprecision(7) 
                 << Helper::next_float() << " " << Helper::next_int(10000);

            std::unordered_map<std::string, std::pair<int, bool>> opts = {
                {"1", {1, true}}
            };

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
            const auto& coord = data[i];

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
            for (const auto& [key, value] : coord.opts) {
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

        if (_result.size() >= 15 && _result.compare(0, 15, "{\"coordinates\":") == 0) {
            result++;
        }
    }

    uint32_t checksum() override {
        return result;
    }

    const std::string& get_result() const { 
        return _result; 
    }
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

    std::string name() const override { return "JsonParseDom"; }    

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

        result_val += Helper::checksum_f64(x) + Helper::checksum_f64(y) + Helper::checksum_f64(z);  
    }

    uint32_t checksum() override {
        return result_val;
    }
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

    std::string name() const override { return "JsonParseMapping"; }    

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
        result_val += Helper::checksum_f64(avg.x) + Helper::checksum_f64(avg.y) + Helper::checksum_f64(avg.z);  
    }

    uint32_t checksum() override {
        return result_val;
    }
};

class Primes : public Benchmark {
private:
    struct Node {
        std::array<std::unique_ptr<Node>, 10> children;
        bool is_terminal;

        Node() : is_terminal(false) {}

        Node(const Node&) = delete;
        Node& operator=(const Node&) = delete;

        Node(Node&&) = default;
        Node& operator=(Node&&) = default;

        ~Node() = default;
    };

    static std::vector<int> generate_primes(int limit) {
        if (limit < 2) return {};

        std::vector<bool> is_prime(limit + 1, true);
        is_prime[0] = is_prime[1] = false;

        const int sqrt_limit = static_cast<int>(std::sqrt(limit));

        for (int p = 2; p <= sqrt_limit; ++p) {
            if (is_prime[p]) {
                for (int multiple = p * p; multiple <= limit; multiple += p) {
                    is_prime[multiple] = false;
                }
            }
        }

        std::vector<int> primes;
        primes.reserve(static_cast<size_t>(limit / (std::log(limit) - 1.1)));

        using namespace std::views;
        auto prime_numbers = iota(2, limit + 1) 
                           | filter([&is_prime](int n) { return is_prime[n]; });

        std::ranges::copy(prime_numbers, std::back_inserter(primes));

        return primes;
    }

    static std::unique_ptr<Node> build_trie(const std::vector<int>& primes) {
        auto root = std::make_unique<Node>();

        for (int prime : primes) {
            Node* current = root.get();
            std::string digits = std::to_string(prime);

            for (char digit_char : digits) {
                int digit = digit_char - '0';

                if (!current->children[digit]) {
                    current->children[digit] = std::make_unique<Node>();
                }
                current = current->children[digit].get();
            }
            current->is_terminal = true;
        }

        return root;
    }

    static std::vector<int> find_primes_with_prefix(const std::unique_ptr<Node>& trie_root, 
                                                    int prefix) {
        std::string prefix_str = std::to_string(prefix);

        const Node* current = trie_root.get();
        for (char digit_char : prefix_str) {
            int digit = digit_char - '0';

            if (!current->children[digit]) {
                return {};
            }
            current = current->children[digit].get();
        }

        std::vector<int> results;

        struct QueueItem {
            const Node* node;
            int number;
        };

        std::queue<QueueItem> bfs_queue;
        bfs_queue.push({current, prefix});

        while (!bfs_queue.empty()) {
            auto [node, number] = bfs_queue.front();
            bfs_queue.pop();

            if (node->is_terminal) {
                results.push_back(number);
            }

            for (int digit = 0; digit < 10; ++digit) {
                if (node->children[digit]) {
                    bfs_queue.push({node->children[digit].get(), 
                                   number * 10 + digit});
                }
            }
        }

        std::ranges::sort(results);
        return results;
    }

    int64_t n;
    int64_t prefix;
    uint32_t result_val;

public:
    Primes() : n(config_val("limit")), result_val(5432) {
        prefix = config_val("prefix");
    }

    std::string name() const override { return "Primes"; }    

    void run(int iteration_id) override {
        auto primes = generate_primes(static_cast<int>(n));

        auto trie = build_trie(primes);

        auto results = find_primes_with_prefix(trie, static_cast<int>(prefix));

        result_val += static_cast<uint32_t>(results.size());
        for (int prime : results) {
            result_val += static_cast<uint32_t>(prime);
        }
    }

    uint32_t checksum() override {
        return result_val;
    }
};

class Noise : public Benchmark {
private:
    struct Vec2 {
        double x, y;
    };

    class Noise2DContext {
    private:
        std::vector<Vec2> rgradients;
        std::vector<int> permutations;
        int size_val;

        static Vec2 random_gradient() {
            double v = Helper::next_float() * M_PI * 2.0;
            return {std::cos(v), std::sin(v)};
        }

        static double lerp(double a, double b, double v) {
            return a * (1.0 - v) + b * v;
        }

        static double smooth(double v) {
            return v * v * (3.0 - 2.0 * v);
        }

        static double gradient(const Vec2& orig, const Vec2& grad, const Vec2& p) {
            Vec2 sp = {p.x - orig.x, p.y - orig.y};
            return grad.x * sp.x + grad.y * sp.y;
        }

    public:
        Noise2DContext(int size) : size_val(size) {
            rgradients.resize(size);
            permutations.resize(size);

            for (int i = 0; i < size; i++) {
                rgradients[i] = random_gradient();
                permutations[i] = i;
            }

            for (int i = 0; i < size; i++) {
                int a = Helper::next_int(size);
                int b = Helper::next_int(size);
                std::swap(permutations[a], permutations[b]);
            }
        }

        Vec2 get_gradient(int x, int y) {
            int idx = permutations[x & (size_val - 1)] + permutations[y & (size_val - 1)];
            return rgradients[idx & (size_val - 1)];
        }

        std::pair<std::array<Vec2, 4>, std::array<Vec2, 4>> get_gradients(double x, double y) {
            double x0f = std::floor(x);
            double y0f = std::floor(y);
            int x0 = static_cast<int>(x0f);
            int y0 = static_cast<int>(y0f);
            int x1 = x0 + 1;
            int y1 = y0 + 1;

            std::array<Vec2, 4> gradients = {
                get_gradient(x0, y0),
                get_gradient(x1, y0),
                get_gradient(x0, y1),
                get_gradient(x1, y1)
            };

            std::array<Vec2, 4> origins = {
                Vec2{x0f + 0.0, y0f + 0.0},
                Vec2{x0f + 1.0, y0f + 0.0},
                Vec2{x0f + 0.0, y0f + 1.0},
                Vec2{x0f + 1.0, y0f + 1.0}
            };

            return {gradients, origins};
        }

        double get(double x, double y) {
            Vec2 p = {x, y};
            auto [gradients, origins] = get_gradients(x, y);

            double v0 = gradient(origins[0], gradients[0], p);
            double v1 = gradient(origins[1], gradients[1], p);
            double v2 = gradient(origins[2], gradients[2], p);
            double v3 = gradient(origins[3], gradients[3], p);

            double fx = smooth(x - origins[0].x);
            double vx0 = lerp(v0, v1, fx);
            double vx1 = lerp(v2, v3, fx);

            double fy = smooth(y - origins[0].y);
            return lerp(vx0, vx1, fy);
        }
    };

    static constexpr char32_t SYM[6] = {U' ', U'░', U'▒', U'▓', U'█', U'█'};

    int64_t size_val;
    uint32_t result_val;
    std::unique_ptr<Noise2DContext> n2d;

public:
    Noise() : result_val(0) {
        size_val = config_val("size");
        n2d = std::make_unique<Noise2DContext>(static_cast<int>(size_val));
    }

    std::string name() const override { return "Noise"; }    

    void run(int iteration_id) override {
        for (int64_t y = 0; y < size_val; y++) {
            for (int64_t x = 0; x < size_val; x++) {
                double v = n2d->get(x * 0.1, (y + (iteration_id * 128)) * 0.1) * 0.5 + 0.5;
                int idx = static_cast<int>(v / 0.2);
                if (idx >= 6) idx = 5;
                result_val += static_cast<uint32_t>(SYM[idx]);
            }
        }
    }

    uint32_t checksum() override {
        return result_val;
    }
};

class TextRaytracer : public Benchmark {
private:
    struct Vector {
        double x, y, z;

        Vector scale(double s) const { return {x * s, y * s, z * s}; }
        Vector add(const Vector& other) const { return {x + other.x, y + other.y, z + other.z}; }
        Vector sub(const Vector& other) const { return {x - other.x, y - other.y, z - other.z}; }
        double dot(const Vector& other) const { return x * other.x + y * other.y + z * other.z; }
        double magnitude() const { return std::sqrt(dot(*this)); }
        Vector normalize() const { 
            double mag = magnitude();
            if (mag == 0.0) return {0, 0, 0};
            return scale(1.0 / mag); 
        }
    };

    struct Ray {
        Vector orig, dir;
    };

    struct Color {
        double r, g, b;

        Color scale(double s) const { return {r * s, g * s, b * s}; }
        Color add(const Color& other) const { return {r + other.r, g + other.g, b + other.b}; }
    };

    struct Sphere {
        Vector center;
        double radius;
        Color color;

        Vector get_normal(const Vector& pt) const {
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

    std::vector<Sphere> SCENE = {
        {{-1.0, 0.0, 3.0}, 0.3, RED},
        {{0.0, 0.0, 3.0}, 0.8, GREEN},
        {{1.0, 0.0, 3.0}, 0.4, BLUE}
    };

    int32_t w, h;
    uint32_t result_val;

    int shade_pixel(const Ray& ray, const Sphere& obj, double tval) {
        Vector pi = ray.orig.add(ray.dir.scale(tval));
        Color color = diffuse_shading(pi, obj, LIGHT1);
        double col = (color.r + color.g + color.b) / 3.0;
        int idx = static_cast<int>(col * 6.0);
        if (idx < 0) idx = 0;
        if (idx >= 6) idx = 5;
        return idx;
    }

    std::optional<double> intersect_sphere(const Ray& ray, const Vector& center, double radius) {
        Vector l = center.sub(ray.orig);
        double tca = l.dot(ray.dir);
        if (tca < 0.0) return std::nullopt;

        double d2 = l.dot(l) - tca * tca;
        double r2 = radius * radius;
        if (d2 > r2) return std::nullopt;

        double thc = std::sqrt(r2 - d2);
        double t0 = tca - thc;
        if (t0 > 10000.0) return std::nullopt;

        return t0;
    }

    double clamp(double x, double a, double b) {
        if (x < a) return a;
        if (x > b) return b;
        return x;
    }

    Color diffuse_shading(const Vector& pi, const Sphere& obj, const Light& light) {
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

    std::string name() const override { return "TextRaytracer"; }    

    void run(int iteration_id) override {
        for (int j = 0; j < h; j++) {
            for (int i = 0; i < w; i++) {
                double fw = w, fi = i, fj = j, fh = h;

                Ray ray{
                    {0.0, 0.0, 0.0},
                    Vector{(fi - fw/2.0)/fw, (fj - fh/2.0)/fh, 1.0}.normalize()
                };

                std::optional<double> tval;
                const Sphere* hit_obj = nullptr;

                for (const auto& obj : SCENE) {
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

    uint32_t checksum() override {
        return result_val;
    }
};

class NeuralNet : public Benchmark {
private:
    class Neuron;

    class Synapse {
    public:
        double weight;
        double prev_weight;
        Neuron* source_neuron;
        Neuron* dest_neuron;

        Synapse(Neuron* source, Neuron* dest)
            : source_neuron(source), dest_neuron(dest) {
            weight = prev_weight = Helper::next_float() * 2 - 1;
        }
    };

    class Neuron {
    private:
        static constexpr double LEARNING_RATE = 1.0;
        static constexpr double MOMENTUM = 0.3;

        std::vector<Synapse*> synapses_in;
        std::vector<Synapse*> synapses_out;
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

        double derivative() const {
            return output * (1 - output);
        }

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
                synapse->weight += (rate * LEARNING_RATE * error * synapse->source_neuron->output) +
                                 (MOMENTUM * (synapse->weight - synapse->prev_weight));
                synapse->prev_weight = temp_weight;
            }

            double temp_threshold = threshold;
            threshold += (rate * LEARNING_RATE * error * -1) +
                       (MOMENTUM * (threshold - prev_threshold));
            prev_threshold = temp_threshold;
        }

        void add_synapse_in(Synapse* synapse) { synapses_in.push_back(synapse); }
        void add_synapse_out(Synapse* synapse) { synapses_out.push_back(synapse); }
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

            for (auto& source : input_layer) {
                for (auto& dest : hidden_layer) {
                    auto synapse = std::make_unique<Synapse>(&source, &dest);
                    source.add_synapse_out(synapse.get());
                    dest.add_synapse_in(synapse.get());
                    synapses.push_back(std::move(synapse));
                }
            }

            for (auto& source : hidden_layer) {
                for (auto& dest : output_layer) {
                    auto synapse = std::make_unique<Synapse>(&source, &dest);
                    source.add_synapse_out(synapse.get());
                    dest.add_synapse_in(synapse.get());
                    synapses.push_back(std::move(synapse));
                }
            }
        }

        void train(const std::vector<double>& inputs, const std::vector<double>& targets) {
            feed_forward(inputs);

            for (size_t i = 0; i < output_layer.size(); i++) {
                output_layer[i].output_train(0.3, targets[i]);
            }

            for (auto& neuron : hidden_layer) {
                neuron.hidden_train(0.3);
            }
        }

        void feed_forward(const std::vector<double>& inputs) {
            for (size_t i = 0; i < input_layer.size(); i++) {
                input_layer[i].set_output(inputs[i]);
            }

            for (auto& neuron : hidden_layer) {
                neuron.calculate_output();
            }

            for (auto& neuron : output_layer) {
                neuron.calculate_output();
            }
        }

        std::vector<double> current_outputs() {
            std::vector<double> outputs;
            outputs.reserve(output_layer.size());
            for (const auto& neuron : output_layer) {
                outputs.push_back(neuron.get_output());
            }
            return outputs;
        }
    };

    std::vector<double> res;
    std::unique_ptr<NeuralNetwork> xor_net;

public:
    NeuralNet() {
        xor_net = std::make_unique<NeuralNetwork>(0, 0, 0);
    }

    std::string name() const override { return "NeuralNet"; }    

    void prepare() override {
        xor_net = std::make_unique<NeuralNetwork>(2, 10, 1);
    }

    void run(int iteration_id) override {
        NeuralNetwork& xor_ref = *xor_net;
        xor_ref.train({0, 0}, {0});
        xor_ref.train({1, 0}, {1});
        xor_ref.train({0, 1}, {1});
        xor_ref.train({1, 1}, {0});
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

    SortBenchmark() : result_val(0), size_val(0) {
    }

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

    uint32_t checksum() override {
        return result_val;
    }
};

class SortQuick : public SortBenchmark {
private:
    void quick_sort(std::vector<int32_t>& arr, int low, int high) {
        if (low >= high) return;

        int pivot = arr[(low + high) / 2];
        int i = low, j = high;

        while (i <= j) {
            while (arr[i] < pivot) i++;
            while (arr[j] > pivot) j--;
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

    std::string name() const override { return "SortQuick"; }    

    std::vector<int32_t> test() override {
        std::vector<int32_t> arr = data;
        quick_sort(arr, 0, static_cast<int>(arr.size() - 1));
        return arr;
    }
};

class SortMerge : public SortBenchmark {
private:
    void merge_sort_inplace(std::vector<int32_t>& arr) {
        std::vector<int32_t> temp(arr.size());
        merge_sort_helper(arr, temp, 0, static_cast<int>(arr.size() - 1));
    }

    void merge_sort_helper(std::vector<int32_t>& arr, std::vector<int32_t>& temp, int left, int right) {
        if (left >= right) return;

        int mid = (left + right) / 2;
        merge_sort_helper(arr, temp, left, mid);
        merge_sort_helper(arr, temp, mid + 1, right);
        merge(arr, temp, left, mid, right);
    }

    void merge(std::vector<int32_t>& arr, std::vector<int32_t>& temp, int left, int mid, int right) {
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

    std::string name() const override { return "SortMerge"; }    

    std::vector<int32_t> test() override {
        std::vector<int32_t> arr = data;
        merge_sort_inplace(arr);
        return arr;
    }
};

class SortSelf : public SortBenchmark {
public:
    SortSelf() = default;

    std::string name() const override { return "SortSelf"; }

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
        int components;
        std::vector<std::vector<int>> adj;

        Graph(int vertices, int components = 10) 
            : vertices(vertices), components(components), adj(vertices) {}

        void add_edge(int u, int v) {
            adj[u].push_back(v);
            adj[v].push_back(u);
        }

        void generate_random() {
            int component_size = vertices / components;

            for (int c = 0; c < components; c++) {
                int start_idx = c * component_size;
                int end_idx = (c == components - 1) ? vertices : (c + 1) * component_size;

                for (int i = start_idx + 1; i < end_idx; i++) {
                    int parent = start_idx + Helper::next_int(i - start_idx);
                    add_edge(i, parent);
                }

                int extra_edges = component_size * 2;
                for (int e = 0; e < extra_edges; e++) {
                    int u = start_idx + Helper::next_int(end_idx - start_idx);
                    int v = start_idx + Helper::next_int(end_idx - start_idx);
                    if (u != v) add_edge(u, v);
                }
            }
        }

        bool same_component(int u, int v) {
            int component_size = vertices / components;
            return (u / component_size) == (v / component_size);
        }
    };

    std::unique_ptr<Graph> graph;
    std::vector<std::pair<int, int>> pairs;
    int64_t n_pairs;
    uint32_t result_val;

    std::vector<std::pair<int, int>> generate_pairs(int n) {
        std::vector<std::pair<int, int>> result;
        result.reserve(static_cast<size_t>(n));
        int component_size = graph->vertices / 10;

        for (int i = 0; i < n; i++) {
            if (Helper::next_int(100) < 70) {
                int component = Helper::next_int(10);
                int start = component * component_size + Helper::next_int(component_size);
                int end;
                do {
                    end = component * component_size + Helper::next_int(component_size);
                } while (end == start);
                result.emplace_back(start, end);
            } else {
                int c1 = Helper::next_int(10);
                int c2;
                do {
                    c2 = Helper::next_int(10);
                } while (c2 == c1);
                int start = c1 * component_size + Helper::next_int(component_size);
                int end = c2 * component_size + Helper::next_int(component_size);
                result.emplace_back(start, end);
            }
        }
        return result;
    }

    GraphPathBenchmark() : result_val(0), n_pairs(0) {

    }

public:
    void prepare() override {
        if (n_pairs == 0) {
            n_pairs = config_val("pairs");
            int vertices = static_cast<int>(config_val("vertices"));
            int comps = std::max(10, vertices / 10'000);
            graph = std::make_unique<Graph>(vertices, comps);
            graph->generate_random();
            pairs = generate_pairs(static_cast<int>(n_pairs));
        }
    }

    virtual int64_t test() = 0;

    void run(int iteration_id) override {
        result_val += test();  
    }

    uint32_t checksum() override {
        return result_val;
    }
};

class GraphPathBFS : public GraphPathBenchmark {
private:
    int bfs_shortest_path(int start, int target) {
        if (start == target) return 0;

        std::vector<uint8_t> visited(graph->vertices, 0);
        std::queue<std::pair<int, int>> queue;

        visited[start] = 1;
        queue.push({start, 0});

        while (!queue.empty()) {
            auto [v, dist] = queue.front();
            queue.pop();

            for (int neighbor : graph->adj[v]) {
                if (neighbor == target) return dist + 1;

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

    std::string name() const override { return "GraphPathBFS"; }    

    int64_t test() override {
        int64_t total_length = 0;

        for (const auto& [start, end] : pairs) {
            total_length += bfs_shortest_path(start, end);
        }

        return total_length;
    }
};

class GraphPathDFS : public GraphPathBenchmark {
private:
    int dfs_find_path(int start, int target) {
        if (start == target) return 0;

        std::vector<uint8_t> visited(graph->vertices, 0);
        std::stack<std::pair<int, int>> stack;
        int best_path = INT_MAX;

        stack.push({start, 0});

        while (!stack.empty()) {
            auto [v, dist] = stack.top();
            stack.pop();

            if (visited[v] == 1 || dist >= best_path) continue;
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

    std::string name() const override { return "GraphPathDFS"; }    

    int64_t test() override {
        int64_t total_length = 0;

        for (const auto& [start, end] : pairs) {
            total_length += dfs_find_path(start, end);
        }

        return total_length;
    }
};

class GraphPathDijkstra : public GraphPathBenchmark {
private:
    static constexpr int INF = INT_MAX / 2;

    int dijkstra_shortest_path(int start, int target) {
        if (start == target) return 0;

        std::vector<int> dist(graph->vertices, INF);
        std::vector<uint8_t> visited(graph->vertices, 0);

        dist[start] = 0;

        for (int iteration = 0; iteration < graph->vertices; iteration++) {
            int u = -1;
            int min_dist = INF;

            for (int v = 0; v < graph->vertices; v++) {
                if (visited[v] == 0 && dist[v] < min_dist) {
                    min_dist = dist[v];
                    u = v;
                }
            }

            if (u == -1 || min_dist == INF || u == target) {
                return (u == target) ? min_dist : -1;
            }

            visited[u] = 1;

            for (int v : graph->adj[u]) {
                if (dist[u] + 1 < dist[v]) {
                    dist[v] = dist[u] + 1;
                }
            }
        }

        return -1;
    }

public:
    GraphPathDijkstra() = default;

    std::string name() const override { return "GraphPathDijkstra"; }    

    int64_t test() override {
        int64_t total_length = 0;

        for (const auto& [start, end] : pairs) {
            total_length += dijkstra_shortest_path(start, end);
        }

        return total_length;
    }
};

class BufferHashBenchmark : public Benchmark {
protected:
    std::vector<uint8_t> data;
    int64_t size_val;
    uint32_t result_val;

    BufferHashBenchmark() : result_val(0), size_val(0) {

    }

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

    void run(int iteration_id) override {
        result_val += test();  
    }

    uint32_t checksum() override {
        return result_val;
    }
};

class BufferHashSHA256 : public BufferHashBenchmark {
private:
    struct SimpleSHA256 {
        static std::vector<uint8_t> digest(const std::vector<uint8_t>& data) {
            std::vector<uint8_t> result(32);

            uint32_t hashes[8] = {
                0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
                0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
            };

            for (size_t i = 0; i < data.size(); i++) {
                uint32_t hash_idx = i % 8;
                uint32_t& hash = hashes[hash_idx];
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

    std::string name() const override { return "BufferHashSHA256"; }    

    uint32_t test() override {
        auto bytes = SimpleSHA256::digest(data);
        return *reinterpret_cast<uint32_t*>(bytes.data());
    }
};

class BufferHashCRC32 : public BufferHashBenchmark {
private:
    uint32_t crc32(const std::vector<uint8_t>& data) {
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

    std::string name() const override { return "BufferHashCRC32"; }    

    uint32_t test() override {
        return crc32(data);
    }
};

class CacheSimulation : public Benchmark {
private:
    class FastLRUCache {
    private:
        size_t capacity_;
        std::unordered_map<std::string, 
            std::pair<std::string, 
                typename std::list<std::string>::iterator>> cache_;
        std::list<std::string> lru_list_;

    public:
        FastLRUCache(size_t capacity) : capacity_(capacity) {}

        bool get(const std::string& key) {
            auto it = cache_.find(key);
            if (it != cache_.end()) {
                lru_list_.erase(it->second.second);
                lru_list_.push_front(key);
                it->second.second = lru_list_.begin();
                return true;
            }
            return false;
        }

        void put(const std::string& key, const std::string& value) {
            auto it = cache_.find(key);
            if (it != cache_.end()) {
                lru_list_.erase(it->second.second);
                lru_list_.push_front(key);
                cache_[key] = {value, lru_list_.begin()};
                return;
            }

            if (cache_.size() >= capacity_) {
                std::string oldest_key = lru_list_.back();
                lru_list_.pop_back();
                cache_.erase(oldest_key);
            }

            lru_list_.push_front(key);
            cache_[key] = {value, lru_list_.begin()};
        }

        size_t size() const { return cache_.size(); }
    };

    uint32_t result_val;
    int values_size;
    int cache_size;
    FastLRUCache cache;
    int hits = 0;
    int misses = 0;

public:
    CacheSimulation() : result_val(5432), cache(0) {
        values_size = static_cast<int>(config_val("values"));
        cache_size = static_cast<int>(config_val("size"));
    }

    std::string name() const override { return "CacheSimulation"; }    

    void prepare() override {
        cache = FastLRUCache(cache_size);
    }

    void run(int iteration_id) override {
        char key_buf[32];
        snprintf(key_buf, sizeof(key_buf), "item_%d", Helper::next_int(values_size));
        std::string key(key_buf);

        if (cache.get(key)) {
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

    uint32_t checksum() override {
        uint32_t final_result = result_val;
        final_result = (final_result << 5) + hits;
        final_result = (final_result << 5) + misses;
        final_result = (final_result << 5) + static_cast<uint32_t>(cache.size());
        return final_result;
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
        Variable(const std::string& n) : name(n) {}
    };

    struct BinaryOp;
    struct Assignment;

    struct Node {
        std::variant<Number, Variable, std::unique_ptr<BinaryOp>, std::unique_ptr<Assignment>> data;

        Node(Number n) : data(std::move(n)) {}
        Node(Variable v) : data(std::move(v)) {}
        Node(std::unique_ptr<BinaryOp> b) : data(std::move(b)) {}
        Node(std::unique_ptr<Assignment> a) : data(std::move(a)) {}

        Node(const Node&) = delete;
        Node& operator=(const Node&) = delete;
        Node(Node&&) = default;
        Node& operator=(Node&&) = default;
    };

    struct BinaryOp {
        char op;
        Node left;
        Node right;

        BinaryOp(char o, Node l, Node r) : op(o), left(std::move(l)), right(std::move(r)) {}
    };

    struct Assignment {
        std::string var;
        Node expr;

        Assignment(const std::string& v, Node e) : var(v), expr(std::move(e)) {}
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
            while (current_char != '\0' && std::isspace(static_cast<unsigned char>(current_char))) {
                advance();
            }
        }

        Node parse_number() {
            int64_t v = 0;
            while (current_char != '\0' && std::isdigit(static_cast<unsigned char>(current_char))) {
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
                if (current_char == '\0') break;

                if (current_char == '*' || current_char == '/' || current_char == '%') {
                    char op = current_char;
                    advance();
                    auto right = parse_factor();
                    node = Node(std::make_unique<BinaryOp>(op, std::move(node), std::move(right)));
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
                if (current_char == '\0') break;

                if (current_char == '+' || current_char == '-') {
                    char op = current_char;
                    advance();
                    auto right = parse_term();
                    node = Node(std::make_unique<BinaryOp>(op, std::move(node), std::move(right)));
                } else {
                    break;
                }
            }

            return node;
        }

    public:
        Parser(const std::string& input_str) : input(input_str), pos(0) {
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
                if (current_char == '\0') break;
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
                    os << "(v" << (v - 1) << " / 3) * 4 - " << i << " / (3 + (18 - v" << (v - 2) << ")) % v" << (v - 3) << " + 2 * ((9 - v" << (v - 6) << ") * (v" << (v - 5) << " + 7))";
                    break;
                case 1:
                    os << "v" << (v - 1) << " + (v" << (v - 2) << " + v" << (v - 3) << ") * v" << (v - 4) << " - (v" << (v - 5) << " / v" << (v - 6) << ")";
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

    std::string name() const override { return "CalculatorAst"; }    
    std::vector<Node> expressions;

    void prepare() override {
        text = generate_random_program(n);
    }

    void run(int iteration_id) override {
        Parser parser(text);
        expressions = parser.parse();
        result_val += expressions.size();
        if (!expressions.empty() && std::holds_alternative<std::unique_ptr<Assignment>>(expressions.back().data)) {
            auto& assign = *std::get<std::unique_ptr<Assignment>>(expressions.back().data);
            result_val += Helper::checksum(assign.var);
        }
    }

    uint32_t checksum() override {
        return result_val;
    }
};

class CalculatorInterpreter : public Benchmark {
private:
    class Interpreter {
    private:
        std::unordered_map<std::string, int64_t> variables;

        static int64_t simple_div(int64_t a, int64_t b) {
            if (b == 0) return 0;
            if ((a >= 0 && b > 0) || (a < 0 && b < 0)) {
                return a / b;
            } else {
                return -(std::abs(a) / std::abs(b));
            }
        }

        static int64_t simple_mod(int64_t a, int64_t b) {
            if (b == 0) return 0;
            return a - simple_div(a, b) * b;
        }

        struct Evaluator {
            std::unordered_map<std::string, int64_t>& variables;

            Evaluator(std::unordered_map<std::string, int64_t>& vars) : variables(vars) {}

            int64_t operator()(const CalculatorAst::Number& n) const {
                return n.value;
            }

            int64_t operator()(const CalculatorAst::Variable& v) const {
                auto it = variables.find(v.name);
                return (it != variables.end()) ? it->second : 0;
            }

            int64_t operator()(const std::unique_ptr<CalculatorAst::BinaryOp>& binop) const {
                int64_t left = std::visit(*this, binop->left.data);
                int64_t right = std::visit(*this, binop->right.data);

                switch (binop->op) {
                    case '+': return left + right;
                    case '-': return left - right;
                    case '*': return left * right;
                    case '/': return simple_div(left, right);
                    case '%': return simple_mod(left, right);
                    default: return 0;
                }
            }

            int64_t operator()(const std::unique_ptr<CalculatorAst::Assignment>& assign) const {
                int64_t value = std::visit(*this, assign->expr.data);
                variables[assign->var] = value;
                return value;
            }
        };

    public:
        int64_t run(const std::vector<CalculatorAst::Node>& expressions) {
            int64_t result = 0;
            Evaluator evaluator(variables);

            for (const auto& expr : expressions) {
                result = std::visit(evaluator, expr.data);
            }
            return result;
        }

        void clear() {
            variables.clear();
        }
    };

    int64_t n;
    uint32_t result_val;
    std::vector<CalculatorAst::Node> ast;

public:
    CalculatorInterpreter() : result_val(0) {
        n = config_val("operations");
    }

    std::string name() const override { return "CalculatorInterpreter"; }    

    void prepare() override {
        CalculatorAst ca;
        ca.n = n;
        ca.prepare();
        ca.run(0);
        ast.swap(const_cast<std::vector<CalculatorAst::Node>&>(
            reinterpret_cast<const CalculatorAst&>(ca).expressions));
        }

    void run(int iteration_id) override {
        Interpreter interpreter;
        int64_t result = interpreter.run(ast);
        result_val += result;  
    }

    uint32_t checksum() override {
        return result_val;
    }
};

class GameOfLife : public Benchmark {
private:
    enum class Cell : uint8_t {
        Dead = 0,
        Alive = 1
    };

    class Grid {
    private:
        int width_;
        int height_;
        std::vector<Cell> cells_;      
        std::vector<Cell> buffer_;     

        int count_neighbors(int x, int y, const std::vector<Cell>& cells) const {

            int y_prev = (y == 0) ? height_ - 1 : y - 1;
            int y_next = (y == height_ - 1) ? 0 : y + 1;
            int x_prev = (x == 0) ? width_ - 1 : x - 1;
            int x_next = (x == width_ - 1) ? 0 : x + 1;

            int count = 0;
            count += static_cast<int>(cells[y_prev * width_ + x_prev] == Cell::Alive);
            count += static_cast<int>(cells[y_prev * width_ + x] == Cell::Alive);
            count += static_cast<int>(cells[y_prev * width_ + x_next] == Cell::Alive);
            count += static_cast<int>(cells[y * width_ + x_prev] == Cell::Alive);
            count += static_cast<int>(cells[y * width_ + x_next] == Cell::Alive);
            count += static_cast<int>(cells[y_next * width_ + x_prev] == Cell::Alive);
            count += static_cast<int>(cells[y_next * width_ + x] == Cell::Alive);
            count += static_cast<int>(cells[y_next * width_ + x_next] == Cell::Alive);

            return count;
        }

    public:
        Grid(int width, int height) : width_(width), height_(height) {
            int size = width * height;
            cells_.resize(size, Cell::Dead);
            buffer_.resize(size, Cell::Dead);
        }

        Cell get(int x, int y) const {
            return cells_[y * width_ + x];
        }

        void set(int x, int y, Cell cell) {
            cells_[y * width_ + x] = cell;
        }

        Grid& next_generation() {
            const int width = width_;
            const int height = height_;
            const int size = width * height;

            const std::vector<Cell>& cells = cells_;
            std::vector<Cell>& buffer = buffer_;

            for (int y = 0; y < height; ++y) {
                const int y_idx = y * width;

                for (int x = 0; x < width; ++x) {
                    const int idx = y_idx + x;

                    int neighbors = count_neighbors(x, y, cells);

                    Cell current = cells[idx];
                    Cell next_state = Cell::Dead;

                    if (current == Cell::Alive) {
                        next_state = (neighbors == 2 || neighbors == 3) ? Cell::Alive : Cell::Dead;
                    } else {
                        next_state = (neighbors == 3) ? Cell::Alive : Cell::Dead;
                    }

                    buffer[idx] = next_state;
                }
            }

            std::swap(cells_, buffer_);
            return *this;
        }

        uint32_t compute_hash() const {
            constexpr uint32_t FNV_OFFSET_BASIS = 2166136261UL;
            constexpr uint32_t FNV_PRIME = 16777619UL;

            uint32_t hash = FNV_OFFSET_BASIS;

            const Cell* data = cells_.data();
            const size_t size = cells_.size();

            for (size_t i = 0; i < size; ++i) {
                uint32_t alive = static_cast<uint32_t>(data[i] == Cell::Alive);
                hash = (hash ^ alive) * FNV_PRIME;
            }

            return hash;
        }

        int width() const { return width_; }
        int height() const { return height_; }
    };

    uint32_t result_val;
    int32_t width_;
    int32_t height_;
    Grid grid_;

public:
    GameOfLife() : 
        result_val(0),
        width_(static_cast<int32_t>(config_val("w"))),
        height_(static_cast<int32_t>(config_val("h"))),
        grid_(width_, height_) {
    }

    std::string name() const override { return "GameOfLife"; }    

    void prepare() override {

        for (int y = 0; y < height_; ++y) {
            for (int x = 0; x < width_; ++x) {
                if (Helper::next_float(1.0) < 0.1) {
                    grid_.set(x, y, Cell::Alive);
                }
            }
        }
    }

    void run(int iteration_id) override {

        grid_.next_generation();
    }

    uint32_t checksum() override {
        return grid_.compute_hash();
    }
};

class MazeGenerator : public Benchmark {
private:
    enum class Cell {
        Wall,
        Path
    };

    uint32_t result_val;
    int32_t width_;
    int32_t height_;
    std::vector<std::vector<bool>> bool_grid;

public:
    class Maze {
    private:
        int width_;
        int height_;
        std::vector<std::vector<Cell>> cells_;

        void add_random_paths() {
            int num_extra_paths = (width_ * height_) / 20; 

            for (int i = 0; i < num_extra_paths; i++) {
                int x = Helper::next_int(width_ - 2) + 1; 
                int y = Helper::next_int(height_ - 2) + 1;

                if ((*this)(x, y) == Cell::Wall &&
                    (*this)(x - 1, y) == Cell::Wall &&
                    (*this)(x + 1, y) == Cell::Wall &&
                    (*this)(x, y - 1) == Cell::Wall &&
                    (*this)(x, y + 1) == Cell::Wall) {
                    (*this)(x, y) = Cell::Path;
                }
            }
        }

        void divide(int x1, int y1, int x2, int y2) {
            int width = x2 - x1;
            int height = y2 - y1;

            if (width < 2 || height < 2) return;

            int width_for_wall = std::max(width - 2, 0);
            int height_for_wall = std::max(height - 2, 0);
            int width_for_hole = std::max(width - 1, 0);
            int height_for_hole = std::max(height - 1, 0);

            if (width_for_wall == 0 || height_for_wall == 0 ||
                width_for_hole == 0 || height_for_hole == 0) return;

            if (width > height) {
                int wall_range = std::max(width_for_wall / 2, 1);
                int wall_offset = wall_range > 0 ? Helper::next_int(wall_range) * 2 : 0;
                int wall_x = x1 + 2 + wall_offset;

                int hole_range = std::max(height_for_hole / 2, 1);
                int hole_offset = hole_range > 0 ? Helper::next_int(hole_range) * 2 : 0;
                int hole_y = y1 + 1 + hole_offset;

                if (wall_x > x2 || hole_y > y2) return;

                for (int y = y1; y <= y2; y++) {
                    if (y != hole_y) {
                        (*this)(wall_x, y) = Cell::Wall;
                    }
                }

                if (wall_x > x1 + 1) divide(x1, y1, wall_x - 1, y2);
                if (wall_x + 1 < x2) divide(wall_x + 1, y1, x2, y2);
            } else {
                int wall_range = std::max(height_for_wall / 2, 1);
                int wall_offset = wall_range > 0 ? Helper::next_int(wall_range) * 2 : 0;
                int wall_y = y1 + 2 + wall_offset;

                int hole_range = std::max(width_for_hole / 2, 1);
                int hole_offset = hole_range > 0 ? Helper::next_int(hole_range) * 2 : 0;
                int hole_x = x1 + 1 + hole_offset;

                if (wall_y > y2 || hole_x > x2) return;

                for (int x = x1; x <= x2; x++) {
                    if (x != hole_x) {
                        (*this)(x, wall_y) = Cell::Wall;
                    }
                }

                if (wall_y > y1 + 1) divide(x1, y1, x2, wall_y - 1);
                if (wall_y + 1 < y2) divide(x1, wall_y + 1, x2, y2);
            }
        }

        bool is_connected_impl(const std::pair<int, int>& start, const std::pair<int, int>& goal) const {
            if (start.first >= width_ || start.second >= height_ ||
                goal.first >= width_ || goal.second >= height_) {
                return false;
            }

            std::vector<std::vector<bool>> visited(height_, std::vector<bool>(width_, false));
            std::deque<std::pair<int, int>> queue;

            visited[start.second][start.first] = true;
            queue.push_back(start);

            while (!queue.empty()) {
                auto [x, y] = queue.front();
                queue.pop_front();

                if (std::make_pair(x, y) == goal) return true;

                if (y > 0 && (*this)(x, y - 1) == Cell::Path && !visited[y - 1][x]) {
                    visited[y - 1][x] = true;
                    queue.push_back({x, y - 1});
                }

                if (x + 1 < width_ && (*this)(x + 1, y) == Cell::Path && !visited[y][x + 1]) {
                    visited[y][x + 1] = true;
                    queue.push_back({x + 1, y});
                }

                if (y + 1 < height_ && (*this)(x, y + 1) == Cell::Path && !visited[y + 1][x]) {
                    visited[y + 1][x] = true;
                    queue.push_back({x, y + 1});
                }

                if (x > 0 && (*this)(x - 1, y) == Cell::Path && !visited[y][x - 1]) {
                    visited[y][x - 1] = true;
                    queue.push_back({x - 1, y});
                }
            }

            return false;
        }

    public:
        Maze(int width, int height) : width_(width > 5 ? width : 5), 
                                      height_(height > 5 ? height : 5) {
            cells_.resize(height_, std::vector<Cell>(width_, Cell::Wall));
        }

        Cell operator()(int x, int y) const {
            return cells_[y][x];
        }

        Cell& operator()(int x, int y) {
            return cells_[y][x];
        }

        void generate() {
            if (width_ < 5 || height_ < 5) {
                for (int x = 0; x < width_; x++) {
                    (*this)(x, height_ / 2) = Cell::Path;
                }
                return;
            }

            divide(0, 0, width_ - 1, height_ - 1);
            add_random_paths();
        }

        std::vector<std::vector<bool>> to_bool_grid() const {
            std::vector<std::vector<bool>> result;
            result.reserve(height_);

            for (const auto& row : cells_) {
                std::vector<bool> bool_row;
                bool_row.reserve(width_);
                for (Cell cell : row) {
                    bool_row.push_back(cell == Cell::Path);
                }
                result.push_back(std::move(bool_row));
            }

            return result;
        }

        bool is_connected(const std::pair<int, int>& start, const std::pair<int, int>& goal) const {
            return is_connected_impl(start, goal);
        }

        static std::vector<std::vector<bool>> generate_walkable_maze(int width, int height) {
            Maze maze(width, height);
            maze.generate();

            std::pair<int, int> start = {1, 1};
            std::pair<int, int> goal = {width - 2, height - 2};

            if (!maze.is_connected(start, goal)) {
                for (int x = 0; x < width; x++) {
                    for (int y = 0; y < height; y++) {
                        if (x < maze.width_ && y < maze.height_) {
                            if (x == 1 || y == 1 || x == width - 2 || y == height - 2) {
                                maze(x, y) = Cell::Path;
                            }
                        }
                    }
                }
            }

            return maze.to_bool_grid();
        }

        int width() const { return width_; }
        int height() const { return height_; }
    };

    uint32_t grid_checksum(const std::vector<std::vector<bool>>& grid) const {
        uint32_t hasher = 2166136261UL;      
        uint32_t prime = 16777619UL;         

        for (size_t i = 0; i < grid.size(); i++) {
            const auto& row = grid[i];
            for (size_t j = 0; j < row.size(); j++) {
                if (row[j]) {  
                    uint32_t j_squared = static_cast<uint32_t>(j * j);
                    hasher = (hasher ^ j_squared) * prime;
                }
            }
        }
        return hasher;
    }

public:
    MazeGenerator() : result_val(0) {
        width_ = static_cast<int32_t>(config_val("w"));
        height_ = static_cast<int32_t>(config_val("h"));
    }

    std::string name() const override { return "MazeGenerator"; }    

    void run(int iteration_id) override {
        bool_grid = Maze::generate_walkable_maze(width_, height_);
    }

    uint32_t checksum() override {
        return grid_checksum(bool_grid);
    }
};

class AStarPathfinder : public Benchmark {
private:
    static constexpr int INF = std::numeric_limits<int>::max();
    static constexpr int STRAIGHT_COST = 1000;

    struct Node {
        int x, y, f_score;

        bool operator<(const Node& other) const {
            if (f_score != other.f_score) return f_score < other.f_score;
            if (y != other.y) return y < other.y;
            return x < other.x;
        }

        bool operator>(const Node& other) const {
            return other < *this;
        }
    };

    uint32_t result_val = 0;
    int width_ = 0;
    int height_ = 0;
    int start_x_ = 1;
    int start_y_ = 1;
    int goal_x_ = 0;
    int goal_y_ = 0;

    std::vector<std::vector<bool>> maze_grid_;

    std::vector<int> g_scores_;    
    std::vector<int> came_from_;   

    int heuristic(int x1, int y1, int x2, int y2) const {
        return std::abs(x1 - x2) + std::abs(y1 - y2);
    }

    int pack_coords(int x, int y) const {
        return y * width_ + x;
    }

    std::pair<int, int> unpack_coords(int idx) const {
        return {idx % width_, idx / width_};
    }

    std::pair<std::vector<std::pair<int, int>>, int> find_path() {
        const int size = width_ * height_;
        const int start_idx = pack_coords(start_x_, start_y_);
        const int goal_idx = pack_coords(goal_x_, goal_y_);

        std::fill(g_scores_.begin(), g_scores_.end(), INF);
        std::fill(came_from_.begin(), came_from_.end(), -1);

        std::priority_queue<Node, std::vector<Node>, std::greater<Node>> open_set;

        g_scores_[start_idx] = 0;
        open_set.push({start_x_, start_y_, 
                      heuristic(start_x_, start_y_, goal_x_, goal_y_)});

        int nodes_explored = 0;
        static constexpr std::pair<int, int> directions[] = {{0, -1}, {1, 0}, {0, 1}, {-1, 0}};

        while (!open_set.empty()) {
            Node current = open_set.top();
            open_set.pop();
            nodes_explored++;

            if (current.x == goal_x_ && current.y == goal_y_) {

                std::vector<std::pair<int, int>> path;
                path.reserve(width_ + height_);

                int x = current.x;
                int y = current.y;

                while (x != start_x_ || y != start_y_) {
                    path.emplace_back(x, y);
                    int idx = pack_coords(x, y);
                    int packed = came_from_[idx];
                    if (packed == -1) break;

                    auto [px, py] = unpack_coords(packed);
                    x = px;
                    y = py;
                }

                path.emplace_back(start_x_, start_y_);
                std::reverse(path.begin(), path.end());
                return {path, nodes_explored};
            }

            int current_idx = pack_coords(current.x, current.y);
            int current_g = g_scores_[current_idx];

            for (const auto& [dx, dy] : directions) {
                int nx = current.x + dx;
                int ny = current.y + dy;

                if (nx < 0 || nx >= width_ || ny < 0 || ny >= height_) continue;
                if (!maze_grid_[ny][nx]) continue;

                int tentative_g = current_g + STRAIGHT_COST;
                int neighbor_idx = pack_coords(nx, ny);

                if (tentative_g < g_scores_[neighbor_idx]) {
                    came_from_[neighbor_idx] = current_idx;
                    g_scores_[neighbor_idx] = tentative_g;

                    int f_score = tentative_g + heuristic(nx, ny, goal_x_, goal_y_);
                    open_set.push({nx, ny, f_score});
                }
            }
        }

        return {{}, nodes_explored};
    }

public:
    AStarPathfinder() {
        width_ = static_cast<int>(config_val("w"));
        height_ = static_cast<int>(config_val("h"));
        goal_x_ = width_ - 2;
        goal_y_ = height_ - 2;
    }

    std::string name() const override { return "AStarPathfinder"; }    

    void prepare() override {

        maze_grid_ = MazeGenerator::Maze::generate_walkable_maze(width_, height_);

        int size = width_ * height_;
        g_scores_.resize(size);
        came_from_.resize(size);
    }

    void run(int iteration_id) override {
        auto [path, nodes_explored] = find_path();

        int64_t local_result = 0;
        if (!path.empty()) {
            local_result = (local_result << 5) + static_cast<int64_t>(path.size());
        }
        local_result = (local_result << 5) + nodes_explored;
        result_val += static_cast<uint32_t>(local_result);
    }

    uint32_t checksum() override {
        return result_val;
    }
};

class BWTHuffEncode : public Benchmark {
private:
    struct BWTResult {
        std::vector<uint8_t> transformed;
        size_t original_idx;

        BWTResult(std::vector<uint8_t> t, size_t idx) 
            : transformed(std::move(t)), original_idx(idx) {}
    };

    BWTResult bwt_transform(const std::vector<uint8_t>& input) {
        size_t n = input.size();
        if (n == 0) {
            return BWTResult({}, 0);
        }

        std::vector<uint8_t> doubled(n * 2);
        std::copy(input.begin(), input.end(), doubled.begin());
        std::copy(input.begin(), input.end(), doubled.begin() + n);

        std::vector<size_t> sa(n);
        for (size_t i = 0; i < n; i++) {
            sa[i] = i;
        }

        std::vector<std::vector<size_t>> buckets(256);
        for (size_t idx : sa) {
            uint8_t first_char = input[idx];
            buckets[first_char].push_back(idx);
        }

        size_t pos = 0;
        for (const auto& bucket : buckets) {
            for (size_t idx : bucket) {
                sa[pos++] = idx;
            }
        }

        if (n > 1) {
            std::vector<int> rank(n, 0);
            int current_rank = 0;
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
                std::vector<std::pair<int, int>> pairs(n);
                for (size_t i = 0; i < n; i++) {
                    pairs[i] = {rank[i], rank[(i + k) % n]};
                }

                std::sort(sa.begin(), sa.end(), [&pairs](size_t a, size_t b) {
                    auto pair_a = pairs[a];
                    auto pair_b = pairs[b];
                    if (pair_a.first != pair_b.first) {
                        return pair_a.first < pair_b.first;
                    }
                    return pair_a.second < pair_b.second;
                });

                std::vector<int> new_rank(n, 0);
                new_rank[sa[0]] = 0;
                for (size_t i = 1; i < n; i++) {
                    auto prev_pair = pairs[sa[i - 1]];
                    auto curr_pair = pairs[sa[i]];
                    new_rank[sa[i]] = new_rank[sa[i - 1]] + 
                        (prev_pair != curr_pair ? 1 : 0);
                }

                rank = std::move(new_rank);
                k *= 2;
            }
        }

        std::vector<uint8_t> transformed(n);
        size_t original_idx = 0;

        for (size_t i = 0; i < n; i++) {
            size_t suffix = sa[i];
            if (suffix == 0) {
                transformed[i] = input[n - 1];
                original_idx = i;
            } else {
                transformed[i] = input[suffix - 1];
            }
        }

        return BWTResult(std::move(transformed), original_idx);
    }

    std::vector<uint8_t> bwt_inverse(const BWTResult& bwt_result) {
        const auto& bwt = bwt_result.transformed;
        size_t n = bwt.size();
        if (n == 0) {
            return {};
        }

        size_t counts[256] = {0};  
        for (uint8_t byte : bwt) {
            counts[byte]++;
        }

        size_t positions[256] = {0};  
        size_t total = 0;
        for (int i = 0; i < 256; i++) {
            positions[i] = total;
            total += counts[i];
        }

        std::vector<size_t> next(n, 0);  

        size_t temp_counts[256] = {0};  
        for (size_t i = 0; i < n; i++) {
            uint8_t byte = bwt[i];  
            size_t pos = positions[byte] + temp_counts[byte];  
            next[pos] = i;
            temp_counts[byte]++;
        }

        std::vector<uint8_t> result;
        result.reserve(n);  

        size_t idx = bwt_result.original_idx;
        for (size_t i = 0; i < n; i++) {
            idx = next[idx];
            result.push_back(bwt[idx]);
        }

        return result;
    }

    struct HuffmanNode {
        int frequency;
        uint8_t byte_val;
        bool is_leaf;
        std::shared_ptr<HuffmanNode> left;
        std::shared_ptr<HuffmanNode> right;

        HuffmanNode(int freq, uint8_t byte = 0, bool leaf = true)
            : frequency(freq), byte_val(byte), is_leaf(leaf) {}
    };

    struct HuffmanNodeCompare {
        bool operator()(const std::shared_ptr<HuffmanNode>& a, 
                       const std::shared_ptr<HuffmanNode>& b) const {
            return a->frequency > b->frequency;
        }
    };

    std::shared_ptr<HuffmanNode> build_huffman_tree(const std::vector<int>& frequencies) {
        std::priority_queue<
            std::shared_ptr<HuffmanNode>,
            std::vector<std::shared_ptr<HuffmanNode>>,
            HuffmanNodeCompare> heap;

        for (int i = 0; i < 256; i++) {
            if (frequencies[i] > 0) {
                heap.push(std::make_unique<HuffmanNode>(frequencies[i], static_cast<uint8_t>(i)));
            }
        }

        if (heap.size() == 1) {
            auto node = heap.top();
            heap.pop();

            auto root = std::make_shared<HuffmanNode>(node->frequency, 0, false);
            root->left = node;
            root->right = std::make_shared<HuffmanNode>(0, 0);
            return root;
        }

        while (heap.size() > 1) {
            auto left = heap.top();
            heap.pop();
            auto right = heap.top();
            heap.pop();

            auto parent = std::make_shared<HuffmanNode>(
                left->frequency + right->frequency, 0, false);
            parent->left = left;
            parent->right = right;

            heap.push(parent);
        }

        return heap.top();
    }

    struct HuffmanCodes {
        std::vector<int> code_lengths;
        std::vector<int> codes;

        HuffmanCodes() : code_lengths(256, 0), codes(256, 0) {}
    };

    void build_huffman_codes(const std::shared_ptr<HuffmanNode>& node, int code, int length, 
                            HuffmanCodes& huffman_codes) {
        if (node->is_leaf) {
            if (length > 0 || node->byte_val != 0) {
                int idx = node->byte_val;
                huffman_codes.code_lengths[idx] = length;
                huffman_codes.codes[idx] = code;
            }
        } else {
            if (node->left) {
                build_huffman_codes(node->left, code << 1, length + 1, huffman_codes);
            }
            if (node->right) {
                build_huffman_codes(node->right, (code << 1) | 1, length + 1, huffman_codes);
            }
        }
    }

    struct EncodedResult {
        std::vector<uint8_t> data;
        int bit_count;

        EncodedResult(std::vector<uint8_t> d, int bc) 
            : data(std::move(d)), bit_count(bc) {}
    };

    EncodedResult huffman_encode(const std::vector<uint8_t>& data, const HuffmanCodes& huffman_codes) {
        std::vector<uint8_t> result(data.size() * 2);
        uint8_t current_byte = 0;
        int bit_pos = 0;
        size_t byte_index = 0;
        int total_bits = 0;

        for (uint8_t byte : data) {
            int idx = byte;
            int code = huffman_codes.codes[idx];
            int length = huffman_codes.code_lengths[idx];

            for (int i = length - 1; i >= 0; i--) {
                if ((code & (1 << i)) != 0) {
                    current_byte |= 1 << (7 - bit_pos);
                }
                bit_pos++;
                total_bits++;

                if (bit_pos == 8) {
                    result[byte_index++] = current_byte;
                    current_byte = 0;
                    bit_pos = 0;
                }
            }
        }

        if (bit_pos > 0) {
            result[byte_index++] = current_byte;
        }

        result.resize(byte_index);
        return EncodedResult(std::move(result), total_bits);
    }

    std::vector<uint8_t> huffman_decode(const std::vector<uint8_t>& encoded, 
                                       const std::shared_ptr<HuffmanNode>& root, 
                                       int bit_count) {
        std::vector<uint8_t> result;
        result.reserve(bit_count / 4 + 1);  

        const HuffmanNode* current_node = root.get();  
        int bits_processed = 0;
        size_t byte_index = 0;

        while (bits_processed < bit_count && byte_index < encoded.size()) {
            uint8_t byte_val = encoded[byte_index++];

            if (bits_processed + 8 <= bit_count) {

                for (int bit_pos = 7; bit_pos >= 0; bit_pos--) {
                    bool bit = ((byte_val >> bit_pos) & 1) == 1;
                    current_node = bit ? current_node->right.get() : current_node->left.get();

                    if (current_node->is_leaf) {
                        result.push_back(current_node->byte_val);
                        current_node = root.get();
                    }
                }
                bits_processed += 8;
            } else {

                for (int bit_pos = 7; bit_pos >= 0 && bits_processed < bit_count; bit_pos--) {
                    bool bit = ((byte_val >> bit_pos) & 1) == 1;
                    current_node = bit ? current_node->right.get() : current_node->left.get();
                    bits_processed++;

                    if (current_node->is_leaf) {
                        result.push_back(current_node->byte_val);
                        current_node = root.get();
                    }
                }
            }
        }

        return result;
    }

public:
    struct CompressedData {
        BWTResult bwt_result;
        std::vector<int> frequencies;
        std::vector<uint8_t> encoded_bits;
        int original_bit_count;

        CompressedData(BWTResult bwt, std::vector<int> freq, 
                      std::vector<uint8_t> encoded, int bit_count)
            : bwt_result(std::move(bwt)), frequencies(std::move(freq)),
              encoded_bits(std::move(encoded)), original_bit_count(bit_count) {}
    };

    CompressedData compress(const std::vector<uint8_t>& data) {
        BWTResult bwt_result = bwt_transform(data);

        std::vector<int> frequencies(256, 0);
        for (uint8_t byte : bwt_result.transformed) {
            frequencies[byte]++;
        }

        std::shared_ptr<HuffmanNode> huffman_tree = build_huffman_tree(frequencies);

        HuffmanCodes huffman_codes;
        build_huffman_codes(huffman_tree, 0, 0, huffman_codes);

        EncodedResult encoded = huffman_encode(bwt_result.transformed, huffman_codes);

        return CompressedData(
            std::move(bwt_result),
            std::move(frequencies),
            std::move(encoded.data),
            encoded.bit_count
        );
    }

    std::vector<uint8_t> decompress(const CompressedData& compressed) {
        std::shared_ptr<HuffmanNode> huffman_tree = build_huffman_tree(compressed.frequencies);

        std::vector<uint8_t> decoded = huffman_decode(
            compressed.encoded_bits,
            huffman_tree,
            compressed.original_bit_count
        );

        BWTResult bwt_result(std::move(decoded), compressed.bwt_result.original_idx);

        return bwt_inverse(bwt_result);
    }

    std::vector<uint8_t> generate_test_data(int64_t data_size) {
        std::string pattern = "ABRACADABRA";
        std::vector<uint8_t> data(static_cast<size_t>(data_size));
        for (int64_t i = 0; i < data_size; i++) {
            data[static_cast<size_t>(i)] = pattern[i % pattern.size()];
        }

        return data;
    }

public:
    int64_t size_val;
    std::vector<uint8_t> test_data;
    uint32_t result_val;

    BWTHuffEncode() : result_val(0) {
        size_val = config_val("size");
    }

    std::string name() const override { return "BWTHuffEncode"; }    

    void prepare() override {
        test_data = generate_test_data(size_val);
    }

    void run(int iteration_id) override {
        CompressedData compressed = compress(test_data);
        result_val += compressed.encoded_bits.size();  
    }

    uint32_t checksum() override {
        return result_val;
    }
};

class BWTHuffDecode : public BWTHuffEncode {
private:
    std::optional<CompressedData> compressed_data;
    std::vector<uint8_t> decompressed;

public:
    BWTHuffDecode() {
        size_val = config_val("size");
    }

    std::string name() const override { return "BWTHuffDecode"; }    

    void prepare() override {
        test_data = generate_test_data(size_val);
        compressed_data = compress(test_data);
    }

    void run(int iteration_id) override {
        decompressed = decompress(*compressed_data);
        result_val += decompressed.size();  
    }

    uint32_t checksum() override {
        uint32_t res = result_val;
        if (test_data == decompressed) {
            res += 1000000;
        }
        return res;
    }
};

std::string to_lower(const std::string& str) {
    std::string result = str;
    std::transform(result.begin(), result.end(), result.begin(),
                   [](unsigned char c) { return std::tolower(c); });
    return result;
}

void Benchmark::all(const std::string& single_bench) {
    std::unordered_map<std::string, double> results;
    double summary_time = 0.0;
    int ok = 0;
    int fails = 0;

    std::vector<std::pair<std::string, std::function<std::unique_ptr<Benchmark>()>>> benchmarks = {
        {"Pidigits", []() { return std::make_unique<Pidigits>(); }},
        {"Binarytrees", []() { return std::make_unique<Binarytrees>(); }},
        {"BrainfuckArray", []() { return std::make_unique<BrainfuckArray>(); }},
        {"BrainfuckRecursion", []() { return std::make_unique<BrainfuckRecursion>(); }},
        {"Fannkuchredux", []() { return std::make_unique<Fannkuchredux>(); }},
        {"Fasta", []() { return std::make_unique<Fasta>(); }},
        {"Knuckeotide", []() { return std::make_unique<Knuckeotide>(); }},
        {"Mandelbrot", []() { return std::make_unique<Mandelbrot>(); }},
        {"Matmul1T", []() { return std::make_unique<Matmul1T>(); }},
        {"Matmul4T", []() { return std::make_unique<Matmul4T>(); }},
        {"Matmul8T", []() { return std::make_unique<Matmul8T>(); }},
        {"Matmul16T", []() { return std::make_unique<Matmul16T>(); }},
        {"Nbody", []() { return std::make_unique<Nbody>(); }},
        {"RegexDna", []() { return std::make_unique<RegexDna>(); }},
        {"Revcomp", []() { return std::make_unique<Revcomp>(); }},
        {"Spectralnorm", []() { return std::make_unique<Spectralnorm>(); }},
        {"Base64Encode", []() { return std::make_unique<Base64Encode>(); }},
        {"Base64Decode", []() { return std::make_unique<Base64Decode>(); }},
        {"JsonGenerate", []() { return std::make_unique<JsonGenerate>(); }},
        {"JsonParseDom", []() { return std::make_unique<JsonParseDom>(); }},
        {"JsonParseMapping", []() { return std::make_unique<JsonParseMapping>(); }},
        {"Primes", []() { return std::make_unique<Primes>(); }},
        {"Noise", []() { return std::make_unique<Noise>(); }},        
        {"TextRaytracer", []() { return std::make_unique<TextRaytracer>(); }},
        {"NeuralNet", []() { return std::make_unique<NeuralNet>(); }},
        {"SortQuick", []() { return std::make_unique<SortQuick>(); }},
        {"SortMerge", []() { return std::make_unique<SortMerge>(); }},
        {"SortSelf", []() { return std::make_unique<SortSelf>(); }},
        {"GraphPathBFS", []() { return std::make_unique<GraphPathBFS>(); }},
        {"GraphPathDFS", []() { return std::make_unique<GraphPathDFS>(); }},
        {"GraphPathDijkstra", []() { return std::make_unique<GraphPathDijkstra>(); }},
        {"BufferHashSHA256", []() { return std::make_unique<BufferHashSHA256>(); }},
        {"BufferHashCRC32", []() { return std::make_unique<BufferHashCRC32>(); }},
        {"CacheSimulation", []() { return std::make_unique<CacheSimulation>(); }},        
        {"CalculatorAst", []() { return std::make_unique<CalculatorAst>(); }},
        {"CalculatorInterpreter", []() { return std::make_unique<CalculatorInterpreter>(); }},
        {"GameOfLife", []() { return std::make_unique<GameOfLife>(); }},
        {"MazeGenerator", []() { return std::make_unique<MazeGenerator>(); }},        
        {"AStarPathfinder", []() { return std::make_unique<AStarPathfinder>(); }},        
        {"BWTHuffEncode", []() { return std::make_unique<BWTHuffEncode>(); }},        
        {"BWTHuffDecode", []() { return std::make_unique<BWTHuffDecode>(); }},        
    };

    for (auto& [name, create_benchmark] : benchmarks) {
        if (!single_bench.empty() && to_lower(name).find(to_lower(single_bench)) == std::string::npos) {
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
        bench->set_time_delta(duration.count());
        results[name] = duration.count();

        if (bench->checksum() == bench->expected_checksum()) {
            std::cout << "OK ";
            ok++;
        } else {
            std::cout << "ERR[actual=" << bench->checksum() 
                      << ", expected=" << bench->expected_checksum() << "] ";
            fails++;
        }

        std::cout << "in " << std::fixed << std::setprecision(3) 
                  << duration.count() << "s" << std::endl;

        summary_time += duration.count();

        bench.reset();
        std::this_thread::sleep_for(std::chrono::milliseconds(1));
    }

    std::ofstream results_file("/tmp/results.js");
    results_file << "{";
    bool first = true;
    for (const auto& [name, time] : results) {
        if (!first) results_file << ",";
        results_file << "\"" << name << "\":" << time;
        first = false;
    }
    results_file << "}";
    results_file.close();

    if (ok + fails > 0) {
        std::cout << "Summary: "
                  << std::fixed << std::setprecision(4) 
                  << summary_time << "s, " << (ok + fails) << ", " << ok << ", " << fails << std::endl;
    }

    if (fails > 0) {
        std::exit(1);
    }
}

int main(int argc, char* argv[]) {
    auto now = std::chrono::duration_cast<std::chrono::milliseconds>(
        std::chrono::system_clock::now().time_since_epoch()
    ).count();
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