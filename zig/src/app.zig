//! By convention, root.zig is the root source file when making a library.
const std = @import("std");
const x = @import("c_lib.zig").x;

const Drw = @import("drw.zig").Drw;
const Monitor = @import("monitor.zig").Monitor;
const Window = x.Window;

pub const App = struct {
    // Note to new Zig learners: if we try to deference this, we get "error:
    // cannot dereference undefined value."
    dpy: ?*x.Display = null,

    screen: c_int = undefined,

    /// Screen width.
    sw: u32 = undefined,

    /// Screen height.
    sh: u32 = undefined,

    drw: Drw = undefined,

    /// Left-right padding.
    lrpad: u16 = 0,

    bar_height: i32 = 0,

    mons: ?*Monitor = null,

    /// Selected monitor.
    selmon: ?*Monitor = null,

    root: Window = undefined,
    wmcheckwin: Window = undefined,
};
