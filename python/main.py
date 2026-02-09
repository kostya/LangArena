from __future__ import annotations

import array
import base64
import collections
import concurrent.futures
import functools
import hashlib
import heapq
import json
import math
import multiprocessing
import os
import re
import sys
import time

from abc import ABC, abstractmethod
from collections import OrderedDict, deque
from concurrent.futures import ThreadPoolExecutor, TimeoutError
from dataclasses import dataclass
from enum import Enum
from io import StringIO
from pathlib import Path
from typing import (Any, Callable, Dict, List, NamedTuple, Optional, Union)

def with_timeout(timeout_seconds):

    def decorator(func):
        @functools.wraps(func)
        def wrapper(*args, **kwargs):
            with ThreadPoolExecutor(max_workers=1) as executor:
                future = executor.submit(func, *args, **kwargs)
                try:
                    return future.result(timeout=timeout_seconds)
                except TimeoutError:
                    future.cancel()
                    raise TimeoutError(f"Function {func.__name__} timed out after {timeout_seconds} seconds")
        return wrapper
    return decorator

class Performance:
    @staticmethod
    def now() -> float:
        return time.time() * 1000  

class Helper:
    IM = 139968
    IA = 3877
    IC = 29573
    INIT = 42

    _last_value = INIT
    _config: Optional[Dict[str, Any]] = None

    @staticmethod
    def reset() -> None:
        Helper._last_value = Helper.INIT

    @property
    @staticmethod
    def last() -> int:
        return Helper._last_value

    @last.setter
    @staticmethod
    def last(value: int) -> None:
        Helper._last_value = value

    @staticmethod
    def next_int(max_val: int) -> int:
        Helper._last_value = (Helper._last_value * Helper.IA + Helper.IC) % Helper.IM
        return int(Helper._last_value / Helper.IM * max_val)

    @staticmethod
    def next_int_range(from_val: int, to_val: int) -> int:
        return Helper.next_int(to_val - from_val + 1) + from_val

    @staticmethod
    def next_float(max_val: float = 1.0) -> float:
        Helper._last_value = (Helper._last_value * Helper.IA + Helper.IC) % Helper.IM
        return max_val * Helper._last_value / Helper.IM

    @staticmethod
    def debug(message: str) -> None:
        if os.environ.get('DEBUG') == '1':
            print(f'DEBUG: {message}')

    @staticmethod
    def checksum_string(s: str) -> int:
        hash_val = 5381
        for char in s:
            hash_val = ((hash_val << 5) + hash_val) + ord(char)
            hash_val &= 0xFFFFFFFF
        return hash_val & 0xFFFFFFFF

    @staticmethod
    def checksum_bytes(data: bytes) -> int:
        hash_val = 5381
        for byte in data:
            hash_val = ((hash_val << 5) + hash_val) + byte
            hash_val &= 0xFFFFFFFF
        return hash_val & 0xFFFFFFFF

    @staticmethod
    def checksum_float(value: float) -> int:
        return Helper.checksum_string(f"{value:.7f}")

    @staticmethod
    def load_config(config_file: str = '../test.json') -> None:
        try:
            config_path = Path(config_file)
            if not config_path.exists():

                config_path = Path(config_file.replace('../', ''))

            with open(config_path, 'r') as f:
                Helper._config = json.load(f)
        except Exception as e:
            print(f'Error loading config file {config_file}: {e}')
            sys.exit(1)

    @staticmethod
    def config_i64(className: str, fieldName: str) -> int:
        if Helper._config is None or className not in Helper._config:
            raise Exception(f'Config not found for class {className}')

        value = Helper._config[className][fieldName]
        if isinstance(value, (int, str)):
            return int(value)
        raise Exception(f'Config for {className}, not found i64 field: {fieldName}')

    @staticmethod
    def config_s(className: str, fieldName: str) -> str:
        if Helper._config is None or className not in Helper._config:
            raise Exception(f'Config not found for class {className}')

        value = Helper._config[className][fieldName]
        if isinstance(value, str):
            return value
        raise Exception(f'Config for {className}, not found string field: {fieldName}')

class TreeNode:
    def __init__(self, item: int, depth: int = 0):
        self.item = item
        self.left: Optional[TreeNode] = None
        self.right: Optional[TreeNode] = None

        if depth > 0:
            self.left = TreeNode(2 * item - 1, depth - 1)
            self.right = TreeNode(2 * item, depth - 1)

    @staticmethod
    def create(item: int, depth: int) -> 'TreeNode':
        return TreeNode(item, depth - 1)

    def check(self) -> int:
        if self.left is None or self.right is None:
            return self.item
        return self.left.check() - self.right.check() + self.item

class Benchmark(ABC):
    def __init__(self):
        self._iterations_cache = None

    @abstractmethod
    def run_benchmark(self, iteration_id: int) -> None:
        pass

    @abstractmethod
    def checksum(self) -> int:
        pass

    def prepare(self) -> None:
        pass

    @property
    def config(self) -> Dict[str, Any]:
        config = Helper._config
        class_name = self.__class__.__name__
        if config and class_name in config:
            return config[class_name]
        return {}

    @property
    def warmup_iterations(self) -> int:
        if Helper._config and 'warmup_iterations' in Helper._config:
            return int(Helper._config['warmup_iterations'])
        return max(int(self.iterations * 0.2), 1)

    @with_timeout(150)
    def warmup(self) -> None:
        for i in range(self.warmup_iterations):
            self.run_benchmark(i)

    @with_timeout(150)
    def run_all(self) -> None:
        for i in range(self.iterations):
            self.run_benchmark(i)

    @property
    def iterations(self) -> int:
        if self._iterations_cache is None:
            try:
                class_name = self.__class__.__name__
                self._iterations_cache = Helper.config_i64(class_name, 'iterations')
            except:
                self._iterations_cache = 1
        return self._iterations_cache

    @property
    def expected_checksum(self) -> int:
        try:
            class_name = self.__class__.__name__
            return Helper.config_i64(class_name, 'checksum')
        except:
            return 0

    @staticmethod
    def run(single_bench: Optional[str] = None) -> None:
        results = {}
        summary_time = 0.0
        ok = 0
        fails = 0

        for benchmark_class in Benchmark._benchmark_classes:
            bench_instance = benchmark_class()
            class_name = bench_instance.__class__.__name__

            if single_bench and single_bench.lower() not in class_name.lower():
                continue

            if class_name in ['SortBenchmark', 'BufferHashBenchmark', 'GraphPathBenchmark']:
                continue

            print(f'{class_name}: ', end='', flush=True)

            bench = benchmark_class()
            Helper.reset()
            bench.prepare()

            try:
                bench.warmup()
            except TimeoutError:
                pass

            Helper.reset()

            start_time = Performance.now()
            try:
                bench.run_all()
                end_time = Performance.now()
                time_delta = (end_time - start_time) / 1000.0
                results[class_name] = time_delta
                actual_result = bench.checksum()
            except TimeoutError:
                end_time = Performance.now()
                time_delta = (end_time - start_time) / 1000.0
                results[class_name] = time_delta
                actual_result = "Timeout"

            expected_result = bench.expected_checksum

            if actual_result == expected_result:
                print('OK ', end='')
                ok += 1
            else:
                print(f'ERR[actual={actual_result}, expected={expected_result}] ', end='')
                fails += 1

            print(f'in {time_delta:.3f}s')
            summary_time += time_delta

        try:
            results_path = Path('/tmp/results.python.json')
            with open(results_path, 'w') as f:
                json.dump(results, f)
        except:
            pass

        print(f'Summary: {summary_time:.4f}s, {ok + fails}, {ok}, {fails}')

        if fails > 0:
            sys.exit(1)

    _benchmark_classes: List[Callable[[], 'Benchmark']] = []

    @staticmethod
    def register_benchmark(constructor: Callable[[], 'Benchmark']) -> None:
        Benchmark._benchmark_classes.append(constructor)

class Binarytrees(Benchmark):
    def __init__(self):
        super().__init__()
        class_name = self.__class__.__name__
        self.n = Helper.config_i64(class_name, 'depth')
        self.result = 0

    def run_benchmark(self, iteration_id: int) -> None:
        min_depth = 4
        max_depth = max(min_depth + 2, self.n)
        stretch_depth = max_depth + 1

        stretch_tree = TreeNode.create(0, stretch_depth)
        self.result += stretch_tree.check()

        for depth in range(min_depth, max_depth + 1, 2):
            iterations = 1 << (max_depth - depth + min_depth)

            for i in range(1, iterations + 1):
                tree1 = TreeNode.create(i, depth)
                tree2 = TreeNode.create(-i, depth)

                self.result += tree1.check()
                self.result += tree2.check()

    def checksum(self) -> int:
        return self.result & 0xFFFFFFFF

class BrainfuckProgram:
    def __init__(self, text: str):
        self._commands = self._filter_commands(text)
        self._jumps = [0] * len(self._commands)
        self._build_jumps()

    @staticmethod
    def _filter_commands(text: str) -> str:

        buffer = []
        for char in text:
            if char in '[]<>+-,.':
                buffer.append(char)
        return ''.join(buffer)

    def _build_jumps(self):

        stack = []

        for i, cmd in enumerate(self._commands):
            if cmd == '[':
                stack.append(i)
            elif cmd == ']' and stack:
                start = stack.pop()
                self._jumps[start] = i
                self._jumps[i] = start

    def run(self) -> int:

        result = 0
        tape = Tape()
        pc = 0

        while pc < len(self._commands):
            cmd = self._commands[pc]

            if cmd == '+':
                tape.inc()
            elif cmd == '-':
                tape.dec()
            elif cmd == '>':
                tape.advance()
            elif cmd == '<':
                tape.devance()
            elif cmd == '[':
                if tape.get() == 0:
                    pc = self._jumps[pc]
            elif cmd == ']':
                if tape.get() != 0:
                    pc = self._jumps[pc]
            elif cmd == '.':
                result = ((result << 2) + tape.get()) & 0xFFFFFFFF

            pc += 1

        return result

class Tape:
    def __init__(self, size: int = 30000):
        self._tape = bytearray(size)
        self._pos = 0

    def get(self) -> int:
        return self._tape[self._pos]

    def inc(self):
        self._tape[self._pos] = (self._tape[self._pos] + 1) & 0xFF

    def dec(self):
        self._tape[self._pos] = (self._tape[self._pos] - 1) & 0xFF

    def advance(self):
        self._pos += 1
        if self._pos >= len(self._tape):
            self._tape.append(0)

    def devance(self):
        if self._pos > 0:
            self._pos -= 1

class BrainfuckArray(Benchmark):
    def __init__(self):
        super().__init__()
        self._program_text = ""
        self._warmup_text = ""
        self._result_value = 0

    def prepare(self):
        class_name = self.__class__.__name__
        self._program_text = Helper.config_s(class_name, "program")
        self._warmup_text = Helper.config_s(class_name, "warmup_program")

    def warmup(self):
        prepare_iters = self.warmup_iterations
        for i in range(prepare_iters):
            BrainfuckProgram(self._warmup_text).run()

    def run_benchmark(self, iteration_id: int):
        result = BrainfuckProgram(self._program_text).run()
        self._result_value = (self._result_value + result) & 0xFFFFFFFF

    def checksum(self) -> int:
        return self._result_value & 0xFFFFFFFF

class Op:

    pass

@dataclass
class IncOp(Op):
    value: int

@dataclass
class MoveOp(Op):
    value: int

@dataclass
class PrintOp(Op):
    pass

@dataclass
class LoopOp(Op):
    ops: List[Op]

class Tape2:
    INITIAL_SIZE = 1024

    def __init__(self):
        self._tape = bytearray(self.INITIAL_SIZE)
        self._pos = 0

    def get(self) -> int:
        return self._tape[self._pos]

    def inc(self, x: int):
        self._tape[self._pos] = (self._tape[self._pos] + x) & 0xFF

    def move(self, x: int):
        self._pos += x

        if self._pos >= len(self._tape):
            new_length = max(self._pos + 1, len(self._tape) * 2)
            new_length = min(new_length, 1 << 30)  
            new_tape = bytearray(new_length)
            new_tape[:len(self._tape)] = self._tape
            self._tape = new_tape

        if self._pos < 0:
            self._pos = 0

class BrainfuckProgram2:
    def __init__(self, code: str):
        self._ops = self._parse(code)
        self._result_value = 0

    def run(self) -> int:
        self._result_value = 0
        self._run_ops(self._ops, Tape2())
        return self._result_value

    def _run_ops(self, program: List[Op], tape: Tape2):
        for op in program:
            if isinstance(op, LoopOp):
                while tape.get() != 0:
                    self._run_ops(op.ops, tape)
            elif isinstance(op, IncOp):
                tape.inc(op.value)
            elif isinstance(op, MoveOp):
                tape.move(op.value)
            elif isinstance(op, PrintOp):
                self._result_value = ((self._result_value << 2) + tape.get()) & 0xFFFFFFFF

    @staticmethod
    def _parse_sequence(chars: List[str], index: int):

        result = []
        i = index

        while i < len(chars):
            c = chars[i]
            i += 1

            op = None

            if c == '+':
                op = IncOp(1)
            elif c == '-':
                op = IncOp(-1)
            elif c == '>':
                op = MoveOp(1)
            elif c == '<':
                op = MoveOp(-1)
            elif c == '.':
                op = PrintOp()
            elif c == '[':

                parse_result = BrainfuckProgram2._parse_sequence(chars, i)
                result.append(LoopOp(parse_result[0]))
                i = parse_result[1]  
                continue  
            elif c == ']':

                return result, i
            else:
                continue  

            if op is not None:
                result.append(op)

        return result, i

    @staticmethod
    def _parse(code: str) -> List[Op]:

        chars = list(code)
        parse_result = BrainfuckProgram2._parse_sequence(chars, 0)
        return parse_result[0]  

