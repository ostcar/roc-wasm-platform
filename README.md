# Roc WASM Platform

roc wasm platform can be used by [roc](https://www.roc-lang.org/) to build wasm modules.

It creates a wasm module, where the wasm runtime and the roc code can use any
types as arguments, that can be decoded by
[json](https://github.com/lukewilliamboswell/roc-json). 

The encoding format will probably change in the future.


## How to use it

With the current wasm standard, it is not possible to send custom types between
the wasm runtime and the wasm module. Only numbers can be transferred directly.

To send other data, the wasm runtime has to convert it to raw bytes, allocate
enough memory in wasm and call the wasm function with the pointer to that memory
as argument.

The roc wasm platform reads the memory from the given pointer, decodes it (as
json) and calls the roc function with the decoded data.

For the return value, the same happens the other way around.

For this to work, the wasm runtime and the roc app have to use the same type.

The wasm-module exports this two functions:

(TODO: Get the wasm signature)
```
allocUint8(length: u32) [*]u8;
run_roc(pointer: [*]u8, length: usize) [*]const u8
```


## Issues

There are currently some issues with roc you have to know about:


### Build from source

You have to build the roc binary from source. See https://github.com/roc-lang/roc/issues/5573

One way to do it is by running from the roc source code with:

```bash
cargo run -- build /PATH/TO/YOUR/main.roc --target=wasm32
```


### Zig Version

You can use zig 0.9.1 or zig 0.10.1. Both versions have issues.


#### 0.9.1

There is a caching bug in zig 0.9.1. To work around it, you have to remove the
zig cache before running `roc build`. See:
https://github.com/ziglang/zig/issues/12864

```bash
find  ~/.cache/roc/ -name zig-cache -exec rm -r {} \;
```


#### 0.10.1

The roc compiler uses zig 0.9.1. So the buildin object files where created with
this version.

To use zig 0.10.1 is possible, but there will be warnings like

```
wasm-ld: warning: Linking two modules of different data layouts: '/home/max/src/roc/target/debug/build/wasi_libc_sys-661fd49d43379bb3/out/wasi-libc.a(llrintl.o at 2476264)' is 'e-m:e-p:32:32-i64:64-n32:64-S128-ni:1:10:20' whereas 'ld-temp.o' is 'e-m:e-p:32:32-p10:8:8-p20:8:8-i64:64-n32:64-S128-ni:1:10:20'
```

It seems, that they can be ignored.


## TODO

* Bundle the platform and use it in the examples
* Show the necessary changes in the roc compiler to use zig 0.10.1
