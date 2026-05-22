const std = @import("std");
const text = @import("text.zig");

test "truncateForWidth preserves short text" {
    const original = "short";
    const result = try text.truncateForWidth(std.testing.allocator, original, 10);

    try std.testing.expectEqualStrings(original, result);
    try std.testing.expectEqual(@intFromPtr(original.ptr), @intFromPtr(result.ptr));
}

test "truncateForWidth truncates long text with ellipsis" {
    const result = try text.truncateForWidth(std.testing.allocator, "carbonara", 6);
    defer std.testing.allocator.free(result);

    try std.testing.expectEqualStrings("car...", result);
}

test "truncateForWidth handles narrow widths" {
    try std.testing.expectEqualStrings("", try text.truncateForWidth(std.testing.allocator, "abc", 0));
    try std.testing.expectEqualStrings("a", try text.truncateForWidth(std.testing.allocator, "abc", 1));
    try std.testing.expectEqualStrings("ab", try text.truncateForWidth(std.testing.allocator, "abc", 2));
    try std.testing.expectEqualStrings("abc", try text.truncateForWidth(std.testing.allocator, "abc", 3));
}

test "isTruncated reports length over width" {
    try std.testing.expect(!text.isTruncated("abc", 3));
    try std.testing.expect(text.isTruncated("abcd", 3));
}

test "detailModalBodyWidth follows modal sizing rules" {
    try std.testing.expectEqual(@as(usize, 14), text.detailModalBodyWidth(10));
    try std.testing.expectEqual(@as(usize, 74), text.detailModalBodyWidth(100));
}

test "wrapText wraps at spaces" {
    const result = try text.wrapText(std.testing.allocator, "one two three", 7);
    defer std.testing.allocator.free(result);

    try std.testing.expectEqualStrings("one\ntwo\nthree", result);
}

test "wrapText preserves blank lines" {
    const result = try text.wrapText(std.testing.allocator, "one\n\ntwo", 10);
    defer std.testing.allocator.free(result);

    try std.testing.expectEqualStrings("one\n\ntwo", result);
}