class BrainfuckRecursion(Benchmark):
    def __init__(self):
        super().__init__()
        self._text = ""
        self._result_value = 0

    def prepare(self):
        class_name = self.__class__.__name__
        self._text = Helper.config_s(class_name, "program")

    def warmup(self):
        class_name = self.__class__.__name__
        warmup_program = Helper.config_s(class_name, "warmup_program")
        for i in range(self.warmup_iterations):
            program = BrainfuckProgram2(warmup_program)
            program.run()

    def run_benchmark(self, iteration_id: int):
        program = BrainfuckProgram2(self._text)
        self._result_value = (self._result_value + program.run()) & 0xFFFFFFFF

    def checksum(self) -> int:
        return self._result_value & 0xFFFFFFFF

class Pidigits(Benchmark):
    def __init__(self):
        super().__init__()
        self.nn = 0
        self._result_buffer = []
        self._result_str = ""

    def prepare(self):
        class_name = self.__class__.__name__
        self.nn = Helper.config_i64(class_name, "amount")

    def run_benchmark(self, iteration_id: int):
        i = 0
        k = 0
        ns = 0
        a = 0
        k1 = 1
        n = 1
        d = 1

        while True:
            k += 1
            t = n << 1
            n *= k
            k1 += 2
            a = (a + t) * k1
            d *= k1

            if a >= n:
                temp = n * 3 + a
                t = temp // d
                u = temp % d
                u += n

                if d > u:
                    digit = t
                    ns = ns * 10 + digit
                    i += 1

                    if i % 10 == 0:
                        line = f"{ns:010d}\t:{i}\n"
                        self._result_buffer.append(line)
                        ns = 0

                    if i >= self.nn:
                        break

                    a = (a - d * t) * 10
                    n *= 10

        if ns != 0 and self._result_buffer:
            remaining_digits = 10 if self.nn % 10 == 0 else self.nn % 10
            line = f"{ns:0{remaining_digits}d}\t:{i}\n"
            self._result_buffer.append(line)

        self._result_str = ''.join(self._result_buffer)

    def checksum(self) -> int:
        return Helper.checksum_string(self._result_str)

class Fannkuchredux(Benchmark):
    def __init__(self):
        super().__init__()
        self.n = 0
        self._result_value = 0

    def prepare(self):
        class_name = self.__class__.__name__
        self.n = Helper.config_i64(class_name, "n")

    def _fannkuchredux(self, n: int) -> Tuple[int, int]:
        perm1 = list(range(n))
        perm = [0] * n
        count = [0] * n

        max_flips_count = 0
        perm_count = 0
        checksum = 0
        r = n

        while True:
            while r > 1:
                count[r - 1] = r
                r -= 1

            perm[:] = perm1

            flips_count = 0
            k = perm[0]

            while k != 0:
                k2 = (k + 1) // 2

                for i in range(k2):
                    j = k - i
                    perm[i], perm[j] = perm[j], perm[i]

                flips_count += 1
                k = perm[0]

            if flips_count > max_flips_count:
                max_flips_count = flips_count

            checksum += flips_count if perm_count % 2 == 0 else -flips_count

            while True:
                if r == n:
                    return checksum, max_flips_count

                perm0 = perm1[0]
                for i in range(r):
                    j = i + 1
                    perm1[i], perm1[j] = perm1[j], perm1[i]

                perm1[r] = perm0
                count[r] -= 1
                cntr = count[r]

                if cntr > 0:
                    break

                r += 1

            perm_count += 1

    def run_benchmark(self, iteration_id: int):
        checksum, max_flips_count = self._fannkuchredux(self.n)
        self._result_value += checksum * 100 + max_flips_count

    def checksum(self) -> int:
        return self._result_value

@dataclass
class Gene:
    char: str
    prob: float

class Fasta(Benchmark):
    LINE_LENGTH = 60

    IUB = [
        Gene('a', 0.27), Gene('c', 0.39), Gene('g', 0.51),
        Gene('t', 0.78), Gene('B', 0.8), Gene('D', 0.8200000000000001),
        Gene('H', 0.8400000000000001), Gene('K', 0.8600000000000001),
        Gene('M', 0.8800000000000001), Gene('N', 0.9000000000000001),
        Gene('R', 0.9200000000000002), Gene('S', 0.9400000000000002),
        Gene('V', 0.9600000000000002), Gene('W', 0.9800000000000002),
        Gene('Y', 1.0000000000000002),
    ]

    HOMO = [
        Gene('a', 0.302954942668), Gene('c', 0.5009432431601),
        Gene('g', 0.6984905497992), Gene('t', 1.0),
    ]

    ALU = (
        "GGCCGGGCGCGGTGGCTCACGCCTGTAATCCCAGCACTTTGGGAGGCCGAGGCGGGCGG"
        "ATCACCTGAGGTCAGGAGTTCGAGACCAGCCTGGCCAACATGGTGAAACCCCGTCTCTA"
        "CTAAAAATACAAAAATTAGCCGGGCGTGGTGGCGCGCGCCTGTAATCCCAGCTACTCGG"
        "GAGGCTGAGGCAGGAGAATCGCTTGAACCCGGGAGGCGGAGGTTGCAGTGAGCCGAGAT"
        "CGCGCCACTGCACTCCAGCCTGGGCGACAGAGCGAGACTCCGTCTCAAAAA"
    )

    def __init__(self):
        super().__init__()
        class_name = self.__class__.__name__
        self.n = Helper.config_i64(class_name, "n")
        self.result_buffer = StringIO()

    def set_iterations(self, count: int):
        self.n = count

    def _select_random(self, genelist: List[Gene]) -> str:
        r = Helper.next_float()

        if r < genelist[0].prob:
            return genelist[0].char

        lo = 0
        hi = len(genelist) - 1

        while hi > lo + 1:
            i = (hi + lo) // 2
            if r < genelist[i].prob:
                hi = i
            else:
                lo = i

        return genelist[hi].char

    def _make_random_fasta(self, id_str: str, desc: str, genelist: List[Gene], n: int):
        self.result_buffer.write(f'>{id_str} {desc}\n')

        todo = n

        while todo > 0:
            m = min(todo, self.LINE_LENGTH)
            line = []

            for _ in range(m):
                line.append(self._select_random(genelist))

            self.result_buffer.write(''.join(line))
            self.result_buffer.write('\n')
            todo -= self.LINE_LENGTH

    def _make_repeat_fasta(self, id_str: str, desc: str, s: str, n: int):
        self.result_buffer.write(f'>{id_str} {desc}\n')

        todo = n
        k = 0
        kn = len(s)

        while todo > 0:
            m = min(todo, self.LINE_LENGTH)
            remaining = m

            while remaining >= kn - k:
                self.result_buffer.write(s[k:])
                remaining -= kn - k
                k = 0

            if remaining > 0:
                self.result_buffer.write(s[k:k + remaining])
                k += remaining

            self.result_buffer.write('\n')
            todo -= self.LINE_LENGTH

    def prepare(self):
        self.result_buffer = StringIO()

    def run_benchmark(self, iteration_id: int):
        self._make_repeat_fasta("ONE", "Homo sapiens alu", self.ALU, self.n * 2)
        self._make_random_fasta("TWO", "IUB ambiguity codes", self.IUB, self.n * 3)
        self._make_random_fasta("THREE", "Homo sapiens frequency", self.HOMO, self.n * 5)

    def get_result(self) -> str:
        return self.result_buffer.getvalue()

    def checksum(self) -> int:
        return Helper.checksum_string(self.result_buffer.getvalue())

class Knuckeotide(Benchmark):
    def __init__(self):
        super().__init__()
        self._seq = ""
        self._result_str = ""

    def _frequency(self, seq: str, length: int) -> Dict[str, int]:
        n = len(seq) - length + 1
        table = {}

        for i in range(n):
            key = seq[i:i + length]
            table[key] = table.get(key, 0) + 1

        return table

    def _sort_by_freq(self, seq: str, length: int):
        table = self._frequency(seq, length)
        n = len(seq) - length + 1

        sorted_items = sorted(table.items(), key=lambda x: x[1], reverse=True)

        for key, value in sorted_items:
            freq = (value * 100) / n
            self._result_str += f"{key.upper()} {freq:.3f}\n"

        self._result_str += '\n'

    def _find_seq(self, seq: str, s: str):
        table = self._frequency(seq, len(s))
        count = table.get(s.lower(), 0)
        self._result_str += f"{count}\t{s.upper()}\n"

    def prepare(self):
        class_name = self.__class__.__name__
        n = Helper.config_i64(class_name, "n")

        fasta = Fasta()
        fasta.set_iterations(n)
        fasta.prepare()
        fasta.run_benchmark(0)

        fasta_output = fasta.get_result()

        seq = ""
        after_three = False

        for line in fasta_output.split('\n'):
            if line.startswith('>THREE'):
                after_three = True
                continue

            if after_three:
                if line.startswith('>'):
                    break
                seq += line.strip()

        self._seq = seq

    def run_benchmark(self, iteration_id: int):
        for i in range(1, 3):
            self._sort_by_freq(self._seq, i)

        sequences = ['ggt', 'ggta', 'ggtatt', 'ggtattttaatt', 'ggtattttaatttatagt']
        for s in sequences:
            self._find_seq(self._seq, s)

    def checksum(self) -> int:
        return Helper.checksum_string(self._result_str)

class Mandelbrot(Benchmark):
    ITER = 50
    LIMIT = 2.0

    def __init__(self):
        super().__init__()
        self.w = 0
        self.h = 0
        self._result_bytes = []

    def prepare(self):
        class_name = self.__class__.__name__
        self.w = Helper.config_i64(class_name, "w")
        self.h = Helper.config_i64(class_name, "h")
        self._result_bytes = []  

    def run_benchmark(self, iteration_id: int):

        header = f'P4\n{self.w} {self.h}\n'
        self._result_bytes.extend(header.encode('ascii'))

        bit_num = 0
        byte_acc = 0

        for y in range(self.h):
            for x in range(self.w):
                zr = 0.0
                zi = 0.0
                tr = 0.0
                ti = 0.0

                cr = (2.0 * x / self.w - 1.5)
                ci = (2.0 * y / self.h - 1.0)

                i = 0
                while i < self.ITER and (tr + ti) <= self.LIMIT * self.LIMIT:
                    zi = 2.0 * zr * zi + ci
                    zr = tr - ti + cr
                    tr = zr * zr
                    ti = zi * zi
                    i += 1

                byte_acc <<= 1
                if tr + ti <= self.LIMIT * self.LIMIT:
                    byte_acc |= 0x01
                bit_num += 1

                if bit_num == 8:
                    self._result_bytes.append(byte_acc)
                    byte_acc = 0
                    bit_num = 0
                elif x == self.w - 1:
                    byte_acc <<= (8 - (self.w % 8))
                    self._result_bytes.append(byte_acc)
                    byte_acc = 0
                    bit_num = 0

    def checksum(self) -> int:
        return Helper.checksum_bytes(self._result_bytes)

class MatmulBase(Benchmark):
    def __init__(self):
        super().__init__()
        self.n = 0
        self._result_value = 0  

    def prepare(self):
        class_name = self.__class__.__name__
        self.n = Helper.config_i64(class_name, "n")

    def _matgen(self, n: int) -> List[List[float]]:
        tmp = 1.0 / n / n
        a = [[0.0] * n for _ in range(n)]
        for i in range(n):
            for j in range(n):
                a[i][j] = tmp * (i - j) * (i + j)
        return a

    def _matmul_sync(self, a: List[List[float]], b: List[List[float]]) -> List[List[float]]:
        size = len(a)
        bT = [[0.0] * size for _ in range(size)]
        for i in range(size):
            for j in range(size):
                bT[j][i] = b[i][j]

        c = [[0.0] * size for _ in range(size)]
        for i in range(size):
            ai = a[i]
            ci = c[i]
            for j in range(size):
                bTj = bT[j]
                sum_val = 0.0
                for k in range(size):
                    sum_val += ai[k] * bTj[k]
                ci[j] = sum_val
        return c

    def checksum(self) -> int:

        return self._result_value & 0xFFFFFFFF

class Matmul1T(MatmulBase):
    def run_benchmark(self, iteration_id: int) -> None:
        a = self._matgen(self.n)
        b = self._matgen(self.n)
        c = self._matmul_sync(a, b)
        value = c[self.n >> 1][self.n >> 1]

        self._result_value = (self._result_value + Helper.checksum_float(value)) & 0xFFFFFFFF

