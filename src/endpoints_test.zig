const std = @import("std");
const arxiv = @import("arxiv.zig");
const hackernews = @import("hackernews.zig");
const producthunt = @import("producthunt.zig");
const trending = @import("trending.zig");

test "trending endpoint targets OSS Insight trends API" {
    try std.testing.expect(std.mem.startsWith(u8, trending.endpoint, "https://"));
    try std.testing.expect(std.mem.indexOf(u8, trending.endpoint, "api.ossinsight.io/v1/trends/repos/") != null);
    try std.testing.expect(std.mem.indexOf(u8, trending.endpoint, "period=past_24_hours") != null);
    try std.testing.expect(std.mem.indexOf(u8, trending.endpoint, "language=All") != null);
}

test "product hunt endpoint targets GraphQL API" {
    try std.testing.expect(std.mem.startsWith(u8, producthunt.endpoint, "https://"));
    try std.testing.expectEqualStrings("https://api.producthunt.com/v2/api/graphql", producthunt.endpoint);
}

test "hacker news endpoints target Firebase API" {
    try std.testing.expect(std.mem.startsWith(u8, hackernews.topstories_endpoint, "https://"));
    try std.testing.expectEqualStrings(
        "https://hacker-news.firebaseio.com/v0/topstories.json?print=pretty",
        hackernews.topstories_endpoint,
    );

    var url_buf: [256]u8 = undefined;
    const item_url = try hackernews.itemEndpoint(&url_buf, 8863);
    try std.testing.expectEqualStrings(
        "https://hacker-news.firebaseio.com/v0/item/8863.json?print=pretty",
        item_url,
    );
}

test "arxiv endpoint targets query API for category" {
    var url_buf: [256]u8 = undefined;
    const url = try arxiv.endpointForCategory(&url_buf, "cs.AI");

    try std.testing.expect(std.mem.startsWith(u8, url, "https://"));
    try std.testing.expect(std.mem.indexOf(u8, url, "export.arxiv.org/api/query") != null);
    try std.testing.expect(std.mem.indexOf(u8, url, "search_query=cat:cs.AI") != null);
    try std.testing.expect(std.mem.indexOf(u8, url, "max_results=5") != null);
    try std.testing.expect(std.mem.indexOf(u8, url, "sortBy=submittedDate") != null);
    try std.testing.expect(std.mem.indexOf(u8, url, "sortOrder=descending") != null);
}
