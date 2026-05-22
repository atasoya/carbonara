pub const max_panel_width = 140;

pub fn panelWidth(terminal_width: u16) u16 {
    return @min(terminal_width -| 2, @as(u16, max_panel_width));
}

pub fn viewportHeight(terminal_height: u16) u16 {
    return @max(@as(u16, 5), @min(terminal_height -| 14, @as(u16, 18)));
}
