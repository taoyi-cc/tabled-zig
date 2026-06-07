const std = @import("std");
pub const table = @import("table.zig");
pub const builder = @import("builder.zig");
pub const Table = table.Table;
pub const Builder = builder.Builder;
const builtin = @import("builtin");
const windows = std.os.windows;
extern "kernel32" fn GetConsoleOutputCP() callconv(.winapi) windows.UINT;
extern "kernel32" fn SetConsoleOutputCP(wCodePageID: windows.UINT) callconv(.winapi) windows.BOOL;

const UTF8 = 65001;
const Error = error{ SetOutputCPFailed, GetOutputCPFailed };
var original: c_uint = undefined;

pub fn init() Error!void {
    if (builtin.os.tag == .windows) {
        original = GetConsoleOutputCP();
        if (original == 0) {
            return Error.GetOutputCPFailed;
        }
        if (!SetConsoleOutputCP(UTF8).toBool()) {
            return Error.SetOutputCPFailed;
        }
    }
}

pub fn deinit() void {
    if (builtin.os.tag == .windows) {
        _ = SetConsoleOutputCP(original);
    }
}
