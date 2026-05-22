pub const Tab = enum {
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

pub fn next(tab: Tab) Tab {
    return switch (tab) {
        .trendingRepos => .hackernews,
        .hackernews => .productHunt,
        .productHunt => .arxiv,
        .arxiv => .rss,
        .rss => .trendingRepos,
    };
}

pub fn previous(tab: Tab) Tab {
    return switch (tab) {
        .trendingRepos => .rss,
        .hackernews => .trendingRepos,
        .productHunt => .hackernews,
        .arxiv => .productHunt,
        .rss => .arxiv,
    };
}
