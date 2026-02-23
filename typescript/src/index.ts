const isDeno = (() => {
  try {
    // @ts-ignore
    return typeof Deno !== "undefined" && Deno.version !== undefined;
  } catch {
    return false;
  }
})();

const isBun = (() => {
  try {
    // @ts-ignore
    return typeof Bun !== "undefined" && Bun.version !== undefined;
  } catch {
    return false;
  }
})();

const isNode = (() => {
  try {
    // @ts-ignore
    return (
      typeof process !== "undefined" &&
      process.versions &&
      process.versions.node &&
      !isBun
    );
  } catch {
    return false;
  }
})();

const getPerformance = (): { now: () => number } => {
  try {
    const global = globalThis as any;
    if (
      typeof global.performance !== "undefined" &&
      typeof global.performance.now === "function"
    ) {
      return global.performance;
    }

    if (isNode) {
      try {
        // @ts-ignore
        return require("perf_hooks").performance;
      } catch {}
    }
  } catch {}

  return {
    now: () => Date.now(),
  };
};

const performance = getPerformance();

export class Helper {
  private static readonly IM = 139968;
  private static readonly IA = 3877;
  private static readonly IC = 29573;
  private static readonly INIT = 42;

  private static lastValue: number = Helper.INIT;
  private static inputMap: Record<string, string> = {};
  private static expectMap: Record<string, bigint> = {};

  static reset(): void {
    Helper.lastValue = Helper.INIT;
  }

  static get last(): number {
    return Helper.lastValue;
  }

  static set last(value: number) {
    Helper.lastValue = value;
  }

  static nextInt(max: number): number {
    Helper.last = (Helper.last * Helper.IA + Helper.IC) % Helper.IM;
    return Math.floor((Helper.last / Helper.IM) * max);
  }

  static nextIntRange(from: number, to: number): number {
    return Helper.nextInt(to - from + 1) + from;
  }

  static nextFloat(max: number = 1.0): number {
    Helper.last = (Helper.last * Helper.IA + Helper.IC) % Helper.IM;
    return (max * Helper.last) / Helper.IM;
  }

  static debug(message: string): void {
    try {
      if (isDeno) {
        // @ts-ignore
        if (Deno.env.get("DEBUG") === "1") {
          console.log(message);
        }
      } else if (isNode || isBun) {
        // @ts-ignore
        if (process.env.DEBUG === "1") {
          console.log(message);
        }
      }
    } catch {}
  }

  static checksumString(str: string): number {
    let hash = 5381;
    for (let i = 0; i < str.length; i++) {
      const byte = str.charCodeAt(i);
      hash = (hash << 5) + hash + byte;
      hash = hash & 0xffffffff;
    }
    return hash >>> 0;
  }

  static checksumBytes(bytes: Uint8Array): number {
    let hash = 5381;
    for (const byte of bytes) {
      hash = (hash << 5) + hash + byte;
      hash = hash & 0xffffffff;
    }
    return hash >>> 0;
  }

  static checksumFloat(value: number): number {
    return Helper.checksumString(value.toFixed(7));
  }

  static async loadConfig(configFile: string = "../test.js"): Promise<void> {
    try {
      let content = "";

      if (isDeno) {
        try {
          const denoGlobal = (globalThis as any).Deno;
          if (denoGlobal && typeof denoGlobal.cwd === "function") {
            const filePath = configFile.startsWith("/")
              ? configFile
              : denoGlobal.cwd() + "/" + configFile;
            content = denoGlobal.readTextFileSync(filePath);
          } else {
            throw new Error("Deno environment not properly detected");
          }
        } catch (denoError: any) {
          console.error(
            `Deno error loading ${configFile}:`,
            denoError?.message || denoError,
          );
          const denoGlobal = (globalThis as any).Deno;
          if (denoGlobal && typeof denoGlobal.exit === "function") {
            denoGlobal.exit(1);
          }
          throw denoError;
        }
      } else if (isNode) {
        try {
          // @ts-ignore
          const fs = require("fs");
          // @ts-ignore
          const path = require("path");
          // @ts-ignore
          const filePath = path.resolve(process.cwd(), configFile);
          content = fs.readFileSync(filePath, "utf-8");
        } catch (nodeError: any) {
          console.error(
            `Node.js error loading ${configFile}:`,
            nodeError?.message || nodeError,
          );
          // @ts-ignore
          process.exit(1);
        }
      } else if (isBun) {
        try {
          // @ts-ignore
          const file = Bun.file(configFile);
          content = await file.text();
        } catch (bunError: any) {
          console.error(
            `Bun error loading ${configFile}:`,
            bunError?.message || bunError,
          );
          // @ts-ignore
          process.exit(1);
        }
      } else {
        console.error(`Unknown environment, cannot load config: ${configFile}`);
        return;
      }

      const config = JSON.parse(content);

      (Helper as any).CONFIG = config;
    } catch (error: any) {
      console.error(
        `Error loading config file ${configFile}:`,
        error?.message || error,
      );

      try {
        if (isDeno) {
          const denoGlobal = (globalThis as any).Deno;
          if (denoGlobal && typeof denoGlobal.exit === "function") {
            denoGlobal.exit(1);
          }
        } else if (isNode || isBun) {
          // @ts-ignore
          if (typeof process !== "undefined" && process.exit) {
            // @ts-ignore
            process.exit(1);
          }
        }
      } catch {
        throw error;
      }
    }
  }

