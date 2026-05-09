//! By convention, root.zig is the root source file when making a library.
const std = @import("std");
const log = std.log;
const build_opts = @import("build_opts");
const X = @import("c_lib.zig").X;
const Net = @import("atoms.zig").Net;
const WM = @import("atoms.zig").WM;
const SchemeState = @import("enums.zig").SchemeState;
const CursorState = @import("enums.zig").CursorState;
const Size = @import("enums.zig").Size;
const fstr = @import("fstr.zig").fstr;
const Client = @import("client.zig").Client;
const Allocator = std.mem.Allocator;
const EnumArray = @import("enum_array.zig").EnumArray;

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
    dpy: *X.Display = undefined,

    screen: c_int = 0,

    /// Screen size.
    /// Apparently dwm updates this in `void configurenotify(XEvent *)`, and
    /// that's probably how multipe monitors are supported.
    s: Size = .zero,

    drw: Drw = undefined,

    /// Left-right padding.
    lrpad: u32 = 0,

    bar_height: u32 = 0,

    mons: ?*Monitor = null,

    /// Selected monitor.
    selmon: *Monitor = undefined,

    root: Window = 0,

    wmatom: EnumArray(WM, Atom) = .empty,
    netatom: EnumArray(Net, Atom) = .empty,
    cursors: EnumArray(CursorState, Cursor) = .empty,
    scheme: EnumArray(SchemeState, *ColorScheme) = .empty,

    /// The only purpose for this is to patch for `updatebars`.
    updatebars_buffer: fstr(16) = .empty,

    /// Status bar text.
    stext: fstr(256) = .empty,

    numlockmask: c_uint = 0,

    running: bool = true,

    pub fn init() Self {
        var z = Self{};
        z.updatebars_buffer.set(build_opts.name);
        return z;
    }

    /// (dwm) TEXTW
    pub fn TEXTW(self: *Self, allocator: Allocator, text: []const u8) u32 {
        return self.drw.fontSetGetWidth(allocator, text) + self.lrpad;
    }

    pub fn setStatusText(self: *Self, text: []const u8) void {
        const n = @min(text.len, self.stext_buf.len);
        @memcpy(self.stext_buf[0..n], text[0..n]);
        self.stext = self.stext_buf[0..n];
    }

    pub fn classHint(self: *Self) X.XClassHint {
        log.info("Class Hint: {s}", .{self.updatebars_buffer.get()});
        const slice = self.updatebars_buffer.cstr().?;
        return .{ .res_class = slice, .res_name = slice };
    }

    /// (dwm) getrootptr
    pub fn getRootPtr(self: *const Self, x: *c_int, y: *c_int) bool {
        var w: Window = undefined;
        var d_int: c_int = undefined; // dummy c_int.
        var d_uint: c_uint = undefined; // dummy c_uint.
        // XQueryPointer returns the root window the pointer is logically on and
        // the pointer coordinates relative to the root window's origin.
        const res: X.Bool = X.XQueryPointer(self.dpy, self.root, &w, &w, x, y, &d_int, &d_int, &d_uint);
        return res != 0;
    }

    /// Gets the property of a window in text form, and writes it to `buffer`.
    /// Returns the number of valid bytes written to the buffer.
    /// (dwm) gettextprop
    pub fn getTextProp(self: *const Self, w: Window, atom: X.Atom, buffer: []u8) ?usize {
        if (buffer.len == 0) return null;
        var tp: X.XTextProperty = undefined;
        if (X.XGetTextProperty(self.dpy, w, &tp, atom) == 0 or tp.nitems == 0) {
            return null;
        }
        var l: ?usize = null;
        if (tp.encoding == X.XA_STRING) {
            const value: []const u8 = std.mem.span(tp.value);
            l = @min(value.len, buffer.len);
            @memcpy(buffer[0..l.?], value[0..l.?]);
        } else {
            var list: [*c][*c]u8 = undefined;
            var n: c_int = undefined;
            const res = X.XmbTextPropertyToTextList(self.dpy, &tp, &list, &n);
            if (res >= X.Success and n > 0 and list != null) {
                const value: []const u8 = std.mem.span(list[0]);
                l = @min(value.len, buffer.len);
                @memcpy(buffer[0..l.?], value[0..l.?]);
            }
            X.XFreeStringList(list);
        }
        _ = X.XFree(tp.value);
        return l;
    }
};
