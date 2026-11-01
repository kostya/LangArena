"use strict";

const isDeno = (() => {
  try {
    return typeof Deno !== "undefined" && Deno.version !== undefined;
  } catch {
    return false;
  }
})();

const isBun = (() => {
  try {
    return typeof Bun !== "undefined" && Bun.version !== undefined;
  } catch {
    return false;
  }
})();

const isNode = (() => {
  try {
    return typeof process !== "undefined" && process.versions && process.versions.node && !isBun;
  } catch {
    return false;
  }
})();

const getPerformance = () => {
  try {
    const global = globalThis;
    if (typeof global.performance !== "undefined" && typeof global.performance.now === "function") {
      return global.performance;
    }
    if (isNode) {
      try {
        return require("perf_hooks").performance;
      } catch {}
    }
  } catch {}
  return {
    now: () => Date.now(),
  };
};
const performance = getPerformance();

class Helper {
  static IM = 139968;
  static IA = 3877;
  static IC = 29573;
  static INIT = 42;
  static lastValue = Helper.INIT;
  static inputMap = {};
  static expectMap = {};
  static _config = null;
  static _order = [];

  static get order() {
    return this._order;
  }

  static reset() {
    this.lastValue = this.INIT;
  }

  static get last() {
    return this.lastValue;
  }

  static set last(value) {
    this.lastValue = value;
  }

  static nextInt(max) {
    this.last = (this.last * this.IA + this.IC) % this.IM;
    return Math.floor((this.last / this.IM) * max);
  }

  static nextIntRange(from, to) {
    return this.nextInt(to - from + 1) + from;
  }

  static nextFloat(max = 1.0) {
    this.last = (this.last * this.IA + this.IC) % this.IM;
    return (max * this.last) / this.IM;
  }

  static debug(message) {
    try {
      if (isDeno) {
        if (Deno.env.get("DEBUG") === "1") {
          console.log(message);
        }
      } else if (isNode || isBun) {
        if (process.env.DEBUG === "1") {
          console.log(message);
        }
      }
    } catch {}
  }

  static checksumString(str) {
    let hash = 5381;
    for (let i = 0; i < str.length; i++) {
      const byte = str.charCodeAt(i);
      hash = (hash << 5) + hash + byte;
      hash = hash & 0xffffffff;
    }
    return hash >>> 0;
  }

  static checksumBytes(bytes) {
    let hash = 5381;
    for (const byte of bytes) {
      hash = (hash << 5) + hash + byte;
      hash = hash & 0xffffffff;
    }
    return hash >>> 0;
  }

  static checksumFloat(value) {
    return this.checksumString(value.toFixed(7));
  }

  static async loadConfig(configFile = "../run.js") {
    try {
      let content = "";
      if (isDeno) {
        try {
          const denoGlobal = globalThis.Deno;
          if (denoGlobal && typeof denoGlobal.cwd === "function") {
            const filePath = configFile.startsWith("/")
              ? configFile
              : denoGlobal.cwd() + "/" + configFile;
            content = denoGlobal.readTextFileSync(filePath);
          } else {
            throw new Error("Deno environment not properly detected");
          }
        } catch (denoError) {
          console.error(`Deno error loading ${configFile}:`, denoError?.message || denoError);
          const denoGlobal = globalThis.Deno;
          if (denoGlobal && typeof denoGlobal.exit === "function") {
            denoGlobal.exit(1);
          }
          throw denoError;
        }
      } else if (isNode) {
        try {
          const fs = require("fs");
          const path = require("path");
          const filePath = path.resolve(process.cwd(), configFile);
          content = fs.readFileSync(filePath, "utf-8");
        } catch (nodeError) {
          console.error(`Node.js error loading ${configFile}:`, nodeError?.message || nodeError);
          process.exit(1);
        }
      } else if (isBun) {
        try {
          const file = Bun.file(configFile);
          content = await file.text();
        } catch (bunError) {
          console.error(`Bun error loading ${configFile}:`, bunError?.message || bunError);
          process.exit(1);
        }
      } else {
        console.error(`Unknown environment, cannot load config: ${configFile}`);
        return;
      }

      const data = JSON.parse(content);

      if (Array.isArray(data)) {
        const configDict = {};
        const orderList = [];
        for (const item of data) {
          const name = item.name;
          if (name) {
            configDict[name] = item;
            orderList.push(name);
          }
        }
        Helper._config = configDict;
        Helper._order = orderList;
      } else {
        Helper._config = data;
        Helper._order = [];
      }
    } catch (error) {
      console.error(`Error loading config file ${configFile}:`, error?.message || error);
      try {
        if (isDeno) {
          const denoGlobal = globalThis.Deno;
          if (denoGlobal && typeof denoGlobal.exit === "function") {
            denoGlobal.exit(1);
          }
        } else if (isNode || isBun) {
          if (typeof process !== "undefined" && process.exit) {
            process.exit(1);
          }
        }
      } catch {
        throw error;
      }
    }
  }

  static configI64(className, fieldName) {
    const config = Helper._config;
    if (!config || !config[className]) {
      throw new Error(`Config not found class ${className}`);
    }

    const value = config[className][fieldName];
    if (typeof value === "bigint") {
      return value;
    } else if (typeof value === "number") {
      return BigInt(value);
    } else {
      throw new Error(
        `Config for ${className}, not found i64 field: ${fieldName} in ${JSON.stringify(config[className])}`,
      );
    }
  }

  static configS(className, fieldName) {
    const config = Helper._config;
    if (!config || !config[className]) {
      throw new Error(`Config not found class ${className}`);
    }

    const value = config[className][fieldName];
    if (typeof value === "string") {
      return value;
    } else {
      throw new Error(
        `Config for ${className}, not found string field: ${fieldName} in ${JSON.stringify(config[className])}`,
      );
    }
  }
}

class Benchmark {
  get name() {
    return this.constructor.name;
  }

  prepare() {}

  get config() {
    const config = Helper._config;
    return config && config[this.name] ? config[this.name] : {};
  }

  get warmupIterations() {
    const config = Helper._config;
    if (config && config[this.name] && config[this.name].warmup_iterations !== undefined) {
      return Number(config[this.name].warmup_iterations);
    }
    return Math.max(Math.floor(this.iterations * 0.2), 1);
  }

  warmup() {
    for (let i = 0; i < this.warmupIterations; i++) {
      this.run(i);
    }
  }

  runAll() {
    for (let i = 0; i < this.iterations; i++) {
      this.run(i);
    }
  }

  get iterations() {
    try {
      return Number(Helper.configI64(this.name, "iterations"));
    } catch {
      return 1;
    }
  }

  get expectedChecksum() {
    try {
      return Helper.configI64(this.name, "checksum");
    } catch {
      return 0n;
    }
  }

  static benchmarkMap = new Map();

  static registerBenchmark(name, cls) {
    if (this.benchmarkMap.has(name)) {
      console.warn(`Warning: Benchmark with name "${name}" already registered. Skipping.`);
      return;
    }
    this.benchmarkMap.set(name, cls);
  }

  static run(singleBench) {
    let summaryTime = 0;
    let ok = 0;
    let fails = 0;

    for (const benchName of Helper.order) {
      if (singleBench && !benchName.toLowerCase().includes(singleBench.toLowerCase())) {
        continue;
      }

      const cls = this.benchmarkMap.get(benchName);
      if (!cls) {
        console.log(`Warning: Benchmark '${benchName}' defined in config but not found in code`);
        continue;
      }

      try {
        if (isNode || isBun) {
          process.stdout.write(`${benchName}: `);
        } else if (isDeno) {
          Deno.stdout.write(new TextEncoder().encode(`${benchName}: `));
        } else {
          console.log(`${benchName}: starting...`);
        }
      } catch {
        console.log(`${benchName}: `);
      }

      const bench = new cls();

      Helper.reset();
      bench.prepare();
      bench.warmup();

      Helper.reset();

      const startTime = performance.now();
      bench.runAll();
      const endTime = performance.now();
      const timeDelta = (endTime - startTime) / 1000;

      try {
        if (global.gc) {
          global.gc();
        }
      } catch {}

      const actualResult = BigInt(bench.checksum());
      const expectedResult = bench.expectedChecksum;

      if (actualResult === expectedResult) {
        try {
          if (isNode || isBun) {
            process.stdout.write("OK ");
          } else if (isDeno) {
            Deno.stdout.write(new TextEncoder().encode("OK "));
          } else {
            console.log("OK ");
          }
        } catch {
          console.log("OK ");
        }
        ok++;
      } else {
        const errorMsg = `ERR[actual=${actualResult.toString()}, expected=${expectedResult?.toString() || "undefined"}] `;
        try {
          if (isNode || isBun) {
            process.stdout.write(errorMsg);
          } else if (isDeno) {
            Deno.stdout.write(new TextEncoder().encode(errorMsg));
          } else {
            console.log(errorMsg);
          }
        } catch {
          console.log(errorMsg);
        }
        fails++;
      }

      console.log(`in ${timeDelta.toFixed(3)}s`);
      summaryTime += timeDelta;
    }

    console.log(`Summary: ${summaryTime.toFixed(4)}s, ${ok + fails}, ${ok}, ${fails}`);

    if (fails > 0) {
      try {
        if (isDeno) {
          Deno.exit(1);
        } else if (isNode || isBun) {
          process.exit(1);
        }
      } catch {
        throw new Error("Benchmarks failed");
      }
    }
  }
}

class TreeNode {
  constructor(item, depth = 0) {
    this.item = item;
    this.left = null;
    this.right = null;
    if (depth > 0) {
      this.left = new TreeNode(2 * item - 1, depth - 1);
      this.right = new TreeNode(2 * item, depth - 1);
    }
  }

  static create(item, depth) {
    return new TreeNode(item, depth - 1);
  }

  check() {
    if (!this.left || !this.right) {
      return this.item;
    }
    return this.left.check() - this.right.check() + this.item;
  }
}

class TreeNodeObj {
  constructor(item, depth) {
    this.item = item;
    this.left = null;
    this.right = null;
    if (depth > 0) {
      const shift = 1 << (depth - 1);
      this.left = new TreeNodeObj(item - shift, depth - 1);
      this.right = new TreeNodeObj(item + shift, depth - 1);
    }
  }

  sum() {
    let total = (this.item >>> 0) + 1;
    if (this.left) total += this.left.sum();
    if (this.right) total += this.right.sum();
    return total >>> 0;
  }
}

class BinarytreesObj extends Benchmark {
  constructor() {
    super();
    this.n = Number(Helper.configI64(this.name, "depth"));
    this.result = 0;
  }

  run(_iteration_id) {
    const root = new TreeNodeObj(0, this.n);
    this.result = (this.result + root.sum()) >>> 0;
  }

  checksum() {
    return this.result >>> 0;
  }

  get name() {
    return "Binarytrees::Obj";
  }
}

class TreeArena {
  constructor() {
    this.nodes = [];
  }

  build(item, depth) {
    const idx = this.nodes.length;
    this.nodes.push({ item, left: -1, right: -1 });

    if (depth > 0) {
      const shift = 1 << (depth - 1);
      const leftIdx = this.build(item - shift, depth - 1);
      const rightIdx = this.build(item + shift, depth - 1);
      const node = this.nodes[idx];
      node.left = leftIdx;
      node.right = rightIdx;
    }

    return idx;
  }

  sum(idx) {
    const node = this.nodes[idx];
    let total = (node.item >>> 0) + 1;

    if (node.left >= 0) total += this.sum(node.left);
    if (node.right >= 0) total += this.sum(node.right);

    return total >>> 0;
  }

  clear() {
    this.nodes = [];
  }
}

class BinarytreesArena extends Benchmark {
  constructor() {
    super();
    this.n = Number(Helper.configI64(this.name, "depth"));
    this.result = 0;
  }

  run(_iteration_id) {
    var arena = new TreeArena();
    const rootIdx = arena.build(0, this.n);
    this.result = (this.result + arena.sum(rootIdx)) >>> 0;
  }

  checksum() {
    return this.result >>> 0;
  }

  get name() {
    return "Binarytrees::Arena";
  }
}

class Tape {
  constructor() {
    this.tape = new Uint8Array(30000);
    this.pos = 0;
  }

  get() {
    return this.tape[this.pos];
  }

  inc() {
    this.tape[this.pos] = (this.tape[this.pos] + 1) & 255;
  }

  dec() {
    this.tape[this.pos] = (this.tape[this.pos] - 1) & 255;
  }

  advance() {
    this.pos++;
    if (this.pos >= this.tape.length) {
      const newTape = new Uint8Array(this.tape.length + 1);
      newTape.set(this.tape);
      this.tape = newTape;
    }
  }

  devance() {
    if (this.pos > 0) {
      this.pos--;
    }
  }
}

const BF_CHAR_PLUS = "+".charCodeAt(0);
const BF_CHAR_MINUS = "-".charCodeAt(0);
const BF_CHAR_LESS = "<".charCodeAt(0);
const BF_CHAR_GREATER = ">".charCodeAt(0);
const BF_CHAR_LEFT_BRACKET = "[".charCodeAt(0);
const BF_CHAR_RIGHT_BRACKET = "]".charCodeAt(0);
const BF_CHAR_DOT = ".".charCodeAt(0);
const BF_CHAR_COMMA = ",".charCodeAt(0);

class Program {
  constructor(text) {
    const valid = new Set(["[", "]", "<", ">", "+", "-", ",", "."]);
    const bytes = [];
    for (let i = 0; i < text.length; i++) {
      const c = text[i];
      if (valid.has(c)) {
        bytes.push(c.charCodeAt(0));
      }
    }

    this.commands = new Uint8Array(bytes);
    this.jumps = new Array(this.commands.length).fill(0);
    const stack = [];

    for (let i = 0; i < this.commands.length; i++) {
      const cmd = this.commands[i];
      if (cmd === BF_CHAR_LEFT_BRACKET) {
        stack.push(i);
      } else if (cmd === BF_CHAR_RIGHT_BRACKET && stack.length > 0) {
        const start = stack.pop();
        this.jumps[start] = i;
        this.jumps[i] = start;
      }
    }
  }

  run() {
    let result = 0;
    const tape = new Tape();
    let pc = 0;
    const commands = this.commands;
    const jumps = this.jumps;

    while (pc < commands.length) {
      const cmd = commands[pc];

      switch (cmd) {
        case BF_CHAR_PLUS:
          tape.inc();
          break;
        case BF_CHAR_MINUS:
          tape.dec();
          break;
        case BF_CHAR_GREATER:
          tape.advance();
          break;
        case BF_CHAR_LESS:
          tape.devance();
          break;
        case BF_CHAR_LEFT_BRACKET:
          if (tape.get() === 0) {
            pc = jumps[pc];
          }
          break;
        case BF_CHAR_RIGHT_BRACKET:
          if (tape.get() !== 0) {
            pc = jumps[pc];
          }
          break;
        case BF_CHAR_DOT:
          result = ((result << 2) + tape.get()) >>> 0;
          break;
      }

      pc++;
    }

    return result;
  }
}

class BrainfuckArray extends Benchmark {
  constructor() {
    super();
    this.programText = Helper.configS(this.name, "program");
    this.warmupText = Helper.configS(this.name, "warmup_program");
    this.resultValue = 0;
  }

  warmup() {
    const prepareIters = this.warmupIterations;
    for (let i = 0; i < prepareIters; i++) {
      new Program(this.warmupText).run();
    }
  }

  run(_iteration_id) {
    const result = new Program(this.programText).run();
    this.resultValue = (this.resultValue + result) >>> 0;
  }

  checksum() {
    return this.resultValue >>> 0;
  }

  get name() {
    return "Brainfuck::Array";
  }
}

const OpType = {
  INC: 0,
  DEC: 1,
  NEXT: 2,
  PREV: 3,
  PRINT: 4,
  LOOP: 5,
};

class Tape2 {
  constructor() {
    this.tape = new Uint8Array(30000);
    this.pos = 0;
  }

  get() {
    return this.tape[this.pos];
  }

  inc() {
    this.tape[this.pos]++;
  }

  dec() {
    this.tape[this.pos]--;
  }

  next() {
    this.pos++;
    if (this.pos >= this.tape.length) {
      const newTape = new Uint8Array(this.tape.length + 1);
      newTape.set(this.tape);
      this.tape = newTape;
    }
  }

  prev() {
    if (this.pos > 0) {
      this.pos--;
    }
  }
}

class Program2 {
  constructor(code) {
    this.ops = this.parse(code);
    this.resultValue = 0;
  }

  run() {
    this.runOps(this.ops, new Tape2());
    return this.resultValue >>> 0;
  }

  runOps(program, tape) {
    for (const op of program) {
      switch (op.type) {
        case OpType.INC:
          tape.inc();
          break;
        case OpType.DEC:
          tape.dec();
          break;
        case OpType.NEXT:
          tape.next();
          break;
        case OpType.PREV:
          tape.prev();
          break;
        case OpType.PRINT:
          this.resultValue = (this.resultValue << 2) + tape.get();
          break;
        case OpType.LOOP:
          while (tape.get() !== 0) {
            this.runOps(op.loop, tape);
          }
          break;
      }
    }
  }

