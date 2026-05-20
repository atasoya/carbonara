const std = @import("std");

fn findOpenTagStart(xml: []const u8, tag: []const u8) ?usize {
    var i: usize = 0;
    while (i < xml.len) : (i += 1) {
        if (xml[i] != '<') continue;
        const rest = xml[i + 1 ..];
        if (std.mem.indexOfScalar(u8, rest, ':')) |colon| {
            if (std.mem.startsWith(u8, rest[colon + 1 ..], tag)) {
                const after = rest[colon + 1 + tag.len ..];
                if (after.len == 0 or after[0] == '>' or after[0] == ' ' or after[0] == '/') return i;
            }
        }
        if (std.mem.startsWith(u8, rest, tag)) {
            const after = rest[tag.len..];
            if (after.len == 0 or after[0] == '>' or after[0] == ' ' or after[0] == '/') return i;
        }
    }
    return null;
}

fn findCloseTagStart(xml: []const u8, tag: []const u8) ?usize {
    var i: usize = 0;
    while (i < xml.len) : (i += 1) {
        if (xml[i] != '<') continue;
        if (i + 1 >= xml.len) continue;
        if (xml[i + 1] != '/') continue;
        const rest = xml[i + 2 ..];
        if (std.mem.indexOfScalar(u8, rest, ':')) |colon| {
            if (std.mem.startsWith(u8, rest[colon + 1 ..], tag)) {
                const after = rest[colon + 1 + tag.len ..];
                if (after.len > 0 and after[0] == '>') return i;
            }
        }
        if (std.mem.startsWith(u8, rest, tag)) {
            const after = rest[tag.len..];
            if (after.len > 0 and after[0] == '>') return i;
        }
    }
    return null;
}

pub fn childText(xml: []const u8, tag: []const u8) ?[]const u8 {
    const open_start = findOpenTagStart(xml, tag) orelse return null;
    const gt = std.mem.indexOfScalar(u8, xml[open_start..], '>') orelse return null;
    const content_start = open_start + gt + 1;
    const close_start = findCloseTagStart(xml[content_start..], tag) orelse return null;
    return xml[content_start..][0..close_start];
}

pub fn childTexts(xml: []const u8, tag: []const u8, allocator: std.mem.Allocator) ![][]const u8 {
    var count: usize = 0;
    var pos: usize = 0;
    while (true) {
        const text = childText(xml[pos..], tag) orelse break;
        count += 1;
        const offset = @intFromPtr(text.ptr) - @intFromPtr(xml.ptr);
        const abs_text_end = offset + text.len;
        const gt = std.mem.indexOfScalar(u8, xml[abs_text_end..], '>') orelse break;
        pos = abs_text_end + gt + 1;
    }

    var result = try allocator.alloc([]const u8, count);
    errdefer allocator.free(result);

    var idx: usize = 0;
    pos = 0;
    while (idx < count) {
        const text = childText(xml[pos..], tag) orelse break;
        result[idx] = text;
        idx += 1;
        const offset = @intFromPtr(text.ptr) - @intFromPtr(xml.ptr);
        const abs_text_end = offset + text.len;
        const gt = std.mem.indexOfScalar(u8, xml[abs_text_end..], '>') orelse break;
        pos = abs_text_end + gt + 1;
    }

    return result;
}

