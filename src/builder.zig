const std = @import("std");
const table = @import("table.zig");
const Table = table.Table;
const Config = table.Config;
const lib = @import("lib.zig");
const String = lib.String;

pub const Builder = struct {
    source: std.ArrayList([]const String),
    allocator: std.mem.Allocator,

    pub fn init(gpa: std.mem.Allocator) Builder {
        return .{ .source = std.ArrayList([]const String).empty, .allocator = gpa };
    }

    pub fn deinit(self: *Builder) void {
        self.source.deinit(self.allocator);
    }

    pub fn pushLine(self: *Builder, line: []const String) !void {
        try self.source.append(self.allocator, line);
    }

    pub fn build(self: *Builder, config: Config) Table {
        const t = Table.init(self.allocator, self.source.items, config);
        return t;
    }
};
