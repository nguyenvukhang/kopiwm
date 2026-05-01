const x = @import("c_lib.zig").x;
const fc = @import("c_lib.zig").fc;

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
    fc: ?*fc.FcPattern,
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

    /// Replaces `drw_create` in dwm.
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
};
