function do_effect(memory, name_pointer, arg_pointer) {
  const name_slice = new Uint32Array(memory.buffer, name_pointer, 3);
  const name = decodeZeroTerminatedString(memory, name_slice[0]);

  switch (name) {
    case "console_log":
      console.log(get_argument(memory, arg_pointer));
      return "";

    case "time":
      // An effect can return anything that is decodable. In this case a number.
      return new Date().getTime();

    case "localstorage_set":
      const {key, value} = get_argument(memory, arg_pointer);
      localStorage.setItem(key, value);
      return "";

    case "localstorage_get":
      const getKey = get_argument(memory, arg_pointer);
      return localStorage.getItem(getKey);

    default:
      console.log("unknown Effect: ", name)
      return "unknown effect"
  }
}

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

function get_argument(memory, arg_pointer) {
  const argument_slice = new Uint32Array(memory.buffer, arg_pointer, 3);
  return decodeZeroTerminatedString(memory, argument_slice[0]);
}

async function load_wasm(wasm_file) {
  let memory = undefined;
  let allocater = undefined;

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
        const value = do_effect(memory, name_pointer, argument_pointer);

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

  if (allocater === undefined) {
    throw "You have to clear the zig cache befor building the wasm module!"
  }

  return function (input) {
    try {
      const message = send_string(memory, allocater, input)

      // Call the roc code
      const result_pointer = run_roc(message.pointer, message.length);
      const result_message = decodeZeroTerminatedString(memory, result_pointer);
      return result_message;

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
