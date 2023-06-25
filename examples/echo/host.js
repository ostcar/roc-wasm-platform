async function roc_web_platform_run(wasm_filename, input, callback) {
  let exit_code;

  const importObj = {
    wasi_snapshot_preview1: {
      proc_exit: (code) => {
        if (code !== 0) {
          console.error(`Exited with code ${code}`);
        }
        exit_code = code;
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

  const fetchPromise = fetch(wasm_filename);

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

  try {
    // Encode the input message as json
    const message = new TextEncoder().encode(JSON.stringify(input));
    
    // Allocate enough memory in wasm
    const in_pointer = wasm.instance.exports.allocUint8(message.length);

    // Init the wasm memory
    const memory_bytes = new Uint8Array(wasm.instance.exports.memory.buffer);

    // Write the encoded input to the wasm memory
    memory_bytes.set(message, in_pointer);
  
    // Call the roc code
    const out_pointer = wasm.instance.exports.run_roc(in_pointer, message.length);
    
    // Find the end of the roc return value (the first 0 byte)
    let stop;
    for (stop = out_pointer; memory_bytes[stop] != 0; stop++) ;

    // Decode the roc value
    let result = JSON.parse(new TextDecoder().decode(memory_bytes.slice(out_pointer, stop)));

    callback(result);

  } catch (e) {
    const is_ok = e.message === "unreachable" && exit_code === 0;
    if (!is_ok) {
      console.error(e);
    }
  }
}

if (typeof module !== "undefined") {
  module.exports = {
    roc_web_platform_run,
  };
}