pub fn attrValue(xml: []const u8, tag: []const u8, attr: []const u8) ?[]const u8 {
    const open_start = findOpenTagStart(xml, tag) orelse return null;
    const gt_rel = std.mem.indexOfScalar(u8, xml[open_start..], '>') orelse return null;
    const open_tag_text = xml[open_start..][0..gt_rel];

    var dq_buf: [256]u8 = undefined;
    const dq_pattern = std.fmt.bufPrint(&dq_buf, "{s}=\"", .{attr}) catch return null;
    if (std.mem.indexOf(u8, open_tag_text, dq_pattern)) |attr_start| {
        const val_start = attr_start + dq_pattern.len;
        const end = std.mem.indexOfScalar(u8, open_tag_text[val_start..], '"') orelse return null;
        return open_tag_text[val_start..][0..end];
    }

    var sq_buf: [256]u8 = undefined;
    const sq_pattern = std.fmt.bufPrint(&sq_buf, "{s}='", .{attr}) catch return null;
    if (std.mem.indexOf(u8, open_tag_text, sq_pattern)) |attr_start| {
        const val_start = attr_start + sq_pattern.len;
        const end = std.mem.indexOfScalar(u8, open_tag_text[val_start..], '\'') orelse return null;
        return open_tag_text[val_start..][0..end];
    }

    return null;
}

pub fn entries(xml: []const u8, tag: []const u8, allocator: std.mem.Allocator) ![][]const u8 {
    var count: usize = 0;
    var pos: usize = 0;
    while (true) {
        const open_start = findOpenTagStart(xml[pos..], tag) orelse break;
        const abs_open = pos + open_start;
        const gt = std.mem.indexOfScalar(u8, xml[abs_open..], '>') orelse break;
        const content_start = abs_open + gt + 1;
        const close_start = findCloseTagStart(xml[content_start..], tag) orelse break;
        count += 1;
        const abs_close_start = content_start + close_start;
        const close_gt = std.mem.indexOfScalar(u8, xml[abs_close_start..], '>') orelse break;
        pos = abs_close_start + close_gt + 1;
    }

    var result = try allocator.alloc([]const u8, count);
    errdefer allocator.free(result);

    var idx: usize = 0;
    pos = 0;
    while (idx < count) {
        const open_start = findOpenTagStart(xml[pos..], tag) orelse break;
        const abs_open = pos + open_start;
        const gt = std.mem.indexOfScalar(u8, xml[abs_open..], '>') orelse break;
        const content_start = abs_open + gt + 1;
        const close_start = findCloseTagStart(xml[content_start..], tag) orelse break;
        result[idx] = xml[content_start..][0..close_start];
        idx += 1;
        const abs_close_start = content_start + close_start;
        const close_gt = std.mem.indexOfScalar(u8, xml[abs_close_start..], '>') orelse break;
        pos = abs_close_start + close_gt + 1;
    }

    return result;
}

pub fn decodeEntities(allocator: std.mem.Allocator, text: []const u8) ![]const u8 {
    if (std.mem.indexOfScalar(u8, text, '&') == null) return try allocator.dupe(u8, text);

    var result = try allocator.alloc(u8, text.len);
    errdefer allocator.free(result);

    var out: usize = 0;
    var i: usize = 0;
    while (i < text.len) : (i += 1) {
        if (text[i] == '&') {
            const semi = std.mem.indexOfScalar(u8, text[i..], ';') orelse {
                result[out] = text[i];
                out += 1;
                continue;
            };
            const entity = text[i + 1 ..][0..semi];
            if (std.mem.eql(u8, entity, "amp")) {
                result[out] = '&';
                out += 1;
                i += semi;
                continue;
            }
            if (std.mem.eql(u8, entity, "lt")) {
                result[out] = '<';
                out += 1;
                i += semi;
                continue;
            }
            if (std.mem.eql(u8, entity, "gt")) {
                result[out] = '>';
                out += 1;
                i += semi;
                continue;
            }
            if (std.mem.eql(u8, entity, "apos")) {
                result[out] = '\'';
                out += 1;
                i += semi;
                continue;
            }
            if (std.mem.eql(u8, entity, "quot")) {
                result[out] = '"';
                out += 1;
                i += semi;
                continue;
            }
            @memcpy(result[out..][0 .. semi + 1], text[i..][0 .. semi + 1]);
            out += semi + 1;
            i += semi;
        } else {
            result[out] = text[i];
            out += 1;
        }
    }

    return result[0..out];
}
