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
    scheme: ?*ColorScheme = null,
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

    /// [dwm] drw_setscheme
    pub fn setScheme(self: *Self, scheme: *ColorScheme) void {
        self.scheme = scheme;
    }

    /// [dwm] drw_setfontset
    pub fn setFontSet(self: *Self, set: *Fnt) void {
        self.fonts = set;
    }

    // #define TEXTW(X) (drw_fontset_getwidth(drw, (X)) + lrpad)

    /// [dwm] drw_text
    pub fn drawText(
        self: *Self,
        x_coord: i32,
        y_coord: i32,
        width: u32,
        height: u32,
        lpad: u32,
        text: []const u8,
        invert: u32,
    ) i32 {
        var x = x_coord;
        const y = y_coord;
        var w = width;
        const h = height;
        if (text.len == 0) {
            return 0;
        }
        const fonts = self.fonts orelse return 0;
        // TODO: figure out why dwm requires x and y to be non-zero.
        const render: bool = x != 0 or y != 0 or w != 0 or h != 0;
        if (render and (self.scheme == null or w == 0)) {
            return 0;
        }
        const invert_ = invert != 0; // just the boolean version of `invert`.

        var d: ?*X.XftDraw = null;
        if (!render) {
            w = if (invert == 0) ~invert else invert;
        } else {
            const color = if (invert_) self.scheme.?.fg else self.scheme.?.bg;
            _ = X.XSetForeground(self.dpy, self.gc, color.pixel);
            _ = X.XFillRectangle(self.dpy, self.drawable, self.gc, x, y, w, h);
            if (w < lpad) {
                return x + @as(i32, @intCast(w));
            }
            d = X.XftDrawCreate(
                self.dpy,
                self.drawable,
                X.DefaultVisual(self.dpy, self.screen),
                X.DefaultColormap(self.dpy, self.screen),
            );
            x += @intCast(lpad);
            w -= lpad;
        }
        _ = fonts;

        // int ty, ellipsis_x = 0;
        // unsigned int tmpw, ew, ellipsis_w = 0, ellipsis_len, hash, h0, h1;
        // XftDraw *d = NULL;
        // Fnt *usedfont, *curfont, *nextfont;
        // int utf8strlen, utf8charlen, utf8err, render = x || y || w || h;
        // long utf8codepoint = 0;
        // const char *utf8str;
        // FcCharSet *fccharset;
        // FcPattern *fcpattern;
        // FcPattern *match;
        // XftResult result;
        // int charexists = 0, overflow = 0;

        // keep track of a couple codepoints for which we have no match.
        // static unsigned int nomatches[128], ellipsis_width, invalid_width;
        // static const char invalid[] = "�";

        // if (!render) {
        //     w = invert ? invert : ~invert;
        // } else {
        //     XSetForeground(drw->dpy, drw->gc,
        //                    drw->scheme[invert ? ColFg : ColBg].pixel);
        //     XFillRectangle(drw->dpy, drw->drawable, drw->gc, x, y, w, h);
        //     if (w < lpad) {
        //         return x + w;
        //     }
        //     d = XftDrawCreate(drw->dpy, drw->drawable,
        //                       DefaultVisual(drw->dpy, drw->screen),
        //                       DefaultColormap(drw->dpy, drw->screen));
        //     x += lpad;
        //     w -= lpad;
        // }
        //
        // usedfont = drw->fonts;
        // if (!ellipsis_width && render) {
        //     ellipsis_width = drw_fontset_getwidth(drw, "...");
        // }
        // if (!invalid_width && render) {
        //     invalid_width = drw_fontset_getwidth(drw, invalid);
        // }
        // while (1) {
        //     ew = ellipsis_len = utf8err = utf8charlen = utf8strlen = 0;
        //     utf8str = text;
        //     nextfont = NULL;
        //     while (*text) {
        //         utf8charlen = utf8decode(text, &utf8codepoint, &utf8err);
        //         for (curfont = drw->fonts; curfont; curfont = curfont->next) {
        //             charexists =
        //                 charexists ||
        //                 XftCharExists(drw->dpy, curfont->xfont, utf8codepoint);
        //             if (charexists) {
        //                 drw_font_getexts(curfont, text, utf8charlen, &tmpw, NULL);
        //                 if (ew + ellipsis_width <= w) {
        //                     /* keep track where the ellipsis still fits */
        //                     ellipsis_x = x + ew;
        //                     ellipsis_w = w - ew;
        //                     ellipsis_len = utf8strlen;
        //                 }
        //
        //                 if (ew + tmpw > w) {
        //                     overflow = 1;
        //                     /* called from drw_fontset_getwidth_clamp():
        //                      * it wants the width AFTER the overflow
        //                      */
        //                     if (!render) {
        //                         x += tmpw;
        //                     } else {
        //                         utf8strlen = ellipsis_len;
        //                     }
        //                 } else if (curfont == usedfont) {
        //                     text += utf8charlen;
        //                     utf8strlen += utf8err ? 0 : utf8charlen;
        //                     ew += utf8err ? 0 : tmpw;
        //                 } else {
        //                     nextfont = curfont;
        //                 }
        //                 break;
        //             }
        //         }
        //
        //         if (overflow || !charexists || nextfont || utf8err) {
        //             break;
        //         } else {
        //             charexists = 0;
        //         }
        //     }
        //
        //     if (utf8strlen) {
        //         if (render) {
        //             ty = y + (h - usedfont->h) / 2 + usedfont->xfont->ascent;
        //             XftDrawStringUtf8(d, &drw->scheme[invert ? ColBg : ColFg],
        //                               usedfont->xfont, x, ty, (XftChar8 *)utf8str,
        //                               utf8strlen);
        //         }
        //         x += ew;
        //         w -= ew;
        //     }
        //     if (utf8err && (!render || invalid_width < w)) {
        //         if (render) {
        //             drw_text(drw, x, y, w, h, 0, invalid, invert);
        //         }
        //         x += invalid_width;
        //         w -= invalid_width;
        //     }
        //     if (render && overflow) {
        //         drw_text(drw, ellipsis_x, y, ellipsis_w, h, 0, "...", invert);
        //     }
        //
        //     if (!*text || overflow) {
        //         break;
        //     } else if (nextfont) {
        //         charexists = 0;
        //         usedfont = nextfont;
        //     } else {
        //         /* Regardless of whether or not a fallback font is found, the
        //          * character must be drawn. */
        //         charexists = 1;
        //
        //         hash = (unsigned int)utf8codepoint;
        //         hash = ((hash >> 16) ^ hash) * 0x21F0AAAD;
        //         hash = ((hash >> 15) ^ hash) * 0xD35A2D97;
        //         h0 = ((hash >> 15) ^ hash) % LENGTH(nomatches);
        //         h1 = (hash >> 17) % LENGTH(nomatches);
        //         /* avoid expensive XftFontMatch call when we know we won't find a
        //          * match */
        //         if (nomatches[h0] == utf8codepoint ||
        //             nomatches[h1] == utf8codepoint) {
        //             goto no_match;
        //         }
        //
        //         fccharset = FcCharSetCreate();
        //         FcCharSetAddChar(fccharset, utf8codepoint);
        //
        //         if (!drw->fonts->pattern) {
        //             /* Refer to the comment in xfont_create for more information. */
        //             die("the first font in the cache must be loaded from a font "
        //                 "string.");
        //         }
        //
        //         fcpattern = FcPatternDuplicate(drw->fonts->pattern);
        //         FcPatternAddCharSet(fcpattern, FC_CHARSET, fccharset);
        //         FcPatternAddBool(fcpattern, FC_SCALABLE, FcTrue);
        //
        //         FcConfigSubstitute(NULL, fcpattern, FcMatchPattern);
        //         FcDefaultSubstitute(fcpattern);
        //         match = XftFontMatch(drw->dpy, drw->screen, fcpattern, &result);
        //
        //         FcCharSetDestroy(fccharset);
        //         FcPatternDestroy(fcpattern);
        //
        //         if (match) {
        //             usedfont = xfont_create(drw, NULL, match);
        //             if (usedfont &&
        //                 XftCharExists(drw->dpy, usedfont->xfont, utf8codepoint)) {
        //                 for (curfont = drw->fonts; curfont->next;
        //                      curfont = curfont->next); /* NOP */
        //                 curfont->next = usedfont;
        //             } else {
        //                 xfont_free(usedfont);
        //                 nomatches[nomatches[h0] ? h1 : h0] = utf8codepoint;
        //             no_match:
        //                 usedfont = drw->fonts;
        //             }
        //         }
        //     }
        // }
        // if (d) {
        //     XftDrawDestroy(d);
        // }
        //
        // return x + (render ? w : 0);

        return 0;
    }

    /// [dwm] drw_fontset_getwidth
    pub fn fontSetGetWidth(self: *Self, text: []const u8) u32 {
        if (self.fonts == null or text.len == 0) {
            return 0;
        }
        return @intCast(self.drawText(0, 0, 0, 0, 0, text, 0));
    }
    // unsigned int drw_fontset_getwidth(Drw *drw, const char *text) {
    // if (!drw || !drw->fonts || !text) {
    //     return 0;
    // }
    // return drw_text(drw, 0, 0, 0, 0, 0, text, 0);
    // }

};
