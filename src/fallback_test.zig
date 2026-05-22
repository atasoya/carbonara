const std = @import("std");
const fallback = @import("fallback.zig");

test "fallback trending repos include display fields and urls" {
    var repos = try fallback.trendingRepos(std.testing.allocator);
    defer repos.deinit();

    try std.testing.expect(repos.items.items.len > 0);
    const repo = repos.items.items[0];
    try std.testing.expect(repo.name.len > 0);
    try std.testing.expect(repo.description.len > 0);
    try std.testing.expect(repo.language.len > 0);
    try std.testing.expect(repo.stars.len > 0);
    try std.testing.expect(std.mem.startsWith(u8, repo.url, "https://github.com/"));
}

test "fallback hacker news stories include display fields and urls" {
    var stories = try fallback.hackerNews(std.testing.allocator);
    defer stories.deinit();

    try std.testing.expect(stories.items.items.len > 0);
    const story = stories.items.items[0];
    try std.testing.expect(story.title.len > 0);
    try std.testing.expect(story.by.len > 0);
    try std.testing.expect(story.score.len > 0);
    try std.testing.expect(story.comments.len > 0);
    try std.testing.expect(std.mem.startsWith(u8, story.url, "https://"));
}

test "fallback rss items include display fields and links" {
    var items = try fallback.rssFeeds(std.testing.allocator);
    defer items.deinit();

    try std.testing.expect(items.items.items.len > 0);
    const item = items.items.items[0];
    try std.testing.expect(item.title.len > 0);
    try std.testing.expect(item.source.len > 0);
    try std.testing.expect(item.pub_date.len > 0);
    try std.testing.expect(std.mem.startsWith(u8, item.link, "https://"));
}

test "fallback arxiv papers include display fields and urls" {
    var papers = try fallback.arxivPapers(std.testing.allocator);
    defer papers.deinit();

    try std.testing.expect(papers.items.items.len > 0);
    const paper = papers.items.items[0];
    try std.testing.expect(paper.title.len > 0);
    try std.testing.expect(paper.category.len > 0);
    try std.testing.expect(paper.authors.len > 0);
    try std.testing.expect(paper.date.len > 0);
    try std.testing.expect(std.mem.startsWith(u8, paper.url, "https://arxiv.org/"));
}
