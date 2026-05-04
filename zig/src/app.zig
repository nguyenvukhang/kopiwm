//! By convention, root.zig is the root source file when making a library.
const std = @import("std");
const build_opts = @import("build_opts");
const X = @import("c_lib.zig").X;
const Net = @import("enums.zig").Net;
const WM = @import("enums.zig").WM;
const SchemeState = @import("enums.zig").SchemeState;
const CursorState = @import("enums.zig").CursorState;
const fstr = @import("fstr.zig").fstr;
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

    wmatom: EnumArray(WM, Atom) = undefined,
    netatom: EnumArray(Net, Atom) = undefined,

    cursors: EnumArray(CursorState, Cursor) = undefined,

    scheme: EnumArray(SchemeState, *ColorScheme) = undefined,

    /// The only purpose for this is to patch for `updatebars`.
    updatebars_buffer: [16]u8 = undefined,

    /// Status bar text.
    stext: fstr(256) = undefined,

    numlockmask: c_uint = undefined,

    pub fn init() Self {
        var z = Self{};
        const n = @min(build_opts.name.len, z.updatebars_buffer.len);
        @memcpy(z.updatebars_buffer[0..n], build_opts.name[0..n]);
        return z;
    }

    /// [dwm] TEXTW
    pub fn TEXTW(self: *Self, allocator: Allocator, text: []const u8) u32 {
        return self.drw.fontSetGetWidth(allocator, text) + self.lrpad;
    }

    pub fn setStatusText(self: *Self, text: []const u8) void {
        const n = @min(text.len, self.stext_buf.len);
        @memcpy(self.stext_buf[0..n], text[0..n]);
        self.stext = self.stext_buf[0..n];
    }

    pub fn classHint(self: *Self) X.XClassHint {
        return .{
            .res_class = &self.updatebars_buffer,
            .res_name = &self.updatebars_buffer,
        };
    }
};
