//! By convention, root.zig is the root source file when making a library.
const std = @import("std");
const x = @import("c_lib.zig").x;

const Drw = @import("drw.zig").Drw;
const Monitor = @import("monitor.zig").Monitor;
const Window = x.Window;

pub const App = struct {
    // Note to new Zig learners: if we try to deference this, we get "error:
    // cannot dereference undefined value."
    dpy: ?*x.Display,

    screen: c_int,

    /// Screen width.
    sw: u32,

    /// Screen height.
    sh: u32,

    drw: Drw,

    /// Left-right padding.
    lrpad: u16,

    bar_height: u16,

    mons: ?*Monitor,

    /// Selected monitor.
    selmon: ?*Monitor,

    root: Window,
    wmcheckwin: Window,
};
