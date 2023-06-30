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

  const fetchPromise = fetch(file);

  let wasm;
  if (WebAssembly.instantiateStreaming) {
    // streaming API has better performance if available
    // It can start compiling Wasm before it has fetched all of the bytes, so we don't `await` the request!
    wasm = await WebAssembly.instantiateStreaming(fetchPromise, importObj);
  } else {
    const response = await fetchPromise;
    const module_bytes = await response.arrayBuffer();
    wasm = await WebAssembly.instantiate(module_bytes, importObj);
  }

  return async function (input1, input2, callback) {
    try {
      // Encode the input message as json
      const message1 = new TextEncoder().encode(JSON.stringify(input1));
      const message2 = new TextEncoder().encode(JSON.stringify(input2));

      // Allocate enough memory in wasm
      const in_pointer1 = wasm.instance.exports.allocUint8(message1.length);
      const in_pointer2 = wasm.instance.exports.allocUint8(message2.length);

      // Init the wasm memory
      const memory_bytes = new Uint8Array(wasm.instance.exports.memory.buffer);

      // Write the encoded input to the wasm memory
      memory_bytes.set(message1, in_pointer1);
      memory_bytes.set(message2, in_pointer2);

      // Call the roc code
      const callback_pointer = wasm.instance.exports.run_roc(in_pointer1, message1.length);
      console.log(callback_pointer);
      console.log(memory_bytes);
      const out_pointer = wasm.instance.exports.callback(callback_pointer, in_pointer2, message2.length);

      // Find the end of the roc return value (the first 0 byte)
      let stop;
      for (stop = out_pointer; memory_bytes[stop] != 0; stop++);

      // Decode the roc value
      const result = JSON.parse(new TextDecoder().decode(memory_bytes.slice(out_pointer, stop)));

      callback(result);

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
