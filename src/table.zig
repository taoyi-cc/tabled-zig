const std = @import("std");
const lib = @import("lib.zig");
const String = lib.String;
const Char = lib.Char;
pub const Style = enum { none, ascii, ascii_round, modern };

pub const Border = struct {
    gadget: String,
    top_gadget: String,
    bottom_gadget: String,
    left_gadget: String,
    right_gadget: String,
    top_left: String,
    top_right: String,
    bottom_left: String,
    bottom_right: String,
    line_delimiter: String,
    col_delimiter: String,

    fn new(style: Style) Border {
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
    gap: u8 = 1,
};

pub const Table = struct {
    allocator: std.mem.Allocator,
    source: []const []const String,
    result: std.ArrayList(Char),
    config: Config,
    border: Border,

    pub fn init(gpa: std.mem.Allocator, source: []const []const String, config: Config) Table {
        const result = std.ArrayList(Char).empty;
        const border = Border.new(config.style);
        return Table{
            .allocator = gpa,
            .source = source,
            .result = result,
            .config = config,
            .border = border,
        };
    }

    pub fn deinit(self: *Table) void {
        self.result.deinit(self.allocator);
    }

    fn addLineDelimiter(self: *Table, gap: u8, col_count: usize, col_lengths: []usize, line_no: usize) !void {
        if (self.config.style == .none) {
            return;
        }
        const data = self.source;
        const border = self.border;
        const gpa = self.allocator;
        for (0..col_count + 1) |i| {
            if (line_no == 0) {
                try self.result.appendSlice(gpa, if (i == 0) border.top_left else if (i == col_count) border.top_right else border.top_gadget);
            } else if (line_no == data.len) {
                try self.result.appendSlice(gpa, if (i == 0) border.bottom_left else if (i == col_count) border.bottom_right else border.bottom_gadget);
            } else {
                try self.result.appendSlice(gpa, if (i == 0) border.left_gadget else if (i == col_count) border.right_gadget else border.gadget);
            }
            if (i < col_lengths.len) {
                const len = col_lengths[i];
                for (0..len + gap * 2) |_| {
                    try self.result.appendSlice(gpa, border.line_delimiter);
                }
            }
        }
        try self.result.append(gpa, '\n');
    }

    pub fn display(self: *Table) ![]u8 {
        if (self.result.items.len > 0) {
            return self.result.items;
        }
        const gpa = self.allocator;
        const data = self.source;
        const gap = self.config.gap;
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

        try self.addLineDelimiter(gap, col_count, col_lengths, 0);

        for (data, 0..) |line, line_no| {
            try self.result.appendSlice(gpa, self.border.col_delimiter);
            for (0..col_count) |i| {
                const el = if (i < line.len) line[i] else "";

                for (0..gap) |_| {
                    try self.result.append(gpa, ' ');
                }
                try self.result.appendSlice(gpa, el);
                for (0..col_lengths[i] - el.len + gap) |_| {
                    try self.result.append(gpa, ' ');
                }
                try self.result.appendSlice(gpa, self.border.col_delimiter);
            }
            try self.result.append(gpa, '\n');

            try self.addLineDelimiter(gap, col_count, col_lengths, line_no + 1);
        }
        return self.result.items;
    }
};
