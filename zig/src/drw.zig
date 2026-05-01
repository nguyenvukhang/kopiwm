const std = @import("std");
const x = @import("c_lib.zig").x;
const fc = @import("c_lib.zig").fc;
const mem = std.mem;
const Allocator = mem.Allocator;

pub const Cursor = x.Cursor;
pub const Display = x.Display;
pub const Drawable = x.Drawable;
pub const Window = x.Window;
pub const XftColor = x.XftColor;

// TODO: change this to Font when all is said and done.
/// This represents a linked list of fonts.
pub const Fnt = struct {
    dpy: ?*Display,
    h: u16,
    xfont: ?*x.XftFont,
    pattern: ?*x.FcPattern,
    next: ?*Fnt,
};

pub const ColorSchemeIdx = enum(u8) {
    /// Foreground color.
    Fg = 0,
    /// Background color.
    Bg = 1,
    /// Border color.
    Border = 2,
};

pub const ColorScheme = struct {
    /// Foreground color.
    fg: XftColor,
    /// Background color.
    bg: XftColor,
    /// Border color.
    border: XftColor,
};

/// [dwm] xfont_create
fn xfontCreate(
    allocator: Allocator,
    drw: *Drw,
    fontname: []const u8,
    font_pattern: ?*x.FcPattern,
) error{OutOfMemory}!?*Fnt {
    var xfont: ?*x.XftFont = null;
    var pattern: ?*x.FcPattern = null;

    if (fontname.len > 0) {
        // Using the pattern found at font->xfont->pattern does not yield the
        // same substitution results as using the pattern returned by
        // FcNameParse; using the latter results in the desired fallback
        // behaviour whereas the former just results in missing-character
        // rectangles being drawn, at least with some fonts.
        xfont = x.XftFontOpenName(drw.dpy, drw.screen, @ptrCast(fontname));
        if (xfont == null) {
            std.debug.print("error, cannot load font from name: '{s}'\n", .{fontname});
            return null;
        }
        pattern = x.FcNameParse(@ptrCast(fontname));
        if (pattern == null) {
            std.debug.print("error, cannot parse font name to pattern: '{s}'\n", .{fontname});
            x.XftFontClose(drw.dpy, xfont);
            return null;
        }
    } else if (font_pattern) |fp| {
        xfont = x.XftFontOpenPattern(drw.dpy, fp);
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
        x.FcPatternDestroy(pattern);
    }
    x.XftFontClose(font.dpy, font.xfont);
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
    gc: x.GC,
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
            .drawable = x.XCreatePixmap(dpy, window, w, h, @intCast(x.DefaultDepth(dpy, screen))),
            .gc = x.XCreateGC(dpy, window, 0, null),
        };
        _ = x.XSetLineAttributes(dpy, drw.gc, 1, x.LineSolid, x.CapButt, x.JoinMiter);
        return drw;
    }

    /// [dwm] drw_resize
    pub fn resize(self: *Self, w: u32, h: u32) void {
        self.w = w;
        self.h = h;
        if (self.drawable) {
            x.XFreePixmap(self.dpy, self.drawable);
        }
        self.drawable = x.XCreatePixmap(
            self.dpy,
            self.window,
            w,
            h,
            @intCast(x.DefaultDepth(self.dpy, self.screen)),
        );
    }

    /// [dwm] drw_free
    pub fn deinit(self: *Self, allocator: Allocator) void {
        _ = x.XFreePixmap(self.dpy, self.drawable);
        _ = x.XFreeGC(self.dpy, self.gc);
        fontsetFree(allocator, self.fonts);
    }

    /// [dwm] drw_fontset_create
    pub fn fontsetCreate(self: *Self, alloc: Allocator, fonts: []const []const u8) error{OutOfMemory}!?*Fnt {
        if (fonts.len == 0) {
            return null;
        }
        var cur: ?*Fnt = null;
        var ret: ?*Fnt = null;
        for (fonts) |font| {
            cur = try xfontCreate(alloc, self, font, null);
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
};