  static configI64(className: string, fieldName: string): bigint {
    const config = (Helper as any).CONFIG;
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

  static configS(className: string, fieldName: string): string {
    const config = (Helper as any).CONFIG;
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

async function main(): Promise<void> {
  let args: string[] = [];

  try {
    if (isDeno) {
      // @ts-ignore
      args = Deno.args;
    } else if (isNode || isBun) {
      // @ts-ignore
      args = process.argv.slice(2);
    }
  } catch {
    args = [];
  }

  let configFile = "../test.js";
  let testName: string | undefined;

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

export abstract class Benchmark {
  abstract run(iteration_id: number): void;
  abstract checksum(): number;

  get name(): string {
    return this.constructor.name;
  }

  prepare(): void {}

  get config(): Record<string, any> {
    const config = (Helper as any).CONFIG;
    return config && config[this.name] ? config[this.name] : {};
  }

  get warmupIterations(): number {
    const config = (Helper as any).CONFIG;
    if (config && config.warmup_iterations !== undefined) {
      return Number(config.warmup_iterations);
    }
    return Math.max(Math.floor(this.iterations * 0.2), 1);
  }

  warmup(): void {
    for (let i = 0; i < this.warmupIterations; i++) {
      this.run(i);
    }
  }

  runAll(): void {
    for (let i = 0; i < this.iterations; i++) {
      this.run(i);
    }
  }

  get iterations(): number {
    try {
      return Number(Helper.configI64(this.name, "iterations"));
    } catch {
      return 1;
    }
  }

  get expectedChecksum(): bigint {
    try {
      return Helper.configI64(this.name, "checksum");
    } catch {
      return 0n;
    }
  }

  private static NamedFactory = class {
    constructor(
      public name: string,
      public cls: new () => Benchmark,
    ) {}
  };

  private static benchmarkFactories: InstanceType<
    typeof Benchmark.NamedFactory
  >[] = [];

  static registerBenchmark(name: string, cls: new () => Benchmark): void {
    if (this.benchmarkFactories.some((f) => f.name === name)) {
      console.warn(
        `Warning: Benchmark with name "${name}" already registered. Skipping.`,
      );
      return;
    }
    this.benchmarkFactories.push(new this.NamedFactory(name, cls));
  }

  static run(singleBench?: string): void {
    const results: Record<string, number> = {};
    let summaryTime = 0;
    let ok = 0;
    let fails = 0;

    for (const factoryInfo of this.benchmarkFactories) {
      const benchName = factoryInfo.name;

      if (
        singleBench &&
        !benchName.toLowerCase().includes(singleBench.toLowerCase())
      ) {
        continue;
      }

      const config = (Helper as any).CONFIG;
      if (!config || !config[benchName]) {
        console.log(`\n[${benchName}]: SKIP - no config entry`);
        continue;
      }

      try {
        if (isNode || isBun) {
          // @ts-ignore
          process.stdout.write(`${benchName}: `);
        } else if (isDeno) {
          // @ts-ignore
          Deno.stdout.write(new TextEncoder().encode(`${benchName}: `));
        } else {
          console.log(`${benchName}: starting...`);
        }
      } catch {
        console.log(`${benchName}: `);
      }

      const bench = new factoryInfo.cls();

      Helper.reset();
      bench.prepare();
      bench.warmup();

      Helper.reset();

      const startTime = performance.now();
      bench.runAll();
      const endTime = performance.now();
      const timeDelta = (endTime - startTime) / 1000;

      results[benchName] = timeDelta;

      try {
        // @ts-ignore
        if (global.gc) {
          // @ts-ignore
          global.gc();
        }
      } catch {}

      const actualResult = BigInt(bench.checksum());
      const expectedResult = bench.expectedChecksum;

      if (actualResult === expectedResult) {
        try {
          if (isNode || isBun) {
            // @ts-ignore
            process.stdout.write("OK ");
          } else if (isDeno) {
            // @ts-ignore
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
            // @ts-ignore
            process.stdout.write(errorMsg);
          } else if (isDeno) {
            // @ts-ignore
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

    try {
      if (isNode) {
        // @ts-ignore
        const fs = require("fs");
        // @ts-ignore
        const path = require("path");
        fs.writeFileSync(
          "/tmp/results.js",
          `window.results = ${JSON.stringify(results)};`,
        );
      } else if (isBun) {
        // @ts-ignore
        const fs = require("fs");
        fs.writeFileSync(
          "/tmp/results.js",
          `window.results = ${JSON.stringify(results)};`,
        );
      }
    } catch {}

    console.log(
      `Summary: ${summaryTime.toFixed(4)}s, ${ok + fails}, ${ok}, ${fails}`,
    );

    if (fails > 0) {
      try {
        if (isDeno) {
          // @ts-ignore
          Deno.exit(1);
        } else if (isNode || isBun) {
          // @ts-ignore
          process.exit(1);
        }
      } catch {
        throw new Error("Benchmarks failed");
      }
    }
  }
}

export class Pidigits extends Benchmark {
  private nn: number;
  private resultBuffer: string[] = [];

  constructor() {
    super();
    this.nn = Number(Helper.configI64(this.name, "amount"));
  }

  run(_iteration_id: number): void {
    let i = 0;
    let k = 0;
    let ns = 0n;
    let a = 0n;
    let t = 0n;
    let u = 0n;
    let k1 = 1;
    let n = 1n;
    let d = 1n;

    while (true) {
      k += 1;
      t = n << 1n;
      n *= BigInt(k);
      k1 += 2;
      a = (a + t) * BigInt(k1);
      d *= BigInt(k1);

      if (a >= n) {
        const temp = n * 3n + a;
        t = temp / d;
        u = temp % d;
        u += n;

        if (d > u) {
          const digit = Number(t);
          ns = ns * 10n + BigInt(digit);
          i += 1;

          if (i % 10 === 0) {
            const line = ns.toString().padStart(10, "0") + `\t:${i}\n`;
            this.resultBuffer.push(line);
            ns = 0n;
          }

          if (i >= this.nn) {
            break;
          }

          a = (a - d * t) * 10n;
          n *= 10n;
        }
      }
    }

    if (ns !== 0n && this.resultBuffer.length > 0) {
      const remainingDigits = this.nn % 10 || 10;
      const line = ns.toString().padStart(remainingDigits, "0") + `\t:${i}\n`;
      this.resultBuffer.push(line);
    }
  }

  checksum(): number {
    return Helper.checksumString(this.resultBuffer.join(""));
  }
  override get name(): string {
    return "CLBG::Pidigits";
  }
}

class TreeNode {
  left: TreeNode | null = null;
  right: TreeNode | null = null;

  constructor(
    public item: number,
    depth: number = 0,
  ) {
    if (depth > 0) {
      this.left = new TreeNode(2 * item - 1, depth - 1);
      this.right = new TreeNode(2 * item, depth - 1);
    }
  }

  static create(item: number, depth: number): TreeNode {
    return new TreeNode(item, depth - 1);
  }

  check(): number {
    if (!this.left || !this.right) {
      return this.item;
    }
    return this.left.check() - this.right.check() + this.item;
  }
}

export class BinarytreesObj extends Benchmark {
  private n: number;
  private result: number = 0;

  constructor() {
    super();
    this.n = Number(Helper.configI64(this.name, "depth"));
  }

  run(_iteration_id: number): void {
    const root = new TreeNodeObj(0, this.n);
    this.result = (this.result + root.sum()) >>> 0;
  }

  checksum(): number {
    return this.result >>> 0;
  }

  override get name(): string {
    return "Binarytrees::Obj";
  }
}

class TreeNodeObj {
  left: TreeNodeObj | null = null;
  right: TreeNodeObj | null = null;

  constructor(
    public item: number,
    depth: number,
  ) {
    if (depth > 0) {
      const shift = 1 << (depth - 1);
      this.left = new TreeNodeObj(item - shift, depth - 1);
      this.right = new TreeNodeObj(item + shift, depth - 1);
    }
  }

  sum(): number {
    let total = (this.item >>> 0) + 1;
    if (this.left) total += this.left.sum();
    if (this.right) total += this.right.sum();
    return total >>> 0;
  }
}

export class BinarytreesArena extends Benchmark {
  private n: number;
  private result: number = 0;

  constructor() {
    super();
    this.n = Number(Helper.configI64(this.name, "depth"));
  }

  run(_iteration_id: number): void {
    var arena = new TreeArena();
    const rootIdx = arena.build(0, this.n);
    this.result = (this.result + arena.sum(rootIdx)) >>> 0;
  }

  checksum(): number {
    return this.result >>> 0;
  }
  override get name(): string {
    return "Binarytrees::Arena";
  }
}

interface TreeNodeArena {
  item: number;
  left: number;
  right: number;
}

class TreeArena {
  private nodes: TreeNodeArena[] = [];

  build(item: number, depth: number): number {
    const idx = this.nodes.length;
    this.nodes.push({ item, left: -1, right: -1 });

    if (depth > 0) {
      const shift = 1 << (depth - 1);
      const leftIdx = this.build(item - shift, depth - 1);
      const rightIdx = this.build(item + shift, depth - 1);
      this.nodes[idx].left = leftIdx;
      this.nodes[idx].right = rightIdx;
    }

    return idx;
  }

  sum(idx: number): number {
    const node = this.nodes[idx];
    let total = (node.item >>> 0) + 1;

    if (node.left >= 0) total += this.sum(node.left);
    if (node.right >= 0) total += this.sum(node.right);

    return total >>> 0;
  }

  clear(): void {
    this.nodes = [];
  }
}

class Tape {
  private tape: Uint8Array;
  private pos: number;

  constructor() {
    this.tape = new Uint8Array(30000);
    this.pos = 0;
  }

  get(): number {
    return this.tape[this.pos];
  }

  inc(): void {
    this.tape[this.pos] = (this.tape[this.pos] + 1) & 255;
  }

  dec(): void {
    this.tape[this.pos] = (this.tape[this.pos] - 1) & 255;
  }

  advance(): void {
    this.pos++;
    if (this.pos >= this.tape.length) {
      const newTape = new Uint8Array(this.tape.length + 1);
      newTape.set(this.tape);
      this.tape = newTape;
    }
  }

  devance(): void {
    if (this.pos > 0) {
      this.pos--;
    }
  }
}

class Program {
  private commands: Uint8Array;
  private jumps: number[];

  constructor(text: string) {
    const valid = new Set(["[", "]", "<", ">", "+", "-", ",", "."]);
    const bytes: number[] = [];
    for (let i = 0; i < text.length; i++) {
      const c = text[i];
      if (valid.has(c)) {
        bytes.push(c.charCodeAt(0));
      }
    }

    this.commands = new Uint8Array(bytes);
    this.jumps = new Array(this.commands.length).fill(0);
    const stack: number[] = [];

    for (let i = 0; i < this.commands.length; i++) {
      const cmd = this.commands[i];
      if (cmd === 91) {
        stack.push(i);
      } else if (cmd === 93 && stack.length > 0) {
        const start = stack.pop()!;
        this.jumps[start] = i;
        this.jumps[i] = start;
      }
    }
  }

  run(): number {
    let result = 0;
    const tape = new Tape();
    let pc = 0;
    const commands = this.commands;
    const jumps = this.jumps;

    while (pc < commands.length) {
      const cmd = commands[pc];

      switch (cmd) {
        case 43:
          tape.inc();
          break;
        case 45:
          tape.dec();
          break;
        case 62:
          tape.advance();
          break;
        case 60:
          tape.devance();
          break;
        case 91:
          if (tape.get() === 0) {
            pc = jumps[pc];
          }
          break;
        case 93:
          if (tape.get() !== 0) {
            pc = jumps[pc];
          }
          break;
        case 46:
          result = ((result << 2) + tape.get()) >>> 0;
          break;
      }

      pc++;
    }

    return result;
  }
}

export class BrainfuckArray extends Benchmark {
  private programText: string;
  private warmupText: string;
  private resultValue: number = 0;

  constructor() {
    super();
    this.programText = Helper.configS(this.name, "program");
    this.warmupText = Helper.configS(this.name, "warmup_program");
  }

  warmup(): void {
    const prepareIters = this.warmupIterations;
    for (let i = 0; i < prepareIters; i++) {
      new Program(this.warmupText).run();
    }
  }

  run(_iteration_id: number): void {
    const result = new Program(this.programText).run();
    this.resultValue = (this.resultValue + result) >>> 0;
  }

  checksum(): number {
    return this.resultValue >>> 0;
  }

  override get name(): string {
    return "Brainfuck::Array";
  }
}

const enum OpType {
  INC,
  DEC,
  NEXT,
  PREV,
  PRINT,
  LOOP,
}

type Op = {
  type: OpType;
  loop?: Op[];
};

class Tape2 {
  private tape: Uint8Array;
  private pos: number;

  constructor() {
    this.tape = new Uint8Array(30000);
    this.pos = 0;
  }

  get(): number {
    return this.tape[this.pos];
  }

  inc(): void {
    this.tape[this.pos]++;
  }

  dec(): void {
    this.tape[this.pos]--;
  }

  next(): void {
    this.pos++;
    if (this.pos >= this.tape.length) {
      const newTape = new Uint8Array(this.tape.length + 1);
      newTape.set(this.tape);
      this.tape = newTape;
    }
  }

  prev(): void {
    if (this.pos > 0) {
      this.pos--;
    }
  }
}

class Program2 {
  private ops: Op[];
  private resultValue: number;

  constructor(code: string) {
    this.ops = this.parse(code);
    this.resultValue = 0;
  }

  run(): number {
    this.runOps(this.ops, new Tape2());
    return this.resultValue >>> 0;
  }

  private runOps(program: Op[], tape: Tape2): void {
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
            this.runOps(op.loop!, tape);
          }
          break;
      }
    }
  }

  private parse(code: string): Op[] {
    const chars = Array.from(code);
    return this.parseSequence(chars, 0)[0];
  }

  private parseSequence(chars: string[], index: number): [Op[], number] {
    const result: Op[] = [];
    let i = index;

    while (i < chars.length) {
      const c = chars[i];
      i++;

      let op: Op | null = null;

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

export class BrainfuckRecursion extends Benchmark {
  private text: string;
  private resultValue: number;

  constructor() {
    super();
    this.text = Helper.configS(this.name, "program");
    this.resultValue = 0;
  }

  warmup(): void {
    const warmupProgram = Helper.configS(this.name, "warmup_program");
    for (let i = 0; i < this.warmupIterations; i++) {
      const program = new Program2(warmupProgram);
      program.run();
    }
  }

  run(_iteration_id: number): void {
    const program = new Program2(this.text);
    this.resultValue = (this.resultValue + program.run()) >>> 0;
  }

  checksum(): number {
    return this.resultValue >>> 0;
  }
  override get name(): string {
    return "Brainfuck::Recursion";
  }
}

export class Fannkuchredux extends Benchmark {
  private n: number;
  private resultValue: number = 0;

  constructor() {
    super();
    this.n = Number(Helper.configI64(this.name, "n"));
  }

  private fannkuchredux(n: number): [number, number] {
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

  run(_iteration_id: number): void {
    const [checksum, maxFlipsCount] = this.fannkuchredux(this.n);
    this.resultValue += checksum * 100 + maxFlipsCount;
  }

  checksum(): number {
    return this.resultValue;
  }
  override get name(): string {
    return "CLBG::Fannkuchredux";
  }
}

interface Gene {
  char: string;
  prob: number;
}

export class Fasta extends Benchmark {
  private static readonly LINE_LENGTH = 60;

  private static readonly IUB: Gene[] = [
    { char: "a", prob: 0.27 },
    { char: "c", prob: 0.39 },
    { char: "g", prob: 0.51 },
    { char: "t", prob: 0.78 },
    { char: "B", prob: 0.8 },
    { char: "D", prob: 0.8200000000000001 },
    { char: "H", prob: 0.8400000000000001 },
    { char: "K", prob: 0.8600000000000001 },
    { char: "M", prob: 0.8800000000000001 },
    { char: "N", prob: 0.9000000000000001 },
    { char: "R", prob: 0.9200000000000002 },
    { char: "S", prob: 0.9400000000000002 },
    { char: "V", prob: 0.9600000000000002 },
    { char: "W", prob: 0.9800000000000002 },
    { char: "Y", prob: 1.0000000000000002 },
  ];

  private static readonly HOMO: Gene[] = [
    { char: "a", prob: 0.302954942668 },
    { char: "c", prob: 0.5009432431601 },
    { char: "g", prob: 0.6984905497992 },
    { char: "t", prob: 1.0 },
  ];

  private static readonly ALU =
    "GGCCGGGCGCGGTGGCTCACGCCTGTAATCCCAGCACTTTGGGAGGCCGAGGCGGGCGGATCACCTGAGGTCAGGAGTTCGAGACCAGCCTGGCCAACATGGTGAAACCCCGTCTCTACTAAAAATACAAAAATTAGCCGGGCGTGGTGGCGCGCGCCTGTAATCCCAGCTACTCGGGAGGCTGAGGCAGGAGAATCGCTTGAACCCGGGAGGCGGAGGTTGCAGTGAGCCGAGATCGCGCCACTGCACTCCAGCCTGGGCGACAGAGCGAGACTCCGTCTCAAAAA";

  public n: number;
  public resultStr: string = "";

  constructor() {
    super();
    this.n = Number(Helper.configI64(this.name, "n"));
  }

  setIterations(count: number): void {
    this.n = count;
  }

  private selectRandom(genelist: Gene[]): string {
    const r = Helper.nextFloat();
    if (r < genelist[0].prob) {
      return genelist[0].char;
    }

    let lo = 0;
    let hi = genelist.length - 1;

    while (hi > lo + 1) {
      const i = Math.floor((hi + lo) / 2);
      if (r < genelist[i].prob) {
        hi = i;
      } else {
        lo = i;
      }
    }
    return genelist[hi].char;
  }

  private makeRandomFasta(
    id: string,
    desc: string,
    genelist: Gene[],
    n: number,
  ): void {
    const lines: string[] = [];
    lines.push(`>${id} ${desc}`);

    let todo = n;

    while (todo > 0) {
      const m = todo < Fasta.LINE_LENGTH ? todo : Fasta.LINE_LENGTH;
      const lineChars: string[] = new Array(m);

      for (let i = 0; i < m; i++) {
        lineChars[i] = this.selectRandom(genelist);
      }

      lines.push(lineChars.join(""));
      todo -= Fasta.LINE_LENGTH;
    }

    this.resultStr += lines.join("\n") + "\n";
  }

  private makeRepeatFasta(
    id: string,
    desc: string,
    s: string,
    n: number,
  ): void {
    let todo = n;
    let k = 0;
    const kn = s.length;

    this.resultStr += `>${id} ${desc}\n`;

    while (todo > 0) {
      const m = todo < Fasta.LINE_LENGTH ? todo : Fasta.LINE_LENGTH;
      let remaining = m;

      while (remaining >= kn - k) {
        this.resultStr += s.slice(k);
        remaining -= kn - k;
        k = 0;
      }

      if (remaining > 0) {
        this.resultStr += s.slice(k, k + remaining);
        k += remaining;
      }

      this.resultStr += "\n";
      todo -= Fasta.LINE_LENGTH;
    }
  }

  run(_iteration_id: number): void {
    this.makeRepeatFasta("ONE", "Homo sapiens alu", Fasta.ALU, this.n * 2);
    this.makeRandomFasta("TWO", "IUB ambiguity codes", Fasta.IUB, this.n * 3);
    this.makeRandomFasta(
      "THREE",
      "Homo sapiens frequency",
      Fasta.HOMO,
      this.n * 5,
    );
  }

  checksum(): number {
    return Helper.checksumString(this.resultStr);
  }
  override get name(): string {
    return "CLBG::Fasta";
  }
}

export class Knuckeotide extends Benchmark {
  private seq: string = "";
  private resultStr: string = "";

  private frequency(
    seq: string,
    length: number,
  ): { n: number; table: Map<string, number> } {
    const n = seq.length - length + 1;
    const table = new Map<string, number>();

    for (let i = 0; i < n; i++) {
      const key = seq.slice(i, i + length);
      table.set(key, (table.get(key) || 0) + 1);
    }

    return { n, table };
  }

  private sortByFreq(seq: string, length: number): void {
    const { n, table } = this.frequency(seq, length);

    const sorted = Array.from(table.entries()).sort((a, b) => b[1] - a[1]);

    for (const [key, count] of sorted) {
      const freq = (count * 100) / n;
      this.resultStr += `${key.toUpperCase()} ${freq.toFixed(3)}\n`;
    }

    this.resultStr += "\n";
  }

  private findSeq(seq: string, s: string): void {
    const { n, table } = this.frequency(seq, s.length);
    const count = table.get(s.toLowerCase()) || 0;
    this.resultStr += `${count}\t${s.toUpperCase()}\n`;
  }

  prepare(): void {
    const n = Number(Helper.configI64(this.name, "n"));

    const fasta = new Fasta();
    fasta.n = n;
    fasta.prepare();
    fasta.run(0);

    const fastaOutput = fasta.resultStr;

    let seq = "";
    let afterThree = false;

    const lines = fastaOutput.split("\n");
    for (const line of lines) {
      if (line.startsWith(">THREE")) {
        afterThree = true;
        continue;
      }

      if (afterThree) {
        if (line.startsWith(">")) {
          break;
        }
        seq += line.trim();
      }
    }

    this.seq = seq;
  }

  run(_iteration_id: number): void {
    for (let i = 1; i <= 2; i++) {
      this.sortByFreq(this.seq, i);
    }

    const sequences = [
      "ggt",
      "ggta",
      "ggtatt",
      "ggtattttaatt",
      "ggtattttaatttatagt",
    ];
    for (const s of sequences) {
      this.findSeq(this.seq, s);
    }
  }

  checksum(): number {
    return Helper.checksumString(this.resultStr);
  }
  override get name(): string {
    return "CLBG::Knuckeotide";
  }
}

export class Mandelbrot extends Benchmark {
  private static readonly ITER = 50;
  private static readonly LIMIT = 2.0;

  private w: number;
  private h: number;
  private resultBytes: number[] = [];

  constructor() {
    super();
    this.w = Number(Helper.configI64(this.name, "w"));
    this.h = Number(Helper.configI64(this.name, "h"));
  }

  run(_iteration_id: number): void {
    const header = `P4\n${this.w} ${this.h}\n`;

    this.resultBytes.push(...Array.from(header, (c) => c.charCodeAt(0)));

    let bitNum = 0;
    let byteAcc = 0;

    for (let y = 0; y < this.h; y++) {
      for (let x = 0; x < this.w; x++) {
        let zr = 0.0;
        let zi = 0.0;
        let tr = 0.0;
        let ti = 0.0;

        const cr = (2.0 * x) / this.w - 1.5;
        const ci = (2.0 * y) / this.h - 1.0;

        let i = 0;
        while (
          i < Mandelbrot.ITER &&
          tr + ti <= Mandelbrot.LIMIT * Mandelbrot.LIMIT
        ) {
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

  checksum(): number {
    const bytes = new Uint8Array(this.resultBytes);
    return Helper.checksumBytes(bytes);
  }
  override get name(): string {
    return "CLBG::Mandelbrot";
  }
}

export class Matmul1T extends Benchmark {
  private n: number;
  private resultValue: number = 0;

  constructor() {
    super();
    this.n = Number(Helper.configI64(this.name, "n"));
  }

  private matmul(a: number[][], b: number[][]): number[][] {
    const m = a.length;
    const n = a[0].length;
    const p = b[0].length;

    const b2: number[][] = Array(p)
      .fill(0)
      .map(() => Array(n).fill(0));
    for (let i = 0; i < n; i++) {
      for (let j = 0; j < p; j++) {
        b2[j][i] = b[i][j];
      }
    }

    const c: number[][] = Array(m)
      .fill(0)
      .map(() => Array(p).fill(0));

    for (let i = 0; i < m; i++) {
      const ai = a[i];
      const ci = c[i];

      for (let j = 0; j < p; j++) {
        const b2j = b2[j];
        let s = 0.0;

        for (let k = 0; k < n; k++) {
          s += ai[k] * b2j[k];
        }

        ci[j] = s;
      }
    }

    return c;
  }

  private matgen(n: number): number[][] {
    const tmp = 1.0 / n / n;
    const a: number[][] = Array(n)
      .fill(0)
      .map(() => Array(n).fill(0));

    for (let i = 0; i < n; i++) {
      for (let j = 0; j < n; j++) {
        a[i][j] = tmp * (i - j) * (i + j);
      }
    }

    return a;
  }

  run(_iteration_id: number): void {
    const a = this.matgen(this.n);
    const b = this.matgen(this.n);
    const c = this.matmul(a, b);
    const value = c[this.n >> 1][this.n >> 1];

    this.resultValue =
      (this.resultValue + Helper.checksumFloat(value)) & 0xffffffff;
  }

  checksum(): number {
    return this.resultValue >>> 0;
  }
  override get name(): string {
    return "Matmul::T1";
  }
}

export class Matmul4T extends Benchmark {
  private n: number;
  private resultValue: number = 0;

  constructor() {
    super();
    this.n = Number(Helper.configI64(this.name, "n"));
  }

  private matgen(n: number): number[][] {
    const tmp = 1.0 / n / n;
    const a: number[][] = Array(n)
      .fill(0)
      .map(() => Array(n).fill(0));

    for (let i = 0; i < n; i++) {
      for (let j = 0; j < n; j++) {
        a[i][j] = tmp * (i - j) * (i + j);
      }
    }

    return a;
  }

  private matmulParallel(a: number[][], b: number[][]): number[][] {
    const size = a.length;

    const bT: number[][] = Array(size)
      .fill(0)
      .map(() => Array(size).fill(0));
    for (let i = 0; i < size; i++) {
      for (let j = 0; j < size; j++) {
        bT[j][i] = b[i][j];
      }
    }

    const c: number[][] = Array(size)
      .fill(0)
      .map(() => Array(size).fill(0));

    const numParts = 4;
    const rowsPerPart = Math.ceil(size / numParts);

    for (let part = 0; part < numParts; part++) {
      const startRow = part * rowsPerPart;
      const endRow = Math.min(startRow + rowsPerPart, size);

      for (let i = startRow; i < endRow; i++) {
        const ai = a[i];
        const ci = c[i];

        for (let j = 0; j < size; j++) {
          let sum = 0.0;
          const bTj = bT[j];

          for (let k = 0; k < size; k++) {
            sum += ai[k] * bTj[k];
          }

          ci[j] = sum;
        }
      }
    }

    return c;
  }

  run(_iteration_id: number): void {
    const a = this.matgen(this.n);
    const b = this.matgen(this.n);
    const c = this.matmulParallel(a, b);
    const value = c[this.n >> 1][this.n >> 1];

    this.resultValue =
      (this.resultValue + Helper.checksumFloat(value)) & 0xffffffff;
  }

  checksum(): number {
    return this.resultValue >>> 0;
  }
  override get name(): string {
    return "Matmul::T4";
  }
}

export class Matmul8T extends Benchmark {
  private n: number;
  private resultValue: number = 0;

  constructor() {
    super();
    this.n = Number(Helper.configI64(this.name, "n"));
  }

  private matgen(n: number): number[][] {
    const tmp = 1.0 / n / n;
    const a: number[][] = Array(n)
      .fill(0)
      .map(() => Array(n).fill(0));

    for (let i = 0; i < n; i++) {
      for (let j = 0; j < n; j++) {
        a[i][j] = tmp * (i - j) * (i + j);
      }
    }

    return a;
  }

  private matmulParallel(a: number[][], b: number[][]): number[][] {
    const size = a.length;

    const bT: number[][] = Array(size)
      .fill(0)
      .map(() => Array(size).fill(0));
    for (let i = 0; i < size; i++) {
      for (let j = 0; j < size; j++) {
        bT[j][i] = b[i][j];
      }
    }

    const c: number[][] = Array(size)
      .fill(0)
      .map(() => Array(size).fill(0));

    const numParts = 8;
    const rowsPerPart = Math.ceil(size / numParts);

    for (let part = 0; part < numParts; part++) {
      const startRow = part * rowsPerPart;
      const endRow = Math.min(startRow + rowsPerPart, size);

      for (let i = startRow; i < endRow; i++) {
        const ai = a[i];
        const ci = c[i];

        for (let j = 0; j < size; j++) {
          let sum = 0.0;
          const bTj = bT[j];

          for (let k = 0; k < size; k++) {
            sum += ai[k] * bTj[k];
          }

          ci[j] = sum;
        }
      }
    }

    return c;
  }

  run(_iteration_id: number): void {
    const a = this.matgen(this.n);
    const b = this.matgen(this.n);
    const c = this.matmulParallel(a, b);
    const value = c[this.n >> 1][this.n >> 1];

    this.resultValue =
      (this.resultValue + Helper.checksumFloat(value)) & 0xffffffff;
  }

  checksum(): number {
    return this.resultValue >>> 0;
  }
  override get name(): string {
    return "Matmul::T8";
  }
}

export class Matmul16T extends Benchmark {
  private n: number;
  private resultValue: number = 0;

  constructor() {
    super();
    this.n = Number(Helper.configI64(this.name, "n"));
  }

  private matgen(n: number): number[][] {
    const tmp = 1.0 / n / n;
    const a: number[][] = Array(n)
      .fill(0)
      .map(() => Array(n).fill(0));

    for (let i = 0; i < n; i++) {
      for (let j = 0; j < n; j++) {
        a[i][j] = tmp * (i - j) * (i + j);
      }
    }

    return a;
  }

  private matmulParallel(a: number[][], b: number[][]): number[][] {
    const size = a.length;

    const bT: number[][] = Array(size)
      .fill(0)
      .map(() => Array(size).fill(0));
    for (let i = 0; i < size; i++) {
      for (let j = 0; j < size; j++) {
        bT[j][i] = b[i][j];
      }
    }

    const c: number[][] = Array(size)
      .fill(0)
      .map(() => Array(size).fill(0));

    const numParts = 16;
    const rowsPerPart = Math.ceil(size / numParts);

    for (let part = 0; part < numParts; part++) {
      const startRow = part * rowsPerPart;
      const endRow = Math.min(startRow + rowsPerPart, size);

      for (let i = startRow; i < endRow; i++) {
        const ai = a[i];
        const ci = c[i];

        for (let j = 0; j < size; j++) {
          let sum = 0.0;
          const bTj = bT[j];

          for (let k = 0; k < size; k++) {
            sum += ai[k] * bTj[k];
          }

          ci[j] = sum;
        }
      }
    }

    return c;
  }

  run(_iteration_id: number): void {
    const a = this.matgen(this.n);
    const b = this.matgen(this.n);
    const c = this.matmulParallel(a, b);
    const value = c[this.n >> 1][this.n >> 1];

    this.resultValue =
      (this.resultValue + Helper.checksumFloat(value)) & 0xffffffff;
  }

  checksum(): number {
    return this.resultValue >>> 0;
  }
  override get name(): string {
    return "Matmul::T16";
  }
}

const SOLAR_MASS = 4 * Math.PI * Math.PI;
const DAYS_PER_YEAR = 365.24;

class Planet {
  x: number;
  y: number;
  z: number;
  vx: number;
  vy: number;
  vz: number;
  mass: number;

  constructor(
    x: number,
    y: number,
    z: number,
    vx: number,
    vy: number,
    vz: number,
    mass: number,
  ) {
    this.x = x;
    this.y = y;
    this.z = z;
    this.vx = vx * DAYS_PER_YEAR;
    this.vy = vy * DAYS_PER_YEAR;
    this.vz = vz * DAYS_PER_YEAR;
    this.mass = mass * SOLAR_MASS;
  }

  moveFromI(bodies: Planet[], nbodies: number, dt: number, i: number): void {
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

export class Nbody extends Benchmark {
  static readonly SOLAR_MASS = SOLAR_MASS;
  static readonly DAYS_PER_YEAR = DAYS_PER_YEAR;

  private static readonly BODIES: Planet[] = [
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

  private bodies: Planet[];
  private resultValue: bigint = 0n;
  private v1: number = 0;

  constructor() {
    super();
    this.bodies = Nbody.BODIES.map((p) => {
      return new Planet(
        p.x,
        p.y,
        p.z,
        p.vx / DAYS_PER_YEAR,
        p.vy / DAYS_PER_YEAR,
        p.vz / DAYS_PER_YEAR,
        p.mass / SOLAR_MASS,
      );
    });
  }

  private energy(bodies: Planet[]): number {
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

  private offsetMomentum(bodies: Planet[]): void {
    let px = 0.0;
    let py = 0.0;
    let pz = 0.0;

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

  prepare(): void {
    this.offsetMomentum(this.bodies);
    this.v1 = this.energy(this.bodies);
  }

  run(_iteration_id: number): void {
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

  checksum(): number {
    const v2 = this.energy(this.bodies);
    const checksum1 = Helper.checksumFloat(this.v1);
    const checksum2 = Helper.checksumFloat(v2);

    return (checksum1 << 5) & checksum2 & 0xffffffff;
  }
  override get name(): string {
    return "CLBG::Nbody";
  }
}

export class RegexDna extends Benchmark {
  private seq: string = "";
  private ilen: number = 0;
  private clen: number = 0;
  private resultStr: string = "";

  prepare(): void {
    const n = Number(Helper.configI64(this.name, "n"));

    const fasta = new Fasta();
    fasta.n = n;
    fasta.prepare();
    fasta.run(0);

    const fastaOutput = fasta.resultStr;

    let seq = "";
    let totalBytes = 0;

    const lines = fastaOutput.split("\n");
    for (let i = 0; i < lines.length; i++) {
      const line = lines[i];

      const lineBytes = new TextEncoder().encode(line).length;

      if (i < lines.length - 1) {
        totalBytes += lineBytes + 1;
      } else if (line.length > 0) {
        totalBytes += lineBytes;
      } else {
      }

      if (!line.startsWith(">")) {
        seq += line.trim();
      }
    }

    totalBytes = new TextEncoder().encode(fastaOutput).length;

    this.seq = seq;
    this.ilen = totalBytes;
    this.clen = new TextEncoder().encode(seq).length;
  }

  run(_iteration_id: number): void {
    const patterns = [
      /agggtaaa|tttaccct/gi,
      /[cgt]gggtaaa|tttaccc[acg]/gi,
      /a[act]ggtaaa|tttacc[agt]t/gi,
      /ag[act]gtaaa|tttac[agt]ct/gi,
      /agg[act]taaa|ttta[agt]cct/gi,
      /aggg[acg]aaa|ttt[cgt]ccct/gi,
      /agggt[cgt]aa|tt[acg]accct/gi,
      /agggta[cgt]a|t[acg]taccct/gi,
      /agggtaa[cgt]|[acg]ttaccct/gi,
    ];

    for (const pattern of patterns) {
      const matches = this.seq.match(pattern) || [];
      this.resultStr += `${pattern.source} ${matches.length}\n`;
    }

    const replacements: Record<string, string> = {
      B: "(c|g|t)",
      D: "(a|g|t)",
      H: "(a|c|t)",
      K: "(g|t)",
      M: "(a|c)",
      N: "(a|c|g|t)",
      R: "(a|g)",
      S: "(c|t)",
      V: "(a|c|g)",
      W: "(a|t)",
      Y: "(c|t)",
    };

    let modifiedSeq = this.seq;
    for (const [key, value] of Object.entries(replacements)) {
      const regex = new RegExp(key, "gi");
      const before = modifiedSeq.length;
      modifiedSeq = modifiedSeq.replace(regex, value);
    }

    this.resultStr += `\n${this.ilen}\n${this.clen}\n${modifiedSeq.length}\n`;
  }

  checksum(): number {
    return Helper.checksumString(this.resultStr);
  }
  override get name(): string {
    return "CLBG::RegexDna";
  }
}

export class Revcomp extends Benchmark {
  private input: string = "";
  private resultValue: number = 0;

  private static lookupTable: Uint8Array | null = null;

  private static readonly FROM = "wsatugcyrkmbdhvnATUGCYRKMBDHVN";
  private static readonly TO = "WSTAACGRYMKVHDBNTAACGRYMKVHDBN";

  prepare(): void {
    const n = Number(Helper.configI64(this.name, "n"));

    const fasta = new Fasta();
    fasta.n = n;
    fasta.prepare();
    fasta.run(0);

    const fastaOutput = fasta.resultStr;

    const lines = fastaOutput.split("\n");
    const seqParts: string[] = [];
    let partCount = 0;

    for (const line of lines) {
      if (line.startsWith(">")) {
        seqParts[partCount++] = "\n---\n";
      } else if (line.trim()) {
        seqParts[partCount++] = line.trim();
      }
    }

    this.input = seqParts.join("");
  }

  private static initLookupTable(): Uint8Array {
    if (Revcomp.lookupTable) {
      return Revcomp.lookupTable;
    }

    const lookup = new Uint8Array(256);
    for (let i = 0; i < 256; i++) lookup[i] = i;

    for (let i = 0; i < Revcomp.FROM.length; i++) {
      const fromChar = Revcomp.FROM.charCodeAt(i);
      const toChar = Revcomp.TO.charCodeAt(i);
      lookup[fromChar] = toChar;
    }

    Revcomp.lookupTable = lookup;
    return lookup;
  }

  private revcompGoStyle(seq: string): string {
    const len = seq.length;
    const lookup = Revcomp.initLookupTable();

    const lineLength = 60;
    const numLines = Math.ceil(len / lineLength);
    const resultBytes = new Uint8Array(len + numLines);

    let writePos = 0;
    let readPos = len - 1;

    for (let line = 0; line < numLines; line++) {
      const charsInLine = Math.min(lineLength, readPos + 1);

      for (let i = 0; i < charsInLine; i++) {
        const charCode = seq.charCodeAt(readPos--);
        resultBytes[writePos++] = lookup[charCode];
      }

      resultBytes[writePos++] = 10;
    }

    const decoder = new TextDecoder("ascii");
    return decoder.decode(resultBytes);
  }

  run(_iteration_id: number): void {
    const v = Helper.checksumString(this.revcompGoStyle(this.input));
    this.resultValue = (this.resultValue + v) >>> 0;
  }

  checksum(): number {
    return this.resultValue;
  }
  override get name(): string {
    return "CLBG::Revcomp";
  }
}

export class Spectralnorm extends Benchmark {
  private size: number;
  private u: number[];
  private v: number[];

  constructor() {
    super();
    this.size = Number(Helper.configI64(this.name, "size"));
    this.u = new Array(this.size).fill(1.0);
    this.v = new Array(this.size).fill(1.0);
  }

  private evalA(i: number, j: number): number {
    return 1.0 / (((i + j) * (i + j + 1)) / 2.0 + i + 1.0);
  }

  private evalATimesU(u: number[]): number[] {
    const n = u.length;
    const result: number[] = new Array(n).fill(0);

    for (let i = 0; i < n; i++) {
      let v = 0.0;
      for (let j = 0; j < n; j++) {
        v += this.evalA(i, j) * u[j];
      }
      result[i] = v;
    }

    return result;
  }

  private evalAtTimesU(u: number[]): number[] {
    const n = u.length;
    const result: number[] = new Array(n).fill(0);

    for (let i = 0; i < n; i++) {
      let v = 0.0;
      for (let j = 0; j < n; j++) {
        v += this.evalA(j, i) * u[j];
      }
      result[i] = v;
    }

    return result;
  }

  private evalAtATimesU(u: number[]): number[] {
    return this.evalAtTimesU(this.evalATimesU(u));
  }

  run(_iteration_id: number): void {
    this.v = this.evalAtATimesU(this.u);
    this.u = this.evalAtATimesU(this.v);
  }

  checksum(): number {
    let vBv = 0.0;
    let vv = 0.0;

    for (let i = 0; i < this.size; i++) {
      vBv += this.u[i] * this.v[i];
      vv += this.v[i] * this.v[i];
    }

    const result = Math.sqrt(vBv / vv);
    return Helper.checksumFloat(result);
  }
  override get name(): string {
    return "CLBG::Spectralnorm";
  }
}

export class Base64Encode extends Benchmark {
  private n: number;
  private str: string = "";
  private str2: string = "";
  private resultValue: number = 0;

  constructor() {
    super();
    this.n = Number(Helper.configI64(this.name, "size"));
  }

  prepare(): void {
    this.str = "a".repeat(this.n);
    this.str2 = btoa(this.str);
  }

  run(_iteration_id: number): void {
    this.str2 = btoa(this.str);
    this.resultValue = (this.resultValue + this.str2.length) >>> 0;
  }

  checksum(): number {
    const output = `encode ${this.str.slice(0, 4)}... to ${this.str2.slice(0, 4)}...: ${this.resultValue}`;
    return Helper.checksumString(output);
  }
  override get name(): string {
    return "Base64::Encode";
  }
}

export class Base64Decode extends Benchmark {
  private n: number;
  private str2: string = "";
  private str3: string = "";
  private resultValue: number = 0;

  constructor() {
    super();
    this.n = Number(Helper.configI64(this.name, "size"));
  }

  prepare(): void {
    const str = "a".repeat(this.n);
    this.str2 = btoa(str);
    this.str3 = atob(this.str2);
  }

  run(_iteration_id: number): void {
    this.str3 = atob(this.str2);
    this.resultValue = (this.resultValue + this.str3.length) >>> 0;
  }

  checksum(): number {
    const output = `decode ${this.str2.slice(0, 4)}... to ${this.str3.slice(0, 4)}...: ${this.resultValue}`;
    return Helper.checksumString(output);
  }
  override get name(): string {
    return "Base64::Decode";
  }
}

export class JsonGenerate extends Benchmark {
  public n: number;
  private data: any[] = [];
  private text: string = "";
  private result: number = 0;

  constructor() {
    super();
    this.n = Number(Helper.configI64(this.name, "coords"));
  }

  prepare(): void {
    this.data = [];

    for (let i = 0; i < this.n; i++) {
      this.data.push({
        x: parseFloat(Helper.nextFloat().toFixed(8)),
        y: parseFloat(Helper.nextFloat().toFixed(8)),
        z: parseFloat(Helper.nextFloat().toFixed(8)),
        name: `${Helper.nextFloat().toFixed(7)} ${Helper.nextInt(10000)}`,
        opts: {
          "1": [1, true],
        },
      });
    }
  }

  run(_iteration_id: number): void {
    const jsonData = {
      coordinates: this.data,
      info: "some info",
    };

    this.text = JSON.stringify(jsonData, null, 0);

    if (this.text.startsWith('{"coordinates":')) {
      this.result++;
    }
  }

  getText(): string {
    return this.text;
  }

  checksum(): number {
    return this.result >>> 0;
  }
  override get name(): string {
    return "Json::Generate";
  }
}

export class JsonParseDom extends Benchmark {
  private text: string = "";
  private resultValue: number = 0;

  prepare(): void {
    const jsonGen = new JsonGenerate();
    jsonGen.n = Number(Helper.configI64(this.name, "coords"));
    jsonGen.prepare();
    jsonGen.run(0);
    this.text = jsonGen.getText();
  }

  private calc(text: string): [number, number, number] {
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

  run(_iteration_id: number): void {
    const [x, y, z] = this.calc(this.text);

    this.resultValue =
      (this.resultValue + Helper.checksumFloat(x)) & 0xffffffff;
    this.resultValue =
      (this.resultValue + Helper.checksumFloat(y)) & 0xffffffff;
    this.resultValue =
      (this.resultValue + Helper.checksumFloat(z)) & 0xffffffff;
  }

  checksum(): number {
    return this.resultValue >>> 0;
  }
  override get name(): string {
    return "Json::ParseDom";
  }
}

interface Coordinate {
  x: number;
  y: number;
  z: number;
}

interface CoordinatesData {
  coordinates: Coordinate[];
}

export class JsonParseMapping extends Benchmark {
  private text: string = "";
  private resultValue: number = 0;

  prepare(): void {
    const jsonGen = new JsonGenerate();
    jsonGen.n = Number(Helper.configI64(this.name, "coords"));
    jsonGen.prepare();
    jsonGen.run(0);
    this.text = jsonGen.getText();
  }

  private calc(text: string): Coordinate {
    const data: CoordinatesData = JSON.parse(text);
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

    return {
      x: x / len,
      y: y / len,
      z: z / len,
    };
  }

  run(_iteration_id: number): void {
    const coord = this.calc(this.text);

    this.resultValue =
      (this.resultValue + Helper.checksumFloat(coord.x)) & 0xffffffff;
    this.resultValue =
      (this.resultValue + Helper.checksumFloat(coord.y)) & 0xffffffff;
    this.resultValue =
      (this.resultValue + Helper.checksumFloat(coord.z)) & 0xffffffff;
  }

  checksum(): number {
    return this.resultValue >>> 0;
  }
  override get name(): string {
    return "Json::ParseMapping";
  }
}

class PrimesNode {
  children: (PrimesNode | null)[] = new Array(10).fill(null);
  terminal: boolean = false;
}

export class Primes extends Benchmark {
  private n: bigint;
  private prefix: bigint;
  private resultValue: number = 5432;

  constructor() {
    super();
    this.n = Helper.configI64(this.name, "limit");
    this.prefix = Helper.configI64(this.name, "prefix");
  }

  private generatePrimes(limit: number): number[] {
    if (limit < 2) return [];

    const isPrime = new Array(limit + 1).fill(true);
    isPrime[0] = isPrime[1] = false;

    const sqrtLimit = Math.floor(Math.sqrt(limit));

    for (let p = 2; p <= sqrtLimit; p++) {
      if (isPrime[p]) {
        for (let multiple = p * p; multiple <= limit; multiple += p) {
          isPrime[multiple] = false;
        }
      }
    }

    const estimatedSize = Math.floor(limit / (Math.log(limit) - 1.1));
    const primes: number[] = [];
    primes.length = estimatedSize;
    let count = 0;

    for (let i = 2; i <= limit; i++) {
      if (isPrime[i]) {
        primes[count++] = i;
      }
    }

    primes.length = count;
    return primes;
  }

  private buildTrie(numbers: number[]): PrimesNode {
    const root = new PrimesNode();

    for (const num of numbers) {
      let current = root;
      const str = num.toString();

      for (let i = 0; i < str.length; i++) {
        const digit = str.charCodeAt(i) - 48;

        if (current.children[digit] === null) {
          current.children[digit] = new PrimesNode();
        }
        current = current.children[digit]!;
      }
      current.terminal = true;
    }

    return root;
  }

  private findPrimesWithPrefix(root: PrimesNode, prefix: number): number[] {
    const prefixStr = prefix.toString();
    let current = root;

    for (let i = 0; i < prefixStr.length; i++) {
      const digit = prefixStr.charCodeAt(i) - 48;
      const next = current.children[digit];
      if (next === null) {
        return [];
      }
      current = next;
    }

    const results: number[] = [];
    const queue: Array<[PrimesNode, number]> = [];
    queue.push([current, prefix]);

    while (queue.length > 0) {
      const [node, number] = queue.shift()!;

      if (node.terminal) {
        results.push(number);
      }

      for (let digit = 0; digit < 10; digit++) {
        const child = node.children[digit];
        if (child !== null) {
          queue.push([child, number * 10 + digit]);
        }
      }
    }

    results.sort((a, b) => a - b);
    return results;
  }

  run(_iteration_id: number): void {
    const primes = this.generatePrimes(Number(this.n));
    const trie = this.buildTrie(primes);
    const results = this.findPrimesWithPrefix(trie, Number(this.prefix));

    this.resultValue = (this.resultValue + results.length) & 0xffffffff;
    for (const num of results) {
      this.resultValue = (this.resultValue + num) & 0xffffffff;
    }
  }

  checksum(): number {
    return this.resultValue;
  }
  override get name(): string {
    return "Etc::Primes";
  }
}

class NoiseVec2 {
  constructor(
    public x: number,
    public y: number,
  ) {}
}

class Noise2DContext {
  private size: number;
  private mask: number;
  private rgradients: NoiseVec2[];
  private permutations: number[];

  constructor(size: number) {
    this.size = size;
    this.mask = size - 1;

    this.rgradients = new Array(size);
    for (let i = 0; i < size; i++) {
      const v = Helper.nextFloat() * Math.PI * 2.0;
      this.rgradients[i] = new NoiseVec2(Math.cos(v), Math.sin(v));
    }

    this.permutations = new Array(size);
    for (let i = 0; i < size; i++) {
      this.permutations[i] = i;
    }

    for (let i = 0; i < size; i++) {
      const a = Helper.nextInt(size);
      const b = Helper.nextInt(size);
      const temp = this.permutations[a];
      this.permutations[a] = this.permutations[b];
      this.permutations[b] = temp;
    }
  }

  private gradient(orig: NoiseVec2, grad: NoiseVec2, p: NoiseVec2): number {
    return grad.x * (p.x - orig.x) + grad.y * (p.y - orig.y);
  }

  private lerp(a: number, b: number, v: number): number {
    return a + (b - a) * v;
  }

  private smooth(v: number): number {
    return v * v * (3.0 - 2.0 * v);
  }

  private getGradient(x: number, y: number): NoiseVec2 {
    const idx =
      this.permutations[x & this.mask] + this.permutations[y & this.mask];
    return this.rgradients[idx & this.mask];
  }

  private getGradients(x: number, y: number): [NoiseVec2[], NoiseVec2[]] {
    const x0f = Math.floor(x);
    const y0f = Math.floor(y);
    const x0 = x0f | 0;
    const y0 = y0f | 0;

    const gradients = [
      this.getGradient(x0, y0),
      this.getGradient(x0 + 1, y0),
      this.getGradient(x0, y0 + 1),
      this.getGradient(x0 + 1, y0 + 1),
    ];

    const origins = [
      new NoiseVec2(x0f + 0.0, y0f + 0.0),
      new NoiseVec2(x0f + 1.0, y0f + 0.0),
      new NoiseVec2(x0f + 0.0, y0f + 1.0),
      new NoiseVec2(x0f + 1.0, y0f + 1.0),
    ];

    return [gradients, origins];
  }

  get(x: number, y: number): number {
    const p = new NoiseVec2(x, y);
    const [gradients, origins] = this.getGradients(x, y);

    const v0 = this.gradient(origins[0], gradients[0], p);
    const v1 = this.gradient(origins[1], gradients[1], p);
    const v2 = this.gradient(origins[2], gradients[2], p);
    const v3 = this.gradient(origins[3], gradients[3], p);

    const fx = this.smooth(x - origins[0].x);
    const vx0 = this.lerp(v0, v1, fx);
    const vx1 = this.lerp(v2, v3, fx);

    const fy = this.smooth(y - origins[0].y);
    return this.lerp(vx0, vx1, fy);
  }
}

export class Noise extends Benchmark {
  private static readonly SYM = [" ", "░", "▒", "▓", "█", "█"];

  private size: bigint;
  private n2d: Noise2DContext;
  private resultValue: number = 0;

  constructor() {
    super();
    this.size = Helper.configI64(this.name, "size");
    this.n2d = new Noise2DContext(Number(this.size));
  }

  run(iteration_id: number): void {
    for (let y = 0; y < this.size; y++) {
      for (let x = 0; x < this.size; x++) {
        const v =
          this.n2d.get(x * 0.1, (y + iteration_id * 128) * 0.1) * 0.5 + 0.5;
        const idx = Math.floor(v / 0.2);
        const charIdx =
          idx < 0 ? 0 : idx > Noise.SYM.length - 1 ? Noise.SYM.length - 1 : idx;
        this.resultValue =
          (this.resultValue + Noise.SYM[charIdx].charCodeAt(0)) & 0xffffffff;
      }
    }
  }

  checksum(): number {
    return this.resultValue;
  }
  override get name(): string {
    return "Etc::Noise";
  }
}

class TextRaytracerVector {
  constructor(
    public x: number,
    public y: number,
    public z: number,
  ) {}

  scale(s: number): TextRaytracerVector {
    return new TextRaytracerVector(this.x * s, this.y * s, this.z * s);
  }

  add(other: TextRaytracerVector): TextRaytracerVector {
    return new TextRaytracerVector(
      this.x + other.x,
      this.y + other.y,
      this.z + other.z,
    );
  }

  subtract(other: TextRaytracerVector): TextRaytracerVector {
    return new TextRaytracerVector(
      this.x - other.x,
      this.y - other.y,
      this.z - other.z,
    );
  }

  dot(other: TextRaytracerVector): number {
    return this.x * other.x + this.y * other.y + this.z * other.z;
  }

  magnitude(): number {
    return Math.sqrt(this.dot(this));
  }

  normalize(): TextRaytracerVector {
    const mag = this.magnitude();
    return this.scale(1.0 / mag);
  }
}

class TextRaytracerRay {
  constructor(
    public orig: TextRaytracerVector,
    public dir: TextRaytracerVector,
  ) {}
}

class TextRaytracerColor {
  constructor(
    public r: number,
    public g: number,
    public b: number,
  ) {}

  scale(s: number): TextRaytracerColor {
    return new TextRaytracerColor(this.r * s, this.g * s, this.b * s);
  }

  add(other: TextRaytracerColor): TextRaytracerColor {
    return new TextRaytracerColor(
      this.r + other.r,
      this.g + other.g,
      this.b + other.b,
    );
  }
}

class TextRaytracerSphere {
  constructor(
    public center: TextRaytracerVector,
    public radius: number,
    public color: TextRaytracerColor,
  ) {}

  getNormal(pt: TextRaytracerVector): TextRaytracerVector {
    return pt.subtract(this.center).normalize();
  }
}

class TextRaytracerLight {
  constructor(
    public position: TextRaytracerVector,
    public color: TextRaytracerColor,
  ) {}
}

class TextRaytracerHit {
  constructor(
    public obj: TextRaytracerSphere,
    public value: number,
  ) {}
}

export class TextRaytracer extends Benchmark {
  private static readonly WHITE = new TextRaytracerColor(1.0, 1.0, 1.0);
  private static readonly RED = new TextRaytracerColor(1.0, 0.0, 0.0);
  private static readonly GREEN = new TextRaytracerColor(0.0, 1.0, 0.0);
  private static readonly BLUE = new TextRaytracerColor(0.0, 0.0, 1.0);

  private static readonly LIGHT1 = new TextRaytracerLight(
    new TextRaytracerVector(0.7, -1.0, 1.7),
    TextRaytracer.WHITE,
  );

  private static readonly SCENE: TextRaytracerSphere[] = [
    new TextRaytracerSphere(
      new TextRaytracerVector(-1.0, 0.0, 3.0),
      0.3,
      TextRaytracer.RED,
    ),
    new TextRaytracerSphere(
      new TextRaytracerVector(0.0, 0.0, 3.0),
      0.8,
      TextRaytracer.GREEN,
    ),
    new TextRaytracerSphere(
      new TextRaytracerVector(1.0, 0.0, 3.0),
      0.4,
      TextRaytracer.BLUE,
    ),
  ];

  private static readonly LUT = [".", "-", "+", "*", "X", "M"];

  private w: number;
  private h: number;
  private resultValue: number = 0;

  constructor() {
    super();
    this.w = Number(Helper.configI64(this.name, "w"));
    this.h = Number(Helper.configI64(this.name, "h"));
  }

  private shadePixel(
    ray: TextRaytracerRay,
    obj: TextRaytracerSphere,
    tval: number,
  ): number {
    const pi = ray.orig.add(ray.dir.scale(tval));
    const color = this.diffuseShading(pi, obj, TextRaytracer.LIGHT1);
    const col = (color.r + color.g + color.b) / 3.0;
    return Math.floor(col * 6.0);
  }

  private intersectSphere(
    ray: TextRaytracerRay,
    center: TextRaytracerVector,
    radius: number,
  ): number | null {
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

  private clamp(x: number, a: number, b: number): number {
    if (x < a) return a;
    if (x > b) return b;
    return x;
  }

  private diffuseShading(
    pi: TextRaytracerVector,
    obj: TextRaytracerSphere,
    light: TextRaytracerLight,
  ): TextRaytracerColor {
    const n = obj.getNormal(pi);
    const lam1 = light.position.subtract(pi).normalize().dot(n);
    const lam2 = this.clamp(lam1, 0.0, 1.0);
    return light.color.scale(lam2 * 0.5).add(obj.color.scale(0.3));
  }

  run(_iteration_id: number): void {
    let res = 0;
    const fw = this.w;
    const fh = this.h;

    for (let j = 0; j < this.h; j++) {
      for (let i = 0; i < this.w; i++) {
        const ray = new TextRaytracerRay(
          new TextRaytracerVector(0.0, 0.0, 0.0),
          new TextRaytracerVector(
            (i - fw / 2.0) / fw,
            (j - fh / 2.0) / fh,
            1.0,
          ).normalize(),
        );

        let hit: TextRaytracerHit | null = null;

        for (const obj of TextRaytracer.SCENE) {
          const ret = this.intersectSphere(ray, obj.center, obj.radius);
          if (ret !== null) {
            hit = new TextRaytracerHit(obj, ret);
            break;
          }
        }

        let pixel: string;
        if (hit) {
          const shadeIdx = this.shadePixel(ray, hit.obj, hit.value);
          pixel =
            TextRaytracer.LUT[Math.min(shadeIdx, TextRaytracer.LUT.length - 1)];
        } else {
          pixel = " ";
        }

        res += pixel.charCodeAt(0);
      }
    }

    this.resultValue = (this.resultValue + res) & 0xffffffff;
  }

  checksum(): number {
    return this.resultValue >>> 0;
  }
  override get name(): string {
    return "Etc::TextRaytracer";
  }
}

class NeuralNetSynapse {
  weight: number;
  prevWeight: number;
  sourceNeuron: NeuralNetNeuron;
  destNeuron: NeuralNetNeuron;

  constructor(sourceNeuron: NeuralNetNeuron, destNeuron: NeuralNetNeuron) {
    this.sourceNeuron = sourceNeuron;
    this.destNeuron = destNeuron;
    this.prevWeight = this.weight = Helper.nextFloat() * 2 - 1;
  }
}

class NeuralNetNeuron {
  private static readonly LEARNING_RATE = 1.0;
  private static readonly MOMENTUM = 0.3;

  synapsesIn: NeuralNetSynapse[] = [];
  synapsesOut: NeuralNetSynapse[] = [];
  threshold: number;
  prevThreshold: number;
  error: number = 0;
  output: number = 0;

  constructor() {
    this.prevThreshold = this.threshold = Helper.nextFloat() * 2 - 1;
  }

  calculateOutput(): void {
    let activation = 0;
    for (const synapse of this.synapsesIn) {
      activation += synapse.weight * synapse.sourceNeuron.output;
    }
    activation -= this.threshold;

    this.output = 1.0 / (1.0 + Math.exp(-activation));
  }

  derivative(): number {
    return this.output * (1 - this.output);
  }

  outputTrain(rate: number, target: number): void {
    this.error = (target - this.output) * this.derivative();
    this.updateWeights(rate);
  }

  hiddenTrain(rate: number): void {
    let sum = 0;
    for (const synapse of this.synapsesOut) {
      sum += synapse.prevWeight * synapse.destNeuron.error;
    }
    this.error = sum * this.derivative();
    this.updateWeights(rate);
  }

  updateWeights(rate: number): void {
    for (const synapse of this.synapsesIn) {
      const tempWeight = synapse.weight;
      synapse.weight +=
        rate *
          NeuralNetNeuron.LEARNING_RATE *
          this.error *
          synapse.sourceNeuron.output +
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
  private inputLayer: NeuralNetNeuron[];
  private hiddenLayer: NeuralNetNeuron[];
  private outputLayer: NeuralNetNeuron[];

  constructor(inputs: number, hidden: number, outputs: number) {
    this.inputLayer = Array.from(
      { length: inputs },
      () => new NeuralNetNeuron(),
    );
    this.hiddenLayer = Array.from(
      { length: hidden },
      () => new NeuralNetNeuron(),
    );
    this.outputLayer = Array.from(
      { length: outputs },
      () => new NeuralNetNeuron(),
    );

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

  train(inputs: number[], targets: number[]): void {
    this.feedForward(inputs);

    for (let i = 0; i < this.outputLayer.length; i++) {
      this.outputLayer[i].outputTrain(0.3, targets[i]);
    }

    for (const neuron of this.hiddenLayer) {
      neuron.hiddenTrain(0.3);
    }
  }

  feedForward(inputs: number[]): void {
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

  currentOutputs(): number[] {
    return this.outputLayer.map((neuron) => neuron.output);
  }
}

export class NeuralNet extends Benchmark {
  private results: number[] = [];
  private xor: NeuralNetNetwork;

  constructor() {
    super();
    this.xor = new NeuralNetNetwork(0, 0, 0);
  }

  prepare(): void {
    this.xor = new NeuralNetNetwork(2, 10, 1);
  }

  run(_iteration_id: number): void {
    this.xor.train([0, 0], [0]);
    this.xor.train([1, 0], [1]);
    this.xor.train([0, 1], [1]);
    this.xor.train([1, 1], [0]);
  }

  checksum(): number {
    this.xor.feedForward([0, 0]);
    this.results.push(...this.xor.currentOutputs());

    this.xor.feedForward([0, 1]);
    this.results.push(...this.xor.currentOutputs());

    this.xor.feedForward([1, 0]);
    this.results.push(...this.xor.currentOutputs());

    this.xor.feedForward([1, 1]);
    this.results.push(...this.xor.currentOutputs());

    const sum = this.results.reduce((a, b) => a + b, 0);
    return Helper.checksumFloat(sum);
  }
  override get name(): string {
    return "Etc::NeuralNet";
  }
}

export abstract class SortBenchmark extends Benchmark {
  protected data: number[] = [];
  protected size: number;
  protected resultValue: number = 0;

  constructor() {
    super();
    this.size = Number(Helper.configI64(this.name, "size"));
  }

  prepare(): void {
    this.data = [];
    for (let i = 0; i < this.size; i++) {
      this.data.push(Helper.nextInt(1000000));
    }
  }

  abstract test(): number[];

  run(_iteration_id: number): void {
    this.resultValue =
      (this.resultValue + this.data[Helper.nextInt(this.size)]) & 0xffffffff;
    const t = this.test();
    this.resultValue =
      (this.resultValue + t[Helper.nextInt(this.size)]) & 0xffffffff;
  }

  checksum(): number {
    return this.resultValue;
  }
  override get name(): string {
    return "Sort";
  }
}

export class SortQuick extends SortBenchmark {
  test(): number[] {
    const arr = [...this.data];
    this.quickSort(arr, 0, arr.length - 1);
    return arr;
  }

  private quickSort(arr: number[], low: number, high: number): void {
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
  override get name(): string {
    return "Sort::Quick";
  }
}

export class SortMerge extends SortBenchmark {
  test(): number[] {
    const arr = [...this.data];
    this.mergeSortInplace(arr);
    return arr;
  }

  private mergeSortInplace(arr: number[]): void {
    const temp = new Array(arr.length).fill(0);
    this.mergeSortHelper(arr, temp, 0, arr.length - 1);
  }

  private mergeSortHelper(
    arr: number[],
    temp: number[],
    left: number,
    right: number,
  ): void {
    if (left >= right) return;

    const mid = Math.floor((left + right) / 2);
    this.mergeSortHelper(arr, temp, left, mid);
    this.mergeSortHelper(arr, temp, mid + 1, right);
    this.merge(arr, temp, left, mid, right);
  }

  private merge(
    arr: number[],
    temp: number[],
    left: number,
    mid: number,
    right: number,
  ): void {
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
  override get name(): string {
    return "Sort::Merge";
  }
}

export class SortSelf extends SortBenchmark {
  test(): number[] {
    const arr = [...this.data];
    arr.sort((a, b) => a - b);
    return arr;
  }
  override get name(): string {
    return "Sort::Self";
  }
}

export class GraphPathGraph {
  vertices: number;
  jumps: number;
  jumpLen: number;
  private adj: number[][];

  constructor(vertices: number, jumps: number = 3, jumpLen: number = 100) {
    this.vertices = vertices;
    this.jumps = jumps;
    this.jumpLen = jumpLen;
    this.adj = Array(vertices)
      .fill(0)
      .map(() => []);
  }

  addEdge(u: number, v: number): void {
    this.adj[u].push(v);
    this.adj[v].push(u);
  }

  generateRandom(): void {
    for (let i = 1; i < this.vertices; i++) {
      this.addEdge(i, i - 1);
    }

    for (let v = 0; v < this.vertices; v++) {
      const numJumps = Helper.nextInt(this.jumps);
      for (let j = 0; j < numJumps; j++) {
        const offset =
          Helper.nextInt(this.jumpLen) - Math.floor(this.jumpLen / 2);
        const u = v + offset;

        if (u >= 0 && u < this.vertices && u !== v) {
          this.addEdge(v, u);
        }
      }
    }
  }

  getAdjacency(): number[][] {
    return this.adj;
  }

  getVertices(): number {
    return this.vertices;
  }
}

export abstract class GraphPathBenchmark extends Benchmark {
  protected graph!: GraphPathGraph;
  protected resultValue: number = 0;

  prepare(): void {
    const vertices = Number(Helper.configI64(this.name, "vertices"));
    const jumps = Number(Helper.configI64(this.name, "jumps"));
    const jumpLen = Number(Helper.configI64(this.name, "jump_len"));

    this.graph = new GraphPathGraph(vertices, jumps, jumpLen);
    this.graph.generateRandom();
  }

  abstract run(_iteration_id: number): void;

  checksum(): number {
    return this.resultValue >>> 0;
  }
  override get name(): string {
    return "Graph";
  }
}

export class GraphPathBFS extends GraphPathBenchmark {
  run(_iteration_id: number): void {
    const length = this.bfsShortestPath(0, this.graph.getVertices() - 1);
    this.resultValue += length;
  }

  private bfsShortestPath(start: number, target: number): number {
    if (start === target) return 0;

    const visited = new Uint8Array(this.graph.getVertices());
    const queue: [number, number][] = [[start, 0]];
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
  override get name(): string {
    return "Graph::BFS";
  }
}

export class GraphPathDFS extends GraphPathBenchmark {
  run(_iteration_id: number): void {
    const length = this.dfsFindPath(0, this.graph.getVertices() - 1);
    this.resultValue += length;
  }

  private dfsFindPath(start: number, target: number): number {
    if (start === target) return 0;

    const visited = new Uint8Array(this.graph.getVertices());
    const stack: [number, number][] = [[start, 0]];
    let bestPath = Number.MAX_SAFE_INTEGER;

    while (stack.length > 0) {
      const [v, dist] = stack.pop()!;

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
  override get name(): string {
    return "Graph::DFS";
  }
}

export class GraphPathAStar extends GraphPathBenchmark {
  run(_iteration_id: number): void {
    const length = this.aStarShortestPath(0, this.graph.getVertices() - 1);
    this.resultValue += length;
  }

  private heuristic(v: number, target: number): number {
    return target - v;
  }

  private aStarShortestPath(start: number, target: number): number {
    if (start === target) return 0;

    const vertices = this.graph.getVertices();
    const gScore = new Array(vertices).fill(Number.MAX_SAFE_INTEGER);
    const closed = new Uint8Array(vertices);

    gScore[start] = 0;

    const heapVertices: number[] = [];
    const heapPriorities: number[] = [];
    const inOpenSet = new Uint8Array(vertices);

    const heapPush = (vertex: number, priority: number) => {
      let i = heapVertices.length;
      heapVertices.push(vertex);
      heapPriorities.push(priority);

      while (i > 0) {
        const parent = Math.floor((i - 1) / 2);
        if (heapPriorities[parent] <= heapPriorities[i]) break;
        [heapVertices[i], heapVertices[parent]] = [
          heapVertices[parent],
          heapVertices[i],
        ];
        [heapPriorities[i], heapPriorities[parent]] = [
          heapPriorities[parent],
          heapPriorities[i],
        ];
        i = parent;
      }
    };

    const heapPop = (): number | undefined => {
      if (heapVertices.length === 0) return undefined;

      const result = heapVertices[0];
      heapVertices[0] = heapVertices[heapVertices.length - 1];
      heapPriorities[0] = heapPriorities[heapPriorities.length - 1];
      heapVertices.pop();
      heapPriorities.pop();

      let i = 0;
      const n = heapVertices.length;
      while (true) {
        const left = 2 * i + 1;
        const right = 2 * i + 2;
        let smallest = i;

        if (left < n && heapPriorities[left] < heapPriorities[smallest]) {
          smallest = left;
        }
        if (right < n && heapPriorities[right] < heapPriorities[smallest]) {
          smallest = right;
        }
        if (smallest === i) break;

        [heapVertices[i], heapVertices[smallest]] = [
          heapVertices[smallest],
          heapVertices[i],
        ];
        [heapPriorities[i], heapPriorities[smallest]] = [
          heapPriorities[smallest],
          heapPriorities[i],
        ];
        i = smallest;
      }

      return result;
    };

    heapPush(start, this.heuristic(start, target));
    inOpenSet[start] = 1;

    while (heapVertices.length > 0) {
      const current = heapPop()!;
      inOpenSet[current] = 0;

      if (current === target) {
        return gScore[current];
      }

      closed[current] = 1;

      for (const neighbor of this.graph.getAdjacency()[current]) {
        if (closed[neighbor]) continue;

        const tentativeG = gScore[current] + 1;

        if (tentativeG < gScore[neighbor]) {
          gScore[neighbor] = tentativeG;
          const f = tentativeG + this.heuristic(neighbor, target);

          if (inOpenSet[neighbor] === 0) {
            heapPush(neighbor, f);
            inOpenSet[neighbor] = 1;
          }
        }
      }
    }

    return -1;
  }
  override get name(): string {
    return "Graph::AStar";
  }
}

export abstract class BufferHashBenchmark extends Benchmark {
  protected data: Uint8Array;
  protected size: number;
  protected resultValue: number = 0;

  constructor() {
    super();
    this.size = Number(Helper.configI64(this.name, "size"));
    this.data = new Uint8Array(this.size);
  }

  prepare(): void {
    for (let i = 0; i < this.data.length; i++) {
      this.data[i] = Helper.nextInt(256);
    }
  }

  abstract test(): number;

  run(_iteration_id: number): void {
    const hash = this.test();
    this.resultValue = (this.resultValue + hash) & 0xffffffff;
  }

  checksum(): number {
    return this.resultValue >>> 0;
  }
  override get name(): string {
    return "Hash";
  }
}

export class BufferHashCRC32 extends BufferHashBenchmark {
  test(): number {
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
  override get name(): string {
    return "Hash::CRC32";
  }
}

class SimpleSHA256 {
  static digest(data: Uint8Array): Uint8Array {
    const result = new Uint8Array(32);

    const hashes = [
      0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c,
      0x1f83d9ab, 0x5be0cd19,
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

export class BufferHashSHA256 extends BufferHashBenchmark {
  test(): number {
    const bytes = SimpleSHA256.digest(this.data);
    const view = new DataView(bytes.buffer);

    return view.getUint32(0, true);
  }
  override get name(): string {
    return "Hash::SHA256";
  }
}

class FastLRUCache<K, V> {
  private capacity: number;
  private _size: number = 0;
  private cache: Map<K, Node3<K, V>> = new Map();
  private head: Node3<K, V> | null = null;
  private tail: Node3<K, V> | null = null;

  constructor(capacity: number) {
    this.capacity = capacity;
  }

  get(key: K): V | undefined {
    const node = this.cache.get(key);
    if (!node) return undefined;

    this.moveToFront(node);
    return node.value;
  }

  put(key: K, value: V): void {
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

  size(): number {
    return this._size;
  }

  private moveToFront(node: Node3<K, V>): void {
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

  private addToFront(node: Node3<K, V>): void {
    node.next = this.head;
    if (this.head) this.head.prev = node;
    this.head = node;
    if (!this.tail) this.tail = node;
  }

  private removeOldest(): void {
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

class Node3<K, V> {
  key: K;
  value: V;
  prev: Node3<K, V> | null = null;
  next: Node3<K, V> | null = null;

  constructor(key: K, value: V) {
    this.key = key;
    this.value = value;
  }
}

export class CacheSimulation extends Benchmark {
  private valuesSize: number;
  private cache: FastLRUCache<string, string>;
  private hits: number = 0;
  private misses: number = 0;
  private resultValue: number = 5432;

  constructor() {
    super();
    this.valuesSize = Number(Helper.configI64(this.name, "values"));
    this.cache = new FastLRUCache(Number(Helper.configI64(this.name, "size")));
  }

  run(_iteration_id: number): void {
    const key = `item_${Helper.nextInt(this.valuesSize)}`;

    if (this.cache.get(key) !== undefined) {
      this.hits++;
      this.cache.put(key, `updated_${this.iterations}`);
    } else {
      this.misses++;
      this.cache.put(key, `new_${this.iterations}`);
    }
  }

  checksum(): number {
    let result = 5432;
    result = ((result << 5) + this.hits) & 0xffffffff;
    result = ((result << 5) + this.misses) & 0xffffffff;
    result = ((result << 5) + this.cache.size()) & 0xffffffff;
    return result >>> 0;
  }
  override get name(): string {
    return "Etc::CacheSimulation";
  }
}

abstract class Node2 {}

class NumberNode extends Node2 {
  constructor(public value: number) {
    super();
  }
}

class VariableNode extends Node2 {
  constructor(public name: string) {
    super();
  }
}

class BinaryOpNode extends Node2 {
  constructor(
    public op: string,
    public left: Node2,
    public right: Node2,
  ) {
    super();
  }
}

class AssignmentNode extends Node2 {
  constructor(
    public varName: string,
    public expr: Node2,
  ) {
    super();
  }
}

class Parser {
  private input: string;
  private pos: number = 0;
  private chars: string[];
  private currentChar: string = "\0";
  public expressions: Node2[] = [];

  constructor(input: string) {
    this.input = input;
    this.chars = Array.from(input);
    this.currentChar = this.chars.length > 0 ? this.chars[0] : "\0";
  }

  parse(): void {
    while (this.pos < this.chars.length) {
      const expr = this.parseExpression();
      if (expr) {
        this.expressions.push(expr);
      }
    }
  }

  private parseExpression(): Node2 {
    let node = this.parseTerm();

    while (this.pos < this.chars.length) {
      this.skipWhitespace();
      if (this.pos >= this.chars.length) break;

      if (this.currentChar === "+" || this.currentChar === "-") {
        const op = this.currentChar;
        this.advance();
        const right = this.parseTerm();
        node = new BinaryOpNode(op, node, right);
      } else {
        break;
      }
    }

    return node;
  }

  private parseTerm(): Node2 {
    let node = this.parseFactor();

    while (this.pos < this.chars.length) {
      this.skipWhitespace();
      if (this.pos >= this.chars.length) break;

      if (
        this.currentChar === "*" ||
        this.currentChar === "/" ||
        this.currentChar === "%"
      ) {
        const op = this.currentChar;
        this.advance();
        const right = this.parseFactor();
        node = new BinaryOpNode(op, node, right);
      } else {
        break;
      }
    }

    return node;
  }

  private parseFactor(): Node2 {
    this.skipWhitespace();
    if (this.pos >= this.chars.length) {
      return new NumberNode(0);
    }

    const char = this.currentChar;

    if (char >= "0" && char <= "9") {
      return this.parseNumber();
    } else if ((char >= "a" && char <= "z") || (char >= "A" && char <= "Z")) {
      return this.parseVariable();
    } else if (char === "(") {
      this.advance();
      const node = this.parseExpression();
      this.skipWhitespace();
      if (this.currentChar === ")") {
        this.advance();
      }
      return node;
    } else {
      return new NumberNode(0);
    }
  }

  private parseNumber(): Node2 {
    let value = 0;
    while (this.pos < this.chars.length && this.isDigit(this.currentChar)) {
      const digit = this.currentChar.charCodeAt(0) - "0".charCodeAt(0);
      value = value * 10 + digit;
      this.advance();
    }
    return new NumberNode(value);
  }

  private parseVariable(): Node2 {
    const start = this.pos;
    while (
      this.pos < this.chars.length &&
      (this.isLetter(this.currentChar) || this.isDigit(this.currentChar))
    ) {
      this.advance();
    }
    const varName = this.input.substring(start, this.pos);

    this.skipWhitespace();
    if (this.currentChar === "=") {
      this.advance();
      const expr = this.parseExpression();
      return new AssignmentNode(varName, expr);
    }

    return new VariableNode(varName);
  }

  private advance(): void {
    this.pos++;
    if (this.pos >= this.chars.length) {
      this.currentChar = "\0";
    } else {
      this.currentChar = this.chars[this.pos];
    }
  }

  private skipWhitespace(): void {
    while (
      this.pos < this.chars.length &&
      this.isWhitespace(this.currentChar)
    ) {
      this.advance();
    }
  }

  private isDigit(char: string): boolean {
    return char >= "0" && char <= "9";
  }

  private isLetter(char: string): boolean {
    return (char >= "a" && char <= "z") || (char >= "A" && char <= "Z");
  }

  private isWhitespace(char: string): boolean {
    return char === " " || char === "\t" || char === "\n" || char === "\r";
  }
}

export class CalculatorAst extends Benchmark {
  public n: number;
  private text: string = "";
  private expressions: Node2[] = [];
  private resultValue: number = 0;

  constructor() {
    super();
    this.n = Number(Helper.configI64(this.name, "operations"));
  }

  private generateRandomProgram(n: number = 1000): string {
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
  prepare(): void {
    this.text = this.generateRandomProgram(this.n);
  }

  run(_iteration_id: number): void {
    const parser = new Parser(this.text);
    parser.parse();
    this.expressions = parser.expressions;
    this.resultValue =
      (this.resultValue + this.expressions.length) & 0xffffffff;
    const lastExpr = this.expressions[this.expressions.length - 1];
    if (lastExpr instanceof AssignmentNode) {
      this.resultValue =
        (this.resultValue + Helper.checksumString(lastExpr.varName)) &
        0xffffffff;
    }
  }

  getExpressions(): Node2[] {
    return this.expressions;
  }

  checksum(): number {
    return this.resultValue;
  }
  override get name(): string {
    return "Calculator::Ast";
  }
}

class Int64 {
  private low: number;
  private high: number;

  constructor(value: number | bigint) {
    if (typeof value === "bigint") {
      const mask = 0xffffffffn;
      this.low = Number(value & mask);
      this.high = Number((value >> 32n) & mask);
    } else {
      this.low = value | 0;
      this.high = value >= 0 ? 0 : -1;
    }
  }

  toBigInt(): bigint {
    const lowUnsigned = BigInt(this.low >>> 0);
    const highUnsigned = BigInt(this.high >>> 0);
    const result = (highUnsigned << 32n) | lowUnsigned;

    if (this.high & 0x80000000) {
      const mask = (1n << 64n) - 1n;
      return result - (1n << 64n);
    }
    return result;
  }

  tonumber(): number {
    return this.low;
  }

  add(other: Int64): Int64 {
    let low = (this.low + other.low) | 0;
    let high = (this.high + other.high) | 0;

    if ((this.low >>> 0) + (other.low >>> 0) > 0xffffffff) {
      high = (high + 1) | 0;
    }

    return Int64.fromParts(low, high);
  }

  sub(other: Int64): Int64 {
    let low = (this.low - other.low) | 0;
    let high = (this.high - other.high) | 0;

    if (this.low >>> 0 < other.low >>> 0) {
      high = (high - 1) | 0;
    }

    return Int64.fromParts(low, high);
  }

  mul(other: Int64): Int64 {
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

  div(other: Int64): Int64 {
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

  mod(other: Int64): Int64 {
    if (other.isZero()) return new Int64(0);

    const a = this.toBigInt();
    const b = other.toBigInt();
    const div = this.div(other);
    const divBig = div.toBigInt();
    const result = a - divBig * b;

    return new Int64(result);
  }

  isZero(): boolean {
    return this.low === 0 && this.high === 0;
  }

  static fromParts(low: number, high: number): Int64 {
    const result = new Int64(0);
    result.low = low;
    result.high = high;
    return result;
  }
}

class Interpreter {
  private variables: Map<string, Int64> = new Map();

  private evaluate(node: any): Int64 {
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

  run(expressions: any[]): Int64 {
    let result = new Int64(0);
    for (const expr of expressions) {
      result = this.evaluate(expr);
    }
    return result;
  }

  clear(): void {
    this.variables.clear();
  }
}

export class CalculatorInterpreter extends Benchmark {
  private ast: any[] = [];
  private resultValue: number = 0;

  prepare(): void {
    const calculator = new CalculatorAst();
    calculator.n = Number(Helper.configI64(this.name, "operations"));
    calculator.prepare();
    calculator.run(0);
    this.ast = calculator.getExpressions();
  }

  run(_iteration_id: number): void {
    const interpreter = new Interpreter();
    const result = interpreter.run(this.ast);
    this.resultValue = (this.resultValue + result.tonumber()) & 0xffffffff;
  }

  checksum(): number {
    return this.resultValue;
  }
  override get name(): string {
    return "Calculator::Interpreter";
  }
}

class CellObj {
  alive: boolean = false;
  nextState: boolean = false;
  neighbors: CellObj[] = new Array(8);
  neighborCount: number = 0;

  addNeighbor(cell: CellObj): void {
    this.neighbors[this.neighborCount++] = cell;
  }

  computeNextState(): void {
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

  update(): void {
    this.alive = this.nextState;
  }
}

class GameOfLifeGrid {
  private width: number;
  private height: number;
  private cells: CellObj[][];

  constructor(width: number, height: number) {
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

  private linkNeighbors(): void {
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

  nextGeneration(): void {
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

  countAlive(): number {
    let count = 0;
    for (let y = 0; y < this.height; y++) {
      for (let x = 0; x < this.width; x++) {
        if (this.cells[y][x].alive) count++;
      }
    }
    return count;
  }

  computeHash(): number {
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

  getCells(): CellObj[][] {
    return this.cells;
  }
}

export class GameOfLife extends Benchmark {
  private readonly width: number;
  private readonly height: number;
  private grid: GameOfLifeGrid;

  constructor() {
    super();
    this.width = Number(Helper.configI64(this.name, "w"));
    this.height = Number(Helper.configI64(this.name, "h"));
    this.grid = new GameOfLifeGrid(this.width, this.height);
  }

  prepare(): void {
    for (let y = 0; y < this.height; y++) {
      for (let x = 0; x < this.width; x++) {
        if (Helper.nextFloat() < 0.1) {
          this.grid.getCells()[y][x].alive = true;
        }
      }
    }
  }

  run(_iteration_id: number): void {
    this.grid.nextGeneration();
  }

  checksum(): number {
    const alive = this.grid.countAlive();
    return (this.grid.computeHash() + alive) >>> 0;
  }
  override get name(): string {
    return "Etc::GameOfLife";
  }
}

enum MazeCell {
  Wall,
  Path,
}

export class MazeGeneratorClass {
  private width: number;
  private height: number;
  private cells: MazeCell[][];

  constructor(width: number, height: number) {
    this.width = width > 5 ? width : 5;
    this.height = height > 5 ? height : 5;
    this.cells = Array(this.height);
    for (let y = 0; y < this.height; y++) {
      this.cells[y] = Array(this.width).fill(MazeCell.Wall);
    }
  }

  get(x: number, y: number): MazeCell {
    return this.cells[y][x];
  }

  set(x: number, y: number, cell: MazeCell): void {
    this.cells[y][x] = cell;
  }

  private divide(x1: number, y1: number, x2: number, y2: number): void {
    const width = x2 - x1;
    const height = y2 - y1;

    if (width < 2 || height < 2) return;

    const widthForWall = Math.max(width - 2, 0);
    const heightForWall = Math.max(height - 2, 0);
    const widthForHole = Math.max(width - 1, 0);
    const heightForHole = Math.max(height - 1, 0);

    if (
      widthForWall === 0 ||
      heightForWall === 0 ||
      widthForHole === 0 ||
      heightForHole === 0
    )
      return;

    if (width > height) {
      const wallRange = Math.max(Math.floor(widthForWall / 2), 1);
      const wallOffset = wallRange > 0 ? Helper.nextInt(wallRange) * 2 : 0;
      const wallX = x1 + 2 + wallOffset;

      const holeRange = Math.max(Math.floor(heightForHole / 2), 1);
      const holeOffset = holeRange > 0 ? Helper.nextInt(holeRange) * 2 : 0;
      const holeY = y1 + 1 + holeOffset;

      if (wallX > x2 || holeY > y2) return;

      for (let y = y1; y <= y2; y++) {
        if (y !== holeY) {
          this.set(wallX, y, MazeCell.Wall);
        }
      }

      if (wallX > x1 + 1) this.divide(x1, y1, wallX - 1, y2);
      if (wallX + 1 < x2) this.divide(wallX + 1, y1, x2, y2);
    } else {
      const wallRange = Math.max(Math.floor(heightForWall / 2), 1);
      const wallOffset = wallRange > 0 ? Helper.nextInt(wallRange) * 2 : 0;
      const wallY = y1 + 2 + wallOffset;

      const holeRange = Math.max(Math.floor(widthForHole / 2), 1);
      const holeOffset = holeRange > 0 ? Helper.nextInt(holeRange) * 2 : 0;
      const holeX = x1 + 1 + holeOffset;

      if (wallY > y2 || holeX > x2) return;

      for (let x = x1; x <= x2; x++) {
        if (x !== holeX) {
          this.set(x, wallY, MazeCell.Wall);
        }
      }

      if (wallY > y1 + 1) this.divide(x1, y1, x2, wallY - 1);
      if (wallY + 1 < y2) this.divide(x1, wallY + 1, x2, y2);
    }
  }

  private isConnectedImpl(
    startX: number,
    startY: number,
    goalX: number,
    goalY: number,
  ): boolean {
    if (
      startX >= this.width ||
      startY >= this.height ||
      goalX >= this.width ||
      goalY >= this.height
    ) {
      return false;
    }

    const visited: boolean[][] = Array(this.height);
    for (let y = 0; y < this.height; y++) {
      visited[y] = Array(this.width).fill(false);
    }

    const queue: [number, number][] = [];
    let queueIndex = 0;

    visited[startY][startX] = true;
    queue.push([startX, startY]);

    while (queueIndex < queue.length) {
      const [x, y] = queue[queueIndex++];

      if (x === goalX && y === goalY) return true;

      if (y > 0 && this.get(x, y - 1) === MazeCell.Path && !visited[y - 1][x]) {
        visited[y - 1][x] = true;
        queue.push([x, y - 1]);
      }

      if (
        x + 1 < this.width &&
        this.get(x + 1, y) === MazeCell.Path &&
        !visited[y][x + 1]
      ) {
        visited[y][x + 1] = true;
        queue.push([x + 1, y]);
      }

      if (
        y + 1 < this.height &&
        this.get(x, y + 1) === MazeCell.Path &&
        !visited[y + 1][x]
      ) {
        visited[y + 1][x] = true;
        queue.push([x, y + 1]);
      }

      if (x > 0 && this.get(x - 1, y) === MazeCell.Path && !visited[y][x - 1]) {
        visited[y][x - 1] = true;
        queue.push([x - 1, y]);
      }
    }

    return false;
  }

  generate(): void {
    if (this.width < 5 || this.height < 5) {
      for (let x = 0; x < this.width; x++) {
        this.set(x, Math.floor(this.height / 2), MazeCell.Path);
      }
      return;
    }

    this.divide(0, 0, this.width - 1, this.height - 1);
    this.addRandomPaths();
  }

  private addRandomPaths(): void {
    const numExtraPaths = Math.floor((this.width * this.height) / 20);

    for (let i = 0; i < numExtraPaths; i++) {
      const x = Helper.nextInt(this.width - 2) + 1;
      const y = Helper.nextInt(this.height - 2) + 1;

      if (
        this.get(x, y) === MazeCell.Wall &&
        [
          this.get(x - 1, y),
          this.get(x + 1, y),
          this.get(x, y - 1),
          this.get(x, y + 1),
        ].every((cell) => cell === MazeCell.Wall)
      ) {
        this.set(x, y, MazeCell.Path);
      }
    }
  }

  toBoolGrid(): boolean[][] {
    const result: boolean[][] = Array(this.height);
    for (let y = 0; y < this.height; y++) {
      result[y] = Array(this.width);
      for (let x = 0; x < this.width; x++) {
        result[y][x] = this.cells[y][x] === MazeCell.Path;
      }
    }
    return result;
  }

  isConnected(
    startX: number,
    startY: number,
    goalX: number,
    goalY: number,
  ): boolean {
    return this.isConnectedImpl(startX, startY, goalX, goalY);
  }

  public static generateWalkableMaze(
    width: number,
    height: number,
  ): boolean[][] {
    const maze = new MazeGeneratorClass(width, height);
    maze.generate();

    const startX = 1;
    const startY = 1;
    const goalX = width - 2;
    const goalY = height - 2;

    if (!maze.isConnected(startX, startY, goalX, goalY)) {
      for (let x = 0; x < width; x++) {
        for (let y = 0; y < height; y++) {
          if (x === 1 || y === 1 || x === width - 2 || y === height - 2) {
            maze.set(x, y, MazeCell.Path);
          }
        }
      }
    }

    return maze.toBoolGrid();
  }
}

export class MazeGenerator extends Benchmark {
  private readonly width: number;
  private readonly height: number;
  private boolGrid: boolean[][] = [];

  constructor() {
    super();
    this.width = Number(Helper.configI64(this.name, "w"));
    this.height = Number(Helper.configI64(this.name, "h"));
  }

  run(_iteration_id: number): void {
    this.boolGrid = MazeGeneratorClass.generateWalkableMaze(
      this.width,
      this.height,
    );
  }

  private gridChecksum(grid: boolean[][]): number {
    let hasher = 2166136261 >>> 0;
    const prime = 16777619 >>> 0;

    for (let i = 0; i < grid.length; i++) {
      const row = grid[i];
      for (let j = 0; j < row.length; j++) {
        if (row[j]) {
          const j_squared = Math.imul(j, j) >>> 0;
          hasher = hasher ^ j_squared;
          hasher = Math.imul(hasher, prime) >>> 0;
        }
      }
    }
    return hasher >>> 0;
  }

  checksum(): number {
    return this.gridChecksum(this.boolGrid) >>> 0;
  }
  override get name(): string {
    return "MazeGenerator";
  }
}

class AStarNode {
  constructor(
    public x: number,
    public y: number,
    public fScore: number,
  ) {}

  compareTo(other: AStarNode): number {
    if (this.fScore !== other.fScore) {
      return this.fScore - other.fScore;
    }
    if (this.y !== other.y) {
      return this.y - other.y;
    }
    return this.x - other.x;
  }
}

class AStarBinaryHeap {
  private data: AStarNode[] = [];

  push(item: AStarNode): void {
    this.data.push(item);
    this.siftUp(this.data.length - 1);
  }

  pop(): AStarNode {
    const result = this.data[0];
    const last = this.data.pop()!;

    if (this.data.length > 0) {
      this.data[0] = last;
      this.siftDown(0);
    }

    return result;
  }

  isEmpty(): boolean {
    return this.data.length === 0;
  }

  private siftUp(index: number): void {
    const node = this.data[index];

    while (index > 0) {
      const parent = (index - 1) >> 1;
      const parentNode = this.data[parent];

      if (node.compareTo(parentNode) >= 0) break;

      this.data[index] = parentNode;
      this.data[parent] = node;
      index = parent;
    }
  }

  private siftDown(index: number): void {
    const size = this.data.length;
    const node = this.data[index];

    while (true) {
      const left = (index << 1) + 1;
      const right = left + 1;
      let smallest = index;

      if (left < size) {
        const leftNode = this.data[left];
        if (leftNode.compareTo(this.data[smallest]) < 0) {
          smallest = left;
        }
      }

      if (right < size) {
        const rightNode = this.data[right];
        if (rightNode.compareTo(this.data[smallest]) < 0) {
          smallest = right;
        }
      }

      if (smallest === index) break;

      this.data[index] = this.data[smallest];
      this.data[smallest] = node;
      index = smallest;
    }
  }
}

export class AStarPathfinder extends Benchmark {
  private resultVal: number = 0;
  private readonly startX: number;
  private readonly startY: number;
  private readonly goalX: number;
  private readonly goalY: number;
  private readonly width: number;
  private readonly height: number;
  private mazeGrid: boolean[][] = [];

  private gScoresCache: Int32Array;
  private cameFromCache: Int32Array;

  private static readonly DIRECTIONS: [number, number][] = [
    [0, -1],
    [1, 0],
    [0, 1],
    [-1, 0],
  ];
  private static readonly STRAIGHT_COST = 1000;
  private static readonly INF = 0x7fffffff;

  constructor() {
    super();
    this.width = Number(Helper.configI64(this.name, "w"));
    this.height = Number(Helper.configI64(this.name, "h"));
    this.startX = 1;
    this.startY = 1;
    this.goalX = this.width - 2;
    this.goalY = this.height - 2;

    const size = this.width * this.height;
    this.gScoresCache = new Int32Array(size);
    this.cameFromCache = new Int32Array(size);
  }

  private distance(aX: number, aY: number, bX: number, bY: number): number {
    return Math.abs(aX - bX) + Math.abs(aY - bY);
  }

  private packCoords(x: number, y: number): number {
    return y * this.width + x;
  }

  private unpackCoords(packed: number): [number, number] {
    return [packed % this.width, Math.floor(packed / this.width)];
  }

  private findPath(): [Array<[number, number]>, number] {
    const grid = this.mazeGrid;
    const width = this.width;
    const height = this.height;

    const gScores = this.gScoresCache;
    const cameFrom = this.cameFromCache;

    gScores.fill(AStarPathfinder.INF);
    cameFrom.fill(-1);

    const openSet = new AStarBinaryHeap();

    const startIdx = this.packCoords(this.startX, this.startY);
    gScores[startIdx] = 0;
    openSet.push(
      new AStarNode(
        this.startX,
        this.startY,
        this.distance(this.startX, this.startY, this.goalX, this.goalY),
      ),
    );

    let nodesExplored = 0;

    while (!openSet.isEmpty()) {
      const current = openSet.pop();
      nodesExplored++;

      if (current.x === this.goalX && current.y === this.goalY) {
        const path: Array<[number, number]> = [];
        let x = current.x;
        let y = current.y;

        while (x !== this.startX || y !== this.startY) {
          path.push([x, y]);
          const idx = this.packCoords(x, y);
          const packed = cameFrom[idx];
          if (packed === -1) break;

          [x, y] = this.unpackCoords(packed);
        }

        path.push([this.startX, this.startY]);
        path.reverse();
        return [path, nodesExplored];
      }

      const currentIdx = this.packCoords(current.x, current.y);
      const currentG = gScores[currentIdx];

      for (const [dx, dy] of AStarPathfinder.DIRECTIONS) {
        const nx = current.x + dx;
        const ny = current.y + dy;

        if (nx < 0 || nx >= width || ny < 0 || ny >= height) continue;
        if (!grid[ny][nx]) continue;

        const tentativeG = currentG + AStarPathfinder.STRAIGHT_COST;
        const neighborIdx = this.packCoords(nx, ny);

        if (tentativeG < gScores[neighborIdx]) {
          cameFrom[neighborIdx] = currentIdx;
          gScores[neighborIdx] = tentativeG;

          const fScore =
            tentativeG + this.distance(nx, ny, this.goalX, this.goalY);
          openSet.push(new AStarNode(nx, ny, fScore));
        }
      }
    }

    return [[], nodesExplored];
  }

  prepare(): void {
    this.mazeGrid = MazeGeneratorClass.generateWalkableMaze(
      this.width,
      this.height,
    );
  }

  run(_iteration_id: number): void {
    const [path, nodesExplored] = this.findPath();

    let localResult = 0;

    localResult = path.length;

    localResult = ((localResult << 5) + nodesExplored) >>> 0;

    this.resultVal = (this.resultVal + localResult) >>> 0;
  }

  checksum(): number {
    return this.resultVal;
  }
  override get name(): string {
    return "AStarPathfinder";
  }
}

class Compress {
  static generateTestData(size: bigint): Uint8Array {
    const pattern = new TextEncoder().encode("ABRACADABRA");
    const sizeNum = Number(size);
    const data = new Uint8Array(sizeNum);
    const patternLength = pattern.length;

    for (let i = 0; i < sizeNum; i++) {
      data[i] = pattern[i % patternLength];
    }

    return data;
  }

  static arraysEqual(a: Uint8Array, b: Uint8Array): boolean {
    if (a.length !== b.length) return false;
    for (let i = 0; i < a.length; i++) {
      if (a[i] !== b[i]) return false;
    }
    return true;
  }
}

class BWTResult {
  constructor(
    public transformed: Uint8Array,
    public originalIdx: number,
  ) {}
}

export class BWTEncode extends Benchmark {
  public sizeVal: bigint;
  protected testData: Uint8Array = new Uint8Array();
  public bwtResult: BWTResult | null = null;
  protected resultVal: number = 0;

  constructor() {
    super();
    this.sizeVal = Helper.configI64("Compress::BWTEncode", "size");
  }

  override get name(): string {
    return "Compress::BWTEncode";
  }

  override prepare(): void {
    this.testData = Compress.generateTestData(this.sizeVal);
    this.resultVal = 0;
  }

  override run(_iteration_id: number): void {
    this.bwtResult = this.bwtTransform(this.testData);
    this.resultVal = (this.resultVal + this.bwtResult.transformed.length) >>> 0;
  }

  override checksum(): number {
    return this.resultVal >>> 0;
  }

  protected bwtTransform(input: Uint8Array): BWTResult {
    const n = input.length;
    if (n === 0) {
      return new BWTResult(new Uint8Array(), 0);
    }

    let sa: number[] = Array.from({ length: n }, (_, i) => i);

    const buckets: number[][] = Array.from({ length: 256 }, () => []);

    for (const idx of sa) {
      const firstChar = input[idx];
      buckets[firstChar].push(idx);
    }

    let pos = 0;
    for (const bucket of buckets) {
      for (const idx of bucket) {
        sa[pos++] = idx;
      }
    }

    if (n > 1) {
      const rank = new Array(n).fill(0);
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
        const pairs: [number, number][] = new Array(n);
        for (let i = 0; i < n; i++) {
          pairs[i] = [rank[i], rank[(i + k) % n]];
        }

        sa.sort((a, b) => {
          const pairA = pairs[a];
          const pairB = pairs[b];
          if (pairA[0] !== pairB[0]) {
            return pairA[0] - pairB[0];
          }
          return pairA[1] - pairB[1];
        });

        const newRank = new Array(n).fill(0);
        newRank[sa[0]] = 0;
        for (let i = 1; i < n; i++) {
          const prevPair = pairs[sa[i - 1]];
          const currPair = pairs[sa[i]];
          newRank[sa[i]] =
            newRank[sa[i - 1]] +
            (prevPair[0] !== currPair[0] || prevPair[1] !== currPair[1]
              ? 1
              : 0);
        }

        for (let i = 0; i < n; i++) {
          rank[i] = newRank[i];
        }
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

export class BWTDecode extends Benchmark {
  protected sizeVal: bigint;
  protected testData: Uint8Array = new Uint8Array();
  protected inverted: Uint8Array = new Uint8Array();
  protected bwtResult: BWTResult | null = null;
  protected resultVal: number = 0;

  constructor() {
    super();
    this.sizeVal = Helper.configI64("Compress::BWTDecode", "size");
  }

  override get name(): string {
    return "Compress::BWTDecode";
  }

  override prepare(): void {
    this.testData = Compress.generateTestData(this.sizeVal);

    const encoder = new BWTEncode();
    encoder.sizeVal = this.sizeVal;
    encoder.prepare();
    encoder.run(0);
    this.bwtResult = encoder.bwtResult;
    this.resultVal = 0;
  }

  override run(_iteration_id: number): void {
    this.inverted = this.bwtInverse(this.bwtResult!);
    this.resultVal = (this.resultVal + this.inverted.length) >>> 0;
  }

  override checksum(): number {
    let res = this.resultVal;
    if (Compress.arraysEqual(this.inverted, this.testData)) {
      res += 100000;
    }
    return res >>> 0;
  }

  protected bwtInverse(bwtResult: BWTResult): Uint8Array {
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
  constructor(
    public frequency: number,
    public byteVal: number = 0,
    public isLeaf: boolean = true,
    public left: HuffmanNode | null = null,
    public right: HuffmanNode | null = null,
  ) {}
}

class HuffmanCodes {
  codeLengths: number[] = new Array(256).fill(0);
  codes: number[] = new Array(256).fill(0);
}

class EncodedResult {
  constructor(
    public data: Uint8Array,
    public bitCount: number,
    public frequencies: number[],
  ) {}
}

export class HuffEncode extends Benchmark {
  public sizeVal: bigint;
  protected testData: Uint8Array = new Uint8Array();
  public encoded: EncodedResult | null = null;
  protected resultVal: number = 0;

  constructor() {
    super();
    this.sizeVal = Helper.configI64("Compress::HuffEncode", "size");
  }

  override get name(): string {
    return "Compress::HuffEncode";
  }

  override prepare(): void {
    this.testData = Compress.generateTestData(this.sizeVal);
    this.resultVal = 0;
  }

  override run(_iteration_id: number): void {
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

  override checksum(): number {
    return this.resultVal >>> 0;
  }

  static buildHuffmanTree(frequencies: number[]): HuffmanNode {
    const heap: HuffmanNode[] = [];

    for (let i = 0; i < frequencies.length; i++) {
      if (frequencies[i] > 0) {
        heap.push(new HuffmanNode(frequencies[i], i));
      }
    }

    heap.sort((a, b) => a.frequency - b.frequency);

    if (heap.length === 1) {
      const node = heap[0];
      return new HuffmanNode(
        node.frequency,
        0,
        false,
        node,
        new HuffmanNode(0, 0),
      );
    }

    while (heap.length > 1) {
      const left = heap.shift()!;
      const right = heap.shift()!;

      const parent = new HuffmanNode(
        left.frequency + right.frequency,
        0,
        false,
        left,
        right,
      );

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

  protected buildHuffmanCodes(
    node: HuffmanNode,
    code: number,
    length: number,
    huffmanCodes: HuffmanCodes,
  ): void {
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
        this.buildHuffmanCodes(
          node.right,
          (code << 1) | 1,
          length + 1,
          huffmanCodes,
        );
      }
    }
  }

  protected huffmanEncode(
    data: Uint8Array,
    huffmanCodes: HuffmanCodes,
    frequencies: number[],
  ): EncodedResult {
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

    return new EncodedResult(
      result.slice(0, byteIndex),
      totalBits,
      frequencies,
    );
  }
}

export class HuffDecode extends Benchmark {
  protected sizeVal: bigint;
  protected testData: Uint8Array = new Uint8Array();
  protected decoded: Uint8Array = new Uint8Array();
  protected encoded: EncodedResult | null = null;
  protected resultVal: number = 0;

  constructor() {
    super();
    this.sizeVal = Helper.configI64("Compress::HuffDecode", "size");
  }

  override get name(): string {
    return "Compress::HuffDecode";
  }

  override prepare(): void {
    this.testData = Compress.generateTestData(this.sizeVal);

    const encoder = new HuffEncode();
    encoder.sizeVal = this.sizeVal;
    encoder.prepare();
    encoder.run(0);
    this.encoded = encoder.encoded;
    this.resultVal = 0;
  }

  override run(_iteration_id: number): void {
    const tree = HuffEncode.buildHuffmanTree(this.encoded!.frequencies);
    this.decoded = this.huffmanDecode(
      this.encoded!.data,
      tree,
      this.encoded!.bitCount,
    );
    this.resultVal = (this.resultVal + this.decoded.length) >>> 0;
  }

  override checksum(): number {
    let res = this.resultVal;
    if (Compress.arraysEqual(this.decoded, this.testData)) {
      res += 100000;
    }
    return res >>> 0;
  }

  protected huffmanDecode(
    encoded: Uint8Array,
    root: HuffmanNode,
    bitCount: number,
  ): Uint8Array {
    const result: number[] = [];

    let currentNode = root;
    let bitsProcessed = 0;
    let byteIndex = 0;

    while (bitsProcessed < bitCount && byteIndex < encoded.length) {
      const byteVal = encoded[byteIndex++];

      for (let bitPos = 7; bitPos >= 0 && bitsProcessed < bitCount; bitPos--) {
        const bit = ((byteVal >> bitPos) & 1) === 1;
        bitsProcessed++;

        currentNode = bit ? currentNode.right! : currentNode.left!;

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
  total: number;
  low: number[];
  high: number[];

  constructor(frequencies: number[]) {
    this.total = frequencies.reduce((a, b) => a + b, 0);
    this.low = new Array(256).fill(0);
    this.high = new Array(256).fill(0);

    let cum = 0;
    for (let i = 0; i < 256; i++) {
      this.low[i] = cum;
      cum += frequencies[i];
      this.high[i] = cum;
    }
  }
}

class BitOutputStream {
  private buffer: number = 0;
  private bitPos: number = 0;
  private bytes: number[] = [];
  private bitsWritten: number = 0;

  writeBit(bit: number): void {
    this.buffer = (this.buffer << 1) | (bit & 1);
    this.bitPos++;
    this.bitsWritten++;

    if (this.bitPos === 8) {
      this.bytes.push(this.buffer & 0xff);
      this.buffer = 0;
      this.bitPos = 0;
    }
  }

  flush(): Uint8Array {
    if (this.bitPos > 0) {
      this.buffer <<= 8 - this.bitPos;
      this.bytes.push(this.buffer & 0xff);
    }
    return new Uint8Array(this.bytes);
  }

  getBitsWritten(): number {
    return this.bitsWritten;
  }
}

class ArithEncodedResult {
  constructor(
    public data: Uint8Array,
    public bitCount: number,
    public frequencies: number[],
  ) {}
}

export class ArithEncode extends Benchmark {
  public sizeVal: bigint;
  protected testData: Uint8Array = new Uint8Array();
  public encoded: ArithEncodedResult | null = null;
  protected resultVal: number = 0;

  constructor() {
    super();
    this.sizeVal = Helper.configI64("Compress::ArithEncode", "size");
  }

  override get name(): string {
    return "Compress::ArithEncode";
  }

  override prepare(): void {
    this.testData = Compress.generateTestData(this.sizeVal);
    this.resultVal = 0;
  }

  override run(_iteration_id: number): void {
    this.encoded = this.arithEncode(this.testData);
    this.resultVal = (this.resultVal + this.encoded.data.length) >>> 0;
  }

  override checksum(): number {
    return this.resultVal >>> 0;
  }

  protected arithEncode(data: Uint8Array): ArithEncodedResult {
    const frequencies = new Array(256).fill(0);
    for (const byte of data) {
      frequencies[byte]++;
    }

    const freqTable = new ArithFreqTable(frequencies);

    let low: number = 0;
    let high: number = 0xffffffff;
    let pending = 0;
    const output = new BitOutputStream();

    for (const byte of data) {
      const idx = byte;
      const range = high - low + 1;

      high =
        low + Math.floor((range * freqTable.high[idx]) / freqTable.total) - 1;
      low = low + Math.floor((range * freqTable.low[idx]) / freqTable.total);

      while (true) {
        if (high < 0x80000000) {
          output.writeBit(0);
          for (let i = 0; i < pending; i++) output.writeBit(1);
          pending = 0;
        } else if (low >= 0x80000000) {
          output.writeBit(1);
          for (let i = 0; i < pending; i++) output.writeBit(0);
          pending = 0;
          low -= 0x80000000;
          high -= 0x80000000;
        } else if (low >= 0x40000000 && high < 0xc0000000) {
          pending++;
          low -= 0x40000000;
          high -= 0x40000000;
        } else {
          break;
        }

        low <<= 1;
        high = (high << 1) | 1;
        high >>>= 0;
      }
    }

    pending++;
    if (low < 0x40000000) {
      output.writeBit(0);
      for (let i = 0; i < pending; i++) output.writeBit(1);
    } else {
      output.writeBit(1);
      for (let i = 0; i < pending; i++) output.writeBit(0);
    }

    return new ArithEncodedResult(
      output.flush(),
      output.getBitsWritten(),
      frequencies,
    );
  }
}

class BitInputStream {
  private bytes: Uint8Array;
  private bytePos: number = 0;
  private bitPos: number = 0;
  private currentByte: number;

  constructor(bytes: Uint8Array) {
    this.bytes = bytes;
    this.currentByte = bytes.length > 0 ? bytes[0] : 0;
  }

  readBit(): number {
    if (this.bitPos === 8) {
      this.bytePos++;
      this.bitPos = 0;
      this.currentByte =
        this.bytePos < this.bytes.length ? this.bytes[this.bytePos] : 0;
    }

    const bit = (this.currentByte >> (7 - this.bitPos)) & 1;
    this.bitPos++;
    return bit;
  }
}

export class ArithDecode extends Benchmark {
  protected sizeVal: bigint;
  protected testData: Uint8Array = new Uint8Array();
  protected decoded: Uint8Array = new Uint8Array();
  protected encoded: ArithEncodedResult | null = null;
  protected resultVal: number = 0;

  constructor() {
    super();
    this.sizeVal = Helper.configI64("Compress::ArithDecode", "size");
  }

  override get name(): string {
    return "Compress::ArithDecode";
  }

  override prepare(): void {
    this.testData = Compress.generateTestData(this.sizeVal);

    const encoder = new ArithEncode();
    encoder.sizeVal = this.sizeVal;
    encoder.prepare();
    encoder.run(0);
    this.encoded = encoder.encoded;
    this.resultVal = 0;
  }

  override run(_iteration_id: number): void {
    this.decoded = this.arithDecode(this.encoded!);
    this.resultVal = (this.resultVal + this.decoded.length) >>> 0;
  }

  override checksum(): number {
    let res = this.resultVal;
    if (Compress.arraysEqual(this.decoded, this.testData)) {
      res += 100000;
    }
    return res >>> 0;
  }

  protected arithDecode(encoded: ArithEncodedResult): Uint8Array {
    const frequencies = encoded.frequencies;
    const total = frequencies.reduce((a, b) => a + b, 0);
    const dataSize = total;

    const lowTable = new Array(256).fill(0);
    const highTable = new Array(256).fill(0);
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
      value = (value << 1) | input.readBit();
    }

    let low = 0;
    let high = 0xffffffff;

    for (let j = 0; j < dataSize; j++) {
      const range = high - low + 1;
      const scaled = Math.floor(((value - low + 1) * total - 1) / range);

      let symbol = 0;
      while (symbol < 255 && highTable[symbol] <= scaled) {
        symbol++;
      }

      result[j] = symbol;

      high = low + Math.floor((range * highTable[symbol]) / total) - 1;
      low = low + Math.floor((range * lowTable[symbol]) / total);

      while (true) {
        if (high < 0x80000000) {
        } else if (low >= 0x80000000) {
          value -= 0x80000000;
          low -= 0x80000000;
          high -= 0x80000000;
        } else if (low >= 0x40000000 && high < 0xc0000000) {
          value -= 0x40000000;
          low -= 0x40000000;
          high -= 0x40000000;
        } else {
          break;
        }

        low <<= 1;
        high = (high << 1) | 1;
        value = (value << 1) | input.readBit();
      }
    }

    return result;
  }
}

class LZWResult {
  constructor(
    public data: Uint8Array,
    public dictSize: number,
  ) {}
}

export class LZWEncode extends Benchmark {
  public sizeVal: bigint;
  protected testData: Uint8Array = new Uint8Array();
  public encoded: LZWResult | null = null;
  protected resultVal: number = 0;

  constructor() {
    super();
    this.sizeVal = Helper.configI64("Compress::LZWEncode", "size");
  }

  override get name(): string {
    return "Compress::LZWEncode";
  }

  override prepare(): void {
    this.testData = Compress.generateTestData(this.sizeVal);
    this.resultVal = 0;
  }

  override run(_iteration_id: number): void {
    this.encoded = this.lzwEncode(this.testData);
    this.resultVal = (this.resultVal + this.encoded.data.length) >>> 0;
  }

  override checksum(): number {
    return this.resultVal >>> 0;
  }

  protected lzwEncode(input: Uint8Array): LZWResult {
    if (input.length === 0) {
      return new LZWResult(new Uint8Array(), 256);
    }

    const dict = new Map<string, number>();
    for (let i = 0; i < 256; i++) {
      dict.set(String.fromCharCode(i), i);
    }

    let nextCode = 256;
    const result: number[] = [];

    let current = String.fromCharCode(input[0]);

    for (let i = 1; i < input.length; i++) {
      const nextChar = String.fromCharCode(input[i]);
      const newStr = current + nextChar;

      if (dict.has(newStr)) {
        current = newStr;
      } else {
        const code = dict.get(current)!;
        result.push((code >> 8) & 0xff);
        result.push(code & 0xff);

        dict.set(newStr, nextCode);
        nextCode++;
        current = nextChar;
      }
    }

    const code = dict.get(current)!;
    result.push((code >> 8) & 0xff);
    result.push(code & 0xff);

    return new LZWResult(new Uint8Array(result), nextCode);
  }
}

export class LZWDecode extends Benchmark {
  protected sizeVal: bigint;
  protected testData: Uint8Array = new Uint8Array();
  protected decoded: Uint8Array = new Uint8Array();
  protected encoded: LZWResult | null = null;
  protected resultVal: number = 0;

  constructor() {
    super();
    this.sizeVal = Helper.configI64("Compress::LZWDecode", "size");
  }

  override get name(): string {
    return "Compress::LZWDecode";
  }

  override prepare(): void {
    this.testData = Compress.generateTestData(this.sizeVal);

    const encoder = new LZWEncode();
    encoder.sizeVal = this.sizeVal;
    encoder.prepare();
    encoder.run(0);
    this.encoded = encoder.encoded;
    this.resultVal = 0;
  }

  override run(_iteration_id: number): void {
    this.decoded = this.lzwDecode(this.encoded!);
    this.resultVal = (this.resultVal + this.decoded.length) >>> 0;
  }

  override checksum(): number {
    let res = this.resultVal;
    if (Compress.arraysEqual(this.decoded, this.testData)) {
      res += 100000;
    }
    return res >>> 0;
  }

  protected lzwDecode(encoded: LZWResult): Uint8Array {
    if (encoded.data.length === 0) {
      return new Uint8Array();
    }

    const dict: string[] = new Array(4096);
    for (let i = 0; i < 256; i++) {
      dict[i] = String.fromCharCode(i);
    }

    const result: number[] = [];
    const data = encoded.data;
    let pos = 0;

    let oldCode = (data[pos] << 8) | data[pos + 1];
    pos += 2;

    let oldStr = dict[oldCode];
    for (let j = 0; j < oldStr.length; j++) {
      result.push(oldStr.charCodeAt(j));
    }

    let nextCode = 256;

    while (pos < data.length) {
      const newCode = (data[pos] << 8) | data[pos + 1];
      pos += 2;

      let newStr: string;
      if (newCode < dict.length && dict[newCode] !== undefined) {
        newStr = dict[newCode];
      } else if (newCode === nextCode) {
        newStr = oldStr + oldStr[0];
      } else {
        throw new Error(`Error decode: invalid code ${newCode}`);
      }

      for (let j = 0; j < newStr.length; j++) {
        result.push(newStr.charCodeAt(j));
      }

      dict[nextCode] = oldStr + newStr[0];
      nextCode++;

      oldCode = newCode;
      oldStr = newStr;
    }

    return new Uint8Array(result);
  }
}

Benchmark.registerBenchmark("CLBG::Pidigits", Pidigits);
Benchmark.registerBenchmark("Binarytrees::Obj", BinarytreesObj);
Benchmark.registerBenchmark("Binarytrees::Arena", BinarytreesArena);
Benchmark.registerBenchmark("Brainfuck::Array", BrainfuckArray);
Benchmark.registerBenchmark("Brainfuck::Recursion", BrainfuckRecursion);
Benchmark.registerBenchmark("CLBG::Fannkuchredux", Fannkuchredux);
Benchmark.registerBenchmark("CLBG::Fasta", Fasta);
Benchmark.registerBenchmark("CLBG::Knuckeotide", Knuckeotide);
Benchmark.registerBenchmark("CLBG::Mandelbrot", Mandelbrot);
Benchmark.registerBenchmark("Matmul::T1", Matmul1T);
Benchmark.registerBenchmark("Matmul::T4", Matmul4T);
Benchmark.registerBenchmark("Matmul::T8", Matmul8T);
Benchmark.registerBenchmark("Matmul::T16", Matmul16T);
Benchmark.registerBenchmark("CLBG::Nbody", Nbody);
Benchmark.registerBenchmark("CLBG::RegexDna", RegexDna);
Benchmark.registerBenchmark("CLBG::Revcomp", Revcomp);
Benchmark.registerBenchmark("CLBG::Spectralnorm", Spectralnorm);
Benchmark.registerBenchmark("Base64::Encode", Base64Encode);
Benchmark.registerBenchmark("Base64::Decode", Base64Decode);
Benchmark.registerBenchmark("Json::Generate", JsonGenerate);
Benchmark.registerBenchmark("Json::ParseDom", JsonParseDom);
Benchmark.registerBenchmark("Json::ParseMapping", JsonParseMapping);
Benchmark.registerBenchmark("Etc::Primes", Primes);
Benchmark.registerBenchmark("Etc::Noise", Noise);
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
Benchmark.registerBenchmark("MazeGenerator", MazeGenerator);
Benchmark.registerBenchmark("AStarPathfinder", AStarPathfinder);
Benchmark.registerBenchmark("Compress::BWTEncode", BWTEncode);
Benchmark.registerBenchmark("Compress::BWTDecode", BWTDecode);
Benchmark.registerBenchmark("Compress::HuffEncode", HuffEncode);
Benchmark.registerBenchmark("Compress::HuffDecode", HuffDecode);
Benchmark.registerBenchmark("Compress::ArithEncode", ArithEncode);

Benchmark.registerBenchmark("Compress::LZWEncode", LZWEncode);
Benchmark.registerBenchmark("Compress::LZWDecode", LZWDecode);

const RECOMPILE_MARKER = "RECOMPILE_MARKER_0";

try {
  main().catch(console.error);
} catch (error) {
  console.error("Failed to run benchmarks:", error);
  try {
    if (isDeno) {
      // @ts-ignore
      Deno.exit(1);
    } else if (isNode || isBun) {
      // @ts-ignore
      process.exit(1);
    }
  } catch {}
}
