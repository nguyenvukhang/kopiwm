const std = @import("std");
const X = @import("c_lib.zig").X;
const fc = @import("c_lib.zig").fc;
const mem = std.mem;
const Allocator = mem.Allocator;
const log = std.log;

pub const Cursor = X.Cursor;
pub const Display = X.Display;
pub const Drawable = X.Drawable;
pub const Window = X.Window;
pub const XftColor = X.XftColor;
pub const XftFont = X.XftFont;
pub const FcPattern = X.FcPattern;

// TODO: change this to Font when all is said and done.
/// This represents a linked list of fonts.
pub const Fnt = struct {
    dpy: ?*Display,
    h: u16,
    xfont: ?*XftFont,
    pattern: ?*FcPattern,
    next: ?*Fnt,
};

pub fn Scheme(comptime T: type) type {
    return struct {
        const Self = @This();
        /// Foreground color.
        fg: T,
        /// Background color.
        bg: T,
        /// Border color.
        border: T,
    };
}

pub const ColorScheme = Scheme(XftColor);

/// [dwm] xfont_create
fn xfontCreate(
    allocator: Allocator,
    drw: *Drw,
    fontname: []const u8,
    font_pattern: ?*FcPattern,
) error{OutOfMemory}!?*Fnt {
    var xfont: ?*XftFont = null;
    var pattern: ?*FcPattern = null;

    if (fontname.len > 0) {
        // Using the pattern found at font->xfont->pattern does not yield the
        // same substitution results as using the pattern returned by
        // FcNameParse; using the latter results in the desired fallback
        // behaviour whereas the former just results in missing-character
        // rectangles being drawn, at least with some fonts.
        xfont = X.XftFontOpenName(drw.dpy, drw.screen, @ptrCast(fontname));
        if (xfont == null) {
            std.debug.print("error, cannot load font from name: '{s}'\n", .{fontname});
            return null;
        }
        pattern = X.FcNameParse(@ptrCast(fontname));
        if (pattern == null) {
            std.debug.print("error, cannot parse font name to pattern: '{s}'\n", .{fontname});
            X.XftFontClose(drw.dpy, xfont);
            return null;
        }
    } else if (font_pattern) |fp| {
        xfont = X.XftFontOpenPattern(drw.dpy, fp);
        if (xfont == null) {
            std.debug.print("error, cannot load font from pattern\n", .{});
            return null;
        }
    } else {
        @panic("No font specified.");
    }

    var font = try allocator.create(Fnt);
    font.xfont = xfont;
    font.pattern = pattern;
    font.h = @intCast(xfont.?.ascent);
    font.h += @intCast(xfont.?.descent);
    font.dpy = drw.dpy;

    return font;
}

/// [dwm] xfont_free
fn xfontFree(allocator: Allocator, font: *Fnt) void {
    if (font.pattern) |pattern| {
        X.FcPatternDestroy(pattern);
    }
    X.XftFontClose(font.dpy, font.xfont);
    allocator.destroy(font);
}

pub const Drw = struct {
    const Self = @This();

    /// Width.
    w: u32,
    /// Height.
    h: u32,
    dpy: *Display,
    screen: c_int,
    root: Window,
    drawable: Drawable,
    gc: X.GC,
    scheme: ?ColorScheme = null,
    /// A linked list of fonts.
    fonts: ?*Fnt = null,

    /// [dwm] drw_create
    pub fn init(
        dpy: *Display,
        screen: c_int,
        window: Window,
        /// width
        w: u32,
        /// height
        h: u32,
    ) Self {
        const drw: Self = .{
            .w = w,
            .h = h,
            .dpy = dpy,
            .screen = screen,
            .root = window,
            .drawable = X.XCreatePixmap(dpy, window, w, h, @intCast(X.DefaultDepth(dpy, screen))),
            .gc = X.XCreateGC(dpy, window, 0, null),
        };
        _ = X.XSetLineAttributes(dpy, drw.gc, 1, X.LineSolid, X.CapButt, X.JoinMiter);
        return drw;
    }

    /// [dwm] drw_resize
    pub fn resize(self: *Self, w: u32, h: u32) void {
        self.w = w;
        self.h = h;
        if (self.drawable) {
            X.XFreePixmap(self.dpy, self.drawable);
        }
        self.drawable = X.XCreatePixmap(
            self.dpy,
            self.window,
            w,
            h,
            @intCast(X.DefaultDepth(self.dpy, self.screen)),
        );
    }

    /// [dwm] drw_free
    pub fn deinit(self: *Self, allocator: Allocator) void {
        _ = X.XFreePixmap(self.dpy, self.drawable);
        _ = X.XFreeGC(self.dpy, self.gc);
        fontsetFree(allocator, self.fonts);
    }

    /// [dwm] drw_fontset_create
    pub fn fontsetCreate(self: *Self, allocator: Allocator, fonts: []const []const u8) error{OutOfMemory}!?*Fnt {
        if (fonts.len == 0) {
            return null;
        }
        var cur: ?*Fnt = null;
        var ret: ?*Fnt = null;
        for (fonts) |font| {
            cur = try xfontCreate(allocator, self, font, null);
            if (cur) |cur_| {
                cur_.next = ret;
                ret = cur;
            }
        }
        self.fonts = ret;
        return ret;
    }

    /// [dwm] drw_fontset_free
    pub fn fontsetFree(allocator: Allocator, set: ?*Fnt) void {
        if (set) |f| {
            fontsetFree(allocator, f.next);
            xfontFree(allocator, f);
        }
    }

    /// [dwm] drw_clr_create
    pub fn clrCreate(self: *Self, dest: *XftColor, color_name: []const u8) void {
        const result = X.XftColorAllocName(
            self.dpy,
            X.DefaultVisual(self.dpy, self.screen),
            X.DefaultColormap(self.dpy, self.screen),
            color_name.ptr,
            dest,
        );
        if (result == 0) {
            std.debug.print("error, cannot allocate color '{s}'\n", .{color_name});
            std.process.exit(1);
        }
        dest.pixel |= 0xff << 24;
        log.info("clrCreate({s}) --> {x}", .{ color_name, dest.pixel });
    }

    /// [dwm] drw_clr_free
    pub fn clrFree(self: *Self, c: *XftColor) void {
        X.XftColorFree(
            self.dpy,
            X.DefaultVisual(self.dpy, self.screen),
            X.DefaultColormap(self.dpy, self.screen),
            c,
        );
    }

    /// [dwm] drw_scm_create
    pub fn scmCreate(
        self: *Self,
        allocator: Allocator,
        scheme: Scheme([]const u8),
    ) error{OutOfMemory}!*ColorScheme {
        var ret = try allocator.create(ColorScheme);
        self.clrCreate(&ret.fg, scheme.fg);
        self.clrCreate(&ret.bg, scheme.bg);
        self.clrCreate(&ret.border, scheme.border);
        return ret;
    }

    /// [dwm] drw_scm_free
    pub fn scmFree(self: *Self, allocator: Allocator, scheme: *ColorScheme) void {
        self.clrFree(&scheme.fg);
        self.clrFree(&scheme.bg);
        self.clrFree(&scheme.border);
        allocator.destroy(scheme);
    }

    /// [dwm] drw_cur_create
    pub fn curCreate(self: *Self, shape: c_uint) Cursor {
        return X.XCreateFontCursor(self.dpy, shape);
    }

    /// [dwm] drw_cur_free
    pub fn curFree(self: *Self, cursor: Cursor) void {
        _ = X.XFreeCursor(self.dpy, cursor);
    }
};
