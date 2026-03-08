import { readFile } from 'node:fs/promises';
import { WASI } from 'node:wasi';
import { argv, env } from 'node:process';

const wasmArgs = argv.slice(2);
if (wasmArgs.length === 0 || !wasmArgs[0].startsWith('dummy')) {
  wasmArgs.unshift('dummy');
}

const wasi = new WASI({
  version: 'preview1',
  args: wasmArgs,
  env,
  preopens: {
    '.': '.',
  },
});

const wasmBuffer = await readFile('target/wasm32-wasip1/release/benchmarks-opt.wasm');
const wasmModule = await WebAssembly.compile(wasmBuffer);

const importObject = {
  wasi_snapshot_preview1: wasi.wasiImport,
};

const instance = await WebAssembly.instantiate(wasmModule, importObject);
wasi.start(instance);