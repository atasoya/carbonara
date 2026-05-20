const std = @import("std");
const Writer = std.Io.Writer;
const zz = @import("zigzag");
const trending = @import("trending.zig");

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
    spinner: zz.Spinner,
    runner: zz.AsyncRunner(Msg),
    show_quit_confirm: bool,

    pub const Msg = union(enum) {
        key: zz.KeyEvent,
        tick: zz.msg.Tick,
        window_size: struct { width: u16, height: u16 },
        trending_loaded: trending.RepoList,
        trending_failed,
    };

    const FetchArg = struct {
        allocator: std.mem.Allocator,
        io: std.Io,
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
        self.spinner = zz.Spinner.init();
        self.runner = zz.AsyncRunner(Msg).init(std.heap.page_allocator);
        _ = self.runner.spawnWithArg(FetchArg, .{ .allocator = std.heap.page_allocator, .io = ctx.io }, fetchTrendingTask);
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
                    self.handleTrendingResult(result);
                }
                return .none;
            },
            .window_size => return .none,
            .trending_loaded, .trending_failed => {
                self.handleTrendingResult(msg);
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

        var box_style = zz.Style{};
        box_style = box_style
            .borderAll(zz.Border.rounded)
            .borderForeground(zz.Color.gray(8))
            .paddingAll(1)
            .width(panelWidth(ctx));

        const content = try std.fmt.allocPrint(
            ctx.allocator,
            "{s}\n\nTop Hacker News stories will be shown here.",
            .{title},
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

        var box_style = zz.Style{};
        box_style = box_style
            .borderAll(zz.Border.rounded)
            .borderForeground(zz.Color.gray(8))
            .paddingAll(1)
            .width(panelWidth(ctx));

        const content = try std.fmt.allocPrint(
            ctx.allocator,
            "{s}\n\nProduct Hunt launches will be shown here.",
            .{title},
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

        var box_style = zz.Style{};
        box_style = box_style
            .borderAll(zz.Border.rounded)
            .borderForeground(zz.Color.gray(8))
            .paddingAll(1)
            .width(panelWidth(ctx));

        const content = try std.fmt.allocPrint(
            ctx.allocator,
            "{s}\n\nLatest ArXiv papers will be shown here.",
            .{title},
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

        var box_style = zz.Style{};
        box_style = box_style
            .borderAll(zz.Border.rounded)
            .borderForeground(zz.Color.gray(8))
            .paddingAll(1)
            .width(panelWidth(ctx));

        const content = try std.fmt.allocPrint(
            ctx.allocator,
            "{s}\n\nRSS feed items will be shown here.",
            .{title},
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
    }
};

pub fn main(init: std.process.Init) !void {
    var program = zz.Program(Model).initWithOptions(init.gpa, init.io, init.environ_map, .{
        .mouse = true,
        .title = "Carbonara",
    });

    defer program.deinit();

    try program.run();
}
