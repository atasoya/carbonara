const std = @import("std");
const xml = @import("xml.zig");

pub const FeedItem = struct {
    title: []const u8,
    link: []const u8,
    pub_date: []const u8,
    source: []const u8,
};

pub const FeedItemList = struct {
    allocator: std.mem.Allocator,
    items: std.array_list.Managed(FeedItem),

    pub fn init(allocator: std.mem.Allocator) FeedItemList {
        return .{
            .allocator = allocator,
            .items = std.array_list.Managed(FeedItem).init(allocator),
        };
    }

    pub fn deinit(self: *FeedItemList) void {
        for (self.items.items) |item| {
            self.allocator.free(item.title);
            self.allocator.free(item.link);
            self.allocator.free(item.pub_date);
            self.allocator.free(item.source);
        }
        self.items.deinit();
    }

    pub fn add(self: *FeedItemList, title: []const u8, link: []const u8, pub_date: []const u8, source: []const u8) !void {
        const owned_title = try self.allocator.dupe(u8, title);
        errdefer self.allocator.free(owned_title);
        const owned_link = try self.allocator.dupe(u8, link);
        errdefer self.allocator.free(owned_link);
        const owned_date = try self.allocator.dupe(u8, pub_date);
        errdefer self.allocator.free(owned_date);
        const owned_source = try self.allocator.dupe(u8, source);
        errdefer self.allocator.free(owned_source);

        try self.items.append(.{
            .title = owned_title,
            .link = owned_link,
            .pub_date = owned_date,
            .source = owned_source,
        });
    }
};

fn extractHostname(url: []const u8) []const u8 {
    var s = url;
    if (std.mem.startsWith(u8, s, "https://")) {
        s = s[8..];
    } else if (std.mem.startsWith(u8, s, "http://")) {
        s = s[7..];
    }
    const slash = std.mem.indexOfScalar(u8, s, '/');
    if (slash) |pos| s = s[0..pos];
    return s;
}

pub fn fetch(allocator: std.mem.Allocator, io: std.Io, url: []const u8) !FeedItemList {
    const hostname = extractHostname(url);

    const result = try std.process.run(allocator, io, .{
        .argv = &.{
            "curl",
            "--silent",
            "--show-error",
            "--request",
            "GET",
            "--url",
            url,
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

    const item_entries = try xml.entries(result.stdout, "item", allocator);
    defer allocator.free(item_entries);

    var items = FeedItemList.init(allocator);
    errdefer items.deinit();

    const max_items: usize = 5;
    for (item_entries, 0..) |entry, i| {
        if (i >= max_items) break;
        const title_raw = stripCDATA(xml.childText(entry, "title") orelse continue);
        const link_raw = stripCDATA(xml.childText(entry, "link") orelse continue);
        const pub_date_raw = stripCDATA(xml.childText(entry, "pubDate") orelse "");

        const title = xml.decodeEntities(allocator, title_raw) catch continue;
        const date = formatDate(allocator, pub_date_raw) catch {
            allocator.free(title);
            continue;
        };

        items.add(title, link_raw, date, hostname) catch {
            allocator.free(title);
            allocator.free(date);
            continue;
        };

        allocator.free(title);
        allocator.free(date);
    }

    return items;
}

fn stripCDATA(text: []const u8) []const u8 {
    const cdata_prefix = "<![CDATA[";
    const cdata_suffix = "]]>";
    if (std.mem.startsWith(u8, text, cdata_prefix) and std.mem.endsWith(u8, text, cdata_suffix)) {
        return text[cdata_prefix.len .. text.len - cdata_suffix.len];
    }
    return text;
}

fn monthToNum(month: []const u8) ?[]const u8 {
    if (std.mem.eql(u8, month, "Jan")) return "01";
    if (std.mem.eql(u8, month, "Feb")) return "02";
    if (std.mem.eql(u8, month, "Mar")) return "03";
    if (std.mem.eql(u8, month, "Apr")) return "04";
    if (std.mem.eql(u8, month, "May")) return "05";
    if (std.mem.eql(u8, month, "Jun")) return "06";
    if (std.mem.eql(u8, month, "Jul")) return "07";
    if (std.mem.eql(u8, month, "Aug")) return "08";
    if (std.mem.eql(u8, month, "Sep")) return "09";
    if (std.mem.eql(u8, month, "Oct")) return "10";
    if (std.mem.eql(u8, month, "Nov")) return "11";
    if (std.mem.eql(u8, month, "Dec")) return "12";
    return null;
}

fn formatDate(allocator: std.mem.Allocator, raw: []const u8) ![]const u8 {
    if (raw.len == 0) return allocator.dupe(u8, "");

    const comma = std.mem.indexOfScalar(u8, raw, ',') orelse return allocator.dupe(u8, raw);
    var rest = raw[comma + 1 ..];
    while (rest.len > 0 and rest[0] == ' ') rest = rest[1..];
    const day_end = std.mem.indexOfScalar(u8, rest, ' ') orelse return allocator.dupe(u8, raw);
    const day = rest[0..day_end];
    rest = rest[day_end + 1 ..];
    const month_end = std.mem.indexOfScalar(u8, rest, ' ') orelse return allocator.dupe(u8, raw);
    const month = rest[0..month_end];
    rest = rest[month_end + 1 ..];
    const year_end = std.mem.indexOfScalar(u8, rest, ' ') orelse return allocator.dupe(u8, raw);
    const year = rest[0..year_end];

    const month_num = monthToNum(month) orelse return allocator.dupe(u8, raw);
    return std.fmt.allocPrint(allocator, "{s}-{s}-{s}", .{ year, month_num, day });
}
