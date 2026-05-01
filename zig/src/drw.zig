const std = @import("std");
const x = @import("c_lib.zig").x;
const fc = @import("c_lib.zig").fc;
const mem = std.mem;

pub const Cursor = x.Cursor;
pub const Display = x.Display;
pub const Drawable = x.Drawable;
pub const Window = x.Window;
pub const XftColor = x.XftColor;

// TODO: change this to Font when all is said and done.
pub const Fnt = struct {
    dpy: ?*Display,
    h: u16,
    xfont: ?*x.XftFont,
    pattern: ?*fc.FcPattern,
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
    allocator: mem.Allocator,
    drw: *Drw,
    fontname: []const u8,
    font_pattern: ?*x.FcPattern,
) !?*Fnt {
    var xfont: ?*x.XftFont = null;
    var pattern: ?*x.FcPattern = null;

    if (fontname.len > 0) {
        // Using the pattern found at font->xfont->pattern does not yield the
        // same substitution results as using the pattern returned by
        // FcNameParse; using the latter results in the desired fallback
        // behaviour whereas the former just results in missing-character
        // rectangles being drawn, at least with some fonts.
        xfont = x.XftFontOpenName(drw.dpy, drw.screen, fontname);
        if (xfont == null) {
            std.debug.print("error, cannot load font from name: '{s}'\n", .{fontname});
            return null;
        }
        pattern = x.FcNameParse(fontname);
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
    font.h = xfont.?.ascent + xfont.?.descent;
    font.dpy = drw.dpy;

    return font;
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
    pub fn deinit(self: *Self) void {
        x.XFreePixmap(self.dpy, self.drawable);
        x.XFreeGC(self.dpy, self.gc);

        // TODO:  port this line of C:
        // drw_fontset_free(drw->fonts);

    }

    /// [dwm] drw_fontset_create
    pub fn fontset_create(self: *Self, fonts: [][]const u8) ?*Fnt {
        if (fonts.len == 0) {
            return null;
        }
        for (fonts) |font| {
            xfontCreate(self, font, null);
        }

        return self.fonts;

        // Fnt *cur, *ret = NULL;
        // size_t i;
        //
        // for (i = 1; i <= fontcount; i++) {
        //     if ((cur = xfont_create(drw, fonts[fontcount - i], NULL))) {
        //         cur->next = ret;
        //         ret = cur;
        //     }
        // }
        // return (drw->fonts = ret);
    }
};
