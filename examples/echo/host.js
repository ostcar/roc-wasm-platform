function decodeZeroTerminatedString(memory, pointer) {
  // TODO: Use something like: https://github.com/Pyrolistical/typescript-wasm-zig/blob/9ba1f26a24fcf97a4f18257efa82e6b6fceb0be0/index.ts#L33
  const memorySlice = new Uint8Array(memory.buffer, pointer);
  let stop;
  for (stop = 0; memorySlice[stop] != 0 && stop < 1000; stop++);
  const decoded =new TextDecoder().decode(memorySlice.slice(0, stop));
  if (decoded.length == 0) {
    throw "empty string";
  }
  return JSON.parse(decoded);
}

function decodeJob(memory, jobPointer) {
  try {
    const jobSlice = new Uint32Array(memory.buffer, jobPointer,3);

    return {
      callback: jobSlice[0], 
      name: decodeZeroTerminatedString(memory, jobSlice[1]),
      value: decodeZeroTerminatedString(memory, jobSlice[2]),
    };

  } finally {
    // deallocate memory in zig
  }
}

function send_string(memory, allocater, str) {
  const message = new TextEncoder().encode(JSON.stringify(str));
  const pointer = allocater(message.length);
  const slice = new Uint8Array(memory.buffer, pointer,message.length);
  slice.set(message);
  return {pointer: pointer, length: message.length};
}

async function load_wasm(wasm_file) {
  const importObj = {
    // TODO: Why do I have to define this?
    wasi_snapshot_preview1: {
      proc_exit: (code) => {
        if (code !== 0) {
          console.error(`Exited with code ${code}`);
        }
      },
      fd_write: (x) => {
        console.error(`fd_write not supported: ${x}`);
      },
    },
    env: {
      roc_panic: (_pointer, _tag_id) => {
        throw "Roc panicked!";
      },
    },
  };

  const  wasm = await WebAssembly.instantiateStreaming(fetch(wasm_file), importObj);
  
  const memory = wasm.instance.exports.memory;
  const allocater = wasm.instance.exports.allocUint8;
  const run_roc = wasm.instance.exports.run_roc;
  const run_callback = wasm.instance.exports.run_callback;

  return function (input1, input2) {
    try {
      const message1 = send_string(memory, allocater, input1)
      const message2 = send_string(memory, allocater, input2)

      // Call the roc code
      const pointer_from_run_roc = run_roc(message1.pointer, message1.length);
      const job = decodeJob(memory, pointer_from_run_roc);
      //console.log(job.name);
      //console.log(job.value);

      // Call the roc callback
      const pointer_from_callback = run_callback(job.callback, message2.pointer, message2.length);

      const result = decodeZeroTerminatedString(memory, pointer_from_callback);

      return result;

    } catch (e) {
      const is_ok = e.message === "unreachable" && exit_code === 0;
      if (!is_ok) {
        console.error(e);
      }
    }
  }
}

if (typeof module !== "undefined") {
  module.exports = {
    load_wasm,
  };
}
