const std = @import("std");
const cfg = @import("config.zig");

const Layout = @import("layout.zig").Layout;
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
    mw: i32,
    // Screen size: height.
    mh: i32,
    // Window area: x-coordinate.
    wx: i32,
    // Window area: y-coordinate.
    wy: i32,
    // Window area: width.
    ww: i32,
    // Window area: height.
    wh: i32,
    // Index of selected tags.
    seltags: u16,
    // Index of selected layout.
    sellt: usize,
    tagset: [2]usize,
    // false means hide bar.
    show_bar: bool,
    // false means bottom bar.
    topbar: bool,
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
        // m->lt[0] = &layouts[0];
        // m->lt[1] = &layouts[1 % LENGTH(layouts)];
        // strncpy(m->ltsymbol, layouts[0].symbol, sizeof m->ltsymbol);
        return m;
    }
};
