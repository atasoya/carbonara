const std = @import("std");

pub const topstories_endpoint = "https://hacker-news.firebaseio.com/v0/topstories.json?print=pretty";
const item_endpoint_prefix = "https://hacker-news.firebaseio.com/v0/item/";
const item_endpoint_suffix = ".json?print=pretty";

pub fn itemEndpoint(buffer: []u8, id: i64) ![]const u8 {
    return try std.fmt.bufPrint(buffer, "{s}{d}{s}", .{ item_endpoint_prefix, id, item_endpoint_suffix });
}

pub const Story = struct {
    title: []const u8,
    by: []const u8,
    score: []const u8,
    comments: []const u8,
    url: []const u8,
};

pub const StoryList = struct {
    allocator: std.mem.Allocator,
    items: std.array_list.Managed(Story),

    pub fn init(allocator: std.mem.Allocator) StoryList {
        return .{
            .allocator = allocator,
            .items = std.array_list.Managed(Story).init(allocator),
        };
    }

    pub fn deinit(self: *StoryList) void {
        for (self.items.items) |story| {
            self.allocator.free(story.title);
            self.allocator.free(story.by);
            self.allocator.free(story.score);
            self.allocator.free(story.comments);
            self.allocator.free(story.url);
        }
        self.items.deinit();
    }

    pub fn add(self: *StoryList, title: []const u8, by: []const u8, score: []const u8, comments: []const u8, url: []const u8) !void {
        const owned_title = try self.allocator.dupe(u8, title);
        errdefer self.allocator.free(owned_title);

        const owned_by = try self.allocator.dupe(u8, by);
        errdefer self.allocator.free(owned_by);

        const owned_score = try self.allocator.dupe(u8, score);
        errdefer self.allocator.free(owned_score);

        const owned_comments = try self.allocator.dupe(u8, comments);
        errdefer self.allocator.free(owned_comments);

        const owned_url = try self.allocator.dupe(u8, url);
        errdefer self.allocator.free(owned_url);

        try self.items.append(.{
            .title = owned_title,
            .by = owned_by,
            .score = owned_score,
            .comments = owned_comments,
            .url = owned_url,
        });
    }
};

pub fn fetch(allocator: std.mem.Allocator, io: std.Io) !StoryList {
    const id_result = try std.process.run(allocator, io, .{
        .argv = &.{
            "curl",  "--silent",          "--show-error", "--request",                "GET",
            "--url", topstories_endpoint, "--header",     "Accept: application/json",
        },
        .stderr_limit = .limited(8 * 1024),
        .stdout_limit = .limited(1024 * 1024),
    });
    defer allocator.free(id_result.stdout);
    defer allocator.free(id_result.stderr);

    switch (id_result.term) {
        .exited => |code| if (code != 0) return error.FetchFailed,
        else => return error.FetchFailed,
    }

    var id_parsed = try std.json.parseFromSlice(std.json.Value, allocator, id_result.stdout, .{});
    defer id_parsed.deinit();

    const ids = id_parsed.value.array.items;
    const count = @min(ids.len, 20);

    var stories = StoryList.init(allocator);
    errdefer stories.deinit();

    for (ids[0..count]) |id_value| {
        const id = switch (id_value) {
            .integer => |n| @as(i64, n),
            .number_string => |s| std.fmt.parseInt(i64, s, 10) catch continue,
            else => continue,
        };

        var url_buf: [256]u8 = undefined;
        const url = try itemEndpoint(&url_buf, id);

        const story_result = std.process.run(allocator, io, .{
            .argv = &.{
                "curl",  "--silent", "--show-error", "--request",                "GET",
                "--url", url,        "--header",     "Accept: application/json",
            },
            .stderr_limit = .limited(8 * 1024),
            .stdout_limit = .limited(1024 * 1024),
        }) catch continue;
        defer allocator.free(story_result.stdout);
        defer allocator.free(story_result.stderr);

        switch (story_result.term) {
            .exited => |code| if (code != 0) continue,
            else => continue,
        }

        var story_parsed = try std.json.parseFromSlice(std.json.Value, allocator, story_result.stdout, .{});
        defer story_parsed.deinit();

        const obj = story_parsed.value.object;

        const title = valueString(obj.get("title")) orelse continue;
        const by = valueString(obj.get("by")) orelse "unknown";

        const score_str = try valueIntString(allocator, obj.get("score"));
        defer allocator.free(score_str);

        const comments_str = try valueIntString(allocator, obj.get("descendants"));
        defer allocator.free(comments_str);

        const raw_url = valueString(obj.get("url")) orelse "";
        if (raw_url.len > 0) {
            try stories.add(title, by, score_str, comments_str, raw_url);
        } else {
            const hn_url = try std.fmt.allocPrint(allocator, "https://news.ycombinator.com/item?id={d}", .{id});
            defer allocator.free(hn_url);
            try stories.add(title, by, score_str, comments_str, hn_url);
        }
    }

    return stories;
}

fn valueString(value: ?std.json.Value) ?[]const u8 {
    const v = value orelse return null;
    return switch (v) {
        .string => |s| s,
        .number_string => |s| s,
        else => null,
    };
}

fn valueIntString(allocator: std.mem.Allocator, value: ?std.json.Value) ![]const u8 {
    const v = value orelse return try allocator.dupe(u8, "0");
    return switch (v) {
        .integer => |n| try std.fmt.allocPrint(allocator, "{d}", .{n}),
        .string => |s| try allocator.dupe(u8, s),
        .number_string => |s| try allocator.dupe(u8, s),
        else => try allocator.dupe(u8, "0"),
    };
}
