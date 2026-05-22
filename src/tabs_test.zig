const std = @import("std");
const tabs = @import("tabs.zig");

test "tab names match labels" {
    try std.testing.expectEqualStrings("Trending Repos", tabs.Tab.trendingRepos.name());
    try std.testing.expectEqualStrings("Hacker News", tabs.Tab.hackernews.name());
    try std.testing.expectEqualStrings("Product Hunt", tabs.Tab.productHunt.name());
    try std.testing.expectEqualStrings("ArXiv", tabs.Tab.arxiv.name());
    try std.testing.expectEqualStrings("RSS Feeds", tabs.Tab.rss.name());
}

test "next cycles through tabs" {
    try std.testing.expectEqual(tabs.Tab.hackernews, tabs.next(.trendingRepos));
    try std.testing.expectEqual(tabs.Tab.productHunt, tabs.next(.hackernews));
    try std.testing.expectEqual(tabs.Tab.arxiv, tabs.next(.productHunt));
    try std.testing.expectEqual(tabs.Tab.rss, tabs.next(.arxiv));
    try std.testing.expectEqual(tabs.Tab.trendingRepos, tabs.next(.rss));
}

test "previous cycles through tabs" {
    try std.testing.expectEqual(tabs.Tab.rss, tabs.previous(.trendingRepos));
    try std.testing.expectEqual(tabs.Tab.trendingRepos, tabs.previous(.hackernews));
    try std.testing.expectEqual(tabs.Tab.hackernews, tabs.previous(.productHunt));
    try std.testing.expectEqual(tabs.Tab.productHunt, tabs.previous(.arxiv));
    try std.testing.expectEqual(tabs.Tab.arxiv, tabs.previous(.rss));
}