class MatmulParallelBase(MatmulBase):
    def __init__(self, num_threads: int = 4):
        super().__init__()
        self.num_threads = num_threads

    def _matmul_worker(self, args) -> tuple:
        start_i, end_i, a, bT, size = args
        local_c = [[0.0] * size for _ in range(end_i - start_i)]

        for local_i, i in enumerate(range(start_i, end_i)):
            ai = a[i]
            ci = local_c[local_i]
            for j in range(size):
                bTj = bT[j]
                sum_val = 0.0
                for k in range(size):
                    sum_val += ai[k] * bTj[k]
                ci[j] = sum_val
        return start_i, local_c

    def run_benchmark(self, iteration_id: int) -> None:
        a = self._matgen(self.n)
        b = self._matgen(self.n)
        size = self.n

        bT = [[0.0] * size for _ in range(size)]
        for i in range(size):
            for j in range(size):
                bT[j][i] = b[i][j]

        rows_per_thread = (size + self.num_threads - 1) // self.num_threads
        futures = []

        with concurrent.futures.ThreadPoolExecutor(max_workers=self.num_threads) as executor:
            for t in range(self.num_threads):
                start_i = t * rows_per_thread
                end_i = min(start_i + rows_per_thread, size)
                if start_i >= size:
                    break
                args = (start_i, end_i, a, bT, size)
                futures.append(executor.submit(self._matmul_worker, args))

            c = [[0.0] * size for _ in range(size)]
            for future in concurrent.futures.as_completed(futures):
                start_i, local_c = future.result()
                for local_i, row in enumerate(local_c):
                    c[start_i + local_i] = row

        value = c[self.n >> 1][self.n >> 1]

        self._result_value = (self._result_value + Helper.checksum_float(value)) & 0xFFFFFFFF

class Matmul4T(MatmulParallelBase):
    def __init__(self):
        super().__init__(num_threads=4)

class Matmul8T(MatmulParallelBase):
    def __init__(self):
        super().__init__(num_threads=8)

class Matmul16T(MatmulParallelBase):
    def __init__(self):
        super().__init__(num_threads=16)

class Planet:
    SOLAR_MASS = 4 * math.pi * math.pi
    DAYS_PER_YEAR = 365.24

    def __init__(self, x, y, z, vx, vy, vz, mass):
        self.x = x
        self.y = y
        self.z = z
        self.vx = vx * self.DAYS_PER_YEAR
        self.vy = vy * self.DAYS_PER_YEAR
        self.vz = vz * self.DAYS_PER_YEAR
        self.mass = mass * self.SOLAR_MASS

    def move_from_i(self, bodies, dt, i):

        nbodies = len(bodies)

        while i < nbodies:
            b2 = bodies[i]
            dx = self.x - b2.x
            dy = self.y - b2.y
            dz = self.z - b2.z

            distance = math.sqrt(dx*dx + dy*dy + dz*dz)
            mag = dt / (distance * distance * distance)
            b_mass_mag = self.mass * mag
            b2_mass_mag = b2.mass * mag

            self.vx -= dx * b2_mass_mag
            self.vy -= dy * b2_mass_mag
            self.vz -= dz * b2_mass_mag
            b2.vx += dx * b_mass_mag
            b2.vy += dy * b_mass_mag
            b2.vz += dz * b_mass_mag
            i += 1

        self.x += dt * self.vx
        self.y += dt * self.vy
        self.z += dt * self.vz

class Nbody(Benchmark):
    SOLAR_MASS = Planet.SOLAR_MASS
    DAYS_PER_YEAR = Planet.DAYS_PER_YEAR

    _INITIAL_BODIES = [
        Planet(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0),
        Planet(
            4.84143144246472090e+00,
            -1.16032004402742839e+00,
            -1.03622044471123109e-01,
            1.66007664274403694e-03,
            7.69901118419740425e-03,
            -6.90460016972063023e-05,
            9.54791938424326609e-04,
        ),
        Planet(
            8.34336671824457987e+00,
            4.12479856412430479e+00,
            -4.03523417114321381e-01,
            -2.76742510726862411e-03,
            4.99852801234917238e-03,
            2.30417297573763929e-05,
            2.85885980666130812e-04,
        ),
        Planet(
            1.28943695621391310e+01,
            -1.51111514016986312e+01,
            -2.23307578892655734e-01,
            2.96460137564761618e-03,
            2.37847173959480950e-03,
            -2.96589568540237556e-05,
            4.36624404335156298e-05,
        ),
        Planet(
            1.53796971148509165e+01,
            -2.59193146099879641e+01,
            1.79258772950371181e-01,
            2.68067772490389322e-03,
            1.62824170038242295e-03,
            -9.51592254519715870e-05,
            5.15138902046611451e-05,
        ),
    ]

    def __init__(self):
        super().__init__()
        self.bodies = []
        self._result_value = 0
        self._v1 = 0.0

    def prepare(self):
        class_name = self.__class__.__name__

        self.bodies = []
        for p in self._INITIAL_BODIES:
            new_planet = Planet(
                p.x, p.y, p.z,
                p.vx / self.DAYS_PER_YEAR,
                p.vy / self.DAYS_PER_YEAR,
                p.vz / self.DAYS_PER_YEAR,
                p.mass / self.SOLAR_MASS
            )
            self.bodies.append(new_planet)

        self._offset_momentum()
        self._v1 = self._energy()

    def _energy(self):

        e = 0.0
        nbodies = len(self.bodies)

        for i in range(nbodies):
            b = self.bodies[i]
            e += 0.5 * b.mass * (b.vx*b.vx + b.vy*b.vy + b.vz*b.vz)

            for j in range(i + 1, nbodies):
                b2 = self.bodies[j]
                dx = b.x - b2.x
                dy = b.y - b2.y
                dz = b.z - b2.z
                distance = math.sqrt(dx*dx + dy*dy + dz*dz)
                e -= (b.mass * b2.mass) / distance

        return e

    def _offset_momentum(self):

        px = py = pz = 0.0

        for b in self.bodies:
            m = b.mass
            px += b.vx * m
            py += b.vy * m
            pz += b.vz * m

        b = self.bodies[0]
        b.vx = -px / self.SOLAR_MASS
        b.vy = -py / self.SOLAR_MASS
        b.vz = -pz / self.SOLAR_MASS

    def run_benchmark(self, iteration_id: int):
        nbodies = len(self.bodies)
        dt = 0.01

        for i in range(nbodies):
            b = self.bodies[i]
            b.move_from_i(self.bodies, dt, i + 1)

    def checksum(self) -> int:
        v2 = self._energy()
        checksum1 = Helper.checksum_float(self._v1)
        checksum2 = Helper.checksum_float(v2)

        return ((checksum1 << 5) & checksum2) & 0xFFFFFFFF

class RegexDna(Benchmark):
    def __init__(self):
        super().__init__()
        self.seq = ""
        self.ilen = 0
        self.clen = 0
        self.result_str = ""
        self.n = 0

    def prepare(self):
        class_name = self.__class__.__name__
        self.n = Helper.config_i64(class_name, "n")

        fasta = Fasta()
        fasta.set_iterations(self.n)
        fasta.prepare()
        fasta.run_benchmark(0)

        fasta_output = fasta.get_result()

        buffer = []
        lines = fasta_output.split('\n')
        for line in lines:
            if line and not line.startswith('>'):
                buffer.append(line.strip())

        self.seq = ''.join(buffer)
        self.ilen = len(fasta_output.encode('utf-8'))
        self.clen = len(self.seq.encode('utf-8'))

    def run_benchmark(self, iteration_id: int):

        patterns = [
            r'agggtaaa|tttaccct',
            r'[cgt]gggtaaa|tttaccc[acg]',
            r'a[act]ggtaaa|tttacc[agt]t',
            r'ag[act]gtaaa|tttac[agt]ct',
            r'agg[act]taaa|ttta[agt]cct',
            r'aggg[acg]aaa|ttt[cgt]ccct',
            r'agggt[cgt]aa|tt[acg]accct',
            r'agggta[cgt]a|t[acg]taccct',
            r'agggtaa[cgt]|[acg]ttaccct',
        ]

        for pattern in patterns:
            matches = len(re.findall(pattern, self.seq, re.IGNORECASE))
            self.result_str += f"{pattern} {matches}\n"

        replacements = {
            'B': '(c|g|t)',
            'D': '(a|g|t)',
            'H': '(a|c|t)',
            'K': '(g|t)',
            'M': '(a|c)',
            'N': '(a|c|g|t)',
            'R': '(a|g)',
            'S': '(c|t)',
            'V': '(a|c|g)',
            'W': '(a|t)',
            'Y': '(c|t)',
        }

        modified_seq = self.seq
        for key, value in replacements.items():
            modified_seq = re.sub(key, value, modified_seq, flags=re.IGNORECASE)

        modified_len = len(modified_seq.encode('utf-8'))
        self.result_str += f"\n{self.ilen}\n{self.clen}\n{modified_len}\n"

    def checksum(self) -> int:
        return Helper.checksum_string(self.result_str)

class Revcomp(Benchmark):
    FROM = "wsatugcyrkmbdhvnATUGCYRKMBDHVN"
    TO   = "WSTAACGRYMKVHDBNTAACGRYMKVHDBN"

    def __init__(self):
        super().__init__()
        self.input = ""
        self.result_value = 0
        self._lookup_table = None

    def _init_lookup_table(self):

        if self._lookup_table:
            return self._lookup_table

        lookup = [i for i in range(256)]

        for i in range(len(self.FROM)):
            from_char = ord(self.FROM[i])
            to_char = ord(self.TO[i])
            lookup[from_char] = to_char

        self._lookup_table = lookup
        return lookup

    def prepare(self):
        class_name = self.__class__.__name__
        n = Helper.config_i64(class_name, "n")

        fasta = Fasta()
        fasta.n = n
        fasta.prepare()
        fasta.run_benchmark(0)

        fasta_output = fasta.get_result()

        lines = fasta_output.split('\n')
        seq_parts = []

        for line in lines:
            if line.startswith('>'):
                seq_parts.append("\n---\n")
            elif line.strip():
                seq_parts.append(line.strip())

        self.input = ''.join(seq_parts)

    def _revcomp_go_style(self, seq: str) -> str:

        length = len(seq)
        lookup = self._init_lookup_table()

        line_length = 60
        num_lines = (length + line_length - 1) // line_length

        result_chars = []
        read_pos = length - 1

        for line in range(num_lines):
            chars_in_line = min(line_length, read_pos + 1)

            for i in range(chars_in_line):
                char_code = ord(seq[read_pos])
                read_pos -= 1
                result_chars.append(chr(lookup[char_code]))

            result_chars.append('\n')  

        return ''.join(result_chars)

    def run_benchmark(self, iteration_id: int):
        v = Helper.checksum_string(self._revcomp_go_style(self.input))
        self.result_value = (self.result_value + v) & 0xFFFFFFFF

    def checksum(self) -> int:
        return self.result_value & 0xFFFFFFFF

