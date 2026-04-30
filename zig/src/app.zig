//! By convention, root.zig is the root source file when making a library.
const std = @import("std");
const xlib = @import("xlib.zig").xlib;
const drw = @import("drw.zig").drw;

pub const App = struct {
    // Note to new Zig learners: if we try to deference this, we get "error:
    // cannot dereference undefined value."
    dpy: ?*xlib.Display,

    screen: c_int,

    /// Screen width.
    sw: c_int,

    /// Screen height.
    sh: c_int,

    root: xlib.Window,

    drw: *drw.Drw,
};
