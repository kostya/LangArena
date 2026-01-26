// =========== UNIVERSAL BUNDLED BENCHMARKS ===========
// Works in Node.js, Deno, Bun and TypeScript

// Safe environment detection (won't cause TypeScript errors)
const isDeno = (() => {
    try {
        // @ts-ignore - Deno is optional
        return typeof Deno !== 'undefined' && Deno.version !== undefined;
    } catch {
        return false;
    }
})();

const isBun = (() => {
    try {
        // @ts-ignore - Bun is optional
        return typeof Bun !== 'undefined' && Bun.version !== undefined;
    } catch {
        return false;
    }
})();

const isNode = (() => {
    try {
        // @ts-ignore - process is optional
        return typeof process !== 'undefined' && process.versions && process.versions.node && !isBun;
    } catch {
        return false;
    }
})();

async function writeFileUniversal(filePath: string, content: string): Promise<void> {
    // 1. Для Deno
    if (isDeno) {
        await Deno.writeTextFile(filePath, content);
        return;
    }
    // 2. Для Bun
    if (isBun) {
        await Bun.write(filePath, content);
        return;
    }
    // 3. Для Node.js (версии 18+, где fs/promises стабилен)
    if (isNode) {
        const fs = await import('node:fs/promises');
        await fs.writeFile(filePath, content);
        return;
    }
    // 4. Резервный вариант для старого Node.js (не рекомендуется для продакшена)
    if (typeof process !== 'undefined') {
        const fs = require('fs').promises || require('fs');
        const writeFn = fs.writeFile || fs.promises?.writeFile;
        if (writeFn) {
            await writeFn(filePath, content);
            return;
        }
    }
    throw new Error('Неизвестная среда выполнения. Не удалось найти API для записи файла.');
}

// Performance API - правильная инициализация
const getPerformance = (): { now: () => number } => {
    try {
        // Проверяем глобальный performance (браузер, Deno, Bun)
        // Используем каст типов для избежания ошибок TypeScript
        const global = globalThis as any;
        if (typeof global.performance !== 'undefined' && typeof global.performance.now === 'function') {
            return global.performance;
        }
        
        if (isNode) {
            // Node.js нужен perf_hooks
            try {
                // @ts-ignore - dynamic require
                return require('perf_hooks').performance;
            } catch {
                // fallback
            }
        }
    } catch {
        // ignore
    }
    
    // Fallback
    return {
        now: () => Date.now()
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
    return Math.floor(Helper.last / Helper.IM * max);
  }
  
  static nextIntRange(from: number, to: number): number {
    return Helper.nextInt(to - from + 1) + from;
  }
  
  static nextFloat(max: number = 1.0): number {
    Helper.last = (Helper.last * Helper.IA + Helper.IC) % Helper.IM;
    return max * Helper.last / Helper.IM;
  }
  
  static debug(message: string): void {
    // Safe debug without env errors
    try {
        if (isDeno) {
            // @ts-ignore
            if (Deno.env.get('DEBUG') === '1') {
                console.log(message);
            }
        } else if (isNode || isBun) {
            // @ts-ignore
            if (process.env.DEBUG === '1') {
                console.log(message);
            }
        }
    } catch {
        // Ignore env access errors
    }
  }
  
  static checksumString(str: string): number {
    // Helper.debug(`checksum: ${JSON.stringify(str)}`);
    let hash = 5381;
    for (let i = 0; i < str.length; i++) {
      const byte = str.charCodeAt(i);
      hash = ((hash << 5) + hash) + byte;
      hash = hash & 0xFFFFFFFF;
    }
    return hash >>> 0;
  }
  
  static checksumBytes(bytes: Uint8Array): number {
    // Helper.debug(`checksum: ${Array.from(bytes).join(',')}`);
    let hash = 5381;
    for (const byte of bytes) {
      hash = ((hash << 5) + hash) + byte;
      hash = hash & 0xFFFFFFFF;
    }
    return hash >>> 0;
  }
  
  static checksumFloat(value: number): number {
    return Helper.checksumString(value.toFixed(7));
  }
  
  static async loadConfig(configFile: string = '../test.txt'): Promise<void> {
    try {
      let content = '';
      
      if (isDeno) {
        try {
          // @ts-ignore - Deno is optional
          // const filePath = new URL(configFile, import.meta.url).pathname;
          const filePath = configFile.startsWith('/') ? configFile : Deno.cwd() + '/' + configFile;
          // @ts-ignore
          content = Deno.readTextFileSync(filePath);
        } catch (denoError: any) {
          console.error(`❌ Deno error loading ${configFile}:`, denoError?.message || denoError);
          // @ts-ignore
          Deno.exit(1);
        }
      } else if (isNode) {
        try {
          // @ts-ignore - dynamic require
          const fs = require('fs');
          // @ts-ignore - dynamic require
          const path = require('path');
          // @ts-ignore
          const filePath = path.resolve(process.cwd(), configFile);
          content = fs.readFileSync(filePath, 'utf-8');
        } catch (nodeError: any) {
          console.error(`❌ Node.js error loading ${configFile}:`, nodeError?.message || nodeError);
          // @ts-ignore
          process.exit(1);
        }
      } else if (isBun) {
        try {
          // @ts-ignore - Bun is optional
          const file = Bun.file(configFile);
          content = await file.text();
        } catch (bunError: any) {
          console.error(`❌ Bun error loading ${configFile}:`, bunError?.message || bunError);
          // @ts-ignore
          process.exit(1);
        }
      } else {
        console.error(`❌ Unknown environment, cannot load config: ${configFile}`);
        return;
      }
      
      const lines = content.split('\n').filter((line: string) => line.trim() !== '');
      
      lines.forEach((line: string) => {
        const [benchName, input, expectedStr] = line.split('|');
        if (benchName && input) {
          Helper.inputMap[benchName] = input;
          if (expectedStr) {
            Helper.expectMap[benchName] = BigInt(expectedStr);
          }
        }
      });
      
    } catch (error: any) {
      console.error(`❌ Error loading config file ${configFile}:`, error?.message || error);
      // Safe exit
      try {
        if (isDeno) {
          // @ts-ignore
          Deno.exit(1);
        } else if (isNode || isBun) {
          // @ts-ignore
          process.exit(1);
        }
      } catch {
        // Can't exit, just throw
        throw error;
      }
    }
  }
  
  static get INPUT(): Record<string, string> {
    return Helper.inputMap;
  }
  
  static get EXPECT(): Record<string, bigint> {
    return Helper.expectMap;
  }
}

// ===========

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
  
  let configFile = '../test.txt';
  let testName: string | undefined;
  
  if (args.length >= 1) {
    if (args[0].includes('.txt') || args[0].includes('.json') || args[0].includes('.config')) {
      configFile = args[0];
      testName = args[1];
    } else {
      testName = args[0];
    }
  }

  await Helper.loadConfig(configFile);
  Benchmark.run(testName);
}

// ===========

export abstract class Benchmark {
  abstract run(): void;
  abstract getResult(): bigint;
  
  prepare(): void {
    // Can be overridden by subclasses
  }
  
  get iterations(): number {
    const input = Helper.INPUT[this.constructor.name];
    return input ? parseInt(input, 10) : 1;
  }
  
  static run(singleBench?: string): void {
    const results: Record<string, number> = {};
    let summaryTime = 0;
    let ok = 0;
    let fails = 0;
    
    const benchmarkClasses = Benchmark.getBenchmarkClasses();
    
    for (const BenchmarkClass of benchmarkClasses) {
      const className = BenchmarkClass.name;
      
      if (singleBench && className !== singleBench) {
        continue;
      }
      
      // Safe stdout write
      try {
        if (isNode || isBun) {
          // @ts-ignore
          process.stdout.write(`${className}: `);
        } else if (isDeno) {
          // @ts-ignore
          Deno.stdout.write(new TextEncoder().encode(`${className}: `));
        } else {
          console.log(`${className}: starting...`);
        }
      } catch {
        console.log(`${className}: `);
      }
      
      Helper.reset();
      
      const bench = new BenchmarkClass();
      bench.prepare();
      
      const startTime = performance.now();
      bench.run();
      const endTime = performance.now();
      const timeDelta = (endTime - startTime) / 1000;
      
      results[className] = timeDelta;
      
      // Force garbage collection if available
      try {
        // @ts-ignore
        if (global.gc) {
          // @ts-ignore
          global.gc();
        }
      } catch {
        // GC not available
      }
      
      const actualResult = bench.getResult();
      const expectedResult = Helper.EXPECT[className];
      
      if (actualResult === expectedResult) {
        try {
          if (isNode || isBun) {
            // @ts-ignore
            process.stdout.write('OK ');
          } else if (isDeno) {
            // @ts-ignore
            Deno.stdout.write(new TextEncoder().encode('OK '));
          } else {
            console.log('OK ');
          }
        } catch {
          console.log('OK ');
        }
        ok++;
      } else {
        const errorMsg = `ERR[actual=${actualResult.toString()}, expected=${expectedResult?.toString() || 'undefined'}] `;
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
    
    // Write results to file (only in Node.js/Bun with fs)
    try {
      if (isNode) {
        // @ts-ignore
        const fs = require('fs');
        // @ts-ignore
        const path = require('path');
        fs.writeFileSync(
          '/tmp/results.js',
          `window.results = ${JSON.stringify(results)};`
        );
      } else if (isBun) {
        // @ts-ignore
        const fs = require('fs');
        fs.writeFileSync(
          '/tmp/results.js',
          `window.results = ${JSON.stringify(results)};`
        );
      }
    } catch {
      // Ignore write errors
    }
    
    console.log(`Summary: ${summaryTime.toFixed(4)}s, ${ok + fails}, ${ok}, ${fails}`);
    
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
        throw new Error('Benchmarks failed');
      }
    }
  }
  
  private static getBenchmarkClasses(): Array<new () => Benchmark> {
    return (Benchmark as any)._benchmarkClasses || [];
  }
  
  static registerBenchmark<T extends Benchmark>(cls: new () => T): void {
    if (!(Benchmark as any)._benchmarkClasses) {
      (Benchmark as any)._benchmarkClasses = [];
    }
    (Benchmark as any)._benchmarkClasses.push(cls);
  }
}

// =========== ./benchmarks/base64-decode.ts ===========

export class Base64Decode extends Benchmark {
  private static readonly TRIES = 8192;
  
  private n: number;
  private str2: string = '';
  private str3: string = '';
  private resultValue: bigint = 0n;

  constructor() {
    super();
    this.n = this.iterations;
  }

  prepare(): void {
    const str = 'a'.repeat(this.n);
    this.str2 = btoa(str);
    this.str3 = atob(this.str2);
  }

  run(): void {
    let sDecoded = 0;

    for (let i = 0; i < Base64Decode.TRIES; i++) {
      const decoded = atob(this.str2);
      sDecoded += decoded.length;
    }

    const output = `decode ${this.str2.slice(0, 4)}... to ${this.str3.slice(0, 4)}...: ${sDecoded}\n`;
    this.resultValue = BigInt(Helper.checksumString(output));
  }

  getResult(): bigint {
    return this.resultValue;
  }
}

// =========== ./benchmarks/base64-encode.ts ===========

export class Base64Encode extends Benchmark {
  private static readonly TRIES = 8192;
  
  private n: number;
  private str: string = '';
  private str2: string = '';
  private resultValue: bigint = 0n;

  constructor() {
    super();
    this.n = this.iterations;
  }

  prepare(): void {
    this.str = 'a'.repeat(this.n);
    this.str2 = btoa(this.str);
  }

  run(): void {
    let sEncoded = 0;

    for (let i = 0; i < Base64Encode.TRIES; i++) {
      const encoded = btoa(this.str);
      sEncoded += encoded.length;
    }

    const output = `encode ${this.str.slice(0, 4)}... to ${this.str2.slice(0, 4)}...: ${sEncoded}\n`;
    this.resultValue = BigInt(Helper.checksumString(output));
  }

