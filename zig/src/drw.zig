const std = @import("std");
const X = @import("c_lib.zig").X;
const fc = @import("c_lib.zig").fc;
const Rect = @import("rect.zig").Rect;
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
    const Self = @This();

    dpy: ?*Display,
    h: u16,
    xfont: *XftFont,
    pattern: ?*FcPattern,
    next: ?*Fnt,

    /// (dwm) drw_font_getexts
    pub fn getExts(self: *Self, text: []const u8, w: ?*u32, h: ?*u32) void {
        if (text.len == 0) {
            return;
        }
        var ext: X.XGlyphInfo = undefined;
        X.XftTextExtentsUtf8(self.dpy, self.xfont, text.ptr, @intCast(text.len), &ext);
        if (w) |w_ptr| {
            w_ptr.* = @intCast(ext.xOff);
        }
        if (h) |h_ptr| {
            h_ptr.* = self.h;
        }
    }
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

/// (dwm) xfont_create
fn xfontCreate(
    allocator: Allocator,
    drw: *Drw,
    fontname: []const u8,
    font_pattern: ?*FcPattern,
) error{ OutOfMemory, FontCreateError }!*Fnt {
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
            return error.FontCreateError;
        }
        pattern = X.FcNameParse(@ptrCast(fontname));
        if (pattern == null) {
            std.debug.print("error, cannot parse font name to pattern: '{s}'\n", .{fontname});
            X.XftFontClose(drw.dpy, xfont);
            return error.FontCreateError;
        }
    } else if (font_pattern) |fp| {
        xfont = X.XftFontOpenPattern(drw.dpy, fp);
        if (xfont == null) {
            std.debug.print("error, cannot load font from pattern\n", .{});
            return error.FontCreateError;
        }
    } else {
        std.debug.print("No font specified.", .{});
        return error.FontCreateError;
    }

    var font = try allocator.create(Fnt);
    font.xfont = xfont orelse unreachable;
    font.pattern = pattern;
    font.h = @intCast(xfont.?.ascent);
    font.h += @intCast(xfont.?.descent);
    font.dpy = drw.dpy;

    return font;
}

/// (dwm) xfont_free
fn xfontFree(allocator: Allocator, font: *Fnt) void {
    if (font.pattern) |pattern| {
        X.FcPatternDestroy(pattern);
    }
    X.XftFontClose(font.dpy, font.xfont);
    allocator.destroy(font);
}

