const std = @import("std");
const layout = @import("layout.zig");

test "panelWidth leaves terminal margin" {
    try std.testing.expectEqual(@as(u16, 78), layout.panelWidth(80));
}

test "panelWidth caps at max width" {
    try std.testing.expectEqual(@as(u16, layout.max_panel_width), layout.panelWidth(200));
}

test "panelWidth handles tiny terminals" {
    try std.testing.expectEqual(@as(u16, 0), layout.panelWidth(1));
    try std.testing.expectEqual(@as(u16, 0), layout.panelWidth(2));
}

test "viewportHeight respects min and max bounds" {
    try std.testing.expectEqual(@as(u16, 5), layout.viewportHeight(10));
    try std.testing.expectEqual(@as(u16, 6), layout.viewportHeight(20));
    try std.testing.expectEqual(@as(u16, 18), layout.viewportHeight(80));
}