  parse(code) {
    const chars = Array.from(code);
    return this.parseSequence(chars, 0)[0];
  }

  parseSequence(chars, index) {
    const result = [];
    let i = index;

    while (i < chars.length) {
      const c = chars[i];
      i++;

      let op = null;

      switch (c) {
        case "+":
          op = { type: OpType.INC };
          break;
        case "-":
          op = { type: OpType.DEC };
          break;
        case ">":
          op = { type: OpType.NEXT };
          break;
        case "<":
          op = { type: OpType.PREV };
          break;
        case ".":
          op = { type: OpType.PRINT };
          break;
        case "[":
          const [loopOps, newIndex] = this.parseSequence(chars, i);
          op = { type: OpType.LOOP, loop: loopOps };
          i = newIndex;
          break;
        case "]":
          return [result, i];
        default:
          continue;
      }

      if (op) {
        result.push(op);
      }
    }

    return [result, i];
  }
}

class BrainfuckRecursion extends Benchmark {
  constructor() {
    super();
    this.text = Helper.configS(this.name, "program");
    this.resultValue = 0;
  }

  warmup() {
    const warmupProgram = Helper.configS(this.name, "warmup_program");
    for (let i = 0; i < this.warmupIterations; i++) {
      const program = new Program2(warmupProgram);
      program.run();
    }
  }

  run(_iteration_id) {
    const program = new Program2(this.text);
    this.resultValue = (this.resultValue + program.run()) >>> 0;
  }

  checksum() {
    return this.resultValue >>> 0;
  }

  get name() {
    return "Brainfuck::Recursion";
  }
}

class Fannkuchredux extends Benchmark {
  constructor() {
    super();
    this.n = Number(Helper.configI64(this.name, "n"));
    this.resultValue = 0;
  }

  fannkuchredux(n) {
    const perm1 = new Int32Array(n);
    for (let i = 0; i < n; ++i) perm1[i] = i;

    const perm = new Int32Array(n);
    const count = new Int32Array(n);

    let maxFlipsCount = 0;
    let permCount = 0;
    let checksum = 0;
    let r = n;

    while (true) {
      while (r > 1) {
        count[r - 1] = r;
        r--;
      }

      perm.set(perm1);

      let flipsCount = 0;
      let k = perm[0];

      while (k !== 0) {
        let i = 0;
        let j = k;
        while (i < j) {
          const temp = perm[i];
          perm[i] = perm[j];
          perm[j] = temp;
          i++;
          j--;
        }

        flipsCount++;
        k = perm[0];
      }

      maxFlipsCount = Math.max(maxFlipsCount, flipsCount);
      checksum += (permCount & 1) === 0 ? flipsCount : -flipsCount;

      while (true) {
        if (r === n) {
          return [checksum, maxFlipsCount];
        }

        const first = perm1[0];
        for (let i = 0; i < r; i++) {
          perm1[i] = perm1[i + 1];
        }
        perm1[r] = first;

        count[r]--;
        if (count[r] > 0) break;
        r++;
      }

      permCount++;
    }
  }

  run(_iteration_id) {
    const [checksum, maxFlipsCount] = this.fannkuchredux(this.n);
    this.resultValue += checksum * 100 + maxFlipsCount;
  }

  checksum() {
    return this.resultValue;
  }

  get name() {
    return "CLBG::Fannkuchredux";
  }
}

class Mandelbrot extends Benchmark {
  static ITER = 50;
  static LIMIT = 2.0;

  constructor() {
    super();
    this.w = Number(Helper.configI64(this.name, "w"));
    this.h = Number(Helper.configI64(this.name, "h"));
    this.resultBytes = [];
  }

  run(_iteration_id) {
    const header = `P4\n${this.w} ${this.h}\n`;

    this.resultBytes.push(...Array.from(header, (c) => c.charCodeAt(0)));

    let bitNum = 0;
    let byteAcc = 0;

    for (let y = 0; y < this.h; y++) {
      const ci = (2.0 * y) / this.h - 1.0;
      for (let x = 0; x < this.w; x++) {
        let zr = 0.0;
        let zi = 0.0;
        let tr = 0.0;
        let ti = 0.0;

        const cr = (2.0 * x) / this.w - 1.5;

        let i = 0;
        while (i < Mandelbrot.ITER && tr + ti <= Mandelbrot.LIMIT * Mandelbrot.LIMIT) {
          zi = 2.0 * zr * zi + ci;
          zr = tr - ti + cr;
          tr = zr * zr;
          ti = zi * zi;
          i++;
        }

        byteAcc <<= 1;
        if (tr + ti <= Mandelbrot.LIMIT * Mandelbrot.LIMIT) {
          byteAcc |= 0x01;
        }
        bitNum++;

        if (bitNum === 8) {
          this.resultBytes.push(byteAcc);
          byteAcc = 0;
          bitNum = 0;
        } else if (x === this.w - 1) {
          byteAcc <<= 8 - (this.w % 8);
          this.resultBytes.push(byteAcc);
          byteAcc = 0;
          bitNum = 0;
        }
      }
    }
  }

  checksum() {
    const bytes = new Uint8Array(this.resultBytes);
    return Helper.checksumBytes(bytes);
  }

  get name() {
    return "CLBG::Mandelbrot";
  }
}

class MatmulBase extends Benchmark {
  constructor(name) {
    super();
    this.n = 0;
    this.resultValue = 0;
    this.a = [];
    this.b = [];
  }

  prepare() {
    this.n = Number(Helper.configI64(this.name, "n"));
    this.a = this.matgen(this.n);
    this.b = this.matgen(this.n);
    this.resultValue = 0;
  }

  matgen(n) {
    const tmp = 1.0 / n / n;
    const a = Array(n)
      .fill(0)
      .map(() => Array(n).fill(0));

    for (let i = 0; i < n; i++) {
      for (let j = 0; j < n; j++) {
        a[i][j] = tmp * (i - j) * (i + j);
      }
    }

    return a;
  }

  transpose(b) {
    const n = b.length;
    const bT = Array(n)
      .fill(0)
      .map(() => Array(n).fill(0));

    for (let i = 0; i < n; i++) {
      for (let j = 0; j < n; j++) {
        bT[j][i] = b[i][j];
      }
    }

    return bT;
  }

  matmulSequential(a, b) {
    const n = a.length;
    const bT = this.transpose(b);
    const c = Array(n)
      .fill(0)
      .map(() => Array(n).fill(0));

    for (let i = 0; i < n; i++) {
      const ai = a[i];
      const ci = c[i];

      for (let j = 0; j < n; j++) {
        const bTj = bT[j];
        let s = 0.0;

        for (let k = 0; k < n; k++) {
          s += ai[k] * bTj[k];
        }

        ci[j] = s;
      }
    }

    return c;
  }

  matmulParallel(a, b, numThreads) {
    const n = a.length;
    const bT = this.transpose(b);
    const c = Array(n)
      .fill(0)
      .map(() => Array(n).fill(0));

    const rowsPerPart = Math.ceil(n / numThreads);

    for (let part = 0; part < numThreads; part++) {
      const startRow = part * rowsPerPart;
      const endRow = Math.min(startRow + rowsPerPart, n);

      for (let i = startRow; i < endRow; i++) {
        const ai = a[i];
        const ci = c[i];

        for (let j = 0; j < n; j++) {
          let sum = 0.0;
          const bTj = bT[j];

          for (let k = 0; k < n; k++) {
            sum += ai[k] * bTj[k];
          }

          ci[j] = sum;
        }
      }
    }

    return c;
  }

  checksum() {
    return this.resultValue >>> 0;
  }
}

class Matmul1T extends MatmulBase {
  constructor() {
    super("Matmul::Single");
  }

  run(_iteration_id) {
    const c = this.matmulSequential(this.a, this.b);
    const value = c[this.n >> 1][this.n >> 1];
    this.resultValue = (this.resultValue + Helper.checksumFloat(value)) & 0xffffffff;
  }

  get name() {
    return "Matmul::Single";
  }
}

class Matmul4T extends MatmulBase {
  constructor() {
    super("Matmul::T4");
  }

  run(_iteration_id) {
    const c = this.matmulParallel(this.a, this.b, 4);
    const value = c[this.n >> 1][this.n >> 1];
    this.resultValue = (this.resultValue + Helper.checksumFloat(value)) & 0xffffffff;
  }

  get name() {
    return "Matmul::T4";
  }
}

class Matmul8T extends MatmulBase {
  constructor() {
    super("Matmul::T8");
  }

  run(_iteration_id) {
    const c = this.matmulParallel(this.a, this.b, 8);
    const value = c[this.n >> 1][this.n >> 1];
    this.resultValue = (this.resultValue + Helper.checksumFloat(value)) & 0xffffffff;
  }

  get name() {
    return "Matmul::T8";
  }
}

class Matmul16T extends MatmulBase {
  constructor() {
    super("Matmul::T16");
  }

  run(_iteration_id) {
    const c = this.matmulParallel(this.a, this.b, 16);
    const value = c[this.n >> 1][this.n >> 1];
    this.resultValue = (this.resultValue + Helper.checksumFloat(value)) & 0xffffffff;
  }

  get name() {
    return "Matmul::T16";
  }
}

const SOLAR_MASS = 4 * Math.PI * Math.PI;
const DAYS_PER_YEAR = 365.24;

class Planet {
  constructor(x, y, z, vx, vy, vz, mass) {
    this.x = x;
    this.y = y;
    this.z = z;
    this.vx = vx * DAYS_PER_YEAR;
    this.vy = vy * DAYS_PER_YEAR;
    this.vz = vz * DAYS_PER_YEAR;
    this.mass = mass * SOLAR_MASS;
  }

  moveFromI(bodies, nbodies, dt, i) {
    while (i < nbodies) {
      const b2 = bodies[i];
      const dx = this.x - b2.x;
      const dy = this.y - b2.y;
      const dz = this.z - b2.z;

      const distance = Math.sqrt(dx * dx + dy * dy + dz * dz);
      const mag = dt / (distance * distance * distance);
      const bMassMag = this.mass * mag;
      const b2MassMag = b2.mass * mag;

      this.vx -= dx * b2MassMag;
      this.vy -= dy * b2MassMag;
      this.vz -= dz * b2MassMag;
      b2.vx += dx * bMassMag;
      b2.vy += dy * bMassMag;
      b2.vz += dz * bMassMag;
      i++;
    }

    this.x += dt * this.vx;
    this.y += dt * this.vy;
    this.z += dt * this.vz;
  }
}

class Nbody extends Benchmark {
  static SOLAR_MASS = SOLAR_MASS;
  static DAYS_PER_YEAR = DAYS_PER_YEAR;

  static BODIES = [
    new Planet(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0),
    new Planet(
      4.8414314424647209,
      -1.16032004402742839,
      -1.03622044471123109e-1,
      1.66007664274403694e-3,
      7.69901118419740425e-3,
      -6.90460016972063023e-5,
      9.54791938424326609e-4,
    ),
    new Planet(
      8.34336671824457987,
      4.12479856412430479,
      -4.03523417114321381e-1,
      -2.76742510726862411e-3,
      4.99852801234917238e-3,
      2.30417297573763929e-5,
      2.85885980666130812e-4,
    ),
    new Planet(
      1.2894369562139131e1,
      -1.51111514016986312e1,
      -2.23307578892655734e-1,
      2.96460137564761618e-3,
      2.3784717395948095e-3,
      -2.96589568540237556e-5,
      4.36624404335156298e-5,
    ),
    new Planet(
      1.53796971148509165e1,
      -2.59193146099879641e1,
      1.79258772950371181e-1,
      2.68067772490389322e-3,
      1.62824170038242295e-3,
      -9.5159225451971587e-5,
      5.15138902046611451e-5,
    ),
  ];

  constructor() {
    super();
    this.bodies = Nbody.BODIES.map(
      (p) =>
        new Planet(
          p.x,
          p.y,
          p.z,
          p.vx / DAYS_PER_YEAR,
          p.vy / DAYS_PER_YEAR,
          p.vz / DAYS_PER_YEAR,
          p.mass / SOLAR_MASS,
        ),
    );
    this.resultValue = 0n;
    this.v1 = 0;
  }

  energy(bodies) {
    let e = 0.0;
    const nbodies = bodies.length;

    for (let i = 0; i < nbodies; i++) {
      const b = bodies[i];
      e += 0.5 * b.mass * (b.vx * b.vx + b.vy * b.vy + b.vz * b.vz);

      for (let j = i + 1; j < nbodies; j++) {
        const b2 = bodies[j];
        const dx = b.x - b2.x;
        const dy = b.y - b2.y;
        const dz = b.z - b2.z;
        const distance = Math.sqrt(dx * dx + dy * dy + dz * dz);
        e -= (b.mass * b2.mass) / distance;
      }
    }

    return e;
  }

  offsetMomentum(bodies) {
    let px = 0.0,
      py = 0.0,
      pz = 0.0;

    for (const b of bodies) {
      const m = b.mass;
      px += b.vx * m;
      py += b.vy * m;
      pz += b.vz * m;
    }

    const b = bodies[0];
    b.vx = -px / SOLAR_MASS;
    b.vy = -py / SOLAR_MASS;
    b.vz = -pz / SOLAR_MASS;
  }

  prepare() {
    this.offsetMomentum(this.bodies);
    this.v1 = this.energy(this.bodies);
  }

  run(_iteration_id) {
    const nbodies = this.bodies.length;

    let j = 0;
    while (j < 1000) {
      let i = 0;
      while (i < nbodies) {
        const b = this.bodies[i];
        b.moveFromI(this.bodies, nbodies, 0.01, i + 1);
        i++;
      }
      j++;
    }
  }

  checksum() {
    const v2 = this.energy(this.bodies);
    const checksum1 = Helper.checksumFloat(this.v1);
    const checksum2 = Helper.checksumFloat(v2);

    return (checksum1 << 5) & checksum2 & 0xffffffff;
  }

  get name() {
    return "CLBG::Nbody";
  }
}

class Spectralnorm extends Benchmark {
  constructor() {
    super();
    this.size = Number(Helper.configI64(this.name, "size"));
    this.u = new Array(this.size).fill(1.0);
    this.v = new Array(this.size).fill(1.0);
  }

  evalA(i, j) {
    return 1.0 / (((i + j) * (i + j + 1)) / 2.0 + i + 1.0);
  }

  evalATimesU(u) {
    const n = u.length;
    const result = new Array(n).fill(0);

    for (let i = 0; i < n; i++) {
      let v = 0.0;
      for (let j = 0; j < n; j++) {
        v += this.evalA(i, j) * u[j];
      }
      result[i] = v;
    }

    return result;
  }

  evalAtTimesU(u) {
    const n = u.length;
    const result = new Array(n).fill(0);

    for (let i = 0; i < n; i++) {
      let v = 0.0;
      for (let j = 0; j < n; j++) {
        v += this.evalA(j, i) * u[j];
      }
      result[i] = v;
    }

    return result;
  }

  evalAtATimesU(u) {
    return this.evalAtTimesU(this.evalATimesU(u));
  }

  run(_iteration_id) {
    this.v = this.evalAtATimesU(this.u);
    this.u = this.evalAtATimesU(this.v);
  }

  checksum() {
    let vBv = 0.0;
    let vv = 0.0;

    for (let i = 0; i < this.size; i++) {
      vBv += this.u[i] * this.v[i];
      vv += this.v[i] * this.v[i];
    }

    const result = Math.sqrt(vBv / vv);
    return Helper.checksumFloat(result);
  }

  get name() {
    return "CLBG::Spectralnorm";
  }
}

class Base64Encode extends Benchmark {
  constructor() {
    super();
    this.n = Number(Helper.configI64(this.name, "size"));
    this.str = "";
    this.str2 = "";
    this.resultValue = 0;
  }

  prepare() {
    this.str = "a".repeat(this.n);
    this.str2 = btoa(this.str);
  }

  run(_iteration_id) {
    this.str2 = btoa(this.str);
    this.resultValue = (this.resultValue + this.str2.length) >>> 0;
  }

  checksum() {
    const output = `encode ${this.str.slice(0, 4)}... to ${this.str2.slice(0, 4)}...: ${this.resultValue}`;
    return Helper.checksumString(output);
  }

  get name() {
    return "Base64::Encode";
  }
}

class Base64Decode extends Benchmark {
  constructor() {
    super();
    this.n = Number(Helper.configI64(this.name, "size"));
    this.str2 = "";
    this.str3 = "";
    this.resultValue = 0;
  }

  prepare() {
    const str = "a".repeat(this.n);
    this.str2 = btoa(str);
    this.str3 = atob(this.str2);
  }

  run(_iteration_id) {
    this.str3 = atob(this.str2);
    this.resultValue = (this.resultValue + this.str3.length) >>> 0;
  }

  checksum() {
    const output = `decode ${this.str2.slice(0, 4)}... to ${this.str3.slice(0, 4)}...: ${this.resultValue}`;
    return Helper.checksumString(output);
  }

  get name() {
    return "Base64::Decode";
  }
}