class Spectralnorm(Benchmark):
    def __init__(self):
        super().__init__()
        self.size = 0
        self.u = []
        self.v = []

    def prepare(self):
        class_name = self.__class__.__name__
        self.size = Helper.config_i64(class_name, "size")
        self.u = [1.0] * self.size
        self.v = [1.0] * self.size

    def _eval_a(self, i: int, j: int) -> float:
        return 1.0 / (((i + j) * (i + j + 1)) // 2 + i + 1)

    def _eval_a_times_u(self, u_vec):
        n = len(u_vec)
        result = [0.0] * n

        for i in range(n):
            total = 0.0
            for j in range(n):
                total += self._eval_a(i, j) * u_vec[j]
            result[i] = total

        return result

    def _eval_at_times_u(self, u_vec):
        n = len(u_vec)
        result = [0.0] * n

        for i in range(n):
            total = 0.0
            for j in range(n):
                total += self._eval_a(j, i) * u_vec[j]
            result[i] = total

        return result

    def _eval_at_a_times_u(self, u_vec):
        return self._eval_at_times_u(self._eval_a_times_u(u_vec))

    def run_benchmark(self, iteration_id: int):
        self.v = self._eval_at_a_times_u(self.u)
        self.u = self._eval_at_a_times_u(self.v)

    def checksum(self) -> int:
        v_bv = 0.0
        vv = 0.0

        for i in range(self.size):
            v_bv += self.u[i] * self.v[i]
            vv += self.v[i] * self.v[i]

        result = math.sqrt(v_bv / vv)
        return Helper.checksum_float(result)

class Base64Encode(Benchmark):
    def __init__(self):
        super().__init__()
        self.n = 0
        self._str = ""
        self._bytes = b""
        self._str2 = ""
        self._result_value = 0

    def prepare(self):
        class_name = self.__class__.__name__
        self.n = Helper.config_i64(class_name, "size")

        self._str = 'a' * self.n
        self._bytes = b'a' * self.n
        self._str2 = base64.b64encode(self._bytes).decode('ascii')

    def run_benchmark(self, iteration_id: int):
        encoded = base64.b64encode(self._bytes).decode('ascii')
        self._str2 = encoded
        self._result_value = (self._result_value + len(encoded)) & 0xFFFFFFFF

    def checksum(self) -> int:
        output = f"encode {self._str[:min(4, len(self._str))]}... "
        output += f"to {self._str2[:min(4, len(self._str2))]}...: {self._result_value}"
        return Helper.checksum_string(output)

class Base64Decode(Benchmark):
    def __init__(self):
        super().__init__()
        self.n = 0
        self._str2 = ""
        self._bytes = b""
        self._result_value = 0

    def prepare(self):
        class_name = self.__class__.__name__
        self.n = Helper.config_i64(class_name, "size")

        self._bytes = b'a' * self.n
        self._str2 = base64.b64encode(self._bytes).decode('ascii')
        self._bytes = base64.b64decode(self._str2)

    def run_benchmark(self, iteration_id: int):
        decoded = base64.b64decode(self._str2)
        self._bytes = decoded
        self._result_value = (self._result_value + len(decoded)) & 0xFFFFFFFF

    def checksum(self) -> int:
        str3 = self._bytes.decode('ascii', errors='ignore')
        output = f"decode {self._str2[:min(4, len(self._str2))]}... "
        output += f"to {str3[:min(4, len(str3))]}...: {self._result_value}"
        return Helper.checksum_string(output)

class JsonGenerate(Benchmark):
    def __init__(self):
        super().__init__()
        class_name = self.__class__.__name__
        self.n = Helper.config_i64(class_name, "coords")
        self.data = []
        self.text = ''
        self.result = 0

    def prepare(self):
        self.data = []

        for i in range(self.n):
            self.data.append({
                'x': round(Helper.next_float(), 8),
                'y': round(Helper.next_float(), 8),
                'z': round(Helper.next_float(), 8),
                'name': f"{Helper.next_float():.7f} {Helper.next_int(10000)}",
                'opts': {
                    '1': [1, True],
                },
            })

    def run_benchmark(self, iteration_id: int):
        json_data = {
            'coordinates': self.data,
            'info': 'some info',
        }

        self.text = json.dumps(json_data)

        if self.text.startswith('{"coordinates":'):
            self.result += 1

    def get_text(self) -> str:
        return self.text

    def checksum(self) -> int:
        return self.result & 0xFFFFFFFF

class JsonParseDom(Benchmark):
    def __init__(self):
        super().__init__()
        self.text = ''
        self.result_value = 0

    def prepare(self):
        json_gen = JsonGenerate()
        class_name = self.__class__.__name__
        json_gen.n = Helper.config_i64(class_name, "coords")
        json_gen.prepare()
        json_gen.run_benchmark(0)
        self.text = json_gen.get_text()

    def _calc(self, text: str):

        json_obj = json.loads(text)
        coordinates = json_obj['coordinates']
        length = len(coordinates)

        x = y = z = 0.0

        for coord in coordinates:
            x += coord['x']
            y += coord['y']
            z += coord['z']

        return x / length, y / length, z / length

    def run_benchmark(self, iteration_id: int):
        x, y, z = self._calc(self.text)

        self.result_value = (self.result_value + Helper.checksum_float(x)) & 0xFFFFFFFF
        self.result_value = (self.result_value + Helper.checksum_float(y)) & 0xFFFFFFFF
        self.result_value = (self.result_value + Helper.checksum_float(z)) & 0xFFFFFFFF

    def checksum(self) -> int:
        return self.result_value & 0xFFFFFFFF

class CoordinateResult(NamedTuple):
    x: float
    y: float
    z: float

class JsonParseMapping(Benchmark):
    def __init__(self):
        super().__init__()
        self.text = ''
        self.result_value = 0

    def prepare(self):
        json_gen = JsonGenerate()
        class_name = self.__class__.__name__
        json_gen.n = Helper.config_i64(class_name, "coords")
        json_gen.prepare()
        json_gen.run_benchmark(0)
        self.text = json_gen.get_text()

    def _calc(self, text: str) -> CoordinateResult:

        json_obj = json.loads(text)
        coordinates = json_obj['coordinates']
        length = len(coordinates)

        x = y = z = 0.0

        for coord in coordinates:
            x += coord['x']
            y += coord['y']
            z += coord['z']

        return CoordinateResult(x / length, y / length, z / length)

    def run_benchmark(self, iteration_id: int):
        coord = self._calc(self.text)

        self.result_value = (self.result_value + Helper.checksum_float(coord.x)) & 0xFFFFFFFF
        self.result_value = (self.result_value + Helper.checksum_float(coord.y)) & 0xFFFFFFFF
        self.result_value = (self.result_value + Helper.checksum_float(coord.z)) & 0xFFFFFFFF

    def checksum(self) -> int:
        return self.result_value & 0xFFFFFFFF

class PrimesNode:

    def __init__(self):
        self.children: List[Optional['PrimesNode']] = [None] * 10
        self.terminal: bool = False

    def __getitem__(self, digit: int) -> Optional['PrimesNode']:
        return self.children[digit]

    def __setitem__(self, digit: int, node: 'PrimesNode'):
        self.children[digit] = node

class Sieve:

    def __init__(self, limit: int):
        self.limit = limit
        self.prime = [True] * (limit + 1)
        if limit >= 1:
            self.prime[0] = self.prime[1] = False

    def calculate(self) -> 'Sieve':

        sqrt_limit = int(math.sqrt(self.limit))

        for p in range(2, sqrt_limit + 1):
            if self.prime[p]:
                start = p * p
                for multiple in range(start, self.limit + 1, p):
                    self.prime[multiple] = False
        return self

    def to_list(self) -> List[int]:

        if self.limit < 2:
            return []

        try:
            capacity = int(self.limit / math.log(self.limit))
        except:
            capacity = self.limit // 10

        result: List[int] = []

        if self.limit >= 2:
            result.append(2)

        for p in range(3, self.limit + 1, 2):
            if self.prime[p]:
                result.append(p)

        return result

class Primes(Benchmark):
    def __init__(self):
        super().__init__()
        self.n = 0
        self.prefix = 0
        self.result = 5432

    def prepare(self):
        class_name = self.__class__.__name__
        self.n = Helper.config_i64(class_name, "limit")
        self.prefix = Helper.config_i64(class_name, "prefix")

    def _generate_trie(self, primes: List[int]) -> PrimesNode:

        root = PrimesNode()

        for prime in primes:
            node = root
            temp = prime
            digits: List[int] = []

            while temp > 0:
                digits.append(temp % 10)
                temp //= 10
            digits.reverse()

            for digit in digits:
                child = node[digit]
                if child is None:
                    child = PrimesNode()
                    node[digit] = child
                node = child

            node.terminal = True

        return root

    def _find_primes_with_prefix(self, trie: PrimesNode, prefix: int) -> List[int]:

        node = trie
        prefix_value = 0
        temp_prefix = prefix
        prefix_digits: List[int] = []

        while temp_prefix > 0:
            prefix_digits.append(temp_prefix % 10)
            temp_prefix //= 10
        prefix_digits.reverse()

        for digit in prefix_digits:
            prefix_value = prefix_value * 10 + digit
            child = node[digit]
            if child is None:
                return []
            node = child

        results: List[int] = []
        queue: List[Tuple[PrimesNode, int]] = [(node, prefix_value)]

        while queue:
            current_node, current_number = queue.pop(0)

            if current_node.terminal:
                results.append(current_number)

            for digit in range(10):
                child = current_node[digit]
                if child:
                    queue.append((child, current_number * 10 + digit))

        results.sort()
        return results

    def run_benchmark(self, iteration_id: int):

        primes = Sieve(self.n).calculate().to_list()

        trie = self._generate_trie(primes)

        results = self._find_primes_with_prefix(trie, self.prefix)

        self.result = (self.result + len(results)) & 0xFFFFFFFF
        for prime in results:
            self.result = (self.result + prime) & 0xFFFFFFFF

    def checksum(self) -> int:
        return self.result & 0xFFFFFFFF

@dataclass
class Vec2:
    x: float
    y: float

class Noise2DContext:

    def __init__(self, size: int):
        self.size = size

        self.rgradients = [self._random_gradient() for _ in range(size)]

        self.permutations = list(range(size))
        for _ in range(size):
            a = Helper.next_int(size)
            b = Helper.next_int(size)
            self.permutations[a], self.permutations[b] = self.permutations[b], self.permutations[a]

    @staticmethod
    def _random_gradient() -> Vec2:

        v = Helper.next_float() * math.pi * 2.0
        return Vec2(math.cos(v), math.sin(v))

    def get_gradient(self, x: int, y: int) -> Vec2:

        idx = (self.permutations[x & (self.size - 1)] + 
               self.permutations[y & (self.size - 1)])
        return self.rgradients[idx & (self.size - 1)]

    def get_gradients(self, x: float, y: float):

        x0f = math.floor(x)
        y0f = math.floor(y)
        x0 = int(x0f)
        y0 = int(y0f)
        x1 = x0 + 1
        y1 = y0 + 1

        gradients = (
            self.get_gradient(x0, y0),
            self.get_gradient(x1, y0),
            self.get_gradient(x0, y1),
            self.get_gradient(x1, y1),
        )

        origins = (
            Vec2(x0f + 0.0, y0f + 0.0),
            Vec2(x0f + 1.0, y0f + 0.0),
            Vec2(x0f + 0.0, y0f + 1.0),
            Vec2(x0f + 1.0, y0f + 1.0),
        )

        return gradients, origins

    @staticmethod
    def _smooth(v: float) -> float:

        return v * v * (3.0 - 2.0 * v)

    @staticmethod
    def _lerp(a: float, b: float, v: float) -> float:

        return a * (1.0 - v) + b * v

    @staticmethod
    def _gradient(orig: Vec2, grad: Vec2, p: Vec2) -> float:

        sp = Vec2(p.x - orig.x, p.y - orig.y)
        return grad.x * sp.x + grad.y * sp.y

    def get(self, x: float, y: float) -> float:

        p = Vec2(x, y)
        gradients, origins = self.get_gradients(x, y)

        v0 = self._gradient(origins[0], gradients[0], p)
        v1 = self._gradient(origins[1], gradients[1], p)
        v2 = self._gradient(origins[2], gradients[2], p)
        v3 = self._gradient(origins[3], gradients[3], p)

        fx = self._smooth(x - origins[0].x)
        vx0 = self._lerp(v0, v1, fx)
        vx1 = self._lerp(v2, v3, fx)

        fy = self._smooth(y - origins[0].y)
        return self._lerp(vx0, vx1, fy)

class Noise(Benchmark):
    SYM = [' ', '░', '▒', '▓', '█', '█']

    def __init__(self):
        super().__init__()
        self.size = 0
        self.result = 0
        self.n2d: Optional[Noise2DContext] = None

    def prepare(self):
        class_name = self.__class__.__name__
        self.size = Helper.config_i64(class_name, "size")
        self.n2d = Noise2DContext(self.size)

    def run_benchmark(self, iteration_id: int):
        for y in range(self.size):
            for x in range(self.size):
                v = self.n2d.get(x * 0.1, (y + (iteration_id * 128)) * 0.1) * 0.5 + 0.5
                idx = int(v / 0.2)
                self.result = (self.result + ord(self.SYM[idx])) & 0xFFFFFFFF

    def checksum(self) -> int:
        return self.result & 0xFFFFFFFF

@dataclass
class Vector:
    x: float
    y: float
    z: float

    def scale(self, s: float) -> 'Vector':
        return Vector(self.x * s, self.y * s, self.z * s)

    def __add__(self, other: 'Vector') -> 'Vector':
        return Vector(self.x + other.x, self.y + other.y, self.z + other.z)

    def __sub__(self, other: 'Vector') -> 'Vector':
        return Vector(self.x - other.x, self.y - other.y, self.z - other.z)

    def dot(self, other: 'Vector') -> float:
        return self.x * other.x + self.y * other.y + self.z * other.z

    def magnitude(self) -> float:
        return math.sqrt(self.dot(self))

    def normalize(self) -> 'Vector':
        return self.scale(1.0 / self.magnitude())

@dataclass
class Ray:
    orig: Vector
    dir: Vector

@dataclass
class Color:
    r: float
    g: float
    b: float

    def scale(self, s: float) -> 'Color':
        return Color(self.r * s, self.g * s, self.b * s)

    def __add__(self, other: 'Color') -> 'Color':
        return Color(self.r + other.r, self.g + other.g, self.b + other.b)

@dataclass
class Sphere:
    center: Vector
    radius: float
    color: Color

    def get_normal(self, pt: Vector) -> Vector:
        return (pt - self.center).normalize()

@dataclass
class Light:
    position: Vector
    color: Color

@dataclass
class Hit:
    obj: Sphere
    value: float

class TextRaytracer(Benchmark):
    WHITE = Color(1.0, 1.0, 1.0)
    RED = Color(1.0, 0.0, 0.0)
    GREEN = Color(0.0, 1.0, 0.0)
    BLUE = Color(0.0, 0.0, 1.0)

    LIGHT1 = Light(Vector(0.7, -1.0, 1.7), WHITE)
    LUT = ['.', '-', '+', '*', 'X', 'M']

    SCENE = [
        Sphere(Vector(-1.0, 0.0, 3.0), 0.3, RED),
        Sphere(Vector(0.0, 0.0, 3.0), 0.8, GREEN),
        Sphere(Vector(1.0, 0.0, 3.0), 0.4, BLUE),
    ]

    def __init__(self):
        super().__init__()
        self.w = 0
        self.h = 0
        self.res = 0

    def prepare(self):
        class_name = self.__class__.__name__
        self.w = Helper.config_i64(class_name, "w")
        self.h = Helper.config_i64(class_name, "h")

    def intersect_sphere(self, ray: Ray, center: Vector, radius: float) -> Optional[float]:

        l = center - ray.orig
        tca = l.dot(ray.dir)
        if tca < 0.0:
            return None

        d2 = l.dot(l) - tca * tca
        r2 = radius * radius
        if d2 > r2:
            return None

        thc = math.sqrt(r2 - d2)
        t0 = tca - thc

        if t0 > 10000:
            return None

        return t0

    def _clamp(self, x: float, a: float, b: float) -> float:

        if x < a:
            return a
        if x > b:
            return b
        return x

    def diffuse_shading(self, pi: Vector, obj: Sphere, light: Light) -> Color:

        n = obj.get_normal(pi)
        lam1 = (light.position - pi).normalize().dot(n)
        lam2 = self._clamp(lam1, 0.0, 1.0)
        return light.color.scale(lam2 * 0.5) + obj.color.scale(0.3)

    def shade_pixel(self, ray: Ray, obj: Sphere, tval: float) -> int:

        pi = ray.orig + ray.dir.scale(tval)
        color = self.diffuse_shading(pi, obj, self.LIGHT1)
        col = (color.r + color.g + color.b) / 3.0
        return int(col * 6.0)

    def run_benchmark(self, iteration_id: int):
        res = 0

        for j in range(self.h):
            for i in range(self.w):
                fw, fi, fj, fh = float(self.w), float(i), float(j), float(self.h)

                ray = Ray(
                    Vector(0.0, 0.0, 0.0),
                    Vector((fi - fw/2.0)/fw, (fj - fh/2.0)/fh, 1.0).normalize()
                )

                hit = None

                for obj in self.SCENE:
                    t = self.intersect_sphere(ray, obj.center, obj.radius)
                    if t is not None:
                        hit = Hit(obj, t)
                        break

                if hit:
                    pixel_idx = self.shade_pixel(ray, hit.obj, hit.value)
                    pixel = self.LUT[pixel_idx]
                else:
                    pixel = ' '

                res = (res + ord(pixel)) & 0xFFFFFFFF

        self.res = (self.res + res) & 0xFFFFFFFF

    def checksum(self) -> int:
        return self.res & 0xFFFFFFFF

class Synapse:

    def __init__(self, source_neuron: 'Neuron', dest_neuron: 'Neuron'):
        self.source_neuron = source_neuron
        self.dest_neuron = dest_neuron
        self.weight = Helper.next_float() * 2 - 1
        self.prev_weight = self.weight

class Neuron:
    LEARNING_RATE = 1.0
    MOMENTUM = 0.3

    def __init__(self):
        self.threshold = Helper.next_float() * 2 - 1
        self.prev_threshold = self.threshold
        self.synapses_in: List[Synapse] = []
        self.synapses_out: List[Synapse] = []
        self.output = 0.0
        self.error = 0.0

    def calculate_output(self):

        activation = sum(synapse.weight * synapse.source_neuron.output 
                        for synapse in self.synapses_in)
        activation -= self.threshold
        self.output = 1.0 / (1.0 + math.exp(-activation))

    def derivative(self) -> float:

        return self.output * (1.0 - self.output)

    def output_train(self, rate: float, target: float):

        self.error = (target - self.output) * self.derivative()
        self._update_weights(rate)

    def hidden_train(self, rate: float):

        error_sum = sum(synapse.dest_neuron.error * synapse.prev_weight 
                       for synapse in self.synapses_out)
        self.error = error_sum * self.derivative()
        self._update_weights(rate)

    def _update_weights(self, rate: float):

        for synapse in self.synapses_in:
            temp_weight = synapse.weight
            synapse.weight += (rate * self.LEARNING_RATE * self.error * 
                             synapse.source_neuron.output) + \
                            (self.MOMENTUM * (synapse.weight - synapse.prev_weight))
            synapse.prev_weight = temp_weight

        temp_threshold = self.threshold
        self.threshold += (rate * self.LEARNING_RATE * self.error * -1.0) + \
                         (self.MOMENTUM * (self.threshold - self.prev_threshold))
        self.prev_threshold = temp_threshold

class NeuralNetwork:

    def __init__(self, inputs: int, hidden: int, outputs: int):
        self.input_layer = [Neuron() for _ in range(inputs)]
        self.hidden_layer = [Neuron() for _ in range(hidden)]
        self.output_layer = [Neuron() for _ in range(outputs)]

        for source in self.input_layer:
            for dest in self.hidden_layer:
                synapse = Synapse(source, dest)
                source.synapses_out.append(synapse)
                dest.synapses_in.append(synapse)

        for source in self.hidden_layer:
            for dest in self.output_layer:
                synapse = Synapse(source, dest)
                source.synapses_out.append(synapse)
                dest.synapses_in.append(synapse)

    def train(self, inputs: List[float], targets: List[float]):

        self.feed_forward(inputs)

        for neuron, target in zip(self.output_layer, targets):
            neuron.output_train(0.3, target)

        for neuron in self.hidden_layer:
            neuron.hidden_train(0.3)

    def feed_forward(self, inputs: List[float]):

        for neuron, input_val in zip(self.input_layer, inputs):
            neuron.output = input_val

        for neuron in self.hidden_layer:
            neuron.calculate_output()

        for neuron in self.output_layer:
            neuron.calculate_output()

    def current_outputs(self) -> List[float]:

        return [neuron.output for neuron in self.output_layer]

class NeuralNet(Benchmark):
    def __init__(self):
        super().__init__()
        self.xor: Optional[NeuralNetwork] = None

    def prepare(self):

        self.xor = NeuralNetwork(2, 10, 1)

    def run_benchmark(self, iteration_id: int):

        self.xor.train([0.0, 0.0], [0.0])
        self.xor.train([1.0, 0.0], [1.0])
        self.xor.train([0.0, 1.0], [1.0])
        self.xor.train([1.0, 1.0], [0.0])

    def checksum(self) -> int:

        outputs: List[float] = []

        self.xor.feed_forward([0.0, 0.0])
        outputs.extend(self.xor.current_outputs())

        self.xor.feed_forward([0.0, 1.0])
        outputs.extend(self.xor.current_outputs())

        self.xor.feed_forward([1.0, 0.0])
        outputs.extend(self.xor.current_outputs())

        self.xor.feed_forward([1.0, 1.0])
        outputs.extend(self.xor.current_outputs())

        total = sum(outputs)
        return Helper.checksum_float(total)

class SortBenchmark(Benchmark, ABC):
    def __init__(self):
        super().__init__()
        self._data: List[int] = []
        self.size = 0
        self._result_value = 0

    def prepare(self):
        class_name = self.__class__.__name__
        self.size = Helper.config_i64(class_name, "size")

        self._data = []
        for i in range(self.size):
            self._data.append(Helper.next_int(1000000))

    @abstractmethod
    def test(self) -> List[int]:

        pass

    def run_benchmark(self, iteration_id: int):

        self._result_value = (self._result_value + 
                             self._data[Helper.next_int(self.size)]) & 0xFFFFFFFF

        t = self.test()
        self._result_value = (self._result_value + 
                             t[Helper.next_int(self.size)]) & 0xFFFFFFFF

    def checksum(self) -> int:
        return self._result_value

class SortQuick(SortBenchmark):
    def test(self) -> List[int]:
        arr = self._data.copy()
        self._quick_sort(arr, 0, len(arr) - 1)
        return arr

    def _quick_sort(self, arr: List[int], low: int, high: int):

        if low >= high:
            return

        pivot = arr[(low + high) // 2]
        i = low
        j = high

        while i <= j:
            while arr[i] < pivot:
                i += 1
            while arr[j] > pivot:
                j -= 1

            if i <= j:

                arr[i], arr[j] = arr[j], arr[i]
                i += 1
                j -= 1

        self._quick_sort(arr, low, j)
        self._quick_sort(arr, i, high)

class SortMerge(SortBenchmark):
    def test(self) -> List[int]:
        arr = self._data.copy()
        self._merge_sort_inplace(arr)
        return arr

    def _merge_sort_inplace(self, arr: List[int]):

        temp = [0] * len(arr)
        self._merge_sort_helper(arr, temp, 0, len(arr) - 1)

    def _merge_sort_helper(self, arr: List[int], temp: List[int], 
                          left: int, right: int):

        if left >= right:
            return

        mid = (left + right) // 2
        self._merge_sort_helper(arr, temp, left, mid)
        self._merge_sort_helper(arr, temp, mid + 1, right)
        self._merge(arr, temp, left, mid, right)

    def _merge(self, arr: List[int], temp: List[int], 
               left: int, mid: int, right: int):

        for i in range(left, right + 1):
            temp[i] = arr[i]

        i = left
        j = mid + 1
        k = left

        while i <= mid and j <= right:
            if temp[i] <= temp[j]:
                arr[k] = temp[i]
                i += 1
            else:
                arr[k] = temp[j]
                j += 1
            k += 1

        while i <= mid:
            arr[k] = temp[i]
            i += 1
            k += 1

class SortSelf(SortBenchmark):
    def test(self) -> List[int]:
        arr = self._data.copy()
        arr.sort()  
        return arr

class GraphPathGraph:
    def __init__(self, vertices: int, components: int = 10):
        self.vertices = vertices
        self.components = max(10, min(components, vertices // 10000))
        self._adj: List[List[int]] = [[] for _ in range(vertices)]

    def add_edge(self, u: int, v: int):

        self._adj[u].append(v)
        self._adj[v].append(u)

    def generate_random(self):

        component_size = self.vertices // self.components

        for c in range(self.components):
            start_idx = c * component_size
            end_idx = self.vertices if c == self.components - 1 else (c + 1) * component_size

            for i in range(start_idx + 1, end_idx):
                parent = start_idx + Helper.next_int(i - start_idx)
                self.add_edge(i, parent)

            for i in range(component_size * 2):
                u = start_idx + Helper.next_int(end_idx - start_idx)
                v = start_idx + Helper.next_int(end_idx - start_idx)
                if u != v:
                    self.add_edge(u, v)

    def get_adjacency(self) -> List[List[int]]:
        return self._adj

    def get_vertices(self) -> int:
        return self.vertices

class GraphPathBenchmark(Benchmark, ABC):
    def __init__(self):
        super().__init__()
        self._graph: Optional[GraphPathGraph] = None
        self._pairs: List[Tuple[int, int]] = []
        self._n_pairs = 0
        self._result_value = 0

    def prepare(self):
        class_name = self.__class__.__name__
        vertices = Helper.config_i64(class_name, "vertices")
        self._n_pairs = Helper.config_i64(class_name, "pairs")

        self._graph = GraphPathGraph(vertices, max(10, vertices // 10000))
        self._graph.generate_random()
        self._pairs = self._generate_pairs(self._n_pairs)

    def _generate_pairs(self, n: int) -> List[Tuple[int, int]]:

        pairs = []
        component_size = self._graph.get_vertices() // 10

        for i in range(n):
            if Helper.next_int(100) < 70:

                component = Helper.next_int(10)
                start = component * component_size + Helper.next_int(component_size)
                end = component * component_size + Helper.next_int(component_size)

                while end == start:
                    end = component * component_size + Helper.next_int(component_size)
                pairs.append((start, end))
            else:

                c1 = Helper.next_int(10)
                c2 = Helper.next_int(10)
                while c2 == c1:
                    c2 = Helper.next_int(10)
                start = c1 * component_size + Helper.next_int(component_size)
                end = c2 * component_size + Helper.next_int(component_size)
                pairs.append((start, end))

        return pairs

    def checksum(self) -> int:
        return self._result_value & 0xFFFFFFFF

class GraphPathBFS(GraphPathBenchmark):
    def run_benchmark(self, iteration_id: int):
        for start, end in self._pairs:
            length = self._bfs_shortest_path(start, end)
            self._result_value = (self._result_value + length) & 0xFFFFFFFF

    def _bfs_shortest_path(self, start: int, target: int) -> int:

        if start == target:
            return 0

        visited = [0] * self._graph.get_vertices()
        queue = collections.deque()
        queue.append((start, 0))
        visited[start] = 1

        while queue:
            v, dist = queue.popleft()

            for neighbor in self._graph.get_adjacency()[v]:
                if neighbor == target:
                    return dist + 1

                if visited[neighbor] == 0:
                    visited[neighbor] = 1
                    queue.append((neighbor, dist + 1))

        return -1

class GraphPathDFS(GraphPathBenchmark):
    def run_benchmark(self, iteration_id: int):
        for start, end in self._pairs:
            length = self._dfs_find_path(start, end)
            self._result_value = (self._result_value + length) & 0xFFFFFFFF

    def _dfs_find_path(self, start: int, target: int) -> int:

        if start == target:
            return 0

        visited = [0] * self._graph.get_vertices()
        stack = [(start, 0)]
        best_path = 0x7FFFFFFFFFFFFFFF  

        while stack:
            v, dist = stack.pop()

            if visited[v] == 1 or dist >= best_path:
                continue

            visited[v] = 1

            for neighbor in self._graph.get_adjacency()[v]:
                if neighbor == target:
                    if dist + 1 < best_path:
                        best_path = dist + 1
                elif visited[neighbor] == 0:
                    stack.append((neighbor, dist + 1))

        return -1 if best_path == 0x7FFFFFFFFFFFFFFF else best_path

class GraphPathDijkstra(GraphPathBenchmark):
    _INF = 0x7FFFFFFF  

    def run_benchmark(self, iteration_id: int):
        for start, end in self._pairs:
            length = self._dijkstra_shortest_path(start, end)
            self._result_value = (self._result_value + length) & 0xFFFFFFFF

    def _dijkstra_shortest_path(self, start: int, target: int) -> int:

        if start == target:
            return 0

        vertices = self._graph.get_vertices()
        dist = [self._INF] * vertices
        visited = [0] * vertices

        dist[start] = 0

        for _ in range(vertices):

            u = -1
            min_dist = self._INF

            for v in range(vertices):
                if visited[v] == 0 and dist[v] < min_dist:
                    min_dist = dist[v]
                    u = v

            if u == -1 or min_dist == self._INF or u == target:
                return min_dist if u == target else -1

            visited[u] = 1

            for v in self._graph.get_adjacency()[u]:
                if dist[u] + 1 < dist[v]:
                    dist[v] = dist[u] + 1

        return -1

class BufferHashBenchmark(Benchmark, ABC):
    def __init__(self):
        super().__init__()
        self._data = bytearray()
        self._n = 0
        self._result = 0

    def prepare(self):
        class_name = self.__class__.__name__
        self._n = Helper.config_i64(class_name, "size")

        self._data = bytearray(self._n)

        for i in range(self._n):
            self._data[i] = Helper.next_int(256)

    @abstractmethod
    def test(self) -> int:

        pass

    def run_benchmark(self, iteration_id: int):
        hash_value = self.test()
        self._result = (self._result + hash_value) & 0xFFFFFFFF

    def checksum(self) -> int:
        return self._result & 0xFFFFFFFF

class BufferHashCRC32(BufferHashBenchmark):
    def test(self) -> int:

        crc = 0xFFFFFFFF

        for byte in self._data:
            crc ^= byte

            for _ in range(8):
                if crc & 1:

                    crc = ((crc >> 1) & 0x7FFFFFFF) ^ 0xEDB88320
                else:
                    crc = (crc >> 1) & 0x7FFFFFFF

        return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF

class BufferHashSHA256(BufferHashBenchmark):
    def test(self) -> int:

        hashes = [
            0x6a09e667,  
            0xbb67ae85,  
            0x3c6ef372,  
            0xa54ff53a,  
            0x510e527f,  
            0x9b05688c,  
            0x1f83d9ab,  
            0x5be0cd19,  
        ]

        for i, byte in enumerate(self._data):
            hash_idx = i % 8
            hash_val = hashes[hash_idx]

            hash_val = ((hash_val << 5) + hash_val + byte) & 0xFFFFFFFF
            hash_val = ((hash_val + (hash_val << 10)) & 0xFFFFFFFF) ^ (hash_val >> 6)
            hash_val &= 0xFFFFFFFF

            hashes[hash_idx] = hash_val

        result = bytearray(32)

        for i, hash_val in enumerate(hashes):
            result[i * 4] = (hash_val >> 24) & 0xFF
            result[i * 4 + 1] = (hash_val >> 16) & 0xFF
            result[i * 4 + 2] = (hash_val >> 8) & 0xFF
            result[i * 4 + 3] = hash_val & 0xFF

        return (result[0] & 0xFF) | \
               ((result[1] & 0xFF) << 8) | \
               ((result[2] & 0xFF) << 16) | \
               ((result[3] & 0xFF) << 24)

class LRUCacheOrderedDict:

    def __init__(self, capacity: int):
        self.capacity = capacity
        self.cache = OrderedDict()

    def get(self, key: K) -> Optional[V]:

        if key not in self.cache:
            return None

        self.cache.move_to_end(key)  
        return self.cache[key]

    def put(self, key: K, value: V):

        if key in self.cache:
            self.cache[key] = value
            self.cache.move_to_end(key)  
        else:
            if len(self.cache) >= self.capacity:
                self.cache.popitem(last=False)  
            self.cache[key] = value

    @property
    def size(self) -> int:
        return len(self.cache)

class CacheSimulation(Benchmark):

    def __init__(self):
        super().__init__()
        self.result = 5432
        self.values_size = 0
        self.cache: Optional[LRUCacheOrderedDict] = None
        self.hits = 0
        self.misses = 0

    def prepare(self):
        class_name = self.__class__.__name__
        self.values_size = Helper.config_i64(class_name, "values")
        cache_size = Helper.config_i64(class_name, "size")
        self.cache = LRUCacheOrderedDict(cache_size)
        self.hits = 0
        self.misses = 0

    def run_benchmark(self, iteration_id: int):
        key = f"item_{Helper.next_int(self.values_size)}"

        if self.cache.get(key) is not None:

            self.hits += 1
            self.cache.put(key, f"updated_{iteration_id}")
        else:

            self.misses += 1
            self.cache.put(key, f"new_{iteration_id}")

    def checksum(self) -> int:
        self.result = ((self.result << 5) + self.hits) & 0xFFFFFFFF
        self.result = ((self.result << 5) + self.misses) & 0xFFFFFFFF
        self.result = ((self.result << 5) + self.cache.size) & 0xFFFFFFFF
        return self.result & 0xFFFFFFFF

class Node2(ABC):

    pass

class NumberNode(Node2):
    def __init__(self, value: int):
        self.value = value

class VariableNode(Node2):
    def __init__(self, name: str):
        self.name = name

class BinaryOpNode(Node2):
    def __init__(self, op: str, left: Node2, right: Node2):
        self.op = op
        self.left = left
        self.right = right

class AssignmentNode(Node2):
    def __init__(self, var_name: str, expr: Node2):
        self.var_name = var_name
        self.expr = expr

class Parser2:

    def __init__(self, input_str: str):
        self.input = input_str
        self.pos = 0
        self.chars = list(input_str)
        self.current_char = self.chars[0] if self.chars else '\0'
        self.expressions: List[Node2] = []

    def parse(self):

        while self.pos < len(self.chars):
            self._skip_whitespace()
            if self.pos >= len(self.chars):
                break

            expr = self._parse_expression()
            self.expressions.append(expr)

    def _parse_expression(self) -> Node2:

        node = self._parse_term()

        while self.pos < len(self.chars):
            self._skip_whitespace()
            if self.pos >= len(self.chars):
                break

            if self.current_char in '+-':
                op = self.current_char
                self._advance()
                right = self._parse_term()
                node = BinaryOpNode(op, node, right)
            else:
                break

        return node

    def _parse_term(self) -> Node2:

        node = self._parse_factor()

        while self.pos < len(self.chars):
            self._skip_whitespace()
            if self.pos >= len(self.chars):
                break

            if self.current_char in '*/%':
                op = self.current_char
                self._advance()
                right = self._parse_factor()
                node = BinaryOpNode(op, node, right)
            else:
                break

        return node

    def _parse_factor(self) -> Node2:

        self._skip_whitespace()
        if self.pos >= len(self.chars):
            return NumberNode(0)

        char = self.current_char

        if self._is_digit(char):
            return self._parse_number()
        elif self._is_letter(char):
            return self._parse_variable()
        elif char == '(':
            self._advance()  
            node = self._parse_expression()
            self._skip_whitespace()
            if self.current_char == ')':
                self._advance()  
            return node
        else:
            return NumberNode(0)

    def _parse_number(self) -> NumberNode:

        value = 0
        while self.pos < len(self.chars) and self._is_digit(self.current_char):
            digit = ord(self.current_char) - ord('0')
            value = value * 10 + digit
            self._advance()
        return NumberNode(value)

    def _parse_variable(self) -> Node2:

        start = self.pos
        while (self.pos < len(self.chars) and 
               (self._is_letter(self.current_char) or 
                self._is_digit(self.current_char))):
            self._advance()

        var_name = self.input[start:self.pos]

        self._skip_whitespace()
        if self.pos < len(self.chars) and self.current_char == '=':
            self._advance()  
            expr = self._parse_expression()
            return AssignmentNode(var_name, expr)

        return VariableNode(var_name)

    def _advance(self):

        self.pos += 1
        if self.pos >= len(self.chars):
            self.current_char = '\0'
        else:
            self.current_char = self.chars[self.pos]

    def _skip_whitespace(self):

        while self.pos < len(self.chars) and self._is_whitespace(self.current_char):
            self._advance()

    @staticmethod
    def _is_digit(ch: str) -> bool:
        return '0' <= ch <= '9'

    @staticmethod
    def _is_letter(ch: str) -> bool:
        return ('a' <= ch <= 'z') or ('A' <= ch <= 'Z')

    @staticmethod
    def _is_whitespace(ch: str) -> bool:
        return ch in ' \t\n\r'

class CalculatorAst(Benchmark):
    def __init__(self):
        super().__init__()
        self.n = 0
        self._text = ''
        self._expressions: List[Node2] = []
        self._result_value = 0

    def prepare(self):
        class_name = self.__class__.__name__
        self.n = Helper.config_i64(class_name, "operations")
        self._text = self._generate_random_program(self.n)

    def _generate_random_program(self, n: int) -> str:

        lines = []
        lines.append('v0 = 1')

        for i in range(1, 11):
            lines.append(f'v{i} = v{i-1} + {i}')

        for i in range(n):
            v = i + 10
            expr = f'v{v-1} + '  

            choice = Helper.next_int(10)
            if choice == 0:
                expr += f'(v{v-1} / 3) * 4 - {i} / (3 + (18 - v{v-2})) % v{v-3} + 2 * ((9 - v{v-6}) * (v{v-5} + 7))'
            elif choice == 1:
                expr += f'v{v-1} + (v{v-2} + v{v-3}) * v{v-4} - (v{v-5} / v{v-6})'
            elif choice == 2:
                expr += f'(3789 - (((v{v-7})))) + 1'
            elif choice == 3:
                expr += f'4/2 * (1-3) + v{v-9}/v{v-5}'
            elif choice == 4:
                expr += f'1+2+3+4+5+6+v{v-1}'
            elif choice == 5:
                expr += f'(99999 / v{v-3})'
            elif choice == 6:
                expr += f'0 + 0 - v{v-8}'
            elif choice == 7:
                expr += f'((((((((((v{v-6})))))))))) * 2'
            elif choice == 8:
                expr += f'{i} * (v{v-1} % 6) % 7'
            else:  
                expr += f'(1)/(0-v{v-5}) + (v{v-7})'

            lines.append(f'v{v} = {expr}')

        return '\n'.join(lines)

    def run_benchmark(self, iteration_id: int):
        parser = Parser2(self._text)
        parser.parse()
        self._expressions = parser.expressions.copy()

        self._result_value = (self._result_value + len(self._expressions)) & 0xFFFFFFFF

        if self._expressions:
            last_expr = self._expressions[-1]
            if isinstance(last_expr, AssignmentNode):
                self._result_value = (self._result_value + 
                                     Helper.checksum_string(last_expr.var_name)) & 0xFFFFFFFF

    def get_expressions(self) -> List[Node2]:
        return self._expressions.copy()

    def checksum(self) -> int:
        return self._result_value & 0xFFFFFFFF

class Int64:
    MASK64 = 0xFFFFFFFFFFFFFFFF

    def __init__(self, value=0):
        if isinstance(value, Int64):
            self._value = value._value
        else:
            v = int(value)
            self._value = (v & self.MASK64)
            if self._value & (1 << 63):
                self._value -= (1 << 64)

    def __add__(self, other: Int64):
        return Int64(self._value + other._value)

    def __sub__(self, other: Int64):
        return Int64(self._value - other._value)

    def __mul__(self, other: Int64):
        return Int64(self._value * other._value)

    def __floordiv__(self, other: Int64):
        if other._value == 0:
            return Int64(0)

        a = self._value
        b = other._value

        if (a >= 0 and b > 0) or (a < 0 and b < 0):
            result = a // b
        else:
            result = -(abs(a) // abs(b))

        return Int64(result)

    def __mod__(self, other: Int64):
        if other._value == 0:
            return Int64(0)

        div_result = self.__floordiv__(other)
        result = self._value - div_result._value * other._value
        return Int64(result)

    def __int__(self):
        return self._value

    def __eq__(self, other: Int64):
        return self._value == other._value

    def __lt__(self, other: Int64):
        return self._value < other._value

    def __repr__(self):
        return f"Int64({self._value})"

class Interpreter2:
    def __init__(self):
        self.variables = {}

    def evaluate(self, node: Node2) -> Int64:
        if isinstance(node, NumberNode):
            return Int64(node.value)
        elif isinstance(node, VariableNode):
            return self.variables.get(node.name, Int64(0))
        elif isinstance(node, BinaryOpNode):
            left = self.evaluate(node.left)
            right = self.evaluate(node.right)

            if node.op == '+':
                return left + right
            elif node.op == '-':
                return left - right
            elif node.op == '*':
                return left * right
            elif node.op == '/':
                return left // right  
            elif node.op == '%':
                return left % right   
        elif isinstance(node, AssignmentNode):
            value = self.evaluate(node.expr)
            self.variables[node.var_name] = value
            return value

        return Int64(0)

    def run(self, expressions: List[Node2]) -> int:

        result = 0
        for expr in expressions:
            result = self.evaluate(expr)
        return int(result)

    def clear(self):

        self.variables.clear()

class CalculatorInterpreter(Benchmark):
    def __init__(self):
        super().__init__()
        self._ast: List[Node2] = []
        self._result_value = 0

    def prepare(self):
        class_name = self.__class__.__name__
        operations = Helper.config_i64(class_name, "operations")

        calculator_ast = CalculatorAst()
        calculator_ast.n = operations
        text = calculator_ast._generate_random_program(operations)

        parser = Parser2(text)
        parser.parse()
        self._ast = parser.expressions.copy()

    def run_benchmark(self, iteration_id: int):
        interpreter = Interpreter2()
        result = interpreter.run(self._ast)

        result = result & 0xFFFFFFFFFFFFFFFF
        if result & (1 << 63):  
            result = result - (1 << 64)

        self._result_value = (self._result_value + (result & 0xFFFFFFFF)) & 0xFFFFFFFF

    def checksum(self) -> int:
        return self._result_value & 0xFFFFFFFF

class Grid:
    DEAD = 0
    ALIVE = 1

    def __init__(self, width: int, height: int):
        self.width = width
        self.height = height
        size = width * height
        self.cells = bytearray(size)
        self.buffer = bytearray(size)

    def _index(self, x: int, y: int) -> int:
        return y * self.width + x

    def get(self, x: int, y: int) -> int:
        return self.cells[self._index(x, y)]

    def set(self, x: int, y: int, cell: int):
        self.cells[self._index(x, y)] = cell

    def next_generation(self) -> 'Grid':

        w = self.width
        h = self.height

        new_grid = Grid(w, h)
        new_grid.cells, new_grid.buffer = self.buffer, self.cells

        cells = self.cells
        buffer = new_grid.cells

        for y in range(h):
            y_idx = y * w

            y_prev = (y - 1) % h
            y_next = (y + 1) % h
            y_prev_idx = y_prev * w
            y_next_idx = y_next * w

            for x in range(w):
                idx = y_idx + x

                x_prev = (x - 1) % w
                x_next = (x + 1) % w

                neighbors = (
                    cells[y_prev_idx + x_prev] +
                    cells[y_prev_idx + x] +
                    cells[y_prev_idx + x_next] +
                    cells[y_idx + x_prev] +
                    cells[y_idx + x_next] +
                    cells[y_next_idx + x_prev] +
                    cells[y_next_idx + x] +
                    cells[y_next_idx + x_next]
                )

                current = cells[idx]

                if current == self.ALIVE:
                    next_state = self.ALIVE if neighbors in (2, 3) else self.DEAD
                else:
                    next_state = self.ALIVE if neighbors == 3 else self.DEAD

                buffer[idx] = next_state

        return new_grid

    def compute_hash(self) -> int:

        FNV_OFFSET_BASIS = 2166136261
        FNV_PRIME = 16777619

        hash_val = FNV_OFFSET_BASIS

        for cell in self.cells:
            hash_val = (hash_val ^ cell) * FNV_PRIME
            hash_val &= 0xFFFFFFFF  

        return hash_val

class GameOfLife(Benchmark):
    def __init__(self):
        super().__init__()
        self.width = 0
        self.height = 0
        self.grid: Optional[Grid] = None

    def prepare(self):
        class_name = self.__class__.__name__
        self.width = Helper.config_i64(class_name, "w")
        self.height = Helper.config_i64(class_name, "h")

        self.grid = Grid(self.width, self.height)

        for y in range(self.height):
            for x in range(self.width):
                if Helper.next_float() < 0.1:
                    self.grid.set(x, y, Grid.ALIVE)

    def run_benchmark(self, iteration_id: int):
        self.grid = self.grid.next_generation()

    def checksum(self) -> int:
        return self.grid.compute_hash()

class Cell(Enum):
    WALL = 0
    PATH = 1

class Maze:
    def __init__(self, width: int, height: int):
        self.width = width if width > 5 else 5
        self.height = height if height > 5 else 5
        self.cells = [[Cell.WALL for _ in range(self.width)] 
                     for _ in range(self.height)]

    def __getitem__(self, pos: Tuple[int, int]) -> Cell:
        x, y = pos
        return self.cells[y][x]

    def __setitem__(self, pos: Tuple[int, int], value: Cell):
        x, y = pos
        self.cells[y][x] = value

    def generate(self):

        if self.width < 5 or self.height < 5:

            mid_y = self.height // 2
            for x in range(self.width):
                self[x, mid_y] = Cell.PATH
            return

        self._divide(0, 0, self.width - 1, self.height - 1)
        self._add_random_paths()

    def _add_random_paths(self):

        num_extra_paths = (self.width * self.height) // 20

        for _ in range(num_extra_paths):
            x = Helper.next_int(self.width - 2) + 1
            y = Helper.next_int(self.height - 2) + 1

            if (self[x, y] == Cell.WALL and
                self[x - 1, y] == Cell.WALL and
                self[x + 1, y] == Cell.WALL and
                self[x, y - 1] == Cell.WALL and
                self[x, y + 1] == Cell.WALL):
                self[x, y] = Cell.PATH

    def _divide(self, x1: int, y1: int, x2: int, y2: int):
        width = x2 - x1
        height = y2 - y1

        if width < 2 or height < 2:
            return

        width_for_wall = width - 2
        height_for_wall = height - 2
        width_for_hole = width - 1
        height_for_hole = height - 1

        if (width_for_wall <= 0 or height_for_wall <= 0 or 
            width_for_hole <= 0 or height_for_hole <= 0):
            return

        if width > height:

            wall_range = max(width_for_wall // 2, 1)
            wall_offset = (Helper.next_int(wall_range) * 2) if wall_range > 0 else 0
            wall_x = x1 + 2 + wall_offset

            hole_range = max(height_for_hole // 2, 1)
            hole_offset = (Helper.next_int(hole_range) * 2) if hole_range > 0 else 0
            hole_y = y1 + 1 + hole_offset

            if wall_x > x2 or hole_y > y2:
                return

            for y in range(y1, y2 + 1):
                if y != hole_y:
                    self[wall_x, y] = Cell.WALL

            if wall_x > x1 + 1:
                self._divide(x1, y1, wall_x - 1, y2)
            if wall_x + 1 < x2:
                self._divide(wall_x + 1, y1, x2, y2)
        else:

            wall_range = max(height_for_wall // 2, 1)
            wall_offset = (Helper.next_int(wall_range) * 2) if wall_range > 0 else 0
            wall_y = y1 + 2 + wall_offset

            hole_range = max(width_for_hole // 2, 1)
            hole_offset = (Helper.next_int(hole_range) * 2) if hole_range > 0 else 0
            hole_x = x1 + 1 + hole_offset

            if wall_y > y2 or hole_x > x2:
                return

            for x in range(x1, x2 + 1):
                if x != hole_x:
                    self[x, wall_y] = Cell.WALL

            if wall_y > y1 + 1:
                self._divide(x1, y1, x2, wall_y - 1)
            if wall_y + 1 < y2:
                self._divide(x1, wall_y + 1, x2, y2)

    def to_bool_grid(self) -> List[List[bool]]:

        return [[cell == Cell.PATH for cell in row] 
                for row in self.cells]

    def is_connected(self, start: Tuple[int, int], goal: Tuple[int, int]) -> bool:

        if (start[0] >= self.width or start[1] >= self.height or
            goal[0] >= self.width or goal[1] >= self.height):
            return False

        visited = [[False for _ in range(self.width)] 
                  for _ in range(self.height)]
        queue = deque([start])
        visited[start[1]][start[0]] = True

        while queue:
            x, y = queue.popleft()

            if (x, y) == goal:
                return True

            if y > 0 and self[x, y - 1] == Cell.PATH and not visited[y - 1][x]:
                visited[y - 1][x] = True
                queue.append((x, y - 1))

            if x + 1 < self.width and self[x + 1, y] == Cell.PATH and not visited[y][x + 1]:
                visited[y][x + 1] = True
                queue.append((x + 1, y))

            if y + 1 < self.height and self[x, y + 1] == Cell.PATH and not visited[y + 1][x]:
                visited[y + 1][x] = True
                queue.append((x, y + 1))

            if x > 0 and self[x - 1, y] == Cell.PATH and not visited[y][x - 1]:
                visited[y][x - 1] = True
                queue.append((x - 1, y))

        return False

    @staticmethod
    def generate_walkable_maze(width: int, height: int) -> List[List[bool]]:

        maze = Maze(width, height)
        maze.generate()

        start = (1, 1)
        goal = (width - 2, height - 2)

        if not maze.is_connected(start, goal):

            for y in range(height):
                for x in range(width):
                    if y < maze.height and x < maze.width:
                        if x == 1 or y == 1 or x == width - 2 or y == height - 2:
                            maze[x, y] = Cell.PATH

        return maze.to_bool_grid()

class MazeGenerator(Benchmark):
    def __init__(self):
        super().__init__()
        self.result = 0  
        self.width = 0
        self.height = 0
        self.bool_grid: List[List[bool]] = []

    def prepare(self):
        class_name = self.__class__.__name__
        self.width = Helper.config_i64(class_name, "w")
        self.height = Helper.config_i64(class_name, "h")

    def run_benchmark(self, iteration_id: int):

        self.bool_grid = Maze.generate_walkable_maze(self.width, self.height)

    def grid_checksum(self, grid: List[List[bool]]) -> int:

        hasher = 2166136261 & 0xFFFFFFFF  
        prime = 16777619 & 0xFFFFFFFF     

        steps = []

        for i, row in enumerate(grid):
            for j, cell in enumerate(row):
                if cell:

                    j_squared = (j * j) & 0xFFFFFFFF

                    old_hasher = hasher
                    hasher = ((hasher ^ j_squared) * prime) & 0xFFFFFFFF

        return hasher

    def checksum(self) -> int:

        result = self.grid_checksum(self.bool_grid)
        return result

class Node:
    __slots__ = ('x', 'y', 'f_score')

    def __init__(self, x: int, y: int, f_score: int):
        self.x = x
        self.y = y
        self.f_score = f_score

    def __lt__(self, other: 'Node') -> bool:
        return self.f_score < other.f_score

    def __eq__(self, other: 'Node') -> bool:
        return (self.x == other.x and 
                self.y == other.y and 
                self.f_score == other.f_score)

class AStarPathfinder(Benchmark):
    @staticmethod
    def manhattan_distance(x1: int, y1: int, x2: int, y2: int) -> int:
        return abs(x1 - x2) + abs(y1 - y2)

    def __init__(self):
        super().__init__()
        self.width = 0
        self.height = 0
        self.maze_grid: List[List[bool]] = []
        self.result = 0
        self.start_x = 1
        self.start_y = 1
        self.goal_x = 0
        self.goal_y = 0

    def prepare(self):
        class_name = self.__class__.__name__
        self.width = Helper.config_i64(class_name, "w")
        self.height = Helper.config_i64(class_name, "h")
        self.goal_x = self.width - 2
        self.goal_y = self.height - 2

        self.maze_grid = Maze.generate_walkable_maze(self.width, self.height)

    def _pack_coords(self, x: int, y: int) -> int:
        return y * self.width + x

    def _unpack_coords(self, packed: int) -> Tuple[int, int]:
        return packed % self.width, packed // self.width

    def _find_path(self) -> Tuple[Optional[List[Tuple[int, int]]], int]:

        width = self.width
        height = self.height
        grid = self.maze_grid

        size = width * height
        g_scores = [0x7FFFFFFF] * size
        came_from = [-1] * size

        start_idx = self._pack_coords(self.start_x, self.start_y)
        g_scores[start_idx] = 0

        start_f = self.manhattan_distance(
            self.start_x, self.start_y, self.goal_x, self.goal_y)

        open_set = []
        heapq.heappush(open_set, Node(self.start_x, self.start_y, start_f))

        nodes_explored = 0
        directions = [(0, -1), (1, 0), (0, 1), (-1, 0)]

        while open_set:
            current = heapq.heappop(open_set)
            nodes_explored += 1

            if current.x == self.goal_x and current.y == self.goal_y:

                path = []
                x, y = current.x, current.y

                while x != self.start_x or y != self.start_y:
                    path.append((x, y))
                    idx = self._pack_coords(x, y)
                    packed = came_from[idx]
                    if packed == -1:
                        break
                    x, y = self._unpack_coords(packed)

                path.append((self.start_x, self.start_y))
                path.reverse()
                return path, nodes_explored

            current_idx = self._pack_coords(current.x, current.y)
            current_g = g_scores[current_idx]

            for dx, dy in directions:
                nx, ny = current.x + dx, current.y + dy

                if (nx < 0 or nx >= width or 
                    ny < 0 or ny >= height or 
                    not grid[ny][nx]):
                    continue

                tentative_g = current_g + 1000
                neighbor_idx = self._pack_coords(nx, ny)

                if tentative_g < g_scores[neighbor_idx]:
                    came_from[neighbor_idx] = current_idx
                    g_scores[neighbor_idx] = tentative_g

                    f_score = tentative_g + self.manhattan_distance(
                        nx, ny, self.goal_x, self.goal_y)

                    heapq.heappush(open_set, Node(nx, ny, f_score))

        return None, nodes_explored

    def run_benchmark(self, iteration_id: int):
        path, nodes_explored = self._find_path()

        local_result = len(path) if path else 0
        local_result = (local_result << 5) + nodes_explored

        self.result = (self.result + local_result) & 0xFFFFFFFF

    def checksum(self) -> int:
        return self.result & 0xFFFFFFFF

class BWTResult(NamedTuple):
    transformed: bytes
    original_idx: int

class HuffmanNode:
    def __init__(self, frequency: int, byte_val: Optional[int] = None, is_leaf: bool = True):
        self.frequency = frequency
        self.byte_val = byte_val
        self.is_leaf = is_leaf
        self.left: Optional[HuffmanNode] = None
        self.right: Optional[HuffmanNode] = None
        self.index = 0

class HuffmanCodes:
    def __init__(self):
        self.code_lengths = [0] * 256
        self.codes = [0] * 256

class EncodedResult(NamedTuple):
    data: bytes
    bit_count: int

class CompressedData(NamedTuple):
    bwt_result: BWTResult
    frequencies: List[int]
    encoded_bits: bytes
    original_bit_count: int

class BWTHuffBase(Benchmark):
    @staticmethod
    def bwt_transform(input_data: bytes) -> BWTResult:

        n = len(input_data)
        if n == 0:
            return BWTResult(b'', 0)

        sa = list(range(n))

        buckets = [[] for _ in range(256)]
        for idx in sa:
            first_char = input_data[idx]
            buckets[first_char].append(idx)

        sa = []
        for bucket in buckets:
            sa.extend(bucket)

        if n > 1:

            rank = [0] * n
            current_rank = 0
            prev_char = input_data[sa[0]]

            for i, idx in enumerate(sa):
                if input_data[idx] != prev_char:
                    current_rank += 1
                    prev_char = input_data[idx]
                rank[idx] = current_rank

            k = 1
            while k < n:

                pairs = [(rank[i], rank[(i + k) % n]) for i in range(n)]

                sa.sort(key=lambda i: (pairs[i][0], pairs[i][1]))

                new_rank = [0] * n
                new_rank[sa[0]] = 0
                for i in range(1, n):
                    prev_pair = pairs[sa[i - 1]]
                    curr_pair = pairs[sa[i]]
                    new_rank[sa[i]] = new_rank[sa[i - 1]] + (1 if prev_pair != curr_pair else 0)

                rank = new_rank
                k *= 2

        transformed = bytearray(n)
        original_idx = 0

        for i, suffix in enumerate(sa):
            if suffix == 0:
                transformed[i] = input_data[n - 1]
                original_idx = i
            else:
                transformed[i] = input_data[suffix - 1]

        return BWTResult(bytes(transformed), original_idx)

    @staticmethod
    def bwt_inverse(bwt_result: BWTResult) -> bytes:

        bwt = bwt_result.transformed
        n = len(bwt)
        if n == 0:
            return b''

        counts = [0] * 256
        for byte in bwt:
            counts[byte] += 1

        positions = [0] * 256
        total = 0
        for i, count in enumerate(counts):
            positions[i] = total
            total += count

        next_arr = [0] * n
        temp_counts = [0] * 256

        for i, byte in enumerate(bwt):
            byte_idx = byte
            pos = positions[byte_idx] + temp_counts[byte_idx]
            next_arr[pos] = i
            temp_counts[byte_idx] += 1

        result = bytearray(n)
        idx = bwt_result.original_idx

        for i in range(n):
            idx = next_arr[idx]
            result[i] = bwt[idx]

        return bytes(result)

    @staticmethod
    def build_huffman_tree(frequencies: List[int]) -> HuffmanNode:

        heap = []

        for i, freq in enumerate(frequencies):
            if freq > 0:
                heapq.heappush(heap, (freq, i, HuffmanNode(freq, i, True)))

        if len(heap) == 1:
            _, byte_val, node = heapq.heappop(heap)
            root = HuffmanNode(node.frequency, None, False)
            root.left = node
            root.right = HuffmanNode(0, 0, True)
            return root

        while len(heap) > 1:
            freq1, _, left = heapq.heappop(heap)
            freq2, _, right = heapq.heappop(heap)

            parent = HuffmanNode(freq1 + freq2, None, False)
            parent.left = left
            parent.right = right

            heapq.heappush(heap, (parent.frequency, 0, parent))  

        _, _, root = heapq.heappop(heap)
        return root

    @staticmethod
    def build_huffman_codes(node: HuffmanNode, code: int, length: int, 
                           huffman_codes: HuffmanCodes):

        if node.is_leaf:
            if length > 0 or node.byte_val != 0:
                idx = node.byte_val
                if idx is not None:
                    huffman_codes.code_lengths[idx] = length
                    huffman_codes.codes[idx] = code
        else:
            if node.left:
                BWTHuffBase.build_huffman_codes(
                    node.left, code << 1, length + 1, huffman_codes
                )
            if node.right:
                BWTHuffBase.build_huffman_codes(
                    node.right, (code << 1) | 1, length + 1, huffman_codes
                )

    @staticmethod
    def huffman_encode(data: bytes, huffman_codes: HuffmanCodes) -> EncodedResult:

        result = bytearray(len(data) * 2)  
        current_byte = 0
        bit_pos = 0
        byte_index = 0
        total_bits = 0

        for byte in data:
            idx = byte
            code = huffman_codes.codes[idx]
            length = huffman_codes.code_lengths[idx]

            for i in range(length - 1, -1, -1):
                if code & (1 << i):
                    current_byte |= 1 << (7 - bit_pos)

                bit_pos += 1
                total_bits += 1

                if bit_pos == 8:
                    result[byte_index] = current_byte
                    byte_index += 1
                    current_byte = 0
                    bit_pos = 0

        if bit_pos > 0:
            result[byte_index] = current_byte
            byte_index += 1

        return EncodedResult(bytes(result[:byte_index]), total_bits)

    @staticmethod
    def huffman_decode(encoded: bytes, root: HuffmanNode, bit_count: int) -> bytes:

        result = bytearray(bit_count // 4 + 1)  
        result_idx = 0
        current_node = root
        bits_processed = 0
        byte_index = 0

        while bits_processed < bit_count and byte_index < len(encoded):
            byte_val = encoded[byte_index]
            byte_index += 1

            for bit_pos in range(7, -1, -1):
                if bits_processed >= bit_count:
                    break

                bit = (byte_val >> bit_pos) & 1
                bits_processed += 1

                current_node = current_node.right if bit else current_node.left

                if current_node.is_leaf:
                    if current_node.byte_val is not None:

                        if result_idx >= len(result):
                            result.extend([0] * len(result))  

                        result[result_idx] = current_node.byte_val
                        result_idx += 1

                    current_node = root

        return bytes(result[:result_idx])

    @staticmethod
    def compress(data: bytes) -> CompressedData:

        bwt_result = BWTHuffBase.bwt_transform(data)

        frequencies = [0] * 256
        for byte in bwt_result.transformed:
            frequencies[byte] += 1

        huffman_tree = BWTHuffBase.build_huffman_tree(frequencies)
        huffman_codes = HuffmanCodes()
        BWTHuffBase.build_huffman_codes(huffman_tree, 0, 0, huffman_codes)

        encoded = BWTHuffBase.huffman_encode(bwt_result.transformed, huffman_codes)

        return CompressedData(bwt_result, frequencies, encoded.data, encoded.bit_count)

    @staticmethod
    def decompress(compressed: CompressedData) -> bytes:

        huffman_tree = BWTHuffBase.build_huffman_tree(compressed.frequencies)

        decoded = BWTHuffBase.huffman_decode(
            compressed.encoded_bits,
            huffman_tree,
            compressed.original_bit_count
        )

        bwt_result = BWTResult(decoded, compressed.bwt_result.original_idx)
        return BWTHuffBase.bwt_inverse(bwt_result)

class BWTHuffEncode(BWTHuffBase):
    def __init__(self):
        super().__init__()
        self.size = 0
        self.result = 0
        self.test_data: Optional[bytes] = None

    def prepare(self):
        class_name = self.__class__.__name__
        self.size = Helper.config_i64(class_name, "size")
        self.test_data = self._generate_test_data(self.size)

    def _generate_test_data(self, size: int) -> bytes:

        pattern = b"ABRACADABRA"
        data = bytearray(size)

        for i in range(size):
            data[i] = pattern[i % len(pattern)]

        return bytes(data)

    def run_benchmark(self, iteration_id: int):
        compressed = self.compress(self.test_data)
        self.result = (self.result + len(compressed.encoded_bits)) & 0xFFFFFFFF

    def checksum(self) -> int:
        return self.result & 0xFFFFFFFF

class BWTHuffDecode(BWTHuffBase):
    def __init__(self):
        super().__init__()
        self.size = 0
        self.result = 0
        self.test_data: Optional[bytes] = None
        self.compressed: Optional[CompressedData] = None
        self.decompressed: Optional[bytes] = None

    def prepare(self):
        class_name = self.__class__.__name__
        self.size = Helper.config_i64(class_name, "size")
        self.test_data = self._generate_test_data(self.size)
        self.compressed = self.compress(self.test_data)

    def _generate_test_data(self, size: int) -> bytes:

        pattern = b"ABRACADABRA"
        data = bytearray(size)

        for i in range(size):
            data[i] = pattern[i % len(pattern)]

        return bytes(data)

    def run_benchmark(self, iteration_id: int):
        decompressed = self.decompress(self.compressed)
        self.decompressed = decompressed
        self.result = (self.result + len(decompressed)) & 0xFFFFFFFF

    def checksum(self) -> int:

        if self.decompressed == self.test_data:
            self.result = (self.result + 1000000) & 0xFFFFFFFF
        return self.result & 0xFFFFFFFF

def register_benchmarks():

    Benchmark.register_benchmark(Pidigits)
    Benchmark.register_benchmark(Binarytrees)
    Benchmark.register_benchmark(BrainfuckArray)
    Benchmark.register_benchmark(BrainfuckRecursion)
    Benchmark.register_benchmark(Fannkuchredux)
    Benchmark.register_benchmark(Fasta)
    Benchmark.register_benchmark(Knuckeotide)
    Benchmark.register_benchmark(Mandelbrot)
    Benchmark.register_benchmark(Matmul1T)
    Benchmark.register_benchmark(Matmul4T)
    Benchmark.register_benchmark(Matmul8T)
    Benchmark.register_benchmark(Matmul16T)
    Benchmark.register_benchmark(Nbody)
    Benchmark.register_benchmark(RegexDna)
    Benchmark.register_benchmark(Revcomp)
    Benchmark.register_benchmark(Spectralnorm)
    Benchmark.register_benchmark(Base64Encode)
    Benchmark.register_benchmark(Base64Decode)
    Benchmark.register_benchmark(JsonGenerate)
    Benchmark.register_benchmark(JsonParseDom)
    Benchmark.register_benchmark(JsonParseMapping)
    Benchmark.register_benchmark(Primes)
    Benchmark.register_benchmark(Noise)
    Benchmark.register_benchmark(TextRaytracer)
    Benchmark.register_benchmark(NeuralNet)
    Benchmark.register_benchmark(SortQuick)
    Benchmark.register_benchmark(SortMerge)
    Benchmark.register_benchmark(SortSelf)
    Benchmark.register_benchmark(GraphPathBFS)
    Benchmark.register_benchmark(GraphPathDFS)
    Benchmark.register_benchmark(GraphPathDijkstra)
    Benchmark.register_benchmark(BufferHashSHA256)
    Benchmark.register_benchmark(BufferHashCRC32)
    Benchmark.register_benchmark(CacheSimulation)
    Benchmark.register_benchmark(CalculatorAst)
    Benchmark.register_benchmark(CalculatorInterpreter)
    Benchmark.register_benchmark(GameOfLife)
    Benchmark.register_benchmark(MazeGenerator)
    Benchmark.register_benchmark(AStarPathfinder)
    Benchmark.register_benchmark(BWTHuffEncode)
    Benchmark.register_benchmark(BWTHuffDecode)

def main():
    config_file = '../test.json'
    test_name = None

    args = sys.argv[1:]
    if args:
        if any(ext in args[0] for ext in ['.txt', '.json', '.js', '.config']):
            config_file = args[0]
            test_name = args[1] if len(args) > 1 else None
        else:
            test_name = args[0]

    print(f'start: {int(time.time() * 1000)}')

    try:
        Helper.load_config(config_file)
        register_benchmarks()
        Benchmark.run(test_name)
    except Exception as e:
        print(f'Failed to run benchmarks: {e}')
        sys.exit(1)

if __name__ == '__main__':
    main()