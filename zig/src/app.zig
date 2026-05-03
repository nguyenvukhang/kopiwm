//! By convention, root.zig is the root source file when making a library.
const std = @import("std");
const X = @import("c_lib.zig").X;
const Net = @import("enums.zig").Net;
const WM = @import("enums.zig").WM;
const SchemeState = @import("enums.zig").SchemeState;
const Cur = @import("enums.zig").Cur;
const Allocator = std.mem.Allocator;
const EnumArray = std.enums.EnumArray;

const Drw = @import("drw.zig").Drw;
const ColorScheme = @import("drw.zig").ColorScheme;
const Monitor = @import("monitor.zig").Monitor;
const Window = X.Window;
const Atom = X.Atom;
const Cursor = X.Cursor;

pub const App = struct {
    const Self = @This();

    // Note to new Zig learners: if we try to deference this, we get "error:
    // cannot dereference undefined value."
    dpy: ?*X.Display = null,

    screen: c_int = undefined,

    /// Screen width.
    sw: u32 = undefined,

    /// Screen height.
    sh: u32 = undefined,

    drw: Drw = undefined,

    /// Left-right padding.
    lrpad: u32 = 0,

    bar_height: u32 = 0,

    mons: ?*Monitor = null,

    /// Selected monitor.
    selmon: ?*Monitor = null,

    root: Window = undefined,
    wmcheckwin: Window = undefined,

    wmatom: [std.meta.fields(WM).len]Atom = undefined,
    netatom: [std.meta.fields(Net).len]Atom = undefined,

    cursors: [std.meta.fields(Cur).len]Cursor = undefined,

    scheme: EnumArray(SchemeState, *ColorScheme) = undefined,

    /// The only purpose for this is to patch for `updatebars`.
    updatebars_buffer: [16]u8 = undefined,

    /// Status bar text.
    stext_buf: [256]u8 = undefined,
    stext: []const u8 = undefined,

    /// [dwm] TEXTW
    pub fn TEXTW(self: *Self, allocator: Allocator, text: []const u8) u32 {
        return self.drw.fontSetGetWidth(allocator, text) + self.lrpad;
    }

    pub fn setStatusText(self: *Self, text: []const u8) void {
        const n = @min(text.len, self.stext_buf.len);
        @memcpy(self.stext_buf[0..n], text[0..n]);
        self.stext = self.stext_buf[0..n];
    }
};