class JsonGenerate extends Benchmark {
  constructor() {
    super();
    this.n = Number(Helper.configI64(this.name, "coords"));
    this.data = [];
    this.text = "";
    this.result = 0;
  }

  prepare() {
    this.data = [];

    for (let i = 0; i < this.n; i++) {
      this.data.push({
        x: parseFloat(Helper.nextFloat().toFixed(8)),
        y: parseFloat(Helper.nextFloat().toFixed(8)),
        z: parseFloat(Helper.nextFloat().toFixed(8)),
        name: `${Helper.nextFloat().toFixed(7)} ${Helper.nextInt(10000)}`,
        opts: {
          1: [1, true],
        },
      });
    }
  }

  run(_iteration_id) {
    const jsonData = {
      coordinates: this.data,
      info: "some info",
    };

    this.text = JSON.stringify(jsonData, null, 0);

    if (this.text.startsWith('{"coordinates":')) {
      this.result++;
    }
  }

  getText() {
    return this.text;
  }

  checksum() {
    return this.result >>> 0;
  }

  get name() {
    return "Json::Generate";
  }
}

class JsonParseDom extends Benchmark {
  constructor() {
    super();
    this.text = "";
    this.resultValue = 0;
  }

  prepare() {
    const jsonGen = new JsonGenerate();
    jsonGen.n = Number(Helper.configI64(this.name, "coords"));
    jsonGen.prepare();
    jsonGen.run(0);
    this.text = jsonGen.getText();
  }

  calc(text) {
    const json = JSON.parse(text);
    const coordinates = json.coordinates;
    const len = coordinates.length;

    let x = 0;
    let y = 0;
    let z = 0;

    for (const coord of coordinates) {
      x += parseFloat(coord.x);
      y += parseFloat(coord.y);
      z += parseFloat(coord.z);
    }

    return [x / len, y / len, z / len];
  }

  run(_iteration_id) {
    const [x, y, z] = this.calc(this.text);

    this.resultValue = (this.resultValue + Helper.checksumFloat(x)) & 0xffffffff;
    this.resultValue = (this.resultValue + Helper.checksumFloat(y)) & 0xffffffff;
    this.resultValue = (this.resultValue + Helper.checksumFloat(z)) & 0xffffffff;
  }

  checksum() {
    return this.resultValue >>> 0;
  }

  get name() {
    return "Json::ParseDom";
  }
}

class JsonParseMapping extends Benchmark {
  constructor() {
    super();
    this.text = "";
    this.resultValue = 0;
  }

  prepare() {
    const jsonGen = new JsonGenerate();
    jsonGen.n = Number(Helper.configI64(this.name, "coords"));
    jsonGen.prepare();
    jsonGen.run(0);
    this.text = jsonGen.getText();
  }

  calc(text) {
    const data = JSON.parse(text);
    const coordinates = data.coordinates;
    const len = coordinates.length;

    let x = 0;
    let y = 0;
    let z = 0;

    for (const coord of coordinates) {
      x += coord.x;
      y += coord.y;
      z += coord.z;
    }

    return { x: x / len, y: y / len, z: z / len };
  }

  run(_iteration_id) {
    const coord = this.calc(this.text);

    this.resultValue = (this.resultValue + Helper.checksumFloat(coord.x)) & 0xffffffff;
    this.resultValue = (this.resultValue + Helper.checksumFloat(coord.y)) & 0xffffffff;
    this.resultValue = (this.resultValue + Helper.checksumFloat(coord.z)) & 0xffffffff;
  }

  checksum() {
    return this.resultValue >>> 0;
  }

  get name() {
    return "Json::ParseMapping";
  }
}

class Sieve extends Benchmark {
  constructor() {
    super();
    this.limit = Helper.configI64(this.name, "limit");
    this.checksumValue = 0;
  }

  generatePrimes(limit) {
    const primes = new Uint8Array(limit + 1);
    primes.fill(1);
    primes[0] = 0;
    primes[1] = 0;

    const sqrtLimit = Math.floor(Math.sqrt(limit));

    for (let p = 2; p <= sqrtLimit; p++) {
      if (primes[p] === 1) {
        for (let multiple = p * p; multiple <= limit; multiple += p) {
          primes[multiple] = 0;
        }
      }
    }

    let lastPrime = 2;
    let count = 1;

    for (let n = 3; n <= limit; n += 2) {
      if (primes[n] === 1) {
        lastPrime = n;
        count++;
      }
    }

    this.checksumValue = (this.checksumValue + lastPrime + count) & 0xffffffff;
  }

  run(_iteration_id) {
    this.generatePrimes(Number(this.limit));
  }

  checksum() {
    return this.checksumValue;
  }

  get name() {
    return "Etc::Sieve";
  }
}

class TextRaytracerVector {
  constructor(x, y, z) {
    this.x = x;
    this.y = y;
    this.z = z;
  }

  scale(s) {
    return new TextRaytracerVector(this.x * s, this.y * s, this.z * s);
  }

  add(other) {
    return new TextRaytracerVector(this.x + other.x, this.y + other.y, this.z + other.z);
  }

  subtract(other) {
    return new TextRaytracerVector(this.x - other.x, this.y - other.y, this.z - other.z);
  }

  dot(other) {
    return this.x * other.x + this.y * other.y + this.z * other.z;
  }

  magnitude() {
    return Math.sqrt(this.dot(this));
  }

  normalize() {
    const mag = this.magnitude();
    return this.scale(1.0 / mag);
  }
}

class TextRaytracerRay {
  constructor(orig, dir) {
    this.orig = orig;
    this.dir = dir;
  }
}

class TextRaytracerColor {
  constructor(r, g, b) {
    this.r = r;
    this.g = g;
    this.b = b;
  }

  scale(s) {
    return new TextRaytracerColor(this.r * s, this.g * s, this.b * s);
  }

  add(other) {
    return new TextRaytracerColor(this.r + other.r, this.g + other.g, this.b + other.b);
  }
}

class TextRaytracerSphere {
  constructor(center, radius, color) {
    this.center = center;
    this.radius = radius;
    this.color = color;
  }

  getNormal(pt) {
    return pt.subtract(this.center).normalize();
  }
}

class TextRaytracerLight {
  constructor(position, color) {
    this.position = position;
    this.color = color;
  }
}

class TextRaytracerHit {
  constructor(obj, value) {
    this.obj = obj;
    this.value = value;
  }
}

class TextRaytracer extends Benchmark {
  static WHITE = new TextRaytracerColor(1.0, 1.0, 1.0);
  static RED = new TextRaytracerColor(1.0, 0.0, 0.0);
  static GREEN = new TextRaytracerColor(0.0, 1.0, 0.0);
  static BLUE = new TextRaytracerColor(0.0, 0.0, 1.0);

  static LIGHT1 = new TextRaytracerLight(
    new TextRaytracerVector(0.7, -1.0, 1.7),
    TextRaytracer.WHITE,
  );

  static SCENE = [
    new TextRaytracerSphere(new TextRaytracerVector(-1.0, 0.0, 3.0), 0.3, TextRaytracer.RED),
    new TextRaytracerSphere(new TextRaytracerVector(0.0, 0.0, 3.0), 0.8, TextRaytracer.GREEN),
    new TextRaytracerSphere(new TextRaytracerVector(1.0, 0.0, 3.0), 0.4, TextRaytracer.BLUE),
  ];

  static LUT = [".", "-", "+", "*", "X", "M"];

  constructor() {
    super();
    this.w = Number(Helper.configI64(this.name, "w"));
    this.h = Number(Helper.configI64(this.name, "h"));
    this.resultValue = 0;
  }

  shadePixel(ray, obj, tval) {
    const pi = ray.orig.add(ray.dir.scale(tval));
    const color = this.diffuseShading(pi, obj, TextRaytracer.LIGHT1);
    const col = (color.r + color.g + color.b) / 3.0;
    return Math.floor(col * 6.0);
  }

  intersectSphere(ray, center, radius) {
    const l = center.subtract(ray.orig);
    const tca = l.dot(ray.dir);

    if (tca < 0.0) {
      return null;
    }

    const d2 = l.dot(l) - tca * tca;
    const r2 = radius * radius;

    if (d2 > r2) {
      return null;
    }

    const thc = Math.sqrt(r2 - d2);
    const t0 = tca - thc;

    if (t0 > 10000) {
      return null;
    }

    return t0;
  }

  clamp(x, a, b) {
    if (x < a) return a;
    if (x > b) return b;
    return x;
  }

  diffuseShading(pi, obj, light) {
    const n = obj.getNormal(pi);
    const lam1 = light.position.subtract(pi).normalize().dot(n);
    const lam2 = this.clamp(lam1, 0.0, 1.0);
    return light.color.scale(lam2 * 0.5).add(obj.color.scale(0.3));
  }

  run(_iteration_id) {
    let res = 0;
    const fw = this.w;
    const fh = this.h;

    for (let j = 0; j < this.h; j++) {
      for (let i = 0; i < this.w; i++) {
        const ray = new TextRaytracerRay(
          new TextRaytracerVector(0.0, 0.0, 0.0),
          new TextRaytracerVector((i - fw / 2.0) / fw, (j - fh / 2.0) / fh, 1.0).normalize(),
        );

        let hit = null;

        for (const obj of TextRaytracer.SCENE) {
          const ret = this.intersectSphere(ray, obj.center, obj.radius);
          if (ret !== null) {
            hit = new TextRaytracerHit(obj, ret);
            break;
          }
        }

        let pixel;
        if (hit) {
          const shadeIdx = this.shadePixel(ray, hit.obj, hit.value);
          pixel = TextRaytracer.LUT[Math.min(shadeIdx, TextRaytracer.LUT.length - 1)];
        } else {
          pixel = " ";
        }

        res += pixel.charCodeAt(0);
      }
    }

    this.resultValue = (this.resultValue + res) & 0xffffffff;
  }

  checksum() {
    return this.resultValue >>> 0;
  }

  get name() {
    return "Etc::TextRaytracer";
  }
}

class NeuralNetSynapse {
  constructor(sourceNeuron, destNeuron) {
    this.sourceNeuron = sourceNeuron;
    this.destNeuron = destNeuron;
    this.prevWeight = this.weight = Helper.nextFloat() * 2 - 1;
  }
}

class NeuralNetNeuron {
  static LEARNING_RATE = 1.0;
  static MOMENTUM = 0.3;

  constructor() {
    this.synapsesIn = [];
    this.synapsesOut = [];
    this.prevThreshold = this.threshold = Helper.nextFloat() * 2 - 1;
    this.error = 0;
    this.output = 0;
  }

  calculateOutput() {
    let activation = 0;
    for (const synapse of this.synapsesIn) {
      activation += synapse.weight * synapse.sourceNeuron.output;
    }
    activation -= this.threshold;

    this.output = 1.0 / (1.0 + Math.exp(-activation));
  }

  derivative() {
    return this.output * (1 - this.output);
  }

  outputTrain(rate, target) {
    this.error = (target - this.output) * this.derivative();
    this.updateWeights(rate);
  }

  hiddenTrain(rate) {
    let sum = 0;
    for (const synapse of this.synapsesOut) {
      sum += synapse.prevWeight * synapse.destNeuron.error;
    }
    this.error = sum * this.derivative();
    this.updateWeights(rate);
  }

  updateWeights(rate) {
    for (const synapse of this.synapsesIn) {
      const tempWeight = synapse.weight;
      synapse.weight +=
        rate * NeuralNetNeuron.LEARNING_RATE * this.error * synapse.sourceNeuron.output +
        NeuralNetNeuron.MOMENTUM * (synapse.weight - synapse.prevWeight);
      synapse.prevWeight = tempWeight;
    }

    const tempThreshold = this.threshold;
    this.threshold +=
      rate * NeuralNetNeuron.LEARNING_RATE * this.error * -1 +
      NeuralNetNeuron.MOMENTUM * (this.threshold - this.prevThreshold);
    this.prevThreshold = tempThreshold;
  }
}

class NeuralNetNetwork {
  constructor(inputs, hidden, outputs) {
    this.inputLayer = Array.from({ length: inputs }, () => new NeuralNetNeuron());
    this.hiddenLayer = Array.from({ length: hidden }, () => new NeuralNetNeuron());
    this.outputLayer = Array.from({ length: outputs }, () => new NeuralNetNeuron());

    for (const source of this.inputLayer) {
      for (const dest of this.hiddenLayer) {
        const synapse = new NeuralNetSynapse(source, dest);
        source.synapsesOut.push(synapse);
        dest.synapsesIn.push(synapse);
      }
    }

    for (const source of this.hiddenLayer) {
      for (const dest of this.outputLayer) {
        const synapse = new NeuralNetSynapse(source, dest);
        source.synapsesOut.push(synapse);
        dest.synapsesIn.push(synapse);
      }
    }
  }

  train(inputs, targets) {
    this.feedForward(inputs);

    for (let i = 0; i < this.outputLayer.length; i++) {
      this.outputLayer[i].outputTrain(0.3, targets[i]);
    }

    for (const neuron of this.hiddenLayer) {
      neuron.hiddenTrain(0.3);
    }
  }

  feedForward(inputs) {
    for (let i = 0; i < this.inputLayer.length; i++) {
      this.inputLayer[i].output = inputs[i];
    }

    for (const neuron of this.hiddenLayer) {
      neuron.calculateOutput();
    }

    for (const neuron of this.outputLayer) {
      neuron.calculateOutput();
    }
  }

  currentOutputs() {
    return this.outputLayer.map((neuron) => neuron.output);
  }
}

class NeuralNet extends Benchmark {
  static INPUT_00 = [0, 0];
  static INPUT_01 = [0, 1];
  static INPUT_10 = [1, 0];
  static INPUT_11 = [1, 1];
  static TARGET_0 = [0];
  static TARGET_1 = [1];

  constructor() {
    super();
    this.xor = new NeuralNetNetwork(0, 0, 0);
  }

  prepare() {
    this.xor = new NeuralNetNetwork(2, 10, 1);
  }

  run(_iteration_id) {
    for (let i = 0; i < 1000; i++) {
      this.xor.train(NeuralNet.INPUT_00, NeuralNet.TARGET_0);
      this.xor.train(NeuralNet.INPUT_10, NeuralNet.TARGET_1);
      this.xor.train(NeuralNet.INPUT_01, NeuralNet.TARGET_1);
      this.xor.train(NeuralNet.INPUT_11, NeuralNet.TARGET_0);
    }
  }

  checksum() {
    const results = [];

    this.xor.feedForward(NeuralNet.INPUT_00);
    results.push(...this.xor.currentOutputs());

    this.xor.feedForward(NeuralNet.INPUT_01);
    results.push(...this.xor.currentOutputs());

    this.xor.feedForward(NeuralNet.INPUT_10);
    results.push(...this.xor.currentOutputs());

    this.xor.feedForward(NeuralNet.INPUT_11);
    results.push(...this.xor.currentOutputs());

    const sum = results.reduce((a, b) => a + b, 0);
    return Helper.checksumFloat(sum);
  }

  get name() {
    return "Etc::NeuralNet";
  }
}

class SortBenchmark extends Benchmark {
  constructor() {
    super();
    this.data = [];
    this.size = Number(Helper.configI64(this.name, "size"));
    this.resultValue = 0;
  }

  prepare() {
    this.data = [];
    for (let i = 0; i < this.size; i++) {
      this.data.push(Helper.nextInt(1000000));
    }
  }

  run(_iteration_id) {
    this.resultValue = (this.resultValue + this.data[Helper.nextInt(this.size)]) & 0xffffffff;
    const t = this.test();
    this.resultValue = (this.resultValue + t[Helper.nextInt(this.size)]) & 0xffffffff;
  }

  checksum() {
    return this.resultValue;
  }
}

class SortQuick extends SortBenchmark {
  test() {
    const arr = [...this.data];
    this.quickSort(arr, 0, arr.length - 1);
    return arr;
  }

  quickSort(arr, low, high) {
    if (low >= high) return;

    const pivot = arr[Math.floor((low + high) / 2)];
    let i = low;
    let j = high;

    while (i <= j) {
      while (arr[i] < pivot) i++;
      while (arr[j] > pivot) j--;

      if (i <= j) {
        [arr[i], arr[j]] = [arr[j], arr[i]];
        i++;
        j--;
      }
    }

    this.quickSort(arr, low, j);
    this.quickSort(arr, i, high);
  }

  get name() {
    return "Sort::Quick";
  }
}

class SortMerge extends SortBenchmark {
  test() {
    const arr = [...this.data];
    this.mergeSortInplace(arr);
    return arr;
  }

  mergeSortInplace(arr) {
    const temp = new Array(arr.length).fill(0);
    this.mergeSortHelper(arr, temp, 0, arr.length - 1);
  }

  mergeSortHelper(arr, temp, left, right) {
    if (left >= right) return;

    const mid = Math.floor((left + right) / 2);
    this.mergeSortHelper(arr, temp, left, mid);
    this.mergeSortHelper(arr, temp, mid + 1, right);
    this.merge(arr, temp, left, mid, right);
  }

