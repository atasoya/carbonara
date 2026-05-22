const std = @import("std");
const zz = @import("zigzag");
const tabs_mod = @import("../tabs.zig");
const layout = @import("layout.zig");

const Tab = tabs_mod.Tab;

pub fn renderTabBar(ctx: *const zz.Context, active_tab: Tab) ![]const u8 {
    const tabs = [_]Tab{
        .trendingRepos,
        .hackernews,
        .productHunt,
        .arxiv,
        .rss,
    };

    const content_width: usize = layout.panelWidth(ctx.width) -| 4;
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

        if (tab == active_tab) {
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
        .width(layout.panelWidth(ctx.width));

    return bar_style.render(ctx.allocator, bar_content);
}

pub fn renderStatusBar(ctx: *const zz.Context) ![]const u8 {
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
        .width(layout.panelWidth(ctx.width));

    return status_style.render(ctx.allocator, help_view);
}
