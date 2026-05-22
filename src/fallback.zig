const std = @import("std");
const arxiv = @import("arxiv.zig");
const hackernews = @import("hackernews.zig");
const rss = @import("rss.zig");
const trending = @import("trending.zig");

pub fn trendingRepos(allocator: std.mem.Allocator) !trending.RepoList {
    var repos = trending.RepoList.init(allocator);
    errdefer repos.deinit();

    try repos.add("ghostty-org/ghostty", "A fast, feature-rich terminal emulator", "Zig", "34.8k");
    try repos.add("sharkdp/fd", "A simple, fast and user-friendly alternative to find", "Rust", "34.1k");
    try repos.add("astral-sh/uv", "An extremely fast Python package manager", "Rust", "55.3k");
    try repos.add("zed-industries/zed", "Code at the speed of thought", "Rust", "58.7k");
    try repos.add("oven-sh/bun", "Incredibly fast JavaScript runtime", "Zig", "77.2k");
    try repos.add("helix-editor/helix", "A post-modern modal text editor", "Rust", "39.6k");
    try repos.add("charmbracelet/bubbletea", "A powerful little TUI framework", "Go", "31.4k");
    try repos.add("tursodatabase/turso", "SQLite for production", "Rust", "12.9k");
    try repos.add("vercel/next.js", "The React framework for production", "TypeScript", "128k");
    try repos.add("sveltejs/svelte", "Cybernetically enhanced web apps", "TypeScript", "81.5k");
    try repos.add("neovim/neovim", "Hyperextensible Vim-based text editor", "Vim Script", "88.2k");
    try repos.add("ziglang/zig", "General-purpose programming language", "Zig", "40.3k");

    return repos;
}

pub fn hackerNews(allocator: std.mem.Allocator) !hackernews.StoryList {
    var stories = hackernews.StoryList.init(allocator);
    errdefer stories.deinit();

    try stories.add("My YC app: Dropbox - Throw away your USB drive", "dhouston", "111", "71", "https://news.ycombinator.com/item?id=8863");
    try stories.add("Show HN: A new kind of database", "example", "89", "45", "https://example.com");
    try stories.add("Ask HN: What are you working on?", "user123", "120", "60", "https://news.ycombinator.com/item?id=9999");
    try stories.add("The Future of Computing", "techwriter", "67", "34", "https://example.com/future");
    try stories.add("Why Functional Programming Matters", "fp_fan", "55", "28", "https://example.com/fp");

    return stories;
}

pub fn rssFeeds(allocator: std.mem.Allocator) !rss.FeedItemList {
    var items = rss.FeedItemList.init(allocator);
    errdefer items.deinit();

    try items.add("Core Team Member Spotlight: Alex Rønne Petersen", "https://ziglang.org/news/core-team-spotlight-alexrp/", "2026-04-18", "ziglang.org");
    try items.add("0.16.0 Released", "https://ziglang.org/news/0.16.0-released/", "2026-04-14", "ziglang.org");
    try items.add("Migrating from GitHub to Codeberg", "https://ziglang.org/news/migrating-from-github-to-codeberg/", "2025-11-26", "ziglang.org");
    try items.add("The First ziglang.org Outage", "https://ziglang.org/news/first-outage/", "2025-09-08", "ziglang.org");
    try items.add("2025 Financial Report and Fundraiser", "https://ziglang.org/news/2025-financials/", "2025-09-02", "ziglang.org");

    return items;
}

pub fn arxivPapers(allocator: std.mem.Allocator) !arxiv.PaperList {
    var papers = arxiv.PaperList.init(allocator);
    errdefer papers.deinit();

    try papers.add("Attention Is All You Need", "cs.AI", "Vaswani et al.", "2017-06-12", "https://arxiv.org/abs/1706.03762");
    try papers.add("BERT: Pre-training of Deep Bidirectional Transformers", "cs.LG", "Devlin et al.", "2019-05-24", "https://arxiv.org/abs/1810.04805");
    try papers.add("GPT-3: Language Models are Few-Shot Learners", "cs.CL", "Brown et al.", "2020-07-22", "https://arxiv.org/abs/2005.14165");
    try papers.add("Deep Residual Learning for Image Recognition", "cs.CV", "He et al.", "2015-12-10", "https://arxiv.org/abs/1512.03385");
    try papers.add("React: JavaScript library for building user interfaces", "cs.SE", "Facebook", "2013-05-29", "https://arxiv.org/abs/1305.1234");
    try papers.add("Introduction to Algorithms", "cs.DS", "Cormen et al.", "2009-07-31", "https://arxiv.org/abs/0907.1234");

    return papers;
}
