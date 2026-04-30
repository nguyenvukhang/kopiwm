//! By convention, root.zig is the root source file when making a library.
const std = @import("std");
const x = @import("c_lib.zig").x;
const Drw = @import("structs.zig").Drw;

pub const App = struct {
    // Note to new Zig learners: if we try to deference this, we get "error:
    // cannot dereference undefined value."
    dpy: ?*x.Display,

    screen: c_int,

    /// Screen width.
    sw: u32,

    /// Screen height.
    sh: u32,

    root: x.Window,

    drw: Drw,
};
