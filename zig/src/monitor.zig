const std = @import("std");
const mem = std.mem;
const cfg = @import("config.zig");

const lt = @import("layout.zig");
const Layout = lt.Layout;
const Client = @import("client.zig").Client;

const x = @import("c_lib.zig").x;
const Allocator = std.mem.Allocator;

const Window = x.Window;

pub const Monitor = struct {
    const Self = @This();
    /// A fixed-sized buffer to represent the current layout.
    layout_symbol: [16]u8,
    /// Master window factor.
    mfact: f32,
    /// Number of master windows.
    nmaster: i32,

    num: i32,
    // Bar geometry.
    by: i32,
    // Screen size: x-coordinate.
    mx: i32,
    // Screen size: y-coordinate.
    my: i32,
    // Screen size: width.
    mw: u32,
    // Screen size: height.
    mh: u32,
    // Window area: x-coordinate.
    wx: i32,
    // Window area: y-coordinate.
    wy: i32,
    // Window area: width.
    ww: u32,
    // Window area: height.
    wh: u32,
    // Index of selected tags.
    seltags: u16,
    // Index of selected layout.
    sellt: usize,
    tagset: [2]usize,
    // false means hide bar.
    show_bar: bool,
    // false means bottom bar.
    top_bar: bool,
    // Linked list of clients.
    clients: ?*Client,
    // Selected client
    sel: ?*Client,
    // Clients ordered by stack.
    stack: ?*Client,

    next: ?*Self,
    barwin: Window,
    lt: *[2]Layout,

    /// [dwm] createmon
    pub fn init(allocator: Allocator) error{OutOfMemory}!*Self {
        var m = try allocator.create(Self);
        m.tagset[0] = 1;
        m.tagset[1] = 1;
        m.mfact = cfg.mfact;
        m.nmaster = cfg.nmaster;
        m.show_bar = cfg.show_bar;
        m.top_bar = cfg.top_bar;
        m.lt[0] = cfg.layouts[0];
        m.lt[1] = cfg.layouts[1 % cfg.layouts.len];
        const n = @min(m.lt[0].symbol.len, m.layout_symbol.len);
        @memcpy(m.layout_symbol[0..n], m.lt[0].symbol[0..n]);
        return m;
    }
};
