const std = @import("std");

pub const endpoint = "https://api.ossinsight.io/v1/trends/repos/?period=past_24_hours&language=All";

pub const Repo = struct {
    name: []const u8,
    description: []const u8,
    language: []const u8,
    stars: []const u8,
    url: []const u8,
};

pub const RepoList = struct {
    allocator: std.mem.Allocator,
    items: std.array_list.Managed(Repo),

    pub fn init(allocator: std.mem.Allocator) RepoList {
        return .{
            .allocator = allocator,
            .items = std.array_list.Managed(Repo).init(allocator),
        };
    }

    pub fn deinit(self: *RepoList) void {
        for (self.items.items) |repo| {
            self.allocator.free(repo.name);
            self.allocator.free(repo.description);
            self.allocator.free(repo.language);
            self.allocator.free(repo.stars);
            self.allocator.free(repo.url);
        }
        self.items.deinit();
    }

    pub fn add(self: *RepoList, name: []const u8, description: []const u8, language: []const u8, stars: []const u8) !void {
        const owned_name = try self.allocator.dupe(u8, name);
        errdefer self.allocator.free(owned_name);

        const owned_desc = try self.allocator.dupe(u8, description);
        errdefer self.allocator.free(owned_desc);

        const owned_language = try self.allocator.dupe(u8, if (language.len == 0) "Unknown" else language);
        errdefer self.allocator.free(owned_language);

        const owned_stars = try self.allocator.dupe(u8, if (stars.len == 0) "0" else stars);
        errdefer self.allocator.free(owned_stars);

        const owned_url = try std.fmt.allocPrint(self.allocator, "https://github.com/{s}", .{name});
        errdefer self.allocator.free(owned_url);

        try self.items.append(.{
            .name = owned_name,
            .description = owned_desc,
            .language = owned_language,
            .stars = owned_stars,
            .url = owned_url,
        });
    }
};

pub fn fetch(allocator: std.mem.Allocator, io: std.Io) !RepoList {
    const result = try std.process.run(allocator, io, .{
        .argv = &.{
            "curl",
            "--silent",
            "--show-error",
            "--request",
            "GET",
            "--url",
            endpoint,
            "--header",
            "Accept: application/json",
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

    var repos = RepoList.init(allocator);
    errdefer repos.deinit();

    const root = parsed.value.object;
    const data = root.get("data") orelse return error.InvalidResponse;
    const rows_value = data.object.get("rows") orelse return error.InvalidResponse;

    const max_items = @min(rows_value.array.items.len, 20);
    for (rows_value.array.items[0..max_items]) |row_value| {
        const row = row_value.object;
        const name = valueString(row.get("repo_name")) orelse continue;
        const description = valueString(row.get("description")) orelse "";
        const language = valueString(row.get("primary_language")) orelse "Unknown";
        const stars = valueString(row.get("stars")) orelse "0";

        try repos.add(name, description, language, stars);
    }

    return repos;
}

fn valueString(value: ?std.json.Value) ?[]const u8 {
    const v = value orelse return null;
    return switch (v) {
        .string => |s| s,
        .number_string => |s| s,
        .integer => null,
        .float => null,
        else => null,
    };
}
