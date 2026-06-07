const std = @import("std");
const tabled = @import("src/root.zig");
const Table = tabled.Table;

pub fn main(init: std.process.Init) !void {
    try tabled.init(); // It is needed on Windows systems, otherwise garbled text may appear.
    defer tabled.deinit();

    const data = &[_][]const []const u8{
        &[_][]const u8{ "Col1", "Col2", "Col3", "Col4" },
        &[_][]const u8{ "Col1", "Col2", "Col3", "Col4" },
        &[_][]const u8{ "Col1", "Col2", "Col3", "Col4" },
    };
    var t = Table.init(init.gpa, data, .{});
    defer t.deinit();
    std.debug.print("{s}\n", .{try t.display()});

    try example1(init);
    try example2(init);
}

const FileMeta = struct {
    allocator: std.mem.Allocator,
    name: []const u8,
    size: usize,
    type: []const u8,

    fn init(gpa: std.mem.Allocator, name: []const u8, stat: std.Io.File.Stat) !FileMeta {
        return .{
            .allocator = gpa,
            .name = try gpa.dupe(u8, name),
            .size = stat.size,
            .type = if (stat.kind == .directory) "Directory" else "File",
        };
    }

    fn deinit(self: *FileMeta) void {
        self.allocator.free(self.name);
    }
};
fn readDir(gpa: std.mem.Allocator, io: std.Io) !std.ArrayList(FileMeta) {
    const cwd = try std.Io.Dir.cwd().openDir(io, ".", .{ .iterate = true });
    defer cwd.close(io);
    var iter = cwd.iterate();
    var list = std.ArrayList(FileMeta).empty;
    while (try iter.next(io)) |entry| {
        var stat = try cwd.statFile(io, entry.name, .{});
        if (stat.kind == .directory) {
            var total_size: usize = 0;
            const dir = try cwd.openDir(io, entry.name, .{ .iterate = true });
            defer dir.close(io);
            var walker = try dir.walk(gpa);
            defer walker.deinit();
            while (try walker.next(io)) |inner_entry| {
                const inner_stat = try dir.statFile(io, inner_entry.path, .{});
                total_size += inner_stat.size;
            }
            stat.size = total_size;
        }
        try list.append(gpa, try FileMeta.init(gpa, entry.name, stat));
    }
    return list;
}
fn example1(init: std.process.Init) !void {
    const gpa = init.gpa;
    const io = init.io;

    var list = try readDir(gpa, io);
    defer {
        for (list.items) |*it| {
            it.deinit();
        }
        list.deinit(gpa);
    }

    var b = tabled.Builder.init(gpa);
    defer {
        for (b.source.items, 0..) |line, i| {
            if (i > 0) {
                gpa.free(line);
            }
        }
        defer b.deinit();
    }

    try b.pushLineComptime(3, [_][]const u8{ "Name", "Size(Byte)", "Type" });
    const bufs = try gpa.alloc([64]u8, list.items.len);
    defer gpa.free(bufs);

    for (list.items, 0..) |it, i| {
        const line = try gpa.alloc([]const u8, 3);
        line[0] = it.name;
        line[1] = try std.fmt.bufPrint(&bufs[i], "{}", .{it.size});
        line[2] = it.type;
        try b.pushLine(line);
    }

    // var t = Table.init(gpa, file_data, .{ .style = .ascii });
    var t = b.build(.{});
    defer t.deinit();
    std.debug.print("{s}\n", .{try t.display()});
}

fn example2(init: std.process.Init) !void {
    // _ = init;
    const gpa = init.gpa;
    var b = tabled.Builder.init(gpa);
    defer b.deinit();

    try b.pushLineComptime(3, [_][]const u8{ "A", "B", "C" });
    try b.pushLineComptime(3, [_][]const u8{ "1", "2", "3" });
    try b.pushLine(&[_][]const u8{ "4", "5", "6" });

    var t1 = b.build(.{ .style = .ascii_round, .gap = 1 });
    var t2 = b.build(.{ .style = .ascii, .gap = 2 });
    var t3 = b.build(.{ .style = .modern, .gap = 3 });
    defer {
        t1.deinit();
        t2.deinit();
        t3.deinit();
    }

    std.debug.print("{s}\n", .{try t1.display()});
    std.debug.print("{s}\n", .{try t2.display()});
    std.debug.print("{s}\n", .{try t3.display()});
}
