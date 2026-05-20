const std = @import("std");
const Writer = std.Io.Writer;
const zz = @import("zigzag");
const trending = @import("trending.zig");
const hackernews = @import("hackernews.zig");
const arxiv = @import("arxiv.zig");
const config_mod = @import("config.zig");
const rss = @import("rss.zig");
const ph = @import("producthunt.zig");

var product_hunt_token: ?[]const u8 = null;

const max_panel_width = 140;

fn fallbackTrendingRepos(allocator: std.mem.Allocator) !trending.RepoList {
    var repos = trending.RepoList.init(allocator);
    errdefer repos.deinit();

    try repos.add("ghostty-org/ghostty", "Zig", "34.8k");
    try repos.add("sharkdp/fd", "Rust", "34.1k");
    try repos.add("astral-sh/uv", "Rust", "55.3k");
    try repos.add("zed-industries/zed", "Rust", "58.7k");
    try repos.add("oven-sh/bun", "Zig", "77.2k");
    try repos.add("helix-editor/helix", "Rust", "39.6k");
    try repos.add("charmbracelet/bubbletea", "Go", "31.4k");
    try repos.add("tursodatabase/turso", "Rust", "12.9k");
    try repos.add("vercel/next.js", "TypeScript", "128k");
    try repos.add("sveltejs/svelte", "TypeScript", "81.5k");
    try repos.add("neovim/neovim", "Vim Script", "88.2k");
    try repos.add("ziglang/zig", "Zig", "40.3k");

    return repos;
}

fn fallbackHackerNews(allocator: std.mem.Allocator) !hackernews.StoryList {
    var stories = hackernews.StoryList.init(allocator);
    errdefer stories.deinit();

    try stories.add("My YC app: Dropbox - Throw away your USB drive", "dhouston", "111", "71", "https://news.ycombinator.com/item?id=8863");
    try stories.add("Show HN: A new kind of database", "example", "89", "45", "https://example.com");
    try stories.add("Ask HN: What are you working on?", "user123", "120", "60", "https://news.ycombinator.com/item?id=9999");
    try stories.add("The Future of Computing", "techwriter", "67", "34", "https://example.com/future");
    try stories.add("Why Functional Programming Matters", "fp_fan", "55", "28", "https://example.com/fp");

    return stories;
}

fn fallbackRss(allocator: std.mem.Allocator) !rss.FeedItemList {
    var items = rss.FeedItemList.init(allocator);
    errdefer items.deinit();

    try items.add("Core Team Member Spotlight: Alex Rønne Petersen", "https://ziglang.org/news/core-team-spotlight-alexrp/", "2026-04-18", "ziglang.org");
    try items.add("0.16.0 Released", "https://ziglang.org/news/0.16.0-released/", "2026-04-14", "ziglang.org");
    try items.add("Migrating from GitHub to Codeberg", "https://ziglang.org/news/migrating-from-github-to-codeberg/", "2025-11-26", "ziglang.org");
    try items.add("The First ziglang.org Outage", "https://ziglang.org/news/first-outage/", "2025-09-08", "ziglang.org");
    try items.add("2025 Financial Report and Fundraiser", "https://ziglang.org/news/2025-financials/", "2025-09-02", "ziglang.org");

    return items;
}

