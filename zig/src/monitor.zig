const std = @import("std");
const mem = std.mem;
const cfg = @import("config.zig");

const lt = @import("layout.zig");
const Layout = lt.Layout;
const Client = @import("client.zig").Client;

const X = @import("c_lib.zig").X;
const Allocator = std.mem.Allocator;

const Window = X.Window;

pub const Monitor = struct {
    const Self = @This();
    /// A string to represent the current layout.
    layout_symbol: []const u8 = undefined,
    /// Master window factor.
    mfact: f32 = cfg.mfact,
    /// Number of master windows.
    nmaster: i32 = cfg.nmaster,

    num: i32 = undefined,
    /// Bar geometry.
    by: i32 = undefined,
    /// Screen size: x-coordinate.
    mx: i32 = undefined,
    /// Screen size: y-coordinate.
    my: i32 = undefined,
    /// Screen size: width.
    mw: u32 = undefined,
    /// Screen size: height.
    mh: u32 = undefined,
    /// Window area: x-coordinate.
    wx: i32 = undefined,
    /// Window area: y-coordinate.
    wy: i32 = undefined,
    /// Window area: width.
    ww: u32 = undefined,
    /// Window area: height.
    wh: u32 = undefined,
    /// Index of selected tags.
    seltags: u1 = 0,
    /// Index of selected layout.
    sellt: usize = undefined,
    /// A couple of bitmasks, only ever to be indexed by `seltags`.
    tagset: [2]u32 = .{ 1, 1 },
    /// false means hide bar.
    show_bar: bool = cfg.show_bar,
    /// false means bottom bar.
    top_bar: bool = cfg.top_bar,
    /// Linked list of clients.
    clients: ?*Client = null,
    /// Selected client
    sel: ?*Client = null,
    /// Clients ordered by stack.
    stack: ?*Client = null,

    next: ?*Self = null,
    barwin: Window = undefined,
    lt: [2]*const Layout = .{
        &cfg.layouts[0],
        &cfg.layouts[1 % cfg.layouts.len],
    },

    /// [dwm] createmon
    pub fn init(allocator: Allocator) error{OutOfMemory}!*Self {
        var m = try allocator.create(Self);
        m.* = .{};
        m.layout_symbol = m.lt[0].symbol;
        std.log.info("Initialized a monitor!", .{});
        return m;
    }

    /// Checks if the currently selected client.
    pub fn tagMaskIsActive(self: *Self, mask: u32) bool {
        const sel = self.sel orelse return false;
        return (sel.tags & mask) != 0;
    }
};