  merge(arr, temp, left, mid, right) {
    for (let i = left; i <= right; i++) {
      temp[i] = arr[i];
    }

    let i = left;
    let j = mid + 1;
    let k = left;

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

  get name() {
    return "Sort::Merge";
  }
}

class SortSelf extends SortBenchmark {
  test() {
    const arr = [...this.data];
    arr.sort((a, b) => a - b);
    return arr;
  }

  get name() {
    return "Sort::Self";
  }
}

class GraphPathGraph {
  constructor(vertices, jumps = 3, jumpLen = 100) {
    this.vertices = vertices;
    this.jumps = jumps;
    this.jumpLen = jumpLen;
    this.adj = Array(vertices)
      .fill(0)
      .map(() => []);
  }

  addEdge(u, v) {
    this.adj[u].push(v);
    this.adj[v].push(u);
  }

  generateRandom() {
    for (let i = 1; i < this.vertices; i++) {
      this.addEdge(i, i - 1);
    }

    for (let v = 0; v < this.vertices; v++) {
      const numJumps = Helper.nextInt(this.jumps);
      for (let j = 0; j < numJumps; j++) {
        const offset = Helper.nextInt(this.jumpLen) - Math.floor(this.jumpLen / 2);
        const u = v + offset;

        if (u >= 0 && u < this.vertices && u !== v) {
          this.addEdge(v, u);
        }
      }
    }
  }

  getAdjacency() {
    return this.adj;
  }

  getVertices() {
    return this.vertices;
  }
}

class GraphPathBenchmark extends Benchmark {
  prepare() {
    const vertices = Number(Helper.configI64(this.name, "vertices"));
    const jumps = Number(Helper.configI64(this.name, "jumps"));
    const jumpLen = Number(Helper.configI64(this.name, "jump_len"));

    this.graph = new GraphPathGraph(vertices, jumps, jumpLen);
    this.graph.generateRandom();
    this.resultValue = 0;
  }

  checksum() {
    return this.resultValue >>> 0;
  }
}

class GraphPathBFS extends GraphPathBenchmark {
  run(_iteration_id) {
    const length = this.bfsShortestPath(0, this.graph.getVertices() - 1);
    this.resultValue += length;
  }

  bfsShortestPath(start, target) {
    if (start === target) return 0;

    const visited = new Uint8Array(this.graph.getVertices());
    const queue = [[start, 0]];
    visited[start] = 1;
    let head = 0;

    while (head < queue.length) {
      const [v, dist] = queue[head];
      head++;

      for (const neighbor of this.graph.getAdjacency()[v]) {
        if (neighbor === target) {
          return dist + 1;
        }

        if (visited[neighbor] === 0) {
          visited[neighbor] = 1;
          queue.push([neighbor, dist + 1]);
        }
      }
    }

    return -1;
  }

  get name() {
    return "Graph::BFS";
  }
}

class GraphPathDFS extends GraphPathBenchmark {
  run(_iteration_id) {
    const length = this.dfsFindPath(0, this.graph.getVertices() - 1);
    this.resultValue += length;
  }

  dfsFindPath(start, target) {
    if (start === target) return 0;

    const visited = new Uint8Array(this.graph.getVertices());
    const stack = [[start, 0]];
    let bestPath = Number.MAX_SAFE_INTEGER;

    while (stack.length > 0) {
      const [v, dist] = stack.pop();

      if (visited[v] === 1 || dist >= bestPath) continue;
      visited[v] = 1;

      for (const neighbor of this.graph.getAdjacency()[v]) {
        if (neighbor === target) {
          if (dist + 1 < bestPath) {
            bestPath = dist + 1;
          }
        } else if (visited[neighbor] === 0) {
          stack.push([neighbor, dist + 1]);
        }
      }
    }

    return bestPath === Number.MAX_SAFE_INTEGER ? -1 : bestPath;
  }

  get name() {
    return "Graph::DFS";
  }
}

class GraphAStarPriorityQueue {
  constructor() {
    this.heapVertices = [];
    this.heapPriorities = [];
    this.size = 0;
  }

  isEmpty() {
    return this.size === 0;
  }

  push(vertex, priority) {
    let i = this.size;
    this.size++;

    if (i >= this.heapVertices.length) {
      this.heapVertices.push(vertex);
      this.heapPriorities.push(priority);
    } else {
      this.heapVertices[i] = vertex;
      this.heapPriorities[i] = priority;
    }

    while (i > 0) {
      const parent = Math.floor((i - 1) / 2);
      if (this.heapPriorities[parent] <= priority) break;
      this.heapVertices[i] = this.heapVertices[parent];
      this.heapPriorities[i] = this.heapPriorities[parent];
      i = parent;
    }
    this.heapVertices[i] = vertex;
    this.heapPriorities[i] = priority;
  }

  pop() {
    const result = this.heapVertices[0];
    this.size--;

    if (this.size > 0) {
      const lastVertex = this.heapVertices[this.size];
      const lastPriority = this.heapPriorities[this.size];
      let i = 0;

      while (true) {
        const left = 2 * i + 1;
        const right = 2 * i + 2;
        let smallest = i;

        if (left < this.size && this.heapPriorities[left] < this.heapPriorities[smallest]) {
          smallest = left;
        }
        if (right < this.size && this.heapPriorities[right] < this.heapPriorities[smallest]) {
          smallest = right;
        }
        if (smallest === i) break;

        this.heapVertices[i] = this.heapVertices[smallest];
        this.heapPriorities[i] = this.heapPriorities[smallest];
        i = smallest;
      }
      this.heapVertices[i] = lastVertex;
      this.heapPriorities[i] = lastPriority;
    }

    return result;
  }
}

class GraphPathAStar extends GraphPathBenchmark {
  run(_iteration_id) {
    const length = this.aStarShortestPath(0, this.graph.getVertices() - 1);
    this.resultValue += length;
  }

  heuristic(v, target) {
    return target - v;
  }

  aStarShortestPath(start, target) {
    if (start === target) return 0;

    const n = this.graph.getVertices();

    const gScore = new Array(n).fill(Number.MAX_SAFE_INTEGER);
    const bestF = new Array(n).fill(Number.MAX_SAFE_INTEGER);

    gScore[start] = 0;
    const fStart = this.heuristic(start, target);
    bestF[start] = fStart;

    const openSet = new GraphAStarPriorityQueue();
    openSet.push(start, fStart);

    while (!openSet.isEmpty()) {
      const current = openSet.pop();

      if (current === target) {
        return gScore[current];
      }

      for (const neighbor of this.graph.getAdjacency()[current]) {
        const tentativeG = gScore[current] + 1;

        if (tentativeG < gScore[neighbor]) {
          gScore[neighbor] = tentativeG;
          const fNew = tentativeG + this.heuristic(neighbor, target);

          if (fNew < bestF[neighbor]) {
            bestF[neighbor] = fNew;
            openSet.push(neighbor, fNew);
          }
        }
      }
    }

    return -1;
  }

  get name() {
    return "Graph::AStar";
  }
}

class BufferHashBenchmark extends Benchmark {
  constructor() {
    super();
    this.size = Number(Helper.configI64(this.name, "size"));
    this.data = new Uint8Array(this.size);
    this.resultValue = 0;
  }

  prepare() {
    for (let i = 0; i < this.data.length; i++) {
      this.data[i] = Helper.nextInt(256);
    }
  }

  run(_iteration_id) {
    let ch = Helper.nextInt(256);
    this.data[Helper.nextInt(this.data.length)] = ch;
    const hash = this.test();
    this.resultValue = (this.resultValue + hash) & 0xffffffff;
  }

  checksum() {
    return this.resultValue >>> 0;
  }
}

class SimpleSHA256 {
  static digest(data) {
    const result = new Uint8Array(32);

    const hashes = [
      0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab,
      0x5be0cd19,
    ];

    for (let i = 0; i < data.length; i++) {
      const byte = data[i];
      const hashIdx = i % 8;
      let hash = hashes[hashIdx];

      hash = (hash << 5) + hash + byte;
      hash = (hash + (hash << 10)) ^ (hash >>> 6);
      hashes[hashIdx] = hash >>> 0;
    }

    for (let i = 0; i < 8; i++) {
      const hash = hashes[i];
      result[i * 4] = (hash >> 24) & 0xff;
      result[i * 4 + 1] = (hash >> 16) & 0xff;
      result[i * 4 + 2] = (hash >> 8) & 0xff;
      result[i * 4 + 3] = hash & 0xff;
    }

    return result;
  }
}

class BufferHashSHA256 extends BufferHashBenchmark {
  test() {
    const bytes = SimpleSHA256.digest(this.data);
    const view = new DataView(bytes.buffer);

    return view.getUint32(0, true);
  }

  get name() {
    return "Hash::SHA256";
  }
}

class BufferHashCRC32 extends BufferHashBenchmark {
  test() {
    let crc = 0xffffffff;
    const data = this.data;

    for (let i = 0; i < data.length; i++) {
      crc ^= data[i];

      for (let j = 0; j < 8; j++) {
        if (crc & 1) {
          crc = (crc >>> 1) ^ 0xedb88320;
        } else {
          crc >>>= 1;
        }
      }
    }

    return (crc ^ 0xffffffff) >>> 0;
  }

  get name() {
    return "Hash::CRC32";
  }
}

class Node3 {
  constructor(key, value) {
    this.key = key;
    this.value = value;
    this.prev = null;
    this.next = null;
  }
}

class FastLRUCache {
  constructor(capacity) {
    this.capacity = capacity;
    this._size = 0;
    this.cache = new Map();
    this.head = null;
    this.tail = null;
  }

  get(key) {
    const node = this.cache.get(key);
    if (!node) return undefined;

    this.moveToFront(node);
    return node.value;
  }

  put(key, value) {
    let node = this.cache.get(key);
    if (node) {
      node.value = value;
      this.moveToFront(node);
      return;
    }

    if (this._size >= this.capacity) {
      this.removeOldest();
    }

    node = new Node3(key, value);
    this.cache.set(key, node);
    this.addToFront(node);
    this._size++;
  }

  size() {
    return this._size;
  }

  moveToFront(node) {
    if (node === this.head) return;

    if (node.prev) node.prev.next = node.next;
    if (node.next) node.next.prev = node.prev;

    if (node === this.tail) {
      this.tail = node.prev;
    }

    node.prev = null;
    node.next = this.head;
    if (this.head) this.head.prev = node;
    this.head = node;

    if (!this.tail) this.tail = node;
  }

  addToFront(node) {
    node.next = this.head;
    if (this.head) this.head.prev = node;
    this.head = node;
    if (!this.tail) this.tail = node;
  }

  removeOldest() {
    if (!this.tail) return;

    const oldest = this.tail;
    this.cache.delete(oldest.key);

    if (oldest.prev) {
      oldest.prev.next = null;
      this.tail = oldest.prev;
    } else {
      this.head = null;
      this.tail = null;
    }

    this._size--;
  }
}

class CacheSimulation extends Benchmark {
  constructor() {
    super();
    this.valuesSize = Number(Helper.configI64(this.name, "values"));
    this.cache = new FastLRUCache(Number(Helper.configI64(this.name, "size")));
    this.hits = 0;
    this.misses = 0;
    this.resultValue = 5432;
  }

  run(_iteration_id) {
    let j = 0;
    while (j < 1000) {
      const key = `item_${Helper.nextInt(this.valuesSize)}`;

      if (this.cache.get(key) !== undefined) {
        this.hits++;
        this.cache.put(key, `updated_${this.iterations}`);
      } else {
        this.misses++;
        this.cache.put(key, `new_${this.iterations}`);
      }
      j++;
    }
  }

  checksum() {
    let result = 5432;
    result = ((result << 5) + this.hits) & 0xffffffff;
    result = ((result << 5) + this.misses) & 0xffffffff;
    result = ((result << 5) + this.cache.size()) & 0xffffffff;
    return result >>> 0;
  }

  get name() {
    return "Etc::CacheSimulation";
  }
}

class Node2 {}

class NumberNode extends Node2 {
  constructor(value) {
    super();
    this.value = value;
  }
}

class VariableNode extends Node2 {
  constructor(name) {
    super();
    this.name = name;
  }
}

class BinaryOpNode extends Node2 {
  constructor(op, left, right) {
    super();
    this.op = op;
    this.left = left;
    this.right = right;
  }
}

class AssignmentNode extends Node2 {
  constructor(varName, expr) {
    super();
    this.varName = varName;
    this.expr = expr;
  }
}

const CHAR_EOF = 0;
const CHAR_PLUS = "+".charCodeAt(0);
const CHAR_MINUS = "-".charCodeAt(0);
const CHAR_STAR = "*".charCodeAt(0);
const CHAR_SLASH = "/".charCodeAt(0);
const CHAR_PERCENT = "%".charCodeAt(0);
const CHAR_LPAREN = "(".charCodeAt(0);
const CHAR_RPAREN = ")".charCodeAt(0);
const CHAR_EQUALS = "=".charCodeAt(0);
const CHAR_ZERO = "0".charCodeAt(0);
const CHAR_NINE = "9".charCodeAt(0);
const CHAR_A_LOWER = "a".charCodeAt(0);
const CHAR_Z_LOWER = "z".charCodeAt(0);
const CHAR_A_UPPER = "A".charCodeAt(0);
const CHAR_Z_UPPER = "Z".charCodeAt(0);
const CHAR_SPACE = " ".charCodeAt(0);
const CHAR_TAB = "\t".charCodeAt(0);
const CHAR_NEWLINE = "\n".charCodeAt(0);
const CHAR_CR = "\r".charCodeAt(0);

class Parser {
  constructor(input) {
    this.input = input;
    this.bytes = new TextEncoder().encode(input);
    this.pos = 0;
    this.len = this.bytes.length;
    this.currentByte = this.len > 0 ? this.bytes[0] : CHAR_EOF;
    this.expressions = [];
  }

  parse() {
    while (this.currentByte !== CHAR_EOF) {
      this.skipWhitespace();
      if (this.currentByte === CHAR_EOF) break;

      const expr = this.parseExpression();
      if (expr) {
        this.expressions.push(expr);
      }

      this.skipWhitespace();
      while (this.currentByte === CHAR_NEWLINE) {
        this.advance();
        this.skipWhitespace();
      }
    }
  }

  parseExpression() {
    let node = this.parseTerm();

    while (true) {
      this.skipWhitespace();

      if (this.currentByte === CHAR_PLUS || this.currentByte === CHAR_MINUS) {
        const op = String.fromCharCode(this.currentByte);
        this.advance();
        const right = this.parseTerm();
        node = new BinaryOpNode(op, node, right);
      } else {
        break;
      }
    }

    return node;
  }

  parseTerm() {
    let node = this.parseFactor();

    while (true) {
      this.skipWhitespace();

      if (
        this.currentByte === CHAR_STAR ||
        this.currentByte === CHAR_SLASH ||
        this.currentByte === CHAR_PERCENT
      ) {
        const op = String.fromCharCode(this.currentByte);
        this.advance();
        const right = this.parseFactor();
        node = new BinaryOpNode(op, node, right);
      } else {
        break;
      }
    }

    return node;
  }

  parseFactor() {
    this.skipWhitespace();

    const byte = this.currentByte;

    if (this.isDigit(byte)) {
      return this.parseNumber();
    } else if (this.isLetter(byte)) {
      return this.parseVariable();
    } else if (byte === CHAR_LPAREN) {
      this.advance();
      const node = this.parseExpression();
      this.skipWhitespace();
      if (this.currentByte === CHAR_RPAREN) {
        this.advance();
      }
      return node;
    } else {
      this.advance();
      return new NumberNode(0);
    }
  }

  parseNumber() {
    let value = 0;
    while (this.isDigit(this.currentByte)) {
      const digit = this.currentByte - CHAR_ZERO;
      value = value * 10 + digit;
      this.advance();
    }
    return new NumberNode(value);
  }

  parseVariable() {
    const start = this.pos;
    while (this.isLetter(this.currentByte) || this.isDigit(this.currentByte)) {
      this.advance();
    }
    const varName = this.input.substring(start, this.pos);

    this.skipWhitespace();
    if (this.currentByte === CHAR_EQUALS) {
      this.advance();
      const expr = this.parseExpression();
      return new AssignmentNode(varName, expr);
    }

    return new VariableNode(varName);
  }

  advance() {
    this.pos++;
    if (this.pos >= this.len) {
      this.currentByte = CHAR_EOF;
    } else {
      this.currentByte = this.bytes[this.pos];
    }
  }

  skipWhitespace() {
    while (this.isWhitespace(this.currentByte)) {
      this.advance();
    }
  }

  isDigit(byte) {
    return byte >= CHAR_ZERO && byte <= CHAR_NINE;
  }

  isLetter(byte) {
    return (
      (byte >= CHAR_A_LOWER && byte <= CHAR_Z_LOWER) ||
      (byte >= CHAR_A_UPPER && byte <= CHAR_Z_UPPER)
    );
  }

  isWhitespace(byte) {
    return byte === CHAR_SPACE || byte === CHAR_TAB || byte === CHAR_NEWLINE || byte === CHAR_CR;
  }
}

class CalculatorAst extends Benchmark {
  constructor() {
    super();
    this.n = Number(Helper.configI64(this.name, "operations"));
    this.text = "";
    this.expressions = [];
    this.resultValue = 0;
  }

