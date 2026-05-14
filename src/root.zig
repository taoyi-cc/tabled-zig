const std = @import("std");

pub const Style = enum { none, ascii, ascii_round, modern };

pub const Border = struct {
    gadget: []const u8,
    top_gadget: []const u8,
    bottom_gadget: []const u8,
    left_gadget: []const u8,
    right_gadget: []const u8,
    top_left: []const u8,
    top_right: []const u8,
    bottom_left: []const u8,
    bottom_right: []const u8,
    line_delimiter: []const u8,
    col_delimiter: []const u8,

    fn build(style: Style) Border {
        switch (style) {
            .ascii => return .{
                .gadget = "+",
                .top_gadget = "+",
                .bottom_gadget = "+",
                .left_gadget = "+",
                .right_gadget = "+",
                .top_left = "+",
                .top_right = "+",
                .bottom_left = "+",
                .bottom_right = "+",
                .line_delimiter = "-",
                .col_delimiter = "|",
            },
            .ascii_round => return .{
                .gadget = "-",
                .top_gadget = "-",
                .bottom_gadget = "-",
                .left_gadget = "-",
                .right_gadget = "-",
                .top_left = ".",
                .top_right = ".",
                .bottom_left = "'",
                .bottom_right = "'",
                .line_delimiter = "-",
                .col_delimiter = "|",
            },
            .modern => return .{
                .gadget = "┼",
                .top_gadget = "┬",
                .bottom_gadget = "┴",
                .left_gadget = "├",
                .right_gadget = "┤",
                .top_left = "╭",
                .top_right = "╮",
                .bottom_left = "╰",
                .bottom_right = "╯",
                .line_delimiter = "─",
                .col_delimiter = "│",
            },
            .none => return .{
                .gadget = "",
                .top_gadget = "",
                .bottom_gadget = "",
                .left_gadget = "",
                .right_gadget = "",
                .top_left = "",
                .top_right = "",
                .bottom_left = "",
                .bottom_right = "",
                .line_delimiter = "",
                .col_delimiter = "",
            },
        }
    }
};

pub const Config = struct {
    style: Style = .ascii,
};

pub const Table = struct {
    allocator: std.mem.Allocator,
    list: std.ArrayList(u8),
    config: Config,
    border: Border,

    pub fn init(gpa: std.mem.Allocator, config: Config) Table {
        const list = std.ArrayList(u8).empty;
        const border = Border.build(config.style);
        return Table{
            .allocator = gpa,
            .list = list,
            .config = config,
            .border = border,
        };
    }

    pub fn deinit(self: *Table) void {
        self.list.deinit(self.allocator);
    }

    fn buildLineDelimiter(self: *Table, data: []const []const []const u8, gap: u8, col_count: usize, col_lengths: []usize, line_no: usize) !void {
        if (self.config.style == .none) {
            return;
        }
        const border = self.border;
        const gpa = self.allocator;
        for (0..col_count + 1) |i| {
            if (line_no == 0) {
                try self.list.appendSlice(gpa, if (i == 0) border.top_left else if (i == col_count) border.top_right else border.top_gadget);
            } else if (line_no == data.len) {
                try self.list.appendSlice(gpa, if (i == 0) border.bottom_left else if (i == col_count) border.bottom_right else border.bottom_gadget);
            } else {
                try self.list.appendSlice(gpa, if (i == 0) border.left_gadget else if (i == col_count) border.right_gadget else border.gadget);
            }
            if (i < col_lengths.len) {
                const len = col_lengths[i];
                for (0..len + gap * 2) |_| {
                    try self.list.appendSlice(gpa, border.line_delimiter);
                }
            }
        }
        try self.list.append(gpa, '\n');
    }

    pub fn build(self: *Table, data: []const []const []const u8) ![]u8 {
        const gpa = self.allocator;
        self.list.clearRetainingCapacity();
        const gap = 1;
        const col_count = blk: {
            var max: usize = 0;
            for (data) |line| {
                max = @max(max, line.len);
            }
            break :blk max;
        };
        const col_lengths = blk: {
            var slice = try gpa.alloc(usize, col_count);
            @memset(slice, 0);
            for (data) |line| {
                for (line, 0..) |el, i| {
                    slice[i] = @max(slice[i], el.len);
                }
            }
            break :blk slice;
        };
        defer gpa.free(col_lengths);

        try self.buildLineDelimiter(data, gap, col_count, col_lengths, 0);

        for (data, 0..) |line, line_no| {
            try self.list.appendSlice(gpa, self.border.col_delimiter);
            for (0..col_count) |i| {
                const el = if (i < line.len) line[i] else "";

                try self.list.append(gpa, ' ');

                for (0..gap) |_| {
                    try self.list.appendSlice(gpa, el);
                }

                for (0..col_lengths[i] - el.len + gap) |_| {
                    try self.list.append(gpa, ' ');
                }
                try self.list.appendSlice(gpa, self.border.col_delimiter);
            }
            try self.list.append(gpa, '\n');

            try self.buildLineDelimiter(data, gap, col_count, col_lengths, line_no + 1);
        }
        return self.list.items;
    }
};

const builtin = @import("builtin");
const windows = std.os.windows;
extern "kernel32" fn GetConsoleOutputCP() callconv(.winapi) windows.UINT;
extern "kernel32" fn SetConsoleOutputCP(wCodePageID: windows.UINT) callconv(.winapi) windows.BOOL;

var original: c_uint = undefined;
const Error = error{ SetOutputCPFailed, GetOutputCPFailed };

pub fn init() Error!void {
    if (builtin.os.tag == .windows) {
        original = GetConsoleOutputCP();
        if (original == 0) {
            return Error.GetOutputCPFailed;
        }
        if (SetConsoleOutputCP(65001) == 0) {
            return Error.SetOutputCPFailed;
        }
    }
}

pub fn deinit() void {
    if (builtin.os.tag == .windows) {
        _ = SetConsoleOutputCP(original);
    }
}
