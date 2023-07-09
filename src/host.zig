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
const RocJob = extern struct { placeholder_I_dont_understand: u128, name: RocList, value: RocList };

extern fn roc__mainForHost_1_exposed_generic(result: *RocJob, argument: *RocList) void;
extern fn roc__mainForHost_1_exposed_size() i64;
extern fn roc__mainForHost_0_caller(arg: *RocList, callback_pointer: [*]u8, result: *RocList) void;
extern fn roc__mainForHost_0_size() i64;

const ExternJob = extern struct { callback: *RocJob, name: [*]u8, value: [*]u8 };

// run_roc uses the webassembly memory at the given pointer to call roc.
//
// It retuns a new pointer to the data returned by roc.
export fn run_roc(argument_pointer: [*]u8, length: usize) [*]u8 {
    defer std.heap.page_allocator.free(argument_pointer[0..length]);

    const arg = &RocList{ .pointer = argument_pointer, .length = length, .capacity = length };
    const return_size = @intCast(u32, roc__mainForHost_1_exposed_size());
    // TODO: This has to be deallocated
    const raw_output = roc_alloc(@intCast(usize, return_size), @alignOf(u64)).?;
    var roc_result = @ptrCast(*RocJob, @alignCast(@alignOf(RocJob), raw_output));

    roc__mainForHost_1_exposed_generic(roc_result, arg);

    // TODO: This has to be deallocated
    var job = allocator.create(ExternJob) catch
        @panic("failed to allocate result type");

    job.callback = roc_result;
    job.name = roc_result.name.pointer;
    job.value = roc_result.value.pointer;
    return @ptrCast([*]u8, job);
}

export fn run_callback(callback_pointer: [*]u8, argument_pointer: [*]u8, argument_length: usize) [*]u8 {
    defer std.heap.page_allocator.free(argument_pointer[0..argument_length]);

    const arg = &RocList{ .pointer = argument_pointer, .length = argument_length, .capacity = argument_length };

    const return_size = @intCast(u32, roc__mainForHost_0_size());
    // TODO: This has to be deallocated
    const raw_output = roc_alloc(@intCast(usize, return_size), @alignOf(u64)).?;
    var roc_result = @ptrCast(*RocList, @alignCast(@alignOf(RocList), raw_output));

    roc__mainForHost_0_caller(arg, callback_pointer, roc_result);

    return roc_result.pointer;
}

pub fn main() u8 {
    // TODO: This should be removed: https://github.com/roc-lang/roc/issues/5585
    return 0;
}