  generateRandomProgram(n = 1000) {
    let result = "v0 = 1\n";

    for (let i = 0; i < 10; i++) {
      const v = i + 1;
      result += `v${v} = v${v - 1} + ${v}\n`;
    }

    for (let i = 0; i < n; i++) {
      const v = i + 10;
      result += `v${v} = v${v - 1} + `;

      const choice = Helper.nextInt(10);
      switch (choice) {
        case 0:
          result += `(v${v - 1} / 3) * 4 - ${i} / (3 + (18 - v${v - 2})) % v${v - 3} + 2 * ((9 - v${v - 6}) * (v${v - 5} + 7))`;
          break;
        case 1:
          result += `v${v - 1} + (v${v - 2} + v${v - 3}) * v${v - 4} - (v${v - 5} / v${v - 6})`;
          break;
        case 2:
          result += `(3789 - (((v${v - 7})))) + 1`;
          break;
        case 3:
          result += `4/2 * (1-3) + v${v - 9}/v${v - 5}`;
          break;
        case 4:
          result += `1+2+3+4+5+6+v${v - 1}`;
          break;
        case 5:
          result += `(99999 / v${v - 3})`;
          break;
        case 6:
          result += `0 + 0 - v${v - 8}`;
          break;
        case 7:
          result += `((((((((((v${v - 6})))))))))) * 2`;
          break;
        case 8:
          result += `${i} * (v${v - 1}%6)%7`;
          break;
        case 9:
          result += `(1)/(0-v${v - 5}) + (v${v - 7})`;
          break;
      }
      result += "\n";
    }

    return result;
  }

  prepare() {
    this.text = this.generateRandomProgram(this.n);
  }

  run(_iteration_id) {
    const parser = new Parser(this.text);
    parser.parse();
    this.expressions = parser.expressions;
    this.resultValue = (this.resultValue + this.expressions.length) & 0xffffffff;
    const lastExpr = this.expressions[this.expressions.length - 1];
    if (lastExpr instanceof AssignmentNode) {
      this.resultValue = (this.resultValue + Helper.checksumString(lastExpr.varName)) & 0xffffffff;
    }
  }

  getExpressions() {
    return this.expressions;
  }

  checksum() {
    return this.resultValue;
  }

  get name() {
    return "Calculator::Ast";
  }
}

class Int64 {
  constructor(value) {
    if (typeof value === "bigint") {
      const mask = 0xffffffffn;
      this.low = Number(value & mask);
      this.high = Number((value >> 32n) & mask);
    } else {
      this.low = value | 0;
      this.high = value >= 0 ? 0 : -1;
    }
  }

  toBigInt() {
    const lowUnsigned = BigInt(this.low >>> 0);
    const highUnsigned = BigInt(this.high >>> 0);
    const result = (highUnsigned << 32n) | lowUnsigned;

    if (this.high & 0x80000000) {
      const mask = (1n << 64n) - 1n;
      return result - (1n << 64n);
    }
    return result;
  }

  tonumber() {
    return this.low;
  }

  add(other) {
    let low = (this.low + other.low) | 0;
    let high = (this.high + other.high) | 0;

    if ((this.low >>> 0) + (other.low >>> 0) > 0xffffffff) {
      high = (high + 1) | 0;
    }

    return Int64.fromParts(low, high);
  }

  sub(other) {
    let low = (this.low - other.low) | 0;
    let high = (this.high - other.high) | 0;

    if (this.low >>> 0 < other.low >>> 0) {
      high = (high - 1) | 0;
    }

    return Int64.fromParts(low, high);
  }

  mul(other) {
    const a = this.toBigInt();
    const b = other.toBigInt();
    const mask = (1n << 64n) - 1n;
    let result = a * b;

    if (result > 0x7fffffffffffffffn) {
      result = result - (1n << 64n);
    } else if (result < -0x8000000000000000n) {
      result = result + (1n << 64n);
    }

    return new Int64(result);
  }

  div(other) {
    if (other.isZero()) return new Int64(0);

    const a = this.toBigInt();
    const b = other.toBigInt();

    if ((a >= 0n && b > 0n) || (a < 0n && b < 0n)) {
      return new Int64(a / b);
    } else {
      const absA = a < 0n ? -a : a;
      const absB = b < 0n ? -b : b;
      return new Int64(-(absA / absB));
    }
  }

  mod(other) {
    if (other.isZero()) return new Int64(0);

    const a = this.toBigInt();
    const b = other.toBigInt();
    const div = this.div(other);
    const divBig = div.toBigInt();
    const result = a - divBig * b;

    return new Int64(result);
  }

  isZero() {
    return this.low === 0 && this.high === 0;
  }

  static fromParts(low, high) {
    const result = new Int64(0);
    result.low = low;
    result.high = high;
    return result;
  }
}

class Interpreter {
  constructor() {
    this.variables = new Map();
  }

  evaluate(node) {
    if (node.value !== undefined) {
      return new Int64(node.value);
    } else if (node.name !== undefined && node.expr === undefined) {
      return this.variables.get(node.name) || new Int64(0);
    } else if (node.op !== undefined) {
      const left = this.evaluate(node.left);
      const right = this.evaluate(node.right);

      switch (node.op) {
        case "+":
          return left.add(right);
        case "-":
          return left.sub(right);
        case "*":
          return left.mul(right);
        case "/":
          return left.div(right);
        case "%":
          return left.mod(right);
        default:
          return new Int64(0);
      }
    } else if (node.varName !== undefined && node.expr !== undefined) {
      const value = this.evaluate(node.expr);
      this.variables.set(node.varName, value);
      return value;
    }

    return new Int64(0);
  }

  run(expressions) {
    let result = new Int64(0);
    for (const expr of expressions) {
      result = this.evaluate(expr);
    }
    return result;
  }

  clear() {
    this.variables.clear();
  }
}

class CalculatorInterpreter extends Benchmark {
  constructor() {
    super();
    this.ast = [];
    this.resultValue = 0;
  }

  prepare() {
    const calculator = new CalculatorAst();
    calculator.n = Number(Helper.configI64(this.name, "operations"));
    calculator.prepare();
    calculator.run(0);
    this.ast = calculator.getExpressions();
  }

  run(_iteration_id) {
    const interpreter = new Interpreter();
    const result = interpreter.run(this.ast);
    this.resultValue = (this.resultValue + result.tonumber()) & 0xffffffff;
  }

  checksum() {
    return this.resultValue;
  }

  get name() {
    return "Calculator::Interpreter";
  }
}

class CellObj {
  constructor() {
    this.alive = false;
    this.nextState = false;
    this.neighbors = new Array(8);
    this.neighborCount = 0;
  }

  addNeighbor(cell) {
    this.neighbors[this.neighborCount++] = cell;
  }

  computeNextState() {
    let aliveNeighbors = 0;
    for (let i = 0; i < this.neighborCount; i++) {
      if (this.neighbors[i].alive) aliveNeighbors++;
    }

    if (this.alive) {
      this.nextState = aliveNeighbors === 2 || aliveNeighbors === 3;
    } else {
      this.nextState = aliveNeighbors === 3;
    }
  }

  update() {
    this.alive = this.nextState;
  }
}

class GameOfLifeGrid {
  constructor(width, height) {
    this.width = width;
    this.height = height;

    this.cells = new Array(height);
    for (let y = 0; y < height; y++) {
      this.cells[y] = new Array(width);
      for (let x = 0; x < width; x++) {
        this.cells[y][x] = new CellObj();
      }
    }

    this.linkNeighbors();
  }

  linkNeighbors() {
    for (let y = 0; y < this.height; y++) {
      for (let x = 0; x < this.width; x++) {
        const cell = this.cells[y][x];

        for (let dy = -1; dy <= 1; dy++) {
          for (let dx = -1; dx <= 1; dx++) {
            if (dx === 0 && dy === 0) continue;

            const ny = (y + dy + this.height) % this.height;
            const nx = (x + dx + this.width) % this.width;

            cell.addNeighbor(this.cells[ny][nx]);
          }
        }
      }
    }
  }

  nextGeneration() {
    for (let y = 0; y < this.height; y++) {
      for (let x = 0; x < this.width; x++) {
        this.cells[y][x].computeNextState();
      }
    }

    for (let y = 0; y < this.height; y++) {
      for (let x = 0; x < this.width; x++) {
        this.cells[y][x].update();
      }
    }
  }

  countAlive() {
    let count = 0;
    for (let y = 0; y < this.height; y++) {
      for (let x = 0; x < this.width; x++) {
        if (this.cells[y][x].alive) count++;
      }
    }
    return count;
  }

  computeHash() {
    const FNV_OFFSET_BASIS = 2166136261 >>> 0;
    const FNV_PRIME = 16777619 >>> 0;

    let hasher = FNV_OFFSET_BASIS;

    for (let y = 0; y < this.height; y++) {
      for (let x = 0; x < this.width; x++) {
        const alive = this.cells[y][x].alive ? 1 : 0;
        hasher = (hasher ^ alive) >>> 0;
        hasher = Math.imul(hasher, FNV_PRIME) >>> 0;
      }
    }

    return hasher >>> 0;
  }

  getCells() {
    return this.cells;
  }
}

class GameOfLife extends Benchmark {
  constructor() {
    super();
    this.width = Number(Helper.configI64(this.name, "w"));
    this.height = Number(Helper.configI64(this.name, "h"));
    this.grid = new GameOfLifeGrid(this.width, this.height);
  }

  prepare() {
    for (let y = 0; y < this.height; y++) {
      for (let x = 0; x < this.width; x++) {
        if (Helper.nextFloat() < 0.1) {
          this.grid.getCells()[y][x].alive = true;
        }
      }
    }
  }

  run(_iteration_id) {
    this.grid.nextGeneration();
  }

  checksum() {
    const alive = this.grid.countAlive();
    return (this.grid.computeHash() + alive) >>> 0;
  }

  get name() {
    return "Etc::GameOfLife";
  }
}

const CellKind = {
  WALL: 0,
  SPACE: 1,
  START: 2,
  FINISH: 3,
  BORDER: 4,
  PATH: 5,
};

function isWalkable(kind) {
  return kind === CellKind.SPACE || kind === CellKind.START || kind === CellKind.FINISH;
}

class Cell {
  constructor(x, y) {
    this.x = x;
    this.y = y;
    this.kind = CellKind.WALL;
    this.neighbors = [];
  }

  reset() {
    if (this.kind === CellKind.SPACE) {
      this.kind = CellKind.WALL;
    }
  }
}

class Maze {
  constructor(width, height) {
    this.width = Math.max(width, 5);
    this.height = Math.max(height, 5);

    this.cells = [];
    for (let y = 0; y < this.height; y++) {
      const row = [];
      for (let x = 0; x < this.width; x++) {
        row.push(new Cell(x, y));
      }
      this.cells.push(row);
    }

    this.start = this.cells[1][1];
    this.finish = this.cells[this.height - 2][this.width - 2];
    this.start.kind = CellKind.START;
    this.finish.kind = CellKind.FINISH;

    this.updateNeighbors();
  }

  updateNeighbors() {
    for (let y = 0; y < this.height; y++) {
      for (let x = 0; x < this.width; x++) {
        const cell = this.cells[y][x];

        if (x > 0 && y > 0 && x < this.width - 1 && y < this.height - 1) {
          cell.neighbors.push(this.cells[y - 1][x]);
          cell.neighbors.push(this.cells[y + 1][x]);
          cell.neighbors.push(this.cells[y][x + 1]);
          cell.neighbors.push(this.cells[y][x - 1]);

          for (let t = 0; t < 4; t++) {
            const i = Helper.nextInt(4);
            const j = Helper.nextInt(4);
            if (i !== j) {
              [cell.neighbors[i], cell.neighbors[j]] = [cell.neighbors[j], cell.neighbors[i]];
            }
          }
        } else {
          cell.kind = CellKind.BORDER;
        }
      }
    }
  }

  reset() {
    for (const row of this.cells) {
      for (const cell of row) {
        cell.reset();
      }
    }
    this.start.kind = CellKind.START;
    this.finish.kind = CellKind.FINISH;
  }

  dig(startCell) {
    const stack = new Array(this.width * this.height);
    let size = 0;
    stack[size++] = startCell;

    while (size > 0) {
      const cell = stack[--size];

      let walkable = 0;
      for (const n of cell.neighbors) {
        if (isWalkable(n.kind)) walkable++;
      }

      if (walkable !== 1) continue;

      cell.kind = CellKind.SPACE;
      for (const n of cell.neighbors) {
        if (n.kind === CellKind.WALL) {
          stack[size++] = n;
        }
      }
    }
  }

  ensureOpenFinish(cell) {
    cell.kind = CellKind.SPACE;

    let walkable = 0;
    for (const n of cell.neighbors) {
      if (isWalkable(n.kind)) walkable++;
    }

    if (walkable > 1) return;

    for (const n of cell.neighbors) {
      if (n.kind === CellKind.WALL) {
        this.ensureOpenFinish(n);
      }
    }
  }

  generate() {
    for (const n of this.start.neighbors) {
      if (n.kind === CellKind.WALL) {
        this.dig(n);
      }
    }

    for (const n of this.finish.neighbors) {
      if (n.kind === CellKind.WALL) {
        this.ensureOpenFinish(n);
      }
    }
  }

  middleCell() {
    return this.cells[Math.floor(this.height / 2)][Math.floor(this.width / 2)];
  }

  checksum() {
    let hasher = 2166136261 >>> 0;
    const prime = 16777619 >>> 0;

    for (let y = 0; y < this.height; y++) {
      for (let x = 0; x < this.width; x++) {
        if (this.cells[y][x].kind === CellKind.SPACE) {
          const val = (x * y) >>> 0;
          hasher = (hasher ^ val) >>> 0;
          hasher = Math.imul(hasher, prime) >>> 0;
        }
      }
    }
    return hasher >>> 0;
  }

  printToConsole() {
    for (let y = 0; y < this.height; y++) {
      for (let x = 0; x < this.width; x++) {
        const kind = this.cells[y][x].kind;
        if (kind === CellKind.SPACE) process.stdout.write(" ");
        else if (kind === CellKind.WALL) process.stdout.write("\x1b[34m#\x1b[0m");
        else if (kind === CellKind.BORDER) process.stdout.write("\x1b[31mO\x1b[0m");
        else if (kind === CellKind.START) process.stdout.write("\x1b[32m>\x1b[0m");
        else if (kind === CellKind.FINISH) process.stdout.write("\x1b[32m<\x1b[0m");
        else if (kind === CellKind.PATH) process.stdout.write("\x1b[33m.\x1b[0m");
      }
      console.log();
    }
    console.log();
  }
}

class MazeGenerator extends Benchmark {
  constructor() {
    super();
    this.width = Number(Helper.configI64("Maze::Generator", "w"));
    this.height = Number(Helper.configI64("Maze::Generator", "h"));
    this.maze = new Maze(this.width, this.height);
    this.resultVal = 0;
  }

  get name() {
    return "Maze::Generator";
  }

  prepare() {
    this.resultVal = 0;
  }

  run(_iteration_id) {
    this.maze.reset();
    this.maze.generate();
    this.resultVal = (this.resultVal + this.maze.middleCell().kind) >>> 0;
  }

  checksum() {
    return (this.resultVal + this.maze.checksum()) >>> 0;
  }
}

class MazeBFS extends Benchmark {
  constructor() {
    super();
    this.width = Number(Helper.configI64("Maze::BFS", "w"));
    this.height = Number(Helper.configI64("Maze::BFS", "h"));
    this.maze = new Maze(this.width, this.height);
    this.resultVal = 0;
    this.path = [];
  }

  get name() {
    return "Maze::BFS";
  }

  prepare() {
    this.maze.generate();
    this.resultVal = 0;
    this.path = [];
  }

  bfs(start, target) {
    if (start === target) return [start];

    const queue = [];
    const visited = Array(this.height);
    for (let y = 0; y < this.height; y++) {
      visited[y] = Array(this.width).fill(false);
    }
    const pathNodes = [];

    visited[start.y][start.x] = true;
    pathNodes.push({ cell: start, parent: -1 });
    queue.push(0);

    let head = 0;
    while (head < queue.length) {
      const pathId = queue[head++];
      const node = pathNodes[pathId];

      for (const neighbor of node.cell.neighbors) {
        if (neighbor === target) {
          const result = [target];
          let cur = pathId;
          while (cur >= 0) {
            result.push(pathNodes[cur].cell);
            cur = pathNodes[cur].parent;
          }
          return result.reverse();
        }

        if (isWalkable(neighbor.kind) && !visited[neighbor.y][neighbor.x]) {
          visited[neighbor.y][neighbor.x] = true;
          pathNodes.push({ cell: neighbor, parent: pathId });
          queue.push(pathNodes.length - 1);
        }
      }
    }
    return [];
  }

  midCellChecksum(path) {
    if (path.length === 0) return 0;
    const cell = path[Math.floor(path.length / 2)];
    return (cell.x * cell.y) >>> 0;
  }