fn fallbackArxiv(allocator: std.mem.Allocator) !arxiv.PaperList {
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

const Tab = enum {
    trendingRepos,
    hackernews,
    productHunt,
    arxiv,
    rss,

    pub fn name(self: Tab) []const u8 {
        return switch (self) {
            .trendingRepos => "Trending Repos",
            .hackernews => "Hacker News",
            .productHunt => "Product Hunt",
            .arxiv => "ArXiv",
            .rss => "RSS Feeds",
        };
    }
};

const Model = struct {
    active_tab: Tab,
    confirm: zz.Confirm,
    trending_repos: trending.RepoList,
    trending_repos_table: zz.Table(3),
    trending_repos_viewport: zz.Viewport,
    trending_loading: bool,
    ph_posts: ph.PostList,
    ph_table: zz.Table(4),
    ph_viewport: zz.Viewport,
    ph_loading: bool,
    ph_disabled: bool,
    hn_stories: hackernews.StoryList,
    hn_table: zz.Table(4),
    hn_viewport: zz.Viewport,
    hn_loading: bool,
    arxiv_papers: arxiv.PaperList,
    arxiv_table: zz.Table(4),
    arxiv_viewport: zz.Viewport,
    arxiv_loading: bool,
    config: config_mod.Config,
    rss_items: rss.FeedItemList,
    rss_table: zz.Table(3),
    rss_viewport: zz.Viewport,
    rss_loading: bool,
    rss_feed_count: usize,
    rss_completed: usize,
    spinner: zz.Spinner,
    runner: zz.AsyncRunner(Msg),
    show_quit_confirm: bool,

    pub const Msg = union(enum) {
        key: zz.KeyEvent,
        tick: zz.msg.Tick,
        window_size: struct { width: u16, height: u16 },
        trending_loaded: trending.RepoList,
        trending_failed,
        hackernews_loaded: hackernews.StoryList,
        hackernews_failed,
        arxiv_loaded: arxiv.PaperList,
        arxiv_failed,
        rss_loaded: rss.FeedItemList,
        rss_failed,
        producthunt_loaded: ph.PostList,
        producthunt_failed,
    };

    const FetchArg = struct {
        allocator: std.mem.Allocator,
        io: std.Io,
        rss_url: ?[]const u8 = null,
        ph_token: ?[]const u8 = null,
    };

    pub fn init(self: *Model, ctx: *zz.Context) zz.Cmd(Msg) {
        self.active_tab = .trendingRepos;
        self.confirm = zz.Confirm.init("Are you sure you want to quit?");
        self.trending_repos = trending.RepoList.init(std.heap.page_allocator);
        self.trending_repos_table = zz.Table(3).init(std.heap.page_allocator);
        self.trending_repos_table.setHeaders(.{ "Repository", "Language", "Stars" });
        self.trending_repos_table.focus();
        self.trending_repos_table.show_row_borders = true;
        self.trending_repos_table.visible_rows = 100;
        self.populateTrendingReposTable(std.heap.page_allocator, 32, 11, 7);
        self.trending_loading = true;
        self.ph_posts = ph.PostList.init(std.heap.page_allocator);
        self.ph_table = zz.Table(4).init(std.heap.page_allocator);
        self.ph_table.setHeaders(.{ "Name", "Tagline", "Votes", "Comments" });
        self.ph_table.focus();
        self.ph_table.show_row_borders = true;
        self.ph_table.visible_rows = 100;
        self.ph_loading = false;
        self.ph_disabled = true;
        self.ph_viewport = zz.Viewport.init(std.heap.page_allocator, 67, 14);
        self.ph_viewport.setWrap(false);
        self.ph_viewport.setScrollbarChars(".", "#");
        self.ph_viewport.setScrollbarStyle(
            (zz.Style{}).fg(.gray(8)).inline_style(true),
            (zz.Style{}).fg(.cyan).inline_style(true),
        );
        self.hn_stories = hackernews.StoryList.init(std.heap.page_allocator);
        self.hn_table = zz.Table(4).init(std.heap.page_allocator);
        self.hn_table.setHeaders(.{ "Title", "By", "Score", "Comments" });
        self.hn_table.focus();
        self.hn_table.show_row_borders = true;
        self.hn_table.visible_rows = 100;
        self.populateHNTable(std.heap.page_allocator, 32, 15, 6, 8);
        self.hn_loading = true;
        self.hn_viewport = zz.Viewport.init(std.heap.page_allocator, 67, 14);
        self.hn_viewport.setWrap(false);
        self.hn_viewport.setScrollbarChars(".", "#");
        self.hn_viewport.setScrollbarStyle(
            (zz.Style{}).fg(.gray(8)).inline_style(true),
            (zz.Style{}).fg(.cyan).inline_style(true),
        );
        self.arxiv_papers = arxiv.PaperList.init(std.heap.page_allocator);
        self.arxiv_table = zz.Table(4).init(std.heap.page_allocator);
        self.arxiv_table.setHeaders(.{ "Title", "Category", "Authors", "Date" });
        self.arxiv_table.focus();
        self.arxiv_table.show_row_borders = true;
        self.arxiv_table.visible_rows = 100;
        self.populateArxivTable(std.heap.page_allocator, 32, 8, 18, 10);
        self.arxiv_loading = true;
        self.arxiv_viewport = zz.Viewport.init(std.heap.page_allocator, 67, 14);
        self.arxiv_viewport.setWrap(false);
        self.arxiv_viewport.setScrollbarChars(".", "#");
        self.arxiv_viewport.setScrollbarStyle(
            (zz.Style{}).fg(.gray(8)).inline_style(true),
            (zz.Style{}).fg(.cyan).inline_style(true),
        );
        self.config = config_mod.Config.load(std.heap.page_allocator, ctx.io, ctx.home_dir);
        self.rss_items = rss.FeedItemList.init(std.heap.page_allocator);
        self.rss_table = zz.Table(3).init(std.heap.page_allocator);
        self.rss_table.setHeaders(.{ "Title", "Source", "Date" });
        self.rss_table.focus();
        self.rss_table.show_row_borders = true;
        self.rss_table.visible_rows = 100;
        self.rss_loading = self.config.rss_feeds.len > 0;
        self.rss_feed_count = self.config.rss_feeds.len;
        self.rss_completed = 0;
        self.rss_viewport = zz.Viewport.init(std.heap.page_allocator, 67, 14);
        self.rss_viewport.setWrap(false);
        self.rss_viewport.setScrollbarChars(".", "#");
        self.rss_viewport.setScrollbarStyle(
            (zz.Style{}).fg(.gray(8)).inline_style(true),
            (zz.Style{}).fg(.cyan).inline_style(true),
        );
        self.spinner = zz.Spinner.init();
        self.runner = zz.AsyncRunner(Msg).init(std.heap.page_allocator);
        _ = self.runner.spawnWithArg(FetchArg, .{ .allocator = std.heap.page_allocator, .io = ctx.io }, fetchTrendingTask);
        _ = self.runner.spawnWithArg(FetchArg, .{ .allocator = std.heap.page_allocator, .io = ctx.io }, fetchHackerNewsTask);
        _ = self.runner.spawnWithArg(FetchArg, .{ .allocator = std.heap.page_allocator, .io = ctx.io }, fetchArxivTask);
        for (self.config.rss_feeds) |url| {
            _ = self.runner.spawnWithArg(FetchArg, .{
                .allocator = std.heap.page_allocator,
                .io = ctx.io,
                .rss_url = url,
            }, fetchRssTask);
        }
        if (product_hunt_token) |token| {
            self.ph_disabled = false;
            self.ph_loading = true;
            _ = self.runner.spawnWithArg(FetchArg, .{
                .allocator = std.heap.page_allocator,
                .io = ctx.io,
                .ph_token = token,
            }, fetchProductHuntTask);
        }
        self.trending_repos_viewport = zz.Viewport.init(std.heap.page_allocator, 67, 14);
        self.trending_repos_viewport.setWrap(false);
        self.trending_repos_viewport.setScrollbarChars(".", "#");
        self.trending_repos_viewport.setScrollbarStyle(
            (zz.Style{}).fg(.gray(8)).inline_style(true),
            (zz.Style{}).fg(.cyan).inline_style(true),
        );
        self.show_quit_confirm = false;

        return zz.Cmd(Msg).everyMs(100);
    }

    pub fn update(self: *Model, msg: Msg, ctx: *zz.Context) zz.Cmd(Msg) {
        switch (msg) {
            .tick => {
                _ = self.spinner.update(@intCast(ctx.elapsed));
                const results = self.runner.poll();
                for (results) |result| {
                    switch (result) {
                        .trending_loaded, .trending_failed => self.handleTrendingResult(result),
                        .hackernews_loaded, .hackernews_failed => self.handleHackerNewsResult(result),
                        .arxiv_loaded, .arxiv_failed => self.handleArxivResult(result),
                        .rss_loaded, .rss_failed => self.handleRssResult(result),
                        .producthunt_loaded, .producthunt_failed => self.handleProductHuntResult(result),
                        else => {},
                    }
                }
                return .none;
            },
            .window_size => return .none,
            .trending_loaded, .trending_failed => {
                self.handleTrendingResult(msg);
                return .none;
            },
            .hackernews_loaded, .hackernews_failed => {
                self.handleHackerNewsResult(msg);
                return .none;
            },
            .arxiv_loaded, .arxiv_failed => {
                self.handleArxivResult(msg);
                return .none;
            },
            .rss_loaded, .rss_failed => {
                self.handleRssResult(msg);
                return .none;
            },
            .producthunt_loaded, .producthunt_failed => {
                self.handleProductHuntResult(msg);
                return .none;
            },

            .key => |k| {
                if (self.show_quit_confirm) {
                    self.confirm.handleKey(k);

                    if (self.confirm.result()) |confirmed| {
                        self.show_quit_confirm = false;
                        if (confirmed) return .quit;
                    }

                    return .none;
                }

                if (self.active_tab == .trendingRepos) {
                    switch (k.key) {
                        .enter => {
                            if (self.trending_loading) return .none;
                            self.openSelectedTrendingRepo(ctx);
                            return .none;
                        },
                        .up, .down, .page_up, .page_down, .home, .end => {
                            if (self.trending_loading) return .none;
                            self.trending_repos_table.handleKey(k);
                            self.syncTrendingReposViewport();
                            return .none;
                        },
                        .char => |c| switch (c) {
                            'j', 'k', 'g', 'G' => {
                                if (self.trending_loading) return .none;
                                self.trending_repos_table.handleKey(k);
                                self.syncTrendingReposViewport();
                                return .none;
                            },
                            else => {},
                        },
                        else => {},
                    }
                }

                if (self.active_tab == .hackernews) {
                    switch (k.key) {
                        .enter => {
                            if (self.hn_loading) return .none;
                            self.openSelectedHackerNews(ctx);
                            return .none;
                        },
                        .up, .down, .page_up, .page_down, .home, .end => {
                            if (self.hn_loading) return .none;
                            self.hn_table.handleKey(k);
                            self.syncHNViewport();
                            return .none;
                        },
                        .char => |c| switch (c) {
                            'j', 'k', 'g', 'G' => {
                                if (self.hn_loading) return .none;
                                self.hn_table.handleKey(k);
                                self.syncHNViewport();
                                return .none;
                            },
                            else => {},
                        },
                        else => {},
                    }
                }

                if (self.active_tab == .arxiv) {
                    switch (k.key) {
                        .enter => {
                            if (self.arxiv_loading) return .none;
                            self.openSelectedArxiv(ctx);
                            return .none;
                        },
                        .up, .down, .page_up, .page_down, .home, .end => {
                            if (self.arxiv_loading) return .none;
                            self.arxiv_table.handleKey(k);
                            self.syncArxivViewport();
                            return .none;
                        },
                        .char => |c| switch (c) {
                            'j', 'k', 'g', 'G' => {
                                if (self.arxiv_loading) return .none;
                                self.arxiv_table.handleKey(k);
                                self.syncArxivViewport();
                                return .none;
                            },
                            else => {},
                        },
                        else => {},
                    }
                }

                if (self.active_tab == .rss) {
                    switch (k.key) {
                        .enter => {
                            if (self.rss_loading) return .none;
                            self.openSelectedRss(ctx);
                            return .none;
                        },
                        .up, .down, .page_up, .page_down, .home, .end => {
                            if (self.rss_loading) return .none;
                            self.rss_table.handleKey(k);
                            self.syncRssViewport();
                            return .none;
                        },
                        .char => |c| switch (c) {
                            'j', 'k', 'g', 'G' => {
                                if (self.rss_loading) return .none;
                                self.rss_table.handleKey(k);
                                self.syncRssViewport();
                                return .none;
                            },
                            else => {},
                        },
                        else => {},
                    }
                }

                if (self.active_tab == .productHunt) {
                    if (self.ph_disabled) return .none;
                    switch (k.key) {
                        .enter => {
                            if (self.ph_loading) return .none;
                            self.openSelectedProductHunt(ctx);
                            return .none;
                        },
                        .up, .down, .page_up, .page_down, .home, .end => {
                            if (self.ph_loading) return .none;
                            self.ph_table.handleKey(k);
                            self.syncPhViewport();
                            return .none;
                        },
                        .char => |c| switch (c) {
                            'j', 'k', 'g', 'G' => {
                                if (self.ph_loading) return .none;
                                self.ph_table.handleKey(k);
                                self.syncPhViewport();
                                return .none;
                            },
                            else => {},
                        },
                        else => {},
                    }
                }

                switch (k.key) {
                    .char => |c| switch (c) {
                        '1' => self.active_tab = .trendingRepos,
                        '2' => self.active_tab = .hackernews,
                        '3' => self.active_tab = .productHunt,
                        '4' => self.active_tab = .arxiv,
                        '5' => self.active_tab = .rss,
                        'q' => return .quit,
                        else => {},
                    },

                    .tab => {
                        if (k.modifiers.shift) {
                            self.previousTab();
                        } else {
                            self.nextTab();
                        }
                    },

                    else => {},
                }

                return .none;
            },
        }
    }

    fn nextTab(self: *Model) void {
        self.active_tab = switch (self.active_tab) {
            .trendingRepos => .hackernews,
            .hackernews => .productHunt,
            .productHunt => .arxiv,
            .arxiv => .rss,
            .rss => .trendingRepos,
        };
    }

    fn previousTab(self: *Model) void {
        self.active_tab = switch (self.active_tab) {
            .trendingRepos => .rss,
            .hackernews => .trendingRepos,
            .productHunt => .hackernews,
            .arxiv => .productHunt,
            .rss => .arxiv,
        };
    }

    fn panelWidth(ctx: *const zz.Context) u16 {
        return @min(ctx.width -| 2, @as(u16, max_panel_width));
    }

    fn viewportHeight(ctx: *const zz.Context) u16 {
        return @max(@as(u16, 5), @min(ctx.height -| 14, @as(u16, 18)));
    }

    fn fetchTrendingTask(arg: FetchArg) ?Msg {
        const repos = trending.fetch(arg.allocator, arg.io) catch return .trending_failed;
        return .{ .trending_loaded = repos };
    }

    fn handleTrendingResult(self: *Model, msg: Msg) void {
        switch (msg) {
            .trending_loaded => |repos| {
                self.trending_repos.deinit();
                self.trending_repos = repos;
                self.trending_loading = false;
                self.trending_repos_table.cursor_row = 0;
                self.trending_repos_table.y_offset = 0;
                self.trending_repos_viewport.scrollTo(0, 0);
            },
            .trending_failed => {
                if (!self.trending_loading) return;
                self.trending_repos.deinit();
                self.trending_repos = fallbackTrendingRepos(std.heap.page_allocator) catch trending.RepoList.init(std.heap.page_allocator);
                self.trending_loading = false;
                self.trending_repos_table.cursor_row = 0;
                self.trending_repos_table.y_offset = 0;
                self.trending_repos_viewport.scrollTo(0, 0);
            },
            else => {},
        }
    }

    fn configureTrendingReposTable(self: *Model, allocator: std.mem.Allocator, viewport_width: u16) !void {
        const lang_width: u16 = 12;
        const stars_width: u16 = 7;
        const table_overhead: u16 = 10;
        const fixed_width = lang_width + stars_width + table_overhead;
        const repo_width = @min(@as(u16, 80), @max(@as(u16, 24), viewport_width -| fixed_width));

        self.trending_repos_table.setColumnWidth(0, repo_width);
        self.trending_repos_table.setColumnWidth(1, lang_width);
        self.trending_repos_table.setColumnWidth(2, stars_width);
        self.populateTrendingReposTable(allocator, repo_width, lang_width, stars_width);
    }

    fn populateTrendingReposTable(self: *Model, allocator: std.mem.Allocator, repo_width: usize, lang_width: usize, stars_width: usize) void {
        self.trending_repos_table.clearRows();
        for (self.trending_repos.items.items) |repo| {
            self.trending_repos_table.addRow(.{
                truncateForWidth(allocator, repo.name, repo_width) catch repo.name,
                truncateForWidth(allocator, repo.language, lang_width) catch repo.language,
                truncateForWidth(allocator, repo.stars, stars_width) catch repo.stars,
            }) catch {};
        }
    }

    fn truncateForWidth(allocator: std.mem.Allocator, text: []const u8, width: usize) ![]const u8 {
        if (text.len <= width) return text;
        if (width <= 3) return text[0..@min(text.len, width)];
        return try std.fmt.allocPrint(allocator, "{s}...", .{text[0 .. width - 3]});
    }

    fn fetchProductHuntTask(arg: FetchArg) ?Msg {
        const token = arg.ph_token orelse return .producthunt_failed;
        const posts = ph.fetch(arg.allocator, arg.io, token) catch return .producthunt_failed;
        return .{ .producthunt_loaded = posts };
    }

    fn handleProductHuntResult(self: *Model, msg: Msg) void {
        switch (msg) {
            .producthunt_loaded => |posts| {
                self.ph_posts.deinit();
                self.ph_posts = posts;
                self.ph_loading = false;
                self.ph_table.cursor_row = 0;
                self.ph_table.y_offset = 0;
                self.ph_viewport.scrollTo(0, 0);
            },
            .producthunt_failed => {
                if (!self.ph_loading) return;
                self.ph_posts.deinit();
                self.ph_posts = ph.PostList.init(std.heap.page_allocator);
                self.ph_loading = false;
                self.ph_table.cursor_row = 0;
                self.ph_table.y_offset = 0;
                self.ph_viewport.scrollTo(0, 0);
            },
            else => {},
        }
    }

    fn configurePhTable(self: *Model, allocator: std.mem.Allocator, viewport_width: u16) !void {
        const tagline_width: u16 = 24;
        const votes_width: u16 = 6;
        const comments_width: u16 = 8;
        const table_overhead: u16 = 14;
        const fixed_width = tagline_width + votes_width + comments_width + table_overhead;
        const name_width = @min(@as(u16, 80), @max(@as(u16, 16), viewport_width -| fixed_width));

        self.ph_table.setColumnWidth(0, name_width);
        self.ph_table.setColumnWidth(1, tagline_width);
        self.ph_table.setColumnWidth(2, votes_width);
        self.ph_table.setColumnWidth(3, comments_width);
        self.populatePhTable(allocator, name_width, tagline_width, votes_width, comments_width);
    }

    fn populatePhTable(self: *Model, allocator: std.mem.Allocator, name_width: usize, tagline_width: usize, votes_width: usize, comments_width: usize) void {
        self.ph_table.clearRows();
        for (self.ph_posts.items.items) |post| {
            self.ph_table.addRow(.{
                truncateForWidth(allocator, post.name, name_width) catch post.name,
                truncateForWidth(allocator, post.tagline, tagline_width) catch post.tagline,
                truncateForWidth(allocator, post.votes, votes_width) catch post.votes,
                truncateForWidth(allocator, post.comments, comments_width) catch post.comments,
            }) catch {};
        }
    }

    fn openSelectedProductHunt(self: *const Model, ctx: *zz.Context) void {
        const selected = self.ph_table.selectedRow();
        if (selected >= self.ph_posts.items.items.len) return;

        var child = std.process.spawn(ctx.io, .{
            .argv = &.{ "open", self.ph_posts.items.items[selected].url },
            .stdin = .ignore,
            .stdout = .ignore,
            .stderr = .ignore,
        }) catch return;
        _ = child.wait(ctx.io) catch {};
    }

    fn syncPhViewport(self: *Model) void {
        const selected = self.ph_table.selectedRow();
        const header_lines: usize = 3;
        const row_stride: usize = if (self.ph_table.show_row_borders) 2 else 1;
        const row_line = header_lines + selected * row_stride;

        if (row_line < self.ph_viewport.y_offset) {
            self.ph_viewport.scrollTo(row_line, 0);
        } else if (row_line >= self.ph_viewport.y_offset + self.ph_viewport.height) {
            self.ph_viewport.scrollTo(row_line - self.ph_viewport.height + 1, 0);
        }
    }

    fn fetchHackerNewsTask(arg: FetchArg) ?Msg {
        const stories = hackernews.fetch(arg.allocator, arg.io) catch return .hackernews_failed;
        return .{ .hackernews_loaded = stories };
    }

    fn handleHackerNewsResult(self: *Model, msg: Msg) void {
        switch (msg) {
            .hackernews_loaded => |stories| {
                self.hn_stories.deinit();
                self.hn_stories = stories;
                self.hn_loading = false;
                self.hn_table.cursor_row = 0;
                self.hn_table.y_offset = 0;
                self.hn_viewport.scrollTo(0, 0);
            },
            .hackernews_failed => {
                if (!self.hn_loading) return;
                self.hn_stories.deinit();
                self.hn_stories = fallbackHackerNews(std.heap.page_allocator) catch hackernews.StoryList.init(std.heap.page_allocator);
                self.hn_loading = false;
                self.hn_table.cursor_row = 0;
                self.hn_table.y_offset = 0;
                self.hn_viewport.scrollTo(0, 0);
            },
            else => {},
        }
    }

    fn configureHNTable(self: *Model, allocator: std.mem.Allocator, viewport_width: u16) !void {
        const by_width: u16 = 15;
        const score_width: u16 = 6;
        const comments_width: u16 = 8;
        const table_overhead: u16 = 14;
        const fixed_width = by_width + score_width + comments_width + table_overhead;
        const title_width = @min(@as(u16, 120), @max(@as(u16, 24), viewport_width -| fixed_width));

        self.hn_table.setColumnWidth(0, title_width);
        self.hn_table.setColumnWidth(1, by_width);
        self.hn_table.setColumnWidth(2, score_width);
        self.hn_table.setColumnWidth(3, comments_width);
        self.populateHNTable(allocator, title_width, by_width, score_width, comments_width);
    }

    fn populateHNTable(self: *Model, allocator: std.mem.Allocator, title_width: usize, by_width: usize, score_width: usize, comments_width: usize) void {
        self.hn_table.clearRows();
        for (self.hn_stories.items.items) |story| {
            self.hn_table.addRow(.{
                truncateForWidth(allocator, story.title, title_width) catch story.title,
                truncateForWidth(allocator, story.by, by_width) catch story.by,
                truncateForWidth(allocator, story.score, score_width) catch story.score,
                truncateForWidth(allocator, story.comments, comments_width) catch story.comments,
            }) catch {};
        }
    }

    fn openSelectedHackerNews(self: *const Model, ctx: *zz.Context) void {
        const selected = self.hn_table.selectedRow();
        if (selected >= self.hn_stories.items.items.len) return;

        var child = std.process.spawn(ctx.io, .{
            .argv = &.{ "open", self.hn_stories.items.items[selected].url },
            .stdin = .ignore,
            .stdout = .ignore,
            .stderr = .ignore,
        }) catch return;
        _ = child.wait(ctx.io) catch {};
    }

    fn syncHNViewport(self: *Model) void {
        const selected = self.hn_table.selectedRow();
        const header_lines: usize = 3;
        const row_stride: usize = if (self.hn_table.show_row_borders) 2 else 1;
        const row_line = header_lines + selected * row_stride;

        if (row_line < self.hn_viewport.y_offset) {
            self.hn_viewport.scrollTo(row_line, 0);
        } else if (row_line >= self.hn_viewport.y_offset + self.hn_viewport.height) {
            self.hn_viewport.scrollTo(row_line - self.hn_viewport.height + 1, 0);
        }
    }

    fn fetchArxivTask(arg: FetchArg) ?Msg {
        const papers = arxiv.fetch(arg.allocator, arg.io) catch return .arxiv_failed;
        return .{ .arxiv_loaded = papers };
    }

    fn fetchRssTask(arg: FetchArg) ?Msg {
        const url = arg.rss_url orelse return .rss_failed;
        const items = rss.fetch(arg.allocator, arg.io, url) catch return .rss_failed;
        return .{ .rss_loaded = items };
    }

    fn handleArxivResult(self: *Model, msg: Msg) void {
        switch (msg) {
            .arxiv_loaded => |papers| {
                self.arxiv_papers.deinit();
                self.arxiv_papers = papers;
                self.arxiv_loading = false;
                self.arxiv_table.cursor_row = 0;
                self.arxiv_table.y_offset = 0;
                self.arxiv_viewport.scrollTo(0, 0);
            },
            .arxiv_failed => {
                if (!self.arxiv_loading) return;
                self.arxiv_papers.deinit();
                self.arxiv_papers = fallbackArxiv(std.heap.page_allocator) catch arxiv.PaperList.init(std.heap.page_allocator);
                self.arxiv_loading = false;
                self.arxiv_table.cursor_row = 0;
                self.arxiv_table.y_offset = 0;
                self.arxiv_viewport.scrollTo(0, 0);
            },
            else => {},
        }
    }

    fn configureArxivTable(self: *Model, allocator: std.mem.Allocator, viewport_width: u16) !void {
        const date_width: u16 = 10;
        const cat_width: u16 = 8;
        const authors_width: u16 = 18;
        const table_overhead: u16 = 16;
        const fixed_width = date_width + cat_width + authors_width + table_overhead;
        const title_width = @min(@as(u16, 120), @max(@as(u16, 24), viewport_width -| fixed_width));

        self.arxiv_table.setColumnWidth(0, title_width);
        self.arxiv_table.setColumnWidth(1, cat_width);
        self.arxiv_table.setColumnWidth(2, authors_width);
        self.arxiv_table.setColumnWidth(3, date_width);
        self.populateArxivTable(allocator, title_width, cat_width, authors_width, date_width);
    }

    fn populateArxivTable(self: *Model, allocator: std.mem.Allocator, title_width: usize, cat_width: usize, authors_width: usize, date_width: usize) void {
        self.arxiv_table.clearRows();
        for (self.arxiv_papers.items.items) |paper| {
            self.arxiv_table.addRow(.{
                truncateForWidth(allocator, paper.title, title_width) catch paper.title,
                truncateForWidth(allocator, paper.category, cat_width) catch paper.category,
                truncateForWidth(allocator, paper.authors, authors_width) catch paper.authors,
                truncateForWidth(allocator, paper.date, date_width) catch paper.date,
            }) catch {};
        }
    }

    fn openSelectedArxiv(self: *const Model, ctx: *zz.Context) void {
        const selected = self.arxiv_table.selectedRow();
        if (selected >= self.arxiv_papers.items.items.len) return;

        var child = std.process.spawn(ctx.io, .{
            .argv = &.{ "open", self.arxiv_papers.items.items[selected].url },
            .stdin = .ignore,
            .stdout = .ignore,
            .stderr = .ignore,
        }) catch return;
        _ = child.wait(ctx.io) catch {};
    }

    fn syncArxivViewport(self: *Model) void {
        const selected = self.arxiv_table.selectedRow();
        const header_lines: usize = 3;
        const row_stride: usize = if (self.arxiv_table.show_row_borders) 2 else 1;
        const row_line = header_lines + selected * row_stride;

        if (row_line < self.arxiv_viewport.y_offset) {
            self.arxiv_viewport.scrollTo(row_line, 0);
        } else if (row_line >= self.arxiv_viewport.y_offset + self.arxiv_viewport.height) {
            self.arxiv_viewport.scrollTo(row_line - self.arxiv_viewport.height + 1, 0);
        }
    }

    fn handleRssResult(self: *Model, msg: Msg) void {
        switch (msg) {
            .rss_loaded => |items| {
                for (items.items.items) |item| {
                    self.rss_items.add(item.title, item.link, item.pub_date, item.source) catch {};
                }
                const mutable_items: *rss.FeedItemList = @constCast(&items);
                mutable_items.deinit();
                self.rss_completed += 1;
                if (self.rss_completed >= self.rss_feed_count) {
                    self.sortRssItems();
                    self.rss_loading = false;
                    self.rss_table.cursor_row = 0;
                    self.rss_table.y_offset = 0;
                    self.rss_viewport.scrollTo(0, 0);
                }
            },
            .rss_failed => {
                self.rss_completed += 1;
                if (self.rss_completed >= self.rss_feed_count) {
                    if (self.rss_items.items.items.len == 0) {
                        self.rss_items = fallbackRss(std.heap.page_allocator) catch rss.FeedItemList.init(std.heap.page_allocator);
                    } else {
                        self.sortRssItems();
                    }
                    self.rss_loading = false;
                    self.rss_table.cursor_row = 0;
                    self.rss_table.y_offset = 0;
                    self.rss_viewport.scrollTo(0, 0);
                }
            },
            else => {},
        }
    }

    fn sortRssItems(self: *Model) void {
        var i: usize = 1;
        while (i < self.rss_items.items.items.len) : (i += 1) {
            var j = i;
            while (j > 0 and lessByDate(self.rss_items.items.items[j - 1], self.rss_items.items.items[j])) {
                const tmp = self.rss_items.items.items[j];
                self.rss_items.items.items[j] = self.rss_items.items.items[j - 1];
                self.rss_items.items.items[j - 1] = tmp;
                j -= 1;
            }
        }
    }

    fn lessByDate(a: rss.FeedItem, b: rss.FeedItem) bool {
        return std.mem.order(u8, a.pub_date, b.pub_date) == .lt;
    }

    fn configureRssTable(self: *Model, allocator: std.mem.Allocator, viewport_width: u16) !void {
        const source_width: u16 = 20;
        const date_width: u16 = 10;
        const table_overhead: u16 = 10;
        const fixed_width = source_width + date_width + table_overhead;
        const title_width = @min(@as(u16, 120), @max(@as(u16, 24), viewport_width -| fixed_width));

        self.rss_table.setColumnWidth(0, title_width);
        self.rss_table.setColumnWidth(1, source_width);
        self.rss_table.setColumnWidth(2, date_width);
        self.populateRssTable(allocator, title_width, source_width, date_width);
    }

    fn populateRssTable(self: *Model, allocator: std.mem.Allocator, title_width: usize, source_width: usize, date_width: usize) void {
        self.rss_table.clearRows();
        for (self.rss_items.items.items) |item| {
            self.rss_table.addRow(.{
                truncateForWidth(allocator, item.title, title_width) catch item.title,
                truncateForWidth(allocator, item.source, source_width) catch item.source,
                truncateForWidth(allocator, item.pub_date, date_width) catch item.pub_date,
            }) catch {};
        }
    }

    fn openSelectedRss(self: *const Model, ctx: *zz.Context) void {
        const selected = self.rss_table.selectedRow();
        if (selected >= self.rss_items.items.items.len) return;

        var child = std.process.spawn(ctx.io, .{
            .argv = &.{ "open", self.rss_items.items.items[selected].link },
            .stdin = .ignore,
            .stdout = .ignore,
            .stderr = .ignore,
        }) catch return;
        _ = child.wait(ctx.io) catch {};
    }

    fn syncRssViewport(self: *Model) void {
        const selected = self.rss_table.selectedRow();
        const header_lines: usize = 3;
        const row_stride: usize = if (self.rss_table.show_row_borders) 2 else 1;
        const row_line = header_lines + selected * row_stride;

        if (row_line < self.rss_viewport.y_offset) {
            self.rss_viewport.scrollTo(row_line, 0);
        } else if (row_line >= self.rss_viewport.y_offset + self.rss_viewport.height) {
            self.rss_viewport.scrollTo(row_line - self.rss_viewport.height + 1, 0);
        }
    }

    fn openSelectedTrendingRepo(self: *const Model, ctx: *zz.Context) void {
        const selected = self.trending_repos_table.selectedRow();
        if (selected >= self.trending_repos.items.items.len) return;

        var child = std.process.spawn(ctx.io, .{
            .argv = &.{ "open", self.trending_repos.items.items[selected].url },
            .stdin = .ignore,
            .stdout = .ignore,
            .stderr = .ignore,
        }) catch return;
        _ = child.wait(ctx.io) catch {};
    }

    fn syncTrendingReposViewport(self: *Model) void {
        const selected = self.trending_repos_table.selectedRow();
        const header_lines: usize = 3;
        const row_stride: usize = if (self.trending_repos_table.show_row_borders) 2 else 1;
        const row_line = header_lines + selected * row_stride;

        if (row_line < self.trending_repos_viewport.y_offset) {
            self.trending_repos_viewport.scrollTo(row_line, 0);
        } else if (row_line >= self.trending_repos_viewport.y_offset + self.trending_repos_viewport.height) {
            self.trending_repos_viewport.scrollTo(row_line - self.trending_repos_viewport.height + 1, 0);
        }
    }

    pub fn view(self: *const Model, ctx: *const zz.Context) []const u8 {
        const tab_bar = self.renderTabBar(ctx) catch return "Error rendering tab bar";
        const content = self.renderContent(ctx) catch return "Error rendering content";
        const status = self.renderStatusBar(ctx) catch return "Error rendering status";

        const confirm_view = if (self.show_quit_confirm)
            self.confirm.view(ctx.allocator) catch ""
        else
            "";

        const main_view = if (self.show_quit_confirm)
            zz.joinVertical(ctx.allocator, &.{ tab_bar, "", content, "", confirm_view, "", status }) catch tab_bar
        else
            zz.joinVertical(ctx.allocator, &.{ tab_bar, "", content, "", status }) catch tab_bar;

        return zz.place.place(
            ctx.allocator,
            ctx.width,
            ctx.height,
            .center,
            .top,
            main_view,
        ) catch main_view;
    }

    fn renderTabBar(self: *const Model, ctx: *const zz.Context) ![]const u8 {
        const tabs = [_]Tab{
            .trendingRepos,
            .hackernews,
            .productHunt,
            .arxiv,
            .rss,
        };

        const content_width: usize = panelWidth(ctx) -| 4;
        const slot_base = content_width / tabs.len;
        const extra_slots = content_width % tabs.len;
        var slots: [tabs.len][]const u8 = undefined;

        for (tabs, 0..) |tab, i| {
            const label = try std.fmt.allocPrint(
                ctx.allocator,
                "{d}:{s}",
                .{ i + 1, tab.name() },
            );

            const slot_width = slot_base + if (i < extra_slots) @as(usize, 1) else 0;

            if (tab == self.active_tab) {
                var active_style = zz.Style{};
                active_style = active_style
                    .bold(true)
                    .fg(zz.Color.hex("#4ECDC4"))
                    .underline(true)
                    .inline_style(true);

                const styled = try active_style.render(ctx.allocator, label);
                slots[i] = try zz.placeHorizontal(ctx.allocator, slot_width, .center, styled);
            } else {
                var tab_style = zz.Style{};
                tab_style = tab_style
                    .fg(zz.Color.gray(12))
                    .inline_style(true);

                const styled = try tab_style.render(ctx.allocator, label);
                slots[i] = try zz.placeHorizontal(ctx.allocator, slot_width, .center, styled);
            }
        }

        const bar_content = try zz.joinHorizontal(ctx.allocator, &slots);

        var bar_style = zz.Style{};
        bar_style = bar_style
            .borderAll(zz.Border.rounded)
            .borderForeground(zz.Color.gray(8))
            .paddingLeft(1)
            .paddingRight(1)
            .width(panelWidth(ctx));

        return bar_style.render(ctx.allocator, bar_content);
    }

    fn renderContent(self: *const Model, ctx: *const zz.Context) ![]const u8 {
        return switch (self.active_tab) {
            .trendingRepos => self.renderTrendingRepos(ctx),
            .hackernews => self.renderHackerNews(ctx),
            .productHunt => self.renderProductHunt(ctx),
            .arxiv => self.renderArxiv(ctx),
            .rss => self.renderRss(ctx),
        };
    }

    fn renderTrendingRepos(self: *const Model, ctx: *const zz.Context) ![]const u8 {
        var title_style = zz.Style{};
        title_style = title_style
            .bold(true)
            .fg(zz.Color.white)
            .inline_style(true);

        const title = try title_style.render(ctx.allocator, self.active_tab.name());
        const mutable_self: *Model = @constCast(self);
        const content_body = if (self.trending_loading) blk: {
            const loading = try self.spinner.viewWithTitle(ctx.allocator, "Loading trending repositories...");
            break :blk zz.place.place(ctx.allocator, panelWidth(ctx) -| 6, viewportHeight(ctx), .center, .middle, loading) catch loading;
        } else blk: {
            const viewport_width = panelWidth(ctx) -| 6;
            mutable_self.trending_repos_viewport.setSize(viewport_width, viewportHeight(ctx));
            try mutable_self.configureTrendingReposTable(ctx.allocator, viewport_width -| 1);
            const table_content = try self.trending_repos_table.view(ctx.allocator);
            try mutable_self.trending_repos_viewport.setContent(table_content);
            break :blk try mutable_self.trending_repos_viewport.view(ctx.allocator);
        };

        var help_style = zz.Style{};
        help_style = help_style
            .fg(zz.Color.gray(10))
            .inline_style(true);

        const help_text = if (self.trending_loading)
            "Fetching live OSS Insight data..."
        else
            try std.fmt.allocPrint(
                ctx.allocator,
                "j/k Up/Down: select  PgUp/PgDn: page  g/G: ends  Enter: open  {d}/{d}",
                .{ self.trending_repos_table.selectedRow() + 1, self.trending_repos_table.rows.items.len },
            );
        const help = try help_style.render(ctx.allocator, help_text);

        var box_style = zz.Style{};
        box_style = box_style
            .borderAll(zz.Border.rounded)
            .borderForeground(zz.Color.gray(8))
            .paddingAll(1)
            .width(panelWidth(ctx));

        const content = try std.fmt.allocPrint(
            ctx.allocator,
            "{s}\n\n{s}\n\n{s}",
            .{ title, content_body, help },
        );

        return box_style.render(ctx.allocator, content);
    }

    fn renderHackerNews(self: *const Model, ctx: *const zz.Context) ![]const u8 {
        var title_style = zz.Style{};
        title_style = title_style
            .bold(true)
            .fg(zz.Color.white)
            .inline_style(true);

        const title = try title_style.render(ctx.allocator, self.active_tab.name());
        const mutable_self: *Model = @constCast(self);
        const content_body = if (self.hn_loading) blk: {
            const loading = try self.spinner.viewWithTitle(ctx.allocator, "Loading Hacker News stories...");
            break :blk zz.place.place(ctx.allocator, panelWidth(ctx) -| 6, viewportHeight(ctx), .center, .middle, loading) catch loading;
        } else blk: {
            const viewport_width = panelWidth(ctx) -| 6;
            mutable_self.hn_viewport.setSize(viewport_width, viewportHeight(ctx));
            try mutable_self.configureHNTable(ctx.allocator, viewport_width -| 1);
            const table_content = try self.hn_table.view(ctx.allocator);
            try mutable_self.hn_viewport.setContent(table_content);
            break :blk try mutable_self.hn_viewport.view(ctx.allocator);
        };

        var help_style = zz.Style{};
        help_style = help_style
            .fg(zz.Color.gray(10))
            .inline_style(true);

        const help_text = if (self.hn_loading)
            "Fetching top stories from Hacker News..."
        else
            try std.fmt.allocPrint(
                ctx.allocator,
                "j/k Up/Down: select  PgUp/PgDn: page  g/G: ends  Enter: open  {d}/{d}",
                .{ self.hn_table.selectedRow() + 1, self.hn_table.rows.items.len },
            );
        const help = try help_style.render(ctx.allocator, help_text);

        var box_style = zz.Style{};
        box_style = box_style
            .borderAll(zz.Border.rounded)
            .borderForeground(zz.Color.gray(8))
            .paddingAll(1)
            .width(panelWidth(ctx));

        const content = try std.fmt.allocPrint(
            ctx.allocator,
            "{s}\n\n{s}\n\n{s}",
            .{ title, content_body, help },
        );

        return box_style.render(ctx.allocator, content);
    }

    fn renderProductHunt(self: *const Model, ctx: *const zz.Context) ![]const u8 {
        var title_style = zz.Style{};
        title_style = title_style
            .bold(true)
            .fg(zz.Color.white)
            .inline_style(true);

        const title = try title_style.render(ctx.allocator, self.active_tab.name());
        const mutable_self: *Model = @constCast(self);

        const content_body = if (self.ph_disabled) blk: {
            var msg_style = zz.Style{};
            msg_style = msg_style
                .fg(zz.Color.gray(12))
                .inline_style(true);
            const msg = try msg_style.render(ctx.allocator, "Set PRODUCT_HUNT_TOKEN environment variable to enable");
            break :blk zz.place.place(ctx.allocator, panelWidth(ctx) -| 6, viewportHeight(ctx), .center, .middle, msg) catch msg;
        } else if (self.ph_loading) blk: {
            const loading = try self.spinner.viewWithTitle(ctx.allocator, "Loading Product Hunt posts...");
            break :blk zz.place.place(ctx.allocator, panelWidth(ctx) -| 6, viewportHeight(ctx), .center, .middle, loading) catch loading;
        } else blk: {
            const viewport_width = panelWidth(ctx) -| 6;
            mutable_self.ph_viewport.setSize(viewport_width, viewportHeight(ctx));
            try mutable_self.configurePhTable(ctx.allocator, viewport_width -| 1);
            const table_content = try self.ph_table.view(ctx.allocator);
            try mutable_self.ph_viewport.setContent(table_content);
            break :blk try mutable_self.ph_viewport.view(ctx.allocator);
        };

        var help_style = zz.Style{};
        help_style = help_style
            .fg(zz.Color.gray(10))
            .inline_style(true);

        const help_text = if (self.ph_disabled)
            ""
        else if (self.ph_loading)
            "Fetching featured products..."
        else
            try std.fmt.allocPrint(
                ctx.allocator,
                "j/k Up/Down: select  PgUp/PgDn: page  g/G: ends  Enter: open  {d}/{d}",
                .{ self.ph_table.selectedRow() + 1, self.ph_table.rows.items.len },
            );
        const help = try help_style.render(ctx.allocator, help_text);

        var box_style = zz.Style{};
        box_style = box_style
            .borderAll(zz.Border.rounded)
            .borderForeground(zz.Color.gray(8))
            .paddingAll(1)
            .width(panelWidth(ctx));

        const content = try std.fmt.allocPrint(
            ctx.allocator,
            "{s}\n\n{s}\n\n{s}",
            .{ title, content_body, help },
        );

        return box_style.render(ctx.allocator, content);
    }

    fn renderArxiv(self: *const Model, ctx: *const zz.Context) ![]const u8 {
        var title_style = zz.Style{};
        title_style = title_style
            .bold(true)
            .fg(zz.Color.white)
            .inline_style(true);

        const title = try title_style.render(ctx.allocator, self.active_tab.name());
        const mutable_self: *Model = @constCast(self);
        const content_body = if (self.arxiv_loading) blk: {
            const loading = try self.spinner.viewWithTitle(ctx.allocator, "Loading ArXiv papers...");
            break :blk zz.place.place(ctx.allocator, panelWidth(ctx) -| 6, viewportHeight(ctx), .center, .middle, loading) catch loading;
        } else blk: {
            const viewport_width = panelWidth(ctx) -| 6;
            mutable_self.arxiv_viewport.setSize(viewport_width, viewportHeight(ctx));
            try mutable_self.configureArxivTable(ctx.allocator, viewport_width -| 1);
            const table_content = try self.arxiv_table.view(ctx.allocator);
            try mutable_self.arxiv_viewport.setContent(table_content);
            break :blk try mutable_self.arxiv_viewport.view(ctx.allocator);
        };

        var help_style = zz.Style{};
        help_style = help_style
            .fg(zz.Color.gray(10))
            .inline_style(true);

        const help_text = if (self.arxiv_loading)
            "Fetching papers from cs.AI, cs.LG, cs.CL, cs.CV, cs.SE, cs.DS..."
        else
            try std.fmt.allocPrint(
                ctx.allocator,
                "j/k Up/Down: select  PgUp/PgDn: page  g/G: ends  Enter: open  {d}/{d}",
                .{ self.arxiv_table.selectedRow() + 1, self.arxiv_table.rows.items.len },
            );
        const help = try help_style.render(ctx.allocator, help_text);

        var box_style = zz.Style{};
        box_style = box_style
            .borderAll(zz.Border.rounded)
            .borderForeground(zz.Color.gray(8))
            .paddingAll(1)
            .width(panelWidth(ctx));

        const content = try std.fmt.allocPrint(
            ctx.allocator,
            "{s}\n\n{s}\n\n{s}",
            .{ title, content_body, help },
        );

        return box_style.render(ctx.allocator, content);
    }

    fn renderRss(self: *const Model, ctx: *const zz.Context) ![]const u8 {
        var title_style = zz.Style{};
        title_style = title_style
            .bold(true)
            .fg(zz.Color.white)
            .inline_style(true);

        const title = try title_style.render(ctx.allocator, self.active_tab.name());
        const mutable_self: *Model = @constCast(self);
        const content_body = if (self.rss_loading) blk: {
            const loading = try self.spinner.viewWithTitle(ctx.allocator, "Loading RSS feeds...");
            break :blk zz.place.place(ctx.allocator, panelWidth(ctx) -| 6, viewportHeight(ctx), .center, .middle, loading) catch loading;
        } else blk: {
            const viewport_width = panelWidth(ctx) -| 6;
            mutable_self.rss_viewport.setSize(viewport_width, viewportHeight(ctx));
            try mutable_self.configureRssTable(ctx.allocator, viewport_width -| 1);
            const table_content = try self.rss_table.view(ctx.allocator);
            try mutable_self.rss_viewport.setContent(table_content);
            break :blk try mutable_self.rss_viewport.view(ctx.allocator);
        };

        var help_style = zz.Style{};
        help_style = help_style
            .fg(zz.Color.gray(10))
            .inline_style(true);

        const help_text = if (self.rss_loading)
            "Fetching RSS feeds..."
        else
            try std.fmt.allocPrint(
                ctx.allocator,
                "j/k Up/Down: select  PgUp/PgDn: page  g/G: ends  Enter: open  {d}/{d}",
                .{ self.rss_table.selectedRow() + 1, self.rss_table.rows.items.len },
            );
        const help = try help_style.render(ctx.allocator, help_text);

        var box_style = zz.Style{};
        box_style = box_style
            .borderAll(zz.Border.rounded)
            .borderForeground(zz.Color.gray(8))
            .paddingAll(1)
            .width(panelWidth(ctx));

        const content = try std.fmt.allocPrint(
            ctx.allocator,
            "{s}\n\n{s}\n\n{s}",
            .{ title, content_body, help },
        );

        return box_style.render(ctx.allocator, content);
    }
    fn renderStatusBar(self: *const Model, ctx: *const zz.Context) ![]const u8 {
        _ = self;

        var help_comp = zz.components.Help.init(ctx.allocator);
        defer help_comp.deinit();

        try help_comp.addBinding("1-5", "tabs");
        try help_comp.addBinding("Tab", "next");
        try help_comp.addBinding("Shift+Tab", "previous");
        try help_comp.addBinding("q", "quit");

        help_comp.setMaxWidth(ctx.width);

        const help_view = try help_comp.view(ctx.allocator);

        var status_style = zz.Style{};
        status_style = status_style
            .borderAll(zz.Border.rounded)
            .borderForeground(zz.Color.gray(6))
            .paddingLeft(1)
            .paddingRight(1)
            .width(panelWidth(ctx));

        return status_style.render(ctx.allocator, help_view);
    }

    pub fn deinit(self: *Model) void {
        self.runner.deinit();
        self.trending_repos_table.deinit();
        self.trending_repos_viewport.deinit();
        self.trending_repos.deinit();
        self.ph_table.deinit();
        self.ph_viewport.deinit();
        self.ph_posts.deinit();
        self.hn_table.deinit();
        self.hn_viewport.deinit();
        self.hn_stories.deinit();
        self.arxiv_table.deinit();
        self.arxiv_viewport.deinit();
        self.arxiv_papers.deinit();
        self.rss_table.deinit();
        self.rss_viewport.deinit();
        self.rss_items.deinit();
        self.config.deinit();
    }
};

pub fn main(init: std.process.Init) !void {
    product_hunt_token = init.environ_map.get("PRODUCT_HUNT_TOKEN");

    var program = zz.Program(Model).initWithOptions(init.gpa, init.io, init.environ_map, .{
        .mouse = true,
        .title = "Carbonara",
    });

    defer program.deinit();

    try program.run();
}
