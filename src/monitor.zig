const std = @import("std");
const mem = std.mem;
const cfg = @import("config.zig");

const toggle = @import("toggle.zig").toggle;
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
    nmaster: u32 = cfg.nmaster,
    /// Status bar's y-coordinate.
    by: i32 = undefined,
    /// Current monitor rect.
    m: Rect = .zero,
    /// Current window rect.
    w: Rect = .zero,
    /// The bitmask of visible tags. Initialize with the first tag visible.
    tags: u32 = cfg.tagMask(0),
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
    barwin: Window = 0,
    lt: toggle(*const Layout),

    /// (dwm) createmon
    pub fn init(allocator: Allocator) error{OutOfMemory}!*Self {
        var m = try allocator.create(Self);
        m.* = .{
            .lt = .init(&cfg.layouts[0]),
        };
        m.layout_symbol = m.lt.now.symbol;
        std.log.info("Initialized a monitor!", .{});
        return m;
    }

    /// Checks if the currently selected client.
    pub fn tagMaskIsActive(self: *Self, mask: u32) bool {
        const sel = self.sel orelse return false;
        return (sel.tags & mask) != 0;
    }
};