  run(_iteration_id) {
    this.path = this.bfs(this.maze.start, this.maze.finish);
    this.resultVal = (this.resultVal + this.path.length) >>> 0;
  }

  checksum() {
    return (this.resultVal + this.midCellChecksum(this.path)) >>> 0;
  }
}

class AStarPriorityQueue {
  constructor() {
    this.heap = [];
    this.size = 0;
  }

  isEmpty() {
    return this.size === 0;
  }

  push(vertex, priority) {
    let i = this.size;
    this.size++;

    if (i >= this.heap.length) {
      this.heap.push({ priority, vertex });
    } else {
      this.heap[i] = { priority, vertex };
    }

    while (i > 0) {
      const parent = Math.floor((i - 1) / 2);
      if (this.heap[parent].priority <= priority) break;
      this.heap[i] = this.heap[parent];
      i = parent;
    }
    this.heap[i] = { priority, vertex };
  }

  pop() {
    const min = this.heap[0];
    this.size--;

    if (this.size > 0) {
      const last = this.heap[this.size];
      let i = 0;
      while (true) {
        const left = 2 * i + 1;
        const right = 2 * i + 2;
        let smallest = i;

        if (left < this.size && this.heap[left].priority < this.heap[smallest].priority) {
          smallest = left;
        }
        if (right < this.size && this.heap[right].priority < this.heap[smallest].priority) {
          smallest = right;
        }
        if (smallest === i) break;

        this.heap[i] = this.heap[smallest];
        i = smallest;
      }
      this.heap[i] = last;
    }

    return min;
  }
}

class MazeAStar extends Benchmark {
  constructor() {
    super();
    this.width = Number(Helper.configI64("Maze::AStar", "w"));
    this.height = Number(Helper.configI64("Maze::AStar", "h"));
    this.maze = new Maze(this.width, this.height);
    this.resultVal = 0;
    this.path = [];
  }

  get name() {
    return "Maze::AStar";
  }

  prepare() {
    this.maze.generate();
    this.resultVal = 0;
    this.path = [];
  }

  heuristic(a, b) {
    return Math.abs(a.x - b.x) + Math.abs(a.y - b.y);
  }

  idx(y, x) {
    return y * this.width + x;
  }

  astar(start, target) {
    if (start === target) return [start];

    const size = this.width * this.height;

    const cameFrom = new Int32Array(size).fill(-1);
    const gScore = new Int32Array(size).fill(0x7fffffff);
    const bestF = new Int32Array(size).fill(0x7fffffff);

    const startIdx = this.idx(start.y, start.x);
    const targetIdx = this.idx(target.y, target.x);

    const openSet = new AStarPriorityQueue();

    gScore[startIdx] = 0;
    const fStart = this.heuristic(start, target);
    openSet.push(startIdx, fStart);
    bestF[startIdx] = fStart;

    while (!openSet.isEmpty()) {
      const entry = openSet.pop();
      const currentIdx = entry.vertex;

      if (currentIdx === targetIdx) {
        const result = [];
        let cur = currentIdx;
        while (cur !== -1) {
          const y = Math.floor(cur / this.width);
          const x = cur % this.width;
          result.push(this.maze.cells[y][x]);
          cur = cameFrom[cur];
        }
        return result.reverse();
      }

      const currentY = Math.floor(currentIdx / this.width);
      const currentX = currentIdx % this.width;
      const currentCell = this.maze.cells[currentY][currentX];
      const currentG = gScore[currentIdx];

      for (const neighbor of currentCell.neighbors) {
        if (!isWalkable(neighbor.kind)) continue;

        const neighborIdx = this.idx(neighbor.y, neighbor.x);
        const tentativeG = currentG + 1;

        if (tentativeG < gScore[neighborIdx]) {
          cameFrom[neighborIdx] = currentIdx;
          gScore[neighborIdx] = tentativeG;
          const fNew = tentativeG + this.heuristic(neighbor, target);

          if (fNew < bestF[neighborIdx]) {
            bestF[neighborIdx] = fNew;
            openSet.push(neighborIdx, fNew);
          }
        }
      }
    }

    return [];
  }

  midCellChecksum(path) {
    if (path.length === 0) return 0;
    const cell = path[Math.floor(path.length / 2)];
    return (cell.x * cell.y) >>> 0;
  }

  run(_iteration_id) {
    this.path = this.astar(this.maze.start, this.maze.finish);
    this.resultVal = (this.resultVal + this.path.length) >>> 0;
  }

  checksum() {
    return (this.resultVal + this.midCellChecksum(this.path)) >>> 0;
  }
}

class Compress {
  static generateTestData(size) {
    const pattern = new TextEncoder().encode("ABRACADABRA");
    const sizeNum = Number(size);
    const data = new Uint8Array(sizeNum);
    const patternLength = pattern.length;

    for (let i = 0; i < sizeNum; i++) {
      data[i] = pattern[i % patternLength];
    }

    return data;
  }

  static arraysEqual(a, b) {
    if (a.length !== b.length) return false;
    for (let i = 0; i < a.length; i++) {
      if (a[i] !== b[i]) return false;
    }
    return true;
  }
}

class BWTResult {
  constructor(transformed, originalIdx) {
    this.transformed = transformed;
    this.originalIdx = originalIdx;
  }
}

class BWTEncode extends Benchmark {
  constructor() {
    super();
    this.sizeVal = Helper.configI64("Compress::BWTEncode", "size");
    this.testData = new Uint8Array();
    this.bwtResult = null;
    this.resultVal = 0;
  }

  get name() {
    return "Compress::BWTEncode";
  }

  prepare() {
    this.testData = Compress.generateTestData(this.sizeVal);
    this.resultVal = 0;
  }

  run(_iteration_id) {
    this.bwtResult = this.bwtTransform(this.testData);
    this.resultVal = (this.resultVal + this.bwtResult.transformed.length) >>> 0;
  }

  checksum() {
    return this.resultVal >>> 0;
  }

  bwtTransform(input) {
    const n = input.length;
    if (n === 0) {
      return new BWTResult(new Uint8Array(), 0);
    }

    const counts = new Int32Array(256);
    for (let i = 0; i < n; i++) {
      counts[input[i]]++;
    }

    const positions = new Int32Array(256);
    let total = 0;
    for (let i = 0; i < 256; i++) {
      positions[i] = total;
      total += counts[i];
      counts[i] = 0;
    }

    const sa = new Int32Array(n);
    for (let i = 0; i < n; i++) {
      const byteVal = input[i];
      const pos = positions[byteVal] + counts[byteVal];
      sa[pos] = i;
      counts[byteVal]++;
    }

    if (n > 1) {
      const rank = new Int32Array(n);
      let currentRank = 0;
      let prevChar = input[sa[0]];

      for (let i = 0; i < n; i++) {
        const idx = sa[i];
        const currChar = input[idx];
        if (currChar !== prevChar) {
          currentRank++;
          prevChar = currChar;
        }
        rank[idx] = currentRank;
      }

      let k = 1;
      while (k < n) {
        const pairs = new Array(n);
        for (let i = 0; i < n; i++) {
          pairs[i] = [rank[i], rank[(i + k) % n]];
        }

        const saArray = Array.from(sa);
        saArray.sort((a, b) => {
          const pa = pairs[a];
          const pb = pairs[b];
          if (pa[0] !== pb[0]) return pa[0] - pb[0];
          return pa[1] - pb[1];
        });
        for (let i = 0; i < n; i++) sa[i] = saArray[i];

        const newRank = new Int32Array(n);
        newRank[sa[0]] = 0;
        for (let i = 1; i < n; i++) {
          const prevPair = pairs[sa[i - 1]];
          const currPair = pairs[sa[i]];
          const same = prevPair[0] === currPair[0] && prevPair[1] === currPair[1];
          newRank[sa[i]] = newRank[sa[i - 1]] + (same ? 0 : 1);
        }

        for (let i = 0; i < n; i++) rank[i] = newRank[i];
        k *= 2;
      }
    }

    const transformed = new Uint8Array(n);
    let originalIdx = 0;

    for (let i = 0; i < n; i++) {
      const suffix = sa[i];
      if (suffix === 0) {
        transformed[i] = input[n - 1];
        originalIdx = i;
      } else {
        transformed[i] = input[suffix - 1];
      }
    }

    return new BWTResult(transformed, originalIdx);
  }
}

class BWTDecode extends Benchmark {
  constructor() {
    super();
    this.sizeVal = Helper.configI64("Compress::BWTDecode", "size");
    this.testData = new Uint8Array();
    this.inverted = new Uint8Array();
    this.bwtResult = null;
    this.resultVal = 0;
  }

  get name() {
    return "Compress::BWTDecode";
  }

  prepare() {
    this.testData = Compress.generateTestData(this.sizeVal);

    const encoder = new BWTEncode();
    encoder.sizeVal = this.sizeVal;
    encoder.prepare();
    encoder.run(0);
    this.bwtResult = encoder.bwtResult;
    this.resultVal = 0;
  }

  run(_iteration_id) {
    this.inverted = this.bwtInverse(this.bwtResult);
    this.resultVal = (this.resultVal + this.inverted.length) >>> 0;
  }

  checksum() {
    let res = this.resultVal;
    if (Compress.arraysEqual(this.inverted, this.testData)) {
      res += 100000;
    }
    return res >>> 0;
  }

  bwtInverse(bwtResult) {
    const bwt = bwtResult.transformed;
    const n = bwt.length;
    if (n === 0) {
      return new Uint8Array();
    }

    const counts = new Array(256).fill(0);
    for (const byte of bwt) {
      counts[byte]++;
    }

    const positions = new Array(256).fill(0);
    let total = 0;
    for (let i = 0; i < 256; i++) {
      positions[i] = total;
      total += counts[i];
    }

    const next = new Array(n).fill(0);
    const tempCounts = new Array(256).fill(0);

    for (let i = 0; i < n; i++) {
      const byteIdx = bwt[i];
      const pos = positions[byteIdx] + tempCounts[byteIdx];
      next[pos] = i;
      tempCounts[byteIdx]++;
    }

    const result = new Uint8Array(n);
    let idx = bwtResult.originalIdx;

    for (let i = 0; i < n; i++) {
      idx = next[idx];
      result[i] = bwt[idx];
    }

    return result;
  }
}

class HuffmanNode {
  constructor(frequency, byteVal = 0, isLeaf = true, left = null, right = null) {
    this.frequency = frequency;
    this.byteVal = byteVal;
    this.isLeaf = isLeaf;
    this.left = left;
    this.right = right;
  }
}

class HuffmanCodes {
  constructor() {
    this.codeLengths = new Array(256).fill(0);
    this.codes = new Array(256).fill(0);
  }
}

class EncodedResult {
  constructor(data, bitCount, frequencies) {
    this.data = data;
    this.bitCount = bitCount;
    this.frequencies = frequencies;
  }
}

class HuffEncode extends Benchmark {
  constructor() {
    super();
    this.sizeVal = Helper.configI64("Compress::HuffEncode", "size");
    this.testData = new Uint8Array();
    this.encoded = null;
    this.resultVal = 0;
  }

  get name() {
    return "Compress::HuffEncode";
  }

  prepare() {
    this.testData = Compress.generateTestData(this.sizeVal);
    this.resultVal = 0;
  }

  run(_iteration_id) {
    const frequencies = new Array(256).fill(0);
    for (const byte of this.testData) {
      frequencies[byte]++;
    }

    const tree = HuffEncode.buildHuffmanTree(frequencies);

    const codes = new HuffmanCodes();
    this.buildHuffmanCodes(tree, 0, 0, codes);

    this.encoded = this.huffmanEncode(this.testData, codes, frequencies);
    this.resultVal = (this.resultVal + this.encoded.data.length) >>> 0;
  }

  checksum() {
    return this.resultVal >>> 0;
  }

  static buildHuffmanTree(frequencies) {
    const heap = [];

    for (let i = 0; i < frequencies.length; i++) {
      if (frequencies[i] > 0) {
        heap.push(new HuffmanNode(frequencies[i], i));
      }
    }

    heap.sort((a, b) => a.frequency - b.frequency);

    if (heap.length === 1) {
      const node = heap[0];
      return new HuffmanNode(node.frequency, 0, false, node, new HuffmanNode(0, 0));
    }

    while (heap.length > 1) {
      const left = heap.shift();
      const right = heap.shift();

      const parent = new HuffmanNode(left.frequency + right.frequency, 0, false, left, right);

      let inserted = false;
      for (let i = 0; i < heap.length; i++) {
        if (parent.frequency < heap[i].frequency) {
          heap.splice(i, 0, parent);
          inserted = true;
          break;
        }
      }
      if (!inserted) {
        heap.push(parent);
      }
    }

    return heap[0];
  }

  buildHuffmanCodes(node, code, length, huffmanCodes) {
    if (node.isLeaf) {
      if (length > 0 || node.byteVal !== 0) {
        const idx = node.byteVal;
        huffmanCodes.codeLengths[idx] = length;
        huffmanCodes.codes[idx] = code;
      }
    } else {
      if (node.left) {
        this.buildHuffmanCodes(node.left, code << 1, length + 1, huffmanCodes);
      }
      if (node.right) {
        this.buildHuffmanCodes(node.right, (code << 1) | 1, length + 1, huffmanCodes);
      }
    }
  }

  huffmanEncode(data, huffmanCodes, frequencies) {
    const result = new Uint8Array(data.length * 2);
    let currentByte = 0;
    let bitPos = 0;
    let byteIndex = 0;
    let totalBits = 0;

    for (const byte of data) {
      const idx = byte;
      const code = huffmanCodes.codes[idx];
      const length = huffmanCodes.codeLengths[idx];

      for (let i = length - 1; i >= 0; i--) {
        if ((code & (1 << i)) !== 0) {
          currentByte |= 1 << (7 - bitPos);
        }
        bitPos++;
        totalBits++;

        if (bitPos === 8) {
          result[byteIndex++] = currentByte;
          currentByte = 0;
          bitPos = 0;
        }
      }
    }

    if (bitPos > 0) {
      result[byteIndex++] = currentByte;
    }

    return new EncodedResult(result.slice(0, byteIndex), totalBits, frequencies);
  }
}

class HuffDecode extends Benchmark {
  constructor() {
    super();
    this.sizeVal = Helper.configI64("Compress::HuffDecode", "size");
    this.testData = new Uint8Array();
    this.decoded = new Uint8Array();
    this.encoded = null;
    this.resultVal = 0;
  }

  get name() {
    return "Compress::HuffDecode";
  }

  prepare() {
    this.testData = Compress.generateTestData(this.sizeVal);

    const encoder = new HuffEncode();
    encoder.sizeVal = this.sizeVal;
    encoder.prepare();
    encoder.run(0);
    this.encoded = encoder.encoded;
    this.resultVal = 0;
  }

  run(_iteration_id) {
    const tree = HuffEncode.buildHuffmanTree(this.encoded.frequencies);
    this.decoded = this.huffmanDecode(this.encoded.data, tree, this.encoded.bitCount);
    this.resultVal = (this.resultVal + this.decoded.length) >>> 0;
  }

  checksum() {
    let res = this.resultVal;
    if (Compress.arraysEqual(this.decoded, this.testData)) {
      res += 100000;
    }
    return res >>> 0;
  }

  huffmanDecode(encoded, root, bitCount) {
    const result = [];

    let currentNode = root;
    let bitsProcessed = 0;
    let byteIndex = 0;

    while (bitsProcessed < bitCount && byteIndex < encoded.length) {
      const byteVal = encoded[byteIndex++];

      for (let bitPos = 7; bitPos >= 0 && bitsProcessed < bitCount; bitPos--) {
        const bit = ((byteVal >> bitPos) & 1) === 1;
        bitsProcessed++;

        currentNode = bit ? currentNode.right : currentNode.left;

        if (currentNode.isLeaf) {
          result.push(currentNode.byteVal);
          currentNode = root;
        }
      }
    }

    return new Uint8Array(result);
  }
}

class ArithFreqTable {
  constructor(frequencies) {
    this.total = 0;
    for (let i = 0; i < 256; i++) {
      this.total += frequencies[i];
    }

    this.low = new Array(256);
    this.high = new Array(256);

    let cum = 0;
    for (let i = 0; i < 256; i++) {
      this.low[i] = cum;
      cum += frequencies[i];
      this.high[i] = cum;
    }
  }
}

class BitOutputStream {
  constructor() {
    this.buffer = 0;
    this.bitPos = 0;
    this.bytes = [];
    this.bitsWritten = 0;
  }

  writeBit(bit) {
    this.buffer = (this.buffer << 1) | (bit & 1);
    this.bitPos++;
    this.bitsWritten++;

    if (this.bitPos === 8) {
      this.bytes.push(this.buffer);
      this.buffer = 0;
      this.bitPos = 0;
    }
  }

  flush() {
    if (this.bitPos > 0) {
      this.buffer <<= 8 - this.bitPos;
      this.bytes.push(this.buffer);
    }
    return new Uint8Array(this.bytes);
  }

