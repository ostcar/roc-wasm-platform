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

function send_string(memory, allocater, str) {
  const message = new TextEncoder().encode(JSON.stringify(str));
  const pointer = allocater(message.length);
  const slice = new Uint8Array(memory.buffer, pointer,message.length);
  slice.set(message);
  return {pointer: pointer, length: message.length};
}

function do_effect(print, memory, name_pointer, name2_pointer, argument_pointer) {
  const name_slice = new Uint32Array(memory.buffer, name_pointer, 3);
  const name = decodeZeroTerminatedString(memory, name_slice[0]);

  const argument_slice = new Uint32Array(memory.buffer, argument_pointer, 3);
  const argument = decodeZeroTerminatedString(memory, argument_slice[0]);

  switch (name) {
    case "print_str":
      console.log("Printing: ", argument);
      print(argument);
      break
    default:
      console.log("unknown Effect: ", name)
  }
}

async function load_wasm(wasm_file) {
  let memory = undefined;
  let out_callback = undefined;

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
      roc_fx_doEffect: (name, name2, argument) => {
        return do_effect(out_callback, memory, name, name2, argument);
      }
    },
  };

  const  wasm = await WebAssembly.instantiateStreaming(fetch(wasm_file), importObj);
  
  memory = wasm.instance.exports.memory;
  const allocater = wasm.instance.exports.allocUint8;
  const run_roc = wasm.instance.exports.run_roc;
  const run_callback = wasm.instance.exports.run_callback;

  return function (input1, input2, callback) {
    try {
      out_callback = callback;
      const message1 = send_string(memory, allocater, input1)
      const message2 = send_string(memory, allocater, input2)

      // Call the roc code
      run_roc(message1.pointer, message1.length);
      return;

    } catch (e) {
      const is_ok = e.message === "unreachable" && exit_code === 0;
      if (!is_ok) {
        console.error(e);
      }
      
    } finally {
      out_callback = undefined;
    }
  }
}

if (typeof module !== "undefined") {
  module.exports = {
    load_wasm,
  };
}
