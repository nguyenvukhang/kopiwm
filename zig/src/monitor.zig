const std = @import("std");
const mem = std.mem;
const cfg = @import("config.zig");

const lt = @import("layout.zig");
const Layout = lt.Layout;
const Client = @import("client.zig").Client;
const BarPosition = @import("enums.zig").BarPosition;

const X = @import("c_lib.zig").X;
const Allocator = std.mem.Allocator;
const Rect = @import("rect.zig").Rect;

const Window = X.Window;

pub const Monitor = struct {
    const Self = @This();
    /// A string to represent the current layout.
    layout_symbol: []const u8 = undefined,
    /// Master window factor.
    mfact: f32 = cfg.mfact,
    /// Number of master windows.
    nmaster: i32 = cfg.nmaster,
    /// TODO: without Xinerama support, this may be obsolete.
    num: i32 = undefined,
    /// Bar geometry.
    by: i32 = undefined,
    /// Current monitor rect.
    m: Rect = undefined,
    /// Current window rect.
    w: Rect = undefined,
    /// Index of selected tags (indexes `self.tagset`).
    seltags: u1 = 0,
    /// Index of selected layout (indexes `self.lt`).
    sellt: u1 = undefined,
    /// A couple of bitmasks, only ever to be indexed by `seltags`.
    tagset: [2]u32 = .{ 1, 1 },
    /// false means hide bar.
    show_bar: bool = cfg.show_bar,
    bar_pos: BarPosition = cfg.bar_pos,
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

    /// (dwm) createmon
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
