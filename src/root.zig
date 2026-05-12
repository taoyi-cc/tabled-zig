const std = @import("std");

pub const Border = struct {
    gadget: u8,
    top_left: u8,
    top_right: u8,
    bottom_left: u8,
    bottom_right: u8,
    line_delimiter: []const u8,
    col_delimiter: []const u8,

    fn build(style: Style) Border {
        switch (style) {
            .line => return .{
                .gadget = '+',
                .top_left = '+',
                .top_right = '+',
                .bottom_left = '+',
                .bottom_right = '+',
                .line_delimiter = "-",
                .col_delimiter = "|",
            },
            .round => return .{
                .gadget = '-',
                .top_left = '.',
                .top_right = '.',
                .bottom_left = '\'',
                .bottom_right = '\'',
                .line_delimiter = "-",
                .col_delimiter = "|",
            },
            .none => return .{
                .gadget = ' ',
                .top_left = ' ',
                .top_right = ' ',
                .bottom_left = ' ',
                .bottom_right = ' ',
                .line_delimiter = "",
                .col_delimiter = "",
            },
        }
    }
};

pub const Style = enum { none, line, round };
pub const Info = struct {
    line_delimiter: []const u8,
    col_delimiter: []const u8,
    corner: u8,
    gadget: u8,
};
pub const Config = struct {
    style: Style = .line,
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
        for (0..col_count) |i| {
            const len = col_lengths[i];
            if (i == 0) {
                try self.list.append(gpa, if (line_no == 0) border.top_left else if (line_no == data.len) border.bottom_left else border.gadget);
            } else if (i == col_count) {
                try self.list.append(gpa, if (line_no == 0) border.top_right else if (line_no == data.len) border.bottom_right else border.gadget);
            } else {
                try self.list.append(gpa, border.gadget);
            }
            for (0..len + gap * 2) |_| {
                try self.list.appendSlice(gpa, border.line_delimiter);
            }
        }
        // std.debug.print("{}", .{data.len});
        if (line_no == 0) {
            try self.list.append(gpa, border.top_right);
        } else if (line_no == data.len) {
            try self.list.append(gpa, border.bottom_right);
        } else {
            try self.list.append(gpa, border.gadget);
        }
        try self.list.append(gpa, '\n');
    }

    pub fn build(self: *Table, data: []const []const []const u8) ![]u8 {
        const gpa = self.allocator;
        self.list.clearRetainingCapacity();
        // const border = Border.build(self.config.style);
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

        // std.debug.print("{}\n", .{line_len});

        // if (self.config.style != .none) {
        //     for (0..col_count) |i| {
        //         const len = col_lengths[i];
        //         try self.list.append(gpa, if (i == 0) border.top_left else if (i == col_count) border.top_right else border.gadget);
        //         for (0..len + gap * 2) |_| {
        //             try self.list.appendSlice(gpa, border.line_delimiter);
        //         }
        //     }

        //     try self.list.append(gpa, border.top_right);
        //     try self.list.append(gpa, '\n');
        // }
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
            // if (self.config.style != .none) {
            //     for (0..col_count) |i| {
            //         std.debug.print("{any}\n", .{line_no == 0});
            //         const len = col_lengths[i];
            //         if (line_no == 0) {
            //             try self.list.append(gpa, if (i == 0) border.top_left else if (i == col_count - 1) border.top_right else border.gadget);
            //         } else if (line_no == data.len - 1) {
            //             try self.list.append(gpa, if (i == 0) border.bottom_left else if (i == col_count - 1) border.bottom_right else border.gadget);
            //         } else {
            //             try self.list.append(gpa, border.gadget);
            //         }
            //         for (0..len + gap * 2) |_| {
            //             try self.list.appendSlice(gpa, border.line_delimiter);
            //         }
            //     }
            //     // std.debug.print("{}", .{data.len});
            //     // if (line_no == 0) {
            //     // try self.list.append(gpa, border.top_right);
            //     // } else if (line_no == data.len - 1) {
            //     // try self.list.append(gpa, border.bottom_right);
            //     // } else {
            //     try self.list.append(gpa, 'a');
            //     // }
            //     try self.list.append(gpa, '\n');
            // }
        }
        return self.list.items;
    }
};
