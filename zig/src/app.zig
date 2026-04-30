//! By convention, root.zig is the root source file when making a library.
const std = @import("std");
const xlib = @import("xlib.zig").xlib;

pub const App = struct {
    // Note to new Zig learners: if we try to deference this, we get "error:
    // cannot dereference undefined value."
    dpy: ?*xlib.Display = null,
};
