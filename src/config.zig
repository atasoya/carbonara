const std = @import("std");

const default_feeds = &[_][]const u8{"https://ziglang.org/news/index.xml"};

pub const Config = struct {
    rss_feeds: [][]const u8,
    allocator: std.mem.Allocator,

    pub fn load(allocator: std.mem.Allocator, io: std.Io, home_dir: []const u8) Config {
        var path_buf: [2048]u8 = undefined;
        const path = std.fmt.bufPrint(&path_buf, "{s}/.config/carbonara/config.json", .{home_dir}) catch return defaultConfig(allocator);

        const file = std.Io.Dir.openFileAbsolute(io, path, .{}) catch return defaultConfig(allocator);
        defer file.close(io);

        const file_len = file.length(io) catch return defaultConfig(allocator);
        const content = allocator.alloc(u8, file_len) catch return defaultConfig(allocator);
        defer allocator.free(content);
        _ = file.readPositionalAll(io, content, 0) catch return defaultConfig(allocator);

        var parsed = std.json.parseFromSlice(std.json.Value, allocator, content, .{}) catch return defaultConfig(allocator);
        defer parsed.deinit();

        const root = parsed.value.object;
        const feeds_value = root.get("rss_feeds") orelse return defaultConfig(allocator);
        const feed_array = feeds_value.array;

        var feeds = allocator.alloc([]const u8, feed_array.items.len) catch return defaultConfig(allocator);
        errdefer allocator.free(feeds);

        for (feed_array.items, 0..) |item, i| {
            feeds[i] = allocator.dupe(u8, item.string) catch return defaultConfig(allocator);
        }

        return Config{
            .rss_feeds = feeds,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Config) void {
        for (self.rss_feeds) |feed| {
            self.allocator.free(feed);
        }
        self.allocator.free(self.rss_feeds);
    }
};

fn defaultConfig(allocator: std.mem.Allocator) Config {
    const feeds = allocator.dupe([]const u8, default_feeds) catch return Config{
        .rss_feeds = &.{},
        .allocator = allocator,
    };
    return Config{
        .rss_feeds = feeds,
        .allocator = allocator,
    };
}