  getResult(): bigint {
    return this.resultValue;
  }
}

// =========== ./benchmarks/binarytrees.ts ===========

class TreeNode {
  left: TreeNode | null = null;
  right: TreeNode | null = null;
  
  constructor(
    public item: number,
    depth: number = 0
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

export class Binarytrees extends Benchmark {
  private n: number;
  private result: bigint = 0n;
  
  constructor() {
    super();
    this.n = this.iterations;
  }
  
  run(): void {
    const minDepth = 4;
    const maxDepth = Math.max(minDepth + 2, this.n);
    const stretchDepth = maxDepth + 1;
    
    const stretchTree = TreeNode.create(0, stretchDepth);
    this.result += BigInt(stretchTree.check());
    
    for (let depth = minDepth; depth <= maxDepth; depth += 2) {
      const iterations = 1 << (maxDepth - depth + minDepth);
      
      for (let i = 1; i <= iterations; i++) {
        const tree1 = TreeNode.create(i, depth);
        const tree2 = TreeNode.create(-i, depth);
        
        this.result += BigInt(tree1.check());
        this.result += BigInt(tree2.check());
      }
    }
  }
  
  getResult(): bigint {
    return this.result;
  }
}

// =========== ./benchmarks/brainfuck-hashmap.ts ===========

class Tape {
  private tape: number[];
  private pos: number;

  constructor() {
    this.tape = [0];
    this.pos = 0;
  }

  get(): number {
    return this.tape[this.pos];
  }

  inc(): void {
    this.tape[this.pos] += 1;
  }

  dec(): void {
    this.tape[this.pos] -= 1;
  }

  advance(): void {
    this.pos += 1;
    if (this.tape.length <= this.pos) {
      this.tape.push(0);
    }
  }

  devance(): void {
    if (this.pos > 0) {
      this.pos -= 1;
    }
  }
}

class Program {
  private chars: string[] = [];
  private bracketMap: Map<number, number> = new Map();

  constructor(text: string) {
    const leftStack: number[] = [];
    let pc = 0;

    for (const char of text) {
      if ('[]<>+-,.'.includes(char)) {
        this.chars.push(char);
        
        if (char === '[') {
          leftStack.push(pc);
        } else if (char === ']' && leftStack.length > 0) {
          const left = leftStack.pop()!;
          const right = pc;
          this.bracketMap.set(left, right);
          this.bracketMap.set(right, left);
        }
        
        pc += 1;
      }
    }
  }

  run(): bigint {
    let result = 0n;
    const tape = new Tape();
    let pc = 0;

    while (pc < this.chars.length) {
      const char = this.chars[pc];
      
      switch (char) {
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
          if (tape.get() === 0) {
            pc = this.bracketMap.get(pc)!;
          }
          break;
        case ']':
          if (tape.get() !== 0) {
            pc = this.bracketMap.get(pc)!;
          }
          break;
        case '.':
          result = (result << 2n) + BigInt(tape.get());
          break;
      }
      
      pc += 1;
    }

    return result;
  }
}

export class BrainfuckHashMap extends Benchmark {
  private text: string;
  private resultValue: bigint = 0n;

  constructor() {
    super();
    this.text = Helper.INPUT[this.constructor.name] || '';
  }

  run(): void {
    const program = new Program(this.text);
    this.resultValue = program.run();
  }

  getResult(): bigint {
    return this.resultValue;
  }
}

// =========== ./benchmarks/brainfuck-recursion.ts ===========

type Op = 
  | { type: 'inc'; val: number }
  | { type: 'move'; val: number }
  | { type: 'print' }
  | Op[];

class Tape2 {
  private tape: Uint8Array;
  private pos: number;
  private static readonly INITIAL_SIZE = 1024;
  
  constructor() {
    this.tape = new Uint8Array(Tape2.INITIAL_SIZE).fill(0);
    this.pos = 0;
  }
  
  get(): number {
    return this.tape[this.pos];
  }
  
  inc(x: number): void {
    this.tape[this.pos] += x;
  }
  
  move(x: number): void {
    this.pos += x;
    
    if (this.pos >= this.tape.length) {
      const newLength = Math.max(this.tape.length * 2, this.pos + 1);
      const newTape = new Uint8Array(newLength);
      newTape.set(this.tape);
      this.tape = newTape;
    }
    
    if (this.pos < 0) {
      this.pos = 0;
    }
  }
}

class Program2 {
  private ops: Op[];
  private resultValue: bigint;
  
  constructor(code: string) {
    this.ops = this.parse(code);
    this.resultValue = 0n;
  }
  
  run(): bigint {
    this.runOps(this.ops, new Tape2());
    return this.resultValue;
  }
  
  private runOps(program: Op[], tape: Tape2): void {
    for (const op of program) {
      if (Array.isArray(op)) {
        while (tape.get() !== 0) {
          this.runOps(op, tape);
        }
      } else {
        switch (op.type) {
          case 'inc':
            tape.inc(op.val);
            break;
          case 'move':
            tape.move(op.val);
            break;
          case 'print':
            this.resultValue = (this.resultValue << 2n) + BigInt(tape.get());
            break;
        }
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
        case '+':
          op = { type: 'inc', val: 1 };
          break;
        case '-':
          op = { type: 'inc', val: -1 };
          break;
        case '>':
          op = { type: 'move', val: 1 };
          break;
        case '<':
          op = { type: 'move', val: -1 };
          break;
        case '.':
          op = { type: 'print' };
          break;
        case '[':
          const [loopOps, newIndex] = this.parseSequence(chars, i);
          result.push(loopOps);
          i = newIndex;
          break;
        case ']':
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
  private resultValue: bigint;
  
  constructor() {
    super();
    this.text = Helper.INPUT[this.constructor.name] || '';
    this.resultValue = 0n;
  }
  
  run(): void {
    const program = new Program2(this.text);
    this.resultValue = program.run();
  }
  
  getResult(): bigint {
    return this.resultValue;
  }
}

// =========== ./benchmarks/buffer-hash-benchmark.ts ===========

export abstract class BufferHashBenchmark extends Benchmark {
  protected data: Uint8Array;
  protected n: number;
  protected resultValue: bigint = 0n;

  constructor() {
    super();
    this.n = this.iterations;
    this.data = new Uint8Array(1000000);
  }

  prepare(): void {
    Helper.reset();
    for (let i = 0; i < this.data.length; i++) {
      this.data[i] = Helper.nextInt(256);
    }
  }

  abstract test(): number;

  run(): void {
    for (let i = 0; i < this.n; i++) {
      const hash = this.test();
      this.resultValue = (this.resultValue + BigInt(hash)) & 0xFFFFFFFFn;
    }
  }

  getResult(): bigint {
    return this.resultValue;
  }
}

// =========== ./benchmarks/buffer-hash-crc32.ts ===========

export class BufferHashCRC32 extends BufferHashBenchmark {
  test(): number {
    let crc = 0xFFFFFFFF;

    for (const byte of this.data) {
      crc ^= byte;
      
      for (let j = 0; j < 8; j++) {
        if (crc & 1) {
          crc = (crc >>> 1) ^ 0xEDB88320;
        } else {
          crc >>>= 1;
        }
      }
    }

    return (crc ^ 0xFFFFFFFF) >>> 0;
  }
}

// =========== ./benchmarks/buffer-hash-sha256.ts ===========

class SimpleSHA256 {
  static digest(data: Uint8Array): Uint8Array {
    const result = new Uint8Array(32);
    
    const hashes = [
      0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
      0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19,
    ];

    for (let i = 0; i < data.length; i++) {
      const byte = data[i];
      const hashIdx = i % 8;
      let hash = hashes[hashIdx];
      
      hash = ((hash << 5) + hash) + byte;
      hash = (hash + (hash << 10)) ^ (hash >>> 6);
      hashes[hashIdx] = hash >>> 0;
    }

    for (let i = 0; i < 8; i++) {
      const hash = hashes[i];
      result[i * 4] = (hash >> 24) & 0xFF;
      result[i * 4 + 1] = (hash >> 16) & 0xFF;
      result[i * 4 + 2] = (hash >> 8) & 0xFF;
      result[i * 4 + 3] = hash & 0xFF;
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
}

// =========== ./benchmarks/cache-simulation.ts ===========

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
  private operations: number;
  private resultValue: bigint = 0n;

  constructor() {
    super();
    this.operations = this.iterations * 1000;
  }

  run(): void {
    const cache = new FastLRUCache<string, string>(1000);
    let hits = 0;
    let misses = 0;

    for (let i = 0; i < this.operations; i++) {
      const key = `item_${Helper.nextInt(2000)}`;
      
      if (cache.get(key) !== undefined) {
        hits++;
        cache.put(key, `updated_${i}`);
      } else {
        misses++;
        cache.put(key, `new_${i}`);
      }
    }

    const resultStr = `hits:${hits}|misses:${misses}|size:${cache.size()}`;
    this.resultValue = BigInt(Helper.checksumString(resultStr));
  }

  getResult(): bigint {
    return this.resultValue;
  }
}

// =========== ./benchmarks/calculator-ast.ts ===========

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
  constructor(public op: string, public left: Node2, public right: Node2) {
    super();
  }
}

class AssignmentNode extends Node2 {
  constructor(public varName: string, public expr: Node2) {
    super();
  }
}

class Parser {
  private input: string;
  private pos: number = 0;
  private chars: string[];
  private currentChar: string = '\0';
  public expressions: Node2[] = [];

  constructor(input: string) {
    this.input = input;
    this.chars = Array.from(input);
    this.currentChar = this.chars.length > 0 ? this.chars[0] : '\0';
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

      if (this.currentChar === '+' || this.currentChar === '-') {
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

      if (this.currentChar === '*' || this.currentChar === '/' || this.currentChar === '%') {
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

    if (char >= '0' && char <= '9') {
      return this.parseNumber();
    } else if ((char >= 'a' && char <= 'z') || (char >= 'A' && char <= 'Z')) {
      return this.parseVariable();
    } else if (char === '(') {
      this.advance();
      const node = this.parseExpression();
      this.skipWhitespace();
      if (this.currentChar === ')') {
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
      const digit = this.currentChar.charCodeAt(0) - '0'.charCodeAt(0);
      value = value * 10 + digit;
      this.advance();
    }
    return new NumberNode(value);
  }

  private parseVariable(): Node2 {
    const start = this.pos;
    while (this.pos < this.chars.length && 
           (this.isLetter(this.currentChar) || this.isDigit(this.currentChar))) {
      this.advance();
    }
    const varName = this.input.substring(start, this.pos);

    this.skipWhitespace();
    if (this.currentChar === '=') {
      this.advance();
      const expr = this.parseExpression();
      return new AssignmentNode(varName, expr);
    }

    return new VariableNode(varName);
  }

  private advance(): void {
    this.pos++;
    if (this.pos >= this.chars.length) {
      this.currentChar = '\0';
    } else {
      this.currentChar = this.chars[this.pos];
    }
  }

  private skipWhitespace(): void {
    while (this.pos < this.chars.length && this.isWhitespace(this.currentChar)) {
      this.advance();
    }
  }

  private isDigit(char: string): boolean {
    return char >= '0' && char <= '9';
  }

  private isLetter(char: string): boolean {
    return (char >= 'a' && char <= 'z') || (char >= 'A' && char <= 'Z');
  }

  private isWhitespace(char: string): boolean {
    return char === ' ' || char === '\t' || char === '\n' || char === '\r';
  }
}

export class CalculatorAst extends Benchmark {
  public n: number;
  private text: string = '';
  private expressions: Node2[] = [];
  private resultValue: number = 0;

  constructor() {
    super();
    this.n = this.iterations;
  }

  private generateRandomProgram(n: number = 1000): string {
      let result = 'v0 = 1\n';
      
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
          result += '\n';
      }
      
      return result;
  }
  prepare(): void {
    this.text = this.generateRandomProgram(this.n);
  }

  run(): void {
    const parser = new Parser(this.text);
    parser.parse();
    this.expressions = parser.expressions;
    this.resultValue = this.expressions.length;
  }

  getExpressions(): Node2[] {
    return this.expressions;
  }

  getResult(): bigint {
    return BigInt(this.resultValue);
  }
}

// =========== ./benchmarks/calculator-interpreter.ts ===========

class Int64 {
  private low: number;
  private high: number;

  constructor(value: number | bigint) {
    if (typeof value === 'bigint') {
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
    
    if ((this.low >>> 0) < (other.low >>> 0)) {
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
        case '+': return left.add(right);
        case '-': return left.sub(right);
        case '*': return left.mul(right);
        case '/': return left.div(right);
        case '%': return left.mod(right);
        default: return new Int64(0);
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
  private resultValue: bigint = 0n;

  prepare(): void {
    const calculator = new CalculatorAst();
    calculator.n = this.iterations;
    calculator.prepare();
    calculator.run();
    this.ast = calculator.getExpressions();
  }

  run(): void {
    let total = new Int64(0);
    
    for (let i = 0; i < 100; i++) {
      const interpreter = new Interpreter();
      const result = interpreter.run(this.ast);
      total = total.add(result);
    }
    
    this.resultValue = total.toBigInt();
  }

  getResult(): bigint {
    return this.resultValue;
  }
}

// =========== BUNDLED BENCHMARKS ===========

// ... весь код до compression.ts ...

// =========== ./benchmarks/compression.ts ===========

class CompressionBWTResult {
  constructor(
    public transformed: Uint8Array,
    public originalIdx: number
  ) {}
}

class CompressionHuffmanNode {
  constructor(
    public frequency: number,
    public byteVal: number | null = null,
    public isLeaf: boolean = true,
    public left: CompressionHuffmanNode | null = null,
    public right: CompressionHuffmanNode | null = null
  ) {}
}

class CompressionHuffmanCodes {
  codeLengths: number[] = new Array(256).fill(0);
  codes: number[] = new Array(256).fill(0);
}

class CompressionEncodedResult {
  constructor(
    public data: Uint8Array,
    public bitCount: number
  ) {}
}

class CompressionCompressedData {
  constructor(
    public bwtResult: CompressionBWTResult,
    public frequencies: number[],
    public encodedBits: Uint8Array,
    public originalBitCount: number
  ) {}
}

export class Compression extends Benchmark {
  private result: number = 0;
  private testData: Uint8Array = new Uint8Array();

  constructor() {
    super();
  }

  private getIterations(): number {
    const input = Helper.INPUT['Compression'];
    return input ? parseInt(input) : 0;
  }

  private bwtTransform(input: Uint8Array): CompressionBWTResult {
    const n = input.length;
    if (n === 0) {
      return new CompressionBWTResult(new Uint8Array(), 0);
    }

    const doubled = new Uint8Array(n * 2);
    doubled.set(input, 0);
    doubled.set(input, n);

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
          newRank[sa[i]] = newRank[sa[i - 1]] + 
            (prevPair[0] !== currPair[0] || prevPair[1] !== currPair[1] ? 1 : 0);
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

    return new CompressionBWTResult(transformed, originalIdx);
  }

  private bwtInverse(bwtResult: CompressionBWTResult): Uint8Array {
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

  private buildHuffmanTree(frequencies: number[]): CompressionHuffmanNode {
    const heap: CompressionHuffmanNode[] = [];

    for (let i = 0; i < frequencies.length; i++) {
      if (frequencies[i] > 0) {
        heap.push(new CompressionHuffmanNode(frequencies[i], i));
      }
    }

    heap.sort((a, b) => a.frequency - b.frequency);

    if (heap.length === 1) {
      const node = heap[0];
      return new CompressionHuffmanNode(
        node.frequency,
        null,
        false,
        node,
        new CompressionHuffmanNode(0, 0)
      );
    }

    while (heap.length > 1) {
      const left = heap.shift()!;
      const right = heap.shift()!;

      const parent = new CompressionHuffmanNode(
        left.frequency + right.frequency,
        null,
        false,
        left,
        right
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

  private buildHuffmanCodes(
    node: CompressionHuffmanNode,
    code: number = 0,
    length: number = 0,
    huffmanCodes: CompressionHuffmanCodes = new CompressionHuffmanCodes()
  ): CompressionHuffmanCodes {
    if (node.isLeaf) {
      if (length > 0 || node.byteVal !== 0) {
        const idx = node.byteVal!;
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
    return huffmanCodes;
  }

  private huffmanEncode(data: Uint8Array, huffmanCodes: CompressionHuffmanCodes): CompressionEncodedResult {
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

    return new CompressionEncodedResult(result.slice(0, byteIndex), totalBits);
  }

  private huffmanDecode(encoded: Uint8Array, root: CompressionHuffmanNode, bitCount: number): Uint8Array {
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
          if (currentNode.byteVal !== 0) {
            result.push(currentNode.byteVal!);
          }
          currentNode = root;
        }
      }
    }

    return new Uint8Array(result);
  }

  private compress(data: Uint8Array): CompressionCompressedData {
    const bwtResult = this.bwtTransform(data);

    const frequencies = new Array(256).fill(0);
    for (const byte of bwtResult.transformed) {
      frequencies[byte]++;
    }

    const huffmanTree = this.buildHuffmanTree(frequencies);

    const huffmanCodes = this.buildHuffmanCodes(huffmanTree);

    const encoded = this.huffmanEncode(bwtResult.transformed, huffmanCodes);

    return new CompressionCompressedData(
      bwtResult,
      frequencies,
      encoded.data,
      encoded.bitCount
    );
  }

  private decompress(compressed: CompressionCompressedData): Uint8Array {
    const huffmanTree = this.buildHuffmanTree(compressed.frequencies);

    const decoded = this.huffmanDecode(
      compressed.encodedBits,
      huffmanTree,
      compressed.originalBitCount
    );

    const bwtResult = new CompressionBWTResult(
      decoded,
      compressed.bwtResult.originalIdx
    );

    return this.bwtInverse(bwtResult);
  }

  private generateTestData(size: number): Uint8Array {
    const pattern = new TextEncoder().encode("ABRACADABRA");
    const data = new Uint8Array(size);

    for (let i = 0; i < size; i++) {
      data[i] = pattern[i % pattern.length];
    }

    return data;
  }

  prepare(): void {
    this.testData = this.generateTestData(this.iterations);
  }

  run(): void {
    let totalChecksum = 0;

    for (let i = 0; i < 5; i++) {
      const compressed = this.compress(this.testData);

      const decompressed = this.decompress(compressed);

      const checksum = Helper.checksumBytes(decompressed);

      totalChecksum = (totalChecksum + compressed.encodedBits.length) >>> 0;
      totalChecksum = (totalChecksum + checksum) >>> 0;
    }

    this.result = totalChecksum;
  }

  getResult(): bigint {
    return BigInt(this.result);
  }
}

// =========== ./benchmarks/fannkuchredux.ts ===========

export class Fannkuchredux extends Benchmark {
  private n: number;
  private resultValue: bigint = 0n;

  constructor() {
    super();
    this.n = this.iterations;
  }

  private fannkuchredux(n: number): [number, number] {
    const perm1: number[] = Array.from({ length: n }, (_, i) => i);
    const perm: number[] = new Array(n).fill(0);
    const count: number[] = new Array(n).fill(0);
    
    let maxFlipsCount = 0;
    let permCount = 0;
    let checksum = 0;
    let r = n;

    while (true) {
      while (r > 1) {
        count[r - 1] = r;
        r -= 1;
      }

      for (let i = 0; i < n; i++) {
        perm[i] = perm1[i];
      }

      let flipsCount = 0;
      let k = perm[0];

      while (k !== 0) {
        const k2 = Math.floor((k + 1) / 2);
        
        for (let i = 0; i < k2; i++) {
          const j = k - i;
          const temp = perm[i];
          perm[i] = perm[j];
          perm[j] = temp;
        }
        
        flipsCount += 1;
        k = perm[0];
      }

      if (flipsCount > maxFlipsCount) {
        maxFlipsCount = flipsCount;
      }

      checksum += (permCount % 2 === 0) ? flipsCount : -flipsCount;

      while (true) {
        if (r === n) {
          return [checksum, maxFlipsCount];
        }

        const perm0 = perm1[0];
        for (let i = 0; i < r; i++) {
          const j = i + 1;
          const temp = perm1[i];
          perm1[i] = perm1[j];
          perm1[j] = temp;
        }

        perm1[r] = perm0;
        count[r] -= 1;
        const cntr = count[r];
        
        if (cntr > 0) {
          break;
        }
        
        r += 1;
      }
      
      permCount += 1;
    }
  }

  run(): void {
    const [checksum, maxFlipsCount] = this.fannkuchredux(this.n);
    this.resultValue = BigInt(checksum * 100 + maxFlipsCount);
  }

  getResult(): bigint {
    return this.resultValue;
  }
}

// =========== ./benchmarks/fasta.ts ===========

interface Gene {
  char: string;
  prob: number;
}

export class Fasta extends Benchmark {
  private static readonly LINE_LENGTH = 60;
  
  private static readonly IUB: Gene[] = [
    {char: 'a', prob: 0.27}, {char: 'c', prob: 0.39}, {char: 'g', prob: 0.51},
    {char: 't', prob: 0.78}, {char: 'B', prob: 0.8}, {char: 'D', prob: 0.8200000000000001},
    {char: 'H', prob: 0.8400000000000001}, {char: 'K', prob: 0.8600000000000001},
    {char: 'M', prob: 0.8800000000000001}, {char: 'N', prob: 0.9000000000000001},
    {char: 'R', prob: 0.9200000000000002}, {char: 'S', prob: 0.9400000000000002},
    {char: 'V', prob: 0.9600000000000002}, {char: 'W', prob: 0.9800000000000002},
    {char: 'Y', prob: 1.0000000000000002}
  ];
  
  private static readonly HOMO: Gene[] = [
    {char: 'a', prob: 0.302954942668}, {char: 'c', prob: 0.5009432431601},
    {char: 'g', prob: 0.6984905497992}, {char: 't', prob: 1.0}
  ];
  
  private static readonly ALU = "GGCCGGGCGCGGTGGCTCACGCCTGTAATCCCAGCACTTTGGGAGGCCGAGGCGGGCGGATCACCTGAGGTCAGGAGTTCGAGACCAGCCTGGCCAACATGGTGAAACCCCGTCTCTACTAAAAATACAAAAATTAGCCGGGCGTGGTGGCGCGCGCCTGTAATCCCAGCTACTCGGGAGGCTGAGGCAGGAGAATCGCTTGAACCCGGGAGGCGGAGGTTGCAGTGAGCCGAGATCGCGCCACTGCACTCCAGCCTGGGCGACAGAGCGAGACTCCGTCTCAAAAA";
  
  public n: number;
  public resultStr: string = '';

  constructor() {
    super();
    this.n = this.iterations;
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

  private makeRandomFasta(id: string, desc: string, genelist: Gene[], n: number): void {
    let todo = n;
    this.resultStr += `>${id} ${desc}\n`;

    while (todo > 0) {
      const m = todo < Fasta.LINE_LENGTH ? todo : Fasta.LINE_LENGTH;
      let line = '';
      
      for (let i = 0; i < m; i++) {
        line += this.selectRandom(genelist);
      }
      
      this.resultStr += line + '\n';
      todo -= Fasta.LINE_LENGTH;
    }
  }

  private makeRepeatFasta(id: string, desc: string, s: string, n: number): void {
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
      
      this.resultStr += '\n';
      todo -= Fasta.LINE_LENGTH;
    }
  }

  run(): void {
    this.resultStr = '';
    this.makeRepeatFasta("ONE", "Homo sapiens alu", Fasta.ALU, this.n * 2);
    this.makeRandomFasta("TWO", "IUB ambiguity codes", Fasta.IUB, this.n * 3);
    this.makeRandomFasta("THREE", "Homo sapiens frequency", Fasta.HOMO, this.n * 5);
  }

  getResult(): bigint {
    return BigInt(Helper.checksumString(this.resultStr));
  }
}

// =========== ./benchmarks/game_of_life.ts ===========

enum Cell {
    Dead,
    Alive
}

class GameOfLifeGrid {
    private width: number;
    private height: number;
    private cells: Cell[][];
    
    constructor(width: number, height: number) {
        this.width = width;
        this.height = height;
        this.cells = Array(height);
        for (let y = 0; y < height; y++) {
            this.cells[y] = Array(width).fill(Cell.Dead);
        }
    }
    
    get(x: number, y: number): Cell {
        return this.cells[y][x];
    }
    
    set(x: number, y: number, cell: Cell): void {
        this.cells[y][x] = cell;
    }
    
    countNeighbors(x: number, y: number): number {
        let count = 0;
        
        for (let dy = -1; dy <= 1; dy++) {
            for (let dx = -1; dx <= 1; dx++) {
                if (dx === 0 && dy === 0) continue;
                
                let nx = (x + dx) % this.width;
                let ny = (y + dy) % this.height;
                if (nx < 0) nx += this.width;
                if (ny < 0) ny += this.height;
                
                if (this.cells[ny][nx] === Cell.Alive) {
                    count++;
                }
            }
        }
        
        return count;
    }
    
    nextGeneration(): GameOfLifeGrid {
        const nextGrid = new GameOfLifeGrid(this.width, this.height);
        
        for (let y = 0; y < this.height; y++) {
            for (let x = 0; x < this.width; x++) {
                const neighbors = this.countNeighbors(x, y);
                const current = this.cells[y][x];
                
                let nextState = Cell.Dead;
                if (current === Cell.Alive) {
                    if (neighbors === 2 || neighbors === 3) {
                        nextState = Cell.Alive;
                    }
                } else {
                    if (neighbors === 3) {
                        nextState = Cell.Alive;
                    }
                }
                
                nextGrid.cells[y][x] = nextState;
            }
        }
        
        return nextGrid;
    }
    
    aliveCount(): number {
        let count = 0;
        for (const row of this.cells) {
            for (const cell of row) {
                if (cell === Cell.Alive) {
                    count++;
                }
            }
        }
        return count;
    }
}

export class GameOfLife extends Benchmark {
    private resultVal: bigint = 0n;
    private readonly width: number = 256;
    private readonly height: number = 256;
    private grid: GameOfLifeGrid;
    
    constructor() {
        super();
        this.grid = new GameOfLifeGrid(this.width, this.height);
    }
    
    prepare(): void {
        for (let y = 0; y < this.height; y++) {
            for (let x = 0; x < this.width; x++) {
                if (Helper.nextFloat() < 0.1) {
                    this.grid.set(x, y, Cell.Alive);
                }
            }
        }
    }
    
    run(): void {
        const iters = this.iterations;
        for (let i = 0; i < iters; i++) {
            this.grid = this.grid.nextGeneration();
        }
        
        this.resultVal = BigInt(this.grid.aliveCount());
    }
    
    getResult(): bigint {
        return this.resultVal;
    }
}

// =========== ./benchmarks/graph-path-benchmark.ts ===========

export class GraphPathGraph {
  vertices: number;
  private adj: number[][];
  private components: number;

  constructor(vertices: number, components: number = 10) {
    this.vertices = vertices;
    this.components = Math.max(10, Math.floor(vertices / 10000));
    this.adj = Array(vertices).fill(0).map(() => []);
  }

  addEdge(u: number, v: number): void {
    this.adj[u].push(v);
    this.adj[v].push(u);
  }

  generateRandom(): void {
    const componentSize = Math.floor(this.vertices / this.components);

    for (let c = 0; c < this.components; c++) {
      const startIdx = c * componentSize;
      const endIdx = c === this.components - 1 ? this.vertices : (c + 1) * componentSize;

      for (let i = startIdx + 1; i < endIdx; i++) {
        const parent = startIdx + Helper.nextInt(i - startIdx);
        this.addEdge(i, parent);
      }

      for (let i = 0; i < componentSize * 2; i++) {
        const u = startIdx + Helper.nextInt(endIdx - startIdx);
        const v = startIdx + Helper.nextInt(endIdx - startIdx);
        if (u !== v) {
          this.addEdge(u, v);
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
  protected pairs: [number, number][] = [];
  protected nPairs: number;
  protected resultValue: bigint = 0n;

  constructor() {
    super();
    this.nPairs = this.iterations;
  }

  prepare(): void {
    const vertices = this.nPairs * 10;
    this.graph = new GraphPathGraph(vertices, Math.max(10, Math.floor(vertices / 10000)));
    this.graph.generateRandom();
    this.pairs = this.generatePairs(this.nPairs);
  }

  protected generatePairs(n: number): [number, number][] {
    const pairs: [number, number][] = [];
    const componentSize = Math.floor(this.graph.getVertices() / 10);

    for (let i = 0; i < n; i++) {
      if (Helper.nextInt(100) < 70) {
        const component = Helper.nextInt(10);
        const start = component * componentSize + Helper.nextInt(componentSize);
        let end: number;
        do {
          end = component * componentSize + Helper.nextInt(componentSize);
        } while (end === start);
        pairs.push([start, end]);
      } else {
        let c1 = Helper.nextInt(10);
        let c2 = Helper.nextInt(10);
        while (c2 === c1) {
          c2 = Helper.nextInt(10);
        }
        const start = c1 * componentSize + Helper.nextInt(componentSize);
        const end = c2 * componentSize + Helper.nextInt(componentSize);
        pairs.push([start, end]);
      }
    }

    return pairs;
  }

  abstract run(): void;

  getResult(): bigint {
    return this.resultValue;
  }
}

// =========== ./benchmarks/graph-path-bfs.ts ===========

export class GraphPathBFS extends GraphPathBenchmark {
  run(): void {
    let totalLength = 0n;

    for (const [start, end] of this.pairs) {
      const length = this.bfsShortestPath(start, end);
      totalLength += BigInt(length);
    }

    this.resultValue = totalLength;
  }

  private bfsShortestPath(start: number, target: number): number {
    if (start === target) return 0;

    const visited = new Uint8Array(this.graph.getVertices());
    const queue: [number, number][] = [[start, 0]];
    visited[start] = 1;

    while (queue.length > 0) {
      const [v, dist] = queue.shift()!;

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
}

// =========== ./benchmarks/graph-path-dfs.ts ===========

export class GraphPathDFS extends GraphPathBenchmark {
  run(): void {
    let totalLength = 0n;

    for (const [start, end] of this.pairs) {
      const length = this.dfsFindPath(start, end);
      totalLength += BigInt(length);
    }

    this.resultValue = totalLength;
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
}

// =========== ./benchmarks/graph-path-dijkstra.ts ===========

export class GraphPathDijkstra extends GraphPathBenchmark {
  private static readonly INF = Number.MAX_SAFE_INTEGER / 2;

  run(): void {
    let totalLength = 0n;

    for (const [start, end] of this.pairs) {
      const length = this.dijkstraShortestPath(start, end);
      totalLength += BigInt(length);
    }

    this.resultValue = totalLength;
  }

  private dijkstraShortestPath(start: number, target: number): number {
    if (start === target) return 0;

    const vertices = this.graph.getVertices();
    const dist = new Array(vertices).fill(GraphPathDijkstra.INF);
    const visited = new Uint8Array(vertices);
    
    dist[start] = 0;
    const maxIterations = vertices;

    for (let iteration = 0; iteration < maxIterations; iteration++) {
      let u = -1;
      let minDist = GraphPathDijkstra.INF;

      for (let v = 0; v < vertices; v++) {
        if (visited[v] === 0 && dist[v] < minDist) {
          minDist = dist[v];
          u = v;
        }
      }

      if (u === -1 || minDist === GraphPathDijkstra.INF || u === target) {
        return u === target ? minDist : -1;
      }

      visited[u] = 1;

      for (const v of this.graph.getAdjacency()[u]) {
        if (dist[u] + 1 < dist[v]) {
          dist[v] = dist[u] + 1;
        }
      }
    }

    return -1;
  }
}

// =========== ./benchmarks/json-generate.ts ===========

export class JsonGenerate extends Benchmark {
  public n: number;
  private data: any[] = [];
  private text: string = '';

  constructor() {
    super();
    this.n = this.iterations;
  }

  prepare(): void {
    Helper.reset();
    this.data = [];
    
    for (let i = 0; i < this.n; i++) {
      this.data.push({
        x: parseFloat(Helper.nextFloat().toFixed(8)),
        y: parseFloat(Helper.nextFloat().toFixed(8)),
        z: parseFloat(Helper.nextFloat().toFixed(8)),
        name: `${Helper.nextFloat().toFixed(7)} ${Helper.nextInt(10000)}`,
        opts: {
          "1": [1, true]
        }
      });
    }
  }

  run(): void {
    const jsonData = {
      coordinates: this.data,
      info: "some info"
    };
    
    this.text = JSON.stringify(jsonData, null, 0);
  }

  getText(): string {
    return this.text;
  }

  getResult(): bigint {
    return 1n;
  }
}

// =========== ./benchmarks/json-parse-dom.ts ===========

export class JsonParseDom extends Benchmark {
  private text: string = '';
  private resultValue: bigint = 0n;

  prepare(): void {
    const jsonGen = new JsonGenerate();
    jsonGen.n = this.iterations;
    jsonGen.prepare();
    jsonGen.run();
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

  run(): void {
    const [x, y, z] = this.calc(this.text);
    
    let checksum = 0;
    checksum = (checksum + Helper.checksumFloat(x)) & 0xFFFFFFFF;
    checksum = (checksum + Helper.checksumFloat(y)) & 0xFFFFFFFF;
    checksum = (checksum + Helper.checksumFloat(z)) & 0xFFFFFFFF;
    
    this.resultValue = BigInt(checksum >>> 0);
  }

  getResult(): bigint {
    return this.resultValue;
  }
}

// =========== ./benchmarks/json-parse-mapping.ts ===========

interface Coordinate {
  x: number;
  y: number;
  z: number;
}

interface CoordinatesData {
  coordinates: Coordinate[];
  info?: string;
}

export class JsonParseMapping extends Benchmark {
  private text: string = '';
  private resultValue: bigint = 0n;

  prepare(): void {
    const jsonGen = new JsonGenerate();
    jsonGen.n = this.iterations;
    jsonGen.prepare();
    jsonGen.run();
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
      z: z / len
    };
  }

  run(): void {
    const coord = this.calc(this.text);
    
    let checksum = 0;
    checksum = (checksum + Helper.checksumFloat(coord.x)) & 0xFFFFFFFF;
    checksum = (checksum + Helper.checksumFloat(coord.y)) & 0xFFFFFFFF;
    checksum = (checksum + Helper.checksumFloat(coord.z)) & 0xFFFFFFFF;
    
    this.resultValue = BigInt(checksum >>> 0);
  }

  getResult(): bigint {
    return this.resultValue;
  }
}

// =========== ./benchmarks/knuckeotide.ts ===========

export class Knuckeotide extends Benchmark {
  private seq: string = '';
  private resultStr: string = '';

  private frequency(seq: string, length: number): { n: number; table: Map<string, number> } {
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
    
    this.resultStr += '\n';
  }

  private findSeq(seq: string, s: string): void {
    const { n, table } = this.frequency(seq, s.length);
    const count = table.get(s.toLowerCase()) || 0;
    this.resultStr += `${count}\t${s.toUpperCase()}\n`;
  }

  prepare(): void {
      const n = this.iterations;

      const fasta = new Fasta();
      fasta.setIterations(n);
      fasta.prepare();
      fasta.run();
      
      const fastaOutput = fasta.resultStr;
      
      let seq = '';
      let afterThree = false;
      
      const lines = fastaOutput.split('\n');
      for (const line of lines) {
          if (line.startsWith('>THREE')) {
              afterThree = true;
              continue;
          }
          
          if (afterThree) {
              if (line.startsWith('>')) {
                  break;
              }
              seq += line.trim();
          }
      }
      
      this.seq = seq;
  }

  run(): void {
    this.resultStr = '';
    
    for (let i = 1; i <= 2; i++) {
      this.sortByFreq(this.seq, i);
    }
    
    const sequences = ['ggt', 'ggta', 'ggtatt', 'ggtattttaatt', 'ggtattttaatttatagt'];
    for (const s of sequences) {
      this.findSeq(this.seq, s);
    }
  }

  getResult(): bigint {
    return BigInt(Helper.checksumString(this.resultStr));
  }
}

// =========== ./benchmarks/mandelbrot.ts ===========

export class Mandelbrot extends Benchmark {
  private static readonly ITER = 50;
  private static readonly LIMIT = 2.0;
  
  private n: number;
  private resultBytes: number[] = [];

  constructor() {
    super();
    this.n = this.iterations;
  }

  run(): void {
    const w = this.n;
    const h = this.n;
    
    const header = `P4\n${w} ${h}\n`;
    
    this.resultBytes = Array.from(header, c => c.charCodeAt(0));
    
    let bitNum = 0;
    let byteAcc = 0;

    for (let y = 0; y < h; y++) {
      for (let x = 0; x < w; x++) {
        let zr = 0.0;
        let zi = 0.0;
        let tr = 0.0;
        let ti = 0.0;
        
        const cr = (2.0 * x / w - 1.5);
        const ci = (2.0 * y / h - 1.0);

        let i = 0;
        while (i < Mandelbrot.ITER && (tr + ti) <= Mandelbrot.LIMIT * Mandelbrot.LIMIT) {
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
        } else if (x === w - 1) {
          byteAcc <<= (8 - (w % 8));
          this.resultBytes.push(byteAcc);
          byteAcc = 0;
          bitNum = 0;
        }
      }
    }
  }

  getResult(): bigint {
    const bytes = new Uint8Array(this.resultBytes);
    return BigInt(Helper.checksumBytes(bytes));
  }
}

// =========== ./benchmarks/matmul.ts ===========

export class Matmul extends Benchmark {
  private n: number;
  private resultValue: bigint = 0n;

  constructor() {
    super();
    this.n = this.iterations;
  }

  private matmul(a: number[][], b: number[][]): number[][] {
    const m = a.length;
    const n = a[0].length;
    const p = b[0].length;
    
    const b2: number[][] = Array(p).fill(0).map(() => Array(n).fill(0));
    for (let i = 0; i < n; i++) {
      for (let j = 0; j < p; j++) {
        b2[j][i] = b[i][j];
      }
    }
    
    const c: number[][] = Array(m).fill(0).map(() => Array(p).fill(0));
    
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
    const a: number[][] = Array(n).fill(0).map(() => Array(n).fill(0));
    
    for (let i = 0; i < n; i++) {
      for (let j = 0; j < n; j++) {
        a[i][j] = tmp * (i - j) * (i + j);
      }
    }
    
    return a;
  }

  run(): void {
    const a = this.matgen(this.n);
    const b = this.matgen(this.n);
    const c = this.matmul(a, b);
    const value = c[this.n >> 1][this.n >> 1];
    
    this.resultValue = BigInt(Helper.checksumFloat(value));
  }

  getResult(): bigint {
    return this.resultValue;
  }
}

// =========== ./benchmarks/matmul.ts ===========

export class Matmul4T extends Benchmark {
  private n: number;
  private resultValue: bigint = 0n;

  constructor() {
    super();
    this.n = this.iterations;
  }

  private matgen(n: number): number[][] {
    const tmp = 1.0 / n / n;
    const a: number[][] = Array(n).fill(0).map(() => Array(n).fill(0));
    
    for (let i = 0; i < n; i++) {
      for (let j = 0; j < n; j++) {
        a[i][j] = tmp * (i - j) * (i + j);
      }
    }
    
    return a;
  }

  private matmulParallel(a: number[][], b: number[][]): number[][] {
    const size = a.length;
    
    // Транспонируем b
    const bT: number[][] = Array(size).fill(0).map(() => Array(size).fill(0));
    for (let i = 0; i < size; i++) {
      for (let j = 0; j < size; j++) {
        bT[j][i] = b[i][j];
      }
    }
    
    // Умножение матриц (разделяем на 4 части)
    const c: number[][] = Array(size).fill(0).map(() => Array(size).fill(0));
    
    const numParts = 4;
    const rowsPerPart = Math.ceil(size / numParts);
    
    // Выполняем последовательно, но разделяем работу
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

  run(): void {
    const a = this.matgen(this.n);
    const b = this.matgen(this.n);
    const c = this.matmulParallel(a, b);
    const value = c[this.n >> 1][this.n >> 1];
    
    this.resultValue = BigInt(Helper.checksumFloat(value));
  }

  getResult(): bigint {
    return this.resultValue;
  }
}

// =========== ./benchmarks/matmul.ts ===========

export class Matmul8T extends Benchmark {
  private n: number;
  private resultValue: bigint = 0n;

  constructor() {
    super();
    this.n = this.iterations;
  }

  private matgen(n: number): number[][] {
    const tmp = 1.0 / n / n;
    const a: number[][] = Array(n).fill(0).map(() => Array(n).fill(0));
    
    for (let i = 0; i < n; i++) {
      for (let j = 0; j < n; j++) {
        a[i][j] = tmp * (i - j) * (i + j);
      }
    }
    
    return a;
  }

  private matmulParallel(a: number[][], b: number[][]): number[][] {
    const size = a.length;
    
    // Транспонируем b
    const bT: number[][] = Array(size).fill(0).map(() => Array(size).fill(0));
    for (let i = 0; i < size; i++) {
      for (let j = 0; j < size; j++) {
        bT[j][i] = b[i][j];
      }
    }
    
    // Умножение матриц (разделяем на 4 части)
    const c: number[][] = Array(size).fill(0).map(() => Array(size).fill(0));
    
    const numParts = 8;
    const rowsPerPart = Math.ceil(size / numParts);
    
    // Выполняем последовательно, но разделяем работу
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

  run(): void {
    const a = this.matgen(this.n);
    const b = this.matgen(this.n);
    const c = this.matmulParallel(a, b);
    const value = c[this.n >> 1][this.n >> 1];
    
    this.resultValue = BigInt(Helper.checksumFloat(value));
  }

  getResult(): bigint {
    return this.resultValue;
  }
}

// =========== ./benchmarks/matmul.ts ===========

export class Matmul16T extends Benchmark {
  private n: number;
  private resultValue: bigint = 0n;

  constructor() {
    super();
    this.n = this.iterations;
  }

  private matgen(n: number): number[][] {
    const tmp = 1.0 / n / n;
    const a: number[][] = Array(n).fill(0).map(() => Array(n).fill(0));
    
    for (let i = 0; i < n; i++) {
      for (let j = 0; j < n; j++) {
        a[i][j] = tmp * (i - j) * (i + j);
      }
    }
    
    return a;
  }

  private matmulParallel(a: number[][], b: number[][]): number[][] {
    const size = a.length;
    
    // Транспонируем b
    const bT: number[][] = Array(size).fill(0).map(() => Array(size).fill(0));
    for (let i = 0; i < size; i++) {
      for (let j = 0; j < size; j++) {
        bT[j][i] = b[i][j];
      }
    }
    
    // Умножение матриц (разделяем на 4 части)
    const c: number[][] = Array(size).fill(0).map(() => Array(size).fill(0));
    
    const numParts = 16;
    const rowsPerPart = Math.ceil(size / numParts);
    
    // Выполняем последовательно, но разделяем работу
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

  run(): void {
    const a = this.matgen(this.n);
    const b = this.matgen(this.n);
    const c = this.matmulParallel(a, b);
    const value = c[this.n >> 1][this.n >> 1];
    
    this.resultValue = BigInt(Helper.checksumFloat(value));
  }

  getResult(): bigint {
    return this.resultValue;
  }
}

// =========== ./benchmarks/maze_generator.ts ===========

enum MazeCell {
    Wall,
    Path
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
        
        if (widthForWall === 0 || heightForWall === 0 ||
            widthForHole === 0 || heightForHole === 0) return;
        
        if (width > height) {
            const wallRange = Math.max(widthForWall / 2, 1);
            const wallOffset = wallRange > 0 ? (Helper.nextInt(wallRange)) * 2 : 0;
            const wallX = x1 + 2 + wallOffset;
            
            const holeRange = Math.max(heightForHole / 2, 1);
            const holeOffset = holeRange > 0 ? (Helper.nextInt(holeRange)) * 2 : 0;
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
            const wallRange = Math.max(heightForWall / 2, 1);
            const wallOffset = wallRange > 0 ? (Helper.nextInt(wallRange)) * 2 : 0;
            const wallY = y1 + 2 + wallOffset;
            
            const holeRange = Math.max(widthForHole / 2, 1);
            const holeOffset = holeRange > 0 ? (Helper.nextInt(holeRange)) * 2 : 0;
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
    
    private isConnectedImpl(startX: number, startY: number, goalX: number, goalY: number): boolean {
        if (startX >= this.width || startY >= this.height ||
            goalX >= this.width || goalY >= this.height) {
            return false;
        }
        
        const visited: boolean[][] = Array(this.height);
        for (let y = 0; y < this.height; y++) {
            visited[y] = Array(this.width).fill(false);
        }
        
        const queue: [number, number][] = [];
        let queueIndex = 0;  // Используем индекс вместо shift()
        
        visited[startY][startX] = true;
        queue.push([startX, startY]);
        
        while (queueIndex < queue.length) {
            const [x, y] = queue[queueIndex++];
            
            if (x === goalX && y === goalY) return true;
            
            // Верх
            if (y > 0 && this.get(x, y - 1) === MazeCell.Path && !visited[y - 1][x]) {
                visited[y - 1][x] = true;
                queue.push([x, y - 1]);
            }
            
            // Право
            if (x + 1 < this.width && this.get(x + 1, y) === MazeCell.Path && !visited[y][x + 1]) {
                visited[y][x + 1] = true;
                queue.push([x + 1, y]);
            }
            
            // Низ
            if (y + 1 < this.height && this.get(x, y + 1) === MazeCell.Path && !visited[y + 1][x]) {
                visited[y + 1][x] = true;
                queue.push([x, y + 1]);
            }
            
            // Лево
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
    }
    
    toBoolGrid(): boolean[][] {
        const result: boolean[][] = Array(this.height);
        for (let y = 0; y < this.height; y++) {
            result[y] = Array(this.width);
            for (let x = 0; x < this.width; x++) {
                result[y][x] = (this.cells[y][x] === MazeCell.Path);
            }
        }
        return result;
    }
    
    isConnected(startX: number, startY: number, goalX: number, goalY: number): boolean {
        return this.isConnectedImpl(startX, startY, goalX, goalY);
    }
    
    public static generateWalkableMaze(width: number, height: number): boolean[][] {
        const maze = new MazeGeneratorClass(width, height);
        maze.generate();
        
        const startX = 1;
        const startY = 1;
        const goalX = width - 2;
        const goalY = height - 2;
        
        if (!maze.isConnected(startX, startY, goalX, goalY)) {
            // Убираем избыточные проверки - maze.width === width по конструкции
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
    private resultVal: bigint = 0n;
    private readonly width: number = 1001;
    private readonly height: number = 1001;
    
    run(): void {
        let checksum = 0;  // Используем number для промежуточных вычислений
        
        const iters = this.iterations;
        for (let i = 0; i < iters; i++) {
            const boolGrid = MazeGeneratorClass.generateWalkableMaze(this.width, this.height);
            
            // Оптимизация: кэшируем ссылки на строки
            for (let y = 0; y < boolGrid.length; y++) {
                const row = boolGrid[y];
                for (let x = 0; x < row.length; x++) {
                    if (!row[x]) {
                        checksum += x * y;  // Работаем с number
                    }
                }
            }
        }
        
        // Конвертируем в BigInt только в конце
        this.resultVal = BigInt(checksum);
    }
    
    getResult(): bigint {
        return this.resultVal;
    }
}

// =========== ./benchmarks/a_star_pathfinder.ts ===========

interface Heuristic {
    distance(aX: number, aY: number, bX: number, bY: number): number;
}

class ManhattanHeuristic implements Heuristic {
    distance(aX: number, aY: number, bX: number, bY: number): number {
        return (Math.abs(aX - bX) + Math.abs(aY - bY)) * 1000;
    }
}

class EuclideanHeuristic implements Heuristic {
    distance(aX: number, aY: number, bX: number, bY: number): number {
        const dx = Math.abs(aX - bX);
        const dy = Math.abs(aY - bY);
        return Math.hypot(dx, dy) * 1000;
    }
}

class ChebyshevHeuristic implements Heuristic {
    distance(aX: number, aY: number, bX: number, bY: number): number {
        return Math.max(Math.abs(aX - bX), Math.abs(aY - bY)) * 1000;
    }
}

class AStarPathfinderNode {
    x: number;
    y: number;
    fScore: number;
    
    constructor(x: number, y: number, fScore: number) {
        this.x = x;
        this.y = y;
        this.fScore = fScore;
    }
    
    compareTo(other: AStarPathfinderNode): number {
        if (this.fScore !== other.fScore) {
            return this.fScore - other.fScore;
        }
        if (this.y !== other.y) {
            return this.y - other.y;
        }
        return this.x - other.x;
    }
}

class AStarPathfinderBinaryHeap {
    private data: AStarPathfinderNode[] = [];
    
    push(item: AStarPathfinderNode): void {
        this.data.push(item);
        this.siftUp(this.data.length - 1);
    }
    
    pop(): AStarPathfinderNode | null {
        if (this.data.length === 0) {
            return null;
        }
        
        if (this.data.length === 1) {
            return this.data.pop()!;
        }
        
        const result = this.data[0];
        this.data[0] = this.data[this.data.length - 1];
        this.data.pop();
        this.siftDown(0);
        return result;
    }
    
    isEmpty(): boolean {
        return this.data.length === 0;
    }
    
    private siftUp(index: number): void {
        while (index > 0) {
            const parent = Math.floor((index - 1) / 2);
            if (this.data[index].compareTo(this.data[parent]) >= 0) break;
            [this.data[index], this.data[parent]] = [this.data[parent], this.data[index]];
            index = parent;
        }
    }
    
    private siftDown(index: number): void {
        const size = this.data.length;
        while (true) {
            const left = index * 2 + 1;
            const right = left + 1;
            let smallest = index;
            
            if (left < size && this.data[left].compareTo(this.data[smallest]) < 0) {
                smallest = left;
            }
            
            if (right < size && this.data[right].compareTo(this.data[smallest]) < 0) {
                smallest = right;
            }
            
            if (smallest === index) break;
            
            [this.data[index], this.data[smallest]] = [this.data[smallest], this.data[index]];
            index = smallest;
        }
    }
}

export class AStarPathfinder extends Benchmark {
    private resultVal: bigint = 0n;
    private readonly startX: number;
    private readonly startY: number;
    private readonly goalX: number;
    private readonly goalY: number;
    private readonly width: number;
    private readonly height: number;
    private mazeGrid: boolean[][] | null = null;
    
    constructor() {
        super();
        // ТОЧНО как в оригинале: iterations = размер лабиринта
        this.width = this.iterations;
        this.height = this.iterations;
        this.startX = 1;
        this.startY = 1;
        this.goalX = this.width - 2;
        this.goalY = this.height - 2;
    }
    
    private generateWalkableMaze(width: number, height: number): boolean[][] {
        // Используем MazeGenerator из maze_generator.ts
        // Он уже должен быть определен выше в файле
        return MazeGeneratorClass.generateWalkableMaze(width, height);
    }
    
    private ensureMazeGrid(): boolean[][] {
        if (!this.mazeGrid) {
            this.mazeGrid = this.generateWalkableMaze(this.width, this.height);
        }
        return this.mazeGrid;
    }
    
    private findPath(heuristic: Heuristic, allowDiagonal: boolean = false): [number, number][] | null {
        const grid = this.ensureMazeGrid();
        
        const gScores: number[][] = Array(this.height);
        const cameFrom: [number, number][][] = Array(this.height);
        for (let y = 0; y < this.height; y++) {
            gScores[y] = Array(this.width).fill(Number.MAX_SAFE_INTEGER);
            cameFrom[y] = Array(this.width).fill([-1, -1]);
        }
        
        const openSet = new AStarPathfinderBinaryHeap();
        
        gScores[this.startY][this.startX] = 0;
        openSet.push(new AStarPathfinderNode(this.startX, this.startY, 
                             heuristic.distance(this.startX, this.startY, this.goalX, this.goalY)));
        
        const directions: [number, number][] = allowDiagonal ? [
            [0, -1], [1, 0], [0, 1], [-1, 0],
            [-1, -1], [1, -1], [1, 1], [-1, 1]
        ] : [
            [0, -1], [1, 0], [0, 1], [-1, 0]
        ];
        
        const diagonalCost = allowDiagonal ? 1414 : 1000;
        
        while (!openSet.isEmpty()) {
            const current = openSet.pop()!;
            
            if (current.x === this.goalX && current.y === this.goalY) {
                const path: [number, number][] = [];
                let x = current.x;
                let y = current.y;
                
                while (x !== this.startX || y !== this.startY) {
                    path.push([x, y]);
                    const [prevX, prevY] = cameFrom[y][x];
                    x = prevX;
                    y = prevY;
                }
                
                path.push([this.startX, this.startY]);
                path.reverse();
                return path;
            }
            
            const currentG = gScores[current.y][current.x];
            
            for (const [dx, dy] of directions) {
                const nx = current.x + dx;
                const ny = current.y + dy;
                
                if (nx < 0 || nx >= this.width || ny < 0 || ny >= this.height) continue;
                if (!grid[ny][nx]) continue;
                
                const moveCost = (Math.abs(dx) === 1 && Math.abs(dy) === 1) ? diagonalCost : 1000;
                const tentativeG = currentG + moveCost;
                
                if (tentativeG < gScores[ny][nx]) {
                    cameFrom[ny][nx] = [current.x, current.y];
                    gScores[ny][nx] = tentativeG;
                    
                    const fScore = tentativeG + heuristic.distance(nx, ny, this.goalX, this.goalY);
                    openSet.push(new AStarPathfinderNode(nx, ny, fScore));
                }
            }
        }
        
        return null;
    }
    
    private estimateNodesExplored(heuristic: Heuristic, allowDiagonal: boolean = false): number {
        const grid = this.ensureMazeGrid();
        
        const gScores: number[][] = Array(this.height);
        for (let y = 0; y < this.height; y++) {
            gScores[y] = Array(this.width).fill(Number.MAX_SAFE_INTEGER);
        }
        
        const openSet = new AStarPathfinderBinaryHeap();
        const closed: boolean[][] = Array(this.height);
        for (let y = 0; y < this.height; y++) {
            closed[y] = Array(this.width).fill(false);
        }
        
        gScores[this.startY][this.startX] = 0;
        openSet.push(new AStarPathfinderNode(this.startX, this.startY, 
                             heuristic.distance(this.startX, this.startY, this.goalX, this.goalY)));
        
        const directions: [number, number][] = allowDiagonal ? [
            [0, -1], [1, 0], [0, 1], [-1, 0],
            [-1, -1], [1, -1], [1, 1], [-1, 1]
        ] : [
            [0, -1], [1, 0], [0, 1], [-1, 0]
        ];
        
        let nodesExplored = 0;
        
        while (!openSet.isEmpty()) {
            const current = openSet.pop()!;
            
            if (current.x === this.goalX && current.y === this.goalY) {
                break;
            }
            
            if (closed[current.y][current.x]) continue;
            
            closed[current.y][current.x] = true;
            nodesExplored++;
            
            const currentG = gScores[current.y][current.x];
            
            for (const [dx, dy] of directions) {
                const nx = current.x + dx;
                const ny = current.y + dy;
                
                if (nx < 0 || nx >= this.width || ny < 0 || ny >= this.height) continue;
                if (!grid[ny][nx]) continue;
                
                const moveCost = (Math.abs(dx) === 1 && Math.abs(dy) === 1) ? 1414 : 1000;
                const tentativeG = currentG + moveCost;
                
                if (tentativeG < gScores[ny][nx]) {
                    gScores[ny][nx] = tentativeG;
                    
                    const fScore = tentativeG + heuristic.distance(nx, ny, this.goalX, this.goalY);
                    openSet.push(new AStarPathfinderNode(nx, ny, fScore));
                }
            }
        }
        
        return nodesExplored;
    }
    
    private benchmarkDifferentApproaches(): [number, number, number] {
        const heuristics: Heuristic[] = [
            new ManhattanHeuristic(),
            new EuclideanHeuristic(),
            new ChebyshevHeuristic()
        ];
        
        let totalPathsFound = 0;
        let totalPathLength = 0;
        let totalNodesExplored = 0;
        
        for (const heuristic of heuristics) {
            const path = this.findPath(heuristic, false);
            if (path) {
                totalPathsFound++;
                totalPathLength += path.length;
                totalNodesExplored += this.estimateNodesExplored(heuristic, false);
            }
        }
        
        return [totalPathsFound, totalPathLength, totalNodesExplored];
    }
    
    prepare(): void {
        // Сбрасываем генератор для детерминизма
        Helper.reset();
        this.ensureMazeGrid();
    }
    
    run(): void {
        let totalPathsFound = 0;
        let totalPathLength = 0;
        let totalNodesExplored = 0;
        
        // ТОЧНО как в оригинале: 10 итераций
        const iters = 10;
        
        for (let i = 0; i < iters; i++) {
            // Сбрасываем лабиринт для каждой итерации
            this.mazeGrid = null;
            
            // ВАЖНО: Сбросить Helper для детерминизма
            Helper.reset();
            
            const [pathsFound, pathLength, nodesExplored] = this.benchmarkDifferentApproaches();
            
            totalPathsFound += pathsFound;
            totalPathLength += pathLength;
            totalNodesExplored += nodesExplored;
        }

        // Формула как в оригинале:
        // (checksumFloat(val1) >>> 0) ^ ((checksumFloat(val2) >>> 0) << 16) ^ ((checksumFloat(val3) >>> 0) << 32)
        const val1 = Helper.checksumFloat(totalPathsFound) >>> 0;
        const val2 = Helper.checksumFloat(totalPathLength) >>> 0;
        const val3 = Helper.checksumFloat(totalNodesExplored) >>> 0;
        
        const bigResult = BigInt(val1) ^ (BigInt(val2) << 16n) ^ (BigInt(val3) << 32n);

        // Конвертируем в signed 64-bit как в оригинале
        this.resultVal = BigInt.asIntN(64, bigResult);
    }
    
    getResult(): bigint {
        return this.resultVal;
    }
}

// =========== ./benchmarks/nbody.ts ===========

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
    x: number, y: number, z: number,
    vx: number, vy: number, vz: number,
    mass: number
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
      4.84143144246472090e+00,
      -1.16032004402742839e+00,
      -1.03622044471123109e-01,
      1.66007664274403694e-03,
      7.69901118419740425e-03,
      -6.90460016972063023e-05,
      9.54791938424326609e-04),

    new Planet(
      8.34336671824457987e+00,
      4.12479856412430479e+00,
      -4.03523417114321381e-01,
      -2.76742510726862411e-03,
      4.99852801234917238e-03,
      2.30417297573763929e-05,
      2.85885980666130812e-04),

    new Planet(
      1.28943695621391310e+01,
      -1.51111514016986312e+01,
      -2.23307578892655734e-01,
      2.96460137564761618e-03,
      2.37847173959480950e-03,
      -2.96589568540237556e-05,
      4.36624404335156298e-05),

    new Planet(
      1.53796971148509165e+01,
      -2.59193146099879641e+01,
      1.79258772950371181e-01,
      2.68067772490389322e-03,
      1.62824170038242295e-03,
      -9.51592254519715870e-05,
      5.15138902046611451e-05),
  ];

  private n: number;
  private bodies: Planet[];
  private resultValue: bigint = 0n;

  constructor() {
    super();
    this.n = this.iterations;
    this.bodies = Nbody.BODIES.map(p => {
      return new Planet(p.x, p.y, p.z, 
        p.vx / DAYS_PER_YEAR,
        p.vy / DAYS_PER_YEAR,
        p.vz / DAYS_PER_YEAR,
        p.mass / SOLAR_MASS);
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

  run(): void {
    this.offsetMomentum(this.bodies);

    const v1 = this.energy(this.bodies);
    const nbodies = this.bodies.length;
    const dt = 0.01;

    for (let count = 0; count < this.n; count++) {
      let i = 0;
      while (i < nbodies) {
        const b = this.bodies[i];
        b.moveFromI(this.bodies, nbodies, dt, i + 1);
        i++;
      }
    }

    const v2 = this.energy(this.bodies);
    const checksum1 = Helper.checksumFloat(v1);
    const checksum2 = Helper.checksumFloat(v2);
    
    this.resultValue = BigInt((checksum1 << 5) & checksum2);
  }

  getResult(): bigint {
    return this.resultValue;
  }
}

// =========== ./benchmarks/neural-net.ts ===========

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
      synapse.weight += (rate * NeuralNetNeuron.LEARNING_RATE * this.error * synapse.sourceNeuron.output) +
                       (NeuralNetNeuron.MOMENTUM * (synapse.weight - synapse.prevWeight));
      synapse.prevWeight = tempWeight;
    }

    const tempThreshold = this.threshold;
    this.threshold += (rate * NeuralNetNeuron.LEARNING_RATE * this.error * -1) +
                     (NeuralNetNeuron.MOMENTUM * (this.threshold - this.prevThreshold));
    this.prevThreshold = tempThreshold;
  }
}

class NeuralNetNetwork {
  private inputLayer: NeuralNetNeuron[];
  private hiddenLayer: NeuralNetNeuron[];
  private outputLayer: NeuralNetNeuron[];

  constructor(inputs: number, hidden: number, outputs: number) {
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
    return this.outputLayer.map(neuron => neuron.output);
  }
}

export class NeuralNet extends Benchmark {
  private n: number;
  private results: number[] = [];
  private resultValue: bigint = 0n;

  constructor() {
    super();
    this.n = this.iterations;
  }

  run(): void {
    const xor = new NeuralNetNetwork(2, 10, 1);

    for (let i = 0; i < this.n; i++) {
      xor.train([0, 0], [0]);
      xor.train([1, 0], [1]);
      xor.train([0, 1], [1]);
      xor.train([1, 1], [0]);
    }

    xor.feedForward([0, 0]);
    this.results.push(...xor.currentOutputs());
    
    xor.feedForward([0, 1]);
    this.results.push(...xor.currentOutputs());
    
    xor.feedForward([1, 0]);
    this.results.push(...xor.currentOutputs());
    
    xor.feedForward([1, 1]);
    this.results.push(...xor.currentOutputs());

    const sum = this.results.reduce((a, b) => a + b, 0);
    this.resultValue = BigInt(Helper.checksumFloat(sum));
  }

  getResult(): bigint {
    return this.resultValue;
  }
}

// =========== ./benchmarks/noise.ts ===========

class NoiseVec2 {
  constructor(
    public x: number,
    public y: number
  ) {}
}

class Noise2DContext {
  private static readonly SIZE = 64;
  private static readonly MASK = Noise2DContext.SIZE - 1;
  
  private rgradients: NoiseVec2[];
  private permutations: number[];

  constructor() {
    this.rgradients = new Array(Noise2DContext.SIZE);
    for (let i = 0; i < Noise2DContext.SIZE; i++) {
      const v = Helper.nextFloat() * Math.PI * 2.0;
      this.rgradients[i] = new NoiseVec2(Math.cos(v), Math.sin(v));
    }

    this.permutations = new Array(Noise2DContext.SIZE);
    for (let i = 0; i < Noise2DContext.SIZE; i++) {
      this.permutations[i] = i;
    }
    
    const size = Noise2DContext.SIZE;
    const perm = this.permutations;
    for (let i = 0; i < size; i++) {
      const a = Helper.nextInt(size);
      const b = Helper.nextInt(size);
      const temp = perm[a];
      perm[a] = perm[b];
      perm[b] = temp;
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
    const idx = this.permutations[x & Noise2DContext.MASK] + 
                this.permutations[y & Noise2DContext.MASK];
    return this.rgradients[idx & Noise2DContext.MASK];
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
      this.getGradient(x0 + 1, y0 + 1)
    ];

    const origins = [
      new NoiseVec2(x0f + 0.0, y0f + 0.0),
      new NoiseVec2(x0f + 1.0, y0f + 0.0),
      new NoiseVec2(x0f + 0.0, y0f + 1.0),
      new NoiseVec2(x0f + 1.0, y0f + 1.0)
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
  private static readonly SIZE = 64;
  private static readonly SYM = [' ', '░', '▒', '▓', '█', '█'];
  
  private n: number;
  private result: bigint = 0n;

  constructor() {
    super();
    this.n = this.iterations;
  }

  private noise(): bigint {
    const SIZE = Noise.SIZE;
    const pixels = new Float64Array(SIZE * SIZE);
    const n2d = new Noise2DContext();
    
    for (let i = 0; i < 100; i++) {
      const offset = i * 128;
      for (let y = 0; y < SIZE; y++) {
        const yy = (y + offset) * 0.1;
        const baseIdx = y * SIZE;
        for (let x = 0; x < SIZE; x++) {
          const v = n2d.get(x * 0.1, yy) * 0.5 + 0.5;
          pixels[baseIdx + x] = v;
        }
      }
    }
    
    let res = 0n;
    const SYM = Noise.SYM;
    const symLen = SYM.length - 1;
    
    for (let i = 0; i < pixels.length; i++) {
      const v = pixels[i];
      const idx = Math.floor(v / 0.2);
      const charIdx = idx < 0 ? 0 : (idx > symLen ? symLen : idx);
      res += BigInt(SYM[charIdx].charCodeAt(0));
    }
    
    return res;
  }

  run(): void {
    for (let i = 0; i < this.n; i++) {
      const v = this.noise();
      this.result += v;
      this.result &= 0xFFFFFFFFFFFFFFFFn;
    }
  }

  getResult(): bigint {
    return this.result;
  }
}

// =========== ./benchmarks/pidigits.ts ===========

export class Pidigits extends Benchmark {
  private nn: number;
  private resultBuffer: string[] = [];
  private resultStr: string = '';

  constructor() {
    super();
    this.nn = this.iterations;
  }

  run(): void {
    this.resultBuffer = [];
    
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
            const line = ns.toString().padStart(10, '0') + `\t:${i}\n`;
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
      const line = ns.toString().padStart(remainingDigits, '0') + `\t:${i}\n`;
      this.resultBuffer.push(line);
    }
    
    this.resultStr = this.resultBuffer.join('');
  }

  getResult(): bigint {
    return BigInt(Helper.checksumString(this.resultStr));
  }
}

// =========== ./benchmarks/primes.ts ===========

class PrimesNode {
  children: (PrimesNode | null)[] = new Array(10).fill(null);
  terminal: boolean = false;
}

export class Primes extends Benchmark {
  private static readonly PREFIX = 32338;
  
  private n: number;
  private resultValue: bigint = 0n;

  constructor() {
    super();
    this.n = this.iterations;
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
    
    // Разумная оценка размера
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
        const digit = str.charCodeAt(i) - 48; // '0' = 48
        
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
    
    // BFS как в C++ версии
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

  run(): void {
    // 1. Генерация простых чисел (как в C++)
    const primes = this.generatePrimes(this.n);
    
    // 2. Построение префиксного дерева (как в C++)
    const trie = this.buildTrie(primes);
    
    // 3. Поиск по префиксу (как в C++)
    const found = this.findPrimesWithPrefix(trie, Primes.PREFIX);
    
    // 4. Вычисление результата в том же порядке
    let temp = 5432;
    
    // Сначала добавляем размер (как в C++)
    temp = (temp + found.length) >>> 0;
    
    // Затем добавляем все числа (как в C++)
    for (const num of found) {
      temp = (temp + num) >>> 0;
    }
    
    this.resultValue = BigInt(temp);
  }

  getResult(): bigint {
    return this.resultValue;
  }
}

// =========== ./benchmarks/regexdna.ts ===========

export class RegexDna extends Benchmark {
  private seq: string = '';
  private ilen: number = 0;
  private clen: number = 0;
  private resultStr: string = '';

  prepare(): void {
      const n = this.iterations;

      const fasta = new Fasta();
      fasta.n = n;
      fasta.prepare();
      fasta.run();
      
      const fastaOutput = fasta.resultStr;
      
      let seq = '';
      let totalBytes = 0;
      
      const lines = fastaOutput.split('\n');
      for (let i = 0; i < lines.length; i++) {
          const line = lines[i];
          
          const lineBytes = new TextEncoder().encode(line).length;
          
          if (i < lines.length - 1) {
              totalBytes += lineBytes + 1;
          } else if (line.length > 0) {
              totalBytes += lineBytes;
          } else {
          }
          
          if (!line.startsWith('>')) {
              seq += line.trim();
          }
      }
      
      totalBytes = new TextEncoder().encode(fastaOutput).length;
      
      this.seq = seq;
      this.ilen = totalBytes;
      this.clen = new TextEncoder().encode(seq).length;
  }

  run(): void {
    this.resultStr = '';
    
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
      "B": "(c|g|t)",
      "D": "(a|g|t)",
      "H": "(a|c|t)",
      "K": "(g|t)",
      "M": "(a|c)",
      "N": "(a|c|g|t)",
      "R": "(a|g)",
      "S": "(c|t)",
      "V": "(a|c|g)",
      "W": "(a|t)",
      "Y": "(c|t)",
    };

    let modifiedSeq = this.seq;
    for (const [key, value] of Object.entries(replacements)) {
      const regex = new RegExp(key, 'gi');
      const before = modifiedSeq.length;
      modifiedSeq = modifiedSeq.replace(regex, value);
    }
    
    this.resultStr += `\n${this.ilen}\n${this.clen}\n${modifiedSeq.length}\n`;
  }

  getResult(): bigint {
    return BigInt(Helper.checksumString(this.resultStr));
  }
}

// =========== ./benchmarks/revcomp.ts ===========

export class Revcomp extends Benchmark {
  private input: string = '';
  private resultStr: string = '';

  prepare(): void {
    const n = this.iterations;
    
    const fasta = new Fasta();
    fasta.n = n;
    fasta.prepare();
    fasta.run();
    
    this.input = fasta.resultStr;
  }

  private revcomp(seq: string): string {
    const reversed = seq.split('').reverse().join('');
    
    const from = "wsatugcyrkmbdhvnATUGCYRKMBDHVN";
    const to   = "WSTAACGRYMKVHDBNTAACGRYMKVHDBN";
    
    const lookup: string[] = new Array(256);
    for (let i = 0; i < 256; i++) {
        lookup[i] = String.fromCharCode(i);
    }
    for (let i = 0; i < from.length; i++) {
        const charCode = from.charCodeAt(i);
        if (charCode < 256) {
            lookup[charCode] = to[i];
        }
    }
    
    let translated = '';
    for (let i = 0; i < reversed.length; i++) {
        const charCode = reversed.charCodeAt(i);
        translated += lookup[charCode] || reversed[i];
    }
    
    const lineLength = 60;
    let result = '';
    for (let i = 0; i < translated.length; i += lineLength) {
        const end = Math.min(i + lineLength, translated.length);
        result += translated.substring(i, end) + '\n';
    }
    
    return result;
  }

  run(): void {
    this.resultStr = '';
    
    let currentSeq = '';
    const lines = this.input.split(/\r?\n/);
    
    for (let i = 0; i < lines.length; i++) {
        const line = lines[i];
        
        if (line.startsWith('>')) {
            if (currentSeq.length > 0) {
                const revcompResult = this.revcomp(currentSeq);
                this.resultStr += revcompResult;
                currentSeq = '';
            }
            this.resultStr += line + '\n';
        } else {
            currentSeq += line;
        }
    }
    
    if (currentSeq.length > 0) {
        this.resultStr += this.revcomp(currentSeq);
    }
  }

  getResult(): bigint {
    const checksum = Helper.checksumString(this.resultStr);
    return BigInt(checksum);
  }
}

// =========== ./benchmarks/sort-benchmark.ts ===========

export abstract class SortBenchmark extends Benchmark {
  protected static readonly ARR_SIZE = 100000;
  
  protected data: number[] = [];
  protected n: number;
  protected resultValue: bigint = 0n;

  constructor() {
    super();
    this.n = this.iterations;
  }

  prepare(): void {
    Helper.reset();
    this.data = [];
    for (let i = 0; i < SortBenchmark.ARR_SIZE; i++) {
      this.data.push(Helper.nextInt(1000000));
    }
  }

  abstract test(): number[];

  protected checkNElements(arr: number[], n: number): string {
    const step = Math.floor(arr.length / n);
    let result = '[';
    
    for (let i = 0; i < arr.length; i += step) {
      result += `${i}:${arr[i]},`;
    }
    
    result += ']\n';
    return result;
  }

  run(): void {
    let verify = this.checkNElements(this.data, 10);

    for (let i = 0; i < this.n - 1; i++) {
      const t = this.test();
      const mid = Math.floor(t.length / 2);
      this.resultValue = (this.resultValue + BigInt(t[mid])) & 0xFFFFFFFFn;
    }

    const arr = this.test();
    
    verify += this.checkNElements(this.data, 10);
    verify += this.checkNElements(arr, 10);
    
    const checksum = Helper.checksumString(verify);
    this.resultValue = (this.resultValue + BigInt(checksum)) & 0xFFFFFFFFn;
  }

  getResult(): bigint {
    return this.resultValue;
  }
}

// =========== ./benchmarks/sort-merge.ts ===========

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

  private mergeSortHelper(arr: number[], temp: number[], left: number, right: number): void {
    if (left >= right) return;

    const mid = Math.floor((left + right) / 2);
    this.mergeSortHelper(arr, temp, left, mid);
    this.mergeSortHelper(arr, temp, mid + 1, right);
    this.merge(arr, temp, left, mid, right);
  }

  private merge(arr: number[], temp: number[], left: number, mid: number, right: number): void {
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
}

// =========== ./benchmarks/sort-quick.ts ===========

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
}

// =========== ./benchmarks/sort-self.ts ===========

export class SortSelf extends SortBenchmark {
  test(): number[] {
    const arr = [...this.data];
    arr.sort((a, b) => a - b);
    return arr;
  }
}

// =========== ./benchmarks/spectralnorm.ts ===========

export class Spectralnorm extends Benchmark {
  private n: number;
  private resultValue: bigint = 0n;

  constructor() {
    super();
    this.n = this.iterations;
  }

  private evalA(i: number, j: number): number {
    return 1.0 / ((i + j) * (i + j + 1) / 2.0 + i + 1.0);
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

  run(): void {
    let u: number[] = new Array(this.n).fill(1.0);
    let v: number[] = new Array(this.n).fill(1.0);
    
    for (let iter = 0; iter < 10; iter++) {
      v = this.evalAtATimesU(u);
      u = this.evalAtATimesU(v);
    }
    
    let vBv = 0.0;
    let vv = 0.0;
    
    for (let i = 0; i < this.n; i++) {
      vBv += u[i] * v[i];
      vv += v[i] * v[i];
    }
    
    const result = Math.sqrt(vBv / vv);
    this.resultValue = BigInt(Helper.checksumFloat(result));
  }

  getResult(): bigint {
    return this.resultValue;
  }
}

// =========== ./benchmarks/text-raytracer.ts ===========

class TextRaytracerVector {
  constructor(
    public x: number,
    public y: number,
    public z: number
  ) {}

  scale(s: number): TextRaytracerVector {
    return new TextRaytracerVector(this.x * s, this.y * s, this.z * s);
  }

  add(other: TextRaytracerVector): TextRaytracerVector {
    return new TextRaytracerVector(this.x + other.x, this.y + other.y, this.z + other.z);
  }

  subtract(other: TextRaytracerVector): TextRaytracerVector {
    return new TextRaytracerVector(this.x - other.x, this.y - other.y, this.z - other.z);
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
    public dir: TextRaytracerVector
  ) {}
}

class TextRaytracerColor {
  constructor(
    public r: number,
    public g: number,
    public b: number
  ) {}

  scale(s: number): TextRaytracerColor {
    return new TextRaytracerColor(this.r * s, this.g * s, this.b * s);
  }

  add(other: TextRaytracerColor): TextRaytracerColor {
    return new TextRaytracerColor(this.r + other.r, this.g + other.g, this.b + other.b);
  }
}

class TextRaytracerSphere {
  constructor(
    public center: TextRaytracerVector,
    public radius: number,
    public color: TextRaytracerColor
  ) {}

  getNormal(pt: TextRaytracerVector): TextRaytracerVector {
    return pt.subtract(this.center).normalize();
  }
}

class TextRaytracerLight {
  constructor(
    public position: TextRaytracerVector,
    public color: TextRaytracerColor
  ) {}
}

class TextRaytracerHit {
  constructor(
    public obj: TextRaytracerSphere,
    public value: number
  ) {}
}

export class TextRaytracer extends Benchmark {
  private static readonly WHITE = new TextRaytracerColor(1.0, 1.0, 1.0);
  private static readonly RED = new TextRaytracerColor(1.0, 0.0, 0.0);
  private static readonly GREEN = new TextRaytracerColor(0.0, 1.0, 0.0);
  private static readonly BLUE = new TextRaytracerColor(0.0, 0.0, 1.0);
  
  private static readonly LIGHT1 = new TextRaytracerLight(
    new TextRaytracerVector(0.7, -1.0, 1.7),
    TextRaytracer.WHITE
  );
  
  private static readonly SCENE: TextRaytracerSphere[] = [
    new TextRaytracerSphere(new TextRaytracerVector(-1.0, 0.0, 3.0), 0.3, TextRaytracer.RED),
    new TextRaytracerSphere(new TextRaytracerVector(0.0, 0.0, 3.0), 0.8, TextRaytracer.GREEN),
    new TextRaytracerSphere(new TextRaytracerVector(1.0, 0.0, 3.0), 0.4, TextRaytracer.BLUE),
  ];
  
  private static readonly LUT = ['.', '-', '+', '*', 'X', 'M'];
  
  private w: number;
  private h: number;
  private resultValue: bigint = 0n;

  constructor() {
    super();
    this.w = this.iterations;
    this.h = this.iterations;
  }

  private shadePixel(ray: TextRaytracerRay, obj: TextRaytracerSphere, tval: number): number {
    const pi = ray.orig.add(ray.dir.scale(tval));
    const color = this.diffuseShading(pi, obj, TextRaytracer.LIGHT1);
    const col = (color.r + color.g + color.b) / 3.0;
    return Math.floor(col * 6.0);
  }

  private intersectSphere(ray: TextRaytracerRay, center: TextRaytracerVector, radius: number): number | null {
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

  private diffuseShading(pi: TextRaytracerVector, obj: TextRaytracerSphere, light: TextRaytracerLight): TextRaytracerColor {
    const n = obj.getNormal(pi);
    const lam1 = light.position.subtract(pi).normalize().dot(n);
    const lam2 = this.clamp(lam1, 0.0, 1.0);
    return light.color.scale(lam2 * 0.5).add(obj.color.scale(0.3));
  }

  run(): void {
    let res = 0n;
    const fw = this.w;
    const fh = this.h;

    for (let j = 0; j < this.h; j++) {
      for (let i = 0; i < this.w; i++) {
        const ray = new TextRaytracerRay(
          new TextRaytracerVector(0.0, 0.0, 0.0),
          new TextRaytracerVector(
            (i - fw / 2.0) / fw,
            (j - fh / 2.0) / fh,
            1.0
          ).normalize()
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
          pixel = TextRaytracer.LUT[Math.min(shadeIdx, TextRaytracer.LUT.length - 1)];
        } else {
          pixel = ' ';
        }

        res += BigInt(pixel.charCodeAt(0));
        res &= 0xFFFFFFFFFFFFFFFFn;
      }
    }
    
    this.resultValue = res;
  }

  getResult(): bigint {
    return this.resultValue;
  }
}

// =========== РЕГИСТРАЦИЯ ВСЕХ БЕНЧМАРКОВ ===========

Benchmark.registerBenchmark(Pidigits);
Benchmark.registerBenchmark(Binarytrees);
Benchmark.registerBenchmark(BrainfuckHashMap);
Benchmark.registerBenchmark(BrainfuckRecursion);
Benchmark.registerBenchmark(Fannkuchredux);
Benchmark.registerBenchmark(Fasta);
Benchmark.registerBenchmark(Knuckeotide);
Benchmark.registerBenchmark(Mandelbrot);
Benchmark.registerBenchmark(Matmul);
Benchmark.registerBenchmark(Matmul4T);
Benchmark.registerBenchmark(Matmul8T);
Benchmark.registerBenchmark(Matmul16T);
Benchmark.registerBenchmark(Nbody);
Benchmark.registerBenchmark(RegexDna);
Benchmark.registerBenchmark(Revcomp);
Benchmark.registerBenchmark(Spectralnorm);
Benchmark.registerBenchmark(Base64Encode);
Benchmark.registerBenchmark(Base64Decode);
Benchmark.registerBenchmark(Primes);
Benchmark.registerBenchmark(JsonGenerate);
Benchmark.registerBenchmark(JsonParseDom);
Benchmark.registerBenchmark(JsonParseMapping);
Benchmark.registerBenchmark(Noise);
Benchmark.registerBenchmark(TextRaytracer);
Benchmark.registerBenchmark(NeuralNet);
Benchmark.registerBenchmark(SortQuick);
Benchmark.registerBenchmark(SortMerge);
Benchmark.registerBenchmark(SortSelf);
Benchmark.registerBenchmark(GraphPathBFS);
Benchmark.registerBenchmark(GraphPathDFS);
Benchmark.registerBenchmark(GraphPathDijkstra);
Benchmark.registerBenchmark(BufferHashSHA256);
Benchmark.registerBenchmark(BufferHashCRC32);
Benchmark.registerBenchmark(CacheSimulation);
Benchmark.registerBenchmark(CalculatorAst);
Benchmark.registerBenchmark(CalculatorInterpreter);
Benchmark.registerBenchmark(GameOfLife);
Benchmark.registerBenchmark(MazeGenerator);
Benchmark.registerBenchmark(AStarPathfinder);
Benchmark.registerBenchmark(Compression);

// ===========

// =========== ЗАПУСК ===========

(async () => {
    try {
        await writeFileUniversal('/tmp/recompile_marker', 'RECOMPILE_MARKER_0');
    } catch (error) {
    }
})();

// Просто запускаем main
try {
  main().catch(console.error);
} catch (error) {
  console.error('Failed to run benchmarks:', error);
  process.exit(1);
}