/// (dwm) utf8decode
/// Gets the number of bytes required to represent the first utf-8 character in
/// the string `s` provided.
fn utf8decode(s: []const u8, codepoint: *u64, err: *bool) u3 {
    const UTF_INVALID: u32 = 0xFFFD;
    const leading_mask: [4]u8 = .{ 0x7F, 0x1F, 0x0F, 0x07 };
    const overlong: [4]u32 = .{ 0x0, 0x80, 0x0800, 0x10000 };
    const len: u3 = switch (s[0] >> 3) {
        0b00000...0b01111 => 1, // 0XXXX
        0b10000...0b10111 => 0, // 10XXX (invalid)
        0b11000...0b11011 => 2, // 110XX
        0b11100...0b11101 => 3, // 110XX
        0b11110 => 4,
        0b11111 => 0, // (invalid)
        else => unreachable, // because s[0] is 8 bits, so the switch input is 5 bits.
    };
    codepoint.* = UTF_INVALID;
    err.* = true;
    if (len == 0) {
        return 1;
    }

    // Codepoint
    var cp: u64 = s[0] & leading_mask[len - 1];

    for (1..len) |i| {
        if (s[i] == 0 or (s[i] & 0xC0) != 0x80) {
            return @intCast(i);
        }
        cp = (cp << 6) | (s[i] & 0x3F);
    }

    // out of range, surrogate, overlong encoding
    if (cp > 0x10FFFF or (cp >> 11) == 0x1B or cp < overlong[len - 1]) {
        return len;
    }
    err.* = false;
    codepoint.* = cp;
    return len;
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
    /// A linked list of fonts. Guaranteed to have at least one.
    fonts: *Fnt = undefined,

    /// (dwm) drw_create
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

    /// (dwm) drw_resize
    pub fn resize(self: *Self, w: u32, h: u32) void {
        self.w = w;
        self.h = h;
        if (self.drawable != 0) {
            _ = X.XFreePixmap(self.dpy, self.drawable);
        }
        self.drawable = X.XCreatePixmap(
            self.dpy,
            self.root,
            w,
            h,
            @intCast(X.DefaultDepth(self.dpy, self.screen)),
        );
    }

    /// (dwm) drw_free
    pub fn deinit(self: *Self, allocator: Allocator) void {
        _ = X.XFreePixmap(self.dpy, self.drawable);
        _ = X.XFreeGC(self.dpy, self.gc);
        fontsetFree(allocator, self.fonts);
    }

    /// (dwm) drw_fontset_create
    pub fn fontsetCreate(
        self: *Self,
        allocator: Allocator,
        fonts: []const []const u8,
    ) error{ OutOfMemory, FontCreateError }!?*Fnt {
        if (fonts.len == 0) {
            return null;
        }
        var ret: ?*Fnt = null;
        for (fonts) |font| {
            const cur = try xfontCreate(allocator, self, font, null);
            cur.next = ret;
            ret = cur;
        }
        self.fonts = ret orelse {
            @panic("fontsetCreate could not find any viable fonts.");
        };
        return ret;
    }

    /// (dwm) drw_fontset_free
    pub fn fontsetFree(allocator: Allocator, set: ?*Fnt) void {
        if (set) |f| {
            fontsetFree(allocator, f.next);
            xfontFree(allocator, f);
        }
    }

    /// (dwm) drw_clr_create
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

    /// (dwm) drw_clr_free
    pub fn clrFree(self: *Self, c: *XftColor) void {
        X.XftColorFree(
            self.dpy,
            X.DefaultVisual(self.dpy, self.screen),
            X.DefaultColormap(self.dpy, self.screen),
            c,
        );
    }

    /// (dwm) drw_scm_create
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

    /// (dwm) drw_scm_free
    pub fn scmFree(self: *Self, allocator: Allocator, scheme: *ColorScheme) void {
        self.clrFree(&scheme.fg);
        self.clrFree(&scheme.bg);
        self.clrFree(&scheme.border);
        allocator.destroy(scheme);
    }

    /// (dwm) drw_cur_create
    pub fn curCreate(self: *Self, shape: c_uint) Cursor {
        return X.XCreateFontCursor(self.dpy, shape);
    }

    /// (dwm) drw_cur_free
    pub fn curFree(self: *Self, cursor: Cursor) void {
        _ = X.XFreeCursor(self.dpy, cursor);
    }

    /// (dwm) drw_setscheme
    pub fn setScheme(self: *Self, scheme: *ColorScheme) void {
        self.scheme = scheme;
    }

    /// (dwm) drw_setfontset
    pub fn setFontSet(self: *Self, set: *Fnt) void {
        self.fonts = set;
    }

    /// (dwm) drw_rect
    pub fn drawRect(self: *Self, rect: Rect, filled: bool, invert: bool) void {
        const scheme = self.scheme orelse return;
        _ = X.XSetForeground(self.dpy, self.gc, if (invert) scheme.bg.pixel else scheme.fg.pixel);
        if (filled) {
            _ = X.XFillRectangle(self.dpy, self.drawable, self.gc, rect.x, rect.y, rect.w, rect.h);
        } else {
            _ = X.XDrawRectangle(self.dpy, self.drawable, self.gc, rect.x, rect.y, rect.w - 1, rect.h - 1);
        }
    }

    //     void drw_rect(Drw *drw, int x, int y, unsigned int w, unsigned int h,
    //               int filled, int invert) {
    //     XSetForeground(drw->dpy, drw->gc,
    //                    invert ? drw->scheme[ColBg].pixel
    //                           : drw->scheme[ColFg].pixel);
    //     if (filled) {
    //         XFillRectangle(drw->dpy, drw->drawable, drw->gc, x, y, w, h);
    //     } else {
    //         XDrawRectangle(drw->dpy, drw->drawable, drw->gc, x, y, w - 1, h - 1);
    //     }
    // }

    /// (dwm) drw_text
    /// Question: Is `invert` a bitmask? or a boolean? or a numerical value?
    /// Because based on dwm's source code all three cases kinda doesn't fit.
    pub fn drawText(
        self: *Self,
        allocator: Allocator,
        rect: Rect,
        lpad: u32,
        text_to_draw: []const u8,
        invert: u32,
    ) i32 {
        log.info("called drawText(\"{s}\")", .{text_to_draw});
        const INVALID = "�";
        var text: []const u8 = text_to_draw;
        var x = rect.x;
        const y = rect.y;
        var w = rect.w;
        const h = rect.h;
        if (text.len == 0) {
            return 0;
        }

        var usedfont = self.fonts;

        // TODO: figure out why dwm requires x and y to be non-zero.
        const render: bool = x != 0 or y != 0 or w != 0 or h != 0;

        if (render and (self.scheme == null or w == 0)) {
            return 0;
        }

        const state = struct {
            var ellipsis_width: ?u32 = null;
            var invalid_width: ?u32 = null;
            var nomatches: [128]usize = undefined;
        };

        const invert_ = invert != 0; // just the boolean version of `invert`.

        var d: ?*X.XftDraw = null;
        if (!render) {
            // When NOT rendering, treat `invert` as a different kind of value
            // altogether.
            w = if (invert_) invert else ~invert;
        } else {
            const color = if (invert_) &self.scheme.?.fg else &self.scheme.?.bg;
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

        if (state.ellipsis_width == null and render) {
            log.info("Get ellipsis width!", .{});
            state.ellipsis_width = self.fontSetGetWidth(allocator, "...");
        }
        if (state.invalid_width == null and render) {
            log.info("Get invalid character width!", .{});
            state.invalid_width = self.fontSetGetWidth(allocator, INVALID);
        }

        var nextfont: ?*Fnt = null;
        var utf8err: bool = undefined;
        var utf8codepoint: u64 = undefined;
        var ellipsis_x: i32 = 0;
        var ellipsis_len: u32 = undefined;
        var ellipsis_w: u32 = 0;
        var overflow: bool = false;
        var utf8str: []const u8 = undefined;
        var ty: i32 = 0;
        var charexists = false;
        var match_opt: ?*X.FcPattern = null;
        var result: X.XftResult = undefined;
        var utf8charlen: u3 = undefined;
        var ew: u32 = undefined;
        var utf8strlen: u32 = undefined;

        // Main loop for printing text to completion. Breaks only when text runs
        // out or if there is overflow.
        while (true) {
            utf8err = false;
            ellipsis_len = 0;
            utf8charlen = 0;
            utf8strlen = 0;
            ew = 0;
            utf8str = text;
            while (text.len > 0) {
                utf8charlen = utf8decode(text, &utf8codepoint, &utf8err);
                var curfont_opt: ?*Fnt = self.fonts;
                charexists = false;
                var tmpw: u32 = undefined;
                while (curfont_opt) |curfont| : (curfont_opt = curfont.next) {
                    charexists |= X.XftCharExists(self.dpy, curfont.xfont, @intCast(utf8codepoint)) != 0;
                    if (!charexists) {
                        continue;
                    }
                    curfont.getExts(text[0..utf8charlen], &tmpw, null);

                    // TODO: possible dwm bug here that ellipsis width is not
                    // initialized yet.
                    if (ew + (state.ellipsis_width orelse 0) <= w) {
                        // keep track where the ellipsis still fits
                        ellipsis_x = x + @as(i32, @intCast(ew));
                        ellipsis_w = w - ew;
                        ellipsis_len = utf8strlen;
                    }

                    if (ew + tmpw > w) {
                        overflow = true;
                        // called from drw_fontset_getwidth_clamp():
                        // it wants the width AFTER the overflow
                        if (!render) {
                            x += @intCast(tmpw);
                        } else {
                            utf8strlen = ellipsis_len;
                        }
                    } else if (curfont == usedfont) {
                        text = text[utf8charlen..];
                        utf8strlen += if (utf8err) 0 else utf8charlen;
                        ew += if (utf8err) 0 else tmpw;
                    } else {
                        nextfont = curfont;
                    }
                    break;
                }

                if (overflow or !charexists or nextfont != null or utf8err) {
                    break;
                } else {
                    charexists = false;
                }
            }

            if (utf8strlen > 0) {
                if (render) {
                    ty = y + @divTrunc(@as(i32, @intCast(h - usedfont.h)), 2) + usedfont.xfont.ascent;
                    const color = if (invert_) &self.scheme.?.bg else &self.scheme.?.fg;
                    X.XftDrawStringUtf8(d, color, usedfont.xfont, x, ty, utf8str.ptr, @intCast(utf8strlen));
                }
                x += @intCast(ew);
                w -= ew;
            }

            if (utf8err and (!render or (state.invalid_width orelse w) < w)) {
                if (render) {
                    _ = self.drawText(allocator, .{ .x = x, .y = y, .w = w, .h = h }, 0, INVALID, invert);
                }
                x += @intCast(state.invalid_width orelse 0);
                w -= state.invalid_width orelse 0;
            }

            if (render and overflow) {
                _ = self.drawText(allocator, .{ .x = ellipsis_x, .y = y, .w = ellipsis_w, .h = h }, 0, "...", invert);
            }

            if (text.len == 0 or overflow) {
                break;
            } else if (nextfont) |f| {
                charexists = false;
                usedfont = f;
            } else {
                log.warn("Using fallback font", .{});
                // Regardless of whether or not a fallback font is found, the
                // character must be drawn.
                charexists = true;

                var hash: usize = @intCast(utf8codepoint);
                hash = ((hash >> 16) ^ hash) *% 0x21F0AAAD;
                hash = ((hash >> 15) ^ hash) *% 0xD35A2D97;
                const l = state.nomatches.len;
                const h0 = ((hash >> 15) ^ hash) % l;
                const h1 = (hash >> 17) % l;
                // avoid expensive XftFontMatch call when we know we won't find
                // a match
                if (state.nomatches[h0] == utf8codepoint or state.nomatches[h1] == utf8codepoint) {
                    usedfont = self.fonts;
                    continue;
                }

                const fccharset = X.FcCharSetCreate();
                _ = X.FcCharSetAddChar(fccharset, @intCast(utf8codepoint));

                if (self.fonts.pattern == null) {
                    // Refer to the comment in xfont_create for more information.
                    @panic("the first font in the cache must be loaded from a font string.");
                }

                const fcpattern = X.FcPatternDuplicate(self.fonts.pattern);
                _ = X.FcPatternAddCharSet(fcpattern, X.FC_CHARSET, fccharset);
                _ = X.FcPatternAddBool(fcpattern, X.FC_SCALABLE, X.FcTrue);

                _ = X.FcConfigSubstitute(null, fcpattern, X.FcMatchPattern);
                X.FcDefaultSubstitute(fcpattern);
                match_opt = X.XftFontMatch(self.dpy, self.screen, fcpattern, &result);

                X.FcCharSetDestroy(fccharset);
                X.FcPatternDestroy(fcpattern);

                if (match_opt) |match| {
                    const j = if (state.nomatches[h0] > 0) h1 else h0;
                    usedfont = xfontCreate(allocator, self, "", match) catch {
                        state.nomatches[j] = utf8codepoint;
                        continue;
                    };
                    if (X.XftCharExists(self.dpy, usedfont.xfont, @intCast(utf8codepoint)) != 0) {
                        var curfont: *Fnt = self.fonts;
                        while (curfont.next) |next| : (curfont = next) {}
                        curfont.next = usedfont;
                    } else {
                        state.nomatches[j] = utf8codepoint;
                        xfontFree(allocator, usedfont);
                    }
                }
            }
        }
        if (d) |draw| X.XftDrawDestroy(draw);
        return x + if (render) @as(i32, @intCast(w)) else 0;
    }

    /// (dwm) drw_fontset_getwidth
    pub fn fontSetGetWidth(self: *Self, allocator: Allocator, text: []const u8) u32 {
        log.info("called fontSetGetWidth", .{});
        if (text.len == 0) {
            return 0;
        }
        return @intCast(self.drawText(allocator, .zero, 0, text, 0));
    }

    /// (dwm) drw_map
    pub fn map(self: *Self, w: Window, r: Rect) void {
        _ = X.XCopyArea(self.dpy, self.drawable, w, self.gc, r.x, r.y, r.w, r.h, r.x, r.y);
        _ = X.XSync(self.dpy, X.False);
    }
};
