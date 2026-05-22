const std = @import("std");
const Writer = std.Io.Writer;

pub fn truncateForWidth(allocator: std.mem.Allocator, value: []const u8, width: usize) ![]const u8 {
    if (value.len <= width) return value;
    if (width <= 3) return value[0..@min(value.len, width)];
    return try std.fmt.allocPrint(allocator, "{s}...", .{value[0 .. width - 3]});
}

pub fn isTruncated(value: []const u8, width: usize) bool {
    return value.len > width;
}

pub fn detailModalBodyWidth(terminal_width: u16) usize {
    const modal_width = @max(@as(usize, 20), (@as(usize, terminal_width) * 8) / 10);
    return @max(@as(usize, 14), modal_width -| 6);
}

pub fn wrapText(allocator: std.mem.Allocator, value: []const u8, width: usize) ![]const u8 {
    var result: Writer.Allocating = .init(allocator);
    const writer = &result.writer;
    var line_iter = std.mem.splitScalar(u8, value, '\n');
    var first_output_line = true;

    while (line_iter.next()) |line| {
        if (line.len == 0) {
            if (!first_output_line) try writer.writeByte('\n');
            first_output_line = false;
            continue;
        }

        var remaining = line;
        while (remaining.len > width) {
            var split_at = width;
            var i: usize = width;
            while (i > 0) : (i -= 1) {
                if (remaining[i - 1] == ' ') {
                    split_at = i - 1;
                    break;
                }
            }
            if (split_at == 0) split_at = width;

            if (!first_output_line) try writer.writeByte('\n');
            try writer.writeAll(remaining[0..split_at]);
            first_output_line = false;

            remaining = std.mem.trim(u8, remaining[split_at..], " ");
        }

        if (!first_output_line) try writer.writeByte('\n');
        try writer.writeAll(remaining);
        first_output_line = false;
    }

    return result.toOwnedSlice();
}
