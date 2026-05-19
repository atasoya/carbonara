const std = @import("std");
const Writer = std.Io.Writer;
const zz = @import("zigzag");

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
    show_quit_confirm: bool,

    pub const Msg = union(enum) {
        key: zz.KeyEvent,
        tick: zz.msg.Tick,
        window_size: struct { width: u16, height: u16 },
    };

    pub fn init(self: *Model, ctx: *zz.Context) zz.Cmd(Msg) {
        _ = ctx;

        self.active_tab = .trendingRepos;
        self.confirm = zz.Confirm.init("Are you sure you want to quit?");
        self.show_quit_confirm = false;

        return .none;
    }

    pub fn update(self: *Model, msg: Msg, ctx: *zz.Context) zz.Cmd(Msg) {
        _ = ctx;

        switch (msg) {
            .tick => return .none,
            .window_size => return .none,

            .key => |k| {
                if (self.show_quit_confirm) {
                    self.confirm.handleKey(k);

                    if (self.confirm.result()) |confirmed| {
                        self.show_quit_confirm = false;
                        if (confirmed) return .quit;
                    }

                    return .none;
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
        var result: Writer.Allocating = .init(ctx.allocator);
        const writer = &result.writer;

        const tabs = [_]Tab{
            .trendingRepos,
            .hackernews,
            .productHunt,
            .arxiv,
            .rss,
        };

        for (tabs, 0..) |tab, i| {
            if (i > 0) try writer.writeAll("  ");

            const label = try std.fmt.allocPrint(
                ctx.allocator,
                "{d}:{s}",
                .{ i + 1, tab.name() },
            );

            if (tab == self.active_tab) {
                var active_style = zz.Style{};
                active_style = active_style
                    .bold(true)
                    .fg(zz.Color.hex("#4ECDC4"))
                    .underline(true)
                    .inline_style(true);

                const styled = try active_style.render(ctx.allocator, label);
                try writer.writeAll(styled);
            } else {
                var tab_style = zz.Style{};
                tab_style = tab_style
                    .fg(zz.Color.gray(12))
                    .inline_style(true);

                const styled = try tab_style.render(ctx.allocator, label);
                try writer.writeAll(styled);
            }
        }

        const bar_content = try result.toOwnedSlice();

        var bar_style = zz.Style{};
        bar_style = bar_style
            .borderAll(zz.Border.rounded)
            .borderForeground(zz.Color.gray(8))
            .paddingLeft(1)
            .paddingRight(1)
            .width(@min(ctx.width -| 2, 69));

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

        var box_style = zz.Style{};
        box_style = box_style
            .borderAll(zz.Border.rounded)
            .borderForeground(zz.Color.gray(8))
            .paddingAll(1)
            .width(@min(ctx.width -| 2, 69));

        const content = try std.fmt.allocPrint(
            ctx.allocator,
            "{s}\n\nTrending repositories will be shown here.",
            .{title},
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
            .width(@min(ctx.width -| 2, 69));

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
            .width(@min(ctx.width -| 2, 69));

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
            .width(@min(ctx.width -| 2, 69));

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
            .width(@min(ctx.width -| 2, 69));

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

        try help_comp.addBinding("1-6", "tabs");
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
            .width(@min(ctx.width -| 2, 69));

        return status_style.render(ctx.allocator, help_view);
    }

    pub fn deinit(self: *Model) void {
        _ = self;
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
