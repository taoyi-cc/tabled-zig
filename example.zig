const std = @import("std");
const tabled = @import("src/root.zig");
const Table = tabled.Table;

pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;
    // _ = gpa;
    const data1: [3][]const []const u8 = .{
        &[_][]const u8{ "aadd", "v", "c", "d", "hahah" },
        &[_][]const u8{ "aa", "v", "c", "d" },
        &[_][]const u8{ "v", "c", "d" },
    };
    const data2: [3][]const []const u8 = .{
        &[_][]const u8{ "Col1 ", "Col2", "Col3", "Col4", "Col5" },
        &[_][]const u8{ "aa", "v", "c", "d" },
        &[_][]const u8{ "v", "c", "d" },
    };

    var table = Table.init(gpa, .{ .style = .round });
    defer table.deinit();
    std.debug.print("{s}\n", .{try table.build(&data1)});
    std.debug.print("{s}\n", .{try table.build(&data2)});
}
