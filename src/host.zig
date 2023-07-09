const builtin = @import("builtin");
const std = @import("std");
const allocator = std.heap.page_allocator;

comptime {
    if (builtin.target.cpu.arch != .wasm32) {
        @compileError("This platform is for WebAssembly only. You need to pass `--target wasm32` to the Roc compiler.");
    }
}

const Align = extern struct { a: usize, b: usize };
extern fn malloc(size: usize) callconv(.C) ?*align(@alignOf(Align)) anyopaque;
extern fn realloc(c_ptr: [*]align(@alignOf(Align)) u8, size: usize) callconv(.C) ?*anyopaque;
extern fn free(c_ptr: [*]align(@alignOf(Align)) u8) callconv(.C) void;
extern fn memcpy(dest: *anyopaque, src: *anyopaque, count: usize) *anyopaque;

export fn roc_alloc(size: usize, alignment: u32) callconv(.C) ?*anyopaque {
    _ = alignment;

    return malloc(size);
}

export fn roc_realloc(c_ptr: *anyopaque, new_size: usize, old_size: usize, alignment: u32) callconv(.C) ?*anyopaque {
    _ = old_size;
    _ = alignment;

    return realloc(@alignCast(@alignOf(Align), @ptrCast([*]u8, c_ptr)), new_size);
}

export fn roc_dealloc(c_ptr: *anyopaque, alignment: u32) callconv(.C) void {
    _ = alignment;

    free(@alignCast(@alignOf(Align), @ptrCast([*]u8, c_ptr)));
}

// NOTE roc_panic has to be provided by the wasm runtime, so it can throw an exception

// // roc_fx_do_effect is called from roc to do some effect
// export fn roc_fx_do_effect(name: RocList, argument: RocList) RocList {
//     // TODO: If effect would use a Box, would it be a pointer that directly
//     // could be transfaired to wasm? In this case this implementaiton would not
//     // be needed??
//     const result_pointer = do_effect(name.pointer, argument.pointer);

// }

// // do_effect has to be implemented by the wasm-host and colled from roc_fx_do_effect
// extern fn do_effect(name: [*]u8, argument: [*]u8) [*]u8;

// allocUint8 has to be called before run_roc to get some memory in the
// webassembly module.
//
// It returns a pointer, that then can be used by run_roc. The length to
// allocUint8() and run_roc() have to be the same.
export fn allocUint8(length: u32) [*]u8 {
    const slice = std.heap.page_allocator.alloc(u8, length) catch
        @panic("failed to allocate memory");

    return slice.ptr;
}

const RocList = extern struct { pointer: [*]u8, length: usize, capacity: usize };

extern fn roc__mainForHost_1_exposed_generic([*]u8, *RocList) void;
extern fn roc__mainForHost_0_result_size() i64;
extern fn roc__mainForHost_1_exposed_size() i64;
extern fn roc__mainForHost_0_caller(*const u8, [*]u8, [*]u8) void;
extern fn roc__mainForHost_0_size() i64;

// run_roc uses the webassembly memory at the given pointer to call roc.
//
// It retuns a new pointer to the data returned by roc.
export fn run_roc(argument_pointer: [*]u8, length: usize) void {
    defer std.heap.page_allocator.free(argument_pointer[0..length]);

    const arg = &RocList{ .pointer = argument_pointer, .length = length, .capacity = length };

    // The size might be zero; if so, make it at least 8 so that we don't have a nullptr
    const size = std.math.max(@intCast(usize, roc__mainForHost_1_exposed_size()), 8);
    const raw_output = roc_alloc(@intCast(usize, size), @alignOf(u64)).?;
    var output = @ptrCast([*]u8, raw_output);

    defer {
        roc_dealloc(raw_output, @alignOf(u64));
    }

    roc__mainForHost_1_exposed_generic(output, arg);

    const closure_data_pointer = @ptrCast([*]u8, output);

    call_the_closure(closure_data_pointer);

    return;
}

// From: crates/cli_testing_examples/benchmarks/platform/host.zig
fn call_the_closure(closure_data_pointer: [*]u8) void {
    // The size might be zero; if so, make it at least 8 so that we don't have a nullptr
    const size = std.math.max(roc__mainForHost_0_result_size(), 8);
    const raw_output = allocator.allocAdvanced(u8, @alignOf(u64), @intCast(usize, size), .at_least) catch unreachable;
    var output = @ptrCast([*]u8, raw_output);

    defer {
        allocator.free(raw_output);
    }

    const flags: u8 = 0;

    roc__mainForHost_0_caller(&flags, closure_data_pointer, output);

    // The closure returns result, nothing interesting to do with it
    return;
}

pub fn main() u8 {
    // TODO: This should be removed: https://github.com/roc-lang/roc/issues/5585
    return 0;
}
