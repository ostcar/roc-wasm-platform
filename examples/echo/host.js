async function roc_web_platform_run(wasm_filename, callback) {
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
    let message = JSON.stringify({input: "hello world"});
    console.log(message);

    let in_pointer = wasm.instance.exports.allocUint8(message.length);
    const out_pointer = wasm.instance.exports.run_roc(in_pointer, message.length);
    let memory_bytes = new Uint8Array(wasm.instance.exports.memory.buffer);

    let utf8_bytes = "";
    for (let i = out_pointer; memory_bytes[i] != 0 && i < out_pointer+100; i++) {
      utf8_bytes += String.fromCharCode(memory_bytes[i]);
    }

    const js_string = JSON.parse(utf8_bytes);

    callback(js_string)

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
