const std = @import("std");
const zz = @import("zigzag");
const app = @import("app.zig");

pub fn main(init: std.process.Init) !void {
    app.product_hunt_token = init.environ_map.get("PRODUCT_HUNT_TOKEN");

    var program = zz.Program(app.Model).initWithOptions(init.gpa, init.io, init.environ_map, .{
        .mouse = true,
        .title = "Carbonara",
    });

    defer program.deinit();

    try program.run();
}
