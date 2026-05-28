const std = @import("std");

pub const endpoint = "https://api.producthunt.com/v2/api/graphql";

pub const Post = struct {
    name: []const u8,
    tagline: []const u8,
    url: []const u8,
    votes: []const u8,
    comments: []const u8,
};

pub const PostList = struct {
    allocator: std.mem.Allocator,
    items: std.array_list.Managed(Post),

    pub fn init(allocator: std.mem.Allocator) PostList {
        return .{
            .allocator = allocator,
            .items = std.array_list.Managed(Post).init(allocator),
        };
    }

    pub fn deinit(self: *PostList) void {
        for (self.items.items) |post| {
            self.allocator.free(post.name);
            self.allocator.free(post.tagline);
            self.allocator.free(post.url);
            self.allocator.free(post.votes);
            self.allocator.free(post.comments);
        }
        self.items.deinit();
    }

    pub fn add(self: *PostList, name: []const u8, tagline: []const u8, url: []const u8, votes: []const u8, comments: []const u8) !void {
        const owned_name = try self.allocator.dupe(u8, name);
        errdefer self.allocator.free(owned_name);
        const owned_tagline = try self.allocator.dupe(u8, tagline);
        errdefer self.allocator.free(owned_tagline);
        const owned_url = try self.allocator.dupe(u8, url);
        errdefer self.allocator.free(owned_url);
        const owned_votes = try self.allocator.dupe(u8, votes);
        errdefer self.allocator.free(owned_votes);
        const owned_comments = try self.allocator.dupe(u8, comments);
        errdefer self.allocator.free(owned_comments);

        try self.items.append(.{
            .name = owned_name,
            .tagline = owned_tagline,
            .url = owned_url,
            .votes = owned_votes,
            .comments = owned_comments,
        });
    }
};

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

pub fn fetch(allocator: std.mem.Allocator, io: std.Io, token: []const u8) !PostList {
    const body =
        \\{"query":"query { posts(first: 20, featured: true) { edges { node { id name tagline url votesCount commentsCount createdAt } } } }"}
    ;

    const auth_header = try std.fmt.allocPrint(allocator, "Authorization: Bearer {s}", .{token});
    defer allocator.free(auth_header);

    const result = try std.process.run(allocator, io, .{
        .argv = &.{
            "curl",
            "--silent",
            "--show-error",
            "--request",
            "POST",
            "--url",
            endpoint,
            "--header",
            auth_header,
            "--header",
            "Content-Type: application/json",
            "--data",
            body,
        },
        .stderr_limit = .limited(8 * 1024),
        .stdout_limit = .limited(1024 * 1024),
    });
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    switch (result.term) {
        .exited => |code| if (code != 0) return error.FetchFailed,
        else => return error.FetchFailed,
    }

    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, result.stdout, .{});
    defer parsed.deinit();

    var posts = PostList.init(allocator);
    errdefer posts.deinit();

    const root = parsed.value.object;
    const data = root.get("data") orelse return error.InvalidResponse;
    const posts_value = data.object.get("posts") orelse return error.InvalidResponse;
    const edges = posts_value.object.get("edges") orelse return error.InvalidResponse;

    for (edges.array.items) |edge_value| {
        const node = edge_value.object.get("node") orelse continue;
        const node_obj = node.object;

        const name = valueString(node_obj.get("name")) orelse continue;
        const tagline = valueString(node_obj.get("tagline")) orelse "";
        const url = valueString(node_obj.get("url")) orelse continue;
        const votes_str = valueIntString(allocator, node_obj.get("votesCount")) catch continue;
        defer allocator.free(votes_str);
        const comments_str = valueIntString(allocator, node_obj.get("commentsCount")) catch continue;
        defer allocator.free(comments_str);

        try posts.add(name, tagline, url, votes_str, comments_str);
    }

    return posts;
}
