pub const X = @cImport({
    @cInclude("X11/Xlib.h");
    @cInclude("X11/cursorfont.h");
    @cInclude("X11/keysym.h");
    @cInclude("X11/Xatom.h");
    @cInclude("X11/Xproto.h");
    @cInclude("X11/Xutil.h");
    @cInclude("X11/Xft/Xft.h");
});

pub const fc = @cImport({
    @cInclude("fontconfig/fontconfig.h");
});

pub const C = @cImport({
    @cInclude("locale.h");
    @cInclude("signal.h");
});