  getBitsWritten() {
    return this.bitsWritten;
  }
}

class ArithEncodedResult {
  constructor(data, bitCount, frequencies) {
    this.data = data;
    this.bitCount = bitCount;
    this.frequencies = frequencies;
  }
}

class ArithEncode extends Benchmark {
  constructor() {
    super();
    this.sizeVal = Helper.configI64("Compress::ArithEncode", "size");
    this.testData = new Uint8Array();
    this.encoded = null;
    this.resultVal = 0;
  }

  get name() {
    return "Compress::ArithEncode";
  }

  prepare() {
    this.testData = Compress.generateTestData(this.sizeVal);
    this.resultVal = 0;
  }

  run(_iteration_id) {
    this.encoded = this.arithEncode(this.testData);
    this.resultVal = (this.resultVal + this.encoded.data.length) >>> 0;
  }

  checksum() {
    return this.resultVal >>> 0;
  }

  arithEncode(data) {
    const frequencies = new Array(256).fill(0);
    for (let i = 0; i < data.length; i++) {
      frequencies[data[i]]++;
    }

    const freqTable = new ArithFreqTable(frequencies);

    let low = 0;
    let high = 0xffffffff;
    let pending = 0;
    const output = new BitOutputStream();

    for (let i = 0; i < data.length; i++) {
      const idx = data[i];

      const range = high - low + 1;

      const highVal = Math.floor((range * freqTable.high[idx]) / freqTable.total);
      const lowVal = Math.floor((range * freqTable.low[idx]) / freqTable.total);

      high = ((low + highVal - 1) & 0xffffffff) >>> 0;
      low = ((low + lowVal) & 0xffffffff) >>> 0;

      while (true) {
        if (high < 0x80000000) {
          output.writeBit(0);
          for (let j = 0; j < pending; j++) output.writeBit(1);
          pending = 0;
        } else if (low >= 0x80000000) {
          output.writeBit(1);
          for (let j = 0; j < pending; j++) output.writeBit(0);
          pending = 0;
          low = (low - 0x80000000) >>> 0;
          high = (high - 0x80000000) >>> 0;
        } else if (low >= 0x40000000 && high < 0xc0000000) {
          pending++;
          low = (low - 0x40000000) >>> 0;
          high = (high - 0x40000000) >>> 0;
        } else {
          break;
        }

        low = (low << 1) >>> 0;
        high = ((high << 1) | 1) >>> 0;
      }
    }

    pending++;
    if (low < 0x40000000) {
      output.writeBit(0);
      for (let j = 0; j < pending; j++) output.writeBit(1);
    } else {
      output.writeBit(1);
      for (let j = 0; j < pending; j++) output.writeBit(0);
    }

    return new ArithEncodedResult(output.flush(), output.getBitsWritten(), frequencies);
  }
}

class BitInputStream {
  constructor(bytes) {
    this.bytes = bytes;
    this.bytePos = 0;
    this.bitPos = 0;
    this.currentByte = bytes.length > 0 ? bytes[0] : 0;
  }

  readBit() {
    if (this.bitPos === 8) {
      this.bytePos++;
      this.bitPos = 0;
      this.currentByte = this.bytePos < this.bytes.length ? this.bytes[this.bytePos] : 0;
    }

    const bit = (this.currentByte >> (7 - this.bitPos)) & 1;
    this.bitPos++;
    return bit;
  }
}

class ArithDecode extends Benchmark {
  constructor() {
    super();
    this.sizeVal = Helper.configI64("Compress::ArithDecode", "size");
    this.testData = new Uint8Array();
    this.decoded = new Uint8Array();
    this.encoded = null;
    this.resultVal = 0;
  }

  get name() {
    return "Compress::ArithDecode";
  }

  prepare() {
    this.testData = Compress.generateTestData(this.sizeVal);

    const encoder = new ArithEncode();
    encoder.sizeVal = this.sizeVal;
    encoder.prepare();
    encoder.run(0);
    this.encoded = encoder.encoded;
    this.resultVal = 0;
  }

  run(_iteration_id) {
    if (this.encoded) {
      this.decoded = this.arithDecode(this.encoded);
      this.resultVal = (this.resultVal + this.decoded.length) >>> 0;
    }
  }

  checksum() {
    let res = this.resultVal;
    if (this.decoded.length === this.testData.length) {
      let equal = true;
      for (let i = 0; i < this.testData.length; i++) {
        if (this.decoded[i] !== this.testData[i]) {
          equal = false;
          break;
        }
      }
      if (equal) {
        res += 100000;
      }
    }
    return res >>> 0;
  }

  arithDecode(encoded) {
    const frequencies = encoded.frequencies;
    let total = 0;
    for (let i = 0; i < 256; i++) total += frequencies[i];
    const dataSize = total;

    const lowTable = new Array(256);
    const highTable = new Array(256);
    let cum = 0;
    for (let i = 0; i < 256; i++) {
      lowTable[i] = cum;
      cum += frequencies[i];
      highTable[i] = cum;
    }

    const result = new Uint8Array(dataSize);
    const input = new BitInputStream(encoded.data);

    let value = 0;
    for (let i = 0; i < 32; i++) {
      value = ((value << 1) | input.readBit()) >>> 0;
    }

    let low = 0;
    let high = 0xffffffff;

    for (let j = 0; j < dataSize; j++) {
      const range = high - low + 1;
      const scaled = Math.floor((((value - low + 1) >>> 0) * total - 1) / range);

      let left = 0;
      let right = 256;
      while (left < right) {
        const mid = (left + right) >> 1;
        if (highTable[mid] <= scaled) {
          left = mid + 1;
        } else {
          right = mid;
        }
      }
      const symbol = left;

      result[j] = symbol;

      const highVal = Math.floor((range * highTable[symbol]) / total);
      const lowVal = Math.floor((range * lowTable[symbol]) / total);

      high = ((low + highVal - 1) & 0xffffffff) >>> 0;
      low = ((low + lowVal) & 0xffffffff) >>> 0;

      while (true) {
        if (high < 0x80000000) {
        } else if (low >= 0x80000000) {
          value = (value - 0x80000000) >>> 0;
          low = (low - 0x80000000) >>> 0;
          high = (high - 0x80000000) >>> 0;
        } else if (low >= 0x40000000 && high < 0xc0000000) {
          value = (value - 0x40000000) >>> 0;
          low = (low - 0x40000000) >>> 0;
          high = (high - 0x40000000) >>> 0;
        } else {
          break;
        }

        low = (low << 1) >>> 0;
        high = ((high << 1) | 1) >>> 0;
        value = ((value << 1) | input.readBit()) >>> 0;
      }
    }

    return result;
  }
}

class LZWResult {
  constructor(data, dictSize) {
    this.data = data;
    this.dictSize = dictSize;
  }
}

class LZWEncode extends Benchmark {
  constructor() {
    super();
    this.sizeVal = Helper.configI64("Compress::LZWEncode", "size");
    this.testData = new Uint8Array();
    this.encoded = null;
    this.resultVal = 0;
  }

  get name() {
    return "Compress::LZWEncode";
  }

  prepare() {
    this.testData = Compress.generateTestData(this.sizeVal);
    this.resultVal = 0;
  }

  run(_iteration_id) {
    this.encoded = this.lzwEncode(this.testData);
    this.resultVal = (this.resultVal + this.encoded.data.length) >>> 0;
  }

  checksum() {
    return this.resultVal >>> 0;
  }

  lzwEncode(input) {
    if (input.length === 0) {
      return new LZWResult(new Uint8Array(), 256);
    }

    const dict = new Map();
    for (let i = 0; i < 256; i++) {
      dict.set(String.fromCharCode(i), i);
    }

    let nextCode = 256;
    const result = [];

    let current = String.fromCharCode(input[0]);

    for (let i = 1; i < input.length; i++) {
      const nextChar = String.fromCharCode(input[i]);
      const newStr = current + nextChar;

      if (dict.has(newStr)) {
        current = newStr;
      } else {
        const code = dict.get(current);
        result.push((code >> 8) & 0xff);
        result.push(code & 0xff);

        dict.set(newStr, nextCode);
        nextCode++;
        current = nextChar;
      }
    }

    const code = dict.get(current);
    result.push((code >> 8) & 0xff);
    result.push(code & 0xff);

    return new LZWResult(new Uint8Array(result), nextCode);
  }
}

class LZWDecode extends Benchmark {
  constructor() {
    super();
    this.sizeVal = Helper.configI64("Compress::LZWDecode", "size");
    this.testData = new Uint8Array();
    this.decoded = new Uint8Array();
    this.encoded = null;
    this.resultVal = 0;
  }

  get name() {
    return "Compress::LZWDecode";
  }

  prepare() {
    this.testData = Compress.generateTestData(this.sizeVal);

    const encoder = new LZWEncode();
    encoder.sizeVal = this.sizeVal;
    encoder.prepare();
    encoder.run(0);
    this.encoded = encoder.encoded;
    this.resultVal = 0;
  }

  run(_iteration_id) {
    this.decoded = this.lzwDecode(this.encoded);
    this.resultVal = (this.resultVal + this.decoded.length) >>> 0;
  }

  checksum() {
    let res = this.resultVal;
    if (Compress.arraysEqual(this.decoded, this.testData)) {
      res += 100000;
    }
    return res >>> 0;
  }

  lzwDecode(encoded) {
    if (encoded.data.length === 0) {
      return new Uint8Array();
    }

    const dict = new Array(4096);
    for (let i = 0; i < 256; i++) {
      dict[i] = new Uint8Array([i]);
    }

    const resultChunks = [];
    let totalLength = 0;

    const data = encoded.data;
    let pos = 0;

    let oldCode = (data[pos] << 8) | data[pos + 1];
    pos += 2;

    let oldStr = dict[oldCode];
    resultChunks.push(oldStr);
    totalLength += oldStr.length;

    let nextCode = 256;

    while (pos < data.length) {
      const newCode = (data[pos] << 8) | data[pos + 1];
      pos += 2;

      let newStr;
      if (newCode < dict.length && dict[newCode] !== undefined) {
        newStr = dict[newCode];
      } else if (newCode === nextCode) {
        const firstChar = oldStr[0];
        newStr = new Uint8Array(oldStr.length + 1);
        newStr.set(oldStr);
        newStr[oldStr.length] = firstChar;
      } else {
        throw new Error(`Error decode: invalid code ${newCode}`);
      }

      resultChunks.push(newStr);
      totalLength += newStr.length;

      const newEntry = new Uint8Array(oldStr.length + 1);
      newEntry.set(oldStr);
      newEntry[oldStr.length] = newStr[0];
      dict[nextCode] = newEntry;
      nextCode++;

      oldCode = newCode;
      oldStr = newStr;
    }

    const result = new Uint8Array(totalLength);
    let offset = 0;
    for (const chunk of resultChunks) {
      result.set(chunk, offset);
      offset += chunk.length;
    }

    return result;
  }
}

class Jaro extends Benchmark {
  constructor() {
    super();
    this.count = Number(Helper.configI64(this.name, "count"));
    this.size = Number(Helper.configI64(this.name, "size"));
    this.pairs = [];
    this.resultVal = 0;
  }

  get name() {
    return "Distance::Jaro";
  }

  prepare() {
    this.pairs = this.generatePairStrings(this.count, this.size);
    this.resultVal = 0;
  }

  generatePairStrings(n, m) {
    const pairs = [];
    const chars = "abcdefghij".split("");

    for (let i = 0; i < n; i++) {
      const len1 = Helper.nextInt(m) + 4;
      const len2 = Helper.nextInt(m) + 4;

      let str1 = "";
      let str2 = "";

      for (let j = 0; j < len1; j++) {
        str1 += chars[Helper.nextInt(10)];
      }
      for (let j = 0; j < len2; j++) {
        str2 += chars[Helper.nextInt(10)];
      }

      pairs.push([str1, str2]);
    }

    return pairs;
  }

  jaro(s1, s2) {
    const len1 = s1.length;
    const len2 = s2.length;

    if (len1 === 0 || len2 === 0) return 0.0;

    let matchDist = Math.floor(Math.max(len1, len2) / 2) - 1;
    if (matchDist < 0) matchDist = 0;

    const s1Matches = new Array(len1).fill(false);
    const s2Matches = new Array(len2).fill(false);

    let matches = 0;
    for (let i = 0; i < len1; i++) {
      const start = Math.max(0, i - matchDist);
      const end = Math.min(len2 - 1, i + matchDist);

      for (let j = start; j <= end; j++) {
        if (!s2Matches[j] && s1.charCodeAt(i) === s2.charCodeAt(j)) {
          s1Matches[i] = true;
          s2Matches[j] = true;
          matches++;
          break;
        }
      }
    }

    if (matches === 0) return 0.0;

    let transpositions = 0;
    let k = 0;
    for (let i = 0; i < len1; i++) {
      if (s1Matches[i]) {
        while (k < len2 && !s2Matches[k]) {
          k++;
        }
        if (k < len2) {
          if (s1.charCodeAt(i) !== s2.charCodeAt(k)) {
            transpositions++;
          }
          k++;
        }
      }
    }
    transpositions = Math.floor(transpositions / 2);

    const m = matches;
    return (m / len1 + m / len2 + (m - transpositions) / m) / 3.0;
  }

  run(_iteration_id) {
    for (const [s1, s2] of this.pairs) {
      this.resultVal = (this.resultVal + Math.floor(this.jaro(s1, s2) * 1000)) >>> 0;
    }
  }

  checksum() {
    return this.resultVal >>> 0;
  }
}

class NGram extends Benchmark {
  constructor() {
    super();
    this.count = Number(Helper.configI64(this.name, "count"));
    this.size = Number(Helper.configI64(this.name, "size"));
    this.n = 4;
    this.pairs = [];
    this.resultVal = 0;
  }

  get name() {
    return "Distance::NGram";
  }

  prepare() {
    this.pairs = this.generatePairStrings(this.count, this.size);
    this.resultVal = 0;
  }

  generatePairStrings(n, m) {
    const pairs = [];
    const chars = "abcdefghij".split("");

    for (let i = 0; i < n; i++) {
      const len1 = Helper.nextInt(m) + 4;
      const len2 = Helper.nextInt(m) + 4;

      let str1 = "";
      let str2 = "";

      for (let j = 0; j < len1; j++) {
        str1 += chars[Helper.nextInt(10)];
      }
      for (let j = 0; j < len2; j++) {
        str2 += chars[Helper.nextInt(10)];
      }

      pairs.push([str1, str2]);
    }

    return pairs;
  }

  ngram(s1, s2) {
    if (s1.length < this.n || s2.length < this.n) return 0.0;

    const grams1 = new Map();

    for (let i = 0; i <= s1.length - this.n; i++) {
      const gram =
        ((s1.charCodeAt(i) << 24) |
          (s1.charCodeAt(i + 1) << 16) |
          (s1.charCodeAt(i + 2) << 8) |
          s1.charCodeAt(i + 3)) >>>
        0;

      const val = grams1.get(gram) || 0;
      grams1.set(gram, val + 1);
    }

    const grams2 = new Map();
    let intersection = 0;

    for (let i = 0; i <= s2.length - this.n; i++) {
      const gram =
        ((s2.charCodeAt(i) << 24) |
          (s2.charCodeAt(i + 1) << 16) |
          (s2.charCodeAt(i + 2) << 8) |
          s2.charCodeAt(i + 3)) >>>
        0;

      const val2 = grams2.get(gram) || 0;
      grams2.set(gram, val2 + 1);

      const count1 = grams1.get(gram);
      if (count1 !== undefined && val2 + 1 <= count1) {
        intersection++;
      }
    }

    const total = grams1.size + grams2.size;
    return total > 0 ? intersection / total : 0.0;
  }

  run(_iteration_id) {
    for (const [s1, s2] of this.pairs) {
      this.resultVal = (this.resultVal + Math.floor(this.ngram(s1, s2) * 1000)) >>> 0;
    }
  }

  checksum() {
    return this.resultVal >>> 0;
  }
}

class Words extends Benchmark {
  constructor() {
    super();
    this.words = Number(Helper.configI64(this.name, "words"));
    this.wordLen = Number(Helper.configI64(this.name, "word_len"));
    this.chars = "abcdefghijklmnopqrstuvwxyz";
    this.text = "";
    this.checksumVal = 0;
  }

  get name() {
    return "Etc::Words";
  }

  prepare() {
    const wordsList = [];

    for (let i = 0; i < this.words; i++) {
      const len = Helper.nextInt(this.wordLen) + Helper.nextInt(3) + 3;
      let word = "";
      for (let j = 0; j < len; j++) {
        const idx = Helper.nextInt(this.chars.length);
        word += this.chars[idx];
      }
      wordsList.push(word);
    }

    this.text = wordsList.join(" ");
    this.checksumVal = 0;
  }

  run(_iteration_id) {
    const frequencies = new Map();

    for (const word of this.text.split(" ")) {
      if (word === "") continue;
      frequencies.set(word, (frequencies.get(word) || 0) + 1);
    }

    let maxWord = "";
    let maxCount = 0;

    for (const [word, count] of frequencies) {
      if (count > maxCount) {
        maxCount = count;
        maxWord = word;
      }
    }

    const freqSize = frequencies.size;
    const wordChecksum = Helper.checksumString(maxWord);

    this.checksumVal = (this.checksumVal + maxCount + wordChecksum + freqSize) >>> 0;
  }

