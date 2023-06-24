const builtin = @import("builtin");
const std = @import("std");

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
extern fn print_roc_string(str_bytes: ?[*]u8, str_len: usize) void;

export fn allocUint8(length: u32) [*]u8 {
    const slice = std.heap.page_allocator.alloc(u8, length) catch
        @panic("failed to allocate memory");

    return slice.ptr;
}

const RocList = struct { pointer: [*]u8, length: usize, capacity: usize };

extern fn roc__handlerForHost_1_exposed(*RocList, *RocList) void;

export fn run_roc(input: [*]u8, input_len: usize) [*]const u8 {
    defer std.heap.page_allocator.free(input[0..input_len]);

    var arg = RocList{ .pointer = input, .length = input_len, .capacity = input_len };

    // TODO: What should the pointer be for the empty callresult?
    // Is this on the stack or the heap? Do I have to deallocate?
    var callresult = RocList{ .pointer = input, .length = 0, .capacity = 0 };

    roc__handlerForHost_1_exposed(&callresult, &arg);

    return callresult.pointer;
}

pub fn main() u8 {
    // TODO: This should be removed: https://github.com/roc-lang/roc/issues/5585
    return 0;
}
