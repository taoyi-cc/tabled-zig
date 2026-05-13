const std = @import("std");
const tabled = @import("src/root.zig");
const Table = tabled.Table;

pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;
    const io = init.io;

    var list = try readDir(gpa, io);
    defer {
        for (list.items) |*it| {
            it.deinit();
        }
        list.deinit(gpa);
    }

    const file_data = try gpa.alloc([]const []const u8, list.items.len + 1);
    defer {
        for (0..file_data.len) |i| {
            if (i > 0) {
                const line = file_data[i];
                gpa.free(line);
            }
        }
        gpa.free(file_data);
    }
    file_data[0] = &.{ "Name", "Size(Byte)", "Type" };
    var buf: [64]u8 = undefined;
    for (list.items, 0..) |it, i| {
        const line = try gpa.alloc([]const u8, 3);
        line[0] = it.name;
        line[1] = try std.fmt.bufPrint(&buf, "{}", .{it.size});
        line[2] = it.type;
        file_data[i + 1] = line;
    }

    var t = Table.init(gpa, .{ .style = .ascii });
    defer t.deinit();
    std.debug.print("{s}\n", .{try t.build(file_data)});
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
            .type = if (stat.kind == .file) "file" else "dir",
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
        const stat = try cwd.statFile(io, entry.name, .{});
        try list.append(gpa, try FileMeta.init(gpa, entry.name, stat));
    }
    return list;
}