  checksum() {
    return this.checksumVal >>> 0;
  }
}

class LogParser extends Benchmark {
  constructor() {
    super();
    this.linesCount = Number(Helper.configI64(this.name, "lines_count"));
    this.log = "";
    this.checksumVal = 0;

    this.PATTERNS = [
      ["errors", / [5][0-9]{2} | [4][0-9]{2} /g],
      ["bots", /bot|crawler|scanner|spider|indexing|crawl|robot|spider/gi],
      ["suspicious", /etc\/passwd|wp-admin|\.\.\//gi],
      ["ips", /\d+\.\d+\.\d+\.35/g],
      ["api_calls", /\/api\/[^ " ]+/g],
      ["post_requests", /POST [^ ]* HTTP/g],
      ["auth_attempts", /\/login|\/signin/gi],
      ["methods", /get|post|put/gi],
      ["emails", /[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/g],
      ["passwords", /password=[^&\s"]+/g],
      ["tokens", /token=[^&\s"]+|api[_-]?key=[^&\s"]+/g],
      ["sessions", /session[_-]?id=[^&\s"]+/g],
      ["peak_hours", /\[\d+\/\w+\/\d+:1[3-7]:\d+:\d+ [+\-]\d+\]/g],
    ];

    this.IPS = Array.from({ length: 255 }, (_, i) => `192.168.1.${i + 1}`);
    this.METHODS = ["GET", "POST", "PUT", "DELETE"];
    this.PATHS = [
      "/index.html",
      "/api/users",
      "/admin",
      "/images/logo.png",
      "/etc/passwd",
      "/wp-admin/setup.php",
    ];
    this.STATUSES = [200, 201, 301, 302, 400, 401, 403, 404, 500, 502, 503];
    this.AGENTS = ["Mozilla/5.0", "Googlebot/2.1", "curl/7.68.0", "scanner/2.0"];
    this.USERS = ["john", "jane", "alex", "sarah", "mike", "anna", "david", "elena"];
    this.DOMAINS = [
      "example.com",
      "gmail.com",
      "yahoo.com",
      "hotmail.com",
      "company.org",
      "mail.ru",
    ];
  }

  get name() {
    return "Etc::LogParser";
  }

  generateLogLine(i) {
    let line = "";

    line += this.IPS[i % this.IPS.length];
    line += ` - - [${i % 31}/Oct/2023:${i % 60}:55:36 +0000] "`;
    line += this.METHODS[i % this.METHODS.length];
    line += " ";

    if (i % 3 === 0) {
      line += `/login?email=${this.USERS[i % this.USERS.length]}${i % 100}@${this.DOMAINS[i % this.DOMAINS.length]}&password=secret${i % 10000}`;
    } else if (i % 5 === 0) {
      line += "/api/data?token=";
      for (let j = 0; j < (i % 3) + 1; j++) {
        line += "abcdef123456";
      }
    } else if (i % 7 === 0) {
      line += `/user/profile?session_id=sess_${(i * 12345).toString(16)}`;
    } else {
      line += this.PATHS[i % this.PATHS.length];
    }

    line += ` HTTP/1.1" ${this.STATUSES[i % this.STATUSES.length]} 2326 "http://${this.DOMAINS[i % this.DOMAINS.length]}" "${this.AGENTS[i % this.AGENTS.length]}"\n`;

    return line;
  }

  prepare() {
    let logBuilder = "";
    for (let i = 0; i < this.linesCount; i++) {
      logBuilder += this.generateLogLine(i);
    }
    this.log = logBuilder;
    this.checksumVal = 0;
  }

  run(_iteration_id) {
    const matches = {};

    for (const [name, regex] of this.PATTERNS) {
      const count = (this.log.match(regex) || []).length;
      matches[name] = count;
    }

    const total = Object.values(matches).reduce((a, b) => a + b, 0);
    this.checksumVal = (this.checksumVal + total) >>> 0;
  }

  checksum() {
    return this.checksumVal >>> 0;
  }
}

class TemplateBase extends Benchmark {
  constructor() {
    super();
    this.count = 0;
    this.text = "";
    this.rendered = "";
    this.checksumVal = 0;
    this.vars = {};

    TemplateBase.FIRST_NAMES = [
      "John",
      "Jane",
      "Bob",
      "Alice",
      "Charlie",
      "Diana",
      "Sarah",
      "Mike",
    ];
    TemplateBase.LAST_NAMES = [
      "Smith",
      "Johnson",
      "Brown",
      "Taylor",
      "Wilson",
      "Davis",
      "Miller",
      "Jones",
    ];
    TemplateBase.CITIES = [
      "New York",
      "Los Angeles",
      "Chicago",
      "Houston",
      "Phoenix",
      "San Francisco",
    ];
    TemplateBase.LOREM =
      "Lorem {ipsum} dolor {sit} amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore {et} dolore magna aliqua. ";
  }

  prepareTemplate() {
    this.vars = {};
    let textBuilder = "";

    textBuilder += "<html><body>";
    textBuilder += "<h1>{{TITLE}}</h1>";
    this.vars["TITLE"] = "Template title";
    textBuilder += "<p>";
    textBuilder += TemplateBase.LOREM;
    textBuilder += "</p>";
    textBuilder += "<table>";

    for (let i = 0; i < this.count; i++) {
      if (i % 3 === 0) {
        textBuilder += "<!-- {comment} -->";
      }
      textBuilder += "<tr>";
      textBuilder += `<td>{{ FIRST_NAME${i} }}</td>`;
      textBuilder += `<td>{{LAST_NAME${i}}}</td>`;
      textBuilder += `<td>{{  CITY${i}  }}</td>`;

      this.vars[`FIRST_NAME${i}`] = TemplateBase.FIRST_NAMES[i % TemplateBase.FIRST_NAMES.length];
      this.vars[`LAST_NAME${i}`] = TemplateBase.LAST_NAMES[i % TemplateBase.LAST_NAMES.length];
      this.vars[`CITY${i}`] = TemplateBase.CITIES[i % TemplateBase.CITIES.length];

      textBuilder += `<td>{balance: ${i % 100}}</td>`;
      textBuilder += "</tr>\n";
    }

    textBuilder += "</table>";
    textBuilder += "</body></html>";

    this.text = textBuilder;
  }

  checksum() {
    return (this.checksumVal + Helper.checksumString(this.rendered)) >>> 0;
  }
}

class TemplateRegex extends TemplateBase {
  static PATTERN = /{{(.*?)}}/g;

  constructor() {
    super();
    this.count = Number(Helper.configI64(this.name, "count"));
  }

  get name() {
    return "Template::Regex";
  }

  prepare() {
    this.prepareTemplate();
  }

  run(_iteration_id) {
    let result = "";
    let lastPos = 0;
    let match;

    TemplateRegex.PATTERN.lastIndex = 0;

    while ((match = TemplateRegex.PATTERN.exec(this.text)) !== null) {
      const start = match.index;
      const end = start + match[0].length;

      if (start > lastPos) {
        result += this.text.substring(lastPos, start);
      }

      const key = match[1].trim();
      if (this.vars[key]) {
        result += this.vars[key];
      }

      lastPos = end;
    }

    if (lastPos < this.text.length) {
      result += this.text.substring(lastPos);
    }

    this.rendered = result;
    this.checksumVal = (this.checksumVal + this.rendered.length) >>> 0;
  }
}

class TemplateParse extends TemplateBase {
  constructor() {
    super();
    this.count = Number(Helper.configI64(this.name, "count"));
  }

  get name() {
    return "Template::Parse";
  }

  prepare() {
    this.prepareTemplate();
  }

  run(_iteration_id) {
    const len = this.text.length;
    const resultParts = [];

    let i = 0;
    while (i < len) {
      if (i + 1 < len && this.text[i] === "{" && this.text[i + 1] === "{") {
        let j = i + 2;
        while (j + 1 < len) {
          if (this.text[j] === "}" && this.text[j + 1] === "}") {
            break;
          }
          j++;
        }

        if (j + 1 < len) {
          const key = this.text.substring(i + 2, j).trim();
          if (this.vars[key]) {
            resultParts.push(this.vars[key]);
          }
          i = j + 2;
          continue;
        }
      }

      resultParts.push(this.text[i]);
      i++;
    }

    this.rendered = resultParts.join("");
    this.checksumVal = (this.checksumVal + this.rendered.length) >>> 0;
  }
}

class CsvParse extends Benchmark {
  constructor() {
    super();
    this.rows = Number(Helper.configI64(this.name, "rows"));
    this.data = "";
    this.resultVal = 0;
  }

  get name() {
    return "CSV::Parse";
  }

  generateCsvForParsing(rows) {
    let result = "";
    for (let i = 0; i < rows; i++) {
      const c = String.fromCharCode(65 + (i % 26));
      const x = Helper.nextFloat(1.0);
      const z = Helper.nextFloat(1.0);
      const y = Helper.nextFloat(1.0);

      result += `"point ${c}\\n, ""${i % 100}""",${x.toFixed(10)},,${z.toFixed(10)},"[${i % 2 === 0 ? "true" : "false"}\\n, ${i % 100}]",${y.toFixed(10)}\n`;
    }
    return result;
  }

  prepare() {
    this.data = this.generateCsvForParsing(this.rows);
    this.resultVal = 0;
  }

  parseFieldValue(start, end) {
    const field = this.data.substring(start, end);
    const trimmed =
      field.startsWith('"') && field.endsWith('"') ? field.substring(1, field.length - 1) : field;
    return parseFloat(trimmed) || 0;
  }

  parsePoints() {
    const points = [];
    let fieldIdx = 0;
    let fieldStart = 0;
    let inQuotes = false;
    const values = [0, 0, 0, 0, 0, 0];

    let pos = 0;
    const len = this.data.length;

    while (pos < len) {
      const ch = this.data[pos];

      if (ch === '"') {
        if (inQuotes && pos + 1 < len && this.data[pos + 1] === '"') {
          pos += 2;
          continue;
        }
        inQuotes = !inQuotes;
        pos++;
      } else if (ch === "," && !inQuotes) {
        if (fieldIdx === 1 || fieldIdx === 3 || fieldIdx === 5) {
          values[fieldIdx] = this.parseFieldValue(fieldStart, pos);
        }
        fieldIdx++;
        fieldStart = pos + 1;
        pos++;
      } else if (ch === "\n" && !inQuotes) {
        if (fieldIdx < 6) {
          if (fieldIdx === 1 || fieldIdx === 3 || fieldIdx === 5) {
            values[fieldIdx] = this.parseFieldValue(fieldStart, pos);
          }
          fieldIdx++;
        }

        if (fieldIdx >= 6) {
          points.push({ x: values[1], y: values[5], z: values[3] });
        }

        fieldIdx = 0;
        fieldStart = pos + 1;
        pos++;
      } else {
        pos++;
      }
    }

    if (fieldStart < pos && fieldIdx > 0) {
      if (fieldIdx < 6) {
        if (fieldIdx === 1 || fieldIdx === 3 || fieldIdx === 5) {
          values[fieldIdx] = this.parseFieldValue(fieldStart, pos);
        }
        fieldIdx++;
      }

      if (fieldIdx >= 6) {
        points.push({ x: values[1], y: values[5], z: values[3] });
      }
    }

    return points;
  }

  run(iterationId) {
    if (this.data.length === 0) return;

    const points = this.parsePoints();

    if (points.length === 0) return;

    let xSum = 0,
      ySum = 0,
      zSum = 0;
    for (const point of points) {
      xSum += point.x;
      ySum += point.y;
      zSum += point.z;
    }

    const len = points.length;
    this.resultVal = (this.resultVal + Helper.checksumFloat(xSum / len)) >>> 0;
    this.resultVal = (this.resultVal + Helper.checksumFloat(ySum / len)) >>> 0;
    this.resultVal = (this.resultVal + Helper.checksumFloat(zSum / len)) >>> 0;
  }

  checksum() {
    return (this.resultVal + Helper.checksumString(this.data)) >>> 0;
  }
}

Benchmark.registerBenchmark("Binarytrees::Obj", BinarytreesObj);
Benchmark.registerBenchmark("Binarytrees::Arena", BinarytreesArena);
Benchmark.registerBenchmark("Brainfuck::Array", BrainfuckArray);
Benchmark.registerBenchmark("Brainfuck::Recursion", BrainfuckRecursion);
Benchmark.registerBenchmark("CLBG::Fannkuchredux", Fannkuchredux);
Benchmark.registerBenchmark("CLBG::Mandelbrot", Mandelbrot);
Benchmark.registerBenchmark("Matmul::Single", Matmul1T);
Benchmark.registerBenchmark("Matmul::T4", Matmul4T);
Benchmark.registerBenchmark("Matmul::T8", Matmul8T);
Benchmark.registerBenchmark("Matmul::T16", Matmul16T);
Benchmark.registerBenchmark("CLBG::Nbody", Nbody);
Benchmark.registerBenchmark("CLBG::Spectralnorm", Spectralnorm);
Benchmark.registerBenchmark("Base64::Encode", Base64Encode);
Benchmark.registerBenchmark("Base64::Decode", Base64Decode);
Benchmark.registerBenchmark("Json::Generate", JsonGenerate);
Benchmark.registerBenchmark("Json::ParseDom", JsonParseDom);
Benchmark.registerBenchmark("Json::ParseMapping", JsonParseMapping);
Benchmark.registerBenchmark("Etc::Sieve", Sieve);
Benchmark.registerBenchmark("Etc::TextRaytracer", TextRaytracer);
Benchmark.registerBenchmark("Etc::NeuralNet", NeuralNet);
Benchmark.registerBenchmark("Sort::Quick", SortQuick);
Benchmark.registerBenchmark("Sort::Merge", SortMerge);
Benchmark.registerBenchmark("Sort::Self", SortSelf);
Benchmark.registerBenchmark("Graph::BFS", GraphPathBFS);
Benchmark.registerBenchmark("Graph::DFS", GraphPathDFS);
Benchmark.registerBenchmark("Graph::AStar", GraphPathAStar);
Benchmark.registerBenchmark("Hash::SHA256", BufferHashSHA256);
Benchmark.registerBenchmark("Hash::CRC32", BufferHashCRC32);
Benchmark.registerBenchmark("Etc::CacheSimulation", CacheSimulation);
Benchmark.registerBenchmark("Calculator::Ast", CalculatorAst);
Benchmark.registerBenchmark("Calculator::Interpreter", CalculatorInterpreter);
Benchmark.registerBenchmark("Etc::GameOfLife", GameOfLife);
Benchmark.registerBenchmark("Maze::Generator", MazeGenerator);
Benchmark.registerBenchmark("Maze::BFS", MazeBFS);
Benchmark.registerBenchmark("Maze::AStar", MazeAStar);
Benchmark.registerBenchmark("Compress::BWTEncode", BWTEncode);
Benchmark.registerBenchmark("Compress::BWTDecode", BWTDecode);
Benchmark.registerBenchmark("Compress::HuffEncode", HuffEncode);
Benchmark.registerBenchmark("Compress::HuffDecode", HuffDecode);
Benchmark.registerBenchmark("Compress::ArithEncode", ArithEncode);
Benchmark.registerBenchmark("Compress::ArithDecode", ArithDecode);
Benchmark.registerBenchmark("Compress::LZWEncode", LZWEncode);
Benchmark.registerBenchmark("Compress::LZWDecode", LZWDecode);
Benchmark.registerBenchmark("Distance::Jaro", Jaro);
Benchmark.registerBenchmark("Distance::NGram", NGram);
Benchmark.registerBenchmark("Etc::Words", Words);
Benchmark.registerBenchmark("Etc::LogParser", LogParser);
Benchmark.registerBenchmark("Template::Regex", TemplateRegex);
Benchmark.registerBenchmark("Template::Parse", TemplateParse);
Benchmark.registerBenchmark("CSV::Parse", CsvParse);

const RECOMPILE_MARKER = "RECOMPILE_MARKER_0";

async function main() {
  let args = [];

  try {
    if (isDeno) {
      args = Deno.args;
    } else if (isNode || isBun) {
      args = process.argv.slice(2);
    }
  } catch {
    args = [];
  }

  let configFile = "../run.js";
  let testName;

  if (args.length >= 1) {
    if (
      args[0].includes(".txt") ||
      args[0].includes(".json") ||
      args[0].includes(".js") ||
      args[0].includes(".config")
    ) {
      configFile = args[0];
      testName = args[1];
    } else {
      testName = args[0];
    }
  }

  console.log(`start: ${Date.now()}`);
  await Helper.loadConfig(configFile);
  Benchmark.run(testName);
}

try {
  main().catch(console.error);
} catch (error) {
  console.error("Failed to run benchmarks:", error);
  try {
    if (isDeno) {
      Deno.exit(1);
    } else if (isNode || isBun) {
      process.exit(1);
    }
  } catch {}
}