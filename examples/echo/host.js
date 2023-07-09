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
    const jobSlice = new Uint32Array(memory.buffer, jobPointer,2);

    return {
      callback: jobSlice[0], 
      value: decodeZeroTerminatedString(memory,jobSlice[1]),
    };

  } finally {
    // deallocate memory in zig
  }
}

async function load_wasm(file) {
  const importObj = {
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


  const  wasm = await WebAssembly.instantiateStreaming(fetch(file), importObj);


  return function (input1, input2, callback) {
    try {
      // Encode the input message as json
      const message1 = new TextEncoder().encode(JSON.stringify(input1));
      const message2 = new TextEncoder().encode(JSON.stringify(input2));

      // Allocate enough memory in wasm
      const in_pointer1 = wasm.instance.exports.allocUint8(message1.length);
      const in_pointer2 = wasm.instance.exports.allocUint8(message2.length);

      //const test_value = wasm.instance.exports.test_fn();

      // Init the wasm memory
      const memory = new Uint8Array(wasm.instance.exports.memory.buffer);

      // Write the encoded input to the wasm memory
      memory.set(message1, in_pointer1);
      memory.set(message2, in_pointer2);



      // Call the roc code
      const job_pointer = wasm.instance.exports.run_roc(in_pointer1, message1.length);
      const job = decodeJob(wasm.instance.exports.memory, job_pointer);
      console.log(job_pointer);
      console.log(job.callback);
      console.log(memory)
      console.log(job.value);

      const out_pointer = wasm.instance.exports.run_callback(job.callback, in_pointer2, message2.length);
      //const out_pointer = wasm.instance.exports.run_callback(job.callback, in_pointer2, message2.length);

      const result = decodeZeroTerminatedString(wasm.instance.exports.memory, out_pointer);

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
