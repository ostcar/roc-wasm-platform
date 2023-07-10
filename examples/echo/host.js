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

function print_memory(memory) {
  console.log(new Uint8Array(memory.buffer))
}


async function load_wasm(wasm_file) {
  let memory = undefined;
  let allocater = undefined;
  let print_str_callback = undefined;
  let read_str_callback = undefined;

  function do_effect(name_pointer,  arg_pointer) {
    const name_slice = new Uint32Array(memory.buffer, name_pointer, 3);
    const name = decodeZeroTerminatedString(memory, name_slice[0]);
  
    let return_value;
    switch (name) {
      case "print_str":
        const argument_slice = new Uint32Array(memory.buffer, arg_pointer, 3);
        const argument = decodeZeroTerminatedString(memory, argument_slice[0]);
  
        print_str_callback(argument);
        return "foobar"
  
      case "read_str":
        return read_str_callback();
  
      default:
        console.log("unknown Effect: ", name)
        return "unknown effect"
    }
  }

  const importObj = {
    // TODO: Why do I have to define this?
    // Can probably be removed when this is fixed: https://github.com/roc-lang/roc/issues/5585
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
      roc_fx_doEffect: (output_pointer, name_pointer, argument_pointer) => {
        const value = do_effect(name_pointer, argument_pointer);

        const send_data = send_string(memory, allocater, value);
        const out_slice = new Uint32Array(memory.buffer, output_pointer, 3);
        out_slice[0] = send_data.pointer;
        out_slice[1] = send_data.length;
        out_slice[2] = send_data.length;
      }
    },
  };

  const  wasm = await WebAssembly.instantiateStreaming(fetch(wasm_file), importObj);
  
  memory = wasm.instance.exports.memory;
  allocater = wasm.instance.exports.allocUint8;
  const run_roc = wasm.instance.exports.run_roc;

  return function (input, print_str, read_str) {
    try {
      print_str_callback = print_str;
      read_str_callback = read_str;

      const message = send_string(memory, allocater, input)

      // Call the roc code
      const result_pointer = run_roc(message.pointer, message.length);
      const result_message = decodeZeroTerminatedString(memory, result_pointer);
      console.log(result_message)
      return result_message;

    } catch (e) {
      const is_ok = e.message === "unreachable" && exit_code === 0;
      if (!is_ok) {
        console.error(e);
      }

    } finally {
      print_str_callback = undefined;
      read_str_callback = undefined;
    }
  }
}

if (typeof module !== "undefined") {
  module.exports = {
    load_wasm,
  };
}
