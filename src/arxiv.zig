const std = @import("std");
const xml = @import("xml.zig");

const categories = [_][]const u8{
    "cs.AI",
    "cs.LG",
    "cs.CL",
    "cs.CV",
    "cs.SE",
    "cs.DS",
};

const endpoint_prefix = "https://export.arxiv.org/api/query?search_query=cat:";
const endpoint_suffix = "&start=0&max_results=5&sortBy=submittedDate&sortOrder=descending";

pub const Paper = struct {
    title: []const u8,
    category: []const u8,
    authors: []const u8,
    date: []const u8,
    url: []const u8,
};

pub const PaperList = struct {
    allocator: std.mem.Allocator,
    items: std.array_list.Managed(Paper),

    pub fn init(allocator: std.mem.Allocator) PaperList {
        return .{ .allocator = allocator, .items = std.array_list.Managed(Paper).init(allocator) };
    }

    pub fn deinit(self: *PaperList) void {
        for (self.items.items) |paper| {
            self.allocator.free(paper.title);
            self.allocator.free(paper.category);
            self.allocator.free(paper.authors);
            self.allocator.free(paper.date);
            self.allocator.free(paper.url);
        }
        self.items.deinit();
    }

    pub fn add(self: *PaperList, title: []const u8, category: []const u8, authors: []const u8, date: []const u8, url: []const u8) !void {
        const owned_title = try self.allocator.dupe(u8, title);
        errdefer self.allocator.free(owned_title);
        const owned_category = try self.allocator.dupe(u8, category);
        errdefer self.allocator.free(owned_category);
        const owned_authors = try self.allocator.dupe(u8, authors);
        errdefer self.allocator.free(owned_authors);
        const owned_date = try self.allocator.dupe(u8, date);
        errdefer self.allocator.free(owned_date);
        const owned_url = try self.allocator.dupe(u8, url);
        errdefer self.allocator.free(owned_url);

        try self.items.append(.{
            .title = owned_title,
            .category = owned_category,
            .authors = owned_authors,
            .date = owned_date,
            .url = owned_url,
        });
    }
};

pub fn fetch(allocator: std.mem.Allocator, io: std.Io) !PaperList {
    var papers = PaperList.init(allocator);
    errdefer papers.deinit();

    for (categories) |cat| {
        var url_buf: [256]u8 = undefined;
        const url = std.fmt.bufPrint(&url_buf, "{s}{s}{s}", .{ endpoint_prefix, cat, endpoint_suffix }) catch continue;

        const result = std.process.run(allocator, io, .{
            .argv = &.{ "curl", "--silent", "--show-error", "--request", "GET", "--url", url, "--header", "Accept: application/atom+xml" },
            .stderr_limit = .limited(8 * 1024),
            .stdout_limit = .limited(1024 * 1024),
        }) catch continue;
        defer allocator.free(result.stdout);
        defer allocator.free(result.stderr);

        switch (result.term) {
            .exited => |code| if (code != 0) continue,
            else => continue,
        }

        const entry_list = xml.entries(result.stdout, "entry", allocator) catch continue;
        defer allocator.free(entry_list);

        for (entry_list) |entry_xml| {
            const id = xml.childText(entry_xml, "id") orelse continue;
            const title_raw = xml.childText(entry_xml, "title") orelse continue;
            const title = xml.decodeEntities(allocator, std.mem.trim(u8, title_raw, " \n\r\t")) catch continue;
            defer allocator.free(title);

            const published = xml.childText(entry_xml, "published") orelse continue;
            const date = published[0..@min(published.len, 10)];

            const entry_cat = xml.attrValue(entry_xml, "primary_category", "term") orelse cat;

            const name_list = xml.childTexts(entry_xml, "name", allocator) catch &.{};
            defer allocator.free(name_list);
            const authors = formatAuthors(allocator, name_list) catch try allocator.dupe(u8, "Unknown");
            defer allocator.free(authors);

            try papers.add(title, entry_cat, authors, date, id);
        }
    }

    return papers;
}

fn formatAuthors(allocator: std.mem.Allocator, names: []const []const u8) ![]const u8 {
    if (names.len == 0) return try allocator.dupe(u8, "Unknown");
    if (names.len == 1) return try allocator.dupe(u8, names[0]);
    if (names.len == 2) return try std.fmt.allocPrint(allocator, "{s}, {s}", .{ names[0], names[1] });
    return try std.fmt.allocPrint(allocator, "{s}, {s}, et al.", .{ names[0], names[1] });
}
