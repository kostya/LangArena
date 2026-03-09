import { readFile } from 'node:fs/promises';
import { WASI } from 'node:wasi';
import { argv, env } from 'node:process';

const wasmArgs = ['dummy', ...argv.slice(2)];

const wasi = new WASI({
  version: 'preview1',
  args: wasmArgs,
  env,
  preopens: {
    '.': '.',
    '..': '..', 
  },
});

const wasmBuffer = await readFile('target/bin_main.wasm');
const wasmModule = await WebAssembly.compile(wasmBuffer);

const importObject = {
  wasi_snapshot_preview1: wasi.wasiImport,
};

const instance = await WebAssembly.instantiate(wasmModule, importObject);
wasi.start(instance);